// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.


import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flute/foundation.dart';

import 'binary_messenger.dart';

/// A collection of resources used by the application.
///
/// Asset bundles contain resources, such as images and strings, that can be
/// used by an application. Access to these resources is asynchronous so that
/// they can be transparently loaded over a network (e.g., from a
/// [NetworkAssetBundle]) or from the local file system without blocking the
/// application's user interface.
///
/// Applications have a [rootBundle], which contains the resources that were
/// packaged with the application when it was built. To add resources to the
/// [rootBundle] for your application, add them to the `assets` subsection of
/// the `flutter` section of your application's `pubspec.yaml` manifest.
///
/// For example:
///
/// ```yaml
/// name: my_awesome_application
/// flutter:
///   assets:
///    - images/hamilton.jpeg
///    - images/lafayette.jpeg
/// ```
///
/// Rather than accessing the [rootBundle] global static directly, consider
/// obtaining the [AssetBundle] for the current [BuildContext] using
/// [DefaultAssetBundle.of]. This layer of indirection lets ancestor widgets
/// substitute a different [AssetBundle] (e.g., for testing or localization) at
/// runtime rather than directly replying upon the [rootBundle] created at build
/// time. For convenience, the [WidgetsApp] or [MaterialApp] widget at the top
/// of the widget hierarchy configures the [DefaultAssetBundle] to be the
/// [rootBundle].
///
/// See also:
///
///  * [DefaultAssetBundle]
///  * [NetworkAssetBundle]
///  * [rootBundle]
abstract class AssetBundle {
  /// Retrieve a binary resource from the asset bundle as a data stream.
  ///
  /// Throws an exception if the asset is not found.
  Future<ByteData> load(String key);

  /// Retrieve a string from the asset bundle.
  ///
  /// Throws an exception if the asset is not found.
  ///
  /// If the `cache` argument is set to false, then the data will not be
  /// cached, and reading the data may bypass the cache. This is useful if the
  /// caller is going to be doing its own caching. (It might not be cached if
  /// it's set to true either, that depends on the asset bundle
  /// implementation.)
  ///
  /// If the `unzip` argument is set to true, it would first unzip file at the
  /// specified location before retrieving the string content.
  Future<String> loadString(
    String key,
    {
      bool cache = true,
      bool unzip = false,
    }
  ) async {
    final ByteData data = await load(key);
    // Note: data has a non-nullable type, but might be null when running with
    // weak checking, so we need to null check it anyway (and ignore the warning
    // that the null-handling logic is dead code).
    if (data == null)
      throw FlutterError('Unable to load asset: $key'); // ignore: dead_code
    // 50 KB of data should take 2-3 ms to parse on a Moto G4, and about 400 μs
    // on a Pixel 4.
    if (data.lengthInBytes < 50 * 1024 && !unzip) {
      return _utf8Decode(data);
    }

    // For strings larger than 50 KB, run the computation in an isolate to
    // avoid causing main thread jank.
    return compute(
      _utf8Decode,
      data,
      debugLabel: '${unzip ? "Unzip and ": ""}UTF8 decode for "$key"',
    );
  }

  static String _utf8Decode(ByteData data) {
    return utf8.decode(data.buffer.asUint8List());
  }

  /// Retrieve a string from the asset bundle, parse it with the given function,
  /// and return the function's result.
  ///
  /// Implementations may cache the result, so a particular key should only be
  /// used with one parser for the lifetime of the asset bundle.
  Future<T> loadStructuredData<T>(String key, Future<T> parser(String value));

  /// If this is a caching asset bundle, and the given key describes a cached
  /// asset, then evict the asset from the cache so that the next time it is
  /// loaded, the cache will be reread from the asset bundle.
  void evict(String key) { }

  @override
  String toString() => '${describeIdentity(this)}()';
}

