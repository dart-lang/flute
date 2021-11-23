// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:flute/ui.dart';

import 'package:flute/foundation.dart';
import 'package:flute/gestures.dart';
import 'package:flute/painting.dart';
import 'package:flute/services.dart';

import 'binding.dart';
import 'focus_scope.dart';
import 'focus_traversal.dart';
import 'framework.dart';

// Used for debugging focus code. Set to true to see highly verbose debug output
// when focus changes occur.
const bool _kDebugFocus = false;

bool _focusDebug(String message, [Iterable<String>? details]) {
  if (_kDebugFocus) {
    debugPrint('FOCUS: $message');
    if (details != null && details.isNotEmpty) {
      for (final String detail in details) {
        debugPrint('    $detail');
      }
    }
  }
  return true;
}

/// An enum that describes how to handle a key event handled by a
/// [FocusOnKeyCallback].
enum KeyEventResult {
  /// The key event has been handled, and the event should not be propagated to
  /// other key event handlers.
  handled,
  /// The key event has not been handled, and the event should continue to be
  /// propagated to other key event handlers, even non-Flutter ones.
  ignored,
  /// The key event has not been handled, but the key event should not be
  /// propagated to other key event handlers.
  ///
  /// It will be returned to the platform embedding to be propagated to text
  /// fields and non-Flutter key event handlers on the platform.
  skipRemainingHandlers,
}

/// Signature of a callback used by [Focus.onKey] and [FocusScope.onKey]
/// to receive key events.
///
/// The [node] is the node that received the event.
///
/// Returns a [KeyEventResult] that describes how, and whether, the key event
/// was handled.
// TODO(gspencergoog): Convert this from dynamic to KeyEventResult once migration is complete.
typedef FocusOnKeyCallback = dynamic Function(FocusNode node, RawKeyEvent event);

/// An attachment point for a [FocusNode].
///
/// Using a [FocusAttachment] is rarely needed, unless you are building
/// something akin to the [Focus] or [FocusScope] widgets from scratch.
///
/// Once created, a [FocusNode] must be attached to the widget tree by its
/// _host_ [StatefulWidget] via a [FocusAttachment] object. [FocusAttachment]s
/// are owned by the [StatefulWidget] that hosts a [FocusNode] or
/// [FocusScopeNode]. There can be multiple [FocusAttachment]s for each
/// [FocusNode], but the node will only ever be attached to one of them at a
/// time.
///
/// This attachment is created by calling [FocusNode.attach], usually from the
/// host widget's [State.initState] method. If the widget is updated to have a
/// different focus node, then the new node needs to be attached in
/// [State.didUpdateWidget], after calling [detach] on the previous
/// [FocusAttachment]. Once detached, the attachment is defunct and will no
/// longer make changes to the [FocusNode] through [reparent].
///
/// Without these attachment points, it would be possible for a focus node to
/// simultaneously be attached to more than one part of the widget tree during
/// the build stage.
class FocusAttachment {
  /// A private constructor, because [FocusAttachment]s are only to be created
  /// by [FocusNode.attach].
  FocusAttachment._(this._node) : assert(_node != null);

  // The focus node that this attachment manages an attachment for. The node may
  // not yet have a parent, or may have been detached from this attachment, so
  // don't count on this node being in a usable state.
  final FocusNode _node;

  /// Returns true if the associated node is attached to this attachment.
  ///
  /// It is possible to be attached to the widget tree, but not be placed in
  /// the focus tree (i.e. to not have a parent yet in the focus tree).
  bool get isAttached => _node._attachment == this;

  /// Detaches the [FocusNode] this attachment point is associated with from the
  /// focus tree, and disconnects it from this attachment point.
  ///
  /// Calling [FocusNode.dispose] will also automatically detach the node.
  void detach() {
    assert(_node != null);
    assert(_focusDebug('Detaching node:', <String>[_node.toString(), 'With enclosing scope ${_node.enclosingScope}']));
    if (isAttached) {
      if (_node.hasPrimaryFocus || (_node._manager != null && _node._manager!._markedForFocus == _node)) {
        _node.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
      }
      // This node is no longer in the tree, so shouldn't send notifications anymore.
      _node._manager?._markDetached(_node);
      _node._parent?._removeChild(_node);
      _node._attachment = null;
      assert(!_node.hasPrimaryFocus);
      assert(_node._manager?._markedForFocus != _node);
    }
    assert(!isAttached);
  }

  /// Ensures that the [FocusNode] attached at this attachment point has the
  /// proper parent node, changing it if necessary.
  ///
  /// If given, ensures that the given [parent] node is the parent of the node
  /// that is attached at this attachment point, changing it if necessary.
  /// However, it is usually not necessary to supply an explicit parent, since
  /// [reparent] will use [Focus.of] to determine the correct parent node for
  /// the context given in [FocusNode.attach].
  ///
  /// If [isAttached] is false, then calling this method does nothing.
  ///
  /// Should be called whenever the associated widget is rebuilt in order to
  /// maintain the focus hierarchy.
  ///
  /// A [StatefulWidget] that hosts a [FocusNode] should call this method on the
  /// node it hosts during its [State.build] or [State.didChangeDependencies]
  /// methods in case the widget is moved from one location in the tree to
  /// another location that has a different [FocusScope] or context.
  ///
  /// The optional [parent] argument must be supplied when not using [Focus] and
  /// [FocusScope] widgets to build the focus tree, or if there is a need to
  /// supply the parent explicitly (which are both uncommon).
  void reparent({FocusNode? parent}) {
    assert(_node != null);
    if (isAttached) {
      assert(_node.context != null);
      parent ??= Focus.maybeOf(_node.context!, scopeOk: true);
      parent ??= _node.context!.owner!.focusManager.rootScope;
      assert(parent != null);
      parent._reparent(_node);
    }
  }
}

/// Describe what should happen after [FocusNode.unfocus] is called.
///
/// See also:
///
///  * [FocusNode.unfocus], which takes this as its `disposition` parameter.
enum UnfocusDisposition {
  /// Focus the nearest focusable enclosing scope of this node, but do not
  /// descend to locate the leaf [FocusScopeNode.focusedChild] the way
  /// [previouslyFocusedChild] does.
  ///
  /// Focusing the scope in this way clears the [FocusScopeNode.focusedChild]
  /// history for the enclosing scope when it receives focus. Because of this,
  /// calling a traversal method like [FocusNode.nextFocus] after unfocusing
  /// will cause the [FocusTraversalPolicy] to pick the node it thinks should be
  /// first in the scope.
  ///
  /// This is the default disposition for [FocusNode.unfocus].
  scope,

  /// Focus the previously focused child of the nearest focusable enclosing
  /// scope of this node.
  ///
  /// If there is no previously focused child, then this is equivalent to
  /// using the [scope] disposition.
  ///
  /// Unfocusing with this disposition will cause [FocusNode.unfocus] to walk up
  /// the tree to the nearest focusable enclosing scope, then start to walk down
  /// the tree, looking for a focused child at its
  /// [FocusScopeNode.focusedChild].
  ///
  /// If the [FocusScopeNode.focusedChild] is a scope, then look for its
  /// [FocusScopeNode.focusedChild], and so on, finding the leaf
  /// [FocusScopeNode.focusedChild] that is not a scope, or, failing that, a
  /// leaf scope that has no focused child.
  previouslyFocusedChild,
}

