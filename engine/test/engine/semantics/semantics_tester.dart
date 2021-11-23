// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ui/src/engine.dart' show domRenderer, toMatrix32;
import 'package:ui/src/engine/browser_detection.dart';
import 'package:ui/src/engine/host_node.dart';
import 'package:ui/src/engine/semantics.dart';
import 'package:ui/src/engine/util.dart';
import 'package:ui/src/engine/vector_math.dart';
import 'package:ui/ui.dart' as ui;

import '../../matchers.dart';

/// Gets the DOM host where the Flutter app is being rendered.
///
/// This function returns the correct host for the flutter app under testing,
/// so we don't have to hardcode html.document across the test. (The host of a
/// normal flutter app used to be html.document, but now that the app is wrapped
/// in a Shadow DOM, that's not the case anymore.)
HostNode get appHostNode => domRenderer.glassPaneShadow!;

/// CSS style applied to the root of the semantics tree.
// TODO(yjbanov): this should be handled internally by [expectSemanticsTree].
//                No need for every test to inject it.
final String rootSemanticStyle = browserEngine != BrowserEngine.edge
  ? 'filter: opacity(0%); color: rgba(0, 0, 0, 0)'
  : 'color: rgba(0, 0, 0, 0); filter: opacity(0%)';

/// A convenience wrapper of the semantics API for building and inspecting the
/// semantics tree in unit tests.
class SemanticsTester {
  SemanticsTester(this.owner);

  final EngineSemanticsOwner owner;
  final List<SemanticsNodeUpdate> _nodeUpdates = <SemanticsNodeUpdate>[];

