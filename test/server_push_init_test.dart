// server_push_init_test.dart
import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:async_redux/src/optimistic_sync_with_push_mixin.dart';
import 'package:bdd_framework/bdd_framework.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final feature = BddFeature('ServerPush init (persisted revisions)');

  setUp(() {
    resetTestState();
  });

  Bdd(feature)
      .scenario(
          'Init: Fresh server response applies when backend revision >= persisted.')
      .given('App launched with state.serverRevision=100 and backend at 100.')
      .when('User dispatches OptimisticSyncWithPush action.')
      .then('Response is applied and serverRevision increases to 101.')
      .run((_) async {
    final store = Store<AppState>(
        initialState: AppState(liked: false, serverRevision: 100));

    backend = SimulatedBackend(liked: false, serverRevision: 100);

    await store.dispatchAndWait(ToggleLikeStableAction());

    expect(store.state.liked, true);
    expect(store.state.serverRevision, 101);
    expect(backend.serverRevision, 101);
  });

  Bdd(feature)
      .scenario('Init: Fresh push updates both backend and store.')
      .given('App launched with state.serverRevision=100 and backend at 100.')
      .when('A fresh push arrives with serverRevision=105.')
      .then('Both store and backend end at 105 with same liked value.')
      .run((_) async {
    final store = Store<AppState>(
        initialState: AppState(liked: false, serverRevision: 100));

    backend = SimulatedBackend(liked: false, serverRevision: 100);

    // Simulate a fresh push from another device (backend already updated).
    backend.applyPush(true, 105);
    await store.dispatchAndWait(PushLikeUpdate(liked: true, serverRev: 105));

    expect(store.state.liked, true);
    expect(store.state.serverRevision, 105);
    expect(backend.liked, true);
    expect(backend.serverRevision, 105);
  });

  Bdd(feature)
      .scenario(
          'Init: Stale push is ignored using persisted serverRevision in state.')
      .given(
          'App launched with state.serverRevision=100 and revisionMap empty.')
      .when('A ServerPush arrives with serverRevision=99.')
      .then('Push is ignored and state does not regress.')
      .run((_) async {
    final store = Store<AppState>(
        initialState: AppState(liked: true, serverRevision: 100));

    // Backend reflects the persisted state (already at rev 100).
    backend = SimulatedBackend(liked: true, serverRevision: 100);

    // Simulate a delayed/stale push arriving. The backend has already moved on,
    // so we only deliver the stale message to the client (no applyPush call).
    await store.dispatchAndWait(PushLikeUpdate(liked: false, serverRev: 99));

    expect(store.state.liked, true);
    expect(store.state.serverRevision, 100);
  });

  Bdd(feature)
      .scenario(
          'Init: Push with equal serverRevision is ignored at startup.')
      .given('App launched with state.serverRevision=100 and revisionMap empty.')
      .when('A ServerPush arrives with serverRevision=100 and a different liked value.')
      .then('The push is ignored and state remains unchanged.')
      .run((_) async {
    final store = Store<AppState>(
        initialState: AppState(liked: false, serverRevision: 100));

    // Backend reflects the persisted state (already at rev 100).
    backend = SimulatedBackend(liked: false, serverRevision: 100);

    // Push arrives with equal revision but different value.
    // Should be ignored because it's not newer.
    await store.dispatchAndWait(PushLikeUpdate(liked: true, serverRev: 100));

    expect(store.state.liked, false);
    expect(store.state.serverRevision, 100);
  });

  Bdd(feature)
      .scenario(
          'Init: Stale server response is ignored using persisted serverRevision in state.')
      .given(
          'App launched with state.serverRevision=100 and a request returns serverRev=1.')
      .when('A OptimisticSyncWithPush action completes.')
      .then(
          'The stale response is not applied and serverRevision does not regress.')
      .run((_) async {
    final store = Store<AppState>(
        initialState: AppState(liked: false, serverRevision: 100));

    // Simulate a stale backend that starts at revision 0, so first response returns 1.
    backend = SimulatedBackend(liked: false, serverRevision: 0);

    await store.dispatchAndWait(ToggleLikeStableAction());

    // Optimistic UI happened.
    expect(store.state.liked, true);

    // But serverRevision must not go backwards.
    expect(store.state.serverRevision, 100);

    expect(backend.requestLog.length, 1);
    expect(backend.requestLog.first, contains('localRev=1'));
  });

  Bdd(feature)
      .scenario(
          'Init: OptimisticSyncWithPush seeds revisionMap from persisted state so ServerPush ordering works even if push cannot read state.')
      .given('App launched with state.serverRevision=100.')
      .when(
          'A OptimisticSyncWithPush request starts (in flight) and a stale push arrives, but the push action returns null from getServerRevisionFromState.')
      .then('The stale push is still ignored because revisionMap was seeded.')
      .note(
          'This verifies the seeding path: OptimisticSyncWithPush must copy the persisted serverRevision into revisionMap.')
      .run((_) async {
    final store = Store<AppState>(
        initialState: AppState(liked: false, serverRevision: 100));

    // Backend starts at revision 100, will go to 101 when request completes.
    backend = SimulatedBackend(liked: false, serverRevision: 100);

    // Hold request so we can inject push while the request is in flight.
    requestCompleter = Completer<void>();
    requestStarted = Completer<void>();
    requestFinished = Completer<void>();

    // Start request: this must seed revisionMap from state.serverRevision=100.
    store.dispatch(ToggleLikeStableAction());
    await requestStarted!.future; // Wait until request is in flight.
    expect(store.state.liked, true);
    expect(store.state.serverRevision, 100);

    // Stale push arrives (delayed message). Backend has already moved on,
    // so we only deliver the stale message to the client.
    await store.dispatchAndWait(
        PushLikeUpdateNoStateRev(liked: false, serverRev: 99));

    // If seeding didn't happen, this would incorrectly apply and set serverRevision=99.
    expect(store.state.serverRevision, 100);

    // Now complete the request (backend will increment to 101 and apply).
    requestCompleter!.complete();
    await requestFinished!.future; // Wait until action finishes.

    expect(store.state.serverRevision, 101);
    expect(store.state.liked, true);
  });

  Bdd(feature)
      .scenario(
          'Init: Per-key persisted revisions are honored when revisionMap is empty.')
      .given('App launched with serverRevById[A]=100 and serverRevById[B]=0.')
      .when('A stale push arrives for A and a fresh push arrives for B.')
      .then('A push is ignored and B push is applied.')
      .run((_) async {
    final store = Store<AppStateItems>(
      initialState: AppStateItems.initialWithRevs(
        likedById: {'A': false, 'B': false},
        serverRevById: {'A': 100, 'B': 0},
      ),
    );

    // Initialize backends to match persisted state.
    backendByItem['A'] = SimulatedBackend(liked: false, serverRevision: 100);
    backendByItem['B'] = SimulatedBackend(liked: false, serverRevision: 0);

    // Stale push for A (older than persisted 100) must be ignored.
    // Backend has already moved on, so no applyPush call.
    await store.dispatchAndWait(
        PushItemLikeUpdate(itemId: 'A', liked: true, serverRev: 99));
    expect(store.state.likedById['A'], false);
    expect(store.state.serverRevById['A'], 100);

    // Fresh push for B should apply (backend updated first).
    backendByItem['B']!.applyPush(true, 1);
    await store.dispatchAndWait(
        PushItemLikeUpdate(itemId: 'B', liked: true, serverRev: 1));
    expect(store.state.likedById['B'], true);
    expect(store.state.serverRevById['B'], 1);
  });

  Bdd(feature)
      .scenario(
          'Init: OptimisticSyncWithPush seeds per-key revisionMap from persisted state for item keys.')
      .given('App launched with serverRevById[A]=100.')
      .when(
          'A OptimisticSyncWithPush request for A starts, and a stale push for A arrives that cannot read serverRev from state.')
      .then(
          'The stale push is ignored because revisionMap was seeded for key A.')
      .run((_) async {
    final store = Store<AppStateItems>(
      initialState: AppStateItems.initialWithRevs(
        likedById: {'A': false, 'B': false},
        serverRevById: {'A': 100, 'B': 0},
      ),
    );

    // Backend for item A starts at revision 100.
    backendByItem['A'] = SimulatedBackend(liked: false, serverRevision: 100);

    requestCompleterByItem['A'] = Completer<void>();
    requestStartedByItem['A'] = Completer<void>();
    requestFinishedByItem['A'] = Completer<void>();

    // Start request for A: must seed revisionMap for key A from state (100).
    store.dispatch(ToggleLikeItemStableAction('A'));
    await requestStartedByItem['A']!.future; // Wait until request is in flight.
    expect(store.state.likedById['A'], true);
    expect(store.state.serverRevById['A'], 100);

    // Stale push for A (delayed message). Backend has already moved on.
    await store.dispatchAndWait(
        PushItemLikeUpdateNoStateRev(itemId: 'A', liked: false, serverRev: 99));

    // If seeding didn't happen, this would regress serverRevById[A] to 99.
    expect(store.state.serverRevById['A'], 100);

    // Finish request so the test doesn't leave in-flight work behind.
    requestCompleterByItem['A']!.complete();
    await requestFinishedByItem['A']!.future; // Wait until action finishes.

    expect(store.state.serverRevById['A'], 101);
  });
}

