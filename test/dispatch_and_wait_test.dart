import 'package:async_redux/async_redux.dart';
import 'package:bdd_framework/bdd_framework.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var feature = BddFeature('Dispatch and wait');

  Bdd(feature)
      .scenario('Waiting for a dispatchAndWait to end.')
      .given('A SYNC or ASYNC action.')
      .when('The action is dispatched with `dispatchAndWait(action)`.')
      .then('It returns a `Promise` that resolves when the action finishes.')
      .run((_) async {
    final store = Store<State>(initialState: State(1));

    expect(store.state.count, 1);
    await store.dispatch(IncrementSync());
    expect(store.state.count, 2);

    await store.dispatch(IncrementAsync());
    expect(store.state.count, 3);
  });

  Bdd(feature)
      .scenario('Knowing when some action dispatched with `dispatchAndWait` is being processed.')
      .given('A SYNC or ASYNC action.')
      .when('The action is dispatched.')
      .then('We can check if the action is processing with `Store.isWaiting(actionType)`.')
      .run((_) async {
    final store = Store<State>(initialState: State(1));

    // SYNC ACTION: isWaiting is always false.

    expect(store.isWaiting(IncrementSync), false);
    expect(store.state.count, 1);

    var actionSync = IncrementSync();
    expect(actionSync.status.isDispatched, false);
    var promise1 = store.dispatch(actionSync);
    expect(actionSync.status.isDispatched, true);

    expect(store.isWaiting(IncrementSync), false);
    expect(store.state.count, 2);

    await promise1; // Since it's SYNC, it's already finished when dispatched.

    expect(store.isWaiting(IncrementSync), false);
    expect(store.state.count, 2);

    // ASYNC ACTION: isWaiting is true while we wait for it to finish.

    expect(store.isWaiting(IncrementAsync), false);
    expect(store.state.count, 2);

    var actionAsync = IncrementAsync();
    expect(actionAsync.status.isDispatched, false);

    var promise2 = store.dispatch(actionAsync);
    expect(actionAsync.status.isDispatched, true);

    expect(store.isWaiting(IncrementAsync), true); // True!
    expect(store.state.count, 2);

    await promise2; // Since it's ASYNC, it really waits until it finishes.

    expect(store.isWaiting(IncrementAsync), false);
    expect(store.state.count, 3);
  });

  Bdd(feature)
      .scenario('Reading the ActionStatus of the action.')
      .given('A SYNC or ASYNC action.')
      .when('The action is dispatched.')
      .and('The action finishes without any errors.')
      .then('We can check the action status, which says the action completed OK (no errors).')
      .run((_) async {
    final store = Store<State>(initialState: State(1));

    // SYNC ACTION
    var actionSync = IncrementSync();
    var status = actionSync.status;

    expect(status.isDispatched, false);
    expect(status.hasFinishedMethodBefore, false);
    expect(status.hasFinishedMethodReduce, false);
    expect(status.hasFinishedMethodAfter, false);
    expect(status.isCompleted, false);
    expect(status.isCompletedOk, false);
    expect(status.isCompletedFailed, false);

    status = await store.dispatchAndWait(actionSync);

    expect(status, actionSync.status);
    expect(status.isDispatched, true);
    expect(status.hasFinishedMethodBefore, true);
    expect(status.hasFinishedMethodReduce, true);
    expect(status.hasFinishedMethodAfter, true); // After is like a "finally" block. It always runs.
    expect(status.isCompleted, true);
    expect(status.isCompletedOk, true);
    expect(status.isCompletedFailed, false);

    // ASYNC ACTION
    var actionAsync = IncrementAsync();
    status = actionAsync.status;

    expect(status.isDispatched, false);
    expect(status.hasFinishedMethodBefore, false);
    expect(status.hasFinishedMethodReduce, false);
    expect(status.hasFinishedMethodAfter, false);
    expect(status.isCompleted, false);
    expect(status.isCompletedOk, false);
    expect(status.isCompletedFailed, false);

    status = await store.dispatchAndWait(actionAsync);

    expect(status, actionAsync.status);
    expect(status.isDispatched, true);
    expect(status.hasFinishedMethodBefore, true);
    expect(status.hasFinishedMethodReduce, true);
    expect(status.hasFinishedMethodAfter, true); // After is like a "finally" block. It always runs.
    expect(status.isCompleted, true);
    expect(status.isCompletedOk, true);
    expect(status.isCompletedFailed, false);
  });

  Bdd(feature)
      .scenario('Reading the ActionStatus of the action.')
      .given('A SYNC or ASYNC action.')
      .when('The action is dispatched.')
      .and('The action fails in the "before" method.')
      .then('We can check the action status, which says the action completed with errors.')
      .run((_) async {
    final store = Store<State>(initialState: State(1));

    // SYNC ACTION
    var actionSync = IncrementSyncBeforeFails();
    var status = actionSync.status;

    expect(status.isDispatched, false);
    expect(status.hasFinishedMethodBefore, false);
    expect(status.hasFinishedMethodReduce, false);
    expect(status.hasFinishedMethodAfter, false);
    expect(status.isCompleted, false);

    status = await store.dispatchAndWait(actionSync);

    expect(status, actionSync.status);
    expect(status.isDispatched, true);
    expect(status.hasFinishedMethodBefore, false);
    expect(status.hasFinishedMethodReduce, false);
    expect(status.hasFinishedMethodAfter, true); // After is like a "finally" block. It always runs.
    expect(status.isCompleted, true);
    expect(status.isCompletedOk, false);
    expect(status.isCompletedFailed, true);

    // ASYNC ACTION
    var actionAsync = IncrementAsyncBeforeFails();
    status = actionAsync.status;

    expect(status.isDispatched, false);
    expect(status.hasFinishedMethodBefore, false);
    expect(status.hasFinishedMethodReduce, false);
    expect(status.hasFinishedMethodAfter, false);
    expect(status.isCompleted, false);

    status = await store.dispatchAndWait(actionAsync);

    expect(status, actionAsync.status);
    expect(status.isDispatched, true);
    expect(status.hasFinishedMethodBefore, false);
    expect(status.hasFinishedMethodReduce, false);
    expect(status.hasFinishedMethodAfter, true); // After is like a "finally" block. It always runs.
    expect(status.isCompleted, true);
    expect(status.isCompletedOk, false);
    expect(status.isCompletedFailed, true);
  });

  Bdd(feature)
      .scenario('Reading the ActionStatus of the action.')
      .given('A SYNC or ASYNC action.')
      .when('The action is dispatched.')
      .and('The action fails in the "reduce" method.')
      .then('We can check the action status, which says the action completed with errors.')
      .run((_) async {
    final store = Store<State>(initialState: State(1));

    // SYNC ACTION
    var actionSync = IncrementSyncReduceFails();
    var status = actionSync.status;

    expect(status.isDispatched, false);
    expect(status.hasFinishedMethodBefore, false);
    expect(status.hasFinishedMethodReduce, false);
    expect(status.hasFinishedMethodAfter, false);
    expect(status.isCompleted, false);

    status = await store.dispatchAndWait(actionSync);

    expect(status, actionSync.status);
    expect(status.isDispatched, true);
    expect(status.hasFinishedMethodBefore, true);
    expect(status.hasFinishedMethodReduce, false);
    expect(status.hasFinishedMethodAfter, true); // After is like a "finally" block. It always runs.
    expect(status.isCompleted, true);
    expect(status.isCompletedOk, false);
    expect(status.isCompletedFailed, true);

    // ASYNC ACTION
    var actionAsync = IncrementAsyncReduceFails();
    status = actionAsync.status;

    expect(status.isDispatched, false);
    expect(status.hasFinishedMethodBefore, false);
    expect(status.hasFinishedMethodReduce, false);
    expect(status.hasFinishedMethodAfter, false);
    expect(status.isCompleted, false);

    status = await store.dispatchAndWait(actionAsync);

    expect(status, actionAsync.status);
    expect(status.isDispatched, true);
    expect(status.hasFinishedMethodBefore, true);
    expect(status.hasFinishedMethodReduce, false);
    expect(status.hasFinishedMethodAfter, true); // After is like a "finally" block. It always runs.
    expect(status.isCompleted, true);
    expect(status.isCompletedOk, false);
    expect(status.isCompletedFailed, true);
  });

  Bdd(feature)
      .scenario('Reading the ActionStatus of the action.')
      .given('A SYNC or ASYNC action.')
      .when('The action is dispatched.')
      .and('The action fails in the "reduce" method.')
      .then('We can check the action status, which says the action completed with errors.')
      .run((_) async {
    final store = Store<State>(initialState: State(1));

    // SYNC ACTION
    var actionSync = IncrementSyncReduceFails();
    var status = actionSync.status;

    expect(status.isDispatched, false);
    expect(status.hasFinishedMethodBefore, false);
    expect(status.hasFinishedMethodReduce, false);
    expect(status.hasFinishedMethodAfter, false);
    expect(status.isCompleted, false);

    status = await store.dispatchAndWait(actionSync);

    expect(status, actionSync.status);
    expect(status.isDispatched, true);
    expect(status.hasFinishedMethodBefore, true);
    expect(status.hasFinishedMethodReduce, false);
    expect(status.hasFinishedMethodAfter, true); // After is like a "finally" block. It always runs.
    expect(status.isCompleted, true);
    expect(status.isCompletedOk, false);
    expect(status.isCompletedFailed, true);

    // ASYNC ACTION
    var actionAsync = IncrementAsyncReduceFails();
    status = actionAsync.status;

    expect(status.isDispatched, false);
    expect(status.hasFinishedMethodBefore, false);
    expect(status.hasFinishedMethodReduce, false);
    expect(status.hasFinishedMethodAfter, false);
    expect(status.isCompleted, false);

    status = await store.dispatchAndWait(actionAsync);

    expect(status, actionAsync.status);
    expect(status.isDispatched, true);
    expect(status.hasFinishedMethodBefore, true);
    expect(status.hasFinishedMethodReduce, false);
    expect(status.hasFinishedMethodAfter, true); // After is like a "finally" block. It always runs.
    expect(status.isCompleted, true);
    expect(status.isCompletedOk, false);
    expect(status.isCompletedFailed, true);
  });
}

