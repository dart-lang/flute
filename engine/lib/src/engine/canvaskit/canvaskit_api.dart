// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Bindings for CanvasKit JavaScript API.
///
/// Prefer keeping the original CanvasKit names so it is easier to locate
/// the API behind these bindings in the Skia source code.
// ignore_for_file: non_constant_identifier_names

// ignore_for_file: public_member_api_docs
@JS()
library canvaskit_api;

import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:typed_data';

import 'package:js/js.dart';
import 'package:ui/ui.dart' as ui;

import '../profiler.dart';

/// Entrypoint into the CanvasKit API.
late CanvasKit canvasKit;

/// Sets the [CanvasKit] object on `window` so we can use `@JS()` to bind to
/// static APIs.
///
/// See, e.g. [SkPaint].
///
/// This also acts as a cache of an initialized CanvasKit instance. We can use
/// this, for example, to perform a hot restart without needing to redownload
/// and reinitialize CanvasKit.
@JS('window.flutterCanvasKit')
external set windowFlutterCanvasKit(CanvasKit? value);

@JS('window.flutterCanvasKit')
external CanvasKit? get windowFlutterCanvasKit;

@JS()
@anonymous
class CanvasKit {
  external SkBlendModeEnum get BlendMode;
  external SkPaintStyleEnum get PaintStyle;
  external SkStrokeCapEnum get StrokeCap;
  external SkStrokeJoinEnum get StrokeJoin;
  external SkBlurStyleEnum get BlurStyle;
  external SkTileModeEnum get TileMode;
  external SkFilterModeEnum get FilterMode;
  external SkMipmapModeEnum get MipmapMode;
  external SkFillTypeEnum get FillType;
  external SkAlphaTypeEnum get AlphaType;
  external SkColorTypeEnum get ColorType;
  external SkPathOpEnum get PathOp;
  external SkClipOpEnum get ClipOp;
  external SkPointModeEnum get PointMode;
  external SkVertexModeEnum get VertexMode;
  external SkRectHeightStyleEnum get RectHeightStyle;
  external SkRectWidthStyleEnum get RectWidthStyle;
  external SkAffinityEnum get Affinity;
  external SkTextAlignEnum get TextAlign;
  external SkTextHeightBehaviorEnum get TextHeightBehavior;
  external SkTextDirectionEnum get TextDirection;
  external SkFontWeightEnum get FontWeight;
  external SkFontSlantEnum get FontSlant;
  external SkAnimatedImage? MakeAnimatedImageFromEncoded(Uint8List imageData);
  external SkShaderNamespace get Shader;
  external SkMaskFilterNamespace get MaskFilter;
  external SkColorFilterNamespace get ColorFilter;
  external SkImageFilterNamespace get ImageFilter;
  external SkPathNamespace get Path;
  external SkTonalColors computeTonalColors(SkTonalColors inTonalColors);
  external SkVertices MakeVertices(
    SkVertexMode mode,
    Float32List positions,
    Float32List? textureCoordinates,
    Uint32List? colors,
    Uint16List? indices,
  );
  external SkParagraphBuilderNamespace get ParagraphBuilder;
  external SkParagraphStyle ParagraphStyle(
      SkParagraphStyleProperties properties);
  external SkTextStyle TextStyle(SkTextStyleProperties properties);
  external SkSurface MakeSurface(
    int width,
    int height,
  );
  external Uint8List getDataBytes(
    SkData skData,
  );

  // Text decoration enum is embedded in the CanvasKit object itself.
  external int get NoDecoration;
  external int get UnderlineDecoration;
  external int get OverlineDecoration;
  external int get LineThroughDecoration;
  // End of text decoration enum.

  external SkTextDecorationStyleEnum get DecorationStyle;
  external SkTextBaselineEnum get TextBaseline;
  external SkPlaceholderAlignmentEnum get PlaceholderAlignment;

  external SkFontMgrNamespace get FontMgr;
  external TypefaceFontProviderNamespace get TypefaceFontProvider;
  external SkTypefaceFactory get Typeface;
  external int GetWebGLContext(
      html.CanvasElement canvas, SkWebGLContextOptions options);
  external SkGrContext MakeGrContext(int glContext);
  external SkSurface? MakeOnScreenGLSurface(
    SkGrContext grContext,
    int width,
    int height,
    ColorSpace colorSpace,
  );
  external SkSurface MakeSWCanvasSurface(html.CanvasElement canvas);

  /// Creates an image from decoded pixels represented as a list of bytes.
  ///
  /// The pixel data must be encoded according to the image info in [info].
  ///
  /// Typically pixel data is obtained using [SkImage.readPixels]. The
  /// parameters specified in [SkImageInfo] passed [SkImage.readPixels] must
  /// match [info].
  external SkImage? MakeImage(
    SkImageInfo info,
    Uint8List pixels,
    int bytesPerRow,
  );
  external SkImage? MakeLazyImageFromTextureSource(
    Object src,
    SkPartialImageInfo info,
  );
}

@JS('window.CanvasKitInit')
external CanvasKitInitPromise CanvasKitInit(CanvasKitInitOptions options);

typedef LocateFileCallback = String Function(String file, String unusedBase);

@JS()
@anonymous
class CanvasKitInitOptions {
  external factory CanvasKitInitOptions({
    required LocateFileCallback locateFile,
  });
}

typedef CanvasKitInitCallback = void Function(CanvasKit canvasKit);

@JS()
class CanvasKitInitPromise {
  external void then(CanvasKitInitCallback callback);
}

@JS('window.flutterCanvasKit.ColorSpace.SRGB')
external ColorSpace get SkColorSpaceSRGB;

@JS()
class ColorSpace {}

@JS()
@anonymous
class SkWebGLContextOptions {
  external factory SkWebGLContextOptions({
    required int antialias,
    // WebGL version: 1 or 2.
    required int majorVersion,
  });
}

@JS('window.flutterCanvasKit.Surface')
class SkSurface {
  external SkCanvas getCanvas();
  external void flush();
  external int width();
  external int height();
  external void dispose();
  external SkImage makeImageSnapshot();
}

@JS()
@anonymous
class SkGrContext {
  external void setResourceCacheLimitBytes(int limit);
  external void releaseResourcesAndAbandonContext();
  external void delete();
}

@JS()
@anonymous
class SkFontSlantEnum {
  external SkFontSlant get Upright;
  external SkFontSlant get Italic;
}

@JS('window.flutterCanvasKit.FontSlant')
class SkFontSlant {
  external int get value;
}

final List<SkFontSlant> _skFontSlants = <SkFontSlant>[
  canvasKit.FontSlant.Upright,
  canvasKit.FontSlant.Italic,
];

SkFontSlant toSkFontSlant(ui.FontStyle style) {
  return _skFontSlants[style.index];
}

@JS()
@anonymous
class SkFontWeightEnum {
  external SkFontWeight get Thin;
  external SkFontWeight get ExtraLight;
  external SkFontWeight get Light;
  external SkFontWeight get Normal;
  external SkFontWeight get Medium;
  external SkFontWeight get SemiBold;
  external SkFontWeight get Bold;
  external SkFontWeight get ExtraBold;
  external SkFontWeight get ExtraBlack;
}

@JS()
class SkFontWeight {
  external int get value;
}

final List<SkFontWeight> _skFontWeights = <SkFontWeight>[
  canvasKit.FontWeight.Thin,
  canvasKit.FontWeight.ExtraLight,
  canvasKit.FontWeight.Light,
  canvasKit.FontWeight.Normal,
  canvasKit.FontWeight.Medium,
  canvasKit.FontWeight.SemiBold,
  canvasKit.FontWeight.Bold,
  canvasKit.FontWeight.ExtraBold,
  canvasKit.FontWeight.ExtraBlack,
];

SkFontWeight toSkFontWeight(ui.FontWeight weight) {
  return _skFontWeights[weight.index];
}

