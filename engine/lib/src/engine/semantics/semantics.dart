// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ui/ui.dart' as ui;

import '../../engine.dart'  show registerHotRestartListener;
import '../alarm_clock.dart';
import '../browser_detection.dart';
import '../configuration.dart';
import '../dom_renderer.dart';
import '../platform_dispatcher.dart';
import '../util.dart';
import '../vector_math.dart';
import 'checkable.dart';
import 'image.dart';
import 'incrementable.dart';
import 'label_and_value.dart';
import 'live_region.dart';
import 'scrollable.dart';
import 'semantics_helper.dart';
import 'tappable.dart';
import 'text_field.dart';

/// Contains updates for the semantics tree.
///
/// This class provides private engine-side API that's not available in the
/// `dart:ui` [ui.SemanticsUpdate].
class SemanticsUpdate implements ui.SemanticsUpdate {
  SemanticsUpdate({List<SemanticsNodeUpdate>? nodeUpdates})
      : _nodeUpdates = nodeUpdates;

  /// Updates for individual nodes.
  final List<SemanticsNodeUpdate>? _nodeUpdates;

  @override
  void dispose() {
    // Intentionally left blank. This method exists for API compatibility with
    // Flutter, but it is not required as memory resource management is handled
    // by JavaScript's garbage collector.
  }
}

/// Updates the properties of a particular semantics node.
class SemanticsNodeUpdate {
  SemanticsNodeUpdate({
    required this.id,
    required this.flags,
    required this.actions,
    required this.maxValueLength,
    required this.currentValueLength,
    required this.textSelectionBase,
    required this.textSelectionExtent,
    required this.platformViewId,
    required this.scrollChildren,
    required this.scrollIndex,
    required this.scrollPosition,
    required this.scrollExtentMax,
    required this.scrollExtentMin,
    required this.rect,
    required this.label,
    required this.labelAttributes,
    required this.hint,
    required this.hintAttributes,
    required this.value,
    required this.valueAttributes,
    required this.increasedValue,
    required this.increasedValueAttributes,
    required this.decreasedValue,
    required this.decreasedValueAttributes,
    this.tooltip,
    this.textDirection,
    required this.transform,
    required this.elevation,
    required this.thickness,
    required this.childrenInTraversalOrder,
    required this.childrenInHitTestOrder,
    required this.additionalActions,
  });

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final int id;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final int flags;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final int actions;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final int maxValueLength;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final int currentValueLength;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final int textSelectionBase;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final int textSelectionExtent;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final int platformViewId;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final int scrollChildren;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final int scrollIndex;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final double scrollPosition;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final double scrollExtentMax;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final double scrollExtentMin;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final ui.Rect rect;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final String label;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final List<ui.StringAttribute> labelAttributes;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final String hint;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final List<ui.StringAttribute> hintAttributes;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final String value;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final List<ui.StringAttribute> valueAttributes;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final String increasedValue;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final List<ui.StringAttribute> increasedValueAttributes;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final String decreasedValue;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final List<ui.StringAttribute> decreasedValueAttributes;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final String? tooltip;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final ui.TextDirection? textDirection;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final Float32List transform;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final Int32List childrenInTraversalOrder;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final Int32List childrenInHitTestOrder;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final Int32List additionalActions;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final double elevation;

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  final double thickness;
}

/// Identifies one of the roles a [SemanticsObject] plays.
enum Role {
  /// Supports incrementing and/or decrementing its value.
  incrementable,

  /// Able to scroll its contents vertically or horizontally.
  scrollable,

  /// Contains a label or a value.
  ///
  /// The two are combined into the same role because they interact with each
  /// other.
  labelAndValue,

  /// Accepts tap or click gestures.
  tappable,

  /// Contains editable text.
  textField,

  /// A control that has a checked state, such as a check box or a radio button.
  checkable,

  /// Visual only element.
  image,

  /// Contains a region whose changes will be announced to the screen reader
  /// without having to be in focus.
  ///
  /// These regions can be a snackbar or a text field error. Once identified
  /// with this role, they will be able to get the assistive technology's
  /// attention right away.
  liveRegion,
}

/// A function that creates a [RoleManager] for a [SemanticsObject].
typedef RoleManagerFactory = RoleManager Function(SemanticsObject object);

final Map<Role, RoleManagerFactory> _roleFactories = <Role, RoleManagerFactory>{
  Role.incrementable: (SemanticsObject object) => Incrementable(object),
  Role.scrollable: (SemanticsObject object) => Scrollable(object),
  Role.labelAndValue: (SemanticsObject object) => LabelAndValue(object),
  Role.tappable: (SemanticsObject object) => Tappable(object),
  Role.textField: (SemanticsObject object) => TextField(object),
  Role.checkable: (SemanticsObject object) => Checkable(object),
  Role.image: (SemanticsObject object) => ImageRoleManager(object),
  Role.liveRegion: (SemanticsObject object) => LiveRegion(object),
};

/// Provides the functionality associated with the role of the given
/// [semanticsObject].
///
/// The role is determined by [ui.SemanticsFlag]s and [ui.SemanticsAction]s set
/// on the object.
abstract class RoleManager {
  /// Initializes a role for [semanticsObject].
  ///
  /// A single role object manages exactly one [SemanticsObject].
  RoleManager(this.role, this.semanticsObject)
      : assert(semanticsObject != null); // ignore: unnecessary_null_comparison

  /// Role identifier.
  final Role role;

  /// The semantics object managed by this role.
  final SemanticsObject semanticsObject;

  /// Called immediately after the [semanticsObject] updates some of its fields.
  ///
  /// A concrete implementation of this method would typically use some of the
  /// "is*Dirty" getters to find out exactly what's changed and apply the
  /// minimum DOM updates.
  void update();

  /// Called when [semanticsObject] is removed, or when it changes its role such
  /// that this role is no longer relevant.
  ///
  /// This method is expected to remove role-specific functionality from the
  /// DOM. In particular, this method is the appropriate place to call
  /// [EngineSemanticsOwner.removeGestureModeListener] if this role reponds to
  /// gesture mode changes.
  void dispose();
}

/// Instantiation of a framework-side semantics node in the DOM.
///
/// Instances of this class are retained from frame to frame. Each instance is
/// permanently attached to an [id] and a DOM [element] used to convey semantics
/// information to the browser.
class SemanticsObject {
  /// Creates a semantics tree node with the given [id] and [owner].
  SemanticsObject(this.id, this.owner) {
    // DOM nodes created for semantics objects are positioned absolutely using
    // transforms.
    element.style.position = 'absolute';

    // The root node has some properties that other nodes do not.
    if (id == 0 && !configuration.debugShowSemanticsNodes) {
      // Make all semantics transparent. We use `filter` instead of `opacity`
      // attribute because `filter` is stronger. `opacity` does not apply to
      // some elements, particularly on iOS, such as the slider thumb and track.
      //
      // We use transparency instead of "visibility:hidden" or "display:none"
      // so that a screen reader does not ignore these elements.
      element.style.filter = 'opacity(0%)';

      // Make text explicitly transparent to signal to the browser that no
      // rasterization needs to be done.
      element.style.color = 'rgba(0,0,0,0)';
    }

    // Make semantic elements visible for debugging by outlining them using a
    // green border. We do not use `border` attribute because it affects layout
    // (`outline` does not).
    if (configuration.debugShowSemanticsNodes) {
      element.style.outline = '1px solid green';
    }
  }

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  int get flags => _flags;
  int _flags = 0;

