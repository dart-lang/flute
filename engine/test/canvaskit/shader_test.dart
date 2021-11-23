// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:test/bootstrap/browser.dart';
import 'package:test/test.dart';
import 'package:ui/src/engine.dart';
import 'package:ui/ui.dart' as ui;

import 'common.dart';
import 'test_data.dart';

void main() {
  internalBootstrapBrowserTest(() => testMain);
}

void testMain() {
  group('CanvasKit shaders', () {
    setUpCanvasKitTest();

    test('Sweep gradient', () {
      final CkGradientSweep gradient = ui.Gradient.sweep(
        ui.Offset.zero,
        testColors,
      ) as CkGradientSweep;
      expect(gradient.createDefault(), isNotNull);
    });

    test('Linear gradient', () {
      final CkGradientLinear gradient = ui.Gradient.linear(
        ui.Offset.zero,
        const ui.Offset(0, 1),
        testColors,
      ) as CkGradientLinear;
      expect(gradient.createDefault(), isNotNull);
    });

    test('Radial gradient', () {
      final CkGradientRadial gradient = ui.Gradient.radial(
        ui.Offset.zero,
        10,
        testColors,
      ) as CkGradientRadial;
      expect(gradient.createDefault(), isNotNull);
    });

    test('Conical gradient', () {
      final CkGradientConical gradient = ui.Gradient.radial(
        ui.Offset.zero,
        10,
        testColors,
        null,
        ui.TileMode.clamp,
        null,
        const ui.Offset(10, 10),
        40,
      ) as CkGradientConical;
      expect(gradient.createDefault(), isNotNull);
    });

    test('Image shader', () {
      final SkImage skImage = canvasKit.MakeAnimatedImageFromEncoded(kTransparentImage)!.makeImageAtCurrentFrame();
      final CkImage image = CkImage(skImage);
      final CkImageShader imageShader = ui.ImageShader(
        image,
        ui.TileMode.clamp,
        ui.TileMode.repeated,
        Float64List.fromList(Matrix4.diagonal3Values(1, 2, 3).storage),
      ) as CkImageShader;
      expect(imageShader, isA<CkImageShader>());
    });
  // TODO(hterkelsen): https://github.com/flutter/flutter/issues/60040
  }, skip: isIosSafari);
}

const List<ui.Color> testColors = <ui.Color>[ui.Color(0xFFFFFF00), ui.Color(0xFFFFFFFF)];
