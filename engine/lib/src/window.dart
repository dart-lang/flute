// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// See: https://github.com/dart-lang/linter/issues/2921
// ignore_for_file: use_late_for_private_fields_and_variables

part of dart.ui;

const int kImplicitViewId = 0;

class FlutterView {
  FlutterView._(this.viewId, this.platformDispatcher);

  /// The opaque ID for this view.
  final Object viewId;

  /// The platform dispatcher that this view is registered with, and gets its
  /// information from.
  final PlatformDispatcher platformDispatcher;

  ViewConfiguration get _viewConfiguration {
    final PlatformDispatcher engineDispatcher = platformDispatcher;
    assert(engineDispatcher.windowConfigurations.containsKey(viewId));
    return engineDispatcher.windowConfigurations[viewId] ??
        const ViewConfiguration();
  }

  double get devicePixelRatio => _viewConfiguration.devicePixelRatio;
  Rect get physicalGeometry => _viewConfiguration.geometry;
  Size get physicalSize => _viewConfiguration.geometry.size;
  ViewPadding get viewInsets => _viewConfiguration.viewInsets;
  ViewPadding get viewPadding => _viewConfiguration.viewPadding;
  ViewPadding get systemGestureInsets => _viewConfiguration.systemGestureInsets;
  ViewPadding get padding => _viewConfiguration.padding;
  GestureSettings get gestureSettings => _viewConfiguration.gestureSettings;
  List<DisplayFeature> get displayFeatures => _viewConfiguration.displayFeatures;

  void render(Scene scene) {
    // TODO(yjbanov): implement a basic preroll for better benchmark realism.
  }

  void updateSemantics(SemanticsUpdate update) {
    platformDispatcher.updateSemantics(update);
  }
}

class SingletonFlutterWindow extends FlutterView {
  SingletonFlutterWindow._(Object windowId, PlatformDispatcher platformDispatcher)
      : super._(windowId, platformDispatcher) {
    platformDispatcher._updateLifecycleState('resumed');
    _updateWindowMetrics(
      true, // isInitializing
      0, // id
      1.0, // devicePixelRatio
      // 4k
      _screenWidth, // width
      _screenHeight, // height
      0, // viewPaddingTop
      0, // viewPaddingRight
      0, // viewPaddingBottom
      0, // viewPaddingLeft
      0, // viewInsetTop
      0, // viewInsetRight
      0, // viewInsetBottom
      0, // viewInsetLeft
      0, // systemGestureInsetTop
      0, // systemGestureInsetRight
      0, // systemGestureInsetBottom
      0, // systemGestureInsetLeft
      0, // double physicalTouchSlop,
      const <double>[], // List<double> displayFeaturesBounds,
      const <int>[], // List<int> displayFeaturesType,
      const <int>[], // List<int> displayFeaturesState,
    );
  }

  VoidCallback? get onMetricsChanged => platformDispatcher.onMetricsChanged;
  set onMetricsChanged(VoidCallback? callback) {
    platformDispatcher.onMetricsChanged = callback;
  }

  Locale get locale => platformDispatcher.locale;

  List<Locale> get locales => platformDispatcher.locales;

  Locale? computePlatformResolvedLocale(List<Locale> supportedLocales) {
    return platformDispatcher.computePlatformResolvedLocale(supportedLocales);
  }

  VoidCallback? get onLocaleChanged => platformDispatcher.onLocaleChanged;
  set onLocaleChanged(VoidCallback? callback) {
    platformDispatcher.onLocaleChanged = callback;
  }

  String get initialLifecycleState => platformDispatcher.initialLifecycleState;

  double get textScaleFactor => platformDispatcher.textScaleFactor;

  bool get alwaysUse24HourFormat => platformDispatcher.alwaysUse24HourFormat;

  VoidCallback? get onTextScaleFactorChanged => platformDispatcher.onTextScaleFactorChanged;
  set onTextScaleFactorChanged(VoidCallback? callback) {
    platformDispatcher.onTextScaleFactorChanged = callback;
  }

  Brightness get platformBrightness => platformDispatcher.platformBrightness;

