import 'package:js/js.dart';

@JS('window.flutterCanvasKit')
external set _windowFlutterCanvasKit(Object? value);

Future<void> initializeEngine() async {
  // Pretend that CanvasKit exists. Flute doesn't render anything, but we're
  // interested in exercising the CanvasKit codepaths in the framework.
  _windowFlutterCanvasKit = Object();
}
