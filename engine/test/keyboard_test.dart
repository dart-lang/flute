// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

import 'package:quiver/testing/async.dart';
import 'package:test/bootstrap/browser.dart';
import 'package:test/test.dart';
import 'package:ui/src/engine/browser_detection.dart';
import 'package:ui/src/engine/keyboard.dart';
import 'package:ui/src/engine/services.dart';
import 'package:ui/src/engine/text_editing/text_editing.dart';
import 'package:ui/ui.dart' as ui;

void main() {
  internalBootstrapBrowserTest(() => testMain);
}

void testMain() {
  group('Keyboard', () {
    /// Used to save and restore [ui.window.onPlatformMessage] after each test.
    ui.PlatformMessageCallback? savedCallback;

    setUp(() {
      savedCallback = ui.window.onPlatformMessage;
    });

    tearDown(() {
      ui.window.onPlatformMessage = savedCallback;
    });

    test('initializes and disposes', () {
      expect(Keyboard.instance, isNull);
      Keyboard.initialize();
      expect(Keyboard.instance, isA<Keyboard>());
      Keyboard.instance!.dispose();
      expect(Keyboard.instance, isNull);
    });

    test('dispatches keyup to flutter/keyevent channel', () {
      Keyboard.initialize();

      String? channelReceived;
      Map<String, dynamic>? dataReceived;
      ui.window.onPlatformMessage = (String channel, ByteData? data,
          ui.PlatformMessageResponseCallback? callback) {
        channelReceived = channel;
        dataReceived = const JSONMessageCodec().decodeMessage(data) as Map<String, dynamic>?;
      };

      html.KeyboardEvent event;

      event = dispatchKeyboardEvent('keyup', key: 'SomeKey', code: 'SomeCode');

      expect(event.defaultPrevented, isFalse);
      expect(channelReceived, 'flutter/keyevent');
      expect(dataReceived, <String, dynamic>{
        'type': 'keyup',
        'keymap': 'web',
        'code': 'SomeCode',
        'location': 0,
        'key': 'SomeKey',
        'metaState': 0x0,
      });

      Keyboard.instance!.dispose();
    },
        // TODO(mdebbar): https://github.com/flutter/flutter/issues/50815
        skip: browserEngine == BrowserEngine.edge);

    test('dispatches keydown to flutter/keyevent channel', () {
      Keyboard.initialize();

      String? channelReceived;
      Map<String, dynamic>? dataReceived;
      ui.window.onPlatformMessage = (String channel, ByteData? data,
          ui.PlatformMessageResponseCallback? callback) {
        channelReceived = channel;
        dataReceived = const JSONMessageCodec().decodeMessage(data) as Map<String, dynamic>?;
      };

      html.KeyboardEvent event;

      event =
          dispatchKeyboardEvent('keydown', key: 'SomeKey', code: 'SomeCode');

      expect(channelReceived, 'flutter/keyevent');
      expect(dataReceived, <String, dynamic>{
        'type': 'keydown',
        'keymap': 'web',
        'code': 'SomeCode',
        'key': 'SomeKey',
        'location': 0,
        'metaState': 0x0,
      });
      expect(event.defaultPrevented, isFalse);

      Keyboard.instance!.dispose();
    },
        // TODO(mdebbar): https://github.com/flutter/flutter/issues/50815
        skip: browserEngine == BrowserEngine.edge);

    test('dispatches correct meta state', () {
      Keyboard.initialize();

      Map<String, dynamic>? dataReceived;
      ui.window.onPlatformMessage = (String channel, ByteData? data,
          ui.PlatformMessageResponseCallback? callback) {
        dataReceived = const JSONMessageCodec().decodeMessage(data) as Map<String, dynamic>?;
      };

      html.KeyboardEvent event;

      event = dispatchKeyboardEvent(
        'keydown',
        key: 'SomeKey',
        code: 'SomeCode',
        isControlPressed: true,
      );
      expect(event.defaultPrevented, isFalse);
      expect(dataReceived, <String, dynamic>{
        'type': 'keydown',
        'keymap': 'web',
        'code': 'SomeCode',
        'key': 'SomeKey',
        'location': 0,
        //          ctrl
        'metaState': 0x4,
      });

      event = dispatchKeyboardEvent(
        'keydown',
        key: 'SomeKey',
        code: 'SomeCode',
        isShiftPressed: true,
        isAltPressed: true,
        isMetaPressed: true,
      );
      expect(event.defaultPrevented, isFalse);
      expect(dataReceived, <String, dynamic>{
        'type': 'keydown',
        'keymap': 'web',
        'code': 'SomeCode',
        'key': 'SomeKey',
        'location': 0,
        //          shift  alt   meta
        'metaState': 0x1 | 0x2 | 0x8,
      });

      Keyboard.instance!.dispose();
    },
        // TODO(mdebbar): https://github.com/flutter/flutter/issues/50815
        skip: browserEngine == BrowserEngine.edge);

    test('dispatches repeat events', () {
      Keyboard.initialize();

      final List<Map<String, dynamic>> messages = <Map<String, dynamic>>[];
      ui.window.onPlatformMessage = (String channel, ByteData? data,
          ui.PlatformMessageResponseCallback? callback) {
        messages.add(const JSONMessageCodec().decodeMessage(data) as Map<String, dynamic>);
      };

      html.KeyboardEvent event;

      event = dispatchKeyboardEvent(
        'keydown',
        key: 'SomeKey',
        code: 'SomeCode',
        repeat: true,
      );
      expect(event.defaultPrevented, isFalse);

      event = dispatchKeyboardEvent(
        'keydown',
        key: 'SomeKey',
        code: 'SomeCode',
        repeat: true,
      );
      expect(event.defaultPrevented, isFalse);

      event = dispatchKeyboardEvent(
        'keydown',
        key: 'SomeKey',
        code: 'SomeCode',
        repeat: true,
      );
      expect(event.defaultPrevented, isFalse);

      final Map<String, dynamic> expectedMessage = <String, dynamic>{
        'type': 'keydown',
        'keymap': 'web',
        'code': 'SomeCode',
        'key': 'SomeKey',
        'location': 0,
        'metaState': 0,
      };
      expect(messages, <Map<String, dynamic>>[
        expectedMessage,
        expectedMessage,
        expectedMessage,
      ]);

      Keyboard.instance!.dispose();
    },
        // TODO(mdebbar): https://github.com/flutter/flutter/issues/50815
        skip: browserEngine == BrowserEngine.edge);

    test('stops dispatching events after dispose', () {
      Keyboard.initialize();

      int count = 0;
      ui.window.onPlatformMessage = (String channel, ByteData? data,
          ui.PlatformMessageResponseCallback? callback) {
        count += 1;
      };

      dispatchKeyboardEvent('keydown');
      expect(count, 1);
      dispatchKeyboardEvent('keyup');
      expect(count, 2);

      Keyboard.instance!.dispose();
      expect(Keyboard.instance, isNull);

      // No more event dispatching.
      dispatchKeyboardEvent('keydown');
      expect(count, 2);
      dispatchKeyboardEvent('keyup');
      expect(count, 2);
    });

    test('prevents default when key is handled by the framework', () {
      Keyboard.initialize();

      int count = 0;
      ui.window.onPlatformMessage = (String channel, ByteData? data,
          ui.PlatformMessageResponseCallback? callback) {
        count += 1;
        final ByteData response = const JSONMessageCodec().encodeMessage(<String, dynamic>{'handled': true})!;
        callback!(response);
      };

      final html.KeyboardEvent event = dispatchKeyboardEvent(
        'keydown',
        key: 'Tab',
        code: 'Tab',
      );

      expect(event.defaultPrevented, isTrue);
      expect(count, 1);

      Keyboard.instance!.dispose();
    });

    test("Doesn't prevent default when key is not handled by the framework", () {
      Keyboard.initialize();

      int count = 0;
      ui.window.onPlatformMessage = (String channel, ByteData? data,
          ui.PlatformMessageResponseCallback? callback) {
        count += 1;
        final ByteData response = const JSONMessageCodec().encodeMessage(<String, dynamic>{'handled': false})!;
        callback!(response);
      };

      final html.KeyboardEvent event = dispatchKeyboardEvent(
        'keydown',
        key: 'Tab',
        code: 'Tab',
      );

      expect(event.defaultPrevented, isFalse);
      expect(count, 1);

      Keyboard.instance!.dispose();
    });

    test('keyboard events should be triggered on text fields', () {
      Keyboard.initialize();

      int count = 0;
      ui.window.onPlatformMessage = (String channel, ByteData? data,
          ui.PlatformMessageResponseCallback? callback) {
        count += 1;
      };

      useTextEditingElement((html.Element element) {
        final html.KeyboardEvent event = dispatchKeyboardEvent(
          'keydown',
          key: 'SomeKey',
          code: 'SomeCode',
          target: element,
        );

        expect(event.defaultPrevented, isFalse);
        expect(count, 1);
      });

      Keyboard.instance!.dispose();
    });

    test('the "Tab" key should never be ignored', () {
      Keyboard.initialize();

      int count = 0;
      ui.window.onPlatformMessage = (String channel, ByteData? data,
          ui.PlatformMessageResponseCallback? callback) {
        count += 1;
        final ByteData response = const JSONMessageCodec().encodeMessage(<String, dynamic>{'handled': true})!;
        callback!(response);
      };

      useTextEditingElement((html.Element element) {
        final html.KeyboardEvent event = dispatchKeyboardEvent(
          'keydown',
          key: 'Tab',
          code: 'Tab',
          target: element,
        );

        expect(event.defaultPrevented, isTrue);
        expect(count, 1);
      });

      Keyboard.instance!.dispose();
    });

    testFakeAsync(
      'synthesize keyup when shortcut is handled by the system',
      (FakeAsync async) {
        // This can happen when the user clicks `cmd+alt+i` to open devtools. Here
        // is the sequence we receive from the browser in such case:
        //
        // keydown(cmd) -> keydown(alt) -> keydown(i) -> keyup(alt) -> keyup(cmd)
        //
        // There's no `keyup(i)`. The web engine is expected to synthesize a
        // `keyup(i)` event.
        Keyboard.initialize();

        final List<Map<String, dynamic>> messages = <Map<String, dynamic>>[];
        ui.window.onPlatformMessage = (String channel, ByteData? data,
            ui.PlatformMessageResponseCallback? callback) {
          messages.add(const JSONMessageCodec().decodeMessage(data) as Map<String, dynamic>);
        };

        dispatchKeyboardEvent(
          'keydown',
          key: 'Meta',
          code: 'MetaLeft',
          location: 1,
          isMetaPressed: true,
        );
        dispatchKeyboardEvent(
          'keydown',
          key: 'Alt',
          code: 'AltLeft',
          location: 1,
          isMetaPressed: true,
          isAltPressed: true,
        );
        dispatchKeyboardEvent(
          'keydown',
          key: 'i',
          code: 'KeyI',
          isMetaPressed: true,
          isAltPressed: true,
        );
        async.elapse(const Duration(milliseconds: 10));
        dispatchKeyboardEvent(
          'keyup',
          key: 'Meta',
          code: 'MetaLeft',
          location: 1,
          isAltPressed: true,
        );
        dispatchKeyboardEvent(
          'keyup',
          key: 'Alt',
          code: 'AltLeft',
          location: 1,
        );
        // Notice no `keyup` for "i".

        expect(messages, <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'keydown',
            'keymap': 'web',
            'key': 'Meta',
            'code': 'MetaLeft',
            'location': 1,
            //           meta
            'metaState': 0x8,
          },
          <String, dynamic>{
            'type': 'keydown',
            'keymap': 'web',
            'key': 'Alt',
            'code': 'AltLeft',
            'location': 1,
            //           alt   meta
            'metaState': 0x2 | 0x8,
          },
          <String, dynamic>{
            'type': 'keydown',
            'keymap': 'web',
            'key': 'i',
            'code': 'KeyI',
            'location': 0,
            //           alt   meta
            'metaState': 0x2 | 0x8,
          },
          <String, dynamic>{
            'type': 'keyup',
            'keymap': 'web',
            'key': 'Meta',
            'code': 'MetaLeft',
            'location': 1,
            //           alt
            'metaState': 0x2,
          },
          <String, dynamic>{
            'type': 'keyup',
            'keymap': 'web',
            'key': 'Alt',
            'code': 'AltLeft',
            'location': 1,
            'metaState': 0x0,
          },
        ]);
        messages.clear();

        // Still too eary to synthesize a keyup event.
        async.elapse(const Duration(milliseconds: 50));
        expect(messages, isEmpty);

        async.elapse(const Duration(seconds: 3));
        expect(messages, <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'keyup',
            'keymap': 'web',
            'key': 'i',
            'code': 'KeyI',
            'location': 0,
            'metaState': 0x0,
          }
        ]);

        Keyboard.instance!.dispose();
      },
    );

    testFakeAsync(
      'do not synthesize keyup when we receive repeat events',
      (FakeAsync async) {
        Keyboard.initialize();

        final List<Map<String, dynamic>> messages = <Map<String, dynamic>>[];
        ui.window.onPlatformMessage = (String channel, ByteData? data,
            ui.PlatformMessageResponseCallback? callback) {
          messages.add(const JSONMessageCodec().decodeMessage(data) as Map<String, dynamic>);
        };

        dispatchKeyboardEvent(
          'keydown',
          key: 'Meta',
          code: 'MetaLeft',
          location: 1,
          isMetaPressed: true,
        );
        dispatchKeyboardEvent(
          'keydown',
          key: 'Alt',
          code: 'AltLeft',
          location: 1,
          isMetaPressed: true,
          isAltPressed: true,
        );
        dispatchKeyboardEvent(
          'keydown',
          key: 'i',
          code: 'KeyI',
          isMetaPressed: true,
          isAltPressed: true,
        );
        async.elapse(const Duration(milliseconds: 10));
        dispatchKeyboardEvent(
          'keyup',
          key: 'Meta',
          code: 'MetaLeft',
          location: 1,
          isAltPressed: true,
        );
        dispatchKeyboardEvent(
          'keyup',
          key: 'Alt',
          code: 'AltLeft',
          location: 1,
        );
        // Notice no `keyup` for "i".

        messages.clear();

        // Spend more than 2 seconds sending repeat events and make sure no
        // keyup was synthesized.
        for (int i = 0; i < 20; i++) {
          async.elapse(const Duration(milliseconds: 100));
          dispatchKeyboardEvent(
            'keydown',
            key: 'i',
            code: 'KeyI',
            repeat: true,
          );
        }

        // There should be no synthesized keyup.
        expect(messages, hasLength(20));
        for (int i = 0; i < 20; i++) {
          expect(messages[i], <String, dynamic>{
            'type': 'keydown',
            'keymap': 'web',
            'key': 'i',
            'code': 'KeyI',
            'location': 0,
            'metaState': 0x0,
          });
        }
        messages.clear();

        Keyboard.instance!.dispose();
      },
    );

    testFakeAsync(
      'do not synthesize keyup when keys are not affected by meta modifiers',
      (FakeAsync async) {
        Keyboard.initialize();

        final List<Map<String, dynamic>> messages = <Map<String, dynamic>>[];
        ui.window.onPlatformMessage = (String channel, ByteData? data,
            ui.PlatformMessageResponseCallback? callback) {
          messages.add(const JSONMessageCodec().decodeMessage(data) as Map<String, dynamic>);
        };

        dispatchKeyboardEvent(
          'keydown',
          key: 'i',
          code: 'KeyI',
        );
        dispatchKeyboardEvent(
          'keydown',
          key: 'o',
          code: 'KeyO',
        );
        messages.clear();

        // Wait for a long-enough period of time and no events
        // should be synthesized
        async.elapse(const Duration(seconds: 3));
        expect(messages, hasLength(0));

        Keyboard.instance!.dispose();
      },
    );

    testFakeAsync('do not synthesize keyup for meta keys', (FakeAsync async) {
      Keyboard.initialize();

      final List<Map<String, dynamic>> messages = <Map<String, dynamic>>[];
      ui.window.onPlatformMessage = (String channel, ByteData? data,
          ui.PlatformMessageResponseCallback? callback) {
        messages.add(const JSONMessageCodec().decodeMessage(data) as Map<String, dynamic>);
      };

      dispatchKeyboardEvent(
        'keydown',
        key: 'Meta',
        code: 'MetaLeft',
        location: 1,
        isMetaPressed: true,
      );
      dispatchKeyboardEvent(
        'keydown',
        key: 'Alt',
        code: 'AltLeft',
        location: 1,
        isMetaPressed: true,
        isAltPressed: true,
      );
      dispatchKeyboardEvent(
        'keydown',
        key: 'i',
        code: 'KeyI',
        isMetaPressed: true,
        isAltPressed: true,
      );
      async.elapse(const Duration(milliseconds: 10));
      dispatchKeyboardEvent(
        'keyup',
        key: 'Meta',
        code: 'MetaLeft',
        location: 1,
        isAltPressed: true,
      );
      // Notice no `keyup` for "AltLeft" and "i".

      messages.clear();

      // There has been no repeat events for "AltLeft" nor "i". Only "i" should
      // synthesize a keyup event.
      async.elapse(const Duration(seconds: 3));
      expect(messages, <Map<String, dynamic>>[
        <String, dynamic>{
          'type': 'keyup',
          'keymap': 'web',
          'key': 'i',
          'code': 'KeyI',
          'location': 0,
          //           alt
          'metaState': 0x2,
        }
      ]);

      Keyboard.instance!.dispose();
    });
  });
}

