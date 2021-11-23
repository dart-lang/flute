// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:test/bootstrap/browser.dart';
import 'package:test/test.dart';
import 'package:ui/src/engine.dart';
import 'package:ui/ui.dart' as ui;

import 'common.dart';

void main() {
  internalBootstrapBrowserTest(() => testMain);
}

void testMain() {
  group('Vertices', () {
    setUpCanvasKitTest();

    test('can be constructed, drawn, and deleted', () {
      final CkVertices vertices = _testVertices();
      expect(vertices, isA<CkVertices>());
      expect(vertices.createDefault(), isNotNull);
      expect(vertices.resurrect(), isNotNull);

      final CkPictureRecorder recorder = CkPictureRecorder();
      final CkCanvas canvas = recorder.beginRecording(const ui.Rect.fromLTRB(0, 0, 100, 100));
      canvas.drawVertices(
        vertices,
        ui.BlendMode.srcOver,
        CkPaint(),
      );
      vertices.delete();
    });
  // TODO(hterkelsen): https://github.com/flutter/flutter/issues/60040
  }, skip: isIosSafari);
}

CkVertices _testVertices() {
  return ui.Vertices(
    ui.VertexMode.triangles,
    const <ui.Offset>[
      ui.Offset(0, 0),
      ui.Offset(10, 10),
      ui.Offset(0, 20),
    ],
    textureCoordinates: const <ui.Offset>[
      ui.Offset(0, 0),
      ui.Offset(10, 10),
      ui.Offset(0, 20),
    ],
    colors: const <ui.Color>[
      ui.Color.fromRGBO(255, 0, 0, 1.0),
      ui.Color.fromRGBO(0, 255, 0, 1.0),
      ui.Color.fromRGBO(0, 0, 255, 1.0),
    ],
    indices: <int>[0, 1, 2],
  ) as CkVertices;
}
