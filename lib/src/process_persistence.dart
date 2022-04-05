import 'dart:async';

import 'package:async_redux/async_redux.dart';

class ProcessPersistence<St> {
  //
  ProcessPersistence(this.persistor)
      : isPersisting = false,
        newStateAvailable = false,
        lastPersistTime = DateTime.now().toUtc();

  Persistor persistor;
  St? lastPersistedState;
  late St newestState;
  bool isPersisting;
  bool newStateAvailable;
  DateTime lastPersistTime;
  Timer? timer;

  Duration get throttle => persistor.throttle ?? const Duration();

  /// 1) If we're still persisting the last time, don't persist no matter what.
  /// 2) If action is PersistAction, persist immediately.
  /// 3) If throttle period is done, persist.
  /// 4) If throttle period is NOT done, create a timer to persist as soon as it finishes.
  /// Return true if the persist process started.
  /// Return false if persistence was postponed.
  bool process(
    ReduxAction<St>? action,
    St newState,
  ) {
    newestState = newState;

    // 1) If we're still persisting the last time, don't persist no matter what.
    if (isPersisting) {
      newStateAvailable = true;
      return false;
    }
    //
    else {
      //
      var now = DateTime.now().toUtc();

      // 2) If action is PersistAction, persist immediately.
      if (action is PersistAction) {
        _cancelTimer();
        _persist(now, newState);
        return true;
      }
      //
      // 3) If throttle period is done, persist.
      else if (now.difference(lastPersistTime) >= throttle) {
        _persist(now, newState);
        return true;
      }
      //
      // 4) If throttle period is NOT done, create a timer to persist as soon as it finishes.
      else {
        if (timer == null) {
          Duration duration = throttle - now.difference(lastPersistTime);
          timer = Timer(duration, () {
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

  void _persist(DateTime now, newState) {
    isPersisting = true;
    lastPersistTime = now;
    newStateAvailable = false;

    persistor
        .persistDifference(
      lastPersistedState: lastPersistedState,
      newState: newState,
    )
        .whenComplete(() {
      lastPersistedState = newState;
      isPersisting = false;

      // If a new state became available while the present state was saving, save again.
      if (newStateAvailable) {
        newStateAvailable = false;
        process(null, newestState);
      }
    });
  }

  /// Pause the [Persistor] temporarily.
  ///
  /// In more detail, it will pause starting a persistence process. But if a persistence process is
  /// currently running (the [persistDifference] method was called and has not yet finished) it
  /// will first finish it.
  ///
  /// Persistence will resume when you call [resumePersistor].
  ///
  void pausePersistor() {}

  /// Call this to resume the [Persistor], after calling [pausePersistor].
  void resumePersistor() {}
}
