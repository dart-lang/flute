library dart.ui;

import 'dart:async';
import 'dart:collection' as collection;
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:isolate' show SendPort;
import 'dart:math' as math;
import 'dart:typed_data';

import 'src/initialization_io.dart'
  if (dart.library.js_interop) 'src/initialization_web.dart' as initialization;

part 'src/annotations.dart';
part 'src/channel_buffers.dart';
part 'src/compositing.dart';
part 'src/geometry.dart';
part 'src/hash_codes.dart';
part 'src/hooks.dart';
part 'src/isolate_name_server.dart';
part 'src/key.dart';
part 'src/lerp.dart';
part 'src/math.dart';
part 'src/natives.dart';
part 'src/painting.dart';
part 'src/platform_dispatcher.dart';
part 'src/plugins.dart';
part 'src/pointer.dart';
part 'src/semantics.dart';
part 'src/text.dart';
part 'src/window.dart';
part 'src/path/conic.dart';
part 'src/path/cubic.dart';
part 'src/path/path_iterator.dart';
part 'src/path/path_metrics.dart';
part 'src/path/path_ref.dart';
part 'src/path/path_to_svg.dart';
part 'src/path/path_utils.dart';
part 'src/path/path_windings.dart';
part 'src/path/path.dart';
part 'src/path/tangent.dart';

double _screenWidth = 1024;
double _screenHeight = 1024;

Future<void> initializeEngine({
  Size? screenSize,
}) async {
  if (screenSize != null) {
    _screenWidth = screenSize.width;
    _screenHeight = screenSize.height;
  }
  await initialization.initializeEngine();
}