  VoidCallback? get onPlatformBrightnessChanged => platformDispatcher.onPlatformBrightnessChanged;
  set onPlatformBrightnessChanged(VoidCallback? callback) {
    platformDispatcher.onPlatformBrightnessChanged = callback;
  }

  FrameCallback? get onBeginFrame => platformDispatcher.onBeginFrame;
  set onBeginFrame(FrameCallback? callback) {
    platformDispatcher.onBeginFrame = callback;
  }

  VoidCallback? get onDrawFrame => platformDispatcher.onDrawFrame;
  set onDrawFrame(VoidCallback? callback) {
    platformDispatcher.onDrawFrame = callback;
  }

  TimingsCallback? get onReportTimings => platformDispatcher.onReportTimings;
  set onReportTimings(TimingsCallback? callback) {
    platformDispatcher.onReportTimings = callback;
  }

  PointerDataPacketCallback? get onPointerDataPacket => platformDispatcher.onPointerDataPacket;
  set onPointerDataPacket(PointerDataPacketCallback? callback) {
    platformDispatcher.onPointerDataPacket = callback;
  }

  String get defaultRouteName => platformDispatcher.defaultRouteName;

  void scheduleFrame() => platformDispatcher.scheduleFrame();

  bool get semanticsEnabled => platformDispatcher.semanticsEnabled;

  VoidCallback? get onSemanticsEnabledChanged => platformDispatcher.onSemanticsEnabledChanged;
  set onSemanticsEnabledChanged(VoidCallback? callback) {
    platformDispatcher.onSemanticsEnabledChanged = callback;
  }

  SemanticsActionCallback? get onSemanticsAction => platformDispatcher.onSemanticsAction;
  set onSemanticsAction(SemanticsActionCallback? callback) {
    platformDispatcher.onSemanticsAction = callback;
  }

  AccessibilityFeatures get accessibilityFeatures => platformDispatcher.accessibilityFeatures;

  VoidCallback? get onAccessibilityFeaturesChanged => platformDispatcher.onAccessibilityFeaturesChanged;
  set onAccessibilityFeaturesChanged(VoidCallback? callback) {
    platformDispatcher.onAccessibilityFeaturesChanged = callback;
  }

  @override
  void updateSemantics(SemanticsUpdate update) => platformDispatcher.updateSemantics(update);

  void sendPlatformMessage(String name,
      ByteData? data,
      PlatformMessageResponseCallback? callback) {
    platformDispatcher.sendPlatformMessage(name, data, callback);
  }

  PlatformMessageCallback? get onPlatformMessage => platformDispatcher.onPlatformMessage;
  set onPlatformMessage(PlatformMessageCallback? callback) {
    platformDispatcher.onPlatformMessage = callback;
  }

  void setIsolateDebugName(String name) => PlatformDispatcher.instance.setIsolateDebugName(name);
}

/// Additional accessibility features that may be enabled by the platform.
///
/// It is not possible to enable these settings from Flutter, instead they are
/// used by the platform to indicate that additional accessibility features are
/// enabled.
//
// When changes are made to this class, the equivalent APIs in each of the
// embedders *must* be updated.
class AccessibilityFeatures {
  const AccessibilityFeatures._(this._index);

  static const int _kAccessibleNavigation = 1 << 0;
  static const int _kInvertColorsIndex = 1 << 1;
  static const int _kDisableAnimationsIndex = 1 << 2;
  static const int _kBoldTextIndex = 1 << 3;
  static const int _kReduceMotionIndex = 1 << 4;
  static const int _kHighContrastIndex = 1 << 5;

  // A bitfield which represents each enabled feature.
  final int _index;

  /// Whether there is a running accessibility service which is changing the
  /// interaction model of the device.
  ///
  /// For example, TalkBack on Android and VoiceOver on iOS enable this flag.
  bool get accessibleNavigation => _kAccessibleNavigation & _index != 0;

  /// The platform is inverting the colors of the application.
  bool get invertColors => _kInvertColorsIndex & _index != 0;

