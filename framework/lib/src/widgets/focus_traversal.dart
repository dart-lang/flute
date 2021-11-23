// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flute/ui.dart';

import 'package:flute/foundation.dart';
import 'package:flute/painting.dart';

import 'actions.dart';
import 'basic.dart';
import 'editable_text.dart';
import 'focus_manager.dart';
import 'focus_scope.dart';
import 'framework.dart';
import 'scroll_position.dart';
import 'scrollable.dart';

// BuildContext/Element doesn't have a parent accessor, but it can be simulated
// with visitAncestorElements. _getAncestor is needed because
// context.getElementForInheritedWidgetOfExactType will return itself if it
// happens to be of the correct type. _getAncestor should be O(count), since we
// always return false at a specific ancestor. By default it returns the parent,
// which is O(1).
BuildContext? _getAncestor(BuildContext context, {int count = 1}) {
  BuildContext? target;
  context.visitAncestorElements((Element ancestor) {
    count--;
    if (count == 0) {
      target = ancestor;
      return false;
    }
    return true;
  });
  return target;
}

void _focusAndEnsureVisible(
  FocusNode node, {
  ScrollPositionAlignmentPolicy alignmentPolicy = ScrollPositionAlignmentPolicy.explicit,
}) {
  node.requestFocus();
  Scrollable.ensureVisible(node.context!, alignment: 1.0, alignmentPolicy: alignmentPolicy);
}

// A class to temporarily hold information about FocusTraversalGroups when
// sorting their contents.
class _FocusTraversalGroupInfo {
  _FocusTraversalGroupInfo(
    _FocusTraversalGroupMarker? marker, {
    FocusTraversalPolicy? defaultPolicy,
    List<FocusNode>? members,
  })  : groupNode = marker?.focusNode,
        policy = marker?.policy ?? defaultPolicy ?? ReadingOrderTraversalPolicy(),
        members = members ?? <FocusNode>[];

  final FocusNode? groupNode;
  final FocusTraversalPolicy policy;
  final List<FocusNode> members;
}

/// A direction along either the horizontal or vertical axes.
///
/// This is used by the [DirectionalFocusTraversalPolicyMixin], and
/// [FocusNode.focusInDirection] to indicate which direction to look in for the
/// next focus.
enum TraversalDirection {
  /// Indicates a direction above the currently focused widget.
  up,

  /// Indicates a direction to the right of the currently focused widget.
  ///
  /// This direction is unaffected by the [Directionality] of the current
  /// context.
  right,

  /// Indicates a direction below the currently focused widget.
  down,

  /// Indicates a direction to the left of the currently focused widget.
  ///
  /// This direction is unaffected by the [Directionality] of the current
  /// context.
  left,

  // TODO(gspencer): Add diagonal traversal directions used by TV remotes and
  // game controllers when we support them.
}

/// An object used to specify a focus traversal policy used for configuring a
/// [FocusTraversalGroup] widget.
///
/// The focus traversal policy is what determines which widget is "next",
/// "previous", or in a direction from the widget associated with the currently
/// focused [FocusNode] (usually a [Focus] widget).
///
/// One of the pre-defined subclasses may be used, or define a custom policy to
/// create a unique focus order.
///
/// When defining your own, your subclass should implement [sortDescendants] to
/// provide the order in which you would like the descendants to be traversed.
///
/// See also:
///
///  * [FocusNode], for a description of the focus system.
///  * [FocusTraversalGroup], a widget that groups together and imposes a
///    traversal policy on the [Focus] nodes below it in the widget hierarchy.
///  * [FocusNode], which is affected by the traversal policy.
///  * [WidgetOrderTraversalPolicy], a policy that relies on the widget
///    creation order to describe the order of traversal.
///  * [ReadingOrderTraversalPolicy], a policy that describes the order as the
///    natural "reading order" for the current [Directionality].
///  * [OrderedTraversalPolicy], a policy that describes the order
///    explicitly using [FocusTraversalOrder] widgets.
///  * [DirectionalFocusTraversalPolicyMixin] a mixin class that implements
///    focus traversal in a direction.
@immutable
abstract class FocusTraversalPolicy with Diagnosticable {
  /// A const constructor so subclasses can be const.
  const FocusTraversalPolicy();

  /// Returns the node that should receive focus if focus is traversing
  /// forwards, and there is no current focus.
  ///
  /// The node returned is the node that should receive focus if focus is
  /// traversing forwards (i.e. with [next]), and there is no current focus in
  /// the nearest [FocusScopeNode] that `currentNode` belongs to.
  ///
  /// The `currentNode` argument must not be null.
  ///
  /// The default implementation returns the [FocusScopeNode.focusedChild], if
  /// set, on the nearest scope of the `currentNode`, otherwise, returns the
  /// first node from [sortDescendants], or the given `currentNode` if there are
  /// no descendants.
  ///
  /// See also:
  ///
  ///  * [next], the function that is called to move the focus to the next node.
  ///  * [DirectionalFocusTraversalPolicyMixin.findFirstFocusInDirection], a
  ///    function that finds the first focusable widget in a particular direction.
  FocusNode? findFirstFocus(FocusNode currentNode) => _findInitialFocus(currentNode);

  /// Returns the node that should receive focus if focus is traversing
  /// backwards, and there is no current focus.
  ///
  /// The node returned is the one that should receive focus if focus is
  /// traversing backwards (i.e. with [previous]), and there is no current focus
  /// in the nearest [FocusScopeNode] that `currentNode` belongs to.
  ///
  /// The `currentNode` argument must not be null.
  ///
  /// The default implementation returns the [FocusScopeNode.focusedChild], if
  /// set, on the nearest scope of the `currentNode`, otherwise, returns the
  /// last node from [sortDescendants], or the given `currentNode` if there are
  /// no descendants.
  ///
  /// See also:
  ///
  ///  * [previous], the function that is called to move the focus to the next node.
  ///  * [DirectionalFocusTraversalPolicyMixin.findFirstFocusInDirection], a
  ///    function that finds the first focusable widget in a particular direction.
  FocusNode findLastFocus(FocusNode currentNode) => _findInitialFocus(currentNode, fromEnd: true);

  FocusNode _findInitialFocus(FocusNode currentNode, {bool fromEnd = false}) {
    assert(currentNode != null);
    final FocusScopeNode scope = currentNode.nearestScope!;
    FocusNode? candidate = scope.focusedChild;
    if (candidate == null && scope.descendants.isNotEmpty) {
      final Iterable<FocusNode> sorted = _sortAllDescendants(scope, currentNode);
      if (sorted.isEmpty) {
        candidate = null;
      } else {
        candidate = fromEnd ? sorted.last : sorted.first;
      }
    }

    // If we still didn't find any candidate, use the current node as a
    // fallback.
    candidate ??= currentNode;
    return candidate;
  }

  /// Returns the first node in the given `direction` that should receive focus
  /// if there is no current focus in the scope to which the `currentNode`
  /// belongs.
  ///
  /// This is typically used by [inDirection] to determine which node to focus
  /// if it is called when no node is currently focused.
  ///
  /// All arguments must not be null.
  FocusNode? findFirstFocusInDirection(FocusNode currentNode, TraversalDirection direction);

  /// Clears the data associated with the given [FocusScopeNode] for this object.
  ///
  /// This is used to indicate that the focus policy has changed its mode, and
  /// so any cached policy data should be invalidated. For example, changing the
  /// direction in which focus is moving, or changing from directional to
  /// next/previous navigation modes.
  ///
  /// The default implementation does nothing.
  @mustCallSuper
  @protected
  void invalidateScopeData(FocusScopeNode node) {}

  /// This is called whenever the given [node] is re-parented into a new scope,
  /// so that the policy has a chance to update or invalidate any cached data
  /// that it maintains per scope about the node.
  ///
  /// The [oldScope] is the previous scope that this node belonged to, if any.
  ///
  /// The default implementation does nothing.
  @mustCallSuper
  void changedScope({FocusNode? node, FocusScopeNode? oldScope}) {}

  /// Focuses the next widget in the focus scope that contains the given
  /// [currentNode].
  ///
  /// This should determine what the next node to receive focus should be by
  /// inspecting the node tree, and then calling [FocusNode.requestFocus] on
  /// the node that has been selected.
  ///
  /// Returns true if it successfully found a node and requested focus.
  ///
  /// The [currentNode] argument must not be null.
  bool next(FocusNode currentNode) => _moveFocus(currentNode, forward: true);

  /// Focuses the previous widget in the focus scope that contains the given
  /// [currentNode].
  ///
  /// This should determine what the previous node to receive focus should be by
  /// inspecting the node tree, and then calling [FocusNode.requestFocus] on
  /// the node that has been selected.
  ///
  /// Returns true if it successfully found a node and requested focus.
  ///
  /// The [currentNode] argument must not be null.
  bool previous(FocusNode currentNode) => _moveFocus(currentNode, forward: false);

  /// Focuses the next widget in the given [direction] in the focus scope that
  /// contains the given [currentNode].
  ///
  /// This should determine what the next node to receive focus in the given
  /// [direction] should be by inspecting the node tree, and then calling
  /// [FocusNode.requestFocus] on the node that has been selected.
  ///
  /// Returns true if it successfully found a node and requested focus.
  ///
  /// All arguments must not be null.
  bool inDirection(FocusNode currentNode, TraversalDirection direction);