// =============================================================================
// Simulated Backend
// =============================================================================

/// Simulates a backend server that maintains its own state.
/// When it receives a value, it stores it and increments the serverRevision.
class SimulatedBackend {
  bool liked;
  int serverRevision;
  final List<String> requestLog = [];

  SimulatedBackend({required this.liked, required this.serverRevision});

  /// Applies a push that originated from the server (e.g., another device).
  /// Only updates if the revision is newer than current.
  void applyPush(bool value, int rev) {
    requestLog.add('applyPush($value, serverRev=$rev)');
    if (rev > serverRevision) {
      serverRevision = rev;
      liked = value;
    }
  }

  /// Simulates sending a value to the server.
  /// The server stores the value and returns the new state with incremented revision.
  ({bool value, int serverRevision}) receiveValue(bool value, int localRev) {
    requestLog.add('receiveValue($value, localRev=$localRev)');
    liked = value;
    serverRevision++;
    return (value: liked, serverRevision: serverRevision);
  }
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
}

class AppStateItems {
  final Map<String, bool> likedById;
  final Map<String, int> serverRevById;

  AppStateItems({required this.likedById, required this.serverRevById});

  factory AppStateItems.initialWithRevs({
    required Map<String, bool> likedById,
    required Map<String, int> serverRevById,
  }) =>
      AppStateItems(likedById: likedById, serverRevById: serverRevById);

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
}