  /// Updates one semantics node.
  ///
  /// Provides reasonable defaults for the missing attributes, and conveniences
  /// for specifying flags, such as [isTextField].
  SemanticsNodeUpdate updateNode({
    required int id,

    // Flags
    int flags = 0,
    bool? hasCheckedState,
    bool? isChecked,
    bool? isSelected,
    bool? isButton,
    bool? isLink,
    bool? isTextField,
    bool? isReadOnly,
    bool? isFocusable,
    bool? isFocused,
    bool? hasEnabledState,
    bool? isEnabled,
    bool? isInMutuallyExclusiveGroup,
    bool? isHeader,
    bool? isObscured,
    bool? scopesRoute,
    bool? namesRoute,
    bool? isHidden,
    bool? isImage,
    bool? isLiveRegion,
    bool? hasToggledState,
    bool? isToggled,
    bool? hasImplicitScrolling,
    bool? isMultiline,
    bool? isSlider,
    bool? isKeyboardKey,

    // Actions
    int actions = 0,
    bool? hasTap,
    bool? hasLongPress,
    bool? hasScrollLeft,
    bool? hasScrollRight,
    bool? hasScrollUp,
    bool? hasScrollDown,
    bool? hasIncrease,
    bool? hasDecrease,
    bool? hasShowOnScreen,
    bool? hasMoveCursorForwardByCharacter,
    bool? hasMoveCursorBackwardByCharacter,
    bool? hasSetSelection,
    bool? hasCopy,
    bool? hasCut,
    bool? hasPaste,
    bool? hasDidGainAccessibilityFocus,
    bool? hasDidLoseAccessibilityFocus,
    bool? hasCustomAction,
    bool? hasDismiss,
    bool? hasMoveCursorForwardByWord,
    bool? hasMoveCursorBackwardByWord,
    bool? hasSetText,

    // Other attributes
    int? maxValueLength,
    int? currentValueLength,
    int? textSelectionBase,
    int? textSelectionExtent,
    int? platformViewId,
    int? scrollChildren,
    int? scrollIndex,
    double? scrollPosition,
    double? scrollExtentMax,
    double? scrollExtentMin,
    double? elevation,
    double? thickness,
    ui.Rect? rect,
    String? label,
    List<ui.StringAttribute>? labelAttributes,
    String? hint,
    List<ui.StringAttribute>? hintAttributes,
    String? value,
    List<ui.StringAttribute>? valueAttributes,
    String? increasedValue,
    List<ui.StringAttribute>? increasedValueAttributes,
    String? decreasedValue,
    List<ui.StringAttribute>? decreasedValueAttributes,
    String? tooltip,
    ui.TextDirection? textDirection,
    Float64List? transform,
    Int32List? additionalActions,
    List<SemanticsNodeUpdate>? children,
  }) {
    // Flags
    if (hasCheckedState == true) {
      flags |= ui.SemanticsFlag.hasCheckedState.index;
    }
    if (isChecked == true) {
      flags |= ui.SemanticsFlag.isChecked.index;
    }
    if (isSelected == true) {
      flags |= ui.SemanticsFlag.isSelected.index;
    }
    if (isButton == true) {
      flags |= ui.SemanticsFlag.isButton.index;
    }
    if (isLink == true) {
      flags |= ui.SemanticsFlag.isLink.index;
    }
    if (isTextField == true) {
      flags |= ui.SemanticsFlag.isTextField.index;
    }
    if (isReadOnly == true) {
      flags |= ui.SemanticsFlag.isReadOnly.index;
    }
    if (isFocusable == true) {
      flags |= ui.SemanticsFlag.isFocusable.index;
    }
    if (isFocused == true) {
      flags |= ui.SemanticsFlag.isFocused.index;
    }
    if (hasEnabledState == true) {
      flags |= ui.SemanticsFlag.hasEnabledState.index;
    }
    if (isEnabled == true) {
      flags |= ui.SemanticsFlag.isEnabled.index;
    }
    if (isInMutuallyExclusiveGroup == true) {
      flags |= ui.SemanticsFlag.isInMutuallyExclusiveGroup.index;
    }
    if (isHeader == true) {
      flags |= ui.SemanticsFlag.isHeader.index;
    }
    if (isObscured == true) {
      flags |= ui.SemanticsFlag.isObscured.index;
    }
    if (scopesRoute == true) {
      flags |= ui.SemanticsFlag.scopesRoute.index;
    }
    if (namesRoute == true) {
      flags |= ui.SemanticsFlag.namesRoute.index;
    }
    if (isHidden == true) {
      flags |= ui.SemanticsFlag.isHidden.index;
    }
    if (isImage == true) {
      flags |= ui.SemanticsFlag.isImage.index;
    }
    if (isLiveRegion == true) {
      flags |= ui.SemanticsFlag.isLiveRegion.index;
    }
    if (hasToggledState == true) {
      flags |= ui.SemanticsFlag.hasToggledState.index;
    }
    if (isToggled == true) {
      flags |= ui.SemanticsFlag.isToggled.index;
    }
    if (hasImplicitScrolling == true) {
      flags |= ui.SemanticsFlag.hasImplicitScrolling.index;
    }
    if (isMultiline == true) {
      flags |= ui.SemanticsFlag.isMultiline.index;
    }
    if (isSlider == true) {
      flags |= ui.SemanticsFlag.isSlider.index;
    }
    if (isKeyboardKey == true) {
      flags |= ui.SemanticsFlag.isKeyboardKey.index;
    }

    // Actions
    if (hasTap == true) {
      actions |= ui.SemanticsAction.tap.index;
    }
    if (hasLongPress == true) {
      actions |= ui.SemanticsAction.longPress.index;
    }
    if (hasScrollLeft == true) {
      actions |= ui.SemanticsAction.scrollLeft.index;
    }
    if (hasScrollRight == true) {
      actions |= ui.SemanticsAction.scrollRight.index;
    }
    if (hasScrollUp == true) {
      actions |= ui.SemanticsAction.scrollUp.index;
    }
    if (hasScrollDown == true) {
      actions |= ui.SemanticsAction.scrollDown.index;
    }
    if (hasIncrease == true) {
      actions |= ui.SemanticsAction.increase.index;
    }
    if (hasDecrease == true) {
      actions |= ui.SemanticsAction.decrease.index;
    }
    if (hasShowOnScreen == true) {
      actions |= ui.SemanticsAction.showOnScreen.index;
    }
    if (hasMoveCursorForwardByCharacter == true) {
      actions |= ui.SemanticsAction.moveCursorForwardByCharacter.index;
    }
    if (hasMoveCursorBackwardByCharacter == true) {
      actions |= ui.SemanticsAction.moveCursorBackwardByCharacter.index;
    }
    if (hasSetSelection == true) {
      actions |= ui.SemanticsAction.setSelection.index;
    }
    if (hasCopy == true) {
      actions |= ui.SemanticsAction.copy.index;
    }
    if (hasCut == true) {
      actions |= ui.SemanticsAction.cut.index;
    }
    if (hasPaste == true) {
      actions |= ui.SemanticsAction.paste.index;
    }
    if (hasDidGainAccessibilityFocus == true) {
      actions |= ui.SemanticsAction.didGainAccessibilityFocus.index;
    }
    if (hasDidLoseAccessibilityFocus == true) {
      actions |= ui.SemanticsAction.didLoseAccessibilityFocus.index;
    }
    if (hasCustomAction == true) {
      actions |= ui.SemanticsAction.customAction.index;
    }
    if (hasDismiss == true) {
      actions |= ui.SemanticsAction.dismiss.index;
    }
    if (hasMoveCursorForwardByWord == true) {
      actions |= ui.SemanticsAction.moveCursorForwardByWord.index;
    }
    if (hasMoveCursorBackwardByWord == true) {
      actions |= ui.SemanticsAction.moveCursorBackwardByWord.index;
    }
    if (hasSetText == true) {
      actions |= ui.SemanticsAction.setText.index;
    }

    // Other attributes
    ui.Rect childRect(SemanticsNodeUpdate child) {
      return transformRect(Matrix4.fromFloat32List(child.transform), child.rect);
    }

    // If a rect is not provided, generate one than covers all children.
    ui.Rect effectiveRect = rect ?? ui.Rect.zero;
    if (children != null && children.isNotEmpty) {
      effectiveRect = childRect(children.first);
      for (final SemanticsNodeUpdate child in children.skip(1)) {
        effectiveRect = effectiveRect.expandToInclude(childRect(child));
      }
    }

    final Int32List childIds = Int32List(children?.length ?? 0);
    if (children != null) {
      for (int i = 0; i < children.length; i++) {
        childIds[i] = children[i].id;
      }
    }

    final SemanticsNodeUpdate update = SemanticsNodeUpdate(
      id: id,
      flags: flags,
      actions: actions,
      maxValueLength: maxValueLength ?? 0,
      currentValueLength: currentValueLength ?? 0,
      textSelectionBase: textSelectionBase ?? 0,
      textSelectionExtent: textSelectionExtent ?? 0,
      platformViewId: platformViewId ?? 0,
      scrollChildren: scrollChildren ?? 0,
      scrollIndex: scrollIndex ?? 0,
      scrollPosition: scrollPosition ?? 0,
      scrollExtentMax: scrollExtentMax ?? 0,
      scrollExtentMin: scrollExtentMin ?? 0,
      rect: effectiveRect,
      label: label ?? '',
      labelAttributes: labelAttributes ?? const <ui.StringAttribute>[],
      hint: hint ?? '',
      hintAttributes: hintAttributes ?? const <ui.StringAttribute>[],
      value: value ?? '',
      valueAttributes: valueAttributes ?? const <ui.StringAttribute>[],
      increasedValue: increasedValue ?? '',
      increasedValueAttributes: increasedValueAttributes ?? const <ui.StringAttribute>[],
      decreasedValue: decreasedValue ?? '',
      decreasedValueAttributes: decreasedValueAttributes ?? const <ui.StringAttribute>[],
      tooltip: tooltip ?? '',
      transform: transform != null ? toMatrix32(transform) : Matrix4.identity().storage,
      elevation: elevation ?? 0,
      thickness: thickness ?? 0,
      childrenInTraversalOrder: childIds,
      childrenInHitTestOrder: childIds,
      additionalActions: additionalActions ?? Int32List(0),
    );
    _nodeUpdates.add(update);
    return update;
  }

