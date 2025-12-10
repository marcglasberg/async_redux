import 'package:async_redux/async_redux.dart';
import 'package:bdd_framework/bdd_framework.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var feature = BddFeature('Fresh mixin');

  // ==========================================================================
  // Case 1: Initial no key, ignoreFresh == false, success
  // ==========================================================================

  Bdd(feature)
      .scenario('Action succeeds when no fresh key exists')
      .given('No fresh key exists for the action')
      .when('The action is dispatched')
      .then('It should execute and create a fresh key')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));

    // First dispatch - should run since no key exists
    await store.dispatch(
      FreshAction(
        shouldFail: false,
        ignoreFresh: false,
      ),
    );
    expect(store.state.count, 1);

    // Dispatch again immediately - should abort (key is fresh)
    await store.dispatch(
      FreshAction(
        shouldFail: false,
        ignoreFresh: false,
      ),
    );
    expect(store.state.count, 1);
  });

  // ==========================================================================
  // Case 2: Initial no key, ignoreFresh == false, error
  // ==========================================================================

  Bdd(feature)
      .scenario('Action fails when no fresh key exists - key should be removed')
      .given('No fresh key exists for the action')
      .when('The action is dispatched and fails')
      .then('It should execute, then remove the fresh key on error')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));

    // First dispatch - should run and fail, key should be removed
    await store.dispatchAndWait(
      FreshAction(
        shouldFail: true, // True!
        ignoreFresh: false,
      ),
    );

    // The action failed, so the state should not have changed
    expect(store.state.count, 0);

    // Dispatch again - should run because the key was removed after error
    // This time it succeeds, proving it actually ran
    await store.dispatch(
      FreshAction(
        shouldFail: false, // False!
        ignoreFresh: false,
      ),
    );
    expect(store.state.count, 1); // Proves the second dispatch ran
  });

  // ==========================================================================
  // Case 3: Initial stale key, ignoreFresh == false, success
  // ==========================================================================

  Bdd(feature)
      .scenario('Action succeeds when a stale key exists')
      .given('A stale fresh key exists for the action')
      .when('The action is dispatched')
      .then('It should execute and update the fresh key')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));

    // First dispatch with short freshFor
    await store.dispatch(
      FreshAction(
        shouldFail: false,
        ignoreFresh: false,
      ),
    );
    expect(store.state.count, 1);

    // Wait for the fresh period to expire (150ms freshFor + buffer)
    await Future.delayed(const Duration(milliseconds: 200));

    // Now the key is stale, so it should run again
    await store.dispatch(
      FreshAction(
        shouldFail: false,
        ignoreFresh: false,
      ),
    );
    expect(store.state.count, 2);
  });

  // ==========================================================================
  // Case 4: Initial stale key, ignoreFresh == false, error
  // ==========================================================================

  Bdd(feature)
      .scenario('Action fails when a stale key exists - restores stale state')
      .given('A stale fresh key exists for the action')
      .when('The action is dispatched and fails')
      .then('It should restore the old stale expiry')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));

    // Create a stale key by dispatching and waiting
    await store.dispatch(FreshAction(
      shouldFail: false,
      ignoreFresh: false,
    ));
    expect(store.state.count, 1);

    // Wait for the key to become stale
    await Future.delayed(const Duration(milliseconds: 200));

    // Now dispatch with failure - it should run (stale), fail, and restore stale state
    await store.dispatchAndWait(FreshAction(
      shouldFail: true, // Fail!
      ignoreFresh: false,
    ));
    expect(store.state.count, 1); // No change due to failure

    // The key should still be stale, so we can dispatch again
    await store.dispatch(
      FreshAction(
        shouldFail: false,
        ignoreFresh: false,
      ),
    );
    expect(store.state.count, 2);
  });

  // ==========================================================================
  // Case 5: Initial fresh key, ignoreFresh == false
  // ==========================================================================

  Bdd(feature)
      .scenario('Action aborts when fresh key exists')
      .given('A fresh key exists for the action')
      .when('The action is dispatched again')
      .then('It should abort without executing')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));

    // First dispatch - should run
    await store.dispatch(
      FreshAction(
        shouldFail: false,
        ignoreFresh: false,
      ),
    );
    expect(store.state.count, 1);

    // Dispatch again immediately - should abort (key is still fresh)
    await store.dispatch(
      FreshAction(
        shouldFail: false,
        ignoreFresh: false,
      ),
    );
    expect(store.state.count, 1);

    // Wait for fresh period to expire
    await Future.delayed(
      const Duration(milliseconds: 200),
    );

    // Now it should run again
    await store.dispatch(
      FreshAction(
        shouldFail: false,
        ignoreFresh: false,
      ),
    );
    expect(store.state.count, 2);
  });

  // ==========================================================================
  // Case 6: ignoreFresh == true, success
  // ==========================================================================

  Bdd(feature)
      .scenario(
          'Action with ignoreFresh=true always runs and stays fresh on success')
      .given('An action with ignoreFresh set to true')
      .when('The action is dispatched even when fresh')
      .then('It should execute and create a new fresh period')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));

    // First dispatch with ignoreFresh - should run
    await store.dispatch(
      FreshAction(
        shouldFail: false,
        ignoreFresh: true,
      ),
    );
    expect(store.state.count, 1);

    // Dispatch again immediately with ignoreFresh - should run again
    await store.dispatch(
      FreshAction(
        shouldFail: false,
        ignoreFresh: true,
      ),
    );
    expect(store.state.count, 2);

    // After success, the key should be fresh
    // So a normal action (without ignoreFresh) should be aborted
    await store.dispatch(
      FreshAction(
        shouldFail: false,
        ignoreFresh: false,
      ),
    );
    expect(store.state.count, 2); // Aborted

    // Dispatch again immediately with ignoreFresh - should run again
    await store.dispatch(
      FreshAction(
        shouldFail: false,
        ignoreFresh: true,
      ),
    );
    expect(store.state.count, 3);
  });

  // ==========================================================================
  // Case 7: ignoreFresh == true, error
  // ==========================================================================

  Bdd(feature)
      .scenario('Action with ignoreFresh=true runs but removes key on error')
      .given('An action with ignoreFresh set to true')
      .when('The action is dispatched and fails')
      .then('It should execute and remove the key on error')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));

    // Dispatch with ignoreFresh and failure - should run and then remove key
    await store.dispatchAndWait(
      FreshAction(
        shouldFail: true, // Fail!
        ignoreFresh: true, // True!
      ),
    );

    expect(store.state.count, 0); // No change due to failure

    // The key should be removed, so a normal action should run.
    await store.dispatch(
      FreshAction(
        shouldFail: false,
        ignoreFresh: false,
      ),
    );
    expect(store.state.count, 1);
  });

  // ==========================================================================
  // Case 8: removeKey in reduce or before
  // ==========================================================================

  Bdd(feature)
      .scenario('Action calls removeKey - no rollback on error')
      .given('An action that calls removeKey in reduce')
      .when('The action fails')
      .then('The key should remain removed (no rollback)')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));

    // Dispatch action that removes key and fails
    await store.dispatchAndWait(
      FreshAction(
        shouldRemoveKey: true, // Remove key!
        shouldFail: true, // Fail!
        ignoreFresh: false,
      ),
    );

    expect(store.state.count, 0);

    // The key was manually removed, so it should run again
    await store.dispatch(
      FreshAction(
        shouldFail: false,
        shouldRemoveKey: false,
        ignoreFresh: false,
      ),
    );
    expect(store.state.count, 1);
  });

  // ==========================================================================
  // Case 9: removeKey in reduce or before
  // ==========================================================================

  Bdd(feature)
      .scenario('Action calls removeKey - allows immediate re-dispatch')
      .given('An action that calls removeKey in reduce')
      .when('The action succeeds')
      .then('The key should be removed and action can run again')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));

    // Dispatch action that removes its own key
    await store.dispatch(
      FreshAction(
        shouldRemoveKey: true, // Remove key!
        shouldFail: false,
        ignoreFresh: false,
      ),
    );
    expect(store.state.count, 1);

    // The key was removed, so it should run again immediately
    await store.dispatch(
      FreshAction(
        shouldFail: false,
        shouldRemoveKey: false,
        ignoreFresh: false,
      ),
    );
    expect(store.state.count, 2);
  });

  // ==========================================================================
  // Case 10: removeAllKeys in reduce or before
  // ==========================================================================

  Bdd(feature)
      .scenario('Action calls removeAllKeys - clears all fresh keys')
      .given('An action that calls removeAllKeys in reduce')
      .when('The action is dispatched')
      .then('All fresh keys should be removed')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));

    // Create fresh keys for different actions
    await store.dispatch(
      FreshAction(
        shouldFail: false,
        ignoreFresh: false,
      ),
    );
    await store.dispatch(FreshAction2());
    expect(store.state.count, 2);

    // Both should be fresh, so re-dispatch should abort
    await store.dispatch(
      FreshAction(
        shouldFail: false,
        ignoreFresh: false,
      ),
    );
    await store.dispatch(FreshAction2());
    expect(store.state.count, 2);

    // Now dispatch an action that removes all keys
    // Use ignoreFresh so it runs even though the key is fresh
    await store.dispatch(
      FreshAction(
        shouldRemoveAllKeys: true, // Remove all keys!
        shouldFail: false,
        ignoreFresh: true, // Force run even if fresh!
      ),
    );
    expect(store.state.count, 3);

    // Now both actions should run again (keys removed)
    await store.dispatch(
      FreshAction(
        shouldFail: false,
        ignoreFresh: false,
      ),
    );
    await store.dispatch(FreshAction2());
    expect(store.state.count, 5);
  });

  // ==========================================================================
  // Case 11: Two actions A then B, same key, B dispatched while K is fresh from A
  // ==========================================================================

  Bdd(feature)
      .scenario('Two actions with same key - second aborts when first is fresh')
      .given('Two actions that share the same fresh key')
      .when('Both are dispatched while the key is fresh')
      .then('Only the first action should execute')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));

    // Dispatch first action with shared key
    await store.dispatch(FreshActionSharedKey1());
    expect(store.state.count, 1);

    // Dispatch second action with same key - should abort
    await store.dispatch(FreshActionSharedKey2());
    expect(store.state.count, 1);

    // Wait for fresh period to expire
    await Future.delayed(const Duration(milliseconds: 1100));

    // Now second action should run
    await store.dispatch(FreshActionSharedKey2());
    expect(store.state.count, 2);
  });

  // ========================================================================
  // Case 12: Two actions A then B, same key, B dispatched after expiry
  // ========================================================================

  Bdd(feature)
      .scenario(
          'Two actions A then B - B failure does not block future shared-key runs')
      .given('Action A runs successfully, then B runs and fails for same key')
      .when('The shared key was already stale when B ran')
      .then(
          'B\'s failure should not stop another shared-key action from running')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));

    // Action A runs successfully and sets the shared key as fresh.
    await store.dispatch(FreshActionSharedKey1());
    expect(store.state.count, 1);

    // Wait for the shared key to become stale (freshFor == 1000ms).
    await Future.delayed(const Duration(milliseconds: 1100));

    // Action B runs and fails. This should not change the state.
    await store.dispatchAndWait(FreshActionSharedKey2Fails());

    expect(store.state.count, 1);

    // After B's failure, the shared key should be stale again.
    // So another shared-key action should run and change the state.
    await store.dispatch(FreshActionSharedKey1());
    expect(store.state.count, 2);
  });

  // ==========================================================================
  // Case 13: Tests different runtime types
  // ==========================================================================

  Bdd(feature)
      .scenario(
          'Actions with different runtime types have independent freshness')
      .given('Two actions with Fresh mixin but different runtime types')
      .when('Both actions are dispatched in quick succession')
      .then('Both should execute independently')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));

    await store.dispatch(
      FreshAction(
        shouldFail: false,
        ignoreFresh: false,
      ),
    );
    expect(store.state.count, 1);

    await store.dispatch(FreshAction2());
    expect(store.state.count, 2);

    // Both should be fresh now
    await store.dispatch(
      FreshAction(
        shouldFail: false,
        ignoreFresh: false,
      ),
    );
    expect(store.state.count, 2); // Aborted

    await store.dispatch(FreshAction2());
    expect(store.state.count, 2); // Aborted
  });

  // ==========================================================================
  // Case 14: Test freshKeyParams
  // ==========================================================================

  Bdd(feature)
      .scenario('Actions with freshKeyParams differentiate by parameters')
      .given('Actions that use freshKeyParams to differentiate instances')
      .when('Actions with different params are dispatched')
      .then('They should have independent freshness')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));

    // Dispatch with param "A"
    await store.dispatch(
      FreshActionWithParams('A'),
    );
    expect(store.state.count, 1);

    // Dispatch with param "B" - different key, should run
    await store.dispatch(
      FreshActionWithParams('B'),
    );
    expect(store.state.count, 2);

    // Dispatch with param "A" again - same key, should abort
    await store.dispatch(
      FreshActionWithParams('A'),
    );
    expect(store.state.count, 2);

    // Dispatch with param "B" again - same key, should abort
    await store.dispatch(
      FreshActionWithParams('B'),
    );
    expect(store.state.count, 2);
  });

  // ==========================================================================
  // Case 15: Test freshKeyParams
  // ==========================================================================

  Bdd(feature)
      .scenario('Actions with freshKeyParams share freshness for same params')
      .given('Actions with the same freshKeyParams value')
      .when('Dispatched in quick succession')
      .then('The second should abort')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));

    // Dispatch with param "X"
    await store.dispatch(
      FreshActionWithParams('X'),
    );
    expect(store.state.count, 1);

    // Dispatch with same param "X" - should abort
    await store.dispatch(
      FreshActionWithParams('X'),
    );
    expect(store.state.count, 1);
  });

  // ==========================================================================
  // Case 16: Concurrency protection: A fails, B succeeds, no previous key
  // ==========================================================================

  Bdd(feature)
      .scenario(
          'Concurrency: A fails after B succeeds - B\'s freshness is preserved')
      .given('Action A dispatched first but takes time to complete')
      .and('Action B dispatched after A\'s freshness expires, succeeds quickly')
      .when('A finishes and fails after B has already succeeded')
      .then('A\'s failure should NOT remove the fresh key set by B')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));

    // Dispatch action A that:
    // - Uses a shared key
    // - Has a short freshFor (100ms) so it expires quickly
    // - Takes a long time to execute (300ms delay)
    // - Fails at the end
    // Don't await - let it run in background
    store.dispatch(
      FreshActionConcurrentSlow(
        shouldFail: true,
        delayMillis: 300,
        freshForMillis: 100,
      ),
    );

    // Wait for A's freshness to expire (100ms + buffer)
    await Future.delayed(const Duration(milliseconds: 150));

    // At this point:
    // - A is still running (only 150ms passed, A needs 300ms)
    // - A's freshness has expired (100ms freshFor)
    // - Map[K] = expiryA (stale)

    // Dispatch action B that:
    // - Uses the same shared key
    // - Executes quickly
    // - Succeeds
    await store.dispatch(
      FreshActionConcurrentFast(
        shouldFail: false,
      ),
    );

    // B has succeeded and set Map[K] = expiryB (fresh)
    // Count should be 1 from B's success (A hasn't finished yet)
    expect(store.state.count, 1);

    // Wait for A to finish (it takes 300ms total, we've waited 150ms + dispatch time)
    // So wait another 200ms to be safe
    await Future.delayed(const Duration(milliseconds: 200));

    // A has now failed
    // The critical assertion: A's failure should NOT have removed the key
    // Because A's after() sees current = expiryB != _newExpiryA
    // So the rollback is skipped

    // Dispatch another action with the same key
    // If B's freshness is preserved, this should abort
    await store.dispatch(
      FreshActionConcurrentFast(
        shouldFail: false,
      ),
    );

    // Count should still be 1 (second dispatch was aborted because key is fresh from B)
    expect(store.state.count, 1);

    // Wait for B's freshness to expire
    await Future.delayed(const Duration(milliseconds: 1100));

    // Now the key should be stale, so dispatch should succeed
    await store.dispatch(
      FreshActionConcurrentFast(
        shouldFail: false,
      ),
    );
    expect(store.state.count, 2);
  });

  // ==========================================================================
  // Case 17: Concurrency protection: Previous stale expiry exists, A fails, B succeeds
  // ==========================================================================

  Bdd(feature)
      .scenario(
          'Concurrency: Previous stale expiry, A fails after B succeeds - B\'s freshness is preserved')
      .given('An initial action creates a stale expiry for the key')
      .and('A slow failing action A starts and updates the expiry')
      .and('A fast succeeding action B runs after A\'s freshness expires')
      .when('A later fails after B has already succeeded')
      .then(
          'A\'s failure should NOT restore the old stale expiry or remove B\'s freshness')
      .run((_) async {
    final store = Store<AppState>(initialState: AppState(0));

    // Step 1: Initial action C writes the first expiry and succeeds.
    // This gives us a "previous expiry" (_current != null for the next action).
    await store.dispatch(
      FreshActionConcurrentSlow(
        shouldFail: false,
        delayMillis: 0,
        freshForMillis: 100, // short fresh period
      ),
    );
    // C succeeded once
    expect(store.state.count, 1);

    // Wait for C's freshness to expire so its expiry is stale but still in the map.
    await Future.delayed(const Duration(milliseconds: 150));

    // Step 2: Dispatch A (slow, failing) with the same key and same freshFor.
    // At this point:
    // - Map['concurrentKey'] = prevExpiry (from C), which is stale.
    // - A.abortDispatch sees _current != null and writes a new expiryA.
    store.dispatch(
      FreshActionConcurrentSlow(
        shouldFail: true,
        delayMillis: 300, // long running, will fail later
        freshForMillis: 100,
      ),
    );

    // Wait long enough for A's fresh window (100ms) to expire,
    // but not long enough for A to finish (300ms total).
    await Future.delayed(const Duration(milliseconds: 150));

    // Step 3: Dispatch B (fast, succeeding) with the same key.
    // Now:
    // - Map['concurrentKey'] = expiryA (from A), which is stale at this point.
    // - B.abortDispatch sees stale expiry and writes expiryB.
    await store.dispatch(
      FreshActionConcurrentFast(
        shouldFail: false,
      ),
    );

    // C and B have succeeded, A is still running and will fail later.
    // Count: 1 (C) + 1 (B) = 2.
    expect(store.state.count, 2);

    // Step 4: Wait for A to finish and fail.
    await Future.delayed(const Duration(milliseconds: 200));

    // At this time:
    // - Map['concurrentKey'] == expiryB (written by B).
    // - A.after sees status.originalError != null,
    //   current = expiryB, _newExpiryA = expiryA, _currentA = prevExpiry.
    // - Since current != _newExpiryA, rollback is skipped.
    //   So A must NOT restore prevExpiry or remove the key.

    // Step 5: Dispatch B again while its freshFor (1000ms) has not expired.
    // If B's freshness is preserved, this dispatch should abort
    // and the reducer should NOT run.
    await store.dispatch(
      FreshActionConcurrentFast(
        shouldFail: false,
      ),
    );
    expect(store.state.count, 2);

    // Optional: Wait for B's freshness to expire and confirm that the key
    // becomes stale and a new dispatch can run.
    await Future.delayed(const Duration(milliseconds: 1100));

    await store.dispatch(
      FreshActionConcurrentFast(
        shouldFail: false,
      ),
    );
    expect(store.state.count, 3);
  });

  // ==========================================================================
  // Case 18: Concurrency + ignoreFresh: A fails after B succeeds - B's freshness preserved
  // ==========================================================================

  Bdd(feature)
      .scenario(
          'Concurrency with ignoreFresh: A fails after B succeeds - B\'s freshness is preserved')
      .given(
          'A slow action A with ignoreFresh=true starts and reserves freshness')
      .and('After A\'s freshFor expires, a fast action B runs and succeeds')
      .when('A later fails after B has already succeeded')
      .then('A\'s failure should NOT remove or revert B\'s freshness')
      .run((_) async {
    final store = Store<AppState>(initialState: AppState(0));

    // Step 1: Dispatch A (slow, failing, ignoreFresh=true).
    //
    // A characteristics:
    // - freshFor = 100ms
    // - ignoreFresh = true
    // - delay = 300ms, then fails
    //
    // At A.abortDispatch (t0):
    // - Map['concurrentKey'] is probably null (no previous key)
    // - ignoreFresh branch:
    //     Map['concurrentKey'] = expiryA = t0 + 100ms
    //     _newExpiryA = expiryA
    //     _currentA = null
    //
    // Do NOT await: let A run in background.
    store.dispatch(
      FreshActionConcurrentSlowIgnoreFresh(
        shouldFail: true,
        delayMillis: 300,
        freshForMillis: 100,
      ),
    );

    // Step 2: Wait until A's fresh window expires, but A is still running.
    //
    // After 150ms:
    // - expiryA (t0 + 100ms) is in the past => stale
    // - A is still running (needs 300ms)
    await Future.delayed(const Duration(milliseconds: 150));

    // Step 3: Dispatch B (fast, succeeds) with the same key.
    //
    // At B.abortDispatch (t1 ~ t0 + 150ms):
    // - Map['concurrentKey'] = expiryA (stale)
    // - B sees stale, writes:
    //     expiryB = t1 + 1000ms
    //     Map['concurrentKey'] = expiryB
    //     _newExpiryB = expiryB
    //
    // Then B.reduce succeeds and increments count.
    await store.dispatch(
      FreshActionConcurrentFast(
        shouldFail: false,
      ),
    );

    // So far:
    // - Only B has succeeded => count = 1
    // - Map['concurrentKey'] = expiryB (fresh)
    expect(store.state.count, 1);

    // Step 4: Wait for A to finish and fail.
    //
    // After another 200ms:
    // - Total since A started ~350ms > 300ms => A finishes and fails.
    //
    // In A.after:
    // - status.originalError != null
    // - current = Map['concurrentKey'] = expiryB
    // - _newExpiryA = expiryA
    // - current != _newExpiryA => rollback block is SKIPPED
    //   So A does NOT remove the key (even though _currentA == null).
    await Future.delayed(const Duration(milliseconds: 200));

    // Step 5: Dispatch B again while expiryB is still in the future.
    //
    // If B's freshness was preserved, this dispatch must abort
    // (abortDispatch returns true) and NOT increment the counter.
    await store.dispatch(
      FreshActionConcurrentFast(
        shouldFail: false,
      ),
    );

    // Still only one successful run from B.
    expect(store.state.count, 1);

    // Optional: Wait for B's freshness to expire, then B should run again.
    await Future.delayed(const Duration(milliseconds: 1100));

    await store.dispatch(
      FreshActionConcurrentFast(
        shouldFail: false,
      ),
    );
    expect(store.state.count, 2);
  });

  // ==========================================================================
  // Case 19: Scenario 4: Nested override between abort and after, failing outer action
  // ==========================================================================

  Bdd(feature)
      .scenario(
          'Nested override: failing outer action must not revert newer freshness')
      .given('OuterActionNested reserves freshness for a key')
      .and('OverrideAction runs inside its reduce and sets a newer freshness')
      .when('OuterActionNested later fails and after() runs')
      .then('The newer freshness from OverrideAction must be preserved')
      .run((_) async {
    final store = Store<AppState>(initialState: AppState(0));

    // Step 1: Dispatch the outer action that will:
    // - In abortDispatch: reserve expiryA for "nestedKey".
    // - In reduce: dispatch OverrideAction, which:
    //     * runs (ignoreFresh = true),
    //     * sets a newer expiryB for "nestedKey",
    //     * increments count to 1.
    // - Then OuterActionNested throws.
    try {
      await store.dispatch(OuterActionNested());
      fail('Expected OuterActionNested to throw');
    } catch (_) {
      // Expected failure from OuterActionNested.
    }

    // At this point:
    // - OverrideAction has succeeded exactly once => count should be 1.
    expect(store.state.count, 1);

    // In after() of OuterActionNested:
    // - status.originalError != null
    // - current = Map['nestedKey'] is the expiry set by OverrideAction
    // - _newExpiry (from OuterActionNested) is the earlier expiryA
    // - current != _newExpiry => rollback is skipped
    //
    // So the key must still be fresh according to OverrideAction.

    // Step 2: Dispatch CheckAction with the same key.
    //
    // If the newer freshness from OverrideAction is preserved:
    // - abortDispatch of CheckAction sees a fresh key and returns true
    // - reduce() is NOT called and count stays 1.
    //
    // If OuterActionNested had reverted or removed the key on error:
    // - the key would be stale
    // - CheckAction would run and increment count to 2.
    await store.dispatch(CheckAction());

    // Assert that CheckAction was aborted (did not increment the count).
    expect(store.state.count, 1);
  });

  // ---------------------------------------------------------------------------

  // ==========================================================================
  // Case 20: Fresh mixin cannot be combined with Throttle
  // ==========================================================================

  Bdd(feature)
      .scenario('Fresh mixin cannot be combined with Throttle')
      .given('An action that combines Fresh and Throttle mixins')
      .when('The action is dispatched')
      .then('It should throw an AssertionError')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));

    expect(
      () => store.dispatch(FreshWithThrottleAction()),
      throwsA(isA<AssertionError>().having(
        (e) => e.message,
        'message',
        'The Fresh mixin cannot be combined with the Throttle mixin.',
      )),
    );
  });

  // ==========================================================================
  // Case 21: Fresh mixin cannot be combined with NonReentrant
  // ==========================================================================

  Bdd(feature)
      .scenario('Fresh mixin cannot be combined with NonReentrant')
      .given('An action that combines Fresh and NonReentrant mixins')
      .when('The action is dispatched')
      .then('It should throw an AssertionError')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));

    expect(
      () => store.dispatch(FreshWithNonReentrantAction()),
      throwsA(isA<AssertionError>().having(
        (e) => e.message,
        'message',
        'The Fresh mixin cannot be combined with the NonReentrant mixin.',
      )),
    );
  });

  // ==========================================================================
  // Case 22: Fresh mixin cannot be combined with UnlimitedRetryCheckInternet
  // ==========================================================================

  Bdd(feature)
      .scenario(
          'Fresh mixin cannot be combined with UnlimitedRetryCheckInternet')
      .given(
          'An action that combines Fresh and UnlimitedRetryCheckInternet mixins')
      .when('The action is dispatched')
      .then('It should throw an AssertionError')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));

    expect(
      () => store.dispatch(FreshWithUnlimitedRetryAction()),
      throwsA(isA<AssertionError>().having(
        (e) => e.message,
        'message',
        'The Fresh mixin cannot be combined with the UnlimitedRetryCheckInternet mixin.',
      )),
    );
  });

  // ==========================================================================
  // Case 23: Throttle mixin cannot be combined with NonReentrant
  // ==========================================================================

  Bdd(feature)
      .scenario('Throttle mixin cannot be combined with NonReentrant')
      .given('An action that combines Throttle and NonReentrant mixins')
      .when('The action is dispatched')
      .then('It should throw an AssertionError')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));

    // NonReentrant.abortDispatch() runs and detects Throttle
    expect(
      () => store.dispatch(ThrottleWithNonReentrantAction()),
      throwsA(isA<AssertionError>().having(
        (e) => e.message,
        'message',
        'The NonReentrant mixin cannot be combined with the Throttle mixin.',
      )),
    );
  });

  // ==========================================================================
  // Case 24: Throttle mixin cannot be combined with UnlimitedRetryCheckInternet
  // ==========================================================================

  Bdd(feature)
      .scenario(
          'Throttle mixin cannot be combined with UnlimitedRetryCheckInternet')
      .given(
          'An action that combines Throttle and UnlimitedRetryCheckInternet mixins')
      .when('The action is dispatched')
      .then('It should throw an AssertionError')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));

    // UnlimitedRetryCheckInternet.abortDispatch() runs and detects Throttle
    expect(
      () => store.dispatch(ThrottleWithUnlimitedRetryAction()),
      throwsA(isA<AssertionError>().having(
        (e) => e.message,
        'message',
        'The UnlimitedRetryCheckInternet mixin cannot be combined with the Throttle mixin.',
      )),
    );
  });

  // ==========================================================================
  // Case 25: NonReentrant mixin cannot be combined with UnlimitedRetryCheckInternet
  // ==========================================================================

  Bdd(feature)
      .scenario(
          'NonReentrant mixin cannot be combined with UnlimitedRetryCheckInternet')
      .given(
          'An action that combines NonReentrant and UnlimitedRetryCheckInternet mixins')
      .when('The action is dispatched')
      .then('It should throw an AssertionError')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));

    // UnlimitedRetryCheckInternet.abortDispatch() runs and detects NonReentrant
    expect(
      () => store.dispatch(NonReentrantWithUnlimitedRetryAction()),
      throwsA(isA<AssertionError>().having(
        (e) => e.message,
        'message',
        'The UnlimitedRetryCheckInternet mixin cannot be combined with the NonReentrant mixin.',
      )),
    );
  });

  // ==========================================================================
  // Case 26: CheckInternet mixin cannot be combined with AbortWhenNoInternet
  // ==========================================================================

  Bdd(feature)
      .scenario(
          'CheckInternet mixin cannot be combined with AbortWhenNoInternet')
      .given(
          'An action that combines CheckInternet and AbortWhenNoInternet mixins')
      .when('The action is dispatched')
      .then('It should throw an AssertionError')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));

    // AbortWhenNoInternet.before() runs and detects CheckInternet
    expect(
      () => store.dispatch(CheckInternetWithAbortWhenNoInternetAction()),
      throwsA(isA<AssertionError>().having(
        (e) => e.message,
        'message',
        'The AbortWhenNoInternet mixin cannot be combined with the CheckInternet mixin.',
      )),
    );
  });

  // ==========================================================================
  // Case 27: CheckInternet mixin cannot be combined with UnlimitedRetryCheckInternet
  // ==========================================================================

  Bdd(feature)
      .scenario(
          'CheckInternet mixin cannot be combined with UnlimitedRetryCheckInternet')
      .given(
          'An action that combines CheckInternet and UnlimitedRetryCheckInternet mixins')
      .when('The action is dispatched')
      .then('It should throw an AssertionError')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));

    // UnlimitedRetryCheckInternet.abortDispatch() runs first and detects CheckInternet
    expect(
      () => store.dispatch(CheckInternetWithUnlimitedRetryAction()),
      throwsA(isA<AssertionError>().having(
        (e) => e.message,
        'message',
        'The UnlimitedRetryCheckInternet mixin cannot be combined with the CheckInternet mixin.',
      )),
    );
  });

  // ==========================================================================
  // Case 28: AbortWhenNoInternet mixin cannot be combined with UnlimitedRetryCheckInternet
  // ==========================================================================

  Bdd(feature)
      .scenario(
          'AbortWhenNoInternet mixin cannot be combined with UnlimitedRetryCheckInternet')
      .given(
          'An action that combines AbortWhenNoInternet and UnlimitedRetryCheckInternet mixins')
      .when('The action is dispatched')
      .then('It should throw an AssertionError')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));

    // UnlimitedRetryCheckInternet.abortDispatch() runs first and detects AbortWhenNoInternet
    expect(
      () => store.dispatch(AbortWhenNoInternetWithUnlimitedRetryAction()),
      throwsA(isA<AssertionError>().having(
        (e) => e.message,
        'message',
        'The UnlimitedRetryCheckInternet mixin cannot be combined with the AbortWhenNoInternet mixin.',
      )),
    );
  });

  // ---------------------------------------------------------------------------
}

