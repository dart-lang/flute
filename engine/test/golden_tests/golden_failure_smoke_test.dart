// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html' as html;

import 'package:test/bootstrap/browser.dart';
import 'package:test/test.dart';
import 'package:ui/ui.dart';
import 'package:web_engine_tester/golden_tester.dart';

void main() {
  internalBootstrapBrowserTest(() => testMain);
}

void testMain() {
  test('screenshot test reports failure', () async {
    html.document.body!.innerHtml = 'Text that does not appear on the screenshot!';
    await matchGoldenFile('__local__/smoke_test.png', region: const Rect.fromLTWH(0, 0, 320, 200));
  });
}