  /// Whether the [flags] field has been updated but has not been applied to the
  /// DOM yet.
  bool get isFlagsDirty => _isDirty(_flagsIndex);
  static const int _flagsIndex = 1 << 0;
  void _markFlagsDirty() {
    _dirtyFields |= _flagsIndex;
  }

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  int? get actions => _actions;
  int? _actions;

  static const int _actionsIndex = 1 << 1;

  /// Whether the [actions] field has been updated but has not been applied to
  /// the DOM yet.
  bool get isActionsDirty => _isDirty(_actionsIndex);
  void _markActionsDirty() {
    _dirtyFields |= _actionsIndex;
  }

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  int? get textSelectionBase => _textSelectionBase;
  int? _textSelectionBase;

  static const int _textSelectionBaseIndex = 1 << 2;

  /// Whether the [textSelectionBase] field has been updated but has not been
  /// applied to the DOM yet.
  bool get isTextSelectionBaseDirty => _isDirty(_textSelectionBaseIndex);
  void _markTextSelectionBaseDirty() {
    _dirtyFields |= _textSelectionBaseIndex;
  }

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  int? get textSelectionExtent => _textSelectionExtent;
  int? _textSelectionExtent;

  static const int _textSelectionExtentIndex = 1 << 3;

  /// Whether the [textSelectionExtent] field has been updated but has not been
  /// applied to the DOM yet.
  bool get isTextSelectionExtentDirty => _isDirty(_textSelectionExtentIndex);
  void _markTextSelectionExtentDirty() {
    _dirtyFields |= _textSelectionExtentIndex;
  }

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  int? get scrollChildren => _scrollChildren;
  int? _scrollChildren;

  static const int _scrollChildrenIndex = 1 << 4;

  /// Whether the [scrollChildren] field has been updated but has not been
  /// applied to the DOM yet.
  bool get isScrollChildrenDirty => _isDirty(_scrollChildrenIndex);
  void _markScrollChildrenDirty() {
    _dirtyFields |= _scrollChildrenIndex;
  }

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  int? get scrollIndex => _scrollIndex;
  int? _scrollIndex;

  static const int _scrollIndexIndex = 1 << 5;

  /// Whether the [scrollIndex] field has been updated but has not been
  /// applied to the DOM yet.
  bool get isScrollIndexDirty => _isDirty(_scrollIndexIndex);
  void _markScrollIndexDirty() {
    _dirtyFields |= _scrollIndexIndex;
  }

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  double? get scrollPosition => _scrollPosition;
  double? _scrollPosition;

  static const int _scrollPositionIndex = 1 << 6;

  /// Whether the [scrollPosition] field has been updated but has not been
  /// applied to the DOM yet.
  bool get isScrollPositionDirty => _isDirty(_scrollPositionIndex);
  void _markScrollPositionDirty() {
    _dirtyFields |= _scrollPositionIndex;
  }

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  double? get scrollExtentMax => _scrollExtentMax;
  double? _scrollExtentMax;

  static const int _scrollExtentMaxIndex = 1 << 7;

  /// Whether the [scrollExtentMax] field has been updated but has not been
  /// applied to the DOM yet.
  bool get isScrollExtentMaxDirty => _isDirty(_scrollExtentMaxIndex);
  void _markScrollExtentMaxDirty() {
    _dirtyFields |= _scrollExtentMaxIndex;
  }

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  double? get scrollExtentMin => _scrollExtentMin;
  double? _scrollExtentMin;

  static const int _scrollExtentMinIndex = 1 << 8;

  /// Whether the [scrollExtentMin] field has been updated but has not been
  /// applied to the DOM yet.
  bool get isScrollExtentMinDirty => _isDirty(_scrollExtentMinIndex);
  void _markScrollExtentMinDirty() {
    _dirtyFields |= _scrollExtentMinIndex;
  }

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  ui.Rect? get rect => _rect;
  ui.Rect? _rect;

  static const int _rectIndex = 1 << 9;

  /// Whether the [rect] field has been updated but has not been
  /// applied to the DOM yet.
  bool get isRectDirty => _isDirty(_rectIndex);
  void _markRectDirty() {
    _dirtyFields |= _rectIndex;
  }

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  String? get label => _label;
  String? _label;

  /// See [ui.SemanticsUpdateBuilder.updateNode]
  List<ui.StringAttribute>? get labelAttributes => _labelAttributes;
  List<ui.StringAttribute>? _labelAttributes;

  /// Whether this object contains a non-empty label.
  bool get hasLabel => _label != null && _label!.isNotEmpty;

  static const int _labelIndex = 1 << 10;

  /// Whether the [label] field has been updated but has not been
  /// applied to the DOM yet.
  bool get isLabelDirty => _isDirty(_labelIndex);
  void _markLabelDirty() {
    _dirtyFields |= _labelIndex;
  }

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  String? get hint => _hint;
  String? _hint;

  /// See [ui.SemanticsUpdateBuilder.updateNode]
  List<ui.StringAttribute>? get hintAttributes => _hintAttributes;
  List<ui.StringAttribute>? _hintAttributes;

  static const int _hintIndex = 1 << 11;

  /// Whether the [hint] field has been updated but has not been
  /// applied to the DOM yet.
  bool get isHintDirty => _isDirty(_hintIndex);
  void _markHintDirty() {
    _dirtyFields |= _hintIndex;
  }

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  String? get value => _value;
  String? _value;

  /// See [ui.SemanticsUpdateBuilder.updateNode]
  List<ui.StringAttribute>? get valueAttributes => _valueAttributes;
  List<ui.StringAttribute>? _valueAttributes;

  /// Whether this object contains a non-empty value.
  bool get hasValue => _value != null && _value!.isNotEmpty;

  static const int _valueIndex = 1 << 12;

  /// Whether the [value] field has been updated but has not been
  /// applied to the DOM yet.
  bool get isValueDirty => _isDirty(_valueIndex);
  void _markValueDirty() {
    _dirtyFields |= _valueIndex;
  }

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  String? get increasedValue => _increasedValue;
  String? _increasedValue;

  /// See [ui.SemanticsUpdateBuilder.updateNode]
  List<ui.StringAttribute>? get increasedValueAttributes => _increasedValueAttributes;
  List<ui.StringAttribute>? _increasedValueAttributes;

  static const int _increasedValueIndex = 1 << 13;

