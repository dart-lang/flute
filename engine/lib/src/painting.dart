// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.



part of dart.ui;

bool _rectIsValid(Rect rect) {
  assert(rect != null, 'Rect argument was null.'); // ignore: unnecessary_null_comparison
  assert(!rect.hasNaN, 'Rect argument contained a NaN value.');
  return true;
}

bool _rrectIsValid(RRect rrect) {
  assert(rrect != null, 'RRect argument was null.'); // ignore: unnecessary_null_comparison
  assert(!rrect.hasNaN, 'RRect argument contained a NaN value.');
  return true;
}

bool _offsetIsValid(Offset offset) {
  assert(offset != null, 'Offset argument was null.'); // ignore: unnecessary_null_comparison
  assert(!offset.dx.isNaN && !offset.dy.isNaN, 'Offset argument contained a NaN value.');
  return true;
}

bool _matrix4IsValid(Float64List matrix4) {
  assert(matrix4 != null, 'Matrix4 argument was null.'); // ignore: unnecessary_null_comparison
  assert(matrix4.length == 16, 'Matrix4 must have 16 entries.');
  assert(matrix4.every((double value) => value.isFinite), 'Matrix4 entries must be finite.');
  return true;
}

bool _radiusIsValid(Radius radius) {
  assert(radius != null, 'Radius argument was null.'); // ignore: unnecessary_null_comparison
  assert(!radius.x.isNaN && !radius.y.isNaN, 'Radius argument contained a NaN value.');
  return true;
}

Color _scaleAlpha(Color a, double factor) {
  return a.withAlpha((a.alpha * factor).round().clamp(0, 255));
}
class Color {
    const Color(int value) : value = value & 0xFFFFFFFF;
  const Color.fromARGB(int a, int r, int g, int b) :
    value = (((a & 0xff) << 24) |
             ((r & 0xff) << 16) |
             ((g & 0xff) << 8)  |
             ((b & 0xff) << 0)) & 0xFFFFFFFF;
  const Color.fromRGBO(int r, int g, int b, double opacity) :
    value = ((((opacity * 0xff ~/ 1) & 0xff) << 24) |
              ((r                    & 0xff) << 16) |
              ((g                    & 0xff) << 8)  |
              ((b                    & 0xff) << 0)) & 0xFFFFFFFF;
  final int value;
  int get alpha => (0xff000000 & value) >> 24;
  double get opacity => alpha / 0xFF;
  int get red => (0x00ff0000 & value) >> 16;
  int get green => (0x0000ff00 & value) >> 8;
  int get blue => (0x000000ff & value) >> 0;
  Color withAlpha(int a) {
    return Color.fromARGB(a, red, green, blue);
  }
  Color withOpacity(double opacity) {
    assert(opacity >= 0.0 && opacity <= 1.0);
    return withAlpha((255.0 * opacity).round());
  }
  Color withRed(int r) {
    return Color.fromARGB(alpha, r, green, blue);
  }
  Color withGreen(int g) {
    return Color.fromARGB(alpha, red, g, blue);
  }
  Color withBlue(int b) {
    return Color.fromARGB(alpha, red, green, b);
  }

  // See <https://www.w3.org/TR/WCAG20/#relativeluminancedef>
  static double _linearizeColorComponent(double component) {
    if (component <= 0.03928)
      return component / 12.92;
    return math.pow((component + 0.055) / 1.055, 2.4) as double;
  }
  double computeLuminance() {
    // See <https://www.w3.org/TR/WCAG20/#relativeluminancedef>
    final double R = _linearizeColorComponent(red / 0xFF);
    final double G = _linearizeColorComponent(green / 0xFF);
    final double B = _linearizeColorComponent(blue / 0xFF);
    return 0.2126 * R + 0.7152 * G + 0.0722 * B;
  }
  static Color? lerp(Color? a, Color? b, double t) {
    assert(t != null); // ignore: unnecessary_null_comparison
    if (b == null) {
      if (a == null) {
        return null;
      } else {
        return _scaleAlpha(a, 1.0 - t);
      }
    } else {
      if (a == null) {
        return _scaleAlpha(b, t);
      } else {
        return Color.fromARGB(
          _clampInt(_lerpInt(a.alpha, b.alpha, t).toInt(), 0, 255),
          _clampInt(_lerpInt(a.red, b.red, t).toInt(), 0, 255),
          _clampInt(_lerpInt(a.green, b.green, t).toInt(), 0, 255),
          _clampInt(_lerpInt(a.blue, b.blue, t).toInt(), 0, 255),
        );
      }
    }
  }
  static Color alphaBlend(Color foreground, Color background) {
    final int alpha = foreground.alpha;
    if (alpha == 0x00) { // Foreground completely transparent.
      return background;
    }
    final int invAlpha = 0xff - alpha;
    int backAlpha = background.alpha;
    if (backAlpha == 0xff) { // Opaque background case
      return Color.fromARGB(
        0xff,
        (alpha * foreground.red + invAlpha * background.red) ~/ 0xff,
        (alpha * foreground.green + invAlpha * background.green) ~/ 0xff,
        (alpha * foreground.blue + invAlpha * background.blue) ~/ 0xff,
      );
    } else { // General case
      backAlpha = (backAlpha * invAlpha) ~/ 0xff;
      final int outAlpha = alpha + backAlpha;
      assert(outAlpha != 0x00);
      return Color.fromARGB(
        outAlpha,
        (foreground.red * alpha + background.red * backAlpha) ~/ outAlpha,
        (foreground.green * alpha + background.green * backAlpha) ~/ outAlpha,
        (foreground.blue * alpha + background.blue * backAlpha) ~/ outAlpha,
      );
    }
  }
  static int getAlphaFromOpacity(double opacity) {
    assert(opacity != null); // ignore: unnecessary_null_comparison
    return (_clampDouble(opacity, 0.0, 1.0) * 255).round();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other))
      return true;
    if (other.runtimeType != runtimeType)
      return false;
    return other is Color
        && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Color(0x${value.toRadixString(16).padLeft(8, '0')})';
}
enum BlendMode {
  // This list comes from Skia's SkXfermode.h and the values (order) should be
  // kept in sync.
  // See: https://skia.org/user/api/skpaint#SkXfermode
  clear,
  src,
  dst,
  srcOver,
  dstOver,
  srcIn,
  dstIn,
  srcOut,
  dstOut,
  srcATop,
  dstATop,
  xor,
  plus,
  modulate,

  // Following blend modes are defined in the CSS Compositing standard.
  screen,  // The last coeff mode.
  overlay,
  darken,
  lighten,
  colorDodge,
  colorBurn,
  hardLight,
  softLight,
  difference,
  exclusion,
  multiply,  // The last separable mode.
  hue,
  saturation,
  color,
  luminosity,
}
enum FilterQuality {
  // This list comes from Skia's SkFilterQuality.h and the values (order) should
  // be kept in sync.
  none,
  low,
  medium,
  high,
}
// These enum values must be kept in sync with SkPaint::Cap.
enum StrokeCap {
  butt,
  round,
  square,
}
// These enum values must be kept in sync with SkPaint::Join.
enum StrokeJoin {
  miter,
  round,
  bevel,
}
// These enum values must be kept in sync with SkPaint::Style.
enum PaintingStyle {
  // This list comes from Skia's SkPaint.h and the values (order) should be kept
  // in sync.
  fill,
  stroke,
}
enum Clip {
  none,
  hardEdge,
  antiAlias,
  antiAliasWithSaveLayer,
}
class Paint {
  // Paint objects are encoded in two buffers:
  //
  // * _data is binary data in four-byte fields, each of which is either a
  //   uint32_t or a float. The default value for each field is encoded as
  //   zero to make initialization trivial. Most values already have a default
  //   value of zero, but some, such as color, have a non-zero default value.
  //   To encode or decode these values, XOR the value with the default value.
  //
  // * _objects is a list of unencodable objects, typically wrappers for native
  //   objects. The objects are simply stored in the list without any additional
  //   encoding.
  //
  // The binary format must match the deserialization code in paint.cc.

  final ByteData _data = ByteData(_kDataByteCount);
  static const int _kIsAntiAliasIndex = 0;
  static const int _kColorIndex = 1;
  static const int _kBlendModeIndex = 2;
  static const int _kStyleIndex = 3;
  static const int _kStrokeWidthIndex = 4;
  static const int _kStrokeCapIndex = 5;
  static const int _kStrokeJoinIndex = 6;
  static const int _kStrokeMiterLimitIndex = 7;
  static const int _kFilterQualityIndex = 8;
  static const int _kMaskFilterIndex = 9;
  static const int _kMaskFilterBlurStyleIndex = 10;
  static const int _kMaskFilterSigmaIndex = 11;
  static const int _kInvertColorIndex = 12;
  static const int _kDitherIndex = 13;

  static const int _kIsAntiAliasOffset = _kIsAntiAliasIndex << 2;
  static const int _kColorOffset = _kColorIndex << 2;
  static const int _kBlendModeOffset = _kBlendModeIndex << 2;
  static const int _kStyleOffset = _kStyleIndex << 2;
  static const int _kStrokeWidthOffset = _kStrokeWidthIndex << 2;
  static const int _kStrokeCapOffset = _kStrokeCapIndex << 2;
  static const int _kStrokeJoinOffset = _kStrokeJoinIndex << 2;
  static const int _kStrokeMiterLimitOffset = _kStrokeMiterLimitIndex << 2;
  static const int _kFilterQualityOffset = _kFilterQualityIndex << 2;
  static const int _kMaskFilterOffset = _kMaskFilterIndex << 2;
  static const int _kMaskFilterBlurStyleOffset = _kMaskFilterBlurStyleIndex << 2;
  static const int _kMaskFilterSigmaOffset = _kMaskFilterSigmaIndex << 2;
  static const int _kInvertColorOffset = _kInvertColorIndex << 2;
  static const int _kDitherOffset = _kDitherIndex << 2;
  // If you add more fields, remember to update _kDataByteCount.
  static const int _kDataByteCount = 56;

  // Binary format must match the deserialization code in paint.cc.
  List<dynamic>? _objects;

  List<dynamic> _ensureObjectsInitialized() {
    return _objects ??= List<dynamic>.filled(_kObjectCount, null, growable: false);
  }

