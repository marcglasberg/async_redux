import 'package:async_redux/async_redux.dart';
import 'package:bdd_framework/bdd_framework.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var feature = BddFeature('StableSync mixin');

  // ==========================================================================
  // Case 1: Single dispatch applies optimistic update and sends request
  // ==========================================================================

  Bdd(feature)
      .scenario('Single dispatch applies optimistic update and sends request.')
      .given('An action with the StableSync mixin.')
      .when('The action is dispatched once.')
      .then('The optimistic update is applied immediately.')
      .and('The request is sent to the server.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(liked: false));
    requestLog.clear();

    await store.dispatchAndWait(ToggleLikeAction());

    expect(store.state.liked, true);
    expect(requestLog, ['saveValue(true)', 'onFinish()']);
  });

  // ==========================================================================
  // Case 2: Rapid dispatches apply all optimistic updates but coalesce requests
  // ==========================================================================

  Bdd(feature)
      .scenario(
          'Rapid dispatches apply all optimistic updates but coalesce requests.')
      .given('An action with the StableSync mixin.')
      .when('The action is dispatched multiple times rapidly.')
      .then('All optimistic updates are applied immediately.')
      .and('Only necessary requests are sent (coalesced).')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(liked: false));
    requestLog.clear();
    saveValueDelay = const Duration(milliseconds: 100);

    // Dispatch rapidly: false -> true -> false -> true
    store.dispatch(ToggleLikeAction()); // false -> true, sends request
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, true);

    store.dispatch(ToggleLikeAction()); // true -> false, locked
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, false);

    store.dispatch(ToggleLikeAction()); // false -> true, locked
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, true);

    // Wait for all requests to complete
    await store.waitAllActions([]);

    // Final state should be true (last toggle)
    expect(store.state.liked, true);

    // Request log: first sends true, no follow-up needed, then onFinish at end
    expect(requestLog, ['saveValue(true)', 'onFinish()']);

    saveValueDelay = Duration.zero;
  });

  // ==========================================================================
  // Case 3: Follow-up request sent when state differs after completion
  // ==========================================================================

  Bdd(feature)
      .scenario('Follow-up request sent when state differs after completion.')
      .given('An action with the StableSync mixin.')
      .when('The state changes while a request is in flight.')
      .and('The final state differs from what was sent.')
      .then('A follow-up request is sent with the new state.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(liked: false));
    requestLog.clear();
    saveValueDelay = const Duration(milliseconds: 100);

    // Dispatch: false -> true (sends request)
    store.dispatch(ToggleLikeAction());
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, true);

    // Dispatch while locked: true -> false
    store.dispatch(ToggleLikeAction());
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, false);

    // Wait for all to complete
    await store.waitAllActions([]);

    expect(store.state.liked, false);

    // First request sent true, then follow-up sent false, then onFinish at end
    expect(
        requestLog, ['saveValue(true)', 'saveValue(false)', 'onFinish()']);

    saveValueDelay = Duration.zero;
  });

  // ==========================================================================
  // Case 4: No follow-up when state returns to sent value
  // ==========================================================================

  Bdd(feature)
      .scenario('No follow-up when state returns to sent value.')
      .given('An action with the StableSync mixin.')
      .when('The state changes while a request is in flight.')
      .and('The state returns to the value that was sent.')
      .then('No follow-up request is sent.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(liked: false));
    requestLog.clear();
    saveValueDelay = const Duration(milliseconds: 100);

    // Dispatch: false -> true (sends request)
    store.dispatch(ToggleLikeAction());
    await Future.delayed(const Duration(milliseconds: 10));

    // Dispatch: true -> false
    store.dispatch(ToggleLikeAction());
    await Future.delayed(const Duration(milliseconds: 10));

    // Dispatch: false -> true (back to sent value)
    store.dispatch(ToggleLikeAction());
    await Future.delayed(const Duration(milliseconds: 10));

    await store.waitAllActions([]);

    expect(store.state.liked, true);
    // Only one request needed since final state matches sent value, then onFinish
    expect(requestLog, ['saveValue(true)', 'onFinish()']);

    saveValueDelay = Duration.zero;
  });

  // ==========================================================================
  // Case 5: Error calls onFinish and keeps optimistic state
  // ==========================================================================

  Bdd(feature)
      .scenario('Error calls onFinish and keeps optimistic state.')
      .given('An action with the StableSync mixin.')
      .when('The request fails.')
      .then('onFinish is called.')
      .and('The optimistic state remains.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(liked: false));
    requestLog.clear();
    shouldFail = true;

    await store.dispatchAndWait(ToggleLikeAction());

    // Optimistic update remains since no reload (onFinish is general-purpose)
    expect(store.state.liked, true);
    expect(requestLog, ['saveValue(true)', 'onFinish()']);

    shouldFail = false;
  });

  // ==========================================================================
  // Case 7: Different keys can have concurrent requests
  // ==========================================================================

  Bdd(feature)
      .scenario('Different keys can have concurrent requests.')
      .given('Actions with different stableSyncKeyParams.')
      .when('Both are dispatched concurrently.')
      .then('Both requests are sent in parallel.')
      .run((_) async {
    var store = Store<AppState>(
        initialState: AppState(liked: false, items: {'A': false, 'B': false}));
    requestLog.clear();
    saveValueDelay = const Duration(milliseconds: 100);

    // Dispatch for item A and B concurrently
    store.dispatch(ToggleLikeItemAction('A'));
    store.dispatch(ToggleLikeItemAction('B'));

    await Future.delayed(const Duration(milliseconds: 10));

    // Both optimistic updates applied
    expect(store.state.items['A'], true);
    expect(store.state.items['B'], true);

    await store.waitAllActions([]);

    // Both requests sent (not blocked by each other)
    expect(requestLog.contains('saveValue(A, true)'), true);
    expect(requestLog.contains('saveValue(B, true)'), true);

    saveValueDelay = Duration.zero;
  });

  // ==========================================================================
  // Case 8: Same key blocks concurrent requests
  // ==========================================================================

  Bdd(feature)
      .scenario('Same key blocks concurrent requests.')
      .given('Actions with the same stableSyncKeyParams.')
      .when('Both are dispatched while the first is in flight.')
      .then('The second does not send a request until the first completes.')
      .run((_) async {
    var store = Store<AppState>(
        initialState: AppState(liked: false, items: {'A': false}));
    requestLog.clear();
    saveValueDelay = const Duration(milliseconds: 100);

    // Dispatch twice for same item
    store.dispatch(ToggleLikeItemAction('A')); // false -> true
    await Future.delayed(const Duration(milliseconds: 10));
    store.dispatch(ToggleLikeItemAction('A')); // true -> false (locked)

    await Future.delayed(const Duration(milliseconds: 10));

    // Both optimistic updates applied
    expect(store.state.items['A'], false);

    // At this point, only one request should have started
    expect(requestLog, ['saveValue(A, true)']);

    await store.waitAllActions([]);

    // After completion, follow-up request sent, then onFinish at end
    expect(requestLog,
        ['saveValue(A, true)', 'saveValue(A, false)', 'onFinish(A)']);

    saveValueDelay = Duration.zero;
  });

  // ==========================================================================
  // Case 9: Lock is released after successful request
  // ==========================================================================

  Bdd(feature)
      .scenario('Lock is released after successful request.')
      .given('A StableSync action has completed successfully.')
      .when('The same action is dispatched again.')
      .then('A new request is sent (not blocked).')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(liked: false));
    requestLog.clear();

    // First dispatch
    await store.dispatchAndWait(ToggleLikeAction());
    expect(store.state.liked, true);
    expect(requestLog, ['saveValue(true)', 'onFinish()']);

    // Second dispatch after completion
    await store.dispatchAndWait(ToggleLikeAction());
    expect(store.state.liked, false);
    expect(requestLog, [
      'saveValue(true)',
      'onFinish()',
      'saveValue(false)',
      'onFinish()'
    ]);
  });

  // ==========================================================================
  // Case 10: Lock is released after failed request
  // ==========================================================================

  Bdd(feature)
      .scenario('Lock is released after failed request.')
      .given('A StableSync action has failed.')
      .when('The same action is dispatched again.')
      .then('A new request is sent (not blocked).')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(liked: false));
    requestLog.clear();
    shouldFail = true;

    // First dispatch (fails)
    await store.dispatchAndWait(ToggleLikeAction());
    expect(store.state.liked, true); // Optimistic state remains
    expect(requestLog, ['saveValue(true)', 'onFinish()']);

    // Second dispatch after failure
    shouldFail = false;
    await store.dispatchAndWait(ToggleLikeAction());
    expect(store.state.liked, false);
    expect(requestLog, [
      'saveValue(true)',
      'onFinish()',
      'saveValue(false)',
      'onFinish()'
    ]);
  });

  // ==========================================================================
  // Case 11: Multiple follow-up requests when state keeps changing
  // ==========================================================================

  Bdd(feature)
      .scenario('Multiple follow-up requests when state keeps changing.')
      .given('An action with the StableSync mixin.')
      .when('The state changes during each request.')
      .then('Follow-up requests are sent until state stabilizes.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(liked: false));
    requestLog.clear();

    var requestCount = 0;
    saveValueCallback = () async {
      requestCount++;
      await Future.delayed(const Duration(milliseconds: 50));
      // Toggle state during first two requests
      if (requestCount <= 2) {
        store.dispatch(ToggleLikeAction());
      }
    };

    await store.dispatchAndWait(ToggleLikeAction());

    // Should have sent multiple follow-up requests
    expect(requestLog.length, greaterThan(1));

    saveValueCallback = null;
  });

  // ==========================================================================
  // Case 12: StableSync cannot be combined with NonReentrant
  // ==========================================================================

  Bdd(feature)
      .scenario('StableSync cannot be combined with NonReentrant.')
      .given('An action that combines StableSync and NonReentrant.')
      .when('The action is dispatched.')
      .then('An assertion error is thrown.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(liked: false));

    expect(
      () => store.dispatch(StableSyncWithNonReentrantAction()),
      throwsA(isA<AssertionError>().having(
        (e) => e.message,
        'message',
        'The StableSync mixin cannot be combined with the NonReentrant mixin.',
      )),
    );
  });

  // ==========================================================================
  // Case 13: StableSync cannot be combined with Throttle
  // ==========================================================================

  Bdd(feature)
      .scenario('StableSync cannot be combined with Throttle.')
      .given('An action that combines StableSync and Throttle.')
      .when('The action is dispatched.')
      .then('An assertion error is thrown.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(liked: false));

    expect(
      () => store.dispatch(StableSyncWithThrottleAction()),
      throwsA(isA<AssertionError>().having(
        (e) => e.message,
        'message',
        'The StableSync mixin cannot be combined with the Throttle mixin.',
      )),
    );
  });

  // TODO: IGNORE
  // ==========================================================================
  // Case 14: StableSync cannot be combined with Debounce
  // ==========================================================================
  //
  // Bdd(feature)
  //     .scenario('StableSync cannot be combined with Debounce.')
  //     .given('An action that combines StableSync and Debounce.')
  //     .when('The action is dispatched.')
  //     .then('An assertion error is thrown.')
  //     .run((_) async {
  //   var store = Store<AppState>(initialState: AppState(liked: false));
  //
  //   expect(
  //     () => store.dispatch(StableSyncWithDebounceAction()),
  //     throwsA(isA<AssertionError>().having(
  //       (e) => e.message,
  //       'message',
  //       'The StableSync mixin cannot be combined with the Debounce mixin.',
  //     )),
  //   );
  // });

  // ==========================================================================
  // Case 15: StableSync cannot be combined with OptimisticUpdate
  // ==========================================================================

  Bdd(feature)
      .scenario('StableSync cannot be combined with OptimisticUpdate.')
      .given('An action that combines StableSync and OptimisticUpdate.')
      .when('The action is dispatched.')
      .then('An assertion error is thrown.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(liked: false));

    expect(
      () => store.dispatch(StableSyncWithOptimisticUpdateAction()),
      throwsA(isA<AssertionError>().having(
        (e) => e.message,
        'message',
        'The StableSync mixin cannot be combined with the OptimisticUpdate mixin.',
      )),
    );
  });

  // ==========================================================================
  // Case 16: StableSync cannot be combined with Fresh
  // ==========================================================================

  Bdd(feature)
      .scenario('StableSync cannot be combined with Fresh.')
      .given('An action that combines StableSync and Fresh.')
      .when('The action is dispatched.')
      .then('An assertion error is thrown.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(liked: false));

    expect(
      () => store.dispatch(StableSyncWithFreshAction()),
      throwsA(isA<AssertionError>().having(
        (e) => e.message,
        'message',
        'The StableSync mixin cannot be combined with the Fresh mixin.',
      )),
    );
  });

  // ==========================================================================
  // Case 17: computeStableSyncKey can be overridden to share keys
  // ==========================================================================

  Bdd(feature)
      .scenario('computeStableSyncKey can be overridden to share keys.')
      .given('Two different action types with the same computeStableSyncKey.')
      .when('Both are dispatched while the first is in flight.')
      .then('They share the same lock.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(liked: false, count: 0));
    requestLog.clear();
    saveValueDelay = const Duration(milliseconds: 100);

    // Dispatch first action type
    store.dispatch(SharedKeyAction1());
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.count, 1);

    // Dispatch second action type with same key (should be locked)
    store.dispatch(SharedKeyAction2());
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.count, 2); // Optimistic update applied

    // At this point, only first request sent
    expect(requestLog, ['saveValue(sharedKey, 1)']);

    await store.waitAllActions([]);

    // Follow-up with current value
    expect(requestLog, ['saveValue(sharedKey, 1)', 'saveValue(sharedKey, 2)']);

    saveValueDelay = Duration.zero;
  });

  // ==========================================================================
  // Case 18: State cleanup after store shutdown
  // ==========================================================================

  Bdd(feature)
      .scenario('Coalescing state is cleared on store shutdown.')
      .given('A StableSync action is in progress.')
      .when('The store is shut down.')
      .then('The coalescing state is cleared.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(liked: false));
    requestLog.clear();
    saveValueDelay = const Duration(milliseconds: 50);

    // Start a request
    store.dispatch(ToggleLikeAction());
    await Future.delayed(const Duration(milliseconds: 10));

    // Shutdown store
    store.shutdown();

    // Wait for old store's action to complete (it continues running even after shutdown)
    await Future.delayed(const Duration(milliseconds: 100));

    // Create new store - should have fresh coalescing state
    var newStore = Store<AppState>(initialState: AppState(liked: false));
    requestLog.clear();

    // Should be able to dispatch without being blocked by old state
    await newStore.dispatchAndWait(ToggleLikeAction());
    expect(newStore.state.liked, true);
    expect(requestLog, ['saveValue(true)', 'onFinish()']);

    saveValueDelay = Duration.zero;
  });
}

