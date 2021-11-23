// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:ui/ui.dart' as ui;

import 'canvas.dart';
import 'canvaskit_api.dart';
import 'picture.dart';

class CkPictureRecorder implements ui.PictureRecorder {
  ui.Rect? _cullRect;
  SkPictureRecorder? _skRecorder;
  CkCanvas? _recordingCanvas;

  CkCanvas beginRecording(ui.Rect bounds) {
    _cullRect = bounds;
    final SkPictureRecorder recorder = _skRecorder = SkPictureRecorder();
    final Float32List skRect = toSkRect(bounds);
    final SkCanvas skCanvas = recorder.beginRecording(skRect);
    return _recordingCanvas = browserSupportsFinalizationRegistry
        ? CkCanvas(skCanvas)
        : RecordingCkCanvas(skCanvas, bounds);
  }

  CkCanvas? get recordingCanvas => _recordingCanvas;

  @override
  CkPicture endRecording() {
    final SkPictureRecorder? recorder = _skRecorder;

    if (recorder == null) {
      throw StateError('PictureRecorder is not recording');
    }

    final SkPicture skPicture = recorder.finishRecordingAsPicture();
    recorder.delete();
    _skRecorder = null;
    return CkPicture(skPicture, _cullRect, _recordingCanvas!.pictureSnapshot);
  }

  @override
  bool get isRecording => _skRecorder != null;
}