  /// Whether the [increasedValue] field has been updated but has not been
  /// applied to the DOM yet.
  bool get isIncreasedValueDirty => _isDirty(_increasedValueIndex);
  void _markIncreasedValueDirty() {
    _dirtyFields |= _increasedValueIndex;
  }

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  String? get decreasedValue => _decreasedValue;
  String? _decreasedValue;

  /// See [ui.SemanticsUpdateBuilder.updateNode]
  List<ui.StringAttribute>? get decreasedValueAttributes => _decreasedValueAttributes;
  List<ui.StringAttribute>? _decreasedValueAttributes;

  static const int _decreasedValueIndex = 1 << 14;

  /// Whether the [decreasedValue] field has been updated but has not been
  /// applied to the DOM yet.
  bool get isDecreasedValueDirty => _isDirty(_decreasedValueIndex);
  void _markDecreasedValueDirty() {
    _dirtyFields |= _decreasedValueIndex;
  }

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  ui.TextDirection? get textDirection => _textDirection;
  ui.TextDirection? _textDirection;

  static const int _textDirectionIndex = 1 << 15;

  /// Whether the [textDirection] field has been updated but has not been
  /// applied to the DOM yet.
  bool get isTextDirectionDirty => _isDirty(_textDirectionIndex);
  void _markTextDirectionDirty() {
    _dirtyFields |= _textDirectionIndex;
  }

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  Float32List? get transform => _transform;
  Float32List? _transform;

  static const int _transformIndex = 1 << 16;

  /// Whether the [transform] field has been updated but has not been
  /// applied to the DOM yet.
  bool get isTransformDirty => _isDirty(_transformIndex);
  void _markTransformDirty() {
    _dirtyFields |= _transformIndex;
  }

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  Int32List? get childrenInTraversalOrder => _childrenInTraversalOrder;
  Int32List? _childrenInTraversalOrder;

  static const int _childrenInTraversalOrderIndex = 1 << 19;

  /// Whether the [childrenInTraversalOrder] field has been updated but has not
  /// been applied to the DOM yet.
  bool get isChildrenInTraversalOrderDirty =>
      _isDirty(_childrenInTraversalOrderIndex);
  void _markChildrenInTraversalOrderDirty() {
    _dirtyFields |= _childrenInTraversalOrderIndex;
  }

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  Int32List? get childrenInHitTestOrder => _childrenInHitTestOrder;
  Int32List? _childrenInHitTestOrder;

  static const int _childrenInHitTestOrderIndex = 1 << 20;

  /// Whether the [childrenInHitTestOrder] field has been updated but has not
  /// been applied to the DOM yet.
  bool get isChildrenInHitTestOrderDirty =>
      _isDirty(_childrenInHitTestOrderIndex);
  void _markChildrenInHitTestOrderDirty() {
    _dirtyFields |= _childrenInHitTestOrderIndex;
  }

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  Int32List? get additionalActions => _additionalActions;
  Int32List? _additionalActions;

  static const int _additionalActionsIndex = 1 << 21;

  /// Whether the [additionalActions] field has been updated but has not been
  /// applied to the DOM yet.
  bool get isAdditionalActionsDirty => _isDirty(_additionalActionsIndex);
  void _markAdditionalActionsDirty() {
    _dirtyFields |= _additionalActionsIndex;
  }

  /// See [ui.SemanticsUpdateBuilder.updateNode].
  String? get tooltip => _tooltip;
  String? _tooltip;

  /// Whether this object contains a non-empty tooltip.
  bool get hasTooltip => _tooltip != null && _tooltip!.isNotEmpty;

  static const int _tooltipIndex = 1 << 22;

  /// Whether the [tooltip] field has been updated but has not been
  /// applied to the DOM yet.
  bool get isTooltipDirty => _isDirty(_tooltipIndex);
  void _markTooltipDirty() {
    _dirtyFields |= _tooltipIndex;
  }

  /// A unique permanent identifier of the semantics node in the tree.
  final int id;

  /// Controls the semantics tree that this node participates in.
  final EngineSemanticsOwner owner;

  /// The DOM element used to convey semantics information to the browser.
  final html.Element element = html.Element.tag('flt-semantics');

  /// Bitfield showing which fields have been updated but have not yet been
  /// applied to the DOM.
  ///
  /// Instead of use this field directly, prefer using one of the "is*Dirty"
  /// getters, e.g. [isFlagsDirty].
  ///
  /// The bitfield supports up to 31 bits.
  int _dirtyFields = -1; // initial value is when all relevant bits are set

  /// Whether the field corresponding to the [fieldIndex] has been updated.
  bool _isDirty(int fieldIndex) => (_dirtyFields & fieldIndex) != 0;

  /// Returns the HTML element that contains the HTML elements of direct
  /// children of this object.
  ///
  /// The element is created lazily. When the child list is empty this element
  /// is not created. This is necessary for "aria-label" to function correctly.
  /// The browser will ignore the [label] of HTML element that contain child
  /// elements.
  html.Element? getOrCreateChildContainer() {
    if (_childContainerElement == null) {
      _childContainerElement = html.Element.tag('flt-semantics-container');
      _childContainerElement!.style.position = 'absolute';
      element.append(_childContainerElement!);
    }
    return _childContainerElement;
  }

  /// The element that contains the elements belonging to the child semantics
  /// nodes.
  ///
  /// This element is used to correct for [_rect] offsets. It is only non-`null`
  /// when there are non-zero children (i.e. when [hasChildren] is `true`).
  html.Element? _childContainerElement;

  /// The parent of this semantics object.
  SemanticsObject? _parent;

  /// Whether this node currently has a given [SemanticsFlag].
  bool hasFlag(ui.SemanticsFlag flag) => _flags & flag.index != 0;

  /// Whether [actions] contains the given action.
  bool hasAction(ui.SemanticsAction action) => (_actions! & action.index) != 0;

  /// Whether this object represents a vertically scrollable area.
  bool get isVerticalScrollContainer =>
      hasAction(ui.SemanticsAction.scrollDown) ||
      hasAction(ui.SemanticsAction.scrollUp);

  bool get hasFocus => hasFlag(ui.SemanticsFlag.isFocused);

  /// Whether this object represents a hotizontally scrollable area.
  bool get isHorizontalScrollContainer =>
      hasAction(ui.SemanticsAction.scrollLeft) ||
      hasAction(ui.SemanticsAction.scrollRight);

  /// Whether this object has a non-empty list of children.
  bool get hasChildren =>
      _childrenInTraversalOrder != null && _childrenInTraversalOrder!.isNotEmpty;

  /// Whether this object represents an editable text field.
  bool get isTextField => hasFlag(ui.SemanticsFlag.isTextField);

  /// Whether this object needs screen readers attention right away.
  bool get isLiveRegion =>
      hasFlag(ui.SemanticsFlag.isLiveRegion) &&
      !hasFlag(ui.SemanticsFlag.isHidden);

  /// Whether this object represents an image with no tappable functionality.
  bool get isVisualOnly =>
      hasFlag(ui.SemanticsFlag.isImage) &&
      !hasAction(ui.SemanticsAction.tap) &&
      !hasFlag(ui.SemanticsFlag.isButton);

