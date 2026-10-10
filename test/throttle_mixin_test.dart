import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:bdd_framework/bdd_framework.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var feature = BddFeature('Throttle actions');

  Bdd(feature)
      .scenario('Action is throttled when dispatched twice quickly')
      .given('An action with the Throttle mixin')
      .when('The action is dispatched twice within the throttle period')
      .then('It should only execute once')
      .run((_) async {
    //
    var store = Store<AppState>(initialState: AppState(0));
    await store.dispatch(ThrottleAction());
    expect(store.state.count, 1);

    // Dispatch again immediately. This dispatch should be aborted.
    await store.dispatch(ThrottleAction());
    expect(store.state.count, 1);
  });

  Bdd(feature)
      .scenario('Action executes again after throttle period expires')
      .given('An action with the Throttle mixin')
      .when('The action is dispatched, '
          'then after waiting for the throttle period, dispatched again')
      .then('It should execute both times')
      .run((_) async {
    //
    var store = Store<AppState>(initialState: AppState(0));
    await store.dispatch(ThrottleAction());
    expect(store.state.count, 1);

    // Wait for a bit more than the default throttle (400 ms).
    await Future.delayed(const Duration(milliseconds: 400));
    await store.dispatch(ThrottleAction());
    expect(store.state.count, 2);
  });

  Bdd(feature)
      .scenario(
          'Two different actions with the same lock are throttled together')
      .given('Two actions that override lockBuilder to return the same lock')
      .when('Both actions are dispatched in quick succession')
      .then('Only the first action should execute')
      .run((_) async {
    //
    var store = Store<AppState>(initialState: AppState(0));
    await store.dispatch(ThrottleAction1());
    expect(store.state.count, 1);

    // ThrottleAction2 uses the same lock as ThrottleAction1.
    await store.dispatch(ThrottleAction2());
    expect(store.state.count, 1);
  });

  Bdd(feature)
      .scenario('Two different actions with the same lock execute '
          'if throttle period expires')
      .given('Two actions that override lockBuilder to return the same lock')
      .when('The first action is dispatched, '
          'throttle period passes, then the second is dispatched')
      .then('Both actions should execute')
      .run((_) async {
    //
    var store = Store<AppState>(initialState: AppState(0));
    await store.dispatch(ThrottleAction1());
    expect(store.state.count, 1);

    await Future.delayed(const Duration(milliseconds: 400));
    await store.dispatch(ThrottleAction2());
    expect(store.state.count, 2);
  });

  Bdd(feature)
      .scenario('Actions with different runtime types '
          'are not throttled together')
      .given('Two actions with the Throttle mixin but different runtime types')
      .when('Both actions are dispatched in quick succession')
      .then('Both should execute independently')
      .run((_) async {
    //
    var store = Store<AppState>(initialState: AppState(0));
    await store.dispatch(ThrottleActionA());
    expect(store.state.count, 1);

    await store.dispatch(ThrottleActionB());
    expect(store.state.count, 2);
  });

  Bdd(feature)
      .scenario('With removeLockOnError, a failed action removes its lock')
      .given('An action with the Throttle mixin and removeLockOnError true')
      .when('The action fails')
      .then('It can be dispatched again right away')
      .run((_) async {
    //
    var store = Store<AppState>(initialState: AppState(0));
    var done = Completer<void>()..complete();

    await store.dispatchAndWait(SlowFailingAction(done, fail: true));
    await store.dispatchAndWait(SlowFailingAction(done, fail: false));
    expect(store.state.count, 1);
  });

  Bdd(feature)
      .scenario('With removeLockOnError, a failed action does not remove '
          'the lock of a newer action')
      .given('An action with the Throttle mixin and removeLockOnError true')
      .and('The action takes longer than the throttle period, and then fails')
      .and('A second action took a new lock after the first period ended')
      .when('A third action is dispatched within the period of the second')
      .then('The third action is aborted')
      .run((_) async {
    //
    var store = Store<AppState>(initialState: AppState(0));
    var completer = Completer<void>();
    var done = Completer<void>()..complete();

    var failing = SlowFailingAction(completer, fail: true);
    store.dispatch(failing);

    // The first throttle period ends, so this one runs and takes a new lock.
    await Future.delayed(const Duration(milliseconds: 150));
    await store.dispatchAndWait(SlowFailingAction(done, fail: false));
    expect(store.state.count, 1);

    // The first action fails, which must not remove the lock of the second.
    completer.complete();
    await store.waitAllActions([failing]);
    expect(failing.status.originalError, isA<UserException>());

    await store.dispatchAndWait(SlowFailingAction(done, fail: false));
    expect(store.state.count, 1);
  });

  Bdd(feature)
      .scenario('With removeLockOnError, a failed action does not remove '
          'the lock of a newer action that ignored the throttle')
      .given('An action with the Throttle mixin and removeLockOnError true')
      .and('While it runs, a second action ignores the throttle, '
          'and takes a new lock')
      .when('The first action fails, and then a third action is dispatched')
      .then('The third action is aborted')
      .run((_) async {
    //
    var store = Store<AppState>(initialState: AppState(0));
    var completer = Completer<void>();
    var done = Completer<void>()..complete();

    var failing = SlowFailingAction(completer, fail: true);
    store.dispatch(failing);

    await store
        .dispatchAndWait(SlowFailingAction(done, fail: false, force: true));
    expect(store.state.count, 1);

    // The first action fails, which must not remove the lock of the second.
    completer.complete();
    await store.waitAllActions([failing]);
    expect(failing.status.originalError, isA<UserException>());

    await store.dispatchAndWait(SlowFailingAction(done, fail: false));
    expect(store.state.count, 1);
  });
}