  /// Updates the HTML tree from semantics updates accumulated by this builder.
  ///
  /// This builder forgets previous updates and may be reused in future updates.
  Map<int, SemanticsObject> apply() {
    owner.updateSemantics(SemanticsUpdate(nodeUpdates: _nodeUpdates));
    _nodeUpdates.clear();
    return owner.debugSemanticsTree!;
  }

  /// Locates the semantics object with the given [id].
  SemanticsObject getSemanticsObject(int id) {
    return owner.debugSemanticsTree![id]!;
  }

  /// Locates the role manager of the semantics object with the give [id].
  RoleManager? getRoleManager(int id, Role role) {
    return getSemanticsObject(id).debugRoleManagerFor(role);
  }

  /// Locates the [TextField] role manager of the semantics object with the give [id].
  TextField getTextField(int id) {
    return getRoleManager(id, Role.textField)! as TextField;
  }
}

/// Verifies the HTML structure of the current semantics tree.
void expectSemanticsTree(String semanticsHtml) {
  expect(
    canonicalizeHtml(appHostNode.querySelector('flt-semantics')!.outerHtml!),
    canonicalizeHtml(semanticsHtml),
  );
}

/// Finds the first HTML element in the semantics tree used for scrolling.
html.Element? findScrollable() {
  return appHostNode.querySelectorAll('flt-semantics').cast<html.Element?>().firstWhere(
        (html.Element? element) =>
            element!.style.overflow == 'hidden' ||
            element.style.overflowY == 'scroll' ||
            element.style.overflowX == 'scroll',
        orElse: () => null,
      );
}

/// Logs semantics actions dispatched to [ui.window].
class SemanticsActionLogger {
  late StreamController<int> _idLogController;
  late StreamController<ui.SemanticsAction> _actionLogController;

  /// Semantics object ids that dispatched the actions.
  Stream<int> get idLog => _idLog;
  late Stream<int> _idLog;

  /// The actions that were dispatched to [ui.window].
  Stream<ui.SemanticsAction> get actionLog => _actionLog;
  late Stream<ui.SemanticsAction> _actionLog;

  SemanticsActionLogger() {
    _idLogController = StreamController<int>();
    _actionLogController = StreamController<ui.SemanticsAction>();
    _idLog = _idLogController.stream.asBroadcastStream();
    _actionLog = _actionLogController.stream.asBroadcastStream();

    // The browser kicks us out of the test zone when the browser event happens.
    // We memorize the test zone so we can call expect when the callback is
    // fired.
    final Zone testZone = Zone.current;

    ui.window.onSemanticsAction =
        (int id, ui.SemanticsAction action, ByteData? args) {
      _idLogController.add(id);
      _actionLogController.add(action);
      testZone.run(() {
        expect(args, null);
      });
    };
  }
}