@JS()
class SkAffinityEnum {
  external SkAffinity get Upstream;
  external SkAffinity get Downstream;
}

@JS()
class SkAffinity {
  external int get value;
}

final List<SkAffinity> _skAffinitys = <SkAffinity>[
  canvasKit.Affinity.Upstream,
  canvasKit.Affinity.Downstream,
];

SkAffinity toSkAffinity(ui.TextAffinity affinity) {
  return _skAffinitys[affinity.index];
}

@JS()
class SkTextDirectionEnum {
  external SkTextDirection get RTL;
  external SkTextDirection get LTR;
}

@JS()
class SkTextDirection {
  external int get value;
}

// Flutter enumerates text directions as RTL, LTR, while CanvasKit
// enumerates them LTR, RTL.
final List<SkTextDirection> _skTextDirections = <SkTextDirection>[
  canvasKit.TextDirection.RTL,
  canvasKit.TextDirection.LTR,
];

SkTextDirection toSkTextDirection(ui.TextDirection direction) {
  return _skTextDirections[direction.index];
}

@JS()
class SkTextAlignEnum {
  external SkTextAlign get Left;
  external SkTextAlign get Right;
  external SkTextAlign get Center;
  external SkTextAlign get Justify;
  external SkTextAlign get Start;
  external SkTextAlign get End;
}

@JS()
class SkTextAlign {
  external int get value;
}

final List<SkTextAlign> _skTextAligns = <SkTextAlign>[
  canvasKit.TextAlign.Left,
  canvasKit.TextAlign.Right,
  canvasKit.TextAlign.Center,
  canvasKit.TextAlign.Justify,
  canvasKit.TextAlign.Start,
  canvasKit.TextAlign.End,
];

SkTextAlign toSkTextAlign(ui.TextAlign align) {
  return _skTextAligns[align.index];
}

@JS()
class SkTextHeightBehaviorEnum {
  external SkTextHeightBehavior get All;
  external SkTextHeightBehavior get DisableFirstAscent;
  external SkTextHeightBehavior get DisableLastDescent;
  external SkTextHeightBehavior get DisableAll;
}

@JS()
class SkTextHeightBehavior {
  external int get value;
}

final List<SkTextHeightBehavior> _skTextHeightBehaviors =
    <SkTextHeightBehavior>[
  canvasKit.TextHeightBehavior.All,
  canvasKit.TextHeightBehavior.DisableFirstAscent,
  canvasKit.TextHeightBehavior.DisableLastDescent,
  canvasKit.TextHeightBehavior.DisableAll,
];

SkTextHeightBehavior toSkTextHeightBehavior(ui.TextHeightBehavior behavior) {
  final int index = (behavior.applyHeightToFirstAscent ? 0 : 1 << 0) |
      (behavior.applyHeightToLastDescent ? 0 : 1 << 1);
  return _skTextHeightBehaviors[index];
}

@JS()
class SkRectHeightStyleEnum {
  external SkRectHeightStyle get Tight;
  external SkRectHeightStyle get Max;
  external SkRectHeightStyle get IncludeLineSpacingMiddle;
  external SkRectHeightStyle get IncludeLineSpacingTop;
  external SkRectHeightStyle get IncludeLineSpacingBottom;
  external SkRectHeightStyle get Strut;
}

@JS()
class SkRectHeightStyle {
  external int get value;
}

final List<SkRectHeightStyle> _skRectHeightStyles = <SkRectHeightStyle>[
  canvasKit.RectHeightStyle.Tight,
  canvasKit.RectHeightStyle.Max,
  canvasKit.RectHeightStyle.IncludeLineSpacingMiddle,
  canvasKit.RectHeightStyle.IncludeLineSpacingTop,
  canvasKit.RectHeightStyle.IncludeLineSpacingBottom,
  canvasKit.RectHeightStyle.Strut,
];

SkRectHeightStyle toSkRectHeightStyle(ui.BoxHeightStyle style) {
  return _skRectHeightStyles[style.index];
}

@JS()
class SkRectWidthStyleEnum {
  external SkRectWidthStyle get Tight;
  external SkRectWidthStyle get Max;
}

@JS()
class SkRectWidthStyle {
  external int get value;
}

final List<SkRectWidthStyle> _skRectWidthStyles = <SkRectWidthStyle>[
  canvasKit.RectWidthStyle.Tight,
  canvasKit.RectWidthStyle.Max,
];

SkRectWidthStyle toSkRectWidthStyle(ui.BoxWidthStyle style) {
  final int index = style.index;
  return _skRectWidthStyles[index < 2 ? index : 0];
}

@JS()
class SkVertexModeEnum {
  external SkVertexMode get Triangles;
  external SkVertexMode get TrianglesStrip;
  external SkVertexMode get TriangleFan;
}

@JS()
class SkVertexMode {
  external int get value;
}

final List<SkVertexMode> _skVertexModes = <SkVertexMode>[
  canvasKit.VertexMode.Triangles,
  canvasKit.VertexMode.TrianglesStrip,
  canvasKit.VertexMode.TriangleFan,
];

SkVertexMode toSkVertexMode(ui.VertexMode mode) {
  return _skVertexModes[mode.index];
}

@JS()
class SkPointModeEnum {
  external SkPointMode get Points;
  external SkPointMode get Lines;
  external SkPointMode get Polygon;
}

@JS()
class SkPointMode {
  external int get value;
}

final List<SkPointMode> _skPointModes = <SkPointMode>[
  canvasKit.PointMode.Points,
  canvasKit.PointMode.Lines,
  canvasKit.PointMode.Polygon,
];

SkPointMode toSkPointMode(ui.PointMode mode) {
  return _skPointModes[mode.index];
}

@JS()
class SkClipOpEnum {
  external SkClipOp get Difference;
  external SkClipOp get Intersect;
}

@JS()
class SkClipOp {
  external int get value;
}

final List<SkClipOp> _skClipOps = <SkClipOp>[
  canvasKit.ClipOp.Difference,
  canvasKit.ClipOp.Intersect,
];

SkClipOp toSkClipOp(ui.ClipOp clipOp) {
  return _skClipOps[clipOp.index];
}

@JS()
class SkFillTypeEnum {
  external SkFillType get Winding;
  external SkFillType get EvenOdd;
}

@JS()
class SkFillType {
  external int get value;
}

final List<SkFillType> _skFillTypes = <SkFillType>[
  canvasKit.FillType.Winding,
  canvasKit.FillType.EvenOdd,
];

SkFillType toSkFillType(ui.PathFillType fillType) {
  return _skFillTypes[fillType.index];
}

@JS()
class SkPathOpEnum {
  external SkPathOp get Difference;
  external SkPathOp get Intersect;
  external SkPathOp get Union;
  external SkPathOp get XOR;
  external SkPathOp get ReverseDifference;
}

@JS()
class SkPathOp {
  external int get value;
}

final List<SkPathOp> _skPathOps = <SkPathOp>[
  canvasKit.PathOp.Difference,
  canvasKit.PathOp.Intersect,
  canvasKit.PathOp.Union,
  canvasKit.PathOp.XOR,
  canvasKit.PathOp.ReverseDifference,
];

SkPathOp toSkPathOp(ui.PathOperation pathOp) {
  return _skPathOps[pathOp.index];
}

@JS()
class SkBlurStyleEnum {
  external SkBlurStyle get Normal;
  external SkBlurStyle get Solid;
  external SkBlurStyle get Outer;
  external SkBlurStyle get Inner;
}

@JS()
class SkBlurStyle {
  external int get value;
}

final List<SkBlurStyle> _skBlurStyles = <SkBlurStyle>[
  canvasKit.BlurStyle.Normal,
  canvasKit.BlurStyle.Solid,
  canvasKit.BlurStyle.Outer,
  canvasKit.BlurStyle.Inner,
];

