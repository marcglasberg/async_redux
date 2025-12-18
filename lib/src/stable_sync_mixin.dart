import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

/// The [StableSync] mixin is designed for actions where rapid user interactions
/// (like toggling a "like" button) should update the UI immediately and
/// send the updated value to the server, making sure the server and the UI
/// are eventually consistent.
///
/// ---
///
/// The action is not throttled or debounced in any way, and every dispatch
/// applies an optimistic update to the state immediately. This guarantees a
/// very good user experience, because there is immediate feedback on every
/// interaction.
///
/// However, while the first updated value (created by the first time the action
/// is dispatched) is immediately sent to the server, any other value changes
/// that occur while the first request is in flight will NOT be sent immediately.
///
/// Instead, when the first request completes, it checks if the state is still
/// the same as the value that was sent. If not, a follow-up request is sent
/// with the latest value. This process repeats until the state stabilizes.
///
/// Note this guarantees that at most one request is in flight at a time per
/// key, potentially reducing the number of requests sent to the server while
/// still coalescing intermediate changes.
///
/// Optionally:
///
/// * If the server responds with a value, that value is applied to the state.
///   This is useful when the server normalizes or modifies values.
///
/// * When the state finally stabilizes and the request finishes, a
///   callback is called, allowing you to perform side-effects.
///
/// * In special, if the last request fails, the optimistic state remains, but
/// you can then load the current state from the server or handle the error as
/// you see first by returning a value that will be applied to the state.
///
/// In other words, the mixin makes it easy for you to maintain perfect UI
/// responsiveness while minimizing server load, and making sure the server and
/// the UI eventually agree on the same value.
///
/// ---
///
/// ## How it works
///
/// 1. **Immediate UI feedback**: Every dispatch applies [valueToApply] to the
///    state immediately via [applyOptimisticValueToState].
///
/// 2. **Single in-flight request**: Only one request runs at a time per key
///    (as defined by [stableSyncKeyParams]). The first dispatch acquires a lock
///    and calls [sendValueToServer] to send a request to the server.
///
/// 3. **StableSync changes**: If the store state changed while a request started
///    by [sendValueToServer] was in flight (for example, the user tapped a
///    "like" button again while the first request was pending), a follow-up
///    request is automatically sent after the current one completes. The change
///    is detected by comparing [getValueFromState] with the sent value returned
///    by [valueToApply].
///
/// 4. **No unnecessary requests**: If, while the request is in-flight, the
///    state changes but then returns to the same value as before (for example,
///    the user tapped a "like" button again TWICE while the first request was
///    pending), [getValueFromState] matches the sent value and no follow-up
///    request is needed.
///
/// 5. **Server response handling**: If [sendValueToServer] returns a non-null
///    value, it is applied to the state via [applyServerResponseToState] when
///    the state stabilizes. This is optional but useful.
///
/// 6. **Completion callback**: When the state stabilizes and the last request
///    finishes, [onFinish] is called, allowing you to handle errors or perform
///    side-effects, like showing a message or reloading data.
///
/// ```
/// State: liked = false (server confirmed)
///
/// User taps LIKE:
///   → State: liked = true (optimistic)
///   → Lock acquired, Request 1 sends: setLiked(true)
///
/// User taps UNLIKE (Request 1 still in flight):
///   → State: liked = false (optimistic)
///   → No request sent (locked)
///
/// User taps LIKE (Request 1 still in flight):
///   → State: liked = true (optimistic)
///   → No request sent (locked)
///
/// Request 1 completes:
///   → Sent value was `true`, current state is `true`
///   → They match, no follow-up needed, lock released
/// ```
///
/// If the state had been `false` when Request 1 completed, a follow-up
/// Request 2 would automatically be sent with `false`.
///
/// ## Usage
///
/// ```dart
/// class ToggleLike extends AppAction with StableSync<AppState, bool> {
///   final String itemId;
///   ToggleLike(this.itemId);
///
///   // Different items can have concurrent requests
///   @override
///   Object? stableSyncKeyParams() => itemId;
///
///   // The new value to apply (toggle current state)
///   @override
///   bool valueToApply() => !state.items[itemId].liked;
///
///   // Apply the optimistic value to the state
///   @override
///   AppState applyOptimisticValueToState(bool isLiked) =>
///       state.copyWith(items: state.items.setLiked(itemId, isLiked));
///
///   // Apply the server response to the state (can be different from optimistic)
///   @override
///   AppState? applyServerResponseToState(Object? serverResponse) =>
///       state.copyWith(items: state.items.setLiked(itemId, serverResponse as bool));
///
///   // Read the current value from state (used to detect if follow-up needed)
///   @override
///   Object? getValueFromState(AppState state) => state.items[itemId].liked;
///
///   // Send the value to the server, optionally return server-confirmed value
///   @override
///   Future<Object?> sendValueToServer(Object? optimisticValue) async {
///     final response = await api.setLiked(itemId, optimisticValue);
///     return response.liked; // Or return null if server doesn't return a value
///   }
///
///   // Called when state stabilizes (optional). Return state to apply, or null.
///   @override
///   Future<AppState?> onFinish(Object? error) async {
///     if (error != null) {
///       // Handle error: reload from server to restore correct state
///       final reloaded = await api.getItem(itemId);
///       return state.copyWith(items: state.items.update(itemId, reloaded));
///     }
///     return null; // Success, no state change needed
///   }
/// }
/// ```
///
/// ## Server response handling
///
/// [sendValueToServer] can return a value from the server. If non-null, this value is
/// applied to the state **only when the state stabilizes** (no pending changes).
/// This is useful when:
/// - The server normalizes or modifies values
/// - You want to confirm the server accepted the change
/// - The server returns the current state after the update
///
/// If the server response differs from the current optimistic state when the
/// state stabilizes, a follow-up request will be sent automatically.
///
/// ## Error handling
///
/// On failure, the optimistic state remains and [onFinish] is called with
/// the error.
///
/// ## Difference from other mixins
///
/// - **vs [Debounce]**: Debounce waits for inactivity before sending *any*
///   request. StableSync sends the first request immediately and only coalesces
///   subsequent changes.
///
/// - **vs [NonReentrant]**: NonReentrant aborts subsequent dispatches entirely.
///   StableSync applies the optimistic update and queues a follow-up request.
///
/// - **vs [OptimisticUpdate]**: OptimisticUpdate has rollback logic that breaks
///   with concurrent dispatches. StableSync is designed for rapid toggling where
///   only the final state matters.
///
/// Notes:
/// - It should not be combined with [NonReentrant], [Throttle], [Debounce],
///   [OptimisticUpdate], or [Fresh].
///
mixin StableSync<St, T> on ReduxAction<St> {
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

      // Increment for this dispatch
      var entry = _revisionMap[key];
      int newLocalRev = (entry?.localRevision ?? 0) + 1;
      _revisionMap[key] = (
        localRevision: newLocalRev,
        serverRevision: entry?.serverRevision,
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
    return _revisionMap[key]?.serverRevision ?? 0;
  }

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
    var entry = _revisionMap[key];

    // Only update if newer (or first time)
    int? currentServerRev = entry?.serverRevision;
    if (currentServerRev == null || revision > currentServerRev) {
      _revisionMap[key] = (
        localRevision: entry?.localRevision ?? 0,
        serverRevision: revision,
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
      DateTime.fromMillisecondsSinceEpoch(_serverRevision());

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

  /// Override to return `true` if your app receives server-pushed updates
  /// (e.g., via WebSockets) that may modify the same state this action controls.
  ///
  /// When `true`, the mixin uses revision-based synchronization instead of
  /// value-based comparison. This correctly handles the case where a push
  /// update arrives and modifies state while a request is in flight.
  ///
  /// **When to use:**
  /// - Your app listens to real-time updates (WebSocket, SSE, Firebase, etc.)
  /// - Multiple devices can modify the same data
  /// - You want "last write wins" semantics across devices
  ///
  /// **How it works:**
  /// - Each local dispatch increments a `localRevision` counter
  /// - Server-pushed updates do NOT increment localRevision
  /// - Follow-up logic compares revisions instead of values
  /// - This prevents push updates from incorrectly marking state as "stable"
  ///
  /// **Example:**
  /// ```dart
  /// class ToggleLikeAction extends ReduxAction<AppState>
  ///     with StableSync<AppState, bool> {
  ///
  ///   @override
  ///   bool get isPushCompatible => true;
  ///
  ///   @override
  ///   Future<Object?> sendValueToServer(Object? value) async {
  ///     int localRev = localRevision(); // Get current revision
  ///     var response = await api.setLiked(itemId, value, localRev: localRev);
  ///     informServerRevision(response.serverRev); // Track server revision
  ///     return response.liked;
  ///   }
  ///   // ... other overrides
  /// }
  /// ```
  ///
  /// **Default:** `false` (uses value-based comparison for backward compatibility)
  ///
  bool get isPushCompatible => false;

  @override
  Future<St?> reduce() async {
    _cannotCombineStableSyncWithOtherMixins();

    // Reset the flag so localRevision() can increment for this dispatch.
    _localRevisionCalled = false;

    // Compute and cache the key for this dispatch.
    _currentKey = computeStableSyncKey();

    // When push compatible, automatically track revisions for every dispatch.
    // This ensures blocked dispatches also increment the revision counter.
    if (isPushCompatible) {
      localRevision();
    }

    var value = valueToApply();

    // Always apply optimistic update immediately.
    dispatchState(applyOptimisticValueToState(state, value));

    // If locked, another request is in flight. The optimistic update is
    // already applied, so just return. When the in-flight request completes,
    // it will check if a follow-up is needed.
    if (_stableSyncKeySet.contains(_currentKey)) {
      return null;
    }

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
      })> get _revisionMap => store.internalMixinProps.revisionMap;

  /// Sends the request and handles follow-up requests if the state changed
  /// while the request was in flight.
  ///
  /// When revision tracking is enabled (via calling [localRevision]), the
  /// follow-up logic is based on comparing localRevision values instead of
  /// state values. This correctly handles the case where server-pushed updates
  /// modify the state while a request is in flight.
  Future<void> _sendAndFollowUp(Object? key, T sentValue) async {
    T _sentValue = sentValue;

    int requestCount = 0;

    while (true) {
      requestCount++;

      // Capture the localRev we're sending (if using revisions).
      // This must be captured BEFORE calling sendValueToServer, so that
      // when the user calls localRevision() inside sendValueToServer,
      // they get the same value (no dispatch can happen in between since
      // this is synchronous code).
      final int? sentLocalRev =
          isPushCompatible ? _getLocalRevision(key) : null;

      // Reset _informedServerRev before each request so we can detect
      // whether the user called informServerRevision() during sendValueToServer.
      _informedServerRev = null;

      try {
        // Send the value and get the server's response (may be null).
        final Object? serverResponse = await sendValueToServer(_sentValue);

        // Check if state changed while we were sending.
        final stateValue = getValueFromState(state);

        // Determine if we need a follow-up request.
        bool needFollowUp;

        if (isPushCompatible) {
          // Revision-based comparison:
          // If the current localRevision is greater than what we sent,
          // it means new local intent arrived while our request was in flight.
          // We need to send a follow-up to sync the latest intent.
          final int currentLocalRev = _getLocalRevision(key);
          needFollowUp = currentLocalRev > sentLocalRev!;
        } else {
          // Original value-based comparison (for backwards compatibility):
          // If the state value changed, we need a follow-up.
          needFollowUp = ifShouldSendAnotherRequest(
            stateValue: stateValue,
            sentValue: _sentValue,
            requestCount: requestCount,
          );
        }

        if (needFollowUp) {
          // Do NOT apply the server response yet (the state is not yet stable).
          // We need a follow-up request. Loop again with the new value.
          _sentValue = stateValue;
          continue;
        }
        //
        else {
          // State matches what we sent, we're done. State has stabilized.
          // Now apply the server response if one was returned.
          if (serverResponse != null) {
            // Determine if the response should be applied.
            // If the user called informServerRevision(), we check if it's still
            // the newest (no newer push arrived). If the user didn't call it
            // (backward compatibility), we apply unconditionally.
            final bool shouldApply = _informedServerRev == null ||
                _informedServerRev == _serverRevision();

            if (shouldApply) {
              var newState = applyServerResponseToState(state, serverResponse);
              if (newState != null) dispatchState(newState);
            }
          }

          // Release lock and call onFinish with no error.
          _stableSyncKeySet.remove(key);
          await _callOnFinish(null);
          break; // Exit the loop
        }
      } catch (error) {
        // Request failed. Release lock and call onFinish with the error.
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
    _incompatible<StableSync, NonReentrant>(this);
    _incompatible<StableSync, Throttle>(this);
    _incompatible<StableSync, OptimisticUpdate>(this);
    _incompatible<StableSync, Fresh>(this);

    // Works with Debounce!!!!!!!!
    // Works with Debounce!!!!!!!!
    // Works with Debounce!!!!!!!!
    // Works with Debounce!!!!!!!!
    // Works with Debounce!!!!!!!!
    // Works with Debounce!!!!!!!!
    // Works with Debounce!!!!!!!!
    // _incompatible<StableSync, Debounce>(this);
  }
}

void _incompatible<T1, T2>(Object instance) {
  assert(
    instance is! T2,
    'The ${T1.toString().split('<').first} mixin '
    'cannot be combined with the ${T2.toString().split('<').first} mixin.',
  );
}
