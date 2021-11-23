// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:async/async.dart';
import 'package:http_multi_server/http_multi_server.dart';
import 'package:image/image.dart';
import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;
import 'package:pool/pool.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_packages_handler/shelf_packages_handler.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:stream_channel/stream_channel.dart';

import 'package:test_api/src/backend/runtime.dart';
import 'package:test_api/src/backend/suite_platform.dart';
import 'package:test_core/src/runner/configuration.dart';
import 'package:test_core/src/runner/environment.dart';
import 'package:test_core/src/runner/platform.dart';
import 'package:test_core/src/runner/plugin/platform_helpers.dart';
import 'package:test_core/src/runner/runner_suite.dart';
import 'package:test_core/src/runner/suite.dart';
import 'package:test_core/src/util/io.dart';
import 'package:test_core/src/util/stack_trace_mapper.dart';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_test_utils/goldens.dart';
import 'package:web_test_utils/image_compare.dart';
import 'package:web_test_utils/skia_client.dart';

import 'browser.dart';
import 'common.dart';
import 'environment.dart' as env;

/// Custom test platform that serves web engine unit tests.
class BrowserPlatform extends PlatformPlugin {
  /// Starts the server.
  ///
  /// [browserEnvironment] provides the browser environment to run the test.
  ///
  /// If [doUpdateScreenshotGoldens] is true updates screenshot golden files
  /// instead of failing the test on screenshot mismatches.
  static Future<BrowserPlatform> start({
    required BrowserEnvironment browserEnvironment,
    required bool doUpdateScreenshotGoldens,
    required SkiaGoldClient? skiaClient,
    required String? overridePathToCanvasKit,
  }) async {
    final shelf_io.IOServer server = shelf_io.IOServer(await HttpMultiServer.loopback(0));
    return BrowserPlatform._(
      browserEnvironment: browserEnvironment,
      server: server,
      isDebug: Configuration.current.pauseAfterLoad,
      doUpdateScreenshotGoldens: doUpdateScreenshotGoldens,
      packageConfig: await loadPackageConfigUri((await Isolate.packageConfig)!),
      skiaClient: skiaClient,
      overridePathToCanvasKit: overridePathToCanvasKit,
    );
  }

  /// If true, runs the browser with a visible windows (i.e. not headless) and
  /// pauses before running the tests to give the developer a chance to set
  /// breakpoints in the code.
  final bool isDebug;

  /// The underlying server.
  final shelf.Server server;

  /// Provides the environment for the browser running tests.
  final BrowserEnvironment browserEnvironment;

  /// The URL for this server.
  Uri get url => server.url.resolve('/');

  /// A [OneOffHandler] for servicing WebSocket connections for
  /// [BrowserManager]s.
  ///
  /// This is one-off because each [BrowserManager] can only connect to a single
  /// WebSocket,
  final OneOffHandler _webSocketHandler = OneOffHandler();

  /// Handles taking screenshots during tests.
  ///
  /// Implementation will differ depending on the browser.
  final ScreenshotManager? _screenshotManager;

  /// Whether [close] has been called.
  bool get _closed => _closeMemo.hasRun;

  /// Whether to update screenshot golden files.
  final bool doUpdateScreenshotGoldens;

  late final shelf.Handler _packageUrlHandler = packagesDirHandler();

  final PackageConfig packageConfig;

  /// A client for communicating with the Skia Gold backend to fetch, compare
  /// and update images.
  final SkiaGoldClient? skiaClient;

  final String? overridePathToCanvasKit;

