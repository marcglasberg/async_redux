// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// Based upon packages redux by Brian Egan, and flutter_redux by Brian Egan and John Ryan.
// Uses code from package equatable by Felix Angelov.
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

import 'dart:async';

import 'package:async_redux/async_redux.dart';

class ProcessPersistence<St> {
  //
  ProcessPersistence(this.persistor, this.lastPersistedState)
      : isPersisting = false,
        isANewStateAvailable = false,
        lastPersistTime = DateTime.now().toUtc(),
        isPaused = false,
        isInit = false;

  final Persistor persistor;
  St? lastPersistedState;
  late St newestState;
  bool isPersisting;
  bool isANewStateAvailable;
  DateTime lastPersistTime;
  Timer? timer;
  bool isPaused;
  bool isInit;

  /// Completes when the persistence operation currently running finishes.
  Completer<void>? _operationFinished;

  /// True if a [PersistAction] was dispatched while a persistence operation was running.
  bool _isPersistActionWaiting = false;

  /// True if [persistAndPause] was called while a persistence operation was running.
  bool _isPersistAndPauseWaiting = false;

  /// The newest state when [persistAndPause] was called while a persistence operation
  /// was running. It's persisted when the operation finishes, if not yet persisted.
  late St _stateToPersistAndPause;

  /// Called when [Persistor.persistDifference] throws an error, after the error was processed
  /// by [Persistor.wrapError] (and only if it didn't return `null`). The [error] is the
  /// wrapped error, and [originalError] is the error before [Persistor.wrapError].
  /// It should return the error that should be thrown (as an unhandled async error),
  /// or `null` to swallow it. If not set, the wrapped error is thrown.
  Object? Function(Object error, Object originalError, StackTrace stackTrace)? onError;

  Duration get throttle => persistor.throttle ?? const Duration();

  /// Same as [Persistor.saveInitialState] but will remember [initialState] as the [lastPersistedState].
  /// If a save is running, waits for it to finish first, so that it can't overwrite the
  /// [initialState] later.
  Future<void> saveInitialState(St initialState) => _runAlone(() async {
        lastPersistedState = initialState;
        await persistor.saveInitialState(initialState);
      });

  /// Same as [Persistor.readState] but will remember the read state as the [lastPersistedState].
  /// If a save is running, waits for it to finish first, so that it reads the saved state,
  /// and so that the save can't change the [lastPersistedState] later.
  Future<St?> readState() async {
    St? state;
    await _runAlone(() async {
      state = await persistor.readState();
      lastPersistedState = state;
    });
    return state;
  }

  /// Same as [Persistor.deleteState] but will clear the [lastPersistedState].
  /// If a save is running, waits for it to finish first, so that it can't put the deleted
  /// state back later.
  Future<void> deleteState() => _runAlone(() async {
        lastPersistedState = null;
        await persistor.deleteState();
      });

  /// Runs the [operation] when no other persistence operation is running, so that they
  /// don't overlap. While it runs, state changes are not saved. They are saved when it
  /// finishes, if necessary.
  Future<void> _runAlone(Future<void> Function() operation) async {
    while (isPersisting) await _operationFinished!.future;
    _startOperation();
    try {
      await operation();
    } finally {
      _finishOperation();
    }
  }

  void _startOperation() {
    isPersisting = true;
    _operationFinished = Completer<void>();
  }

  void _finishOperation() {
    isPersisting = false;
    _operationFinished!.complete();
    _operationFinished = null;

    processAddedErrors();

    bool persistAndPauseWaiting = _isPersistAndPauseWaiting;
    bool persistActionWaiting = _isPersistActionWaiting;
    bool newStateAvailable = isANewStateAvailable;
    _isPersistAndPauseWaiting = false;
    _isPersistActionWaiting = false;
    isANewStateAvailable = false;

    // If persistAndPause was called while the operation was running, persist now the
    // state it was called with, ignoring the throttle and the pause. State changes made
    // after it was called are only persisted when the persistor is resumed.
    if (persistAndPauseWaiting &&
        !identical(lastPersistedState, _stateToPersistAndPause)) {
      _persist(DateTime.now().toUtc(), _stateToPersistAndPause);

      // If the state changed after persistAndPause was called, check again when this
      // save finishes, in case the persistor was resumed.
      if (!identical(_stateToPersistAndPause, newestState)) {
        isANewStateAvailable = true;
        _isPersistActionWaiting = persistActionWaiting;
      }
    }
    //
    // If the state may have changed while the operation was running, persist it if
    // necessary. If a PersistAction was dispatched meanwhile, ignore the throttle.
    else if (newStateAvailable) _process(isPersistAction: persistActionWaiting);
  }

