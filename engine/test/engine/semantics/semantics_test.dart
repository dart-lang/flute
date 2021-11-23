// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('chrome || safari || firefox')

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:quiver/testing/async.dart';
import 'package:test/bootstrap/browser.dart';
import 'package:test/test.dart';

import 'package:ui/src/engine.dart' show domRenderer;
import 'package:ui/src/engine/browser_detection.dart';
import 'package:ui/src/engine/semantics.dart';
import 'package:ui/src/engine/vector_math.dart';
import 'package:ui/ui.dart' as ui;

import 'semantics_tester.dart';

DateTime _testTime = DateTime(2018, 12, 17);

EngineSemanticsOwner semantics() => EngineSemanticsOwner.instance;

void main() {
  internalBootstrapBrowserTest(() => testMain);
}

void testMain() {
  setUp(() {
    EngineSemanticsOwner.debugResetSemantics();
  });

  group(EngineSemanticsOwner, () {
    _testEngineSemanticsOwner();
  });
  group('longestIncreasingSubsequence', () {
    _testLongestIncreasingSubsequence();
  });
  group('container', () {
    _testContainer();
  });
  group('vertical scrolling', () {
    _testVerticalScrolling();
  });
  group('horizontal scrolling', () {
    _testHorizontalScrolling();
  });
  group('incrementable', () {
    _testIncrementables();
  });
  group('text field', () {
    _testTextField();
  });
  group('checkboxes, radio buttons and switches', () {
    _testCheckables();
  });
  group('tappable', () {
    _testTappable();
  });
  group('image', () {
    _testImage();
  });
  group('header', () {
    _testHeader();
  });
  group('live region', () {
    _testLiveRegion();
  });
}

