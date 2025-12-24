import 'package:async_redux/async_redux.dart';
import 'package:bdd_framework/bdd_framework.dart';
import 'package:flutter_test/flutter_test.dart' hide Retry;

void main() {
  var feature = BddFeature('OptimisticCommand mixin');

  Bdd(feature)
      .scenario('OptimisticCommand applies value, saves, and reloads.')
      .given('An action with OptimisticCommand mixin.')
      .when('The action is dispatched and sendCommandToServer succeeds.')
      .then('The optimistic value is applied immediately.')
      .and('The reloaded value is applied after save completes.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: ['initial']));

    var action = SaveItemAction('new_item');

    // Track state changes during the action.
    action.stateChanges.add(store.state.items);

    await store.dispatchAndWait(action);

    // Final state should have the reloaded items.
    expect(store.state.items, ['reloaded']);
    expect(action.status.isCompletedOk, isTrue);
  });

  Bdd(feature)
      .scenario('OptimisticCommand + Retry: retries sendCommandToServer only, no UI flickering.')
      .given('An action with both OptimisticCommand and Retry mixins.')
      .and('sendCommandToServer fails the first 2 times, then succeeds.')
      .when('The action is dispatched.')
      .then('The optimistic value is applied only once at the start.')
      .and('sendCommandToServer is retried until it succeeds.')
      .and('No rollback/re-apply flickering occurs during retries.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: ['initial']));

    var action = SaveItemActionWithRetry('new_item', failCount: 2);
    await store.dispatchAndWait(action);

    // Final state should have the reloaded items.
    expect(store.state.items, ['reloaded']);
    expect(action.status.isCompletedOk, isTrue);
    expect(action.attempts, 2); // Failed 2 times, then succeeded

    // CRITICAL: Verify NO flickering - optimistic value applied only once.
    // State changes tracked inside the action should show:
    // [optimistic] then [reloaded].
    // NOT: [optimistic] [rollback] [optimistic] [rollback] [optimistic] [reloaded]
    expect(action.stateChangesLog.length, 2); // Only 2 state changes, no flickering
    expect(action.stateChangesLog[0], ['initial', 'new_item']); // Optimistic
    expect(action.stateChangesLog[1], ['reloaded']); // Reloaded
  });

  Bdd(feature)
      .scenario('OptimisticCommand + Retry: rolls back only after all retries fail.')
      .given('An action with both OptimisticCommand and Retry mixins.')
      .and('sendCommandToServer always fails (maxRetries = 3).')
      .when('The action is dispatched.')
      .then('The optimistic value stays in place during all retry attempts.')
      .and('Rollback happens only after all retries are exhausted.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: ['initial']));

    var action = SaveItemActionWithRetryThatAlwaysFails('new_item');
    await store.dispatchAndWait(action);

    // Final state should be rolled back (reloadFromServer doesn't throw, but rollback happens).
    // Note: The finally block still runs reloadFromServer even on failure.
    expect(action.status.isCompletedFailed, isTrue);
    expect(action.attempts, 4); // Initial + 3 retries

    // CRITICAL: Verify NO flickering - optimistic applied once, then reload runs in finally.
    // Without our fix, it would be: [opt] [roll] [opt] [roll] [opt] [roll] [opt] [roll] [reload]
    // With our fix: [opt] [roll] [reload] (rollback + reload in finally)
    expect(action.stateChangesLog.length, 3);
    expect(action.stateChangesLog[0], ['initial', 'new_item']); // Optimistic
    expect(action.stateChangesLog[1], ['initial']); // Rolled back after all retries failed
    expect(action.stateChangesLog[2], ['reloaded']); // Reload in finally
  });

  Bdd(feature)
      .scenario('OptimisticCommand + UnlimitedRetries: retries until success.')
      .given('An action with OptimisticCommand and UnlimitedRetries mixins.')
      .and('sendCommandToServer fails the first 5 times, then succeeds.')
      .when('The action is dispatched.')
      .then('The optimistic value stays in place during all retries.')
      .and('No flickering occurs.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: ['initial']));

    var action = SaveItemActionWithUnlimitedRetry('new_item', failCount: 5);
    await store.dispatchAndWait(action);

    // Final state should have the reloaded items.
    expect(store.state.items, ['reloaded']);
    expect(action.status.isCompletedOk, isTrue);
    expect(action.attempts, 5); // Failed 5 times, then succeeded

    // CRITICAL: Verify NO flickering.
    expect(action.stateChangesLog.length, 2);
    expect(action.stateChangesLog[0], ['initial', 'new_item']); // Optimistic
    expect(action.stateChangesLog[1], ['reloaded']); // Reloaded
  });

  Bdd(feature)
      .scenario('OptimisticCommand without Retry: normal behavior, no retry logic.')
      .given('An action with only OptimisticCommand mixin (no Retry).')
      .and('sendCommandToServer fails.')
      .when('The action is dispatched.')
      .then('The action fails immediately without retrying.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: ['initial']));

    var action = SaveItemActionThatFails('new_item');
    await store.dispatchAndWait(action);

    // Note: reloadFromServer still runs in finally even on failure
    expect(action.status.isCompletedFailed, isTrue);
    expect(action.saveAttempts, 1); // Only 1 attempt, no retries
  });

  Bdd(feature)
      .scenario('OptimisticCommand rolls back on failure.')
      .given('An action with OptimisticCommand mixin.')
      .when('The action is dispatched and sendCommandToServer fails.')
      .then('The optimistic value is rolled back to the initial value.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: ['initial']));

    var action = SaveItemActionThatFailsWithStateLog('new_item');
    await store.dispatchAndWait(action);

    expect(action.status.isCompletedFailed, isTrue);

    // Verify the sequence: optimistic update, then rollback, then reload in finally.
    expect(action.stateChangesLog.length, 3);
    expect(action.stateChangesLog[0], ['initial', 'new_item']); // Optimistic
    expect(action.stateChangesLog[1], ['initial']); // Rolled back
    expect(action.stateChangesLog[2], ['reloaded']); // Reload in finally
  });

  Bdd(feature)
      .scenario('OptimisticCommand does NOT rollback if state changed by another action.')
      .given('An action with OptimisticCommand mixin.')
      .and('Another action modifies the state during sendCommandToServer.')
      .when('The action fails.')
      .then('The optimistic value is NOT rolled back because state changed.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: ['initial']));

    var action = SaveItemActionThatFailsAfterStateChange('new_item', store);
    await store.dispatchAndWait(action);

    expect(action.status.isCompletedFailed, isTrue);

    // State should NOT be rolled back because another action changed it.
    // Final state should be 'changed_by_other' (from the other action) then 'reloaded'.
    // The rollback was skipped because state != optimistic value.
    expect(action.stateChangesLog[0], ['initial', 'new_item']); // Optimistic
    // No rollback occurred because state was changed by another action.
    // Finally block still runs reloadFromServer.
    expect(action.stateChangesLog.last, ['reloaded']); // Reload in finally
    expect(action.rollbackOccurred, isFalse);
  });

  Bdd(feature)
      .scenario('OptimisticCommand without reloadFromServer implementation.')
      .given('An action with OptimisticCommand that does not implement reloadFromServer.')
      .when('The action is dispatched and sendCommandToServer succeeds.')
      .then('The reload step is skipped (no error).')
      .and('The state keeps the optimistic value.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: ['initial']));

    var action = SaveItemActionWithoutReload('new_item');
    await store.dispatchAndWait(action);

    // Final state should keep the optimistic value since reload was not implemented.
    expect(store.state.items, ['initial', 'new_item']);
    expect(action.status.isCompletedOk, isTrue);

    // Only one state change: the optimistic update.
    expect(action.stateChangesLog.length, 1);
    expect(action.stateChangesLog[0], ['initial', 'new_item']);
  });

  Bdd(feature)
      .scenario('OptimisticCommand without reloadFromServer: rollback on failure.')
      .given('An action with OptimisticCommand that does not implement reloadFromServer.')
      .when('The action is dispatched and sendCommandToServer fails.')
      .then('The optimistic value is rolled back.')
      .and('The reload step is skipped (no error).')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: ['initial']));

    var action = SaveItemActionWithoutReloadThatFails('new_item');
    await store.dispatchAndWait(action);

    // Final state should be rolled back to initial since save failed.
    expect(store.state.items, ['initial']);
    expect(action.status.isCompletedFailed, isTrue);

    // Two state changes: optimistic update, then rollback.
    expect(action.stateChangesLog.length, 2);
    expect(action.stateChangesLog[0], ['initial', 'new_item']); // Optimistic
    expect(action.stateChangesLog[1], ['initial']); // Rolled back
  });

  Bdd(feature)
      .scenario('OptimisticCommand + Retry without reloadFromServer: no flickering.')
      .given('An action with OptimisticCommand and Retry, but no reloadFromServer.')
      .and('sendCommandToServer fails the first 2 times, then succeeds.')
      .when('The action is dispatched.')
      .then('No flickering occurs and state keeps optimistic value.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: ['initial']));

    var action = SaveItemActionWithRetryNoReload('new_item', failCount: 2);
    await store.dispatchAndWait(action);

    // Final state should keep the optimistic value since reload was not implemented.
    expect(store.state.items, ['initial', 'new_item']);
    expect(action.status.isCompletedOk, isTrue);
    expect(action.attempts, 2);

    // Only one state change: the optimistic update (no reload).
    expect(action.stateChangesLog.length, 1);
    expect(action.stateChangesLog[0], ['initial', 'new_item']);
  });

  // ---------------------------------------------------------------------------
  // Tests for overriding rollbackState
  // ---------------------------------------------------------------------------

  Bdd(feature)
      .scenario('Custom rollbackState marks item as failed instead of removing it.')
      .given('An action with OptimisticCommand that overrides rollbackState.')
      .when('The action fails.')
      .then('The custom rollback is applied (item marked as failed).')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: ['initial']));

    var action = SaveItemActionWithCustomRollback('new_item');
    await store.dispatchAndWait(action);

    expect(action.status.isCompletedFailed, isTrue);

    // State should have the item marked as failed.
    expect(store.state.items, ['initial', 'new_item (FAILED)']);

    // Verify error was passed to rollbackState.
    expect(action.capturedError, isA<UserException>());

    // Note: stateChangesLog only captures calls through applyValueToState.
    // Custom rollbackState returns a state directly, bypassing applyValueToState.
    // So we only see the optimistic update in the log.
    expect(action.stateChangesLog.length, 1);
    expect(action.stateChangesLog[0], ['initial', 'new_item']);
  });

  Bdd(feature)
      .scenario('rollbackState returning null skips rollback.')
      .given('An action with OptimisticCommand that overrides rollbackState to return null.')
      .when('The action fails.')
      .then('No rollback occurs and state keeps the optimistic value.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: ['initial']));

    var action = SaveItemActionWithRollbackReturningNull('new_item');
    await store.dispatchAndWait(action);

    expect(action.status.isCompletedFailed, isTrue);

    // State should keep the optimistic value (no rollback).
    expect(store.state.items, ['initial', 'new_item']);

    // Only one state change: the optimistic update.
    expect(action.stateChangesLog.length, 1);
    expect(action.stateChangesLog[0], ['initial', 'new_item']);
  });

  // ---------------------------------------------------------------------------
  // Tests for overriding shouldRollback
  // ---------------------------------------------------------------------------

  Bdd(feature)
      .scenario('shouldRollback always true: rollback even when state changed.')
      .given('An action with OptimisticCommand that overrides shouldRollback to always return true.')
      .and('Another action modifies the state during sendCommandToServer.')
      .when('The action fails.')
      .then('The rollback happens even though state changed.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: ['initial']));

    var action = SaveItemActionWithAlwaysRollback('new_item', store);
    await store.dispatchAndWait(action);

    expect(action.status.isCompletedFailed, isTrue);

    // State should be rolled back to initial, overwriting the other action's change.
    expect(store.state.items, ['initial']);

    // State changes: optimistic, then rollback.
    expect(action.stateChangesLog.length, 2);
    expect(action.stateChangesLog[0], ['initial', 'new_item']);
    expect(action.stateChangesLog[1], ['initial']);
  });

  Bdd(feature)
      .scenario('shouldRollback always false: never rollback.')
      .given('An action with OptimisticCommand that overrides shouldRollback to always return false.')
      .when('The action fails.')
      .then('No rollback occurs and state keeps the optimistic value.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: ['initial']));

    var action = SaveItemActionWithNeverRollback('new_item');
    await store.dispatchAndWait(action);

    expect(action.status.isCompletedFailed, isTrue);

    // State should keep the optimistic value (no rollback).
    expect(store.state.items, ['initial', 'new_item']);

    // Only one state change: the optimistic update.
    expect(action.stateChangesLog.length, 1);
    expect(action.stateChangesLog[0], ['initial', 'new_item']);
  });

  Bdd(feature)
      .scenario('shouldRollback conditional: rollback only for validation errors.')
      .given('An action with shouldRollback that returns false for network errors.')
      .when('The action fails with a network error.')
      .then('No rollback occurs.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: ['initial']));

    var action = SaveItemActionWithConditionalRollback('new_item', throwNetworkError: true);
    await store.dispatchAndWait(action);

    expect(action.status.isCompletedFailed, isTrue);

    // No rollback for network error.
    expect(store.state.items, ['initial', 'new_item']);
    expect(action.stateChangesLog.length, 1);
  });

  Bdd(feature)
      .scenario('shouldRollback conditional: rollback for validation errors.')
      .given('An action with shouldRollback that returns true for validation errors.')
      .when('The action fails with a validation error.')
      .then('Rollback occurs.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: ['initial']));

    var action = SaveItemActionWithConditionalRollback('new_item', throwNetworkError: false);
    await store.dispatchAndWait(action);

    expect(action.status.isCompletedFailed, isTrue);

    // Rollback for validation error.
    expect(store.state.items, ['initial']);
    expect(action.stateChangesLog.length, 2);
    expect(action.stateChangesLog[0], ['initial', 'new_item']);
    expect(action.stateChangesLog[1], ['initial']);
  });

  // ---------------------------------------------------------------------------
  // Tests for overriding shouldReload
  // ---------------------------------------------------------------------------

  Bdd(feature)
      .scenario('shouldReload returns false on success: no reload.')
      .given('An action with shouldReload that returns true only on error.')
      .when('The action succeeds.')
      .then('reloadFromServer is not called.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: ['initial']));

    var action = SaveItemActionWithConditionalReload('new_item', shouldFail: false);
    await store.dispatchAndWait(action);

    expect(action.status.isCompletedOk, isTrue);
    expect(action.reloadWasCalled, isFalse);

    // State keeps optimistic value.
    expect(store.state.items, ['initial', 'new_item']);
    expect(action.stateChangesLog.length, 1);
  });

  Bdd(feature)
      .scenario('shouldReload returns true on error: reload happens.')
      .given('An action with shouldReload that returns true only on error.')
      .when('The action fails.')
      .then('reloadFromServer is called and applied.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: ['initial']));

    var action = SaveItemActionWithConditionalReload('new_item', shouldFail: true);
    await store.dispatchAndWait(action);

    expect(action.status.isCompletedFailed, isTrue);
    expect(action.reloadWasCalled, isTrue);

    // State is reloaded.
    expect(store.state.items, ['reloaded']);
  });

  // ---------------------------------------------------------------------------
  // Tests for overriding shouldApplyReload
  // ---------------------------------------------------------------------------

  Bdd(feature)
      .scenario('shouldApplyReload returns true when state unchanged: reload applied.')
      .given('An action with shouldApplyReload that checks if state is unchanged.')
      .and('No other action modifies state during reload.')
      .when('The action succeeds.')
      .then('Reload result is applied.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: ['initial']));

    var action = SaveItemActionWithConditionalApplyReload(
      'new_item',
      store,
      changeStateDuringReload: false,
    );
    await store.dispatchAndWait(action);

    expect(action.status.isCompletedOk, isTrue);

    // Reload was applied.
    expect(store.state.items, ['reloaded']);
  });

  Bdd(feature)
      .scenario('shouldApplyReload returns false when state changed: reload skipped.')
      .given('An action with shouldApplyReload that checks if state is unchanged.')
      .and('Another action modifies state during reload.')
      .when('The action succeeds.')
      .then('Reload result is NOT applied to avoid overwriting newer changes.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: ['initial']));

    var action = SaveItemActionWithConditionalApplyReload(
      'new_item',
      store,
      changeStateDuringReload: true,
    );
    await store.dispatchAndWait(action);

    expect(action.status.isCompletedOk, isTrue);

    // State was changed by other action, so reload was NOT applied.
    // The state should be 'changed_by_other' from ChangeStateAction.
    expect(store.state.items, ['changed_by_other']);
  });

  // ---------------------------------------------------------------------------
  // Tests for overriding applyReloadResultToState
  // ---------------------------------------------------------------------------

  Bdd(feature)
      .scenario('Custom applyReloadResultToState transforms reload result.')
      .given('An action with applyReloadResultToState that transforms the reload result.')
      .and('reloadFromServer returns a map instead of a list.')
      .when('The action succeeds.')
      .then('The custom transformation is applied.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: ['initial']));

    var action = SaveItemActionWithCustomApplyReload('new_item');
    await store.dispatchAndWait(action);

    expect(action.status.isCompletedOk, isTrue);

    // The custom applyReloadResultToState transformed the map and added 'TRANSFORMED'.
    expect(store.state.items, ['server_item1', 'server_item2', 'TRANSFORMED']);
  });

  Bdd(feature)
      .scenario('applyReloadResultToState returning null skips applying reload.')
      .given('An action with applyReloadResultToState that returns null.')
      .when('The action succeeds and reload completes.')
      .then('The reload result is NOT applied and state keeps optimistic value.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: ['initial']));

    var action = SaveItemActionWithApplyReloadReturningNull('new_item');
    await store.dispatchAndWait(action);

    expect(action.status.isCompletedOk, isTrue);
    expect(action.reloadWasCalled, isTrue);

    // Reload was called but NOT applied (applyReloadResultToState returned null).
    // State keeps the optimistic value.
    expect(store.state.items, ['initial', 'new_item']);
    expect(action.stateChangesLog.length, 1);
  });

  // ---------------------------------------------------------------------------
  // Missing edge cases / invariants
  // ---------------------------------------------------------------------------

  Bdd(feature)
      .scenario('OptimisticCommand: if reloadFromServer throws on success, '
          'the action fails with the reload error.')
      .given('An action with OptimisticCommand mixin.')
      .and('sendCommandToServer succeeds.')
      .and('reloadFromServer throws.')
      .when('The action is dispatched.')
      .then('The action fails (reload error is not swallowed).')
      .and('The optimistic value remains applied (reload did not overwrite it).')
      .note('This locks the intended behavior when reload fails but there was no prior error.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: ['initial']));

    var action = SaveItemActionWithReloadThatThrows('new_item');
    await store.dispatchAndWait(action);

    // The action should fail because reloadFromServer threw.
    expect(action.status.isCompletedFailed, isTrue);

    // The error should be the reload error, not swallowed.
    expect(action.status.originalError.toString(), contains('Reload failed'));

    // The optimistic value remains applied (reload did not overwrite it).
    expect(store.state.items, ['initial', 'new_item']);
  });

  Bdd(feature)
      .scenario('OptimisticCommand: if reloadFromServer throws on failure, '
          'the action fails with the original command error.')
      .given('An action with OptimisticCommand mixin.')
      .and('sendCommandToServer throws.')
      .and('reloadFromServer also throws.')
      .when('The action is dispatched.')
      .then('The action fails with the original sendCommandToServer error '
          '(reload error does not replace it).')
      .and('Rollback behavior follows shouldRollback/rollbackState as usual.')
      .note('This ensures reload failure never hides the real command failure.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: ['initial']));

    var action = SaveItemActionWithBothCommandAndReloadThatThrow('new_item');
    await store.dispatchAndWait(action);

    // The action should fail.
    expect(action.status.isCompletedFailed, isTrue);

    // The error should be the ORIGINAL command error, not the reload error.
    expect(action.status.originalError.toString(), contains('Command failed'));

    // Rollback should have happened (state rolled back to initial).
    expect(store.state.items, ['initial']);
  });

  Bdd(feature)
      .scenario('OptimisticCommand: shouldReload can skip reload on error.')
      .given('An action with OptimisticCommand mixin.')
      .and('sendCommandToServer throws.')
      .and('shouldReload returns false when error != null.')
      .when('The action is dispatched.')
      .then('reloadFromServer is not called.')
      .and('Rollback behavior is still evaluated normally.')
      .note('This is different from "reload not implemented". '
          'It is "reload intentionally disabled by policy".')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: ['initial']));

    var action = SaveItemActionWithShouldReloadFalseOnError('new_item');
    await store.dispatchAndWait(action);

    expect(action.status.isCompletedFailed, isTrue);

    // reloadFromServer should NOT have been called.
    expect(action.reloadWasCalled, isFalse);

    // Rollback should still have happened normally.
    expect(store.state.items, ['initial']);
  });

  Bdd(feature)
      .scenario('OptimisticCommand: shouldApplyReload can use the error parameter '
          'to skip applying reload on failure.')
      .given('An action with OptimisticCommand mixin.')
      .and('sendCommandToServer throws.')
      .and('reloadFromServer returns a value.')
      .and('shouldApplyReload returns false when error != null.')
      .when('The action is dispatched.')
      .then('reloadFromServer is called (because shouldReload returned true).')
      .and('The reload result is not applied (because shouldApplyReload returned false).')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: ['initial']));

    var action = SaveItemActionWithShouldApplyReloadFalseOnError('new_item');
    await store.dispatchAndWait(action);

    expect(action.status.isCompletedFailed, isTrue);

    // reloadFromServer WAS called.
    expect(action.reloadWasCalled, isTrue);

    // But the reload result was NOT applied (shouldApplyReload returned false).
    // State should be rolled back to initial, not 'reloaded'.
    expect(store.state.items, ['initial']);
  });

  Bdd(feature)
      .scenario('OptimisticCommand: lastAppliedValue passed to shouldReload/shouldApplyReload '
          'is the rollbackValue when rollback was applied.')
      .given('An action with OptimisticCommand mixin.')
      .and('sendCommandToServer throws.')
      .and('Rollback is applied (shouldRollback returns true and rollbackState returns a non-null state).')
      .and('shouldReload captures the received lastAppliedValue and rollbackValue.')
      .when('The action is dispatched.')
      .then('lastAppliedValue equals rollbackValue when rollback happened.')
      .note('This verifies your bookkeeping: on error, the "last thing we applied" '
          'should reflect rollback, not the optimistic value.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: ['initial']));

    var action = SaveItemActionCaptureLastAppliedOnError('new_item');
    await store.dispatchAndWait(action);

    expect(action.status.isCompletedFailed, isTrue);

    // Verify the captured values.
    expect(action.capturedLastAppliedValue, isNotNull);
    expect(action.capturedRollbackValue, isNotNull);

    // lastAppliedValue should equal rollbackValue when rollback happened.
    expect(action.capturedLastAppliedValue, action.capturedRollbackValue);

    // And both should be the initial value (what we rolled back to).
    expect(action.capturedLastAppliedValue, ['initial']);
  });

  Bdd(feature)
      .scenario('OptimisticCommand: lastAppliedValue passed to shouldReload/shouldApplyReload '
          'is the optimisticValue on success.')
      .given('An action with OptimisticCommand mixin.')
      .and('sendCommandToServer succeeds.')
      .and('shouldReload captures the received lastAppliedValue.')
      .when('The action is dispatched.')
      .then('lastAppliedValue equals optimisticValue.')
      .note('Ensures lastAppliedValue semantics are stable across success vs failure.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: ['initial']));

    var action = SaveItemActionCaptureLastAppliedOnSuccess('new_item');
    await store.dispatchAndWait(action);

    expect(action.status.isCompletedOk, isTrue);

    // Verify the captured lastAppliedValue equals the optimisticValue.
    expect(action.capturedLastAppliedValue, isNotNull);
    expect(action.capturedOptimisticValue, isNotNull);
    expect(action.capturedLastAppliedValue, action.capturedOptimisticValue);

    // And rollbackValue should be null on success.
    expect(action.capturedRollbackValue, isNull);
  });

  Bdd(feature)
      .scenario('OptimisticCommand: optimisticValue is computed exactly once, '
          'even when Retry retries sendCommandToServer.')
      .given('An action with OptimisticCommand and Retry mixins.')
      .and('optimisticValue increments a counter each time it is called.')
      .and('sendCommandToServer fails N times then succeeds.')
      .when('The action is dispatched.')
      .then('optimisticValue was called exactly once.')
      .and('sendCommandToServer was called N+1 times.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: ['initial']));

    var action = SaveItemActionWithOptimisticValueCounter('new_item', failCount: 3);
    await store.dispatchAndWait(action);

    expect(action.status.isCompletedOk, isTrue);

    // optimisticValue should have been called exactly once.
    expect(action.optimisticValueCallCount, 1);

    // sendCommandToServer should have been called N+1 times (3 failures + 1 success = 4).
    expect(action.sendCommandCallCount, 4);
  });

  Bdd(feature)
      .scenario('OptimisticCommand: sendCommandToServer receives the same optimisticValue '
          'instance that was applied to state.')
      .given('An action with OptimisticCommand mixin.')
      .and('optimisticValue returns an object whose identity can be checked.')
      .when('The action is dispatched.')
      .then('sendCommandToServer receives the same object instance returned by optimisticValue.')
      .note('This is useful if users build an optimistic payload object and want to reuse it in the command.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: ['initial']));

    var action = SaveItemActionCheckIdentity('new_item');
    await store.dispatchAndWait(action);

    expect(action.status.isCompletedOk, isTrue);

    // The object passed to sendCommandToServer should be identical to the one returned by optimisticValue.
    expect(action.receivedValueInSendCommand, isNotNull);
    expect(action.createdOptimisticValue, isNotNull);
    expect(identical(action.receivedValueInSendCommand, action.createdOptimisticValue), isTrue);
  });

  // ---------------------------------------------------------------------------
  // Tests for built-in non-reentrant behavior
  // ---------------------------------------------------------------------------

  Bdd(feature)
      .scenario('OptimisticCommand blocks concurrent dispatches.')
      .given('An OptimisticCommand action that takes some time to finish.')
      .when('The action is dispatched.')
      .and('Another action of the same type is dispatched before the previous one finished.')
      .then('The second dispatch is aborted.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: ['initial']));

    // Dispatch first action that takes 100ms.
    store.dispatch(OptimisticCommandSlowAction('item1', delayMillis: 100));
    expect(store.isWaiting(OptimisticCommandSlowAction), true);

    // Wait a bit and dispatch another action of the same type.
    await Future.delayed(const Duration(milliseconds: 10));
    store.dispatch(OptimisticCommandSlowAction('item2', delayMillis: 10));

    // Wait for all actions to finish.
    await store.waitAllActions([]);
    expect(store.isWaiting(OptimisticCommandSlowAction), false);

    // Only the first action ran, adding 'item1'.
    // The second action was aborted.
    expect(store.state.items, ['initial', 'item1']);
  });

  Bdd(feature)
      .scenario('OptimisticCommand allows dispatch after action completes.')
      .given('An OptimisticCommand action has completed.')
      .when('The same action type is dispatched again.')
      .then('It should run successfully.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: ['initial']));

    // Dispatch first action and wait for completion.
    await store.dispatchAndWait(OptimisticCommandSlowAction('item1', delayMillis: 10));
    expect(store.state.items, ['initial', 'item1']);

    // After completion, we can dispatch again.
    await store.dispatchAndWait(OptimisticCommandSlowAction('item2', delayMillis: 10));
    expect(store.state.items, ['initial', 'item1', 'item2']);
  });

  Bdd(feature)
      .scenario('OptimisticCommand releases key even when action fails.')
      .given('An OptimisticCommand action that throws an error.')
      .when('The action is dispatched and fails.')
      .then('A subsequent dispatch of the same action type should run.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: ['initial']));

    // Dispatch action that will fail.
    await store.dispatchAndWait(OptimisticCommandFailingAction());
    expect(store.state.items, ['initial']); // Rolled back due to failure.

    // After failure, we can dispatch again (key was released in after()).
    await store.dispatchAndWait(OptimisticCommandSlowAction('item1', delayMillis: 10));
    expect(store.state.items, ['initial', 'item1']);
  });

  Bdd(feature)
      .scenario('OptimisticCommand with different nonReentrantKeyParams can run in parallel.')
      .given('An OptimisticCommand action that uses nonReentrantKeyParams.')
      .when('Two actions with different params are dispatched concurrently.')
      .then('Both actions should run.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: []));

    // Dispatch two actions with different itemIds - they should both run.
    store.dispatch(OptimisticCommandWithParams('A', 'valueA', delayMillis: 100));
    store.dispatch(OptimisticCommandWithParams('B', 'valueB', delayMillis: 100));

    // Wait for both to complete.
    await store.waitAllActions([]);

    // Both should have run.
    expect(store.state.items.length, 2);
    expect(store.state.items.contains('valueA'), isTrue);
    expect(store.state.items.contains('valueB'), isTrue);
  });

  Bdd(feature)
      .scenario('OptimisticCommand with same nonReentrantKeyParams blocks each other.')
      .given('An OptimisticCommand action that uses nonReentrantKeyParams.')
      .when('Two actions with the same params are dispatched concurrently.')
      .then('Only the first action should run.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: []));

    // Dispatch two actions with the same itemId.
    store.dispatch(OptimisticCommandWithParams('A', 'valueA1', delayMillis: 100));

    // Wait a bit to ensure first action started.
    await Future.delayed(const Duration(milliseconds: 10));

    // This should be aborted because 'A' is already running.
    store.dispatch(OptimisticCommandWithParams('A', 'valueA2', delayMillis: 10));

    // Wait for all to complete.
    await store.waitAllActions([]);

    // Only first should have run.
    expect(store.state.items, ['valueA1']);
  });

  Bdd(feature)
      .scenario('Different OptimisticCommand action types with same computeNonReentrantKey block each other.')
      .given('Two different OptimisticCommand action types that share the same non-reentrant key.')
      .when('Both actions are dispatched concurrently.')
      .then('Only the first action should run.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: []));

    // Dispatch first action with shared key.
    store.dispatch(OptimisticCommandSharedKey1('value1', delayMillis: 100));

    // Wait a bit to ensure first action started.
    await Future.delayed(const Duration(milliseconds: 10));

    // Dispatch second action type with same shared key - should be aborted.
    store.dispatch(OptimisticCommandSharedKey2('value2', delayMillis: 10));

    // Wait for all to complete.
    await store.waitAllActions([]);

    // Only first should have run.
    expect(store.state.items, ['value1']);
  });

  Bdd(feature)
      .scenario('After first OptimisticCommand completes, second action type with shared key can run.')
      .given('Two different OptimisticCommand action types that share the same non-reentrant key.')
      .when('The first action completes.')
      .then('The second action type can run.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: []));

    // Dispatch and wait for first action.
    await store.dispatchAndWait(OptimisticCommandSharedKey1('value1', delayMillis: 10));
    expect(store.state.items, ['value1']);

    // Now second action type with same key should run.
    await store.dispatchAndWait(OptimisticCommandSharedKey2('value2', delayMillis: 10));
    expect(store.state.items, ['value1', 'value2']);
  });

  Bdd(feature)
      .scenario('OptimisticCommand key is released after error in reduce.')
      .given('An OptimisticCommand action with params that throws.')
      .when('The action fails.')
      .then('The key is released and another action with same params can run.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: []));

    // Dispatch action with param 'X' that fails.
    await store.dispatchAndWait(OptimisticCommandWithParamsThatFails('X'));
    expect(store.state.items, []); // Rolled back.

    // Now dispatch another action with same param - should run.
    await store.dispatchAndWait(OptimisticCommandWithParams('X', 'valueX', delayMillis: 10));
    expect(store.state.items, ['valueX']);
  });

  Bdd(feature)
      .scenario('Multiple OptimisticCommand concurrent dispatches with various params.')
      .given('Multiple OptimisticCommand actions with different params.')
      .when('They are dispatched concurrently.')
      .then('Actions with different params run, actions with same params are blocked.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: []));

    // Dispatch multiple actions:
    // - Two with param 'A' (second should be blocked)
    // - Two with param 'B' (second should be blocked)
    // - One with param 'C' (should run)
    store.dispatch(OptimisticCommandWithParams('A', 'A1', delayMillis: 100));
    store.dispatch(OptimisticCommandWithParams('B', 'B1', delayMillis: 100));
    store.dispatch(OptimisticCommandWithParams('C', 'C1', delayMillis: 100));

    await Future.delayed(const Duration(milliseconds: 10));

    store.dispatch(OptimisticCommandWithParams('A', 'A2', delayMillis: 10)); // blocked
    store.dispatch(OptimisticCommandWithParams('B', 'B2', delayMillis: 10)); // blocked

    await store.waitAllActions([]);

    // Only A1, B1, C1 should have run.
    expect(store.state.items.length, 3);
    expect(store.state.items.contains('A1'), isTrue);
    expect(store.state.items.contains('B1'), isTrue);
    expect(store.state.items.contains('C1'), isTrue);
    expect(store.state.items.contains('A2'), isFalse);
    expect(store.state.items.contains('B2'), isFalse);
  });

  Bdd(feature)
      .scenario('OptimisticCommand cannot be combined with NonReentrant mixin.')
      .given('An action that combines OptimisticCommand and NonReentrant.')
      .when('The action is dispatched.')
      .then('An assertion error is thrown.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: ['initial']));

    // This should throw an assertion error due to incompatible mixins.
    expect(
      () => store.dispatch(OptimisticCommandWithNonReentrant('item')),
      throwsA(isA<AssertionError>().having(
        (e) => e.message,
        'message',
        contains('OptimisticCommand'),
      )),
    );
  });

  Bdd(feature)
      .scenario('OptimisticCommand cannot be combined with Throttle mixin.')
      .given('An action that combines OptimisticCommand and Throttle.')
      .when('The action is dispatched.')
      .then('An assertion error is thrown.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: ['initial']));

    // This should throw an assertion error due to incompatible mixins.
    expect(
      () => store.dispatch(OptimisticCommandWithThrottle('item')),
      throwsA(isA<AssertionError>().having(
        (e) => e.message,
        'message',
        contains('OptimisticCommand'),
      )),
    );
  });

  Bdd(feature)
      .scenario('OptimisticCommand cannot be combined with Fresh mixin.')
      .given('An action that combines OptimisticCommand and Fresh.')
      .when('The action is dispatched.')
      .then('An assertion error is thrown.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: ['initial']));

    // This should throw an assertion error due to incompatible mixins.
    expect(
      () => store.dispatch(OptimisticCommandWithFresh('item')),
      throwsA(isA<AssertionError>().having(
        (e) => e.message,
        'message',
        contains('OptimisticCommand'),
      )),
    );
  });
}