/// An object that can be used by a stateful widget to obtain the keyboard focus
/// and to handle keyboard events.
///
/// _Please see the [Focus] and [FocusScope] widgets, which are utility widgets
/// that manage their own [FocusNode]s and [FocusScopeNode]s, respectively. If
/// they aren't appropriate, [FocusNode]s can be managed directly, but doing
/// this yourself is rare._
///
/// [FocusNode]s are persistent objects that form a _focus tree_ that is a
/// representation of the widgets in the hierarchy that are interested in focus.
/// A focus node might need to be created if it is passed in from an ancestor of
/// a [Focus] widget to control the focus of the children from the ancestor, or
/// a widget might need to host one if the widget subsystem is not being used,
/// or if the [Focus] and [FocusScope] widgets provide insufficient control.
///
/// [FocusNode]s are organized into _scopes_ (see [FocusScopeNode]), which form
/// sub-trees of nodes that restrict traversal to a group of nodes. Within a
/// scope, the most recent nodes to have focus are remembered, and if a node is
/// focused and then unfocused, the previous node receives focus again.
///
/// The focus node hierarchy can be traversed using the [parent], [children],
/// [ancestors] and [descendants] accessors.
///
/// [FocusNode]s are [ChangeNotifier]s, so a listener can be registered to
/// receive a notification when the focus changes. If the [Focus] and
/// [FocusScope] widgets are being used to manage the nodes, consider
/// establishing an [InheritedWidget] dependency on them by calling [Focus.of]
/// or [FocusScope.of] instead. [FocusNode.hasFocus] can also be used to
/// establish a similar dependency, especially if all that is needed is to
/// determine whether or not the widget is focused at build time.
///
/// To see the focus tree in the debug console, call [debugDumpFocusTree]. To
/// get the focus tree as a string, call [debugDescribeFocusTree].
///
/// {@template flutter.widgets.FocusNode.lifecycle}
/// ## Lifecycle
///
/// There are several actors involved in the lifecycle of a
/// [FocusNode]/[FocusScopeNode]. They are created and disposed by their
/// _owner_, attached, detached, and re-parented using a [FocusAttachment] by
/// their _host_ (which must be owned by the [State] of a [StatefulWidget]), and
/// they are managed by the [FocusManager]. Different parts of the [FocusNode]
/// API are intended for these different actors.
///
/// [FocusNode]s (and hence [FocusScopeNode]s) are persistent objects that form
/// part of a _focus tree_ that is a sparse representation of the widgets in the
/// hierarchy that are interested in receiving keyboard events. They must be
/// managed like other persistent state, which is typically done by a
/// [StatefulWidget] that owns the node. A stateful widget that owns a focus
/// scope node must call [dispose] from its [State.dispose] method.
///
/// Once created, a [FocusNode] must be attached to the widget tree via a
/// [FocusAttachment] object. This attachment is created by calling [attach],
/// usually from the [State.initState] method. If the hosting widget is updated
/// to have a different focus node, then the updated node needs to be attached
/// in [State.didUpdateWidget], after calling [FocusAttachment.detach] on the
/// previous [FocusAttachment].
///
/// Because [FocusNode]s form a sparse representation of the widget tree, they
/// must be updated whenever the widget tree is rebuilt. This is done by calling
/// [FocusAttachment.reparent], usually from the [State.build] or
/// [State.didChangeDependencies] methods of the widget that represents the
/// focused region, so that the [BuildContext] assigned to the [FocusScopeNode]
/// can be tracked (the context is used to obtain the [RenderObject], from which
/// the geometry of focused regions can be determined).
///
/// Creating a [FocusNode] each time [State.build] is invoked will cause the
/// focus to be lost each time the widget is built, which is usually not desired
/// behavior (call [unfocus] if losing focus is desired).
///
/// If, as is common, the hosting [StatefulWidget] is also the owner of the
/// focus node, then it will also call [dispose] from its [State.dispose] (in
/// which case the [FocusAttachment.detach] may be skipped, since dispose will
/// automatically detach). If another object owns the focus node, then it must
/// call [dispose] when the node is done being used.
/// {@endtemplate}
///
/// {@template flutter.widgets.FocusNode.keyEvents}
/// ## Key Event Propagation
///
/// The [FocusManager] receives key events from [RawKeyboard] and will pass them
/// to the focused nodes. It starts with the node with the primary focus, and
/// will call the [onKey] callback for that node. If the callback returns false,
/// indicating that it did not handle the event, the [FocusManager] will move to
/// the parent of that node and call its [onKey]. If that [onKey] returns true,
/// then it will stop propagating the event. If it reaches the root
/// [FocusScopeNode], [FocusManager.rootScope], the event is discarded.
/// {@endtemplate}
///
/// ## Focus Traversal
///
/// The term _traversal_, sometimes called _tab traversal_, refers to moving the
/// focus from one widget to the next in a particular order (also sometimes
/// referred to as the _tab order_, since the TAB key is often bound to the
/// action to move to the next widget).
///
/// To give focus to the logical _next_ or _previous_ widget in the UI, call the
/// [nextFocus] or [previousFocus] methods. To give the focus to a widget in a
/// particular direction, call the [focusInDirection] method.
///
/// The policy for what the _next_ or _previous_ widget is, or the widget in a
/// particular direction, is determined by the [FocusTraversalPolicy] in force.
///
/// The ambient policy is determined by looking up the widget hierarchy for a
/// [FocusTraversalGroup] widget, and obtaining the focus traversal policy from
/// it. Different focus nodes can inherit difference policies, so part of the
/// app can go in a predefined order (using [OrderedTraversalPolicy]), and part
/// can go in reading order (using [ReadingOrderTraversalPolicy]), depending
/// upon the use case.
///
/// Predefined policies include [WidgetOrderTraversalPolicy],
/// [ReadingOrderTraversalPolicy], [OrderedTraversalPolicy], and
/// [DirectionalFocusTraversalPolicyMixin], but custom policies can be built
/// based upon these policies. See [FocusTraversalPolicy] for more information.
///
/// {@tool dartpad --template=stateless_widget_scaffold_no_null_safety} This example shows how
/// a FocusNode should be managed if not using the [Focus] or [FocusScope]
/// widgets. See the [Focus] widget for a similar example using [Focus] and
/// [FocusScope] widgets.
///
/// ```dart imports
/// import 'package:flute/services.dart';
/// ```
///
/// ```dart preamble
/// class ColorfulButton extends StatefulWidget {
///   ColorfulButton({Key key}) : super(key: key);
///
///   @override
///   _ColorfulButtonState createState() => _ColorfulButtonState();
/// }
///
/// class _ColorfulButtonState extends State<ColorfulButton> {
///   FocusNode _node;
///   bool _focused = false;
///   FocusAttachment _nodeAttachment;
///   Color _color = Colors.white;
///
///   @override
///   void initState() {
///     super.initState();
///     _node = FocusNode(debugLabel: 'Button');
///     _node.addListener(_handleFocusChange);
///     _nodeAttachment = _node.attach(context, onKey: _handleKeyPress);
///   }
///
///   void _handleFocusChange() {
///     if (_node.hasFocus != _focused) {
///       setState(() {
///         _focused = _node.hasFocus;
///       });
///     }
///   }
///
///   KeyEventResult _handleKeyPress(FocusNode node, RawKeyEvent event) {
///     if (event is RawKeyDownEvent) {
///       print('Focus node ${node.debugLabel} got key event: ${event.logicalKey}');
///       if (event.logicalKey == LogicalKeyboardKey.keyR) {
///         print('Changing color to red.');
///         setState(() {
///           _color = Colors.red;
///         });
///         return KeyEventResult.handled;
///       } else if (event.logicalKey == LogicalKeyboardKey.keyG) {
///         print('Changing color to green.');
///         setState(() {
///           _color = Colors.green;
///         });
///         return KeyEventResult.handled;
///       } else if (event.logicalKey == LogicalKeyboardKey.keyB) {
///         print('Changing color to blue.');
///         setState(() {
///           _color = Colors.blue;
///         });
///         return KeyEventResult.handled;
///       }
///     }
///     return KeyEventResult.ignored;
///   }
///
///   @override
///   void dispose() {
///     _node.removeListener(_handleFocusChange);
///     // The attachment will automatically be detached in dispose().
///     _node.dispose();
///     super.dispose();
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     _nodeAttachment.reparent();
///     return GestureDetector(
///       onTap: () {
///         if (_focused) {
///             _node.unfocus();
///         } else {
///            _node.requestFocus();
///         }
///       },
///       child: Center(
///         child: Container(
///           width: 400,
///           height: 100,
///           color: _focused ? _color : Colors.white,
///           alignment: Alignment.center,
///           child: Text(
///               _focused ? "I'm in color! Press R,G,B!" : 'Press to focus'),
///         ),
///       ),
///     );
///   }
/// }
/// ```
///
/// ```dart
/// Widget build(BuildContext context) {
///   final TextTheme textTheme = Theme.of(context).textTheme;
///   return DefaultTextStyle(
///     style: textTheme.headline4,
///     child: ColorfulButton(),
///   );
/// }
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [Focus], a widget that manages a [FocusNode] and provides access to focus
///   information and actions to its descendant widgets.
/// * [FocusTraversalGroup], a widget used to group together and configure the
///   focus traversal policy for a widget subtree.
/// * [FocusManager], a singleton that manages the primary focus and distributes
///   key events to focused nodes.
/// * [FocusTraversalPolicy], a class used to determine how to move the focus to
///   other nodes.
class FocusNode with DiagnosticableTreeMixin, ChangeNotifier {
  /// Creates a focus node.
  ///
  /// The [debugLabel] is ignored on release builds.
  ///
  /// The [skipTraversal], [descendantsAreFocusable], and [canRequestFocus]
  /// arguments must not be null.
  FocusNode({
    String? debugLabel,
    FocusOnKeyCallback? onKey,
    bool skipTraversal = false,
    bool canRequestFocus = true,
    bool descendantsAreFocusable = true,
  })  : assert(skipTraversal != null),
        assert(canRequestFocus != null),
        assert(descendantsAreFocusable != null),
        _skipTraversal = skipTraversal,
        _canRequestFocus = canRequestFocus,
        _descendantsAreFocusable = descendantsAreFocusable,
        _onKey = onKey {
    // Set it via the setter so that it does nothing on release builds.
    this.debugLabel = debugLabel;
  }

