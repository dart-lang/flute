// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flute/ui.dart' show lerpDouble;

import 'package:flute/foundation.dart';
import 'package:flute/widgets.dart';

import 'theme.dart';

/// Defines the visual properties of the routes used to display popup menus
/// as well as [PopupMenuItem] and [PopupMenuDivider] widgets.
///
/// Descendant widgets obtain the current [PopupMenuThemeData] object
/// using `PopupMenuTheme.of(context)`. Instances of
/// [PopupMenuThemeData] can be customized with
/// [PopupMenuThemeData.copyWith].
///
/// Typically, a [PopupMenuThemeData] is specified as part of the
/// overall [Theme] with [ThemeData.popupMenuTheme]. Otherwise,
/// [PopupMenuTheme] can be used to configure its own widget subtree.
///
/// All [PopupMenuThemeData] properties are `null` by default.
/// If any of these properties are null, the popup menu will provide its
/// own defaults.
///
/// See also:
///
///  * [ThemeData], which describes the overall theme information for the
///    application.
@immutable
class PopupMenuThemeData with Diagnosticable {
  /// Creates the set of properties used to configure [PopupMenuTheme].
  const PopupMenuThemeData({
    this.color,
    this.shape,
    this.elevation,
    this.textStyle,
    this.enableFeedback,
  });

  /// The background color of the popup menu.
  final Color? color;

  /// The shape of the popup menu.
  final ShapeBorder? shape;

  /// The elevation of the popup menu.
  final double? elevation;

  /// The text style of items in the popup menu.
  final TextStyle? textStyle;

  /// If specified, defines the feedback property for [PopupMenuButton].
  ///
  /// If [PopupMenuButton.enableFeedback] is provided, [enableFeedback] is ignored.
  final bool? enableFeedback;

  /// Creates a copy of this object with the given fields replaced with the
  /// new values.
  PopupMenuThemeData copyWith({
    Color? color,
    ShapeBorder? shape,
    double? elevation,
    TextStyle? textStyle,
    bool? enableFeedback,
  }) {
    return PopupMenuThemeData(
      color: color ?? this.color,
      shape: shape ?? this.shape,
      elevation: elevation ?? this.elevation,
      textStyle: textStyle ?? this.textStyle,
      enableFeedback: enableFeedback ?? this.enableFeedback,
    );
  }

  /// Linearly interpolate between two popup menu themes.
  ///
  /// If both arguments are null, then null is returned.
  ///
  /// {@macro dart.ui.shadow.lerp}
  static PopupMenuThemeData? lerp(PopupMenuThemeData? a, PopupMenuThemeData? b, double t) {
    assert(t != null);
    if (a == null && b == null)
      return null;
    return PopupMenuThemeData(
      color: Color.lerp(a?.color, b?.color, t),
      shape: ShapeBorder.lerp(a?.shape, b?.shape, t),
      elevation: lerpDouble(a?.elevation, b?.elevation, t),
      textStyle: TextStyle.lerp(a?.textStyle, b?.textStyle, t),
      enableFeedback: t < 0.5 ? a?.enableFeedback : b?.enableFeedback,
    );
  }

  @override
  int get hashCode {
    return hashValues(
      color,
      shape,
      elevation,
      textStyle,
      enableFeedback,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other))
      return true;
    if (other.runtimeType != runtimeType)
      return false;
    return other is PopupMenuThemeData
        && other.elevation == elevation
        && other.color == color
        && other.shape == shape
        && other.textStyle == textStyle
        && other.enableFeedback == enableFeedback;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ColorProperty('color', color, defaultValue: null));
    properties.add(DiagnosticsProperty<ShapeBorder>('shape', shape, defaultValue: null));
    properties.add(DoubleProperty('elevation', elevation, defaultValue: null));
    properties.add(DiagnosticsProperty<TextStyle>('text style', textStyle, defaultValue: null));
    properties.add(DiagnosticsProperty<bool>('enableFeedback', enableFeedback, defaultValue: null));
  }
}

/// An inherited widget that defines the configuration for
/// popup menus in this widget's subtree.
///
/// Values specified here are used for popup menu properties that are not
/// given an explicit non-null value.
class PopupMenuTheme extends InheritedTheme {
  /// Creates a popup menu theme that controls the configurations for
  /// popup menus in its widget subtree.
  ///
  /// The data argument must not be null.
  const PopupMenuTheme({
    Key? key,
    required this.data,
    required Widget child,
  }) : assert(data != null), super(key: key, child: child);

  /// The properties for descendant popup menu widgets.
  final PopupMenuThemeData data;

  /// The closest instance of this class's [data] value that encloses the given
  /// context. If there is no ancestor, it returns [ThemeData.popupMenuTheme].
  /// Applications can assume that the returned value will not be null.
  ///
  /// Typical usage is as follows:
  ///
  /// ```dart
  /// PopupMenuThemeData theme = PopupMenuTheme.of(context);
  /// ```
  static PopupMenuThemeData of(BuildContext context) {
    final PopupMenuTheme? popupMenuTheme = context.dependOnInheritedWidgetOfExactType<PopupMenuTheme>();
    return popupMenuTheme?.data ?? Theme.of(context).popupMenuTheme;
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    return PopupMenuTheme(data: data, child: child);
  }

  @override
  bool updateShouldNotify(PopupMenuTheme oldWidget) => data != oldWidget.data;
}