  BrowserPlatform._({
    required this.browserEnvironment,
    required this.server,
    required this.isDebug,
    required this.doUpdateScreenshotGoldens,
    required this.packageConfig,
    required this.skiaClient,
    required this.overridePathToCanvasKit,
  }) : _screenshotManager = browserEnvironment.getScreenshotManager() {
    // The cascade of request handlers.
    final shelf.Cascade cascade = shelf.Cascade()
        // The web socket that carries the test channels for running tests and
        // reporting restuls. See [_browserManagerFor] and [BrowserManager.start]
        // for details on how the channels are established.
        .add(_webSocketHandler.handler)

        // Serves /packages/* requests; fetches files and sources from
        // pubspec dependencies.
        //
        // Includes:
        //  * Requests for Dart sources from source maps
        //  * Assets that are part of the engine sources, such as Ahem.ttf
        .add(_packageUrlHandler)

        .add(_canvasKitOverrideHandler)

        // Serves files from the web_ui/build/ directory at the root (/) URL path.
        .add(buildDirectoryHandler)

        .add(_testImageListingHandler)

        // Serves the initial HTML for the test.
        .add(_testBootstrapHandler)

        // Serves files from the root of web_ui.
        //
        // This is needed because sourcemaps refer to local files, i.e. those
        // that don't come from package dependencies, relative to web_ui/.
        //
        // Examples of URLs that this handles:
        //  * /test/alarm_clock_test.dart
        //  * /lib/src/engine/alarm_clock.dart
        .add(createStaticHandler(env.environment.webUiRootDir.path))

        // Serves absolute package URLs (i.e. not /packages/* but /Users/user/*/hosted/pub.dartlang.org/*).
        // This handler goes last, after all more specific handlers failed to handle the request.
        .add(_createAbsolutePackageUrlHandler())
        .add(_screeshotHandler)
        .add(_fileNotFoundCatcher);

    server.mount(cascade.handler);
  }

  /// If a path to a custom local build of CanvasKit was specified, serve from
  /// there instead of serving the default CanvasKit in the build/ directory.
  Future<shelf.Response> _canvasKitOverrideHandler(shelf.Request request) async {
    final String? pathOverride = overridePathToCanvasKit;

    if (pathOverride == null || !request.url.path.startsWith('canvaskit/')) {
      return shelf.Response.notFound('Not a request for CanvasKit.');
    }

    final File file = File(p.joinAll(<String>[
      pathOverride,
      ...p.split(request.url.path).skip(1),
    ]));

    if (!file.existsSync()) {
      return shelf.Response.notFound('File not found: ${request.url.path}');
    }

    final String extension = p.extension(file.path);
    final String? contentType = contentTypes[extension];

    if (contentType == null) {
      final String error = 'Failed to determine Content-Type for "${request.url.path}".';
      stderr.writeln(error);
      return shelf.Response.internalServerError(body: error);
    }

    return shelf.Response.ok(
      file.readAsBytesSync(),
      headers: <String, Object>{
        HttpHeaders.contentTypeHeader: contentType,
      },
    );
  }

  /// Lists available test images under `web_ui/build/test_images`.
  Future<shelf.Response> _testImageListingHandler(shelf.Request request) async {
    const Map<String, String> supportedImageTypes = <String, String>{
      '.png': 'image/png',
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.gif': 'image/gif',
      '.webp': 'image/webp',
      '.bmp': 'image/bmp',
    };

    if (request.url.path != 'test_images/') {
      return shelf.Response.notFound('Not found.');
    }

    final Directory testImageDirectory = Directory(p.join(
      env.environment.webUiBuildDir.path,
      'test_images',
    ));

    final List<String> testImageFiles = testImageDirectory
      .listSync(recursive: true)
      .whereType<File>()
      .map<String>((File file) => p.relative(file.path, from: testImageDirectory.path))
      .where((String path) => supportedImageTypes.containsKey(p.extension(path)))
      .toList();

    return shelf.Response.ok(
      json.encode(testImageFiles),
      headers: <String, Object>{
        HttpHeaders.contentTypeHeader: 'application/json',
      },
    );
  }

  Future<shelf.Response> _fileNotFoundCatcher(shelf.Request request) async {
    print('HTTP 404: ${request.url}');
    return shelf.Response.notFound('File not found');
  }

