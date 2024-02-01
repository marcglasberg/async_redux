// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// Based upon packages redux by Brian Egan, and flutter_redux by Brian Egan and John Ryan.
// Uses code from package equatable by Felix Angelov.
// For more info, see: https://pub.dartlang.org/packages/async_redux

library async_redux_store;

import 'dart:async';
import 'dart:collection';

import 'package:async_redux/async_redux.dart';
import 'package:async_redux/src/process_persistence.dart';

part 'redux_action.dart';

typedef Reducer<St> = FutureOr<St?> Function();

typedef Dispatch<St> = FutureOr<ActionStatus> Function(
  ReduxAction<St> action, {
  bool notify,
});

typedef DispatchSync<St> = ActionStatus Function(
  ReduxAction<St> action, {
  bool notify,
});

typedef DispatchAsync<St> = Future<ActionStatus> Function(
  ReduxAction<St> action, {
  bool notify,
});

/// Creates a Redux store that holds the app state.
///
/// The only way to change the state in the store is to dispatch a ReduxAction.
/// You may implement these methods:
///
/// 1) `AppState reduce()` ➜
///    To run synchronously, just return the state:
///         AppState reduce() { ... return state; }
///    To run asynchronously, return a future of the state:
///         Future<AppState> reduce() async { ... return state; }
///    Note that changing the state is optional. If you return null (or Future of null)
///    the state will not be changed. Just the same, if you return the same instance
///    of state (or its Future) the state will not be changed.
///
/// 2) `FutureOr<void> before()` ➜ Runs before the reduce method.
///    If it throws an error, then `reduce` will NOT run.
///    To run `before` synchronously, just return void:
///         void before() { ... }
///    To run asynchronously, return a future of void:
///         Future<void> before() async { ... }
///    Note: If this method runs asynchronously, then `reduce` will also be async,
///    since it must wait for this one to finish.
///
/// 3) `void after()` ➜ Runs after `reduce`, even if an error was thrown by
/// `before` or `reduce` (akin to a "finally" block). If the `after` method itself
/// throws an error, this error will be "swallowed" and ignored. Avoid `after`
/// methods which can throw errors.
///
/// 4) `bool abortDispatch()` ➜ If this returns true, the action will not be
/// dispatched: `before`, `reduce` and `after` will not be called, and the action
/// will not be visible to the `StoreTester`. This is only useful under rare
/// circumstances, and you should only use it if you know what you are doing.
///
/// 5) `Object wrapError(error)` ➜ If any error is thrown by `before` or `reduce`,
/// you have the chance to further process it by using `wrapError`. Usually this
/// is used to wrap the error inside of another that better describes the failed action.
/// For example, if some action converts a String into a number, then instead of
/// throwing a FormatException you could do:
/// `wrapError(error) => UserException("Please enter a valid number.", cause: error)`
///
/// ---
///
/// • ActionObserver observes the dispatching of actions,
///   and may be used to print or log the dispatching of actions.
///
/// • StateObservers receive the action, stateIni (state right before the action),
///   stateEnd (state right after the action), and are used to log and save state.
///
/// • ErrorObservers may be used to observe or process errors thrown by actions.
///
/// For more info, see: https://pub.dartlang.org/packages/async_redux
///
class Store<St> {
  Store({
    required St initialState,
    Object? environment,
    bool syncStream = false,
    TestInfoPrinter? testInfoPrinter,
    List<ActionObserver<St>>? actionObservers,
    List<StateObserver<St>>? stateObservers,
    Persistor<St>? persistor,
    ModelObserver? modelObserver,
    ErrorObserver<St>? errorObserver,
    WrapReduce<St>? wrapReduce,
    WrapError<St>? wrapError,
    bool? defaultDistinct,
    CompareBy? immutableCollectionEquality,
    int? maxErrorsQueued,
  })  : _state = initialState,
        _environment = environment,
        _stateTimestamp = DateTime.now().toUtc(),
        _changeController = StreamController.broadcast(sync: syncStream),
        _actionObservers = actionObservers,
        _stateObservers = stateObservers,
        _processPersistence = persistor == null
            ? //
            null
            : ProcessPersistence(persistor, initialState),
        _modelObserver = modelObserver,
        _errorObserver = errorObserver,
        _wrapError = wrapError,
        _wrapReduce = wrapReduce,
        _defaultDistinct = defaultDistinct ?? true,
        _immutableCollectionEquality = immutableCollectionEquality,
        _errors = Queue<UserException>(),
        _maxErrorsQueued = maxErrorsQueued ?? 10,
        _dispatchCount = 0,
        _reduceCount = 0,
        _shutdown = false,
        _testInfoPrinter = testInfoPrinter,
        _testInfoController = (testInfoPrinter == null)
            ? //
            null
            : StreamController.broadcast(sync: syncStream);

