// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.



part of dart.ui;

class SemanticsAction {
  const SemanticsAction._(this.index) : assert(index != null);

  static const int _kTapIndex = 1 << 0;
  static const int _kLongPressIndex = 1 << 1;
  static const int _kScrollLeftIndex = 1 << 2;
  static const int _kScrollRightIndex = 1 << 3;
  static const int _kScrollUpIndex = 1 << 4;
  static const int _kScrollDownIndex = 1 << 5;
  static const int _kIncreaseIndex = 1 << 6;
  static const int _kDecreaseIndex = 1 << 7;
  static const int _kShowOnScreenIndex = 1 << 8;
  static const int _kMoveCursorForwardByCharacterIndex = 1 << 9;
  static const int _kMoveCursorBackwardByCharacterIndex = 1 << 10;
  static const int _kSetSelectionIndex = 1 << 11;
  static const int _kCopyIndex = 1 << 12;
  static const int _kCutIndex = 1 << 13;
  static const int _kPasteIndex = 1 << 14;
  static const int _kDidGainAccessibilityFocusIndex = 1 << 15;
  static const int _kDidLoseAccessibilityFocusIndex = 1 << 16;
  static const int _kCustomActionIndex = 1 << 17;
  static const int _kDismissIndex = 1 << 18;
  static const int _kMoveCursorForwardByWordIndex = 1 << 19;
  static const int _kMoveCursorBackwardByWordIndex = 1 << 20;
  static const int _kSetTextIndex = 1 << 21;

  final int index;

  static const SemanticsAction tap = SemanticsAction._(_kTapIndex);
  static const SemanticsAction longPress = SemanticsAction._(_kLongPressIndex);
  static const SemanticsAction scrollLeft = SemanticsAction._(_kScrollLeftIndex);
  static const SemanticsAction scrollRight = SemanticsAction._(_kScrollRightIndex);
  static const SemanticsAction scrollUp = SemanticsAction._(_kScrollUpIndex);
  static const SemanticsAction scrollDown = SemanticsAction._(_kScrollDownIndex);
  static const SemanticsAction increase = SemanticsAction._(_kIncreaseIndex);
  static const SemanticsAction decrease = SemanticsAction._(_kDecreaseIndex);
  static const SemanticsAction showOnScreen = SemanticsAction._(_kShowOnScreenIndex);
  static const SemanticsAction moveCursorForwardByCharacter = SemanticsAction._(_kMoveCursorForwardByCharacterIndex);
  static const SemanticsAction moveCursorBackwardByCharacter = SemanticsAction._(_kMoveCursorBackwardByCharacterIndex);
  static const SemanticsAction setText = SemanticsAction._(_kSetTextIndex);
  static const SemanticsAction setSelection = SemanticsAction._(_kSetSelectionIndex);
  static const SemanticsAction copy = SemanticsAction._(_kCopyIndex);
  static const SemanticsAction cut = SemanticsAction._(_kCutIndex);
  static const SemanticsAction paste = SemanticsAction._(_kPasteIndex);
  static const SemanticsAction didGainAccessibilityFocus = SemanticsAction._(_kDidGainAccessibilityFocusIndex);
  static const SemanticsAction didLoseAccessibilityFocus = SemanticsAction._(_kDidLoseAccessibilityFocusIndex);
  static const SemanticsAction customAction = SemanticsAction._(_kCustomActionIndex);
  static const SemanticsAction dismiss = SemanticsAction._(_kDismissIndex);
  static const SemanticsAction moveCursorForwardByWord = SemanticsAction._(_kMoveCursorForwardByWordIndex);
  static const SemanticsAction moveCursorBackwardByWord = SemanticsAction._(_kMoveCursorBackwardByWordIndex);