  /// If true, tells the focus traversal policy to skip over this node for
  /// purposes of the traversal algorithm.
  ///
  /// This may be used to place nodes in the focus tree that may be focused, but
  /// not traversed, allowing them to receive key events as part of the focus
  /// chain, but not be traversed to via focus traversal.
  ///
  /// This is different from [canRequestFocus] because it only implies that the
  /// node can't be reached via traversal, not that it can't be focused. It may
  /// still be focused explicitly.
  bool get skipTraversal => _skipTraversal;
  bool _skipTraversal;
  set skipTraversal(bool value) {
    if (value != _skipTraversal) {
      _skipTraversal = value;
      _manager?._markPropertiesChanged(this);
    }
  }

  /// If true, this focus node may request the primary focus.
  ///
  /// Defaults to true.  Set to false if you want this node to do nothing when
  /// [requestFocus] is called on it.
  ///
  /// If set to false on a [FocusScopeNode], will cause all of the children of
  /// the scope node to not be focusable.
  ///
  /// If set to false on a [FocusNode], it will not affect the children of the
  /// node.
  ///
  /// The [hasFocus] member can still return true if this node is the ancestor
  /// of a node with primary focus.
  ///
  /// This is different than [skipTraversal] because [skipTraversal] still
  /// allows the node to be focused, just not traversed to via the
  /// [FocusTraversalPolicy]
  ///
  /// Setting [canRequestFocus] to false implies that the node will also be
  /// skipped for traversal purposes.
  ///
  /// See also:
  ///
  ///  * [FocusTraversalGroup], a widget used to group together and configure the
  ///    focus traversal policy for a widget subtree.
  ///  * [FocusTraversalPolicy], a class that can be extended to describe a
  ///    traversal policy.
  bool get canRequestFocus {
    if (!_canRequestFocus) {
      return false;
    }
    final FocusScopeNode? scope = enclosingScope;
    if (scope != null && !scope.canRequestFocus) {
      return false;
    }
    for (final FocusNode ancestor in ancestors) {
      if (!ancestor.descendantsAreFocusable) {
        return false;
      }
    }
    return true;
  }

  bool _canRequestFocus;
  @mustCallSuper
  set canRequestFocus(bool value) {
    if (value != _canRequestFocus) {
      // Have to set this first before unfocusing, since it checks this to cull
      // unfocusable, previously-focused children.
      _canRequestFocus = value;
      if (hasFocus && !value) {
        unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
      }
      _manager?._markPropertiesChanged(this);
    }
  }

  /// If false, will disable focus for all of this node's descendants.
  ///
  /// Defaults to true. Does not affect focusability of this node: for that,
  /// use [canRequestFocus].
  ///
  /// If any descendants are focused when this is set to false, they will be
  /// unfocused. When `descendantsAreFocusable` is set to true again, they will
  /// not be refocused, although they will be able to accept focus again.
  ///
  /// Does not affect the value of [canRequestFocus] on the descendants.
  ///
  /// If a descendant node loses focus when this value is changed, the focus
  /// will move to the scope enclosing this node.
  ///
  /// See also:
  ///
  ///  * [ExcludeFocus], a widget that uses this property to conditionally
  ///    exclude focus for a subtree.
  ///  * [Focus], a widget that exposes this setting as a parameter.
  ///  * [FocusTraversalGroup], a widget used to group together and configure
  ///    the focus traversal policy for a widget subtree that also has an
  ///    `descendantsAreFocusable` parameter that prevents its children from
  ///    being focused.
  bool get descendantsAreFocusable => _descendantsAreFocusable;
  bool _descendantsAreFocusable;
  @mustCallSuper
  set descendantsAreFocusable(bool value) {
    if (value == _descendantsAreFocusable) {
      return;
    }
    // Set _descendantsAreFocusable before unfocusing, so the scope won't try
    // and focus any of the children here again if it is false.
    _descendantsAreFocusable = value;
    if (!value && hasFocus) {
      unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
    }
    _manager?._markPropertiesChanged(this);
  }

  /// The context that was supplied to [attach].
  ///
  /// This is typically the context for the widget that is being focused, as it
  /// is used to determine the bounds of the widget.
  BuildContext? get context => _context;
  BuildContext? _context;

  /// Called if this focus node receives a key event while focused (i.e. when
  /// [hasFocus] returns true).
  ///
  /// {@macro flutter.widgets.FocusNode.keyEvents}
  FocusOnKeyCallback? get onKey => _onKey;
  FocusOnKeyCallback? _onKey;

  FocusManager? _manager;
  List<FocusNode>? _ancestors;
  List<FocusNode>? _descendants;
  bool _hasKeyboardToken = false;

  /// Returns the parent node for this object.
  ///
  /// All nodes except for the root [FocusScopeNode] ([FocusManager.rootScope])
  /// will be given a parent when they are added to the focus tree, which is
  /// done using [FocusAttachment.reparent].
  FocusNode? get parent => _parent;
  FocusNode? _parent;

  /// An iterator over the children of this node.
  Iterable<FocusNode> get children => _children;
  final List<FocusNode> _children = <FocusNode>[];

  /// An iterator over the children that are allowed to be traversed by the
  /// [FocusTraversalPolicy].
  Iterable<FocusNode> get traversalChildren {
    if (!canRequestFocus) {
      return const <FocusNode>[];
    }
    return children.where(
      (FocusNode node) => !node.skipTraversal && node.canRequestFocus,
    );
  }

  /// A debug label that is used for diagnostic output.
  ///
  /// Will always return null in release builds.
  String? get debugLabel => _debugLabel;
  String? _debugLabel;
  set debugLabel(String? value) {
    assert(() {
      // Only set the value in debug builds.
      _debugLabel = value;
      return true;
    }());
  }

  FocusAttachment? _attachment;

  /// An [Iterable] over the hierarchy of children below this one, in
  /// depth-first order.
  Iterable<FocusNode> get descendants {
    if (_descendants == null) {
      final List<FocusNode> result = <FocusNode>[];
      for (final FocusNode child in _children) {
        result.addAll(child.descendants);
        result.add(child);
      }
      _descendants = result;
    }
    return _descendants!;
  }

  /// Returns all descendants which do not have the [skipTraversal] and do have
  /// the [canRequestFocus] flag set.
  Iterable<FocusNode> get traversalDescendants => descendants.where((FocusNode node) => !node.skipTraversal && node.canRequestFocus);

  /// An [Iterable] over the ancestors of this node.
  ///
  /// Iterates the ancestors of this node starting at the parent and iterating
  /// over successively more remote ancestors of this node, ending at the root
  /// [FocusScopeNode] ([FocusManager.rootScope]).
  Iterable<FocusNode> get ancestors {
    if (_ancestors == null) {
      final List<FocusNode> result = <FocusNode>[];
      FocusNode? parent = _parent;
      while (parent != null) {
        result.add(parent);
        parent = parent._parent;
      }
      _ancestors = result;
    }
    return _ancestors!;
  }

  /// Whether this node has input focus.
  ///
  /// A [FocusNode] has focus when it is an ancestor of a node that returns true
  /// from [hasPrimaryFocus], or it has the primary focus itself.
  ///
  /// The [hasFocus] accessor is different from [hasPrimaryFocus] in that
  /// [hasFocus] is true if the node is anywhere in the focus chain, but for
  /// [hasPrimaryFocus] the node must to be at the end of the chain to return
  /// true.
  ///
  /// A node that returns true for [hasFocus] will receive key events if none of
  /// its focused descendants returned true from their [onKey] handler.
  ///
  /// This object is a [ChangeNotifier], and notifies its [Listenable] listeners
  /// (registered via [addListener]) whenever this value changes.
  ///
  /// See also:
  ///
  ///  * [Focus.isAt], which is a static method that will return the focus
  ///    state of the nearest ancestor [Focus] widget's focus node.
  bool get hasFocus => hasPrimaryFocus || (_manager?.primaryFocus?.ancestors.contains(this) ?? false);

  /// Returns true if this node currently has the application-wide input focus.
  ///
  /// A [FocusNode] has the primary focus when the node is focused in its
  /// nearest ancestor [FocusScopeNode] and [hasFocus] is true for all its
  /// ancestor nodes, but none of its descendants.
  ///
  /// This is different from [hasFocus] in that [hasFocus] is true if the node
  /// is anywhere in the focus chain, but here the node has to be at the end of
  /// the chain to return true.
  ///
  /// A node that returns true for [hasPrimaryFocus] will be the first node to
  /// receive key events through its [onKey] handler.
  ///
  /// This object notifies its listeners whenever this value changes.
  bool get hasPrimaryFocus => _manager?.primaryFocus == this;