  static const int _kShaderIndex = 0;
  static const int _kColorFilterIndex = 1;
  static const int _kImageFilterIndex = 2;
  static const int _kObjectCount = 3; // Must be one larger than the largest index.
  Paint() {
    if (enableDithering) {
      _dither = true;
    }
  }
  bool get isAntiAlias {
    return _data.getInt32(_kIsAntiAliasOffset, _kFakeHostEndian) == 0;
  }
  set isAntiAlias(bool value) {
    // We encode true as zero and false as one because the default value, which
    // we always encode as zero, is true.
    final int encoded = value ? 0 : 1;
    _data.setInt32(_kIsAntiAliasOffset, encoded, _kFakeHostEndian);
  }

  // Must be kept in sync with the default in paint.cc.
  static const int _kColorDefault = 0xFF000000;
  Color get color {
    final int encoded = _data.getInt32(_kColorOffset, _kFakeHostEndian);
    return Color(encoded ^ _kColorDefault);
  }
  set color(Color value) {
    assert(value != null); // ignore: unnecessary_null_comparison
    final int encoded = value.value ^ _kColorDefault;
    _data.setInt32(_kColorOffset, encoded, _kFakeHostEndian);
  }

  // Must be kept in sync with the default in paint.cc.
  static final int _kBlendModeDefault = BlendMode.srcOver.index;
  BlendMode get blendMode {
    final int encoded = _data.getInt32(_kBlendModeOffset, _kFakeHostEndian);
    return BlendMode.values[encoded ^ _kBlendModeDefault];
  }
  set blendMode(BlendMode value) {
    assert(value != null); // ignore: unnecessary_null_comparison
    final int encoded = value.index ^ _kBlendModeDefault;
    _data.setInt32(_kBlendModeOffset, encoded, _kFakeHostEndian);
  }
  PaintingStyle get style {
    return PaintingStyle.values[_data.getInt32(_kStyleOffset, _kFakeHostEndian)];
  }
  set style(PaintingStyle value) {
    assert(value != null); // ignore: unnecessary_null_comparison
    final int encoded = value.index;
    _data.setInt32(_kStyleOffset, encoded, _kFakeHostEndian);
  }
  double get strokeWidth {
    return _data.getFloat32(_kStrokeWidthOffset, _kFakeHostEndian);
  }
  set strokeWidth(double value) {
    assert(value != null); // ignore: unnecessary_null_comparison
    final double encoded = value;
    _data.setFloat32(_kStrokeWidthOffset, encoded, _kFakeHostEndian);
  }
  StrokeCap get strokeCap {
    return StrokeCap.values[_data.getInt32(_kStrokeCapOffset, _kFakeHostEndian)];
  }
  set strokeCap(StrokeCap value) {
    assert(value != null); // ignore: unnecessary_null_comparison
    final int encoded = value.index;
    _data.setInt32(_kStrokeCapOffset, encoded, _kFakeHostEndian);
  }
  StrokeJoin get strokeJoin {
    return StrokeJoin.values[_data.getInt32(_kStrokeJoinOffset, _kFakeHostEndian)];
  }
  set strokeJoin(StrokeJoin value) {
    assert(value != null); // ignore: unnecessary_null_comparison
    final int encoded = value.index;
    _data.setInt32(_kStrokeJoinOffset, encoded, _kFakeHostEndian);
  }

  // Must be kept in sync with the default in paint.cc.
  static const double _kStrokeMiterLimitDefault = 4.0;
  double get strokeMiterLimit {
    return _data.getFloat32(_kStrokeMiterLimitOffset, _kFakeHostEndian);
  }
  set strokeMiterLimit(double value) {
    assert(value != null); // ignore: unnecessary_null_comparison
    final double encoded = value - _kStrokeMiterLimitDefault;
    _data.setFloat32(_kStrokeMiterLimitOffset, encoded, _kFakeHostEndian);
  }
  MaskFilter? get maskFilter {
    switch (_data.getInt32(_kMaskFilterOffset, _kFakeHostEndian)) {
      case MaskFilter._TypeNone:
        return null;
      case MaskFilter._TypeBlur:
        return MaskFilter.blur(
          BlurStyle.values[_data.getInt32(_kMaskFilterBlurStyleOffset, _kFakeHostEndian)],
          _data.getFloat32(_kMaskFilterSigmaOffset, _kFakeHostEndian),
        );
    }
    return null;
  }
  set maskFilter(MaskFilter? value) {
    if (value == null) {
      _data.setInt32(_kMaskFilterOffset, MaskFilter._TypeNone, _kFakeHostEndian);
      _data.setInt32(_kMaskFilterBlurStyleOffset, 0, _kFakeHostEndian);
      _data.setFloat32(_kMaskFilterSigmaOffset, 0.0, _kFakeHostEndian);
    } else {
      // For now we only support one kind of MaskFilter, so we don't need to
      // check what the type is if it's not null.
      _data.setInt32(_kMaskFilterOffset, MaskFilter._TypeBlur, _kFakeHostEndian);
      _data.setInt32(_kMaskFilterBlurStyleOffset, value._style.index, _kFakeHostEndian);
      _data.setFloat32(_kMaskFilterSigmaOffset, value._sigma, _kFakeHostEndian);
    }
  }
  // TODO(ianh): verify that the image drawing methods actually respect this
  FilterQuality get filterQuality {
    return FilterQuality.values[_data.getInt32(_kFilterQualityOffset, _kFakeHostEndian)];
  }
  set filterQuality(FilterQuality value) {
    assert(value != null); // ignore: unnecessary_null_comparison
    final int encoded = value.index;
    _data.setInt32(_kFilterQualityOffset, encoded, _kFakeHostEndian);
  }
  Shader? get shader {
    return _objects?[_kShaderIndex] as Shader?;
  }
  set shader(Shader? value) {
    _ensureObjectsInitialized()[_kShaderIndex] = value;
  }
  ColorFilter? get colorFilter {
    return _objects?[_kColorFilterIndex]?.creator as ColorFilter?;
  }

  set colorFilter(ColorFilter? value) {
    final _ColorFilter? nativeFilter = value?._toNativeColorFilter();
    if (nativeFilter == null) {
      if (_objects != null) {
        _objects![_kColorFilterIndex] = null;
      }
    } else {
      _ensureObjectsInitialized()[_kColorFilterIndex] = nativeFilter;
    }
  }
  ImageFilter? get imageFilter {
    return _objects?[_kImageFilterIndex]?.creator as ImageFilter?;
  }

  set imageFilter(ImageFilter? value) {
    if (value == null) {
      if (_objects != null) {
        _objects![_kImageFilterIndex] = null;
      }
    } else {
      final List<dynamic> objects = _ensureObjectsInitialized();
      if (objects[_kImageFilterIndex]?.creator != value) {
        objects[_kImageFilterIndex] = value._toNativeImageFilter();
      }
    }
  }
  bool get invertColors {
    return _data.getInt32(_kInvertColorOffset, _kFakeHostEndian) == 1;
  }
  set invertColors(bool value) {
    _data.setInt32(_kInvertColorOffset, value ? 1 : 0, _kFakeHostEndian);
  }

  bool get _dither {
    return _data.getInt32(_kDitherOffset, _kFakeHostEndian) == 1;
  }
  set _dither(bool value) {
    _data.setInt32(_kDitherOffset, value ? 1 : 0, _kFakeHostEndian);
  }
  static bool enableDithering = false;

  @override
  String toString() {
    if (const bool.fromEnvironment('dart.vm.product', defaultValue: false)) {
      return super.toString();
    }
    final StringBuffer result = StringBuffer();
    String semicolon = '';
    result.write('Paint(');
    if (style == PaintingStyle.stroke) {
      result.write('$style');
      if (strokeWidth != 0.0)
        result.write(' ${strokeWidth.toStringAsFixed(1)}');
      else
        result.write(' hairline');
      if (strokeCap != StrokeCap.butt)
        result.write(' $strokeCap');
      if (strokeJoin == StrokeJoin.miter) {
        if (strokeMiterLimit != _kStrokeMiterLimitDefault)
          result.write(' $strokeJoin up to ${strokeMiterLimit.toStringAsFixed(1)}');
      } else {
        result.write(' $strokeJoin');
      }
      semicolon = '; ';
    }
    if (isAntiAlias != true) {
      result.write('${semicolon}antialias off');
      semicolon = '; ';
    }
    if (color != const Color(_kColorDefault)) {
      result.write('$semicolon$color');
      semicolon = '; ';
    }
    if (blendMode.index != _kBlendModeDefault) {
      result.write('$semicolon$blendMode');
      semicolon = '; ';
    }
    if (colorFilter != null) {
      result.write('${semicolon}colorFilter: $colorFilter');
      semicolon = '; ';
    }
    if (maskFilter != null) {
      result.write('${semicolon}maskFilter: $maskFilter');
      semicolon = '; ';
    }
    if (filterQuality != FilterQuality.none) {
      result.write('${semicolon}filterQuality: $filterQuality');
      semicolon = '; ';
    }
    if (shader != null) {
      result.write('${semicolon}shader: $shader');
      semicolon = '; ';
    }
    if (imageFilter != null) {
      result.write('${semicolon}imageFilter: $imageFilter');
      semicolon = '; ';
    }
    if (invertColors)
      result.write('${semicolon}invert: $invertColors');
    if (_dither)
      result.write('${semicolon}dither: $_dither');
    result.write(')');
    return result.toString();
  }
}
enum ImageByteFormat {
  rawRgba,
  rawUnmodified,
  png,
}
enum PixelFormat {
  rgba8888,
  bgra8888,
}

typedef ImageEventCallback = void Function(Image image);

class Image {
  Image._(this._image) {
    assert(() {
      _debugStack = StackTrace.current;
      return true;
    }());
    _image._handles.add(this);
  }

  static ImageEventCallback? onCreate;
  static ImageEventCallback? onDispose;

  // C++ unit tests access this.
  final _Image _image;

  StackTrace? _debugStack;
  int get width {
    assert(!_disposed && !_image._disposed);
    return _image.width;
  }
  int get height {
    assert(!_disposed && !_image._disposed);
    return _image.height;
  }