// =============================================================================
// Test state and actions
// =============================================================================

class AppState {
  final int count;

  AppState(this.count);

  AppState copy({int? count}) => AppState(count ?? this.count);

  @override
  String toString() => 'AppState($count)';
}

// Action with ignoreFresh
class FreshAction extends ReduxAction<AppState> with Fresh {
  final bool shouldFail;
  final bool shouldRemoveKey;
  final bool shouldRemoveAllKeys;
  final bool _ignoreFresh;
  final int _freshFor;

  FreshAction({
    required this.shouldFail,
    required bool ignoreFresh,
    this.shouldRemoveKey = false,
    this.shouldRemoveAllKeys = false,
    int freshFor = 150,
  })  : _ignoreFresh = ignoreFresh,
        _freshFor = freshFor;

  @override
  int get freshFor => _freshFor;

  @override
  bool get ignoreFresh => _ignoreFresh;

  @override
  AppState reduce() {
    if (shouldFail) {
      throw const UserException('Intentional failure');
    }
    if (shouldRemoveKey) {
      removeKey();
    }
    if (shouldRemoveAllKeys) {
      removeAllKeys();
    }
    return state.copy(count: state.count + 1);
  }
}

// Second action type for testing different runtime types
class FreshAction2 extends ReduxAction<AppState> with Fresh {
  @override
  int get freshFor => 1000;

