// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:ui/ui.dart' as ui;

import '../color_filter.dart';
import '../util.dart';
import 'canvaskit_api.dart';
import 'image_filter.dart';
import 'skia_object_cache.dart';

/// A concrete [ManagedSkiaObject] subclass that owns a [SkColorFilter] and
/// manages its lifecycle.
///
/// Seealso:
///
/// * [CkPaint.colorFilter], which uses a [ManagedSkColorFilter] to manage
///   the lifecycle of its [SkColorFilter].
class ManagedSkColorFilter extends ManagedSkiaObject<SkColorFilter> {
  ManagedSkColorFilter(CkColorFilter ckColorFilter)
      : colorFilter = ckColorFilter;

  final CkColorFilter colorFilter;

  @override
  SkColorFilter createDefault() => colorFilter._initRawColorFilter();

  @override
  SkColorFilter resurrect() => colorFilter._initRawColorFilter();

  @override
  void delete() {
    rawSkiaObject?.delete();
  }

  @override
  int get hashCode => colorFilter.hashCode;

  @override
  bool operator ==(Object other) {
    if (runtimeType != other.runtimeType) {
      return false;
    }
    return other is ManagedSkColorFilter && other.colorFilter == colorFilter;
  }

  @override
  String toString() => colorFilter.toString();
}

/// A [ui.ColorFilter] backed by Skia's [SkColorFilter].
///
/// Additionally, this class provides the interface for converting itself to a
/// [ManagedSkiaObject] that manages a skia image filter.
abstract class CkColorFilter
    implements CkManagedSkImageFilterConvertible, EngineColorFilter {
  const CkColorFilter();

  /// Called by [ManagedSkiaObject.createDefault] and
  /// [ManagedSkiaObject.resurrect] to create a new [SkImageFilter], when this
  /// filter is used as an [ImageFilter].
  SkImageFilter initRawImageFilter() =>
      canvasKit.ImageFilter.MakeColorFilter(_initRawColorFilter(), null);

  /// Called by [ManagedSkiaObject.createDefault] and
  /// [ManagedSkiaObject.resurrect] to create a new [SkColorFilter], when this
  /// filter is used as a [ColorFilter].
  SkColorFilter _initRawColorFilter();

  @override
  ManagedSkiaObject<SkImageFilter> get imageFilter =>
      CkColorFilterImageFilter(colorFilter: this);
}

class CkBlendModeColorFilter extends CkColorFilter {
  const CkBlendModeColorFilter(this.color, this.blendMode);

  final ui.Color color;
  final ui.BlendMode blendMode;

  @override
  SkColorFilter _initRawColorFilter() {
    return canvasKit.ColorFilter.MakeBlend(
      toSharedSkColor1(color),
      toSkBlendMode(blendMode),
    );
  }

  @override
  int get hashCode => ui.hashValues(color, blendMode);

  @override
  bool operator ==(Object other) {
    if (runtimeType != other.runtimeType) {
      return false;
    }
    return other is CkBlendModeColorFilter &&
        other.color == color &&
        other.blendMode == blendMode;
  }

  @override
  String toString() => 'ColorFilter.mode($color, $blendMode)';
}

class CkMatrixColorFilter extends CkColorFilter {
  const CkMatrixColorFilter(this.matrix);

  final List<double> matrix;

  @override
  SkColorFilter _initRawColorFilter() {
    assert(this.matrix.length == 20, 'Color Matrix must have 20 entries.');
    final List<double> matrix = this.matrix;
    if (matrix is Float32List) {
      return canvasKit.ColorFilter.MakeMatrix(matrix);
    }
    final Float32List float32Matrix = Float32List(20);
    for (int i = 0; i < 20; i++) {
      float32Matrix[i] = matrix[i];
    }
    return canvasKit.ColorFilter.MakeMatrix(float32Matrix);
  }

  @override
  int get hashCode => ui.hashList(matrix);

  @override
  bool operator ==(Object other) {
    return runtimeType == other.runtimeType &&
        other is CkMatrixColorFilter &&
        listEquals<double>(matrix, other.matrix);
  }

  @override
  String toString() => 'ColorFilter.matrix($matrix)';
}

class CkLinearToSrgbGammaColorFilter extends CkColorFilter {
  const CkLinearToSrgbGammaColorFilter();
  @override
  SkColorFilter _initRawColorFilter() =>
      canvasKit.ColorFilter.MakeLinearToSRGBGamma();

  @override
  bool operator ==(Object other) => runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'ColorFilter.linearToSrgbGamma()';
}

class CkSrgbToLinearGammaColorFilter extends CkColorFilter {
  const CkSrgbToLinearGammaColorFilter();
  @override
  SkColorFilter _initRawColorFilter() =>
      canvasKit.ColorFilter.MakeSRGBToLinearGamma();

  @override
  bool operator ==(Object other) => runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'ColorFilter.srgbToLinearGamma()';
}

class CkComposeColorFilter extends CkColorFilter {
  const CkComposeColorFilter(this.outer, this.inner);
  final ManagedSkColorFilter? outer;
  final ManagedSkColorFilter inner;

  @override
  SkColorFilter _initRawColorFilter() =>
      canvasKit.ColorFilter.MakeCompose(outer?.skiaObject, inner.skiaObject);

  @override
  bool operator ==(Object other) {
    if (other is! CkComposeColorFilter) {
      return false;
    }
    final CkComposeColorFilter filter = other;
    return filter.outer == outer && filter.inner == inner;
  }

  @override
  int get hashCode => Object.hash(outer, inner);

  @override
  String toString() => 'ColorFilter.compose($outer, $inner)';
}
