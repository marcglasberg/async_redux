import 'dart:async';

import 'package:async_redux/async_redux.dart';

class ProcessPersistence<St> {
  //
  ProcessPersistence(this.persistor)
      : isPersisting = false,
        isANewStateAvailable = false,
        lastPersistTime = DateTime.now().toUtc(),
        isPaused = false;

  final Persistor persistor;
  St? lastPersistedState;
  late St newestState;
  bool isPersisting;
  bool isANewStateAvailable;
  DateTime lastPersistTime;
  Timer? timer;
  bool isPaused;

  Duration get throttle => persistor.throttle ?? const Duration();

  /// 1) If we're still persisting the last time, don't persist no matter what.
  /// 2) If throttle period is done (or if action is PersistAction), persist.
  /// 3) If throttle period is NOT done, create a timer to persist as soon as it finishes.
  ///
  /// Return true if the persist process started.
  /// Return false if persistence was postponed.
  ///
  bool process(
    ReduxAction<St>? action,
    St newState,
  ) {
    newestState = newState;

    if (isPaused || identical(lastPersistedState, newState)) return false;

    // 1) If we're still persisting the last time, don't persist no matter what.
    if (isPersisting) {
      isANewStateAvailable = true;
      return false;
    }
    //
    else {
      //
      var now = DateTime.now().toUtc();

      // 2) If throttle period is done (or if action is PersistAction), persist.
      if ( //
          (now.difference(lastPersistTime) >= throttle) //
              ||
              (action is PersistAction) //
          ) {
        _cancelTimer();
        _persist(now, newestState);
        return true;
      }
      //
      // 3) If throttle period is NOT done, create a timer to persist as soon as it finishes.
      else {
        if (timer == null) {
          //
          Duration asSoonAsThrottleFinishes = throttle - now.difference(lastPersistTime);

          timer = Timer(asSoonAsThrottleFinishes, () {
            timer = null;
            process(null, newestState);
          });
        }
        return false;
      }
    }
  }

  void _cancelTimer() {
    if (timer != null) {
      timer!.cancel();
      timer = null;
    }
  }

  void _persist(DateTime now, newState) async {
    isPersisting = true;
    lastPersistTime = now;
    isANewStateAvailable = false;

    try {
      await persistor.persistDifference(
        lastPersistedState: lastPersistedState,
        newState: newState,
      );
    }
    //
     finally {
      lastPersistedState = newState;
      isPersisting = false;

      // If a new state became available while the present state was saving, save again.
      if (isANewStateAvailable) {
        isANewStateAvailable = false;
        process(null, newestState);
      }
    }
  }

  /// Pause the [Persistor] temporarily.
  ///
  /// When [pause] is called, the Persistor will not start a new persistence process, until method
  /// [resume] is called. This will not affect the current persistence process, if one is currently
  /// running.
  ///
  /// Note: A persistence process starts when the [persistDifference] method is called, and
  /// finishes when the future returned by that method completes.
  ///
  void pause() {
    isPaused = true;
  }

  /// Persists the current state (if it's not yet persisted), then pauses the [Persistor]
  /// temporarily.
  ///
  ///
  /// When [persistAndPause] is called, this will not affect the current persistence process, if
  /// one is currently running. If no persistence process was running, it will immediately start a
  /// new persistence process (ignoring [throttle]).
  ///
  /// Then, the Persistor will not start another persistence process, until method [resume] is
  /// called.
  ///
  /// Note: A persistence process starts when the [persistDifference] method is called, and
  /// finishes when the future returned by that method completes.
  ///
  void persistAndPause() {
    isPaused = true;

    _cancelTimer();

    if (!isPersisting && !identical(lastPersistedState, newestState)) {
      var now = DateTime.now().toUtc();
      _persist(now, newestState);
    }
  }

  /// Resumes persistence by the [Persistor], after calling [pause] or [persistAndPause].
  void resume() {
    isPaused = false;
    process(null, newestState);
  }

  /// Asks the [Persistor] to delete the saved state from the persistence.
  Future<void> deletePersistedState() {
    return persistor.deleteState();
  }
}