SkBlurStyle toSkBlurStyle(ui.BlurStyle style) {
  return _skBlurStyles[style.index];
}

@JS()
class SkStrokeCapEnum {
  external SkStrokeCap get Butt;
  external SkStrokeCap get Round;
  external SkStrokeCap get Square;
}

@JS()
class SkStrokeCap {
  external int get value;
}

final List<SkStrokeCap> _skStrokeCaps = <SkStrokeCap>[
  canvasKit.StrokeCap.Butt,
  canvasKit.StrokeCap.Round,
  canvasKit.StrokeCap.Square,
];

SkStrokeCap toSkStrokeCap(ui.StrokeCap strokeCap) {
  return _skStrokeCaps[strokeCap.index];
}

@JS()
class SkPaintStyleEnum {
  external SkPaintStyle get Stroke;
  external SkPaintStyle get Fill;
}

@JS()
class SkPaintStyle {
  external int get value;
}

final List<SkPaintStyle> _skPaintStyles = <SkPaintStyle>[
  canvasKit.PaintStyle.Fill,
  canvasKit.PaintStyle.Stroke,
];

SkPaintStyle toSkPaintStyle(ui.PaintingStyle paintStyle) {
  return _skPaintStyles[paintStyle.index];
}

@JS()
class SkBlendModeEnum {
  external SkBlendMode get Clear;
  external SkBlendMode get Src;
  external SkBlendMode get Dst;
  external SkBlendMode get SrcOver;
  external SkBlendMode get DstOver;
  external SkBlendMode get SrcIn;
  external SkBlendMode get DstIn;
  external SkBlendMode get SrcOut;
  external SkBlendMode get DstOut;
  external SkBlendMode get SrcATop;
  external SkBlendMode get DstATop;
  external SkBlendMode get Xor;
  external SkBlendMode get Plus;
  external SkBlendMode get Modulate;
  external SkBlendMode get Screen;
  external SkBlendMode get Overlay;
  external SkBlendMode get Darken;
  external SkBlendMode get Lighten;
  external SkBlendMode get ColorDodge;
  external SkBlendMode get ColorBurn;
  external SkBlendMode get HardLight;
  external SkBlendMode get SoftLight;
  external SkBlendMode get Difference;
  external SkBlendMode get Exclusion;
  external SkBlendMode get Multiply;
  external SkBlendMode get Hue;
  external SkBlendMode get Saturation;
  external SkBlendMode get Color;
  external SkBlendMode get Luminosity;
}

@JS()
class SkBlendMode {
  external int get value;
}

final List<SkBlendMode> _skBlendModes = <SkBlendMode>[
  canvasKit.BlendMode.Clear,
  canvasKit.BlendMode.Src,
  canvasKit.BlendMode.Dst,
  canvasKit.BlendMode.SrcOver,
  canvasKit.BlendMode.DstOver,
  canvasKit.BlendMode.SrcIn,
  canvasKit.BlendMode.DstIn,
  canvasKit.BlendMode.SrcOut,
  canvasKit.BlendMode.DstOut,
  canvasKit.BlendMode.SrcATop,
  canvasKit.BlendMode.DstATop,
  canvasKit.BlendMode.Xor,
  canvasKit.BlendMode.Plus,
  canvasKit.BlendMode.Modulate,
  canvasKit.BlendMode.Screen,
  canvasKit.BlendMode.Overlay,
  canvasKit.BlendMode.Darken,
  canvasKit.BlendMode.Lighten,
  canvasKit.BlendMode.ColorDodge,
  canvasKit.BlendMode.ColorBurn,
  canvasKit.BlendMode.HardLight,
  canvasKit.BlendMode.SoftLight,
  canvasKit.BlendMode.Difference,
  canvasKit.BlendMode.Exclusion,
  canvasKit.BlendMode.Multiply,
  canvasKit.BlendMode.Hue,
  canvasKit.BlendMode.Saturation,
  canvasKit.BlendMode.Color,
  canvasKit.BlendMode.Luminosity,
];

SkBlendMode toSkBlendMode(ui.BlendMode blendMode) {
  return _skBlendModes[blendMode.index];
}

@JS()
class SkStrokeJoinEnum {
  external SkStrokeJoin get Miter;
  external SkStrokeJoin get Round;
  external SkStrokeJoin get Bevel;
}

@JS()
class SkStrokeJoin {
  external int get value;
}

final List<SkStrokeJoin> _skStrokeJoins = <SkStrokeJoin>[
  canvasKit.StrokeJoin.Miter,
  canvasKit.StrokeJoin.Round,
  canvasKit.StrokeJoin.Bevel,
];

SkStrokeJoin toSkStrokeJoin(ui.StrokeJoin strokeJoin) {
  return _skStrokeJoins[strokeJoin.index];
}

@JS()
class SkTileModeEnum {
  external SkTileMode get Clamp;
  external SkTileMode get Repeat;
  external SkTileMode get Mirror;
  external SkTileMode get Decal;
}

@JS()
class SkTileMode {
  external int get value;
}

final List<SkTileMode> _skTileModes = <SkTileMode>[
  canvasKit.TileMode.Clamp,
  canvasKit.TileMode.Repeat,
  canvasKit.TileMode.Mirror,
  canvasKit.TileMode.Decal,
];

SkTileMode toSkTileMode(ui.TileMode mode) {
  return _skTileModes[mode.index];
}

@JS()
class SkFilterModeEnum {
  external SkFilterMode get Nearest;
  external SkFilterMode get Linear;
}

@JS()
class SkFilterMode {
  external int get value;
}

SkFilterMode toSkFilterMode(ui.FilterQuality filterQuality) {
  return filterQuality == ui.FilterQuality.none
      ? canvasKit.FilterMode.Nearest
      : canvasKit.FilterMode.Linear;
}

@JS()
class SkMipmapModeEnum {
  external SkMipmapMode get None;
  external SkMipmapMode get Nearest;
  external SkMipmapMode get Linear;
}

@JS()
class SkMipmapMode {
  external int get value;
}

SkMipmapMode toSkMipmapMode(ui.FilterQuality filterQuality) {
  return filterQuality == ui.FilterQuality.medium
      ? canvasKit.MipmapMode.Linear
      : canvasKit.MipmapMode.None;
}

@JS()
class SkAlphaTypeEnum {
  external SkAlphaType get Opaque;
  external SkAlphaType get Premul;
  external SkAlphaType get Unpremul;
}

@JS()
class SkAlphaType {
  external int get value;
}

@JS()
class SkColorTypeEnum {
  external SkColorType get Alpha_8;
  external SkColorType get RGB_565;
  external SkColorType get ARGB_4444;
  external SkColorType get RGBA_8888;
  external SkColorType get RGB_888x;
  external SkColorType get BGRA_8888;
  external SkColorType get RGBA_1010102;
  external SkColorType get RGB_101010x;
  external SkColorType get Gray_8;
  external SkColorType get RGBA_F16;
  external SkColorType get RGBA_F32;
}

@JS()
class SkColorType {
  external int get value;
}

@JS()
@anonymous
class SkAnimatedImage {
  external int getFrameCount();

  /// Returns duration in milliseconds.
  external int getRepetitionCount();
  external int decodeNextFrame();
  external SkImage makeImageAtCurrentFrame();
  external int width();
  external int height();

  /// Deletes the C++ object.
  ///
  /// This object is no longer usable after calling this method.
  external void delete();
  external bool isDeleted();
}

@JS()
@anonymous
class SkImage {
  external void delete();
  external int width();
  external int height();
  external SkShader makeShaderCubic(
    SkTileMode tileModeX,
    SkTileMode tileModeY,
    double B,
    double C,
    Float32List? matrix, // 3x3 matrix
  );
  external SkShader makeShaderOptions(
    SkTileMode tileModeX,
    SkTileMode tileModeY,
    SkFilterMode filterMode,
    SkMipmapMode mipmapMode,
    Float32List? matrix, // 3x3 matrix
  );
  external Uint8List readPixels(int srcX, int srcY, SkImageInfo imageInfo);
  external Uint8List? encodeToBytes();
  external bool isAliasOf(SkImage other);
  external bool isDeleted();
}

