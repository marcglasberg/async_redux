import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:bdd_framework/bdd_framework.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var feature = BddFeature('Store wait action');

  test('waitCondition', () async {
    // Returns a future that completes when the state is in the given condition.
    // Since the state is already in the condition, the future completes immediately.
    var store = Store<State>(initialState: State(1));
    await store.waitCondition((state) => state.count == 1);

    // The state is NEVER in the condition, but the timeout will end it.
    await expectLater(
      () => store.waitCondition((state) => state.count == 2, timeoutMillis: 10),
      throwsA(isA<TimeoutException>()),
    );

    // An ASYNC action will put the state in the condition, after a while.
    store = Store<State>(initialState: State(1));
    store.dispatch(IncrementActionAsync());
    await store.waitCondition((state) => state.count == 2);

    // A SYNC action will put the state in the condition, before the condition is created.
    store = Store<State>(initialState: State(1));
    store.dispatch(IncrementAction());
    expect(store.state.count, 2);
    await store.waitCondition((state) => state.count == 2);

    // A Future will dispatch a SYNC action that puts the state in the condition.
    store = Store<State>(initialState: State(1));
    Future(() => store.dispatch(IncrementAction()));
    expect(store.state.count, 1);
    await store.waitCondition((state) => state.count == 2);
    expect(store.state.count, 2);

    // A Future will dispatch a SYNC action that puts the state in the condition, after a while.
    store = Store<State>(initialState: State(1));
    Future.delayed(const Duration(milliseconds: 50), () => store.dispatch(IncrementAction()));
    expect(store.state.count, 1);
    await store.waitCondition((state) => state.count == 2);
    expect(store.state.count, 2);
  });

  test('waitAllActions', () async {
    // Returns a future that completes when no actions are in progress.
    // Since no actions are currently in progress, the future completes immediately.
    // We are ACCEPTING futures completed immediately.
    var store = Store<State>(initialState: State(1));
    await store.waitAllActions([], completeImmediately: true);

    // Returns a future that completes when no actions are in progress.
    // Since no actions are currently in progress, the future completes immediately.
    // We are NOT accepting futures completed immediately: should throw a StoreException.
    store = Store<State>(initialState: State(1));
    await expectLater(
      () => store.waitAllActions([]),
      throwsA(isA<StoreException>()),
    );

    // Returns a future that completes when no actions are in progress.
    // There is an actions is progress.
    store = Store<State>(initialState: State(1));
    store.dispatchAndWait(DelayedAction(1, delayMillis: 1));
    expect(store.state.count, 1);
    await store.waitAllActions([]);
    expect(store.state.count, 2);
  });

  test('waitActionType', () async {
    // Returns a future that completes when the actions of the given type is NOT in progress.
    // Since no actions are currently in progress, the future completes immediately.
    var store = Store<State>(initialState: State(1));
    await store.waitActionType(DelayedAction, completeImmediately: true);

    // Again, since no actions are currently in progress, the future completes immediately.
    // The timeout is irrelevant.
    store = Store<State>(initialState: State(1));
    await store.waitActionType(DelayedAction, timeoutMillis: 1, completeImmediately: true);

    // An actions of the given type is in progress.
    // But then the action ends.
    store = Store<State>(initialState: State(1));
    store.dispatch(DelayedAction(1, delayMillis: 10));
    await store.waitActionType(DelayedAction);

    // An actions of the given type is in progress.
    // But the wait will timeout.
    store = Store<State>(initialState: State(1));
    store.dispatch(DelayedAction(1, delayMillis: 1000));
    await expectLater(
      () => store.waitActionType(DelayedAction, timeoutMillis: 1),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('waitAllActionTypes', () async {
    // Returns a future that completes when ALL actions of the given type are NOT in progress.
    // Since no actions are currently in progress, the future completes immediately.
    var store = Store<State>(initialState: State(1));
    store.dispatch(DelayedAction(1, delayMillis: 10));
    store.waitAllActionTypes([DelayedAction, AnotherDelayedAction]);

    // An actions of the given type is in progress.
    // But then the action ends.
    store = Store<State>(initialState: State(1));
    store.dispatch(DelayedAction(1, delayMillis: 10));
    store.waitAllActionTypes([DelayedAction, AnotherDelayedAction]);

    // ---

    // An actions of the given type is in progress.
    // But the wait will timeout.
    store = Store<State>(initialState: State(1));
    store.dispatch(DelayedAction(1, delayMillis: 1000));

    dynamic error;
    try {
      await store.waitAllActionTypes([DelayedAction, AnotherDelayedAction], timeoutMillis: 10);
    } catch (_error) {
      error = _error;
    }
    expect(error, isA<TimeoutException>());
  });

  test('waitActionCondition', () async {
    // Returns a future that completes when the actions of the given type that are in progress
    // meet the given condition. Since no actions are currently in progress, and we're checking
    // to see if there are no actions in progress, the future completes immediately.
    var store = Store<State>(initialState: State(1));
    await store.waitActionCondition((actions, triggerAction) => actions.isEmpty,
        completeImmediately: true);
  });

  test('waitAnyActionTypeFinishes', () async {
    // Returns a future that completes when an action of ANY of the given types finish after
    // the method is called. We start an action before calling the method, then call the method.
    // As soon as the action finishes, the future completes.
    var store = Store<State>(initialState: State(1));
    store.dispatch(DelayedAction(1, delayMillis: 10));
    ReduxAction<State> action =
        await store.waitAnyActionTypeFinishes([DelayedAction], timeoutMillis: 2000);
    expect(action, isA<DelayedAction>());
    expect(action.status.isCompletedOk, true);

    // ---

    // Returns a future that completes when an action of ANY of the given types finish after
    // the method is called. We start an action before calling the method, then call the method.
    // As soon as the action finishes, the future completes.
    store = Store<State>(initialState: State(1));

    dynamic error;
    try {
      await store.waitAnyActionTypeFinishes([DelayedAction], timeoutMillis: 10);
    } catch (_error) {
      error = _error;
    }
    expect(error, isA<TimeoutException>());
  });

  Bdd(feature)
      .scenario('We dispatch no actions and wait for all to finish.')
      .given('No actions are dispatched.')
      .when('We wait until no actions are dispatched.')
      .then('The code continues immediately.')
      .run((_) async {
    final store = Store<State>(initialState: State(1));

    await store.waitAllActions([], completeImmediately: true);
    expect(store.state.count, 1);
  });

  Bdd(feature)
      .scenario('We dispatch async actions and wait for all to finish.')
      .given('Three ASYNC actions.')
      .when('The actions are dispatched in PARALLEL.')
      .and('We wait until NO ACTIONS are being dispatched.')
      .then('After we wait, all actions finished.')
      .run((_) async {
    final store = Store<State>(initialState: State(1));

    expect(store.state.count, 1);

    store.dispatch(DelayedAction(10, delayMillis: 50));
    store.dispatch(AnotherDelayedAction(100, delayMillis: 100));
    store.dispatch(DelayedAction(1000, delayMillis: 20));

    expect(store.state.count, 1);
    await store.waitAllActions([]);
    expect(store.state.count, 1 + 10 + 100 + 1000);
  });

  Bdd(feature)
      .scenario('We dispatch an async action and wait for its action TYPE to finish.')
      .given('An ASYNC actions.')
      .when('The action is dispatched.')
      .then('We wait until its type finished dispatching.')
      .run((_) async {
    final store = Store<State>(initialState: State(1));

    expect(store.state.count, 1);

    store.dispatch(AnotherDelayedAction(123, delayMillis: 100));
    store.dispatch(DelayedAction(1000, delayMillis: 10));

    expect(store.state.count, 1);
    await store.waitActionType(DelayedAction, timeoutMillis: 2000);
    expect(store.state.count, 1001);
    await store.waitActionType(AnotherDelayedAction, timeoutMillis: 2000);
    expect(store.state.count, 1124);
  });

  Bdd(feature)
      .scenario('We dispatch async actions and wait for some action TYPES to finish.')
      .given('Four ASYNC actions.')
      .and('The fourth takes longer than an others to finish.')
      .when('The actions are dispatched in PARALLEL.')
      .and('We wait until there the types of the faster 3 finished dispatching.')
      .then('After we wait, the 3 actions finished, and the fourth did not.')
      .run((_) async {
    final store = Store<State>(initialState: State(1));

    expect(store.state.count, 1);

    store.dispatch(DelayedAction(10, delayMillis: 50));
    store.dispatch(AnotherDelayedAction(100, delayMillis: 100));
    store.dispatch(YetAnotherDelayedAction(100000, delayMillis: 200));
    store.dispatch(DelayedAction(1000, delayMillis: 10));

    expect(store.state.count, 1);
    await store.waitAllActionTypes([DelayedAction, AnotherDelayedAction], timeoutMillis: 2000);
    expect(store.state.count, 1 + 10 + 100 + 1000);
  });

  Bdd(feature)
      .scenario('We dispatch async actions and wait for some of them to finish.')
      .given('Four ASYNC actions.')
      .and('The fourth takes longer than an others to finish.')
      .when('The actions are dispatched in PARALLEL.')
      .and('We wait until there the faster 3 finished dispatching.')
      .then('After we wait, the 3 actions finished, and the fourth did not.')
      .run((_) async {
    final store = Store<State>(initialState: State(1));

    expect(store.state.count, 1);

    var action50 = DelayedAction(10, delayMillis: 50);
    var action100 = AnotherDelayedAction(100, delayMillis: 100);
    var action200 = YetAnotherDelayedAction(100000, delayMillis: 200);
    var action10 = DelayedAction(1000, delayMillis: 10);

    store.dispatch(action50);
    store.dispatch(action100);
    store.dispatch(action200); // We don't wait for this one.
    store.dispatch(action10);

    expect(store.state.count, 1);
    await store.waitAllActions([action50, action100, action10]);
    expect(store.state.count, 1 + 10 + 100 + 1000);
  });
}

class State {
  final int count;

  State(this.count);

  @override
  String toString() {
    return 'State($count)';
  }
}

class IncrementAction extends ReduxAction<State> {
  @override
  State reduce() => State(state.count + 1);
}

class IncrementActionAsync extends ReduxAction<State> {
  @override
  Future<State> reduce() async {
    await Future.delayed(const Duration(milliseconds: 10));
    return State(state.count + 1);
  }
}

class DelayedAction extends ReduxAction<State> {
  final int increment;
  final int delayMillis;

  DelayedAction(this.increment, {required this.delayMillis});

  @override
  Future<State> reduce() async {
    await Future.delayed(Duration(milliseconds: delayMillis));
    return State(state.count + increment);
  }
}

class AnotherDelayedAction extends DelayedAction {
  AnotherDelayedAction(int increment, {required int delayMillis})
      : super(increment, delayMillis: delayMillis);
}

class YetAnotherDelayedAction extends DelayedAction {
  YetAnotherDelayedAction(int increment, {required int delayMillis})
      : super(increment, delayMillis: delayMillis);
}