  /// Returns the [FocusHighlightMode] that is currently in effect for this node.
  FocusHighlightMode get highlightMode => FocusManager.instance.highlightMode;

  /// Returns the nearest enclosing scope node above this node, including
  /// this node, if it's a scope.
  ///
  /// Returns null if no scope is found.
  ///
  /// Use [enclosingScope] to look for scopes above this node.
  FocusScopeNode? get nearestScope => enclosingScope;

  /// Returns the nearest enclosing scope node above this node, or null if the
  /// node has not yet be added to the focus tree.
  ///
  /// If this node is itself a scope, this will only return ancestors of this
  /// scope.
  ///
  /// Use [nearestScope] to start at this node instead of above it.
  FocusScopeNode? get enclosingScope {
    for (final FocusNode node in ancestors) {
      if (node is FocusScopeNode)
        return node;
    }
    return null;
  }

  /// Returns the size of the attached widget's [RenderObject], in logical
  /// units.
  ///
  /// Size is the size of the transformed widget in global coordinates.
  Size get size => rect.size;

  /// Returns the global offset to the upper left corner of the attached
  /// widget's [RenderObject], in logical units.
  ///
  /// Offset is the offset of the transformed widget in global coordinates.
  Offset get offset {
    assert(
        context != null,
        "Tried to get the offset of a focus node that didn't have its context set yet.\n"
        'The context needs to be set before trying to evaluate traversal policies. '
        'Setting the context is typically done with the attach method.');
    final RenderObject object = context!.findRenderObject()!;
    return MatrixUtils.transformPoint(object.getTransformTo(null), object.semanticBounds.topLeft);
  }

  /// Returns the global rectangle of the attached widget's [RenderObject], in
  /// logical units.
  ///
  /// Rect is the rectangle of the transformed widget in global coordinates.
  Rect get rect {
    assert(
        context != null,
        "Tried to get the bounds of a focus node that didn't have its context set yet.\n"
        'The context needs to be set before trying to evaluate traversal policies. '
        'Setting the context is typically done with the attach method.');
    final RenderObject object = context!.findRenderObject()!;
    final Offset topLeft = MatrixUtils.transformPoint(object.getTransformTo(null), object.semanticBounds.topLeft);
    final Offset bottomRight = MatrixUtils.transformPoint(object.getTransformTo(null), object.semanticBounds.bottomRight);
    return Rect.fromLTRB(topLeft.dx, topLeft.dy, bottomRight.dx, bottomRight.dy);
  }

  /// Removes the focus on this node by moving the primary focus to another node.
  ///
  /// This method removes focus from a node that has the primary focus, cancels
  /// any outstanding requests to focus it, while setting the primary focus to
  /// another node according to the `disposition`.
  ///
  /// It is safe to call regardless of whether this node has ever requested
  /// focus or not. If this node doesn't have focus or primary focus, nothing
  /// happens.
  ///
  /// The `disposition` argument determines which node will receive primary
  /// focus after this one loses it.
  ///
  /// If `disposition` is set to [UnfocusDisposition.scope] (the default), then
  /// the previously focused node history of the enclosing scope will be
  /// cleared, and the primary focus will be moved to the nearest enclosing
  /// scope ancestor that is enabled for focus, ignoring the
  /// [FocusScopeNode.focusedChild] for that scope.
  ///
  /// If `disposition` is set to [UnfocusDisposition.previouslyFocusedChild],
  /// then this node will be removed from the previously focused list in the
  /// [enclosingScope], and the focus will be moved to the previously focused
  /// node of the [enclosingScope], which (if it is a scope itself), will find
  /// its focused child, etc., until a leaf focus node is found. If there is no
  /// previously focused child, then the scope itself will receive focus, as if
  /// [UnfocusDisposition.scope] were specified.
  ///
  /// If you want this node to lose focus and the focus to move to the next or
  /// previous node in the enclosing [FocusTraversalGroup], call [nextFocus] or
  /// [previousFocus] instead of calling `unfocus`.
  ///
  /// {@tool dartpad --template=stateful_widget_material_no_null_safety}
  /// This example shows the difference between the different [UnfocusDisposition]
  /// values for [unfocus].
  ///
  /// Try setting focus on the four text fields by selecting them, and then
  /// select "UNFOCUS" to see what happens when the current
  /// [FocusManager.primaryFocus] is unfocused.
  ///
  /// Try pressing the TAB key after unfocusing to see what the next widget
  /// chosen is.
  ///
  /// ```dart imports
  /// import 'package:flute/foundation.dart';
  /// ```
  ///
  /// ```dart
  /// UnfocusDisposition disposition = UnfocusDisposition.scope;
  ///
  /// @override
  /// Widget build(BuildContext context) {
  ///   return Material(
  ///     child: Container(
  ///       color: Colors.white,
  ///       child: Column(
  ///         mainAxisAlignment: MainAxisAlignment.center,
  ///         children: <Widget>[
  ///           Wrap(
  ///             children: List<Widget>.generate(4, (int index) {
  ///               return SizedBox(
  ///                 width: 200,
  ///                 child: Padding(
  ///                   padding: const EdgeInsets.all(8.0),
  ///                   child: TextField(
  ///                     decoration: InputDecoration(border: OutlineInputBorder()),
  ///                   ),
  ///                 ),
  ///               );
  ///             }),
  ///           ),
  ///           Row(
  ///             mainAxisAlignment: MainAxisAlignment.spaceAround,
  ///             children: <Widget>[
  ///               ...List<Widget>.generate(UnfocusDisposition.values.length,
  ///                   (int index) {
  ///                 return Row(
  ///                   mainAxisSize: MainAxisSize.min,
  ///                   children: <Widget>[
  ///                     Radio<UnfocusDisposition>(
  ///                       groupValue: disposition,
  ///                       onChanged: (UnfocusDisposition value) {
  ///                         setState(() {
  ///                           disposition = value;
  ///                         });
  ///                       },
  ///                       value: UnfocusDisposition.values[index],
  ///                     ),
  ///                     Text(describeEnum(UnfocusDisposition.values[index])),
  ///                   ],
  ///                 );
  ///               }),
  ///               OutlinedButton(
  ///                 child: const Text('UNFOCUS'),
  ///                 onPressed: () {
  ///                   setState(() {
  ///                     primaryFocus.unfocus(disposition: disposition);
  ///                   });
  ///                 },
  ///               ),
  ///             ],
  ///           ),
  ///         ],
  ///       ),
  ///     ),
  ///   );
  /// }
  /// ```
  /// {@end-tool}
  void unfocus({
    UnfocusDisposition disposition = UnfocusDisposition.scope,
  }) {
    assert(disposition != null);
    if (!hasFocus && (_manager == null || _manager!._markedForFocus != this)) {
      return;
    }
    FocusScopeNode? scope = enclosingScope;
    if (scope == null) {
      // If the scope is null, then this is either the root node, or a node that
      // is not yet in the tree, neither of which do anything when unfocused.
      return;
    }
    switch (disposition) {
      case UnfocusDisposition.scope:
        // If it can't request focus, then don't modify its focused children.
        if (scope.canRequestFocus) {
          // Clearing the focused children here prevents re-focusing the node
          // that we just unfocused if we immediately hit "next" after
          // unfocusing, and also prevents choosing to refocus the next-to-last
          // focused child if unfocus is called more than once.
          scope._focusedChildren.clear();
        }

        while (!scope!.canRequestFocus) {
          scope = scope.enclosingScope ?? _manager?.rootScope;
        }
        scope._doRequestFocus(findFirstFocus: false);
        break;
      case UnfocusDisposition.previouslyFocusedChild:
        // Select the most recent focused child from the nearest focusable scope
        // and focus that. If there isn't one, focus the scope itself.
        if (scope.canRequestFocus) {
          scope._focusedChildren.remove(this);
        }
        while (!scope!.canRequestFocus) {
          scope.enclosingScope?._focusedChildren.remove(scope);
          scope = scope.enclosingScope ?? _manager?.rootScope;
        }
        scope._doRequestFocus(findFirstFocus: true);
        break;
    }
    assert(_focusDebug('Unfocused node:', <String>['primary focus was $this', 'next focus will be ${_manager?._markedForFocus}']));
  }

