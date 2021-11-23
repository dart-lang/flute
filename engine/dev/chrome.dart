// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart';
import 'package:pedantic/pedantic.dart';
import 'package:test_api/src/backend/runtime.dart';
import 'package:webkit_inspection_protocol/webkit_inspection_protocol.dart'
    as wip;

import 'browser.dart';
import 'browser_lock.dart';
import 'chrome_installer.dart';
import 'common.dart';
import 'environment.dart';

/// Provides an environment for desktop Chrome.
class ChromeEnvironment implements BrowserEnvironment {
  late final BrowserInstallation _installation;

  @override
  Browser launchBrowserInstance(Uri url, {bool debug = false}) {
    return Chrome(url, _installation, debug: debug);
  }

  @override
  Runtime get packageTestRuntime => Runtime.chrome;

  @override
  Future<void> prepare() async {
    final String version = browserLock.chromeLock.versionForCurrentPlatform;
    _installation = await getOrInstallChrome(
      version,
      infoLog: isCirrus ? stdout : DevNull(),
    );
  }

  @override
  ScreenshotManager? getScreenshotManager() {
    // Always compare screenshots when running tests locally. On CI only compare
    // on Linux.
    if (Platform.isLinux || !isLuci) {
      return ChromeScreenshotManager();
    }
    return null;
  }

  @override
  String get packageTestConfigurationYamlFile => 'dart_test_chrome.yaml';
}

/// Runs desktop Chrome.
///
/// Most of the communication with the browser is expected to happen via HTTP,
/// so this exposes a bare-bones API. The browser starts as soon as the class is
/// constructed, and is killed when [close] is called.
///
/// Any errors starting or running the process are reported through [onExit].
class Chrome extends Browser {
  @override
  final String name = 'Chrome';

  @override
  final Future<Uri> remoteDebuggerUrl;

  /// Starts a new instance of Chrome open to the given [url], which may be a
  /// [Uri] or a [String].
  factory Chrome(Uri url, BrowserInstallation installation, {bool debug = false}) {
    final Completer<Uri> remoteDebuggerCompleter = Completer<Uri>.sync();
    return Chrome._(() async {
      // A good source of various Chrome CLI options:
      // https://peter.sh/experiments/chromium-command-line-switches/
      //
      // Things to try:
      // --font-render-hinting
      // --enable-font-antialiasing
      // --gpu-rasterization-msaa-sample-count
      // --disable-gpu
      // --disallow-non-exact-resource-reuse
      // --disable-font-subpixel-positioning
      final bool isChromeNoSandbox =
          Platform.environment['CHROME_NO_SANDBOX'] == 'true';
      final String dir = environment.webUiDartToolDir.createTempSync('test_chrome_user_data_').resolveSymbolicLinksSync();
      final List<String> args = <String>[
        '--user-data-dir=$dir',
        url.toString(),
        if (!debug)
          '--headless',
        if (isChromeNoSandbox)
          '--no-sandbox',
        // When headless, this is the actual size of the viewport.
        if (!debug)
          '--window-size=$kMaxScreenshotWidth,$kMaxScreenshotHeight',
        // When debugging, run in maximized mode so there's enough room for DevTools.
        if (debug)
          '--start-maximized',
        if (debug)
          '--auto-open-devtools-for-tabs',
        '--disable-extensions',
        '--disable-popup-blocking',
        // Indicates that the browser is in "browse without sign-in" (Guest session) mode.
        '--bwsi',
        '--no-first-run',
        '--no-default-browser-check',
        '--disable-default-apps',
        '--disable-translate',
        '--remote-debugging-port=$kDevtoolsPort',
      ];

      final Process process =
          await _spawnChromiumProcess(installation.executable, args);

      remoteDebuggerCompleter.complete(
          getRemoteDebuggerUrl(Uri.parse('http://localhost:$kDevtoolsPort')));

      unawaited(process.exitCode
          .then((_) => Directory(dir).deleteSync(recursive: true)));

      return process;
    }, remoteDebuggerCompleter.future);
  }

  Chrome._(Future<Process> Function() startBrowser, this.remoteDebuggerUrl)
      : super(startBrowser);
}

/// Used by [Chrome] to detect a glibc bug and retry launching the
/// browser.
///
/// Once every few thousands of launches we hit this glibc bug:
///
/// https://sourceware.org/bugzilla/show_bug.cgi?id=19329.
///
/// When this happens Chrome spits out something like the following then exits with code 127:
///
///     Inconsistency detected by ld.so: ../elf/dl-tls.c: 493: _dl_allocate_tls_init: Assertion `listp->slotinfo[cnt].gen <= GL(dl_tls_generation)' failed!
const String _kGlibcError = 'Inconsistency detected by ld.so';

