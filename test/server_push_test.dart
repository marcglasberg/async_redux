import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:async_redux/src/optimistic_sync_with_push_mixin.dart';
import 'package:bdd_framework/bdd_framework.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var feature = BddFeature('ServerPush + OptimisticSyncWithPush missing scenarios');

  setUp(() {
    resetTestState();
  });

  Bdd(feature)
      .scenario('BUG: Remote newer push can be overwritten by local follow-up.')
      .given('A OptimisticSyncWithPush action has a request in flight '
          'and localRevision advanced.')
      .when('A ServerPush arrives with a newer serverRevision from another '
          'device before the request completes.')
      .then('The mixin must not send a follow-up that fights the '
          'newer serverRevision.')
      .note('Last write wins: newer serverRevision supersedes pending local '
          'intent for that key.')
      .run((_) async {
    var store = Store<AppState>(
        initialState: AppState(liked: false, serverRevision: 10));

    nextServerRevision = 11;

    final req1 = Completer<void>();
    requestCompleter = req1;

    // Tap #1: false -> true, localRev=1, request in flight.
    store.dispatch(ToggleLikeStableAction());
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, true);

    // Tap #2 while in flight: true -> false, localRev=2 (pending local intent differs from sent).
    store.dispatch(ToggleLikeStableAction());
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, false);

    // Remote device push arrives with much newer serverRev, and a different value.
    store.dispatch(PushLikeUpdate(liked: true, serverRev: 50));
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, true);
    expect(store.state.serverRevision, 50);

    // Complete request #1 (serverRev=11, should be stale vs 50).
    req1.complete();
    await Future.delayed(const Duration(milliseconds: 200));

    final sendValueLogs =
        requestLog.where((s) => s.startsWith('sendValue(')).toList();

    // Correct: no follow-up should be sent to override a newer serverRevision.
    expect(sendValueLogs.length, 1,
        reason:
            'Should not fight newer serverRevision with a follow-up request.');

    // Correct: remote push remains the final truth.
    expect(store.state.liked, true);
    expect(store.state.serverRevision, 50);
  });

  Bdd(feature)
      .scenario('ServerPush does not increment localRevision.')
      .given('A OptimisticSyncWithPush action where requests log localRev values.')
      .when('A ServerPush action is dispatched between local taps.')
      .then('The next local request uses the next localRevision '
          'as if the push never happened.')
      .note('Pushes must not be treated as local intent.')
      .run((_) async {
    var store = Store<AppState>(
        initialState: AppState(liked: false, serverRevision: 10));

    nextServerRevision = 11;

    await store.dispatchAndWait(ToggleLikeStableAction());
    expect(requestLog.where((s) => s.startsWith('sendValue(')).length, 1);

    store.dispatch(PushLikeUpdate(liked: false, serverRev: 99));
    await Future.delayed(const Duration(milliseconds: 10));

    await store.dispatchAndWait(ToggleLikeStableAction());

    final sendValueLogs =
        requestLog.where((s) => s.startsWith('sendValue(')).toList();
    expect(sendValueLogs.length, 2);

    expect(sendValueLogs[0], contains('localRev=1'));
    expect(sendValueLogs[1], contains('localRev=2'),
        reason: 'Push must not consume a local revision number.');
  });

  Bdd(feature)
      .scenario(
          'ServerPush applies immediately even while the stable-sync key is locked.')
      .given('A OptimisticSyncWithPush action has a request in flight for a key.')
      .when(
          'A ServerPush arrives for the same key with a newer serverRevision.')
      .then(
          'The pushed value is applied immediately and the stale response is ignored.')
      .note(
          'Immediate apply is required even when locked; staleness must be deterministic.')
      .run((_) async {
    var store = Store<AppState>(
        initialState: AppState(liked: false, serverRevision: 10));

    nextServerRevision = 11;

    final req1 = Completer<void>();
    requestCompleter = req1;

    // Tap #1: optimistic true, request in flight.
    store.dispatch(ToggleLikeStableAction());
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, true);

    // Push arrives while locked: apply immediately.
    store.dispatch(PushLikeUpdate(liked: false, serverRev: 12));
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, false);
    expect(store.state.serverRevision, 12);

    // Complete request (serverRev=11) -> must be ignored as stale.
    req1.complete();
    await Future.delayed(const Duration(milliseconds: 200));

    expect(store.state.liked, false);
    expect(store.state.serverRevision, 12);
  });

  Bdd(feature)
      .scenario(
          'ServerPush keying: push for item B does not interfere with item A in flight.')
      .given('Two OptimisticSync keys A and B, and a request is in flight for A.')
      .when('A ServerPush arrives for B and then for A.')
      .then(
          'Both pushes apply immediately to their own keys and do not affect the other key lock or revisions.')
      .note(
          'Verifies optimisticSyncKeyParams and computeOptimisticSyncKey alignment between OptimisticSyncWithPush and ServerPush.')
      .run((_) async {
    var store = Store<AppStateItems>(initialState: AppStateItems.initial());

    nextServerRevision = 1;

    final reqA = Completer<void>();
    requestCompleterByItem['A'] = reqA;

    // Start request for A (locked for key A).
    store.dispatch(ToggleLikeItemStableAction('A'));
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.likedById['A'], true);

    // Push for B applies immediately (independent key).
    store.dispatch(PushItemLikeUpdate(itemId: 'B', liked: true, serverRev: 5));
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.likedById['B'], true);
    expect(store.state.serverRevById['B'], 5);

    // Push for A applies immediately even though A is locked.
    store.dispatch(PushItemLikeUpdate(itemId: 'A', liked: false, serverRev: 6));
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.likedById['A'], false);
    expect(store.state.serverRevById['A'], 6);

    // Complete request for A (will return serverRev=1, stale vs 6 -> should be ignored).
    reqA.complete();
    await Future.delayed(const Duration(milliseconds: 200));

    expect(store.state.likedById['A'], false);
    expect(store.state.serverRevById['A'], 6);

    // Ensure B stayed untouched by A completion.
    expect(store.state.likedById['B'], true);
    expect(store.state.serverRevById['B'], 5);

    final sendValueLogs =
        requestLog.where((s) => s.startsWith('sendValue(')).toList();
    expect(sendValueLogs.length, 1);
    expect(sendValueLogs.first, contains('item=A'));
  });

  Bdd(feature)
      .scenario('ServerPush ignores pushes with equal serverRevision.')
      .given('Client already applied serverRevision=20 for a key.')
      .when(
          'A ServerPush arrives with serverRevision=20 and a different value.')
      .then('The push is ignored and state does not regress or flap.')
      .note('Ordering rule should be strictly greater than current.')
      .run((_) async {
    var store = Store<AppState>(
        initialState: AppState(liked: false, serverRevision: 0));

    store.dispatch(PushLikeUpdate(liked: true, serverRev: 20));
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, true);
    expect(store.state.serverRevision, 20);

    // Same serverRev, different value -> must be ignored.
    store.dispatch(PushLikeUpdate(liked: false, serverRev: 20));
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, true);
    expect(store.state.serverRevision, 20);
  });

  Bdd(feature)
      .scenario(
          'Optimization preserved with pushes: no follow-up if final local value equals sent value.')
      .given(
          'A OptimisticSyncWithPush action with request 1 in flight and ServerPush updates may arrive.')
      .when(
          'User changes intent during the request but ends back at the original sent value.')
      .then(
          'No follow-up request is sent, even if a push overwrote the store temporarily.')
      .note(
          'Ensures the revision-based path keeps the same coalescing optimization as the value-based path.')
      .run((_) async {
    var store = Store<AppState>(
        initialState: AppState(liked: false, serverRevision: 10));

    nextServerRevision = 11;

    final req1 = Completer<void>();
    requestCompleter = req1;

    // Tap #1: false -> true, localRev=1, request in flight (sent true).
    store.dispatch(ToggleLikeStableAction());
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, true);

    // Tap #2: true -> false, localRev=2.
    store.dispatch(ToggleLikeStableAction());
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, false);

    // Tap #3: false -> true, localRev=3 (back to sent value).
    store.dispatch(ToggleLikeStableAction());
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, true);

    // Push overwrites store temporarily to false (same rev we'll later apply from response).
    store.dispatch(PushLikeUpdate(liked: false, serverRev: 11));
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, false);

    // Complete request #1.
    req1.complete();
    await Future.delayed(const Duration(milliseconds: 200));

    final sendValueLogs =
        requestLog.where((s) => s.startsWith('sendValue(')).toList();
    expect(sendValueLogs.length, 1,
        reason:
            'Should not send follow-up when final local value equals sent value.');

    // Response should restore true (no follow-up needed).
    expect(store.state.liked, true);
    expect(store.state.serverRevision, 11);
  });

  Bdd(feature)
      .scenario(
          'Stale ServerPush does not overwrite local optimistic UI while request is in flight.')
      .given(
          'A OptimisticSyncWithPush action has a request in flight and the store is optimistic.')
      .when(
          'A ServerPush arrives with an older serverRevision for the same key.')
      .then(
          'The push is ignored immediately and the optimistic UI state remains unchanged.')
      .note('Covers out-of-order delivery while locked.')
      .run((_) async {
    var store = Store<AppState>(
        initialState: AppState(liked: false, serverRevision: 0));

    // Seed known server revision in the mixin bookkeeping.
    store.dispatch(PushLikeUpdate(liked: false, serverRev: 20));
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.serverRevision, 20);

    nextServerRevision = 21;

    final req1 = Completer<void>();
    requestCompleter = req1;

    // Tap: optimistic false -> true, request in flight.
    store.dispatch(ToggleLikeStableAction());
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, true);
    expect(store.state.serverRevision, 20);

    // Stale push arrives (older than 20) -> must be ignored.
    store.dispatch(PushLikeUpdate(liked: false, serverRev: 19));
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, true);
    expect(store.state.serverRevision, 20);

    // Complete request -> serverRev=21 (newer) should apply.
    req1.complete();
    await Future.delayed(const Duration(milliseconds: 200));
    expect(store.state.liked, true);
    expect(store.state.serverRevision, 21);
  });

  Bdd(feature)
      .scenario(
          'Stale server response is NOT applied when a newer ServerPush arrives before the response.')
      .given('A OptimisticSyncWithPush action has a request in flight.')
      .when('A ServerPush arrives with a newer serverRevision before the '
          'request completes.')
      .then('The stale response is ignored and the pushed state remains.')
      .run((_) async {
    final store = Store<AppState>(
      initialState: AppState(liked: false, serverRevision: 10),
    );

    // Make request 1 return serverRev=11.
    nextServerRevision = 11;

    // Hold request 1 so we can inject push before response.
    final c = Completer<void>();
    requestCompleter = c;

    // Tap #1: optimistic false -> true, localRev=1.
    store.dispatch(ToggleLikeStableAction());
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, true);

    // Newer push arrives from another device BEFORE request 1 completes.
    store.dispatch(PushLikeUpdate(liked: false, serverRev: 12));
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, false);
    expect(store.state.serverRevision, 12);

    // Now let request 1 complete (it would try to apply serverRev=11).
    c.complete();
    await Future.delayed(const Duration(milliseconds: 100));

    // Because ServerPush updated the mixin's revision map to 12,
    // the response with serverRev=11 must be treated as stale and ignored.
    expect(store.state.liked, false);
    expect(store.state.serverRevision, 12);
  });

  Bdd(feature)
      .scenario('Out-of-order pushes are ignored by ServerPush ordering.')
      .given('A ServerPush has already applied serverRevision=20.')
      .when('A ServerPush arrives with an older serverRevision=19.')
      .then('The older push is ignored and state does not regress.')
      .run((_) async {
    final store = Store<AppState>(
      initialState: AppState(liked: false, serverRevision: 0),
    );

    // First push (new).
    store.dispatch(PushLikeUpdate(liked: true, serverRev: 20));
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, true);
    expect(store.state.serverRevision, 20);

    // Older push should be ignored even if it tries to overwrite.
    store.dispatch(PushLikeUpdate(liked: false, serverRev: 19));
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, true);
    expect(store.state.serverRevision, 20);
  });

  Bdd(feature)
      .scenario(
          'Push echo overwriting store during in-flight request does not break follow-up.')
      .given('A OptimisticSyncWithPush action has a request in flight.')
      .when('User taps again and a push echo overwrites the store.')
      .then('The follow-up still sends the latest local intent value.')
      .note(
          'Ensures local intent is preserved despite store being overwritten.')
      .run((_) async {
    final store = Store<AppState>(
      initialState: AppState(liked: false, serverRevision: 10),
    );

    // Make request 1 wait; it will return serverRev=11, and follow-up will be 12.
    nextServerRevision = 11;
    final c = Completer<void>();
    requestCompleter = c;

    // Tap #1: false -> true (optimistic), localRev=1; request 1 starts.
    store.dispatch(ToggleLikeStableAction());
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, true);

    // Tap #2 while request 1 in flight: true -> false (optimistic), localRev=2.
    store.dispatch(ToggleLikeStableAction());
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, false);

    // Push echo arrives with the older serverRev=11 and overwrites store to true.
    store.dispatch(PushLikeUpdate(liked: true, serverRev: 11));
    await Future.delayed(const Duration(milliseconds: 10));
    expect(store.state.liked, true);

    // Finish request 1, causing OptimisticSyncWithPush to detect localRev advanced
    // and send follow-up with the latest local intent (false).
    c.complete();
    await Future.delayed(const Duration(milliseconds: 200));

    final sendLogs =
        requestLog.where((s) => s.startsWith('sendValue(')).toList();

    // First request should be true, localRev=1.
    expect(sendLogs.first, 'sendValue(true, localRev=1)');

    // Follow-up must send false, localRev=2.
    expect(sendLogs.length, greaterThanOrEqualTo(2));
    expect(sendLogs[1], 'sendValue(false, localRev=2)');

    // Final should reflect the follow-up (newer serverRev=12).
    expect(store.state.liked, false);
    expect(store.state.serverRevision, 12);
  });
}

