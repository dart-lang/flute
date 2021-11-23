// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html' as html;

import 'package:ui/ui.dart' as ui;

import 'browser_detection.dart';
import 'services.dart';
import 'util.dart';

/// Handles clipboard related platform messages.
class ClipboardMessageHandler {
  /// Helper to handle copy to clipboard functionality.
  CopyToClipboardStrategy _copyToClipboardStrategy = CopyToClipboardStrategy();

  /// Helper to handle copy to clipboard functionality.
  PasteFromClipboardStrategy _pasteFromClipboardStrategy =
      PasteFromClipboardStrategy();

  /// Handles the platform message which stores the given text to the clipboard.
  void setDataMethodCall(
      MethodCall methodCall, ui.PlatformMessageResponseCallback? callback) {
    const MethodCodec codec = JSONMethodCodec();
    bool errorEnvelopeEncoded = false;
    _copyToClipboardStrategy
        .setData(methodCall.arguments['text'] as String?)
        .then((bool success) {
      if (success) {
        callback!(codec.encodeSuccessEnvelope(true));
      } else {
        callback!(codec.encodeErrorEnvelope(
            code: 'copy_fail', message: 'Clipboard.setData failed'));
        errorEnvelopeEncoded = true;
      }
    }).catchError((dynamic _) {
      // Don't encode a duplicate reply if we already failed and an error
      // was already encoded.
      if (!errorEnvelopeEncoded) {
        callback!(codec.encodeErrorEnvelope(
            code: 'copy_fail', message: 'Clipboard.setData failed'));
      }
    });
  }

  /// Handles the platform message which retrieves text data from the clipboard.
  void getDataMethodCall(ui.PlatformMessageResponseCallback? callback) {
    const MethodCodec codec = JSONMethodCodec();
    _pasteFromClipboardStrategy.getData().then((String data) {
      final Map<String, dynamic> map = <String, dynamic>{'text': data};
      callback!(codec.encodeSuccessEnvelope(map));
    }).catchError((dynamic error) {
      if (error is UnimplementedError) {
        // Clipboard.getData not supported.
        // Passing [null] to [callback] indicates that the platform message isn't
        // implemented. Look at [MethodChannel.invokeMethod] to see how [null] is
        // handled.
        Future<void>.delayed(Duration.zero).then((_) {
          if (callback != null) {
            callback(null);
          }
        });
        return;
      }
      _reportGetDataFailure(callback, codec, error);
    });
  }

  void _reportGetDataFailure(ui.PlatformMessageResponseCallback? callback,
      MethodCodec codec, dynamic error) {
    print('Could not get text from clipboard: $error');
    callback!(codec.encodeErrorEnvelope(
        code: 'paste_fail', message: 'Clipboard.getData failed'));
  }

  /// Methods used by tests.
  set pasteFromClipboardStrategy(PasteFromClipboardStrategy strategy) {
    _pasteFromClipboardStrategy = strategy;
  }

  set copyToClipboardStrategy(CopyToClipboardStrategy strategy) {
    _copyToClipboardStrategy = strategy;
  }
}

/// Provides functionality for writing text to clipboard.
///
/// A concrete implementation is picked at runtime based on the available
/// APIs and the browser.
abstract class CopyToClipboardStrategy {
  factory CopyToClipboardStrategy() {
    return !unsafeIsNull(html.window.navigator.clipboard)
        ? ClipboardAPICopyStrategy()
        : ExecCommandCopyStrategy();
  }

  /// Places the text onto the browser Clipboard.
  ///
  /// Returns `true` for a successful action.
  ///
  /// Returns `false` for an uncessful action or when there is an excaption.
  Future<bool> setData(String? text);
}

/// Provides functionality for reading text from clipboard.
///
/// A concrete implementation is picked at runtime based on the available
/// APIs and the browser.
abstract class PasteFromClipboardStrategy {
  factory PasteFromClipboardStrategy() {
    return (browserEngine == BrowserEngine.firefox ||
            unsafeIsNull(html.window.navigator.clipboard))
        ? ExecCommandPasteStrategy()
        : ClipboardAPIPasteStrategy();
  }

  /// Returns text from the system Clipboard.
  Future<String> getData();
}

/// Provides copy functionality for browsers which supports ClipboardAPI.
///
/// Works on Chrome and Firefox browsers.
/// See: https://developer.mozilla.org/en-US/docs/Web/API/Clipboard_API
class ClipboardAPICopyStrategy implements CopyToClipboardStrategy {
  @override
  Future<bool> setData(String? text) async {
    try {
      await html.window.navigator.clipboard!.writeText(text!);
    } catch (error) {
      print('copy is not successful $error');
      return Future<bool>.value(false);
    }
    return Future<bool>.value(true);
  }
}

/// Provides paste functionality for browsers which supports `clipboard.readText`.
///
/// Works on Chrome. Firefox only supports `readText` if the target element is
/// in content editable mode.
/// See: https://developer.mozilla.org/en-US/docs/Web/Guide/HTML/Editable_content
/// See: https://developer.mozilla.org/en-US/docs/Web/API/Clipboard_API
class ClipboardAPIPasteStrategy implements PasteFromClipboardStrategy {
  @override
  Future<String> getData() async {
    return html.window.navigator.clipboard!.readText();
  }
}

/// Provides a fallback strategy for browsers which does not support ClipboardAPI.
class ExecCommandCopyStrategy implements CopyToClipboardStrategy {
  @override
  Future<bool> setData(String? text) {
    return Future<bool>.value(_setDataSync(text));
  }

  bool _setDataSync(String? text) {
    // Copy content to clipboard with execCommand.
    // See: https://developers.google.com/web/updates/2015/04/cut-and-copy-commands
    final html.TextAreaElement tempTextArea = _appendTemporaryTextArea();
    tempTextArea.value = text;
    tempTextArea.focus();
    tempTextArea.select();
    bool result = false;
    try {
      result = html.document.execCommand('copy');
      if (!result) {
        print('copy is not successful');
      }
    } catch (error) {
      print('copy is not successful $error');
    } finally {
      _removeTemporaryTextArea(tempTextArea);
    }
    return result;
  }

  html.TextAreaElement _appendTemporaryTextArea() {
    final html.TextAreaElement tempElement = html.TextAreaElement();
    final html.CssStyleDeclaration elementStyle = tempElement.style;
    elementStyle
      ..position = 'absolute'
      ..top = '-99999px'
      ..left = '-99999px'
      ..opacity = '0'
      ..color = 'transparent'
      ..backgroundColor = 'transparent'
      ..background = 'transparent';

    html.document.body!.append(tempElement);

    return tempElement;
  }

  void _removeTemporaryTextArea(html.HtmlElement element) {
    element.remove();
  }
}

/// Provides a fallback strategy for browsers which does not support ClipboardAPI.
class ExecCommandPasteStrategy implements PasteFromClipboardStrategy {
  @override
  Future<String> getData() {
    // TODO(mdebbar): https://github.com/flutter/flutter/issues/48581
    return Future<String>.error(
        UnimplementedError('Paste is not implemented for this browser.'));
  }
}
