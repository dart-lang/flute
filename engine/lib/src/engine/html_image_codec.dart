// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

import 'package:ui/ui.dart' as ui;

import 'browser_detection.dart';
import 'util.dart';

Object? get _jsImageDecodeFunction => js_util.getProperty(
  // ignore: implicit_dynamic_function
  js_util.getProperty(
    // ignore: implicit_dynamic_function
    js_util.getProperty(html.window, 'Image') as Object,
    'prototype',
  ) as Object,
  'decode',
);
final bool _supportsDecode = _jsImageDecodeFunction != null;

typedef WebOnlyImageCodecChunkCallback = void Function(
    int cumulativeBytesLoaded, int expectedTotalBytes);

class HtmlCodec implements ui.Codec {
  final String src;
  final WebOnlyImageCodecChunkCallback? chunkCallback;

  HtmlCodec(this.src, {this.chunkCallback});

  @override
  int get frameCount => 1;

  @override
  int get repetitionCount => 0;

  @override
  Future<ui.FrameInfo> getNextFrame() async {
    final Completer<ui.FrameInfo> completer = Completer<ui.FrameInfo>();
    // Currently there is no way to watch decode progress, so
    // we add 0/100 , 100/100 progress callbacks to enable loading progress
    // builders to create UI.
      chunkCallback?.call(0, 100);
    if (_supportsDecode) {
      final html.ImageElement imgElement = html.ImageElement();
      imgElement.src = src;
      js_util.setProperty(imgElement, 'decoding', 'async');
      imgElement.decode().then((dynamic _) {
        chunkCallback?.call(100, 100);
        int naturalWidth = imgElement.naturalWidth;
        int naturalHeight = imgElement.naturalHeight;
        // Workaround for https://bugzilla.mozilla.org/show_bug.cgi?id=700533.
        if (naturalWidth == 0 && naturalHeight == 0 && (
            browserEngine == BrowserEngine.firefox ||
                browserEngine == BrowserEngine.ie11)) {
          const int kDefaultImageSizeFallback = 300;
          naturalWidth = kDefaultImageSizeFallback;
          naturalHeight = kDefaultImageSizeFallback;
        }
        final HtmlImage image = HtmlImage(
          imgElement,
          naturalWidth,
          naturalHeight,
        );
        completer.complete(SingleFrameInfo(image));
      }).catchError((dynamic e) {
        // This code path is hit on Chrome 80.0.3987.16 when too many
        // images are on the page (~1000).
        // Fallback here is to load using onLoad instead.
        _decodeUsingOnLoad(completer);
      });
    } else {
      _decodeUsingOnLoad(completer);
    }
    return completer.future;
  }

  void _decodeUsingOnLoad(Completer<ui.FrameInfo> completer) {
    StreamSubscription<html.Event>? loadSubscription;
    late StreamSubscription<html.Event> errorSubscription;
    final html.ImageElement imgElement = html.ImageElement();
    // If the browser doesn't support asynchronous decoding of an image,
    // then use the `onload` event to decide when it's ready to paint to the
    // DOM. Unfortunately, this will cause the image to be decoded synchronously
    // on the main thread, and may cause dropped framed.
    errorSubscription = imgElement.onError.listen((html.Event event) {
      loadSubscription?.cancel();
      errorSubscription.cancel();
      completer.completeError(event);
    });
    loadSubscription = imgElement.onLoad.listen((html.Event event) {
      if (chunkCallback != null) {
        chunkCallback!(100, 100);
      }
      loadSubscription!.cancel();
      errorSubscription.cancel();
      final HtmlImage image = HtmlImage(
        imgElement,
        imgElement.naturalWidth,
        imgElement.naturalHeight,
      );
      completer.complete(SingleFrameInfo(image));
    });
    imgElement.src = src;
  }

  @override
  void dispose() {}
}

class HtmlBlobCodec extends HtmlCodec {
  final html.Blob blob;

  HtmlBlobCodec(this.blob) : super(html.Url.createObjectUrlFromBlob(blob));

  @override
  void dispose() {
    html.Url.revokeObjectUrl(src);
  }
}

class SingleFrameInfo implements ui.FrameInfo {
  SingleFrameInfo(this.image);

  @override
  Duration get duration => const Duration(milliseconds: 0);

  @override
  final ui.Image image;
}

class HtmlImage implements ui.Image {
  final html.ImageElement imgElement;
  bool _requiresClone = false;
  HtmlImage(this.imgElement, this.width, this.height);

  bool _disposed = false;
  @override
  void dispose() {
    // Do nothing. The codec that owns this image should take care of
    // releasing the object url.
    if (assertionsEnabled) {
      _disposed = true;
    }
  }

  @override
  bool get debugDisposed {
    if (assertionsEnabled) {
      return _disposed;
    }
    return throw StateError('Image.debugDisposed is only available when asserts are enabled.');
  }


  @override
  ui.Image clone() => this;

  @override
  bool isCloneOf(ui.Image other) => other == this;

  @override
  List<StackTrace>? debugGetOpenHandleStackTraces() => null;

  @override
  final int width;

  @override
  final int height;

  @override
  Future<ByteData?> toByteData({ui.ImageByteFormat format = ui.ImageByteFormat.rawRgba}) {
    switch (format) {
      // TODO(ColdPaleLight): https://github.com/flutter/flutter/issues/89128
      // The format rawRgba always returns straight rather than premul currently.
      case ui.ImageByteFormat.rawRgba:
      case ui.ImageByteFormat.rawStraightRgba:
        final html.CanvasElement canvas = html.CanvasElement()
          ..width = width
          ..height = height;
        final html.CanvasRenderingContext2D ctx = canvas.context2D;
        ctx.drawImage(imgElement, 0, 0);
        final html.ImageData imageData = ctx.getImageData(0, 0, width, height);
        return Future<ByteData?>.value(imageData.data.buffer.asByteData());
      default:
        if (imgElement.src?.startsWith('data:') == true) {
          final UriData data = UriData.fromUri(Uri.parse(imgElement.src!));
          return Future<ByteData?>.value(data.contentAsBytes().buffer.asByteData());
        } else {
          return Future<ByteData?>.value(null);
        }
    }
  }

  // Returns absolutely positioned actual image element on first call and
  // clones on subsequent calls.
  html.ImageElement cloneImageElement() {
    if (_requiresClone) {
      return imgElement.clone(true) as html.ImageElement;
    } else {
      _requiresClone = true;
      imgElement.style.position = 'absolute';
      return imgElement;
    }
  }

  @override
  String toString() => '[$width\u00D7$height]';
}