  /// Handles URLs pointing to Dart sources using absolute URI paths.
  ///
  /// Dart source paths that dart2js puts in source maps for pub packages are
  /// relative to the source map file. Example:
  ///
  ///     ../../../../../../../../../Users/yegor/AppData/Local/Pub/Cache/hosted/pub.dartlang.org/stack_trace-1.10.0/lib/src/frame.dart
  ///
  /// When the browser requests the file from the source map it sends a GET
  /// request like this:
  ///
  ///     GET /Users/yegor/AppData/Local/Pub/Cache/hosted/pub.dartlang.org/stack_trace-1.10.0/lib/src/frame.dart
  ///
  /// There's no predictable structure in this URL. It's unclear whether this
  /// is a request for a source file, or someone trying to hack your
  /// workstation.
  ///
  /// This handler treats the URL as an absolute path, but instead of
  /// unconditionally serving it, it first checks with `package_config.json` on
  /// whether this is a request for a Dart source that's listed in pubspec
  /// dependencies. For example, the `stack_trace` package would be listed in
  /// `package_config.json` as:
  ///
  ///     file:///C:/Users/yegor/AppData/Local/Pub/Cache/hosted/pub.dartlang.org/stack_trace-1.10.0
  ///
  /// If the requested URL points into one of the packages in the package config,
  /// the file is served. Otherwise, HTTP 404 is returned without file contents.
  ///
  /// To handle drive letters (C:\) and *nix file system roots, the URL and
  /// package paths are initially stripped of the root and compared to each
  /// other as prefixes. To actually read the file, the file system root is
  /// prepended before creating the file.
  shelf.Handler _createAbsolutePackageUrlHandler() {
    final Map<String, Package> urlToPackage = <String, Package>{};
    for (final Package package in packageConfig.packages) {
      // Turns the URI as encoded in package_config.json to a file path.
      final String configPath = p.fromUri(package.root);

      // Strips drive letter and root prefix, if any, for example:
      //
      // C:\Users\user\AppData => Users\user\AppData
      // /home/user/path.dart => home/user/path.dart
      final String rootRelativePath = p.relative(configPath, from: p.rootPrefix(configPath));
      urlToPackage[p.toUri(rootRelativePath).path] = package;
    }
    return (shelf.Request request) async {
      final String requestedPath = request.url.path;
      // The cast is needed because keys are non-null String, so there's no way
      // to return null for a mismatch.
      final String? packagePath = urlToPackage.keys.cast<String?>().firstWhere(
        (String? packageUrl) => requestedPath.startsWith(packageUrl!),
        orElse: () => null,
      );
      if (packagePath == null) {
        return shelf.Response.notFound('Not a pub.dartlang.org request');
      }

      // Attach the root prefix, such as drive letter, and convert from URI to path.
      // Examples:
      //
      // Users\user\AppData => C:\Users\user\AppData
      // home/user/path.dart => /home/user/path.dart
      final Package package = urlToPackage[packagePath]!;
      final String filePath = p.join(
        p.rootPrefix(p.fromUri(package.root.path)),
        p.fromUri(requestedPath),
      );
      final File fileInPackage = File(filePath);
      if (!fileInPackage.existsSync()) {
        return shelf.Response.notFound('File not found: $requestedPath');
      }
      return shelf.Response.ok(fileInPackage.openRead());
    };
  }

  Future<shelf.Response> _screeshotHandler(shelf.Request request) async {
    if (!request.requestedUri.path.endsWith('/screenshot')) {
      return shelf.Response.notFound(
          'This request is not handled by the screenshot handler');
    }

    final String payload = await request.readAsString();
    final Map<String, dynamic> requestData =
        json.decode(payload) as Map<String, dynamic>;
    final String filename = requestData['filename'] as String;

    if (_screenshotManager == null) {
      print(
        'INFO: Skipping screenshot check for $filename. Current browser/OS '
        'combination does not support screenshots.',
      );
      return shelf.Response.ok(json.encode('OK'));
    }

    final bool write = requestData['write'] as bool;
    final double maxDiffRate = requestData.containsKey('maxdiffrate')
        ? (requestData['maxdiffrate'] as num)
            .toDouble() // can be parsed as either int or double
        : kMaxDiffRateFailure;
    final Map<String, dynamic> region =
        requestData['region'] as Map<String, dynamic>;
    final PixelComparison pixelComparison = PixelComparison.values.firstWhere(
        (PixelComparison value) => value.toString() == requestData['pixelComparison']);
    final String result = await _diffScreenshot(
        filename, write, maxDiffRate, region, pixelComparison);
    return shelf.Response.ok(json.encode(result));
  }