class State {
  final int count;

  State(this.count);
}

class IncrementSync extends ReduxAction<State> {
  @override
  State reduce() {
    return State(state.count + 1);
  }
}

class IncrementAsync extends ReduxAction<State> {
  @override
  Future<State> reduce() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return State(state.count + 1);
  }
}

class IncrementSyncBeforeFails extends ReduxAction<State> {
  @override
  void before() {
    throw const UserException('Before failed');
  }

  @override
  State reduce() {
    return State(state.count + 1);
  }
}

class IncrementSyncReduceFails extends ReduxAction<State> {
  @override
  State reduce() {
    throw const UserException('Reduce failed');
  }
}

class IncrementSyncAfterFails extends ReduxAction<State> {
  @override
  State reduce() {
    return State(state.count + 1);
  }

  @override
  void after() {
    throw const UserException('After failed');
  }
}

class IncrementAsyncBeforeFails extends ReduxAction<State> {
  @override
  Future<void> before() async {
    throw const UserException('Before failed');
  }

  @override
  Future<State> reduce() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return State(state.count + 1);
  }
}

class IncrementAsyncReduceFails extends ReduxAction<State> {
  @override
  Future<State> reduce() async {
    await Future.delayed(const Duration(milliseconds: 50));
    throw const UserException('Reduce failed');
  }
}

class IncrementAsyncAfterFails extends ReduxAction<State> {
  @override
  Future<State> reduce() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return State(state.count + 1);
  }

  @override
  Future<void> after() async {
    throw const UserException('After failed');
  }
}
