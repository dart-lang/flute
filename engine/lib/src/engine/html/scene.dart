// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html' as html;

import 'package:ui/ui.dart' as ui;

import '../vector_math.dart';
import 'surface.dart';

class SurfaceScene implements ui.Scene {
  /// This class is created by the engine, and should not be instantiated
  /// or extended directly.
  ///
  /// To create a Scene object, use a [SceneBuilder].
  SurfaceScene(this.webOnlyRootElement);

  final html.Element? webOnlyRootElement;

  /// Creates a raster image representation of the current state of the scene.
  /// This is a slow operation that is performed on a background thread.
  @override
  Future<ui.Image> toImage(int width, int height) {
    throw UnsupportedError('toImage is not supported on the Web');
  }

  /// Releases the resources used by this scene.
  ///
  /// After calling this function, the scene is cannot be used further.
  @override
  void dispose() {}
}

/// A surface that creates a DOM element for whole app.
class PersistedScene extends PersistedContainerSurface {
  PersistedScene(PersistedScene? oldLayer) : super(oldLayer) {
    transform = Matrix4.identity();
  }

  @override
  void recomputeTransformAndClip() {
    // The scene clip is the size of the entire window.
    // TODO(yjbanov): in the add2app scenario where we might be hosted inside
    //                a custom element, this will be different. We will need to
    //                update this code when we add add2app support.
    final double screenWidth = html.window.innerWidth!.toDouble();
    final double screenHeight = html.window.innerHeight!.toDouble();
    localClipBounds = ui.Rect.fromLTRB(0, 0, screenWidth, screenHeight);
    projectedClip = null;
  }

  /// Cached inverse of transform on this node. Unlike transform, this
  /// Matrix only contains local transform (not chain multiplied since root).
  Matrix4? _localTransformInverse;

  @override
  Matrix4? get localTransformInverse =>
      _localTransformInverse ??= Matrix4.identity();

  @override
  html.Element createElement() {
    return defaultCreateElement('flt-scene');
  }

  @override
  void apply() {}
}
