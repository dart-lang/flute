// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';
import 'package:flute/ui.dart' as ui show Codec;
import 'package:flute/ui.dart' show Size, Locale, TextDirection, hashValues;

import 'package:flute/foundation.dart';
import 'package:flute/services.dart';

import 'binding.dart';
import 'image_cache.dart';
import 'image_stream.dart';

/// Signature for the callback taken by [_createErrorHandlerAndKey].
typedef _KeyAndErrorHandlerCallback<T> = void Function(T key, ImageErrorListener handleError);

/// Signature used for error handling by [_createErrorHandlerAndKey].
typedef _AsyncKeyErrorHandler<T> = Future<void> Function(T key, Object exception, StackTrace? stack);

/// Configuration information passed to the [ImageProvider.resolve] method to
/// select a specific image.
///
/// See also:
///
///  * [createLocalImageConfiguration], which creates an [ImageConfiguration]
///    based on ambient configuration in a [Widget] environment.
///  * [ImageProvider], which uses [ImageConfiguration] objects to determine
///    which image to obtain.
@immutable
class ImageConfiguration {
  /// Creates an object holding the configuration information for an [ImageProvider].
  ///
  /// All the arguments are optional. Configuration information is merely
  /// advisory and best-effort.
  const ImageConfiguration({
    this.bundle,
    this.devicePixelRatio,
    this.locale,
    this.textDirection,
    this.size,
    this.platform,
  });

  /// Creates an object holding the configuration information for an [ImageProvider].
  ///
  /// All the arguments are optional. Configuration information is merely
  /// advisory and best-effort.
  ImageConfiguration copyWith({
    AssetBundle? bundle,
    double? devicePixelRatio,
    Locale? locale,
    TextDirection? textDirection,
    Size? size,
    TargetPlatform? platform,
  }) {
    return ImageConfiguration(
      bundle: bundle ?? this.bundle,
      devicePixelRatio: devicePixelRatio ?? this.devicePixelRatio,
      locale: locale ?? this.locale,
      textDirection: textDirection ?? this.textDirection,
      size: size ?? this.size,
      platform: platform ?? this.platform,
    );
  }

  /// The preferred [AssetBundle] to use if the [ImageProvider] needs one and
  /// does not have one already selected.
  final AssetBundle? bundle;

  /// The device pixel ratio where the image will be shown.
  final double? devicePixelRatio;

  /// The language and region for which to select the image.
  final Locale? locale;

  /// The reading direction of the language for which to select the image.
  final TextDirection? textDirection;

  /// The size at which the image will be rendered.
  final Size? size;

  /// The [TargetPlatform] for which assets should be used. This allows images
  /// to be specified in a platform-neutral fashion yet use different assets on
  /// different platforms, to match local conventions e.g. for color matching or
  /// shadows.
  final TargetPlatform? platform;

  /// An image configuration that provides no additional information.
  ///
  /// Useful when resolving an [ImageProvider] without any context.
  static const ImageConfiguration empty = ImageConfiguration();

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType)
      return false;
    return other is ImageConfiguration
        && other.bundle == bundle
        && other.devicePixelRatio == devicePixelRatio
        && other.locale == locale
        && other.textDirection == textDirection
        && other.size == size
        && other.platform == platform;
  }

  @override
  int get hashCode => hashValues(bundle, devicePixelRatio, locale, size, platform);

  @override
  String toString() {
    final StringBuffer result = StringBuffer();
    result.write('ImageConfiguration(');
    bool hasArguments = false;
    if (bundle != null) {
      if (hasArguments)
        result.write(', ');
      result.write('bundle: $bundle');
      hasArguments = true;
    }
    if (devicePixelRatio != null) {
      if (hasArguments)
        result.write(', ');
      result.write('devicePixelRatio: ${devicePixelRatio!.toStringAsFixed(1)}');
      hasArguments = true;
    }
    if (locale != null) {
      if (hasArguments)
        result.write(', ');
      result.write('locale: $locale');
      hasArguments = true;
    }
    if (textDirection != null) {
      if (hasArguments)
        result.write(', ');
      result.write('textDirection: $textDirection');
      hasArguments = true;
    }
    if (size != null) {
      if (hasArguments)
        result.write(', ');
      result.write('size: $size');
      hasArguments = true;
    }
    if (platform != null) {
      if (hasArguments)
        result.write(', ');
      result.write('platform: ${describeEnum(platform!)}');
      hasArguments = true;
    }
    result.write(')');
    return result.toString();
  }
}