  Future<String> _diffScreenshot(
      String filename,
      bool write,
      double maxDiffRateFailure,
      Map<String, dynamic> region,
      PixelComparison pixelComparison) async {
    if (doUpdateScreenshotGoldens) {
      write = true;
    }

    String goldensDirectory;
    if (filename.startsWith('__local__')) {
      filename = filename.substring('__local__/'.length);
      goldensDirectory = p.join(
        env.environment.webUiRootDir.path,
        'test',
        'golden_files',
      );
    } else {
      goldensDirectory = p.join(
        env.environment.webUiGoldensRepositoryDirectory.path,
        'engine',
        'web',
      );
    }

    final Rectangle<num> regionAsRectange = Rectangle<num>(
      region['x'] as num,
      region['y'] as num,
      region['width'] as num,
      region['height'] as num,
    );

    // Take screenshot.
    final Image screenshot = await _screenshotManager!.capture(regionAsRectange);

    return compareImage(
      screenshot,
      doUpdateScreenshotGoldens,
      filename,
      pixelComparison,
      maxDiffRateFailure,
      skiaClient,
      goldensDirectory: goldensDirectory,
      filenameSuffix: _screenshotManager!.filenameSuffix,
      write: write,
    );
  }

  static const Map<String, String> contentTypes = <String, String>{
    '.js': 'text/javascript',
    '.wasm': 'application/wasm',
    '.html': 'text/html',
    '.htm': 'text/html',
    '.css': 'text/css',
    '.ico': 'image/icon-x',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.gif': 'image/gif',
    '.webp': 'image/webp',
    '.bmp': 'image/bmp',
    '.svg': 'image/svg+xml',
    '.json': 'application/json',
    '.ttf': 'font/ttf',
    '.woff': 'font/woff',
    '.woff2': 'font/woff2',
  };

  /// A simple file handler that serves files whose URLs and paths are
  /// statically known.
  ///
  /// This is used for trivial use-cases, such as `favicon.ico`, host pages, etc.
  shelf.Response buildDirectoryHandler(shelf.Request request) {
    final File fileInBuild = File(p.join(
      env.environment.webUiBuildDir.path,
      request.url.path,
    ));

    if (!fileInBuild.existsSync()) {
      return shelf.Response.notFound('File not found: ${request.url.path}');
    }

    final String extension = p.extension(fileInBuild.path);
    final String? contentType = contentTypes[extension];

    if (contentType == null) {
      final String error = 'Failed to determine Content-Type for "${request.url.path}".';
      stderr.writeln(error);
      return shelf.Response.internalServerError(body: error);
    }

    return shelf.Response.ok(
      fileInBuild.readAsBytesSync(),
      headers: <String, Object>{
        HttpHeaders.contentTypeHeader: contentType,
      },
    );
  }

  /// Serves the HTML file that bootstraps the test.
  shelf.Response _testBootstrapHandler(shelf.Request request) {
    final String path = p.fromUri(request.url);

    if (path.endsWith('.html')) {
      final String test = p.withoutExtension(path) + '.dart';

      // Link to the Dart wrapper.
      final String scriptBase = htmlEscape.convert(p.basename(test));
      final String link = '<link rel="x-dart-test" href="$scriptBase">';

      return shelf.Response.ok('''
        <!DOCTYPE html>
        <html>
        <head>
          <title>${htmlEscape.convert(test)} Test</title>
          <meta name="assetBase" content="/">
          <script>
            window.flutterConfiguration = {
              canvasKitBaseUrl: "/canvaskit/"
            };
          </script>
          $link
          <script src="packages/test/dart.js"></script>
        </head>
        </html>
      ''', headers: <String, String>{'Content-Type': 'text/html'});
    }

    return shelf.Response.notFound('Not found.');
  }