// =============================================================================
// Test state and helpers
// =============================================================================

class AppState {
  final bool liked;
  final Map<String, bool> items;
  final int count;

  AppState({
    required this.liked,
    this.items = const {},
    this.count = 0,
  });

  AppState copy({bool? liked, Map<String, bool>? items, int? count}) =>
      AppState(
        liked: liked ?? this.liked,
        items: items ?? this.items,
        count: count ?? this.count,
      );

  @override
  String toString() => 'AppState(liked: $liked, items: $items, count: $count)';
}

// Test control variables
List<String> requestLog = [];
Duration saveValueDelay = Duration.zero;
bool shouldFail = false;
Future<void> Function()? saveValueCallback;

// =============================================================================
// Test actions
// =============================================================================

/// Basic toggle like action.
class ToggleLikeAction extends ReduxAction<AppState>
    with StableSync<AppState, bool> {
  @override
  bool valueToApply() => !state.liked;

  @override
  bool getValueFromState(AppState state) => state.liked;

  @override
  AppState applyOptimisticValueToState(state, bool optimisticValueToApply) =>
      state.copy(liked: optimisticValueToApply);

  @override
  AppState applyServerResponseToState(state, Object? serverResponse) =>
      state.copy(liked: serverResponse as bool);

  @override
  Future<Object?> sendValueToServer(Object? value) async {
    requestLog.add('saveValue($value)');
    if (saveValueCallback != null) {
      await saveValueCallback!();
    } else if (saveValueDelay != Duration.zero) {
      await Future.delayed(saveValueDelay);
    }
    if (shouldFail) {
      throw const UserException('Send failed');
    }
    return null;
  }

  @override
  Future<AppState?> onFinish(Object? error) async {
    requestLog.add('onFinish()');
    return null;
  }
}

