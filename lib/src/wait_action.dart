import 'package:flutter/material.dart';

import '../async_redux.dart';

// Developed by Marcelo Glasberg (Apr 2020).
// For more info, see: https://pub.dartlang.org/packages/async_redux

/// For this to work your store state must have a `Wait` field named `wait`,
/// and then the state's `copy` method must also copy this field as a named
/// parameter. For example:
///
/// ```
/// class AppState {
///   final Wait wait;
///   AppState({this.wait});
///   AppState copy({Wait wait}) => AppState(wait: wait);
///   }
/// ```
class WaitAction<St> extends ReduxAction<St> {
  final WaitOperation operation;

  final Object flag, ref;

  /// [flag] and [ref] must be immutable objects.
  WaitAction.add(
    this.flag, {
    this.ref,
  }) : operation = WaitOperation.add;

  WaitAction.remove(
    this.flag, {
    this.ref,
  }) : operation = WaitOperation.remove;

  WaitAction.clear([
    this.flag,
  ])  : operation = WaitOperation.clear,
        ref = null;

  @override
  St reduce() {
    Wait wait = (state as dynamic).wait ?? Wait();
    return (state as dynamic).copy(wait: wait.process(operation, flag: flag, ref: ref));
  }
}