  /// Whether this object carry enabled/disabled state (and if so whether it is
  /// enabled).
  ///
  /// See [EnabledState] for more details.
  EnabledState enabledState() {
    if (hasFlag(ui.SemanticsFlag.hasEnabledState)) {
      if (hasFlag(ui.SemanticsFlag.isEnabled)) {
        return EnabledState.enabled;
      } else {
        return EnabledState.disabled;
      }
    } else {
      return EnabledState.noOpinion;
    }
  }

  /// Updates this object from data received from a semantics [update].
  ///
  /// This method creates [SemanticsObject]s for the direct children of this
  /// object. However, it does not recursively populate them.
  void updateWith(SemanticsNodeUpdate update) {
    // Update all field values and their corresponding dirty flags before
    // applying the updates to the DOM.
    assert(update.flags != null); // ignore: unnecessary_null_comparison
    if (_flags != update.flags) {
      _flags = update.flags;
      _markFlagsDirty();
    }

    if (_value != update.value) {
      _value = update.value;
      _markValueDirty();
    }

    if (_valueAttributes != update.valueAttributes) {
      _valueAttributes = update.valueAttributes;
      _markValueDirty();
    }

    if (_label != update.label) {
      _label = update.label;
      _markLabelDirty();
    }

    if (_labelAttributes != update.labelAttributes) {
      _labelAttributes = update.labelAttributes;
      _markLabelDirty();
    }

    if (_rect != update.rect) {
      _rect = update.rect;
      _markRectDirty();
    }

    if (_transform != update.transform) {
      _transform = update.transform;
      _markTransformDirty();
    }

    if (_scrollPosition != update.scrollPosition) {
      _scrollPosition = update.scrollPosition;
      _markScrollPositionDirty();
    }

    if (_actions != update.actions) {
      _actions = update.actions;
      _markActionsDirty();
    }

    if (_textSelectionBase != update.textSelectionBase) {
      _textSelectionBase = update.textSelectionBase;
      _markTextSelectionBaseDirty();
    }

    if (_textSelectionExtent != update.textSelectionExtent) {
      _textSelectionExtent = update.textSelectionExtent;
      _markTextSelectionExtentDirty();
    }

    if (_scrollChildren != update.scrollChildren) {
      _scrollChildren = update.scrollChildren;
      _markScrollChildrenDirty();
    }

    if (_scrollIndex != update.scrollIndex) {
      _scrollIndex = update.scrollIndex;
      _markScrollIndexDirty();
    }

    if (_scrollExtentMax != update.scrollExtentMax) {
      _scrollExtentMax = update.scrollExtentMax;
      _markScrollExtentMaxDirty();
    }

    if (_scrollExtentMin != update.scrollExtentMin) {
      _scrollExtentMin = update.scrollExtentMin;
      _markScrollExtentMinDirty();
    }

    if (_hint != update.hint) {
      _hint = update.hint;
      _markHintDirty();
    }

    if (_hintAttributes != update.hintAttributes) {
      _hintAttributes = update.hintAttributes;
      _markHintDirty();
    }

    if (_increasedValue != update.increasedValue) {
      _increasedValue = update.increasedValue;
      _markIncreasedValueDirty();
    }

    if (_increasedValueAttributes != update.increasedValueAttributes) {
      _increasedValueAttributes = update.increasedValueAttributes;
      _markIncreasedValueDirty();
    }

    if (_decreasedValue != update.decreasedValue) {
      _decreasedValue = update.decreasedValue;
      _markDecreasedValueDirty();
    }

    if (_decreasedValueAttributes != update.decreasedValueAttributes) {
      _decreasedValueAttributes = update.decreasedValueAttributes;
      _markDecreasedValueDirty();
    }

    if (_tooltip != update.tooltip) {
      _tooltip = update.tooltip;
      _markTooltipDirty();
    }

    if (_textDirection != update.textDirection) {
      _textDirection = update.textDirection;
      _markTextDirectionDirty();
    }

    if (_childrenInHitTestOrder != update.childrenInHitTestOrder) {
      _childrenInHitTestOrder = update.childrenInHitTestOrder;
      _markChildrenInHitTestOrderDirty();
    }

    if (_childrenInTraversalOrder != update.childrenInTraversalOrder) {
      _childrenInTraversalOrder = update.childrenInTraversalOrder;
      _markChildrenInTraversalOrderDirty();
    }

    if (_additionalActions != update.additionalActions) {
      _additionalActions = update.additionalActions;
      _markAdditionalActionsDirty();
    }

    // Apply updates to the DOM.
    _updateRoles();
    _updateChildrenInTraversalOrder();

    // All properties that affect positioning and sizing are checked together
    // any one of them triggers position and size recomputation.
    if (isRectDirty || isTransformDirty || isScrollPositionDirty) {
      recomputePositionAndSize();
    }

    // Make sure we create a child container only when there are children.
    assert(_childContainerElement == null || hasChildren);
    _dirtyFields = 0;
  }

  /// Populates the HTML "role" attribute based on a [condition].
  ///
  /// If [condition] is true, sets the value to [ariaRoleName].
  ///
  /// If [condition] is false, removes the HTML "role" attribute from [element]
  /// if the current role is set to [ariaRoleName]. Otherwise, leaves the value
  /// unchanged. This is done so we gracefully handle multiple competing roles.
  /// For example, if the role changes from "button" to "img" and tappable role
  /// manager attempts to clean up after the image role manager applied the new
  /// role, we do not want it to erase the new role.
  void setAriaRole(String ariaRoleName, bool condition) {
    if (condition) {
      element.setAttribute('role', ariaRoleName);
    } else if (element.getAttribute('role') == ariaRoleName) {
      element.attributes.remove('role');
    }
  }

  /// Role managers.
  ///
  /// The [_roleManagers] map needs to have a stable order for easier debugging
  /// and testing. Dart's map literal guarantees the order as described in the
  /// spec:
  ///
  /// > A map literal is ordered: iterating over the keys and/or values of the maps always happens in the order the keys appeared in the source code.
  final Map<Role, RoleManager?> _roleManagers = <Role, RoleManager?>{};

  /// Returns the role manager for the given [role].
  ///
  /// If a role manager does not exist for the given role, returns null.
  RoleManager? debugRoleManagerFor(Role role) => _roleManagers[role];

  /// Detects the roles that this semantics object corresponds to and manages
  /// the lifecycles of [SemanticsObjectRole] objects.
  void _updateRoles() {
    _updateRole(Role.labelAndValue, (hasLabel || hasValue || hasTooltip) && !isTextField && !isVisualOnly);
    _updateRole(Role.textField, isTextField);

    final bool shouldUseTappableRole =
      (hasAction(ui.SemanticsAction.tap) || hasFlag(ui.SemanticsFlag.isButton)) &&
      // Text fields manage their own focus/tap interactions. We don't need the
      // tappable role manager. It only confuses AT.
      !isTextField;

    _updateRole(Role.tappable, shouldUseTappableRole);
    _updateRole(Role.incrementable, isIncrementable);
    _updateRole(Role.scrollable,
        isVerticalScrollContainer || isHorizontalScrollContainer);
    _updateRole(
        Role.checkable,
        hasFlag(ui.SemanticsFlag.hasCheckedState) ||
            hasFlag(ui.SemanticsFlag.hasToggledState));
    _updateRole(Role.image, isVisualOnly);
    _updateRole(Role.liveRegion, isLiveRegion);
  }