// -----------------------------------------------------------------------------
// State
// -----------------------------------------------------------------------------

class AppState {
  final List<String> items;

  AppState({required this.items});

  AppState copy({List<String>? items}) => AppState(items: items ?? this.items);

  @override
  String toString() => 'AppState(items: $items)';
}

// -----------------------------------------------------------------------------
// Actions
// -----------------------------------------------------------------------------

/// Basic OptimisticCommand action that succeeds.
class SaveItemAction extends ReduxAction<AppState> with OptimisticCommand<AppState> {
  final String newItem;
  final List<List<String>> stateChanges = [];

  SaveItemAction(this.newItem);

  @override
  Object? optimisticValue() => [...state.items, newItem];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) {
    final newItems = value as List<String>;
    stateChanges.add(newItems);
    return state.copy(items: newItems);
  }

  @override
  Future<void> sendCommandToServer(Object? newValue) async {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  @override
  Future<Object?> reloadFromServer() async {
    await Future.delayed(const Duration(milliseconds: 10));
    return ['reloaded'];
  }
}

/// OptimisticCommand action that always fails sendCommandToServer.
class SaveItemActionThatFails extends ReduxAction<AppState>
    with OptimisticCommand<AppState> {
  final String newItem;
  int saveAttempts = 0;

  SaveItemActionThatFails(this.newItem);

  @override
  Object? optimisticValue() => [...state.items, newItem];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) =>
      state.copy(items: value as List<String>);

  @override
  Future<void> sendCommandToServer(Object? newValue) async {
    saveAttempts++;
    await Future.delayed(const Duration(milliseconds: 10));
    throw const UserException('Save failed');
  }

  @override
  Future<Object?> reloadFromServer() async {
    return ['reloaded'];
  }
}

