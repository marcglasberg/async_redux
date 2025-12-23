import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

/// The [StableSyncWithPush] mixin is designed for actions where:
///
/// 1. Your app receives server-pushed updates (like WebSockets, Server-Sent
///    Events (SSE), Firebase) that may modify the same state this action
///    controls.
///
/// 2. Non-blocking user interactions (like toggling a "like" button) should
///    update the UI immediately and send the updated value to the server,
///    making sure the server and the UI are eventually consistent.
///
/// 3. Multiple devices can modify the same data (optional).
///
/// 4. Resilient to out of order delivery.
///
/// 4. You want "last write wins" semantics across devices. In other words,
///    with multiple devices, that's how we decide what truth is when two
///    devices disagree.
///
/// **IMPORTANT:** If your app does not receive server-pushed updates,
/// use the [StableSync] mixin instead.
///
/// ---
///
/// ## How it works
///
/// Please read the documentation of [StableSync] first, as this mixin builds
/// upon that behavior with additional logic to handle server-pushed updates.
///
/// The [StableSyncWithPush] mixin extends [StableSync] by adding this:
///
/// - Each local dispatch increments a `localRevision` counter
/// - Server-pushed updates do NOT increment localRevision
/// - Follow-up logic compares revisions instead of values
/// - This prevents push updates from incorrectly marking state as "stable"
///
/// **Example:**
///
/// ```dart
/// class ToggleLikeAction extends ReduxAction<AppState>
///     with StableSyncWithPush<AppState, bool> {
///
///   @override
///   Future<Object?> sendValueToServer(Object? value) async {
///     int localRev = localRevision(); // Get current revision
///     var response = await api.setLiked(itemId, value, localRev: localRev);
///     informServerRevision(response.serverRev); // Track server revision
///     return response.liked;
///   }
/// }
/// ```
///
/// Notes:
/// - It should not be combined with [NonReentrant], [Throttle], [Debounce],
///   [OptimisticUpdate], or [Fresh].
///
mixin StableSyncWithPush<St, T> on ReduxAction<St> {
  //
  /// Optionally, override [stableSyncKeyParams] to differentiate coalescing by
  /// action parameters. For example, if you have a like button per item,
  /// return the item ID so that different items can have concurrent requests:
  ///
  /// ```dart
  /// Object? stableSyncKeyParams() => itemId;
  /// ```
  ///
  /// You can also return a record of values:
  ///
  /// ```dart
  /// Object? stableSyncKeyParams() => (userId, itemId);
  /// ```
  ///
  /// See also: [computeStableSyncKey], which uses this method by default to
  /// build the key.
  ///
  Object? stableSyncKeyParams() => null;

  /// By default the coalescing key combines the action [runtimeType]
  /// with [stableSyncKeyParams]. Override this method if you want
  /// different action types to share the same coalescing key.
  Object computeStableSyncKey() => (runtimeType, stableSyncKeyParams());

  /// Override [valueToApply] to return the value that should be applied
  /// optimistically to the state and then sent to the server. This is called
  /// synchronously and only once per dispatch, when the reducer starts.
  ///
  /// The value to apply can be anything, and is usually constructed from the
  /// action fields, and/or from the current [state]. Valid examples are:
  ///
  /// ```dart
  /// // Set the like button to "liked".
  /// bool valueToApply() => true
  ///
  /// // Set the like button to "liked" or "not liked", according to
  /// // the field `isLiked` of the action.
  /// bool valueToApply() => isLiked;
  ///
  /// // Toggles the current state of the like button.
  /// bool valueToApply() => !state.items[itemId].isLiked;
  /// ```
  ///
  T valueToApply();

  /// Override [applyOptimisticValueToState] to return a new state where the
  /// given [optimisticValue] is applied to the current [state].
  ///
  /// Note, Async Redux calculated [optimisticValue] by previously
  /// calling [valueToApply].
  ///
  /// ```dart
  /// AppState applyOptimisticValueToState(state, isLiked) =>
  ///     state.copyWith(items: state.items.setLiked(itemId, isLiked));
  /// ```
  St applyOptimisticValueToState(St state, T optimisticValue);

  /// Override [applyServerResponseToState] to return a new state, where the
  /// given [serverResponse] (previously received from the server when running
  /// [sendValueToServer]) is applied to the current [state]. Example:
  ///
  /// ```dart
  /// AppState? applyServerResponseToState(state, serverResponse) =>
  ///     state.copyWith(items: state.items.setLiked(itemId, serverResponse.date.isLiked));
  /// ```
  ///
  /// Note [serverResponse] is never `null` here, because this method is only
  /// called when [sendValueToServer] returned a non-null value.
  ///
  /// If you decide you DO NOT want to apply the server response to the state,
  /// simply return `null`.
  ///
  St? applyServerResponseToState(St state, Object serverResponse);

  /// Override [getValueFromState] to extract the value from the current [state].
  /// This value will be later compared to one returned by [valueToApply] to
  /// determine if a follow-up request is needed.
  ///
  /// Here is the rationale:
  /// When a request completes, if the value in the state is different from
  /// the value that was optimistically applied, it means the user changed it
  /// again while the request was in flight, so a follow-up request is needed
  /// to sync the latest value with the server.
  ///
  /// ```dart
  /// bool getValueFromState(state) => state.items[itemId].liked;
  /// ```
  T getValueFromState(St state);

  /// Override [sendValueToServer] to send the given [optimisticValue] to the
  /// server, and optionally return the server's response.
  ///
  /// Note, Async Redux calculated [optimisticValue] by previously
  /// calling [valueToApply].
  ///
  /// If [sendValueToServer] returns a non-null value, that value will be
  /// applied to the state, but **only when the state stabilizes** (i.e., when
  /// there are no more pending requests and the lock is about to be released).
  /// This prevents the server response from overwriting subsequent user
  /// interactions that occurred while the request was in flight.
  ///
  /// The value in the store state may change while the request is in flight.
  /// For example, if the user presses a like button once, but then
  /// presses it again before the first request finishes, the value in the
  /// store state is now different from the optimistic value that was previously
  /// applied. In this case, [sendValueToServer] will be called again to create
  /// a follow-up request to sync the updated state with the server.
  ///
  /// If [sendValueToServer] returns `null`, the current optimistic state is
  /// assumed to be correct and valid.
  ///
  /// ```dart
  /// Future<Object?> saveValue(Object? optimisticValue) async {
  ///   var response = await api.setLiked(itemId, optimisticValue);
  ///   return response?.liked; // Return server-confirmed value, or null.
  /// }
  /// ```
  Future<Object?> sendValueToServer(Object? optimisticValue);

  /// If your app listens to server-pushed updates (e.g., via WebSockets),
  /// call [localRevision] to enable revision-based synchronization that
  /// correctly handles concurrent updates from multiple devices.
  ///
  /// **When to use:**
  /// Call [localRevision] from [sendValueToServer] to get the revision number
  /// to send with your request. The server should echo this back in its
  /// response so the client knows which request completed.
  ///
  /// **How it works:**
  /// - Each dispatch that calls [localRevision] increments the revision for
  ///   this key (the first call per dispatch increments; subsequent calls in
  ///   the same dispatch return the same value).
  /// - When a request completes, the framework compares the current
  ///   localRevision with what was sent. If they differ, a follow-up request
  ///   is sent automatically.
  /// - Server-pushed updates should NOT call [localRevision] (they are not
  ///   local intent). Instead, use [informServerRevision] to track server state.
  ///
  /// **Important:** Call [localRevision] BEFORE any `await` in your
  /// [sendValueToServer] implementation to ensure the captured value is
  /// consistent.
  ///
  /// **Example:**
  /// ```dart
  /// Future<Object?> sendValueToServer(Object? optimisticValue) async {
  ///   int localRev = localRevision(); // Capture BEFORE await
  ///   var response = await api.setLiked(itemId, optimisticValue, localRev: localRev);
  ///   informServerRevision(response.serverRev);
  ///   return response.liked; // The mixin decides whether to apply this
  /// }
  /// ```
  ///
  /// **Note:** If your app does not listen to server-pushed updates, you can
  /// ignore this method. The default value-comparison logic will still work.
  ///
  int localRevision() {
    final key = _currentKey!;

    if (!_localRevisionCalled) {
      _localRevisionCalled = true;

      // Increment for this dispatch.
      final entry = _revisionMap[key];
      final int newLocalRev = (entry?.localRevision ?? 0) + 1;

      // Snapshot the current known server revision at the moment this local intent is created.
      final int? fromMap = entry?.serverRevision;
      final int? fromState = getServerRevisionFromState(key);
      final int baseServerRev = _bestKnownServerRevision(key);

      // Keep null only if we truly know nothing.
      final int? storedServerRev =
          (fromMap == null && fromState == null) ? null : baseServerRev;

      _revisionMap[key] = (
        localRevision: newLocalRev,
        serverRevision: storedServerRev,
        intentBaseServerRevision: baseServerRev,
        localValue: entry?.localValue, // preserve latest local intent value
      );
    }

    // Always return the current value (might have been updated by other dispatches)
    return _revisionMap[key]!.localRevision;
  }

  /// Tracks whether [localRevision] has been called in this dispatch.
  /// Reset at the start of [reduce].
  bool _localRevisionCalled = false;

  /// Tracks the server revision informed by the user during [sendValueToServer].
  /// Used by _sendAndFollowUp to determine if the response should be applied.
  /// Reset before each call to [sendValueToServer].
  int? _informedServerRev;

  /// Cached coalescing key for the current dispatch.
  /// Computed once in [reduce] and reused by [localRevision],
  /// [_serverRevision], and [informServerRevision].
  Object? _currentKey;

  /// Note: This mutates `_revisionMap`.
  int _bestKnownServerRevision(Object? key) {
    final entry = _revisionMap[key];
    final int fromMap = entry?.serverRevision ?? 0;
    final int fromState = getServerRevisionFromState(key) ?? 0;

    if (fromState > fromMap) {
      _revisionMap[key] = (
      localRevision: entry?.localRevision ?? 0,
      serverRevision: fromState,
      intentBaseServerRevision: entry?.intentBaseServerRevision ?? fromState,
      localValue: entry?.localValue,
      );
      return fromState;
    }

    return fromMap;
  }
  
  /// Returns the current known server revision for this key.
  ///
  /// The serverRevision represents the server's view of the latest write
  /// (under "last write wins" semantics).
  ///
  /// Returns 0 if no server revision has been set for this key.
  ///
  /// See also: [informServerRevision].
  ///
  int _serverRevision() {
    final key = _currentKey!;
    return _bestKnownServerRevision(key);
  }

  /// You must override this to return the server revision you saved in the
  /// state in [ServerPush.applyServerPushToState] for the given [key].
  ///
  /// You MUST return `null` when unknown (not `0`).
  int? getServerRevisionFromState(Object? key);

  /// Call this from [sendValueToServer] to inform the mixin about the
  /// server revision returned in the response.
  ///
  /// The mixin uses this information internally to:
  /// - Track the latest known server revision (for "last write wins" ordering)
  /// - Determine whether to apply the server response (stale responses are
  ///   automatically ignored)
  ///
  /// **Usage:** Just call this method with the serverRevision from the response.
  /// The mixin handles all the logic - you don't need to check or compare
  /// anything yourself.
  ///
  /// **Example:**
  /// ```dart
  /// Future<Object?> sendValueToServer(Object? optimisticValue) async {
  ///   int localRev = localRevision();
  ///   var response = await api.setLiked(itemId, optimisticValue, localRev: localRev);
  ///   informServerRevision(response.serverRev);
  ///   return response.liked; // The mixin decides whether to apply this
  /// }
  /// ```
  ///
  /// **Behavior:**
  /// - Only updates the stored serverRevision if [revision] is greater than
  ///   the current value (prevents regression from stale/out-of-order updates)
  /// - The mixin will only apply the returned server response if this revision
  ///   is still the newest (no newer push has arrived in the meantime)
  ///
  /// See also: [informServerRevisionAsDateTime].
  ///
  void informServerRevision(int revision) {
    _informedServerRev = revision;

    final key = _currentKey!;
    final entry = _revisionMap[key];

    final int currentServerRev = _bestKnownServerRevision(key);

    // Only move forward, but keep local intent info.
    if (revision > currentServerRev) {
      _revisionMap[key] = (
      localRevision: entry?.localRevision ?? 0,
      serverRevision: revision,
      intentBaseServerRevision: entry?.intentBaseServerRevision ?? currentServerRev,
      localValue: entry?.localValue,
      );
    }
  }

  /// Convenience method to inform the server revision from a DateTime.
  /// Uses `millisecondsSinceEpoch` as the revision number.
  ///
  /// See also: [informServerRevision].
  ///
  void informServerRevisionAsDateTime(DateTime revision) {
    informServerRevision(revision.millisecondsSinceEpoch);
  }

  /// Convenience method to get the server revision as a DateTime.
  /// Interprets the revision number as `millisecondsSinceEpoch`.
  ///
  /// Returns `DateTime.fromMillisecondsSinceEpoch(0)` if no revision is set.
  ///
  DateTime serverRevisionAsDateTime() =>
      DateTime.fromMillisecondsSinceEpoch(_serverRevision(), isUtc: true);

  /// Optionally, override [onFinish] to run any code after the synchronization
  /// process completes. For example, you might want to reload related data from
  /// the server, show a confirmation message, or perform cleanup.
  ///
  /// Note [onFinish] is called in both success and failure scenarios, but only
  /// after the state stabilizes for this key (that is, after the last request
  /// finishes and no follow-up request is needed).
  ///
  /// Important: The synchronization lock is released *before* [onFinish] runs.
  /// This means new dispatches for the same key may start a new request while
  /// [onFinish] is still executing.
  ///
  /// The [error] parameter will be `null` on success, or contain the error
  /// object if the request failed.
  ///
  /// If [onFinish] returns a non-null state, it will be applied automatically.
  /// If it returns `null`, no state change is made.
  ///
  /// ```dart
  /// Future<St?> onFinish(Object? error) async {
  ///   if (error == null) {
  ///     // Success: show confirmation, log analytics, etc.
  ///     return null;
  ///   } else {
  ///     // Failure: reload data from the server.
  ///     var reloadedInfo = await api.loadInfo();
  ///     return state.copy(info: reloadedInfo);
  ///   }
  /// }
  /// ```
  ///
  /// Important:
  ///
  /// - If `onFinish(error)` throws, the original [error] is lost and the error
  ///   thrown by [onFinish] becomes the action error. You can handle it in
  ///   [wrapError].
  ///
  /// - Same on success: If `onFinish(null)` throws, the whole action fails
  ///   even though the server request succeeded.  You can handle it in
  ///   [wrapError].
  ///
  Future<St?> onFinish(Object? error) async => null;

  @override
  Future<St?> reduce() async {
    _cannotCombineStableSyncWithOtherMixins();

    // Reset the flag so localRevision() can increment for this dispatch.
    _localRevisionCalled = false;

    // Compute and cache the key for this dispatch.
    _currentKey = computeStableSyncKey();

    // We automatically track revisions for every dispatch.
    // This ensures blocked dispatches also increment the revision counter.
    localRevision();

    final value = valueToApply();

    // Record the latest local intended value for this key, so follow-ups don't
    // depend on store state (which may be overwritten by pushes).
    final entry = _revisionMap[_currentKey];
    _revisionMap[_currentKey] = (
      localRevision: entry?.localRevision ?? 0,
      serverRevision: entry?.serverRevision,
      intentBaseServerRevision:
          entry?.intentBaseServerRevision ?? (entry?.serverRevision ?? 0),
      localValue: value,
    );

    // Always apply optimistic update immediately.
    dispatchState(applyOptimisticValueToState(state, value));

    // If locked, another request is in flight. The optimistic update is
    // already applied, so just return. When the in-flight request completes,
    // it will check if a follow-up is needed.
    if (_stableSyncKeySet.contains(_currentKey)) return null;

    // Acquire lock and send request.
    _stableSyncKeySet.add(_currentKey);
    await _sendAndFollowUp(_currentKey, value);

    return null;
  }

  /// Set that tracks which keys are currently locked (requests in flight).
  Set<Object?> get _stableSyncKeySet =>
      store.internalMixinProps.stableSyncKeySet;

  /// Map that tracks local and server revisions for the given key.
  /// The values can be retrieved by methods [localRevision] and [serverRevision].
  Map<
      Object?,
      ({
        int localRevision,
        int? serverRevision,
        int intentBaseServerRevision,
        Object? localValue,
      })> get _revisionMap => store.internalMixinProps.revisionMap;

  T? _getLatestLocalValue(Object? key) {
    final v = _revisionMap[key]?.localValue;
    return (v is T) ? v : null;
  }

  /// Sends the request and handles follow-up requests if the state changed
  /// while the request was in flight.
  ///
  /// When revision tracking is enabled (`isPushCompatible == true`), follow-up
  /// logic is primarily based on `localRevision` (local intent order), and the
  /// value to resend comes from the latest *local intent value* saved in
  /// `_revisionMap` (so it can't be corrupted by server pushes that overwrite
  /// the store while a request is in flight).
  ///
  /// When revision tracking is disabled, the original behavior is preserved:
  /// follow-up logic compares `stateValue` vs the sent value.
  Future<void> _sendAndFollowUp(Object? key, T sentValue) async {
    T _sentValue = sentValue;

    int requestCount = 0;

    while (true) {
      requestCount++;

      // Capture the local revision representing the intent we are about to send.
      // This is captured before `sendValueToServer` so it represents "what this
      // request corresponds to", even if new local dispatches happen while the
      // request is in flight.
      final int? sentLocalRev = _getLocalRevision(key);

      // Reset before each request so we can detect whether the user called
      // `informServerRevision()` while executing `sendValueToServer`.
      _informedServerRev = null;

      try {
        // Send the value and get the server response (may be null).
        final Object? serverResponse = await sendValueToServer(_sentValue);

        // Validate that the developer called informServerRevision().
        if (_informedServerRev == null) {
          throw StateError(
            'The StableSyncWithPush mixin requires calling '
            'informServerRevision() inside sendValueToServer(). '
            'If you don\'t need server-push handling, use StableSync instead.',
          );
        }

        // Read the current value from the store.
        // WARNING: In push mode this may reflect a server push, not local intent.
        final stateValue = getValueFromState(state);

        bool needFollowUp = false;

        // Revision-based follow-up decision:
        // If localRevision advanced since this request started, the user changed
        // intent while the request was in flight, so we may need a follow-up.
        final int currentLocalRev = _getLocalRevision(key);

        if (currentLocalRev > sentLocalRev!) {
          final entry = _revisionMap[key];
          final int currentServerRev = _bestKnownServerRevision(key);
          final int intentBaseServerRev = entry?.intentBaseServerRevision ?? 0;

          // Remote-wins guard:
          // If a newer server revision arrived than the revision returned by THIS response,
          // and that newer server revision is also newer than the server revision that was
          // current when the latest local intent was created, then the latest local intent
          // is considered superseded under last-write-wins. Do not follow up.
          final bool remoteSupersededThisResponse =
              currentServerRev > _informedServerRev!;

          final bool remoteSupersededLatestIntent =
              currentServerRev > intentBaseServerRev;

          if (remoteSupersededThisResponse && remoteSupersededLatestIntent) {
            needFollowUp = false;
          } else {
            // IMPORTANT: Use the latest *local intent* value for this key, which
            // we saved at dispatch time. Do not rely on store state here, because
            // pushes can overwrite the store while the request is in flight.
            final T latestLocalValue = _getLatestLocalValue(key) ?? stateValue;

            // Optimization (restores old behavior):
            // If the user changed intent during the request but ended up back at
            // the same value we already sent, skip the follow-up request.
            needFollowUp = ifShouldSendAnotherRequest(
              stateValue: latestLocalValue,
              sentValue: _sentValue,
              requestCount: requestCount,
            );

            // If we do need a follow-up, resend the latest local intent value.
            if (needFollowUp) _sentValue = latestLocalValue;
          }
        }

        // If we need a follow-up, loop again without applying server response.
        // The state is not stable yet.
        if (needFollowUp) continue;

        // State is stable for this key. Now we may apply the server response,
        // but only if it is not stale relative to newer pushes.
        if (serverResponse != null) {
          // Only apply if the informed server revision still matches the latest
          // known server revision for this key (i.e., no newer push arrived).
          final bool shouldApply = _informedServerRev == _serverRevision();

          if (shouldApply) {
            final newState = applyServerResponseToState(state, serverResponse);
            if (newState != null) dispatchState(newState);
          }
        }

        // Release lock and finish.
        _stableSyncKeySet.remove(key);
        await _callOnFinish(null);
        break;
      } catch (error) {
        // Request failed: release lock, run onFinish(error), then rethrow so the
        // action still fails as before.
        _stableSyncKeySet.remove(key);
        await _callOnFinish(error);
        rethrow;
      }
    }
  }

  /// Returns the current localRevision for this key, or 0 if not tracking.
  int _getLocalRevision(Object? key) => _revisionMap[key]?.localRevision ?? 0;

  /// Calls [onFinish], applying the returned state if non-null.
  Future<void> _callOnFinish(Object? error) async {
    final newState = await onFinish(error);
    if (newState != null) dispatchState(newState);
  }

  /// If [ifShouldSendAnotherRequest] returns true, the action will perform one
  /// more request to try and send the value from the state to the server.
  ///
  /// The default behavior of this method is to compare:
  /// - The [stateValue], which is the value currently in the store state.
  /// - The [sentValue], which is the value that was sent to the server.
  ///
  /// If both are different, it means that the state was changed after
  /// we sent the request, so we should send another request with the new value.
  ///
  /// Optionally, override this method if you need custom equality logic.
  /// The default implementation uses the `==` operator.
  ///
  /// The number of follow-up requests is limited at [maxFollowUpRequests] to
  /// avoid infinite loops. If that limit is exceeded, a [StateError] is thrown.
  ///
  bool ifShouldSendAnotherRequest({
    required T stateValue,
    required T sentValue,
    required int requestCount,
  }) {
    // Safety check to avoid infinite loops.
    if ((maxFollowUpRequests != -1) && (requestCount > maxFollowUpRequests)) {
      throw StateError('Too many follow-up requests '
          'in action $runtimeType (> $maxFollowUpRequests).');
    }

    return (stateValue is ImmutableCollection &&
            sentValue is ImmutableCollection)
        ? !stateValue.same(sentValue)
        : stateValue != sentValue;
  }

  /// Maximum number of follow-up requests to send before throwing an error.
  /// This is a safety limit to avoid infinite loops. Override if you need a
  /// different limit. Use `-1` for no limit.
  int get maxFollowUpRequests => 10000;

  void _cannotCombineStableSyncWithOtherMixins() {
    _incompatible<StableSyncWithPush, NonReentrant>(this);
    _incompatible<StableSyncWithPush, Throttle>(this);
    _incompatible<StableSyncWithPush, OptimisticUpdate>(this);
    _incompatible<StableSyncWithPush, Fresh>(this);

    // Works with Debounce!!!!!!!!
    // _incompatible<StableSyncWithPush, Debounce>(this);
  }
}

