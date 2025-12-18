import 'package:async_redux/async_redux.dart';
import 'package:bdd_framework/bdd_framework.dart';
import 'package:flutter_test/flutter_test.dart' hide Retry;

void main() {
  var feature = BddFeature('Optimistic update actions');

  Bdd(feature)
      .scenario('OptimisticUpdate applies value, saves, and reloads.')
      .given('An action with OptimisticUpdate mixin.')
      .when('The action is dispatched and saveValue succeeds.')
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
      .scenario('OptimisticUpdate + Retry: retries saveValue only, no UI flickering.')
      .given('An action with both OptimisticUpdate and Retry mixins.')
      .and('saveValue fails the first 2 times, then succeeds.')
      .when('The action is dispatched.')
      .then('The optimistic value is applied only once at the start.')
      .and('saveValue is retried until it succeeds.')
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
      .scenario('OptimisticUpdate + Retry: rolls back only after all retries fail.')
      .given('An action with both OptimisticUpdate and Retry mixins.')
      .and('saveValue always fails (maxRetries = 3).')
      .when('The action is dispatched.')
      .then('The optimistic value stays in place during all retry attempts.')
      .and('Rollback happens only after all retries are exhausted.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: ['initial']));

    var action = SaveItemActionWithRetryThatAlwaysFails('new_item');
    await store.dispatchAndWait(action);

    // Final state should be rolled back (reloadValue doesn't throw, but rollback happens).
    // Note: The finally block still runs reloadValue even on failure.
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
      .scenario('OptimisticUpdate + UnlimitedRetries: retries until success.')
      .given('An action with OptimisticUpdate and UnlimitedRetries mixins.')
      .and('saveValue fails the first 5 times, then succeeds.')
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
      .scenario('OptimisticUpdate without Retry: normal behavior, no retry logic.')
      .given('An action with only OptimisticUpdate mixin (no Retry).')
      .and('saveValue fails.')
      .when('The action is dispatched.')
      .then('The action fails immediately without retrying.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(items: ['initial']));

    var action = SaveItemActionThatFails('new_item');
    await store.dispatchAndWait(action);

    // Note: reloadValue still runs in finally even on failure
    expect(action.status.isCompletedFailed, isTrue);
    expect(action.saveAttempts, 1); // Only 1 attempt, no retries
  });

  Bdd(feature)
      .scenario('OptimisticUpdate rolls back on failure.')
      .given('An action with OptimisticUpdate mixin.')
      .when('The action is dispatched and saveValue fails.')
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
      .scenario('OptimisticUpdate does NOT rollback if state changed by another action.')
      .given('An action with OptimisticUpdate mixin.')
      .and('Another action modifies the state during saveValue.')
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
    // Finally block still runs reloadValue.
    expect(action.stateChangesLog.last, ['reloaded']); // Reload in finally
    expect(action.rollbackOccurred, isFalse);
  });

  Bdd(feature)
      .scenario('OptimisticUpdate without reloadValue implementation.')
      .given('An action with OptimisticUpdate that does not implement reloadValue.')
      .when('The action is dispatched and saveValue succeeds.')
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
      .scenario('OptimisticUpdate without reloadValue: rollback on failure.')
      .given('An action with OptimisticUpdate that does not implement reloadValue.')
      .when('The action is dispatched and saveValue fails.')
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
      .scenario('OptimisticUpdate + Retry without reloadValue: no flickering.')
      .given('An action with OptimisticUpdate and Retry, but no reloadValue.')
      .and('saveValue fails the first 2 times, then succeeds.')
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

/// Basic OptimisticUpdate action that succeeds.
class SaveItemAction extends ReduxAction<AppState> with OptimisticUpdate<AppState> {
  final String newItem;
  final List<List<String>> stateChanges = [];

  SaveItemAction(this.newItem);

  @override
  Object? newValue() => [...state.items, newItem];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) {
    final newItems = value as List<String>;
    stateChanges.add(newItems);
    return state.copy(items: newItems);
  }

  @override
  Future<void> saveValue(Object? newValue) async {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  @override
  Future<Object?> reloadValue() async {
    await Future.delayed(const Duration(milliseconds: 10));
    return ['reloaded'];
  }
}