  static const Map<int, SemanticsAction> values = <int, SemanticsAction>{
    _kTapIndex: tap,
    _kLongPressIndex: longPress,
    _kScrollLeftIndex: scrollLeft,
    _kScrollRightIndex: scrollRight,
    _kScrollUpIndex: scrollUp,
    _kScrollDownIndex: scrollDown,
    _kIncreaseIndex: increase,
    _kDecreaseIndex: decrease,
    _kShowOnScreenIndex: showOnScreen,
    _kMoveCursorForwardByCharacterIndex: moveCursorForwardByCharacter,
    _kMoveCursorBackwardByCharacterIndex: moveCursorBackwardByCharacter,
    _kSetSelectionIndex: setSelection,
    _kCopyIndex: copy,
    _kCutIndex: cut,
    _kPasteIndex: paste,
    _kDidGainAccessibilityFocusIndex: didGainAccessibilityFocus,
    _kDidLoseAccessibilityFocusIndex: didLoseAccessibilityFocus,
    _kCustomActionIndex: customAction,
    _kDismissIndex: dismiss,
    _kMoveCursorForwardByWordIndex: moveCursorForwardByWord,
    _kMoveCursorBackwardByWordIndex: moveCursorBackwardByWord,
    _kSetTextIndex: setText,
  };

  @override
  String toString() {
    switch (index) {
      case _kTapIndex:
        return 'SemanticsAction.tap';
      case _kLongPressIndex:
        return 'SemanticsAction.longPress';
      case _kScrollLeftIndex:
        return 'SemanticsAction.scrollLeft';
      case _kScrollRightIndex:
        return 'SemanticsAction.scrollRight';
      case _kScrollUpIndex:
        return 'SemanticsAction.scrollUp';
      case _kScrollDownIndex:
        return 'SemanticsAction.scrollDown';
      case _kIncreaseIndex:
        return 'SemanticsAction.increase';
      case _kDecreaseIndex:
        return 'SemanticsAction.decrease';
      case _kShowOnScreenIndex:
        return 'SemanticsAction.showOnScreen';
      case _kMoveCursorForwardByCharacterIndex:
        return 'SemanticsAction.moveCursorForwardByCharacter';
      case _kMoveCursorBackwardByCharacterIndex:
        return 'SemanticsAction.moveCursorBackwardByCharacter';
      case _kSetSelectionIndex:
        return 'SemanticsAction.setSelection';
      case _kCopyIndex:
        return 'SemanticsAction.copy';
      case _kCutIndex:
        return 'SemanticsAction.cut';
      case _kPasteIndex:
        return 'SemanticsAction.paste';
      case _kDidGainAccessibilityFocusIndex:
        return 'SemanticsAction.didGainAccessibilityFocus';
      case _kDidLoseAccessibilityFocusIndex:
        return 'SemanticsAction.didLoseAccessibilityFocus';
      case _kCustomActionIndex:
        return 'SemanticsAction.customAction';
      case _kDismissIndex:
        return 'SemanticsAction.dismiss';
      case _kMoveCursorForwardByWordIndex:
        return 'SemanticsAction.moveCursorForwardByWord';
      case _kMoveCursorBackwardByWordIndex:
        return 'SemanticsAction.moveCursorBackwardByWord';
      case _kSetTextIndex:
        return 'SemanticsAction.setText';
    }
    assert(false, 'Unhandled index: $index (0x${index.toRadixString(8).padLeft(4, "0")})');
    return '';
  }
}

class SemanticsFlag {
  const SemanticsFlag._(this.index) : assert(index != null);

  final int index;

  static const int _kHasCheckedStateIndex = 1 << 0;
  static const int _kIsCheckedIndex = 1 << 1;
  static const int _kIsSelectedIndex = 1 << 2;
  static const int _kIsButtonIndex = 1 << 3;
  static const int _kIsTextFieldIndex = 1 << 4;
  static const int _kIsFocusedIndex = 1 << 5;
  static const int _kHasEnabledStateIndex = 1 << 6;
  static const int _kIsEnabledIndex = 1 << 7;
  static const int _kIsInMutuallyExclusiveGroupIndex = 1 << 8;
  static const int _kIsHeaderIndex = 1 << 9;
  static const int _kIsObscuredIndex = 1 << 10;
  static const int _kScopesRouteIndex = 1 << 11;
  static const int _kNamesRouteIndex = 1 << 12;
  static const int _kIsHiddenIndex = 1 << 13;
  static const int _kIsImageIndex = 1 << 14;
  static const int _kIsLiveRegionIndex = 1 << 15;
  static const int _kHasToggledStateIndex = 1 << 16;
  static const int _kIsToggledIndex = 1 << 17;
  static const int _kHasImplicitScrollingIndex = 1 << 18;
  static const int _kIsMultilineIndex = 1 << 19;
  static const int _kIsReadOnlyIndex = 1 << 20;
  static const int _kIsFocusableIndex = 1 << 21;
  static const int _kIsLinkIndex = 1 << 22;
  static const int _kIsSliderIndex = 1 << 23;
  static const int _kIsKeyboardKeyIndex = 1 << 24;
  static const int _kIsCheckStateMixedIndex = 1 << 25;

