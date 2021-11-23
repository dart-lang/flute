// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:test/bootstrap/browser.dart';
import 'package:test/test.dart';
import 'package:ui/src/engine.dart';
import 'package:ui/ui.dart' as ui;

void main() {
  internalBootstrapBrowserTest(() => testMain);
}

Future<void> testMain() async {
  await ui.webOnlyInitializeTestDomRenderer();
  group('loadFontFromList', () {
    const String _testFontUrl = '/assets/fonts/ahem.ttf';

    tearDown(() {
      html.document.fonts!.clear();
    });

    test('surfaces error from invalid font buffer', () async {
      await expectLater(
          ui.loadFontFromList(Uint8List(0), fontFamily: 'test-font'),
          throwsA(const TypeMatcher<Exception>()));
    },
        // TODO(hterkelsen): https://github.com/flutter/flutter/issues/56702
        // TODO(hterkelsen): https://github.com/flutter/flutter/issues/50770
        skip: browserEngine == BrowserEngine.edge ||
            browserEngine == BrowserEngine.webkit);

    test('loads Blehm font from buffer', () async {
      expect(_containsFontFamily('Blehm'), isFalse);

      final html.HttpRequest response = await html.HttpRequest.request(
          _testFontUrl,
          responseType: 'arraybuffer');
      await ui.loadFontFromList(Uint8List.view(response.response as ByteBuffer),
          fontFamily: 'Blehm');

      expect(_containsFontFamily('Blehm'), isTrue);
    },
        // TODO(hterkelsen): https://github.com/flutter/flutter/issues/56702
        // TODO(hterkelsen): https://github.com/flutter/flutter/issues/50770
        skip: browserEngine == BrowserEngine.edge ||
            browserEngine == BrowserEngine.webkit);

    test('loading font should clear measurement caches', () async {
      final EngineParagraphStyle style = EngineParagraphStyle();
      const ui.ParagraphConstraints constraints =
          ui.ParagraphConstraints(width: 30.0);

      final CanvasParagraphBuilder canvasBuilder = CanvasParagraphBuilder(style);
      canvasBuilder.addText('test');
      // Triggers the measuring and verifies the ruler cache has been populated.
      canvasBuilder.build().layout(constraints);
      expect(Spanometer.rulers.length, 1);

      // Now, loads a new font using loadFontFromList. This should clear the
      // cache
      final html.HttpRequest response = await html.HttpRequest.request(
          _testFontUrl,
          responseType: 'arraybuffer');
      await ui.loadFontFromList(Uint8List.view(response.response as ByteBuffer),
          fontFamily: 'Blehm');

      // Verifies the font is loaded, and the cache is cleaned.
      expect(_containsFontFamily('Blehm'), isTrue);
      expect(Spanometer.rulers.length, 0);
    },
        // TODO(hterkelsen): https://github.com/flutter/flutter/issues/56702
        // TODO(hterkelsen): https://github.com/flutter/flutter/issues/50770
        skip: browserEngine == BrowserEngine.edge ||
            browserEngine == BrowserEngine.webkit);

    test('loading font should send font change message', () async {
      final ui.PlatformMessageCallback? oldHandler = ui.window.onPlatformMessage;
      String? actualName;
      String? message;
      window.onPlatformMessage = (String name, ByteData? data,
          ui.PlatformMessageResponseCallback? callback) {
        actualName = name;
        final ByteBuffer buffer = data!.buffer;
        final Uint8List list =
            buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        message = utf8.decode(list);
      };
      final html.HttpRequest response = await html.HttpRequest.request(
          _testFontUrl,
          responseType: 'arraybuffer');
      await ui.loadFontFromList(Uint8List.view(response.response as ByteBuffer),
          fontFamily: 'Blehm');
      final Completer<void> completer = Completer<void>();
      html.window.requestAnimationFrame( (_) { completer.complete(); } );
      await (completer.future); // ignore: unnecessary_parenthesis
      window.onPlatformMessage = oldHandler;
      expect(actualName, 'flutter/system');
      expect(message, '{"type":"fontsChange"}');
    },
        // TODO(hterkelsen): https://github.com/flutter/flutter/issues/56702
        // TODO(hterkelsen): https://github.com/flutter/flutter/issues/50770
        skip: browserEngine == BrowserEngine.edge ||
            browserEngine == BrowserEngine.webkit);
  });
}

bool _containsFontFamily(String family) {
  bool found = false;
  html.document.fonts!.forEach((html.FontFace fontFace,
      html.FontFace fontFaceAgain, html.FontFaceSet fontFaceSet) {
    if (fontFace.family == family) {
      found = true;
    }
  });
  return found;
}
