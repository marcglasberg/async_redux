import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:bdd_framework/bdd_framework.dart';
import 'package:flutter_test/flutter_test.dart' hide Retry;

void main() {
  var feature = BddFeature('OptimisticSync mixin');

  // ==========================================================================
  // Case 1: Single dispatch applies optimistic update and sends request
  // ==========================================================================

  Bdd(feature)
      .scenario('Single dispatch applies optimistic update and sends request.')
      .given('An action with the OptimisticSync mixin.')
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
      .given('An action with the OptimisticSync mixin.')
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
      .given('An action with the OptimisticSync mixin.')
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
    expect(requestLog, ['saveValue(true)', 'saveValue(false)', 'onFinish()']);

    saveValueDelay = Duration.zero;
  });

  // ==========================================================================
  // Case 4: No follow-up when state returns to sent value
  // ==========================================================================

  Bdd(feature)
      .scenario('No follow-up when state returns to sent value.')
      .given('An action with the OptimisticSync mixin.')
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
      .given('An action with the OptimisticSync mixin.')
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
  // Case 6: Different keys can have concurrent requests
  // ==========================================================================

  Bdd(feature)
      .scenario('Different keys can have concurrent requests.')
      .given('Actions with different optimisticSyncKeyParams.')
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
  // Case 7: Same key blocks concurrent requests
  // ==========================================================================

  Bdd(feature)
      .scenario('Same key blocks concurrent requests.')
      .given('Actions with the same optimisticSyncKeyParams.')
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
  // Case 8: Lock is released after successful request
  // ==========================================================================

  Bdd(feature)
      .scenario('Lock is released after successful request.')
      .given('A OptimisticSync action has completed successfully.')
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
    expect(requestLog,
        ['saveValue(true)', 'onFinish()', 'saveValue(false)', 'onFinish()']);
  });

  // ==========================================================================
  // Case 9: Lock is released after failed request
  // ==========================================================================

  Bdd(feature)
      .scenario('Lock is released after failed request.')
      .given('A OptimisticSync action has failed.')
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
    expect(requestLog,
        ['saveValue(true)', 'onFinish()', 'saveValue(false)', 'onFinish()']);
  });

  // ==========================================================================
  // Case 10: Multiple follow-up requests when state keeps changing
  // ==========================================================================

  Bdd(feature)
      .scenario('Multiple follow-up requests when state keeps changing.')
      .given('An action with the OptimisticSync mixin.')
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
  // Case 11: OptimisticSync cannot be combined with NonReentrant
  // ==========================================================================

  Bdd(feature)
      .scenario('OptimisticSync cannot be combined with NonReentrant.')
      .given('An action that combines OptimisticSync and NonReentrant.')
      .when('The action is dispatched.')
      .then('An assertion error is thrown.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(liked: false));

    expect(
      () => store.dispatch(OptimisticSyncWithNonReentrantAction()),
      throwsA(isA<AssertionError>().having(
        (e) => e.message,
        'message',
        'The OptimisticSync mixin cannot be combined with the NonReentrant mixin.',
      )),
    );
  });

  // ==========================================================================
  // Case 12: OptimisticSync cannot be combined with Throttle
  // ==========================================================================

  Bdd(feature)
      .scenario('OptimisticSync cannot be combined with Throttle.')
      .given('An action that combines OptimisticSync and Throttle.')
      .when('The action is dispatched.')
      .then('An assertion error is thrown.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(liked: false));

    expect(
      () => store.dispatch(OptimisticSyncWithThrottleAction()),
      throwsA(isA<AssertionError>().having(
        (e) => e.message,
        'message',
        'The OptimisticSync mixin cannot be combined with the Throttle mixin.',
      )),
    );
  });

  // ==========================================================================
  // Case 13: computeOptimisticSyncKey can be overridden to share keys
  // ==========================================================================

  Bdd(feature)
      .scenario('computeOptimisticSyncKey can be overridden to share keys.')
      .given(
          'Two different action types with the same computeOptimisticSyncKey.')
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
  // Case 14: State cleanup after store shutdown
  // ==========================================================================

  Bdd(feature)
      .scenario('Coalescing state is cleared on store shutdown.')
      .given('A OptimisticSync action is in progress.')
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

  // ==========================================================================
  // Case 15: OptimisticSync cannot be combined with Fresh
  // ==========================================================================

  Bdd(feature)
      .scenario('OptimisticSync cannot be combined with Fresh.')
      .given('An action that combines OptimisticSync and Fresh.')
      .when('The action is dispatched.')
      .then('An assertion error is thrown.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(liked: false));

    expect(
      () => store.dispatch(OptimisticSyncWithFreshAction()),
      throwsA(isA<AssertionError>().having(
        (e) => e.message,
        'message',
        'The OptimisticSync mixin cannot be combined with the Fresh mixin.',
      )),
    );
  });

  // ==========================================================================
  // Case 16: OptimisticSync cannot be combined with UnlimitedRetryCheckInternet
  // ==========================================================================

  Bdd(feature)
      .scenario(
          'OptimisticSync cannot be combined with UnlimitedRetryCheckInternet.')
      .given(
          'An action that combines OptimisticSync and UnlimitedRetryCheckInternet.')
      .when('The action is dispatched.')
      .then('An assertion error is thrown.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(liked: false));

    expect(
      () =>
          store.dispatch(OptimisticSyncWithUnlimitedRetryCheckInternetAction()),
      throwsA(isA<AssertionError>().having(
        (e) => e.message,
        'message',
        'The UnlimitedRetryCheckInternet mixin cannot be combined with the OptimisticSync mixin.',
      )),
    );
  });

  // ==========================================================================
  // Case 17: OptimisticSync cannot be combined with UnlimitedRetries
  // ==========================================================================

  Bdd(feature)
      .scenario('OptimisticSync cannot be combined with UnlimitedRetries.')
      .given('An action that combines OptimisticSync and UnlimitedRetries.')
      .when('The action is dispatched.')
      .then('An assertion error is thrown.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(liked: false));

    expect(
      () => store.dispatch(OptimisticSyncWithUnlimitedRetriesAction()),
      throwsA(isA<AssertionError>().having(
        (e) => e.message,
        'message',
        'The Retry mixin cannot be combined with the OptimisticSync mixin.',
      )),
    );
  });

  // ==========================================================================
  // Case 19: OptimisticSync cannot be combined with OptimisticSyncWithPush
  // ==========================================================================
  // NOTE: This combination now causes a COMPILE-TIME error because the two
  // mixins define sendValueToServer with different signatures:
  // - OptimisticSync: sendValueToServer(Object? optimisticValue)
  // - OptimisticSyncWithPush: sendValueToServer(Object? optimisticValue, int localRevision, int deviceId)
  //
  // This is actually BETTER than a runtime assertion error because it
  // catches the incompatibility at compile time. The test below is skipped
  // since we cannot even create such a class.
  //
  // To verify: try uncommenting OptimisticSyncWithOptimisticSyncWithPushAction
  // in this file and you'll get a compilation error.

  // ==========================================================================
  // Case 21: OptimisticSync cannot be combined with Debounce
  // ==========================================================================

  Bdd(feature)
      .scenario('OptimisticSync cannot be combined with Debounce.')
      .given('An action that combines OptimisticSync and Debounce.')
      .when('The action is dispatched.')
      .then('An assertion error is thrown.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(liked: false));

    expect(
      () => store.dispatch(OptimisticSyncWithDebounceAction()),
      throwsA(isA<AssertionError>().having(
        (e) => e.message,
        'message',
        'The OptimisticSync mixin cannot be combined with the Debounce mixin.',
      )),
    );
  });

  // ==========================================================================
  // Case 22: Server response is applied when non-null and state is stable
  // ==========================================================================

  Bdd(feature)
      .scenario(
          'Server response is applied when sendValueToServer returns a non-null response and state is stable.')
      .given(
          'An action with the OptimisticSync mixin where sendValueToServer returns a non-null response.')
      .when(
          'The action is dispatched once and no other dispatch happens while the request is in flight.')
      .then('The optimistic update is applied immediately.')
      .and(
          'After the request completes, applyServerResponseToState is applied using the server response.')
      .and('onFinish is called once after synchronization completes.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(liked: false, count: 0));
    requestLog.clear();

    // Dispatch action that returns server response
    await store.dispatchAndWait(ServerResponseAction(increment: 10));

    // Optimistic update was 10, but server returns 15 (normalized value)
    expect(store.state.count, 15);
    expect(requestLog, ['saveValue(10)', 'serverResponse(15)', 'onFinish()']);
  });

  // ==========================================================================
  // Case 23: Earlier server response does not overwrite newer local optimistic value
  // ==========================================================================

  Bdd(feature)
      .scenario(
          'An earlier server response does not overwrite a newer local optimistic value.')
      .given(
          'An action with the OptimisticSync mixin where sendValueToServer returns a non-null response.')
      .when('The action is dispatched and a request is in flight.')
      .and(
          'The action is dispatched again for the same key while the first request is still in flight.')
      .then(
          'The latest optimistic value remains visible after the second dispatch.')
      .and(
          'The response from the first request is not applied in a way that overwrites the newer optimistic value.')
      .and(
          'If a follow-up request is needed, only the final stabilized result is applied.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(liked: false, count: 0));
    requestLog.clear();
    saveValueDelay = const Duration(milliseconds: 100);

    // Dispatch first action: optimistic count = 10
    store.dispatch(ServerResponseAction(increment: 10));
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.count, 10, reason: 'First optimistic update');

    // Dispatch second action while first is in flight: optimistic count = 20
    store.dispatch(ServerResponseAction(increment: 10));
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.count, 20, reason: 'Second optimistic update');

    // Wait for all to complete
    await store.waitAllActions([]);

    // First request would have returned 15 (server normalized 10 to 15),
    // but that should NOT be applied because state changed while in flight.
    // A follow-up request was sent with 20, which server normalizes to 25.
    expect(store.state.count, 25, reason: 'Final state from follow-up');

    // Request log shows: first request, follow-up request, then only final serverResponse applied
    expect(requestLog,
        ['saveValue(10)', 'saveValue(20)', 'serverResponse(25)', 'onFinish()']);

    saveValueDelay = Duration.zero;
  });

  // ==========================================================================
  // Case 24: Server response is ignored when applyServerResponseToState returns null
  // ==========================================================================

  Bdd(feature)
      .scenario(
          'Server response is ignored when applyServerResponseToState returns null.')
      .given(
          'An action with the OptimisticSync mixin where sendValueToServer returns a non-null response.')
      .when('The action is dispatched and completes successfully.')
      .then('The optimistic update is applied immediately.')
      .and('The server response is not applied to the state.')
      .and('onFinish is still called after synchronization completes.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(liked: false, count: 0));
    requestLog.clear();

    // Dispatch action that ignores server response
    await store.dispatchAndWait(IgnoreServerResponseAction(increment: 10));

    // Optimistic update was 10, server returned 15, but it's ignored
    expect(store.state.count, 10, reason: 'Server response ignored');
    expect(requestLog, ['saveValue(10)', 'onFinish()']);
  });

  // ==========================================================================
  // Case 25: With multiple follow-ups, only the final server response is applied
  // ==========================================================================

  Bdd(feature)
      .scenario(
          'With multiple follow-up requests, only the final non-null server response is applied.')
      .given(
          'An action with the OptimisticSync mixin where sendValueToServer returns a non-null response.')
      .when(
          'The action is dispatched and the state changes during each request, causing multiple follow-up requests.')
      .then('Multiple requests are sent until the state stabilizes.')
      .and('Only the final server response is applied to the state.')
      .and('onFinish is called once after synchronization completes.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(liked: false, count: 0));
    requestLog.clear();

    var requestCount = 0;
    saveValueCallback = () async {
      requestCount++;
      await Future.delayed(const Duration(milliseconds: 50));
      // Dispatch again during the first two requests to force follow-ups
      if (requestCount <= 2) {
        store.dispatch(ServerResponseAction(increment: 10));
      }
    };

    // Initial dispatch: count goes from 0 to 10
    await store.dispatchAndWait(ServerResponseAction(increment: 10));

    // Should have sent 3 requests (initial + 2 follow-ups)
    // Only the final server response should be applied
    // Request chain: 10 -> server returns 15 (not applied, state changed to 20)
    //                20 -> server returns 25 (not applied, state changed to 30)
    //                30 -> server returns 35 (applied, state stable)
    expect(store.state.count, 35, reason: 'Only final server response applied');

    // Verify 3 saveValue calls, but only 1 serverResponse applied
    expect(requestLog.where((e) => e.startsWith('saveValue')).length, 3);
    expect(requestLog.where((e) => e.startsWith('serverResponse')).length, 1);
    expect(requestLog.last, 'onFinish()');

    saveValueCallback = null;
  });

  // ===========================================================================
  // Case 26: Bug demonstration WITHOUT revisions
  // ===========================================================================

  Bdd(feature)
      .scenario('BUG: Push can cause missed follow-up.')
      .given('An action WITHOUT revision tracking.')
      .when('User taps twice and push arrives between taps.')
      .then('OptimisticSync incorrectly thinks state is stable.')
      .note('With push we must use the `OptimisticSyncWithPush` mixin instead.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(liked: false));

    // Reset shared test controls to avoid bleed-over from previous scenarios.
    requestLog.clear();
    saveValueDelay = Duration.zero;
    shouldFail = false;
    saveValueCallback = null;
    requestCompleter = null;

    // Use completer to control when request completes
    final request1Completer = Completer<void>();
    requestCompleter = request1Completer;

    // Tap #1: liked=false -> liked=true (optimistic)
    store.dispatch(ToggleLikeAction());
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, true, reason: 'Tap #1 optimistic update');
    expect(requestLog, ['saveValue(true)']);

    // Tap #2 (while request 1 in flight): liked=true -> liked=false (optimistic)
    store.dispatch(ToggleLikeAction());
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, false, reason: 'Tap #2 optimistic update');

    // Push arrives (echo of request 1) - overwrites optimistic state!
    // This simulates a WebSocket push arriving before request completes
    store.dispatch(SimulatePushAction(liked: true));
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, true, reason: 'Push overwrote optimistic state');

    // Request 1 completes
    request1Completer.complete();
    await Future.delayed(const Duration(milliseconds: 50));

    // BUG: OptimisticSync sees store=true, sent=true, thinks it's stable!
    // No follow-up sent, final state is WRONG (user's last tap was false)
    expect(store.state.liked, true,
        reason: 'BUG: Final state is wrong (should be false)');
    expect(requestLog, ['saveValue(true)', 'onFinish()'],
        reason: 'BUG: No follow-up request sent');
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
    with OptimisticSync<AppState, bool> {
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
    } else if (requestCompleter != null) {
      // Allow tests to hold the request open until they manually complete it.
      final completer = requestCompleter!;
      requestCompleter = null;
      await completer.future;
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

/// Toggle like for a specific item (uses optimisticSyncKeyParams).
class ToggleLikeItemAction extends ReduxAction<AppState>
    with OptimisticSync<AppState, bool> {
  final String itemId;

  ToggleLikeItemAction(this.itemId);

  @override
  Object? optimisticSyncKeyParams() => itemId;

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

/// Action that returns a non-null server response.
/// Server "normalizes" the value by adding 5 (e.g., 10 becomes 15).
class ServerResponseAction extends ReduxAction<AppState>
    with OptimisticSync<AppState, int> {
  final int increment;

  ServerResponseAction({required this.increment});

  @override
  int valueToApply() => state.count + increment;

  @override
  int getValueFromState(AppState state) => state.count;

  @override
  AppState applyOptimisticValueToState(state, int optimisticValueToApply) =>
      state.copy(count: optimisticValueToApply);

  @override
  AppState? applyServerResponseToState(state, Object serverResponse) {
    requestLog.add('serverResponse($serverResponse)');
    return state.copy(count: serverResponse as int);
  }

  @override
  Future<Object?> sendValueToServer(Object? value) async {
    requestLog.add('saveValue($value)');
    if (saveValueCallback != null) {
      await saveValueCallback!();
    } else if (saveValueDelay != Duration.zero) {
      await Future.delayed(saveValueDelay);
    }
    // Server "normalizes" the value by adding 5
    return (value as int) + 5;
  }

  @override
  Future<AppState?> onFinish(Object? error) async {
    requestLog.add('onFinish()');
    return null;
  }
}

/// Action that returns a non-null server response but ignores it.
class IgnoreServerResponseAction extends ReduxAction<AppState>
    with OptimisticSync<AppState, int> {
  final int increment;

  IgnoreServerResponseAction({required this.increment});

  @override
  int valueToApply() => state.count + increment;

  @override
  int getValueFromState(AppState state) => state.count;

  @override
  AppState applyOptimisticValueToState(state, int optimisticValueToApply) =>
      state.copy(count: optimisticValueToApply);

  @override
  AppState? applyServerResponseToState(state, Object serverResponse) {
    // Intentionally return null to ignore the server response
    return null;
  }

  @override
  Future<Object?> sendValueToServer(Object? value) async {
    requestLog.add('saveValue($value)');
    // Server returns a value, but we'll ignore it
    return (value as int) + 5;
  }

  @override
  Future<AppState?> onFinish(Object? error) async {
    requestLog.add('onFinish()');
    return null;
  }
}

/// Action with shared key (type 1).
class SharedKeyAction1 extends ReduxAction<AppState>
    with OptimisticSync<AppState, int> {
  @override
  Object computeOptimisticSyncKey() => 'sharedKey';

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
    with OptimisticSync<AppState, int> {
  @override
  Object computeOptimisticSyncKey() => 'sharedKey';

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

class OptimisticSyncWithNonReentrantAction extends ReduxAction<AppState>
    with
        OptimisticSync<AppState, bool>,
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

class OptimisticSyncWithThrottleAction extends ReduxAction<AppState>
    with
        OptimisticSync<AppState, bool>,
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

class OptimisticSyncWithDebounceAction extends ReduxAction<AppState>
    with
        OptimisticSync<AppState, bool>,
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

class OptimisticSyncWithFreshAction extends ReduxAction<AppState>
    with
        OptimisticSync<AppState, bool>,
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

class OptimisticSyncWithUnlimitedRetryCheckInternetAction
    extends ReduxAction<AppState>
    with
        OptimisticSync<AppState, bool>,
        // ignore: private_collision_in_mixin_application
        UnlimitedRetryCheckInternet {
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

class OptimisticSyncWithUnlimitedRetriesAction extends ReduxAction<AppState>
    with
        OptimisticSync<AppState, bool>,
        // ignore: private_collision_in_mixin_application
        Retry<AppState>,
        // ignore: private_collision_in_mixin_application
        UnlimitedRetries<AppState> {
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

// This class is intentionally commented out because combining OptimisticSync
// and OptimisticSyncWithPush causes a COMPILE-TIME error due to conflicting
// sendValueToServer signatures. See Case 19 comment above.
//
// class OptimisticSyncWithOptimisticSyncWithPushAction
//     extends ReduxAction<AppState>
//     with
//         OptimisticSync<AppState, bool>,
//         OptimisticSyncWithPush<AppState, bool> {
//   @override
//   bool valueToApply() => !state.liked;
//
//   @override
//   bool getValueFromState(AppState state) => state.liked;
//
//   @override
//   AppState applyOptimisticValueToState(state, bool optimisticValueToApply) =>
//       state.copy(liked: optimisticValueToApply);
//
//   @override
//   AppState applyServerResponseToState(state, Object? serverResponse) =>
//       state.copy(liked: serverResponse as bool);
//
//   @override
//   Future<Object?> sendValueToServer(
//     Object? optimisticValue,
//     int localRevision,
//     int deviceId,
//   ) async =>
//       null;
//
//   @override
//   int getServerRevisionFromState(Object? key) => -1;
// }

// =============================================================================
// Push simulation actions
// =============================================================================

/// Simulates a push update WITHOUT revision tracking.
/// Used to demonstrate the bug.
class SimulatePushAction extends ReduxAction<AppState> {
  final bool liked;

  SimulatePushAction({required this.liked});

  @override
  AppState reduce() => state.copy(liked: liked);
}

Completer<void>? requestCompleter;