@JS()
class SkShaderNamespace {
  external SkShader MakeLinearGradient(
    Float32List from, // 2-element array
    Float32List to, // 2-element array
    Uint32List colors,
    Float32List colorStops,
    SkTileMode tileMode,
    Float32List? matrix,
  );

  external SkShader MakeRadialGradient(
    Float32List center, // 2-element array
    double radius,
    Uint32List colors,
    Float32List colorStops,
    SkTileMode tileMode,
    Float32List? matrix, // 3x3 matrix
    int flags,
  );

  external SkShader MakeTwoPointConicalGradient(
    Float32List focal,
    double focalRadius,
    Float32List center,
    double radius,
    Uint32List colors,
    Float32List colorStops,
    SkTileMode tileMode,
    Float32List? matrix, // 3x3 matrix
    int flags,
  );

  external SkShader MakeSweepGradient(
    double cx,
    double cy,
    Uint32List colors,
    Float32List colorStops,
    SkTileMode tileMode,
    Float32List? matrix, // 3x3 matrix
    int flags,
    double startAngle,
    double endAngle,
  );
}

@JS()
@anonymous
class SkShader {
  external void delete();
}

@JS()
class SkMaskFilterNamespace {
  // Creates a blur MaskFilter.
  //
  // Returns `null` if [sigma] is 0 or infinite.
  external SkMaskFilter? MakeBlur(
      SkBlurStyle blurStyle, double sigma, bool respectCTM);
}

// This needs to be bound to top-level because SkPaint is initialized
// with `new`. Also in Dart you can't write this:
//
//     external SkPaint SkPaint();
@JS('window.flutterCanvasKit.Paint')
class SkPaint {
  external SkPaint();
  external void setBlendMode(SkBlendMode blendMode);
  external void setStyle(SkPaintStyle paintStyle);
  external void setStrokeWidth(double width);
  external void setStrokeCap(SkStrokeCap cap);
  external void setStrokeJoin(SkStrokeJoin join);
  external void setAntiAlias(bool isAntiAlias);
  external void setColorInt(int color);
  external void setShader(SkShader? shader);
  external void setMaskFilter(SkMaskFilter? maskFilter);
  external void setColorFilter(SkColorFilter? colorFilter);
  external void setStrokeMiter(double miterLimit);
  external void setImageFilter(SkImageFilter? imageFilter);
  external void delete();
}

@JS()
@anonymous
abstract class CkFilterOptions {}

@JS()
@anonymous
class _CkCubicFilterOptions extends CkFilterOptions {
  external double get B;
  external double get C;

  external factory _CkCubicFilterOptions({double B, double C});
}

@JS()
@anonymous
class _CkTransformFilterOptions extends CkFilterOptions {
  external SkFilterMode get filter;
  external SkMipmapMode get mipmap;

  external factory _CkTransformFilterOptions(
      {SkFilterMode filter, SkMipmapMode mipmap});
}

final Map<ui.FilterQuality, CkFilterOptions> _filterOptions =
    <ui.FilterQuality, CkFilterOptions>{
  ui.FilterQuality.none: _CkTransformFilterOptions(
    filter: canvasKit.FilterMode.Nearest,
    mipmap: canvasKit.MipmapMode.None,
  ),
  ui.FilterQuality.low: _CkTransformFilterOptions(
    filter: canvasKit.FilterMode.Linear,
    mipmap: canvasKit.MipmapMode.None,
  ),
  ui.FilterQuality.medium: _CkTransformFilterOptions(
    filter: canvasKit.FilterMode.Linear,
    mipmap: canvasKit.MipmapMode.Linear,
  ),
  ui.FilterQuality.high: _CkCubicFilterOptions(
    B: 1.0 / 3,
    C: 1.0 / 3,
  ),
};

CkFilterOptions toSkFilterOptions(ui.FilterQuality filterQuality) {
  return _filterOptions[filterQuality]!;
}

@JS()
@anonymous
class SkMaskFilter {
  external void delete();
}

@JS()
class SkColorFilterNamespace {
  external SkColorFilter MakeBlend(Float32List color, SkBlendMode blendMode);
  external SkColorFilter MakeMatrix(
    Float32List matrix, // 20-element matrix
  );
  external SkColorFilter MakeLinearToSRGBGamma();
  external SkColorFilter MakeSRGBToLinearGamma();
  external SkColorFilter MakeCompose(SkColorFilter? outer, SkColorFilter inner);
}

@JS()
@anonymous
class SkColorFilter {
  external void delete();
}

@JS()
class SkImageFilterNamespace {
  external SkImageFilter MakeBlur(
    double sigmaX,
    double sigmaY,
    SkTileMode tileMode,
    void input, // we don't use this yet
  );

  external SkImageFilter MakeMatrixTransform(
    Float32List matrix, // 3x3 matrix
    CkFilterOptions filterOptions,
    void input, // we don't use this yet
  );

  external SkImageFilter MakeColorFilter(
    SkColorFilter colorFilter,
    void input, // we don't use this yet
  );

  external SkImageFilter MakeCompose(
    SkImageFilter outer,
    SkImageFilter inner,
  );
}

@JS()
@anonymous
class SkImageFilter {
  external void delete();
}

@JS()
class SkPathNamespace {
  /// Creates an [SkPath] using commands obtained from [SkPath.toCmds].
  external SkPath MakeFromCmds(List<dynamic> pathCommands);

  /// Creates an [SkPath] by combining [path1] and [path2] using [pathOp].
  external SkPath MakeFromOp(SkPath path1, SkPath path2, SkPathOp pathOp);
}

/// Converts a 4x4 Flutter matrix (represented as a [Float32List] in
/// column major order) to an SkM44 which is a 4x4 matrix represented
/// as a [Float32List] in row major order.
Float32List toSkM44FromFloat32(Float32List matrix4) {
  final Float32List skM44 = Float32List(16);
  for (int r = 0; r < 4; r++) {
    for (int c = 0; c < 4; c++) {
      skM44[c * 4 + r] = matrix4[r * 4 + c];
    }
  }
  return skM44;
}

// Mappings from SkMatrix-index to input-index.
const List<int> _skMatrixIndexToMatrix4Index = <int>[
  0, 4, 12, // Row 1
  1, 5, 13, // Row 2
  3, 7, 15, // Row 3
];

/// Converts a 4x4 Flutter matrix (represented as a [Float32List]) to an
/// SkMatrix, which is a 3x3 transform matrix.
Float32List toSkMatrixFromFloat32(Float32List matrix4) {
  final Float32List skMatrix = Float32List(9);
  for (int i = 0; i < 9; ++i) {
    final int matrix4Index = _skMatrixIndexToMatrix4Index[i];
    if (matrix4Index < matrix4.length)
      skMatrix[i] = matrix4[matrix4Index];
    else
      skMatrix[i] = 0.0;
  }
  return skMatrix;
}

/// Converts a 4x4 Flutter matrix (represented as a [Float32List]) to an
/// SkMatrix, which is a 3x3 transform matrix.
Float32List toSkMatrixFromFloat64(Float64List matrix4) {
  final Float32List skMatrix = Float32List(9);
  for (int i = 0; i < 9; ++i) {
    final int matrix4Index = _skMatrixIndexToMatrix4Index[i];
    if (matrix4Index < matrix4.length)
      skMatrix[i] = matrix4[matrix4Index];
    else
      skMatrix[i] = 0.0;
  }
  return skMatrix;
}

