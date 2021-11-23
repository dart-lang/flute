// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:test/bootstrap/browser.dart';
import 'package:test/test.dart';
import 'package:ui/src/engine.dart';
import 'package:ui/ui.dart' as ui;
import 'package:web_engine_tester/golden_tester.dart';

import '../matchers.dart';
import 'common.dart';
import 'test_data.dart';

void main() {
  internalBootstrapBrowserTest(() => testMain);
}

void testMain() {
  group('CanvasKit Images', () {
    setUpCanvasKitTest();

    tearDown(() {
      debugRestoreHttpRequestFactory();
    });

    _testForImageCodecs(useBrowserImageDecoder: false);

    if (browserSupportsImageDecoder) {
      _testForImageCodecs(useBrowserImageDecoder: true);
    }

    test('isAvif', () {
      expect(isAvif(Uint8List.fromList(<int>[])), isFalse);
      expect(isAvif(Uint8List.fromList(<int>[1, 2, 3])), isFalse);
      expect(
        isAvif(Uint8List.fromList(<int>[
          0x00, 0x00, 0x00, 0x1c, 0x66, 0x74, 0x79, 0x70,
          0x61, 0x76, 0x69, 0x66, 0x00, 0x00, 0x00, 0x00,
        ])),
        isTrue,
      );
      expect(
        isAvif(Uint8List.fromList(<int>[
          0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70,
          0x61, 0x76, 0x69, 0x66, 0x00, 0x00, 0x00, 0x00,
        ])),
        isTrue,
      );
    });
  // TODO(hterkelsen): https://github.com/flutter/flutter/issues/60040
  }, skip: isIosSafari);
}

