// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html' as html;

import 'package:ui/ui.dart' as ui;

import '../browser_detection.dart';
import '../configuration.dart';
import '../platform_dispatcher.dart';
import '../util.dart';
import '../window.dart';
import 'canvas.dart';
import 'canvaskit_api.dart';
import 'initialization.dart';
import 'surface_factory.dart';
import 'util.dart';

typedef SubmitCallback = bool Function(SurfaceFrame, CkCanvas);

/// A frame which contains a canvas to be drawn into.
class SurfaceFrame {
  final CkSurface skiaSurface;
  final SubmitCallback submitCallback;
  bool _submitted;

  SurfaceFrame(this.skiaSurface, this.submitCallback)
      : _submitted = false,
        assert(skiaSurface != null), // ignore: unnecessary_null_comparison
        assert(submitCallback != null); // ignore: unnecessary_null_comparison

  /// Submit this frame to be drawn.
  bool submit() {
    if (_submitted) {
      return false;
    }
    return submitCallback(this, skiaCanvas);
  }

  CkCanvas get skiaCanvas => skiaSurface.getCanvas();
}

/// A surface which can be drawn into by the compositor.
///
/// The underlying representation is a [CkSurface], which can be reused by
/// successive frames if they are the same size. Otherwise, a new [CkSurface] is
/// created.
class Surface {
  Surface();

  CkSurface? _surface;

  /// If true, forces a new WebGL context to be created, even if the window
  /// size is the same. This is used to restore the UI after the browser tab
  /// goes dormant and loses the GL context.
  bool _forceNewContext = true;
  bool get debugForceNewContext => _forceNewContext;

  bool _contextLost = false;
  bool get debugContextLost => _contextLost;

  /// A cached copy of the most recently created `webglcontextlost` listener.
  ///
  /// We must cache this function because each time we access the tear-off it
  /// creates a new object, meaning we won't be able to remove this listener
  /// later.
  void Function(html.Event)? _cachedContextLostListener;

  /// A cached copy of the most recently created `webglcontextrestored`
  /// listener.
  ///
  /// We must cache this function because each time we access the tear-off it
  /// creates a new object, meaning we won't be able to remove this listener
  /// later.
  void Function(html.Event)? _cachedContextRestoredListener;

  SkGrContext? _grContext;
  int? _glContext;
  int? _skiaCacheBytes;

  /// The root HTML element for this surface.
  ///
  /// This element contains the canvas used to draw the UI. Unlike the canvas,
  /// this element is permanent. It is never replaced or deleted, until this
  /// surface is disposed of via [dispose].
  ///
  /// Conversely, the canvas that lives inside this element can be swapped, for
  /// example, when the screen size changes, or when the WebGL context is lost
  /// due to the browser tab becoming dormant.
  final html.Element htmlElement = html.Element.tag('flt-canvas-container');

  /// The underlying `<canvas>` element used for this surface.
  html.CanvasElement? htmlCanvas;
  int _pixelWidth = -1;
  int _pixelHeight = -1;

  /// Specify the GPU resource cache limits.
  void setSkiaResourceCacheMaxBytes(int bytes) {
    _skiaCacheBytes = bytes;
    _syncCacheBytes();
  }

  void _syncCacheBytes() {
    if (_skiaCacheBytes != null) {
      _grContext?.setResourceCacheLimitBytes(_skiaCacheBytes!);
    }
  }

  bool _addedToScene = false;

  /// Acquire a frame of the given [size] containing a drawable canvas.
  ///
  /// The given [size] is in physical pixels.
  SurfaceFrame acquireFrame(ui.Size size) {
    final CkSurface surface = createOrUpdateSurface(size);

    // ignore: prefer_function_declarations_over_variables
    final SubmitCallback submitCallback =
        (SurfaceFrame surfaceFrame, CkCanvas canvas) {
      return _presentSurface();
    };

    return SurfaceFrame(surface, submitCallback);
  }

  void addToScene() {
    if (!_addedToScene) {
      skiaSceneHost!.children.insert(0, htmlElement);
    }
    _addedToScene = true;
  }

  ui.Size? _currentCanvasPhysicalSize;
  ui.Size? _currentSurfaceSize;
  double _currentDevicePixelRatio = -1;