  /// The platform is requesting that animations be disabled or simplified.
  bool get disableAnimations => _kDisableAnimationsIndex & _index != 0;

  /// The platform is requesting that text be rendered at a bold font weight.
  ///
  /// Only supported on iOS.
  bool get boldText => _kBoldTextIndex & _index != 0;

  /// The platform is requesting that certain animations be simplified and
  /// parallax effects removed.
  ///
  /// Only supported on iOS.
  bool get reduceMotion => _kReduceMotionIndex & _index != 0;

  /// The platform is requesting that UI be rendered with darker colors.
  ///
  /// Only supported on iOS.
  bool get highContrast => _kHighContrastIndex & _index != 0;

  @override
  String toString() {
    final List<String> features = <String>[];
    if (accessibleNavigation)
      features.add('accessibleNavigation');
    if (invertColors)
      features.add('invertColors');
    if (disableAnimations)
      features.add('disableAnimations');
    if (boldText)
      features.add('boldText');
    if (reduceMotion)
      features.add('reduceMotion');
    if (highContrast)
      features.add('highContrast');
    return 'AccessibilityFeatures$features';
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType)
      return false;
    return other is AccessibilityFeatures
        && other._index == _index;
  }

  @override
  int get hashCode => _index.hashCode;
}

/// Describes the contrast of a theme or color palette.
enum Brightness {
  /// The color is dark and will require a light text color to achieve readable
  /// contrast.
  ///
  /// For example, the color might be dark grey, requiring white text.
  dark,

  /// The color is light and will require a dark text color to achieve readable
  /// contrast.
  ///
  /// For example, the color might be bright white, requiring black text.
  light,
}

/// The [SingletonFlutterWindow] representing the main window for applications
/// where there is only one window, such as applications designed for
/// single-display mobile devices.
///
/// Applications that are designed to use more than one window should interact
/// with the `WidgetsBinding.instance.platformDispatcher` instead.
///
/// Consider avoiding static references to this singleton through
/// [PlatformDispatcher.instance] and instead prefer using a binding for
/// dependency resolution such as `WidgetsBinding.instance.window`.
///
/// Static access of this `window` object means that Flutter has few, if any
/// options to fake or mock the given object in tests. Even in cases where Dart
/// offers special language constructs to forcefully shadow such properties,
/// those mechanisms would only be reasonable for tests and they would not be
/// reasonable for a future of Flutter where we legitimately want to select an
/// appropriate implementation at runtime.
///
/// The only place that `WidgetsBinding.instance.window` is inappropriate is if
/// access to these APIs is required before the binding is initialized by
/// invoking `runApp()` or `WidgetsFlutterBinding.instance.ensureInitialized()`.
/// In that case, it is necessary (though unfortunate) to use the
/// [PlatformDispatcher.instance] object statically.
///
/// See also:
///
/// * [PlatformDispatcher.views], contains the current list of Flutter windows
///   belonging to the application, including top level application windows like
///   this one.
final SingletonFlutterWindow window = SingletonFlutterWindow._(0, PlatformDispatcher.instance);

class GestureSettings {
  const GestureSettings({
    this.physicalTouchSlop,
    this.physicalDoubleTapSlop,
  });

  final double? physicalTouchSlop;

  final double? physicalDoubleTapSlop;

  GestureSettings copyWith({
    double? physicalTouchSlop,
    double? physicalDoubleTapSlop,
  }) {
    return GestureSettings(
      physicalTouchSlop: physicalTouchSlop ?? this.physicalTouchSlop,
      physicalDoubleTapSlop: physicalDoubleTapSlop ?? this.physicalDoubleTapSlop,
    );
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is GestureSettings &&
      other.physicalTouchSlop == physicalTouchSlop &&
      other.physicalDoubleTapSlop == physicalDoubleTapSlop;
  }

  @override
  int get hashCode => Object.hash(physicalTouchSlop, physicalDoubleTapSlop);

  @override
  String toString() => 'GestureSettings(physicalTouchSlop: $physicalTouchSlop, physicalDoubleTapSlop: $physicalDoubleTapSlop)';
}