  /// Sorts the given `descendants` into focus order.
  ///
  /// Subclasses should override this to implement a different sort for [next]
  /// and [previous] to use in their ordering. If the returned iterable omits a
  /// node that is a descendant of the given scope, then the user will be unable
  /// to use next/previous keyboard traversal to reach that node.
  ///
  /// The node used to initiate the traversal (the one passed to [next] or
  /// [previous]) is passed as `currentNode`.
  ///
  /// Having the current node in the list is what allows the algorithm to
  /// determine which nodes are adjacent to the current node. If the
  /// `currentNode` is removed from the list, then the focus will be unchanged
  /// when [next] or [previous] are called, and they will return false.
  ///
  /// This is not used for directional focus ([inDirection]), only for
  /// determining the focus order for [next] and [previous].
  ///
  /// When implementing an override for this function, be sure to use
  /// [mergeSort] instead of Dart's default list sorting algorithm when sorting
  /// items, since the default algorithm is not stable (items deemed to be equal
  /// can appear in arbitrary order, and change positions between sorts), whereas
  /// [mergeSort] is stable.
  @protected
  Iterable<FocusNode> sortDescendants(Iterable<FocusNode> descendants, FocusNode currentNode);

  _FocusTraversalGroupMarker? _getMarker(BuildContext? context) {
    return context?.getElementForInheritedWidgetOfExactType<_FocusTraversalGroupMarker>()?.widget as _FocusTraversalGroupMarker?;
  }

  // Sort all descendants, taking into account the FocusTraversalGroup
  // that they are each in, and filtering out non-traversable/focusable nodes.
  List<FocusNode> _sortAllDescendants(FocusScopeNode scope, FocusNode currentNode) {
    assert(scope != null);
    final _FocusTraversalGroupMarker? scopeGroupMarker = _getMarker(scope.context);
    final FocusTraversalPolicy defaultPolicy = scopeGroupMarker?.policy ?? ReadingOrderTraversalPolicy();
    // Build the sorting data structure, separating descendants into groups.
    final Map<FocusNode?, _FocusTraversalGroupInfo> groups = <FocusNode?, _FocusTraversalGroupInfo>{};
    for (final FocusNode node in scope.descendants) {
      final _FocusTraversalGroupMarker? groupMarker = _getMarker(node.context);
      final FocusNode? groupNode = groupMarker?.focusNode;
      // Group nodes need to be added to their parent's node, or to the "null"
      // node if no parent is found. This creates the hierarchy of group nodes
      // and makes it so the entire group is sorted along with the other members
      // of the parent group.
      if (node == groupNode) {
        // To find the parent of the group node, we need to skip over the parent
        // of the Focus node in _FocusTraversalGroupState.build, and start
        // looking with that node's parent, since _getMarker will return the
        // context it was called on if it matches the type.
        final BuildContext? parentContext = _getAncestor(groupNode!.context!, count: 2);
        final _FocusTraversalGroupMarker? parentMarker = _getMarker(parentContext);
        final FocusNode? parentNode = parentMarker?.focusNode;
        groups[parentNode] ??= _FocusTraversalGroupInfo(parentMarker, members: <FocusNode>[], defaultPolicy: defaultPolicy);
        assert(!groups[parentNode]!.members.contains(node));
        groups[parentNode]!.members.add(groupNode);
        continue;
      }
      // Skip non-focusable and non-traversable nodes in the same way that
      // FocusScopeNode.traversalDescendants would.
      if (node.canRequestFocus && !node.skipTraversal) {
        groups[groupNode] ??= _FocusTraversalGroupInfo(groupMarker, members: <FocusNode>[], defaultPolicy: defaultPolicy);
        assert(!groups[groupNode]!.members.contains(node));
        groups[groupNode]!.members.add(node);
      }
    }

    // Sort the member lists using the individual policy sorts.
    final Set<FocusNode?> groupKeys = groups.keys.toSet();
    for (final FocusNode? key in groups.keys) {
      final List<FocusNode> sortedMembers = groups[key]!.policy.sortDescendants(groups[key]!.members, currentNode).toList();
      groups[key]!.members.clear();
      groups[key]!.members.addAll(sortedMembers);
    }

    // Traverse the group tree, adding the children of members in the order they
    // appear in the member lists.
    final List<FocusNode> sortedDescendants = <FocusNode>[];
    void visitGroups(_FocusTraversalGroupInfo info) {
      for (final FocusNode node in info.members) {
        if (groupKeys.contains(node)) {
          // This is a policy group focus node. Replace it with the members of
          // the corresponding policy group.
          visitGroups(groups[node]!);
        } else {
          sortedDescendants.add(node);
        }
      }
    }

    visitGroups(groups[scopeGroupMarker?.focusNode]!);
    assert(
      sortedDescendants.length <= scope.traversalDescendants.length && sortedDescendants.toSet().difference(scope.traversalDescendants.toSet()).isEmpty,
      'sorted descendants contains more nodes than it should: (${sortedDescendants.toSet().difference(scope.traversalDescendants.toSet())})'
    );
    return sortedDescendants;
  }