  /// Creates a <canvas> and SkSurface for the given [size].
  CkSurface createOrUpdateSurface(ui.Size size) {
    if (size.isEmpty) {
      throw CanvasKitError('Cannot create surfaces of empty size.');
    }

    // Check if the window is the same size as before, and if so, don't allocate
    // a new canvas as the previous canvas is big enough to fit everything.
    final ui.Size? previousSurfaceSize = _currentSurfaceSize;
    if (!_forceNewContext &&
        previousSurfaceSize != null &&
        size.width == previousSurfaceSize.width &&
        size.height == previousSurfaceSize.height) {
      // The existing surface is still reusable.
      if (window.devicePixelRatio != _currentDevicePixelRatio) {
        _updateLogicalHtmlCanvasSize();
      }
      return _surface!;
    }

    _currentDevicePixelRatio = window.devicePixelRatio;

    // If the current canvas size is smaller than the requested size then create
    // a new, larger, canvas. Then update the GR context so we can create a new
    // SkSurface.
    final ui.Size? previousCanvasSize = _currentCanvasPhysicalSize;
    if (_forceNewContext ||
        previousCanvasSize == null ||
        size.width > previousCanvasSize.width ||
        size.height > previousCanvasSize.height) {
      // Initialize a new, larger, canvas. If the size is growing, then make the
      // new canvas larger than required to avoid many canvas creations.
      final ui.Size newSize = previousCanvasSize == null ? size : size * 1.4;

      _surface?.dispose();
      _surface = null;
      _addedToScene = false;
      _grContext?.releaseResourcesAndAbandonContext();
      _grContext?.delete();
      _grContext = null;

      _createNewCanvas(newSize);
      _currentCanvasPhysicalSize = newSize;
    }

    _currentSurfaceSize = size;
    _translateCanvas();
    return _surface = _createNewSurface(size);
  }

  /// Sets the CSS size of the canvas so that canvas pixels are 1:1 with device
  /// pixels.
  ///
  /// The logical size of the canvas is not based on the size of the window
  /// but on the size of the canvas, which, due to `ceil()` above, may not be
  /// the same as the window. We do not round/floor/ceil the logical size as
  /// CSS pixels can contain more than one physical pixel and therefore to
  /// match the size of the window precisely we use the most precise floating
  /// point value we can get.
  void _updateLogicalHtmlCanvasSize() {
    final double logicalWidth = _pixelWidth / window.devicePixelRatio;
    final double logicalHeight = _pixelHeight / window.devicePixelRatio;
    htmlCanvas!.style
      ..width = '${logicalWidth}px'
      ..height = '${logicalHeight}px';
  }

  /// Translate the canvas so the surface covers the visible portion of the
  /// screen.
  ///
  /// The <canvas> may be larger than the visible screen, but the SkSurface is
  /// exactly the size of the visible screen. Unfortunately, the SkSurface is
  /// drawn in the lower left corner of the <canvas>, and without translation,
  /// only the top left of the <canvas> is visible. So we shift the canvas up so
  /// the bottom left corner is visible.
  void _translateCanvas() {
    final int surfaceHeight = _currentSurfaceSize!.height.ceil();
    final double offset =
        (_pixelHeight - surfaceHeight) / window.devicePixelRatio;
    htmlCanvas!.style.transform = 'translate(0, -${offset}px)';
  }

  void _contextRestoredListener(html.Event event) {
    assert(
        _contextLost,
        'Received "webglcontextrestored" event but never received '
        'a "webglcontextlost" event.');
    _contextLost = false;
    // Force the framework to rerender the frame.
    EnginePlatformDispatcher.instance.invokeOnMetricsChanged();
    event.stopPropagation();
    event.preventDefault();
  }

  void _contextLostListener(html.Event event) {
    assert(event.target == htmlCanvas,
        'Received a context lost event for a disposed canvas');
    final SurfaceFactory factory = SurfaceFactory.instance;
    _contextLost = true;
    if (factory.isLive(this)) {
      _forceNewContext = true;
      event.preventDefault();
    } else {
      dispose();
    }
  }

