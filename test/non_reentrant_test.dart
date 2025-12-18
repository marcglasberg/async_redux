import 'package:async_redux/async_redux.dart';
import 'package:bdd_framework/bdd_framework.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var feature = BddFeature('Non reentrant actions');

  // ==========================================================================
  // Case 1: Sync action non-reentrant does not call itself
  // ==========================================================================

  Bdd(feature)
      .scenario('Sync action non-reentrant does not call itself.')
      .given('A SYNC action that calls itself.')
      .and('The action is non-reentrant.')
      .when('The action is dispatched.')
      .then('It runs once.')
      .and('Does not result in a stack overflow.')
      .run((_) async {
    var store = Store<State>(initialState: State(1));

    expect(store.state.count, 1);
    store.dispatchSync(NonReentrantSyncActionCallsItself());
    expect(store.state.count, 2);
  });

  // ==========================================================================
  // Case 2: Async action non-reentrant does not call itself
  // ==========================================================================

  Bdd(feature)
      .scenario('Async action non-reentrant does not call itself.')
      .given('An ASYNC action that calls itself.')
      .and('The action is non-reentrant.')
      .when('The action is dispatched.')
      .then('It runs once.')
      .and('Does not result in a stack overflow.')
      .run((_) async {
    var store = Store<State>(initialState: State(1));

    expect(store.state.count, 1);
    store.dispatch(NonReentrantAsyncActionCallsItself());
    expect(store.state.count, 2);
  });

  // ==========================================================================
  // Case 3: Async action non-reentrant blocks concurrent dispatches
  // ==========================================================================

  Bdd(feature)
      .scenario(
          'Async action non-reentrant does not start before an action of the same type finished.')
      .given('An ASYNC action takes some time to finish.')
      .and('The action is non-reentrant.')
      .when('The action is dispatched.')
      .and('Another action of the same type is dispatched before the previous one finished.')
      .then('It runs only once.')
      .run((_) async {
    var store = Store<State>(initialState: State(1));

    // We start with count 1.
    expect(store.state.count, 1);
    expect(store.isWaiting(NonReentrantAsyncAction), false);

    // We dispatch an action that will wait for 100 millis and increment 10.
    store.dispatch(NonReentrantAsyncAction(10, 100));
    expect(store.isWaiting(NonReentrantAsyncAction), true);

    // So far, we still have count 1.
    expect(store.state.count, 1);

    // We wait a little bit and dispatch ANOTHER action that will wait for 10 millis and increment 50.
    await Future.delayed(const Duration(milliseconds: 10));
    store.dispatch(NonReentrantAsyncAction(50, 10));
    expect(store.isWaiting(NonReentrantAsyncAction), true);

    // We wait for all actions to finish dispatching.
    await store.waitAllActions([]);
    expect(store.isWaiting(NonReentrantAsyncAction), false);

    // The only action that ran was the first one, which incremented by 10 (1+10 = 11).
    // The second action was aborted.
    expect(store.state.count, 11);
  });

  // ==========================================================================
  // Case 4: NonReentrant allows dispatch after action completes
  // ==========================================================================

  Bdd(feature)
      .scenario('NonReentrant allows dispatch after action completes.')
      .given('An ASYNC non-reentrant action has completed.')
      .when('The same action type is dispatched again.')
      .then('It should run successfully.')
      .run((_) async {
    var store = Store<State>(initialState: State(1));

    // Dispatch first action
    await store.dispatchAndWait(NonReentrantAsyncAction(10, 50));
    expect(store.state.count, 11);

    // After completion, we can dispatch again
    await store.dispatchAndWait(NonReentrantAsyncAction(5, 50));
    expect(store.state.count, 16);
  });

  // ==========================================================================
  // Case 5: NonReentrant releases key even on failure
  // ==========================================================================

  Bdd(feature)
      .scenario('NonReentrant releases key even when action fails.')
      .given('A non-reentrant action that throws an error.')
      .when('The action is dispatched and fails.')
      .then('A subsequent dispatch of the same action type should run.')
      .run((_) async {
    var store = Store<State>(initialState: State(1));

    // Dispatch action that will fail
    await store.dispatchAndWait(NonReentrantFailingAction());
    expect(store.state.count, 1); // No change due to failure

    // After failure, we can dispatch again (key was released in after())
    await store.dispatchAndWait(NonReentrantAsyncAction(10, 10));
    expect(store.state.count, 11);
  });

  // ==========================================================================
  // Case 6: Actions with nonReentrantKeyParams can run in parallel
  // ==========================================================================

  Bdd(feature)
      .scenario(
          'Actions with different nonReentrantKeyParams can run in parallel.')
      .given('A non-reentrant action that uses nonReentrantKeyParams.')
      .when('Two actions with different params are dispatched concurrently.')
      .then('Both actions should run.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));

    // Dispatch two actions with different itemIds - they should both run
    store.dispatch(NonReentrantWithParams('A', 10, 100));
    store.dispatch(NonReentrantWithParams('B', 20, 100));

    // Wait for both to complete
    await store.waitAllActions([]);

    // Both should have run: 0 + 10 + 20 = 30
    expect(store.state.count, 30);
  });

  // ==========================================================================
  // Case 7: Actions with same nonReentrantKeyParams block each other
  // ==========================================================================

  Bdd(feature)
      .scenario('Actions with same nonReentrantKeyParams block each other.')
      .given('A non-reentrant action that uses nonReentrantKeyParams.')
      .when('Two actions with the same params are dispatched concurrently.')
      .then('Only the first action should run.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));

    // Dispatch two actions with the same itemId
    store.dispatch(NonReentrantWithParams('A', 10, 100));

    // Wait a bit to ensure first action started
    await Future.delayed(const Duration(milliseconds: 10));

    // This should be aborted because 'A' is already running
    store.dispatch(NonReentrantWithParams('A', 50, 10));

    // Wait for all to complete
    await store.waitAllActions([]);

    // Only first should have run: 0 + 10 = 10
    expect(store.state.count, 10);
  });

  // ==========================================================================
  // Case 8: Different action types with same computeNonReentrantKey block each other
  // ==========================================================================

  Bdd(feature)
      .scenario(
          'Different action types with same computeNonReentrantKey block each other.')
      .given('Two different action types that share the same non-reentrant key.')
      .when('Both actions are dispatched concurrently.')
      .then('Only the first action should run.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));

    // Dispatch first action with shared key
    store.dispatch(NonReentrantSharedKey1(10, 100));

    // Wait a bit to ensure first action started
    await Future.delayed(const Duration(milliseconds: 10));

    // Dispatch second action type with same shared key - should be aborted
    store.dispatch(NonReentrantSharedKey2(50, 10));

    // Wait for all to complete
    await store.waitAllActions([]);

    // Only first should have run: 0 + 10 = 10
    expect(store.state.count, 10);
  });

  // ==========================================================================
  // Case 9: After first action completes, second action type with shared key can run
  // ==========================================================================

  Bdd(feature)
      .scenario(
          'After first action completes, second action type with shared key can run.')
      .given('Two different action types that share the same non-reentrant key.')
      .when('The first action completes.')
      .then('The second action type can run.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));

    // Dispatch and wait for first action
    await store.dispatchAndWait(NonReentrantSharedKey1(10, 50));
    expect(store.state.count, 10);

    // Now second action type with same key should run
    await store.dispatchAndWait(NonReentrantSharedKey2(20, 50));
    expect(store.state.count, 30);
  });

  // ==========================================================================
  // Case 10: Multiple concurrent dispatches with various params
  // ==========================================================================

  Bdd(feature)
      .scenario('Multiple concurrent dispatches with various params.')
      .given('Multiple non-reentrant actions with different params.')
      .when('They are dispatched concurrently.')
      .then(
          'Actions with different params run, actions with same params are blocked.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));

    // Dispatch multiple actions:
    // - Two with param 'A' (second should be blocked)
    // - Two with param 'B' (second should be blocked)
    // - One with param 'C' (should run)
    store.dispatch(NonReentrantWithParams('A', 1, 100));
    store.dispatch(NonReentrantWithParams('B', 2, 100));
    store.dispatch(NonReentrantWithParams('C', 4, 100));

    await Future.delayed(const Duration(milliseconds: 10));

    store.dispatch(NonReentrantWithParams('A', 8, 10)); // blocked
    store.dispatch(NonReentrantWithParams('B', 16, 10)); // blocked

    await store.waitAllActions([]);

    // Only A(1), B(2), C(4) should have run: 0 + 1 + 2 + 4 = 7
    expect(store.state.count, 7);
  });

  // ==========================================================================
  // Case 11: NonReentrant action key is released after error in reduce
  // ==========================================================================

  Bdd(feature)
      .scenario('NonReentrant action key is released after error in reduce.')
      .given('A non-reentrant action with params that throws.')
      .when('The action fails.')
      .then('The key is released and another action with same params can run.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));

    // Dispatch action with param 'X' that fails
    await store.dispatchAndWait(NonReentrantWithParamsFails('X'));
    expect(store.state.count, 0); // No change

    // Now dispatch another action with same param - should run
    await store.dispatchAndWait(NonReentrantWithParams('X', 10, 10));
    expect(store.state.count, 10);
  });

  // ==========================================================================
  // Case 12: Default nonReentrantKeyParams returns null
  // ==========================================================================

  Bdd(feature)
      .scenario('Default nonReentrantKeyParams returns null.')
      .given('A non-reentrant action without overriding nonReentrantKeyParams.')
      .when('The action is dispatched twice concurrently.')
      .then('The second dispatch is blocked based on runtimeType.')
      .run((_) async {
    var store = Store<State>(initialState: State(1));

    // These use default key (runtimeType, null)
    store.dispatch(NonReentrantAsyncAction(10, 100));

    await Future.delayed(const Duration(milliseconds: 10));

    store.dispatch(NonReentrantAsyncAction(50, 10)); // Should be blocked

    await store.waitAllActions([]);

    // Only first ran: 1 + 10 = 11
    expect(store.state.count, 11);
  });
}

