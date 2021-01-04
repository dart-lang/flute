// @dart=2.12

import 'dart:math' as math;

import 'package:flute/ui.dart' as ui;
import 'package:flute/cupertino.dart';
import 'package:flute/material.dart';

const int maxDepth = 6;
final math.Random random = math.Random(0);

void main() {
  ui.setScreenSize(3840, 2160);  // 4k
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
      home: MyHomePage('Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage(this.title);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
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
  _LayoutWidget(this.node, { required Key key }) : super(key: key);

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
      lowerBound: 0,
      upperBound: 1.0,
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
  _LeafWidget(this.node, { required Key key }) : super(key: key);

  final _LeafNode node;

  @override
  Widget build(BuildContext context) {
    switch(node.kind) {
      case _WidgetKind.button:
        return RaisedButton(
          onPressed: () {},
          child: Text('Button'),
        );
      case _WidgetKind.checkbox:
        return Checkbox(
          value: true,
          onChanged: (bool? state) {},
        );
      case _WidgetKind.plainText:
        return Text('Hello World!');
      case _WidgetKind.datePicker:
        return CupertinoTimerPicker(
          onTimerDurationChanged: (Duration duration) {},
        );
      case _WidgetKind.progressIndicator:
        return CircularProgressIndicator();
      case _WidgetKind.slider:
        return Slider(
          value: 50,
          min: 0,
          max: 100,
          onChanged: (double value) {},
        );
      case _WidgetKind.appBar:
        return AppBar(
          leading: RaisedButton(elevation: 2.0, child: Text('H'), onPressed: () {}),
          title: Text('ello'),
          actions: <Widget>[
            RaisedButton(elevation: 2.0, child: Text('W'), onPressed: () {}),
            RaisedButton(elevation: 2.0, child: Text('o'), onPressed: () {}),
            RaisedButton(elevation: 2.0, child: Text('r'), onPressed: () {}),
            RaisedButton(elevation: 2.0, child: Text('l'), onPressed: () {}),
            RaisedButton(elevation: 2.0, child: Text('d'), onPressed: () {}),
            RaisedButton(elevation: 2.0, child: Text('!'), onPressed: () {}),
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
  factory _LayoutNode.generate({int depth = 0}) {
    final _LayoutNode node = _LayoutNode(
      isColumn: depth % 2 == 0,
      firstChild: depth >= maxDepth ? _LeafNode.generate() : _LayoutNode.generate(depth: depth + 1),
      secondChild: depth >= maxDepth ? _LeafNode.generate() : _LayoutNode.generate(depth: depth + 1),
    );
    return node;
  }

  _LayoutNode({
    required this.isColumn,
    required this.firstChild,
    required this.secondChild,
  });

  final bool isColumn;
  final _Node firstChild;
  final _Node secondChild;
}

class _LeafNode extends _Node {
  factory _LeafNode.generate() {
    return _LeafNode(
      kind: _WidgetKind.values[random.nextInt(_WidgetKind.values.length)],
    );
  }

  _LeafNode({
    required this.kind,
  });

  final _WidgetKind kind;
}