/// Performs the decode process for use in [ImageProvider.load].
///
/// This callback allows decoupling of the `cacheWidth`, `cacheHeight`, and
/// `allowUpscaling` parameters from implementations of [ImageProvider] that do
/// not expose them.
///
/// See also:
///
///  * [ResizeImage], which uses this to override the `cacheWidth`,
///    `cacheHeight`, and `allowUpscaling` parameters.
typedef DecoderCallback = Future<ui.Codec> Function(Uint8List bytes, {int? cacheWidth, int? cacheHeight, bool allowUpscaling});

/// Identifies an image without committing to the precise final asset. This
/// allows a set of images to be identified and for the precise image to later
/// be resolved based on the environment, e.g. the device pixel ratio.
///
/// To obtain an [ImageStream] from an [ImageProvider], call [resolve],
/// passing it an [ImageConfiguration] object.
///
/// [ImageProvider] uses the global [imageCache] to cache images.
///
/// The type argument `T` is the type of the object used to represent a resolved
/// configuration. This is also the type used for the key in the image cache. It
/// should be immutable and implement the [==] operator and the [hashCode]
/// getter. Subclasses should subclass a variant of [ImageProvider] with an
/// explicit `T` type argument.
///
/// The type argument does not have to be specified when using the type as an
/// argument (where any image provider is acceptable).
///
/// The following image formats are supported: {@macro flutter.dart:ui.imageFormats}
///
/// ## Lifecycle of resolving an image
///
/// The [ImageProvider] goes through the following lifecycle to resolve an
/// image, once the [resolve] method is called:
///
///   1. Create an [ImageStream] using [createStream] to return to the caller.
///      This stream will be used to communicate back to the caller when the
///      image is decoded and ready to display, or when an error occurs.
///   2. Obtain the key for the image using [obtainKey].
///      Calling this method can throw exceptions into the zone asynchronously
///      or into the callstack synchronously. To handle that, an error handler
///      is created that catches both synchronous and asynchronous errors, to
///      make sure errors can be routed to the correct consumers.
///      The error handler is passed on to [resolveStreamForKey] and the
///      [ImageCache].
///   3. If the key is successfully obtained, schedule resolution of the image
///      using that key. This is handled by [resolveStreamForKey]. That method
///      may fizzle if it determines the image is no longer necessary, use the
///      provided [ImageErrorListener] to report an error, set the completer
///      from the cache if possible, or call [load] to fetch the encoded image
///      bytes and schedule decoding.
///   4. The [load] method is responsible for both fetching the encoded bytes
///      and decoding them using the provided [DecoderCallback]. It is called
///      in a context that uses the [ImageErrorListener] to report errors back.
///
/// Subclasses normally only have to implement the [load] and [obtainKey]
/// methods. A subclass that needs finer grained control over the [ImageStream]
/// type must override [createStream]. A subclass that needs finer grained
/// control over the resolution, such as delaying calling [load], must override
/// [resolveStreamForKey].
///
/// The [resolve] method is marked as [nonVirtual] so that [ImageProvider]s can
/// be properly composed, and so that the base class can properly set up error
/// handling for subsequent methods.
///
/// ## Using an [ImageProvider]
///
/// {@tool snippet}
///
/// The following shows the code required to write a widget that fully conforms
/// to the [ImageProvider] and [Widget] protocols. (It is essentially a
/// bare-bones version of the [widgets.Image] widget.)
///
/// ```dart
/// class MyImage extends StatefulWidget {
///   const MyImage({
///     Key? key,
///     required this.imageProvider,
///   }) : super(key: key);
///
///   final ImageProvider imageProvider;
///
///   @override
///   _MyImageState createState() => _MyImageState();
/// }
///
/// class _MyImageState extends State<MyImage> {
///   ImageStream? _imageStream;
///   ImageInfo? _imageInfo;
///
///   @override
///   void didChangeDependencies() {
///     super.didChangeDependencies();
///     // We call _getImage here because createLocalImageConfiguration() needs to
///     // be called again if the dependencies changed, in case the changes relate
///     // to the DefaultAssetBundle, MediaQuery, etc, which that method uses.
///     _getImage();
///   }
///
///   @override
///   void didUpdateWidget(MyImage oldWidget) {
///     super.didUpdateWidget(oldWidget);
///     if (widget.imageProvider != oldWidget.imageProvider)
///       _getImage();
///   }
///
///   void _getImage() {
///     final ImageStream? oldImageStream = _imageStream;
///     _imageStream = widget.imageProvider.resolve(createLocalImageConfiguration(context));
///     if (_imageStream!.key != oldImageStream?.key) {
///       // If the keys are the same, then we got the same image back, and so we don't
///       // need to update the listeners. If the key changed, though, we must make sure
///       // to switch our listeners to the new image stream.
///       final ImageStreamListener listener = ImageStreamListener(_updateImage);
///       oldImageStream?.removeListener(listener);
///       _imageStream!.addListener(listener);
///     }
///   }
///
///   void _updateImage(ImageInfo imageInfo, bool synchronousCall) {
///     setState(() {
///       // Trigger a build whenever the image changes.
///       _imageInfo?.dispose();
///       _imageInfo = imageInfo;
///     });
///   }
///
///   @override
///   void dispose() {
///     _imageStream?.removeListener(ImageStreamListener(_updateImage));
///     _imageInfo?.dispose();
///     _imageInfo = null;
///     super.dispose();
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return RawImage(
///       image: _imageInfo?.image, // this is a dart:ui Image object
///       scale: _imageInfo?.scale ?? 1.0,
///     );
///   }
/// }
/// ```
/// {@end-tool}
@optionalTypeArgs
abstract class ImageProvider<T extends Object> {
  /// Abstract const constructor. This constructor enables subclasses to provide
  /// const constructors so that they can be used in const expressions.
  const ImageProvider();

  /// Resolves this image provider using the given `configuration`, returning
  /// an [ImageStream].
  ///
  /// This is the public entry-point of the [ImageProvider] class hierarchy.
  ///
  /// Subclasses should implement [obtainKey] and [load], which are used by this
  /// method. If they need to change the implementation of [ImageStream] used,
  /// they should override [createStream]. If they need to manage the actual
  /// resolution of the image, they should override [resolveStreamForKey].
  ///
  /// See the Lifecycle documentation on [ImageProvider] for more information.
  @nonVirtual
  ImageStream resolve(ImageConfiguration configuration) {
    assert(configuration != null);
    final ImageStream stream = createStream(configuration);
    // Load the key (potentially asynchronously), set up an error handling zone,
    // and call resolveStreamForKey.
    _createErrorHandlerAndKey(
      configuration,
      (T key, ImageErrorListener errorHandler) {
        resolveStreamForKey(configuration, stream, key, errorHandler);
      },
      (T? key, Object exception, StackTrace? stack) async {
        await null; // wait an event turn in case a listener has been added to the image stream.
        final _ErrorImageCompleter imageCompleter = _ErrorImageCompleter();
        stream.setCompleter(imageCompleter);
        InformationCollector? collector;
        assert(() {
          collector = () sync* {
            yield DiagnosticsProperty<ImageProvider>('Image provider', this);
            yield DiagnosticsProperty<ImageConfiguration>('Image configuration', configuration);
            yield DiagnosticsProperty<T>('Image key', key, defaultValue: null);
          };
          return true;
        }());
        imageCompleter.setError(
          exception: exception,
          stack: stack,
          context: ErrorDescription('while resolving an image'),
          silent: true, // could be a network error or whatnot
          informationCollector: collector,
        );
      },
    );
    return stream;
  }

  /// Called by [resolve] to create the [ImageStream] it returns.
  ///
  /// Subclasses should override this instead of [resolve] if they need to
  /// return some subclass of [ImageStream]. The stream created here will be
  /// passed to [resolveStreamForKey].
  @protected
  ImageStream createStream(ImageConfiguration configuration) {
    return ImageStream();
  }

  /// Returns the cache location for the key that this [ImageProvider] creates.
  ///
  /// The location may be [ImageCacheStatus.untracked], indicating that this
  /// image provider's key is not available in the [ImageCache].
  ///
  /// The `cache` and `configuration` parameters must not be null. If the
  /// `handleError` parameter is null, errors will be reported to
  /// [FlutterError.onError], and the method will return null.
  ///
  /// A completed return value of null indicates that an error has occurred.
  Future<ImageCacheStatus?> obtainCacheStatus({
    required ImageConfiguration configuration,
    ImageErrorListener? handleError,
  }) {
    assert(configuration != null);
    final Completer<ImageCacheStatus?> completer = Completer<ImageCacheStatus?>();
    _createErrorHandlerAndKey(
      configuration,
      (T key, ImageErrorListener innerHandleError) {
        completer.complete(PaintingBinding.instance!.imageCache!.statusForKey(key));
      },
      (T? key, Object exception, StackTrace? stack) async {
        if (handleError != null) {
          handleError(exception, stack);
        } else {
          InformationCollector? collector;
          assert(() {
            collector = () sync* {
              yield DiagnosticsProperty<ImageProvider>('Image provider', this);
              yield DiagnosticsProperty<ImageConfiguration>('Image configuration', configuration);
              yield DiagnosticsProperty<T>('Image key', key, defaultValue: null);
            };
            return true;
          }());
          FlutterError.reportError(FlutterErrorDetails(
            context: ErrorDescription('while checking the cache location of an image'),
            informationCollector: collector,
            exception: exception,
            stack: stack,
          ));
          completer.complete(null);
        }
      },
    );
    return completer.future;
  }

  /// This method is used by both [resolve] and [obtainCacheStatus] to ensure
  /// that errors thrown during key creation are handled whether synchronous or
  /// asynchronous.
  void _createErrorHandlerAndKey(
    ImageConfiguration configuration,
    _KeyAndErrorHandlerCallback<T> successCallback,
    _AsyncKeyErrorHandler<T?> errorCallback,
  ) {
    T? obtainedKey;
    bool didError = false;
    Future<void> handleError(Object exception, StackTrace? stack) async {
      if (didError) {
        return;
      }
      if (!didError) {
        errorCallback(obtainedKey, exception, stack);
      }
      didError = true;
    }

    // If an error is added to a synchronous completer before a listener has been
    // added, it can throw an error both into the zone and up the stack. Thus, it
    // looks like the error has been caught, but it is in fact also bubbling to the
    // zone. Since we cannot prevent all usage of Completer.sync here, or rather
    // that changing them would be too breaking, we instead hook into the same
    // zone mechanism to intercept the uncaught error and deliver it to the
    // image stream's error handler. Note that these errors may be duplicated,
    // hence the need for the `didError` flag.
    final Zone dangerZone = Zone.current.fork(
      specification: ZoneSpecification(
        handleUncaughtError: (Zone zone, ZoneDelegate delegate, Zone parent, Object error, StackTrace stackTrace) {
          handleError(error, stackTrace);
        }
      )
    );
    dangerZone.runGuarded(() {
      Future<T> key;
      try {
        key = obtainKey(configuration);
      } catch (error, stackTrace) {
        handleError(error, stackTrace);
        return;
      }
      key.then<void>((T key) {
        obtainedKey = key;
        try {
          successCallback(key, handleError);
        } catch (error, stackTrace) {
          handleError(error, stackTrace);
        }
      }).catchError(handleError);
    });
  }

  /// Called by [resolve] with the key returned by [obtainKey].
  ///
  /// Subclasses should override this method rather than calling [obtainKey] if
  /// they need to use a key directly. The [resolve] method installs appropriate
  /// error handling guards so that errors will bubble up to the right places in
  /// the framework, and passes those guards along to this method via the
  /// [handleError] parameter.
  ///
  /// It is safe for the implementation of this method to call [handleError]
  /// multiple times if multiple errors occur, or if an error is thrown both
  /// synchronously into the current part of the stack and thrown into the
  /// enclosing [Zone].
  ///
  /// The default implementation uses the key to interact with the [ImageCache],
  /// calling [ImageCache.putIfAbsent] and notifying listeners of the [stream].
  /// Implementers that do not call super are expected to correctly use the
  /// [ImageCache].
  @protected
  void resolveStreamForKey(ImageConfiguration configuration, ImageStream stream, T key, ImageErrorListener handleError) {
    // This is an unusual edge case where someone has told us that they found
    // the image we want before getting to this method. We should avoid calling
    // load again, but still update the image cache with LRU information.
    if (stream.completer != null) {
      final ImageStreamCompleter? completer = PaintingBinding.instance!.imageCache!.putIfAbsent(
        key,
        () => stream.completer!,
        onError: handleError,
      );
      assert(identical(completer, stream.completer));
      return;
    }
    final ImageStreamCompleter? completer = PaintingBinding.instance!.imageCache!.putIfAbsent(
      key,
      () => load(key, PaintingBinding.instance!.instantiateImageCodec),
      onError: handleError,
    );
    if (completer != null) {
      stream.setCompleter(completer);
    }
  }

  /// Evicts an entry from the image cache.
  ///
  /// Returns a [Future] which indicates whether the value was successfully
  /// removed.
  ///
  /// The [ImageProvider] used does not need to be the same instance that was
  /// passed to an [Image] widget, but it does need to create a key which is
  /// equal to one.
  ///
  /// The [cache] is optional and defaults to the global image cache.
  ///
  /// The [configuration] is optional and defaults to
  /// [ImageConfiguration.empty].
  ///
  /// {@tool snippet}
  ///
  /// The following sample code shows how an image loaded using the [Image]
  /// widget can be evicted using a [NetworkImage] with a matching URL.
  ///
  /// ```dart
  /// class MyWidget extends StatelessWidget {
  ///   final String url = '...';
  ///
  ///   @override
  ///   Widget build(BuildContext context) {
  ///     return Image.network(url);
  ///   }
  ///
  ///   void evictImage() {
  ///     final NetworkImage provider = NetworkImage(url);
  ///     provider.evict().then<void>((bool success) {
  ///       if (success)
  ///         debugPrint('removed image!');
  ///     });
  ///   }
  /// }
  /// ```
  /// {@end-tool}
  Future<bool> evict({ ImageCache? cache, ImageConfiguration configuration = ImageConfiguration.empty }) async {
    cache ??= imageCache;
    final T key = await obtainKey(configuration);
    return cache!.evict(key);
  }

  /// Converts an ImageProvider's settings plus an ImageConfiguration to a key
  /// that describes the precise image to load.
  ///
  /// The type of the key is determined by the subclass. It is a value that
  /// unambiguously identifies the image (_including its scale_) that the [load]
  /// method will fetch. Different [ImageProvider]s given the same constructor
  /// arguments and [ImageConfiguration] objects should return keys that are
  /// '==' to each other (possibly by using a class for the key that itself
  /// implements [==]).
  Future<T> obtainKey(ImageConfiguration configuration);

  /// Converts a key into an [ImageStreamCompleter], and begins fetching the
  /// image.
  ///
  /// The [decode] callback provides the logic to obtain the codec for the
  /// image.
  ///
  /// See also:
  ///
  ///  * [ResizeImage], for modifying the key to account for cache dimensions.
  @protected
  ImageStreamCompleter load(T key, DecoderCallback decode);

  @override
  String toString() => '${objectRuntimeType(this, 'ImageConfiguration')}()';
}

/// Key for the image obtained by an [AssetImage] or [ExactAssetImage].
///
/// This is used to identify the precise resource in the [imageCache].
@immutable
class AssetBundleImageKey {
  /// Creates the key for an [AssetImage] or [AssetBundleImageProvider].
  ///
  /// The arguments must not be null.
  const AssetBundleImageKey({
    required this.bundle,
    required this.name,
    required this.scale,
  }) : assert(bundle != null),
       assert(name != null),
       assert(scale != null);

  /// The bundle from which the image will be obtained.
  ///
  /// The image is obtained by calling [AssetBundle.load] on the given [bundle]
  /// using the key given by [name].
  final AssetBundle bundle;

  /// The key to use to obtain the resource from the [bundle]. This is the
  /// argument passed to [AssetBundle.load].
  final String name;

  /// The scale to place in the [ImageInfo] object of the image.
  final double scale;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType)
      return false;
    return other is AssetBundleImageKey
        && other.bundle == bundle
        && other.name == name
        && other.scale == scale;
  }

  @override
  int get hashCode => hashValues(bundle, name, scale);

  @override
  String toString() => '${objectRuntimeType(this, 'AssetBundleImageKey')}(bundle: $bundle, name: "$name", scale: $scale)';
}