/// Converts an [offset] into an `[x, y]` pair stored in a `Float32List`.
///
/// The returned list can be passed to CanvasKit API that take points.
Float32List toSkPoint(ui.Offset offset) {
  final Float32List point = Float32List(2);
  point[0] = offset.dx;
  point[1] = offset.dy;
  return point;
}

/// Color stops used when the framework specifies `null`.
final Float32List _kDefaultSkColorStops = Float32List(2)
  ..[0] = 0
  ..[1] = 1;

/// Converts a list of color stops into a Skia-compatible JS array or color stops.
///
/// In Flutter `null` means two color stops `[0, 1]` that in Skia must be specified explicitly.
Float32List toSkColorStops(List<double>? colorStops) {
  if (colorStops == null) {
    return _kDefaultSkColorStops;
  }

  final int len = colorStops.length;
  final Float32List skColorStops = Float32List(len);
  for (int i = 0; i < len; i++) {
    skColorStops[i] = colorStops[i];
  }
  return skColorStops;
}

@JS('Float32Array')
external _NativeFloat32ArrayType get _nativeFloat32ArrayType;

@JS()
class _NativeFloat32ArrayType {}

@JS('window.flutterCanvasKit.Malloc')
external SkFloat32List _mallocFloat32List(
  _NativeFloat32ArrayType float32ListType,
  int size,
);

/// Allocates a [Float32List] backed by WASM memory, managed by
/// a [SkFloat32List].
///
/// To free the allocated array use [freeFloat32List].
SkFloat32List mallocFloat32List(int size) {
  return _mallocFloat32List(_nativeFloat32ArrayType, size);
}

/// Frees the WASM memory occupied by a [SkFloat32List].
///
/// The [list] is no longer usable after calling this function.
///
/// Use this function to free lists owned by the engine.
@JS('window.flutterCanvasKit.Free')
external void freeFloat32List(SkFloat32List list);

/// Wraps a [Float32List] backed by WASM memory.
///
/// This wrapper is necessary because the raw [Float32List] will get detached
/// when WASM grows its memory. Call [toTypedArray] to get a new instance
/// that's attached to the current WASM memory block.
@JS()
class SkFloat32List {
  /// Returns the [Float32List] object backed by WASM memory.
  ///
  /// Do not reuse the returned list across multiple WASM function/method
  /// invocations that may lead to WASM memory to grow. When WASM memory
  /// grows the [Float32List] object becomes "detached" and is no longer
  /// usable. Instead, call this method every time you need to read from
  /// or write to the list.
  external Float32List toTypedArray();
}

/// Writes [color] information into the given [skColor] buffer.
Float32List _populateSkColor(SkFloat32List skColor, ui.Color color) {
  final Float32List array = skColor.toTypedArray();
  array[0] = color.red / 255.0;
  array[1] = color.green / 255.0;
  array[2] = color.blue / 255.0;
  array[3] = color.alpha / 255.0;
  return array;
}

/// Unpacks the [color] into CanvasKit-compatible representation stored
/// in a shared memory location #1.
///
/// Use this only for passing transient data to CanvasKit. Because the
/// memory is shared the value will not persist.
Float32List toSharedSkColor1(ui.Color color) {
  return _populateSkColor(_sharedSkColor1, color);
}

final SkFloat32List _sharedSkColor1 = mallocFloat32List(4);

/// Unpacks the [color] into CanvasKit-compatible representation stored
/// in a shared memory location #2.
///
/// Use this only for passing transient data to CanvasKit. Because the
/// memory is shared the value will not persist.
Float32List toSharedSkColor2(ui.Color color) {
  return _populateSkColor(_sharedSkColor2, color);
}

final SkFloat32List _sharedSkColor2 = mallocFloat32List(4);

/// Unpacks the [color] into CanvasKit-compatible representation stored
/// in a shared memory location #3.
///
/// Use this only for passing transient data to CanvasKit. Because the
/// memory is shared the value will not persist.
Float32List toSharedSkColor3(ui.Color color) {
  return _populateSkColor(_sharedSkColor3, color);
}

final SkFloat32List _sharedSkColor3 = mallocFloat32List(4);

@JS('window.flutterCanvasKit.Path')
class SkPath {
  external SkPath([SkPath? other]);
  external void setFillType(SkFillType fillType);
  external void addArc(
    Float32List oval,
    double startAngleDegrees,
    double sweepAngleDegrees,
  );
  external void addOval(
    Float32List oval,
    bool counterClockWise,
    int startIndex,
  );
  external void addPath(
    SkPath other,
    double scaleX,
    double skewX,
    double transX,
    double skewY,
    double scaleY,
    double transY,
    double pers0,
    double pers1,
    double pers2,
    bool extendPath,
  );
  external void addPoly(
    Float32List points,
    bool close,
  );
  external void addRRect(
    Float32List rrect,
    bool counterClockWise,
  );
  external void addRect(
    Float32List rect,
  );
  external void arcToOval(
    Float32List oval,
    double startAngleDegrees,
    double sweepAngleDegrees,
    bool forceMoveTo,
  );
  external void arcToRotated(
    double radiusX,
    double radiusY,
    double rotation,
    bool useSmallArc,
    bool counterClockWise,
    double x,
    double y,
  );
  external void close();
  external void conicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double w,
  );
  external bool contains(
    double x,
    double y,
  );
  external void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  );
  external Float32List getBounds();
  external void lineTo(double x, double y);
  external void moveTo(double x, double y);
  external void quadTo(
    double x1,
    double y1,
    double x2,
    double y2,
  );
  external void rArcTo(
    double x,
    double y,
    double rotation,
    bool useSmallArc,
    bool counterClockWise,
    double deltaX,
    double deltaY,
  );
  external void rConicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double w,
  );
  external void rCubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  );
  external void rLineTo(double x, double y);
  external void rMoveTo(double x, double y);
  external void rQuadTo(
    double x1,
    double y1,
    double x2,
    double y2,
  );
  external void reset();
  external String toSVGString();
  external bool isEmpty();
  external SkPath copy();
  external void transform(
    double scaleX,
    double skewX,
    double transX,
    double skewY,
    double scaleY,
    double transY,
    double pers0,
    double pers1,
    double pers2,
  );

  /// Serializes the path into a list of commands.
  ///
  /// The list can be used to create a new [SkPath] using
  /// [CanvasKit.Path.MakeFromCmds].
  external List<dynamic> toCmds();

  external void delete();
}

@JS('window.flutterCanvasKit.ContourMeasureIter')
class SkContourMeasureIter {
  external SkContourMeasureIter(SkPath path, bool forceClosed, double resScale);
  external SkContourMeasure? next();
  external void delete();
}

@JS()
class SkContourMeasure {
  external SkPath getSegment(double start, double end, bool startWithMoveTo);
  external Float32List getPosTan(double distance);
  external bool isClosed();
  external double length();
  external void delete();
}

// TODO(hterkelsen): Use a shared malloc'ed array for performance.
Float32List toSkRect(ui.Rect rect) {
  final Float32List skRect = Float32List(4);
  skRect[0] = rect.left;
  skRect[1] = rect.top;
  skRect[2] = rect.right;
  skRect[3] = rect.bottom;
  return skRect;
}

ui.Rect fromSkRect(Float32List skRect) {
  return ui.Rect.fromLTRB(skRect[0], skRect[1], skRect[2], skRect[3]);
}

// TODO(hterkelsen): Use a shared malloc'ed array for performance.
Float32List toSkRRect(ui.RRect rrect) {
  final Float32List skRRect = Float32List(12);
  skRRect[0] = rrect.left;
  skRRect[1] = rrect.top;
  skRRect[2] = rrect.right;
  skRRect[3] = rrect.bottom;
  skRRect[4] = rrect.tlRadiusX;
  skRRect[5] = rrect.tlRadiusY;
  skRRect[6] = rrect.trRadiusX;
  skRRect[7] = rrect.trRadiusY;
  skRRect[8] = rrect.brRadiusX;
  skRRect[9] = rrect.brRadiusY;
  skRRect[10] = rrect.blRadiusX;
  skRRect[11] = rrect.blRadiusY;
  return skRRect;
}