  bool _disposed = false;
  void dispose() {
    assert(!_disposed && !_image._disposed);
    assert(_image._handles.contains(this));
    _disposed = true;
    final bool removed = _image._handles.remove(this);
    assert(removed);
    if (_image._handles.isEmpty) {
      _image.dispose();
    }
  }
  bool get debugDisposed {
    bool? disposed;
    assert(() {
      disposed = _disposed;
      return true;
    }());
    return disposed ?? (throw StateError('Image.debugDisposed is only available when asserts are enabled.'));
  }
  Future<ByteData?> toByteData({ImageByteFormat format = ImageByteFormat.rawRgba}) {
    assert(!_disposed && !_image._disposed);
    return _image.toByteData(format: format);
  }
  List<StackTrace>? debugGetOpenHandleStackTraces() {
    List<StackTrace>? stacks;
    assert(() {
      stacks = _image._handles.map((Image handle) => handle._debugStack!).toList();
      return true;
    }());
    return stacks;
  }
  Image clone() {
    if (_disposed) {
      throw StateError(
        'Cannot clone a disposed image.\n'
        'The clone() method of a previously-disposed Image was called. Once an '
        'Image object has been disposed, it can no longer be used to create '
        'handles, as the underlying data may have been released.'
      );
    }
    assert(!_image._disposed);
    return Image._(_image);
  }
  bool isCloneOf(Image other) => other._image == _image;

  @override
  String toString() => _image.toString();
}

class _Image {
  // This class is created by the engine, and should not be instantiated
  // or extended directly.
  //
  // _Images are always handed out wrapped in [Image]s. To create an [Image],
  // use the ImageDescriptor API.
  _Image._(this.width, this.height);

  final int width;

  final int height;

  Future<ByteData?> toByteData({ImageByteFormat format = ImageByteFormat.rawRgba}) {
    return _futurize((_Callback<ByteData> callback) {
      return _toByteData(format.index, (Uint8List? encoded) {
        callback(encoded!.buffer.asByteData());
      });
    });
  }
  String? _toByteData(int format, _Callback<Uint8List?> callback) { return null; }

  bool _disposed = false;
  void dispose() {
    assert(!_disposed);
    assert(
      _handles.isEmpty,
      'Attempted to dispose of an Image object that has ${_handles.length} '
      'open handles.\n'
      'If you see this, it is a bug in dart:ui. Please file an issue at '
      'https://github.com/flutter/flutter/issues/new.',
    );
    _disposed = true;
    _dispose();
  }

  void _dispose() {}

  Set<Image> _handles = <Image>{};

  @override
  String toString() => '[$width\u00D7$height]';
}
typedef ImageDecoderCallback = void Function(Image result);
class FrameInfo {
  FrameInfo._({required this.duration, required this.image});
  final Duration duration;
  final Image image;
}
class Codec {
  //
  // This class is created by the engine, and should not be instantiated
  // or extended directly.
  //
  // To obtain an instance of the [Codec] interface, see
  // [instantiateImageCodec].
    Codec._();

  int? _cachedFrameCount;
  int get frameCount => _cachedFrameCount ??= _frameCount;
  int get _frameCount { return 1; }

  int? _cachedRepetitionCount;
  int get repetitionCount => _cachedRepetitionCount ??= _repetitionCount;
  int get _repetitionCount { return 1; }
  Future<FrameInfo> getNextFrame() async {
    final Completer<FrameInfo> completer = Completer<FrameInfo>.sync();
    final String? error = _getNextFrame((_Image? image, int durationMilliseconds) {
      if (image == null) {
        throw Exception('Codec failed to produce an image, possibly due to invalid image data.');
      }
      completer.complete(FrameInfo._(
        image: Image._(image),
        duration: Duration(milliseconds: durationMilliseconds),
      ));
    });
    if (error != null) {
      throw Exception(error);
    }
    return completer.future;
  }
  String? _getNextFrame(void Function(_Image?, int) callback) { return null; }
  void dispose() {  }
}
Future<Codec> instantiateImageCodec(
  Uint8List list, {
  int? targetWidth,
  int? targetHeight,
  bool allowUpscaling = true,
}) async {
  final ImmutableBuffer buffer = await ImmutableBuffer.fromUint8List(list);
  final ImageDescriptor descriptor = await ImageDescriptor.encoded(buffer);
  if (!allowUpscaling) {
    if (targetWidth != null && targetWidth > descriptor.width) {
      targetWidth = descriptor.width;
    }
    if (targetHeight != null && targetHeight > descriptor.height) {
      targetHeight = descriptor.height;
    }
  }
  return descriptor.instantiateCodec(
    targetWidth: targetWidth,
    targetHeight: targetHeight,
  );
}
void decodeImageFromList(Uint8List list, ImageDecoderCallback callback) {
  _decodeImageFromListAsync(list, callback);
}

Future<void> _decodeImageFromListAsync(Uint8List list,
                                       ImageDecoderCallback callback) async {
  final Codec codec = await instantiateImageCodec(list);
  final FrameInfo frameInfo = await codec.getNextFrame();
  callback(frameInfo.image);
}
void decodeImageFromPixels(
  Uint8List pixels,
  int width,
  int height,
  PixelFormat format,
  ImageDecoderCallback callback, {
  int? rowBytes,
  int? targetWidth,
  int? targetHeight,
  bool allowUpscaling = true,
}) {
  if (targetWidth != null) {
    assert(allowUpscaling || targetWidth <= width);
  }
  if (targetHeight != null) {
    assert(allowUpscaling || targetHeight <= height);
  }

  ImmutableBuffer.fromUint8List(pixels)
    .then((ImmutableBuffer buffer) {
      final ImageDescriptor descriptor = ImageDescriptor.raw(
        buffer,
        width: width,
        height: height,
        rowBytes: rowBytes,
        pixelFormat: format,
      );

      if (!allowUpscaling) {
        if (targetWidth != null && targetWidth! > descriptor.width) {
          targetWidth = descriptor.width;
        }
        if (targetHeight != null && targetHeight! > descriptor.height) {
          targetHeight = descriptor.height;
        }
      }

      descriptor
        .instantiateCodec(
          targetWidth: targetWidth,
          targetHeight: targetHeight,
        )
        .then((Codec codec) => codec.getNextFrame())
        .then((FrameInfo frameInfo) => callback(frameInfo.image));
  });
}
enum PathFillType {
  nonZero,
  evenOdd,
}
// Must be kept in sync with SkPathOp
enum PathOperation {
  difference,
  intersect,
  union,
  xor,
  reverseDifference,
}

abstract class EngineLayer {
  void dispose();
  bool get debugDisposed;
}

abstract class Path {
  factory Path() => SurfacePath();
  factory Path.from(Path source) => SurfacePath.from(source as SurfacePath);
  PathFillType get fillType;
  set fillType(PathFillType value);
  void moveTo(double x, double y);
  void relativeMoveTo(double dx, double dy);
  void lineTo(double x, double y);
  void relativeLineTo(double dx, double dy);
  void quadraticBezierTo(double x1, double y1, double x2, double y2);
  void relativeQuadraticBezierTo(double x1, double y1, double x2, double y2);
  void cubicTo(double x1, double y1, double x2, double y2, double x3, double y3);
  void relativeCubicTo(double x1, double y1, double x2, double y2, double x3, double y3);
  void conicTo(double x1, double y1, double x2, double y2, double w);
  void relativeConicTo(double x1, double y1, double x2, double y2, double w);
  void arcTo(Rect rect, double startAngle, double sweepAngle, bool forceMoveTo);
  void arcToPoint(
    Offset arcEnd, {
    Radius radius = Radius.zero,
    double rotation = 0.0,
    bool largeArc = false,
    bool clockwise = true,
  });
  void relativeArcToPoint(
    Offset arcEndDelta, {
    Radius radius = Radius.zero,
    double rotation = 0.0,
    bool largeArc = false,
    bool clockwise = true,
  });
  void addRect(Rect rect);
  void addOval(Rect oval);
  void addArc(Rect oval, double startAngle, double sweepAngle);
  void addPolygon(List<Offset> points, bool close);
  void addRRect(RRect rrect);
  void addPath(Path path, Offset offset, {Float64List? matrix4});
  void extendWithPath(Path path, Offset offset, {Float64List? matrix4});
  void close();
  void reset();
  bool contains(Offset point);
  Path shift(Offset offset);
  Path transform(Float64List matrix4);
  // see https://skia.org/user/api/SkPath_Reference#SkPath_getBounds
  Rect getBounds();

  static Path combine(PathOperation operation, Path path1, Path path2) {
    throw UnimplementedError('combinePaths not implemented in flute.');
  }

  PathMetrics computeMetrics({bool forceClosed = false});
}

abstract class PathMetrics extends collection.IterableBase<PathMetric> {
  @override
  Iterator<PathMetric> get iterator;
}

abstract class PathMetricIterator implements Iterator<PathMetric> {
  @override
  PathMetric get current;

  @override
  bool moveNext();
}

abstract class PathMetric {
  double get length;
  int get contourIndex;
  Tangent? getTangentForOffset(double distance);
  Path extractPath(double start, double end, {bool startWithMoveTo = true});
  bool get isClosed;
}

class Tangent {
  const Tangent(this.position, this.vector)
      : assert(position != null),
        assert(vector != null);
  factory Tangent.fromAngle(Offset position, double angle) {
    return Tangent(position, Offset(math.cos(angle), math.sin(angle)));
  }
  final Offset position;
  final Offset vector;
  // flip the sign to be consistent with [Path.arcTo]'s `sweepAngle`
  double get angle => -math.atan2(vector.dy, vector.dx);
}

// These enum values must be kept in sync with SkBlurStyle.
enum BlurStyle {
  // These mirror SkBlurStyle and must be kept in sync.
  normal,
  solid,
  outer,
  inner,
}
class MaskFilter {
  const MaskFilter.blur(
    this._style,
    this._sigma,
  ) : assert(_style != null), // ignore: unnecessary_null_comparison
      assert(_sigma != null); // ignore: unnecessary_null_comparison

  final BlurStyle _style;
  final double _sigma;

  // The type of MaskFilter class to create for Skia.
  // These constants must be kept in sync with MaskFilterType in paint.cc.
  static const int _TypeNone = 0; // null
  static const int _TypeBlur = 1; // SkBlurMaskFilter

  @override
  bool operator ==(Object other) {
    return other is MaskFilter
        && other._style == _style
        && other._sigma == _sigma;
  }

  @override
  int get hashCode => hashValues(_style, _sigma);

  @override
  String toString() => 'MaskFilter.blur($_style, ${_sigma.toStringAsFixed(1)})';
}
class ColorFilter implements ImageFilter {
  const ColorFilter.mode(Color color, BlendMode blendMode)
      : _color = color,
        _blendMode = blendMode,
        _matrix = null,
        _type = _kTypeMode;
  const ColorFilter.matrix(List<double> matrix)
      : _color = null,
        _blendMode = null,
        _matrix = matrix,
        _type = _kTypeMatrix;
  const ColorFilter.linearToSrgbGamma()
      : _color = null,
        _blendMode = null,
        _matrix = null,
        _type = _kTypeLinearToSrgbGamma;
  const ColorFilter.srgbToLinearGamma()
      : _color = null,
        _blendMode = null,
        _matrix = null,
        _type = _kTypeSrgbToLinearGamma;