/// A subclass of [ImageProvider] that knows about [AssetBundle]s.
///
/// This factors out the common logic of [AssetBundle]-based [ImageProvider]
/// classes, simplifying what subclasses must implement to just [obtainKey].
abstract class AssetBundleImageProvider extends ImageProvider<AssetBundleImageKey> {
  /// Abstract const constructor. This constructor enables subclasses to provide
  /// const constructors so that they can be used in const expressions.
  const AssetBundleImageProvider();

  /// Converts a key into an [ImageStreamCompleter], and begins fetching the
  /// image.
  @override
  ImageStreamCompleter load(AssetBundleImageKey key, DecoderCallback decode) {
    InformationCollector? collector;
    assert(() {
      collector = () sync* {
        yield DiagnosticsProperty<ImageProvider>('Image provider', this);
        yield DiagnosticsProperty<AssetBundleImageKey>('Image key', key);
      };
      return true;
    }());
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: key.scale,
      debugLabel: key.name,
      informationCollector: collector
    );
  }

  /// Fetches the image from the asset bundle, decodes it, and returns a
  /// corresponding [ImageInfo] object.
  ///
  /// This function is used by [load].
  @protected
  Future<ui.Codec> _loadAsync(AssetBundleImageKey key, DecoderCallback decode) async {
    ByteData? data;
    // Hot reload/restart could change whether an asset bundle or key in a
    // bundle are available, or if it is a network backed bundle.
    try {
      data = await key.bundle.load(key.name);
    } on FlutterError {
      PaintingBinding.instance!.imageCache!.evict(key);
      rethrow;
    }
    // `key.bundle.load` has a non-nullable return type, but might be null when
    // running with weak checking, so we need to null check it anyway (and
    // ignore the warning that the null-handling logic is dead code).
    if (data == null) { // ignore: dead_code
      PaintingBinding.instance!.imageCache!.evict(key);
      throw StateError('Unable to read data');
    }
    return await decode(data.buffer.asUint8List());
  }
}