  void _updateRole(Role role, bool enabled) {
    RoleManager? manager = _roleManagers[role];
    if (enabled) {
      if (manager == null) {
        manager = _roleFactories[role]!(this);
        _roleManagers[role] = manager;
      }
      manager.update();
    } else if (manager != null) {
      manager.dispose();
      _roleManagers.remove(role);
    }
    // Nothing to do in the "else case" as it means that we want to disable a
    // role that we don't currently have in the first place.
  }

  /// Whether the object represents an UI element with "increase" or "decrease"
  /// controls, e.g. a slider.
  ///
  /// Such objects are expressed in HTML using `<input type="range">`.
  bool get isIncrementable =>
      hasAction(ui.SemanticsAction.increase) ||
      hasAction(ui.SemanticsAction.decrease);

  /// Role-specific adjustment of the vertical position of the child container.
  ///
  /// This is used, for example, by the [Scrollable] to compensate for the
  /// `scrollTop` offset in the DOM.
  ///
  /// This field must not be null.
  double verticalContainerAdjustment = 0.0;

  /// Role-specific adjustment of the horizontal position of the child
  /// container.
  ///
  /// This is used, for example, by the [Scrollable] to compensate for the
  /// `scrollLeft` offset in the DOM.
  ///
  /// This field must not be null.
  double horizontalContainerAdjustment = 0.0;

  /// Computes the size and position of [element] and, if this element
  /// [hasChildren], of [getOrCreateChildContainer].
  void recomputePositionAndSize() {
    element.style
      ..width = '${_rect!.width}px'
      ..height = '${_rect!.height}px';

    final html.Element? containerElement =
        hasChildren ? getOrCreateChildContainer() : null;

    final bool hasZeroRectOffset = _rect!.top == 0.0 && _rect!.left == 0.0;
    final Float32List? transform = _transform;
    final bool hasIdentityTransform =
        transform == null || isIdentityFloat32ListTransform(transform);

    if (hasZeroRectOffset &&
        hasIdentityTransform &&
        verticalContainerAdjustment == 0.0 &&
        horizontalContainerAdjustment == 0.0) {
      _clearSemanticElementTransform(element);
      if (containerElement != null) {
        _clearSemanticElementTransform(containerElement);
      }
      return;
    }

    late Matrix4 effectiveTransform;
    bool effectiveTransformIsIdentity = true;
    if (!hasZeroRectOffset) {
      if (transform == null) {
        final double left = _rect!.left;
        final double top = _rect!.top;
        effectiveTransform = Matrix4.translationValues(left, top, 0.0);
        effectiveTransformIsIdentity = left == 0.0 && top == 0.0;
      } else {
        // Clone to avoid mutating _transform.
        effectiveTransform = Matrix4.fromFloat32List(transform).clone()
          ..translate(_rect!.left, _rect!.top, 0.0);
        effectiveTransformIsIdentity = effectiveTransform.isIdentity();
      }
    } else if (!hasIdentityTransform) {
      effectiveTransform = Matrix4.fromFloat32List(transform);
      effectiveTransformIsIdentity = false;
    }

    if (!effectiveTransformIsIdentity) {
      element.style
        ..transformOrigin = '0 0 0'
        ..transform = matrix4ToCssTransform(effectiveTransform);
    } else {
      _clearSemanticElementTransform(element);
    }

    if (containerElement != null) {
      if (!hasZeroRectOffset ||
          verticalContainerAdjustment != 0.0 ||
          horizontalContainerAdjustment != 0.0) {
        final double translateX = -_rect!.left + horizontalContainerAdjustment;
        final double translateY = -_rect!.top + verticalContainerAdjustment;
        containerElement.style
          ..top = '${translateY}px'
          ..left = '${translateX}px';
      } else {
        _clearSemanticElementTransform(containerElement);
      }
    }
  }

  /// Clears the transform on a semantic element as if an identity transform is
  /// applied.
  ///
  /// On macOS and iOS, VoiceOver requires `left=0; top=0` value to correctly
  /// handle traversal order.
  ///
  /// See https://github.com/flutter/flutter/issues/73347.
  static void _clearSemanticElementTransform(html.Element element) {
    element.style
      ..removeProperty('transform-origin')
      ..removeProperty('transform');
    if (isMacOrIOS) {
      element.style
        ..top = '0px'
        ..left = '0px';
    } else {
      element.style
        ..removeProperty('top')
        ..removeProperty('left');
    }
  }

  Int32List? _previousChildrenInTraversalOrder;

