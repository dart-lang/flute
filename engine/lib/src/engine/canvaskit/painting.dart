// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:ui/ui.dart' as ui;

import 'canvaskit_api.dart';
import 'color_filter.dart';
import 'image_filter.dart';
import 'mask_filter.dart';
import 'shader.dart';
import 'skia_object_cache.dart';

/// The implementation of [ui.Paint] used by the CanvasKit backend.
///
/// This class is backed by a Skia object that must be explicitly
/// deleted to avoid a memory leak. This is done by extending [SkiaObject].
class CkPaint extends ManagedSkiaObject<SkPaint> implements ui.Paint {
  CkPaint();

  static const ui.Color _defaultPaintColor = ui.Color(0xFF000000);

  @override
  ui.BlendMode get blendMode => _blendMode;
  @override
  set blendMode(ui.BlendMode value) {
    if (_blendMode == value) {
      return;
    }
    _blendMode = value;
    skiaObject.setBlendMode(toSkBlendMode(value));
  }

  ui.BlendMode _blendMode = ui.BlendMode.srcOver;

  @override
  ui.PaintingStyle get style => _style;

  @override
  set style(ui.PaintingStyle value) {
    if (_style == value) {
      return;
    }
    _style = value;
    skiaObject.setStyle(toSkPaintStyle(value));
  }

  ui.PaintingStyle _style = ui.PaintingStyle.fill;

  @override
  double get strokeWidth => _strokeWidth;
  @override
  set strokeWidth(double value) {
    if (_strokeWidth == value) {
      return;
    }
    _strokeWidth = value;
    skiaObject.setStrokeWidth(value);
  }

  double _strokeWidth = 0.0;

  @override
  ui.StrokeCap get strokeCap => _strokeCap;
  @override
  set strokeCap(ui.StrokeCap value) {
    if (_strokeCap == value) {
      return;
    }
    _strokeCap = value;
    skiaObject.setStrokeCap(toSkStrokeCap(value));
  }

  ui.StrokeCap _strokeCap = ui.StrokeCap.butt;

  @override
  ui.StrokeJoin get strokeJoin => _strokeJoin;
  @override
  set strokeJoin(ui.StrokeJoin value) {
    if (_strokeJoin == value) {
      return;
    }
    _strokeJoin = value;
    skiaObject.setStrokeJoin(toSkStrokeJoin(value));
  }

  ui.StrokeJoin _strokeJoin = ui.StrokeJoin.miter;

  @override
  bool get isAntiAlias => _isAntiAlias;
  @override
  set isAntiAlias(bool value) {
    if (_isAntiAlias == value) {
      return;
    }
    _isAntiAlias = value;
    skiaObject.setAntiAlias(value);
  }

  bool _isAntiAlias = true;

  @override
  ui.Color get color => _color;
  @override
  set color(ui.Color value) {
    if (_color == value) {
      return;
    }
    _color = value;
    skiaObject.setColorInt(value.value);
  }

  ui.Color _color = _defaultPaintColor;

  @override
  bool get invertColors => _invertColors;
  @override
  set invertColors(bool value) {
    if (value == _invertColors) {
      return;
    }
    if (!value) {
      _effectiveColorFilter = _originalColorFilter;
      _originalColorFilter = null;
    } else {
      _originalColorFilter = _effectiveColorFilter;
      if (_effectiveColorFilter == null) {
        _effectiveColorFilter = _invertColorFilter;
      } else {
        _effectiveColorFilter = ManagedSkColorFilter(
            CkComposeColorFilter(_invertColorFilter, _effectiveColorFilter!));
      }
    }
    skiaObject.setColorFilter(_effectiveColorFilter?.skiaObject);
    _invertColors = value;
  }

  bool _invertColors = false;
  // The original color filter before we inverted colors. If we set
  // `invertColors` back to `false`, then restore this filter rather than
  // invert the color filter again.
  ManagedSkColorFilter? _originalColorFilter;

  @override
  ui.Shader? get shader => _shader;
  @override
  set shader(ui.Shader? value) {
    if (_shader == value) {
      return;
    }
    _shader = value as CkShader?;
    skiaObject.setShader(_shader?.withQuality(_filterQuality));
  }

  CkShader? _shader;