/// OptimisticUpdate action that always fails saveValue.
class SaveItemActionThatFails extends ReduxAction<AppState>
    with OptimisticUpdate<AppState> {
  final String newItem;
  int saveAttempts = 0;

  SaveItemActionThatFails(this.newItem);

  @override
  Object? newValue() => [...state.items, newItem];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) =>
      state.copy(items: value as List<String>);

  @override
  Future<void> saveValue(Object? newValue) async {
    saveAttempts++;
    await Future.delayed(const Duration(milliseconds: 10));
    throw const UserException('Save failed');
  }

  @override
  Future<Object?> reloadValue() async {
    return ['reloaded'];
  }
}

/// OptimisticUpdate action that fails and tracks state changes (for rollback test).
class SaveItemActionThatFailsWithStateLog extends ReduxAction<AppState>
    with OptimisticUpdate<AppState> {
  final String newItem;
  final List<List<String>> stateChangesLog = [];

  SaveItemActionThatFailsWithStateLog(this.newItem);

  @override
  Object? newValue() => [...state.items, newItem];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) {
    final newItems = value as List<String>;
    stateChangesLog.add(newItems);
    return state.copy(items: newItems);
  }

  @override
  Future<void> saveValue(Object? newValue) async {
    await Future.delayed(const Duration(milliseconds: 10));
    throw const UserException('Save failed');
  }

  @override
  Future<Object?> reloadValue() async {
    return ['reloaded'];
  }
}

/// OptimisticUpdate action that fails after another action changes the state.
/// This tests the conditional rollback logic.
class SaveItemActionThatFailsAfterStateChange extends ReduxAction<AppState>
    with OptimisticUpdate<AppState> {
  final String newItem;
  final Store<AppState> _store;
  final List<List<String>> stateChangesLog = [];
  bool rollbackOccurred = false;

  SaveItemActionThatFailsAfterStateChange(this.newItem, this._store);

  @override
  Object? newValue() => [...state.items, newItem];

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
  Future<void> saveValue(Object? newValue) async {
    await Future.delayed(const Duration(milliseconds: 10));
    // Another action changes the state during save.
    _store.dispatch(ChangeStateAction());
    await Future.delayed(const Duration(milliseconds: 10));
    throw const UserException('Save failed');
  }

  @override
  Future<Object?> reloadValue() async {
    return ['reloaded'];
  }
}

/// Action that changes the state (used to simulate concurrent modification).
class ChangeStateAction extends ReduxAction<AppState> {
  @override
  AppState reduce() => state.copy(items: ['changed_by_other']);
}

/// OptimisticUpdate action that does NOT implement reloadValue.
class SaveItemActionWithoutReload extends ReduxAction<AppState>
    with OptimisticUpdate<AppState> {
  final String newItem;
  final List<List<String>> stateChangesLog = [];

  SaveItemActionWithoutReload(this.newItem);

  @override
  Object? newValue() => [...state.items, newItem];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) {
    final newItems = value as List<String>;
    stateChangesLog.add(newItems);
    return state.copy(items: newItems);
  }

  @override
  Future<void> saveValue(Object? newValue) async {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  // reloadValue is intentionally NOT overridden - uses default that throws UnimplementedError.
}

/// OptimisticUpdate action that does NOT implement reloadValue and fails.
class SaveItemActionWithoutReloadThatFails extends ReduxAction<AppState>
    with OptimisticUpdate<AppState> {
  final String newItem;
  final List<List<String>> stateChangesLog = [];

  SaveItemActionWithoutReloadThatFails(this.newItem);

  @override
  Object? newValue() => [...state.items, newItem];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) {
    final newItems = value as List<String>;
    stateChangesLog.add(newItems);
    return state.copy(items: newItems);
  }

  @override
  Future<void> saveValue(Object? newValue) async {
    await Future.delayed(const Duration(milliseconds: 10));
    throw const UserException('Save failed');
  }

  // reloadValue is intentionally NOT overridden - uses default that throws UnimplementedError.
}