/// An [AssetBundle] that permanently caches string and structured resources
/// that have been fetched.
///
/// Strings (for [loadString] and [loadStructuredData]) are decoded as UTF-8.
/// Data that is cached is cached for the lifetime of the asset bundle
/// (typically the lifetime of the application).
///
/// Binary resources (from [load]) are not cached.
abstract class CachingAssetBundle extends AssetBundle {
  // TODO(ianh): Replace this with an intelligent cache, see https://github.com/flutter/flutter/issues/3568
  final Map<String, Future<String>> _stringCache = <String, Future<String>>{};
  final Map<String, Future<dynamic>> _structuredDataCache = <String, Future<dynamic>>{};

  @override
  Future<String> loadString(String key, { bool cache = true, bool unzip = false }) {
    if (cache)
      return _stringCache.putIfAbsent(key, () => super.loadString(key, unzip: unzip));
    return super.loadString(key, unzip: unzip);
  }

  /// Retrieve a string from the asset bundle, parse it with the given function,
  /// and return the function's result.
  ///
  /// The result of parsing the string is cached (the string itself is not,
  /// unless you also fetch it with [loadString]). For any given `key`, the
  /// `parser` is only run the first time.
  ///
  /// Once the value has been parsed, the future returned by this function for
  /// subsequent calls will be a [SynchronousFuture], which resolves its
  /// callback synchronously.
  @override
  Future<T> loadStructuredData<T>(String key, Future<T> parser(String value)) {
    assert(key != null);
    assert(parser != null);
    if (_structuredDataCache.containsKey(key))
      return _structuredDataCache[key]! as Future<T>;
    Completer<T>? completer;
    Future<T>? result;
    loadString(key, cache: false).then<T>(parser).then<void>((T value) {
      result = SynchronousFuture<T>(value);
      _structuredDataCache[key] = result!;
      if (completer != null) {
        // We already returned from the loadStructuredData function, which means
        // we are in the asynchronous mode. Pass the value to the completer. The
        // completer's future is what we returned.
        completer.complete(value);
      }
    });
    if (result != null) {
      // The code above ran synchronously, and came up with an answer.
      // Return the SynchronousFuture that we created above.
      return result!;
    }
    // The code above hasn't yet run its "then" handler yet. Let's prepare a
    // completer for it to use when it does run.
    completer = Completer<T>();
    _structuredDataCache[key] = completer.future;
    return completer.future;
  }

  @override
  void evict(String key) {
    _stringCache.remove(key);
    _structuredDataCache.remove(key);
  }
}

/// An [AssetBundle] that loads resources using platform messages.
class PlatformAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final Uint8List encoded = utf8.encoder.convert(Uri(path: Uri.encodeFull(key)).path);
    final ByteData? asset =
        await defaultBinaryMessenger.send('flutter/assets', encoded.buffer.asByteData());
    if (asset == null)
      throw FlutterError('Unable to load asset: $key');
    return asset;
  }
}

AssetBundle _initRootBundle() {
  return PlatformAssetBundle();
}

/// The [AssetBundle] from which this application was loaded.
///
/// The [rootBundle] contains the resources that were packaged with the
/// application when it was built. To add resources to the [rootBundle] for your
/// application, add them to the `assets` subsection of the `flutter` section of
/// your application's `pubspec.yaml` manifest.
///
/// For example:
///
/// ```yaml
/// name: my_awesome_application
/// flutter:
///   assets:
///    - images/hamilton.jpeg
///    - images/lafayette.jpeg
/// ```
///
/// Rather than using [rootBundle] directly, consider obtaining the
/// [AssetBundle] for the current [BuildContext] using [DefaultAssetBundle.of].
/// This layer of indirection lets ancestor widgets substitute a different
/// [AssetBundle] at runtime (e.g., for testing or localization) rather than
/// directly replying upon the [rootBundle] created at build time. For
/// convenience, the [WidgetsApp] or [MaterialApp] widget at the top of the
/// widget hierarchy configures the [DefaultAssetBundle] to be the [rootBundle].
///
/// See also:
///
///  * [DefaultAssetBundle]
///  * [NetworkAssetBundle]
final AssetBundle rootBundle = _initRootBundle();