  /// Moves the focus to the next node in the FocusScopeNode nearest to the
  /// currentNode argument, either in a forward or reverse direction, depending
  /// on the value of the forward argument.
  ///
  /// This function is called by the next and previous members to move to the
  /// next or previous node, respectively.
  ///
  /// Uses [findFirstFocus]/[findLastFocus] to find the first/last node if there is
  /// no [FocusScopeNode.focusedChild] set. If there is a focused child for the
  /// scope, then it calls sortDescendants to get a sorted list of descendants,
  /// and then finds the node after the current first focus of the scope if
  /// forward is true, and the node before it if forward is false.
  ///
  /// Returns true if a node requested focus.
  @protected
  bool _moveFocus(FocusNode currentNode, {required bool forward}) {
    assert(forward != null);
    final FocusScopeNode nearestScope = currentNode.nearestScope!;
    invalidateScopeData(nearestScope);
    final FocusNode? focusedChild = nearestScope.focusedChild;
    if (focusedChild == null) {
      final FocusNode? firstFocus = forward ? findFirstFocus(currentNode) : findLastFocus(currentNode);
      if (firstFocus != null) {
        _focusAndEnsureVisible(
          firstFocus,
          alignmentPolicy: forward ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
        return true;
      }
    }
    final List<FocusNode> sortedNodes = _sortAllDescendants(nearestScope, currentNode);
    if (forward && focusedChild == sortedNodes.last) {
      _focusAndEnsureVisible(sortedNodes.first, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
      return true;
    }
    if (!forward && focusedChild == sortedNodes.first) {
      _focusAndEnsureVisible(sortedNodes.last, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart);
      return true;
    }

    final Iterable<FocusNode> maybeFlipped = forward ? sortedNodes : sortedNodes.reversed;
    FocusNode? previousNode;
    for (final FocusNode node in maybeFlipped) {
      if (previousNode == focusedChild) {
        _focusAndEnsureVisible(
          node,
          alignmentPolicy: forward ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
        return true;
      }
      previousNode = node;
    }
    return false;
  }
}

// A policy data object for use by the DirectionalFocusTraversalPolicyMixin so
// it can keep track of the traversal history.
class _DirectionalPolicyDataEntry {
  const _DirectionalPolicyDataEntry({required this.direction, required this.node})
      : assert(direction != null),
        assert(node != null);

  final TraversalDirection direction;
  final FocusNode node;
}

class _DirectionalPolicyData {
  const _DirectionalPolicyData({required this.history}) : assert(history != null);

  /// A queue of entries that describe the path taken to the current node.
  final List<_DirectionalPolicyDataEntry> history;
}

/// A mixin class that provides an implementation for finding a node in a
/// particular direction.
///
/// This can be mixed in to other [FocusTraversalPolicy] implementations that
/// only want to implement new next/previous policies.
///
/// Since hysteresis in the navigation order is undesirable, this implementation
/// maintains a stack of previous locations that have been visited on the
/// policy data for the affected [FocusScopeNode]. If the previous direction
/// was the opposite of the current direction, then the this policy will request
/// focus on the previously focused node. Change to another direction other than
/// the current one or its opposite will clear the stack.
///
/// For instance, if the focus moves down, down, down, and then up, up, up, it
/// will follow the same path through the widgets in both directions. However,
/// if it moves down, down, down, left, right, and then up, up, up, it may not
/// follow the same path on the way up as it did on the way down, since changing
/// the axis of motion resets the history.
///
/// See also:
///
///  * [FocusNode], for a description of the focus system.
///  * [FocusTraversalGroup], a widget that groups together and imposes a
///    traversal policy on the [Focus] nodes below it in the widget hierarchy.
///  * [WidgetOrderTraversalPolicy], a policy that relies on the widget
///    creation order to describe the order of traversal.
///  * [ReadingOrderTraversalPolicy], a policy that describes the order as the
///    natural "reading order" for the current [Directionality].
///  * [OrderedTraversalPolicy], a policy that describes the order
///    explicitly using [FocusTraversalOrder] widgets.
mixin DirectionalFocusTraversalPolicyMixin on FocusTraversalPolicy {
  final Map<FocusScopeNode, _DirectionalPolicyData> _policyData = <FocusScopeNode, _DirectionalPolicyData>{};

  @override
  void invalidateScopeData(FocusScopeNode node) {
    super.invalidateScopeData(node);
    _policyData.remove(node);
  }

  @override
  void changedScope({FocusNode? node, FocusScopeNode? oldScope}) {
    super.changedScope(node: node, oldScope: oldScope);
    if (oldScope != null) {
      _policyData[oldScope]?.history.removeWhere((_DirectionalPolicyDataEntry entry) {
        return entry.node == node;
      });
    }
  }

  @override
  FocusNode? findFirstFocusInDirection(FocusNode currentNode, TraversalDirection direction) {
    assert(direction != null);
    assert(currentNode != null);
    switch (direction) {
      case TraversalDirection.up:
        // Find the bottom-most node so we can go up from there.
        return _sortAndFindInitial(currentNode, vertical: true, first: false);
      case TraversalDirection.down:
        // Find the top-most node so we can go down from there.
        return _sortAndFindInitial(currentNode, vertical: true, first: true);
      case TraversalDirection.left:
        // Find the right-most node so we can go left from there.
        return _sortAndFindInitial(currentNode, vertical: false, first: false);
      case TraversalDirection.right:
        // Find the left-most node so we can go right from there.
        return _sortAndFindInitial(currentNode, vertical: false, first: true);
    }
  }

  FocusNode? _sortAndFindInitial(FocusNode currentNode, {required bool vertical, required bool first}) {
    final Iterable<FocusNode> nodes = currentNode.nearestScope!.traversalDescendants;
    final List<FocusNode> sorted = nodes.toList();
    mergeSort<FocusNode>(sorted, compare: (FocusNode a, FocusNode b) {
      if (vertical) {
        if (first) {
          return a.rect.top.compareTo(b.rect.top);
        } else {
          return b.rect.bottom.compareTo(a.rect.bottom);
        }
      } else {
        if (first) {
          return a.rect.left.compareTo(b.rect.left);
        } else {
          return b.rect.right.compareTo(a.rect.right);
        }
      }
    });

    if (sorted.isNotEmpty) {
      return sorted.first;
    }

    return null;
  }

  // Sorts nodes from left to right horizontally, and removes nodes that are
  // either to the right of the left side of the target node if we're going
  // left, or to the left of the right side of the target node if we're going
  // right.
  //
  // This doesn't need to take into account directionality because it is
  // typically intending to actually go left or right, not in a reading
  // direction.
  Iterable<FocusNode>? _sortAndFilterHorizontally(
    TraversalDirection direction,
    Rect target,
    FocusNode nearestScope,
  ) {
    assert(direction == TraversalDirection.left || direction == TraversalDirection.right);
    final Iterable<FocusNode> nodes = nearestScope.traversalDescendants;
    assert(!nodes.contains(nearestScope));
    final List<FocusNode> sorted = nodes.toList();
    mergeSort<FocusNode>(sorted, compare: (FocusNode a, FocusNode b) => a.rect.center.dx.compareTo(b.rect.center.dx));
    Iterable<FocusNode>? result;
    switch (direction) {
      case TraversalDirection.left:
        result = sorted.where((FocusNode node) => node.rect != target && node.rect.center.dx <= target.left);
        break;
      case TraversalDirection.right:
        result = sorted.where((FocusNode node) => node.rect != target && node.rect.center.dx >= target.right);
        break;
      case TraversalDirection.up:
      case TraversalDirection.down:
        break;
    }
    return result;
  }

  // Sorts nodes from top to bottom vertically, and removes nodes that are
  // either below the top of the target node if we're going up, or above the
  // bottom of the target node if we're going down.
  Iterable<FocusNode>? _sortAndFilterVertically(
    TraversalDirection direction,
    Rect target,
    Iterable<FocusNode> nodes,
  ) {
    final List<FocusNode> sorted = nodes.toList();
    mergeSort<FocusNode>(sorted, compare: (FocusNode a, FocusNode b) => a.rect.center.dy.compareTo(b.rect.center.dy));
    switch (direction) {
      case TraversalDirection.up:
        return sorted.where((FocusNode node) => node.rect != target && node.rect.center.dy <= target.top);
      case TraversalDirection.down:
        return sorted.where((FocusNode node) => node.rect != target && node.rect.center.dy >= target.bottom);
      case TraversalDirection.left:
      case TraversalDirection.right:
        break;
    }
    assert(direction == TraversalDirection.up || direction == TraversalDirection.down);
    return null;
  }

  // Updates the policy data to keep the previously visited node so that we can
  // avoid hysteresis when we change directions in navigation.
  //
  // Returns true if focus was requested on a previous node.
  bool _popPolicyDataIfNeeded(TraversalDirection direction, FocusScopeNode nearestScope, FocusNode focusedChild) {
    final _DirectionalPolicyData? policyData = _policyData[nearestScope];
    if (policyData != null && policyData.history.isNotEmpty && policyData.history.first.direction != direction) {
      if (policyData.history.last.node.parent == null) {
        // If a node has been removed from the tree, then we should stop
        // referencing it and reset the scope data so that we don't try and
        // request focus on it. This can happen in slivers where the rendered
        // node has been unmounted. This has the side effect that hysteresis
        // might not be avoided when items that go off screen get unmounted.
        invalidateScopeData(nearestScope);
        return false;
      }

      // Returns true if successfully popped the history.
      bool popOrInvalidate(TraversalDirection direction) {
        final FocusNode lastNode = policyData.history.removeLast().node;
        if (Scrollable.of(lastNode.context!) != Scrollable.of(primaryFocus!.context!)) {
          invalidateScopeData(nearestScope);
          return false;
        }
        final ScrollPositionAlignmentPolicy alignmentPolicy;
        switch (direction) {
          case TraversalDirection.up:
          case TraversalDirection.left:
            alignmentPolicy = ScrollPositionAlignmentPolicy.keepVisibleAtStart;
            break;
          case TraversalDirection.right:
          case TraversalDirection.down:
            alignmentPolicy = ScrollPositionAlignmentPolicy.keepVisibleAtEnd;
            break;
        }
        _focusAndEnsureVisible(
          lastNode,
          alignmentPolicy: alignmentPolicy,
        );
        return true;
      }

      switch (direction) {
        case TraversalDirection.down:
        case TraversalDirection.up:
          switch (policyData.history.first.direction) {
            case TraversalDirection.left:
            case TraversalDirection.right:
              // Reset the policy data if we change directions.
              invalidateScopeData(nearestScope);
              break;
            case TraversalDirection.up:
            case TraversalDirection.down:
              if (popOrInvalidate(direction)) {
                return true;
              }
              break;
          }
          break;
        case TraversalDirection.left:
        case TraversalDirection.right:
          switch (policyData.history.first.direction) {
            case TraversalDirection.left:
            case TraversalDirection.right:
              if (popOrInvalidate(direction)) {
                return true;
              }
              break;
            case TraversalDirection.up:
            case TraversalDirection.down:
              // Reset the policy data if we change directions.
              invalidateScopeData(nearestScope);
              break;
          }
      }
    }
    if (policyData != null && policyData.history.isEmpty) {
      invalidateScopeData(nearestScope);
    }
    return false;
  }

  void _pushPolicyData(TraversalDirection direction, FocusScopeNode nearestScope, FocusNode focusedChild) {
    final _DirectionalPolicyData? policyData = _policyData[nearestScope];
    final _DirectionalPolicyDataEntry newEntry = _DirectionalPolicyDataEntry(node: focusedChild, direction: direction);
    if (policyData != null) {
      policyData.history.add(newEntry);
    } else {
      _policyData[nearestScope] = _DirectionalPolicyData(history: <_DirectionalPolicyDataEntry>[newEntry]);
    }
  }

  /// Focuses the next widget in the given [direction] in the [FocusScope] that
  /// contains the [currentNode].
  ///
  /// This determines what the next node to receive focus in the given
  /// [direction] will be by inspecting the node tree, and then calling
  /// [FocusNode.requestFocus] on it.
  ///
  /// Returns true if it successfully found a node and requested focus.
  ///
  /// Maintains a stack of previous locations that have been visited on the
  /// policy data for the affected [FocusScopeNode]. If the previous direction
  /// was the opposite of the current direction, then the this policy will
  /// request focus on the previously focused node. Change to another direction
  /// other than the current one or its opposite will clear the stack.
  ///
  /// If this function returns true when called by a subclass, then the subclass
  /// should return true and not request focus from any node.
  @mustCallSuper
  @override
  bool inDirection(FocusNode currentNode, TraversalDirection direction) {
    final FocusScopeNode nearestScope = currentNode.nearestScope!;
    final FocusNode? focusedChild = nearestScope.focusedChild;
    if (focusedChild == null) {
      final FocusNode firstFocus = findFirstFocusInDirection(currentNode, direction) ?? currentNode;
      switch (direction) {
        case TraversalDirection.up:
        case TraversalDirection.left:
          _focusAndEnsureVisible(
            firstFocus,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
          );
          break;
        case TraversalDirection.right:
        case TraversalDirection.down:
          _focusAndEnsureVisible(
            firstFocus,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          );
          break;
      }
      return true;
    }
    if (_popPolicyDataIfNeeded(direction, nearestScope, focusedChild)) {
      return true;
    }
    FocusNode? found;
    final ScrollableState? focusedScrollable = Scrollable.of(focusedChild.context!);
    switch (direction) {
      case TraversalDirection.down:
      case TraversalDirection.up:
        Iterable<FocusNode>? eligibleNodes = _sortAndFilterVertically(
          direction,
          focusedChild.rect,
          nearestScope.traversalDescendants,
        );
        if (focusedScrollable != null && !focusedScrollable.position.atEdge) {
          final Iterable<FocusNode> filteredEligibleNodes = eligibleNodes!.where((FocusNode node) => Scrollable.of(node.context!) == focusedScrollable);
          if (filteredEligibleNodes.isNotEmpty) {
            eligibleNodes = filteredEligibleNodes;
          }
        }
        if (eligibleNodes!.isEmpty) {
          break;
        }
        List<FocusNode> sorted = eligibleNodes.toList();
        if (direction == TraversalDirection.up) {
          sorted = sorted.reversed.toList();
        }
        // Find any nodes that intersect the band of the focused child.
        final Rect band = Rect.fromLTRB(focusedChild.rect.left, -double.infinity, focusedChild.rect.right, double.infinity);
        final Iterable<FocusNode> inBand = sorted.where((FocusNode node) => !node.rect.intersect(band).isEmpty);
        if (inBand.isNotEmpty) {
          // The inBand list is already sorted by horizontal distance, so pick
          // the closest one.
          found = inBand.first;
          break;
        }
        // Only out-of-band targets remain, so pick the one that is closest the
        // to the center line horizontally.
        mergeSort<FocusNode>(sorted, compare: (FocusNode a, FocusNode b) {
          return (a.rect.center.dx - focusedChild.rect.center.dx).abs().compareTo((b.rect.center.dx - focusedChild.rect.center.dx).abs());
        });
        found = sorted.first;
        break;
      case TraversalDirection.right:
      case TraversalDirection.left:
        Iterable<FocusNode>? eligibleNodes = _sortAndFilterHorizontally(direction, focusedChild.rect, nearestScope);
        if (focusedScrollable != null && !focusedScrollable.position.atEdge) {
          final Iterable<FocusNode> filteredEligibleNodes = eligibleNodes!.where((FocusNode node) => Scrollable.of(node.context!) == focusedScrollable);
          if (filteredEligibleNodes.isNotEmpty) {
            eligibleNodes = filteredEligibleNodes;
          }
        }
        if (eligibleNodes!.isEmpty) {
          break;
        }
        List<FocusNode> sorted = eligibleNodes.toList();
        if (direction == TraversalDirection.left) {
          sorted = sorted.reversed.toList();
        }
        // Find any nodes that intersect the band of the focused child.
        final Rect band = Rect.fromLTRB(-double.infinity, focusedChild.rect.top, double.infinity, focusedChild.rect.bottom);
        final Iterable<FocusNode> inBand = sorted.where((FocusNode node) => !node.rect.intersect(band).isEmpty);
        if (inBand.isNotEmpty) {
          // The inBand list is already sorted by vertical distance, so pick the
          // closest one.
          found = inBand.first;
          break;
        }
        // Only out-of-band targets remain, so pick the one that is closest the
        // to the center line vertically.
        mergeSort<FocusNode>(sorted, compare: (FocusNode a, FocusNode b) {
          return (a.rect.center.dy - focusedChild.rect.center.dy).abs().compareTo((b.rect.center.dy - focusedChild.rect.center.dy).abs());
        });
        found = sorted.first;
        break;
    }
    if (found != null) {
      _pushPolicyData(direction, nearestScope, focusedChild);
      switch (direction) {
        case TraversalDirection.up:
        case TraversalDirection.left:
          _focusAndEnsureVisible(
            found,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
          );
          break;
        case TraversalDirection.down:
        case TraversalDirection.right:
          _focusAndEnsureVisible(
            found,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          );
          break;
      }
      return true;
    }
    return false;
  }
}

/// A [FocusTraversalPolicy] that traverses the focus order in widget hierarchy
/// order.
///
/// This policy is used when the order desired is the order in which widgets are
/// created in the widget hierarchy.
///
/// See also:
///
///  * [FocusNode], for a description of the focus system.
///  * [FocusTraversalGroup], a widget that groups together and imposes a
///    traversal policy on the [Focus] nodes below it in the widget hierarchy.
///  * [ReadingOrderTraversalPolicy], a policy that describes the order as the
///    natural "reading order" for the current [Directionality].
///  * [DirectionalFocusTraversalPolicyMixin] a mixin class that implements
///    focus traversal in a direction.
///  * [OrderedTraversalPolicy], a policy that describes the order
///    explicitly using [FocusTraversalOrder] widgets.
class WidgetOrderTraversalPolicy extends FocusTraversalPolicy with DirectionalFocusTraversalPolicyMixin {
  @override
  Iterable<FocusNode> sortDescendants(Iterable<FocusNode> descendants, FocusNode currentNode) => descendants;
}

// This class exists mainly for efficiency reasons: the rect is copied out of
// the node, because it will be accessed many times in the reading order
// algorithm, and the FocusNode.rect accessor does coordinate transformation. If
// not for this optimization, it could just be removed, and the node used
// directly.
//
// It's also a convenient place to put some utility functions having to do with
// the sort data.
class _ReadingOrderSortData with Diagnosticable {
  _ReadingOrderSortData(this.node)
      : assert(node != null),
        rect = node.rect,
        directionality = _findDirectionality(node.context!);

  final TextDirection? directionality;
  final Rect rect;
  final FocusNode node;

  // Find the directionality in force for a build context without creating a
  // dependency.
  static TextDirection? _findDirectionality(BuildContext context) {
    return (context.getElementForInheritedWidgetOfExactType<Directionality>()?.widget as Directionality?)?.textDirection;
  }

  /// Finds the common Directional ancestor of an entire list of groups.
  static TextDirection? commonDirectionalityOf(List<_ReadingOrderSortData> list) {
    final Iterable<Set<Directionality>> allAncestors = list.map<Set<Directionality>>((_ReadingOrderSortData member) => member.directionalAncestors.toSet());
    Set<Directionality>? common;
    for (final Set<Directionality> ancestorSet in allAncestors) {
      common ??= ancestorSet;
      common = common.intersection(ancestorSet);
    }
    if (common!.isEmpty) {
      // If there is no common ancestor, then arbitrarily pick the
      // directionality of the first group, which is the equivalent of the "first
      // strongly typed" item in a bidi algorithm.
      return list.first.directionality;
    }
    // Find the closest common ancestor. The memberAncestors list contains the
    // ancestors for all members, but the first member's ancestry was
    // added in order from nearest to furthest, so we can still use that
    // to determine the closest one.
    return list.first.directionalAncestors.firstWhere(common.contains).textDirection;
  }

  static void sortWithDirectionality(List<_ReadingOrderSortData> list, TextDirection directionality) {
    mergeSort<_ReadingOrderSortData>(list, compare: (_ReadingOrderSortData a, _ReadingOrderSortData b) {
      switch (directionality) {
        case TextDirection.ltr:
          return a.rect.left.compareTo(b.rect.left);
        case TextDirection.rtl:
          return b.rect.right.compareTo(a.rect.right);
      }
    });
  }

  /// Returns the list of Directionality ancestors, in order from nearest to
  /// furthest.
  Iterable<Directionality> get directionalAncestors {
    List<Directionality> getDirectionalityAncestors(BuildContext context) {
      final List<Directionality> result = <Directionality>[];
      InheritedElement? directionalityElement = context.getElementForInheritedWidgetOfExactType<Directionality>();
      while (directionalityElement != null) {
        result.add(directionalityElement.widget as Directionality);
        directionalityElement = _getAncestor(directionalityElement)?.getElementForInheritedWidgetOfExactType<Directionality>();
      }
      return result;
    }

    _directionalAncestors ??= getDirectionalityAncestors(node.context!);
    return _directionalAncestors!;
  }

  List<Directionality>? _directionalAncestors;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TextDirection>('directionality', directionality));
    properties.add(StringProperty('name', node.debugLabel, defaultValue: null));
    properties.add(DiagnosticsProperty<Rect>('rect', rect));
  }
}

// A class for containing group data while sorting in reading order while taking
// into account the ambient directionality.
class _ReadingOrderDirectionalGroupData with Diagnosticable {
  _ReadingOrderDirectionalGroupData(this.members);

