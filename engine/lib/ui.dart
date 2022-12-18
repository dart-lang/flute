library dart.ui;

import 'dart:async';
import 'dart:collection' as collection;
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:isolate' show SendPort;
import 'dart:math' as math;
import 'dart:typed_data';

part 'src/annotations.dart';
part 'src/channel_buffers.dart';
part 'src/compositing.dart';
part 'src/geometry.dart';
part 'src/hash_codes.dart';
part 'src/hooks.dart';
part 'src/isolate_name_server.dart';
part 'src/lerp.dart';
part 'src/natives.dart';
part 'src/painting.dart';
part 'src/platform_dispatcher.dart';
part 'src/plugins.dart';
part 'src/pointer.dart';
part 'src/semantics.dart';
part 'src/text.dart';
part 'src/window.dart';

double _screenWidth = 1024;
double _screenHeight = 1024;

void setScreenSize(double width, double height) {
  _screenWidth = width;
  _screenHeight = height;
}
