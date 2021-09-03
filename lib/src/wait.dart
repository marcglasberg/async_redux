// Developed by Marcelo Glasberg (Apr 2020).
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
/// * To check if there is any waiting: state.wait.isWaiting
/// * To check if a specific flag is waiting: state.wait.isWaitingFor(myFlag);
/// * To check if a specific flag/reference is waiting: state.wait.isWaitingFor(myFlag, ref: myRef);
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
  /// `if (wait.isWaitingFor(appointment, ref: time) { ... }`
  ///
  /// Or if you are waiting for the whole day:
  /// `if (wait.isWaitingFor(appointment, ref: Wait.ALL) { ... }`
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

  Wait process(
    WaitOperation operation, {
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

  bool get isWaiting => _flags.isNotEmpty;

  bool isWaitingFor(Object? flag, {Object? ref}) {
    Set? refs = _flags[flag];

    if (ref == null)
      return refs != null && refs.isNotEmpty;
    else
      return refs != null && refs.contains(ref);
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

  void clearWhere(
          bool Function(
    Object? flag,
    Set<Object?> refs,
  )
              test) =>
      _flags.removeWhere(test);

  Map<Object?, Set<Object?>> _deepCopy() {
    Map<Object?, Set<Object?>> newFlags = {};

    for (MapEntry<Object?, Set<Object?>> flag in _flags.entries) {
      newFlags[flag.key] = Set.of(flag.value);
    }

    return newFlags;
  }
}