@immutable
class _SizeAwareCacheKey {
  const _SizeAwareCacheKey(this.providerCacheKey, this.width, this.height);

  final Object providerCacheKey;

  final int? width;

  final int? height;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType)
      return false;
    return other is _SizeAwareCacheKey
        && other.providerCacheKey == providerCacheKey
        && other.width == width
        && other.height == height;
  }

  @override
  int get hashCode => hashValues(providerCacheKey, width, height);
}

/// Instructs Flutter to decode the image at the specified dimensions
/// instead of at its native size.
///
/// This allows finer control of the size of the image in [ImageCache] and is
/// generally used to reduce the memory footprint of [ImageCache].
///
/// The decoded image may still be displayed at sizes other than the
/// cached size provided here.
class ResizeImage extends ImageProvider<_SizeAwareCacheKey> {
  /// Creates an ImageProvider that decodes the image to the specified size.
  ///
  /// The cached image will be directly decoded and stored at the resolution
  /// defined by `width` and `height`. The image will lose detail and
  /// use less memory if resized to a size smaller than the native size.
  const ResizeImage(
    this.imageProvider, {
    this.width,
    this.height,
    this.allowUpscaling = false,
  }) : assert(width != null || height != null),
       assert(allowUpscaling != null);

  /// The [ImageProvider] that this class wraps.
  final ImageProvider imageProvider;