/// OptimisticCommand action that fails and tracks state changes (for rollback test).
class SaveItemActionThatFailsWithStateLog extends ReduxAction<AppState>
    with OptimisticCommand<AppState> {
  final String newItem;
  final List<List<String>> stateChangesLog = [];

  SaveItemActionThatFailsWithStateLog(this.newItem);

  @override
  Object? optimisticValue() => [...state.items, newItem];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) {
    final newItems = value as List<String>;
    stateChangesLog.add(newItems);
    return state.copy(items: newItems);
  }

  @override
  Future<void> sendCommandToServer(Object? newValue) async {
    await Future.delayed(const Duration(milliseconds: 10));
    throw const UserException('Save failed');
  }

  @override
  Future<Object?> reloadFromServer() async {
    return ['reloaded'];
  }
}

/// OptimisticCommand action that fails after another action changes the state.
/// This tests the conditional rollback logic.
class SaveItemActionThatFailsAfterStateChange extends ReduxAction<AppState>
    with OptimisticCommand<AppState> {
  final String newItem;
  final Store<AppState> _store;
  final List<List<String>> stateChangesLog = [];
  bool rollbackOccurred = false;

  SaveItemActionThatFailsAfterStateChange(this.newItem, this._store);

  @override
  Object? optimisticValue() => [...state.items, newItem];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) {
    final newItems = value as List<String>;
    // Track if this is a rollback (going back to initial).
    if (stateChangesLog.isNotEmpty && newItems.length == 1 && newItems[0] == 'initial') {
      rollbackOccurred = true;
    }
    stateChangesLog.add(newItems);
    return state.copy(items: newItems);
  }

  @override
  Future<void> sendCommandToServer(Object? newValue) async {
    await Future.delayed(const Duration(milliseconds: 10));
    // Another action changes the state during save.
    _store.dispatch(ChangeStateAction());
    await Future.delayed(const Duration(milliseconds: 10));
    throw const UserException('Save failed');
  }

  @override
  Future<Object?> reloadFromServer() async {
    return ['reloaded'];
  }
}