  @override
  AppState reduce() {
    return state.copy(count: state.count + 1);
  }
}

// Actions with shared key
class FreshActionSharedKey1 extends ReduxAction<AppState> with Fresh {
  @override
  int get freshFor => 1000;

  @override
  Object computeFreshKey() => 'sharedKey';

  @override
  AppState reduce() {
    return state.copy(count: state.count + 1);
  }
}

class FreshActionSharedKey2 extends ReduxAction<AppState> with Fresh {
  @override
  int get freshFor => 1000;

  @override
  Object computeFreshKey() => 'sharedKey';

  @override
  AppState reduce() {
    return state.copy(count: state.count + 1);
  }
}

class FreshActionSharedKey2Fails extends ReduxAction<AppState> with Fresh {
  @override
  int get freshFor => 1000;

  @override
  Object computeFreshKey() => 'sharedKey';

  @override
  AppState reduce() {
    throw const UserException('Intentional failure');
  }
}

// Action with freshKeyParams
class FreshActionWithParams extends ReduxAction<AppState> with Fresh {
  final String param;

  FreshActionWithParams(this.param);

  @override
  int get freshFor => 1000;

  @override
  Object? freshKeyParams() => param;

  @override
  AppState reduce() {
    return state.copy(count: state.count + 1);
  }
}