  /// Removes the keyboard token from this focus node if it has one.
  ///
  /// This mechanism helps distinguish between an input control gaining focus by
  /// default and gaining focus as a result of an explicit user action.
  ///
  /// When a focus node requests the focus (either via
  /// [FocusScopeNode.requestFocus] or [FocusScopeNode.autofocus]), the focus
  /// node receives a keyboard token if it does not already have one. Later,
  /// when the focus node becomes focused, the widget that manages the
  /// [TextInputConnection] should show the keyboard (i.e. call
  /// [TextInputConnection.show]) only if it successfully consumes the keyboard
  /// token from the focus node.
  ///
  /// Returns true if this method successfully consumes the keyboard token.
  bool consumeKeyboardToken() {
    if (!_hasKeyboardToken) {
      return false;
    }
    _hasKeyboardToken = false;
    return true;
  }

  // Marks the node as being the next to be focused, meaning that it will become
  // the primary focus and notify listeners of a focus change the next time
  // focus is resolved by the manager. If something else calls _markNextFocus
  // before then, then that node will become the next focus instead of the
  // previous one.
  void _markNextFocus(FocusNode newFocus) {
    if (_manager != null) {
      // If we have a manager, then let it handle the focus change.
      _manager!._markNextFocus(this);
      return;
    }
    // If we don't have a manager, then change the focus locally.
    newFocus._setAsFocusedChildForScope();
    newFocus._notify();
    if (newFocus != this) {
      _notify();
    }
  }

  // Removes the given FocusNode and its children as a child of this node.
  @mustCallSuper
  void _removeChild(FocusNode node, {bool removeScopeFocus = true}) {
    assert(node != null);
    assert(_children.contains(node), "Tried to remove a node that wasn't a child.");
    assert(node._parent == this);
    assert(node._manager == _manager);

    if (removeScopeFocus) {
      node.enclosingScope?._focusedChildren.remove(node);
    }

    node._parent = null;
    _children.remove(node);
    for (final FocusNode ancestor in ancestors) {
      ancestor._descendants = null;
    }
    _descendants = null;
    assert(_manager == null || !_manager!.rootScope.descendants.contains(node));
  }

  void _updateManager(FocusManager? manager) {
    _manager = manager;
    for (final FocusNode descendant in descendants) {
      descendant._manager = manager;
      descendant._ancestors = null;
    }
  }

  // Used by FocusAttachment.reparent to perform the actual parenting operation.
  @mustCallSuper
  void _reparent(FocusNode child) {
    assert(child != null);
    assert(child != this, 'Tried to make a child into a parent of itself.');
    if (child._parent == this) {
      assert(_children.contains(child), "Found a node that says it's a child, but doesn't appear in the child list.");
      // The child is already a child of this parent.
      return;
    }
    assert(_manager == null || child != _manager!.rootScope, "Reparenting the root node isn't allowed.");
    assert(!ancestors.contains(child), 'The supplied child is already an ancestor of this node. Loops are not allowed.');
    final FocusScopeNode? oldScope = child.enclosingScope;
    final bool hadFocus = child.hasFocus;
    child._parent?._removeChild(child, removeScopeFocus: oldScope != nearestScope);
    _children.add(child);
    child._parent = this;
    child._ancestors = null;
    child._updateManager(_manager);
    for (final FocusNode ancestor in child.ancestors) {
      ancestor._descendants = null;
    }
    if (hadFocus) {
      // Update the focus chain for the current focus without changing it.
      _manager?.primaryFocus?._setAsFocusedChildForScope();
    }
    if (oldScope != null && child.context != null && child.enclosingScope != oldScope) {
      FocusTraversalGroup.maybeOf(child.context!)?.changedScope(node: child, oldScope: oldScope);
    }
    if (child._requestFocusWhenReparented) {
      child._doRequestFocus(findFirstFocus: true);
      child._requestFocusWhenReparented = false;
    }
  }

  /// Called by the _host_ [StatefulWidget] to attach a [FocusNode] to the
  /// widget tree.
  ///
  /// In order to attach a [FocusNode] to the widget tree, call [attach],
  /// typically from the [StatefulWidget]'s [State.initState] method.
  ///
  /// If the focus node in the host widget is swapped out, the new node will
  /// need to be attached. [FocusAttachment.detach] should be called on the old
  /// node, and then [attach] called on the new node. This typically happens in
  /// the [State.didUpdateWidget] method.
  @mustCallSuper
  FocusAttachment attach(BuildContext? context, {FocusOnKeyCallback? onKey}) {
    _context = context;
    _onKey = onKey ?? _onKey;
    _attachment = FocusAttachment._(this);
    return _attachment!;
  }

  @override
  void dispose() {
    // Detaching will also unfocus and clean up the manager's data structures.
    _attachment?.detach();
    super.dispose();
  }

  @mustCallSuper
  void _notify() {
    if (_parent == null) {
      // no longer part of the tree, so don't notify.
      return;
    }
    if (hasPrimaryFocus) {
      _setAsFocusedChildForScope();
    }
    notifyListeners();
  }

  /// Requests the primary focus for this node, or for a supplied [node], which
  /// will also give focus to its [ancestors].
  ///
  /// If called without a node, request focus for this node. If the node hasn't
  /// been added to the focus tree yet, then defer the focus request until it
  /// is, allowing newly created widgets to request focus as soon as they are
  /// added.
  ///
  /// If the given [node] is not yet a part of the focus tree, then this method
  /// will add the [node] as a child of this node before requesting focus.
  ///
  /// If the given [node] is a [FocusScopeNode] and that focus scope node has a
  /// non-null [FocusScopeNode.focusedChild], then request the focus for the
  /// focused child. This process is recursive and continues until it encounters
  /// either a focus scope node with a null focused child or an ordinary
  /// (non-scope) [FocusNode] is found.
  ///
  /// The node is notified that it has received the primary focus in a
  /// microtask, so notification may lag the request by up to one frame.
  void requestFocus([FocusNode? node]) {
    if (node != null) {
      if (node._parent == null) {
        _reparent(node);
      }
      assert(node.ancestors.contains(this), 'Focus was requested for a node that is not a descendant of the scope from which it was requested.');
      node._doRequestFocus(findFirstFocus: true);
      return;
    }
    _doRequestFocus(findFirstFocus: true);
  }

  // Note that this is overridden in FocusScopeNode.
  void _doRequestFocus({required bool findFirstFocus}) {
    assert(findFirstFocus != null);
    if (!canRequestFocus) {
      assert(_focusDebug('Node NOT requesting focus because canRequestFocus is false: $this'));
      return;
    }
    // If the node isn't part of the tree, then we just defer the focus request
    // until the next time it is reparented, so that it's possible to focus
    // newly added widgets.
    if (_parent == null) {
      _requestFocusWhenReparented = true;
      return;
    }
    _setAsFocusedChildForScope();
    if (hasPrimaryFocus && (_manager!._markedForFocus == null || _manager!._markedForFocus == this)) {
      return;
    }
    _hasKeyboardToken = true;
    assert(_focusDebug('Node requesting focus: $this'));
    _markNextFocus(this);
  }

  // If set to true, the node will request focus on this node the next time
  // this node is reparented in the focus tree.
  //
  // Once requestFocus has been called at the next reparenting, this value
  // will be reset to false.
  //
  // This will only force a call to requestFocus for the node once the next time
  // the node is reparented. After that, _requestFocusWhenReparented would need
  // to be set to true again to have it be focused again on the next
  // reparenting.
  //
  // This is used when requestFocus is called and there is no parent yet.
  bool _requestFocusWhenReparented = false;

  /// Sets this node as the [FocusScopeNode.focusedChild] of the enclosing
  /// scope.
  ///
  /// Sets this node as the focused child for the enclosing scope, and that
  /// scope as the focused child for the scope above it, etc., until it reaches
  /// the root node. It doesn't change the primary focus, it just changes what
  /// node would be focused if the enclosing scope receives focus, and keeps
  /// track of previously focused children in that scope, so that if the focused
  /// child in that scope is removed, the previous focus returns.
  void _setAsFocusedChildForScope() {
    FocusNode scopeFocus = this;
    for (final FocusScopeNode ancestor in ancestors.whereType<FocusScopeNode>()) {
      assert(scopeFocus != ancestor, 'Somehow made a loop by setting focusedChild to its scope.');
      assert(_focusDebug('Setting $scopeFocus as focused child for scope:', <String>[ancestor.toString()]));
      // Remove it anywhere in the focused child history.
      ancestor._focusedChildren.remove(scopeFocus);
      // Add it to the end of the list, which is also the top of the queue: The
      // end of the list represents the currently focused child.
      ancestor._focusedChildren.add(scopeFocus);
      scopeFocus = ancestor;
    }
  }

  /// Request to move the focus to the next focus node, by calling the
  /// [FocusTraversalPolicy.next] method.
  ///
  /// Returns true if it successfully found a node and requested focus.
  bool nextFocus() => FocusTraversalGroup.of(context!).next(this);

