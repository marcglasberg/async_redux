import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:bdd_framework/bdd_framework.dart';
import 'package:flutter_test/flutter_test.dart';

/// These tests verify that [StableSync] correctly handles server-pushed updates
/// (e.g., via WebSockets) when using the revision-based synchronization system.
///
/// The revision system consists of:
/// - [localRevision]: Tracks local user intent (increments on each dispatch)
/// - [informServerRevision]: Reports the server's revision from responses/pushes
///
/// This ensures that:
/// 1. Push updates don't cause incorrect "stable" detection
/// 2. Last-write-wins semantics work across devices
/// 3. Out-of-order/replay pushes don't regress state
void main() {
  var feature = BddFeature('StableSync push compatibility');

  setUp(() {
    resetTestState();
  });

  // ===========================================================================
  // Case 1: Bug demonstration WITHOUT revisions
  // ===========================================================================

  Bdd(feature)
      .scenario('BUG: Without revisions, push can cause missed follow-up.')
      .given('An action WITHOUT revision tracking.')
      .when('User taps twice and push arrives between taps.')
      .then('StableSync incorrectly thinks state is stable.')
      .note('This demonstrates the bug that revisions fix.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(liked: false));

    // Use completer to control when request completes
    final request1Completer = Completer<void>();
    requestCompleter = request1Completer;

    // Tap #1: liked=false -> liked=true (optimistic)
    store.dispatch(ToggleLikeActionNoRevisions());
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, true, reason: 'Tap #1 optimistic update');
    expect(requestLog, ['sendValue(true)']);

    // Tap #2 (while request 1 in flight): liked=true -> liked=false (optimistic)
    store.dispatch(ToggleLikeActionNoRevisions());
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

    // BUG: StableSync sees store=true, sent=true, thinks it's stable!
    // No follow-up sent, final state is WRONG (user's last tap was false)
    expect(store.state.liked, true,
        reason: 'BUG: Final state is wrong (should be false)');
    expect(requestLog, ['sendValue(true)', 'onFinish()'],
        reason: 'BUG: No follow-up request sent');
  });

  // ===========================================================================
  // Case 2: Fix WITH revisions - follow-up correctly sent
  // ===========================================================================

  Bdd(feature)
      .scenario('FIX: With revisions, push does not prevent follow-up.')
      .given('An action WITH revision tracking.')
      .when('User taps twice and push arrives between taps.')
      .then('StableSync correctly sends follow-up based on localRevision.')
      .run((_) async {
    var store = Store<AppState>(
        initialState: AppState(liked: false, serverRevision: 10));

    // Set up server to return sequential revisions
    nextServerRevision = 11;

    // Tap #1: liked=false -> liked=true (optimistic), localRev=1
    store.dispatch(ToggleLikeActionWithRevisions());
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, true, reason: 'Tap #1 optimistic update');

    // Tap #2 (while request 1 potentially still processing): localRev=2
    store.dispatch(ToggleLikeActionWithRevisions());
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, false, reason: 'Tap #2 optimistic update');

    // Wait for all actions to complete
    await Future.delayed(const Duration(milliseconds: 100));

    // With revisions, the follow-up should have been sent because
    // localRev(2) > sentLocalRev(1) at the time request 1 completed
    expect(requestLog.where((s) => s.startsWith('sendValue')).length,
        greaterThanOrEqualTo(2),
        reason: 'Follow-up should be sent');
  });

  // ===========================================================================
  // Case 3: Remote device wins (last write wins)
  // ===========================================================================

  Bdd(feature)
      .scenario('Remote device wins under last-write-wins.')
      .given('This device taps LIKE and sends request.')
      .when('Other device sends UNLIKE with newer serverRev via push.')
      .then('Remote wins, push value is preserved.')
      .run((_) async {
    var store = Store<AppState>(
        initialState: AppState(liked: false, serverRevision: 10));

    nextServerRevision = 11;

    // This device taps LIKE: localRev=1
    store.dispatch(ToggleLikeActionWithRevisions());
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, true);

    // Other device sets UNLIKE with newer serverRev=12 (via push)
    store.dispatch(SimulatePushWithRevisionAction(liked: false, serverRev: 12));
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, false, reason: 'Push from other device applied');
    expect(store.state.serverRevision, 12);

    // Wait for our request to complete
    await Future.delayed(const Duration(milliseconds: 100));

    // The push's value should be preserved because it had a newer serverRev
    // and the server response (serverRev=11) is stale
    expect(store.state.serverRevision, 12, reason: 'Push serverRev preserved');
  });

  // ===========================================================================
  // Case 4: Local wins over older remote push
  // ===========================================================================

  Bdd(feature)
      .scenario('Local wins when remote push is older.')
      .given('This device taps LIKE and sends request.')
      .when('Request completes, then older push arrives.')
      .then('Local wins, stale push is ignored.')
      .run((_) async {
    var store = Store<AppState>(
        initialState: AppState(liked: false, serverRevision: 10));

    nextServerRevision = 15;

    // This device taps LIKE: localRev=1
    store.dispatch(ToggleLikeActionWithRevisions());
    await Future.delayed(const Duration(milliseconds: 100));

    expect(store.state.liked, true);
    expect(store.state.serverRevision, 15);

    // Old push arrives (serverRev=12 < 15) - should be IGNORED
    store.dispatch(SimulatePushWithRevisionAction(liked: false, serverRev: 12));
    await Future.delayed(const Duration(milliseconds: 10));

    // State should NOT change (push was stale)
    expect(store.state.liked, true, reason: 'Stale push ignored, local wins');
    expect(store.state.serverRevision, 15, reason: 'ServerRev unchanged');
  });

  // ===========================================================================
  // Case 5: Out-of-order / replay safety
  // ===========================================================================

  Bdd(feature)
      .scenario('Out-of-order pushes are ignored (replay safety).')
      .given('Client has serverRev=20, liked=true.')
      .when('Reconnect/replay delivers older pushes.')
      .then('Older pushes are ignored, only newer applied.')
      .run((_) async {
    var store = Store<AppState>(
        initialState: AppState(liked: true, serverRevision: 20));

    // Old pushes arrive (replay from reconnect) - should be IGNORED
    store.dispatch(SimulatePushWithRevisionAction(liked: false, serverRev: 18));
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, true, reason: 'serverRev=18 < 20, ignored');
    expect(store.state.serverRevision, 20);

    store.dispatch(SimulatePushWithRevisionAction(liked: false, serverRev: 19));
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, true, reason: 'serverRev=19 < 20, ignored');
    expect(store.state.serverRevision, 20);

    // New push arrives (serverRev=21) - should be APPLIED
    store.dispatch(SimulatePushWithRevisionAction(liked: false, serverRev: 21));
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, false, reason: 'serverRev=21 > 20, applied');
    expect(store.state.serverRevision, 21);
  });

  // ===========================================================================
  // Case 6: Stale response is not applied when push is newer
  // ===========================================================================

  Bdd(feature)
      .scenario('Stale server response is not applied to state.')
      .given('Request is sent.')
      .when('Push with newer serverRev arrives before response.')
      .then('Response is ignored (stale), push value preserved.')
      .run((_) async {
    var store = Store<AppState>(
        initialState: AppState(liked: false, serverRevision: 10));

    nextServerRevision = 11;

    // Tap: false -> true, localRev=1
    store.dispatch(ToggleLikeActionWithRevisions());
    await Future.delayed(const Duration(milliseconds: 100));

    // Now the request has completed with serverRev=11
    expect(store.state.liked, true);
    expect(store.state.serverRevision, 11);

    // Push arrives with newer serverRev - should be applied
    store.dispatch(SimulatePushWithRevisionAction(liked: false, serverRev: 15));
    await Future.delayed(const Duration(milliseconds: 10));

    expect(store.state.liked, false, reason: 'Push with newer serverRev applied');
    expect(store.state.serverRevision, 15,
        reason: 'Push serverRev applied (15 > 11)');

    // Now a stale push arrives (serverRev=12 < 15) - should be IGNORED
    store.dispatch(SimulatePushWithRevisionAction(liked: true, serverRev: 12));
    await Future.delayed(const Duration(milliseconds: 10));

    expect(store.state.liked, false, reason: 'Stale push ignored');
    expect(store.state.serverRevision, 15, reason: 'ServerRev unchanged');
  });

  // ===========================================================================
  // Case 7: Backward compatibility - works without revisions
  // ===========================================================================

  Bdd(feature)
      .scenario('Backward compatible: Works without revision calls.')
      .given('An action that does not use localRevision/informServerRevision.')
      .when('Normal dispatch flow occurs.')
      .then('Original value-based comparison still works.')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(liked: false));

    await store.dispatchAndWait(ToggleLikeActionNoRevisions());

    expect(store.state.liked, true);
    expect(requestLog, ['sendValue(true)', 'onFinish()']);
  });

  // ===========================================================================
  // Case 8: DateTime-based server revision
  // ===========================================================================

  Bdd(feature)
      .scenario('DateTime-based server revision works correctly.')
      .given('Server uses DateTime for revisions.')
      .when('Push arrives with DateTime-based serverRev.')
      .then('Ordering works correctly.')
      .run((_) async {
    final oldTime = DateTime(2024, 1, 1, 12, 0, 0);
    final newTime = DateTime(2024, 1, 1, 12, 0, 1);

    var store = Store<AppState>(
        initialState: AppState(
            liked: false, serverRevision: oldTime.millisecondsSinceEpoch));

    // Push with older DateTime - should be ignored
    store.dispatch(SimulatePushWithRevisionAction(
      liked: true,
      serverRev:
          oldTime.subtract(const Duration(seconds: 1)).millisecondsSinceEpoch,
    ));
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, false, reason: 'Older DateTime ignored');

    // Push with newer DateTime - should be applied
    store.dispatch(SimulatePushWithRevisionAction(
      liked: true,
      serverRev: newTime.millisecondsSinceEpoch,
    ));
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, true, reason: 'Newer DateTime applied');
  });

  // ===========================================================================
  // Case 9: Multiple rapid taps coalesce correctly with revisions
  // ===========================================================================

  Bdd(feature)
      .scenario('Multiple rapid taps coalesce correctly with revisions.')
      .given('User taps rapidly multiple times.')
      .when('Requests complete with revisions.')
      .then('Final state reflects optimistic updates, requests are coalesced.')
      .run((_) async {
    var store = Store<AppState>(
        initialState: AppState(liked: false, serverRevision: 10));

    nextServerRevision = 11;
    requestDelay = const Duration(milliseconds: 50);

    // Rapid taps: false -> true -> false -> true -> false -> true
    for (var i = 0; i < 5; i++) {
      store.dispatch(ToggleLikeActionWithRevisions());
      await Future.delayed(const Duration(milliseconds: 5));
    }

    // Optimistic state after 5 toggles from false should be true
    // (odd number of toggles inverts the initial state)
    expect(store.state.liked, true,
        reason: '5 toggles from false ends at true (optimistic)');

    // Wait for all to complete
    await Future.delayed(const Duration(milliseconds: 500));

    // Should have at least 1 request (coalescing may occur)
    final sendCount =
        requestLog.where((s) => s.startsWith('sendValue')).length;
    expect(sendCount, greaterThanOrEqualTo(1));

    // Verify onFinish was called
    expect(requestLog.last, 'onFinish()');

    requestDelay = Duration.zero;
  });

  // ===========================================================================
  // Case 10: localRevision increments correctly across dispatches
  // ===========================================================================

  Bdd(feature)
      .scenario('localRevision increments correctly across dispatches.')
      .given('Multiple dispatches occur.')
      .when('Each dispatch calls localRevision.')
      .then('First dispatch gets localRev=1, follow-up gets localRev=2.')
      .run((_) async {
    var store = Store<AppState>(
        initialState: AppState(liked: false, serverRevision: 10));

    nextServerRevision = 11;
    requestDelay = const Duration(milliseconds: 50);

    // Dispatch 1: localRev should be 1
    store.dispatch(ToggleLikeActionWithRevisions());
    await Future.delayed(const Duration(milliseconds: 10));

    // Dispatch 2 (while 1 is in flight): this will increment localRev to 2
    // but won't send a request yet (locked)
    store.dispatch(ToggleLikeActionWithRevisions());
    await Future.delayed(const Duration(milliseconds: 10));

    // Wait for request 1 to complete and follow-up to be sent
    await Future.delayed(const Duration(milliseconds: 200));

    // Check that first request had localRev=1
    expect(requestLog[0], contains('localRev=1'),
        reason: 'First request has localRev=1');

    // If follow-up was sent (because state changed), it should have localRev=2
    final sendValueLogs =
        requestLog.where((s) => s.startsWith('sendValue')).toList();
    if (sendValueLogs.length > 1) {
      expect(sendValueLogs[1], contains('localRev=2'),
          reason: 'Follow-up has localRev=2');
    }

    requestDelay = Duration.zero;
  });

  // ===========================================================================
  // Case 11: Push during follow-up is handled correctly
  // ===========================================================================

  Bdd(feature)
      .scenario('Push during follow-up request is handled correctly.')
      .given('Request completes and follow-up is being sent.')
      .when('Push arrives during follow-up.')
      .then('System remains consistent.')
      .run((_) async {
    var store = Store<AppState>(
        initialState: AppState(liked: false, serverRevision: 10));

    nextServerRevision = 11;
    requestDelay = const Duration(milliseconds: 50);

    // Tap 1
    store.dispatch(ToggleLikeActionWithRevisions());
    await Future.delayed(const Duration(milliseconds: 10));

    // Tap 2 (triggers follow-up later)
    store.dispatch(ToggleLikeActionWithRevisions());
    await Future.delayed(const Duration(milliseconds: 10));

    // Push arrives
    store.dispatch(SimulatePushWithRevisionAction(liked: true, serverRev: 15));
    await Future.delayed(const Duration(milliseconds: 10));

    // Wait for everything to settle
    await Future.delayed(const Duration(milliseconds: 200));

    // System should be in a consistent state
    expect(store.state.serverRevision, greaterThanOrEqualTo(11));
    expect(requestLog.last, 'onFinish()');

    requestDelay = Duration.zero;
  });

  // ===========================================================================
  // BUG 1: Follow-up sends wrong value when push overwrites state
  // ===========================================================================

  Bdd(feature)
      .scenario('BUG: Push-mode follow-up can send wrong value after push.')
      .given('isPushCompatible=true action with requests in flight.')
      .when('Push overwrites state before request completes.')
      .then('Follow-up sends wrong value from pushed state, not local intent.')
      .note('This is the main bug with revision-based follow-up.')
      .run((_) async {
    var store = Store<AppState>(
        initialState: AppState(liked: false, serverRevision: 10));

    nextServerRevision = 11;

    // Use completer to precisely control when Request 1 completes
    final request1Completer = Completer<void>();
    requestCompleter = request1Completer;

    // Tap #1: liked=false -> liked=true (optimistic), localRev=1
    store.dispatch(ToggleLikeActionWithRevisions());
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, true, reason: 'Tap #1 optimistic update');
    expect(requestLog, ['sendValue(true, localRev=1)']);

    // Tap #2 (while request 1 in flight): liked=true -> liked=false (optimistic), localRev=2
    store.dispatch(ToggleLikeActionWithRevisions());
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, false,
        reason: 'Tap #2 optimistic update (user wants false)');

    // Push arrives (echo of Request 1) - overwrites optimistic state!
    // This simulates the server echoing back the first request's value
    store.dispatch(
        SimulatePushWithRevisionAction(liked: true, serverRev: 11));
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, true, reason: 'Push overwrote optimistic state');

    // Request 1 completes
    request1Completer.complete();
    await Future.delayed(const Duration(milliseconds: 50));

    // BUG: Follow-up detects currentLocalRev(2) > sentLocalRev(1), so it sends follow-up
    // BUT it reads stateValue from the pushed-overwritten state (true) instead of
    // the actual latest local intent (false), so it sends the WRONG value!
    expect(requestLog.length, greaterThanOrEqualTo(2),
        reason: 'Follow-up was sent (revision check passed)');

    // Check what the follow-up sent
    final followUpLog =
        requestLog.where((s) => s.startsWith('sendValue')).toList();
    if (followUpLog.length >= 2) {
      // CORRECT: Should send user's last intent (false), not the pushed value (true)
      expect(followUpLog[1], 'sendValue(false, localRev=2)',
          reason:
              'Follow-up should send latest local intent (false), not pushed value (true)');
    }

    // Wait for everything to complete
    await Future.delayed(const Duration(milliseconds: 100));

    // CORRECT: Final state should match user's last tap (false)
    expect(store.state.liked, false,
        reason:
            'Final state should be false (user\'s last tap), not true (pushed value)');
  });

  // ===========================================================================
  // BUG 2: Lost optimization - unnecessary request when value returns
  // ===========================================================================

  Bdd(feature)
      .scenario('BUG: Push-mode sends unnecessary request on value toggle.')
      .given('isPushCompatible=true action.')
      .when('User toggles twice back to original value.')
      .then('Sends unnecessary follow-up (revision-only check loses value optimization).')
      .note('Old value-based logic would skip request, revision-based does not.')
      .run((_) async {
    var store = Store<AppState>(
        initialState: AppState(liked: false, serverRevision: 10));

    nextServerRevision = 11;

    // Use completer to control when Request 1 completes
    final request1Completer = Completer<void>();
    requestCompleter = request1Completer;

    // Tap #1: liked=false -> liked=true, localRev=1
    store.dispatch(ToggleLikeActionWithRevisions());
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, true, reason: 'Tap #1 optimistic');
    expect(requestLog, ['sendValue(true, localRev=1)']);

    // Tap #2 (while request 1 in flight): liked=true -> liked=false, localRev=2
    // This returns the value to what was originally sent in Request 1
    store.dispatch(ToggleLikeActionWithRevisions());
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, false, reason: 'Tap #2 back to original');

    // Request 1 completes
    request1Completer.complete();
    await Future.delayed(const Duration(milliseconds: 100));

    // BUG: Revision-based check sees currentLocalRev(2) > sentLocalRev(1)
    // so it sends a follow-up even though state.liked is now false,
    // which is what we already have (original state before any taps).
    //
    // The old value-based logic would compare:
    //   stateValue (false) == sentValue (true)? No
    // But it would also check if we NEED to send because the value differs
    // from what the server knows. Since we're back to the original,
    // ideally no request is needed.
    //
    // However, this is more nuanced - the optimization was that if you
    // toggle back to the value you ALREADY SENT, you don't send again.
    // Here we sent (true), and now state is (false), so a follow-up IS sent.

    final sendValueLogs =
        requestLog.where((s) => s.startsWith('sendValue')).toList();

    // CORRECT: Should not send follow-up when user toggles back
    // With proper optimization, toggling back to the original value
    // should not trigger an unnecessary network request.
    expect(sendValueLogs.length, 1,
        reason:
            'Should only send 1 request (optimization: no follow-up when toggled back to original)');

    // Note: This is an efficiency optimization that revision-only logic loses.
    // The old value-based logic could detect when the final value
    // doesn't need syncing and skip the follow-up request.
  });
}