  St _state;

  final Object? _environment;

  Object? get env => _environment;

  DateTime _stateTimestamp;

  /// The current state of the app.
  St get state => _state;

  /// The timestamp of the current state in the store, in UTC.
  DateTime get stateTimestamp => _stateTimestamp;

  bool get defaultDistinct => _defaultDistinct;

  /// 1) If `null` (the default), view-models which are immutable collections will be compared
  /// by their default equality.
  ///
  /// 2) If `CompareBy.byDeepEquals`, view-models which are immutable collections will be compared
  /// by their items, one by one (potentially slow comparison).
  ///
  /// 3) If `CompareBy.byIdentity`, view-models which are immutable collections will be compared
  /// by their internals being identical (very fast comparison).
  ///
  /// Note: This works with immutable collections `IList`, `ISet`, `IMap` and `IMapOfSets` from
  /// the https://pub.dev/packages/fast_immutable_collections package.
  ///
  CompareBy? get immutableCollectionEquality => _immutableCollectionEquality;

  ModelObserver? get modelObserver => _modelObserver;

  int get dispatchCount => _dispatchCount;

  int get reduceCount => _reduceCount;

  final StreamController<St> _changeController;

  final List<ActionObserver>? _actionObservers;

  final List<StateObserver>? _stateObservers;

  final ProcessPersistence<St>? _processPersistence;

  final ModelObserver? _modelObserver;

  final ErrorObserver<St>? _errorObserver;

  final WrapError<St>? _wrapError;

  final WrapReduce<St>? _wrapReduce;

  final bool _defaultDistinct;

  final CompareBy? _immutableCollectionEquality;

  final Queue<UserException> _errors;

  /// [UserException]s may be queued to be shown to the user by a
  /// [UserExceptionDialog] widgets. Usually, if you are not planning on using
  /// that dialog (or something similar) you should probably not throw
  /// [UserException]s, so this should not be a problem. Still, to further
  /// prevent memory problems, there is a maximum number of exceptions the
  /// queue can hold.
  final int _maxErrorsQueued;

  bool _shutdown;

  // For testing:
  int _dispatchCount;
  int _reduceCount;
  TestInfoPrinter? _testInfoPrinter;
  StreamController<TestInfo<St>>? _testInfoController;

  TestInfoPrinter? get testInfoPrinter => _testInfoPrinter;

  /// A stream that emits the current state when it changes.
  ///
  /// # Example
  ///
  ///     // Create the Store;
  ///     final store = new Store<int>(initialState: 0);
  ///
  ///     // Listen to the Store's onChange stream, and print the latest
  ///     // state to the console whenever the reducer produces a new state.
  ///     // Store StreamSubscription as a variable, so you can stop listening later.
  ///     final subscription = store.onChange.listen(print);
  ///
  ///     // Dispatch some actions, which prints the state.
  ///     store.dispatch(IncrementAction());
  ///
  ///     // When you want to stop printing, cancel the subscription.
  ///     subscription.cancel();
  ///
  Stream<St> get onChange => _changeController.stream;

  /// Used by the storeTester.
  Stream<TestInfo<St>> get onReduce => (_testInfoController != null)
      ? //
      _testInfoController!.stream
      : Stream<TestInfo<St>>.empty();

