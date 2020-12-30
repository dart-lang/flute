// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

void exit(int exitCode) {
  print('Pretending the app exiting.');
  throw Exception('Exiting with exit code $exitCode');
}

class Platform {
  static String get operatingSystem => 'Android';
  static bool get isAndroid => true;
  static bool get isIOS => false;
  static String get resolvedExecutable => '/path/to/App';
  static String get pathSeparator => '/';
}