  /// Updates the traversal child list of [object] from the given [update].
  ///
  /// This method does not recursively update child elements' properties or
  /// their grandchildren. This is handled by [updateSemantics] method walking
  /// all the update nodes.
  void _updateChildrenInTraversalOrder() {
    // Remove all children case.
    if (_childrenInTraversalOrder == null ||
        _childrenInTraversalOrder!.isEmpty) {
      if (_previousChildrenInTraversalOrder == null ||
          _previousChildrenInTraversalOrder!.isEmpty) {
        // We must not have created a container element when child list is empty.
        assert(_childContainerElement == null);
        _previousChildrenInTraversalOrder = _childrenInTraversalOrder;
        return;
      }

      // We must have created a container element when child list is not empty.
      assert(_childContainerElement != null);

      // Remove all children from this semantics object.
      final int len = _previousChildrenInTraversalOrder!.length;
      for (int i = 0; i < len; i++) {
        owner._detachObject(_previousChildrenInTraversalOrder![i]);
      }
      _previousChildrenInTraversalOrder = null;
      _childContainerElement!.remove();
      _childContainerElement = null;
      _previousChildrenInTraversalOrder = _childrenInTraversalOrder;
      return;
    }

    final html.Element? containerElement = getOrCreateChildContainer();

    // Empty case.
    if (_previousChildrenInTraversalOrder == null ||
        _previousChildrenInTraversalOrder!.isEmpty) {
      _previousChildrenInTraversalOrder = _childrenInTraversalOrder;
      for (final int id in _previousChildrenInTraversalOrder!) {
        final SemanticsObject child = owner.getOrCreateObject(id);
        containerElement!.append(child.element);
        owner._attachObject(parent: this, child: child);
      }
      _previousChildrenInTraversalOrder = _childrenInTraversalOrder;
      return;
    }

    // Both non-empty case.

    // Indices into the new child list pointing at children that also exist in
    // the old child list.
    final List<int> intersectionIndicesNew = <int>[];

    // Indices into the old child list pointing at children that also exist in
    // the new child list.
    final List<int> intersectionIndicesOld = <int>[];

    int newIndex = 0;

    // The smallest of the two child list lengths.
    final int minLength = math.min(
      _previousChildrenInTraversalOrder!.length,
      _childrenInTraversalOrder!.length,
    );

    // Scan forward until first discrepancy.
    while (newIndex < minLength &&
        _previousChildrenInTraversalOrder![newIndex] ==
            _childrenInTraversalOrder![newIndex]) {
      intersectionIndicesNew.add(newIndex);
      intersectionIndicesOld.add(newIndex);
      newIndex += 1;
    }

    // If child lists are identical, do nothing.
    if (_previousChildrenInTraversalOrder!.length ==
            _childrenInTraversalOrder!.length &&
        newIndex == _childrenInTraversalOrder!.length) {
      return;
    }

    // If child lists are not identical, continue computing the intersection
    // between the two lists.
    while (newIndex < _childrenInTraversalOrder!.length) {
      for (int oldIndex = 0;
          oldIndex < _previousChildrenInTraversalOrder!.length;
          oldIndex += 1) {
        if (_previousChildrenInTraversalOrder![oldIndex] ==
            _childrenInTraversalOrder![newIndex]) {
          intersectionIndicesNew.add(newIndex);
          intersectionIndicesOld.add(oldIndex);
          break;
        }
      }
      newIndex += 1;
    }

    // The longest sub-sequence in the old list maximizes the number of children
    // that do not need to be moved.
    final List<int?> longestSequence =
        longestIncreasingSubsequence(intersectionIndicesOld);
    final List<int> stationaryIds = <int>[];
    for (int i = 0; i < longestSequence.length; i += 1) {
      stationaryIds.add(_previousChildrenInTraversalOrder![
          intersectionIndicesOld[longestSequence[i]!]]);
    }

    // Remove children that are no longer in the list.
    for (int i = 0; i < _previousChildrenInTraversalOrder!.length; i++) {
      if (!intersectionIndicesOld.contains(i)) {
        // Child not in the intersection. Must be removed.
        final int childId = _previousChildrenInTraversalOrder![i];
        owner._detachObject(childId);
      }
    }

    html.Element? refNode;
    for (int i = _childrenInTraversalOrder!.length - 1; i >= 0; i -= 1) {
      final int childId = _childrenInTraversalOrder![i];
      final SemanticsObject child = owner.getOrCreateObject(childId);
      if (!stationaryIds.contains(childId)) {
        if (refNode == null) {
          containerElement!.append(child.element);
        } else {
          containerElement!.insertBefore(child.element, refNode);
        }
        owner._attachObject(parent: this, child: child);
      } else {
        assert(child._parent == this);
      }
      refNode = child.element;
    }

    _previousChildrenInTraversalOrder = _childrenInTraversalOrder;
  }

  @override
  String toString() {
    if (assertionsEnabled) {
      final String children = _childrenInTraversalOrder != null &&
              _childrenInTraversalOrder!.isNotEmpty
          ? '[${_childrenInTraversalOrder!.join(', ')}]'
          : '<empty>';
      return '$runtimeType(#$id, children: $children)';
    } else {
      return super.toString();
    }
  }
}

/// Controls how pointer events and browser-detected gestures are treated by
/// the Web Engine.
enum AccessibilityMode {
  /// We are not told whether the assistive technology is enabled or not.
  ///
  /// This is the default mode.
  ///
  /// In this mode we use a gesture recognition system that deduplicates
  /// gestures detected by Flutter with gestures detected by the browser.
  unknown,

  /// We are told whether the assistive technology is enabled.
  known,
}

/// Called when the current [GestureMode] changes.
typedef GestureModeCallback = void Function(GestureMode mode);

/// The method used to detect user gestures.
enum GestureMode {
  /// Send pointer events to Flutter to detect gestures using framework-level
  /// gesture recognizers and gesture arenas.
  pointerEvents,

  /// Listen to browser-detected gestures and report them to the framework as
  /// [ui.SemanticsAction].
  browserGestures,
}

/// The top-level service that manages everything semantics-related.
class EngineSemanticsOwner {
  EngineSemanticsOwner._() {
    registerHotRestartListener(() {
      _rootSemanticsElement?.remove();
    });
  }

  /// The singleton instance that manages semantics.
  static EngineSemanticsOwner get instance {
    return _instance ??= EngineSemanticsOwner._();
  }

  static EngineSemanticsOwner? _instance;

  /// Disables semantics and uninitializes the singleton [instance].
  ///
  /// Instances of [EngineSemanticsOwner] are no longer valid after calling this
  /// method. Using them will lead to undefined behavior. This method is only
  /// meant to be used for testing.
  static void debugResetSemantics() {
    if (_instance == null) {
      return;
    }
    _instance!.semanticsEnabled = false;
    _instance = null;
  }

  final Map<int, SemanticsObject> _semanticsTree = <int, SemanticsObject>{};

  /// Map [SemanticsObject.id] to parent [SemanticsObject] it was attached to
  /// this frame.
  Map<int?, SemanticsObject> _attachments = <int?, SemanticsObject>{};

  /// Declares that the [child] must be attached to the [parent].
  ///
  /// Attachments take precedence over detachments (see [_detachObject]). This
  /// allows the same node to be detached from one parent in the tree and
  /// reattached to another parent.
  void _attachObject({required SemanticsObject parent, required SemanticsObject child}) {
    assert(child != null); // ignore: unnecessary_null_comparison
    assert(parent != null); // ignore: unnecessary_null_comparison
    child._parent = parent;
    _attachments[child.id] = parent;
  }

  /// List of objects that were detached this frame.
  ///
  /// The objects in this list will be detached permanently unless they are
  /// reattached via the [_attachObject] method.
  List<SemanticsObject?> _detachments = <SemanticsObject?>[];

  /// Declares that the [SemanticsObject] with the given [id] was detached from
  /// its current parent object.
  ///
  /// The object will be detached permanently unless it is reattached via the
  /// [_attachObject] method.
  void _detachObject(int? id) {
    assert(_semanticsTree.containsKey(id));
    final SemanticsObject? object = _semanticsTree[id];
    _detachments.add(object);
  }

  /// Callbacks called after all objects in the tree have their properties
  /// populated and their sizes and locations computed.
  ///
  /// This list is reset to empty after all callbacks are called.
  List<ui.VoidCallback> _oneTimePostUpdateCallbacks = <ui.VoidCallback>[];

  /// Schedules a one-time callback to be called after all objects in the tree
  /// have their properties populated and their sizes and locations computed.
  void addOneTimePostUpdateCallback(ui.VoidCallback callback) {
    _oneTimePostUpdateCallbacks.add(callback);
  }