  /// The width the image should decode to and cache.
  final int? width;

  /// The height the image should decode to and cache.
  final int? height;

  /// Whether the [width] and [height] parameters should be clamped to the
  /// intrinsic width and height of the image.
  ///
  /// In general, it is better for memory usage to avoid scaling the image
  /// beyond its intrinsic dimensions when decoding it. If there is a need to
  /// scale an image larger, it is better to apply a scale to the canvas, or
  /// to use an appropriate [Image.fit].
  final bool allowUpscaling;

  /// Composes the `provider` in a [ResizeImage] only when `cacheWidth` and
  /// `cacheHeight` are not both null.
  ///
  /// When `cacheWidth` and `cacheHeight` are both null, this will return the
  /// `provider` directly.
  static ImageProvider<Object> resizeIfNeeded(int? cacheWidth, int? cacheHeight, ImageProvider<Object> provider) {
    if (cacheWidth != null || cacheHeight != null) {
      return ResizeImage(provider, width: cacheWidth, height: cacheHeight);
    }
    return provider;
  }

  @override
  ImageStreamCompleter load(_SizeAwareCacheKey key, DecoderCallback decode) {
    final DecoderCallback decodeResize = (Uint8List bytes, {int? cacheWidth, int? cacheHeight, bool? allowUpscaling}) {
      assert(
        cacheWidth == null && cacheHeight == null && allowUpscaling == null,
        'ResizeImage cannot be composed with another ImageProvider that applies '
        'cacheWidth, cacheHeight, or allowUpscaling.'
      );
      return decode(bytes, cacheWidth: width, cacheHeight: height, allowUpscaling: this.allowUpscaling);
    };
    final ImageStreamCompleter completer = imageProvider.load(key.providerCacheKey, decodeResize);
    if (!kReleaseMode) {
      completer.debugLabel = '${completer.debugLabel} - Resized(${key.width}×${key.height})';
    }
    return completer;
  }