// A simple state that holds a count.
class AppState {
  final int count;

  AppState(this.count);

  AppState copy({int? count}) => AppState(count ?? this.count);

  @override
  String toString() => 'TestState($count)';
}

// An action that uses the Throttle mixin to increment the state.
class ThrottleAction extends ReduxAction<AppState> with Throttle {
  @override
  int throttle = 300;

  @override
  AppState reduce() {
    return state.copy(count: state.count + 1);
  }
}

// Two actions that override lockBuilder to return the same lock.
class ThrottleAction1 extends ReduxAction<AppState> with Throttle {
  @override
  int throttle = 300;

  @override
  Object? lockBuilder() => 'sharedLock';

  @override
  AppState reduce() {
    return state.copy(count: state.count + 1);
  }
}

class ThrottleAction2 extends ReduxAction<AppState> with Throttle {
  @override
  int throttle = 300;

  @override
  Object? lockBuilder() => 'sharedLock';

  @override
  AppState reduce() {
    return state.copy(count: state.count + 1);
  }
}

// Two actions with default lock (their runtime types differ).
class ThrottleActionA extends ReduxAction<AppState> with Throttle {
  @override
  int throttle = 300;

  @override
  AppState reduce() {
    return state.copy(count: state.count + 1);
  }
}

class ThrottleActionB extends ReduxAction<AppState> with Throttle {
  @override
  int throttle = 300;

  @override
  AppState reduce() {
    return state.copy(count: state.count + 1);
  }
}

// An action that waits for the completer, and then fails or increments the state.
class SlowFailingAction extends ReduxAction<AppState> with Throttle {
  final Completer<void> completer;
  final bool fail;
  final bool force;

  SlowFailingAction(this.completer, {required this.fail, this.force = false});

  @override
  int throttle = 100;

  @override
  bool removeLockOnError = true;

  @override
  bool get ignoreThrottle => force;

  @override
  Future<AppState> reduce() async {
    await completer.future;
    if (fail) throw const UserException('Failed');
    return state.copy(count: state.count + 1);
  }
}
