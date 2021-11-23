// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.


import 'package:flute/ui.dart';

import 'message_codecs.dart';
import 'platform_channel.dart';

/// Platform channels used by the Flutter system.
class SystemChannels {
  // This class is not meant to be instantiated or extended; this constructor
  // prevents instantiation and extension.
  // ignore: unused_element
  SystemChannels._();

  /// A JSON [MethodChannel] for navigation.
  ///
  /// The following incoming methods are defined for this channel (registered
  /// using [MethodChannel.setMethodCallHandler]):
  ///
  ///  * `popRoute`, which is called when the system wants the current route to
  ///    be removed (e.g. if the user hits a system-level back button).
  ///
  ///  * `pushRoute`, which is called with a single string argument when the
  ///    operating system instructs the application to open a particular page.
  ///
  ///  * `pushRouteInformation`, which is called with a map, which contains a
  ///    location string and a state object, when the operating system instructs
  ///    the application to open a particular page. These parameters are stored
  ///    under the key `location` and `state` in the map.
  ///
  /// The following methods are used for the opposite direction data flow. The
  /// framework notifies the engine about the route changes.
  ///
  ///  * `routeUpdated`, which is called when current route has changed.
  ///
  ///  * `routeInformationUpdated`, which is called by the [Router] when the
  ///    application navigate to a new location.
  ///
  /// See also:
  ///
  ///  * [WidgetsBindingObserver.didPopRoute] and
  ///    [WidgetsBindingObserver.didPushRoute], which expose this channel's
  ///    methods.
  ///  * [Navigator] which manages transitions from one page to another.
  ///    [Navigator.push], [Navigator.pushReplacement], [Navigator.pop] and
  ///    [Navigator.replace], utilize this channel's methods to send route
  ///    change information from framework to engine.
  static const MethodChannel navigation = OptionalMethodChannel(
      'flutter/navigation',
      JSONMethodCodec(),
  );

  /// A JSON [MethodChannel] for invoking miscellaneous platform methods.
  ///
  /// The following outgoing methods are defined for this channel (invoked using
  /// [OptionalMethodChannel.invokeMethod]):
  ///
  ///  * `Clipboard.setData`: Places the data from the `text` entry of the
  ///    argument, which must be a [Map], onto the system clipboard. See
  ///    [Clipboard.setData].
  ///
  ///  * `Clipboard.getData`: Returns the data that has the format specified in
  ///    the argument, a [String], from the system clipboard. The only format
  ///    currently supported is `text/plain` ([Clipboard.kTextPlain]). The
  ///    result is a [Map] with a single key, `text`. See [Clipboard.getData].
  ///
  ///  * `HapticFeedback.vibrate`: Triggers a system-default haptic response.
  ///    See [HapticFeedback.vibrate].
  ///
  ///  * `SystemSound.play`: Triggers a system audio effect. The argument must
  ///    be a [String] describing the desired effect; currently only `click` is
  ///    supported. See [SystemSound.play].
  ///
  ///  * `SystemChrome.setPreferredOrientations`: Informs the operating system
  ///    of the desired orientation of the display. The argument is a [List] of
  ///    values which are string representations of values of the
  ///    [DeviceOrientation] enum. See [SystemChrome.setPreferredOrientations].
  ///
  ///  * `SystemChrome.setApplicationSwitcherDescription`: Informs the operating
  ///    system of the desired label and color to be used to describe the
  ///    application in any system-level application lists (e.g. application
  ///    switchers). The argument is a [Map] with two keys, `label` giving a
  ///    [String] description, and `primaryColor` giving a 32 bit integer value
  ///    (the lower eight bits being the blue channel, the next eight bits being
  ///    the green channel, the next eight bits being the red channel, and the
  ///    high eight bits being set, as from [Color.value] for an opaque color).
  ///    The `primaryColor` can also be zero to indicate that the system default
  ///    should be used. See [SystemChrome.setApplicationSwitcherDescription].
  ///
  ///  * `SystemChrome.setEnabledSystemUIOverlays`: Specifies the set of system
  ///    overlays to have visible when the application is running. The argument
  ///    is a [List] of values which are string representations of values of the
  ///    [SystemUiOverlay] enum. See [SystemChrome.setEnabledSystemUIOverlays].
  ///
  ///  * `SystemChrome.setSystemUIOverlayStyle`: Specifies whether system
  ///    overlays (e.g. the status bar on Android or iOS) should be `light` or
  ///    `dark`. The argument is one of those two strings. See
  ///    [SystemChrome.setSystemUIOverlayStyle].
  ///
  ///  * `SystemNavigator.pop`: Tells the operating system to close the
  ///    application, or the closest equivalent. See [SystemNavigator.pop].
  ///
  /// Calls to methods that are not implemented on the shell side are ignored
  /// (so it is safe to call methods when the relevant plugin might be missing).
  static const MethodChannel platform = OptionalMethodChannel(
      'flutter/platform',
      JSONMethodCodec(),
  );