// Actions for concurrency test - slow action that takes time to complete
class FreshActionConcurrentSlow extends ReduxAction<AppState> with Fresh {
  final bool shouldFail;
  final int delayMillis;
  final int freshForMillis;

  FreshActionConcurrentSlow({
    required this.shouldFail,
    required this.delayMillis,
    required this.freshForMillis,
  });

  @override
  int get freshFor => freshForMillis;

  @override
  Object computeFreshKey() => 'concurrentKey';

  @override
  Future<AppState> reduce() async {
    // Simulate long-running operation
    await Future.delayed(Duration(milliseconds: delayMillis));

    if (shouldFail) {
      throw const UserException('Intentional failure from slow action');
    }
    return state.copy(count: state.count + 1);
  }
}

// Fast action for concurrency test
class FreshActionConcurrentFast extends ReduxAction<AppState> with Fresh {
  final bool shouldFail;

  FreshActionConcurrentFast({required this.shouldFail});

  @override
  int get freshFor => 1000;

  @override
  Object computeFreshKey() => 'concurrentKey';

  @override
  AppState reduce() {
    if (shouldFail) {
      throw const UserException('Intentional failure from fast action');
    }
    return state.copy(count: state.count + 1);
  }
}

// Slow action with ignoreFresh=true for concurrency tests
class FreshActionConcurrentSlowIgnoreFresh extends ReduxAction<AppState>
    with Fresh {
  final bool shouldFail;
  final int delayMillis;
  final int freshForMillis;

  FreshActionConcurrentSlowIgnoreFresh({
    required this.shouldFail,
    required this.delayMillis,
    required this.freshForMillis,
  });

  @override
  int get freshFor => freshForMillis;

  @override
  bool get ignoreFresh => true;

  @override
  Object computeFreshKey() => 'concurrentKey';

  @override
  Future<AppState> reduce() async {
    // Simulate long-running operation
    await Future.delayed(Duration(milliseconds: delayMillis));

    if (shouldFail) {
      throw const UserException(
          'Intentional failure from slow ignoreFresh action');
    }

    return state.copy(count: state.count + 1);
  }
}

