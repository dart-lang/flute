// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:ui/ui.dart';

/// How to compare pixels within the image.
///
/// Keep this enum in sync with the one defined in `goldens.dart`.
enum PixelComparison {
  /// Allows minor blur and anti-aliasing differences by comparing a 3x3 grid
  /// surrounding the pixel rather than direct 1:1 comparison.
  fuzzy,

  /// Compares one pixel at a time.
  ///
  /// Anti-aliasing or blur will result in higher diff rate.
  precise,
}

Future<void> matchGoldenFile(String filename,
    {bool write = false, Rect? region, double? maxDiffRatePercent, PixelComparison pixelComparison = PixelComparison.fuzzy}) async {
}
