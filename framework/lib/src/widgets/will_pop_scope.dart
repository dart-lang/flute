// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'framework.dart';
import 'navigator.dart';
import 'routes.dart';

/// Registers a callback to veto attempts by the user to dismiss the enclosing
/// [ModalRoute].
///
/// {@tool snippet --template=stateful_widget}
///
/// Whenever the back button is pressed, you will get a callback at [onWillPop],
/// which returns a [Future]. If the [Future] returns true, the screen is
/// popped.
///
/// ```dart
/// bool shouldPop = true;
/// @override
/// Widget build(BuildContext context) {
///   return WillPopScope (
///     onWillPop: () async {
///       return shouldPop;
///     },
///     child: Text('WillPopScope sample'),
///   );
/// }
/// ```
/// {@end-tool}
///
/// {@tool dartpad --template=stateful_widget_material_no_null_safety}
/// ```dart
/// bool shouldPop = true;
/// @override
/// Widget build(BuildContext context) {
///   return WillPopScope(
///     onWillPop: () async {
///       return shouldPop;
///     },
///     child: Scaffold(
///       appBar: AppBar(
///         title: Text("Flutter WillPopScope demo"),
///       ),
///       body: Center(
///         child: Column(
///           mainAxisAlignment: MainAxisAlignment.center,
///           children: [
///             OutlinedButton(
///               child: Text('Push'),
///               onPressed: () {
///                 Navigator.of(context).push(
///                   MaterialPageRoute(
///                     builder: (context) {
///                       return MyStatefulWidget();
///                     },
///                   ),
///                 );
///               },
///             ),
///             OutlinedButton(
///               child: Text('shouldPop: $shouldPop'),
///               onPressed: () {
///                 setState(
///                   () {
///                     shouldPop = !shouldPop;
///                   },
///                 );
///               },
///             ),
///             Text("Push to a new screen, then tap on shouldPop "
///                 "button to toggle its value. Press the back "
///                 "button in the appBar to check its behaviour "
///                 "for different values of shouldPop"),
///           ],
///         ),
///       ),
///     ),
///   );
/// }
/// ```
///
/// {@end-tool}
///
/// See also:
///
///  * [ModalRoute.addScopedWillPopCallback] and [ModalRoute.removeScopedWillPopCallback],
///    which this widget uses to register and unregister [onWillPop].
///  * [Form], which provides an `onWillPop` callback that enables the form
///    to veto a `pop` initiated by the app's back button.
///
class WillPopScope extends StatefulWidget {
  /// Creates a widget that registers a callback to veto attempts by the user to
  /// dismiss the enclosing [ModalRoute].
  ///
  /// The [child] argument must not be null.
  const WillPopScope({
    Key? key,
    required this.child,
    required this.onWillPop,
  }) : assert(child != null),
       super(key: key);

  /// The widget below this widget in the tree.
  ///
  /// {@macro flutter.widgets.ProxyWidget.child}
  final Widget child;

  /// Called to veto attempts by the user to dismiss the enclosing [ModalRoute].
  ///
  /// If the callback returns a Future that resolves to false, the enclosing
  /// route will not be popped.
  final WillPopCallback? onWillPop;

  @override
  _WillPopScopeState createState() => _WillPopScopeState();
}

class _WillPopScopeState extends State<WillPopScope> {
  ModalRoute<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.onWillPop != null)
      _route?.removeScopedWillPopCallback(widget.onWillPop!);
    _route = ModalRoute.of(context);
    if (widget.onWillPop != null)
      _route?.addScopedWillPopCallback(widget.onWillPop!);
  }

  @override
  void didUpdateWidget(WillPopScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(_route == ModalRoute.of(context));
    if (widget.onWillPop != oldWidget.onWillPop && _route != null) {
      if (oldWidget.onWillPop != null)
        _route!.removeScopedWillPopCallback(oldWidget.onWillPop!);
      if (widget.onWillPop != null)
        _route!.addScopedWillPopCallback(widget.onWillPop!);
    }
  }

  @override
  void dispose() {
    if (widget.onWillPop != null)
      _route?.removeScopedWillPopCallback(widget.onWillPop!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
