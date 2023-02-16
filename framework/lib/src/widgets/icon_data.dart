// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flute/foundation.dart';

/// A description of an icon fulfilled by a font glyph.
///
/// See [Icons] for a number of predefined icons available for material
/// design applications.
@immutable
class IconData {
  /// Creates icon data.
  ///
  /// Rarely used directly. Instead, consider using one of the predefined icons
  /// like the [Icons] collection.
  ///
  /// The [fontPackage] argument must be non-null when using a font family that
  /// is included in a package. This is used when selecting the font.
  const IconData(
    this.codePoint, {
    this.fontFamily,
    this.fontPackage,
    this.matchTextDirection = false,
  });

  /// The Unicode code point at which this icon is stored in the icon font.
  final int codePoint;

  /// The font family from which the glyph for the [codePoint] will be selected.
  final String? fontFamily;

  /// The name of the package from which the font family is included.
  ///
  /// The name is used by the [Icon] widget when configuring the [TextStyle] so
  /// that the given [fontFamily] is obtained from the appropriate asset.
  ///
  /// See also:
  ///
  ///  * [TextStyle], which describes how to use fonts from other packages.
  final String? fontPackage;

  /// Whether this icon should be automatically mirrored in right-to-left
  /// environments.
  ///
  /// The [Icon] widget respects this value by mirroring the icon when the
  /// [Directionality] is [TextDirection.rtl].
  final bool matchTextDirection;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is IconData
        && other.codePoint == codePoint
        && other.fontFamily == fontFamily
        && other.fontPackage == fontPackage
        && other.matchTextDirection == matchTextDirection;
  }

  @override
  int get hashCode => Object.hash(codePoint, fontFamily, fontPackage, matchTextDirection);

  @override
  String toString() => 'IconData(U+${codePoint.toRadixString(16).toUpperCase().padLeft(5, '0')})';
}

/// [DiagnosticsProperty] that has an [IconData] as value.
class IconDataProperty extends DiagnosticsProperty<IconData> {
  /// Create a diagnostics property for [IconData].
  ///
  /// The [showName], [style], and [level] arguments must not be null.
  IconDataProperty(
    String super.name,
    super.value, {
    super.ifNull,
    super.showName,
    super.style,
    super.level,
  });

  @override
  Map<String, Object?> toJsonMap(DiagnosticsSerializationDelegate delegate) {
    final Map<String, Object?> json = super.toJsonMap(delegate);
    if (value != null) {
      json['valueProperties'] = <String, Object>{
        'codePoint': value!.codePoint,
      };
    }
    return json;
  }
}

class _StaticIconProvider {
  const _StaticIconProvider();
}

/// Annotation for classes that only provide static const [IconData] instances.
///
/// This is a hint to the font tree shaker to ignore the constant instances
/// of [IconData] appearing in the class when tracking which code points
/// should be retained in the bundled font.
const Object staticIconProvider = _StaticIconProvider();
