// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flute/cupertino.dart';
import 'package:flute/foundation.dart';
import 'package:flute/widgets.dart';

import 'material_localizations.dart';
import 'theme_data.dart';
import 'typography.dart';

export 'theme_data.dart' show Brightness, ThemeData;

/// The duration over which theme changes animate by default.
const Duration kThemeAnimationDuration = Duration(milliseconds: 200);

/// Applies a theme to descendant widgets.
///
/// A theme describes the colors and typographic choices of an application.
///
/// Descendant widgets obtain the current theme's [ThemeData] object using
/// [Theme.of]. When a widget uses [Theme.of], it is automatically rebuilt if
/// the theme later changes, so that the changes can be applied.
///
/// The [Theme] widget implies an [IconTheme] widget, set to the value of the
/// [ThemeData.iconTheme] of the [data] for the [Theme].
///
/// See also:
///
///  * [ThemeData], which describes the actual configuration of a theme.
///  * [AnimatedTheme], which animates the [ThemeData] when it changes rather
///    than changing the theme all at once.
///  * [MaterialApp], which includes an [AnimatedTheme] widget configured via
///    the [MaterialApp.theme] argument.
class Theme extends StatelessWidget {
  /// Applies the given theme [data] to [child].
  ///
  /// The [data] and [child] arguments must not be null.
  const Theme({
    Key? key,
    required this.data,
    required this.child,
  }) : assert(child != null),
       assert(data != null),
       super(key: key);

  /// Specifies the color and typography values for descendant widgets.
  final ThemeData data;

  /// The widget below this widget in the tree.
  ///
  /// {@macro flutter.widgets.ProxyWidget.child}
  final Widget child;

  static final ThemeData _kFallbackTheme = ThemeData.fallback();

  /// The data from the closest [Theme] instance that encloses the given
  /// context.
  ///
  /// If the given context is enclosed in a [Localizations] widget providing
  /// [MaterialLocalizations], the returned data is localized according to the
  /// nearest available [MaterialLocalizations].
  ///
  /// Defaults to [new ThemeData.fallback] if there is no [Theme] in the given
  /// build context.
  ///
  /// Typical usage is as follows:
  ///
  /// ```dart
  /// @override
  /// Widget build(BuildContext context) {
  ///   return Text(
  ///     'Example',
  ///     style: Theme.of(context).textTheme.headline6,
  ///   );
  /// }
  /// ```
  ///
  /// When the [Theme] is actually created in the same `build` function
  /// (possibly indirectly, e.g. as part of a [MaterialApp]), the `context`
  /// argument to the `build` function can't be used to find the [Theme] (since
  /// it's "above" the widget being returned). In such cases, the following
  /// technique with a [Builder] can be used to provide a new scope with a
  /// [BuildContext] that is "under" the [Theme]:
  ///
  /// ```dart
  /// @override
  /// Widget build(BuildContext context) {
  ///   return MaterialApp(
  ///     theme: ThemeData.light(),
  ///     body: Builder(
  ///       // Create an inner BuildContext so that we can refer to
  ///       // the Theme with Theme.of().
  ///       builder: (BuildContext context) {
  ///         return Center(
  ///           child: Text(
  ///             'Example',
  ///             style: Theme.of(context).textTheme.headline6,
  ///           ),
  ///         );
  ///       },
  ///     ),
  ///   );
  /// }
  /// ```
  static ThemeData of(BuildContext context) {
    final _InheritedTheme? inheritedTheme = context.dependOnInheritedWidgetOfExactType<_InheritedTheme>();
    final MaterialLocalizations? localizations = Localizations.of<MaterialLocalizations>(context, MaterialLocalizations);
    final ScriptCategory category = localizations?.scriptCategory ?? ScriptCategory.englishLike;
    final ThemeData theme = inheritedTheme?.theme.data ?? _kFallbackTheme;
    return ThemeData.localize(theme, theme.typography.geometryThemeFor(category));
  }

  @override
  Widget build(BuildContext context) {
    return _InheritedTheme(
      theme: this,
      child: CupertinoTheme(
        // We're using a MaterialBasedCupertinoThemeData here instead of a
        // CupertinoThemeData because it defers some properties to the Material
        // ThemeData.
        data: MaterialBasedCupertinoThemeData(
          materialTheme: data,
        ),
        child: IconTheme(
          data: data.iconTheme,
          child: child,
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ThemeData>('data', data, showName: false));
  }
}

class _InheritedTheme extends InheritedTheme {
  const _InheritedTheme({
    Key? key,
    required this.theme,
    required Widget child,
  }) : assert(theme != null),
       super(key: key, child: child);

  final Theme theme;

  @override
  Widget wrap(BuildContext context, Widget child) {
    return Theme(data: theme.data, child: child);
  }

  @override
  bool updateShouldNotify(_InheritedTheme old) => theme.data != old.theme.data;
}

/// An interpolation between two [ThemeData]s.
///
/// This class specializes the interpolation of [Tween<ThemeData>] to call the
/// [ThemeData.lerp] method.
///
/// See [Tween] for a discussion on how to use interpolation objects.
class ThemeDataTween extends Tween<ThemeData> {
  /// Creates a [ThemeData] tween.
  ///
  /// The [begin] and [end] properties must be non-null before the tween is
  /// first used, but the arguments can be null if the values are going to be
  /// filled in later.
  ThemeDataTween({ ThemeData? begin, ThemeData? end }) : super(begin: begin, end: end);

  @override
  ThemeData lerp(double t) => ThemeData.lerp(begin!, end!, t);
}

/// Animated version of [Theme] which automatically transitions the colors,
/// etc, over a given duration whenever the given theme changes.
///
/// Here's an illustration of what using this widget looks like, using a [curve]
/// of [Curves.elasticInOut].
/// {@animation 250 266 https://flutter.github.io/assets-for-api-docs/assets/widgets/animated_theme.mp4}
///
/// See also:
///
///  * [Theme], which [AnimatedTheme] uses to actually apply the interpolated
///    theme.
///  * [ThemeData], which describes the actual configuration of a theme.
///  * [MaterialApp], which includes an [AnimatedTheme] widget configured via
///    the [MaterialApp.theme] argument.
class AnimatedTheme extends ImplicitlyAnimatedWidget {
  /// Creates an animated theme.
  ///
  /// By default, the theme transition uses a linear curve. The [data] and
  /// [child] arguments must not be null.
  const AnimatedTheme({
    Key? key,
    required this.data,
    Curve curve = Curves.linear,
    Duration duration = kThemeAnimationDuration,
    VoidCallback? onEnd,
    required this.child,
  }) : assert(child != null),
       assert(data != null),
       super(key: key, curve: curve, duration: duration, onEnd: onEnd);

  /// Specifies the color and typography values for descendant widgets.
  final ThemeData data;

  /// The widget below this widget in the tree.
  ///
  /// {@macro flutter.widgets.ProxyWidget.child}
  final Widget child;

  @override
  _AnimatedThemeState createState() => _AnimatedThemeState();
}

class _AnimatedThemeState extends AnimatedWidgetBaseState<AnimatedTheme> {
  ThemeDataTween? _data;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    // TODO(ianh): Use constructor tear-offs when it becomes possible, https://github.com/dart-lang/sdk/issues/10659
    _data = visitor(_data, widget.data, (dynamic value) => ThemeDataTween(begin: value as ThemeData))! as ThemeDataTween;
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      child: widget.child,
      data: _data!.evaluate(animation),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(DiagnosticsProperty<ThemeDataTween>('data', _data, showName: false, defaultValue: null));
  }
}