  /// A JSON [MethodChannel] for handling text input.
  ///
  /// This channel exposes a system text input control for interacting with IMEs
  /// (input method editors, for example on-screen keyboards). There is one
  /// control, and at any time it can have one active transaction. Transactions
  /// are represented by an integer. New Transactions are started by
  /// `TextInput.setClient`. Messages that are sent are assumed to be for the
  /// current transaction (the last "client" set by `TextInput.setClient`).
  /// Messages received from the shell side specify the transaction to which
  /// they apply, so that stale messages referencing past transactions can be
  /// ignored.
  ///
  /// The methods described below are wrapped in a more convenient form by the
  /// [TextInput] and [TextInputConnection] class.
  ///
  /// The following outgoing methods are defined for this channel (invoked using
  /// [OptionalMethodChannel.invokeMethod]):
  ///
  ///  * `TextInput.setClient`: Establishes a new transaction. The arguments is
  ///    a [List] whose first value is an integer representing a previously
  ///    unused transaction identifier, and the second is a [String] with a
  ///    JSON-encoded object with five keys, as obtained from
  ///    [TextInputConfiguration.toJson]. This method must be invoked before any
  ///    others (except `TextInput.hide`). See [TextInput.attach].
  ///
  ///  * `TextInput.show`: Show the keyboard. See [TextInputConnection.show].
  ///
  ///  * `TextInput.setEditingState`: Update the value in the text editing
  ///    control. The argument is a [String] with a JSON-encoded object with
  ///    seven keys, as obtained from [TextEditingValue.toJSON]. See
  ///    [TextInputConnection.setEditingState].
  ///
  ///  * `TextInput.clearClient`: End the current transaction. The next method
  ///    called must be `TextInput.setClient` (or `TextInput.hide`). See
  ///    [TextInputConnection.close].
  ///
  ///  * `TextInput.hide`: Hide the keyboard. Unlike the other methods, this can
  ///    be called at any time. See [TextInputConnection.close].
  ///
  /// The following incoming methods are defined for this channel (registered
  /// using [MethodChannel.setMethodCallHandler]). In each case, the first argument
  /// is a transaction identifier. Calls for stale transactions should be ignored.
  ///
  ///  * `TextInputClient.updateEditingState`: The user has changed the contents
  ///    of the text control. The second argument is a [String] containing a
  ///    JSON-encoded object with seven keys, in the form expected by
  ///    [TextEditingValue.fromJSON].
  ///
  ///  * `TextInputClient.performAction`: The user has triggered an action. The
  ///    second argument is a [String] consisting of the stringification of one
  ///    of the values of the [TextInputAction] enum.
  ///
  ///  * `TextInputClient.requestExistingInputState`: The embedding may have
  ///    lost its internal state about the current editing client, if there is
  ///    one. The framework should call `TextInput.setClient` and
  ///    `TextInput.setEditingState` again with its most recent information. If
  ///    there is no existing state on the framework side, the call should
  ///    fizzle.
  ///
  ///  * `TextInputClient.onConnectionClosed`: The text input connection closed
  ///    on the platform side. For example the application is moved to
  ///    background or used closed the virtual keyboard. This method informs
  ///    [TextInputClient] to clear connection and finalize editing.
  ///    `TextInput.clearClient` and `TextInput.hide` is not called after
  ///    clearing the connection since on the platform side the connection is
  ///    already finalized.
  ///
  /// Calls to methods that are not implemented on the shell side are ignored
  /// (so it is safe to call methods when the relevant plugin might be missing).
  static const MethodChannel textInput = OptionalMethodChannel(
      'flutter/textinput',
      JSONMethodCodec(),
  );

  /// A JSON [BasicMessageChannel] for keyboard events.
  ///
  /// Each incoming message received on this channel (registered using
  /// [BasicMessageChannel.setMessageHandler]) consists of a [Map] with
  /// platform-specific data, plus a `type` field which is either `keydown`, or
  /// `keyup`.
  ///
  /// On Android, the available fields are those described by
  /// [RawKeyEventDataAndroid]'s properties.
  ///
  /// On Fuchsia, the available fields are those described by
  /// [RawKeyEventDataFuchsia]'s properties.
  ///
  /// No messages are sent on other platforms currently.
  ///
  /// See also:
  ///
  ///  * [RawKeyboard], which uses this channel to expose key data.
  ///  * [new RawKeyEvent.fromMessage], which can decode this data into the [RawKeyEvent]
  ///    subclasses mentioned above.
  static const BasicMessageChannel<dynamic> keyEvent = BasicMessageChannel<dynamic>(
      'flutter/keyevent',
      JSONMessageCodec(),
  );

  /// A string [BasicMessageChannel] for lifecycle events.
  ///
  /// Valid messages are string representations of the values of the
  /// [AppLifecycleState] enumeration. A handler can be registered using
  /// [BasicMessageChannel.setMessageHandler].
  ///
  /// See also:
  ///
  ///  * [WidgetsBindingObserver.didChangeAppLifecycleState], which triggers
  ///    whenever a message is received on this channel.
  static const BasicMessageChannel<String?> lifecycle = BasicMessageChannel<String?>(
      'flutter/lifecycle',
      StringCodec(),
  );