void _incompatible<T1, T2>(Object instance) {
  assert(
    instance is! T2,
    'The ${T1.toString().split('<').first} mixin '
    'cannot be combined with the ${T2.toString().split('<').first} mixin.',
  );
}

mixin ServerPush<St> on ReduxAction<St> {
  /// Return the Type of the StableSync/StableSyncWithPush action that owns
  /// this value (so both compute the same stable-sync key).
  Type associatedAction();

  /// Same meaning as in StableSync: the params that differentiate keys.
  Object? stableSyncKeyParams() => null;

  /// Must match the StableSync action key computation.
  /// Default: (associatedActionType, stableSyncKeyParams)
  Object computeStableSyncKey() => (associatedAction(), stableSyncKeyParams());

  /// You must override this to provide the revision number that came with
  /// the push. For example:
  ///
  /// ```dart
  /// class PushLikeUpdate extends AppAction with ServerPush {
  ///   final bool liked;
  ///   final int serverRev;
  ///   PushLikeUpdate({required this.liked, required this.serverRev});
  ///
  ///   Type associatedAction() => ToggleLikeStableAction;
  ///
  ///   int serverRevision() => serverRev;
  ///
  ///   AppState? applyServerPushToState(AppState state)
  ///     => state.copy(liked: liked, serverRevision: serverRev);
  /// }
  /// ```dart
  int serverRevision();

  /// You must override this to:
  /// - Apply the pushed data to [state].
  /// - Save the [serverRevision] for the current [key] to the [state].
  ///
  /// Return `null` to ignore the push.
  ///
  /// IMPORTANT: This should be a pure state transform and must NOT call
  /// localRevision() or sendValueToServer().
  ///
  St? applyServerPushToState(St state, Object? key, int serverRevision);

  /// You must override this to return the server revision you saved in the
  /// state in [applyServerPushToState] for the given [key].
  ///
  /// You MUST return `null` when unknown (not `0`).
  int? getServerRevisionFromState(Object? key);

  /// If true (default), applies the push even while the stable-sync key is locked.
  /// If you set this to false, you must handle deferral elsewhere, otherwise the
  /// push will be ignored while locked.
  bool get applyEvenIfLocked => true;

  @override
  St? reduce() {
    final key = computeStableSyncKey();
    final incomingServerRev = serverRevision();

    final entry0 = _revisionMap[key];
    final fromMap = entry0?.serverRevision;
    final fromState = getServerRevisionFromState(key);

    final currentServerRev = (fromMap == null && fromState == null)
        ? null
        : ((fromMap ?? 0) > (fromState ?? 0)
            ? (fromMap ?? 0)
            : (fromState ?? 0));

    // Seed the map from persisted state if needed.
    // This is important even when we ignore the push as stale.
    if (fromMap == null && fromState != null) {
      _revisionMap[key] = (
        localRevision: entry0?.localRevision ?? 0,
        serverRevision: fromState,
        intentBaseServerRevision: entry0?.intentBaseServerRevision ?? fromState,
        localValue: entry0?.localValue,
      );
    }

    // Ignore stale/out-of-order pushes.
    if (currentServerRev != null && incomingServerRev <= currentServerRev) {
      return null;
    }

    // Optionally ignore while locked (not deferred by default).
    if (!applyEvenIfLocked && _stableSyncKeySet.contains(key)) {
      return null;
    }

    // Apply pushed state.
    final newState = applyServerPushToState(state, key, incomingServerRev);
    if (newState == null) return null;

    // Record newest known server revision for this key (preserve local intent info).
    final entry = _revisionMap[key];
    _revisionMap[key] = (
      localRevision: entry?.localRevision ?? 0,
      serverRevision: incomingServerRev,
      intentBaseServerRevision:
          entry?.intentBaseServerRevision ?? (currentServerRev ?? 0),
      localValue: entry?.localValue,
    );

    return newState;
  }

  Set<Object?> get _stableSyncKeySet =>
      store.internalMixinProps.stableSyncKeySet;

  Map<
      Object?,
      ({
        int localRevision,
        int? serverRevision,
        int intentBaseServerRevision,
        Object? localValue,
      })> get _revisionMap => store.internalMixinProps.revisionMap;
}
