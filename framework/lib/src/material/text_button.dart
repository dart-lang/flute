// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'package:flute/ui.dart' show lerpDouble;

import 'package:flute/foundation.dart';
import 'package:flute/rendering.dart';
import 'package:flute/widgets.dart';

import 'button_style.dart';
import 'button_style_button.dart';
import 'color_scheme.dart';
import 'colors.dart';
import 'constants.dart';
import 'material_state.dart';
import 'text_button_theme.dart';
import 'theme.dart';
import 'theme_data.dart';

/// A Material Design "Text Button".
///
/// Use text buttons on toolbars, in dialogs, or inline with other
/// content but offset from that content with padding so that the
/// button's presence is obvious. Text buttons do not have visible
/// borders and must therefore rely on their position relative to
/// other content for context. In dialogs and cards, they should be
/// grouped together in one of the bottom corners. Avoid using text
/// buttons where they would blend in with other content, for example
/// in the middle of lists.
///
/// A text button is a label [child] displayed on a (zero elevation)
/// [Material] widget. The label's [Text] and [Icon] widgets are
/// displayed in the [style]'s [ButtonStyle.foregroundColor]. The
/// button reacts to touches by filling with the [style]'s
/// [ButtonStyle.backgroundColor].
///
/// The text button's default style is defined by [defaultStyleOf].
/// The style of this text button can be overridden with its [style]
/// parameter. The style of all text buttons in a subtree can be
/// overridden with the [TextButtonTheme] and the style of all of the
/// text buttons in an app can be overridden with the [Theme]'s
/// [ThemeData.textButtonTheme] property.
///
/// The static [styleFrom] method is a convenient way to create a
/// text button [ButtonStyle] from simple values.
///
/// If the [onPressed] and [onLongPress] callbacks are null, then this
/// button will be disabled, it will not react to touch.
///
/// See also:
///
///  * [OutlinedButton], a [TextButton] with a border outline.
///  * [ElevatedButton], a filled button whose material elevates when pressed.
///  * <https://material.io/design/components/buttons.html>
class TextButton extends ButtonStyleButton {
  /// Create a TextButton.
  ///
  /// The [autofocus] and [clipBehavior] arguments must not be null.
  const TextButton({
    Key? key,
    required VoidCallback? onPressed,
    VoidCallback? onLongPress,
    ButtonStyle? style,
    FocusNode? focusNode,
    bool autofocus = false,
    Clip clipBehavior = Clip.none,
    required Widget child,
  }) : super(
    key: key,
    onPressed: onPressed,
    onLongPress: onLongPress,
    style: style,
    focusNode: focusNode,
    autofocus: autofocus,
    clipBehavior: clipBehavior,
    child: child,
  );

  /// Create a text button from a pair of widgets that serve as the button's
  /// [icon] and [label].
  ///
  /// The icon and label are arranged in a row and padded by 8 logical pixels
  /// at the ends, with an 8 pixel gap in between.
  ///
  /// The [icon] and [label] arguments must not be null.
  factory TextButton.icon({
    Key? key,
    required VoidCallback? onPressed,
    VoidCallback? onLongPress,
    ButtonStyle? style,
    FocusNode? focusNode,
    bool? autofocus,
    Clip? clipBehavior,
    required Widget icon,
    required Widget label,
  }) = _TextButtonWithIcon;