  final Color? _color;
  final BlendMode? _blendMode;
  final List<double>? _matrix;
  final int _type;

  // The type of SkColorFilter class to create for Skia.
  static const int _kTypeMode = 1; // MakeModeFilter
  static const int _kTypeMatrix = 2; // MakeMatrixFilterRowMajor255
  static const int _kTypeLinearToSrgbGamma = 3; // MakeLinearToSRGBGamma
  static const int _kTypeSrgbToLinearGamma = 4; // MakeSRGBToLinearGamma

  // SkImageFilters::ColorFilter
  @override
  _ImageFilter _toNativeImageFilter() => _ImageFilter.fromColorFilter(this);

  _ColorFilter? _toNativeColorFilter() {
    switch (_type) {
      case _kTypeMode:
        if (_color == null || _blendMode == null) {
          return null;
        }
        return _ColorFilter.mode(this);
      case _kTypeMatrix:
        if (_matrix == null) {
          return null;
        }
        assert(_matrix!.length == 20, 'Color Matrix must have 20 entries.');
        return _ColorFilter.matrix(this);
      case _kTypeLinearToSrgbGamma:
        return _ColorFilter.linearToSrgbGamma(this);
      case _kTypeSrgbToLinearGamma:
        return _ColorFilter.srgbToLinearGamma(this);
      default:
        throw StateError('Unknown mode $_type for ColorFilter.');
    }
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType)
      return false;
    return other is ColorFilter
        && other._type == _type
        && _listEquals<double>(other._matrix, _matrix)
        && other._color == _color
        && other._blendMode == _blendMode;
  }

  @override
  int get hashCode => hashValues(_color, _blendMode, hashList(_matrix), _type);

  @override
  String get _shortDescription {
    switch (_type) {
      case _kTypeMode:
        return 'ColorFilter.mode($_color, $_blendMode)';
      case _kTypeMatrix:
        return 'ColorFilter.matrix($_matrix)';
      case _kTypeLinearToSrgbGamma:
        return 'ColorFilter.linearToSrgbGamma()';
      case _kTypeSrgbToLinearGamma:
        return 'ColorFilter.srgbToLinearGamma()';
      default:
        return 'unknow ColorFilter';
    }
  }

  @override
  String toString() {
    switch (_type) {
      case _kTypeMode:
        return 'ColorFilter.mode($_color, $_blendMode)';
      case _kTypeMatrix:
        return 'ColorFilter.matrix($_matrix)';
      case _kTypeLinearToSrgbGamma:
        return 'ColorFilter.linearToSrgbGamma()';
      case _kTypeSrgbToLinearGamma:
        return 'ColorFilter.srgbToLinearGamma()';
      default:
        return 'Unknown ColorFilter type. This is an error. If you\'re seeing this, please file an issue at https://github.com/flutter/flutter/issues/new.';
    }
  }
}
class _ColorFilter {
  _ColorFilter.mode(this.creator)
    : assert(creator != null), // ignore: unnecessary_null_comparison
      assert(creator._type == ColorFilter._kTypeMode) {
    _constructor();
    _initMode(creator._color!.value, creator._blendMode!.index);
  }

  _ColorFilter.matrix(this.creator)
    : assert(creator != null), // ignore: unnecessary_null_comparison
      assert(creator._type == ColorFilter._kTypeMatrix) {
    _constructor();
    _initMatrix(Float32List.fromList(creator._matrix!));
  }
  _ColorFilter.linearToSrgbGamma(this.creator)
    : assert(creator != null), // ignore: unnecessary_null_comparison
      assert(creator._type == ColorFilter._kTypeLinearToSrgbGamma) {
    _constructor();
    _initLinearToSrgbGamma();
  }

  _ColorFilter.srgbToLinearGamma(this.creator)
    : assert(creator != null), // ignore: unnecessary_null_comparison
      assert(creator._type == ColorFilter._kTypeSrgbToLinearGamma) {
    _constructor();
    _initSrgbToLinearGamma();
  }
  final ColorFilter creator;

  void _constructor() {  }
  void _initMode(int color, int blendMode) {  }
  void _initMatrix(Float32List matrix) {  }
  void _initLinearToSrgbGamma() {  }
  void _initSrgbToLinearGamma() {  }
}
abstract class ImageFilter {
  factory ImageFilter.blur({ double sigmaX = 0.0, double sigmaY = 0.0, TileMode tileMode = TileMode.clamp }) {
    assert(sigmaX != null); // ignore: unnecessary_null_comparison
    assert(sigmaY != null); // ignore: unnecessary_null_comparison
    assert(tileMode != null); // ignore: unnecessary_null_comparison
    return _GaussianBlurImageFilter(sigmaX: sigmaX, sigmaY: sigmaY, tileMode: tileMode);
  }
  factory ImageFilter.matrix(Float64List matrix4,
                     { FilterQuality filterQuality = FilterQuality.low }) {
    assert(matrix4 != null);       // ignore: unnecessary_null_comparison
    assert(filterQuality != null); // ignore: unnecessary_null_comparison
    if (matrix4.length != 16)
      throw ArgumentError('"matrix4" must have 16 entries.');
    return _MatrixImageFilter(data: Float64List.fromList(matrix4), filterQuality: filterQuality);
  }
  factory ImageFilter.compose({ required ImageFilter outer, required ImageFilter inner }) {
    assert (inner != null && outer != null);  // ignore: unnecessary_null_comparison
    return _ComposeImageFilter(innerFilter: inner, outerFilter: outer);
  }

  // Converts this to a native SkImageFilter. See the comments of this method in
  // subclasses for the exact type of SkImageFilter this method converts to.
  _ImageFilter _toNativeImageFilter();

  // The description text to show when the filter is part of a composite
  // [ImageFilter] created using [ImageFilter.compose].
  String get _shortDescription;
}

class _MatrixImageFilter implements ImageFilter {
  _MatrixImageFilter({ required this.data, required this.filterQuality });

  final Float64List data;
  final FilterQuality filterQuality;

  // MakeMatrixFilterRowMajor255
  late final _ImageFilter nativeFilter = _ImageFilter.matrix(this);
  @override
  _ImageFilter _toNativeImageFilter() => nativeFilter;

  @override
  String get _shortDescription => 'matrix($data, $filterQuality)';

  @override
  String toString() => 'ImageFilter.matrix($data, $filterQuality)';

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType)
      return false;
    return other is _MatrixImageFilter
        && other.filterQuality == filterQuality
        && _listEquals<double>(other.data, data);
  }

  @override
  int get hashCode => hashValues(filterQuality, hashList(data));
}

class _GaussianBlurImageFilter implements ImageFilter {
  _GaussianBlurImageFilter({ required this.sigmaX, required this.sigmaY, required this.tileMode });

  final double sigmaX;
  final double sigmaY;
  final TileMode tileMode;

  // MakeBlurFilter
  late final _ImageFilter nativeFilter = _ImageFilter.blur(this);
  @override
  _ImageFilter _toNativeImageFilter() => nativeFilter;

  String get _modeString {
    switch(tileMode) {
      case TileMode.clamp: return 'clamp';
      case TileMode.mirror: return 'mirror';
      case TileMode.repeated: return 'repeated';
      case TileMode.decal: return 'decal';
    }
  }

  @override
  String get _shortDescription => 'blur($sigmaX, $sigmaY, $_modeString)';

  @override
  String toString() => 'ImageFilter.blur($sigmaX, $sigmaY, $_modeString)';

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType)
      return false;
    return other is _GaussianBlurImageFilter
        && other.sigmaX == sigmaX
        && other.sigmaY == sigmaY
        && other.tileMode == tileMode;
  }

  @override
  int get hashCode => hashValues(sigmaX, sigmaY);
}

class _ComposeImageFilter implements ImageFilter {
  _ComposeImageFilter({ required this.innerFilter, required this.outerFilter });

  final ImageFilter innerFilter;
  final ImageFilter outerFilter;

  // SkImageFilters::Compose
  late final _ImageFilter nativeFilter = _ImageFilter.composed(this);
  @override
  _ImageFilter _toNativeImageFilter() => nativeFilter;

  @override
  String get _shortDescription => '${innerFilter._shortDescription} -> ${outerFilter._shortDescription}';

  @override
  String toString() => 'ImageFilter.compose(source -> $_shortDescription -> result)';

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType)
      return false;
    return other is _ComposeImageFilter
        && other.innerFilter == innerFilter
        && other.outerFilter == outerFilter;
  }

  @override
  int get hashCode => hashValues(innerFilter, outerFilter);
}
class _ImageFilter {
  void _constructor() {  }
  _ImageFilter.blur(_GaussianBlurImageFilter filter)
    : assert(filter != null), // ignore: unnecessary_null_comparison
      creator = filter {    // ignore: prefer_initializing_formals
    _constructor();
    _initBlur(filter.sigmaX, filter.sigmaY, filter.tileMode.index);
  }
  void _initBlur(double sigmaX, double sigmaY, int tileMode) {  }
  _ImageFilter.matrix(_MatrixImageFilter filter)
    : assert(filter != null), // ignore: unnecessary_null_comparison
      creator = filter {    // ignore: prefer_initializing_formals
    if (filter.data.length != 16)
      throw ArgumentError('"matrix4" must have 16 entries.');
    _constructor();
    _initMatrix(filter.data, filter.filterQuality.index);
  }
  void _initMatrix(Float64List matrix4, int filterQuality) {  }
  _ImageFilter.fromColorFilter(ColorFilter filter)
    : assert(filter != null), // ignore: unnecessary_null_comparison
      creator = filter {    // ignore: prefer_initializing_formals
    _constructor();
    final _ColorFilter? nativeFilter = filter._toNativeColorFilter();
    _initColorFilter(nativeFilter);
  }
  void _initColorFilter(_ColorFilter? colorFilter) {  }
  _ImageFilter.composed(_ComposeImageFilter filter)
    : assert(filter != null), // ignore: unnecessary_null_comparison
      creator = filter {    // ignore: prefer_initializing_formals
    _constructor();
    final _ImageFilter nativeFilterInner = filter.innerFilter._toNativeImageFilter();
    final _ImageFilter nativeFilterOuter = filter.outerFilter._toNativeImageFilter();
    _initComposed(nativeFilterOuter,  nativeFilterInner);
  }
  void _initComposed(_ImageFilter outerFilter, _ImageFilter innerFilter) {  }
  final ImageFilter creator;
}
class Shader {
  Shader._();