  final List<_ReadingOrderSortData> members;

  TextDirection? get directionality => members.first.directionality;

  Rect? _rect;
  Rect get rect {
    if (_rect == null) {
      for (final Rect rect in members.map<Rect>((_ReadingOrderSortData data) => data.rect)) {
        _rect ??= rect;
        _rect = _rect!.expandToInclude(rect);
      }
    }
    return _rect!;
  }

  List<Directionality> get memberAncestors {
    if (_memberAncestors == null) {
      _memberAncestors = <Directionality>[];
      for (final _ReadingOrderSortData member in members) {
        _memberAncestors!.addAll(member.directionalAncestors);
      }
    }
    return _memberAncestors!;
  }

  List<Directionality>? _memberAncestors;

  static void sortWithDirectionality(List<_ReadingOrderDirectionalGroupData> list, TextDirection directionality) {
    mergeSort<_ReadingOrderDirectionalGroupData>(list, compare: (_ReadingOrderDirectionalGroupData a, _ReadingOrderDirectionalGroupData b) {
      switch (directionality) {
        case TextDirection.ltr:
          return a.rect.left.compareTo(b.rect.left);
        case TextDirection.rtl:
          return b.rect.right.compareTo(a.rect.right);
      }
    });
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TextDirection>('directionality', directionality));
    properties.add(DiagnosticsProperty<Rect>('rect', rect));
    properties.add(IterableProperty<String>('members', members.map<String>((_ReadingOrderSortData member) {
      return '"${member.node.debugLabel}"(${member.rect})';
    })));
  }
}