  /// Pause the [Persistor] temporarily.
  ///
  /// When [pausePersistor] is called, the Persistor will not start a new persistence process, until method
  /// [resumePersistor] is called. This will not affect the current persistence process, if one is currently
  /// running.
  ///
  /// Note: A persistence process starts when the [Persistor.persistDifference] method is called,
  /// and finishes when the future returned by that method completes.
  ///
  void pausePersistor() {
    _processPersistence?.pause();
  }

  /// Persists the current state (if it's not yet persisted), then pauses the [Persistor]
  /// temporarily.
  ///
  ///
  /// When [persistAndPausePersistor] is called, this will not affect the current persistence
  /// process, if one is currently running. If no persistence process was running, it will
  /// immediately start a new persistence process (ignoring [Persistor.throttle]).
  ///
  /// Then, the Persistor will not start another persistence process, until method
  /// [resumePersistor] is called.
  ///
  /// Note: A persistence process starts when the [Persistor.persistDifference] method is called,
  /// and finishes when the future returned by that method completes.
  ///
  void persistAndPausePersistor() {
    _processPersistence?.persistAndPause();
  }

  /// Resumes persistence by the [Persistor],
  /// after calling [pausePersistor] or [persistAndPausePersistor].
  void resumePersistor() {
    _processPersistence?.resume();
  }

  /// Asks the [Persistor] to save the [initialState] in the local persistence.
  Future<void> saveInitialStateInPersistence(St initialState) async {
    return _processPersistence?.saveInitialState(initialState);
  }

  /// Asks the [Persistor] to read the state from the local persistence.
  /// Important: If you use this, you MUST put this state into the store.
  /// The Persistor will assume that's the case, and will not work properly otherwise.
  Future<St?> readStateFromPersistence() async {
    return _processPersistence?.readState();
  }

  /// Asks the [Persistor] to delete the saved state from the local persistence.
  Future<void> deleteStateFromPersistence() async {
    return _processPersistence?.deleteState();
  }

  /// Gets, from the [Persistor], the last state that was saved to the local persistence.
  St? getLastPersistedStateFromPersistor() => _processPersistence?.lastPersistedState;

  /// Turns on testing capabilities, if not already.
  void initTestInfoController() {
    _testInfoController ??= StreamController.broadcast(sync: false);
  }

  /// Changes the testInfoPrinter.
  void initTestInfoPrinter(TestInfoPrinter testInfoPrinter) {
    _testInfoPrinter = testInfoPrinter;
    initTestInfoController();
  }

  /// Beware: Changes the state directly. Use only for TESTS.
  void defineState(St state) {
    _state = state;
    _stateTimestamp = DateTime.now().toUtc();
  }

  /// Returns a future which will complete when the given [condition] is true.
  /// The condition can access the state. You may also provide a
  /// [timeoutInSeconds], which by default is null (never times out).
  Future<void> waitCondition(
    bool Function(St) condition, {
    int? timeoutInSeconds,
  }) async {
    var conditionTester = StoreTester.simple(this);
    try {
      await conditionTester.waitCondition(
        (TestInfo<St>? info) => condition(info!.state),
        timeoutInSeconds: timeoutInSeconds,
      );
    } finally {
      await conditionTester.cancel();
    }
  }

  /// Adds an error at the end of the error queue.
  void _addError(UserException error) {
    if (_errors.length > _maxErrorsQueued) _errors.removeFirst();
    _errors.addLast(error);
  }

  /// Gets the first error from the error queue, and removes it from the queue.
  UserException? getAndRemoveFirstError() => //
      (_errors.isEmpty) //
          ? null
          : _errors.removeFirst();

  /// Call this method to shut down the store.
  /// It won't accept dispatches or change the state anymore.
  void shutdown() {
    _shutdown = true;
  }

  bool get isShutdown => _shutdown;

  /// Runs the action, applying its reducer, and possibly changing the store state.
  /// The action may be sync or async. Note: [dispatch] is of type [Dispatch].
  FutureOr<ActionStatus> dispatch(ReduxAction<St> action, {bool notify = true}) =>
      _dispatch(action, notify: notify);