/// Action that changes the state (used to simulate concurrent modification).
class ChangeStateAction extends ReduxAction<AppState> {
  @override
  AppState reduce() => state.copy(items: ['changed_by_other']);
}

/// OptimisticCommand action that does NOT implement reloadFromServer.
class SaveItemActionWithoutReload extends ReduxAction<AppState>
    with OptimisticCommand<AppState> {
  final String newItem;
  final List<List<String>> stateChangesLog = [];

  SaveItemActionWithoutReload(this.newItem);

  @override
  Object? optimisticValue() => [...state.items, newItem];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) {
    final newItems = value as List<String>;
    stateChangesLog.add(newItems);
    return state.copy(items: newItems);
  }

  @override
  Future<void> sendCommandToServer(Object? newValue) async {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  // reloadFromServer is intentionally NOT overridden - uses default that throws UnimplementedError.
}

/// OptimisticCommand action that does NOT implement reloadFromServer and fails.
class SaveItemActionWithoutReloadThatFails extends ReduxAction<AppState>
    with OptimisticCommand<AppState> {
  final String newItem;
  final List<List<String>> stateChangesLog = [];

  SaveItemActionWithoutReloadThatFails(this.newItem);

  @override
  Object? optimisticValue() => [...state.items, newItem];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) {
    final newItems = value as List<String>;
    stateChangesLog.add(newItems);
    return state.copy(items: newItems);
  }

  @override
  Future<void> sendCommandToServer(Object? newValue) async {
    await Future.delayed(const Duration(milliseconds: 10));
    throw const UserException('Save failed');
  }

  // reloadFromServer is intentionally NOT overridden - uses default that throws UnimplementedError.
}