  void _checkNotClosed() {
    if (_closed) {
      throw StateError('Cannot load test suite. Test platform is closed.');
    }
  }

  /// Loads the test suite at [path] on the platform [platform].
  ///
  /// This will start a browser to load the suite if one isn't already running.
  /// Throws an [ArgumentError] if `platform.platform` isn't a browser.
  @override
  Future<RunnerSuite> load(String path, SuitePlatform platform,
      SuiteConfiguration suiteConfig, Object message) async {
    _checkNotClosed();
    if (suiteConfig.precompiledPath == null) {
      throw Exception('This test platform only supports precompiled JS.');
    }
    final Runtime browser = platform.runtime;
    assert(suiteConfig.runtimes.contains(browser.identifier));

    if (!browser.isBrowser) {
      throw ArgumentError('$browser is not a browser.');
    }
    _checkNotClosed();

    final Uri suiteUrl = url.resolveUri(
        p.toUri(p.withoutExtension(p.relative(path, from: env.environment.webUiBuildDir.path)) + '.html'));
    _checkNotClosed();

    final BrowserManager? browserManager = await _startBrowserManager();
    if (browserManager == null) {
      throw StateError('Failed to initialize browser manager for ${browser.name}');
    }
    _checkNotClosed();

    final RunnerSuite suite = await browserManager.load(path, suiteUrl, suiteConfig, message);
    _checkNotClosed();
    return suite;
  }

  @override
  StreamChannel<dynamic> loadChannel(String path, SuitePlatform platform) =>
      throw UnimplementedError();

  Future<BrowserManager?>? _browserManager;

  /// Starts a browser manager for the browser provided by [browserEnvironment];
  ///
  /// If no browser manager is running yet, starts one.
  Future<BrowserManager?> _startBrowserManager() {
    if (_browserManager != null) {
      return _browserManager!;
    }

    final Completer<WebSocketChannel> completer = Completer<WebSocketChannel>.sync();
    final String path = _webSocketHandler.create(webSocketHandler(completer.complete));
    final Uri webSocketUrl = url.replace(scheme: 'ws').resolve(path);
    final Uri hostUrl = url
        .resolve('host/index.html')
        .replace(queryParameters: <String, dynamic>{
      'managerUrl': webSocketUrl.toString(),
      'debug': isDebug.toString()
    });

    final Future<BrowserManager?> future = BrowserManager.start(
      browserEnvironment: browserEnvironment,
      url: hostUrl,
      future: completer.future,
      packageConfig: packageConfig,
      debug: isDebug,
    );

    // Store null values for browsers that error out so we know not to load them
    // again.
    _browserManager = future.catchError((dynamic _) => null);

    return future;
  }

  /// Close all the browsers that the server currently has open.
  ///
  /// Note that this doesn't close the server itself. Browser tests can still be
  /// loaded, they'll just spawn new browsers.
  @override
  Future<void> closeEphemeral() async {
    if (_browserManager != null) {
      final BrowserManager? result = await _browserManager!;
      await result?.close();
    }
  }

  /// Closes the server and releases all its resources.
  ///
  /// Returns a [Future] that completes once the server is closed and its
  /// resources have been fully released.
  @override
  Future<void> close() {
    return _closeMemo.runOnce(() async {
      final List<Future<void>> futures = <Future<void>>[];
      futures.add(Future<void>.microtask(() async {
        if (_browserManager != null) {
          final BrowserManager? result = await _browserManager!;
          await result?.close();
        }
      }));
      futures.add(server.close());

      await Future.wait(futures);
    });
  }

  final AsyncMemoizer<dynamic> _closeMemo = AsyncMemoizer<dynamic>();
}