void _testEngineSemanticsOwner() {
  test('instantiates a singleton', () {
    expect(semantics(), same(semantics()));
  });

  test('semantics is off by default', () {
    expect(semantics().semanticsEnabled, isFalse);
  });

  test('default mode is "unknown"', () {
    expect(semantics().mode, AccessibilityMode.unknown);
  });

  test('placeholder enables semantics', () async {
    domRenderer.reset(); // triggers `autoEnableOnTap` to be called
    expect(semantics().semanticsEnabled, isFalse);

    // Synthesize a click on the placeholder.
    final html.Element placeholder =
        appHostNode.querySelector('flt-semantics-placeholder')!;

    expect(placeholder.isConnected, isTrue);

    final html.Rectangle<num> rect = placeholder.getBoundingClientRect();
    placeholder.dispatchEvent(html.MouseEvent(
      'click',
      clientX: (rect.left + (rect.right - rect.left) / 2).floor(),
      clientY: (rect.top + (rect.bottom - rect.top) / 2).floor(),
    ));

    // On mobile semantics is enabled asynchronously.
    if (isMobile) {
      while (placeholder.isConnected!) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
    expect(semantics().semanticsEnabled, isTrue);
    expect(placeholder.isConnected, isFalse);
  });

  test('auto-enables semantics', () async {
    domRenderer.reset(); // triggers `autoEnableOnTap` to be called
    expect(semantics().semanticsEnabled, isFalse);

    final html.Element placeholder =
        appHostNode.querySelector('flt-semantics-placeholder')!;

    expect(placeholder.isConnected, isTrue);

    // Sending a semantics update should auto-enable engine semantics.
    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    updateNode(builder, id: 0);
    semantics().updateSemantics(builder.build());

    expect(semantics().semanticsEnabled, isTrue);

    // The placeholder should be removed
    expect(placeholder.isConnected, isFalse);
  });

  void renderSemantics({String? label, String? tooltip}) {
    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    updateNode(
      builder,
      id: 0,
      actions: 0,
      flags: 0,
      transform: Matrix4.identity().toFloat64(),
      rect: const ui.Rect.fromLTRB(0, 0, 20, 20),
      childrenInHitTestOrder: Int32List.fromList(<int>[1]),
      childrenInTraversalOrder: Int32List.fromList(<int>[1]),
    );
    updateNode(
      builder,
      id: 1,
      actions: 0,
      flags: 0,
      label: label ?? '',
      tooltip: tooltip ?? '',
      transform: Matrix4.identity().toFloat64(),
      rect: const ui.Rect.fromLTRB(0, 0, 20, 20),
    );
    semantics().updateSemantics(builder.build());
  }

  void renderLabel(String label) {
    renderSemantics(label: label);
  }

  test('produces an aria-label', () async {
    semantics().semanticsEnabled = true;

    // Create
    renderLabel('Hello');

    final Map<int, SemanticsObject> tree = semantics().debugSemanticsTree!;
    expect(tree.length, 2);
    expect(tree[0]!.id, 0);
    expect(tree[0]!.element.tagName.toLowerCase(), 'flt-semantics');
    expect(tree[1]!.id, 1);
    expect(tree[1]!.label, 'Hello');

    expectSemanticsTree('''
<sem style="$rootSemanticStyle">
  <sem-c>
    <sem aria-label="Hello">
      <sem-v>Hello</sem-v>
    </sem>
  </sem-c>
</sem>''');

    // Update
    renderLabel('World');

    expectSemanticsTree('''
<sem style="$rootSemanticStyle">
  <sem-c>
    <sem aria-label="World">
      <sem-v>World</sem-v>
    </sem>
  </sem-c>
</sem>''');

    // Remove
    renderLabel('');

    expectSemanticsTree('''
<sem style="$rootSemanticStyle">
  <sem-c>
    <sem></sem>
  </sem-c>
</sem>''');

    semantics().semanticsEnabled = false;
  });

  test('tooltip is part of label', () async {
    semantics().semanticsEnabled = true;

    // Create
    renderSemantics(tooltip: 'tooltip');

    final Map<int, SemanticsObject> tree = semantics().debugSemanticsTree!;
    expect(tree.length, 2);
    expect(tree[0]!.id, 0);
    expect(tree[0]!.element.tagName.toLowerCase(), 'flt-semantics');
    expect(tree[1]!.id, 1);
    expect(tree[1]!.tooltip, 'tooltip');

    expectSemanticsTree('''
<sem style="$rootSemanticStyle">
  <sem-c>
    <sem aria-label="tooltip">
      <sem-v>tooltip</sem-v>
    </sem>
  </sem-c>
</sem>''');

    // Update
    renderSemantics(label: 'Hello', tooltip: 'tooltip');

    expectSemanticsTree('''
<sem style="$rootSemanticStyle">
  <sem-c>
    <sem aria-label="tooltip\nHello">
      <sem-v>tooltip\nHello</sem-v>
    </sem>
  </sem-c>
</sem>''');

    // Remove
    renderSemantics();

    expectSemanticsTree('''
<sem style="$rootSemanticStyle">
  <sem-c>
    <sem></sem>
  </sem-c>
</sem>''');

    semantics().semanticsEnabled = false;
  });

  test('clears semantics tree when disabled', () {
    expect(semantics().debugSemanticsTree, isEmpty);
    semantics().semanticsEnabled = true;
    renderLabel('Hello');
    expect(semantics().debugSemanticsTree, isNotEmpty);
    semantics().semanticsEnabled = false;
    expect(semantics().debugSemanticsTree, isEmpty);
  });

  test('accepts standalone browser gestures', () {
    semantics().semanticsEnabled = true;
    expect(semantics().shouldAcceptBrowserGesture('click'), isTrue);
    semantics().semanticsEnabled = false;
  });

  test('rejects browser gestures accompanied by pointer click', () {
    FakeAsync().run((FakeAsync fakeAsync) {
      semantics()
        ..debugOverrideTimestampFunction(fakeAsync.getClock(_testTime).now)
        ..semanticsEnabled = true;
      expect(semantics().shouldAcceptBrowserGesture('click'), isTrue);
      semantics().receiveGlobalEvent(html.Event('pointermove'));
      expect(semantics().shouldAcceptBrowserGesture('click'), isFalse);

      // After 1 second of inactivity a browser gestures counts as standalone.
      fakeAsync.elapse(const Duration(seconds: 1));
      expect(semantics().shouldAcceptBrowserGesture('click'), isTrue);
      semantics().semanticsEnabled = false;
    });
  });
  test('checks shouldEnableSemantics for every global event', () {
    final MockSemanticsEnabler mockSemanticsEnabler = MockSemanticsEnabler();
    semantics().semanticsHelper.semanticsEnabler = mockSemanticsEnabler;
    final html.Event pointerEvent = html.Event('pointermove');

    semantics().receiveGlobalEvent(pointerEvent);

    // Verify the interactions.
    expect(
      mockSemanticsEnabler.shouldEnableSemanticsEvents,
      <html.Event>[pointerEvent],
    );
  });

  test('forwards events to framework if shouldEnableSemantics returns true', () {
    final MockSemanticsEnabler mockSemanticsEnabler = MockSemanticsEnabler();
    semantics().semanticsHelper.semanticsEnabler = mockSemanticsEnabler;
    final html.Event pointerEvent = html.Event('pointermove');
    mockSemanticsEnabler.shouldEnableSemanticsReturnValue = true;
    expect(semantics().receiveGlobalEvent(pointerEvent), isTrue);
  });
}

class MockSemanticsEnabler implements SemanticsEnabler {
  @override
  void dispose() {
  }

  @override
  bool get isWaitingToEnableSemantics => throw UnimplementedError();

  @override
  html.Element prepareAccessibilityPlaceholder() {
    throw UnimplementedError();
  }

  bool shouldEnableSemanticsReturnValue = false;
  final List<html.Event> shouldEnableSemanticsEvents = <html.Event>[];

  @override
  bool shouldEnableSemantics(html.Event event) {
    shouldEnableSemanticsEvents.add(event);
    return shouldEnableSemanticsReturnValue;
  }

  @override
  bool tryEnableSemantics(html.Event event) {
    throw UnimplementedError();
  }
}

void _testHeader() {
  test('renders heading role for headers', () {
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    updateNode(
      builder,
      id: 0,
      actions: 0,
      flags: 0 | ui.SemanticsFlag.isHeader.index,
      label: 'Header of the page',
      transform: Matrix4.identity().toFloat64(),
      rect: const ui.Rect.fromLTRB(0, 0, 100, 50),
    );

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem role="heading" aria-label="Header of the page" style="$rootSemanticStyle">
  <sem-v>Header of the page</sem-v>
</sem>
''');

    semantics().semanticsEnabled = false;
  });
}

void _testLongestIncreasingSubsequence() {
  void expectLis(List<int> list, List<int> seq) {
    expect(longestIncreasingSubsequence(list), seq);
  }

  test('trivial case', () {
    expectLis(<int>[], <int>[]);
  });

  test('longest in the middle', () {
    expectLis(<int>[10, 1, 2, 3, 0], <int>[1, 2, 3]);
  });

  test('longest at head', () {
    expectLis(<int>[1, 2, 3, 0], <int>[0, 1, 2]);
  });

  test('longest at tail', () {
    expectLis(<int>[10, 1, 2, 3], <int>[1, 2, 3]);
  });

  test('longest in a jagged pattern', () {
    expectLis(
        <int>[0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5], <int>[0, 1, 3, 5, 7, 9]);
  });

  test('fully sorted up', () {
    for (int count = 0; count < 100; count += 1) {
      expectLis(
        List<int>.generate(count, (int i) => 10 * i),
        List<int>.generate(count, (int i) => i),
      );
    }
  });

  test('fully sorted down', () {
    for (int count = 1; count < 100; count += 1) {
      expectLis(
        List<int>.generate(count, (int i) => 10 * (count - i)),
        <int>[count - 1],
      );
    }
  });
}

void _testContainer() {
  test('container node has no transform when there is no rect offset',
      () async {
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    const ui.Rect zeroOffsetRect = ui.Rect.fromLTRB(0, 0, 20, 20);
    updateNode(
      builder,
      id: 0,
      actions: 0,
      flags: 0,
      transform: Matrix4.identity().toFloat64(),
      rect: zeroOffsetRect,
      childrenInHitTestOrder: Int32List.fromList(<int>[1]),
      childrenInTraversalOrder: Int32List.fromList(<int>[1]),
    );

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem style="$rootSemanticStyle">
  <sem-c>
    <sem></sem>
  </sem-c>
</sem>''');

    final html.Element parentElement =
        appHostNode.querySelector('flt-semantics')!;
    final html.Element container =
        appHostNode.querySelector('flt-semantics-container')!;

    if (isMacOrIOS) {
      expect(parentElement.style.top, '0px');
      expect(parentElement.style.left, '0px');
      expect(container.style.top, '0px');
      expect(container.style.left, '0px');
    } else {
      expect(parentElement.style.top, '');
      expect(parentElement.style.left, '');
      expect(container.style.top, '');
      expect(container.style.left, '');
    }
    expect(parentElement.style.transform, '');
    expect(parentElement.style.transformOrigin, '');
    expect(container.style.transform, '');
    expect(container.style.transformOrigin, '');
    semantics().semanticsEnabled = false;
  });

  test('container node compensates for rect offset', () async {
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    updateNode(
      builder,
      id: 0,
      actions: 0,
      flags: 0,
      transform: Matrix4.identity().toFloat64(),
      rect: const ui.Rect.fromLTRB(10, 10, 20, 20),
      childrenInHitTestOrder: Int32List.fromList(<int>[1]),
      childrenInTraversalOrder: Int32List.fromList(<int>[1]),
    );

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem style="$rootSemanticStyle">
  <sem-c>
    <sem></sem>
  </sem-c>
</sem>''');

    final html.Element parentElement =
        appHostNode.querySelector('flt-semantics')!;
    final html.Element container =
        appHostNode.querySelector('flt-semantics-container')!;

    expect(parentElement.style.transform, 'matrix(1, 0, 0, 1, 10, 10)');
    expect(parentElement.style.transformOrigin, '0px 0px 0px');
    expect(container.style.top, '-10px');
    expect(container.style.left, '-10px');
    semantics().semanticsEnabled = false;
  });

  test('0 offsets are not removed for voiceover', () async {
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    updateNode(
      builder,
      id: 0,
      actions: 0,
      flags: 0,
      transform: Matrix4.identity().toFloat64(),
      rect: const ui.Rect.fromLTRB(0, 0, 20, 20),
      childrenInHitTestOrder: Int32List.fromList(<int>[1]),
      childrenInTraversalOrder: Int32List.fromList(<int>[1]),
    );

    semantics().updateSemantics(builder.build());
    if (browserEngine == BrowserEngine.edge) {
      expectSemanticsTree('''
<sem style="color: rgba(0, 0, 0, 0); filter: opacity(0%)">
  <sem-c>
    <sem></sem>
  </sem-c>
</sem>''');
    } else {
      expectSemanticsTree('''
<sem style="$rootSemanticStyle">
  <sem-c>
    <sem></sem>
  </sem-c>
</sem>''');
    }

    final html.Element parentElement =
        appHostNode.querySelector('flt-semantics')!;
    final html.Element container =
        appHostNode.querySelector('flt-semantics-container')!;

    if (isMacOrIOS) {
      expect(parentElement.style.top, '0px');
      expect(parentElement.style.left, '0px');
      expect(container.style.top, '0px');
      expect(container.style.left, '0px');
    } else {
      expect(parentElement.style.top, '');
      expect(parentElement.style.left, '');
      expect(container.style.top, '');
      expect(container.style.left, '');
    }
    expect(parentElement.style.transform, '');
    expect(parentElement.style.transformOrigin, '');
    expect(container.style.transform, '');
    expect(container.style.transformOrigin, '');

    semantics().semanticsEnabled = false;
  });
}

void _testVerticalScrolling() {
  test('renders an empty scrollable node', () async {
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    updateNode(
      builder,
      id: 0,
      actions: 0 | ui.SemanticsAction.scrollUp.index,
      flags: 0,
      transform: Matrix4.identity().toFloat64(),
      rect: const ui.Rect.fromLTRB(0, 0, 50, 100),
    );

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem style="$rootSemanticStyle; touch-action: none; overflow-y: scroll">
</sem>''');

    semantics().semanticsEnabled = false;
  });

  test('scrollable node with children has a container node', () async {
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    updateNode(
      builder,
      id: 0,
      actions: 0 | ui.SemanticsAction.scrollUp.index,
      flags: 0,
      transform: Matrix4.identity().toFloat64(),
      rect: const ui.Rect.fromLTRB(0, 0, 50, 100),
      childrenInHitTestOrder: Int32List.fromList(<int>[1]),
      childrenInTraversalOrder: Int32List.fromList(<int>[1]),
    );

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem style="$rootSemanticStyle; touch-action: none; overflow-y: scroll">
  <sem-c>
    <sem></sem>
  </sem-c>
</sem>''');

    final html.Element? scrollable = findScrollable();
    expect(scrollable, isNotNull);

    // When there's less content than the available size the neutral scrollTop
    // is 0.
    expect(scrollable!.scrollTop, 0);

    semantics().semanticsEnabled = false;
  });

  test('scrollable node dispatches scroll events', () async {
    final StreamController<int> idLogController = StreamController<int>();
    final StreamController<ui.SemanticsAction> actionLogController =
        StreamController<ui.SemanticsAction>();
    final Stream<int> idLog = idLogController.stream.asBroadcastStream();
    final Stream<ui.SemanticsAction> actionLog =
        actionLogController.stream.asBroadcastStream();

    // The browser kicks us out of the test zone when the scroll event happens.
    // We memorize the test zone so we can call expect when the callback is
    // fired.
    final Zone testZone = Zone.current;

    ui.window.onSemanticsAction =
        (int id, ui.SemanticsAction action, ByteData? args) {
      idLogController.add(id);
      actionLogController.add(action);
      testZone.run(() {
        expect(args, null);
      });
    };
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    updateNode(
      builder,
      id: 0,
      actions: 0 |
          ui.SemanticsAction.scrollUp.index |
          ui.SemanticsAction.scrollDown.index,
      flags: 0,
      transform: Matrix4.identity().toFloat64(),
      rect: const ui.Rect.fromLTRB(0, 0, 50, 100),
      childrenInHitTestOrder: Int32List.fromList(<int>[1, 2, 3]),
      childrenInTraversalOrder: Int32List.fromList(<int>[1, 2, 3]),
    );

    for (int id = 1; id <= 5; id++) {
      updateNode(
        builder,
        id: id,
        actions: 0,
        flags: 0,
        transform: Matrix4.translationValues(0, 50.0 * id, 0).toFloat64(),
        rect: const ui.Rect.fromLTRB(0, 0, 50, 50),
      );
    }

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem style="$rootSemanticStyle; touch-action: none; overflow-y: scroll">
  <sem-c>
    <sem></sem>
    <sem></sem>
    <sem></sem>
  </sem-c>
</sem>''');

    final html.Element? scrollable = findScrollable();
    expect(scrollable, isNotNull);

    // When there's more content than the available size the neutral scrollTop
    // is greater than 0 with a maximum of 10 or 9.
    int browserMaxScrollDiff = 0;
    // The max scroll value varies between `9` and `10` for Safari desktop
    // browsers.
    if (browserEngine == BrowserEngine.webkit &&
        operatingSystem == OperatingSystem.macOs) {
      browserMaxScrollDiff = 1;
    }

    expect(scrollable!.scrollTop >= (10 - browserMaxScrollDiff), isTrue);

    scrollable.scrollTop = 20;
    expect(scrollable.scrollTop, 20);
    expect(await idLog.first, 0);
    expect(await actionLog.first, ui.SemanticsAction.scrollUp);
    // Engine semantics returns scroll top back to neutral.
    expect(scrollable.scrollTop >= (10 - browserMaxScrollDiff), isTrue);

    scrollable.scrollTop = 5;
    expect(scrollable.scrollTop >= (5 - browserMaxScrollDiff), isTrue);
    expect(await idLog.first, 0);
    expect(await actionLog.first, ui.SemanticsAction.scrollDown);
    // Engine semantics returns scroll top back to neutral.
    expect(scrollable.scrollTop >= (10 - browserMaxScrollDiff), isTrue);

    semantics().semanticsEnabled = false;
  });
}

