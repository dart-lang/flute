// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ui/ui.dart' as ui;

import '../../engine.dart' show toMatrix32;
import '../picture.dart';
import '../util.dart';
import '../validators.dart';
import 'painting.dart';
import 'recording_canvas.dart';
import 'render_vertices.dart';

class SurfaceCanvas implements ui.Canvas {
  RecordingCanvas _canvas;

  factory SurfaceCanvas(EnginePictureRecorder recorder, [ui.Rect? cullRect]) {
    if (recorder.isRecording) {
      throw ArgumentError(
          '"recorder" must not already be associated with another Canvas.');
    }
    cullRect ??= ui.Rect.largest;
    return SurfaceCanvas._(recorder.beginRecording(cullRect));
  }

  SurfaceCanvas._(this._canvas);

  @override
  void save() {
    _canvas.save();
  }

  @override
  void saveLayer(ui.Rect? bounds, ui.Paint paint) {
    assert(paint != null); // ignore: unnecessary_null_comparison
    if (bounds == null) {
      _saveLayerWithoutBounds(paint);
    } else {
      assert(rectIsValid(bounds));
      _saveLayer(bounds, paint);
    }
  }

  void _saveLayerWithoutBounds(ui.Paint paint) {
    _canvas.saveLayerWithoutBounds(paint as SurfacePaint);
  }

  void _saveLayer(ui.Rect bounds, ui.Paint paint) {
    _canvas.saveLayer(bounds, paint as SurfacePaint);
  }

  @override
  void restore() {
    _canvas.restore();
  }

  @override
  int getSaveCount() => _canvas.saveCount;

  @override
  void translate(double dx, double dy) {
    _canvas.translate(dx, dy);
  }

  @override
  void scale(double sx, [double? sy]) => _scale(sx, sy ?? sx);

  void _scale(double sx, double sy) {
    _canvas.scale(sx, sy);
  }

  @override
  void rotate(double radians) {
    _canvas.rotate(radians);
  }

  @override
  void skew(double sx, double sy) {
    _canvas.skew(sx, sy);
  }

  @override
  void transform(Float64List matrix4) {
    assert(matrix4 != null); // ignore: unnecessary_null_comparison
    if (matrix4.length != 16) {
      throw ArgumentError('"matrix4" must have 16 entries.');
    }
    _transform(toMatrix32(matrix4));
  }

  void _transform(Float32List matrix4) {
    _canvas.transform(matrix4);
  }

  @override
  void clipRect(ui.Rect rect,
      {ui.ClipOp clipOp = ui.ClipOp.intersect, bool doAntiAlias = true}) {
    assert(rectIsValid(rect));
    assert(clipOp != null); // ignore: unnecessary_null_comparison
    assert(doAntiAlias != null); // ignore: unnecessary_null_comparison
    _clipRect(rect, clipOp, doAntiAlias);
  }

  void _clipRect(ui.Rect rect, ui.ClipOp clipOp, bool doAntiAlias) {
    _canvas.clipRect(rect, clipOp);
  }

  @override
  void clipRRect(ui.RRect rrect, {bool doAntiAlias = true}) {
    assert(rrectIsValid(rrect));
    assert(doAntiAlias != null); // ignore: unnecessary_null_comparison
    _clipRRect(rrect, doAntiAlias);
  }

  void _clipRRect(ui.RRect rrect, bool doAntiAlias) {
    _canvas.clipRRect(rrect);
  }

  @override
  void clipPath(ui.Path path, {bool doAntiAlias = true}) {
    // ignore: unnecessary_null_comparison
    assert(path != null); // path is checked on the engine side
    assert(doAntiAlias != null); // ignore: unnecessary_null_comparison
    _clipPath(path, doAntiAlias);
  }

  void _clipPath(ui.Path path, bool doAntiAlias) {
    _canvas.clipPath(path, doAntiAlias: doAntiAlias);
  }

  @override
  void drawColor(ui.Color color, ui.BlendMode blendMode) {
    assert(color != null); // ignore: unnecessary_null_comparison
    assert(blendMode != null); // ignore: unnecessary_null_comparison
    _drawColor(color, blendMode);
  }

  void _drawColor(ui.Color color, ui.BlendMode blendMode) {
    _canvas.drawColor(color, blendMode);
  }

  @override
  void drawLine(ui.Offset p1, ui.Offset p2, ui.Paint paint) {
    assert(offsetIsValid(p1));
    assert(offsetIsValid(p2));
    assert(paint != null); // ignore: unnecessary_null_comparison
    _drawLine(p1, p2, paint);
  }