/// Traverses the focus order in "reading order".
///
/// By default, reading order traversal goes in the reading direction, and then
/// down, using this algorithm:
///
/// 1. Find the node rectangle that has the highest `top` on the screen.
/// 2. Find any other nodes that intersect the infinite horizontal band defined
///    by the highest rectangle's top and bottom edges.
/// 3. Pick the closest to the beginning of the reading order from among the
///    nodes discovered above.
///
/// It uses the ambient [Directionality] in the context for the enclosing
/// [FocusTraversalGroup] to determine which direction is "reading order".
///
/// See also:
///
///  * [FocusNode], for a description of the focus system.
///  * [FocusTraversalGroup], a widget that groups together and imposes a
///    traversal policy on the [Focus] nodes below it in the widget hierarchy.
///  * [WidgetOrderTraversalPolicy], a policy that relies on the widget
///    creation order to describe the order of traversal.
///  * [DirectionalFocusTraversalPolicyMixin] a mixin class that implements
///    focus traversal in a direction.
///  * [OrderedTraversalPolicy], a policy that describes the order
///    explicitly using [FocusTraversalOrder] widgets.
class ReadingOrderTraversalPolicy extends FocusTraversalPolicy with DirectionalFocusTraversalPolicyMixin {
  // Collects the given candidates into groups by directionality. The candidates
  // have already been sorted as if they all had the directionality of the
  // nearest Directionality ancestor.
  List<_ReadingOrderDirectionalGroupData> _collectDirectionalityGroups(Iterable<_ReadingOrderSortData> candidates) {
    TextDirection? currentDirection = candidates.first.directionality;
    List<_ReadingOrderSortData> currentGroup = <_ReadingOrderSortData>[];
    final List<_ReadingOrderDirectionalGroupData> result = <_ReadingOrderDirectionalGroupData>[];
    // Split candidates into runs of the same directionality.
    for (final _ReadingOrderSortData candidate in candidates) {
      if (candidate.directionality == currentDirection) {
        currentGroup.add(candidate);
        continue;
      }
      currentDirection = candidate.directionality;
      result.add(_ReadingOrderDirectionalGroupData(currentGroup));
      currentGroup = <_ReadingOrderSortData>[candidate];
    }
    if (currentGroup.isNotEmpty) {
      result.add(_ReadingOrderDirectionalGroupData(currentGroup));
    }
    // Sort each group separately. Each group has the same directionality.
    for (final _ReadingOrderDirectionalGroupData bandGroup in result) {
      if (bandGroup.members.length == 1) {
        continue; // No need to sort one node.
      }
      _ReadingOrderSortData.sortWithDirectionality(bandGroup.members, bandGroup.directionality!);
    }
    return result;
  }

  _ReadingOrderSortData _pickNext(List<_ReadingOrderSortData> candidates) {
    // Find the topmost node by sorting on the top of the rectangles.
    mergeSort<_ReadingOrderSortData>(candidates, compare: (_ReadingOrderSortData a, _ReadingOrderSortData b) => a.rect.top.compareTo(b.rect.top));
    final _ReadingOrderSortData topmost = candidates.first;

    // Find the candidates that are in the same horizontal band as the current one.
    List<_ReadingOrderSortData> inBand(_ReadingOrderSortData current, Iterable<_ReadingOrderSortData> candidates) {
      final Rect band = Rect.fromLTRB(double.negativeInfinity, current.rect.top, double.infinity, current.rect.bottom);
      return candidates.where((_ReadingOrderSortData item) {
        return !item.rect.intersect(band).isEmpty;
      }).toList();
    }

    final List<_ReadingOrderSortData> inBandOfTop = inBand(topmost, candidates);
    // It has to have at least topmost in it if the topmost is not degenerate.
    assert(topmost.rect.isEmpty || inBandOfTop.isNotEmpty);

    // The topmost rect in is in a band by itself, so just return that one.
    if (inBandOfTop.length <= 1) {
      return topmost;
    }

    // Now that we know there are others in the same band as the topmost, then pick
    // the one at the beginning, depending on the text direction in force.

    // Find out the directionality of the nearest common Directionality
    // ancestor for all nodes. This provides a base directionality to use for
    // the ordering of the groups.
    final TextDirection? nearestCommonDirectionality = _ReadingOrderSortData.commonDirectionalityOf(inBandOfTop);

    // Do an initial common-directionality-based sort to get consistent geometric
    // ordering for grouping into directionality groups. It has to use the
    // common directionality to be able to group into sane groups for the
    // given directionality, since rectangles can overlap and give different
    // results for different directionalities.
    _ReadingOrderSortData.sortWithDirectionality(inBandOfTop, nearestCommonDirectionality!);

    // Collect the top band into internally sorted groups with shared directionality.
    final List<_ReadingOrderDirectionalGroupData> bandGroups = _collectDirectionalityGroups(inBandOfTop);
    if (bandGroups.length == 1) {
      // There's only one directionality group, so just send back the first
      // one in that group, since it's already sorted.
      return bandGroups.first.members.first;
    }

    // Sort the groups based on the common directionality and bounding boxes.
    _ReadingOrderDirectionalGroupData.sortWithDirectionality(bandGroups, nearestCommonDirectionality);
    return bandGroups.first.members.first;
  }

  // Sorts the list of nodes based on their geometry into the desired reading
  // order based on the directionality of the context for each node.
  @override
  Iterable<FocusNode> sortDescendants(Iterable<FocusNode> descendants, FocusNode currentNode) {
    assert(descendants != null);
    if (descendants.length <= 1) {
      return descendants;
    }

    final List<_ReadingOrderSortData> data = <_ReadingOrderSortData>[
      for (final FocusNode node in descendants) _ReadingOrderSortData(node),
    ];

    final List<FocusNode> sortedList = <FocusNode>[];
    final List<_ReadingOrderSortData> unplaced = data;

    // Pick the initial widget as the one that is at the beginning of the band
    // of the topmost, or the topmost, if there are no others in its band.
    _ReadingOrderSortData current = _pickNext(unplaced);
    sortedList.add(current.node);
    unplaced.remove(current);

    // Go through each node, picking the next one after eliminating the previous
    // one, since removing the previously picked node will expose a new band in
    // which to choose candidates.
    while (unplaced.isNotEmpty) {
      final _ReadingOrderSortData next = _pickNext(unplaced);
      current = next;
      sortedList.add(current.node);
      unplaced.remove(current);
    }
    return sortedList;
  }
}

/// Base class for all sort orders for [OrderedTraversalPolicy] traversal.
///
/// {@template flutter.widgets.FocusOrder.comparable}
/// Only orders of the same type are comparable. If a set of widgets in the same
/// [FocusTraversalGroup] contains orders that are not comparable with each
/// other, it will assert, since the ordering between such keys is undefined. To
/// avoid collisions, use a [FocusTraversalGroup] to group similarly ordered
/// widgets together.
///
/// When overriding, [FocusOrder.doCompare] must be overridden instead of
/// [FocusOrder.compareTo], which calls [FocusOrder.doCompare] to do the actual
/// comparison.
/// {@endtemplate}
///
/// See also:
///
/// * [FocusTraversalGroup], a widget that groups together and imposes a
///   traversal policy on the [Focus] nodes below it in the widget hierarchy.
/// * [FocusTraversalOrder], a widget that assigns an order to a widget subtree
///   for the [OrderedTraversalPolicy] to use.
/// * [NumericFocusOrder], for a focus order that describes its order with a
///   `double`.
/// * [LexicalFocusOrder], a focus order that assigns a string-based lexical
///   traversal order to a [FocusTraversalOrder] widget.
@immutable
abstract class FocusOrder with Diagnosticable implements Comparable<FocusOrder> {
  /// Abstract const constructor. This constructor enables subclasses to provide
  /// const constructors so that they can be used in const expressions.
  const FocusOrder();