void _testHorizontalScrolling() {
  test('renders an empty scrollable node', () async {
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    updateNode(
      builder,
      id: 0,
      actions: 0 | ui.SemanticsAction.scrollLeft.index,
      flags: 0,
      transform: Matrix4.identity().toFloat64(),
      rect: const ui.Rect.fromLTRB(0, 0, 100, 50),
    );

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem style="$rootSemanticStyle; touch-action: none; overflow-x: scroll">
</sem>''');

    semantics().semanticsEnabled = false;
  });

  test('scrollable node with children has a container node', () async {
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    updateNode(
      builder,
      id: 0,
      actions: 0 | ui.SemanticsAction.scrollLeft.index,
      flags: 0,
      transform: Matrix4.identity().toFloat64(),
      rect: const ui.Rect.fromLTRB(0, 0, 100, 50),
      childrenInHitTestOrder: Int32List.fromList(<int>[1]),
      childrenInTraversalOrder: Int32List.fromList(<int>[1]),
    );

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem style="$rootSemanticStyle; touch-action: none; overflow-x: scroll">
  <sem-c>
    <sem></sem>
  </sem-c>
</sem>''');

    final html.Element? scrollable = findScrollable();
    expect(scrollable, isNotNull);

    // When there's less content than the available size the neutral
    // scrollLeft is 0.
    expect(scrollable!.scrollLeft, 0);

    semantics().semanticsEnabled = false;
  });

  test('scrollable node dispatches scroll events', () async {
    final SemanticsActionLogger logger = SemanticsActionLogger();
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    updateNode(
      builder,
      id: 0,
      actions: 0 |
          ui.SemanticsAction.scrollLeft.index |
          ui.SemanticsAction.scrollRight.index,
      flags: 0,
      transform: Matrix4.identity().toFloat64(),
      rect: const ui.Rect.fromLTRB(0, 0, 100, 50),
      childrenInHitTestOrder: Int32List.fromList(<int>[1, 2, 3]),
      childrenInTraversalOrder: Int32List.fromList(<int>[1, 2, 3]),
    );

    for (int id = 1; id <= 3; id++) {
      updateNode(
        builder,
        id: id,
        actions: 0,
        flags: 0,
        transform: Matrix4.translationValues(50.0 * id, 0, 0).toFloat64(),
        rect: const ui.Rect.fromLTRB(0, 0, 50, 50),
      );
    }

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem style="$rootSemanticStyle; touch-action: none; overflow-x: scroll">
  <sem-c>
    <sem></sem>
    <sem></sem>
    <sem></sem>
  </sem-c>
</sem>''');

    final html.Element? scrollable = findScrollable();
    expect(scrollable, isNotNull);

    // When there's more content than the available size the neutral scrollTop
    // is greater than 0 with a maximum of 10.
    int browserMaxScrollDiff = 0;
    // The max scroll value varies between `9` and `10` for Safari desktop
    // browsers.
    if (browserEngine == BrowserEngine.webkit &&
        operatingSystem == OperatingSystem.macOs) {
      browserMaxScrollDiff = 1;
    }
    expect(scrollable!.scrollLeft >= (10 - browserMaxScrollDiff), isTrue);

    scrollable.scrollLeft = 20;
    expect(scrollable.scrollLeft, 20);
    expect(await logger.idLog.first, 0);
    expect(await logger.actionLog.first, ui.SemanticsAction.scrollLeft);
    // Engine semantics returns scroll position back to neutral.
    expect(scrollable.scrollLeft >= (10 - browserMaxScrollDiff), isTrue);

    scrollable.scrollLeft = 5;
    expect(scrollable.scrollLeft >= (5 - browserMaxScrollDiff), isTrue);
    expect(await logger.idLog.first, 0);
    expect(await logger.actionLog.first, ui.SemanticsAction.scrollRight);
    // Engine semantics returns scroll top back to neutral.
    expect(scrollable.scrollLeft >= (10 - browserMaxScrollDiff), isTrue);

    semantics().semanticsEnabled = false;
  });
}

void _testIncrementables() {
  test('renders a trivial incrementable node', () async {
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    updateNode(
      builder,
      id: 0,
      actions: 0 | ui.SemanticsAction.increase.index,
      flags: 0,
      value: 'd',
      transform: Matrix4.identity().toFloat64(),
      rect: const ui.Rect.fromLTRB(0, 0, 100, 50),
    );

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem style="$rootSemanticStyle">
  <input aria-valuenow="1" aria-valuetext="d" aria-valuemax="1" aria-valuemin="1">
</sem>''');

    semantics().semanticsEnabled = false;
  });

  test('increments', () async {
    final SemanticsActionLogger logger = SemanticsActionLogger();
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    updateNode(
      builder,
      id: 0,
      actions: 0 | ui.SemanticsAction.increase.index,
      flags: 0,
      value: 'd',
      increasedValue: 'e',
      transform: Matrix4.identity().toFloat64(),
      rect: const ui.Rect.fromLTRB(0, 0, 100, 50),
    );

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem style="$rootSemanticStyle">
  <input aria-valuenow="1" aria-valuetext="d" aria-valuemax="2" aria-valuemin="1">
</sem>''');

    final html.InputElement input = appHostNode.querySelector('input')! as html.InputElement;
    input.value = '2';
    input.dispatchEvent(html.Event('change'));

    expect(await logger.idLog.first, 0);
    expect(await logger.actionLog.first, ui.SemanticsAction.increase);

    semantics().semanticsEnabled = false;
  });

  test('decrements', () async {
    final SemanticsActionLogger logger = SemanticsActionLogger();
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    updateNode(
      builder,
      id: 0,
      actions: 0 | ui.SemanticsAction.decrease.index,
      flags: 0,
      value: 'd',
      decreasedValue: 'c',
      transform: Matrix4.identity().toFloat64(),
      rect: const ui.Rect.fromLTRB(0, 0, 100, 50),
    );

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem style="$rootSemanticStyle">
  <input aria-valuenow="1" aria-valuetext="d" aria-valuemax="1" aria-valuemin="0">
</sem>''');

    final html.InputElement input = appHostNode.querySelector('input')! as html.InputElement;
    input.value = '0';
    input.dispatchEvent(html.Event('change'));

    expect(await logger.idLog.first, 0);
    expect(await logger.actionLog.first, ui.SemanticsAction.decrease);

    semantics().semanticsEnabled = false;
  },
      // TODO(yjbanov): https://github.com/flutter/flutter/issues/50754
      skip: browserEngine == BrowserEngine.edge);

  test('renders a node that can both increment and decrement', () async {
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    updateNode(
      builder,
      id: 0,
      actions: 0 |
          ui.SemanticsAction.decrease.index |
          ui.SemanticsAction.increase.index,
      flags: 0,
      value: 'd',
      increasedValue: 'e',
      decreasedValue: 'c',
      transform: Matrix4.identity().toFloat64(),
      rect: const ui.Rect.fromLTRB(0, 0, 100, 50),
    );

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem style="$rootSemanticStyle">
  <input aria-valuenow="1" aria-valuetext="d" aria-valuemax="2" aria-valuemin="0">
</sem>''');

    semantics().semanticsEnabled = false;
  },
      // TODO(yjbanov): https://github.com/flutter/flutter/issues/50754
      skip: browserEngine == BrowserEngine.edge);
}

void _testTextField() {
  test('renders a text field', () async {
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    updateNode(
      builder,
      id: 0,
      actions: 0 | ui.SemanticsAction.tap.index,
      flags: 0 | ui.SemanticsFlag.isTextField.index,
      value: 'hello',
      transform: Matrix4.identity().toFloat64(),
      rect: const ui.Rect.fromLTRB(0, 0, 100, 50),
    );

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem style="$rootSemanticStyle">
  <input value="hello" />
</sem>''');

    semantics().semanticsEnabled = false;
  },
      // TODO(yjbanov): https://github.com/flutter/flutter/issues/50754
      skip: browserEngine == BrowserEngine.edge);

  // TODO(yjbanov): this test will need to be adjusted for Safari when we add
  //                Safari testing.
  test('sends a tap action when text field is activated', () async {
    final SemanticsActionLogger logger = SemanticsActionLogger();
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    updateNode(
      builder,
      id: 0,
      actions: 0 | ui.SemanticsAction.tap.index,
      flags: 0 | ui.SemanticsFlag.isTextField.index,
      value: 'hello',
      transform: Matrix4.identity().toFloat64(),
      rect: const ui.Rect.fromLTRB(0, 0, 100, 50),
    );

    semantics().updateSemantics(builder.build());

    final html.Element textField =
        appHostNode.querySelector('input[data-semantics-role="text-field"]')!;

    expect(appHostNode.activeElement, isNot(textField));

    textField.focus();

    expect(appHostNode.activeElement, textField);
    expect(await logger.idLog.first, 0);
    expect(await logger.actionLog.first, ui.SemanticsAction.tap);

    semantics().semanticsEnabled = false;
  }, // TODO(yjbanov): https://github.com/flutter/flutter/issues/46638
      // TODO(yjbanov): https://github.com/flutter/flutter/issues/50590
      // TODO(yjbanov): https://github.com/flutter/flutter/issues/50754
      skip: browserEngine != BrowserEngine.blink);
}

