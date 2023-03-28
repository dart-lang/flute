// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:engine/ui.dart' show PlatformDispatcher;

void initializeBenchmarkHarness(String name, List<String> args) {
  final int startOfMain = DateTime.now().microsecondsSinceEpoch;

  if (args.isEmpty) {
    // Run in default mode, rather than as a Golem benchmark.
    return;
  }

  // First argument is time since epoch as measured just prior to launching the
  // benchmark, in seconds, formatted as a decimal number, i.e. the output of
  // `date '+%s.%N'`.
  final int beforeStart = (double.parse(args[0]) * 1000000).toInt();
  final int timeToMain = startOfMain - beforeStart;
  print('$name.TimeToMain(StartupTime): $timeToMain us.');

  // Second argument (optional) is number of frames to measure, default 1000.
  final int framesToTime = args.length < 2 ? 1000 : int.parse(args[1]);

  // Third argument (optional) is number of frames to skip before starting the
  // measurement, default 10.
  final int framesToSkip = args.length < 3 ? 10 : int.parse(args[2]);

  double buildSum = 0;
  double drawSum = 0;

  bool averagesPrinted = false;

  bool frameCallback(int frameCount, double buildTime, double drawTime) {
    if (frameCount == 1) {
      final int afterFirstFrame = DateTime.now().microsecondsSinceEpoch;
      final int timeToFirstFrame = afterFirstFrame - beforeStart;
      print('$name.TimeToFirstFrame(StartupTime): $timeToFirstFrame us.');
    }

    if (frameCount > framesToSkip + framesToTime) {
      if (!averagesPrinted) {
        final int averageBuild = (buildSum / framesToTime * 1000).toInt();
        print('$name.AverageBuild(RunTimeRaw): $averageBuild us.');
        final int averageDraw = (drawSum / framesToTime * 1000).toInt();
        print('$name.AverageDraw(RunTimeRaw): $averageDraw us.');
        final int averageFrame =
            ((buildSum + drawSum) / framesToTime * 1000).toInt();
        print('$name.AverageFrame(RunTime): $averageFrame us.');
        averagesPrinted = true;
      }
      return false;
    }

    if (frameCount > framesToSkip) {
      buildSum += buildTime;
      drawSum += drawTime;
    }

    return true;
  }

  PlatformDispatcher.frameCallback = frameCallback;
}