  /// Compares this object to another [Comparable].
  ///
  /// When overriding [FocusOrder], implement [doCompare] instead of this
  /// function to do the actual comparison.
  ///
  /// Returns a value like a [Comparator] when comparing `this` to [other].
  /// That is, it returns a negative integer if `this` is ordered before [other],
  /// a positive integer if `this` is ordered after [other],
  /// and zero if `this` and [other] are ordered together.
  ///
  /// The [other] argument must be a value that is comparable to this object.
  @override
  @nonVirtual
  int compareTo(FocusOrder other) {
    assert(
        runtimeType == other.runtimeType,
        "The sorting algorithm must not compare incomparable keys, since they don't "
        'know how to order themselves relative to each other. Comparing $this with $other');
    return doCompare(other);
  }

  /// The subclass implementation called by [compareTo] to compare orders.
  ///
  /// The argument is guaranteed to be of the same [runtimeType] as this object.
  ///
  /// The method should return a negative number if this object comes earlier in
  /// the sort order than the `other` argument; and a positive number if it
  /// comes later in the sort order than `other`. Returning zero causes the
  /// system to fall back to the secondary sort order defined by
  /// [OrderedTraversalPolicy.secondary]
  @protected
  int doCompare(covariant FocusOrder other);
}

/// Can be given to a [FocusTraversalOrder] widget to assign a numerical order
/// to a widget subtree that is using a [OrderedTraversalPolicy] to define the
/// order in which widgets should be traversed with the keyboard.
///
/// {@macro flutter.widgets.FocusOrder.comparable}
///
/// See also:
///
///  * [FocusTraversalOrder], a widget that assigns an order to a widget subtree
///    for the [OrderedTraversalPolicy] to use.
class NumericFocusOrder extends FocusOrder {
  /// Const constructor. This constructor enables subclasses to provide
  /// const constructors so that they can be used in const expressions.
  const NumericFocusOrder(this.order) : assert(order != null);

  /// The numerical order to assign to the widget subtree using
  /// [FocusTraversalOrder].
  ///
  /// Determines the placement of this widget in a sequence of widgets that defines
  /// the order in which this node is traversed by the focus policy.
  ///
  /// Lower values will be traversed first.
  final double order;

  @override
  int doCompare(NumericFocusOrder other) => order.compareTo(other.order);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('order', order));
  }
}

/// Can be given to a [FocusTraversalOrder] widget to use a String to assign a
/// lexical order to a widget subtree that is using a
/// [OrderedTraversalPolicy] to define the order in which widgets should be
/// traversed with the keyboard.
///
/// This sorts strings using Dart's default string comparison, which is not
/// locale specific.
///
/// {@macro flutter.widgets.FocusOrder.comparable}
///
/// See also:
///
///  * [FocusTraversalOrder], a widget that assigns an order to a widget subtree
///    for the [OrderedTraversalPolicy] to use.
class LexicalFocusOrder extends FocusOrder {
  /// Const constructor. This constructor enables subclasses to provide
  /// const constructors so that they can be used in const expressions.
  const LexicalFocusOrder(this.order) : assert(order != null);

  /// The String that defines the lexical order to assign to the widget subtree
  /// using [FocusTraversalOrder].
  ///
  /// Determines the placement of this widget in a sequence of widgets that defines
  /// the order in which this node is traversed by the focus policy.
  ///
  /// Lower lexical values will be traversed first (e.g. 'a' comes before 'z').
  final String order;

  @override
  int doCompare(LexicalFocusOrder other) => order.compareTo(other.order);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('order', order));
  }
}

// Used to help sort the focus nodes in an OrderedFocusTraversalPolicy.
class _OrderedFocusInfo {
  const _OrderedFocusInfo({required this.node, required this.order})
      : assert(node != null),
        assert(order != null);

  final FocusNode node;
  final FocusOrder order;
}

/// A [FocusTraversalPolicy] that orders nodes by an explicit order that resides
/// in the nearest [FocusTraversalOrder] widget ancestor.
///
/// {@macro flutter.widgets.FocusOrder.comparable}
///
/// {@tool dartpad --template=stateless_widget_scaffold_center_no_null_safety}
/// This sample shows how to assign a traversal order to a widget. In the
/// example, the focus order goes from bottom right (the "One" button) to top
/// left (the "Six" button).
///
/// ```dart preamble
/// class DemoButton extends StatelessWidget {
///   const DemoButton({this.name, this.autofocus = false, this.order});
///
///   final String name;
///   final bool autofocus;
///   final double order;
///
///   void _handleOnPressed() {
///     print('Button $name pressed.');
///     debugDumpFocusTree();
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return FocusTraversalOrder(
///       order: NumericFocusOrder(order),
///       child: TextButton(
///         autofocus: autofocus,
///         onPressed: () => _handleOnPressed(),
///         child: Text(name),
///       ),
///     );
///   }
/// }
/// ```
///
/// ```dart
/// Widget build(BuildContext context) {
///   return FocusTraversalGroup(
///     policy: OrderedTraversalPolicy(),
///     child: Column(
///       mainAxisAlignment: MainAxisAlignment.center,
///       children: <Widget>[
///         Row(
///           mainAxisAlignment: MainAxisAlignment.center,
///           children: const <Widget>[
///             DemoButton(name: 'Six', order: 6),
///           ],
///         ),
///         Row(
///           mainAxisAlignment: MainAxisAlignment.center,
///           children: const <Widget>[
///             DemoButton(name: 'Five', order: 5),
///             DemoButton(name: 'Four', order: 4),
///           ],
///         ),
///         Row(
///           mainAxisAlignment: MainAxisAlignment.center,
///           children: const <Widget>[
///             DemoButton(name: 'Three', order: 3),
///             DemoButton(name: 'Two', order: 2),
///             DemoButton(name: 'One', order: 1, autofocus: true),
///           ],
///         ),
///       ],
///     ),
///   );
/// }
/// ```
/// {@end-tool}
///
/// See also:
///
///  * [FocusTraversalGroup], a widget that groups together and imposes a
///    traversal policy on the [Focus] nodes below it in the widget hierarchy.
///  * [WidgetOrderTraversalPolicy], a policy that relies on the widget
///    creation order to describe the order of traversal.
///  * [ReadingOrderTraversalPolicy], a policy that describes the order as the
///    natural "reading order" for the current [Directionality].
///  * [NumericFocusOrder], a focus order that assigns a numeric traversal order
///    to a [FocusTraversalOrder] widget.
///  * [LexicalFocusOrder], a focus order that assigns a string-based lexical
///    traversal order to a [FocusTraversalOrder] widget.
///  * [FocusOrder], an abstract base class for all types of focus traversal
///    orderings.
class OrderedTraversalPolicy extends FocusTraversalPolicy with DirectionalFocusTraversalPolicyMixin {
  /// Constructs a traversal policy that orders widgets for keyboard traversal
  /// based on an explicit order.
  ///
  /// If [secondary] is null, it will default to [ReadingOrderTraversalPolicy].
  OrderedTraversalPolicy({this.secondary});

  /// This is the policy that is used when a node doesn't have an order
  /// assigned, or when multiple nodes have orders which are identical.
  ///
  /// If not set, this defaults to [ReadingOrderTraversalPolicy].
  ///
  /// This policy determines the secondary sorting order of nodes which evaluate
  /// as having an identical order (including those with no order specified).
  ///
  /// Nodes with no order specified will be sorted after nodes with an explicit
  /// order.
  final FocusTraversalPolicy? secondary;

  @override
  Iterable<FocusNode> sortDescendants(Iterable<FocusNode> descendants, FocusNode currentNode) {
    final FocusTraversalPolicy secondaryPolicy = secondary ?? ReadingOrderTraversalPolicy();
    final Iterable<FocusNode> sortedDescendants = secondaryPolicy.sortDescendants(descendants, currentNode);
    final List<FocusNode> unordered = <FocusNode>[];
    final List<_OrderedFocusInfo> ordered = <_OrderedFocusInfo>[];
    for (final FocusNode node in sortedDescendants) {
      final FocusOrder? order = FocusTraversalOrder.maybeOf(node.context!);
      if (order != null) {
        ordered.add(_OrderedFocusInfo(node: node, order: order));
      } else {
        unordered.add(node);
      }
    }
    mergeSort<_OrderedFocusInfo>(ordered, compare: (_OrderedFocusInfo a, _OrderedFocusInfo b) {
      assert(
        a.order.runtimeType == b.order.runtimeType,
        'When sorting nodes for determining focus order, the order (${a.order}) of '
        "node ${a.node}, isn't the same type as the order (${b.order}) of ${b.node}. "
        "Incompatible order types can't be compared.  Use a FocusTraversalGroup to group "
        'similar orders together.',
      );
      return a.order.compareTo(b.order);
    });
    return ordered.map<FocusNode>((_OrderedFocusInfo info) => info.node).followedBy(unordered);
  }
}

/// An inherited widget that describes the order in which its child subtree
/// should be traversed.
///
/// {@macro flutter.widgets.FocusOrder.comparable}
///
/// The order for a widget is determined by the [FocusOrder] returned by
/// [FocusTraversalOrder.of] for a particular context.
class FocusTraversalOrder extends InheritedWidget {
  /// A const constructor so that subclasses can be const.
  const FocusTraversalOrder({Key? key, required this.order, required Widget child}) : super(key: key, child: child);

  /// The order for the widget descendants of this [FocusTraversalOrder].
  final FocusOrder order;

  /// Finds the [FocusOrder] in the nearest ancestor [FocusTraversalOrder] widget.
  ///
  /// It does not create a rebuild dependency because changing the traversal
  /// order doesn't change the widget tree, so nothing needs to be rebuilt as a
  /// result of an order change.
  ///
  /// If no [FocusTraversalOrder] ancestor exists, or the order is null, this
  /// will assert in debug mode, and throw an exception in release mode.
  static FocusOrder of(BuildContext context) {
    assert(context != null);
    final FocusTraversalOrder? marker = context.getElementForInheritedWidgetOfExactType<FocusTraversalOrder>()?.widget as FocusTraversalOrder?;
    assert((){
      if (marker == null) {
        throw FlutterError(
          'FocusTraversalOrder.of() was called with a context that '
          'does not contain a FocusTraversalOrder widget. No TraversalOrder widget '
          'ancestor could be found starting from the context that was passed to '
          'FocusTraversalOrder.of().\n'
          'The context used was:\n'
          '  $context',
        );
      }
      return true;
    }());
    return marker!.order;
  }

  /// Finds the [FocusOrder] in the nearest ancestor [FocusTraversalOrder] widget.
  ///
  /// It does not create a rebuild dependency because changing the traversal
  /// order doesn't change the widget tree, so nothing needs to be rebuilt as a
  /// result of an order change.
  ///
  /// If no [FocusTraversalOrder] ancestor exists, or the order is null, returns null.
  static FocusOrder? maybeOf(BuildContext context) {
    assert(context != null);
    final FocusTraversalOrder? marker = context.getElementForInheritedWidgetOfExactType<FocusTraversalOrder>()?.widget as FocusTraversalOrder?;
    return marker?.order;
  }

  // Since the order of traversal doesn't affect display of anything, we don't
  // need to force a rebuild of anything that depends upon it.
  @override
  bool updateShouldNotify(InheritedWidget oldWidget) => false;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<FocusOrder>('order', order));
  }
}

