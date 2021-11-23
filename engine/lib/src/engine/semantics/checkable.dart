// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// TODO(yjbanov): TalkBack on Android incorrectly reads state changes for radio
//                buttons. When checking a radio button it reads
//                "Checked, not checked". This is likely due to another radio
//                button automatically becoming unchecked. VoiceOver reads it
//                correctly. It is possible we can fix this by using
//                "radiogroup" and "aria-owns". This may require a change in the
//                framework. Currently the framework does not report the
//                grouping of radio buttons.

import 'dart:html' as html;

import 'package:ui/ui.dart' as ui;

import 'semantics.dart';

/// The specific type of checkable control.
enum _CheckableKind {
  /// A checkbox. An element, which has [ui.SemanticsFlag.hasCheckedState] set
  /// and does not have [ui.SemanticsFlag.isInMutuallyExclusiveGroup] or
  /// [ui.SemanticsFlag.hasToggledState] state, is marked as a checkbox.
  checkbox,

  /// A radio button, defined by [ui.SemanticsFlag.isInMutuallyExclusiveGroup].
  radio,

  /// A switch, defined by [ui.SemanticsFlag.hasToggledState].
  toggle,
}

_CheckableKind _checkableKindFromSemanticsFlag(
    SemanticsObject semanticsObject) {
  if (semanticsObject.hasFlag(ui.SemanticsFlag.isInMutuallyExclusiveGroup)) {
    return _CheckableKind.radio;
  } else if (semanticsObject.hasFlag(ui.SemanticsFlag.hasToggledState)) {
    return _CheckableKind.toggle;
  } else {
    return _CheckableKind.checkbox;
  }
}

/// Renders semantics objects that have checkable (on/off) states.
///
/// Three objects which are implemented by this class are checkboxes, radio
/// buttons and switches.
///
/// See also [ui.SemanticsFlag.hasCheckedState], [ui.SemanticsFlag.isChecked],
/// [ui.SemanticsFlag.isInMutuallyExclusiveGroup], [ui.SemanticsFlag.isToggled],
/// [ui.SemanticsFlag.hasToggledState]
class Checkable extends RoleManager {
  final _CheckableKind _kind;

  Checkable(SemanticsObject semanticsObject)
      : _kind = _checkableKindFromSemanticsFlag(semanticsObject),
        super(Role.checkable, semanticsObject);

  @override
  void update() {
    if (semanticsObject.isFlagsDirty) {
      switch (_kind) {
        case _CheckableKind.checkbox:
          semanticsObject.setAriaRole('checkbox', true);
          break;
        case _CheckableKind.radio:
          semanticsObject.setAriaRole('radio', true);
          break;
        case _CheckableKind.toggle:
          semanticsObject.setAriaRole('switch', true);
          break;
      }

      /// Adding disabled and aria-disabled attribute to notify the assistive
      /// technologies of disabled elements.
      _updateDisabledAttribute();

      semanticsObject.element.setAttribute(
        'aria-checked',
        (semanticsObject.hasFlag(ui.SemanticsFlag.isChecked) ||
                semanticsObject.hasFlag(ui.SemanticsFlag.isToggled))
            ? 'true'
            : 'false',
      );
    }
  }

  @override
  void dispose() {
    switch (_kind) {
      case _CheckableKind.checkbox:
        semanticsObject.setAriaRole('checkbox', false);
        break;
      case _CheckableKind.radio:
        semanticsObject.setAriaRole('radio', false);
        break;
      case _CheckableKind.toggle:
        semanticsObject.setAriaRole('switch', false);
        break;
    }
    _removeDisabledAttribute();
  }

  void _updateDisabledAttribute() {
    if (semanticsObject.enabledState() == EnabledState.disabled) {
      final html.Element element = semanticsObject.element;
      element
        ..setAttribute('aria-disabled', 'true')
        ..setAttribute('disabled', 'true');
    } else {
      _removeDisabledAttribute();
    }
  }

  void _removeDisabledAttribute() {
    final html.Element element = semanticsObject.element;
    element..removeAttribute('aria-disabled')..removeAttribute('disabled');
  }
}
