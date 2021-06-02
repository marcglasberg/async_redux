library async_redux_store;

import 'dart:async';
import 'dart:collection';

import 'package:async_redux/async_redux.dart';
import 'package:async_redux/src/process_persistence.dart';

part 'redux_action.dart';

// Developed by Marcelo Glasberg (Aug 2019).
// Based upon packages redux by Brian Egan, and flutter_redux by Brian Egan and John Ryan.
// Uses code from package equatable by Felix Angelov.
// For more info, see: https://pub.dartlang.org/packages/async_redux

// /////////////////////////////////////////////////////////////////////////////

typedef Reducer<St> = FutureOr<St?> Function();

typedef Dispatch<St> = void Function(
  ReduxAction<St> action, {
  bool notify,
});

typedef DispatchFuture<St> = Future<void> Function(
  ReduxAction<St> action, {
  bool notify,
});

typedef DispatchX<St> = FutureOr<ActionStatus> Function(
  ReduxAction<St> action, {
  bool notify,
});

// /////////////////////////////////////////////////////////////////////////////

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
/// `wrapError(error) => UserException("Please enter a valid number.", error: error)`
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
    bool syncStream = false,
    TestInfoPrinter? testInfoPrinter,
    List<ActionObserver>? actionObservers,
    List<StateObserver>? stateObservers,
    Persistor? persistor,
    ModelObserver? modelObserver,
    ErrorObserver? errorObserver,
    WrapError? wrapError,
    bool? defaultDistinct,
    CompareBy? immutableCollectionEquality,
  })  : _state = initialState,
        _stateTimestamp = DateTime.now().toUtc(),
        _changeController = StreamController.broadcast(sync: syncStream),
        _actionObservers = actionObservers,
        _stateObservers = stateObservers,
        _processPersistence = persistor == null
            ? //
            null
            : ProcessPersistence(persistor),
        _modelObserver = modelObserver,
        _errorObserver = errorObserver,
        _wrapError = wrapError,
        _defaultDistinct = defaultDistinct ?? true,
        _immutableCollectionEquality = immutableCollectionEquality,
        _errors = Queue<UserException>(),
        _dispatchCount = 0,
        _reduceCount = 0,
        _shutdown = false,
        _testInfoPrinter = testInfoPrinter,
        _testInfoController = (testInfoPrinter == null)
            ? //
            null
            : StreamController.broadcast(sync: syncStream);

  St _state;

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

  final ProcessPersistence? _processPersistence;

  final ModelObserver? _modelObserver;

  final ErrorObserver? _errorObserver;

  final WrapError? _wrapError;

  final bool _defaultDistinct;

  final CompareBy? _immutableCollectionEquality;

  final Queue<UserException> _errors;

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
  void _addError(UserException error) => _errors.addLast(error);

  /// Gets the first error from the error queue, and removes it from the queue.
  UserException? getAndRemoveFirstError() => (_errors.isEmpty)
      ? //
      null
      : _errors.removeFirst();

  /// Call this method to shut down the store.
  /// It won't accept dispatches or change the state anymore.
  void shutdown() {
    _shutdown = true;
  }

  bool get isShutdown => _shutdown;

  /// Runs the action, applying its reducer, and possibly changing the store state.
  /// Note: store.dispatch is of type Dispatch.
  void dispatch(ReduxAction<St> action, {bool notify = true}) {
    _dispatch(action, notify: notify);
  }

  Future<void> dispatchFuture(ReduxAction<St> action, {bool notify = true}) async =>
      _dispatch(action, notify: notify);

  FutureOr<ActionStatus> dispatchX(ReduxAction<St> action, {bool notify = true}) =>
      _dispatch(action, notify: notify);

  FutureOr<ActionStatus> _dispatch(ReduxAction<St> action, {required bool notify}) async {
    // The action may access the store/state/dispatch as fields.
    action.setStore(this);

    if (_shutdown || action.abortDispatch()) return ActionStatus();

    _dispatchCount++;

    if (_actionObservers != null)
      for (ActionObserver observer in _actionObservers!) {
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
      processedError = _processError(error, stackTrace, action, afterWasRun);
      // Error is meant to be "swallowed".
      if (processedError == null)
        return action._status;
      // Error was not changed. Rethrows.
      else if (identical(processedError, error))
        rethrow;
      // Error was wrapped. Rethrows, but loses stacktrace due to Dart architecture.
      // See: https://groups.google.com/a/dartlang.org/forum/#!topic/misc/O1OKnYTUcoo
      // See: https://github.com/dart-lang/sdk/issues/10297
      // This should be fixed when this issue is solved: https://github.com/dart-lang/sdk/issues/30741
      else
        throw processedError;
    }
    //
     finally {
      _finalize(action, originalError, processedError, afterWasRun);
    }

    return action._status;
  }

  FutureOr<void> _applyReducer(ReduxAction<St> action, {bool notify = true}) {
    _reduceCount++;

    Reducer<St?> reducer = action.wrapReduce(action.reduce);

    // Sync reducer.
    if (reducer is St? Function()) {
      St? result = reducer();
      _registerState(result, action, notify: notify);
    }
    //
    // Async reducer.
    else if (reducer is Future<St?> Function()) {
      // Make sure it's NOT a completed future.
      Future<St?> result = (() async {
        await Future.microtask(() {});
        return reducer();
      })();

      // The "then callback" will be applied synchronously,
      // immediately after we get the result,
      // only because we're sure the future is NOT completed.
      return result.then((state) => _registerState(
            state,
            action,
            notify: notify,
          ));
    }
    // Not defined.
    else {
      throw StoreException("Reducer should return `St?` or `Future<St?>`. "
          "Do not return `FutureOr<St?>`. "
          "Reduce is of type: '${reducer.runtimeType}'.");
    }
  }

  /// Adds the state to the changeController, but only if the `reduce` method
  /// did not returned null, and if it did not return the same identical state.
  /// Note: We compare the state using `identical` (which is fast).
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
      for (StateObserver observer in _stateObservers!) {
        observer.observe(action, stateIni, stateEnd, dispatchCount);
      }

    if (_processPersistence != null)
      _processPersistence!.process(
        action,
        stateEnd,
      );
  }

  /// Returns the processed error. Returns `null` if the error is meant to be "swallowed".
  Object? _processError(
    Object? error,
    StackTrace stackTrace,
    ReduxAction<St> action,
    _Flag<bool> afterWasRun,
  ) {
    try {
      error = action.wrapError(error);
    } catch (_error, stackTrace) {
      // Errors thrown by the action's wrapError.
      // WrapError should never throw. It should return an error.
      _throws(
        "Method '${action.runtimeType}.wrapError()' "
        "has thrown an error:\n '$_error'.",
        error,
        stackTrace,
      );
    }

    if (_wrapError != null && error != null) {
      try {
        error = _wrapError!.wrap(error, stackTrace, action) ?? error;
      } catch (_error) {
        // Errors thrown by the global wrapError.
        // WrapError should never throw. It should return an error.
        _throws(
          "Method 'WrapError.wrap()' "
          "has thrown an error:\n '$_error'.",
          error,
          stackTrace,
        );
      }
    }

    afterWasRun.value = true;
    _after(action);

    // Memorizes errors of type UserException (in the error queue).
    // These errors are usually shown to the user in a modal dialog, and are not logged.
    if (error is UserException) {
      _addError(error);
      _changeController.add(state);
    }

    // If an errorObserver was NOT defined, return (to throw) errors which are not UserException.
    if (_errorObserver == null) {
      if (error is! UserException) return error;
    }
    // If an errorObserver was defined, observe the error.
    // Then, if the observer returns true, return the error to be thrown.
    else if (error != null) {
      if (_errorObserver!.observe(error, stackTrace, action, this)) //
        return error;
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
      for (ActionObserver observer in _actionObservers!) {
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

  /// Prints the error/stacktrace information to the console,
  /// then throws the error after an asynchronous gap.
  /// Note: We print the stacktrace because the rethrow loses
  /// the stacktrace due to Dart architecture.
  ///  See: https://groups.google.com/a/dartlang.org/forum/#!topic/misc/O1OKnYTUcoo
  ///  See: https://github.com/dart-lang/sdk/issues/10297
  ///  This should be fixed when this issue is solved: https://github.com/dart-lang/sdk/issues/30741
  ///
  void _throws(errorMsg, error, StackTrace? stackTrace) {
    if (errorMsg != null) print(errorMsg);
    if (stackTrace != null) {
      print("\nStackTrace:\n$stackTrace");
      print("--- End of the StackTrace\n\n");
    }

    Future(() {
      throw error;
    });
  }
}

// /////////////////////////////////////////////////////////////////////////////

enum CompareBy { byDeepEquals, byIdentity }

// /////////////////////////////////////////////////////////////////////////////

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

// /////////////////////////////////////////////////////////////////////////////

class _Flag<T> {
  T value;

  _Flag(this.value);

  @override
  bool operator ==(Object other) => true;

  @override
  int get hashCode => 0;
}

// /////////////////////////////////////////////////////////////////////////////
