import 'dart:js_interop';

@JS('window.flutterCanvasKit')
external set _windowFlutterCanvasKit(JSAny? value);

Future<void> initializeEngine() async {
  // Pretend that CanvasKit exists. Flute doesn't render anything, but we're
  // interested in exercising the CanvasKit codepaths in the framework.
  _windowFlutterCanvasKit = Object().toJSBox;
}