// Outer action: reserves freshness, then dispatches OverrideAction, then fails.
class OuterActionNested extends ReduxAction<AppState> with Fresh {
  @override
  int get freshFor => 1000; // Long enough so it won't expire during the test.

  @override
  Object computeFreshKey() => 'nestedKey';

  @override
  bool get ignoreFresh => false;

  @override
  Future<AppState> reduce() async {
    // "External" writer: overrides the freshness while this action is running.
    await dispatch(OverrideAction());

    // Now fail, after OverrideAction has already succeeded.
    throw Exception('OuterActionNested fails after override');
  }
}

// Override action: always runs, sets freshness, increments count.
class OverrideAction extends ReduxAction<AppState> with Fresh {
  @override
  int get freshFor => 1000;

  @override
  Object computeFreshKey() => 'nestedKey';

  @override
  bool get ignoreFresh => true; // Always run and reset freshness.

  @override
  AppState reduce() {
    // This is our "external" writer that sets the final freshness.
    return state.copy(count: state.count + 1);
  }
}

// Check action: normal Fresh semantics, used to verify freshness state.
class CheckAction extends ReduxAction<AppState> with Fresh {
  @override
  int get freshFor => 1000;

  @override
  Object computeFreshKey() => 'nestedKey';

  @override
  bool get ignoreFresh => false;