void _testCheckables() {
  test('renders a switched on switch element', () async {
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    updateNode(
      builder,
      id: 0,
      actions: 0 | ui.SemanticsAction.tap.index,
      flags: 0 |
          ui.SemanticsFlag.isEnabled.index |
          ui.SemanticsFlag.hasEnabledState.index |
          ui.SemanticsFlag.hasToggledState.index |
          ui.SemanticsFlag.isToggled.index,
      transform: Matrix4.identity().toFloat64(),
      rect: const ui.Rect.fromLTRB(0, 0, 100, 50),
    );

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem role="switch" aria-checked="true" style="$rootSemanticStyle"></sem>
''');

    semantics().semanticsEnabled = false;
  },
      // TODO(yjbanov): https://github.com/flutter/flutter/issues/50754
      skip: browserEngine == BrowserEngine.edge);

  test('renders a switched on disabled switch element', () async {
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    updateNode(
      builder,
      id: 0,
      actions: 0 | ui.SemanticsAction.tap.index,
      flags: 0 |
          ui.SemanticsFlag.hasToggledState.index |
          ui.SemanticsFlag.isToggled.index |
          ui.SemanticsFlag.hasEnabledState.index,
      transform: Matrix4.identity().toFloat64(),
      rect: const ui.Rect.fromLTRB(0, 0, 100, 50),
    );

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem role="switch" aria-disabled="true" aria-checked="true" style="$rootSemanticStyle"></sem>
''');

    semantics().semanticsEnabled = false;
  },
      // TODO(yjbanov): https://github.com/flutter/flutter/issues/50754
      skip: browserEngine == BrowserEngine.edge);

  test('renders a switched off switch element', () async {
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    updateNode(
      builder,
      id: 0,
      actions: 0 | ui.SemanticsAction.tap.index,
      flags: 0 |
          ui.SemanticsFlag.hasToggledState.index |
          ui.SemanticsFlag.isEnabled.index |
          ui.SemanticsFlag.hasEnabledState.index,
      transform: Matrix4.identity().toFloat64(),
      rect: const ui.Rect.fromLTRB(0, 0, 100, 50),
    );

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem role="switch" aria-checked="false" style="$rootSemanticStyle"></sem>
''');

    semantics().semanticsEnabled = false;
  },
      // TODO(yjbanov): https://github.com/flutter/flutter/issues/50754
      skip: browserEngine == BrowserEngine.edge);

  test('renders a checked checkbox', () async {
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    updateNode(
      builder,
      id: 0,
      actions: 0 | ui.SemanticsAction.tap.index,
      flags: 0 |
          ui.SemanticsFlag.isEnabled.index |
          ui.SemanticsFlag.hasEnabledState.index |
          ui.SemanticsFlag.hasCheckedState.index |
          ui.SemanticsFlag.isChecked.index,
      transform: Matrix4.identity().toFloat64(),
      rect: const ui.Rect.fromLTRB(0, 0, 100, 50),
    );

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem role="checkbox" aria-checked="true" style="$rootSemanticStyle"></sem>
''');

    semantics().semanticsEnabled = false;
  },
      // TODO(yjbanov): https://github.com/flutter/flutter/issues/50754
      skip: browserEngine == BrowserEngine.edge);

  test('renders a checked disabled checkbox', () async {
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    updateNode(
      builder,
      id: 0,
      actions: 0 | ui.SemanticsAction.tap.index,
      flags: 0 |
          ui.SemanticsFlag.hasCheckedState.index |
          ui.SemanticsFlag.hasEnabledState.index |
          ui.SemanticsFlag.isChecked.index,
      transform: Matrix4.identity().toFloat64(),
      rect: const ui.Rect.fromLTRB(0, 0, 100, 50),
    );

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem role="checkbox" aria-disabled="true" aria-checked="true" style="$rootSemanticStyle"></sem>
''');

    semantics().semanticsEnabled = false;
  },
      // TODO(yjbanov): https://github.com/flutter/flutter/issues/50754
      skip: browserEngine == BrowserEngine.edge);

  test('renders an unchecked checkbox', () async {
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    updateNode(
      builder,
      id: 0,
      actions: 0 | ui.SemanticsAction.tap.index,
      flags: 0 |
          ui.SemanticsFlag.hasCheckedState.index |
          ui.SemanticsFlag.isEnabled.index |
          ui.SemanticsFlag.hasEnabledState.index,
      transform: Matrix4.identity().toFloat64(),
      rect: const ui.Rect.fromLTRB(0, 0, 100, 50),
    );

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem role="checkbox" aria-checked="false" style="$rootSemanticStyle"></sem>
''');

    semantics().semanticsEnabled = false;
  },
      // TODO(yjbanov): https://github.com/flutter/flutter/issues/50754
      skip: browserEngine == BrowserEngine.edge);

  test('renders a checked radio button', () async {
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    updateNode(
      builder,
      id: 0,
      actions: 0 | ui.SemanticsAction.tap.index,
      flags: 0 |
          ui.SemanticsFlag.isEnabled.index |
          ui.SemanticsFlag.hasEnabledState.index |
          ui.SemanticsFlag.hasCheckedState.index |
          ui.SemanticsFlag.isInMutuallyExclusiveGroup.index |
          ui.SemanticsFlag.isChecked.index,
      transform: Matrix4.identity().toFloat64(),
      rect: const ui.Rect.fromLTRB(0, 0, 100, 50),
    );

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem role="radio" aria-checked="true" style="$rootSemanticStyle"></sem>
''');

    semantics().semanticsEnabled = false;
  },
      // TODO(yjbanov): https://github.com/flutter/flutter/issues/50754
      skip: browserEngine == BrowserEngine.edge);

  test('renders a checked disabled radio button', () async {
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    updateNode(
      builder,
      id: 0,
      actions: 0 | ui.SemanticsAction.tap.index,
      flags: 0 |
          ui.SemanticsFlag.hasEnabledState.index |
          ui.SemanticsFlag.hasCheckedState.index |
          ui.SemanticsFlag.isInMutuallyExclusiveGroup.index |
          ui.SemanticsFlag.isChecked.index,
      transform: Matrix4.identity().toFloat64(),
      rect: const ui.Rect.fromLTRB(0, 0, 100, 50),
    );

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem role="radio" aria-disabled="true" aria-checked="true" style="$rootSemanticStyle"></sem>
''');

    semantics().semanticsEnabled = false;
  },
      // TODO(yjbanov): https://github.com/flutter/flutter/issues/50754
      skip: browserEngine == BrowserEngine.edge);

  test('renders an unchecked checkbox', () async {
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    updateNode(
      builder,
      id: 0,
      actions: 0 | ui.SemanticsAction.tap.index,
      flags: 0 |
          ui.SemanticsFlag.isEnabled.index |
          ui.SemanticsFlag.hasEnabledState.index |
          ui.SemanticsFlag.hasCheckedState.index |
          ui.SemanticsFlag.isInMutuallyExclusiveGroup.index,
      transform: Matrix4.identity().toFloat64(),
      rect: const ui.Rect.fromLTRB(0, 0, 100, 50),
    );

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem role="radio" aria-checked="false" style="$rootSemanticStyle"></sem>
''');

    semantics().semanticsEnabled = false;
  },
      // TODO(yjbanov): https://github.com/flutter/flutter/issues/50754
      skip: browserEngine == BrowserEngine.edge);
}

void _testTappable() {
  test('renders an enabled tappable widget', () async {
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final SemanticsTester tester = SemanticsTester(semantics());
    tester.updateNode(
      id: 0,
      hasTap: true,
      hasEnabledState: true,
      isEnabled: true,
      isButton: true,
      rect: const ui.Rect.fromLTRB(0, 0, 100, 50),
    );
    tester.apply();

    expectSemanticsTree('''
<sem role="button" style="$rootSemanticStyle"></sem>
''');

    expect(tester.getSemanticsObject(0).element.tabIndex, 0);

    semantics().semanticsEnabled = false;
  },
      // TODO(yjbanov): https://github.com/flutter/flutter/issues/50754
      skip: browserEngine == BrowserEngine.edge);

  test('renders a disabled tappable widget', () async {
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    updateNode(
      builder,
      id: 0,
      actions: 0 | ui.SemanticsAction.tap.index,
      flags: 0 |
          ui.SemanticsFlag.hasEnabledState.index |
          ui.SemanticsFlag.isButton.index,
      transform: Matrix4.identity().toFloat64(),
      rect: const ui.Rect.fromLTRB(0, 0, 100, 50),
    );

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem role="button" aria-disabled="true" style="$rootSemanticStyle"></sem>
''');

    semantics().semanticsEnabled = false;
  },
      // TODO(yjbanov): https://github.com/flutter/flutter/issues/50754
      skip: browserEngine == BrowserEngine.edge);
}