  bool _debugDisposed = false;

  bool get debugDisposed {
    late bool disposed;
    assert(() {
      disposed = _debugDisposed;
      return true;
    }());
    return disposed;
  }

  void dispose() {
    assert(() {
      assert(!_debugDisposed);
      _debugDisposed = true;
      return true;
    }());
  }
}

// These enum values must be kept in sync with SkTileMode.
enum TileMode {
  clamp,
  repeated,
  mirror,
  decal,
}

Int32List _encodeColorList(List<Color> colors) {
  final int colorCount = colors.length;
  final Int32List result = Int32List(colorCount);
  for (int i = 0; i < colorCount; ++i)
    result[i] = colors[i].value;
  return result;
}

Float32List _encodePointList(List<Offset> points) {
  assert(points != null); // ignore: unnecessary_null_comparison
  final int pointCount = points.length;
  final Float32List result = Float32List(pointCount * 2);
  for (int i = 0; i < pointCount; ++i) {
    final int xIndex = i * 2;
    final int yIndex = xIndex + 1;
    final Offset point = points[i];
    assert(_offsetIsValid(point));
    result[xIndex] = point.dx;
    result[yIndex] = point.dy;
  }
  return result;
}

Float32List _encodeTwoPoints(Offset pointA, Offset pointB) {
  assert(_offsetIsValid(pointA));
  assert(_offsetIsValid(pointB));
  final Float32List result = Float32List(4);
  result[0] = pointA.dx;
  result[1] = pointA.dy;
  result[2] = pointB.dx;
  result[3] = pointB.dy;
  return result;
}
class Gradient extends Shader {

  void _constructor() {}
  Gradient.linear(
    Offset from,
    Offset to,
    List<Color> colors, [
    List<double>? colorStops,
    TileMode tileMode = TileMode.clamp,
    Float64List? matrix4,
  ]) : assert(_offsetIsValid(from)),
       assert(_offsetIsValid(to)),
       assert(colors != null), // ignore: unnecessary_null_comparison
       assert(tileMode != null), // ignore: unnecessary_null_comparison
       assert(matrix4 == null || _matrix4IsValid(matrix4)), // ignore: unnecessary_null_comparison
       super._() {
    _validateColorStops(colors, colorStops);
    final Float32List endPointsBuffer = _encodeTwoPoints(from, to);
    final Int32List colorsBuffer = _encodeColorList(colors);
    final Float32List? colorStopsBuffer = colorStops == null ? null : Float32List.fromList(colorStops);
    _constructor();
    _initLinear(endPointsBuffer, colorsBuffer, colorStopsBuffer, tileMode.index, matrix4);
  }
  void _initLinear(Float32List endPoints, Int32List colors, Float32List? colorStops, int tileMode, Float64List? matrix4) {}
  Gradient.radial(
    Offset center,
    double radius,
    List<Color> colors, [
    List<double>? colorStops,
    TileMode tileMode = TileMode.clamp,
    Float64List? matrix4,
    Offset? focal,
    double focalRadius = 0.0
  ]) : assert(_offsetIsValid(center)),
       assert(colors != null), // ignore: unnecessary_null_comparison
       assert(tileMode != null), // ignore: unnecessary_null_comparison
       assert(matrix4 == null || _matrix4IsValid(matrix4)),
       super._() {
    _validateColorStops(colors, colorStops);
    final Int32List colorsBuffer = _encodeColorList(colors);
    final Float32List? colorStopsBuffer = colorStops == null ? null : Float32List.fromList(colorStops);

    // If focal is null or focal radius is null, this should be treated as a regular radial gradient
    // If focal == center and the focal radius is 0.0, it's still a regular radial gradient
    if (focal == null || (focal == center && focalRadius == 0.0)) {
      _constructor();
      _initRadial(center.dx, center.dy, radius, colorsBuffer, colorStopsBuffer, tileMode.index, matrix4);
    } else {
      assert(center != Offset.zero || focal != Offset.zero); // will result in exception(s) in Skia side
      _constructor();
      _initConical(focal.dx, focal.dy, focalRadius, center.dx, center.dy, radius, colorsBuffer, colorStopsBuffer, tileMode.index, matrix4);
    }
  }
  void _initRadial(double centerX, double centerY, double radius, Int32List colors, Float32List? colorStops, int tileMode, Float64List? matrix4) {  }
  void _initConical(double startX, double startY, double startRadius, double endX, double endY, double endRadius, Int32List colors, Float32List? colorStops, int tileMode, Float64List? matrix4) {  }
  Gradient.sweep(
    Offset center,
    List<Color> colors, [
    List<double>? colorStops,
    TileMode tileMode = TileMode.clamp,
    double startAngle = 0.0,
    double endAngle = math.pi * 2,
    Float64List? matrix4,
  ]) : assert(_offsetIsValid(center)),
       assert(colors != null), // ignore: unnecessary_null_comparison
       assert(tileMode != null), // ignore: unnecessary_null_comparison
       assert(startAngle != null), // ignore: unnecessary_null_comparison
       assert(endAngle != null), // ignore: unnecessary_null_comparison
       assert(startAngle < endAngle),
       assert(matrix4 == null || _matrix4IsValid(matrix4)),
       super._() {
    _validateColorStops(colors, colorStops);
    final Int32List colorsBuffer = _encodeColorList(colors);
    final Float32List? colorStopsBuffer = colorStops == null ? null : Float32List.fromList(colorStops);
    _constructor();
    _initSweep(center.dx, center.dy, colorsBuffer, colorStopsBuffer, tileMode.index, startAngle, endAngle, matrix4);
  }
  void _initSweep(double centerX, double centerY, Int32List colors, Float32List? colorStops, int tileMode, double startAngle, double endAngle, Float64List? matrix) {  }

  static void _validateColorStops(List<Color> colors, List<double>? colorStops) {
    if (colorStops == null) {
      if (colors.length != 2)
        throw ArgumentError('"colors" must have length 2 if "colorStops" is omitted.');
    } else {
      if (colors.length != colorStops.length)
        throw ArgumentError('"colors" and "colorStops" arguments must have equal length.');
    }
  }
}
class ImageShader extends Shader {
    // ignore: avoid_unused_constructor_parameters
    ImageShader(Image image, TileMode tmx, TileMode tmy, Float64List matrix4, { FilterQuality? filterQuality }) :
    // ignore: unnecessary_null_comparison
    assert(image != null), // image is checked on the engine side
    assert(tmx != null), // ignore: unnecessary_null_comparison
    assert(tmy != null), // ignore: unnecessary_null_comparison
    assert(matrix4 != null), // ignore: unnecessary_null_comparison
    super._() {
    if (matrix4.length != 16)
      throw ArgumentError('"matrix4" must have 16 entries.');
    _constructor();
    _initWithImage(image._image, tmx.index, tmy.index, matrix4);
  }
  void _constructor() {  }
  void _initWithImage(_Image image, int tmx, int tmy, Float64List matrix4) {  }
}
// These enum values must be kept in sync with SkVertices::VertexMode.
enum VertexMode {
  triangles,
  triangleStrip,
  triangleFan,
}
class Vertices {
  Vertices(
    VertexMode mode,
    List<Offset> positions, {
    List<Offset>? textureCoordinates,
    List<Color>? colors,
    List<int>? indices,
  }) : assert(mode != null), // ignore: unnecessary_null_comparison
       assert(positions != null) { // ignore: unnecessary_null_comparison
    if (textureCoordinates != null && textureCoordinates.length != positions.length)
      throw ArgumentError('"positions" and "textureCoordinates" lengths must match.');
    if (colors != null && colors.length != positions.length)
      throw ArgumentError('"positions" and "colors" lengths must match.');
    if (indices != null && indices.any((int i) => i < 0 || i >= positions.length))
      throw ArgumentError('"indices" values must be valid indices in the positions list.');

    final Float32List encodedPositions = _encodePointList(positions);
    final Float32List? encodedTextureCoordinates = (textureCoordinates != null)
      ? _encodePointList(textureCoordinates)
      : null;
    final Int32List? encodedColors = colors != null
      ? _encodeColorList(colors)
      : null;
    final Uint16List? encodedIndices = indices != null
      ? Uint16List.fromList(indices)
      : null;

    if (!_init(this, mode.index, encodedPositions, encodedTextureCoordinates, encodedColors, encodedIndices))
      throw ArgumentError('Invalid configuration for vertices.');
  }
  Vertices.raw(
    VertexMode mode,
    Float32List positions, {
    Float32List? textureCoordinates,
    Int32List? colors,
    Uint16List? indices,
  }) : assert(mode != null), // ignore: unnecessary_null_comparison
       assert(positions != null) { // ignore: unnecessary_null_comparison
    if (textureCoordinates != null && textureCoordinates.length != positions.length)
      throw ArgumentError('"positions" and "textureCoordinates" lengths must match.');
    if (colors != null && colors.length * 2 != positions.length)
      throw ArgumentError('"positions" and "colors" lengths must match.');
    if (indices != null && indices.any((int i) => i < 0 || i >= positions.length))
      throw ArgumentError('"indices" values must be valid indices in the positions list.');

    if (!_init(this, mode.index, positions, textureCoordinates, colors, indices))
      throw ArgumentError('Invalid configuration for vertices.');
  }

  bool _init(Vertices outVertices,
             int mode,
             Float32List positions,
             Float32List? textureCoordinates,
             Int32List? colors,
             Uint16List? indices) { return true; }
}
// ignore: deprecated_member_use
// These enum values must be kept in sync with SkCanvas::PointMode.
enum PointMode {
  points,
  lines,
  polygon,
}
enum ClipOp {
  difference,
  intersect,
}