  /// Processes the errors added by [Persistor.addError], removing them from the persistor.
  /// Each error is given to [onError], and if it returns an error, it's thrown as an
  /// unhandled async error.
  void processAddedErrors() {
    while (true) {
      var addedError = persistor.getAndRemoveFirstError();
      if (addedError == null) break;
      var (error, stackTrace) = addedError;

      Object? processedError = (onError == null) //
          ? error
          : onError!(error, error, stackTrace);

      if (processedError != null)
        Future(() => Error.throwWithStackTrace(processedError, stackTrace));
    }
  }

  /// 1) If we're still persisting the last time, don't persist no matter what.
  ///    Instead, check again when it finishes.
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
    isInit = true;
    newestState = newState;
    return _process(isPersistAction: action is PersistAction);
  }

  bool _process({required bool isPersistAction}) {
    //
    // 1) If we're still persisting the last time, don't persist no matter what.
    // Instead, check again when it finishes. This is done even if the newest state is
    // the last persisted state, since the running process will change the last
    // persisted state when it finishes.
    if (isPersisting) {
      isANewStateAvailable = true;
      if (isPersistAction && !isPaused) _isPersistActionWaiting = true;
      return false;
    }
    //
    else if (isPaused || identical(lastPersistedState, newestState))
      return false;
    //
    else {
      //
      var now = DateTime.now().toUtc();

      // 2) If throttle period is done (or if action is PersistAction), persist.
      if ( //
          (now.difference(lastPersistTime) >= throttle) //
              ||
              isPersistAction //
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
          Duration asSoonAsThrottleFinishes =
              throttle - now.difference(lastPersistTime);

          timer = Timer(asSoonAsThrottleFinishes, () {
            timer = null;
            _process(isPersistAction: false);
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
    _startOperation();
    lastPersistTime = now;
    isANewStateAvailable = false;

    try {
      await persistor.persistDifference(
        lastPersistedState: lastPersistedState,
        newState: newState,
      );

      // Only consider the state persisted if it succeeded. Otherwise, the next time we persist,
      // the difference will be calculated from the last state that was actually persisted.
      lastPersistedState = newState;
    }
    //
    catch (error, stackTrace) {
      Object? processedError;

      try {
        processedError = persistor.wrapError(error, stackTrace);
      } catch (_error) {
        // If the persistor's wrapError throws an error, it will be used instead
        // of the original error (but the recommended way is returning the error).
        processedError = _error;
      }

      if (processedError != null && onError != null)
        processedError = onError!(processedError, error, stackTrace);

      if (processedError != null) Error.throwWithStackTrace(processedError, stackTrace);
    }
    //
    finally {
      // If a new state became available while the present state was saving, save again.
      _finishOperation();
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
  /// When [persistAndPause] is called, if no persistence process is running, it will
  /// immediately start a new persistence process (ignoring [throttle]). If one is currently
  /// running, it will not be affected, and the state at the time of the call will be
  /// persisted as soon as it finishes (if it's not yet persisted). State changes made
  /// after the call are not persisted until [resume] is called.
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

    if (isPersisting) {
      if (isInit) {
        _isPersistAndPauseWaiting = true;
        _stateToPersistAndPause = newestState;
      }
    } else
      _persistIfNotYetPersisted();
  }

  void _persistIfNotYetPersisted() {
    if (isInit && !identical(lastPersistedState, newestState)) {
      var now = DateTime.now().toUtc();
      _persist(now, newestState);
    }
  }

  /// Resumes persistence by the [Persistor], after calling [pause] or [persistAndPause].
  void resume() {
    isPaused = false;
    if (isInit) _process(isPersistAction: false);
  }
}