/// A Shelf handler that provides support for one-time handlers.
///
/// This is useful for handlers that only expect to be hit once before becoming
/// invalid and don't need to have a persistent URL.
class OneOffHandler {
  /// A map from URL paths to handlers.
  final Map<String, shelf.Handler> _handlers = <String, shelf.Handler>{};

  /// The counter of handlers that have been activated.
  int _counter = 0;

  /// The actual [shelf.Handler] that dispatches requests.
  shelf.Handler get handler => _onRequest;

  /// Creates a new one-off handler that forwards to [handler].
  ///
  /// Returns a string that's the URL path for hitting this handler, relative to
  /// the URL for the one-off handler itself.
  ///
  /// [handler] will be unmounted as soon as it receives a request.
  String create(shelf.Handler handler) {
    final String path = _counter.toString();
    _handlers[path] = handler;
    _counter++;
    return path;
  }

  /// Dispatches [request] to the appropriate handler.
  FutureOr<shelf.Response> _onRequest(shelf.Request request) {
    final List<String> components = p.url.split(request.url.path);
    if (components.isEmpty) {
      return shelf.Response.notFound(null);
    }

    final String path = components.removeAt(0);
    final shelf.Handler? handler = _handlers.remove(path);
    if (handler == null) {
      return shelf.Response.notFound(null);
    }
    return handler(request.change(path: path));
  }
}

/// Manages the connection to a single running browser.
///
/// This is in charge of telling the browser which test suites to load and
/// converting its responses into [Suite] objects.
class BrowserManager {
  final PackageConfig packageConfig;

  /// The browser instance that this is connected to via [_channel].
  final Browser _browser;

  /// The browser environment for this test.
  final BrowserEnvironment _browserEnvironment;

  /// The channel used to communicate with the browser.
  ///
  /// This is connected to a page running `static/host.dart`.
  late final MultiChannel<dynamic> _channel;

  /// A pool that ensures that limits the number of initial connections the
  /// manager will wait for at once.
  ///
  /// This isn't the *total* number of connections; any number of iframes may be
  /// loaded in the same browser. However, the browser can only load so many at
  /// once, and we want a timeout in case they fail so we only wait for so many
  /// at once.
  final Pool _pool = Pool(8);

  /// The ID of the next suite to be loaded.
  ///
  /// This is used to ensure that the suites can be referred to consistently
  /// across the client and server.
  int _suiteID = 0;

  /// Whether the channel to the browser has closed.
  bool _closed = false;

  /// The completer for [_BrowserEnvironment.displayPause].
  ///
  /// This will be `null` as long as the browser isn't displaying a pause
  /// screen.
  CancelableCompleter<void>? _pauseCompleter;

  /// The controller for [_BrowserEnvironment.onRestart].
  final StreamController<dynamic> _onRestartController = StreamController<dynamic>.broadcast();

  /// The environment to attach to each suite.
  late final Future<_BrowserEnvironment> _environment;

  /// Controllers for every suite in this browser.
  ///
  /// These are used to mark suites as debugging or not based on the browser's
  /// pings.
  final Set<RunnerSuiteController> _controllers = <RunnerSuiteController>{};

  // A timer that's reset whenever we receive a message from the browser.
  //
  // Because the browser stops running code when the user is actively debugging,
  // this lets us detect whether they're debugging reasonably accurately.
  late final RestartableTimer _timer;