// =============================================================================
// Test control variables
// =============================================================================

late SimulatedBackend backend;
Map<String, SimulatedBackend> backendByItem = {};

Completer<void>? requestCompleter;
Completer<void>? requestStarted;
Completer<void>? requestFinished;

Map<String, Completer<void>?> requestCompleterByItem = {};
Map<String, Completer<void>?> requestStartedByItem = {};
Map<String, Completer<void>?> requestFinishedByItem = {};

void resetTestState() {
  backend = SimulatedBackend(liked: false, serverRevision: 0);
  backendByItem = {};
  requestCompleter = null;
  requestStarted = null;
  requestFinished = null;
  requestCompleterByItem = {};
  requestStartedByItem = {};
  requestFinishedByItem = {};
}

// =============================================================================
// Actions
// =============================================================================

class ToggleLikeStableAction extends ReduxAction<AppState>
    with OptimisticSyncWithPush<AppState, bool> {
  @override
  bool valueToApply() => !state.liked;

  @override
  bool getValueFromState(AppState state) => state.liked;

  @override
  AppState applyOptimisticValueToState(AppState state, bool optimisticValue) =>
      state.copy(liked: optimisticValue);

  @override
  AppState? applyServerResponseToState(AppState state, Object serverResponse) {
    final response = serverResponse as ({bool value, int serverRevision});
    return state.copy(
      liked: response.value,
      serverRevision: response.serverRevision,
    );
  }

  @override
  Future<Object?> sendValueToServer(Object? value) async {
    final localRev = localRevision();

    // Signal: request is now in-flight (it will block on requestCompleter).
    // Use isCompleted guard to handle follow-up requests safely.
    if (requestStarted != null && !requestStarted!.isCompleted) {
      requestStarted!.complete();
    }

    if (requestCompleter != null) {
      await requestCompleter!.future;
      requestCompleter = null;
    }

    final response = backend.receiveValue(value as bool, localRev);
    informServerRevision(response.serverRevision);

    return response;
  }

  @override
  Future<AppState?> onFinish(Object? error) async {
    // Use isCompleted guard to handle follow-up requests safely.
    if (requestFinished != null && !requestFinished!.isCompleted) {
      requestFinished!.complete();
    }
    return null;
  }

  @override
  int? getServerRevisionFromState(Object? key) => state.serverRevision;
}