void _testImage() {
  test('renders an image with no child nodes and with a label', () async {
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    updateNode(
      builder,
      id: 0,
      actions: 0,
      flags: 0 | ui.SemanticsFlag.isImage.index,
      label: 'Test Image Label',
      transform: Matrix4.identity().toFloat64(),
      rect: const ui.Rect.fromLTRB(0, 0, 100, 50),
    );

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem role="img" aria-label="Test Image Label" style="$rootSemanticStyle"></sem>
''');

    semantics().semanticsEnabled = false;
  },
      // TODO(yjbanov): https://github.com/flutter/flutter/issues/50754
      skip: browserEngine == BrowserEngine.edge);

  test('renders an image with a child node and with a label', () async {
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    updateNode(
      builder,
      id: 0,
      actions: 0,
      flags: 0 | ui.SemanticsFlag.isImage.index,
      label: 'Test Image Label',
      transform: Matrix4.identity().toFloat64(),
      rect: const ui.Rect.fromLTRB(0, 0, 100, 50),
      childrenInHitTestOrder: Int32List.fromList(<int>[1]),
      childrenInTraversalOrder: Int32List.fromList(<int>[1]),
    );

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem style="$rootSemanticStyle">
  <sem-img role="img" aria-label="Test Image Label">
  </sem-img>
  <sem-c>
    <sem></sem>
  </sem-c>
</sem>''');

    semantics().semanticsEnabled = false;
  },
      // TODO(yjbanov): https://github.com/flutter/flutter/issues/50754
      skip: browserEngine == BrowserEngine.edge);

  test('renders an image with no child nodes without a label', () async {
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    updateNode(
      builder,
      id: 0,
      actions: 0,
      flags: 0 | ui.SemanticsFlag.isImage.index,
      transform: Matrix4.identity().toFloat64(),
      rect: const ui.Rect.fromLTRB(0, 0, 100, 50),
    );

    semantics().updateSemantics(builder.build());
    expectSemanticsTree(
        '''<sem role="img" style="$rootSemanticStyle"></sem>''');

    semantics().semanticsEnabled = false;
  },
      // TODO(yjbanov): https://github.com/flutter/flutter/issues/50754
      skip: browserEngine == BrowserEngine.edge);

  test('renders an image with a child node and without a label', () async {
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    updateNode(
      builder,
      id: 0,
      actions: 0,
      flags: 0 | ui.SemanticsFlag.isImage.index,
      transform: Matrix4.identity().toFloat64(),
      rect: const ui.Rect.fromLTRB(0, 0, 100, 50),
      childrenInHitTestOrder: Int32List.fromList(<int>[1]),
      childrenInTraversalOrder: Int32List.fromList(<int>[1]),
    );

    semantics().updateSemantics(builder.build());
    expectSemanticsTree('''
<sem style="$rootSemanticStyle">
  <sem-img role="img">
  </sem-img>
  <sem-c>
    <sem></sem>
  </sem-c>
</sem>''');

    semantics().semanticsEnabled = false;
  },
      // TODO(yjbanov): https://github.com/flutter/flutter/issues/50754
      skip: browserEngine == BrowserEngine.edge);
}