  void _drawLine(ui.Offset p1, ui.Offset p2, ui.Paint paint) {
    _canvas.drawLine(p1, p2, paint as SurfacePaint);
  }

  @override
  void drawPaint(ui.Paint paint) {
    assert(paint != null); // ignore: unnecessary_null_comparison
    _drawPaint(paint);
  }

  void _drawPaint(ui.Paint paint) {
    _canvas.drawPaint(paint as SurfacePaint);
  }

  @override
  void drawRect(ui.Rect rect, ui.Paint paint) {
    assert(rectIsValid(rect));
    assert(paint != null); // ignore: unnecessary_null_comparison
    _drawRect(rect, paint);
  }

  void _drawRect(ui.Rect rect, ui.Paint paint) {
    _canvas.drawRect(rect, paint as SurfacePaint);
  }

  @override
  void drawRRect(ui.RRect rrect, ui.Paint paint) {
    assert(rrectIsValid(rrect));
    assert(paint != null); // ignore: unnecessary_null_comparison
    _drawRRect(rrect, paint);
  }

  void _drawRRect(ui.RRect rrect, ui.Paint paint) {
    _canvas.drawRRect(rrect, paint as SurfacePaint);
  }

  @override
  void drawDRRect(ui.RRect outer, ui.RRect inner, ui.Paint paint) {
    assert(rrectIsValid(outer));
    assert(rrectIsValid(inner));
    assert(paint != null); // ignore: unnecessary_null_comparison
    _drawDRRect(outer, inner, paint);
  }

  void _drawDRRect(ui.RRect outer, ui.RRect inner, ui.Paint paint) {
    _canvas.drawDRRect(outer, inner, paint as SurfacePaint);
  }

  @override
  void drawOval(ui.Rect rect, ui.Paint paint) {
    assert(rectIsValid(rect));
    assert(paint != null); // ignore: unnecessary_null_comparison
    _drawOval(rect, paint);
  }

  void _drawOval(ui.Rect rect, ui.Paint paint) {
    _canvas.drawOval(rect, paint as SurfacePaint);
  }

  @override
  void drawCircle(ui.Offset c, double radius, ui.Paint paint) {
    assert(offsetIsValid(c));
    assert(paint != null); // ignore: unnecessary_null_comparison
    _drawCircle(c, radius, paint);
  }

  void _drawCircle(ui.Offset c, double radius, ui.Paint paint) {
    _canvas.drawCircle(c, radius, paint as SurfacePaint);
  }

  @override
  void drawArc(ui.Rect rect, double startAngle, double sweepAngle,
      bool useCenter, ui.Paint paint) {
    assert(rectIsValid(rect));
    assert(paint != null); // ignore: unnecessary_null_comparison
    const double pi = math.pi;
    const double pi2 = 2.0 * pi;

    final ui.Path path = ui.Path();
    if (useCenter) {
      path.moveTo(
          (rect.left + rect.right) / 2.0, (rect.top + rect.bottom) / 2.0);
    }
    bool forceMoveTo = !useCenter;
    if (sweepAngle <= -pi2) {
      path.arcTo(rect, startAngle, -pi, forceMoveTo);
      startAngle -= pi;
      path.arcTo(rect, startAngle, -pi, false);
      startAngle -= pi;
      forceMoveTo = false;
      sweepAngle += pi2;
    }
    while (sweepAngle >= pi2) {
      path.arcTo(rect, startAngle, pi, forceMoveTo);
      startAngle += pi;
      path.arcTo(rect, startAngle, pi, false);
      startAngle += pi;
      forceMoveTo = false;
      sweepAngle -= pi2;
    }
    path.arcTo(rect, startAngle, sweepAngle, forceMoveTo);
    if (useCenter) {
      path.close();
    }
    _canvas.drawPath(path, paint as SurfacePaint);
  }

  @override
  void drawPath(ui.Path path, ui.Paint paint) {
    // ignore: unnecessary_null_comparison
    assert(path != null); // path is checked on the engine side
    assert(paint != null); // ignore: unnecessary_null_comparison
    _drawPath(path, paint);
  }

  void _drawPath(ui.Path path, ui.Paint paint) {
    _canvas.drawPath(path, paint as SurfacePaint);
  }