class PushLikeUpdate extends ReduxAction<AppState> with ServerPush<AppState> {
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
  int? getServerRevisionFromState(Object? key) => state.serverRevision;
}

/// Same as PushLikeUpdate but pretends it cannot read persisted revision from state.
/// Used to prove OptimisticSyncWithPush seeded revisionMap.
class PushLikeUpdateNoStateRev extends ReduxAction<AppState>
    with ServerPush<AppState> {
  final bool liked;
  final int serverRev;

  PushLikeUpdateNoStateRev({required this.liked, required this.serverRev});

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
  int? getServerRevisionFromState(Object? key) => null;
}

class ToggleLikeItemStableAction extends ReduxAction<AppStateItems>
    with OptimisticSyncWithPush<AppStateItems, bool> {
  final String itemId;

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
    final response = serverResponse as ({bool value, int serverRevision});
    return state
        .setLiked(itemId, response.value)
        .setServerRev(itemId, response.serverRevision);
  }

  @override
  Future<Object?> sendValueToServer(Object? value) async {
    final localRev = localRevision();

    // Signal: request is now in-flight (it will block on requestCompleterByItem).
    // Use isCompleted guard to handle follow-up requests safely.
    final started = requestStartedByItem[itemId];
    if (started != null && !started.isCompleted) {
      started.complete();
    }

    final c = requestCompleterByItem[itemId];
    if (c != null) {
      await c.future;
      requestCompleterByItem[itemId] = null;
    }

    // Get or create backend, seeding from persisted state.
    final itemBackend = backendByItem[itemId] ??
        SimulatedBackend(
          liked: state.likedById[itemId] ?? false,
          serverRevision: state.serverRevById[itemId] ?? 0,
        );
    backendByItem[itemId] = itemBackend;

    final response = itemBackend.receiveValue(value as bool, localRev);
    informServerRevision(response.serverRevision);

    return response;
  }

  @override
  Future<AppStateItems?> onFinish(Object? error) async {
    // Use isCompleted guard to handle follow-up requests safely.
    final finished = requestFinishedByItem[itemId];
    if (finished != null && !finished.isCompleted) {
      finished.complete();
    }
    return null;
  }

  @override
  int? getServerRevisionFromState(Object? key) {
    final k = key is String ? key : itemId;
    return state.serverRevById[k];
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
    final k = key is String ? key : itemId;
    return state.serverRevById[k];
  }
}

class PushItemLikeUpdateNoStateRev extends ReduxAction<AppStateItems>
    with ServerPush<AppStateItems> {
  final String itemId;
  final bool liked;
  final int serverRev;

  PushItemLikeUpdateNoStateRev(
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
  int? getServerRevisionFromState(Object? key) => null;
}