  /// Request to move the focus to the previous focus node, by calling the
  /// [FocusTraversalPolicy.previous] method.
  ///
  /// Returns true if it successfully found a node and requested focus.
  bool previousFocus() => FocusTraversalGroup.of(context!).previous(this);

  /// Request to move the focus to the nearest focus node in the given
  /// direction, by calling the [FocusTraversalPolicy.inDirection] method.
  ///
  /// Returns true if it successfully found a node and requested focus.
  bool focusInDirection(TraversalDirection direction) => FocusTraversalGroup.of(context!).inDirection(this, direction);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<BuildContext>('context', context, defaultValue: null));
    properties.add(FlagProperty('descendantsAreFocusable', value: descendantsAreFocusable, ifFalse: 'DESCENDANTS UNFOCUSABLE', defaultValue: true));
    properties.add(FlagProperty('canRequestFocus', value: canRequestFocus, ifFalse: 'NOT FOCUSABLE', defaultValue: true));
    properties.add(FlagProperty('hasFocus', value: hasFocus && !hasPrimaryFocus, ifTrue: 'IN FOCUS PATH', defaultValue: false));
    properties.add(FlagProperty('hasPrimaryFocus', value: hasPrimaryFocus, ifTrue: 'PRIMARY FOCUS', defaultValue: false));
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    int count = 1;
    return _children.map<DiagnosticsNode>((FocusNode child) {
      return child.toDiagnosticsNode(name: 'Child ${count++}');
    }).toList();
  }

  @override
  String toStringShort() {
    final bool hasDebugLabel = debugLabel != null && debugLabel!.isNotEmpty;
    final String extraData = '${hasDebugLabel ? debugLabel : ''}'
        '${hasFocus && hasDebugLabel ? ' ' : ''}'
        '${hasFocus && !hasPrimaryFocus ? '[IN FOCUS PATH]' : ''}'
        '${hasPrimaryFocus ? '[PRIMARY FOCUS]' : ''}';
    return '${describeIdentity(this)}${extraData.isNotEmpty ? '($extraData)' : ''}';
  }
}

/// A subclass of [FocusNode] that acts as a scope for its descendants,
/// maintaining information about which descendant is currently or was last
/// focused.
///
/// _Please see the [FocusScope] and [Focus] widgets, which are utility widgets
/// that manage their own [FocusScopeNode]s and [FocusNode]s, respectively. If
/// they aren't appropriate, [FocusScopeNode]s can be managed directly._
///
/// [FocusScopeNode] organizes [FocusNode]s into _scopes_. Scopes form sub-trees
/// of nodes that can be traversed as a group. Within a scope, the most recent
/// nodes to have focus are remembered, and if a node is focused and then
/// removed, the original node receives focus again.
///
/// From a [FocusScopeNode], calling [setFirstFocus], sets the given focus scope
/// as the [focusedChild] of this node, adopting if it isn't already part of the
/// focus tree.
///
/// {@macro flutter.widgets.FocusNode.lifecycle}
/// {@macro flutter.widgets.FocusNode.keyEvents}
///
/// See also:
///
///  * [Focus], a widget that manages a [FocusNode] and provides access to focus
///    information and actions to its descendant widgets.
///  * [FocusManager], a singleton that manages the primary focus and
///    distributes key events to focused nodes.
class FocusScopeNode extends FocusNode {
  /// Creates a [FocusScopeNode].
  ///
  /// All parameters are optional.
  FocusScopeNode({
    String? debugLabel,
    FocusOnKeyCallback? onKey,
    bool skipTraversal = false,
    bool canRequestFocus = true,
  })  : assert(skipTraversal != null),
        assert(canRequestFocus != null),
        super(
          debugLabel: debugLabel,
          onKey: onKey,
          canRequestFocus: canRequestFocus,
          descendantsAreFocusable: true,
          skipTraversal: skipTraversal,
        );

  @override
  FocusScopeNode get nearestScope => this;

  /// Returns true if this scope is the focused child of its parent scope.
  bool get isFirstFocus => enclosingScope!.focusedChild == this;

  /// Returns the child of this node that should receive focus if this scope
  /// node receives focus.
  ///
  /// If [hasFocus] is true, then this points to the child of this node that is
  /// currently focused.
  ///
  /// Returns null if there is no currently focused child.
  FocusNode? get focusedChild {
    assert(_focusedChildren.isEmpty || _focusedChildren.last.enclosingScope == this, 'Focused child does not have the same idea of its enclosing scope as the scope does.');
    return _focusedChildren.isNotEmpty ? _focusedChildren.last : null;
  }

  // A stack of the children that have been set as the focusedChild, most recent
  // last (which is the top of the stack).
  final List<FocusNode> _focusedChildren = <FocusNode>[];

  /// Make the given [scope] the active child scope for this scope.
  ///
  /// If the given [scope] is not yet a part of the focus tree, then add it to
  /// the tree as a child of this scope. If it is already part of the focus
  /// tree, the given scope must be a descendant of this scope.
  void setFirstFocus(FocusScopeNode scope) {
    assert(scope != null);
    assert(scope != this, 'Unexpected self-reference in setFirstFocus.');
    assert(_focusDebug('Setting scope as first focus in $this to node:', <String>[scope.toString()]));
    if (scope._parent == null) {
      _reparent(scope);
    }
    assert(scope.ancestors.contains(this), '$FocusScopeNode $scope must be a child of $this to set it as first focus.');
    if (hasFocus) {
      scope._doRequestFocus(findFirstFocus: true);
    } else {
      scope._setAsFocusedChildForScope();
    }
  }

  /// If this scope lacks a focus, request that the given node become the focus.
  ///
  /// If the given node is not yet part of the focus tree, then add it as a
  /// child of this node.
  ///
  /// Useful for widgets that wish to grab the focus if no other widget already
  /// has the focus.
  ///
  /// The node is notified that it has received the primary focus in a
  /// microtask, so notification may lag the request by up to one frame.
  void autofocus(FocusNode node) {
    assert(_focusDebug('Node autofocusing: $node'));
    if (focusedChild == null) {
      if (node._parent == null) {
        _reparent(node);
      }
      assert(node.ancestors.contains(this), 'Autofocus was requested for a node that is not a descendant of the scope from which it was requested.');
      node._doRequestFocus(findFirstFocus: true);
    }
  }

  @override
  void _doRequestFocus({required bool findFirstFocus}) {
    assert(findFirstFocus != null);

    // It is possible that a previously focused child is no longer focusable.
    while (focusedChild != null && !focusedChild!.canRequestFocus)
      _focusedChildren.removeLast();

    // If findFirstFocus is false, then the request is to make this scope the
    // focus instead of looking for the ultimate first focus for this scope and
    // its descendants.
    if (!findFirstFocus) {
      if (canRequestFocus) {
        _setAsFocusedChildForScope();
        _markNextFocus(this);
      }
      return;
    }

    // Start with the primary focus as the focused child of this scope, if there
    // is one. Otherwise start with this node itself.
    FocusNode primaryFocus = focusedChild ?? this;
    // Keep going down through scopes until the ultimately focusable item is
    // found, a scope doesn't have a focusedChild, or a non-scope is
    // encountered.
    while (primaryFocus is FocusScopeNode && primaryFocus.focusedChild != null) {
      primaryFocus = primaryFocus.focusedChild!;
    }
    if (identical(primaryFocus, this)) {
      // We didn't find a FocusNode at the leaf, so we're focusing the scope, if
      // allowed.
      if (primaryFocus.canRequestFocus) {
        _setAsFocusedChildForScope();
        _markNextFocus(this);
      }
    } else {
      // We found a FocusScopeNode at the leaf, so ask it to focus itself
      // instead of this scope. That will cause this scope to return true from
      // hasFocus, but false from hasPrimaryFocus.
      primaryFocus._doRequestFocus(findFirstFocus: findFirstFocus);
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    if (_focusedChildren.isEmpty) {
      return;
    }
    final List<String> childList = _focusedChildren.reversed.map<String>((FocusNode child) {
      return child.toStringShort();
    }).toList();
    properties.add(IterableProperty<String>('focusedChildren', childList, defaultValue: <String>[]));
  }
}

/// An enum to describe which kind of focus highlight behavior to use when
/// displaying focus information.
enum FocusHighlightMode {
  /// Touch interfaces will not show the focus highlight except for controls
  /// which bring up the soft keyboard.
  ///
  /// If a device that uses a traditional mouse and keyboard has a touch screen
  /// attached, it can also enter `touch` mode if the user is using the touch
  /// screen.
  touch,

