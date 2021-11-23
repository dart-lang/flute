// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html' as html;

import '../browser_detection.dart';

/// Various types of inputs used in text fields.
///
/// These types are coming from Flutter's [TextInputType]. Currently, we don't
/// support all the types. We fallback to [EngineInputType.text] when Flutter
/// sends a type that isn't supported.
// TODO(mdebbar): Support more types.
abstract class EngineInputType {
  const EngineInputType();

  static EngineInputType fromName(String name, {bool isDecimal = false}) {
    switch (name) {
      case 'TextInputType.number':
        return isDecimal ? decimal : number;
      case 'TextInputType.phone':
        return phone;
      case 'TextInputType.emailAddress':
        return emailAddress;
      case 'TextInputType.url':
        return url;
      case 'TextInputType.multiline':
        return multiline;
      case 'TextInputType.none':
        return none;
      case 'TextInputType.text':
      default:
        return text;
    }
  }

  /// No text input.
  static const NoTextInputType none = NoTextInputType();

  /// Single-line text input type.
  static const TextInputType text = TextInputType();

  /// Numeric input type.
  static const NumberInputType number = NumberInputType();

  /// Decimal input type.
  static const DecimalInputType decimal = DecimalInputType();

  /// Phone number input type.
  static const PhoneInputType phone = PhoneInputType();

  /// Email address input type.
  static const EmailInputType emailAddress = EmailInputType();

  /// URL input type.
  static const UrlInputType url = UrlInputType();

  /// Multi-line text input type.
  static const MultilineInputType multiline = MultilineInputType();

  /// The HTML `inputmode` attribute to be set on the DOM element.
  ///
  /// This HTML attribute helps the browser decide what kind of keyboard works
  /// best for this text field.
  ///
  /// For various `inputmode` values supported by browsers, see:
  /// <https://developer.mozilla.org/en-US/docs/Web/HTML/Global_attributes/inputmode>.
  String? get inputmodeAttribute;

  /// Whether this input type allows the "Enter" key to submit the input action.
  bool get submitActionOnEnter => true;

  /// Create the appropriate DOM element for this input type.
  html.HtmlElement createDomElement() => html.InputElement();

  /// Given a [domElement], set attributes that are specific to this input type.
  void configureInputMode(html.HtmlElement domElement) {
    if (inputmodeAttribute == null) {
      return;
    }

    // Only apply `inputmode` in mobile browsers so that the right virtual
    // keyboard shows up.
    if (operatingSystem == OperatingSystem.iOs ||
        operatingSystem == OperatingSystem.android ||
        inputmodeAttribute == EngineInputType.none.inputmodeAttribute) {
      domElement.setAttribute('inputmode', inputmodeAttribute!);
    }
  }
}

/// No text input.
class NoTextInputType extends EngineInputType {
  const NoTextInputType();

  @override
  String get inputmodeAttribute => 'none';
}

/// Single-line text input type.
class TextInputType extends EngineInputType {
  const TextInputType();

  @override
  String get inputmodeAttribute => 'text';
}

/// Numeric input type.
///
/// Input keyboard with only the digits 0–9.
class NumberInputType extends EngineInputType {
  const NumberInputType();

  @override
  String get inputmodeAttribute => 'numeric';
}

/// Decimal input type.
///
/// Input keyboard with containing the digits 0–9 and a decimal separator.
/// Separator can be `.`, `,` depending on the locale.
class DecimalInputType extends EngineInputType {
  const DecimalInputType();

  @override
  String get inputmodeAttribute => 'decimal';
}

/// Phone number input type.
class PhoneInputType extends EngineInputType {
  const PhoneInputType();

  @override
  String get inputmodeAttribute => 'tel';
}

/// Email address input type.
class EmailInputType extends EngineInputType {
  const EmailInputType();

  @override
  String get inputmodeAttribute => 'email';
}

/// URL input type.
class UrlInputType extends EngineInputType {
  const UrlInputType();

  @override
  String get inputmodeAttribute => 'url';
}

/// Multi-line text input type.
class MultilineInputType extends EngineInputType {
  const MultilineInputType();

  @override
  String? get inputmodeAttribute => null;

  @override
  bool get submitActionOnEnter => false;

  @override
  html.HtmlElement createDomElement() => html.TextAreaElement();
}
