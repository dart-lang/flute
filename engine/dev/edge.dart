// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:test_api/src/backend/runtime.dart';

import 'browser.dart';
import 'browser_lock.dart';
import 'common.dart';
import 'edge_installation.dart';

/// Provides an environment for the desktop Microsoft Edge (Chromium-based).
class EdgeEnvironment implements BrowserEnvironment {
  @override
  Browser launchBrowserInstance(Uri url, {bool debug = false}) {
    return Edge(url);
  }

  @override
  Runtime get packageTestRuntime => Runtime.internetExplorer;

  @override
  Future<void> prepare() async {
    // Edge doesn't need any special prep.
  }

  @override
  ScreenshotManager? getScreenshotManager() => null;

  @override
  String get packageTestConfigurationYamlFile => 'dart_test_edge.yaml';
}

/// Runs desktop Edge.
///
/// Most of the communication with the browser is expected to happen via HTTP,
/// so this exposes a bare-bones API. The browser starts as soon as the class is
/// constructed, and is killed when [close] is called.
///
/// Any errors starting or running the process are reported through [onExit].
class Edge extends Browser {
  @override
  final String name = 'Edge';

  /// Starts a new instance of Safari open to the given [url], which may be a
  /// [Uri] or a [String].
  factory Edge(Uri url) {
    return Edge._(() async {
      final BrowserInstallation installation = await getEdgeInstallation(
        browserLock.edgeLock.launcherVersion,
        infoLog: DevNull(),
      );

      // Debug is not a valid option for Edge. Remove it.
      String pathToOpen = url.toString();
      if(pathToOpen.contains('debug')) {
        final int index = pathToOpen.indexOf('debug');
        pathToOpen = pathToOpen.substring(0, index-1);
      }

      final Process process = await Process.start(
        installation.executable,
        <String>[pathToOpen,'-k'],
      );

      return process;
    });
  }

  Edge._(Future<Process> Function() startBrowser) : super(startBrowser);
}
