// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// For more info, see: https://pub.dartlang.org/packages/async_redux

import 'package:flutter/foundation.dart';

enum WaitOperation { add, remove, clear }

/// Immutable object to keep track of boolean flags that indicate if some
/// process is in progress (the user is "waiting").
///
/// The flags and flag-references can be any immutable object.
/// They must be immutable to make sure [Wait] is also immutable.
///
/// Use it in Redux store states, like this:
/// * To add a flag: state.copy(wait: state.wait.add(flag: myFlag));
/// * To remove a flag: state.copy(wait: state.wait.remove(flag: myFlag));
/// * To clear all flags: state.copy(wait: state.wait.clear());
///
/// If can also use have a flag with a reference, like this:
/// * To add a flag with reference: state.copy(wait: state.wait.add(flag: myFlag, ref:MyRef));
/// * To remove a flag with reference: state.copy(wait: state.wait.remove(flag: myFlag, ref:MyRef));
/// * To clear all references for a flag: state.copy(wait: state.wait.clear(flag: myFlag));
///
/// In the ViewModel, you can check the flags/references, like this:
///
/// * To check if there is any waiting: state.wait.isWaitingAny
/// * To check if is waiting a specific flag: state.wait.isWaiting(myFlag);
/// * To check if is waiting a specific flag/reference: state.wait.isWaiting(myFlag, ref: myRef);
///
@immutable
class Wait {
  final Map<Object?, Set<Object?>> _flags;

  static const Wait empty = Wait._({});

  factory Wait() => empty;

  /// Convenience flag that you can use when a `null` value means ALL.
  /// For example, suppose if you want until an async process schedules an `appointment`
  /// for specific `time`. However, if no time is selected, you want to schedule the whole
  /// day (all "times"). You can do:
  /// `dispatch(WaitAction.add(appointment, ref: time ?? Wait.ALL));`
  ///
  /// And then later check if you are waiting for a specific time:
  /// `if (wait.isWaiting(appointment, ref: time) { ... }`
  ///
  /// Or if you are waiting for the whole day:
  /// `if (wait.isWaiting(appointment, ref: Wait.ALL) { ... }`
  ///
  static const ALL = Object();

  const Wait._(Map<Object?, Set<Object?>> flags) : _flags = flags;

  Wait add({required Object? flag, Object? ref}) {
    Map<Object?, Set<Object?>> newFlags = _deepCopy();

    Set<Object?>? refs = newFlags[flag];
    if (refs == null) {
      refs = {};
      newFlags[flag] = refs;
    }
    refs.add(ref);

    return Wait._(newFlags);
  }

  Wait remove({required Object? flag, Object? ref}) {
    if (_flags.isEmpty)
      return this;
    else {
      Map<Object?, Set<Object?>> newFlags = _deepCopy();

      if (ref == null) {
        newFlags.remove(flag);
      } else {
        Set<Object?> refs = newFlags[flag] ?? {};
        refs.remove(ref);
        if (refs.isEmpty) newFlags.remove(flag);
      }

      if (newFlags.isEmpty)
        return empty;
      else
        return Wait._(newFlags);
    }
  }

  Wait process(WaitOperation operation, {
    required Object? flag,
    Object? ref,
  }) {
    if (operation == WaitOperation.add)
      return add(flag: flag, ref: ref);
    else if (operation == WaitOperation.remove)
      return remove(flag: flag, ref: ref);
    else if (operation == WaitOperation.clear)
      return clear(flag: flag);
    else
      throw AssertionError(operation);
  }

  /// Return true if there is any waiting (any flag).
  bool get isWaitingAny => _flags.isNotEmpty;

  /// Return true if is waiting for a specific flag.
  /// If [ref] is null, it returns true if it's waiting for any reference of the flag.
  /// If [ref] is not null, it returns true if it's waiting for that specific reference of the flag.
  bool isWaiting(Object? flag, {Object? ref}) {
    Set? refs = _flags[flag];

    return (ref == null) //
        ? (refs != null) && refs.isNotEmpty //
        : (refs != null) && refs.contains(ref);
  }

  /// Return true if is waiting for ANY flag of the specific type.
  ///
  /// This is useful when you want to wait for an Action to finish. For example:
  ///
  /// ```
  /// class MyAction extends ReduxAction<AppState> {
  ///   Future<AppState?> reduce() async {
  ///     await doSomething();
  ///     return null;
  ///   }
  ///
  ///   void before() => dispatch(WaitAction.add(this));
  ///   void after() => dispatch(WaitAction.remove(this));
  /// }
  ///
  /// // Then, in some widget or connector:
  /// if (wait.isWaitingForType<MyAction>()) { ... }
  /// ```
  bool isWaitingForType<T>() {
    for (Object? flag in _flags.keys)
      if (flag is T) return true;
    return false;
  }

  Wait clear({Object? flag}) {
    if (flag == null)
      return empty;
    else {
      Map<Object?, Set<Object?>> newFlags = _deepCopy();
      newFlags.remove(flag);
      return Wait._(newFlags);
    }
  }

  void clearWhere(bool Function(
      Object? flag,
      Set<Object?> refs,
      ) test) =>
      _flags.removeWhere(test);

  Map<Object?, Set<Object?>> _deepCopy() {
    Map<Object?, Set<Object?>> newFlags = {};

    for (MapEntry<Object?, Set<Object?>> flag in _flags.entries) {
      newFlags[flag.key] = Set.of(flag.value);
    }

    return newFlags;
  }
}