/// OptimisticCommand + Retry action without reloadFromServer implementation.
class SaveItemActionWithRetryNoReload extends ReduxAction<AppState>
    with OptimisticCommand<AppState>, Retry<AppState> {
  final String newItem;
  final int failCount;
  int _saveAttemptCount = 0;
  final List<List<String>> stateChangesLog = [];

  SaveItemActionWithRetryNoReload(this.newItem, {required this.failCount});

  @override
  Duration get initialDelay => const Duration(milliseconds: 5);

  @override
  int get maxRetries => 10;

  @override
  Object? optimisticValue() => [...state.items, newItem];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) {
    final newItems = value as List<String>;
    stateChangesLog.add(newItems);
    return state.copy(items: newItems);
  }

  @override
  Future<void> sendCommandToServer(Object? newValue) async {
    _saveAttemptCount++;
    await Future.delayed(const Duration(milliseconds: 5));
    if (_saveAttemptCount <= failCount) {
      throw UserException('Save failed: attempt $_saveAttemptCount');
    }
  }

  // reloadFromServer is intentionally NOT overridden - uses default that throws UnimplementedError.
}

/// OptimisticCommand + Retry action that fails [failCount] times then succeeds.
class SaveItemActionWithRetry extends ReduxAction<AppState>
    with OptimisticCommand<AppState>, Retry<AppState> {
  final String newItem;
  final int failCount;
  int _saveAttemptCount = 0;
  final List<List<String>> stateChangesLog = [];

  SaveItemActionWithRetry(this.newItem, {required this.failCount});

  @override
  Duration get initialDelay => const Duration(milliseconds: 5);

  @override
  int get maxRetries => 10;

  @override
  Object? optimisticValue() => [...state.items, newItem];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) {
    final newItems = value as List<String>;
    stateChangesLog.add(newItems);
    return state.copy(items: newItems);
  }

  @override
  Future<void> sendCommandToServer(Object? newValue) async {
    _saveAttemptCount++;
    await Future.delayed(const Duration(milliseconds: 5));
    if (_saveAttemptCount <= failCount) {
      throw UserException('Save failed: attempt $_saveAttemptCount');
    }
  }

  @override
  Future<Object?> reloadFromServer() async {
    await Future.delayed(const Duration(milliseconds: 5));
    return ['reloaded'];
  }
}