  @override
  AppState reduce() {
    // Should only run if the key is stale.
    return state.copy(count: state.count + 1);
  }
}

// Action that combines Fresh with Throttle (incompatible)
class FreshWithThrottleAction extends ReduxAction<AppState>
    with
        Throttle,
        // ignore: private_collision_in_mixin_application
        Fresh {
  @override
  int get freshFor => 1000;

  @override
  int get throttle => 1000;

  @override
  AppState reduce() {
    return state.copy(count: state.count + 1);
  }
}

// Action that combines Fresh with NonReentrant (incompatible)
class FreshWithNonReentrantAction extends ReduxAction<AppState>
    with
        NonReentrant,
        // ignore: private_collision_in_mixin_application
        Fresh {
  @override
  int get freshFor => 1000;

  @override
  AppState reduce() {
    return state.copy(count: state.count + 1);
  }
}

// Action that combines Fresh with UnlimitedRetryCheckInternet (incompatible)
class FreshWithUnlimitedRetryAction extends ReduxAction<AppState>
    with
        UnlimitedRetryCheckInternet,
        // ignore: private_collision_in_mixin_application
        Fresh {
  @override
  int get freshFor => 1000;

  @override
  AppState reduce() {
    return state.copy(count: state.count + 1);
  }
}

// Action that combines Throttle with NonReentrant (incompatible)
class ThrottleWithNonReentrantAction extends ReduxAction<AppState>
    with
        Throttle,
        // ignore: private_collision_in_mixin_application
        NonReentrant {
  @override
  int get throttle => 1000;

  @override
  AppState reduce() {
    return state.copy(count: state.count + 1);
  }
}