/// OptimisticUpdate + Retry action without reloadValue implementation.
class SaveItemActionWithRetryNoReload extends ReduxAction<AppState>
    with OptimisticUpdate<AppState>, Retry<AppState> {
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
  Object? newValue() => [...state.items, newItem];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) {
    final newItems = value as List<String>;
    stateChangesLog.add(newItems);
    return state.copy(items: newItems);
  }

  @override
  Future<void> saveValue(Object? newValue) async {
    _saveAttemptCount++;
    await Future.delayed(const Duration(milliseconds: 5));
    if (_saveAttemptCount <= failCount) {
      throw UserException('Save failed: attempt $_saveAttemptCount');
    }
  }

  // reloadValue is intentionally NOT overridden - uses default that throws UnimplementedError.
}

/// OptimisticUpdate + Retry action that fails [failCount] times then succeeds.
class SaveItemActionWithRetry extends ReduxAction<AppState>
    with OptimisticUpdate<AppState>, Retry<AppState> {
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
  Object? newValue() => [...state.items, newItem];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) {
    final newItems = value as List<String>;
    stateChangesLog.add(newItems);
    return state.copy(items: newItems);
  }

  @override
  Future<void> saveValue(Object? newValue) async {
    _saveAttemptCount++;
    await Future.delayed(const Duration(milliseconds: 5));
    if (_saveAttemptCount <= failCount) {
      throw UserException('Save failed: attempt $_saveAttemptCount');
    }
  }

  @override
  Future<Object?> reloadValue() async {
    await Future.delayed(const Duration(milliseconds: 5));
    return ['reloaded'];
  }
}

/// OptimisticUpdate + Retry action that always fails (tests rollback after exhausting retries).
class SaveItemActionWithRetryThatAlwaysFails extends ReduxAction<AppState>
    with OptimisticUpdate<AppState>, Retry<AppState> {
  final String newItem;
  final List<List<String>> stateChangesLog = [];

  SaveItemActionWithRetryThatAlwaysFails(this.newItem);

  @override
  Duration get initialDelay => const Duration(milliseconds: 5);

  @override
  int get maxRetries => 3;

  @override
  Object? newValue() => [...state.items, newItem];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) {
    final newItems = value as List<String>;
    stateChangesLog.add(newItems);
    return state.copy(items: newItems);
  }

  @override
  Future<void> saveValue(Object? newValue) async {
    await Future.delayed(const Duration(milliseconds: 5));
    throw const UserException('Save always fails');
  }

  @override
  Future<Object?> reloadValue() async {
    return ['reloaded'];
  }
}

/// OptimisticUpdate + UnlimitedRetries action.
class SaveItemActionWithUnlimitedRetry extends ReduxAction<AppState>
    with OptimisticUpdate<AppState>, Retry<AppState>, UnlimitedRetries<AppState> {
  final String newItem;
  final int failCount;
  int _saveAttemptCount = 0;
  final List<List<String>> stateChangesLog = [];

  SaveItemActionWithUnlimitedRetry(this.newItem, {required this.failCount});

  @override
  Duration get initialDelay => const Duration(milliseconds: 5);

  @override
  Object? newValue() => [...state.items, newItem];

  @override
  Object? getValueFromState(AppState state) => state.items;

  @override
  AppState applyValueToState(AppState state, Object? value) {
    final newItems = value as List<String>;
    stateChangesLog.add(newItems);
    return state.copy(items: newItems);
  }

  @override
  Future<void> saveValue(Object? newValue) async {
    _saveAttemptCount++;
    await Future.delayed(const Duration(milliseconds: 5));
    if (_saveAttemptCount <= failCount) {
      throw UserException('Save failed: attempt $_saveAttemptCount');
    }
  }

  @override
  Future<Object?> reloadValue() async {
    await Future.delayed(const Duration(milliseconds: 5));
    return ['reloaded'];
  }
}
