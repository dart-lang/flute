// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flute/ui.dart' show Size, hashValues;

import 'package:flute/foundation.dart';

/// Whether to replace all shadows with solid color blocks.
///
/// This is useful when writing golden file tests (see [matchesGoldenFile]) since
/// the rendering of shadows is not guaranteed to be pixel-for-pixel identical from
/// version to version (or even from run to run).
bool debugDisableShadows = false;

/// Called when the framework is about to paint an [Image] to a [Canvas] with an
/// [ImageSizeInfo] that contains the decoded size of the image as well as its
/// output size.
///
/// See: [debugOnPaintImage].
typedef PaintImageCallback = void Function(ImageSizeInfo);

/// Tracks the bytes used by a [dart:ui.Image] compared to the bytes needed to
/// paint that image without scaling it.
@immutable
class ImageSizeInfo {
  /// Creates an object to track the backing size of a [dart:ui.Image] compared
  /// to its display size on a [Canvas].
  ///
  /// This class is used by the framework when it paints an image to a canvas
  /// to report to `dart:developer`'s [postEvent], as well as to the
  /// [debugOnPaintImage] callback if it is set.
  const ImageSizeInfo({this.source, this.displaySize, required this.imageSize});

  /// A unique identifier for this image, for example its asset path or network
  /// URL.
  final String? source;

  /// The size of the area the image will be rendered in.
  final Size? displaySize;

  /// The size the image has been decoded to.
  final Size imageSize;

  /// The number of bytes needed to render the image without scaling it.
  int get displaySizeInBytes => _sizeToBytes(displaySize!);

  /// The number of bytes used by the image in memory.
  int get decodedSizeInBytes => _sizeToBytes(imageSize);

  int _sizeToBytes(Size size) {
    // Assume 4 bytes per pixel and that mipmapping will be used, which adds
    // 4/3.
    return (size.width * size.height * 4 * (4/3)).toInt();
  }

  /// Returns a JSON encodable representation of this object.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'source': source,
      if (displaySize != null)
        'displaySize': <String, Object?>{
          'width': displaySize!.width,
          'height': displaySize!.height,
        },
      'imageSize': <String, Object?>{
        'width': imageSize.width,
        'height': imageSize.height,
      },
      'displaySizeInBytes': displaySizeInBytes,
      'decodedSizeInBytes': decodedSizeInBytes,
    };
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ImageSizeInfo
        && other.source == source
        && other.imageSize == imageSize
        && other.displaySize == displaySize;
  }

  @override
  int get hashCode => hashValues(source, displaySize, imageSize);

  @override
  String toString() => 'ImageSizeInfo($source, imageSize: $imageSize, displaySize: $displaySize)';
}

/// If not null, called when the framework is about to paint an [Image] to a
/// [Canvas] with an [ImageSizeInfo] that contains the decoded size of the
/// image as well as its output size.
///
/// A test can use this callback to detect if images under test are being
/// rendered with the appropriate cache dimensions.
///
/// For example, if a 100x100 image is decoded it takes roughly 53kb in memory
/// (including mipmapping overhead). If it is only ever displayed at 50x50, it
/// would take only 13kb if the cacheHeight/cacheWidth parameters had been
/// specified at that size. This problem becomes more serious for larger
/// images, such as a high resolution image from a 12MP camera, which would be
/// 64mb when decoded.
///
/// When using this callback, developers should consider whether the image will
/// be panned or scaled up in the application, how many images are being
/// displayed, and whether the application will run on multiple devices with
/// different resolutions and memory capacities. For example, it should be fine
/// to have an image that animates from thumbnail size to full screen be at
/// a higher resolution while animating, but it would be problematic to have
/// a grid or list of such thumbnails all be at the full resolution at the same
/// time.
PaintImageCallback? debugOnPaintImage;

/// If true, the framework will color invert and horizontally flip images that
/// have been decoded to a size taking at least [debugImageOverheadAllowance]
/// bytes more than necessary.
///
/// It will also call [FlutterError.reportError] with information about the
/// image's decoded size and its display size, which can be used resize the
/// asset before shipping it, apply `cacheHeight` or `cacheWidth` parameters, or
/// directly use a [ResizeImage]. Whenever possible, resizing the image asset
/// itself should be preferred, to avoid unnecessary network traffic, disk space
/// usage, and other memory overhead incurred during decoding.
///
/// Developers using this flag should test their application on appropriate
/// devices and display sizes for their expected deployment targets when using
/// these parameters. For example, an application that responsively resizes
/// images for a desktop and mobile layout should avoid decoding all images at
/// sizes appropriate for mobile when on desktop. Applications should also avoid
/// animating these parameters, as each change will result in a newly decoded
/// image. For example, an image that always grows into view should decode only
/// at its largest size, whereas an image that normally is a thumbnail and then
/// pops into view should be decoded at its smallest size for the thumbnail and
/// the largest size when needed.
///
/// This has no effect unless asserts are enabled.
bool debugInvertOversizedImages = false;

/// The number of bytes an image must use before it triggers inversion when
/// [debugInvertOversizedImages] is true.
///
/// Default is 1024 (1kb).
int debugImageOverheadAllowance = 1024;

/// Returns true if none of the painting library debug variables have been changed.
///
/// This function is used by the test framework to ensure that debug variables
/// haven't been inadvertently changed.
///
/// See [the painting library](painting/painting-library.html) for a complete
/// list.
///
/// The `debugDisableShadowsOverride` argument can be provided to override
/// the expected value for [debugDisableShadows]. (This exists because the
/// test framework itself overrides this value in some cases.)
bool debugAssertAllPaintingVarsUnset(String reason, { bool debugDisableShadowsOverride = false }) {
  assert(() {
    if (debugDisableShadows != debugDisableShadowsOverride ||
        debugOnPaintImage != null ||
        debugInvertOversizedImages == true ||
        debugImageOverheadAllowance != 1024) {
      throw FlutterError(reason);
    }
    return true;
  }());
  return true;
}