// =============================================================================
// Shared test state
// =============================================================================

class AppState {
  final bool liked;
  final int serverRevision;

  AppState({required this.liked, this.serverRevision = 0});

  AppState copy({bool? liked, int? serverRevision}) => AppState(
        liked: liked ?? this.liked,
        serverRevision: serverRevision ?? this.serverRevision,
      );

  @override
  String toString() => 'AppState(liked: $liked, serverRev: $serverRevision)';
}

class AppStateItems {
  final Map<String, bool> likedById;
  final Map<String, int> serverRevById;

  AppStateItems({required this.likedById, required this.serverRevById});

  factory AppStateItems.initial() => AppStateItems(
        likedById: {'A': false, 'B': false},
        serverRevById: {'A': 0, 'B': 0},
      );

  AppStateItems copy({
    Map<String, bool>? likedById,
    Map<String, int>? serverRevById,
  }) =>
      AppStateItems(
        likedById: likedById ?? this.likedById,
        serverRevById: serverRevById ?? this.serverRevById,
      );

  AppStateItems setLiked(String id, bool liked) =>
      copy(likedById: {...likedById, id: liked});

  AppStateItems setServerRev(String id, int rev) =>
      copy(serverRevById: {...serverRevById, id: rev});

  @override
  String toString() =>
      'AppStateItems(likedById: $likedById, serverRevById: $serverRevById)';
}