// TODO(hterkelsen): Use a shared malloc'ed array for performance.
Float32List toOuterSkRect(ui.RRect rrect) {
  final Float32List skRect = Float32List(4);
  skRect[0] = rrect.left;
  skRect[1] = rrect.top;
  skRect[2] = rrect.right;
  skRect[3] = rrect.bottom;
  return skRect;
}

/// Encodes a list of offsets to CanvasKit-compatible point array.
///
/// Uses `CanvasKit.Malloc` to allocate storage for the points in the WASM
/// memory to avoid unnecessary copying. Unless CanvasKit takes ownership of
/// the list the returned list must be explicitly freed using
/// [freeMallocedFloat32List].
SkFloat32List toMallocedSkPoints(List<ui.Offset> points) {
  final int len = points.length;
  final SkFloat32List skPoints = mallocFloat32List(len * 2);
  final Float32List list = skPoints.toTypedArray();
  for (int i = 0; i < len; i++) {
    list[2 * i] = points[i].dx;
    list[2 * i + 1] = points[i].dy;
  }
  return skPoints;
}

/// Converts a list of [ui.Offset] into a flat list of points.
Float32List toFlatSkPoints(List<ui.Offset> points) {
  final int len = points.length;
  final Float32List result = Float32List(len * 2);
  for (int i = 0; i < len; i++) {
    result[2 * i] = points[i].dx;
    result[2 * i + 1] = points[i].dy;
  }
  return result;
}

/// Converts a list of [ui.Color] into a flat list of ints.
Uint32List toFlatColors(List<ui.Color> colors) {
  final int len = colors.length;
  final Uint32List result = Uint32List(len);
  for (int i = 0; i < len; i++) {
    result[i] = colors[i].value;
  }
  return result;
}

Uint16List toUint16List(List<int> ints) {
  final int len = ints.length;
  final Uint16List result = Uint16List(len);
  for (int i = 0; i < len; i++) {
    result[i] = ints[i];
  }
  return result;
}

@JS('window.flutterCanvasKit.PictureRecorder')
class SkPictureRecorder {
  external SkPictureRecorder();
  external SkCanvas beginRecording(Float32List bounds);
  external SkPicture finishRecordingAsPicture();
  external void delete();
}

/// We do not use the `delete` method (which may be removed in the future anyway).
///
/// By Skia coding convention raw pointers should always be treated as
/// "borrowed", i.e. their memory is managed by other objects. In the case of
/// [SkCanvas] it is managed by [SkPictureRecorder].
@JS()
@anonymous
class SkCanvas {
  external void clear(Float32List color);
  external void clipPath(
    SkPath path,
    SkClipOp clipOp,
    bool doAntiAlias,
  );
  external void clipRRect(
    Float32List rrect,
    SkClipOp clipOp,
    bool doAntiAlias,
  );
  external void clipRect(
    Float32List rrect,
    SkClipOp clipOp,
    bool doAntiAlias,
  );
  external void drawArc(
    Float32List oval,
    double startAngleDegrees,
    double sweepAngleDegrees,
    bool useCenter,
    SkPaint paint,
  );
  external void drawAtlas(
    SkImage image,
    Float32List rects,
    Float32List rstTransforms,
    SkPaint paint,
    SkBlendMode blendMode,
    Uint32List? colors,
  );
  external void drawCircle(
    double x,
    double y,
    double radius,
    SkPaint paint,
  );
  external void drawColorInt(
    int color,
    SkBlendMode blendMode,
  );
  external void drawDRRect(
    Float32List outer,
    Float32List inner,
    SkPaint paint,
  );
  external void drawImageCubic(
    SkImage image,
    double x,
    double y,
    double B,
    double C,
    SkPaint paint,
  );
  external void drawImageOptions(
    SkImage image,
    double x,
    double y,
    SkFilterMode filterMode,
    SkMipmapMode mipmapMode,
    SkPaint paint,
  );
  external void drawImageRectCubic(
    SkImage image,
    Float32List src,
    Float32List dst,
    double B,
    double C,
    SkPaint paint,
  );
  external void drawImageRectOptions(
    SkImage image,
    Float32List src,
    Float32List dst,
    SkFilterMode filterMode,
    SkMipmapMode mipmapMode,
    SkPaint paint,
  );
  external void drawImageNine(
    SkImage image,
    Float32List center,
    Float32List dst,
    SkFilterMode filterMode,
    SkPaint paint,
  );
  external void drawLine(
    double x1,
    double y1,
    double x2,
    double y2,
    SkPaint paint,
  );
  external void drawOval(
    Float32List rect,
    SkPaint paint,
  );
  external void drawPaint(
    SkPaint paint,
  );
  external void drawPath(
    SkPath path,
    SkPaint paint,
  );
  external void drawPoints(
    SkPointMode pointMode,
    Float32List points,
    SkPaint paint,
  );
  external void drawRRect(
    Float32List rrect,
    SkPaint paint,
  );
  external void drawRect(
    Float32List rrect,
    SkPaint paint,
  );
  external void drawShadow(
    SkPath path,
    Float32List zPlaneParams,
    Float32List lightPos,
    double lightRadius,
    Float32List ambientColor,
    Float32List spotColor,
    int flags,
  );
  external void drawVertices(
    SkVertices vertices,
    SkBlendMode blendMode,
    SkPaint paint,
  );
  external int save();
  external int getSaveCount();
  external void saveLayer(
    SkPaint? paint,
    Float32List? bounds,
    SkImageFilter? backdrop,
    int? flags,
  );
  external void restore();
  external void restoreToCount(int count);
  external void rotate(
    double angleDegrees,
    double px,
    double py,
  );
  external void scale(double x, double y);
  external void skew(double x, double y);
  external void concat(Float32List matrix);
  external void translate(double x, double y);
  external void drawPicture(SkPicture picture);
  external void drawParagraph(
    SkParagraph paragraph,
    double x,
    double y,
  );
}

@JS()
@anonymous
class SkPicture {
  external void delete();
}

@JS()
@anonymous
class SkParagraphBuilderNamespace {
  external SkParagraphBuilder Make(
    SkParagraphStyle paragraphStyle,
    SkFontMgr? fontManager,
  );

  external SkParagraphBuilder MakeFromFontProvider(
    SkParagraphStyle paragraphStyle,
    TypefaceFontProvider? fontManager,
  );
}

@JS()
@anonymous
class SkParagraphBuilder {
  external void addText(String text);
  external void pushStyle(SkTextStyle textStyle);
  external void pushPaintStyle(
      SkTextStyle textStyle, SkPaint foreground, SkPaint background);
  external void pop();
  external void addPlaceholder(
    double width,
    double height,
    SkPlaceholderAlignment alignment,
    SkTextBaseline baseline,
    double offset,
  );
  external SkParagraph build();
  external void delete();
}

@JS()
@anonymous
class SkParagraphStyle {}

@JS()
@anonymous
class SkParagraphStyleProperties {
  external set textAlign(SkTextAlign? value);
  external set textDirection(SkTextDirection? value);
  external set heightMultiplier(double? value);
  external set textHeightBehavior(SkTextHeightBehavior? value);
  external set maxLines(int? value);
  external set ellipsis(String? value);
  external set textStyle(SkTextStyleProperties? value);
  external set strutStyle(SkStrutStyleProperties? strutStyle);
}

@JS()
class SkTextStyle {}

@JS()
class SkTextDecorationStyleEnum {
  external SkTextDecorationStyle get Solid;
  external SkTextDecorationStyle get Double;
  external SkTextDecorationStyle get Dotted;
  external SkTextDecorationStyle get Dashed;
  external SkTextDecorationStyle get Wavy;
}