  /// Traditional interfaces (keyboard and mouse) will show the currently
  /// focused control via a focus highlight of some sort.
  ///
  /// If a touch device (like a mobile phone) has a keyboard and/or mouse
  /// attached, it also can enter `traditional` mode if the user is using these
  /// input devices.
  traditional,
}

/// An enum to describe how the current value of [FocusManager.highlightMode] is
/// determined. The strategy is set on [FocusManager.highlightStrategy].
enum FocusHighlightStrategy {
  /// Automatic switches between the various highlight modes based on the last
  /// kind of input that was received. This is the default.
  automatic,

  /// [FocusManager.highlightMode] always returns [FocusHighlightMode.touch].
  alwaysTouch,

  /// [FocusManager.highlightMode] always returns [FocusHighlightMode.traditional].
  alwaysTraditional,
}

/// Manages the focus tree.
///
/// The focus tree is a separate, sparser, tree from the widget tree that
/// maintains the hierarchical relationship between focusable widgets in the
/// widget tree.
///
/// The focus manager is responsible for tracking which [FocusNode] has the
/// primary input focus (the [primaryFocus]), holding the [FocusScopeNode] that
/// is the root of the focus tree (the [rootScope]), and what the current
/// [highlightMode] is. It also distributes key events from [RawKeyboard] to the
/// nodes in the focus tree.
///
/// The singleton [FocusManager] instance is held by the [WidgetsBinding] as
/// [WidgetsBinding.focusManager], and can be conveniently accessed using the
/// [FocusManager.instance] static accessor.
///
/// To find the [FocusNode] for a given [BuildContext], use [Focus.of]. To find
/// the [FocusScopeNode] for a given [BuildContext], use [FocusScope.of].
///
/// If you would like notification whenever the [primaryFocus] changes, register
/// a listener with [addListener]. When you no longer want to receive these
/// events, as when your object is about to be disposed, you must unregister
/// with [removeListener] to avoid memory leaks. Removing listeners is typically
/// done in [State.dispose] on stateful widgets.
///
/// The [highlightMode] describes how focus highlights should be displayed on
/// components in the UI. The [highlightMode] changes are notified separately
/// via [addHighlightModeListener] and removed with
/// [removeHighlightModeListener]. The highlight mode changes when the user
/// switches from a mouse to a touch interface, or vice versa.
///
/// The widgets that are used to manage focus in the widget tree are:
///
///  * [Focus], a widget that manages a [FocusNode] in the focus tree so that
///    the focus tree reflects changes in the widget hierarchy.
///  * [FocusScope], a widget that manages a [FocusScopeNode] in the focus tree,
///    creating a new scope for restricting focus to a set of focus nodes.
///  * [FocusTraversalGroup], a widget that groups together nodes that should be
///    traversed using an order described by a given [FocusTraversalPolicy].
///
/// See also:
///
///  * [FocusNode], which is a node in the focus tree that can receive focus.
///  * [FocusScopeNode], which is a node in the focus tree used to collect
///    subtrees into groups and restrict focus to them.
///  * The [primaryFocus] global accessor, for convenient access from anywhere
///    to the current focus manager state.
class FocusManager with DiagnosticableTreeMixin, ChangeNotifier {
  /// Creates an object that manages the focus tree.
  ///
  /// This constructor is rarely called directly. To access the [FocusManager],
  /// consider using the [FocusManager.instance] accessor instead (which gets it
  /// from the [WidgetsBinding] singleton).
  FocusManager() {
    rootScope._manager = this;
    RawKeyboard.instance.keyEventHandler = _handleRawKeyEvent;
    GestureBinding.instance!.pointerRouter.addGlobalRoute(_handlePointerEvent);
  }

  /// Provides convenient access to the current [FocusManager] singleton from
  /// the [WidgetsBinding] instance.
  static FocusManager get instance => WidgetsBinding.instance!.focusManager;

  /// Sets the strategy by which [highlightMode] is determined.
  ///
  /// If set to [FocusHighlightStrategy.automatic], then the highlight mode will
  /// change depending upon the interaction mode used last. For instance, if the
  /// last interaction was a touch interaction, then [highlightMode] will return
  /// [FocusHighlightMode.touch], and focus highlights will only appear on
  /// widgets that bring up a soft keyboard. If the last interaction was a
  /// non-touch interaction (hardware keyboard press, mouse click, etc.), then
  /// [highlightMode] will return [FocusHighlightMode.traditional], and focus
  /// highlights will appear on all widgets.
  ///
  /// If set to [FocusHighlightStrategy.alwaysTouch] or
  /// [FocusHighlightStrategy.alwaysTraditional], then [highlightMode] will
  /// always return [FocusHighlightMode.touch] or
  /// [FocusHighlightMode.traditional], respectively, regardless of the last UI
  /// interaction type.
  ///
  /// The initial value of [highlightMode] depends upon the value of
  /// [defaultTargetPlatform] and [BaseMouseTracker.mouseIsConnected] of
  /// [RendererBinding.mouseTracker], making a guess about which interaction is
  /// most appropriate for the initial interaction mode.
  ///
  /// Defaults to [FocusHighlightStrategy.automatic].
  FocusHighlightStrategy get highlightStrategy => _highlightStrategy;
  FocusHighlightStrategy _highlightStrategy = FocusHighlightStrategy.automatic;
  set highlightStrategy(FocusHighlightStrategy highlightStrategy) {
    _highlightStrategy = highlightStrategy;
    _updateHighlightMode();
  }

  static FocusHighlightMode get _defaultModeForPlatform {
    // Assume that if we're on one of the mobile platforms, and there's no mouse
    // connected, that the initial interaction will be touch-based, and that
    // it's traditional mouse and keyboard on all other platforms.
    //
    // This only affects the initial value: the ongoing value is updated to a
    // known correct value as soon as any pointer/keyboard events are received.
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
        if (WidgetsBinding.instance!.mouseTracker.mouseIsConnected) {
          return FocusHighlightMode.traditional;
        }
        return FocusHighlightMode.touch;
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return FocusHighlightMode.traditional;
    }
  }

  /// Indicates the current interaction mode for focus highlights.
  ///
  /// The value returned depends upon the [highlightStrategy] used, and possibly
  /// (depending on the value of [highlightStrategy]) the most recent
  /// interaction mode that they user used.
  ///
  /// If [highlightMode] returns [FocusHighlightMode.touch], then widgets should
  /// not draw their focus highlight unless they perform text entry.
  ///
  /// If [highlightMode] returns [FocusHighlightMode.traditional], then widgets should
  /// draw their focus highlight whenever they are focused.
  // Don't want to set _highlightMode here, since it's possible for the target
  // platform to change (especially in tests).
  FocusHighlightMode get highlightMode => _highlightMode ?? _defaultModeForPlatform;
  FocusHighlightMode? _highlightMode;

  // If set, indicates if the last interaction detected was touch or not.
  // If null, no interactions have occurred yet.
  bool? _lastInteractionWasTouch;

  // Update function to be called whenever the state relating to highlightMode
  // changes.
  void _updateHighlightMode() {
    final FocusHighlightMode newMode;
    switch (highlightStrategy) {
      case FocusHighlightStrategy.automatic:
        if (_lastInteractionWasTouch == null) {
          // If we don't have any information about the last interaction yet,
          // then just rely on the default value for the platform, which will be
          // determined based on the target platform if _highlightMode is not
          // set.
          return;
        }
        if (_lastInteractionWasTouch!) {
          newMode = FocusHighlightMode.touch;
        } else {
          newMode = FocusHighlightMode.traditional;
        }
        break;
      case FocusHighlightStrategy.alwaysTouch:
        newMode = FocusHighlightMode.touch;
        break;
      case FocusHighlightStrategy.alwaysTraditional:
        newMode = FocusHighlightMode.traditional;
        break;
    }
    // We can't just compare newMode with _highlightMode here, since
    // _highlightMode could be null, so we want to compare with the return value
    // for the getter, since that's what clients will be looking at.
    final FocusHighlightMode oldMode = highlightMode;
    _highlightMode = newMode;
    if (highlightMode != oldMode) {
      _notifyHighlightModeListeners();
    }
  }

  // The list of listeners for [highlightMode] state changes.
  final HashedObserverList<ValueChanged<FocusHighlightMode>> _listeners = HashedObserverList<ValueChanged<FocusHighlightMode>>();

  /// Register a closure to be called when the [FocusManager] notifies its listeners
  /// that the value of [highlightMode] has changed.
  void addHighlightModeListener(ValueChanged<FocusHighlightMode> listener) => _listeners.add(listener);

  /// Remove a previously registered closure from the list of closures that the
  /// [FocusManager] notifies.
  void removeHighlightModeListener(ValueChanged<FocusHighlightMode> listener) => _listeners.remove(listener);