// =============================================================================
// Test state and actions
// =============================================================================

class State {
  final int count;

  State(this.count);

  @override
  String toString() => 'State($count)';
}

class NonReentrantSyncActionCallsItself extends ReduxAction<State>
    with NonReentrant {
  @override
  State reduce() {
    dispatch(NonReentrantSyncActionCallsItself());
    return State(state.count + 1);
  }
}

class NonReentrantAsyncActionCallsItself extends ReduxAction<State>
    with NonReentrant {
  @override
  Future<State> reduce() async {
    dispatch(NonReentrantSyncActionCallsItself());
    return State(state.count + 1);
  }
}

class NonReentrantAsyncAction extends ReduxAction<State> with NonReentrant {
  final int increment;
  final int delayMillis;

  NonReentrantAsyncAction(this.increment, this.delayMillis);

  @override
  Future<State> reduce() async {
    await Future.delayed(Duration(milliseconds: delayMillis));
    return State(state.count + increment);
  }
}

/// Action that always fails - used to test that key is released on error.
class NonReentrantFailingAction extends ReduxAction<State> with NonReentrant {
  @override
  Future<State> reduce() async {
    await Future.delayed(const Duration(milliseconds: 10));
    throw const UserException('Intentional failure');
  }
}

/// Action that uses nonReentrantKeyParams to differentiate by itemId.
class NonReentrantWithParams extends ReduxAction<State> with NonReentrant {
  final String itemId;
  final int increment;
  final int delayMillis;