  /// Reconciles [_attachments] and [_detachments], and after that calls all
  /// the one-time callbacks scheduled via the [addOneTimePostUpdateCallback]
  /// method.
  void _finalizeTree() {
    for (final SemanticsObject? object in _detachments) {
      final SemanticsObject? parent = _attachments[object!.id];
      if (parent == null) {
        // Was not reparented and is removed permanently from the tree.
        _semanticsTree.remove(object.id);
        object._parent = null;
        object.element.remove();
      } else {
        assert(object._parent == parent);
        assert(object.element.parent == parent._childContainerElement);
      }
    }
    _detachments = <SemanticsObject?>[];
    _attachments = <int?, SemanticsObject>{};

    if (_oneTimePostUpdateCallbacks.isNotEmpty) {
      for (final ui.VoidCallback callback in _oneTimePostUpdateCallbacks) {
        callback();
      }
      _oneTimePostUpdateCallbacks = <ui.VoidCallback>[];
    }
  }

  /// Returns the entire semantics tree for testing.
  ///
  /// Works only in debug mode.
  Map<int, SemanticsObject>? get debugSemanticsTree {
    Map<int, SemanticsObject>? result;
    assert(() {
      result = _semanticsTree;
      return true;
    }());
    return result;
  }

  /// The top-level DOM element of the semantics DOM element tree.
  html.Element? _rootSemanticsElement;

  // ignore: prefer_function_declarations_over_variables
  TimestampFunction _now = () => DateTime.now();

  void debugOverrideTimestampFunction(TimestampFunction value) {
    _now = value;
  }

  void debugResetTimestampFunction() {
    _now = () => DateTime.now();
  }

  final SemanticsHelper semanticsHelper = SemanticsHelper();

  /// Whether the user has requested that [updateSemantics] be called when the
  /// semantic contents of window changes.
  ///
  /// The [ui.PlatformDispatcher.onSemanticsEnabledChanged] callback is called
  /// whenever this value changes.
  ///
  /// This is separate from accessibility [mode], which controls how gestures
  /// are interpreted when this value is true.
  bool get semanticsEnabled => _semanticsEnabled;
  bool _semanticsEnabled = false;
  set semanticsEnabled(bool value) {
    if (value == _semanticsEnabled) {
      return;
    }
    _semanticsEnabled = value;

    if (!_semanticsEnabled) {
      // We do not process browser events at all when semantics is explicitly
      // disabled. All gestures are handled by the framework-level gesture
      // recognizers from pointer events.
      if (_gestureMode != GestureMode.pointerEvents) {
        _gestureMode = GestureMode.pointerEvents;
        _notifyGestureModeListeners();
      }
      final List<int?> keys = _semanticsTree.keys.toList();
      final int len = keys.length;
      for (int i = 0; i < len; i++) {
        _detachObject(keys[i]);
      }
      _finalizeTree();
      _rootSemanticsElement?.remove();
      _rootSemanticsElement = null;
      _gestureModeClock?.datetime = null;
    }
    EnginePlatformDispatcher.instance.updateSemanticsEnabled(_semanticsEnabled);
  }

  /// Controls how pointer events and browser-detected gestures are treated by
  /// the Web Engine.
  ///
  /// The default mode is [AccessibilityMode.unknown].
  AccessibilityMode get mode => _mode;
  set mode(AccessibilityMode value) {
    assert(value != null); // ignore: unnecessary_null_comparison
    _mode = value;
  }

  AccessibilityMode _mode = AccessibilityMode.unknown;

  /// Currently used [GestureMode].
  ///
  /// This value changes automatically depending on the incoming input events.
  /// Functionality that implements different strategies depending on this mode
  /// would use [addGestureModeListener] and [removeGestureModeListener] to get
  /// notifications about when the value of this field changes.
  GestureMode get gestureMode => _gestureMode;
  GestureMode _gestureMode = GestureMode.browserGestures;

  AlarmClock? _gestureModeClock;

  AlarmClock? _getGestureModeClock() {
    if (_gestureModeClock == null) {
      _gestureModeClock = AlarmClock(_now);
      _gestureModeClock!.callback = () {
        if (_gestureMode == GestureMode.browserGestures) {
          return;
        }

        _gestureMode = GestureMode.browserGestures;
        _notifyGestureModeListeners();
      };
    }
    return _gestureModeClock;
  }

  /// Disables browser gestures temporarily because we have detected pointer
  /// events.
  ///
  /// This is used to deduplicate gestures detected by Flutter and gestures
  /// detected by the browser. Flutter-detected gestures have higher precedence.
  void _temporarilyDisableBrowserGestureMode() {
    const Duration _kDebounceThreshold = Duration(milliseconds: 500);
    _getGestureModeClock()!.datetime = _now().add(_kDebounceThreshold);
    if (_gestureMode != GestureMode.pointerEvents) {
      _gestureMode = GestureMode.pointerEvents;
      _notifyGestureModeListeners();
    }
  }

  /// Receives DOM events from the pointer event system to correlate with the
  /// semantics events; returns true if the event should be forwarded to the
  /// framework.
  ///
  /// The browser sends us both raw pointer events and gestures from
  /// [SemanticsObject.element]s. There could be three possibilities:
  ///
  /// 1. Assistive technology is enabled and we know that it is.
  /// 2. Assistive technology is disabled and we know that it isn't.
  /// 3. We do not know whether an assistive technology is enabled.
  ///
  /// If [autoEnableOnTap] was called, this will automatically enable semantics
  /// if the user requests it.
  ///
  /// In the first case we can ignore raw pointer events and only interpret
  /// high-level gestures, e.g. "click".
  ///
  /// In the second case we can ignore high-level gestures and interpret the raw
  /// pointer events directly.
  ///
  /// Finally, in a mode when we do not know if an assistive technology is
  /// enabled or not we do a best-effort estimate which to respond to, raw
  /// pointer or high-level gestures. We avoid doing both because that will
  /// result in double-firing of event listeners, such as `onTap` on a button.
  /// An approach we use is to measure the distance between the last pointer
  /// event and a gesture event. If a gesture is receive "soon" after the last
  /// received pointer event (determined by a heuristic), it is debounced as it
  /// is likely that the gesture detected from the pointer even will do the
  /// right thing. However, if we receive a standalone gesture we will map it
  /// onto a [ui.SemanticsAction] to be processed by the framework.
  bool receiveGlobalEvent(html.Event event) {
    // For pointer event reference see:
    //
    // https://developer.mozilla.org/en-US/docs/Web/API/Pointer_events
    const List<String> _pointerEventTypes = <String>[
      'pointerdown',
      'pointermove',
      'pointerup',
      'pointercancel',
      'touchstart',
      'touchend',
      'touchmove',
      'touchcancel',
      'mousedown',
      'mousemove',
      'mouseup',
      'keyup',
      'keydown',
    ];

    if (_pointerEventTypes.contains(event.type)) {
      _temporarilyDisableBrowserGestureMode();
    }

    return semanticsHelper.shouldEnableSemantics(event);
  }

  /// Callbacks called when the [GestureMode] changes.
  ///
  /// Callbacks are called synchronously. HTML DOM updates made in a callback
  /// take effect in the current animation frame and/or the current message loop
  /// event.
  List<GestureModeCallback?> _gestureModeListeners = <GestureModeCallback?>[];