class _CanvasMethods {
  static const int save = 0;
  static const int saveLayer = 1;
  static const int restore = 2;
  static const int translate = 3;
  static const int scale = 4;
  static const int rotate = 5;
  static const int skew = 6;
  static const int transform = 7;
  static const int clipRect = 8;
  static const int clipRRect = 9;
  static const int clipPath = 10;
  static const int drawColor = 11;
  static const int drawLine = 12;
  static const int drawPaint = 13;
  static const int drawRect = 14;
  static const int drawRRect = 15;
  static const int drawDRRect = 16;
  static const int drawOval = 17;
  static const int drawCircle = 18;
  static const int drawArc = 19;
  static const int drawPath = 20;
  static const int drawImage = 21;
  static const int drawImageRect = 22;
  static const int drawImageNine = 23;
  static const int drawPicture = 24;
  static const int drawParagraph = 25;
  static const int drawPoints = 26;
  static const int drawVertices = 27;
  static const int drawAtlas = 28;
  static const int drawShadow = 29;
}
class Canvas {
  Canvas(PictureRecorder this._recorder, [Rect? cullRect]) : assert(_recorder != null) { // ignore: unnecessary_null_comparison
    cullRect?.inflate(10);
    if (_recorder!.isRecording)
      throw ArgumentError('"recorder" must not already be associated with another Canvas.');
    _recorder!._canvas = this;
  }

  // The underlying Skia SkCanvas is owned by the PictureRecorder used to create this Canvas.
  // The Canvas holds a reference to the PictureRecorder to prevent the recorder from being
  // garbage collected until PictureRecorder.endRecording is called.
  PictureRecorder? _recorder;

  Uint8List _methods = Uint8List(10);
  int _methodsLength = 0;
  Float32List _data = Float32List(30);
  int _dataLength = 0;
  List<Object> _objects = <Object>[];
  int _saveCount = 0;

  void _addObject(Object object) {
    _objects.add(object);
  }

  void _addMethod(int methodId) {
    if (_methodsLength >= _methods.length) {
      final Uint8List newList = Uint8List(_methods.length * 2);
      for (int i = 0; i < _methodsLength; i++) {
        newList[i] = _methods[i];
      }
      _methods = newList;
    }
    _methods[_methodsLength] = methodId;
    _methodsLength += 1;
  }

  void _ensureDataLength(int newLength) {
    if (_data.length >= newLength) {
      return;
    }

    final Float32List newList = Float32List(_data.length * 2);
    for (int i = 0; i < _dataLength; i++) {
      newList[i] = _data[i];
    }
    _data = newList;
  }

  void _addData1(double a) {
    _ensureDataLength(_dataLength + 1);
    _data[_dataLength++] = a;
  }

  void _addData2(double a, double b) {
    _ensureDataLength(_dataLength + 2);
    _data[_dataLength++] = a;
    _data[_dataLength++] = b;
  }

  void _addData4(double a, double b, double c, double d) {
    _ensureDataLength(_dataLength + 4);
    _data[_dataLength++] = a;
    _data[_dataLength++] = b;
    _data[_dataLength++] = c;
    _data[_dataLength++] = d;
  }

  void _addData6(double a, double b, double c, double d, double e, double f) {
    _ensureDataLength(_dataLength + 6);
    _data[_dataLength++] = a;
    _data[_dataLength++] = b;
    _data[_dataLength++] = c;
    _data[_dataLength++] = d;
    _data[_dataLength++] = e;
    _data[_dataLength++] = f;
  }

  void _addData7(double a, double b, double c, double d, double e, double f, double g) {
    _ensureDataLength(_dataLength + 7);
    _data[_dataLength++] = a;
    _data[_dataLength++] = b;
    _data[_dataLength++] = c;
    _data[_dataLength++] = d;
    _data[_dataLength++] = e;
    _data[_dataLength++] = f;
    _data[_dataLength++] = g;
  }

  void _addData12(double a, double b, double c, double d, double e, double f,
                  double g, double h, double i, double j, double k, double l) {
    _ensureDataLength(_dataLength + 12);
    _data[_dataLength++] = a;
    _data[_dataLength++] = b;
    _data[_dataLength++] = c;
    _data[_dataLength++] = d;
    _data[_dataLength++] = e;
    _data[_dataLength++] = f;
    _data[_dataLength++] = g;
    _data[_dataLength++] = h;
    _data[_dataLength++] = i;
    _data[_dataLength++] = j;
    _data[_dataLength++] = k;
    _data[_dataLength++] = l;
  }

  void save() {
    _addMethod(_CanvasMethods.save);
    _saveCount += 1;
  }
  void saveLayer(Rect? bounds, Paint paint) {
    assert(paint != null); // ignore: unnecessary_null_comparison
    _addMethod(_CanvasMethods.saveLayer);
    _addObject(paint);
    if (bounds != null) {
      assert(_rectIsValid(bounds));
      _addData4(bounds.left, bounds.top, bounds.right, bounds.bottom);
    }
  }

  void restore() {
    _addMethod(_CanvasMethods.restore);
    _saveCount -= 1;
  }

  int getSaveCount() => _saveCount;

  void translate(double dx, double dy) {
    _addMethod(_CanvasMethods.translate);
    _addData2(dx, dy);
  }

  void scale(double sx, [double? sy]) {
    _addMethod(_CanvasMethods.scale);
    _addData2(sx, sy ?? 1.0);
  }

  void rotate(double radians) {
    _addMethod(_CanvasMethods.rotate);
    _addData1(radians);
  }

  void skew(double sx, double sy) {
    _addMethod(_CanvasMethods.skew);
    _addData2(sx, sy);
  }

  void transform(Float64List matrix4) {
    assert(matrix4 != null); // ignore: unnecessary_null_comparison
    if (matrix4.length != 16)
      throw ArgumentError('"matrix4" must have 16 entries.');

    _addMethod(_CanvasMethods.transform);
    _addObject(matrix4);
  }

  void clipRect(Rect rect, { ClipOp clipOp = ClipOp.intersect, bool doAntiAlias = true }) {
    assert(_rectIsValid(rect));
    assert(clipOp != null); // ignore: unnecessary_null_comparison
    assert(doAntiAlias != null); // ignore: unnecessary_null_comparison
    _addMethod(_CanvasMethods.clipRect);
    _addData6(rect.left, rect.top, rect.right, rect.bottom, clipOp.index.toDouble(), doAntiAlias ? 1 : 0);
  }

  void clipRRect(RRect rrect, {bool doAntiAlias = true}) {
    assert(_rrectIsValid(rrect));
    assert(doAntiAlias != null); // ignore: unnecessary_null_comparison
    _addMethod(_CanvasMethods.clipRRect);
    _addData12(
      rrect.left,
      rrect.top,
      rrect.right,
      rrect.bottom,
      rrect.tlRadiusX,
      rrect.tlRadiusY,
      rrect.trRadiusX,
      rrect.trRadiusY,
      rrect.brRadiusX,
      rrect.brRadiusY,
      rrect.blRadiusX,
      rrect.blRadiusY,
    );
    _addData1(doAntiAlias ? 1 : 0);
  }

  void clipPath(Path path, {bool doAntiAlias = true}) {
    // ignore: unnecessary_null_comparison
    assert(path != null); // path is checked on the engine side
    assert(doAntiAlias != null); // ignore: unnecessary_null_comparison
    _addMethod(_CanvasMethods.clipPath);
    _addObject(path);
    _addData1(doAntiAlias ? 1 : 0);
  }

  void drawColor(Color color, BlendMode blendMode) {
    assert(color != null); // ignore: unnecessary_null_comparison
    assert(blendMode != null); // ignore: unnecessary_null_comparison
    _addMethod(_CanvasMethods.drawColor);
    _addData2(
      color.value.toDouble(),
      blendMode.index.toDouble(),
    );
  }

  void drawLine(Offset p1, Offset p2, Paint paint) {
    assert(_offsetIsValid(p1));
    assert(_offsetIsValid(p2));
    assert(paint != null); // ignore: unnecessary_null_comparison
    _addMethod(_CanvasMethods.drawLine);
    _addObject(paint);
    _addData4(p1.dx, p1.dy, p2.dx, p2.dy);
  }

  void drawPaint(Paint paint) {
    assert(paint != null); // ignore: unnecessary_null_comparison
    _addMethod(_CanvasMethods.drawPaint);
    _addObject(paint);
  }

  void drawRect(Rect rect, Paint paint) {
    assert(_rectIsValid(rect));
    assert(paint != null); // ignore: unnecessary_null_comparison
    _addMethod(_CanvasMethods.drawRect);
    _addObject(paint);
    _addData4(rect.left, rect.top, rect.right, rect.bottom);
  }

  void drawRRect(RRect rrect, Paint paint) {
    assert(_rrectIsValid(rrect));
    assert(paint != null); // ignore: unnecessary_null_comparison
    _addMethod(_CanvasMethods.drawRRect);
    _addObject(paint);
    _addData12(
      rrect.left,
      rrect.top,
      rrect.right,
      rrect.bottom,
      rrect.tlRadiusX,
      rrect.tlRadiusY,
      rrect.trRadiusX,
      rrect.trRadiusY,
      rrect.brRadiusX,
      rrect.brRadiusY,
      rrect.blRadiusX,
      rrect.blRadiusY,
    );
  }

  void drawDRRect(RRect outer, RRect inner, Paint paint) {
    assert(_rrectIsValid(outer));
    assert(_rrectIsValid(inner));
    assert(paint != null); // ignore: unnecessary_null_comparison
    _addMethod(_CanvasMethods.drawDRRect);
    _addObject(paint);
    _addData12(
      outer.left,
      outer.top,
      outer.right,
      outer.bottom,
      outer.tlRadiusX,
      outer.tlRadiusY,
      outer.trRadiusX,
      outer.trRadiusY,
      outer.brRadiusX,
      outer.brRadiusY,
      outer.blRadiusX,
      outer.blRadiusY,
    );
    _addData12(
      inner.left,
      inner.top,
      inner.right,
      inner.bottom,
      inner.tlRadiusX,
      inner.tlRadiusY,
      inner.trRadiusX,
      inner.trRadiusY,
      inner.brRadiusX,
      inner.brRadiusY,
      inner.blRadiusX,
      inner.blRadiusY,
    );
  }

  void drawOval(Rect rect, Paint paint) {
    assert(_rectIsValid(rect));
    assert(paint != null); // ignore: unnecessary_null_comparison
    _addMethod(_CanvasMethods.drawOval);
    _addObject(paint);
    _addData4(rect.left, rect.top, rect.right, rect.bottom);
  }

  void drawCircle(Offset c, double radius, Paint paint) {
    assert(_offsetIsValid(c));
    assert(paint != null); // ignore: unnecessary_null_comparison
    _addMethod(_CanvasMethods.drawCircle);
    _addObject(paint);
    _addData2(c.dx, c.dy);
    _addData1(radius);
  }