  @override
  void drawImage(ui.Image image, ui.Offset offset, ui.Paint paint) {
    // ignore: unnecessary_null_comparison
    assert(image != null); // image is checked on the engine side
    assert(offsetIsValid(offset));
    assert(paint != null); // ignore: unnecessary_null_comparison
    _drawImage(image, offset, paint);
  }

  void _drawImage(ui.Image image, ui.Offset p, ui.Paint paint) {
    _canvas.drawImage(image, p, paint as SurfacePaint);
  }

  @override
  void drawImageRect(ui.Image image, ui.Rect src, ui.Rect dst, ui.Paint paint) {
    // ignore: unnecessary_null_comparison
    assert(image != null); // image is checked on the engine side
    assert(rectIsValid(src));
    assert(rectIsValid(dst));
    assert(paint != null); // ignore: unnecessary_null_comparison
    _drawImageRect(image, src, dst, paint);
  }

  void _drawImageRect(
      ui.Image image, ui.Rect src, ui.Rect dst, ui.Paint paint) {
    _canvas.drawImageRect(image, src, dst, paint as SurfacePaint);
  }

  // Return a list of slice coordinates based on the size of the nine-slice parameters in
  // one dimension. Each set of slice coordinates contains a begin/end pair for each of the
  // source (image) and dest (screen) in the order (src0, dst0, src1, dst1).
  // The area from src0 => src1 of the image is painted on the screen from dst0 => dst1
  // The slices for each dimension are generated independently.
  List<double> _initSlices(double img0, double imgC0, double imgC1, double img1, double dst0, double dst1) {
    final double imageDim = img1 - img0;
    final double destDim = dst1 - dst0;

    if (imageDim == destDim) {
      // If the src and dest are the same size then we do not need scaling
      // We return 4 values for a single slice
      return <double>[ img0, dst0, img1, dst1 ];
    }

    final double edge0Dim = imgC0 - img0;
    final double edge1Dim = img1 - imgC1;
    final double edgesDim = edge0Dim + edge1Dim;

    if (edgesDim >= destDim) {
      // the center portion has disappeared, leaving only the edges to scale to a common
      // center position in the destination
      // this produces only 2 slices which is 8 values
      final double dstC = dst0 + destDim * edge0Dim / edgesDim;
      return <double>[
        img0,  dst0, imgC0, dstC,
        imgC1, dstC, img1,  dst1,
      ];
    }

    // center portion is nonEmpty and only that part is scaled
    // we need 3 slices which is 12 values
    final double dstC0 = dst0 + edge0Dim;
    final double dstC1 = dst1 - edge1Dim;
    return <double>[
      img0,  dst0,  imgC0, dstC0,
      imgC0, dstC0, imgC1, dstC1,
      imgC1, dstC1, img1,  dst1
    ];
  }

  @override
  void drawImageNine(
      ui.Image image, ui.Rect center, ui.Rect dst, ui.Paint paint) {
    // ignore: unnecessary_null_comparison
    assert(image != null); // image is checked on the engine side
    assert(rectIsValid(center));
    assert(rectIsValid(dst));
    assert(paint != null); // ignore: unnecessary_null_comparison

    if (dst.isEmpty)
      return;

    final List<double> hSlices = _initSlices(
      0,
      center.left,
      center.right,
      image.width.toDouble(),
      dst.left,
      dst.right,
    );
    final List<double> vSlices = _initSlices(
      0,
      center.top,
      center.bottom,
      image.height.toDouble(),
      dst.top,
      dst.bottom,
    );

    for (int yi = 0; yi < vSlices.length; yi += 4) {
      final double srcY0 = vSlices[yi];
      final double dstY0 = vSlices[yi + 1];
      final double srcY1 = vSlices[yi + 2];
      final double dstY1 = vSlices[yi + 3];
      for (int xi = 0; xi < hSlices.length; xi += 4) {
        final double srcX0 = hSlices[xi];
        final double dstX0 = hSlices[xi + 1];
        final double srcX1 = hSlices[xi + 2];
        final double dstX1 = hSlices[xi + 3];
        drawImageRect(
          image,
          ui.Rect.fromLTRB(srcX0, srcY0, srcX1, srcY1),
          ui.Rect.fromLTRB(dstX0, dstY0, dstX1, dstY1),
          paint,
        );
      }
    }
  }

  @override
  void drawPicture(ui.Picture picture) {
    // ignore: unnecessary_null_comparison
    assert(picture != null); // picture is checked on the engine side
    _canvas.drawPicture(picture);
  }

