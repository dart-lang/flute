// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flute/foundation.dart';

import 'framework.dart';
import 'scroll_controller.dart';

/// Associates a [ScrollController] with a subtree.
///
/// When a [ScrollView] has [ScrollView.primary] set to true and is not given
/// an explicit [ScrollController], the [ScrollView] uses [of] to find the
/// [ScrollController] associated with its subtree.
///
/// This mechanism can be used to provide default behavior for scroll views in a
/// subtree. For example, the [Scaffold] uses this mechanism to implement the
/// scroll-to-top gesture on iOS.
///
/// Another default behavior handled by the PrimaryScrollController is default
/// [ScrollAction]s. If a ScrollAction is not handled by an otherwise focused
/// part of the application, the ScrollAction will be evaluated using the scroll
/// view associated with a PrimaryScrollController, for example, when executing
/// [Shortcuts] key events like page up and down.
///
/// See also:
///   * [ScrollAction], an [Action] that scrolls the [Scrollable] that encloses
///     the current [primaryFocus] or is attached to the PrimaryScrollController.
///   * [Shortcuts], a widget that establishes a [ShortcutManager] to be used
///     by its descendants when invoking an [Action] via a keyboard key
///     combination that maps to an [Intent].
class PrimaryScrollController extends InheritedWidget {
  /// Creates a widget that associates a [ScrollController] with a subtree.
  const PrimaryScrollController({
    Key? key,
    required ScrollController this.controller,
    required Widget child,
  }) : assert(controller != null),
       super(key: key, child: child);

  /// Creates a subtree without an associated [ScrollController].
  const PrimaryScrollController.none({
    Key? key,
    required Widget child,
  }) : controller = null,
       super(key: key, child: child);

  /// The [ScrollController] associated with the subtree.
  ///
  /// See also:
  ///
  ///  * [ScrollView.controller], which discusses the purpose of specifying a
  ///    scroll controller.
  final ScrollController? controller;

  /// Returns the [ScrollController] most closely associated with the given
  /// context.
  ///
  /// Returns null if there is no [ScrollController] associated with the given
  /// context.
  static ScrollController? of(BuildContext context) {
    final PrimaryScrollController? result = context.dependOnInheritedWidgetOfExactType<PrimaryScrollController>();
    return result?.controller;
  }

  @override
  bool updateShouldNotify(PrimaryScrollController oldWidget) => controller != oldWidget.controller;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ScrollController>('controller', controller, ifNull: 'no controller', showName: false));
  }
}
