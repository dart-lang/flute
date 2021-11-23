// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html' as html;
import 'dart:math' as math;

import 'package:test/bootstrap/browser.dart';
import 'package:test/test.dart';
import 'package:ui/src/engine.dart';
import 'package:ui/ui.dart' as ui;
import 'package:web_engine_tester/golden_tester.dart';

import '../../matchers.dart';

const ui.Rect region = ui.Rect.fromLTWH(0, 0, 500, 100);

void main() {
  internalBootstrapBrowserTest(() => testMain);
}

Future<void> testMain() async {
  setUp(() async {
    // To debug test failures uncomment the following to visualize clipping
    // layers:
    // debugShowClipLayers = true;
    SurfaceSceneBuilder.debugForgetFrameScene();
    for (final html.Node scene in html.document.querySelectorAll('flt-scene')) {
      scene.remove();
    }

    await ui.webOnlyInitializePlatform();
    ui.webOnlyFontCollection.debugRegisterTestFonts();
    await ui.webOnlyFontCollection.ensureFontsLoaded();
  });

  test('pushClipRect', () async {
    final SurfaceSceneBuilder builder = SurfaceSceneBuilder();
    builder.pushClipRect(
      const ui.Rect.fromLTRB(10, 10, 60, 60),
    );
    _drawTestPicture(builder);
    builder.pop();

    html.document.body!.append(builder.build().webOnlyRootElement!);

    await matchGoldenFile('compositing_shifted_clip_rect.png', region: region);
  });

  test('pushClipRect with offset and transform', () async {
    final SurfaceSceneBuilder builder = SurfaceSceneBuilder();

    builder.pushOffset(0, 60);
    builder.pushTransform(
      Matrix4.diagonal3Values(1, -1, 1).toFloat64(),
    );
    builder.pushClipRect(
      const ui.Rect.fromLTRB(10, 10, 60, 60),
    );
    _drawTestPicture(builder);
    builder.pop();
    builder.pop();
    builder.pop();

    html.document.body!.append(builder.build().webOnlyRootElement!);

    await matchGoldenFile('compositing_clip_rect_with_offset_and_transform.png',
        region: region);
  });

  test('pushClipRect with offset and transform ClipOp none should not clip',
      () async {
    final SurfaceSceneBuilder builder = SurfaceSceneBuilder();

    builder.pushOffset(0, 80);
    builder.pushTransform(
      Matrix4.diagonal3Values(1, -1, 1).toFloat64(),
    );
    builder.pushClipRect(const ui.Rect.fromLTRB(10, 10, 60, 60),
        clipBehavior: ui.Clip.none);
    _drawTestPicture(builder);
    builder.pop();
    builder.pop();
    builder.pop();

    html.document.body!.append(builder.build().webOnlyRootElement!);

    await matchGoldenFile('compositing_clip_rect_clipop_none.png',
        region: region);
  });

  test('pushClipRRect with offset and transform ClipOp none should not clip',
      () async {
    final SurfaceSceneBuilder builder = SurfaceSceneBuilder();

    builder.pushOffset(0, 80);
    builder.pushTransform(
      Matrix4.diagonal3Values(1, -1, 1).toFloat64(),
    );
    builder.pushClipRRect(
        ui.RRect.fromRectAndRadius(
          const ui.Rect.fromLTRB(10, 10, 60, 60),
          const ui.Radius.circular(1),
        ),
        clipBehavior: ui.Clip.none);
    _drawTestPicture(builder);
    builder.pop();
    builder.pop();
    builder.pop();

    html.document.body!.append(builder.build().webOnlyRootElement!);

    await matchGoldenFile('compositing_clip_rrect_clipop_none.png',
        region: region);
  });

  test('pushClipRRect', () async {
    final SurfaceSceneBuilder builder = SurfaceSceneBuilder();
    builder.pushClipRRect(
      ui.RRect.fromLTRBR(10, 10, 60, 60, const ui.Radius.circular(5)),
    );
    _drawTestPicture(builder);
    builder.pop();

    html.document.body!.append(builder.build().webOnlyRootElement!);

    await matchGoldenFile('compositing_shifted_clip_rrect.png', region: region);
  });

  test('pushPhysicalShape', () async {
    final SurfaceSceneBuilder builder = SurfaceSceneBuilder();
    builder.pushPhysicalShape(
      path: ui.Path()..addRect(const ui.Rect.fromLTRB(10, 10, 60, 60)),
      clipBehavior: ui.Clip.hardEdge,
      color: const ui.Color.fromRGBO(0, 0, 0, 0.3),
      elevation: 0,
    );
    _drawTestPicture(builder);
    builder.pop();

    builder.pushOffset(70, 0);
    builder.pushPhysicalShape(
      path: ui.Path()
        ..addRRect(ui.RRect.fromLTRBR(10, 10, 60, 60, const ui.Radius.circular(5))),
      clipBehavior: ui.Clip.hardEdge,
      color: const ui.Color.fromRGBO(0, 0, 0, 0.3),
      elevation: 0,
    );
    _drawTestPicture(builder);
    builder.pop();
    builder.pop();

    html.document.body!.append(builder.build().webOnlyRootElement!);

    await matchGoldenFile('compositing_shifted_physical_shape_clip.png',
        region: region);
  });

  test('pushPhysicalShape clipOp.none', () async {
    final SurfaceSceneBuilder builder = SurfaceSceneBuilder();
    builder.pushPhysicalShape(
      path: ui.Path()..addRect(const ui.Rect.fromLTRB(10, 10, 60, 60)),
      clipBehavior: ui.Clip.hardEdge,
      color: const ui.Color.fromRGBO(0, 0, 0, 0.3),
      elevation: 0,
    );
    _drawTestPicture(builder);
    builder.pop();

    builder.pushOffset(70, 0);
    builder.pushPhysicalShape(
      path: ui.Path()
        ..addRRect(ui.RRect.fromLTRBR(10, 10, 60, 60, const ui.Radius.circular(5))),
      clipBehavior: ui.Clip.none,
      color: const ui.Color.fromRGBO(0, 0, 0, 0.3),
      elevation: 0,
    );
    _drawTestPicture(builder);
    builder.pop();
    builder.pop();

    html.document.body!.append(builder.build().webOnlyRootElement!);

    await matchGoldenFile('compositing_shifted_physical_shape_clipnone.png',
        region: region);
  });

  test('pushPhysicalShape with path and elevation', () async {
    final ui.Path cutCornersButton = ui.Path()
      ..moveTo(15, 10)
      ..lineTo(60, 10)
      ..lineTo(60, 60)
      ..lineTo(15, 60)
      ..lineTo(10, 55)
      ..lineTo(10, 15);

    final SurfaceSceneBuilder builder = SurfaceSceneBuilder();
    builder.pushPhysicalShape(
      path: cutCornersButton,
      clipBehavior: ui.Clip.hardEdge,
      color: const ui.Color(0xFFA0FFFF),
      elevation: 2,
    );
    _drawTestPicture(builder);
    builder.pop();

    builder.pushOffset(70, 0);
    builder.pushPhysicalShape(
      path: cutCornersButton,
      clipBehavior: ui.Clip.hardEdge,
      color: const ui.Color(0xFFA0FFFF),
      elevation: 8,
    );
    _drawTestPicture(builder);
    builder.pop();
    builder.pop();

    builder.pushOffset(140, 0);
    builder.pushPhysicalShape(
      path: ui.Path()..addOval(const ui.Rect.fromLTRB(10, 10, 60, 60)),
      clipBehavior: ui.Clip.hardEdge,
      color: const ui.Color(0xFFA0FFFF),
      elevation: 4,
    );
    _drawTestPicture(builder);
    builder.pop();
    builder.pop();

    builder.pushOffset(210, 0);
    builder.pushPhysicalShape(
      path: ui.Path()
        ..addRRect(ui.RRect.fromRectAndRadius(
            const ui.Rect.fromLTRB(10, 10, 60, 60), const ui.Radius.circular(10.0))),
      clipBehavior: ui.Clip.hardEdge,
      color: const ui.Color(0xFFA0FFFF),
      elevation: 4,
    );
    _drawTestPicture(builder);
    builder.pop();
    builder.pop();

    html.document.body!.append(builder.build().webOnlyRootElement!);

    await matchGoldenFile('compositing_physical_shape_path.png',
        region: region);
  });

  test('pushPhysicalShape should update across frames', () async {
    final ui.Path cutCornersButton = ui.Path()
      ..moveTo(15, 10)
      ..lineTo(60, 10)
      ..lineTo(60, 60)
      ..lineTo(15, 60)
      ..lineTo(10, 55)
      ..lineTo(10, 15);

    /// Start with shape that has elevation and red color.
    final SurfaceSceneBuilder builder = SurfaceSceneBuilder();
    final ui.PhysicalShapeEngineLayer oldShapeLayer = builder.pushPhysicalShape(
      path: cutCornersButton,
      clipBehavior: ui.Clip.hardEdge,
      color: const ui.Color(0xFFFF0000),
      elevation: 2,
    );
    _drawTestPicture(builder);
    builder.pop();

    final html.Element viewElement = builder.build().webOnlyRootElement!;
    html.document.body!.append(viewElement);
    await matchGoldenFile('compositing_physical_update_1.png', region: region);
    viewElement.remove();

    /// Update color to green.
    final SurfaceSceneBuilder builder2 = SurfaceSceneBuilder();
    final ui.PhysicalShapeEngineLayer oldShapeLayer2 = builder2.pushPhysicalShape(
      path: cutCornersButton,
      clipBehavior: ui.Clip.hardEdge,
      color: const ui.Color(0xFF00FF00),
      elevation: 2,
      oldLayer: oldShapeLayer,
    );
    _drawTestPicture(builder2);
    builder2.pop();

    final html.Element viewElement2 = builder2.build().webOnlyRootElement!;
    html.document.body!.append(viewElement2);
    await matchGoldenFile('compositing_physical_update_2.png', region: region);
    viewElement2.remove();

    /// Update elevation.
    final SurfaceSceneBuilder builder3 = SurfaceSceneBuilder();
    final ui.PhysicalShapeEngineLayer oldShapeLayer3 = builder3.pushPhysicalShape(
      path: cutCornersButton,
      clipBehavior: ui.Clip.hardEdge,
      color: const ui.Color(0xFF00FF00),
      elevation: 6,
      oldLayer: oldShapeLayer2,
    );
    _drawTestPicture(builder3);
    builder3.pop();

    final html.Element viewElement3 = builder3.build().webOnlyRootElement!;
    html.document.body!.append(viewElement3);
    await matchGoldenFile('compositing_physical_update_3.png',
        region: region, maxDiffRatePercent: 0.8);
    viewElement3.remove();

    /// Update shape from arbitrary path to rect.
    final SurfaceSceneBuilder builder4 = SurfaceSceneBuilder();
    final ui.PhysicalShapeEngineLayer oldShapeLayer4 = builder4.pushPhysicalShape(
      path: ui.Path()..addOval(const ui.Rect.fromLTRB(10, 10, 60, 60)),
      clipBehavior: ui.Clip.hardEdge,
      color: const ui.Color(0xFF00FF00),
      elevation: 6,
      oldLayer: oldShapeLayer3,
    );
    _drawTestPicture(builder4);
    builder4.pop();

    final html.Element viewElement4 = builder4.build().webOnlyRootElement!;
    html.document.body!.append(viewElement4);
    await matchGoldenFile('compositing_physical_update_4.png', region: region);
    viewElement4.remove();

    /// Update shape back to arbitrary path.
    final SurfaceSceneBuilder builder5 = SurfaceSceneBuilder();
    final ui.PhysicalShapeEngineLayer oldShapeLayer5 = builder5.pushPhysicalShape(
      path: cutCornersButton,
      clipBehavior: ui.Clip.hardEdge,
      color: const ui.Color(0xFF00FF00),
      elevation: 6,
      oldLayer: oldShapeLayer4,
    );
    _drawTestPicture(builder5);
    builder5.pop();

    final html.Element viewElement5 = builder5.build().webOnlyRootElement!;
    html.document.body!.append(viewElement5);
    await matchGoldenFile('compositing_physical_update_3.png',
        region: region,
        maxDiffRatePercent: browserEngine == BrowserEngine.webkit ? 0.6 : 0.4);
    viewElement5.remove();

    /// Update shadow color.
    final SurfaceSceneBuilder builder6 = SurfaceSceneBuilder();
    builder6.pushPhysicalShape(
      path: cutCornersButton,
      clipBehavior: ui.Clip.hardEdge,
      color: const ui.Color(0xFF00FF00),
      shadowColor: const ui.Color(0xFFFF0000),
      elevation: 6,
      oldLayer: oldShapeLayer5,
    );
    _drawTestPicture(builder6);
    builder6.pop();

    final html.Element viewElement6 = builder6.build().webOnlyRootElement!;
    html.document.body!.append(viewElement6);
    await matchGoldenFile('compositing_physical_update_5.png', region: region);
    viewElement6.remove();
  });

  test('pushImageFilter blur', () async {
    final SurfaceSceneBuilder builder = SurfaceSceneBuilder();
    builder.pushImageFilter(
      ui.ImageFilter.blur(sigmaX: 1, sigmaY: 3),
    );
    _drawTestPicture(builder);
    builder.pop();

    html.document.body!.append(builder.build().webOnlyRootElement!);

    await matchGoldenFile('compositing_image_filter.png', region: region);
  });

  test('pushImageFilter matrix', () async {
    final SurfaceSceneBuilder builder = SurfaceSceneBuilder();
    builder.pushImageFilter(
      ui.ImageFilter.matrix(
          (
              Matrix4.identity()
                ..translate(40, 10)
                ..rotateZ(math.pi / 6)
                ..scale(0.75, 0.75)
          ).toFloat64()),
    );
    _drawTestPicture(builder);
    builder.pop();

    html.document.body!.append(builder.build().webOnlyRootElement!);

    await matchGoldenFile('compositing_image_filter_matrix.png', region: region);
  });

  group('Cull rect computation', () {
    _testCullRectComputation();
  });
}