  static const SemanticsFlag hasCheckedState = SemanticsFlag._(_kHasCheckedStateIndex);
  static const SemanticsFlag isChecked = SemanticsFlag._(_kIsCheckedIndex);
  static const SemanticsFlag isSelected = SemanticsFlag._(_kIsSelectedIndex);
  static const SemanticsFlag isButton = SemanticsFlag._(_kIsButtonIndex);
  static const SemanticsFlag isTextField = SemanticsFlag._(_kIsTextFieldIndex);
  static const SemanticsFlag isSlider = SemanticsFlag._(_kIsSliderIndex);
  static const SemanticsFlag isKeyboardKey = SemanticsFlag._(_kIsKeyboardKeyIndex);
  static const SemanticsFlag isReadOnly = SemanticsFlag._(_kIsReadOnlyIndex);
  static const SemanticsFlag isLink = SemanticsFlag._(_kIsLinkIndex);
  static const SemanticsFlag isFocusable = SemanticsFlag._(_kIsFocusableIndex);
  static const SemanticsFlag isFocused = SemanticsFlag._(_kIsFocusedIndex);
  static const SemanticsFlag hasEnabledState = SemanticsFlag._(_kHasEnabledStateIndex);
  static const SemanticsFlag isEnabled = SemanticsFlag._(_kIsEnabledIndex);
  static const SemanticsFlag isInMutuallyExclusiveGroup = SemanticsFlag._(_kIsInMutuallyExclusiveGroupIndex);
  static const SemanticsFlag isHeader = SemanticsFlag._(_kIsHeaderIndex);
  static const SemanticsFlag isObscured = SemanticsFlag._(_kIsObscuredIndex);
  static const SemanticsFlag isMultiline = SemanticsFlag._(_kIsMultilineIndex);
  static const SemanticsFlag scopesRoute = SemanticsFlag._(_kScopesRouteIndex);
  static const SemanticsFlag namesRoute = SemanticsFlag._(_kNamesRouteIndex);
  static const SemanticsFlag isHidden = SemanticsFlag._(_kIsHiddenIndex);
  static const SemanticsFlag isImage = SemanticsFlag._(_kIsImageIndex);
  static const SemanticsFlag isLiveRegion = SemanticsFlag._(_kIsLiveRegionIndex);
  static const SemanticsFlag hasToggledState = SemanticsFlag._(_kHasToggledStateIndex);
  static const SemanticsFlag isToggled = SemanticsFlag._(_kIsToggledIndex);
  static const SemanticsFlag hasImplicitScrolling = SemanticsFlag._(_kHasImplicitScrollingIndex);
  static const SemanticsFlag isCheckStateMixed = SemanticsFlag._(_kIsCheckStateMixedIndex);

  static const Map<int, SemanticsFlag> values = <int, SemanticsFlag>{
    _kHasCheckedStateIndex: hasCheckedState,
    _kIsCheckedIndex: isChecked,
    _kIsSelectedIndex: isSelected,
    _kIsButtonIndex: isButton,
    _kIsTextFieldIndex: isTextField,
    _kIsFocusedIndex: isFocused,
    _kHasEnabledStateIndex: hasEnabledState,
    _kIsEnabledIndex: isEnabled,
    _kIsInMutuallyExclusiveGroupIndex: isInMutuallyExclusiveGroup,
    _kIsHeaderIndex: isHeader,
    _kIsObscuredIndex: isObscured,
    _kScopesRouteIndex: scopesRoute,
    _kNamesRouteIndex: namesRoute,
    _kIsHiddenIndex: isHidden,
    _kIsImageIndex: isImage,
    _kIsLiveRegionIndex: isLiveRegion,
    _kHasToggledStateIndex: hasToggledState,
    _kIsToggledIndex: isToggled,
    _kHasImplicitScrollingIndex: hasImplicitScrolling,
    _kIsMultilineIndex: isMultiline,
    _kIsReadOnlyIndex: isReadOnly,
    _kIsFocusableIndex: isFocusable,
    _kIsLinkIndex: isLink,
    _kIsSliderIndex: isSlider,
    _kIsKeyboardKeyIndex: isKeyboardKey,
    _kIsCheckStateMixedIndex: isCheckStateMixed,
  };

