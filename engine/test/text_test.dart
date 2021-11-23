// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html';

import 'package:test/bootstrap/browser.dart';
import 'package:test/test.dart';

import 'package:ui/src/engine.dart';
import 'package:ui/ui.dart';

import 'html/paragraph/helper.dart';
import 'matchers.dart';

void main() {
  internalBootstrapBrowserTest(() => testMain);
}

Future<void> testMain() async {
  const double baselineRatio = 1.1662499904632568;

  await webOnlyInitializeTestDomRenderer();

  late String fallback;
  setUp(() {
    if (operatingSystem == OperatingSystem.macOs ||
        operatingSystem == OperatingSystem.iOs) {
      fallback = '-apple-system, BlinkMacSystemFont';
    } else {
      fallback = 'Arial';
    }
  });

  test('predictably lays out a single-line paragraph', () {
    for (final double fontSize in <double>[10.0, 20.0, 30.0, 40.0]) {
      final ParagraphBuilder builder = ParagraphBuilder(ParagraphStyle(
        fontFamily: 'Ahem',
        fontStyle: FontStyle.normal,
        fontWeight: FontWeight.normal,
        fontSize: fontSize,
      ));
      builder.addText('Test');
      final Paragraph paragraph = builder.build();
      paragraph.layout(const ParagraphConstraints(width: 400.0));

      expect(paragraph.height, fontSize);
      expect(paragraph.width, 400.0);
      expect(paragraph.minIntrinsicWidth, fontSize * 4.0);
      expect(paragraph.maxIntrinsicWidth, fontSize * 4.0);
      expect(paragraph.alphabeticBaseline, fontSize * .8);
      expect(
        paragraph.ideographicBaseline,
        within(
            distance: 0.001,
            from: paragraph.alphabeticBaseline * baselineRatio),
      );
    }
  });

  test('predictably lays out a multi-line paragraph', () {
    for (final double fontSize in <double>[10.0, 20.0, 30.0, 40.0]) {
      final ParagraphBuilder builder = ParagraphBuilder(ParagraphStyle(
        fontFamily: 'Ahem',
        fontStyle: FontStyle.normal,
        fontWeight: FontWeight.normal,
        fontSize: fontSize,
      ));
      builder.addText('Test Ahem');
      final Paragraph paragraph = builder.build();
      paragraph.layout(ParagraphConstraints(width: fontSize * 5.0));

      expect(paragraph.height, fontSize * 2.0); // because it wraps
      expect(paragraph.width, fontSize * 5.0);
      expect(paragraph.minIntrinsicWidth, fontSize * 4.0);

      // TODO(yjbanov): due to https://github.com/flutter/flutter/issues/21965
      //                Flutter reports a different number. Ours is correct
      //                though.
      expect(paragraph.maxIntrinsicWidth, fontSize * 9.0);
      expect(paragraph.alphabeticBaseline, fontSize * .8);
      expect(
        paragraph.ideographicBaseline,
        within(
            distance: 0.001,
            from: paragraph.alphabeticBaseline * baselineRatio),
      );
    }
  });

  test('lay out unattached paragraph', () {
    final CanvasParagraph paragraph = plain(EngineParagraphStyle(
      fontFamily: 'sans-serif',
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.normal,
      fontSize: 14.0,
    ), 'How do you do this fine morning?');

    expect(paragraph.height, 0.0);
    expect(paragraph.width, -1.0);
    expect(paragraph.minIntrinsicWidth, 0.0);
    expect(paragraph.maxIntrinsicWidth, 0.0);
    expect(paragraph.alphabeticBaseline, -1.0);
    expect(paragraph.ideographicBaseline, -1.0);

    paragraph.layout(const ParagraphConstraints(width: 60.0));

    expect(paragraph.height, greaterThan(0.0));
    expect(paragraph.width, greaterThan(0.0));
    expect(paragraph.minIntrinsicWidth, greaterThan(0.0));
    expect(paragraph.maxIntrinsicWidth, greaterThan(0.0));
    expect(paragraph.minIntrinsicWidth, lessThan(paragraph.maxIntrinsicWidth));
    expect(paragraph.alphabeticBaseline, greaterThan(0.0));
    expect(paragraph.ideographicBaseline, greaterThan(0.0));
  });

  Paragraph measure(
      {String text = 'Hello', double fontSize = 14.0, double width = 50.0}) {
    final ParagraphBuilder builder = ParagraphBuilder(ParagraphStyle(
      fontFamily: 'sans-serif',
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.normal,
      fontSize: fontSize,
    ));
    builder.addText(text);
    final Paragraph paragraph = builder.build();
    paragraph.layout(ParagraphConstraints(width: width));
    return paragraph;
  }

  test('baseline increases with font size', () {
    Paragraph previousParagraph = measure(fontSize: 10.0);
    for (int i = 0; i < 6; i++) {
      final double fontSize = 20.0 + 10.0 * i;
      final Paragraph paragraph = measure(fontSize: fontSize);
      expect(paragraph.alphabeticBaseline,
          greaterThan(previousParagraph.alphabeticBaseline));
      expect(paragraph.ideographicBaseline,
          greaterThan(previousParagraph.ideographicBaseline));
      previousParagraph = paragraph;
    }
  });

  test('baseline does not depend on text', () {
    final Paragraph golden = measure(fontSize: 30.0);
    for (int i = 1; i < 30; i++) {
      final Paragraph paragraph = measure(text: 'hello ' * i, fontSize: 30.0);
      expect(paragraph.alphabeticBaseline, golden.alphabeticBaseline);
      expect(paragraph.ideographicBaseline, golden.ideographicBaseline);
    }
  });

  test('$ParagraphBuilder detects plain text', () {
    ParagraphBuilder builder = ParagraphBuilder(EngineParagraphStyle(
      fontFamily: 'sans-serif',
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.normal,
      fontSize: 15.0,
    ));
    builder.addText('hi');
    CanvasParagraph paragraph = builder.build() as CanvasParagraph;
    expect(paragraph.plainText, isNotNull);
    expect(paragraph.paragraphStyle.fontWeight, FontWeight.normal);

    builder = ParagraphBuilder(EngineParagraphStyle(
      fontFamily: 'sans-serif',
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.normal,
      fontSize: 15.0,
    ));
    builder.pushStyle(TextStyle(fontWeight: FontWeight.bold));
    builder.addText('hi');
    paragraph = builder.build() as CanvasParagraph;
    expect(paragraph.plainText, isNotNull);
  });

  test('$ParagraphBuilder detects rich text', () {
    final ParagraphBuilder builder = ParagraphBuilder(EngineParagraphStyle(
      fontFamily: 'sans-serif',
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.normal,
      fontSize: 15.0,
    ));
    builder.addText('h');
    builder.pushStyle(TextStyle(fontWeight: FontWeight.bold));
    builder.addText('i');
    final CanvasParagraph paragraph = builder.build() as CanvasParagraph;
    expect(paragraph.plainText, 'hi');
  });

  test('$ParagraphBuilder treats empty text as plain', () {
    final ParagraphBuilder builder = ParagraphBuilder(EngineParagraphStyle(
      fontFamily: 'sans-serif',
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.normal,
      fontSize: 15.0,
    ));
    builder.pushStyle(TextStyle(fontWeight: FontWeight.bold));
    final CanvasParagraph paragraph = builder.build() as CanvasParagraph;
    expect(paragraph.plainText, '');
  });

  // Regression test for https://github.com/flutter/flutter/issues/38972
  test(
      'should not set fontFamily to effectiveFontFamily for spans in rich text',
      () {
    final ParagraphBuilder builder = ParagraphBuilder(EngineParagraphStyle(
      fontFamily: 'Roboto',
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.normal,
      fontSize: 15.0,
    ));
    builder
        .pushStyle(TextStyle(fontFamily: 'Menlo', fontWeight: FontWeight.bold));
    const String firstSpanText = 'abc';
    builder.addText(firstSpanText);
    builder.pushStyle(TextStyle(fontSize: 30.0, fontWeight: FontWeight.normal));
    const String secondSpanText = 'def';
    builder.addText(secondSpanText);
    final CanvasParagraph paragraph = builder.build() as CanvasParagraph;
    paragraph.layout(const ParagraphConstraints(width: 800.0));
    expect(paragraph.plainText, 'abcdef');
    final List<SpanElement> spans =
        paragraph.toDomElement().querySelectorAll('span');
    expect(spans[0].style.fontFamily, 'Ahem, $fallback, sans-serif');
    // The nested span here should not set it's family to default sans-serif.
    expect(spans[1].style.fontFamily, 'Ahem, $fallback, sans-serif');
  },
      // TODO(mdebbar): https://github.com/flutter/flutter/issues/50771
      // TODO(mdebbar): https://github.com/flutter/flutter/issues/46638
      skip: browserEngine == BrowserEngine.firefox ||
          browserEngine == BrowserEngine.edge);

  test('adds Arial and sans-serif as fallback fonts', () {
    // Set this to false so it doesn't default to 'Ahem' font.
    debugEmulateFlutterTesterEnvironment = false;

    final CanvasParagraph paragraph = plain(EngineParagraphStyle(
      fontFamily: 'SomeFont',
      fontSize: 12.0,
    ), 'Hello');

    paragraph.layout(constrain(double.infinity));
    expect(paragraph.toDomElement().style.fontFamily,
        'SomeFont, $fallback, sans-serif');

    debugEmulateFlutterTesterEnvironment = true;
  },
      // TODO(mdebbar): https://github.com/flutter/flutter/issues/50771
      // TODO(mdebbar): https://github.com/flutter/flutter/issues/46638
      skip: browserEngine == BrowserEngine.firefox ||
          browserEngine == BrowserEngine.edge);

  test('does not add fallback fonts to generic families', () {
    // Set this to false so it doesn't default to 'Ahem' font.
    debugEmulateFlutterTesterEnvironment = false;

    final CanvasParagraph paragraph = plain(EngineParagraphStyle(
      fontFamily: 'serif',
      fontSize: 12.0,
    ), 'Hello');

    paragraph.layout(constrain(double.infinity));
    expect(paragraph.toDomElement().style.fontFamily, 'serif');

    debugEmulateFlutterTesterEnvironment = true;
  });

  test('can set font families that need to be quoted', () {
    // Set this to false so it doesn't default to 'Ahem' font.
    debugEmulateFlutterTesterEnvironment = false;

    final CanvasParagraph paragraph = plain(EngineParagraphStyle(
      fontFamily: 'MyFont 2000',
      fontSize: 12.0,
    ), 'Hello');

    paragraph.layout(constrain(double.infinity));
    expect(paragraph.toDomElement().style.fontFamily,
        '"MyFont 2000", $fallback, sans-serif');

    debugEmulateFlutterTesterEnvironment = true;
  },
      // TODO(mdebbar): https://github.com/flutter/flutter/issues/50771
      skip: browserEngine == BrowserEngine.edge);

  group('TextRange', () {
    test('empty ranges are correct', () {
      const TextRange range = TextRange(start: -1, end: -1);
      expect(range, equals(const TextRange.collapsed(-1)));
      expect(range, equals(TextRange.empty));
    });
    test('isValid works', () {
      expect(TextRange.empty.isValid, isFalse);
      expect(const TextRange(start: 0, end: 0).isValid, isTrue);
      expect(const TextRange(start: 0, end: 10).isValid, isTrue);
      expect(const TextRange(start: 10, end: 10).isValid, isTrue);
      expect(const TextRange(start: -1, end: 10).isValid, isFalse);
      expect(const TextRange(start: 10, end: 0).isValid, isTrue);
      expect(const TextRange(start: 10, end: -1).isValid, isFalse);
    });
    test('isCollapsed works', () {
      expect(TextRange.empty.isCollapsed, isTrue);
      expect(const TextRange(start: 0, end: 0).isCollapsed, isTrue);
      expect(const TextRange(start: 0, end: 10).isCollapsed, isFalse);
      expect(const TextRange(start: 10, end: 10).isCollapsed, isTrue);
      expect(const TextRange(start: -1, end: 10).isCollapsed, isFalse);
      expect(const TextRange(start: 10, end: 0).isCollapsed, isFalse);
      expect(const TextRange(start: 10, end: -1).isCollapsed, isFalse);
    });
    test('isNormalized works', () {
      expect(TextRange.empty.isNormalized, isTrue);
      expect(const TextRange(start: 0, end: 0).isNormalized, isTrue);
      expect(const TextRange(start: 0, end: 10).isNormalized, isTrue);
      expect(const TextRange(start: 10, end: 10).isNormalized, isTrue);
      expect(const TextRange(start: -1, end: 10).isNormalized, isTrue);
      expect(const TextRange(start: 10, end: 0).isNormalized, isFalse);
      expect(const TextRange(start: 10, end: -1).isNormalized, isFalse);
    });
    test('textBefore works', () {
      expect(const TextRange(start: 0, end: 0).textBefore('hello'), isEmpty);
      expect(
          const TextRange(start: 1, end: 1).textBefore('hello'), equals('h'));
      expect(
          const TextRange(start: 1, end: 2).textBefore('hello'), equals('h'));
      expect(const TextRange(start: 5, end: 5).textBefore('hello'),
          equals('hello'));
      expect(const TextRange(start: 0, end: 5).textBefore('hello'), isEmpty);
    });
    test('textAfter works', () {
      expect(const TextRange(start: 0, end: 0).textAfter('hello'),
          equals('hello'));
      expect(
          const TextRange(start: 1, end: 1).textAfter('hello'), equals('ello'));
      expect(
          const TextRange(start: 1, end: 2).textAfter('hello'), equals('llo'));
      expect(const TextRange(start: 5, end: 5).textAfter('hello'), isEmpty);
      expect(const TextRange(start: 0, end: 5).textAfter('hello'), isEmpty);
    });
    test('textInside works', () {
      expect(const TextRange(start: 0, end: 0).textInside('hello'), isEmpty);
      expect(const TextRange(start: 1, end: 1).textInside('hello'), isEmpty);
      expect(
          const TextRange(start: 1, end: 2).textInside('hello'), equals('e'));
      expect(const TextRange(start: 5, end: 5).textInside('hello'), isEmpty);
      expect(const TextRange(start: 0, end: 5).textInside('hello'),
          equals('hello'));
    });
  });
}