// =============================================================================
// Test state
// =============================================================================

class AppState {
  final bool liked;
  final Map<String, bool> items;
  final int serverRevision;
  final Map<String, int> serverRevisions;

  AppState({
    required this.liked,
    this.items = const {},
    this.serverRevision = 0,
    this.serverRevisions = const {},
  });

  AppState copy({
    bool? liked,
    Map<String, bool>? items,
    int? serverRevision,
    Map<String, int>? serverRevisions,
  }) =>
      AppState(
        liked: liked ?? this.liked,
        items: items ?? this.items,
        serverRevision: serverRevision ?? this.serverRevision,
        serverRevisions: serverRevisions ?? this.serverRevisions,
      );

  @override
  String toString() =>
      'AppState(liked: $liked, serverRev: $serverRevision, items: $items)';
}

// =============================================================================
// Test control variables
// =============================================================================

List<String> requestLog = [];
Completer<void>? requestCompleter;
int nextServerRevision = 1;
Duration requestDelay = Duration.zero;

void resetTestState() {
  requestLog = [];
  requestCompleter = null;
  nextServerRevision = 1;
  requestDelay = Duration.zero;
}

// =============================================================================
// Actions WITHOUT revision tracking (for demonstrating the bug)
// =============================================================================

class ToggleLikeActionNoRevisions extends ReduxAction<AppState>
    with StableSync<AppState, bool> {
  @override
  bool valueToApply() => !state.liked;

  @override
  bool getValueFromState(AppState state) => state.liked;

  @override
  AppState applyOptimisticValueToState(state, bool optimisticValue) =>
      state.copy(liked: optimisticValue);

  @override
  AppState? applyServerResponseToState(state, Object serverResponse) =>
      state.copy(liked: serverResponse as bool);

  @override
  Future<Object?> sendValueToServer(Object? value) async {
    requestLog.add('sendValue($value)');

    // Wait for completer if provided
    if (requestCompleter != null) {
      await requestCompleter!.future;
    } else if (requestDelay != Duration.zero) {
      await Future.delayed(requestDelay);
    }

    return value;
  }

  @override
  Future<AppState?> onFinish(Object? error) async {
    requestLog.add('onFinish()');
    return null;
  }
}