  void drawArc(Rect rect, double startAngle, double sweepAngle, bool useCenter, Paint paint) {
    assert(_rectIsValid(rect));
    assert(paint != null); // ignore: unnecessary_null_comparison
    _addMethod(_CanvasMethods.drawArc);
    _addObject(paint);
    _addData7(rect.left, rect.top, rect.right, rect.bottom, startAngle,
             sweepAngle, useCenter ? 1 : 0);
  }

  void drawPath(Path path, Paint paint) {
    // ignore: unnecessary_null_comparison
    assert(path != null); // path is checked on the engine side
    assert(paint != null); // ignore: unnecessary_null_comparison
    _addMethod(_CanvasMethods.drawPath);
    _addObject(paint);
    _addObject(path);
  }

  void drawImage(Image image, Offset offset, Paint paint) {
    // ignore: unnecessary_null_comparison
    assert(image != null); // image is checked on the engine side
    assert(_offsetIsValid(offset));
    assert(paint != null); // ignore: unnecessary_null_comparison
    _addMethod(_CanvasMethods.drawImage);
    _addObject(paint);
    _addObject(image);
  }

  void drawImageRect(Image image, Rect src, Rect dst, Paint paint) {
    // ignore: unnecessary_null_comparison
    assert(image != null); // image is checked on the engine side
    assert(_rectIsValid(src));
    assert(_rectIsValid(dst));
    assert(paint != null); // ignore: unnecessary_null_comparison
    _addMethod(_CanvasMethods.drawImageRect);
    _addObject(paint);
    _addObject(image);
    _addData4(
      src.left,
      src.top,
      src.right,
      src.bottom,
    );
    _addData4(
      dst.left,
      dst.top,
      dst.right,
      dst.bottom,
    );
  }

  void drawImageNine(Image image, Rect center, Rect dst, Paint paint) {
    // ignore: unnecessary_null_comparison
    assert(image != null); // image is checked on the engine side
    assert(_rectIsValid(center));
    assert(_rectIsValid(dst));
    assert(paint != null); // ignore: unnecessary_null_comparison
    _addMethod(_CanvasMethods.drawImageNine);
    _addObject(paint);
    _addObject(image);
    _addData4(
      center.left,
      center.top,
      center.right,
      center.bottom,
    );
    _addData4(
      dst.left,
      dst.top,
      dst.right,
      dst.bottom,
    );
  }

  void drawPicture(Picture picture) {
    // ignore: unnecessary_null_comparison
    assert(picture != null); // picture is checked on the engine side
    _addMethod(_CanvasMethods.drawPicture);
    _addObject(picture);
  }

  void drawParagraph(Paragraph paragraph, Offset offset) {
    assert(paragraph != null); // ignore: unnecessary_null_comparison
    assert(_offsetIsValid(offset));
    _addMethod(_CanvasMethods.drawParagraph);
    _addObject(paragraph);
  }

  void drawPoints(PointMode pointMode, List<Offset> points, Paint paint) {
    assert(pointMode != null); // ignore: unnecessary_null_comparison
    assert(points != null); // ignore: unnecessary_null_comparison
    assert(paint != null); // ignore: unnecessary_null_comparison
    _drawPoints(paint, pointMode.index, _encodePointList(points));
  }

  void drawRawPoints(PointMode pointMode, Float32List points, Paint paint) {
    assert(pointMode != null); // ignore: unnecessary_null_comparison
    assert(points != null); // ignore: unnecessary_null_comparison
    assert(paint != null); // ignore: unnecessary_null_comparison
    if (points.length % 2 != 0)
      throw ArgumentError('"points" must have an even number of values.');
    _drawPoints(paint, pointMode.index, points);
  }

  void _drawPoints(
    Paint paint,
    int pointMode,
    Float32List points,
  ) {
    _addMethod(_CanvasMethods.drawPoints);
    _addObject(paint);
    _addObject(points);
    _addData1(pointMode.toDouble());
  }

  void drawVertices(Vertices vertices, BlendMode blendMode, Paint paint) {
    // ignore: unnecessary_null_comparison
    assert(vertices != null); // vertices is checked on the engine side
    assert(paint != null); // ignore: unnecessary_null_comparison
    assert(blendMode != null); // ignore: unnecessary_null_comparison
    _addMethod(_CanvasMethods.drawVertices);
    _addObject(paint);
    _addObject(vertices);
    _addData1(blendMode.index.toDouble());
  }

  void drawAtlas(Image atlas,
                 List<RSTransform> transforms,
                 List<Rect> rects,
                 List<Color>? colors,
                 BlendMode? blendMode,
                 Rect? cullRect,
                 Paint paint) {
    // ignore: unnecessary_null_comparison
    assert(atlas != null); // atlas is checked on the engine side
    assert(transforms != null); // ignore: unnecessary_null_comparison
    assert(rects != null); // ignore: unnecessary_null_comparison
    assert(colors == null || colors.isEmpty || blendMode != null);
    assert(paint != null); // ignore: unnecessary_null_comparison

    final int rectCount = rects.length;
    if (transforms.length != rectCount)
      throw ArgumentError('"transforms" and "rects" lengths must match.');
    if (colors != null && colors.isNotEmpty && colors.length != rectCount)
      throw ArgumentError('If non-null, "colors" length must match that of "transforms" and "rects".');

    final Float32List rstTransformBuffer = Float32List(rectCount * 4);
    final Float32List rectBuffer = Float32List(rectCount * 4);

    for (int i = 0; i < rectCount; ++i) {
      final int index0 = i * 4;
      final int index1 = index0 + 1;
      final int index2 = index0 + 2;
      final int index3 = index0 + 3;
      final RSTransform rstTransform = transforms[i];
      final Rect rect = rects[i];
      assert(_rectIsValid(rect));
      rstTransformBuffer[index0] = rstTransform.scos;
      rstTransformBuffer[index1] = rstTransform.ssin;
      rstTransformBuffer[index2] = rstTransform.tx;
      rstTransformBuffer[index3] = rstTransform.ty;
      rectBuffer[index0] = rect.left;
      rectBuffer[index1] = rect.top;
      rectBuffer[index2] = rect.right;
      rectBuffer[index3] = rect.bottom;
    }

    final Int32List? colorBuffer = (colors == null || colors.isEmpty) ? null : _encodeColorList(colors);

    _drawAtlas(
      paint, atlas._image, rstTransformBuffer, rectBuffer,
      colorBuffer, (blendMode ?? BlendMode.src).index, cullRect ?? Rect.largest,
    );
  }
  void drawRawAtlas(Image atlas,
                    Float32List rstTransforms,
                    Float32List rects,
                    Int32List? colors,
                    BlendMode? blendMode,
                    Rect? cullRect,
                    Paint paint) {
    // ignore: unnecessary_null_comparison
    assert(atlas != null); // atlas is checked on the engine side
    assert(rstTransforms != null); // ignore: unnecessary_null_comparison
    assert(rects != null); // ignore: unnecessary_null_comparison
    assert(colors == null || blendMode != null);
    assert(paint != null); // ignore: unnecessary_null_comparison

    final int rectCount = rects.length;
    if (rstTransforms.length != rectCount)
      throw ArgumentError('"rstTransforms" and "rects" lengths must match.');
    if (rectCount % 4 != 0)
      throw ArgumentError('"rstTransforms" and "rects" lengths must be a multiple of four.');
    if (colors != null && colors.length * 4 != rectCount)
      throw ArgumentError('If non-null, "colors" length must be one fourth the length of "rstTransforms" and "rects".');

    _drawAtlas(
      paint, atlas._image, rstTransforms, rects,
      colors, (blendMode ?? BlendMode.src).index, cullRect ?? Rect.largest,
    );
  }

  void _drawAtlas(
    Paint paint,
    _Image atlas,
    Float32List rstTransforms,
    Float32List rects,
    Int32List? colors,
    int blendMode,
    Rect cullRect,
  ) {
    _addMethod(_CanvasMethods.drawAtlas);
    _addObject(paint);
    _addObject(rstTransforms);
    _addObject(rects);
    _addObject(colors ?? Int32List(0));
    _addData1(blendMode.toDouble());
    _addData4(
      cullRect.left,
      cullRect.top,
      cullRect.right,
      cullRect.bottom,
    );
  }

  void drawShadow(Path path, Color color, double elevation, bool transparentOccluder) {
    // ignore: unnecessary_null_comparison
    assert(path != null); // path is checked on the engine side
    assert(color != null); // ignore: unnecessary_null_comparison
    assert(transparentOccluder != null); // ignore: unnecessary_null_comparison
    _addMethod(_CanvasMethods.drawShadow);
    _addObject(path);
    _addData2(color.value.toDouble(), elevation);
    _addData1(transparentOccluder ? 1 : 0);
  }
}

typedef PictureEventCallback = void Function(Picture picture);

class Picture {
  Picture._();

  static PictureEventCallback? onCreate;
  static PictureEventCallback? onDispose;

  Future<Image> toImage(int width, int height) async {
    if (width <= 0 || height <= 0)
      throw Exception('Invalid image dimensions.');
    return Image._(_Image._(width, height));
  }

  void dispose() {  }
  int get approximateBytesUsed { return 100000; }
}

class PictureRecorder {
  PictureRecorder();
  bool get isRecording => _canvas != null;
  Picture endRecording() {
    if (_canvas == null)
      throw StateError('PictureRecorder did not start recording.');
    final Picture picture = Picture._();
    _canvas!._recorder = null;
    _canvas = null;
    return picture;
  }

  Canvas? _canvas;
}
class Shadow {
  const Shadow({
    this.color = const Color(_kColorDefault),
    this.offset = Offset.zero,
    this.blurRadius = 0.0,
  }) : assert(color != null, 'Text shadow color was null.'), // ignore: unnecessary_null_comparison
       assert(offset != null, 'Text shadow offset was null.'), // ignore: unnecessary_null_comparison
       assert(blurRadius >= 0.0, 'Text shadow blur radius should be non-negative.');

