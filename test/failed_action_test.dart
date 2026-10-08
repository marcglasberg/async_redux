import 'package:async_redux/async_redux.dart';
import 'package:bdd_framework/bdd_framework.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var feature = BddFeature('Failed action');

  Bdd(feature)
      .scenario('Checking if a SYNC action has failed.')
      .given('A SYNC action.')
      .when('The action is dispatched twice with `dispatch(action)`.')
      .and('The action fails the first time, but not the second time.')
      .then('We can check that the action failed the first time, but not the second.')
      .and('We can get the action exception the first time, but null the second time.')
      .and('We can clear the failing flag.')
      .run((_) async {
    final store = Store<State>(initialState: State(1));

    // When the SYNC action fails, the failed flag is set.
    expect(store.isFailed(SyncActionThatFails), false);
    var actionFail = SyncActionThatFails(true);
    store.dispatch(actionFail);
    expect(store.isFailed(SyncActionThatFails), true);
    expect(store.exceptionFor(SyncActionThatFails), const UserException('Yes, it failed.'));

    // When the same action is dispatched and does not fail, the failed flag is cleared.
    var actionSuccess = SyncActionThatFails(false);
    store.dispatch(actionSuccess);
    expect(store.isFailed(SyncActionThatFails), false);
    expect(store.exceptionFor(SyncActionThatFails), null);

    // Test clearing the exception.

    // Fail it again.
    store.dispatch(SyncActionThatFails(true));
    expect(store.isFailed(SyncActionThatFails), true);
    expect(store.exceptionFor(SyncActionThatFails), const UserException('Yes, it failed.'));

    // We clear the exception for ANOTHER action. It doesn't clear anything.
    store.clearExceptionFor(AsyncActionThatFails);
    expect(store.isFailed(SyncActionThatFails), true);
    expect(store.exceptionFor(SyncActionThatFails), const UserException('Yes, it failed.'));

    // We clear the exception for the correct action. Now it's NOT failing anymore.
    store.clearExceptionFor(SyncActionThatFails);
    expect(store.isFailed(SyncActionThatFails), false);
    expect(store.exceptionFor(SyncActionThatFails), null);
  });

  Bdd(feature)
      .scenario(
          'Dispatching an action again clears its failed state, even if nobody checked it.')
      .given('A SYNC action that failed, and nobody called `isFailed` or `exceptionFor`.')
      .when('The action is dispatched again and succeeds.')
      .and('Only then `isFailed` and `exceptionFor` are called for it.')
      .then('The action is not failed, and has no exception.')
      .run((_) async {
    final store = Store<State>(initialState: State(1));

    // Fails, but nobody checks it.
    store.dispatch(SyncActionThatFails(true));

    // Succeeds, and only now we check it.
    store.dispatch(SyncActionThatFails(false));

    expect(store.isFailed(SyncActionThatFails), false);
    expect(store.exceptionFor(SyncActionThatFails), null);
  });

  Bdd(feature)
      .scenario(
          'The failed state is cleared when the action is dispatched again, not when it ends.')
      .given('An ASYNC action that failed, and nobody called `isFailed` or `exceptionFor`.')
      .when('The action is dispatched again, and is still running.')
      .then('The action is not failed, and has no exception.')
      .and('If it fails again, it is failed again, with the new exception.')
      .run((_) async {
    final store = Store<State>(initialState: State(1));

    // Fails, but nobody checks it.
    await store.dispatchAndWait(AsyncActionThatFails(true));

    // Dispatched again. While it runs, it's not failed.
    var future = store.dispatchAndWait(AsyncActionThatFails(true));
    expect(store.isFailed(AsyncActionThatFails), false);
    expect(store.exceptionFor(AsyncActionThatFails), null);

    // It fails again.
    await future;
    expect(store.isFailed(AsyncActionThatFails), true);
    expect(store.exceptionFor(AsyncActionThatFails), const UserException('Yes, it failed.'));
  });

  Bdd(feature)
      .scenario('Checking if an ASYNC action has failed.')
      .given('An ASYNC action.')
      .when('The action is dispatched twice with `dispatch(action)`.')
      .and('The action fails the first time, but not the second time.')
      .then('We can check that the action failed the first time, but not the second.')
      .and('We can get the action exception the first time, but null the second time.')
      .and('We can clear the failing flag.')
      .run((_) async {
    final store = Store<State>(initialState: State(1));

    // Initially, flag tells us it's NOT failing.
    expect(store.isFailed(AsyncActionThatFails), false);
    var actionFail = AsyncActionThatFails(true);

    // The action is dispatched, but it's ASYNC. We wait for it.
    await store.dispatch(actionFail);

    // Now it's failed.
    expect(store.isFailed(AsyncActionThatFails), true);
    expect(store.exceptionFor(AsyncActionThatFails), const UserException('Yes, it failed.'));

    // We clear the exception, so that it's NOT failing.
    store.clearExceptionFor(AsyncActionThatFails);
    expect(store.isFailed(AsyncActionThatFails), false);
    actionFail = AsyncActionThatFails(true);

    // The action is dispatched, but it's ASYNC.
    store.dispatch(actionFail);

    // So, there was no time to fail.
    expect(store.isFailed(AsyncActionThatFails), false);

    // We wait until it really finishes.
    await Future.delayed(const Duration(milliseconds: 50));

    // Now it's failed.
    expect(store.isFailed(AsyncActionThatFails), true);
    expect(store.exceptionFor(AsyncActionThatFails), const UserException('Yes, it failed.'));

    // We dispatch the same action type again.
    actionFail = AsyncActionThatFails(true);
    store.dispatch(actionFail);

    // This act of dispatching it cleared the flag.
    expect(store.isFailed(AsyncActionThatFails), false);

    // We wait until it really finishes, again.
    await Future.delayed(const Duration(milliseconds: 500));

    // Not it's failed, again.
    expect(store.isFailed(AsyncActionThatFails), true);
    expect(store.exceptionFor(AsyncActionThatFails), const UserException('Yes, it failed.'));
  });

  Bdd(feature)
      .scenario('Checking if any of a list of action types has failed.')
      .given('A list of action types, where only the last one failed.')
      .when('We check the list with `isFailed` and `exceptionFor`.')
      .then('We get the failure of the type that failed, even if it is not the first.')
      .and('Dispatching any of the types again clears its failure.')
      .and('Clearing the list notifies the UI, even if only the first type failed.')
      .run((_) async {
    final store = Store<State>(initialState: State(1));
    var types = [SyncActionThatFails, AsyncActionThatFails];

    // Only the LAST type in the list failed.
    await store.dispatchAndWait(AsyncActionThatFails(true));
    expect(store.isFailed(types), true);
    expect(store.exceptionFor(types), const UserException('Yes, it failed.'));

    // Now both types failed. We get the exception of the first one in the list.
    store.dispatch(SyncActionThatFails(true));
    expect(store.isFailed(types), true);

    // Since we checked the whole list, dispatching any of its types clears its failure.
    await store.dispatchAndWait(AsyncActionThatFails(false));
    expect(store.isFailed(AsyncActionThatFails), false);
    expect(store.isFailed(types), true);

    // Only the FIRST type in the list failed, and clearing the list notifies the UI.
    var notifications = 0;
    var subscription = store.onChange.listen((_) => notifications++);
    store.clearExceptionFor(types);
    await Future.delayed(Duration.zero);
    expect(notifications, 1);
    expect(store.isFailed(types), false);
    expect(store.exceptionFor(types), null);
    await subscription.cancel();
  });
}

class State {
  final int count;

  State(this.count);
}

class SyncActionThatFails extends ReduxAction<State> {
  final bool ifFails;

  SyncActionThatFails(this.ifFails);

  @override
  State? reduce() {
    if (ifFails) throw const UserException('Yes, it failed.');
    return null;
  }
}

class AsyncActionThatFails extends ReduxAction<State> {
  final bool ifFails;

  AsyncActionThatFails(this.ifFails);

  @override
  Future<State?> reduce() async {
    await Future.delayed(const Duration(milliseconds: 1));
    if (ifFails) throw const UserException('Yes, it failed.');
    return null;
  }
}