@JS()
class SkTextDecorationStyle {
  external int get value;
}

final List<SkTextDecorationStyle> _skTextDecorationStyles =
    <SkTextDecorationStyle>[
  canvasKit.DecorationStyle.Solid,
  canvasKit.DecorationStyle.Double,
  canvasKit.DecorationStyle.Dotted,
  canvasKit.DecorationStyle.Dashed,
  canvasKit.DecorationStyle.Wavy,
];

SkTextDecorationStyle toSkTextDecorationStyle(ui.TextDecorationStyle style) {
  return _skTextDecorationStyles[style.index];
}

@JS()
class SkTextBaselineEnum {
  external SkTextBaseline get Alphabetic;
  external SkTextBaseline get Ideographic;
}

@JS()
class SkTextBaseline {
  external int get value;
}

final List<SkTextBaseline> _skTextBaselines = <SkTextBaseline>[
  canvasKit.TextBaseline.Alphabetic,
  canvasKit.TextBaseline.Ideographic,
];

SkTextBaseline toSkTextBaseline(ui.TextBaseline baseline) {
  return _skTextBaselines[baseline.index];
}

@JS()
class SkPlaceholderAlignmentEnum {
  external SkPlaceholderAlignment get Baseline;
  external SkPlaceholderAlignment get AboveBaseline;
  external SkPlaceholderAlignment get BelowBaseline;
  external SkPlaceholderAlignment get Top;
  external SkPlaceholderAlignment get Bottom;
  external SkPlaceholderAlignment get Middle;
}

@JS()
class SkPlaceholderAlignment {
  external int get value;
}

final List<SkPlaceholderAlignment> _skPlaceholderAlignments =
    <SkPlaceholderAlignment>[
  canvasKit.PlaceholderAlignment.Baseline,
  canvasKit.PlaceholderAlignment.AboveBaseline,
  canvasKit.PlaceholderAlignment.BelowBaseline,
  canvasKit.PlaceholderAlignment.Top,
  canvasKit.PlaceholderAlignment.Bottom,
  canvasKit.PlaceholderAlignment.Middle,
];

SkPlaceholderAlignment toSkPlaceholderAlignment(
    ui.PlaceholderAlignment alignment) {
  return _skPlaceholderAlignments[alignment.index];
}

@JS()
@anonymous
class SkTextStyleProperties {
  external set backgroundColor(Float32List? value);
  external set color(Float32List? value);
  external set foregroundColor(Float32List? value);
  external set decoration(int? value);
  external set decorationThickness(double? value);
  external set decorationColor(Float32List? value);
  external set decorationStyle(SkTextDecorationStyle? value);
  external set textBaseline(SkTextBaseline? value);
  external set fontSize(double? value);
  external set letterSpacing(double? value);
  external set wordSpacing(double? value);
  external set heightMultiplier(double? value);
  external set halfLeading(bool? value);
  external set locale(String? value);
  external set fontFamilies(List<String>? value);
  external set fontStyle(SkFontStyle? value);
  external set shadows(List<SkTextShadow>? value);
  external set fontFeatures(List<SkFontFeature>? value);
}

@JS()
@anonymous
class SkStrutStyleProperties {
  external set fontFamilies(List<String>? value);
  external set fontStyle(SkFontStyle? value);
  external set fontSize(double? value);
  external set heightMultiplier(double? value);
  external set halfLeading(bool? value);
  external set leading(double? value);
  external set strutEnabled(bool? value);
  external set forceStrutHeight(bool? value);
}

@JS()
@anonymous
class SkFontStyle {
  external set weight(SkFontWeight? value);
  external set slant(SkFontSlant? value);
}

@JS()
@anonymous
class SkTextShadow {
  external set color(Float32List? value);
  external set offset(Float32List? value);
  external set blurRadius(double? value);
}

@JS()
@anonymous
class SkFontFeature {
  external set name(String? value);
  external set value(int? value);
}

@JS()
@anonymous
class SkTypeface {}

@JS('window.flutterCanvasKit.Font')
class SkFont {
  external SkFont(SkTypeface typeface);
  external Uint8List getGlyphIDs(String text);
  external void getGlyphBounds(
      List<int> glyphs, SkPaint? paint, Uint8List? output);
}

@JS()
@anonymous
class SkFontMgr {
  external String? getFamilyName(int fontId);
  external void delete();
  external SkTypeface? MakeTypefaceFromData(Uint8List font);
}

@JS('window.flutterCanvasKit.TypefaceFontProvider')
class TypefaceFontProvider extends SkFontMgr {
  external TypefaceFontProvider();
  external void registerFont(Uint8List font, String family);
}

@JS()
@anonymous
class SkLineMetrics {
  external int get startIndex;
  external int get endIndex;
  external int get endExcludingWhitespaces;
  external int get endIncludingNewline;
  external bool get isHardBreak;
  external double get ascent;
  external double get descent;
  external double get height;
  external double get width;
  external double get left;
  external double get baseline;
  external int get lineNumber;
}

@JS()
@anonymous
class SkParagraph {
  external double getAlphabeticBaseline();
  external bool didExceedMaxLines();
  external double getHeight();
  external double getIdeographicBaseline();
  external List<SkLineMetrics> getLineMetrics();
  external double getLongestLine();
  external double getMaxIntrinsicWidth();
  external double getMinIntrinsicWidth();
  external double getMaxWidth();
  external List<Float32List> getRectsForRange(
    int start,
    int end,
    SkRectHeightStyle heightStyle,
    SkRectWidthStyle widthStyle,
  );
  external List<dynamic> getRectsForPlaceholders();
  external SkTextPosition getGlyphPositionAtCoordinate(
    double x,
    double y,
  );
  external SkTextRange getWordBoundary(int position);
  external void layout(double width);
  external void delete();
}

@JS()
class SkTextPosition {
  external SkAffinity get affinity;
  external int get pos;
}

@JS()
class SkTextRange {
  external int get start;
  external int get end;
}

@JS()
@anonymous
class SkVertices {
  external void delete();
}

@JS()
@anonymous
class SkTonalColors {
  external factory SkTonalColors({
    required Float32List ambient,
    required Float32List spot,
  });
  external Float32List get ambient;
  external Float32List get spot;
}

@JS()
class SkFontMgrNamespace {
  // TODO(yjbanov): can this be made non-null? It returns null in our unit-tests right now.
  external SkFontMgr? FromData(List<Uint8List> fonts);
}

@JS()
class TypefaceFontProviderNamespace {
  external TypefaceFontProvider Make();
}

@JS()
@anonymous
class SkTypefaceFactory {
  external SkTypeface? MakeFreeTypeFaceFromData(ByteBuffer fontData);
}

/// Collects Skia objects that are no longer necessary.
abstract class Collector {
  /// The production collector implementation.
  static final Collector _productionInstance = ProductionCollector();

  /// The collector implementation currently in use.
  static Collector get instance => _instance;
  static Collector _instance = _productionInstance;

  /// In tests overrides the collector implementation.
  static void debugOverrideCollector(Collector override) {
    _instance = override;
  }

  /// In tests restores the collector to the production implementation.
  static void debugRestoreCollector() {
    _instance = _productionInstance;
  }

  /// Registers a [deletable] for collection when the [wrapper] object is
  /// garbage collected.
  ///
  /// The [debugLabel] is used to track the origin of the deletable.
  void register(Object wrapper, SkDeletable deletable);

  /// Deletes the [deletable].
  ///
  /// The exact timing of the deletion is implementation-specific. For example,
  /// a production implementation may want to batch deletables and schedule a
  /// timer to collect them instead of deleting right away.
  ///
  /// A test implementation may want a collection strategy that's less efficient
  /// but more predictable.
  void collect(SkDeletable deletable);
}