  @override
  String toString() {
    switch (index) {
      case _kHasCheckedStateIndex:
        return 'SemanticsFlag.hasCheckedState';
      case _kIsCheckedIndex:
        return 'SemanticsFlag.isChecked';
      case _kIsSelectedIndex:
        return 'SemanticsFlag.isSelected';
      case _kIsButtonIndex:
        return 'SemanticsFlag.isButton';
      case _kIsTextFieldIndex:
        return 'SemanticsFlag.isTextField';
      case _kIsFocusedIndex:
        return 'SemanticsFlag.isFocused';
      case _kHasEnabledStateIndex:
        return 'SemanticsFlag.hasEnabledState';
      case _kIsEnabledIndex:
        return 'SemanticsFlag.isEnabled';
      case _kIsInMutuallyExclusiveGroupIndex:
        return 'SemanticsFlag.isInMutuallyExclusiveGroup';
      case _kIsHeaderIndex:
        return 'SemanticsFlag.isHeader';
      case _kIsObscuredIndex:
        return 'SemanticsFlag.isObscured';
      case _kScopesRouteIndex:
        return 'SemanticsFlag.scopesRoute';
      case _kNamesRouteIndex:
        return 'SemanticsFlag.namesRoute';
      case _kIsHiddenIndex:
        return 'SemanticsFlag.isHidden';
      case _kIsImageIndex:
        return 'SemanticsFlag.isImage';
      case _kIsLiveRegionIndex:
        return 'SemanticsFlag.isLiveRegion';
      case _kHasToggledStateIndex:
        return 'SemanticsFlag.hasToggledState';
      case _kIsToggledIndex:
        return 'SemanticsFlag.isToggled';
      case _kHasImplicitScrollingIndex:
        return 'SemanticsFlag.hasImplicitScrolling';
      case _kIsMultilineIndex:
        return 'SemanticsFlag.isMultiline';
      case _kIsReadOnlyIndex:
        return 'SemanticsFlag.isReadOnly';
      case _kIsFocusableIndex:
        return 'SemanticsFlag.isFocusable';
      case _kIsLinkIndex:
        return 'SemanticsFlag.isLink';
      case _kIsSliderIndex:
        return 'SemanticsFlag.isSlider';
      case _kIsKeyboardKeyIndex:
        return 'SemanticsFlag.isKeyboardKey';
      case _kIsCheckStateMixedIndex:
        return 'SemanticsFlag.isCheckStateMixed';
    }
    assert(false, 'Unhandled index: $index (0x${index.toRadixString(8).padLeft(4, "0")})');
    return '';
  }
}

/// An object that creates [SemanticsUpdate] objects.
///
/// Once created, the [SemanticsUpdate] objects can be passed to
/// [PlatformDispatcher.updateSemantics] to update the semantics conveyed to the
/// user.
class SemanticsUpdateBuilder {
  /// Creates an empty [SemanticsUpdateBuilder] object.
    SemanticsUpdateBuilder() { _constructor(); }
  void _constructor() { throw UnimplementedError(); }