void _testLiveRegion() {
  test('renders a live region if there is a label', () async {
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    updateNode(
      builder,
      id: 0,
      actions: 0,
      label: 'This is a snackbar',
      flags: 0 | ui.SemanticsFlag.isLiveRegion.index,
      transform: Matrix4.identity().toFloat64(),
      rect: const ui.Rect.fromLTRB(0, 0, 100, 50),
    );
    semantics().updateSemantics(builder.build());

    expectSemanticsTree('''
<sem aria-label="This is a snackbar" aria-live="polite" style="$rootSemanticStyle"><sem-v>This is a snackbar</sem-v></sem>
''');

    semantics().semanticsEnabled = false;
  },
      // TODO(yjbanov): https://github.com/flutter/flutter/issues/50754
      skip: browserEngine == BrowserEngine.edge);

  test('does not render a live region if there is no label', () async {
    semantics()
      ..debugOverrideTimestampFunction(() => _testTime)
      ..semanticsEnabled = true;

    final ui.SemanticsUpdateBuilder builder = ui.SemanticsUpdateBuilder();
    updateNode(
      builder,
      id: 0,
      flags: 0 | ui.SemanticsFlag.isLiveRegion.index,
      actions: 0,
      transform: Matrix4.identity().toFloat64(),
      rect: const ui.Rect.fromLTRB(0, 0, 100, 50),
    );
    semantics().updateSemantics(builder.build());

    expectSemanticsTree('''
<sem style="$rootSemanticStyle"></sem>
''');

    semantics().semanticsEnabled = false;
  });
}

