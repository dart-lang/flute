// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart=2.12

import 'dart:math' as math;

import 'package:engine/ui.dart' as ui;
import 'package:flute/cupertino.dart';
import 'package:flute/material.dart';

import 'harness.dart';

const int maxDepth = 6;
final math.Random random = math.Random(0);

void main(List<String> args) {
  initializeBenchmarkHarness('FluteComplex', args);
  ui.initializeEngine(
    screenSize: const Size(3840, 2160),  // 4k
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage('Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage(this.title);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _LayoutNode rootNode = _LayoutNode.generate();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _LayoutWidget(rootNode, key: const ValueKey<String>('root')),
    );
  }
}

class _LayoutWidget extends StatefulWidget {
  const _LayoutWidget(this.node, { required Key key }) : super(key: key);

  final _LayoutNode node;

  @override
  State<StatefulWidget> createState() {
    return _LayoutWidgetState();
  }
}

class _LayoutWidgetState extends State<_LayoutWidget> with SingleTickerProviderStateMixin {
  late final Widget firstChild = _buildChild(const ValueKey<int>(1), widget.node.firstChild);
  late final Widget secondChild = _buildChild(const ValueKey<int>(2), widget.node.secondChild);
  late final Animation<double> _animation;
  final bool isReversed = random.nextBool();

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )
    ..addListener(() {
      setState(() {});
    })
    ..repeat();
  }

  static Widget _buildChild(ValueKey<int> key, final _Node child) {
    if (child is _LayoutNode) {
      return _LayoutWidget(child, key: key);
    } else {
      return _LeafWidget(child as _LeafNode, key: key);
    }
  }

  @override
  Widget build(BuildContext context) {
    final int delta = ((_animation.value - 0.5).abs() * 3000).toInt() * (isReversed ? -1 : 1);
    final List<Widget> children = <Widget>[
      Flexible(flex: 5000 + delta, child: firstChild),
      Flexible(flex: 5000 - delta, child: secondChild),
    ];
    if (widget.node.isColumn) {
      return Column(
        children: children,
      );
    } else {
      return Row(
        children: children,
      );
    }
  }
}

class _LeafWidget extends StatelessWidget {
  const _LeafWidget(this.node, { required Key key }) : super(key: key);

  final _LeafNode node;

  @override
  Widget build(BuildContext context) {
    switch(node.kind) {
      case _WidgetKind.button:
        return TextButton(
          onPressed: () {},
          child: const Text('Button'),
        );
      case _WidgetKind.checkbox:
        return Checkbox(
          value: true,
          onChanged: (bool? state) {},
        );
      case _WidgetKind.plainText:
        return const Text('Hello World!');
      case _WidgetKind.datePicker:
        return CupertinoTimerPicker(
          onTimerDurationChanged: (Duration duration) {},
        );
      case _WidgetKind.progressIndicator:
        return const CircularProgressIndicator();
      case _WidgetKind.slider:
        return Slider(
          value: 50,
          max: 100,
          onChanged: (double value) {},
        );
      case _WidgetKind.appBar:
        return AppBar(
          leading: TextButton(child: const Text('H'), onPressed: () {}),
          title: const Text('ello'),
          actions: <Widget>[
            TextButton(child: const Text('W'), onPressed: () {}),
            TextButton(child: const Text('o'), onPressed: () {}),
            TextButton(child: const Text('r'), onPressed: () {}),
            TextButton(child: const Text('l'), onPressed: () {}),
            TextButton(child: const Text('d'), onPressed: () {}),
            TextButton(child: const Text('!'), onPressed: () {}),
          ],
        );
    }
  }
}

enum _WidgetKind {
  button,
  checkbox,
  plainText,
  datePicker,
  progressIndicator,
  slider,
  appBar,
}

abstract class _Node {}

class _LayoutNode extends _Node {
  _LayoutNode({
    required this.isColumn,
    required this.firstChild,
    required this.secondChild,
  });

  factory _LayoutNode.generate({int depth = 0}) {
    final _LayoutNode node = _LayoutNode(
      isColumn: depth.isEven,
      firstChild: depth >= maxDepth ? _LeafNode.generate() : _LayoutNode.generate(depth: depth + 1),
      secondChild: depth >= maxDepth ? _LeafNode.generate() : _LayoutNode.generate(depth: depth + 1),
    );
    return node;
  }

  final bool isColumn;
  final _Node firstChild;
  final _Node secondChild;
}

class _LeafNode extends _Node {
  _LeafNode({
    required this.kind,
  });

  factory _LeafNode.generate() {
    return _LeafNode(
      kind: _WidgetKind.values[random.nextInt(_WidgetKind.values.length)],
    );
  }

  final _WidgetKind kind;
}