  @override
  Future<_SizeAwareCacheKey> obtainKey(ImageConfiguration configuration) {
    Completer<_SizeAwareCacheKey>? completer;
    // If the imageProvider.obtainKey future is synchronous, then we will be able to fill in result with
    // a value before completer is initialized below.
    SynchronousFuture<_SizeAwareCacheKey>? result;
    imageProvider.obtainKey(configuration).then((Object key) {
      if (completer == null) {
        // This future has completed synchronously (completer was never assigned),
        // so we can directly create the synchronous result to return.
        result = SynchronousFuture<_SizeAwareCacheKey>(_SizeAwareCacheKey(key, width, height));
      } else {
        // This future did not synchronously complete.
        completer.complete(_SizeAwareCacheKey(key, width, height));
      }
    });
    if (result != null) {
      return result!;
    }
    // If the code reaches here, it means the imageProvider.obtainKey was not
    // completed sync, so we initialize the completer for completion later.
    completer = Completer<_SizeAwareCacheKey>();
    return completer.future;
  }
}

/// Decodes the given [Uint8List] buffer as an image, associating it with the
/// given scale.
///
/// The provided [bytes] buffer should not be changed after it is provided
/// to a [MemoryImage]. To provide an [ImageStream] that represents an image
/// that changes over time, consider creating a new subclass of [ImageProvider]
/// whose [load] method returns a subclass of [ImageStreamCompleter] that can
/// handle providing multiple images.
///
/// See also:
///
///  * [Image.memory] for a shorthand of an [Image] widget backed by [MemoryImage].
@immutable
class MemoryImage extends ImageProvider<MemoryImage> {
  /// Creates an object that decodes a [Uint8List] buffer as an image.
  ///
  /// The arguments must not be null.
  const MemoryImage(this.bytes, { this.scale = 1.0 })
    : assert(bytes != null),
      assert(scale != null);