/// Toggle like for a specific item (uses stableSyncKeyParams).
class ToggleLikeItemAction extends ReduxAction<AppState>
    with StableSync<AppState, bool> {
  final String itemId;

  ToggleLikeItemAction(this.itemId);

  @override
  Object? stableSyncKeyParams() => itemId;

  @override
  bool valueToApply() => !(state.items[itemId] ?? false);

  @override
  bool getValueFromState(AppState state) => state.items[itemId] ?? false;

  @override
  AppState applyOptimisticValueToState(state, bool optimisticValueToApply) {
    final newItems = Map<String, bool>.from(state.items);
    newItems[itemId] = optimisticValueToApply;
    return state.copy(items: newItems);
  }

  @override
  AppState applyServerResponseToState(state, Object? serverResponse) {
    final newItems = Map<String, bool>.from(state.items);
    newItems[itemId] = serverResponse as bool;
    return state.copy(items: newItems);
  }

  @override
  Future<Object?> sendValueToServer(Object? value) async {
    requestLog.add('saveValue($itemId, $value)');
    if (saveValueDelay != Duration.zero) {
      await Future.delayed(saveValueDelay);
    }
    if (shouldFail) {
      throw const UserException('Send failed');
    }
    return null;
  }

  @override
  Future<AppState?> onFinish(Object? error) async {
    requestLog.add('onFinish($itemId)');
    return null;
  }
}