/// OptimisticCommand + Retry action that always fails (tests rollback after exhausting retries).
class SaveItemActionWithRetryThatAlwaysFails extends ReduxAction<AppState>
    with OptimisticCommand<AppState>, Retry<AppState> {
  final String newItem;
  final List<List<String>> stateChangesLog = [];

  SaveItemActionWithRetryThatAlwaysFails(this.newItem);

  @override
  Duration get initialDelay => const Duration(milliseconds: 5);

  @override
  int get maxRetries => 3;

  @override
  Object? optimisticValue() => [...state.items, newItem];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) {
    final newItems = value as List<String>;
    stateChangesLog.add(newItems);
    return state.copy(items: newItems);
  }

  @override
  Future<void> sendCommandToServer(Object? newValue) async {
    await Future.delayed(const Duration(milliseconds: 5));
    throw const UserException('Save always fails');
  }

  @override
  Future<Object?> reloadFromServer() async {
    return ['reloaded'];
  }
}

/// OptimisticCommand + UnlimitedRetries action.
class SaveItemActionWithUnlimitedRetry extends ReduxAction<AppState>
    with OptimisticCommand<AppState>, Retry<AppState>, UnlimitedRetries<AppState> {
  final String newItem;
  final int failCount;
  int _saveAttemptCount = 0;
  final List<List<String>> stateChangesLog = [];

  SaveItemActionWithUnlimitedRetry(this.newItem, {required this.failCount});

  @override
  Duration get initialDelay => const Duration(milliseconds: 5);

  @override
  Object? optimisticValue() => [...state.items, newItem];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) {
    final newItems = value as List<String>;
    stateChangesLog.add(newItems);
    return state.copy(items: newItems);
  }

  @override
  Future<void> sendCommandToServer(Object? newValue) async {
    _saveAttemptCount++;
    await Future.delayed(const Duration(milliseconds: 5));
    if (_saveAttemptCount <= failCount) {
      throw UserException('Save failed: attempt $_saveAttemptCount');
    }
  }

  @override
  Future<Object?> reloadFromServer() async {
    await Future.delayed(const Duration(milliseconds: 5));
    return ['reloaded'];
  }
}

// -----------------------------------------------------------------------------
// Actions for testing override methods
// -----------------------------------------------------------------------------

/// Action that overrides rollbackState to mark the item as failed instead of removing it.
class SaveItemActionWithCustomRollback extends ReduxAction<AppState>
    with OptimisticCommand<AppState> {
  final String newItem;
  final List<List<String>> stateChangesLog = [];
  Object? capturedError;

  SaveItemActionWithCustomRollback(this.newItem);

  @override
  Object? optimisticValue() => [...state.items, newItem];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) {
    final newItems = value as List<String>;
    stateChangesLog.add(newItems);
    return state.copy(items: newItems);
  }

  @override
  Future<void> sendCommandToServer(Object? newValue) async {
    await Future.delayed(const Duration(milliseconds: 10));
    throw const UserException('Save failed');
  }

  @override
  AppState? rollbackState({
    required Object? initialValue,
    required Object? optimisticValue,
    required Object error,
  }) {
    capturedError = error;
    // Instead of restoring initial value, mark the item as failed.
    final items = optimisticValue as List<String>;
    final markedItems = items.map((item) => item == newItem ? '$item (FAILED)' : item).toList();
    return state.copy(items: markedItems);
  }

  // No reload to keep test simple.
}

/// Action that overrides rollbackState to return null (skip rollback).
class SaveItemActionWithRollbackReturningNull extends ReduxAction<AppState>
    with OptimisticCommand<AppState> {
  final String newItem;
  final List<List<String>> stateChangesLog = [];

  SaveItemActionWithRollbackReturningNull(this.newItem);

  @override
  Object? optimisticValue() => [...state.items, newItem];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) {
    final newItems = value as List<String>;
    stateChangesLog.add(newItems);
    return state.copy(items: newItems);
  }

  @override
  Future<void> sendCommandToServer(Object? newValue) async {
    await Future.delayed(const Duration(milliseconds: 10));
    throw const UserException('Save failed');
  }

  @override
  AppState? rollbackState({
    required Object? initialValue,
    required Object? optimisticValue,
    required Object error,
  }) {
    // Return null to skip rollback.
    return null;
  }

  // No reload to keep test simple.
}

/// Action that overrides shouldRollback to always rollback (even if state changed).
class SaveItemActionWithAlwaysRollback extends ReduxAction<AppState>
    with OptimisticCommand<AppState> {
  final String newItem;
  final Store<AppState> _store;
  final List<List<String>> stateChangesLog = [];

  SaveItemActionWithAlwaysRollback(this.newItem, this._store);

  @override
  Object? optimisticValue() => [...state.items, newItem];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) {
    final newItems = value as List<String>;
    stateChangesLog.add(newItems);
    return state.copy(items: newItems);
  }

  @override
  Future<void> sendCommandToServer(Object? newValue) async {
    await Future.delayed(const Duration(milliseconds: 10));
    // Another action changes the state during save.
    _store.dispatch(ChangeStateAction());
    await Future.delayed(const Duration(milliseconds: 10));
    throw const UserException('Save failed');
  }

  @override
  bool shouldRollback({
    required Object? currentValue,
    required Object? initialValue,
    required Object? optimisticValue,
    required Object error,
  }) {
    // Always rollback, regardless of whether state changed.
    return true;
  }

  // No reload to keep test simple.
}

/// Action that overrides shouldRollback to never rollback.
class SaveItemActionWithNeverRollback extends ReduxAction<AppState>
    with OptimisticCommand<AppState> {
  final String newItem;
  final List<List<String>> stateChangesLog = [];

  SaveItemActionWithNeverRollback(this.newItem);

  @override
  Object? optimisticValue() => [...state.items, newItem];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) {
    final newItems = value as List<String>;
    stateChangesLog.add(newItems);
    return state.copy(items: newItems);
  }

  @override
  Future<void> sendCommandToServer(Object? newValue) async {
    await Future.delayed(const Duration(milliseconds: 10));
    throw const UserException('Save failed');
  }

  @override
  bool shouldRollback({
    required Object? currentValue,
    required Object? initialValue,
    required Object? optimisticValue,
    required Object error,
  }) {
    // Never rollback.
    return false;
  }

  // No reload to keep test simple.
}

/// Action that overrides shouldRollback based on error type.
class SaveItemActionWithConditionalRollback extends ReduxAction<AppState>
    with OptimisticCommand<AppState> {
  final String newItem;
  final bool throwNetworkError;
  final List<List<String>> stateChangesLog = [];

  SaveItemActionWithConditionalRollback(this.newItem, {required this.throwNetworkError});

  @override
  Object? optimisticValue() => [...state.items, newItem];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) {
    final newItems = value as List<String>;
    stateChangesLog.add(newItems);
    return state.copy(items: newItems);
  }

  @override
  Future<void> sendCommandToServer(Object? newValue) async {
    await Future.delayed(const Duration(milliseconds: 10));
    if (throwNetworkError) {
      throw const UserException('Network error');
    } else {
      throw const UserException('Validation error');
    }
  }

  @override
  bool shouldRollback({
    required Object? currentValue,
    required Object? initialValue,
    required Object? optimisticValue,
    required Object error,
  }) {
    // Only rollback for validation errors, not network errors (might retry later).
    if (error is UserException && error.toString().contains('Network error')) {
      return false;
    }
    return true;
  }

  // No reload to keep test simple.
}

/// Action that overrides shouldReload to skip reload on success.
class SaveItemActionWithConditionalReload extends ReduxAction<AppState>
    with OptimisticCommand<AppState> {
  final String newItem;
  final bool shouldFail;
  final List<List<String>> stateChangesLog = [];
  bool reloadWasCalled = false;

  SaveItemActionWithConditionalReload(this.newItem, {required this.shouldFail});

  @override
  Object? optimisticValue() => [...state.items, newItem];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) {
    final newItems = value as List<String>;
    stateChangesLog.add(newItems);
    return state.copy(items: newItems);
  }

  @override
  Future<void> sendCommandToServer(Object? newValue) async {
    await Future.delayed(const Duration(milliseconds: 10));
    if (shouldFail) throw const UserException('Save failed');
  }

  @override
  bool shouldReload({
    required Object? currentValue,
    required Object? lastAppliedValue,
    required Object? optimisticValue,
    required Object? rollbackValue,
    required Object? error,
  }) {
    // Only reload on error, not on success.
    return error != null;
  }

  @override
  Future<Object?> reloadFromServer() async {
    reloadWasCalled = true;
    return ['reloaded'];
  }
}