  /// The bytes to decode into an image.
  final Uint8List bytes;

  /// The scale to place in the [ImageInfo] object of the image.
  final double scale;

  @override
  Future<MemoryImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<MemoryImage>(this);
  }

  @override
  ImageStreamCompleter load(MemoryImage key, DecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: key.scale,
      debugLabel: 'MemoryImage(${describeIdentity(key.bytes)})',
    );
  }

  Future<ui.Codec> _loadAsync(MemoryImage key, DecoderCallback decode) {
    assert(key == this);

    return decode(bytes);
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType)
      return false;
    return other is MemoryImage
        && other.bytes == bytes
        && other.scale == scale;
  }

  @override
  int get hashCode => hashValues(bytes.hashCode, scale);

  @override
  String toString() => '${objectRuntimeType(this, 'MemoryImage')}(${describeIdentity(bytes)}, scale: $scale)';
}

/// Fetches an image from an [AssetBundle], associating it with the given scale.
///
/// This implementation requires an explicit final [assetName] and [scale] on
/// construction, and ignores the device pixel ratio and size in the
/// configuration passed into [resolve]. For a resolution-aware variant that
/// uses the configuration to pick an appropriate image based on the device
/// pixel ratio and size, see [AssetImage].
///
/// ## Fetching assets
///
/// When fetching an image provided by the app itself, use the [assetName]
/// argument to name the asset to choose. For instance, consider a directory
/// `icons` with an image `heart.png`. First, the `pubspec.yaml` of the project
/// should specify its assets in the `flutter` section:
///
/// ```yaml
/// flutter:
///   assets:
///     - icons/heart.png
/// ```
///
/// Then, to fetch the image and associate it with scale `1.5`, use:
///
/// ```dart
/// AssetImage('icons/heart.png', scale: 1.5)
/// ```
///
/// ## Assets in packages
///
/// To fetch an asset from a package, the [package] argument must be provided.
/// For instance, suppose the structure above is inside a package called
/// `my_icons`. Then to fetch the image, use:
///
/// ```dart
/// AssetImage('icons/heart.png', scale: 1.5, package: 'my_icons')
/// ```
///
/// Assets used by the package itself should also be fetched using the [package]
/// argument as above.
///
/// If the desired asset is specified in the `pubspec.yaml` of the package, it
/// is bundled automatically with the app. In particular, assets used by the
/// package itself must be specified in its `pubspec.yaml`.
///
/// A package can also choose to have assets in its 'lib/' folder that are not
/// specified in its `pubspec.yaml`. In this case for those images to be
/// bundled, the app has to specify which ones to include. For instance a
/// package named `fancy_backgrounds` could have:
///
/// ```
/// lib/backgrounds/background1.png
/// lib/backgrounds/background2.png
/// lib/backgrounds/background3.png
/// ```
///
/// To include, say the first image, the `pubspec.yaml` of the app should specify
/// it in the `assets` section:
///
/// ```yaml
///   assets:
///     - packages/fancy_backgrounds/backgrounds/background1.png
/// ```
///
/// The `lib/` is implied, so it should not be included in the asset path.
///
/// See also:
///
///  * [Image.asset] for a shorthand of an [Image] widget backed by
///    [ExactAssetImage] when using a scale.
@immutable
class ExactAssetImage extends AssetBundleImageProvider {
  /// Creates an object that fetches the given image from an asset bundle.
  ///
  /// The [assetName] and [scale] arguments must not be null. The [scale] arguments
  /// defaults to 1.0. The [bundle] argument may be null, in which case the
  /// bundle provided in the [ImageConfiguration] passed to the [resolve] call
  /// will be used instead.
  ///
  /// The [package] argument must be non-null when fetching an asset that is
  /// included in a package. See the documentation for the [ExactAssetImage] class
  /// itself for details.
  const ExactAssetImage(
    this.assetName, {
    this.scale = 1.0,
    this.bundle,
    this.package,
  }) : assert(assetName != null),
       assert(scale != null);

