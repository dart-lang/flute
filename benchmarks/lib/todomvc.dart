// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:engine/ui.dart' as ui;

import 'package:flute/material.dart';
import 'package:flute/scheduler.dart';

import 'harness.dart';

void main(List<String> args) {
  initializeBenchmarkHarness('FluteTodoMVC', args);
  ui.initializeEngine(
    screenSize: const Size(3840, 2160), // 4k
  );
  runApp(const TodoApp());
}

class TodoApp extends StatefulWidget {
  const TodoApp({super.key});

  @override
  State<TodoApp> createState() => TodoAppState();
}

class TodoAppState extends State<TodoApp> with SingleTickerProviderStateMixin {
  final List<Todo> _todos = [];

  FilterType _filter = FilterType.all;
  late TextEditingController _textController;
  late TextEditingController _editController;
  String? _editingTodoId;

  AnimationPhase phase = AnimationPhase.adding;
  int? completingIndex;
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _editController = TextEditingController();

    _ticker = createTicker((Duration _) {
      setState(() {
        switch (phase) {
          case AnimationPhase.adding:
            _textController.text = 'TodoItem ${_todos.length}';
            addTodo();
            if (_todos.length == numberOfTodos) {
              phase = AnimationPhase.completing;
              completingIndex = 0;
            }
            break;
          case AnimationPhase.completing:
            final int index = completingIndex!;
            toggleTodoStatus(_todos[index].id);
            completingIndex = index + 1;
            if (index == (_todos.length - 1)) {
              completingIndex = null;
              phase = AnimationPhase.removing;
            }
            break;
          case AnimationPhase.removing:
            removeTodo(_todos.last.id);
            if (_todos.isEmpty) {
              phase = AnimationPhase.adding;
            }
            break;
        }
      });
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _textController.dispose();
    _editController.dispose();
    super.dispose();
  }

  List<Todo> get todos {
    switch (_filter) {
      case FilterType.active:
        return _todos.where((todo) => !todo.completed).toList();
      case FilterType.completed:
        return _todos.where((todo) => todo.completed).toList();
      case FilterType.all:
        return _todos;
    }
  }

  FilterType get filter => _filter;
  TextEditingController get textController => _textController;
  TextEditingController get editController => _editController;
  String? get editingTodoId => _editingTodoId;

  int get itemsLeft => _todos.where((todo) => !todo.completed).length;

  void addTodo() {
    if (_textController.text.trim().isEmpty) return;
    setState(() {
      final newTodo = Todo(
        id: DateTime.now().toString(),
        text: _textController.text.trim(),
      );
      _todos.add(newTodo);
      _textController.clear();
    });
  }

  void toggleTodoStatus(String id) {
    setState(() {
      final todo = _todos.firstWhere((todo) => todo.id == id);
      todo.completed = !todo.completed;
    });
  }

  void removeTodo(String id) {
    setState(() {
      _todos.removeWhere((todo) => todo.id == id);
    });
  }

  void clearCompleted() {
    setState(() {
      _todos.removeWhere((todo) => todo.completed);
    });
  }

  void setFilter(FilterType filter) {
    setState(() {
      _filter = filter;
    });
  }

  void startEditing(String id) {
    setState(() {
      final todo = _todos.firstWhere((todo) => todo.id == id);
      _editingTodoId = id;
      _editController.text = todo.text;
    });
  }

  void submitEdit() {
    if (_editingTodoId == null) return;
    setState(() {
      final newText = _editController.text.trim();
      if (newText.isEmpty) {
        _todos.removeWhere((todo) => todo.id == _editingTodoId!);
      } else {
        final todo = _todos.firstWhere((todo) => todo.id == _editingTodoId!);
        todo.text = newText;
      }
      _editingTodoId = null;
      _editController.clear();
    });
  }

  void cancelEditing() {
    setState(() {
      _editingTodoId = null;
      _editController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TodoMVC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: Colors.grey[200],
      ),
      home: TodoScreen(appState: this),
    );
  }
}

class TodoScreen extends StatelessWidget {
  final TodoAppState appState;

  const TodoScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 120,
        title: const Text(
          'todos',
          style: TextStyle(
            fontSize: 80,
            fontWeight: FontWeight.w200,
            color: Color.fromRGBO(175, 47, 47, 0.15),
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0.0,
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          children: [
            Expanded(child: TodoList(appState: appState)),
            const Footer(),
          ],
        ),
      ),
    );
  }
}