  /// A static convenience method that constructs a text button
  /// [ButtonStyle] given simple values.
  ///
  /// The [primary], and [onSurface] colors are used to to create a
  /// [MaterialStateProperty] [ButtonStyle.foregroundColor] value in the same
  /// way that [defaultStyleOf] uses the [ColorScheme] colors with the same
  /// names. Specify a value for [primary] to specify the color of the button's
  /// text and icons as well as the overlay colors used to indicate the hover,
  /// focus, and pressed states. Use [onSurface] to specify the button's
  /// disabled text and icon color.
  ///
  /// Similarly, the [enabledMouseCursor] and [disabledMouseCursor]
  /// parameters are used to construct [ButtonStyle.mouseCursor].
  ///
  /// All of the other parameters are either used directly or used to
  /// create a [MaterialStateProperty] with a single value for all
  /// states.
  ///
  /// All parameters default to null. By default this method returns
  /// a [ButtonStyle] that doesn't override anything.
  ///
  /// For example, to override the default text and icon colors for a
  /// [TextButton], as well as its overlay color, with all of the
  /// standard opacity adjustments for the pressed, focused, and
  /// hovered states, one could write:
  ///
  /// ```dart
  /// TextButton(
  ///   style: TextButton.styleFrom(primary: Colors.green),
  /// )
  /// ```
  static ButtonStyle styleFrom({
    Color? primary,
    Color? onSurface,
    Color? backgroundColor,
    Color? shadowColor,
    double? elevation,
    TextStyle? textStyle,
    EdgeInsetsGeometry? padding,
    Size? minimumSize,
    BorderSide? side,
    OutlinedBorder? shape,
    MouseCursor? enabledMouseCursor,
    MouseCursor? disabledMouseCursor,
    VisualDensity? visualDensity,
    MaterialTapTargetSize? tapTargetSize,
    Duration? animationDuration,
    bool? enableFeedback,
  }) {
    final MaterialStateProperty<Color?>? foregroundColor = (onSurface == null && primary == null)
      ? null
      : _TextButtonDefaultForeground(primary, onSurface);
    final MaterialStateProperty<Color?>? overlayColor = (primary == null)
      ? null
      : _TextButtonDefaultOverlay(primary);
    final MaterialStateProperty<MouseCursor>? mouseCursor = (enabledMouseCursor == null && disabledMouseCursor == null)
      ? null
      : _TextButtonDefaultMouseCursor(enabledMouseCursor!, disabledMouseCursor!);

    return ButtonStyle(
      textStyle: ButtonStyleButton.allOrNull<TextStyle>(textStyle),
      backgroundColor: ButtonStyleButton.allOrNull<Color>(backgroundColor),
      foregroundColor: foregroundColor,
      overlayColor: overlayColor,
      shadowColor: ButtonStyleButton.allOrNull<Color>(shadowColor),
      elevation: ButtonStyleButton.allOrNull<double>(elevation),
      padding: ButtonStyleButton.allOrNull<EdgeInsetsGeometry>(padding),
      minimumSize: ButtonStyleButton.allOrNull<Size>(minimumSize),
      side: ButtonStyleButton.allOrNull<BorderSide>(side),
      shape: ButtonStyleButton.allOrNull<OutlinedBorder>(shape),
      mouseCursor: mouseCursor,
      visualDensity: visualDensity,
      tapTargetSize: tapTargetSize,
      animationDuration: animationDuration,
      enableFeedback: enableFeedback,
    );
  }

  /// Defines the button's default appearance.
  ///
  /// The button [child]'s [Text] and [Icon] widgets are rendered with
  /// the [ButtonStyle]'s foreground color. The button's [InkWell] adds
  /// the style's overlay color when the button is focused, hovered
  /// or pressed. The button's background color becomes its [Material]
  /// color and is transparent by default.
  ///
  /// All of the ButtonStyle's defaults appear below.
  ///
  /// In this list "Theme.foo" is shorthand for
  /// `Theme.of(context).foo`. Color scheme values like
  /// "onSurface(0.38)" are shorthand for
  /// `onSurface.withOpacity(0.38)`. [MaterialStateProperty] valued
  /// properties that are not followed by by a sublist have the same
  /// value for all states, otherwise the values are as specified for
  /// each state and "others" means all other states.
  ///
  /// The `textScaleFactor` is the value of
  /// `MediaQuery.of(context).textScaleFactor` and the names of the
  /// EdgeInsets constructors and `EdgeInsetsGeometry.lerp` have been
  /// abbreviated for readability.
  ///
  /// The color of the [ButtonStyle.textStyle] is not used, the
  /// [ButtonStyle.foregroundColor] color is used instead.
  ///
  /// * `textStyle` - Theme.textTheme.button
  /// * `backgroundColor` - transparent
  /// * `foregroundColor`
  ///   * disabled - Theme.colorScheme.onSurface(0.38)
  ///   * others - Theme.colorScheme.primary
  /// * `overlayColor`
  ///   * hovered - Theme.colorScheme.primary(0.04)
  ///   * focused or pressed - Theme.colorScheme.primary(0.12)
  /// * `shadowColor` - Theme.shadowColor
  /// * `elevation` - 0
  /// * `padding`
  ///   * `textScaleFactor <= 1` - all(8)
  ///   * `1 < textScaleFactor <= 2` - lerp(all(8), horizontal(8))
  ///   * `2 < textScaleFactor <= 3` - lerp(horizontal(8), horizontal(4))
  ///   * `3 < textScaleFactor` - horizontal(4)
  /// * `minimumSize` - Size(64, 36)
  /// * `side` - null
  /// * `shape` - RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))
  /// * `mouseCursor`
  ///   * disabled - SystemMouseCursors.forbidden
  ///   * others - SystemMouseCursors.click
  /// * `visualDensity` - theme.visualDensity
  /// * `tapTargetSize` - theme.materialTapTargetSize
  /// * `animationDuration` - kThemeChangeDuration
  /// * `enableFeedback` - true
  ///
  /// The default padding values for the [TextButton.icon] factory are slightly different:
  ///
  /// * `padding`
  ///   * `textScaleFactor <= 1` - all(8)
  ///   * `1 < textScaleFactor <= 2 `- lerp(all(8), horizontal(4))
  ///   * `2 < textScaleFactor` - horizontal(4)
  ///
  /// The default value for `side`, which defines the appearance of the button's
  /// outline, is null. That means that the outline is defined by the button
  /// shape's [OutlinedBorder.side]. Typically the default value of an
  /// [OutlinedBorder]'s side is [BorderSide.none], so an outline is not drawn.
  @override
  ButtonStyle defaultStyleOf(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    final EdgeInsetsGeometry scaledPadding = ButtonStyleButton.scaledPadding(
      const EdgeInsets.all(8),
      const EdgeInsets.symmetric(horizontal: 8),
      const EdgeInsets.symmetric(horizontal: 4),
      MediaQuery.maybeOf(context)?.textScaleFactor ?? 1,
    );

    return styleFrom(
      primary: colorScheme.primary,
      onSurface: colorScheme.onSurface,
      backgroundColor: Colors.transparent,
      shadowColor: theme.shadowColor,
      elevation: 0,
      textStyle: theme.textTheme.button,
      padding: scaledPadding,
      minimumSize: const Size(64, 36),
      side: null,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
      enabledMouseCursor: SystemMouseCursors.click,
      disabledMouseCursor: SystemMouseCursors.forbidden,
      visualDensity: theme.visualDensity,
      tapTargetSize: theme.materialTapTargetSize,
      animationDuration: kThemeChangeDuration,
      enableFeedback: true,
    );
  }