  /// This function is expensive.
  ///
  /// It's better to reuse canvas if possible.
  void _createNewCanvas(ui.Size physicalSize) {
    // Clear the container, if it's not empty. We're going to create a new <canvas>.
    if (this.htmlCanvas != null) {
      this.htmlCanvas!.removeEventListener(
            'webglcontextrestored',
            _cachedContextRestoredListener,
            false,
          );
      this.htmlCanvas!.removeEventListener(
            'webglcontextlost',
            _cachedContextLostListener,
            false,
          );
      this.htmlCanvas!.remove();
      _cachedContextRestoredListener = null;
      _cachedContextLostListener = null;
    }

    // If `physicalSize` is not precise, use a slightly bigger canvas. This way
    // we ensure that the rendred picture covers the entire browser window.
    _pixelWidth = physicalSize.width.ceil();
    _pixelHeight = physicalSize.height.ceil();
    final html.CanvasElement htmlCanvas = html.CanvasElement(
      width: _pixelWidth,
      height: _pixelHeight,
    );
    this.htmlCanvas = htmlCanvas;
    htmlCanvas.style.position = 'absolute';
    _updateLogicalHtmlCanvasSize();

    // When the browser tab using WebGL goes dormant the browser and/or OS may
    // decide to clear GPU resources to let other tabs/programs use the GPU.
    // When this happens, the browser sends the "webglcontextlost" event as a
    // notification. When we receive this notification we force a new context.
    //
    // See also: https://www.khronos.org/webgl/wiki/HandlingContextLost
    _cachedContextRestoredListener = _contextRestoredListener;
    _cachedContextLostListener = _contextLostListener;
    htmlCanvas.addEventListener(
      'webglcontextlost',
      _cachedContextLostListener,
      false,
    );
    htmlCanvas.addEventListener(
      'webglcontextrestored',
      _cachedContextRestoredListener,
      false,
    );
    _forceNewContext = false;
    _contextLost = false;

    if (webGLVersion != -1 && !configuration.canvasKitForceCpuOnly) {
      final int glContext = canvasKit.GetWebGLContext(
        htmlCanvas,
        SkWebGLContextOptions(
          // Default to no anti-aliasing. Paint commands can be explicitly
          // anti-aliased by setting their `Paint` object's `antialias` property.
          antialias: 0,
          majorVersion: webGLVersion,
        ),
      );

      _glContext = glContext;

      if (_glContext != 0) {
        _grContext = canvasKit.MakeGrContext(glContext);
        if (_grContext == null) {
          throw CanvasKitError('Failed to initialize CanvasKit. '
              'CanvasKit.MakeGrContext returned null.');
        }
        // Set the cache byte limit for this grContext, if not specified it will
        // use CanvasKit's default.
        _syncCacheBytes();
      }
    }

    htmlElement.append(htmlCanvas);
  }

  CkSurface _createNewSurface(ui.Size size) {
    assert(htmlCanvas != null);
    if (webGLVersion == -1) {
      return _makeSoftwareCanvasSurface(
          htmlCanvas!, 'WebGL support not detected');
    } else if (configuration.canvasKitForceCpuOnly) {
      return _makeSoftwareCanvasSurface(
          htmlCanvas!, 'CPU rendering forced by application');
    } else if (_glContext == 0) {
      return _makeSoftwareCanvasSurface(
          htmlCanvas!, 'Failed to initialize WebGL context');
    } else {
      final SkSurface? skSurface = canvasKit.MakeOnScreenGLSurface(
        _grContext!,
        size.width.ceil(),
        size.height.ceil(),
        SkColorSpaceSRGB,
      );

      if (skSurface == null) {
        return _makeSoftwareCanvasSurface(
            htmlCanvas!, 'Failed to initialize WebGL surface');
      }

      return CkSurface(skSurface, _glContext);
    }
  }

  static bool _didWarnAboutWebGlInitializationFailure = false;

  CkSurface _makeSoftwareCanvasSurface(
      html.CanvasElement htmlCanvas, String reason) {
    if (!_didWarnAboutWebGlInitializationFailure) {
      printWarning('WARNING: Falling back to CPU-only rendering. $reason.');
      _didWarnAboutWebGlInitializationFailure = true;
    }
    return CkSurface(
      canvasKit.MakeSWCanvasSurface(htmlCanvas),
      null,
    );
  }

  bool _presentSurface() {
    _surface!.flush();
    return true;
  }

  void dispose() {
    htmlCanvas?.removeEventListener(
        'webglcontextlost', _cachedContextLostListener, false);
    htmlCanvas?.removeEventListener(
        'webglcontextrestored', _cachedContextRestoredListener, false);
    _cachedContextLostListener = null;
    _cachedContextRestoredListener = null;
    htmlElement.remove();
    _surface?.dispose();
  }
}

/// A Dart wrapper around Skia's CkSurface.
class CkSurface {
  CkSurface(this.surface, this._glContext);

  CkCanvas getCanvas() {
    assert(!_isDisposed, 'Attempting to use the canvas of a disposed surface');
    return CkCanvas(surface.getCanvas());
  }

  /// The underlying CanvasKit surface object.
  ///
  /// Only borrow this value temporarily. Do not store it as it may be deleted
  /// at any moment. Storing it may lead to dangling pointer bugs.
  final SkSurface surface;

  final int? _glContext;

  /// Flushes the graphics to be rendered on screen.
  void flush() {
    surface.flush();
  }

  int? get context => _glContext;

  int width() => surface.width();
  int height() => surface.height();

  void dispose() {
    if (_isDisposed) {
      return;
    }
    surface.dispose();
    _isDisposed = true;
  }

  bool _isDisposed = false;
}