  /// Starts the browser identified by [runtime] and has it connect to [url].
  ///
  /// [url] should serve a page that establishes a WebSocket connection with
  /// this process. That connection, once established, should be emitted via
  /// [future]. If [debug] is true, starts the browser in debug mode, with its
  /// debugger interfaces on and detected.
  ///
  /// The [settings] indicate how to invoke this browser's executable.
  ///
  /// Returns the browser manager, or throws an [Exception] if a
  /// connection fails to be established.
  static Future<BrowserManager?> start({
    required BrowserEnvironment browserEnvironment,
    required Uri url,
    required Future<WebSocketChannel> future,
    required PackageConfig packageConfig,
    bool debug = false,
  }) {
    final Browser browser = _newBrowser(url, browserEnvironment, debug: debug);

    final Completer<BrowserManager> completer = Completer<BrowserManager>();

    // For the cases where we use a delegator such as `adb` (for Android) or
    // `xcrun` (for IOS), these delegator processes can shut down before the
    // websocket is available. Therefore do not throw an error if process
    // exits with exitCode 0. Note that `browser` will throw and error if the
    // exit code was not 0, which will be processed by the next callback.
    browser.onExit.catchError((Object error, StackTrace stackTrace) {
      if (completer.isCompleted) {
        return;
      }
      completer.completeError(error, stackTrace);
    });

    future.then((WebSocketChannel webSocket) {
      if (completer.isCompleted) {
        return;
      }
      completer.complete(BrowserManager._(packageConfig, browser, browserEnvironment, webSocket));
    }).catchError((Object error, StackTrace stackTrace) {
      browser.close();
      if (completer.isCompleted) {
        return null;
      }
      completer.completeError(error, stackTrace);
    });

    return completer.future;
  }

  /// Starts the browser and requests that it load the test page at [url].
  ///
  /// If [debug] is true, starts the browser in debug mode.
  static Browser _newBrowser(Uri url, BrowserEnvironment browserEnvironment, {bool debug = false}) {
    return browserEnvironment.launchBrowserInstance(url, debug: debug);
  }

  /// Creates a new BrowserManager that communicates with the browser over
  /// [webSocket].
  BrowserManager._(this.packageConfig, this._browser, this._browserEnvironment, WebSocketChannel webSocket) {
    // The duration should be short enough that the debugging console is open as
    // soon as the user is done setting breakpoints, but long enough that a test
    // doing a lot of synchronous work doesn't trigger a false positive.
    //
    // Start this canceled because we don't want it to start ticking until we
    // get some response from the iframe.
    _timer = RestartableTimer(const Duration(seconds: 3), () {
      for (final RunnerSuiteController controller in _controllers) {
        controller.setDebugging(true);
      }
    })
      ..cancel();

    // Whenever we get a message, no matter which child channel it's for, we the
    // know browser is still running code which means the user isn't debugging.
    _channel = MultiChannel<dynamic>(
        webSocket.cast<String>().transform(jsonDocument).changeStream((Stream<Object?> stream) {
      return stream.map((Object? message) {
        if (!_closed) {
          _timer.reset();
        }
        for (final RunnerSuiteController controller in _controllers) {
          controller.setDebugging(false);
        }

        return message;
      });
    }));

    _environment = _loadBrowserEnvironment();
    _channel.stream
        .listen((dynamic message) => _onMessage(message as Map<dynamic, dynamic>), onDone: close);
  }

  /// Loads [_BrowserEnvironment].
  Future<_BrowserEnvironment> _loadBrowserEnvironment() async {
    return _BrowserEnvironment(this, await _browser.observatoryUrl,
        await _browser.remoteDebuggerUrl, _onRestartController.stream);
  }

