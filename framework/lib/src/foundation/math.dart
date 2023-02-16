// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Same as [num.clamp] but optimized for non-null [double].
///
/// This is faster because it avoids polymorphism, boxing, and special cases for
/// floating point numbers.
//
// See also: //dev/benchmarks/microbenchmarks/lib/foundation/clamp.dart

export 'package:engine/ui.dart' show clampDouble;