// Action that combines Throttle with UnlimitedRetryCheckInternet (incompatible)
class ThrottleWithUnlimitedRetryAction extends ReduxAction<AppState>
    with
        Throttle,
        // ignore: private_collision_in_mixin_application
        UnlimitedRetryCheckInternet {
  @override
  int get throttle => 1000;

  @override
  AppState reduce() {
    return state.copy(count: state.count + 1);
  }
}

// Action that combines NonReentrant with UnlimitedRetryCheckInternet (incompatible)
class NonReentrantWithUnlimitedRetryAction extends ReduxAction<AppState>
    with
        NonReentrant,
        // ignore: private_collision_in_mixin_application
        UnlimitedRetryCheckInternet {
  @override
  AppState reduce() {
    return state.copy(count: state.count + 1);
  }
}

// Action that combines CheckInternet with AbortWhenNoInternet (incompatible)
class CheckInternetWithAbortWhenNoInternetAction extends ReduxAction<AppState>
    with
        CheckInternet,
        // ignore: private_collision_in_mixin_application
        AbortWhenNoInternet {
  @override
  AppState reduce() {
    return state.copy(count: state.count + 1);
  }
}

// Action that combines CheckInternet with UnlimitedRetryCheckInternet (incompatible)
class CheckInternetWithUnlimitedRetryAction extends ReduxAction<AppState>
    with
        CheckInternet,
        // ignore: private_collision_in_mixin_application
        UnlimitedRetryCheckInternet {
  @override
  AppState reduce() {
    return state.copy(count: state.count + 1);
  }
}

// Action that combines AbortWhenNoInternet with UnlimitedRetryCheckInternet (incompatible)
class AbortWhenNoInternetWithUnlimitedRetryAction extends ReduxAction<AppState>
    with
        AbortWhenNoInternet,
        // ignore: private_collision_in_mixin_application
        UnlimitedRetryCheckInternet {
  @override
  AppState reduce() {
    return state.copy(count: state.count + 1);
  }
}