/// A facade in front of [ui.SemanticsUpdateBuilder.updateNode] that
/// supplies default values for semantics attributes.
// TODO(yjbanov): move this to TestSemanticsBuilder
void updateNode(
  ui.SemanticsUpdateBuilder builder, {
  int id = 0,
  int flags = 0,
  int actions = 0,
  int maxValueLength = 0,
  int currentValueLength = 0,
  int textSelectionBase = 0,
  int textSelectionExtent = 0,
  int platformViewId = 0,
  int scrollChildren = 0,
  int scrollIndex = 0,
  double scrollPosition = 0.0,
  double scrollExtentMax = 0.0,
  double scrollExtentMin = 0.0,
  double elevation = 0.0,
  double thickness = 0.0,
  ui.Rect rect = ui.Rect.zero,
  String label = '',
  List<ui.StringAttribute> labelAttributes = const <ui.StringAttribute>[],
  String hint = '',
  List<ui.StringAttribute> hintAttributes = const <ui.StringAttribute>[],
  String value = '',
  List<ui.StringAttribute> valueAttributes = const <ui.StringAttribute>[],
  String increasedValue = '',
  List<ui.StringAttribute> increasedValueAttributes = const <ui.StringAttribute>[],
  String decreasedValue = '',
  List<ui.StringAttribute> decreasedValueAttributes = const <ui.StringAttribute>[],
  String tooltip = '',
  ui.TextDirection textDirection = ui.TextDirection.ltr,
  Float64List? transform,
  Int32List? childrenInTraversalOrder,
  Int32List? childrenInHitTestOrder,
  Int32List? additionalActions,
}) {
  transform ??= Float64List.fromList(Matrix4.identity().storage);
  childrenInTraversalOrder ??= Int32List(0);
  childrenInHitTestOrder ??= Int32List(0);
  additionalActions ??= Int32List(0);
  builder.updateNode(
    id: id,
    flags: flags,
    actions: actions,
    maxValueLength: maxValueLength,
    currentValueLength: currentValueLength,
    textSelectionBase: textSelectionBase,
    textSelectionExtent: textSelectionExtent,
    platformViewId: platformViewId,
    scrollChildren: scrollChildren,
    scrollIndex: scrollIndex,
    scrollPosition: scrollPosition,
    scrollExtentMax: scrollExtentMax,
    scrollExtentMin: scrollExtentMin,
    elevation: elevation,
    thickness: thickness,
    rect: rect,
    label: label,
    labelAttributes: labelAttributes,
    hint: hint,
    hintAttributes: hintAttributes,
    value: value,
    valueAttributes: valueAttributes,
    increasedValue: increasedValue,
    increasedValueAttributes: increasedValueAttributes,
    decreasedValue: decreasedValue,
    decreasedValueAttributes: decreasedValueAttributes,
    tooltip: tooltip,
    textDirection: textDirection,
    transform: transform,
    childrenInTraversalOrder: childrenInTraversalOrder,
    childrenInHitTestOrder: childrenInHitTestOrder,
    additionalActions: additionalActions,
  );
}