/// Action that overrides shouldApplyReload to skip applying if state changed.
class SaveItemActionWithConditionalApplyReload extends ReduxAction<AppState>
    with OptimisticCommand<AppState> {
  final String newItem;
  final Store<AppState> _store;
  final bool changeStateDuringReload;
  final List<List<String>> stateChangesLog = [];

  SaveItemActionWithConditionalApplyReload(
    this.newItem,
    this._store, {
    required this.changeStateDuringReload,
  });

  @override
  Object? optimisticValue() => [...state.items, newItem];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) {
    final newItems = value as List<String>;
    stateChangesLog.add(newItems);
    return state.copy(items: newItems);
  }

  @override
  Future<void> sendCommandToServer(Object? newValue) async {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  @override
  bool shouldApplyReload({
    required Object? currentValue,
    required Object? lastAppliedValue,
    required Object? optimisticValue,
    required Object? rollbackValue,
    required Object? reloadResult,
    required Object? error,
  }) {
    // Only apply reload if state hasn't changed since we applied our value.
    return currentValue == lastAppliedValue;
  }

  @override
  Future<Object?> reloadFromServer() async {
    if (changeStateDuringReload) {
      // Simulate another action changing state while we're reloading.
      _store.dispatch(ChangeStateAction());
      await Future.delayed(const Duration(milliseconds: 10));
    }
    return ['reloaded'];
  }
}

/// Action that overrides applyReloadResultToState to transform reload result.
class SaveItemActionWithCustomApplyReload extends ReduxAction<AppState>
    with OptimisticCommand<AppState> {
  final String newItem;
  final List<List<String>> stateChangesLog = [];

  SaveItemActionWithCustomApplyReload(this.newItem);

  @override
  Object? optimisticValue() => [...state.items, newItem];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) {
    final newItems = value as List<String>;
    stateChangesLog.add(newItems);
    return state.copy(items: newItems);
  }

  @override
  Future<void> sendCommandToServer(Object? newValue) async {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  @override
  Future<Object?> reloadFromServer() async {
    // Return a map instead of a list (different shape than expected by applyValueToState).
    return {'items': ['server_item1', 'server_item2'], 'count': 2};
  }

  @override
  AppState? applyReloadResultToState(AppState state, Object? reloadResult) {
    // Transform the map result into what we need.
    final map = reloadResult as Map<String, dynamic>;
    final items = (map['items'] as List).cast<String>();
    // Add a marker to show we transformed the data.
    return state.copy(items: [...items, 'TRANSFORMED']);
  }
}

/// Action that overrides applyReloadResultToState to return null (skip applying).
class SaveItemActionWithApplyReloadReturningNull extends ReduxAction<AppState>
    with OptimisticCommand<AppState> {
  final String newItem;
  final List<List<String>> stateChangesLog = [];
  bool reloadWasCalled = false;

  SaveItemActionWithApplyReloadReturningNull(this.newItem);

  @override
  Object? optimisticValue() => [...state.items, newItem];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) {
    final newItems = value as List<String>;
    stateChangesLog.add(newItems);
    return state.copy(items: newItems);
  }

  @override
  Future<void> sendCommandToServer(Object? newValue) async {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  @override
  Future<Object?> reloadFromServer() async {
    reloadWasCalled = true;
    return ['reloaded'];
  }

  @override
  AppState? applyReloadResultToState(AppState state, Object? reloadResult) {
    // Return null to skip applying the reload result.
    return null;
  }
}

// -----------------------------------------------------------------------------
// Actions for edge case tests
// -----------------------------------------------------------------------------

/// Action where sendCommandToServer succeeds but reloadFromServer throws.
class SaveItemActionWithReloadThatThrows extends ReduxAction<AppState>
    with OptimisticCommand<AppState> {
  final String newItem;

  SaveItemActionWithReloadThatThrows(this.newItem);

  @override
  Object? optimisticValue() => [...state.items, newItem];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) =>
      state.copy(items: value as List<String>);

  @override
  Future<void> sendCommandToServer(Object? newValue) async {
    await Future.delayed(const Duration(milliseconds: 10));
    // Succeeds - no throw.
  }

  @override
  Future<Object?> reloadFromServer() async {
    throw const UserException('Reload failed');
  }
}

/// Action where both sendCommandToServer and reloadFromServer throw.
class SaveItemActionWithBothCommandAndReloadThatThrow extends ReduxAction<AppState>
    with OptimisticCommand<AppState> {
  final String newItem;

  SaveItemActionWithBothCommandAndReloadThatThrow(this.newItem);

  @override
  Object? optimisticValue() => [...state.items, newItem];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) =>
      state.copy(items: value as List<String>);

  @override
  Future<void> sendCommandToServer(Object? newValue) async {
    await Future.delayed(const Duration(milliseconds: 10));
    throw const UserException('Command failed');
  }

  @override
  Future<Object?> reloadFromServer() async {
    throw const UserException('Reload failed');
  }
}

/// Action that overrides shouldReload to return false when there's an error.
class SaveItemActionWithShouldReloadFalseOnError extends ReduxAction<AppState>
    with OptimisticCommand<AppState> {
  final String newItem;
  bool reloadWasCalled = false;

  SaveItemActionWithShouldReloadFalseOnError(this.newItem);

  @override
  Object? optimisticValue() => [...state.items, newItem];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) =>
      state.copy(items: value as List<String>);

  @override
  Future<void> sendCommandToServer(Object? newValue) async {
    await Future.delayed(const Duration(milliseconds: 10));
    throw const UserException('Command failed');
  }

  @override
  bool shouldReload({
    required Object? currentValue,
    required Object? lastAppliedValue,
    required Object? optimisticValue,
    required Object? rollbackValue,
    required Object? error,
  }) {
    // Skip reload when there's an error.
    return error == null;
  }

  @override
  Future<Object?> reloadFromServer() async {
    reloadWasCalled = true;
    return ['reloaded'];
  }
}

/// Action that overrides shouldApplyReload to return false when there's an error.
class SaveItemActionWithShouldApplyReloadFalseOnError extends ReduxAction<AppState>
    with OptimisticCommand<AppState> {
  final String newItem;
  bool reloadWasCalled = false;

  SaveItemActionWithShouldApplyReloadFalseOnError(this.newItem);

  @override
  Object? optimisticValue() => [...state.items, newItem];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) =>
      state.copy(items: value as List<String>);

  @override
  Future<void> sendCommandToServer(Object? newValue) async {
    await Future.delayed(const Duration(milliseconds: 10));
    throw const UserException('Command failed');
  }

  @override
  bool shouldApplyReload({
    required Object? currentValue,
    required Object? lastAppliedValue,
    required Object? optimisticValue,
    required Object? rollbackValue,
    required Object? reloadResult,
    required Object? error,
  }) {
    // Skip applying reload when there's an error.
    return error == null;
  }

  @override
  Future<Object?> reloadFromServer() async {
    reloadWasCalled = true;
    return ['reloaded'];
  }
}

/// Action that captures lastAppliedValue and rollbackValue on error.
class SaveItemActionCaptureLastAppliedOnError extends ReduxAction<AppState>
    with OptimisticCommand<AppState> {
  final String newItem;
  Object? capturedLastAppliedValue;
  Object? capturedRollbackValue;

  SaveItemActionCaptureLastAppliedOnError(this.newItem);

  @override
  Object? optimisticValue() => [...state.items, newItem];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) =>
      state.copy(items: value as List<String>);

  @override
  Future<void> sendCommandToServer(Object? newValue) async {
    await Future.delayed(const Duration(milliseconds: 10));
    throw const UserException('Command failed');
  }

  @override
  bool shouldReload({
    required Object? currentValue,
    required Object? lastAppliedValue,
    required Object? optimisticValue,
    required Object? rollbackValue,
    required Object? error,
  }) {
    // Capture the values for testing.
    capturedLastAppliedValue = lastAppliedValue;
    capturedRollbackValue = rollbackValue;
    return false; // Skip reload to simplify test.
  }
}