/// A widget that describes the inherited focus policy for focus traversal for
/// its descendants, grouping them into a separate traversal group.
///
/// A traversal group is treated as one entity when sorted by the traversal
/// algorithm, so it can be used to segregate different parts of the widget tree
/// that need to be sorted using different algorithms and/or sort orders when
/// using an [OrderedTraversalPolicy].
///
/// Within the group, it will use the given [policy] to order the elements. The
/// group itself will be ordered using the parent group's policy.
///
/// By default, traverses in reading order using [ReadingOrderTraversalPolicy].
///
/// To prevent the members of the group from being focused, set the
/// [descendantsAreFocusable] attribute to false.
///
/// {@tool dartpad --template=stateless_widget_material_no_null_safety}
/// This sample shows three rows of buttons, each grouped by a
/// [FocusTraversalGroup], each with different traversal order policies. Use tab
/// traversal to see the order they are traversed in.  The first row follows a
/// numerical order, the second follows a lexical order (ordered to traverse
/// right to left), and the third ignores the numerical order assigned to it and
/// traverses in widget order.
///
/// ```dart preamble
/// /// A button wrapper that adds either a numerical or lexical order, depending on
/// /// the type of T.
/// class OrderedButton<T> extends StatefulWidget {
///   const OrderedButton({
///     this.name,
///     this.canRequestFocus = true,
///     this.autofocus = false,
///     this.order,
///   });
///
///   final String name;
///   final bool canRequestFocus;
///   final bool autofocus;
///   final T order;
///
///   @override
///   _OrderedButtonState createState() => _OrderedButtonState();
/// }
///
/// class _OrderedButtonState<T> extends State<OrderedButton<T>> {
///   FocusNode focusNode;
///
///   @override
///   void initState() {
///     super.initState();
///     focusNode = FocusNode(
///       debugLabel: widget.name,
///       canRequestFocus: widget.canRequestFocus,
///     );
///   }
///
///   @override
///   void dispose() {
///     focusNode?.dispose();
///     super.dispose();
///   }
///
///   @override
///   void didUpdateWidget(OrderedButton oldWidget) {
///     super.didUpdateWidget(oldWidget);
///     focusNode.canRequestFocus = widget.canRequestFocus;
///   }
///
///   void _handleOnPressed() {
///     focusNode.requestFocus();
///     print('Button ${widget.name} pressed.');
///     debugDumpFocusTree();
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     FocusOrder order;
///     if (widget.order is num) {
///       order = NumericFocusOrder((widget.order as num).toDouble());
///     } else {
///       order = LexicalFocusOrder(widget.order.toString());
///     }
///
///     Color overlayColor(Set<MaterialState> states) {
///       if (states.contains(MaterialState.focused)) {
///         return Colors.red;
///       }
///       if (states.contains(MaterialState.hovered)) {
///         return Colors.blue;
///       }
///       return null;  // defer to the default overlayColor
///     }
///
///     Color foregroundColor(Set<MaterialState> states) {
///       if (states.contains(MaterialState.focused) || states.contains(MaterialState.hovered)) {
///         return Colors.white;
///       }
///       return null;  // defer to the default foregroundColor
///     }
///
///     return FocusTraversalOrder(
///       order: order,
///       child: Padding(
///         padding: const EdgeInsets.all(8.0),
///         child: OutlinedButton(
///           focusNode: focusNode,
///           autofocus: widget.autofocus,
///           style: ButtonStyle(
///             overlayColor: MaterialStateProperty.resolveWith<Color>(overlayColor),
///             foregroundColor: MaterialStateProperty.resolveWith<Color>(foregroundColor),
///           ),
///           onPressed: () => _handleOnPressed(),
///           child: Text(widget.name),
///         ),
///       ),
///     );
///   }
/// }
/// ```
///
/// ```dart
/// Widget build(BuildContext context) {
///   return Container(
///     color: Colors.white,
///     child: FocusTraversalGroup(
///       policy: OrderedTraversalPolicy(),
///       child: Column(
///         mainAxisAlignment: MainAxisAlignment.center,
///         children: <Widget>[
///           // A group that is ordered with a numerical order, from left to right.
///           FocusTraversalGroup(
///             policy: OrderedTraversalPolicy(),
///             child: Row(
///               mainAxisAlignment: MainAxisAlignment.center,
///               children: List<Widget>.generate(3, (int index) {
///                 return OrderedButton<num>(
///                   name: 'num: $index',
///                   // TRY THIS: change this to "3 - index" and see how the order changes.
///                   order: index,
///                 );
///               }),
///             ),
///           ),
///           // A group that is ordered with a lexical order, from right to left.
///           FocusTraversalGroup(
///             policy: OrderedTraversalPolicy(),
///             child: Row(
///               mainAxisAlignment: MainAxisAlignment.center,
///               children: List<Widget>.generate(3, (int index) {
///                 // Order as "C" "B", "A".
///                 String order =
///                     String.fromCharCode('A'.codeUnitAt(0) + (2 - index));
///                 return OrderedButton<String>(
///                   name: 'String: $order',
///                   order: order,
///                 );
///               }),
///             ),
///           ),
///           // A group that orders in widget order, regardless of what the order is set to.
///           FocusTraversalGroup(
///             // Note that because this is NOT an OrderedTraversalPolicy, the
///             // assigned order of these OrderedButtons is ignored, and they
///             // are traversed in widget order. TRY THIS: change this to
///             // "OrderedTraversalPolicy()" and see that it now follows the
///             // numeric order set on them instead of the widget order.
///             policy: WidgetOrderTraversalPolicy(),
///             child: Row(
///               mainAxisAlignment: MainAxisAlignment.center,
///               children: List<Widget>.generate(3, (int index) {
///                 return OrderedButton<num>(
///                   name: 'ignored num: ${3 - index}',
///                   order: 3 - index,
///                 );
///               }),
///             ),
///           ),
///         ],
///       ),
///     ),
///   );
/// }
/// ```
/// {@end-tool}
///
/// See also:
///
///  * [FocusNode], for a description of the focus system.
///  * [WidgetOrderTraversalPolicy], a policy that relies on the widget
///    creation order to describe the order of traversal.
///  * [ReadingOrderTraversalPolicy], a policy that describes the order as the
///    natural "reading order" for the current [Directionality].
///  * [DirectionalFocusTraversalPolicyMixin] a mixin class that implements
///    focus traversal in a direction.
class FocusTraversalGroup extends StatefulWidget {
  /// Creates a [FocusTraversalGroup] object.
  ///
  /// The [child] and [descendantsAreFocusable] arguments must not be null.
  FocusTraversalGroup({
    Key? key,
    FocusTraversalPolicy? policy,
    this.descendantsAreFocusable = true,
    required this.child,
  })  : assert(descendantsAreFocusable != null),
        policy = policy ?? ReadingOrderTraversalPolicy(),
        super(key: key);

  /// The policy used to move the focus from one focus node to another when
  /// traversing them using a keyboard.
  ///
  /// If not specified, traverses in reading order using
  /// [ReadingOrderTraversalPolicy].
  ///
  /// See also:
  ///
  ///  * [FocusTraversalPolicy] for the API used to impose traversal order
  ///    policy.
  ///  * [WidgetOrderTraversalPolicy] for a traversal policy that traverses
  ///    nodes in the order they are added to the widget tree.
  ///  * [ReadingOrderTraversalPolicy] for a traversal policy that traverses
  ///    nodes in the reading order defined in the widget tree, and then top to
  ///    bottom.
  final FocusTraversalPolicy policy;