void _testForImageCodecs({required bool useBrowserImageDecoder}) {
  final String mode = useBrowserImageDecoder ? 'webcodecs' : 'wasm';

  group('($mode})', () {
    setUp(() {
      browserSupportsImageDecoder = useBrowserImageDecoder;
    });

    tearDown(() {
      debugResetBrowserSupportsImageDecoder();
    });

    test('CkAnimatedImage can be explicitly disposed of', () {
      final CkAnimatedImage image = CkAnimatedImage.decodeFromBytes(kTransparentImage, 'test');
      expect(image.debugDisposed, isFalse);
      image.dispose();
      expect(image.debugDisposed, isTrue);

      // Disallow usage after disposal
      expect(() => image.frameCount, throwsAssertionError);
      expect(() => image.repetitionCount, throwsAssertionError);
      expect(() => image.getNextFrame(), throwsAssertionError);

      // Disallow double-dispose.
      expect(() => image.dispose(), throwsAssertionError);
      testCollector.collectNow();
    });

    test('CkAnimatedImage remembers last animation position after resurrection', () async {
      browserSupportsFinalizationRegistry = false;

      Future<void> expectFrameData(ui.FrameInfo frame, List<int> data) async {
        final ByteData frameData = (await frame.image.toByteData())!;
        expect(frameData.buffer.asUint8List(), Uint8List.fromList(data));
      }

      final CkAnimatedImage image = CkAnimatedImage.decodeFromBytes(kAnimatedGif, 'test');
      expect(image.frameCount, 3);
      expect(image.repetitionCount, -1);

      final ui.FrameInfo frame1 = await image.getNextFrame();
      expectFrameData(frame1, <int>[0, 255, 0, 255]);
      final ui.FrameInfo frame2 = await image.getNextFrame();
      expectFrameData(frame2, <int>[0, 0, 255, 255]);

      // Pretend that the image is temporarily deleted.
      image.delete();
      image.didDelete();

      // Check that we got the 3rd frame after resurrection.
      final ui.FrameInfo frame3 = await image.getNextFrame();
      expectFrameData(frame3, <int>[255, 0, 0, 255]);

      testCollector.collectNow();
    });

    test('CkImage toString', () {
      final SkImage skImage =
          canvasKit.MakeAnimatedImageFromEncoded(kTransparentImage)!
              .makeImageAtCurrentFrame();
      final CkImage image = CkImage(skImage);
      expect(image.toString(), '[1×1]');
      image.dispose();
      testCollector.collectNow();
    });

    test('CkImage can be explicitly disposed of', () {
      final SkImage skImage =
          canvasKit.MakeAnimatedImageFromEncoded(kTransparentImage)!
              .makeImageAtCurrentFrame();
      final CkImage image = CkImage(skImage);
      expect(image.debugDisposed, isFalse);
      expect(image.box.isDeletedPermanently, isFalse);
      image.dispose();
      expect(image.debugDisposed, isTrue);
      expect(image.box.isDeletedPermanently, isTrue);

      // Disallow double-dispose.
      expect(() => image.dispose(), throwsAssertionError);
      testCollector.collectNow();
    });

    test('CkImage can be explicitly disposed of when cloned', () async {
      final SkImage skImage =
          canvasKit.MakeAnimatedImageFromEncoded(kTransparentImage)!
              .makeImageAtCurrentFrame();
      final CkImage image = CkImage(skImage);
      final SkiaObjectBox<CkImage, SkImage> box = image.box;
      expect(box.refCount, 1);
      expect(box.debugGetStackTraces().length, 1);

      final CkImage clone = image.clone();
      expect(box.refCount, 2);
      expect(box.debugGetStackTraces().length, 2);

      expect(image.isCloneOf(clone), isTrue);
      expect(box.isDeletedPermanently, isFalse);

      testCollector.collectNow();
      expect(skImage.isDeleted(), isFalse);
      image.dispose();
      expect(box.refCount, 1);
      expect(box.isDeletedPermanently, isFalse);

      testCollector.collectNow();
      expect(skImage.isDeleted(), isFalse);
      clone.dispose();
      expect(box.refCount, 0);
      expect(box.isDeletedPermanently, isTrue);

      testCollector.collectNow();
      expect(skImage.isDeleted(), isTrue);
      expect(box.debugGetStackTraces().length, 0);
      testCollector.collectNow();
    });

    test('CkImage toByteData', () async {
      final SkImage skImage =
          canvasKit.MakeAnimatedImageFromEncoded(kTransparentImage)!
              .makeImageAtCurrentFrame();
      final CkImage image = CkImage(skImage);
      expect((await image.toByteData()).lengthInBytes, greaterThan(0));
      expect((await image.toByteData(format: ui.ImageByteFormat.png)).lengthInBytes, greaterThan(0));
      testCollector.collectNow();
    });

    // Regression test for https://github.com/flutter/flutter/issues/72469
    test('CkImage can be resurrected', () {
      browserSupportsFinalizationRegistry = false;
      final SkImage skImage =
          canvasKit.MakeAnimatedImageFromEncoded(kTransparentImage)!
              .makeImageAtCurrentFrame();
      final CkImage image = CkImage(skImage);
      expect(image.box.rawSkiaObject, isNotNull);

      // Pretend that the image is temporarily deleted.
      image.box.delete();
      image.box.didDelete();
      expect(image.box.rawSkiaObject, isNull);

      // Attempting to access the skia object here would previously throw
      // "Stack Overflow" in Safari.
      expect(image.box.skiaObject, isNotNull);
      testCollector.collectNow();
    });

    test('skiaInstantiateWebImageCodec loads an image from the network',
        () async {
      httpRequestFactory = () {
        return TestHttpRequest()
          ..status = 200
          ..onLoad = Stream<html.ProgressEvent>.fromIterable(<html.ProgressEvent>[
            html.ProgressEvent('test progress event'),
          ])
          ..response = kTransparentImage.buffer;
      };
      final ui.Codec codec = await skiaInstantiateWebImageCodec('http://image-server.com/picture.jpg', null);
      expect(codec.frameCount, 1);
      final ui.Image image = (await codec.getNextFrame()).image;
      expect(image.height, 1);
      expect(image.width, 1);
      testCollector.collectNow();
    });

    test('instantiateImageCodec respects target image size',
        () async {
      const List<List<int>> targetSizes = <List<int>>[
        <int>[1, 1],
        <int>[1, 2],
        <int>[2, 3],
        <int>[3, 4],
        <int>[4, 4],
        <int>[10, 20],
      ];

      for (final List<int> targetSize in targetSizes) {
        final int targetWidth = targetSize[0];
        final int targetHeight = targetSize[1];

        final ui.Codec codec = await ui.instantiateImageCodec(
          k4x4PngImage,
          targetWidth: targetWidth,
          targetHeight: targetHeight,
        );

        final ui.Image image = (await codec.getNextFrame()).image;
        // TODO(yjbanov): https://github.com/flutter/flutter/issues/34075
        // expect(image.width, targetWidth);
        // expect(image.height, targetHeight);
        image.dispose();
        codec.dispose();
      }

      testCollector.collectNow();
    });

    test('skiaInstantiateWebImageCodec throws exception on request error',
        () async {
      httpRequestFactory = () {
        return TestHttpRequest()
          ..onError = Stream<html.ProgressEvent>.fromIterable(<html.ProgressEvent>[
            html.ProgressEvent('test error'),
          ]);
      };
      try {
        await skiaInstantiateWebImageCodec('url-does-not-matter', null);
        fail('Expected to throw');
      } on ImageCodecException catch (exception) {
        expect(
          exception.toString(),
          'ImageCodecException: Failed to load network image.\n'
          'Image URL: url-does-not-matter\n'
          'Trying to load an image from another domain? Find answers at:\n'
          'https://flutter.dev/docs/development/platform-integration/web-images',
        );
      }
      testCollector.collectNow();
    });

    test('skiaInstantiateWebImageCodec throws exception on HTTP error',
        () async {
      try {
        await skiaInstantiateWebImageCodec('/does-not-exist.jpg', null);
        fail('Expected to throw');
      } on ImageCodecException catch (exception) {
        expect(
          exception.toString(),
          'ImageCodecException: Failed to load network image.\n'
          'Image URL: /does-not-exist.jpg\n'
          'Server response code: 404',
        );
      }
      testCollector.collectNow();
    });

    test('skiaInstantiateWebImageCodec includes URL in the error for malformed image',
        () async {
      httpRequestFactory = () {
        return TestHttpRequest()
          ..status = 200
          ..onLoad = Stream<html.ProgressEvent>.fromIterable(<html.ProgressEvent>[
            html.ProgressEvent('test progress event'),
          ])
          ..response = Uint8List(0).buffer;
      };
      try {
        await skiaInstantiateWebImageCodec('http://image-server.com/picture.jpg', null);
        fail('Expected to throw');
      } on ImageCodecException catch (exception) {
        if (!browserSupportsImageDecoder) {
          expect(
            exception.toString(),
            'ImageCodecException: Failed to decode image data.\n'
            'Image source: http://image-server.com/picture.jpg',
          );
        } else {
          expect(
            exception.toString(),
            'ImageCodecException: Failed to detect image file format using the file header.\n'
            'File header was empty.\n'
            'Image source: http://image-server.com/picture.jpg',
          );
        }
      }
      testCollector.collectNow();
    });

    test('Reports error when failing to decode empty image data', () async {
      try {
        await ui.instantiateImageCodec(Uint8List(0));
        fail('Expected to throw');
      } on ImageCodecException catch (exception) {
        if (!browserSupportsImageDecoder) {
          expect(
            exception.toString(),
            'ImageCodecException: Failed to decode image data.\n'
            'Image source: encoded image bytes',
          );
        } else {
          expect(
            exception.toString(),
            'ImageCodecException: Failed to detect image file format using the file header.\n'
            'File header was empty.\n'
            'Image source: encoded image bytes',
          );
        }
      }
    });

    test('Reports error when failing to decode malformed image data', () async {
      try {
        await ui.instantiateImageCodec(Uint8List.fromList(<int>[
          0xFF, 0xD8, 0xFF, 0xDB, 0x00, 0x00, 0x00,
        ]));
        fail('Expected to throw');
      } on ImageCodecException catch (exception) {
        if (!browserSupportsImageDecoder) {
          expect(
            exception.toString(),
            'ImageCodecException: Failed to decode image data.\n'
            'Image source: encoded image bytes'
          );
        } else {
          expect(
            exception.toString(),
            // Browser error message is not checked as it can depend on the
            // browser engine and version.
            matches(RegExp(
              r"ImageCodecException: Failed to decode image using the browser's ImageDecoder API.\n"
              r'Image source: encoded image bytes\n'
              r'Original browser error: .+'
            ))
          );
        }
      }
    });

    test('Includes file header in the error message when fails to detect file type', () async {
      try {
        await ui.instantiateImageCodec(Uint8List.fromList(<int>[
          0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x00,
        ]));
        fail('Expected to throw');
      } on ImageCodecException catch (exception) {
        if (!browserSupportsImageDecoder) {
          expect(
            exception.toString(),
            'ImageCodecException: Failed to decode image data.\n'
            'Image source: encoded image bytes'
          );
        } else {
          expect(
            exception.toString(),
            'ImageCodecException: Failed to detect image file format using the file header.\n'
            'File header was [0x01 0x02 0x03 0x04 0x05 0x06 0x07 0x08 0x09 0x00].\n'
            'Image source: encoded image bytes'
          );
        }
      }
    });

    test('Provides readable error message when image type is unsupported', () async {
      addTearDown(() {
        debugContentTypeDetector = null;
      });
      debugContentTypeDetector = (_) {
        return 'unsupported/image-type';
      };
      try {
        await ui.instantiateImageCodec(Uint8List.fromList(<int>[
          0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x00,
        ]));
        fail('Expected to throw');
      } on ImageCodecException catch (exception) {
        if (!browserSupportsImageDecoder) {
          expect(
            exception.toString(),
            'ImageCodecException: Failed to decode image data.\n'
            'Image source: encoded image bytes'
          );
        } else {
          expect(
            exception.toString(),
            'ImageCodecException: Image file format (unsupported/image-type) is not supported by this browser\'s ImageDecoder API.\n'
            'Image source: encoded image bytes'
          );
        }
      }
    });

    test('decodeImageFromPixels', () async {
      Future<ui.Image> _testDecodeFromPixels(int width, int height) async {
        final Completer<ui.Image> completer = Completer<ui.Image>();
        ui.decodeImageFromPixels(
          Uint8List.fromList(List<int>.filled(width * height * 4, 0, growable: false)),
          width,
          height,
          ui.PixelFormat.rgba8888,
          (ui.Image image) {
            completer.complete(image);
          },
        );
        return completer.future;
      }

      final ui.Image image1 = await _testDecodeFromPixels(10, 20);
      expect(image1, isNotNull);
      expect(image1.width, 10);
      expect(image1.height, 20);

      final ui.Image image2 = await _testDecodeFromPixels(40, 100);
      expect(image2, isNotNull);
      expect(image2.width, 40);
      expect(image2.height, 100);
    });

    test('Decode test images', () async {
      final html.Body listingResponse = await httpFetch('/test_images/');
      final List<String> testFiles = (await listingResponse.json() as List<dynamic>).cast<String>();

      // Sanity-check the test file list. If suddenly test files are moved or
      // deleted, and the test server returns an empty list, or is missing some
      // important test files, we want to know.
      expect(testFiles, isNotEmpty);
      expect(testFiles, contains(matches(RegExp(r'.*\.jpg'))));
      expect(testFiles, contains(matches(RegExp(r'.*\.png'))));
      expect(testFiles, contains(matches(RegExp(r'.*\.gif'))));
      expect(testFiles, contains(matches(RegExp(r'.*\.webp'))));
      expect(testFiles, contains(matches(RegExp(r'.*\.bmp'))));

      for (final String testFile in testFiles) {
        final html.Body imageResponse = await httpFetch('/test_images/$testFile');
        final Uint8List imageData = (await imageResponse.arrayBuffer() as ByteBuffer).asUint8List();
        final ui.Codec codec = await skiaInstantiateImageCodec(imageData);
        expect(codec.frameCount, greaterThan(0));
        expect(codec.repetitionCount, isNotNull);
        for (int i = 0; i < codec.frameCount; i++) {
          final ui.FrameInfo frame = await codec.getNextFrame();
          expect(frame.duration, isNotNull);
          expect(frame.image, isNotNull);
        }
        codec.dispose();
      }
    });

    // This is a regression test for the issues with transferring textures from
    // one GL context to another, such as:
    //
    //  * https://github.com/flutter/flutter/issues/86809
    //  * https://github.com/flutter/flutter/issues/91881
    test('the same image can be rendered on difference surfaces', () async {
      ui.platformViewRegistry.registerViewFactory(
        'test-platform-view',
        (int viewId) => html.DivElement()..id = 'view-0',
      );
      await createPlatformView(0, 'test-platform-view');

      final EnginePlatformDispatcher dispatcher =
          ui.window.platformDispatcher as EnginePlatformDispatcher;

      final ui.Codec codec = await ui.instantiateImageCodec(k4x4PngImage);
      final CkImage image = (await codec.getNextFrame()).image as CkImage;

      final LayerSceneBuilder sb = LayerSceneBuilder();
      sb.pushOffset(4, 4);
      {
        final CkPictureRecorder recorder = CkPictureRecorder();
        final CkCanvas canvas = recorder.beginRecording(ui.Rect.largest);
        canvas.save();
        canvas.scale(16, 16);
        canvas.drawImage(image, ui.Offset.zero, CkPaint());
        canvas.restore();
        canvas.drawParagraph(makeSimpleText('1'), const ui.Offset(4, 4));
        sb.addPicture(ui.Offset.zero, recorder.endRecording());
      }
      sb.addPlatformView(0, width: 100, height: 100);
      sb.pushOffset(20, 20);
      {
        final CkPictureRecorder recorder = CkPictureRecorder();
        final CkCanvas canvas = recorder.beginRecording(ui.Rect.largest);
        canvas.save();
        canvas.scale(16, 16);
        canvas.drawImage(image, ui.Offset.zero, CkPaint());
        canvas.restore();
        canvas.drawParagraph(makeSimpleText('2'), const ui.Offset(2, 2));
        sb.addPicture(ui.Offset.zero, recorder.endRecording());
      }
      dispatcher.rasterizer!.draw(sb.build().layerTree);
      await matchGoldenFile(
        'canvaskit_cross_gl_context_image_$mode.png',
        region: const ui.Rect.fromLTRB(0, 0, 100, 100),
        maxDiffRatePercent: 0,
      );

      await disposePlatformView(0);
    });
  });
}