  /// Runs the action, applying its reducer, and possibly changing the store state.
  /// Note: [dispatchAsync] is of type [DispatchAsync]. It returns `Future<ActionStatus>`,
  /// which means you can `await` it.
  Future<ActionStatus> dispatchAsync(ReduxAction<St> action, {bool notify = true}) =>
      Future.value(_dispatch(action, notify: notify));

  /// Runs the action, applying its reducer, and possibly changing the store state.
  /// Note: [dispatchSync] is of type [DispatchSync].
  /// If the action is async, it will throw a [StoreException].
  ActionStatus dispatchSync(ReduxAction<St> action, {bool notify = true}) {
    if (!_ifActionIsSync(action)) {
      throw StoreException(
          "Can't dispatchSync(${action.runtimeType}) because ${action.runtimeType} is async.");
    }

    return _dispatch(action, notify: notify) as ActionStatus;
  }

  FutureOr<ActionStatus> _dispatch(ReduxAction<St> action, {required bool notify}) {
    // The action may access the store/state/dispatch as fields.
    action.setStore(this);

    if (_shutdown || action.abortDispatch()) return ActionStatus();

    _dispatchCount++;

    if (_actionObservers != null)
      for (ActionObserver observer in _actionObservers) {
        observer.observe(action, dispatchCount, ini: true);
      }

    return _processAction(action, notify: notify);
  }

  void createTestInfoSnapshot(
    St state,
    ReduxAction<St> action,
    Object? error,
    Object? processedError, {
    required bool ini,
  }) {
    if (_testInfoController != null || testInfoPrinter != null) {
      var reduceInfo = TestInfo<St>(
        state,
        ini,
        action,
        error,
        processedError,
        dispatchCount,
        reduceCount,
        errors,
      );
      if (_testInfoController != null) _testInfoController!.add(reduceInfo);
      if (testInfoPrinter != null) testInfoPrinter!(reduceInfo);
    }
  }

  Queue<UserException> get errors => Queue<UserException>.of(_errors);

  /// We check the return type of methods `before` and `reduce` to decide if the
  /// reducer is synchronous or asynchronous. It's important to run the reducer
  /// synchronously, if possible.
  FutureOr<ActionStatus> _processAction(
    ReduxAction<St> action, {
    bool notify = true,
  }) {
    //
    if (_ifActionIsSync(action)) {
      return _processAction_Sync(action, notify: notify);
    } else
      return _processAction_Async(action, notify: notify);
  }

  bool _ifActionIsSync(ReduxAction<St> action) {
    //
    /// Note: before MUST check that it's NOT Future<void> Function(),
    /// because checking if it's void Function() doesn't work.
    bool beforeMethodIsSync = action.before is! Future<void> Function();

    bool reduceMethodIsSync = action.reduce is St? Function();

    return (beforeMethodIsSync && reduceMethodIsSync);
  }

  /// We check the return type of methods `before` and `reduce` to decide if the
  /// reducer is synchronous or asynchronous. It's important to run the reducer
  /// synchronously, if possible.
  ActionStatus _processAction_Sync(
    ReduxAction<St> action, {
    bool notify = true,
  }) {
    //
    // Creates the "INI" test snapshot.
    createTestInfoSnapshot(state!, action, null, null, ini: true);

    // The action may access the store/state/dispatch as fields.
    assert(action.store == this);

    var afterWasRun = _Flag<bool>(false);

    Object? originalError, processedError;

    try {
      action._status._clear();
      var result = action.before();
      if (result is Future) throw StoreException(_beforeTypeErrorMsg);

      action._status._isBeforeDone = true;
      if (_shutdown) return action._status;
      _applyReducer(action, notify: notify);
      action._status._isReduceDone = true;
      if (_shutdown) return action._status;
    }
    //
    catch (error, stackTrace) {
      originalError = error;
      processedError = _processError(action, error, stackTrace, afterWasRun);

      // Error is meant to be "swallowed".
      if (processedError == null)
        return action._status;
      //
      // Error was not changed. Rethrow.
      else if (identical(processedError, error))
        rethrow;
      //
      // Error was wrapped. Throw.
      else
        Error.throwWithStackTrace(processedError, stackTrace);
    }
    //
    finally {
      _finalize(action, originalError, processedError, afterWasRun);
    }

    return action._status;
  }

