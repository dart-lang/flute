// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flute/rendering.dart';

import 'basic.dart';
import 'framework.dart';

/// An interface for widgets that can return the size this widget would prefer
/// if it were otherwise unconstrained.
///
/// There are a few cases, notably [AppBar] and [TabBar], where it would be
/// undesirable for the widget to constrain its own size but where the widget
/// needs to expose a preferred or "default" size. For example a primary
/// [Scaffold] sets its app bar height to the app bar's preferred height
/// plus the height of the system status bar.
///
/// Use [PreferredSize] to give a preferred size to an arbitrary widget.
abstract class PreferredSizeWidget implements Widget {
  /// The size this widget would prefer if it were otherwise unconstrained.
  ///
  /// In many cases it's only necessary to define one preferred dimension.
  /// For example the [Scaffold] only depends on its app bar's preferred
  /// height. In that case implementations of this method can just return
  /// `new Size.fromHeight(myAppBarHeight)`.
  Size get preferredSize;
}

/// A widget with a preferred size.
///
/// This widget does not impose any constraints on its child, and it doesn't
/// affect the child's layout in any way. It just advertises a preferred size
/// which can be used by the parent.
///
/// Widgets like [AppBar] implement a [PreferredSizeWidget].
///
/// {@tool dartpad --template=stateless_widget_material}
///
/// This sample shows a custom widget, similar to an [AppBar], which uses a
/// [PreferredSize] widget, with its height set to 80 logical pixels.
/// Changing the [PreferredSize] can be used to change the height
/// of the custom app bar.
///
/// ```dart preamble
/// class AppBarContent extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return Column(
///       mainAxisAlignment: MainAxisAlignment.end,
///       children: [
///         Padding(
///           padding: const EdgeInsets.symmetric(horizontal: 10),
///           child: Row(
///             children: [
///               Text(
///                 "PreferredSize Sample",
///                 style: TextStyle(color: Colors.white),
///               ),
///               Spacer(),
///               IconButton(
///                 icon: Icon(
///                   Icons.search,
///                   size: 20,
///                 ),
///                 color: Colors.white,
///                 onPressed: () {},
///               ),
///               IconButton(
///                 icon: Icon(
///                   Icons.more_vert,
///                   size: 20,
///                 ),
///                 color: Colors.white,
///                 onPressed: () {},
///               ),
///             ],
///           ),
///         ),
///       ],
///     );
///   }
/// }
/// ```
///```dart
/// Widget build(BuildContext context) {
///   return Scaffold(
///     appBar: PreferredSize(
///       preferredSize: const Size.fromHeight(80.0),
///       child: Container(
///         decoration: BoxDecoration(
///           gradient: LinearGradient(
///             colors: [Colors.blue, Colors.pink],
///           ),
///         ),
///         child: AppBarContent(),
///       ),
///     ),
///     body: Center(
///       child: Text("Content"),
///     ),
///   );
/// }
/// ```
/// {@end-tool}
///
/// See also:
///
///  * [AppBar.bottom] and [Scaffold.appBar], which require preferred size widgets.
///  * [PreferredSizeWidget], the interface which this widget implements to expose
///    its preferred size.
///  * [AppBar] and [TabBar], which implement PreferredSizeWidget.
class PreferredSize extends StatelessWidget implements PreferredSizeWidget {
  /// Creates a widget that has a preferred size.
  const PreferredSize({
    Key? key,
    required this.child,
    required this.preferredSize,
  }) : super(key: key);

  /// The widget below this widget in the tree.
  ///
  /// {@macro flutter.widgets.ProxyWidget.child}
  final Widget child;

  @override
  final Size preferredSize;

  @override
  Widget build(BuildContext context) => child;
}