  void _notifyHighlightModeListeners() {
    if (_listeners.isEmpty) {
      return;
    }
    final List<ValueChanged<FocusHighlightMode>> localListeners = List<ValueChanged<FocusHighlightMode>>.from(_listeners);
    for (final ValueChanged<FocusHighlightMode> listener in localListeners) {
      try {
        if (_listeners.contains(listener)) {
          listener(highlightMode);
        }
      } catch (exception, stack) {
        InformationCollector? collector;
        assert(() {
          collector = () sync* {
            yield DiagnosticsProperty<FocusManager>(
              'The $runtimeType sending notification was',
              this,
              style: DiagnosticsTreeStyle.errorProperty,
            );
          };
          return true;
        }());
        FlutterError.reportError(FlutterErrorDetails(
          exception: exception,
          stack: stack,
          library: 'widgets library',
          context: ErrorDescription('while dispatching notifications for $runtimeType'),
          informationCollector: collector,
        ));
      }
    }
  }

  /// The root [FocusScopeNode] in the focus tree.
  ///
  /// This field is rarely used directly. To find the nearest [FocusScopeNode]
  /// for a given [FocusNode], call [FocusNode.nearestScope].
  final FocusScopeNode rootScope = FocusScopeNode(debugLabel: 'Root Focus Scope');

  void _handlePointerEvent(PointerEvent event) {
    final FocusHighlightMode expectedMode;
    switch (event.kind) {
      case PointerDeviceKind.touch:
      case PointerDeviceKind.stylus:
      case PointerDeviceKind.invertedStylus:
        _lastInteractionWasTouch = true;
        expectedMode = FocusHighlightMode.touch;
        break;
      case PointerDeviceKind.mouse:
      case PointerDeviceKind.unknown:
        _lastInteractionWasTouch = false;
        expectedMode = FocusHighlightMode.traditional;
        break;
    }
    if (expectedMode != highlightMode) {
      _updateHighlightMode();
    }
  }

  bool _handleRawKeyEvent(RawKeyEvent event) {
    // Update highlightMode first, since things responding to the keys might
    // look at the highlight mode, and it should be accurate.
    _lastInteractionWasTouch = false;
    _updateHighlightMode();

    assert(_focusDebug('Received key event ${event.logicalKey}'));
    if (_primaryFocus == null) {
      assert(_focusDebug('No primary focus for key event, ignored: $event'));
      return false;
    }

    // Walk the current focus from the leaf to the root, calling each one's
    // onKey on the way up, and if one responds that they handled it or want to
    // stop propagation, stop.
    bool handled = false;
    for (final FocusNode node in <FocusNode>[_primaryFocus!, ..._primaryFocus!.ancestors]) {
      if (node.onKey != null) {
        // TODO(gspencergoog): Convert this from dynamic to KeyEventResult once migration is complete.
        final dynamic result = node.onKey!(node, event);
        assert(result is bool || result is KeyEventResult,
            'Value returned from onKey handler must be a non-null bool or KeyEventResult, not ${result.runtimeType}');
        if (result is KeyEventResult) {
          switch (result) {
            case KeyEventResult.handled:
              assert(_focusDebug('Node $node handled key event $event.'));
              handled = true;
              break;
            case KeyEventResult.skipRemainingHandlers:
              assert(_focusDebug('Node $node stopped key event propagation: $event.'));
              handled = false;
              break;
            case KeyEventResult.ignored:
              continue;
          }
        } else if (result is bool){
          if (result) {
            assert(_focusDebug('Node $node handled key event $event.'));
            handled = true;
            break;
          } else {
            continue;
          }
        }
        break;
      }
    }
    if (!handled) {
      assert(_focusDebug('Key event not handled by anyone: $event.'));
    }
    return handled;
  }

  /// The node that currently has the primary focus.
  FocusNode? get primaryFocus => _primaryFocus;
  FocusNode? _primaryFocus;

  // The set of nodes that need to notify their listeners of changes at the next
  // update.
  final Set<FocusNode> _dirtyNodes = <FocusNode>{};

  // The node that has requested to have the primary focus, but hasn't been
  // given it yet.
  FocusNode? _markedForFocus;

  void _markDetached(FocusNode node) {
    // The node has been removed from the tree, so it no longer needs to be
    // notified of changes.
    assert(_focusDebug('Node was detached: $node'));
    if (_primaryFocus == node) {
      _primaryFocus = null;
    }
    _dirtyNodes.remove(node);
  }

  void _markPropertiesChanged(FocusNode node) {
    _markNeedsUpdate();
    assert(_focusDebug('Properties changed for node $node.'));
    _dirtyNodes.add(node);
  }

  void _markNextFocus(FocusNode node) {
    if (_primaryFocus == node) {
      // The caller asked for the current focus to be the next focus, so just
      // pretend that didn't happen.
      _markedForFocus = null;
    } else {
      _markedForFocus = node;
      _markNeedsUpdate();
    }
  }

  // True indicates that there is an update pending.
  bool _haveScheduledUpdate = false;

  // Request that an update be scheduled, optionally requesting focus for the
  // given newFocus node.
  void _markNeedsUpdate() {
    assert(_focusDebug('Scheduling update, current focus is $_primaryFocus, next focus will be $_markedForFocus'));
    if (_haveScheduledUpdate) {
      return;
    }
    _haveScheduledUpdate = true;
    scheduleMicrotask(_applyFocusChange);
  }

  void _applyFocusChange() {
    _haveScheduledUpdate = false;
    final FocusNode? previousFocus = _primaryFocus;
    if (_primaryFocus == null && _markedForFocus == null) {
      // If we don't have any current focus, and nobody has asked to focus yet,
      // then revert to the root scope.
      _markedForFocus = rootScope;
    }
    assert(_focusDebug('Refreshing focus state. Next focus will be $_markedForFocus'));
    // A node has requested to be the next focus, and isn't already the primary
    // focus.
    if (_markedForFocus != null && _markedForFocus != _primaryFocus) {
      final Set<FocusNode> previousPath = previousFocus?.ancestors.toSet() ?? <FocusNode>{};
      final Set<FocusNode> nextPath = _markedForFocus!.ancestors.toSet();
      // Notify nodes that are newly focused.
      _dirtyNodes.addAll(nextPath.difference(previousPath));
      // Notify nodes that are no longer focused
      _dirtyNodes.addAll(previousPath.difference(nextPath));

      _primaryFocus = _markedForFocus;
      _markedForFocus = null;
    }
    if (previousFocus != _primaryFocus) {
      assert(_focusDebug('Updating focus from $previousFocus to $_primaryFocus'));
      if (previousFocus != null) {
        _dirtyNodes.add(previousFocus);
      }
      if (_primaryFocus != null) {
        _dirtyNodes.add(_primaryFocus!);
      }
    }
    assert(_focusDebug('Notifying ${_dirtyNodes.length} dirty nodes:', _dirtyNodes.toList().map<String>((FocusNode node) => node.toString())));
    for (final FocusNode node in _dirtyNodes) {
      node._notify();
    }
    _dirtyNodes.clear();
    if (previousFocus != _primaryFocus) {
      notifyListeners();
    }
    assert(() {
      if (_kDebugFocus) {
        debugDumpFocusTree();
      }
      return true;
    }());
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    return <DiagnosticsNode>[
      rootScope.toDiagnosticsNode(name: 'rootScope'),
    ];
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties.add(FlagProperty('haveScheduledUpdate', value: _haveScheduledUpdate, ifTrue: 'UPDATE SCHEDULED'));
    properties.add(DiagnosticsProperty<FocusNode>('primaryFocus', primaryFocus, defaultValue: null));
    properties.add(DiagnosticsProperty<FocusNode>('nextFocus', _markedForFocus, defaultValue: null));
    final Element? element = primaryFocus?.context as Element?;
    if (element != null) {
      properties.add(DiagnosticsProperty<String>('primaryFocusCreator', element.debugGetCreatorChain(20)));
    }
  }
}

/// Provides convenient access to the current [FocusManager.primaryFocus] from the
/// [WidgetsBinding] instance.
FocusNode? get primaryFocus => WidgetsBinding.instance!.focusManager.primaryFocus;

/// Returns a text representation of the current focus tree, along with the
/// current attributes on each node.
///
/// Will return an empty string in release builds.
String debugDescribeFocusTree() {
  assert(WidgetsBinding.instance != null);
  String? result;
  assert(() {
    result = FocusManager.instance.toStringDeep();
    return true;
  }());
  return result ?? '';
}

/// Prints a text representation of the current focus tree, along with the
/// current attributes on each node.
///
/// Will do nothing in release builds.
void debugDumpFocusTree() {
  assert(() {
    debugPrint(debugDescribeFocusTree());
    return true;
  }());
}
