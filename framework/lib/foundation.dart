// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Core Flutter framework primitives.
///
/// The features defined in this library are the lowest-level utility
/// classes and functions used by all the other layers of the Flutter
/// framework.
library foundation;

export 'package:meta/meta.dart' show
  factory,
  immutable,
  mustCallSuper,
  nonVirtual,
  optionalTypeArgs,
  protected,
  required,
  visibleForTesting;

// Examples can assume:
// // @dart = 2.9
// String _name;
// bool _first;
// bool _lights;
// bool _visible;
// bool inherit;
// int columns;
// int rows;
// class Cat { }
// double _volume;
// dynamic _calculation;
// dynamic _last;
// dynamic _selection;

export 'src/foundation/annotations.dart';
export 'src/foundation/assertions.dart';
export 'src/foundation/basic_types.dart';
export 'src/foundation/binding.dart';
export 'src/foundation/bitfield.dart';
export 'src/foundation/change_notifier.dart';
export 'src/foundation/collections.dart';
export 'src/foundation/constants.dart';
export 'src/foundation/debug.dart';
export 'src/foundation/diagnostics.dart';
export 'src/foundation/isolates.dart';
export 'src/foundation/key.dart';
export 'src/foundation/licenses.dart';
export 'src/foundation/node.dart';
export 'src/foundation/object.dart';
export 'src/foundation/observer_list.dart';
export 'src/foundation/platform.dart';
export 'src/foundation/print.dart';
export 'src/foundation/serialization.dart';
export 'src/foundation/stack_frame.dart';
export 'src/foundation/synchronous_future.dart';
export 'src/foundation/unicode.dart';