Future<Process> _spawnChromiumProcess(String executable, List<String> args, { String? workingDirectory }) async {
  // Keep attempting to launch the browser until one of:
  // - Chrome launched successfully, in which case we just return from the loop.
  // - The tool detected an unretriable Chrome error, in which case we throw ToolExit.
  while (true) {
    final Process process = await Process.start(executable, args, workingDirectory: workingDirectory);

    process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((String line) {
        print('[CHROME STDOUT]: $line');
      });

    // Wait until the DevTools are listening before trying to connect. This is
    // only required for flutter_test --platform=chrome and not flutter run.
    bool hitGlibcBug = false;
    await process.stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .map((String line) {
        print('[CHROME STDERR]:$line');
        if (line.contains(_kGlibcError)) {
          hitGlibcBug = true;
        }
        return line;
      })
      .firstWhere((String line) => line.startsWith('DevTools listening'), orElse: () {
        if (hitGlibcBug) {
          const String message = 'Encountered glibc bug '
              'https://sourceware.org/bugzilla/show_bug.cgi?id=19329. '
              'Will try launching browser again.';
          print(message);
          return message;
        }
        print('Failed to launch browser. Command used to launch it: ${args.join(' ')}');
        throw Exception(
          'Failed to launch browser. Make sure you are using an up-to-date '
          'Chrome or Edge. Otherwise, consider using -d web-server instead '
          'and filing an issue at https://github.com/flutter/flutter/issues.',
        );
      });

    if (!hitGlibcBug) {
      return process;
    }

    // A precaution that avoids accumulating browser processes, in case the
    // glibc bug doesn't cause the browser to quit and we keep looping and
    // launching more processes.
    process.exitCode.timeout(const Duration(seconds: 1), onTimeout: () {
      process.kill();
      return -1;
    });
  }
}

/// Returns the full URL of the Chrome remote debugger for the main page.
///
/// This takes the [base] remote debugger URL (which points to a browser-wide
/// page) and uses its JSON API to find the resolved URL for debugging the host
/// page.
Future<Uri> getRemoteDebuggerUrl(Uri base) async {
  try {
    final HttpClient client = HttpClient();
    final HttpClientRequest request = await client.getUrl(base.resolve('/json/list'));
    final HttpClientResponse response = await request.close();
    final List<dynamic>? jsonObject =
        await json.fuse(utf8).decoder.bind(response).single as List<dynamic>?;
    return base.resolve(jsonObject!.first['devtoolsFrontendUrl'] as String);
  } catch (_) {
    // If we fail to talk to the remote debugger protocol, give up and return
    // the raw URL rather than crashing.
    return base;
  }
}

/// [ScreenshotManager] implementation for Chrome.
///
/// This manager can be used for both macOS and Linux.
// TODO(yjbanov): extends tests to Window, https://github.com/flutter/flutter/issues/65673
class ChromeScreenshotManager extends ScreenshotManager {
  @override
  String get filenameSuffix => '';

  /// Capture a screenshot of the web content.
  ///
  /// Uses Webkit Inspection Protocol server's `captureScreenshot` API.
  ///
  /// [region] is used to decide which part of the web content will be used in
  /// test image. It includes starting coordinate x,y as well as height and
  /// width of the area to capture.
  @override
  Future<Image> capture(math.Rectangle<num>? region) async {
    final wip.ChromeConnection chromeConnection =
        wip.ChromeConnection('localhost', kDevtoolsPort);
    final wip.ChromeTab? chromeTab = await chromeConnection.getTab(
        (wip.ChromeTab chromeTab) => chromeTab.url.contains('localhost'));
    if (chromeTab == null) {
      throw StateError(
        'Failed locate Chrome tab with the test page',
      );
    }
    final wip.WipConnection wipConnection = await chromeTab.connect();

    Map<String, dynamic>? captureScreenshotParameters;
    if (region != null) {
      captureScreenshotParameters = <String, dynamic>{
        'format': 'png',
        'clip': <String, dynamic>{
          'x': region.left,
          'y': region.top,
          'width': region.width,
          'height': region.height,
          'scale':
              // This is NOT the DPI of the page, instead it's the "zoom level".
              1,
        },
      };
    }

    // Setting hardware-independent screen parameters:
    // https://chromedevtools.github.io/devtools-protocol/tot/Emulation
    await wipConnection
        .sendCommand('Emulation.setDeviceMetricsOverride', <String, dynamic>{
      'width': kMaxScreenshotWidth,
      'height': kMaxScreenshotHeight,
      'deviceScaleFactor': 1,
      'mobile': false,
    });
    final wip.WipResponse response = await wipConnection.sendCommand(
        'Page.captureScreenshot', captureScreenshotParameters);

    final Image screenshot =
        decodePng(base64.decode(response.result!['data'] as String))!;

    return screenshot;
  }
}
