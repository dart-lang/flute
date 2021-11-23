// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// TODO(yjbanov): the Web-only API below need to be cleaned up.

part of ui;

Future<void>? _testPlatformInitializedFuture;

Future<dynamic> ensureTestPlatformInitializedThenRunTest(dynamic Function() body) {
  if (_testPlatformInitializedFuture == null) {
    debugEmulateFlutterTesterEnvironment = true;

    // Initializing the platform will ensure that the test font is loaded.
    _testPlatformInitializedFuture =
        webOnlyInitializePlatform(assetManager: engine.WebOnlyMockAssetManager());
  }
  return _testPlatformInitializedFuture!.then<dynamic>((_) => body());
}

Future<void>? _platformInitializedFuture;

Future<void> webOnlyInitializeTestDomRenderer({double devicePixelRatio = 3.0}) {
  // Force-initialize DomRenderer so it doesn't overwrite test pixel ratio.
  engine.ensureDomRendererInitialized();

  // The following parameters are hard-coded in Flutter's test embedder. Since
  // we don't have an embedder yet this is the lowest-most layer we can put
  // this stuff in.
  engine.window.debugOverrideDevicePixelRatio(devicePixelRatio);
  engine.window.webOnlyDebugPhysicalSizeOverride =
      Size(800 * devicePixelRatio, 600 * devicePixelRatio);
  engine.scheduleFrameCallback = () {};
  debugEmulateFlutterTesterEnvironment = true;

  // Initialize platform once and reuse across all tests.
  if (_platformInitializedFuture != null) {
    return _platformInitializedFuture!;
  }
  return _platformInitializedFuture =
      webOnlyInitializePlatform(assetManager: engine.WebOnlyMockAssetManager());
}