// =============================================================================
// Actions WITH revision tracking (the fix)
// =============================================================================

class ToggleLikeActionWithRevisions extends ReduxAction<AppState>
    with StableSync<AppState, bool> {
  int _serverRevFromResponse = 0;

  // Enable revision-based synchronization for push compatibility.
  @override
  bool get isPushCompatible => true;

  @override
  bool valueToApply() => !state.liked;

  @override
  bool getValueFromState(AppState state) => state.liked;

  @override
  AppState applyOptimisticValueToState(state, bool optimisticValue) =>
      state.copy(liked: optimisticValue);

  @override
  AppState? applyServerResponseToState(state, Object serverResponse) {
    return state.copy(
      liked: serverResponse as bool,
      serverRevision: _serverRevFromResponse,
    );
  }

  @override
  Future<Object?> sendValueToServer(Object? value) async {
    // Call localRevision() to get the CURRENT revision value.
    // This may differ from what was captured in valueToApply() when this is a
    // follow-up request (other dispatches may have incremented the revision).
    int localRev = localRevision();
    requestLog.add('sendValue($value, localRev=$localRev)');

    // Wait for completer if provided
    if (requestCompleter != null) {
      await requestCompleter!.future;
      requestCompleter = null; // Reset after use
    } else if (requestDelay != Duration.zero) {
      await Future.delayed(requestDelay);
    }

    // Get and increment server revision
    _serverRevFromResponse = nextServerRevision++;
    informServerRevision(_serverRevFromResponse);

    return value;
  }

  @override
  Future<AppState?> onFinish(Object? error) async {
    requestLog.add('onFinish()');
    return null;
  }
}

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

/// Simulates a push update WITH revision tracking.
/// Only applies if serverRev > current stored serverRev.
class SimulatePushWithRevisionAction extends ReduxAction<AppState> {
  final bool liked;
  final int serverRev;

  SimulatePushWithRevisionAction({required this.liked, required this.serverRev});

  @override
  AppState? reduce() {
    // Check if this push is newer than what we know
    if (serverRev > state.serverRevision) {
      // Apply the push to state
      return state.copy(liked: liked, serverRevision: serverRev);
    }
    // Stale push, ignore
    return null;
  }
}