  /// Calls the [callback] every time the current [GestureMode] changes.
  ///
  /// The callback is called synchronously. HTML DOM updates made in the
  /// callback take effect in the current animation frame and/or the current
  /// message loop event.
  void addGestureModeListener(GestureModeCallback? callback) {
    _gestureModeListeners.add(callback);
  }

  /// Stops calling the [callback] when the [GestureMode] changes.
  ///
  /// The passed [callback] must be the exact same object as the one passed to
  /// [addGestureModeListener].
  void removeGestureModeListener(GestureModeCallback? callback) {
    assert(_gestureModeListeners.contains(callback));
    _gestureModeListeners.remove(callback);
  }

  void _notifyGestureModeListeners() {
    for (int i = 0; i < _gestureModeListeners.length; i++) {
      _gestureModeListeners[i]!(_gestureMode);
    }
  }

  /// Whether a gesture event of type [eventType] should be accepted as a
  /// semantic action.
  ///
  /// If [mode] is [AccessibilityMode.known] the gesture is always accepted if
  /// [semanticsEnabled] is `true`, and it is always rejected if
  /// [semanticsEnabled] is `false`.
  ///
  /// If [mode] is [AccessibilityMode.unknown] the gesture is accepted if it is
  /// not accompanied by pointer events. In the presence of pointer events we
  /// delegate to Flutter's gesture detection system to produce gestures.
  bool shouldAcceptBrowserGesture(String eventType) {
    if (_mode == AccessibilityMode.known) {
      // Do not ignore accessibility gestures in known mode, unless semantics
      // is explicitly disabled.
      return semanticsEnabled;
    }

    const List<String> pointerDebouncedGestures = <String>[
      'click',
      'scroll',
    ];

    if (pointerDebouncedGestures.contains(eventType)) {
      return _gestureMode == GestureMode.browserGestures;
    }

    return false;
  }

  /// Looks up a [SemanticsObject] in the semantics tree by ID, or creates a new
  /// instance if it does not exist.
  SemanticsObject getOrCreateObject(int id) {
    SemanticsObject? object = _semanticsTree[id];
    if (object == null) {
      object = SemanticsObject(id, this);
      _semanticsTree[id] = object;
    }
    return object;
  }

  /// Updates the semantics tree from data in the [uiUpdate].
  void updateSemantics(ui.SemanticsUpdate uiUpdate) {
    if (!_semanticsEnabled) {
      if (ui.debugEmulateFlutterTesterEnvironment) {
        // Running Flutter widget tests in a fake environment. Don't enable
        // engine semantics. Test semantics trees violate invariants in ways
        // production implementation isn't built to handle. For example, tests
        // routinely reset semantics node IDs, which is messing up the update
        // process.
        return;
      } else {
        // Running a real app. Auto-enable engine semantics.
        semanticsHelper.dispose(); // placeholder no longer needed
        semanticsEnabled = true;
      }
    }

    final SemanticsUpdate update = uiUpdate as SemanticsUpdate;
    for (final SemanticsNodeUpdate nodeUpdate in update._nodeUpdates!) {
      final SemanticsObject object = getOrCreateObject(nodeUpdate.id);
      object.updateWith(nodeUpdate);
    }

    if (_rootSemanticsElement == null) {
      final SemanticsObject root = _semanticsTree[0]!;
      _rootSemanticsElement = root.element;
      domRenderer.semanticsHostElement!.append(root.element);
    }

    _finalizeTree();

    assert(_semanticsTree.containsKey(0)); // must contain root node
    assert(() {
      // Validate tree
      _semanticsTree.forEach((int? id, SemanticsObject? object) {
        assert(id == object!.id);
        // Ensure child ID list is consistent with the parent-child
        // relationship of the semantics tree.
        if (object!._childrenInTraversalOrder != null) {
          for (final int childId in object._childrenInTraversalOrder!) {
            final SemanticsObject? child = _semanticsTree[childId];
            if (child == null) {
              throw AssertionError('Child #$childId is missing in the tree.');
            }
            if (child._parent == null) {
              throw AssertionError(
                  'Child #$childId of parent #${object.id} has null parent '
                  'reference.');
            }
            if (!identical(child._parent, object)) {
              throw AssertionError(
                  'Parent #${object.id} has child #$childId. However, the '
                  'child is attached to #${child._parent!.id}.');
            }
          }
        }
      });

      // Validate that all updates were applied
      for (final SemanticsNodeUpdate update in update._nodeUpdates!) {
        // Node was added to the tree.
        assert(_semanticsTree.containsKey(update.id));
      }

      return true;
    }());
  }
}

/// Computes the [longest increasing subsequence](http://en.wikipedia.org/wiki/Longest_increasing_subsequence).
///
/// Returns list of indices (rather than values) into [list].
///
/// Complexity: n*log(n)
List<int> longestIncreasingSubsequence(List<int> list) {
  final int len = list.length;
  final List<int> predecessors = <int>[];
  final List<int> mins = <int>[0];
  int longest = 0;
  for (int i = 0; i < len; i++) {
    // Binary search for the largest positive `j ≤ longest`
    // such that `list[mins[j]] < list[i]`
    final int elem = list[i];
    int lo = 1;
    int hi = longest;
    while (lo <= hi) {
      final int mid = (lo + hi) ~/ 2;
      if (list[mins[mid]] < elem) {
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    // After searching, `lo` is 1 greater than the
    // length of the longest prefix of `list[i]`
    final int expansionIndex = lo;
    // The predecessor of `list[i]` is the last index of
    // the subsequence of length `newLongest - 1`
    predecessors.add(mins[expansionIndex - 1]);
    if (expansionIndex >= mins.length) {
      mins.add(i);
    } else {
      mins[expansionIndex] = i;
    }
    if (expansionIndex > longest) {
      // If we found a subsequence longer than any we've
      // found yet, update `longest`
      longest = expansionIndex;
    }
  }
  // Reconstruct the longest subsequence
  final List<int> seq = List<int>.filled(longest, 0);
  int k = mins[longest];
  for (int i = longest - 1; i >= 0; i--) {
    seq[i] = k;
    k = predecessors[k];
  }
  return seq;
}

/// States that a [ui.SemanticsNode] can have.
///
/// SemanticsNodes can be in three distinct states (enabled, disabled,
/// no opinion).
enum EnabledState {
  /// Flag [ui.SemanticsFlag.hasEnabledState] is not set.
  ///
  /// The node does not have enabled/disabled state.
  noOpinion,

  /// Flag [ui.SemanticsFlag.hasEnabledState] and [ui.SemanticsFlag.isEnabled]
  /// are set.
  ///
  /// The node is enabled.
  enabled,

  /// Flag [ui.SemanticsFlag.hasEnabledState] is set and
  /// [ui.SemanticsFlag.isEnabled] is not set.
  ///
  /// The node is disabled.
  disabled,
}