void _testCullRectComputation() {
  // Draw a picture larger that screen. Verify that cull rect is equal to screen
  // bounds.
  test('fills screen bounds', () async {
    final ui.SceneBuilder builder = ui.SceneBuilder();
    drawWithBitmapCanvas(builder, (RecordingCanvas canvas) {
      canvas.drawCircle(
          ui.Offset.zero, 10000, SurfacePaint()..style = ui.PaintingStyle.fill);
    });
    builder.build();

    final PersistedPicture picture = enumeratePictures().single;
    expect(picture.optimalLocalCullRect, const ui.Rect.fromLTRB(0, 0, 500, 100));
  }, skip: '''
  TODO(https://github.com/flutter/flutter/issues/40395)
  Needs ability to set iframe to 500,100 size. Current screen seems to be 500,500''');

  // Draw a picture that overflows the screen. Verify that cull rect is the
  // intersection of screen bounds and paint bounds.
  test('intersects with screen bounds', () async {
    final ui.SceneBuilder builder = ui.SceneBuilder();
    drawWithBitmapCanvas(builder, (RecordingCanvas canvas) {
      canvas.drawCircle(ui.Offset.zero, 20, SurfacePaint()..style = ui.PaintingStyle.fill);
    });
    builder.build();

    final PersistedPicture picture = enumeratePictures().single;
    expect(picture.optimalLocalCullRect, const ui.Rect.fromLTRB(0, 0, 20, 20));
  });

  // Draw a picture that's fully outside the screen bounds. Verify the cull rect
  // is zero.
  test('fully outside screen bounds', () async {
    final ui.SceneBuilder builder = ui.SceneBuilder();
    drawWithBitmapCanvas(builder, (RecordingCanvas canvas) {
      canvas.drawCircle(
          const ui.Offset(-100, -100), 20, SurfacePaint()..style = ui.PaintingStyle.fill);
    });
    builder.build();

    final PersistedPicture picture = enumeratePictures().single;
    expect(picture.optimalLocalCullRect, ui.Rect.zero);
    expect(picture.debugExactGlobalCullRect, ui.Rect.zero);
  });

  // Draw a picture that's fully inside the screen. Verify that cull rect is
  // equal to the paint bounds.
  test('limits to paint bounds if no clip layers', () async {
    final ui.SceneBuilder builder = ui.SceneBuilder();
    drawWithBitmapCanvas(builder, (RecordingCanvas canvas) {
      canvas.drawCircle(
          const ui.Offset(50, 50), 10, SurfacePaint()..style = ui.PaintingStyle.fill);
    });
    builder.build();

    final PersistedPicture picture = enumeratePictures().single;
    expect(picture.optimalLocalCullRect, const ui.Rect.fromLTRB(40, 40, 60, 60));
  });

  // Draw a picture smaller than the screen. Offset it such that it remains
  // fully inside the screen bounds. Verify that cull rect is still just the
  // paint bounds.
  test('offset does not affect paint bounds', () async {
    final ui.SceneBuilder builder = ui.SceneBuilder();

    builder.pushOffset(10, 10);
    drawWithBitmapCanvas(builder, (RecordingCanvas canvas) {
      canvas.drawCircle(
          const ui.Offset(50, 50), 10, SurfacePaint()..style = ui.PaintingStyle.fill);
    });
    builder.pop();

    builder.build();

    final PersistedPicture picture = enumeratePictures().single;
    expect(picture.optimalLocalCullRect, const ui.Rect.fromLTRB(40, 40, 60, 60));
  });

  // Draw a picture smaller than the screen. Offset it such that the picture
  // overflows screen bounds. Verify that the cull rect is the intersection
  // between screen bounds and paint bounds.
  test('offset overflows paint bounds', () async {
    final ui.SceneBuilder builder = ui.SceneBuilder();

    builder.pushOffset(0, 90);
    drawWithBitmapCanvas(builder, (RecordingCanvas canvas) {
      canvas.drawCircle(ui.Offset.zero, 20, SurfacePaint()..style = ui.PaintingStyle.fill);
    });
    builder.pop();

    builder.build();

    final PersistedPicture picture = enumeratePictures().single;
    expect(
        picture.debugExactGlobalCullRect, const ui.Rect.fromLTRB(0, 70, 20, 100));
    expect(picture.optimalLocalCullRect, const ui.Rect.fromLTRB(0, -20, 20, 10));
  }, skip: '''
  TODO(https://github.com/flutter/flutter/issues/40395)
  Needs ability to set iframe to 500,100 size. Current screen seems to be 500,500''');

  // Draw a picture inside a layer clip but fill all available space inside it.
  // Verify that the cull rect is equal to the layer clip.
  test('fills layer clip rect', () async {
    final SurfaceSceneBuilder builder = SurfaceSceneBuilder();
    builder.pushClipRect(
      const ui.Rect.fromLTWH(10, 10, 60, 60),
    );

    builder.pushClipRect(
      const ui.Rect.fromLTWH(40, 40, 60, 60),
    );

    drawWithBitmapCanvas(builder, (RecordingCanvas canvas) {
      canvas.drawCircle(
          ui.Offset.zero, 10000, SurfacePaint()..style = ui.PaintingStyle.fill);
    });

    builder.pop(); // pushClipRect
    builder.pop(); // pushClipRect
    html.document.body!.append(builder.build().webOnlyRootElement!);

    await matchGoldenFile('compositing_cull_rect_fills_layer_clip.png',
        region: region);

    final PersistedPicture picture = enumeratePictures().single;
    expect(picture.optimalLocalCullRect, const ui.Rect.fromLTRB(40, 40, 70, 70));
  });

  // Draw a picture inside a layer clip but position the picture such that its
  // paint bounds overflow the layer clip. Verify that the cull rect is the
  // intersection between the layer clip and paint bounds.
  test('intersects layer clip rect and paint bounds', () async {
    final SurfaceSceneBuilder builder = SurfaceSceneBuilder();
    builder.pushClipRect(
      const ui.Rect.fromLTWH(10, 10, 60, 60),
    );

    builder.pushClipRect(
      const ui.Rect.fromLTWH(40, 40, 60, 60),
    );

    drawWithBitmapCanvas(builder, (RecordingCanvas canvas) {
      canvas.drawCircle(
          const ui.Offset(80, 55), 30, SurfacePaint()..style = ui.PaintingStyle.fill);
    });

    builder.pop(); // pushClipRect
    builder.pop(); // pushClipRect
    html.document.body!.append(builder.build().webOnlyRootElement!);

    await matchGoldenFile(
        'compositing_cull_rect_intersects_clip_and_paint_bounds.png',
        region: region);

    final PersistedPicture picture = enumeratePictures().single;
    expect(picture.optimalLocalCullRect, const ui.Rect.fromLTRB(50, 40, 70, 70));
  });

  // Draw a picture inside a layer clip that's positioned inside the clip using
  // an offset layer. Verify that the cull rect is the intersection between the
  // layer clip and the offset paint bounds.
  test('offsets picture inside layer clip rect', () async {
    final SurfaceSceneBuilder builder = SurfaceSceneBuilder();
    builder.pushClipRect(
      const ui.Rect.fromLTWH(10, 10, 60, 60),
    );

    builder.pushClipRect(
      const ui.Rect.fromLTWH(40, 40, 60, 60),
    );

    builder.pushOffset(55, 70);

    drawWithBitmapCanvas(builder, (RecordingCanvas canvas) {
      canvas.drawCircle(ui.Offset.zero, 20, SurfacePaint()..style = ui.PaintingStyle.fill);
    });

    builder.pop(); // pushOffset
    builder.pop(); // pushClipRect
    builder.pop(); // pushClipRect
    html.document.body!.append(builder.build().webOnlyRootElement!);

    await matchGoldenFile('compositing_cull_rect_offset_inside_layer_clip.png',
        region: region);

    final PersistedPicture picture = enumeratePictures().single;
    expect(picture.optimalLocalCullRect,
        const ui.Rect.fromLTRB(-15.0, -20.0, 15.0, 0.0));
  });

  // Draw a picture inside a layer clip that's positioned an offset layer such
  // that the picture is push completely outside the clip area. Verify that the
  // cull rect is zero.
  test('zero intersection with clip', () async {
    final ui.SceneBuilder builder = ui.SceneBuilder();
    builder.pushClipRect(
      const ui.Rect.fromLTWH(10, 10, 60, 60),
    );

    builder.pushClipRect(
      const ui.Rect.fromLTWH(40, 40, 60, 60),
    );

    builder.pushOffset(100, 50);

    drawWithBitmapCanvas(builder, (RecordingCanvas canvas) {
      canvas.drawCircle(ui.Offset.zero, 20, SurfacePaint()..style = ui.PaintingStyle.fill);
    });

    builder.pop(); // pushOffset
    builder.pop(); // pushClipRect
    builder.pop(); // pushClipRect

    builder.build();

    final PersistedPicture picture = enumeratePictures().single;
    expect(picture.optimalLocalCullRect, ui.Rect.zero);
    expect(picture.debugExactGlobalCullRect, ui.Rect.zero);
  });

  // Draw a picture inside a rotated clip. Verify that the cull rect is big
  // enough to fit the rotated clip.
  test('rotates clip and the picture', () async {
    final SurfaceSceneBuilder builder = SurfaceSceneBuilder();
    builder.pushOffset(80, 50);

    builder.pushTransform(
      Matrix4.rotationZ(-math.pi / 4).toFloat64(),
    );

    builder.pushClipRect(
      const ui.Rect.fromLTRB(-10, -10, 10, 10),
    );

    builder.pushTransform(
      Matrix4.rotationZ(math.pi / 4).toFloat64(),
    );

    drawWithBitmapCanvas(builder, (RecordingCanvas canvas) {
      canvas.drawPaint(SurfacePaint()
        ..color = const ui.Color.fromRGBO(0, 0, 255, 0.6)
        ..style = ui.PaintingStyle.fill);
      canvas.drawRect(
        const ui.Rect.fromLTRB(-5, -5, 5, 5),
        SurfacePaint()
          ..color = const ui.Color.fromRGBO(0, 255, 0, 1.0)
          ..style = ui.PaintingStyle.fill,
      );
    });

    builder.pop(); // pushTransform
    builder.pop(); // pushClipRect
    builder.pop(); // pushTransform
    builder.pop(); // pushOffset
    html.document.body!.append(builder.build().webOnlyRootElement!);

    await matchGoldenFile('compositing_cull_rect_rotated.png', region: region);

    final PersistedPicture picture = enumeratePictures().single;
    expect(
      picture.optimalLocalCullRect,
      within(
          distance: 0.05, from: const ui.Rect.fromLTRB(-14.1, -14.1, 14.1, 14.1)),
    );
  });

  test('pushClipPath', () async {
    final SurfaceSceneBuilder builder = SurfaceSceneBuilder();
    final ui.Path path = ui.Path();
    path.addRect(const ui.Rect.fromLTRB(10, 10, 60, 60));
    builder.pushClipPath(
      path,
    );
    _drawTestPicture(builder);
    builder.pop();

    html.document.body!.append(builder.build().webOnlyRootElement!);

    await matchGoldenFile('compositing_clip_path.png', region: region);
  });

  // Draw a picture inside a rotated clip. Verify that the cull rect is big
  // enough to fit the rotated clip.
  test('clips correctly when using 3d transforms', () async {
    final SurfaceSceneBuilder builder = SurfaceSceneBuilder();

    builder.pushTransform(Matrix4.diagonal3Values(
            EnginePlatformDispatcher.browserDevicePixelRatio,
            EnginePlatformDispatcher.browserDevicePixelRatio,
            1.0)
        .toFloat64());

    // TODO(yjbanov): see the TODO below.
    // final double screenWidth = html.window.innerWidth.toDouble();
    // final double screenHeight = html.window.innerHeight.toDouble();

    final Matrix4 scaleTransform = Matrix4.identity().scaled(0.5, 0.2);
    builder.pushTransform(
      scaleTransform.toFloat64(),
    );

    builder.pushOffset(400, 200);

    builder.pushClipRect(
      const ui.Rect.fromLTRB(-200, -200, 200, 200),
    );

    builder
        .pushTransform(Matrix4.rotationY(45.0 * math.pi / 180.0).toFloat64());

    builder.pushClipRect(
      const ui.Rect.fromLTRB(-140, -140, 140, 140),
    );

    builder.pushTransform(Matrix4.translationValues(0, 0, -50).toFloat64());

    drawWithBitmapCanvas(builder, (RecordingCanvas canvas) {
      canvas.drawPaint(SurfacePaint()
        ..color = const ui.Color.fromRGBO(0, 0, 255, 0.6)
        ..style = ui.PaintingStyle.fill);
      // ui.Rect will be clipped.
      canvas.drawRect(
        const ui.Rect.fromLTRB(-150, -150, 150, 150),
        SurfacePaint()
          ..color = const ui.Color.fromRGBO(0, 255, 0, 1.0)
          ..style = ui.PaintingStyle.fill,
      );
      // Should be outside the clip range.
      canvas.drawRect(
        const ui.Rect.fromLTRB(-150, -150, -140, -140),
        SurfacePaint()
          ..color = const ui.Color.fromARGB(0xE0, 255, 0, 0)
          ..style = ui.PaintingStyle.fill,
      );
      canvas.drawRect(
        const ui.Rect.fromLTRB(140, -150, 150, -140),
        SurfacePaint()
          ..color = const ui.Color.fromARGB(0xE0, 255, 0, 0)
          ..style = ui.PaintingStyle.fill,
      );
      canvas.drawRect(
        const ui.Rect.fromLTRB(-150, 140, -140, 150),
        SurfacePaint()
          ..color = const ui.Color.fromARGB(0xE0, 255, 0, 0)
          ..style = ui.PaintingStyle.fill,
      );
      canvas.drawRect(
        const ui.Rect.fromLTRB(140, 140, 150, 150),
        SurfacePaint()
          ..color = const ui.Color.fromARGB(0xE0, 255, 0, 0)
          ..style = ui.PaintingStyle.fill,
      );
      // Should be inside clip range
      canvas.drawRect(
        const ui.Rect.fromLTRB(-100, -100, -90, -90),
        SurfacePaint()
          ..color = const ui.Color.fromARGB(0xE0, 0, 0, 0x80)
          ..style = ui.PaintingStyle.fill,
      );
      canvas.drawRect(
        const ui.Rect.fromLTRB(90, -100, 100, -90),
        SurfacePaint()
          ..color = const ui.Color.fromARGB(0xE0, 0, 0, 0x80)
          ..style = ui.PaintingStyle.fill,
      );
      canvas.drawRect(
        const ui.Rect.fromLTRB(-100, 90, -90, 100),
        SurfacePaint()
          ..color = const ui.Color.fromARGB(0xE0, 0, 0, 0x80)
          ..style = ui.PaintingStyle.fill,
      );
      canvas.drawRect(
        const ui.Rect.fromLTRB(90, 90, 100, 100),
        SurfacePaint()
          ..color = const ui.Color.fromARGB(0xE0, 0, 0, 0x80)
          ..style = ui.PaintingStyle.fill,
      );
    });

    builder.pop(); // pushTransform Z-50
    builder.pop(); // pushClipRect
    builder.pop(); // pushTransform 3D rotate
    builder.pop(); // pushClipRect
    builder.pop(); // pushOffset
    builder.pop(); // pushTransform scale
    builder.pop(); // pushTransform scale devicepixelratio
    html.document.body!.append(builder.build().webOnlyRootElement!);

    await matchGoldenFile('compositing_3d_rotate1.png', region: region);

    // ignore: unused_local_variable
    final PersistedPicture picture = enumeratePictures().single;
    // TODO(yjbanov): https://github.com/flutter/flutter/issues/40395)
    //   Needs ability to set iframe to 500,100 size. Current screen seems to be 500,500.
    // expect(
    //   picture.optimalLocalCullRect,
    //   within(
    //       distance: 0.05,
    //       from: ui.Rect.fromLTRB(
    //           -140, -140, screenWidth - 360.0, screenHeight + 40.0)),
    // );
  });

  // This test reproduces text blurriness when two pieces of text appear inside
  // two nested clips:
  //
  //   ┌───────────────────────┐
  //   │   text in outer clip  │
  //   │ ┌────────────────────┐│
  //   │ │ text in inner clip ││
  //   │ └────────────────────┘│
  //   └───────────────────────┘
  //
  // This test clips using layers. See a similar test in `bitmap_canvas_golden_test.dart`,
  // which clips using canvas.
  //
  // More details: https://github.com/flutter/flutter/issues/32274
  test(
    'renders clipped text with high quality',
    () async {
      // To reproduce blurriness we need real clipping.
      final CanvasParagraph paragraph =
          (ui.ParagraphBuilder(ui.ParagraphStyle(fontFamily: 'Roboto'))
                // Use a decoration to force rendering in DOM mode.
                ..pushStyle(ui.TextStyle(decoration: ui.TextDecoration.lineThrough, decorationColor: const ui.Color(0x00000000)))
                ..addText('Am I blurry?'))
              .build() as CanvasParagraph;
      paragraph.layout(const ui.ParagraphConstraints(width: 1000));

      final ui.Rect canvasSize = ui.Rect.fromLTRB(
        0,
        0,
        paragraph.maxIntrinsicWidth + 16,
        2 * paragraph.height + 32,
      );
      final ui.Rect outerClip =
          ui.Rect.fromLTRB(0.5, 0.5, canvasSize.right, canvasSize.bottom);
      final ui.Rect innerClip = ui.Rect.fromLTRB(0.5, canvasSize.bottom / 2 + 0.5,
          canvasSize.right, canvasSize.bottom);
      final SurfaceSceneBuilder builder = SurfaceSceneBuilder();

      builder.pushClipRect(outerClip);

      {
        final EnginePictureRecorder recorder = EnginePictureRecorder();
        final RecordingCanvas canvas = recorder.beginRecording(outerClip);
        canvas.drawParagraph(paragraph, const ui.Offset(8.5, 8.5));
        final ui.Picture picture = recorder.endRecording();
        expect(paragraph.drawOnCanvas, isFalse);

        builder.addPicture(
          ui.Offset.zero,
          picture,
        );
      }

      builder.pushClipRect(innerClip);
      {
        final EnginePictureRecorder recorder = EnginePictureRecorder();
        final RecordingCanvas canvas = recorder.beginRecording(innerClip);
        canvas.drawParagraph(paragraph, ui.Offset(8.5, 8.5 + innerClip.top));
        final ui.Picture picture = recorder.endRecording();
        expect(paragraph.drawOnCanvas, isFalse);

        builder.addPicture(
          ui.Offset.zero,
          picture,
        );
      }
      builder.pop(); // inner clip
      builder.pop(); // outer clip

      final html.Element sceneElement = builder.build().webOnlyRootElement!;
      expect(
        sceneElement
            .querySelectorAll('p')
            .map<String>((html.Element e) => e.innerText)
            .toList(),
        <String>['Am I blurry?', 'Am I blurry?'],
        reason: 'Expected to render text using HTML',
      );
      html.document.body!.append(sceneElement);

      await matchGoldenFile(
        'compositing_draw_high_quality_text.png',
        region: canvasSize,
        maxDiffRatePercent: 0.0,
        pixelComparison: PixelComparison.precise,
      );
    },
    testOn: 'chrome',
  );
}