  /// A JSON [BasicMessageChannel] for system events.
  ///
  /// Events are exposed as [Map]s with string keys. The `type` key specifies
  /// the type of the event; the currently supported system event types are
  /// those listed below. A handler can be registered using
  /// [BasicMessageChannel.setMessageHandler].
  ///
  ///  * `memoryPressure`: Indicates that the operating system would like
  ///    applications to release caches to free up more memory. See
  ///    [WidgetsBindingObserver.didHaveMemoryPressure], which triggers whenever
  ///    a message is received on this channel.
  static const BasicMessageChannel<dynamic> system = BasicMessageChannel<dynamic>(
      'flutter/system',
      JSONMessageCodec(),
  );

  /// A [BasicMessageChannel] for accessibility events.
  ///
  /// See also:
  ///
  ///  * [SemanticsEvent] and its subclasses for a list of valid accessibility
  ///    events that can be sent over this channel.
  ///  * [SemanticsNode.sendEvent], which uses this channel to dispatch events.
  static const BasicMessageChannel<dynamic> accessibility = BasicMessageChannel<dynamic>(
    'flutter/accessibility',
    StandardMessageCodec(),
  );

  /// A [MethodChannel] for controlling platform views.
  ///
  /// See also:
  ///
  ///  * [PlatformViewsService] for the available operations on this channel.
  static const MethodChannel platform_views = MethodChannel(
    'flutter/platform_views',
    StandardMethodCodec(),
  );

  /// A [MethodChannel] for configuring the Skia graphics library.
  ///
  /// The following outgoing methods are defined for this channel (invoked using
  /// [OptionalMethodChannel.invokeMethod]):
  ///
  ///  * `Skia.setResourceCacheMaxBytes`: Set the maximum number of bytes that
  ///    can be held in the GPU resource cache.
  static const MethodChannel skia = MethodChannel(
    'flutter/skia',
    JSONMethodCodec(),
  );

  /// A [MethodChannel] for configuring mouse cursors.
  ///
  /// All outgoing methods defined for this channel uses a `Map<String, dynamic>`
  /// to contain multiple parameters, including the following methods (invoked
  /// using [OptionalMethodChannel.invokeMethod]):
  ///
  ///  * `activateSystemCursor`: Request to set the cursor of a pointer
  ///    device to a system cursor. The parameters are
  ///    integer `device`, and string `kind`.
  static const MethodChannel mouseCursor = OptionalMethodChannel(
    'flutter/mousecursor',
    StandardMethodCodec(),
  );

  /// A [MethodChannel] for synchronizing restoration data with the engine.
  ///
  /// The following outgoing methods are defined for this channel (invoked using
  /// [OptionalMethodChannel.invokeMethod]):
  ///
  ///  * `get`: Retrieves the current restoration information (e.g. provided by
  ///    the operating system) from the engine. The method returns a map
  ///    containing an `enabled` boolean to indicate whether collecting
  ///    restoration data is supported by the embedder. If `enabled` is true,
  ///    the map may also contain restoration data stored under the `data` key
  ///    from which the state of the framework may be restored. The restoration
  ///    data is encoded as [Uint8List].
  ///  * `put`: Sends the current restoration data to the engine. Takes the
  ///    restoration data encoded as [Uint8List] as argument.
  ///
  /// The following incoming methods are defined for this channel (registered
  /// using [MethodChannel.setMethodCallHandler]).
  ///
  ///  * `push`: Called by the engine to send newly provided restoration
  ///    information to the framework. The argument given to this method has
  ///    the same format as the object that the `get` method returns.
  ///
  /// See also:
  ///
  ///  * [RestorationManager], which uses this channel and also describes how
  ///    restoration data is used in Flutter.
  static const MethodChannel restoration = OptionalMethodChannel(
    'flutter/restoration',
    StandardMethodCodec(),
  );

  /// A [MethodChannel] for installing and managing dynamic features.
  ///
  /// The following outgoing methods are defined for this channel (invoked using
  /// [OptionalMethodChannel.invokeMethod]):
  ///
  ///  * `installDynamicFeature`: Requests that a dynamic feature identified by
  ///    the provided loadingUnitId or moduleName be downloaded and installed.
  ///    Providing a loadingUnitId with null moduleName will install a dynamic
  ///    feature module that includes the desired loading unit. If a moduleName
  ///    is provided, then the dynamic feature with the moduleName will be installed.
  ///    This method returns a future that will not be completed until the
  ///    feature is fully installed and ready to use. When an error occurs, the
  ///    future will complete an error. Calling `loadLibrary()` on a deferred
  ///    imported library is equivalent to calling this method with a
  ///    loadingUnitId and null moduleName.
  ///  * `getDynamicFeatureInstallState`: Gets the current installation state of
  ///    the dynamic feature identified by the loadingUnitId or moduleName.
  ///    This method returns a string that represents the state. Depending on
  ///    the implementation, this string may vary, but the default Google Play
  ///    Store implementation beings in the "Requested" state before transitioning
  ///    into the "Downloading" and finally the "Installed" state.
  static const MethodChannel dynamicfeature = OptionalMethodChannel(
    'flutter/dynamicfeature',
    StandardMethodCodec(),
  );
}