  /// {@macro flutter.widgets.Focus.descendantsAreFocusable}
  final bool descendantsAreFocusable;

  /// The child widget of this [FocusTraversalGroup].
  ///
  /// {@macro flutter.widgets.ProxyWidget.child}
  final Widget child;

  /// Returns the focus policy set by the [FocusTraversalGroup] that most
  /// tightly encloses the given [BuildContext].
  ///
  /// It does not create a rebuild dependency because changing the traversal
  /// order doesn't change the widget tree, so nothing needs to be rebuilt as a
  /// result of an order change.
  ///
  /// Will assert if no [FocusTraversalGroup] ancestor is found.
  ///
  /// See also:
  ///
  ///  * [maybeOf] for a similar function that will return null if no
  ///    [FocusTraversalGroup] ancestor is found.
  static FocusTraversalPolicy of(BuildContext context) {
    assert(context != null);
    final _FocusTraversalGroupMarker? inherited = context.dependOnInheritedWidgetOfExactType<_FocusTraversalGroupMarker>();
    assert(() {
      if (inherited == null) {
        throw FlutterError(
          'Unable to find a FocusTraversalGroup widget in the context.\n'
          'FocusTraversalGroup.of() was called with a context that does not contain a '
          'FocusTraversalGroup.\n'
          'No FocusTraversalGroup ancestor could be found starting from the context that was '
          'passed to FocusTraversalGroup.of(). This can happen because there is not a '
          'WidgetsApp or MaterialApp widget (those widgets introduce a FocusTraversalGroup), '
          'or it can happen if the context comes from a widget above those widgets.\n'
          'The context used was:\n'
          '  $context',
        );
      }
      return true;
    }());
    return inherited!.policy;
  }

  /// Returns the focus policy set by the [FocusTraversalGroup] that most
  /// tightly encloses the given [BuildContext].
  ///
  /// It does not create a rebuild dependency because changing the traversal
  /// order doesn't change the widget tree, so nothing needs to be rebuilt as a
  /// result of an order change.
  ///
  /// Will return null if it doesn't find a [FocusTraversalGroup] ancestor.
  ///
  /// See also:
  ///
  ///  * [of] for a similar function that will throw if no [FocusTraversalGroup]
  ///    ancestor is found.
  static FocusTraversalPolicy? maybeOf(BuildContext context) {
    assert(context != null);
    final _FocusTraversalGroupMarker? inherited = context.dependOnInheritedWidgetOfExactType<_FocusTraversalGroupMarker>();
    return inherited?.policy;
  }

  @override
  _FocusTraversalGroupState createState() => _FocusTraversalGroupState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<FocusTraversalPolicy>('policy', policy));
  }
}

class _FocusTraversalGroupState extends State<FocusTraversalGroup> {
  // The internal focus node used to collect the children of this node into a
  // group, and to provide a context for the traversal algorithm to sort the
  // group with.
  FocusNode? focusNode;

  @override
  void initState() {
    super.initState();
    focusNode = FocusNode(
      canRequestFocus: false,
      skipTraversal: true,
      debugLabel: 'FocusTraversalGroup',
    );
  }

  @override
  void dispose() {
    focusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _FocusTraversalGroupMarker(
      policy: widget.policy,
      focusNode: focusNode!,
      child: Focus(
        focusNode: focusNode,
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        descendantsAreFocusable: widget.descendantsAreFocusable,
        child: widget.child,
      ),
    );
  }
}

// A "marker" inherited widget to make the group faster to find.
class _FocusTraversalGroupMarker extends InheritedWidget {
  const _FocusTraversalGroupMarker({
    required this.policy,
    required this.focusNode,
    required Widget child,
  })  : assert(policy != null),
        assert(focusNode != null),
        super(child: child);

  final FocusTraversalPolicy policy;
  final FocusNode focusNode;

  @override
  bool updateShouldNotify(InheritedWidget oldWidget) => false;
}

/// An intent for use with the [RequestFocusAction], which supplies the
/// [FocusNode] that should be focused.
class RequestFocusIntent extends Intent {
  /// A const constructor for a [RequestFocusIntent], so that subclasses may be
  /// const.
  const RequestFocusIntent(this.focusNode)
      : assert(focusNode != null);

  /// The [FocusNode] that is to be focused.
  final FocusNode focusNode;
}

/// An [Action] that requests the focus on the node it is given in its
/// [RequestFocusIntent].
///
/// This action can be used to request focus for a particular node, by calling
/// [Action.invoke] like so:
///
/// ```dart
/// Actions.invoke(context, const RequestFocusIntent(focusNode));
/// ```
///
/// Where the `focusNode` is the node for which the focus will be requested.
///
/// The difference between requesting focus in this way versus calling
/// [FocusNode.requestFocus] directly is that it will use the [Action]
/// registered in the nearest [Actions] widget associated with
/// [RequestFocusIntent] to make the request, rather than just requesting focus
/// directly. This allows the action to have additional side effects, like
/// logging, or undo and redo functionality.
///
/// This [RequestFocusAction] class is the default action associated with the
/// [RequestFocusIntent] in the [WidgetsApp], and it simply requests focus. You
/// can redefine the associated action with your own [Actions] widget.
///
/// See [FocusTraversalPolicy] for more information about focus traversal.
class RequestFocusAction extends Action<RequestFocusIntent> {
  @override
  void invoke(RequestFocusIntent intent) {
    _focusAndEnsureVisible(intent.focusNode);
  }
}

/// An [Intent] bound to [NextFocusAction], which moves the focus to the next
/// focusable node in the focus traversal order.
///
/// See [FocusTraversalPolicy] for more information about focus traversal.
class NextFocusIntent extends Intent {
  /// Creates a const [NextFocusIntent] so subclasses can be const.
  const NextFocusIntent();
}

/// An [Action] that moves the focus to the next focusable node in the focus
/// order.
///
/// This action is the default action registered for the [NextFocusIntent], and
/// by default is bound to the [LogicalKeyboardKey.tab] key in the [WidgetsApp].
///
/// See [FocusTraversalPolicy] for more information about focus traversal.
class NextFocusAction extends Action<NextFocusIntent> {
  @override
  void invoke(NextFocusIntent intent) {
    primaryFocus!.nextFocus();
  }
}

/// An [Intent] bound to [PreviousFocusAction], which moves the focus to the
/// previous focusable node in the focus traversal order.
///
/// See [FocusTraversalPolicy] for more information about focus traversal.
class PreviousFocusIntent extends Intent {
  /// Creates a const [PreviousFocusIntent] so subclasses can be const.
  const PreviousFocusIntent();
}

/// An [Action] that moves the focus to the previous focusable node in the focus
/// order.
///
/// This action is the default action registered for the [PreviousFocusIntent],
/// and by default is bound to a combination of the [LogicalKeyboardKey.tab] key
/// and the [LogicalKeyboardKey.shift] key in the [WidgetsApp].
///
/// See [FocusTraversalPolicy] for more information about focus traversal.
class PreviousFocusAction extends Action<PreviousFocusIntent> {
  @override
  void invoke(PreviousFocusIntent intent) {
    primaryFocus!.previousFocus();
  }
}

/// An [Intent] that represents moving to the next focusable node in the given
/// [direction].
///
/// This is the [Intent] bound by default to the [LogicalKeyboardKey.arrowUp],
/// [LogicalKeyboardKey.arrowDown], [LogicalKeyboardKey.arrowLeft], and
/// [LogicalKeyboardKey.arrowRight] keys in the [WidgetsApp], with the
/// appropriate associated directions.
///
/// See [FocusTraversalPolicy] for more information about focus traversal.
class DirectionalFocusIntent extends Intent {
  /// Creates a [DirectionalFocusIntent] intending to move the focus in the
  /// given [direction].
  const DirectionalFocusIntent(this.direction, {this.ignoreTextFields = true})
      : assert(ignoreTextFields != null);

  /// The direction in which to look for the next focusable node when the
  /// associated [DirectionalFocusAction] is invoked.
  final TraversalDirection direction;

  /// If true, then directional focus actions that occur within a text field
  /// will not happen when the focus node which received the key is a text
  /// field.
  ///
  /// Defaults to true.
  final bool ignoreTextFields;
}

/// An [Action] that moves the focus to the focusable node in the direction
/// configured by the associated [DirectionalFocusIntent.direction].
///
/// This is the [Action] associated with [DirectionalFocusIntent] and bound by
/// default to the [LogicalKeyboardKey.arrowUp], [LogicalKeyboardKey.arrowDown],
/// [LogicalKeyboardKey.arrowLeft], and [LogicalKeyboardKey.arrowRight] keys in
/// the [WidgetsApp], with the appropriate associated directions.
class DirectionalFocusAction extends Action<DirectionalFocusIntent> {
  @override
  void invoke(DirectionalFocusIntent intent) {
    if (!intent.ignoreTextFields || primaryFocus!.context!.widget is! EditableText) {
      primaryFocus!.focusInDirection(intent.direction);
    }
  }
}