  /// Update the information associated with the node with the given `id`.
  ///
  /// The semantics nodes form a tree, with the root of the tree always having
  /// an id of zero. The `childrenInTraversalOrder` and `childrenInHitTestOrder`
  /// are the ids of the nodes that are immediate children of this node. The
  /// former enumerates children in traversal order, and the latter enumerates
  /// the same children in the hit test order. The two lists must have the same
  /// length and contain the same ids. They may only differ in the order the
  /// ids are listed in. For more information about different child orders, see
  /// [DebugSemanticsDumpOrder].
  ///
  /// The system retains the nodes that are currently reachable from the root.
  /// A given update need not contain information for nodes that do not change
  /// in the update. If a node is not reachable from the root after an update,
  /// the node will be discarded from the tree.
  ///
  /// The `flags` are a bit field of [SemanticsFlag]s that apply to this node.
  ///
  /// The `actions` are a bit field of [SemanticsAction]s that can be undertaken
  /// by this node. If the user wishes to undertake one of these actions on this
  /// node, the [PlatformDispatcher.onSemanticsAction] will be called with `id`
  /// and one of the possible [SemanticsAction]s. Because the semantics tree is
  /// maintained asynchronously, the [PlatformDispatcher.onSemanticsAction]
  /// callback might be called with an action that is no longer possible.
  ///
  /// The `label` is a string that describes this node. The `value` property
  /// describes the current value of the node as a string. The `increasedValue`
  /// string will become the `value` string after a [SemanticsAction.increase]
  /// action is performed. The `decreasedValue` string will become the `value`
  /// string after a [SemanticsAction.decrease] action is performed. The `hint`
  /// string describes what result an action performed on this node has. The
  /// reading direction of all these strings is given by `textDirection`.
  ///
  /// The fields `textSelectionBase` and `textSelectionExtent` describe the
  /// currently selected text within `value`. A value of -1 indicates no
  /// current text selection base or extent.
  ///
  /// The field `maxValueLength` is used to indicate that an editable text
  /// field has a limit on the number of characters entered. If it is -1 there
  /// is no limit on the number of characters entered. The field
  /// `currentValueLength` indicates how much of that limit has already been
  /// used up. When `maxValueLength` is >= 0, `currentValueLength` must also be
  /// >= 0, otherwise it should be specified to be -1.
  ///
  /// The field `platformViewId` references the platform view, whose semantics
  /// nodes will be added as children to this node. If a platform view is
  /// specified, `childrenInHitTestOrder` and `childrenInTraversalOrder` must
  /// be empty. A value of -1 indicates that this node is not associated with a
  /// platform view.
  ///
  /// For scrollable nodes `scrollPosition` describes the current scroll
  /// position in logical pixel. `scrollExtentMax` and `scrollExtentMin`
  /// describe the maximum and minimum in-rage values that `scrollPosition` can
  /// be. Both or either may be infinity to indicate unbound scrolling. The
  /// value for `scrollPosition` can (temporarily) be outside this range, for
  /// example during an overscroll. `scrollChildren` is the count of the
  /// total number of child nodes that contribute semantics and `scrollIndex`
  /// is the index of the first visible child node that contributes semantics.
  ///
  /// The `rect` is the region occupied by this node in its own coordinate
  /// system.
  ///
  /// The `transform` is a matrix that maps this node's coordinate system into
  /// its parent's coordinate system.
  ///
  /// The `elevation` describes the distance in z-direction between this node
  /// and the `elevation` of the parent.
  ///
  /// The `thickness` describes how much space this node occupies in the
  /// z-direction starting at `elevation`. Basically, in the z-direction the
  /// node starts at `elevation` above the parent and ends at `elevation` +
  /// `thickness` above the parent.
  void updateNode({
    required int id,
    required int flags,
    required int actions,
    required int maxValueLength,
    required int currentValueLength,
    required int textSelectionBase,
    required int textSelectionExtent,
    required int platformViewId,
    required int scrollChildren,
    required int scrollIndex,
    required double scrollPosition,
    required double scrollExtentMax,
    required double scrollExtentMin,
    required double elevation,
    required double thickness,
    required Rect rect,
    required String label,
    required List<StringAttribute> labelAttributes,
    required String value,
    required List<StringAttribute> valueAttributes,
    required String increasedValue,
    required List<StringAttribute> increasedValueAttributes,
    required String decreasedValue,
    required List<StringAttribute> decreasedValueAttributes,
    required String hint,
    required List<StringAttribute> hintAttributes,
    String? tooltip,
    TextDirection? textDirection,
    required Float64List transform,
    required Int32List childrenInTraversalOrder,
    required Int32List childrenInHitTestOrder,
    required Int32List additionalActions,
  }) {
    assert(_matrix4IsValid(transform));
    assert(
      // ignore: unnecessary_null_comparison
      scrollChildren == 0 || scrollChildren == null || (scrollChildren > 0 && childrenInHitTestOrder != null),
      'If a node has scrollChildren, it must have childrenInHitTestOrder',
    );
    _updateNode(
      id,
      flags,
      actions,
      maxValueLength,
      currentValueLength,
      textSelectionBase,
      textSelectionExtent,
      platformViewId,
      scrollChildren,
      scrollIndex,
      scrollPosition,
      scrollExtentMax,
      scrollExtentMin,
      rect.left,
      rect.top,
      rect.right,
      rect.bottom,
      elevation,
      thickness,
      label,
      hint,
      value,
      increasedValue,
      decreasedValue,
      textDirection != null ? textDirection.index + 1 : 0,
      transform,
      childrenInTraversalOrder,
      childrenInHitTestOrder,
      additionalActions,
    );
  }
  void _updateNode(
    int id,
    int flags,
    int actions,
    int maxValueLength,
    int currentValueLength,
    int textSelectionBase,
    int textSelectionExtent,
    int platformViewId,
    int scrollChildren,
    int scrollIndex,
    double scrollPosition,
    double scrollExtentMax,
    double scrollExtentMin,
    double left,
    double top,
    double right,
    double bottom,
    double elevation,
    double thickness,
    String label,
    String hint,
    String value,
    String increasedValue,
    String decreasedValue,
    int textDirection,
    Float64List transform,
    Int32List childrenInTraversalOrder,
    Int32List childrenInHitTestOrder,
    Int32List additionalActions,
  ) { throw UnimplementedError(); }

