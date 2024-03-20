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