  @override
  ui.MaskFilter? get maskFilter => _maskFilter;
  @override
  set maskFilter(ui.MaskFilter? value) {
    if (value == _maskFilter) {
      return;
    }
    _maskFilter = value;
    if (value != null) {
      // CanvasKit returns `null` if the sigma is `0` or infinite.
      if (!(value.webOnlySigma.isFinite && value.webOnlySigma > 0)) {
        // Don't create a [CkMaskFilter].
        _ckMaskFilter = null;
      } else {
        _ckMaskFilter = CkMaskFilter.blur(
          value.webOnlyBlurStyle,
          value.webOnlySigma,
        );
      }
    } else {
      _ckMaskFilter = null;
    }
    skiaObject.setMaskFilter(_ckMaskFilter?.skiaObject);
  }

  ui.MaskFilter? _maskFilter;
  CkMaskFilter? _ckMaskFilter;

  @override
  ui.FilterQuality get filterQuality => _filterQuality;
  @override
  set filterQuality(ui.FilterQuality value) {
    if (_filterQuality == value) {
      return;
    }
    _filterQuality = value;
    skiaObject.setShader(_shader?.withQuality(value));
  }

  ui.FilterQuality _filterQuality = ui.FilterQuality.none;

  @override
  ui.ColorFilter? get colorFilter => _effectiveColorFilter?.colorFilter;
  @override
  set colorFilter(ui.ColorFilter? value) {
    if (colorFilter == value) {
      return;
    }

    _originalColorFilter = null;
    if (value == null) {
      _effectiveColorFilter = null;
    } else {
      _effectiveColorFilter = ManagedSkColorFilter(value as CkColorFilter);
    }

    if (invertColors) {
      _originalColorFilter = _effectiveColorFilter;
      if (_effectiveColorFilter == null) {
        _effectiveColorFilter = _invertColorFilter;
      } else {
        _effectiveColorFilter = ManagedSkColorFilter(
            CkComposeColorFilter(_invertColorFilter, _effectiveColorFilter!));
      }
    }

    skiaObject.setColorFilter(_effectiveColorFilter?.skiaObject);
  }

  /// The effective color filter.
  ///
  /// This is a combination of the `colorFilter` and `invertColors` properties.
  ManagedSkColorFilter? _effectiveColorFilter;

  @override
  double get strokeMiterLimit => _strokeMiterLimit;
  @override
  set strokeMiterLimit(double value) {
    if (_strokeMiterLimit == value) {
      return;
    }
    _strokeMiterLimit = value;
    skiaObject.setStrokeMiter(value);
  }

  double _strokeMiterLimit = 0.0;

  @override
  ui.ImageFilter? get imageFilter => _imageFilter;
  @override
  set imageFilter(ui.ImageFilter? value) {
    if (_imageFilter == value) {
      return;
    }

    _imageFilter = value as CkManagedSkImageFilterConvertible?;
    _managedImageFilter = _imageFilter?.imageFilter;
    skiaObject.setImageFilter(_managedImageFilter?.skiaObject);
  }

  CkManagedSkImageFilterConvertible? _imageFilter;
  ManagedSkiaObject<SkImageFilter>? _managedImageFilter;

  @override
  SkPaint createDefault() {
    final SkPaint paint = SkPaint();
    paint.setAntiAlias(_isAntiAlias);
    paint.setColorInt(_color.value);
    return paint;
  }

  @override
  SkPaint resurrect() {
    final SkPaint paint = SkPaint();
    // No need to do anything for `invertColors`. If it was set, then it
    // updated `_managedColorFilter`.
    paint.setBlendMode(toSkBlendMode(_blendMode));
    paint.setStyle(toSkPaintStyle(_style));
    paint.setStrokeWidth(_strokeWidth);
    paint.setAntiAlias(_isAntiAlias);
    paint.setColorInt(_color.value);
    paint.setShader(_shader?.withQuality(_filterQuality));
    paint.setMaskFilter(_ckMaskFilter?.skiaObject);
    paint.setColorFilter(_effectiveColorFilter?.skiaObject);
    paint.setImageFilter(_managedImageFilter?.skiaObject);
    paint.setStrokeCap(toSkStrokeCap(_strokeCap));
    paint.setStrokeJoin(toSkStrokeJoin(_strokeJoin));
    paint.setStrokeMiter(_strokeMiterLimit);
    return paint;
  }

  @override
  void delete() {
    rawSkiaObject?.delete();
  }
}

final Float32List _invertColorMatrix = Float32List.fromList(const <double>[
  -1.0, 0, 0, 1.0, 0, // row
  0, -1.0, 0, 1.0, 0, // row
  0, 0, -1.0, 1.0, 0, // row
  1.0, 1.0, 1.0, 1.0, 0
]);

final ManagedSkColorFilter _invertColorFilter =
    ManagedSkColorFilter(CkMatrixColorFilter(_invertColorMatrix));