  /// Tells the browser the load a test suite from the URL [url].
  ///
  /// [url] should be an HTML page with a reference to the JS-compiled test
  /// suite. [path] is the path of the original test suite file, which is used
  /// for reporting. [suiteConfig] is the configuration for the test suite.
  Future<RunnerSuite> load(String path, Uri url, SuiteConfiguration suiteConfig,
      Object message) async {
    url = url.replace(
        fragment: Uri.encodeFull(jsonEncode(<String, dynamic>{
      'metadata': suiteConfig.metadata.serialize(),
      'browser': _browserEnvironment.packageTestRuntime.identifier
    })));

    final int suiteID = _suiteID++;
    RunnerSuiteController? controller;
    void closeIframe() {
      if (_closed) {
        return;
      }
      _controllers.remove(controller);
      _channel.sink.add(<String, dynamic>{'command': 'closeSuite', 'id': suiteID});
    }

    // The virtual channel will be closed when the suite is closed, in which
    // case we should unload the iframe.
    final VirtualChannel<dynamic> virtualChannel = _channel.virtualChannel();
    final int suiteChannelID = virtualChannel.id;
    final StreamChannel<dynamic> suiteChannel = virtualChannel.transformStream(
        StreamTransformer<dynamic, dynamic>.fromHandlers(handleDone: (EventSink<dynamic> sink) {
      closeIframe();
      sink.close();
    }));

    return _pool.withResource<RunnerSuite>(() async {
      _channel.sink.add(<String, dynamic>{
        'command': 'loadSuite',
        'url': url.toString(),
        'id': suiteID,
        'channel': suiteChannelID
      });

      try {
        controller = deserializeSuite(path, currentPlatform(_browserEnvironment.packageTestRuntime),
            suiteConfig, await _environment, suiteChannel, message);

        final String sourceMapFileName =
            '${p.basename(path)}.browser_test.dart.js.map';
        final String pathToTest = p.dirname(path);

        final String mapPath = p.join(env.environment.webUiRootDir.path,
            'build', pathToTest, sourceMapFileName);

        final Map<String, Uri> packageMap = <String, Uri>{
          for (Package p in packageConfig.packages) p.name: p.packageUriRoot
        };
        final JSStackTraceMapper mapper = JSStackTraceMapper(
          await File(mapPath).readAsString(),
          mapUrl: p.toUri(mapPath),
          packageMap: packageMap,
          sdkRoot: p.toUri(sdkDir),
        );

        controller!.channel('test.browser.mapper').sink.add(mapper.serialize());

        _controllers.add(controller!);
        return await controller!.suite;
      } catch (_) {
        closeIframe();
        rethrow;
      }
    });
  }

  /// An implementation of [Environment.displayPause].
  CancelableOperation<void> _displayPause() {
    CancelableCompleter<void>? pauseCompleter = _pauseCompleter;
    if (pauseCompleter != null) {
      return pauseCompleter.operation;
    }

    pauseCompleter = CancelableCompleter<void>(onCancel: () {
      _channel.sink.add(<String, String>{'command': 'resume'});
      _pauseCompleter = null;
    });
    _pauseCompleter = pauseCompleter;

    pauseCompleter.operation.value.whenComplete(() {
      _pauseCompleter = null;
    });

    _channel.sink.add(<String, String>{'command': 'displayPause'});

    return pauseCompleter.operation;
  }

  /// The callback for handling messages received from the host page.
  void _onMessage(Map<dynamic, dynamic> message) {
    switch (message['command'] as String) {
      case 'ping':
        break;

      case 'restart':
        _onRestartController.add(null);
        break;

      case 'resume':
        _pauseCompleter?.complete();
        break;

      default:
        // Unreachable.
        assert(false);
        break;
    }
  }

  /// Closes the manager and releases any resources it owns, including closing
  /// the browser.
  Future<void> close() => _closeMemoizer.runOnce(() {
        _closed = true;
        _timer.cancel();
        _pauseCompleter?.complete();
        _pauseCompleter = null;
        _controllers.clear();
        return _browser.close();
      });
  final AsyncMemoizer<dynamic> _closeMemoizer = AsyncMemoizer<dynamic>();
}

/// An implementation of [Environment] for the browser.
///
/// All methods forward directly to [BrowserManager].
class _BrowserEnvironment implements Environment {
  final BrowserManager _manager;

  @override
  final bool supportsDebugging = true;

  @override
  final Uri? observatoryUrl;

  @override
  final Uri? remoteDebuggerUrl;

  @override
  final Stream<dynamic> onRestart;

  _BrowserEnvironment(this._manager, this.observatoryUrl,
      this.remoteDebuggerUrl, this.onRestart);

  @override
  CancelableOperation<void> displayPause() => _manager._displayPause();
}

bool get isCirrus => Platform.environment['CIRRUS_CI'] == 'true';
