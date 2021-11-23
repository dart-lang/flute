// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flute/foundation.dart';
import 'package:flute/services.dart';

import 'editable_text.dart';
import 'restoration.dart';

// Examples can assume:
// // @dart = 2.9

/// A [RestorableProperty] that makes the wrapped value accessible to the owning
/// [State] object via the [value] getter and setter.
///
/// Whenever a new [value] is set, [didUpdateValue] is called. Subclasses should
/// call [notifyListeners] from this method if the new value changes what
/// [toPrimitives] returns.
///
/// ## Using a RestorableValue
///
/// {@tool dartpad --template=stateful_widget_restoration_no_null_safety}
/// A [StatefulWidget] that has a restorable [int] property.
///
/// ```dart
///   // The current value of the answer is stored in a [RestorableProperty].
///   // During state restoration it is automatically restored to its old value.
///   // If no restoration data is available to restore the answer from, it is
///   // initialized to the specified default value, in this case 42.
///   RestorableInt _answer = RestorableInt(42);
///
///   @override
///   void restoreState(RestorationBucket oldBucket, bool initialRestore) {
///     // All restorable properties must be registered with the mixin. After
///     // registration, the answer either has its old value restored or is
///     // initialized to its default value.
///     registerForRestoration(_answer, 'answer');
///   }
///
///   void _incrementAnswer() {
///     setState(() {
///       // The current value of the property can be accessed and modified via
///       // the value getter and setter.
///       _answer.value += 1;
///     });
///   }
///
///   @override
///   void dispose() {
///     // Properties must be disposed when no longer used.
///     _answer.dispose();
///     super.dispose();
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return OutlinedButton(
///       child: Text('${_answer.value}'),
///       onPressed: _incrementAnswer,
///     );
///   }
/// ```
/// {@end-tool}
///
/// ## Creating a subclass
///
/// {@tool snippet}
/// This example shows how to create a new `RestorableValue` subclass,
/// in this case for the [Duration] class.
///
/// ```dart
/// class RestorableDuration extends RestorableValue<Duration> {
///   @override
///   Duration createDefaultValue() => const Duration();
///
///   @override
///   void didUpdateValue(Duration oldValue) {
///     if (oldValue.inMicroseconds != value.inMicroseconds)
///       notifyListeners();
///   }
///
///   @override
///   Duration fromPrimitives(Object data) {
///     return Duration(microseconds: data as int);
///   }
///
///   @override
///   Object toPrimitives() {
///     return value.inMicroseconds;
///   }
/// }
/// ```
/// {@end-tool}
///
/// See also:
///
///  * [RestorableProperty], which is the super class of this class.
///  * [RestorationMixin], to which a [RestorableValue] needs to be registered
///    in order to work.
///  * [RestorationManager], which provides an overview of how state restoration
///    works in Flutter.
abstract class RestorableValue<T> extends RestorableProperty<T> {
  /// The current value stored in this property.
  ///
  /// A representation of the current value is stored in the restoration data.
  /// During state restoration, the property will restore the value to what it
  /// was when the restoration data it is getting restored from was collected.
  ///
  /// The [value] can only be accessed after the property has been registered
  /// with a [RestorationMixin] by calling
  /// [RestorationMixin.registerForRestoration].
  T get value {
    assert(isRegistered);
    return _value as T;
  }
  T? _value;
  set value(T newValue) {
    assert(isRegistered);
    if (newValue != _value) {
      final T? oldValue = _value;
      _value = newValue;
      didUpdateValue(oldValue);
    }
  }

  @mustCallSuper
  @override
  void initWithValue(T value) {
    _value = value;
  }

  /// Called whenever a new value is assigned to [value].
  ///
  /// The new value can be accessed via the regular [value] getter and the
  /// previous value is provided as `oldValue`.
  ///
  /// Subclasses should call [notifyListeners] from this method, if the new
  /// value changes what [toPrimitives] returns.
  @protected
  void didUpdateValue(T? oldValue);
}

// _RestorablePrimitiveValueN and its subclasses allows for null values.
// See [_RestorablePrimitiveValue] for the non-nullable version of this class.
class _RestorablePrimitiveValueN<T extends Object?> extends RestorableValue<T> {
  _RestorablePrimitiveValueN(this._defaultValue)
    : assert(debugIsSerializableForRestoration(_defaultValue)),
      super();

  final T _defaultValue;

  @override
  T createDefaultValue() => _defaultValue;

  @override
  void didUpdateValue(T? oldValue) {
    assert(debugIsSerializableForRestoration(value));
    notifyListeners();
  }

  @override
  T fromPrimitives(Object? serialized) => serialized as T;

  @override
  Object? toPrimitives() => value;
}

// _RestorablePrimitiveValue and its subclasses are non-nullable.
// See [_RestorablePrimitiveValueN] for the nullable version of this class.
class _RestorablePrimitiveValue<T extends Object> extends _RestorablePrimitiveValueN<T> {
  _RestorablePrimitiveValue(T _defaultValue)
    : assert(_defaultValue != null),
      assert(debugIsSerializableForRestoration(_defaultValue)),
      super(_defaultValue);

  @override
  set value(T value) {
    assert(value != null);
    super.value = value;
  }

  @override
  T fromPrimitives(Object? serialized) {
    assert(serialized != null);
    return super.fromPrimitives(serialized);
  }

  @override
  Object toPrimitives() {
    assert(value != null);
    return super.toPrimitives()!;
  }
}

/// A [RestorableProperty] that knows how to store and restore a [num].
///
/// {@template flutter.widgets.RestorableNum}
/// The current [value] of this property is stored in the restoration data.
/// During state restoration the property is restored to the value it had when
/// the restoration data it is getting restored from was collected.
///
/// If no restoration data is available, [value] is initialized to the
/// `defaultValue` given in the constructor.
/// {@endtemplate}
///
/// Instead of using the more generic [RestorableNum] directly, consider using
/// one of the more specific subclasses (e.g. [RestorableDouble] to store a
/// [double] and [RestorableInt] to store an [int]).
class RestorableNum<T extends num> extends _RestorablePrimitiveValue<T> {
  /// Creates a [RestorableNum].
  ///
  /// {@template flutter.widgets.RestorableNum.constructor}
  /// If no restoration data is available to restore the value in this property
  /// from, the property will be initialized with the provided `defaultValue`.
  /// {@endtemplate}
  RestorableNum(T defaultValue) : assert(defaultValue != null), super(defaultValue);
}

/// A [RestorableProperty] that knows how to store and restore a [double].
///
/// {@macro flutter.widgets.RestorableNum}
class RestorableDouble extends RestorableNum<double> {
  /// Creates a [RestorableDouble].
  ///
  /// {@macro flutter.widgets.RestorableNum.constructor}
  RestorableDouble(double defaultValue) : assert(defaultValue != null), super(defaultValue);
}

/// A [RestorableProperty] that knows how to store and restore an [int].
///
/// {@macro flutter.widgets.RestorableNum}
class RestorableInt extends RestorableNum<int> {
  /// Creates a [RestorableInt].
  ///
  /// {@macro flutter.widgets.RestorableNum.constructor}
  RestorableInt(int defaultValue) : assert(defaultValue != null), super(defaultValue);
}

/// A [RestorableProperty] that knows how to store and restore a [String].
///
/// {@macro flutter.widgets.RestorableNum}
class RestorableString extends _RestorablePrimitiveValue<String> {
  /// Creates a [RestorableString].
  ///
  /// {@macro flutter.widgets.RestorableNum.constructor}
  RestorableString(String defaultValue) : assert(defaultValue != null), super(defaultValue);
}

/// A [RestorableProperty] that knows how to store and restore a [bool].
///
/// {@macro flutter.widgets.RestorableNum}
class RestorableBool extends _RestorablePrimitiveValue<bool> {
  /// Creates a [RestorableBool].
  ///
  /// {@macro flutter.widgets.RestorableNum.constructor}
  ///
  /// See also:
  ///
  ///  * [RestorableBoolN] for the nullable version of this class.
  RestorableBool(bool defaultValue) : assert(defaultValue != null), super(defaultValue);
}

/// A [RestorableProperty] that knows how to store and restore a [bool] that is
/// nullable.
///
/// {@macro flutter.widgets.RestorableNum}
class RestorableBoolN extends _RestorablePrimitiveValueN<bool?> {
  /// Creates a [RestorableBoolN].
  ///
  /// {@macro flutter.widgets.RestorableNum.constructor}
  ///
  /// See also:
  ///
  ///  * [RestorableBool] for the non-nullable version of this class.
  RestorableBoolN(bool? defaultValue) : super(defaultValue);
}

/// A base class for creating a [RestorableProperty] that stores and restores a
/// [Listenable].
///
/// This class may be used to implement a [RestorableProperty] for a
/// [Listenable], whose information it needs to store in the restoration data
/// change whenever the [Listenable] notifies its listeners.
///
/// The [RestorationMixin] this property is registered with will call
/// [toPrimitives] whenever the wrapped [Listenable] notifies its listeners to
/// update the information that this property has stored in the restoration
/// data.
abstract class RestorableListenable<T extends Listenable> extends RestorableProperty<T> {
  /// The [Listenable] stored in this property.
  ///
  /// A representation of the current value of the [Listenable] is stored in the
  /// restoration data. During state restoration, the [Listenable] returned by
  /// this getter will be restored to the state it had when the restoration data
  /// the property is getting restored from was collected.
  ///
  /// The [value] can only be accessed after the property has been registered
  /// with a [RestorationMixin] by calling
  /// [RestorationMixin.registerForRestoration].
  T get value {
    assert(isRegistered);
    return _value!;
  }
  T? _value;

  @override
  void initWithValue(T value) {
    assert(value != null);
    _value?.removeListener(notifyListeners);
    _value = value;
    _value!.addListener(notifyListeners);
  }

  @override
  void dispose() {
    super.dispose();
    _value?.removeListener(notifyListeners);
  }
}

/// A base class for creating a [RestorableProperty] that stores and restores a
/// [ChangeNotifier].
///
/// This class may be used to implement a [RestorableProperty] for a
/// [ChangeNotifier], whose information it needs to store in the restoration
/// data change whenever the [ChangeNotifier] notifies its listeners.
///
/// The [RestorationMixin] this property is registered with will call
/// [toPrimitives] whenever the wrapped [ChangeNotifier] notifies its listeners
/// to update the information that this property has stored in the restoration
/// data.
///
/// Furthermore, the property will dispose the wrapped [ChangeNotifier] when
/// either the property itself is disposed or its value is replaced with another
/// [ChangeNotifier] instance.
abstract class RestorableChangeNotifier<T extends ChangeNotifier> extends RestorableListenable<T> {
  @override
  void initWithValue(T value) {
    _disposeOldValue();
    super.initWithValue(value);
  }

  @override
  void dispose() {
    _disposeOldValue();
    super.dispose();
  }

  void _disposeOldValue() {
    if (_value != null) {
      // Scheduling a microtask for dispose to give other entities a chance
      // to remove their listeners first.
      scheduleMicrotask(_value!.dispose);
    }
  }
}

/// A [RestorableProperty] that knows how to store and restore a
/// [TextEditingController].
///
/// The [TextEditingController] is accessible via the [value] getter. During
/// state restoration, the property will restore [TextEditingController.text] to
/// the value it had when the restoration data it is getting restored from was
/// collected.
class RestorableTextEditingController extends RestorableChangeNotifier<TextEditingController> {
  /// Creates a [RestorableTextEditingController].
  ///
  /// This constructor treats a null `text` argument as if it were the empty
  /// string.
  factory RestorableTextEditingController({String? text}) => RestorableTextEditingController.fromValue(
    text == null ? TextEditingValue.empty : TextEditingValue(text: text),
  );

  /// Creates a [RestorableTextEditingController] from an initial
  /// [TextEditingValue].
  ///
  /// This constructor treats a null `value` argument as if it were
  /// [TextEditingValue.empty].
  RestorableTextEditingController.fromValue(TextEditingValue value) : _initialValue = value;

  final TextEditingValue _initialValue;

  @override
  TextEditingController createDefaultValue() {
    return TextEditingController.fromValue(_initialValue);
  }

  @override
  TextEditingController fromPrimitives(Object? data) {
    return TextEditingController(text: data! as String);
  }

  @override
  Object toPrimitives() {
    return value.text;
  }
}