  @override
  void drawParagraph(ui.Paragraph paragraph, ui.Offset offset) {
    assert(paragraph != null); // ignore: unnecessary_null_comparison
    assert(offsetIsValid(offset));
    _drawParagraph(paragraph, offset);
  }

  void _drawParagraph(ui.Paragraph paragraph, ui.Offset offset) {
    _canvas.drawParagraph(paragraph, offset);
  }

  @override
  void drawPoints(
      ui.PointMode pointMode, List<ui.Offset> points, ui.Paint paint) {
    assert(pointMode != null); // ignore: unnecessary_null_comparison
    assert(points != null); // ignore: unnecessary_null_comparison
    assert(paint != null); // ignore: unnecessary_null_comparison
    final Float32List pointList = offsetListToFloat32List(points);
    drawRawPoints(pointMode, pointList, paint);
  }

  @override
  void drawRawPoints(
      ui.PointMode pointMode, Float32List points, ui.Paint paint) {
    assert(pointMode != null); // ignore: unnecessary_null_comparison
    assert(points != null); // ignore: unnecessary_null_comparison
    assert(paint != null); // ignore: unnecessary_null_comparison
    if (points.length % 2 != 0) {
      throw ArgumentError('"points" must have an even number of values.');
    }
    _canvas.drawRawPoints(pointMode, points, paint as SurfacePaint);
  }

  @override
  void drawVertices(
      ui.Vertices vertices, ui.BlendMode blendMode, ui.Paint paint) {
    //assert(vertices != null); // vertices is checked on the engine side
    assert(paint != null); // ignore: unnecessary_null_comparison
    assert(blendMode != null); // ignore: unnecessary_null_comparison
    _canvas.drawVertices(
        vertices as SurfaceVertices, blendMode, paint as SurfacePaint);
  }

  @override
  void drawAtlas(
    ui.Image atlas,
    List<ui.RSTransform> transforms,
    List<ui.Rect> rects,
    List<ui.Color>? colors,
    ui.BlendMode? blendMode,
    ui.Rect? cullRect,
    ui.Paint paint,
  ) {
    // ignore: unnecessary_null_comparison
    assert(atlas != null); // atlas is checked on the engine side
    assert(transforms != null); // ignore: unnecessary_null_comparison
    assert(rects != null); // ignore: unnecessary_null_comparison
    assert(colors == null || colors.isEmpty || blendMode != null);
    assert(paint != null); // ignore: unnecessary_null_comparison

    final int rectCount = rects.length;
    if (transforms.length != rectCount) {
      throw ArgumentError('"transforms" and "rects" lengths must match.');
    }
    if (colors != null && colors.isNotEmpty && colors.length != rectCount) {
      throw ArgumentError(
          'If non-null, "colors" length must match that of "transforms" and "rects".');
    }

    // TODO(het): Do we need to support this?
    throw UnimplementedError();
  }

  @override
  void drawRawAtlas(
    ui.Image atlas,
    Float32List rstTransforms,
    Float32List rects,
    Int32List? colors,
    ui.BlendMode? blendMode,
    ui.Rect? cullRect,
    ui.Paint paint,
  ) {
    // ignore: unnecessary_null_comparison
    assert(atlas != null); // atlas is checked on the engine side
    assert(rstTransforms != null); // ignore: unnecessary_null_comparison
    assert(rects != null); // ignore: unnecessary_null_comparison
    assert(colors == null || blendMode != null);
    assert(paint != null); // ignore: unnecessary_null_comparison

    final int rectCount = rects.length;
    if (rstTransforms.length != rectCount) {
      throw ArgumentError('"rstTransforms" and "rects" lengths must match.');
    }
    if (rectCount % 4 != 0) {
      throw ArgumentError(
          '"rstTransforms" and "rects" lengths must be a multiple of four.');
    }
    if (colors != null && colors.length * 4 != rectCount) {
      throw ArgumentError(
          'If non-null, "colors" length must be one fourth the length of "rstTransforms" and "rects".');
    }

    // TODO(het): Do we need to support this?
    throw UnimplementedError();
  }

  @override
  void drawShadow(
    ui.Path path,
    ui.Color color,
    double elevation,
    bool transparentOccluder,
  ) {
    // ignore: unnecessary_null_comparison
    assert(path != null); // path is checked on the engine side
    assert(color != null); // ignore: unnecessary_null_comparison
    assert(transparentOccluder != null); // ignore: unnecessary_null_comparison
    _canvas.drawShadow(path, color, elevation, transparentOccluder);
  }
}