/// Action with shared key (type 1).
class SharedKeyAction1 extends ReduxAction<AppState>
    with StableSync<AppState, int> {
  @override
  Object computeStableSyncKey() => 'sharedKey';

  @override
  int valueToApply() => state.count + 1;

  @override
  int getValueFromState(AppState state) => state.count;

  @override
  AppState applyOptimisticValueToState(state, int optimisticValueToApply) =>
      state.copy(count: optimisticValueToApply);

  @override
  AppState applyServerResponseToState(state, Object? serverResponse) =>
      state.copy(count: serverResponse as int);

  @override
  Future<Object?> sendValueToServer(Object? value) async {
    requestLog.add('saveValue(sharedKey, $value)');
    if (saveValueDelay != Duration.zero) {
      await Future.delayed(saveValueDelay);
    }
    return null;
  }
}

/// Action with shared key (type 2).
class SharedKeyAction2 extends ReduxAction<AppState>
    with StableSync<AppState, int> {
  @override
  Object computeStableSyncKey() => 'sharedKey';

  @override
  int valueToApply() => state.count + 1;

  @override
  int getValueFromState(AppState state) => state.count;

  @override
  AppState applyOptimisticValueToState(state, int optimisticValueToApply) =>
      state.copy(count: optimisticValueToApply);

  @override
  AppState applyServerResponseToState(state, Object? serverResponse) =>
      state.copy(count: serverResponse as int);

  @override
  Future<Object?> sendValueToServer(Object? value) async {
    requestLog.add('saveValue(sharedKey, $value)');
    if (saveValueDelay != Duration.zero) {
      await Future.delayed(saveValueDelay);
    }
    return null;
  }
}