// =============================================================================
// Test control variables
// =============================================================================

List<String> requestLog = [];
Completer<void>? requestCompleter;
Map<String, Completer<void>?> requestCompleterByItem = {};
int nextServerRevision = 1;

void resetTestState() {
  requestLog = [];
  requestCompleter = null;
  requestCompleterByItem = {};
  nextServerRevision = 1;
}

// =============================================================================
// Actions
// =============================================================================

class ToggleLikeStableAction extends ReduxAction<AppState>
    with OptimisticSyncWithPush<AppState, bool> {
  int _serverRevFromResponse = 0;

  @override
  bool valueToApply() => !state.liked;

  @override
  bool getValueFromState(AppState state) => state.liked;

  @override
  AppState applyOptimisticValueToState(AppState state, bool optimisticValue) =>
      state.copy(liked: optimisticValue);

  @override
  AppState? applyServerResponseToState(AppState state, Object serverResponse) {
    return state.copy(
      liked: serverResponse as bool,
      serverRevision: _serverRevFromResponse,
    );
  }
  
  @override
  Future<Object?> sendValueToServer(Object? value) async {
    final localRev = localRevision();
    requestLog.add('sendValue($value, localRev=$localRev)');

    if (requestCompleter != null) {
      await requestCompleter!.future;
      requestCompleter = null;
    }

    _serverRevFromResponse = nextServerRevision++;
    informServerRevision(_serverRevFromResponse);

    return value;
  }

  @override
  Future<AppState?> onFinish(Object? error) async {
    requestLog.add('onFinish()');
    return null;
  }

  @override
  int? getServerRevisionFromState(Object? key) {
    return state.serverRevision;
  }
}