/// Uses the browser's real `FinalizationRegistry` to collect objects.
///
/// Uses timers to delete objects in batches and outside the animation frame.
class ProductionCollector implements Collector {
  ProductionCollector() {
    _skObjectFinalizationRegistry =
        SkObjectFinalizationRegistry(js.allowInterop((SkDeletable deletable) {
      // This is called when GC decides to collect the wrapper object and
      // notify us, which may happen after the object is already deleted
      // explicitly, e.g. when its ref count drops to zero. When that happens
      // skip collection of this object.
      if (!deletable.isDeleted()) {
        collect(deletable);
      }
    }));
  }

  late final SkObjectFinalizationRegistry _skObjectFinalizationRegistry;
  List<SkDeletable> _skiaObjectCollectionQueue = <SkDeletable>[];
  Timer? _skiaObjectCollectionTimer;

  @override
  void register(Object wrapper, SkDeletable deletable) {
    if (Instrumentation.enabled) {
      Instrumentation.instance.incrementCounter(
        '${deletable.constructor.name} registered',
      );
    }
    _skObjectFinalizationRegistry.register(wrapper, deletable);
  }

  /// Schedules a Skia object for deletion in an asap timer.
  ///
  /// A timer is used for the following reasons:
  ///
  ///  - Deleting the object immediately may lead to dangling pointer as the Skia
  ///    object may still be used by a function in the current frame. For example,
  ///    a `CkPaint` + `SkPaint` pair may be created by the framework, passed to
  ///    the engine, and the `CkPaint` dropped immediately. Because GC can kick in
  ///    any time, including in the middle of the event, we may delete `SkPaint`
  ///    prematurely.
  ///  - A microtask, while solves the problem above, would prevent the event from
  ///    yielding to the graphics system to render the frame on the screen if there
  ///    is a large number of objects to delete, causing jank.
  ///
  /// Because scheduling a timer is expensive, the timer is shared by all objects
  /// deleted this frame. No timer is created if no objects were scheduled for
  /// deletion.
  @override
  void collect(SkDeletable deletable) {
    assert(
      !deletable.isDeleted(),
      'Attempted to delete an already deleted Skia object.',
    );
    _skiaObjectCollectionQueue.add(deletable);

    _skiaObjectCollectionTimer ??= Timer(Duration.zero, () {
      // Null out the timer so we can schedule a new one next time objects are
      // scheduled for deletion.
      _skiaObjectCollectionTimer = null;
      collectSkiaObjectsNow();
    });
  }

  /// Deletes all Skia objects pending deletion synchronously.
  ///
  /// After calling this method [_skiaObjectCollectionQueue] is empty.
  ///
  /// Throws a [SkiaObjectCollectionError] if CanvasKit fails to delete at least
  /// one object. The error is populated with information about the first failed
  /// object. Upon an error the collection continues and the collection queue is
  /// emptied out to prevent memory leaks. This may happen, for example, when the
  /// same object is deleted more than once.
  void collectSkiaObjectsNow() {
    html.window.performance.mark('SkObject collection-start');
    final int length = _skiaObjectCollectionQueue.length;
    dynamic firstError;
    StackTrace? firstStackTrace;
    for (int i = 0; i < length; i++) {
      final SkDeletable deletable = _skiaObjectCollectionQueue[i];
      if (deletable.isDeleted()) {
        // Some Skia objects are ref counted and are deleted before GC and/or
        // the collection timer begins collecting them. So we have to check
        // again if the objects is worth collecting.
        continue;
      }
      if (Instrumentation.enabled) {
        Instrumentation.instance.incrementCounter(
          '${deletable.constructor.name} deleted',
        );
      }
      try {
        deletable.delete();
      } catch (error, stackTrace) {
        // Remember the error, but keep going. If for some reason CanvasKit fails
        // to delete an object we still want to delete other objects and empty
        // out the queue. Otherwise, the queue will never be flushed and keep
        // accumulating objects, a.k.a. memory leak.
        if (firstError == null) {
          firstError = error;
          firstStackTrace = stackTrace;
        }
      }
    }
    _skiaObjectCollectionQueue = <SkDeletable>[];

    html.window.performance.mark('SkObject collection-end');
    html.window.performance.measure('SkObject collection',
        'SkObject collection-start', 'SkObject collection-end');

    // It's safe to throw the error here, now that we've processed the queue.
    if (firstError != null) {
      throw SkiaObjectCollectionError(firstError, firstStackTrace);
    }
  }
}

/// Thrown by [ProductionCollector] when Skia object collection fails.
class SkiaObjectCollectionError implements Error {
  SkiaObjectCollectionError(this.error, this.stackTrace);

  final dynamic error;

  @override
  final StackTrace? stackTrace;

  @override
  String toString() => 'SkiaObjectCollectionError: $error\n$stackTrace';
}

/// Any Skia object that has a `delete` method.
@JS()
@anonymous
class SkDeletable {
  /// Deletes the C++ side object.
  external void delete();

  /// Returns whether the correcponding C++ object has been deleted.
  external bool isDeleted();

  /// Returns the JavaScript constructor for this object.
  ///
  /// This is useful for debugging.
  external JsConstructor get constructor;
}

@JS()
@anonymous
class JsConstructor {
  /// The name of the "constructor", typically the function name called with
  /// the `new` keyword, or the ES6 class name.
  ///
  /// This is useful for debugging.
  external String get name;
}

/// Attaches a weakly referenced object to another object and calls a finalizer
/// with the latter when weakly referenced object is garbage collected.
///
/// We use this to delete Skia objects when their "Ck" wrapper is garbage
/// collected.
///
/// Example sequence of events:
///
/// 1. A (CkPaint, SkPaint) pair created.
/// 2. The paint is used to paint some picture.
/// 3. CkPaint is dropped by the app.
/// 4. GC decides to perform a GC cycle and collects CkPaint.
/// 5. The finalizer function is called with the SkPaint as the sole argument.
/// 6. We call `delete` on SkPaint.
@JS('window.FinalizationRegistry')
class SkObjectFinalizationRegistry {
  // TODO(hterkelsen): Add a type for the `cleanup` function when
  // native constructors support type parameters.
  external SkObjectFinalizationRegistry(Function cleanup);
  external void register(Object ckObject, Object skObject);
}

@JS('window.FinalizationRegistry')
external Object? get _finalizationRegistryConstructor;

/// Whether the current browser supports `FinalizationRegistry`.
bool browserSupportsFinalizationRegistry =
    _finalizationRegistryConstructor != null;

/// Sets the value of [browserSupportsFinalizationRegistry] to its true value.
void debugResetBrowserSupportsFinalizationRegistry() {
  browserSupportsFinalizationRegistry =
      _finalizationRegistryConstructor != null;
}

@JS()
class SkData {
  external int size();
  external bool isEmpty();
  external Uint8List bytes();
  external void delete();
}

@JS()
@anonymous
class SkImageInfo {
  external factory SkImageInfo({
    required int width,
    required int height,
    required SkColorType colorType,
    required SkAlphaType alphaType,
    required ColorSpace colorSpace,
  });
  external SkAlphaType get alphaType;
  external ColorSpace get colorSpace;
  external SkColorType get colorType;
  external int get height;
  external bool get isEmpty;
  external bool get isOpaque;
  external Float32List get bounds;
  external int get width;
  external SkImageInfo makeAlphaType(SkAlphaType alphaType);
  external SkImageInfo makeColorSpace(ColorSpace colorSpace);
  external SkImageInfo makeColorType(SkColorType colorType);
  external SkImageInfo makeWH(int width, int height);
}

@JS()
@anonymous
class SkPartialImageInfo {
  external factory SkPartialImageInfo({
    required int width,
    required int height,
    required SkColorType colorType,
    required SkAlphaType alphaType,
    required ColorSpace colorSpace,
  });
  external SkAlphaType get alphaType;
  external ColorSpace get colorSpace;
  external SkColorType get colorType;
  external int get height;
  external int get width;
}