  /// We check the return type of methods `before` and `reduce` to decide if the
  /// reducer is synchronous or asynchronous. It's important to run the reducer
  /// synchronously, if possible.
  Future<ActionStatus> _processAction_Async(
    ReduxAction<St> action, {
    bool notify = true,
  }) async {
    //
    // Creates the "INI" test snapshot.
    createTestInfoSnapshot(state!, action, null, null, ini: true);

    // The action may access the store/state/dispatch as fields.
    assert(action.store == this);

    var afterWasRun = _Flag<bool>(false);

    Object? result, originalError, processedError;

    try {
      action._status._clear();
      result = action.before();
      if (result is Future) await result;
      action._status._isBeforeDone = true;
      if (_shutdown) return action._status;
      result = _applyReducer(action, notify: notify);
      if (result is Future) await result;
      action._status._isReduceDone = true;
      if (_shutdown) return action._status;
    }
    //
    catch (error, stackTrace) {
      originalError = error;
      processedError = _processError(action, error, stackTrace, afterWasRun);
      // Error is meant to be "swallowed".
      if (processedError == null)
        return action._status;
      // Error was not changed. Rethrows.
      else if (identical(processedError, error))
        rethrow;
      // Error was wrapped. Throw.
      else
        Error.throwWithStackTrace(processedError, stackTrace);
    }
    //
    finally {
      _finalize(action, originalError, processedError, afterWasRun);
    }

    return action._status;
  }

  static const _beforeTypeErrorMsg =
      "Before should return `void` or `Future<void>`. Do not return `FutureOr`.";

  static const _reducerTypeErrorMsg = "Reducer should return `St?` or `Future<St?>`. ";

  static const _wrapReducerTypeErrorMsg = "WrapReduce should return `St?` or `Future<St?>`. ";

  void _checkReducerType(FutureOr<St?> Function() reduce, bool wrapped) {
    //
    // Sync reducer is acceptable.
    if (reduce is St? Function()) {
      return;
    }
    //
    // Async reducer is acceptable.
    else if (reduce is Future<St?> Function()) {
      return;
    }
    //
    else if (reduce is Future<St>? Function()) {
      throw StoreException((wrapped ? _wrapReducerTypeErrorMsg : _reducerTypeErrorMsg) +
          "Do not return `Future<St>?`.");
    }
    //
    else if (reduce is Future<St?>? Function()) {
      throw StoreException((wrapped ? _wrapReducerTypeErrorMsg : _reducerTypeErrorMsg) +
          "Do not return `Future<St?>?`.");
    }
    //
    // ignore: unnecessary_type_check
    else if (reduce is FutureOr Function()) {
      throw StoreException((wrapped ? _wrapReducerTypeErrorMsg : _reducerTypeErrorMsg) +
          "Do not return `FutureOr`.");
    }
    //
    else {
      throw StoreException((wrapped ? _wrapReducerTypeErrorMsg : _reducerTypeErrorMsg) +
          "Do not return `${reduce.runtimeType}`.");
    }
  }