  /// Update the custom semantics action associated with the given `id`.
  ///
  /// The name of the action exposed to the user is the `label`. For overridden
  /// standard actions this value is ignored.
  ///
  /// The `hint` should describe what happens when an action occurs, not the
  /// manner in which a tap is accomplished. For example, use "delete" instead
  /// of "double tap to delete".
  ///
  /// The text direction of the `hint` and `label` is the same as the global
  /// window.
  ///
  /// For overridden standard actions, `overrideId` corresponds with a
  /// [SemanticsAction.index] value. For custom actions this argument should not be
  /// provided.
  void updateCustomAction({required int id, String? label, String? hint, int overrideId = -1}) {
    assert(id != null); // ignore: unnecessary_null_comparison
    assert(overrideId != null); // ignore: unnecessary_null_comparison
    _updateCustomAction(id, label, hint, overrideId);
  }
  void _updateCustomAction(
      int id,
      String? label,
      String? hint,
      int overrideId) { throw UnimplementedError(); }

  /// Creates a [SemanticsUpdate] object that encapsulates the updates recorded
  /// by this object.
  ///
  /// The returned object can be passed to [PlatformDispatcher.updateSemantics]
  /// to actually update the semantics retained by the system.
  SemanticsUpdate build() {
    final SemanticsUpdate semanticsUpdate = SemanticsUpdate._();
    _build(semanticsUpdate);
    return semanticsUpdate;
  }
  void _build(SemanticsUpdate outSemanticsUpdate) { throw UnimplementedError(); }
}

/// An opaque object representing a batch of semantics updates.
///
/// To create a SemanticsUpdate object, use a [SemanticsUpdateBuilder].
///
/// Semantics updates can be applied to the system's retained semantics tree
/// using the [PlatformDispatcher.updateSemantics] method.
class SemanticsUpdate {
  /// This class is created by the engine, and should not be instantiated
  /// or extended directly.
  ///
  /// To create a SemanticsUpdate object, use a [SemanticsUpdateBuilder].
    SemanticsUpdate._();

  /// Releases the resources used by this semantics update.
  ///
  /// After calling this function, the semantics update is cannot be used
  /// further.
  void dispose() { throw UnimplementedError(); }
}

abstract class StringAttribute {
  StringAttribute._({
    required this.range,
  });

  final TextRange range;

  StringAttribute copy({required TextRange range});
}

class SpellOutStringAttribute extends StringAttribute {
  SpellOutStringAttribute({
    required super.range,
  }) : super._();

  @override
  StringAttribute copy({required TextRange range}) {
    return SpellOutStringAttribute(range: range);
  }

  @override
  String toString() {
    return 'SpellOutStringAttribute($range)';
  }
}

class LocaleStringAttribute extends StringAttribute {
  LocaleStringAttribute({
    required super.range,
    required this.locale,
  }) : super._();

  final Locale locale;

  @override
  StringAttribute copy({required TextRange range}) {
    return LocaleStringAttribute(range: range, locale: locale);
  }

  @override
  String toString() {
    return 'LocaleStringAttribute($range, ${locale.toLanguageTag()})';
  }
}