  /// Returns the [TextButtonThemeData.style] of the closest
  /// [TextButtonTheme] ancestor.
  @override
  ButtonStyle? themeStyleOf(BuildContext context) {
    return TextButtonTheme.of(context).style;
  }
}

@immutable
class _TextButtonDefaultForeground extends MaterialStateProperty<Color?> {
  _TextButtonDefaultForeground(this.primary, this.onSurface);

  final Color? primary;
  final Color? onSurface;

  @override
  Color? resolve(Set<MaterialState> states) {
    if (states.contains(MaterialState.disabled))
      return onSurface?.withOpacity(0.38);
    return primary;
  }

  @override
  String toString() {
    return '{disabled: ${onSurface?.withOpacity(0.38)}, otherwise: $primary}';
  }
}

@immutable
class _TextButtonDefaultOverlay extends MaterialStateProperty<Color?> {
  _TextButtonDefaultOverlay(this.primary);

  final Color primary;

  @override
  Color? resolve(Set<MaterialState> states) {
    if (states.contains(MaterialState.hovered))
      return primary.withOpacity(0.04);
    if (states.contains(MaterialState.focused) || states.contains(MaterialState.pressed))
      return primary.withOpacity(0.12);
    return null;
  }

  @override
  String toString() {
    return '{hovered: ${primary.withOpacity(0.04)}, focused,pressed: ${primary.withOpacity(0.12)}, otherwise: null}';
  }
}

@immutable
class _TextButtonDefaultMouseCursor extends MaterialStateProperty<MouseCursor> with Diagnosticable {
  _TextButtonDefaultMouseCursor(this.enabledCursor, this.disabledCursor);

  final MouseCursor enabledCursor;
  final MouseCursor disabledCursor;

  @override
  MouseCursor resolve(Set<MaterialState> states) {
    if (states.contains(MaterialState.disabled))
      return disabledCursor;
    return enabledCursor;
  }
}

class _TextButtonWithIcon extends TextButton {
  _TextButtonWithIcon({
    Key? key,
    required VoidCallback? onPressed,
    VoidCallback? onLongPress,
    ButtonStyle? style,
    FocusNode? focusNode,
    bool? autofocus,
    Clip? clipBehavior,
    required Widget icon,
    required Widget label,
  }) : assert(icon != null),
       assert(label != null),
       super(
         key: key,
         onPressed: onPressed,
         onLongPress: onLongPress,
         style: style,
         focusNode: focusNode,
         autofocus: autofocus ?? false,
         clipBehavior: clipBehavior ?? Clip.none,
         child: _TextButtonWithIconChild(icon: icon, label: label),
      );

  @override
  ButtonStyle defaultStyleOf(BuildContext context) {
    final EdgeInsetsGeometry scaledPadding = ButtonStyleButton.scaledPadding(
      const EdgeInsets.all(8),
      const EdgeInsets.symmetric(horizontal: 4),
      const EdgeInsets.symmetric(horizontal: 4),
      MediaQuery.maybeOf(context)?.textScaleFactor ?? 1,
    );
    return super.defaultStyleOf(context).copyWith(
      padding: MaterialStateProperty.all<EdgeInsetsGeometry>(scaledPadding)
    );
  }
}

class _TextButtonWithIconChild extends StatelessWidget {
  const _TextButtonWithIconChild({
    Key? key,
    required this.label,
    required this.icon,
  }) : super(key: key);

  final Widget label;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    final double scale = MediaQuery.maybeOf(context)?.textScaleFactor ?? 1;
    final double gap = scale <= 1 ? 8 : lerpDouble(8, 4, math.min(scale - 1, 1))!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[icon, SizedBox(width: gap), label],
    );
  }
}