class TestHttpRequest implements html.HttpRequest {
  @override
  String responseType = 'invalid';

  @override
  int? timeout = 10;

  @override
  bool? withCredentials = false;

  @override
  void abort() {
    throw UnimplementedError();
  }

  @override
  void addEventListener(String type, html.EventListener? listener, [bool? useCapture]) {
    throw UnimplementedError();
  }

  @override
  bool dispatchEvent(html.Event event) {
    throw UnimplementedError();
  }

  @override
  String getAllResponseHeaders() {
    throw UnimplementedError();
  }

  @override
  String getResponseHeader(String name) {
    throw UnimplementedError();
  }

  @override
  html.Events get on => throw UnimplementedError();

  @override
  Stream<html.ProgressEvent> get onAbort => throw UnimplementedError();

  @override
  Stream<html.ProgressEvent> onError = Stream<html.ProgressEvent>.fromIterable(<html.ProgressEvent>[]);

  @override
  Stream<html.ProgressEvent> onLoad = Stream<html.ProgressEvent>.fromIterable(<html.ProgressEvent>[]);

  @override
  Stream<html.ProgressEvent> get onLoadEnd => throw UnimplementedError();

  @override
  Stream<html.ProgressEvent> get onLoadStart => throw UnimplementedError();

  @override
  Stream<html.ProgressEvent> get onProgress => throw UnimplementedError();

  @override
  Stream<html.Event> get onReadyStateChange => throw UnimplementedError();

  @override
  Stream<html.ProgressEvent> get onTimeout => throw UnimplementedError();

  @override
  void open(String method, String url, {bool? async, String? user, String? password}) {}

  @override
  void overrideMimeType(String mime) {
    throw UnimplementedError();
  }

  @override
  int get readyState => throw UnimplementedError();

  @override
  void removeEventListener(String type, html.EventListener? listener, [bool? useCapture]) {
    throw UnimplementedError();
  }

  @override
  dynamic response;

  @override
  Map<String, String> get responseHeaders => throw UnimplementedError();

  @override
  String get responseText => throw UnimplementedError();

  @override
  String get responseUrl => throw UnimplementedError();

  @override
  html.Document get responseXml => throw UnimplementedError();

  @override
  void send([dynamic bodyOrData]) {
  }

  @override
  void setRequestHeader(String name, String value) {
    throw UnimplementedError();
  }

  @override
  int status = -1;

  @override
  String get statusText => throw UnimplementedError();

  @override
  html.HttpRequestUpload get upload => throw UnimplementedError();
}