class TodoList extends StatefulWidget {
  final TodoAppState appState;

  const TodoList({super.key, required this.appState});

  @override
  State<TodoList> createState() => _TodoListState();
}

class _TodoListState extends State<TodoList> {
  late FocusNode _textFieldFocusNode;

  @override
  void initState() {
    super.initState();
    _textFieldFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 550,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            offset: const Offset(0, 2.5),
            blurRadius: 5,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(0, 1),
            blurRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 5.0),
            child: Row(
              children: [
                const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: widget.appState.textController,
                    focusNode: _textFieldFocusNode,
                    onSubmitted: (_) {
                      widget.appState.addTodo();
                      _textFieldFocusNode.requestFocus();
                    },
                    style: const TextStyle(fontSize: fontSize),
                    decoration: const InputDecoration(
                      hintText: 'What needs to be done?',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Color(0xFFE0E0E0)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: widget.appState.todos.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final todo = widget.appState.todos[index];
                return TodoListItem(todo: todo, appState: widget.appState);
              },
            ),
          ),
          TodoFooter(appState: widget.appState),
        ],
      ),
    );
  }
}

class TodoListItem extends StatelessWidget {
  final Todo todo;
  final TodoAppState appState;

  const TodoListItem({super.key, required this.todo, required this.appState});

  @override
  Widget build(BuildContext context) {
    final isEditing = appState.editingTodoId == todo.id;

    return ListTile(
      leading: Checkbox(
        value: todo.completed, // Assuming todo.completed is a bool
        onChanged: (value) => appState.toggleTodoStatus(todo.id),
        shape: const CircleBorder(),
        activeColor: Colors.green,
        checkColor: Colors.white,
      ),
      title: isEditing
          ? TextField(
              controller: appState.editController,
              autofocus: true,
              onSubmitted: (_) => appState.submitEdit(),
              onTapOutside: (_) {
                // Submit on tap outside
                if (appState.editingTodoId == todo.id) {
                  // only if still editing this item
                  appState.submitEdit();
                }
              },
              style: const TextStyle(fontSize: fontSize),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
              ),
            )
          : GestureDetector(
              onTap: () => appState.startEditing(todo.id),
              child: Text(
                todo.text,
                style: TextStyle(
                  fontSize: fontSize,
                  decoration: todo.completed
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                  color: todo.completed ? Colors.grey : Colors.black,
                ),
              ),
            ),
      trailing: IconButton(
        icon: const Icon(Icons.close, color: Colors.red),
        onPressed: () => appState.removeTodo(todo.id),
      ),
    );
  }
}

class TodoFooter extends StatelessWidget {
  final TodoAppState appState;

  const TodoFooter({super.key, required this.appState});

  Widget _buildFilterButton(
    BuildContext context,
    FilterType filterType,
    String text,
    TodoAppState appState,
  ) {
    return TextButton(
      onPressed: () => appState.setFilter(filterType),
      style: TextButton.styleFrom(
        foregroundColor:
            appState.filter == filterType ? Colors.red : Colors.grey,
      ),
      child: Text(text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${appState.itemsLeft} items left'),
          Row(
            children: [
              _buildFilterButton(context, FilterType.all, 'All', appState),
              _buildFilterButton(
                context,
                FilterType.active,
                'Active',
                appState,
              ),
              _buildFilterButton(
                context,
                FilterType.completed,
                'Completed',
                appState,
              ),
            ],
          ),
          TextButton(
            onPressed: () => appState.clearCompleted(),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            child: const Text('Clear completed'),
          ),
        ],
      ),
    );
  }
}

class Footer extends StatelessWidget {
  const Footer({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 40.0, bottom: 20.0),
      child: Column(
        children: [
          Text('Click to edit a todo', style: TextStyle(color: Colors.grey)),
          SizedBox(height: 10),
          Text(
            'Written by the Dart team',
            style: TextStyle(color: Colors.grey),
          ),
          SizedBox(height: 10),
          Text('Part of TodoMVC', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class Todo {
  String id;
  String text;
  bool completed;

  Todo({required this.id, required this.text, this.completed = false});
}

enum FilterType { all, active, completed }

const double fontSize = 16.0;

enum AnimationPhase { adding, completing, removing }

const int numberOfTodos = 100;