// =============================================================================
// Incompatible mixin combinations
// =============================================================================

class StableSyncWithNonReentrantAction extends ReduxAction<AppState>
    with
        StableSync<AppState, bool>,
        // ignore: private_collision_in_mixin_application
        NonReentrant {
  @override
  bool valueToApply() => !state.liked;

  @override
  bool getValueFromState(AppState state) => state.liked;

  @override
  AppState applyOptimisticValueToState(state, bool optimisticValueToApply) =>
      state.copy(liked: optimisticValueToApply);

  @override
  AppState applyServerResponseToState(state, Object? serverResponse) =>
      state.copy(liked: serverResponse as bool);

  @override
  Future<Object?> sendValueToServer(Object? value) async => null;
}

class StableSyncWithThrottleAction extends ReduxAction<AppState>
    with
        StableSync<AppState, bool>,
        // ignore: private_collision_in_mixin_application
        Throttle {
  @override
  bool valueToApply() => !state.liked;

  @override
  bool getValueFromState(AppState state) => state.liked;

  @override
  AppState applyOptimisticValueToState(state, bool optimisticValueToApply) =>
      state.copy(liked: optimisticValueToApply);

  @override
  AppState applyServerResponseToState(state, Object? serverResponse) =>
      state.copy(liked: serverResponse as bool);

  @override
  Future<Object?> sendValueToServer(Object? value) async => null;
}