  /// The name of the asset.
  final String assetName;

  /// The key to use to obtain the resource from the [bundle]. This is the
  /// argument passed to [AssetBundle.load].
  String get keyName => package == null ? assetName : 'packages/$package/$assetName';

  /// The scale to place in the [ImageInfo] object of the image.
  final double scale;

  /// The bundle from which the image will be obtained.
  ///
  /// If the provided [bundle] is null, the bundle provided in the
  /// [ImageConfiguration] passed to the [resolve] call will be used instead. If
  /// that is also null, the [rootBundle] is used.
  ///
  /// The image is obtained by calling [AssetBundle.load] on the given [bundle]
  /// using the key given by [keyName].
  final AssetBundle? bundle;

  /// The name of the package from which the image is included. See the
  /// documentation for the [ExactAssetImage] class itself for details.
  final String? package;

  @override
  Future<AssetBundleImageKey> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<AssetBundleImageKey>(AssetBundleImageKey(
      bundle: bundle ?? configuration.bundle ?? rootBundle,
      name: keyName,
      scale: scale,
    ));
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType)
      return false;
    return other is ExactAssetImage
        && other.keyName == keyName
        && other.scale == scale
        && other.bundle == bundle;
  }

  @override
  int get hashCode => hashValues(keyName, scale, bundle);

  @override
  String toString() => '${objectRuntimeType(this, 'ExactAssetImage')}(name: "$keyName", scale: $scale, bundle: $bundle)';
}

// A completer used when resolving an image fails sync.
class _ErrorImageCompleter extends ImageStreamCompleter {
  _ErrorImageCompleter();

  void setError({
    DiagnosticsNode? context,
    required Object exception,
    StackTrace? stack,
    InformationCollector? informationCollector,
    bool silent = false,
  }) {
    reportError(
      context: context,
      exception: exception,
      stack: stack,
      informationCollector: informationCollector,
      silent: silent,
    );
  }
}

/// The exception thrown when the HTTP request to load a network image fails.
class NetworkImageLoadException implements Exception {
  /// Creates a [NetworkImageLoadException] with the specified http [statusCode]
  /// and [uri].
  NetworkImageLoadException({required this.statusCode, required this.uri})
      : assert(uri != null),
        assert(statusCode != null),
        _message = 'HTTP request failed, statusCode: $statusCode, $uri';

  /// The HTTP status code from the server.
  final int statusCode;

  /// A human-readable error message.
  final String _message;

  /// Resolved URL of the requested image.
  final Uri uri;

  @override
  String toString() => _message;
}