class PushLikeUpdate extends ReduxAction<AppState> with ServerPush {
  final bool liked;
  final int serverRev;

  PushLikeUpdate({required this.liked, required this.serverRev});

  @override
  Type associatedAction() => ToggleLikeStableAction;

  @override
  int serverRevision() => serverRev;

  @override
  AppState? applyServerPushToState(
      AppState state, Object? key, int serverRevision) {
    return state.copy(liked: liked, serverRevision: serverRevision);
  }

  @override
  int? getServerRevisionFromState(Object? key) {
    return state.serverRevision;
  }
}

class ToggleLikeItemStableAction extends ReduxAction<AppStateItems>
    with OptimisticSyncWithPush<AppStateItems, bool> {
  final String itemId;
  int _serverRevFromResponse = 0;

  ToggleLikeItemStableAction(this.itemId);

  @override
  Object? optimisticSyncKeyParams() => itemId;

  @override
  bool valueToApply() => !(state.likedById[itemId] ?? false);

  @override
  bool getValueFromState(AppStateItems state) =>
      state.likedById[itemId] ?? false;

  @override
  AppStateItems applyOptimisticValueToState(
      AppStateItems state, bool optimisticValue) {
    return state.setLiked(itemId, optimisticValue);
  }

  @override
  AppStateItems? applyServerResponseToState(
      AppStateItems state, Object serverResponse) {
    return state
        .setLiked(itemId, serverResponse as bool)
        .setServerRev(itemId, _serverRevFromResponse);
  }

  @override
  Future<Object?> sendValueToServer(Object? value) async {
    final localRev = localRevision();
    requestLog.add('sendValue(item=$itemId, value=$value, localRev=$localRev)');

    final c = requestCompleterByItem[itemId];
    if (c != null) {
      await c.future;
      requestCompleterByItem[itemId] = null;
    }

    _serverRevFromResponse = nextServerRevision++;
    informServerRevision(_serverRevFromResponse);

    return value;
  }

  @override
  Future<AppStateItems?> onFinish(Object? error) async {
    requestLog.add('onFinish(item=$itemId)');
    return null;
  }

  @override
  int? getServerRevisionFromState(Object? key) {
    return state.serverRevById[key];
  }
}

class PushItemLikeUpdate extends ReduxAction<AppStateItems>
    with ServerPush<AppStateItems> {
  final String itemId;
  final bool liked;
  final int serverRev;

  PushItemLikeUpdate(
      {required this.itemId, required this.liked, required this.serverRev});

  @override
  Type associatedAction() => ToggleLikeItemStableAction;

  @override
  Object? optimisticSyncKeyParams() => itemId;

  @override
  int serverRevision() => serverRev;

  @override
  AppStateItems? applyServerPushToState(
      AppStateItems state, Object? key, int serverRevision) {
    return state.setLiked(itemId, liked).setServerRev(itemId, serverRevision);
  }

  @override
  int? getServerRevisionFromState(Object? key) {
    return state.serverRevById[key];
  }
}