  NonReentrantWithParams(this.itemId, this.increment, this.delayMillis);

  @override
  Object? nonReentrantKeyParams() => itemId;

  @override
  Future<State> reduce() async {
    await Future.delayed(Duration(milliseconds: delayMillis));
    return State(state.count + increment);
  }
}

/// Action that uses nonReentrantKeyParams and always fails.
class NonReentrantWithParamsFails extends ReduxAction<State> with NonReentrant {
  final String itemId;

  NonReentrantWithParamsFails(this.itemId);

  @override
  Object? nonReentrantKeyParams() => itemId;

  @override
  Future<State> reduce() async {
    await Future.delayed(const Duration(milliseconds: 10));
    throw const UserException('Intentional failure');
  }
}

/// First action type that uses a shared non-reentrant key via computeNonReentrantKey.
class NonReentrantSharedKey1 extends ReduxAction<State> with NonReentrant {
  final int increment;
  final int delayMillis;

  NonReentrantSharedKey1(this.increment, this.delayMillis);

  @override
  Object computeNonReentrantKey() => 'sharedKey';

  @override
  Future<State> reduce() async {
    await Future.delayed(Duration(milliseconds: delayMillis));
    return State(state.count + increment);
  }
}

/// Second action type that uses the same shared non-reentrant key.
class NonReentrantSharedKey2 extends ReduxAction<State> with NonReentrant {
  final int increment;
  final int delayMillis;

  NonReentrantSharedKey2(this.increment, this.delayMillis);

  @override
  Object computeNonReentrantKey() => 'sharedKey';

  @override
  Future<State> reduce() async {
    await Future.delayed(Duration(milliseconds: delayMillis));
    return State(state.count + increment);
  }
}