  FutureOr<void> _applyReducer(ReduxAction<St> action, {bool notify = true}) {
    _reduceCount++;

    // Make sure the action reducer returns an acceptable type.
    _checkReducerType(action.reduce, false);

    Reducer<St> reducer = action.wrapReduce(action.reduce);

    // Make sure the wrapReduce also returns an acceptable type.
    _checkReducerType(action.reduce, true);

    if (_wrapReduce != null) reducer = _wrapReduce.wrapReduce(reducer, this);

    // Sync reducer.
    if (reducer is St? Function()) {
      _registerState(reducer(), action, notify: notify);
    }
    //
    // Async reducer.
    else if (reducer is Future<St?> Function()) {
      /// When a reducer returns a state, we need to apply that state immediately in the store.
      /// If we wait even a single microtask, another reducer may change the store-state before we
      /// have the chance to apply the state. This would result in the later reducer overriding the
      /// value of the other reducer, and state changes will be lost.
      ///
      /// To fix this we'll depend on the behavior described below, which was confirmed by the Dart
      /// team:
      ///
      /// 1) When a future returned by an async function completes, it will call the `then` method
      /// synchronously (in the same microtask), as long as the function returns a value (not a
      /// Future) AND this happens AFTER at least one await. This means we then have the chance to
      /// apply the returned state to the store right away.
      ///
      /// 2) When a future returned by an async function completes, it will call the `then` method
      /// asynchronously (delayed to a later microtask) if there was no await in the async
      /// function. When that happens, the future is created "completed", and Dart will wait for
      /// the next microtask before calling the `then` method (they do this because they want to
      /// enforce that a listener on a future is always notified in a later microtask than the one
      /// where it was registered). This means we will only be able to apply the returned state to
      /// the store during the next microtask. There is now a chance state will be lost.
      /// This situation must be avoided at all cost, and it's actually simple to solve it:
      /// An async reducer must never complete without at least one await.
      /// Unfortunately, if the developer forgets to add the await, there is no way for AsyncRedux
      /// to let them know about it, because there is no way for us to know if a Future is
      /// completed. The completion information exists in the `FutureImpl` class but it's not
      /// exposed. I have asked the Dart team to expose this information, but they refused. The
      /// only solution is to document this and trust the developer.
      ///
      /// Important: The behavior described above was confirmed by the Dart team, but it's NOT
      /// documented. In other words, they make no promise that it will be kept in the future.
      /// If that ever changes, AsyncRedux will need to change too, so that reducers return
      /// `St? Function(state)` instead of returning `state`. For example, instead of a reducer
      /// ending with `return state.copy(123)` it would be `return (state) => state.copy(123)`.
      /// Hopefully, the tests in `sync_async_test.dart` will catch this, if it ever changes.

      action._completedFuture = false;

      return reducer().then((state) {
        _registerState(state, action, notify: notify);

        if (action._completedFuture) {
          Future.error("The reducer of action ${action.runtimeType} returned a completed Future. "
              "This may result in state changes being lost. "
              "Please make sure all code paths in the reducer pass through at least one `await`. "
              "If necessary, add `await microtask;` to the start of the reducer.");
        }
      });
    }
    // Not accepted.
    else {
      throw StoreException("Reducer should return `St?` or `Future<St?>`. "
          "Do not return `FutureOr<St?>`. "
          "Reduce is of type: '${reducer.runtimeType}'.");
    }
  }

  /// Adds the state to the changeController, but only if the `reduce` method
  /// did not returned null, and if it did not return the same identical state.
  ///
  /// Note: We compare the state using `identical` (which is fast).
  ///
  /// The [StateObserver]s are always called (if defined). If you need to know if the state was
  /// changed or not, you can compare `bool ifStateChanged = identical(stateIni, stateEnd)`
  void _registerState(
    St? state,
    ReduxAction<St> action, {
    bool notify = true,
  }) {
    if (_shutdown) return;

    St stateIni = _state;

    // Reducers may return null state, or the unaltered state,
    // when they don't want to change the state.
    if (state != null && !identical(_state, state)) {
      _state = state;
      _stateTimestamp = DateTime.now().toUtc();

      if (notify) {
        _changeController.add(state);
      }
    }
    St stateEnd = _state;

    if (_stateObservers != null)
      for (StateObserver observer in _stateObservers) {
        observer.observe(action, stateIni, stateEnd, null, dispatchCount);
      }

    if (_processPersistence != null)
      _processPersistence.process(
        action,
        stateEnd,
      );
  }