class StableSyncWithDebounceAction extends ReduxAction<AppState>
    with
        StableSync<AppState, bool>,
        // ignore: private_collision_in_mixin_application
        Debounce {
  @override
  bool valueToApply() => !state.liked;

  @override
  bool getValueFromState(AppState state) => state.liked;

  @override
  AppState applyOptimisticValueToState(state, bool optimisticValueToApply) =>
      state.copy(liked: optimisticValueToApply);

  @override
  AppState applyServerResponseToState(state, Object? serverResponse) =>
      state.copy(liked: serverResponse as bool);

  @override
  Future<Object?> sendValueToServer(Object? value) async => null;
}

class StableSyncWithOptimisticUpdateAction extends ReduxAction<AppState>
    with
        OptimisticUpdate<AppState>,
        // ignore: private_collision_in_mixin_application
        StableSync<AppState, bool> {
  @override
  Object? newValue() => !state.liked;

  @override
  bool valueToApply() => !state.liked;

  @override
  bool getValueFromState(AppState state) => state.liked;

  @override
  AppState applyOptimisticValueToState(state, bool optimisticValueToApply) =>
      state.copy(liked: optimisticValueToApply);

  @override
  AppState applyServerResponseToState(state, Object? serverResponse) =>
      state.copy(liked: serverResponse as bool);

  @override
  AppState applyValueToState(AppState state, Object? value) =>
      state.copy(liked: value as bool);

  @override
  Future<Object?> sendValueToServer(Object? value) async => null;
}

class StableSyncWithFreshAction extends ReduxAction<AppState>
    with
        StableSync<AppState, bool>,
        // ignore: private_collision_in_mixin_application
        Fresh {
  @override
  bool valueToApply() => !state.liked;

  @override
  bool getValueFromState(AppState state) => state.liked;

  @override
  AppState applyOptimisticValueToState(state, bool optimisticValueToApply) =>
      state.copy(liked: optimisticValueToApply);

  @override
  AppState applyServerResponseToState(state, Object? serverResponse) =>
      state.copy(liked: serverResponse as bool);

  @override
  Future<Object?> sendValueToServer(Object? value) async => null;
}