void _drawTestPicture(ui.SceneBuilder builder) {
  final EnginePictureRecorder recorder = EnginePictureRecorder();
  final RecordingCanvas canvas =
      recorder.beginRecording(const ui.Rect.fromLTRB(0, 0, 100, 100));
  canvas.drawCircle(
      const ui.Offset(10, 10), 10, SurfacePaint()..style = ui.PaintingStyle.fill);
  canvas.drawCircle(
      const ui.Offset(60, 10),
      10,
      SurfacePaint()
        ..style = ui.PaintingStyle.fill
        ..color = const ui.Color.fromRGBO(255, 0, 0, 1));
  canvas.drawCircle(
      const ui.Offset(10, 60),
      10,
      SurfacePaint()
        ..style = ui.PaintingStyle.fill
        ..color = const ui.Color.fromRGBO(0, 255, 0, 1));
  canvas.drawCircle(
      const ui.Offset(60, 60),
      10,
      SurfacePaint()
        ..style = ui.PaintingStyle.fill
        ..color = const ui.Color.fromRGBO(0, 0, 255, 1));
  final ui.Picture picture = recorder.endRecording();

  builder.addPicture(
    ui.Offset.zero,
    picture,
  );
}

typedef PaintCallback = void Function(RecordingCanvas canvas);

void drawWithBitmapCanvas(ui.SceneBuilder builder, PaintCallback callback,
    {ui.Rect bounds = ui.Rect.largest}) {
  final EnginePictureRecorder recorder = EnginePictureRecorder();
  final RecordingCanvas canvas = recorder.beginRecording(bounds);

  canvas.debugEnforceArbitraryPaint();
  callback(canvas);
  final ui.Picture picture = recorder.endRecording();

  builder.addPicture(
    ui.Offset.zero,
    picture,
  );
}
