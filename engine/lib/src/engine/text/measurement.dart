// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html' as html;

import '../../engine.dart' show registerHotRestartListener;
import '../dom_renderer.dart';

// TODO(yjbanov): this is a hack we use to compute ideographic baseline; this
//                number is the ratio ideographic/alphabetic for font Ahem,
//                which matches the Flutter number. It may be completely wrong
//                for any other font. We'll need to eventually fix this. That
//                said Flutter doesn't seem to use ideographic baseline for
//                anything as of this writing.
const double baselineRatioHack = 1.1662499904632568;

/// Hosts ruler DOM elements in a hidden container under a `root` [html.Node].
///
/// The `root` [html.Node] is optional. Defaults to [domRenderer.glassPaneShadow].
class RulerHost {
  RulerHost({html.Node? root}) {
    _rulerHost.style
      ..position = 'fixed'
      ..visibility = 'hidden'
      ..overflow = 'hidden'
      ..top = '0'
      ..left = '0'
      ..width = '0'
      ..height = '0';

    (root ?? domRenderer.glassPaneShadow!.node).append(_rulerHost);
    registerHotRestartListener(dispose);
  }

  /// Hosts a cache of rulers that measure text.
  ///
  /// This element exists purely for organizational purposes. Otherwise the
  /// rulers would be attached to the `<body>` element polluting the element
  /// tree and making it hard to navigate. It does not serve any functional
  /// purpose.
  final html.Element _rulerHost = html.Element.tag('flt-ruler-host');

  /// Releases the resources used by this [RulerHost].
  ///
  /// After this is called, this object is no longer usable.
  void dispose() {
    _rulerHost.remove();
  }

  /// Adds an element used for measuring text as a child of [_rulerHost].
  void addElement(html.HtmlElement element) {
    _rulerHost.append(element);
  }
}

// These global variables are used to memoize calls to [measureSubstring]. They
// are used to remember the last arguments passed to it, and the last return
// value.
// They are being initialized so that the compiler knows they'll never be null.
int _lastStart = -1;
int _lastEnd = -1;
String _lastText = '';
String _lastCssFont = '';
double _lastWidth = -1;

/// Measures the width of the substring of [text] starting from the index
/// [start] (inclusive) to [end] (exclusive).
///
/// This method assumes that the correct font has already been set on
/// [_canvasContext].
double measureSubstring(
  html.CanvasRenderingContext2D _canvasContext,
  String text,
  int start,
  int end, {
  double? letterSpacing,
}) {
  assert(0 <= start);
  assert(start <= end);
  assert(end <= text.length);

  if (start == end) {
    return 0;
  }

  final String cssFont = _canvasContext.font;
  double width;

  // TODO(mdebbar): Explore caching all widths in a map, not only the last one.
  if (start == _lastStart &&
      end == _lastEnd &&
      text == _lastText &&
      cssFont == _lastCssFont) {
    // Reuse the previously calculated width if all factors that affect width
    // are unchanged. The only exception is letter-spacing. We always add
    // letter-spacing to the width later below.
    width = _lastWidth;
  } else {
    final String sub =
      start == 0 && end == text.length ? text : text.substring(start, end);
    width = _canvasContext.measureText(sub).width!.toDouble();
  }

  _lastStart = start;
  _lastEnd = end;
  _lastText = text;
  _lastCssFont = cssFont;
  _lastWidth = width;

  // Now add letter spacing to the width.
  letterSpacing ??= 0.0;
  if (letterSpacing != 0.0) {
    width += letterSpacing * (end - start);
  }

  // What we are doing here is we are rounding to the nearest 2nd decimal
  // point. So 39.999423 becomes 40, and 11.243982 becomes 11.24.
  // The reason we are doing this is because we noticed that canvas API has a
  // ±0.001 error margin.
  return _roundWidth(width);
}

double _roundWidth(double width) {
  return (width * 100).round() / 100;
}