/// Action that captures lastAppliedValue on success.
class SaveItemActionCaptureLastAppliedOnSuccess extends ReduxAction<AppState>
    with OptimisticCommand<AppState> {
  final String newItem;
  Object? capturedLastAppliedValue;
  Object? capturedOptimisticValue;
  Object? capturedRollbackValue;

  SaveItemActionCaptureLastAppliedOnSuccess(this.newItem);

  @override
  Object? optimisticValue() {
    final value = [...state.items, newItem];
    capturedOptimisticValue = value;
    return value;
  }

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) =>
      state.copy(items: value as List<String>);

  @override
  Future<void> sendCommandToServer(Object? newValue) async {
    await Future.delayed(const Duration(milliseconds: 10));
    // Succeeds - no throw.
  }

  @override
  bool shouldReload({
    required Object? currentValue,
    required Object? lastAppliedValue,
    required Object? optimisticValue,
    required Object? rollbackValue,
    required Object? error,
  }) {
    // Capture the values for testing.
    capturedLastAppliedValue = lastAppliedValue;
    capturedRollbackValue = rollbackValue;
    return false; // Skip reload to simplify test.
  }
}

/// Action with Retry that counts optimisticValue and sendCommandToServer calls.
class SaveItemActionWithOptimisticValueCounter extends ReduxAction<AppState>
    with OptimisticCommand<AppState>, Retry<AppState> {
  final String newItem;
  final int failCount;
  int optimisticValueCallCount = 0;
  int sendCommandCallCount = 0;

  SaveItemActionWithOptimisticValueCounter(this.newItem, {required this.failCount});

  @override
  Duration get initialDelay => const Duration(milliseconds: 5);

  @override
  int get maxRetries => 10;

  @override
  Object? optimisticValue() {
    optimisticValueCallCount++;
    return [...state.items, newItem];
  }

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) =>
      state.copy(items: value as List<String>);

  @override
  Future<void> sendCommandToServer(Object? newValue) async {
    sendCommandCallCount++;
    await Future.delayed(const Duration(milliseconds: 5));
    if (sendCommandCallCount <= failCount) {
      throw UserException('Failed: attempt $sendCommandCallCount');
    }
  }

  // No reload to keep test simple.
}

/// Action that checks identity of optimisticValue passed to sendCommandToServer.
class SaveItemActionCheckIdentity extends ReduxAction<AppState>
    with OptimisticCommand<AppState> {
  final String newItem;
  Object? createdOptimisticValue;
  Object? receivedValueInSendCommand;

  SaveItemActionCheckIdentity(this.newItem);

  @override
  Object? optimisticValue() {
    // Create a new list and store reference for identity check.
    createdOptimisticValue = [...state.items, newItem];
    return createdOptimisticValue;
  }

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) =>
      state.copy(items: value as List<String>);

  @override
  Future<void> sendCommandToServer(Object? newValue) async {
    receivedValueInSendCommand = newValue;
    await Future.delayed(const Duration(milliseconds: 10));
  }

  // No reload to keep test simple.
}

// -----------------------------------------------------------------------------
// Actions for non-reentrant behavior tests
// -----------------------------------------------------------------------------

/// OptimisticCommand action with configurable delay (for testing non-reentrant behavior).
class OptimisticCommandSlowAction extends ReduxAction<AppState>
    with OptimisticCommand<AppState> {
  final String newItem;
  final int delayMillis;

  OptimisticCommandSlowAction(this.newItem, {required this.delayMillis});

  @override
  Object? optimisticValue() => [...state.items, newItem];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) =>
      state.copy(items: value as List<String>);

  @override
  Future<void> sendCommandToServer(Object? newValue) async {
    await Future.delayed(Duration(milliseconds: delayMillis));
  }

  // No reload to keep test simple.
}

/// OptimisticCommand action that always fails (for testing key release on failure).
class OptimisticCommandFailingAction extends ReduxAction<AppState>
    with OptimisticCommand<AppState> {
  @override
  Object? optimisticValue() => [...state.items, 'failing_item'];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) =>
      state.copy(items: value as List<String>);

  @override
  Future<void> sendCommandToServer(Object? newValue) async {
    await Future.delayed(const Duration(milliseconds: 10));
    throw const UserException('Intentional failure');
  }

  // No reload to keep test simple.
}

/// OptimisticCommand action that uses nonReentrantKeyParams to differentiate by itemId.
class OptimisticCommandWithParams extends ReduxAction<AppState>
    with OptimisticCommand<AppState> {
  final String itemId;
  final String value;
  final int delayMillis;

  OptimisticCommandWithParams(this.itemId, this.value, {required this.delayMillis});

  @override
  Object? nonReentrantKeyParams() => itemId;

  @override
  Object? optimisticValue() => [...state.items, value];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) =>
      state.copy(items: value as List<String>);

  @override
  Future<void> sendCommandToServer(Object? newValue) async {
    await Future.delayed(Duration(milliseconds: delayMillis));
  }

  // No reload to keep test simple.
}

/// OptimisticCommand action that uses nonReentrantKeyParams and always fails.
class OptimisticCommandWithParamsThatFails extends ReduxAction<AppState>
    with OptimisticCommand<AppState> {
  final String itemId;

  OptimisticCommandWithParamsThatFails(this.itemId);

  @override
  Object? nonReentrantKeyParams() => itemId;

  @override
  Object? optimisticValue() => [...state.items, 'failing_$itemId'];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) =>
      state.copy(items: value as List<String>);

  @override
  Future<void> sendCommandToServer(Object? newValue) async {
    await Future.delayed(const Duration(milliseconds: 10));
    throw const UserException('Intentional failure');
  }

  // No reload to keep test simple.
}

/// First OptimisticCommand action type that uses a shared non-reentrant key via computeNonReentrantKey.
class OptimisticCommandSharedKey1 extends ReduxAction<AppState>
    with OptimisticCommand<AppState> {
  final String value;
  final int delayMillis;

  OptimisticCommandSharedKey1(this.value, {required this.delayMillis});

  @override
  Object computeNonReentrantKey() => 'sharedOptimisticKey';

  @override
  Object? optimisticValue() => [...state.items, value];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) =>
      state.copy(items: value as List<String>);

  @override
  Future<void> sendCommandToServer(Object? newValue) async {
    await Future.delayed(Duration(milliseconds: delayMillis));
  }

  // No reload to keep test simple.
}

/// Second OptimisticCommand action type that uses the same shared non-reentrant key.
class OptimisticCommandSharedKey2 extends ReduxAction<AppState>
    with OptimisticCommand<AppState> {
  final String value;
  final int delayMillis;

  OptimisticCommandSharedKey2(this.value, {required this.delayMillis});

  @override
  Object computeNonReentrantKey() => 'sharedOptimisticKey';

  @override
  Object? optimisticValue() => [...state.items, value];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) =>
      state.copy(items: value as List<String>);

  @override
  Future<void> sendCommandToServer(Object? newValue) async {
    await Future.delayed(Duration(milliseconds: delayMillis));
  }

  // No reload to keep test simple.
}

/// OptimisticCommand action that also uses NonReentrant (should throw assertion error).
class OptimisticCommandWithNonReentrant extends ReduxAction<AppState>
    with OptimisticCommand<AppState>, NonReentrant<AppState> {
  final String newItem;

  OptimisticCommandWithNonReentrant(this.newItem);

  @override
  Object? optimisticValue() => [...state.items, newItem];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) =>
      state.copy(items: value as List<String>);

  @override
  Future<void> sendCommandToServer(Object? newValue) async {
    await Future.delayed(const Duration(milliseconds: 10));
  }
}

/// OptimisticCommand action that also uses Throttle (should throw assertion error).
class OptimisticCommandWithThrottle extends ReduxAction<AppState>
    with OptimisticCommand<AppState>, Throttle<AppState> {
  final String newItem;

  OptimisticCommandWithThrottle(this.newItem);

  @override
  Object? optimisticValue() => [...state.items, newItem];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) =>
      state.copy(items: value as List<String>);

  @override
  Future<void> sendCommandToServer(Object? newValue) async {
    await Future.delayed(const Duration(milliseconds: 10));
  }
}

/// OptimisticCommand action that also uses Fresh (should throw assertion error).
class OptimisticCommandWithFresh extends ReduxAction<AppState>
    with OptimisticCommand<AppState>, Fresh<AppState> {
  final String newItem;

  OptimisticCommandWithFresh(this.newItem);

  @override
  Object? optimisticValue() => [...state.items, newItem];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) =>
      state.copy(items: value as List<String>);

  @override
  Future<void> sendCommandToServer(Object? newValue) async {
    await Future.delayed(const Duration(milliseconds: 10));
  }
}