  /// Returns the processed error. Returns `null` if the error is meant to be "swallowed".
  Object? _processError(
    ReduxAction<St> action,
    Object error,
    StackTrace stackTrace,
    _Flag<bool> afterWasRun,
  ) {
    if (_stateObservers != null)
      for (StateObserver observer in _stateObservers) {
        observer.observe(action, _state, _state, error, dispatchCount);
      }

    Object? errorOrNull = error;
    try {
      errorOrNull = action.wrapError(errorOrNull, stackTrace);
    } catch (_error, stackTrace) {
      // Errors thrown by the action's wrapError.
      // WrapError should never throw. It should return an error.
      _throws(
        "Method '${action.runtimeType}.wrapError()' "
        "has thrown an error:\n '$_error'.",
        errorOrNull,
        stackTrace,
      );
    }

    if (_wrapError != null && errorOrNull != null) {
      try {
        errorOrNull = _wrapError.wrap(errorOrNull, stackTrace, action) ?? errorOrNull;
      } catch (_error) {
        // Errors thrown by the global wrapError.
        // WrapError should never throw. It should return an error.
        _throws(
          "Method 'WrapError.wrap()' "
          "has thrown an error:\n '$_error'.",
          errorOrNull,
          stackTrace,
        );
      }
    }

    afterWasRun.value = true;
    _after(action);

    // Memorizes errors of type UserException (in the error queue).
    // These errors are usually shown to the user in a modal dialog, and are not logged.
    if (errorOrNull is UserException) {
      _addError(errorOrNull);
      _changeController.add(state);
    }

    // If an errorObserver was NOT defined, return (to throw) errors which are not UserException.
    if (_errorObserver == null) {
      if (errorOrNull is! UserException) return errorOrNull;
    }
    // If an errorObserver was defined, observe the error.
    // Then, if the observer returns true, return the error to be thrown.
    else if (errorOrNull != null) {
      if (_errorObserver.observe(errorOrNull, stackTrace, action, this)) //
        return errorOrNull;
    }

    return null;
  }

  void _finalize(
    ReduxAction<St> action,
    Object? error,
    Object? processedError,
    _Flag<bool> afterWasRun,
  ) {
    if (!afterWasRun.value) _after(action);

    createTestInfoSnapshot(state!, action, error, processedError, ini: false);

    if (_actionObservers != null)
      for (ActionObserver observer in _actionObservers) {
        observer.observe(action, dispatchCount, ini: false);
      }
  }

  void _after(ReduxAction<St> action) {
    try {
      action.after();
      action._status._isAfterDone = true;
    } catch (error, stackTrace) {
      // After should never throw.
      // However, if it does, prints the error information to the console,
      // then throw the error after an asynchronous gap.
      _throws(
        "Method '${action.runtimeType}.after()' "
        "has thrown an error:\n '$error'.",
        error,
        stackTrace,
      );
    }
  }

  /// Closes down the store so it will no longer be operational.
  /// Only use this if you want to destroy the Store while your app is running.
  /// Do not use this method as a way to stop listening to onChange state changes.
  /// For that purpose, view the onChange documentation.
  Future teardown({St? emptyState}) async {
    if (emptyState != null) _state = emptyState;
    _stateTimestamp = DateTime.now().toUtc();
    return _changeController.close();
  }

  /// Throws the error after an asynchronous gap.
  void _throws(errorMsg, Object? error, StackTrace stackTrace) {
    Future(() {
      Error.throwWithStackTrace(
        (error == null) ? errorMsg : "$errorMsg:\n  $error",
        stackTrace,
      );
    });
  }
}

//

enum CompareBy { byDeepEquals, byIdentity }

class ActionStatus {
  bool _isBeforeDone = false;
  bool _isReduceDone = false;
  bool _isAfterDone = false;

  bool get isBeforeDone => _isBeforeDone;

  bool get isReduceDone => _isReduceDone;

  bool get isAfterDone => _isAfterDone;

  bool get isFinished => _isBeforeDone && _isReduceDone && _isAfterDone;

  void _clear() {
    _isBeforeDone = false;
    _isReduceDone = false;
    _isAfterDone = false;
  }
}

class _Flag<T> {
  T value;

  _Flag(this.value);

  @override
  bool operator ==(Object other) => true;

  @override
  int get hashCode => 0;
}