typedef ElementCallback = void Function(html.Element element);

void useTextEditingElement(ElementCallback callback) {
  final html.InputElement input = html.InputElement();
  input.classes.add(HybridTextEditing.textEditingClass);

  try {
    html.document.body!.append(input);
    callback(input);
  } finally {
    input.remove();
  }
}

html.KeyboardEvent dispatchKeyboardEvent(
  String type, {
  html.EventTarget? target,
  String? key,
  String? code,
  int location = 0,
  bool repeat = false,
  bool isShiftPressed = false,
  bool isAltPressed = false,
  bool isControlPressed = false,
  bool isMetaPressed = false,
}) {
  target ??= html.window;

  final Function jsKeyboardEvent =
      // ignore: implicit_dynamic_function
      js_util.getProperty(html.window, 'KeyboardEvent') as Function;
  final List<dynamic> eventArgs = <dynamic>[
    type,
    <String, dynamic>{
      'key': key,
      'code': code,
      'location': location,
      'repeat': repeat,
      'shiftKey': isShiftPressed,
      'altKey': isAltPressed,
      'ctrlKey': isControlPressed,
      'metaKey': isMetaPressed,
      'bubbles': true,
      'cancelable': true,
    }
  ];
  // ignore: implicit_dynamic_function
  final html.KeyboardEvent event = js_util.callConstructor(
    jsKeyboardEvent,
    js_util.jsify(eventArgs) as List<Object?>,
  ) as html.KeyboardEvent;
  target.dispatchEvent(event);

  return event;
}

typedef FakeAsyncTest = void Function(FakeAsync);

void testFakeAsync(String description, FakeAsyncTest fn) {
  test(description, () {
    FakeAsync().run(fn);
  });
}