  static const int _kColorDefault = 0xFF000000;
  final Color color;
  final Offset offset;
  final double blurRadius;
  // See SkBlurMask::ConvertRadiusToSigma().
  // <https://github.com/google/skia/blob/bb5b77db51d2e149ee66db284903572a5aac09be/src/effects/SkBlurMask.cpp#L23>
  static double convertRadiusToSigma(double radius) {
    return radius * 0.57735 + 0.5;
  }
  double get blurSigma => convertRadiusToSigma(blurRadius);
  Paint toPaint() {
    return Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);
  }
  Shadow scale(double factor) {
    return Shadow(
      color: color,
      offset: offset * factor,
      blurRadius: blurRadius * factor,
    );
  }
  static Shadow? lerp(Shadow? a, Shadow? b, double t) {
    assert(t != null); // ignore: unnecessary_null_comparison
    if (b == null) {
      if (a == null) {
        return null;
      } else {
        return a.scale(1.0 - t);
      }
    } else {
      if (a == null) {
        return b.scale(t);
      } else {
        return Shadow(
          color: Color.lerp(a.color, b.color, t)!,
          offset: Offset.lerp(a.offset, b.offset, t)!,
          blurRadius: _lerpDouble(a.blurRadius, b.blurRadius, t),
        );
      }
    }
  }
  static List<Shadow>? lerpList(List<Shadow>? a, List<Shadow>? b, double t) {
    assert(t != null); // ignore: unnecessary_null_comparison
    if (a == null && b == null)
      return null;
    a ??= <Shadow>[];
    b ??= <Shadow>[];
    final List<Shadow> result = <Shadow>[];
    final int commonLength = math.min(a.length, b.length);
    for (int i = 0; i < commonLength; i += 1)
      result.add(Shadow.lerp(a[i], b[i], t)!);
    for (int i = commonLength; i < a.length; i += 1)
      result.add(a[i].scale(1.0 - t));
    for (int i = commonLength; i < b.length; i += 1)
      result.add(b[i].scale(t));
    return result;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other))
      return true;
    return other is Shadow
        && other.color == color
        && other.offset == offset
        && other.blurRadius == blurRadius;
  }

  @override
  int get hashCode => hashValues(color, offset, blurRadius);

  @override
  String toString() => 'TextShadow($color, $offset, $blurRadius)';
}
class ImmutableBuffer {
  ImmutableBuffer._(this.length);
  static Future<ImmutableBuffer> fromUint8List(Uint8List list) {
    final ImmutableBuffer instance = ImmutableBuffer._(list.length);
    return _futurize((_Callback<void> callback) {
      instance._init(list, callback);
      return null;
    }).then((_) => instance);
  }

  static Future<ImmutableBuffer> fromAsset(String assetKey) async {
    throw UnsupportedError('ImmutableBuffer.fromAsset is not supported in flute.');
  }

  static Future<ImmutableBuffer> fromFilePath(String path) async {
    throw UnsupportedError('ImmutableBuffer.fromFilePath is not supported in flute.');
  }

  void _init(Uint8List list, _Callback<void> callback) {
    _list = Uint8List.fromList(list);
  }

  Uint8List? _list;

  final int length;
  void dispose() {  }
}
class ImageDescriptor {
  ImageDescriptor._();
  static Future<ImageDescriptor> encoded(ImmutableBuffer buffer) {
    final ImageDescriptor descriptor = ImageDescriptor._();
    return _futurize((_Callback<void> callback) {
      return descriptor._initEncoded(buffer, callback);
    }).then((_) => descriptor);
  }
  String? _initEncoded(ImmutableBuffer buffer, _Callback<void> callback) { return null; }
  // Not async because there's no expensive work to do here.
  ImageDescriptor.raw(
    ImmutableBuffer buffer, {
    required int width,
    required int height,
    int? rowBytes,
    required PixelFormat pixelFormat,
  }) {
    _width = width;
    _height = height;
    // We only support 4 byte pixel formats in the PixelFormat enum.
    _bytesPerPixel = 4;
    _initRaw(this, buffer, width, height, rowBytes ?? -1, pixelFormat.index);
  }
  void _initRaw(ImageDescriptor outDescriptor, ImmutableBuffer buffer, int width, int height, int rowBytes, int pixelFormat) {  }

  int? _width;
  int _getWidth() { return 100; }
  int get width => _width ??= _getWidth();

  int? _height;
  int _getHeight() { return 50; }
  int get height => _height ??= _getHeight();

  int? _bytesPerPixel;
  int _getBytesPerPixel() { return 4; }
  int get bytesPerPixel => _bytesPerPixel ??= _getBytesPerPixel();
  void dispose() {  }
  Future<Codec> instantiateCodec({int? targetWidth, int? targetHeight}) async {
    if (targetWidth != null && targetWidth <= 0) {
      targetWidth = null;
    }
    if (targetHeight != null && targetHeight <= 0) {
      targetHeight = null;
    }

    if (targetWidth == null && targetHeight == null) {
      targetWidth = width;
      targetHeight = height;
    } else if (targetWidth == null && targetHeight != null) {
      targetWidth = (targetHeight * (width / height)).round();
      targetHeight = targetHeight;
    } else if (targetHeight == null && targetWidth != null) {
      targetWidth = targetWidth;
      targetHeight = targetWidth ~/ (width / height);
    }
    assert(targetWidth != null);
    assert(targetHeight != null);

    final Codec codec = Codec._();
    _instantiateCodec(codec, targetWidth!, targetHeight!);
    return codec;
  }
  void _instantiateCodec(Codec outCodec, int targetWidth, int targetHeight) {  }
}
typedef _Callback<T> = void Function(T result);
typedef _Callbacker<T> = String? Function(_Callback<T> callback);
Future<T> _futurize<T>(_Callbacker<T> callbacker) {
  final Completer<T> completer = Completer<T>.sync();
  final String? error = callbacker((T t) {
    if (t == null) {
      completer.completeError(Exception('operation failed'));
    } else {
      completer.complete(t);
    }
  });
  if (error != null)
    throw Exception(error);
  return completer.future;
}

class FragmentShader extends Shader {
  FragmentShader._(FragmentProgram program, { String? debugName }) : _program = program, _debugName = debugName, super._();

  final FragmentProgram _program;
  final String? _debugName;

  static final Float32List _kEmptyFloat32List = Float32List(0);
  Float32List _floats = _kEmptyFloat32List;

  void setFloat(int index, double value) {
    assert(!debugDisposed, 'Tried to accesss uniforms on a disposed Shader: $this');
    _floats[index] = value;
  }

  void setImageSampler(int index, Image image) {
    assert(!debugDisposed, 'Tried to access uniforms on a disposed Shader: $this');
  }

  @override
  void dispose() {
    super.dispose();
    _floats = _kEmptyFloat32List;
  }

  @override
  String toString() => 'FragmentShader(name: $_debugName, program: $_program)';
}

class FragmentProgram {
  FragmentProgram._fromAsset(String assetKey) {
    assert(() {
      _debugName = assetKey;
      return true;
    }());
  }

  String? _debugName;

  static Future<FragmentProgram> fromAsset(String assetKey) {
    final String encodedKey = Uri(path: Uri.encodeFull(assetKey)).path;
    final FragmentProgram? program = _shaderRegistry[encodedKey]?.target;
    if (program != null) {
      return Future<FragmentProgram>.value(program);
    }
    return Future<FragmentProgram>.microtask(() {
      final FragmentProgram program = FragmentProgram._fromAsset(encodedKey);
      _shaderRegistry[encodedKey] = WeakReference<FragmentProgram>(program);
      return program;
    });
  }

  static final Map<String, WeakReference<FragmentProgram>> _shaderRegistry =
      <String, WeakReference<FragmentProgram>>{};

  /// Returns a fresh instance of [FragmentShader].
  FragmentShader fragmentShader() => FragmentShader._(this, debugName: _debugName);
}

Future<Codec> instantiateImageCodecFromBuffer(
  ImmutableBuffer buffer, {
  int? targetWidth,
  int? targetHeight,
  bool allowUpscaling = true,
}) async {
  final ImageDescriptor descriptor = await ImageDescriptor.encoded(buffer);
  if (!allowUpscaling) {
    if (targetWidth != null && targetWidth > descriptor.width) {
      targetWidth = descriptor.width;
    }
    if (targetHeight != null && targetHeight > descriptor.height) {
      targetHeight = descriptor.height;
    }
  }
  buffer.dispose();
  return descriptor.instantiateCodec(
    targetWidth: targetWidth,
    targetHeight: targetHeight,
  );
}


Future<Codec> instantiateImageCodecWithSize(
  ImmutableBuffer buffer, {
  TargetImageSizeCallback? getTargetSize,
}) async {
  if (getTargetSize == null) {
    return instantiateImageCodec(buffer._list!);
  } else {
    final Codec codec = await instantiateImageCodec(buffer._list!);
    try {
      final FrameInfo info = await codec.getNextFrame();
      try {
        final int width = info.image.width;
        final int height = info.image.height;
        final TargetImageSize targetSize = getTargetSize(width, height);
        return instantiateImageCodec(buffer._list!,
            targetWidth: targetSize.width, targetHeight: targetSize.height, allowUpscaling: false);
      } finally {
        info.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }
}

/// Signature for a callback that determines the size to which an image should
/// be decoded given its intrinsic size.
///
/// See also:
///
///  * [instantiateImageCodecWithSize], which used this signature for its
///    `getTargetSize` argument.
typedef TargetImageSizeCallback = TargetImageSize Function(
  int intrinsicWidth,
  int intrinsicHeight,
);

/// A specification of the size to which an image should be decoded.
///
/// See also:
///
///  * [TargetImageSizeCallback], a callback that returns instances of this
///    class when consulted by image decoding methods such as
///    [instantiateImageCodecWithSize].
class TargetImageSize {
  /// Creates a new instance of this class.
  ///
  /// The `width` and `height` may both be null, but if they're non-null, they
  /// must be positive.
  const TargetImageSize({this.width, this.height})
      : assert(width == null || width > 0),
        assert(height == null || height > 0);

  /// The width into which to load the image.
  ///
  /// If this is non-null, the image will be decoded into the specified width.
  /// If this is null and [height] is also null, the image will be decoded into
  /// its intrinsic size. If this is null and [height] is non-null, the image
  /// will be decoded into a width that maintains its intrinsic aspect ratio
  /// while respecting the [height] value.
  ///
  /// If this value is non-null, it must be positive.
  final int? width;

  /// The height into which to load the image.
  ///
  /// If this is non-null, the image will be decoded into the specified height.
  /// If this is null and [width] is also null, the image will be decoded into
  /// its intrinsic size. If this is null and [width] is non-null, the image
  /// will be decoded into a height that maintains its intrinsic aspect ratio
  /// while respecting the [width] value.
  ///
  /// If this value is non-null, it must be positive.
  final int? height;

  @override
  String toString() => 'TargetImageSize($width x $height)';
}
