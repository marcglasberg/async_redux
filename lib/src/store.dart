import 'dart:async';
import 'dart:collection';

import 'package:async_redux/async_redux.dart';
import 'package:async_redux/src/process_persistence.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

// Developed by Marcelo Glasberg (Aug 2019).
// Based upon packages redux by Brian Egan, and flutter_redux by Brian Egan and John Ryan.
// Uses code from package equatable by Felix Angelov.
// For more info, see: https://pub.dartlang.org/packages/async_redux

// /////////////////////////////////////////////////////////////////////////////

typedef Dispatch<St> = void Function(
  ReduxAction<St> action, {
  bool notify,
});

typedef DispatchFuture<St> = Future<void> Function(
  ReduxAction<St> action, {
  bool notify,
});

typedef TestInfoPrinter = void Function(TestInfo);

class TestInfo<St> {
  final St state;
  final bool ini;
  final ReduxAction<St> action;
  final int dispatchCount;
  final int reduceCount;

  /// List of all UserException's waiting to be displayed in the error dialog.
  Queue<UserException> errors;

  /// The error thrown by the action, if any,
  /// before being processed by the action's wrapError() method.
  final Object error;

  /// The error thrown by the action,
  /// after being processed by the action's wrapError() method.
  final Object processedError;

  bool get isINI => ini;

  bool get isEND => !ini;

  Type get type {
    // Removes the generic type from UserExceptionAction, WaitAction,
    // NavigateAction and PersistAction.
    // For example UserExceptionAction<AppState> becomes UserExceptionAction<dynamic>.
    if (action is UserExceptionAction) {
      if (action.runtimeType.toString().split('<')[0] == 'UserExceptionAction') //
        return UserExceptionAction;
    } else if (action is WaitAction) {
      if (action.runtimeType.toString().split('<')[0] == 'WaitAction') //
        return WaitAction;
    } else if (action is NavigateAction) {
      if (action.runtimeType.toString().split('<')[0] == 'NavigateAction') //
        return NavigateAction;
    } else if (action is PersistAction) {
      if (action.runtimeType.toString().split('<')[0] == 'PersistAction') //
        return PersistAction;
    }

    return action.runtimeType;
  }

  TestInfo(
    this.state,
    this.ini,
    this.action,
    this.error,
    this.processedError,
    this.dispatchCount,
    this.reduceCount,
    this.errors,
  ) : assert(state != null);

  @override
  String toString() => 'D:$dispatchCount '
      'R:$reduceCount '
      '= $action ${ini ? "INI" : "END"}\n';
}

// /////////////////////////////////////////////////////////////////////////////

/// During development, use this error observer if you want all errors to be
/// shown to the user in a dialog, not only UserExceptions. In more detail:
/// This will wrap all errors into UserExceptions, and put them all into the
/// error queue. Note that errors which are NOT originally UserExceptions will
/// still be thrown, while UserExceptions will still be swallowed.
///
/// Passe it to the store like this:
///
/// `var store = Store(errorObserver:DevelopmentErrorObserver());`
///
class DevelopmentErrorObserver<St> implements ErrorObserver<St> {
  @override
  bool observe(
    Object error,
    StackTrace stackTrace,
    ReduxAction<St> action,
    Store store,
  ) {
    if (error is UserException)
      return false;
    else {
      UserException errorAsUserException = UserException(
        error.toString(),
        cause: error,
      );
      store._addError(errorAsUserException);
      store._changeController.add(store.state);
      return true;
    }
  }
}

/// Swallows all errors (not recommended). Passe it to the store like this:
///
/// `var store = Store(errorObserver:SwallowErrorObserver());`
///
class SwallowErrorObserver<St> implements ErrorObserver<St> {
  @override
  bool observe(
    Object error,
    StackTrace stackTrace,
    ReduxAction<St> action,
    Store store,
  ) {
    return false;
  }
}

/// This model observer prints the StoreConnector's ViewModel to the console.
///
/// Passe it to the store like this:
///
/// `var store = Store(modelObserver:DefaultModelObserver());`
///
/// If you need to print the type of the `StoreConnector` to the console,
/// make sure to pass `debug:this` as a `StoreConnector` constructor parameter.
/// Then, optionally, you can also specify a list of `StoreConnector`s to be
/// observed:
///
/// `DefaultModelObserver([MyStoreConnector, SomeOtherStoreConnector]);`
///
/// You can also override your `ViewModels.toString()` to print out
/// any extra info you need.
///
class DefaultModelObserver<Model> implements ModelObserver<Model> {
  Model _previous;
  Model _current;

  Model get previous => _previous;

  Model get current => _current;

  final List<Type> _storeConnectorTypes;

  DefaultModelObserver([this._storeConnectorTypes = const <Type>[]]);

  @override
  void observe({
    Model modelPrevious,
    Model modelCurrent,
    bool isDistinct,
    StoreConnector storeConnector,
    int reduceCount,
    int dispatchCount,
  }) {
    _previous = modelPrevious;
    _current = modelCurrent;

    var shouldObserve = (_storeConnectorTypes == null || //
            _storeConnectorTypes.isEmpty) ||
        _storeConnectorTypes.contains(storeConnector.debug?.runtimeType);

    if (shouldObserve)
      print("Model D:$dispatchCount R:$reduceCount = "
          "Rebuild:${isDistinct == null || isDistinct}, "
          "${storeConnector.debug == null ? "" : //
              "Connector:${storeConnector.debug.runtimeType}"}, "
          "Model:$modelCurrent.");
  }
}

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
    St initialState,
    bool syncStream = false,
    TestInfoPrinter testInfoPrinter,
    bool ifRecordsTestInfo,
    List<ActionObserver> actionObservers,
    List<StateObserver> stateObservers,
    Persistor persistor,
    ModelObserver modelObserver,
    ErrorObserver errorObserver,
    WrapError wrapError,
    bool defaultDistinct,
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

  int get dispatchCount => _dispatchCount;

  int get reduceCount => _reduceCount;

  final StreamController<St> _changeController;

  final List<ActionObserver> _actionObservers;

  final List<StateObserver> _stateObservers;

  final ProcessPersistence _processPersistence;

  final ModelObserver _modelObserver;

  final ErrorObserver _errorObserver;

  final WrapError _wrapError;

  final bool _defaultDistinct;

  final Queue<UserException> _errors;

  bool _shutdown;

  // For testing:
  int _dispatchCount;
  int _reduceCount;
  TestInfoPrinter _testInfoPrinter;
  StreamController<TestInfo<St>> _testInfoController;

  TestInfoPrinter get testInfoPrinter => _testInfoPrinter;

  /// Turns on testing capabilities, if not already.
  void initTestInfoController() {
    _testInfoController ??= StreamController.broadcast(sync: false);
  }

  /// Changes the testInfoPrinter.
  void initTestInfoPrinter(TestInfoPrinter testInfoPrinter) {
    _testInfoPrinter = testInfoPrinter;
    initTestInfoController();
  }

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
      _testInfoController.stream
      : Stream<TestInfo<St>>.empty();

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
    int timeoutInSeconds,
  }) async {
    var conditionTester = StoreTester.simple(this);
    try {
      await conditionTester.waitCondition(
        (TestInfo<St> info) => condition(info.state),
        timeoutInSeconds: timeoutInSeconds,
      );
    } finally {
      await conditionTester.cancel();
    }
  }

  /// Adds an error at the end of the error queue.
  void _addError(UserException error) => _errors.addLast(error);

  /// Gets the first error from the error queue, and removes it from the queue.
  UserException getAndRemoveFirstError() => (_errors.isEmpty)
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
    assert(action != null);

    // The action may access the store/state/dispatch as fields.
    action.setStore(this);

    if (_shutdown || action.abortDispatch()) return;

    _dispatchCount++;

    if (_actionObservers != null)
      for (ActionObserver observer in _actionObservers) {
        observer.observe(action, dispatchCount, ini: true);
      }

    _processAction(action, notify: notify);
  }

  Future<void> dispatchFuture(
    ReduxAction<St> action, {
    bool notify = true,
  }) async {
    assert(action != null);

    // The action may access the store/state/dispatch as fields.
    action.setStore(this);

    if (_shutdown || action.abortDispatch()) return;

    _dispatchCount++;

    if (_actionObservers != null)
      for (ActionObserver observer in _actionObservers) {
        observer.observe(action, dispatchCount, ini: true);
      }

    await _processAction(action, notify: notify);
  }

  void createTestInfoSnapshot(
    St state,
    ReduxAction<St> action,
    dynamic error,
    dynamic processedError, {
    @required bool ini,
  }) {
    assert(state != null);
    assert(action != null);
    assert(ini != null);

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
      if (_testInfoController != null) _testInfoController.add(reduceInfo);
      if (testInfoPrinter != null) testInfoPrinter(reduceInfo);
    }
  }

  Queue get errors => Queue<UserException>.of(_errors);

  /// We check the return type of methods `before` and `reduce` to decide if the
  /// reducer is synchronous or asynchronous. It's important to run the reducer
  /// synchronously, if possible.
  Future<void> _processAction(
    ReduxAction<St> action, {
    bool notify = true,
  }) async {
    //
    // Creates the "INI" test snapshot.
    createTestInfoSnapshot(state, action, null, null, ini: true);

    // The action may access the store/state/dispatch as fields.
    assert(action.store == this);

    var afterWasRun = _Flag<bool>(false);

    dynamic result;

    dynamic originalError;
    dynamic processedError;

    try {
      action._status = ActionStatus();
      result = action.before();
      if (result is Future) await result;
      action._status._isBeforeDone = true;
      if (_shutdown) return;
      result = _applyReducer(action, notify: notify);
      if (result is Future) await result;
      action._status._isReduceDone = true;
      if (_shutdown) return;
    } catch (error, stackTrace) {
      originalError = error;
      processedError = _processError(error, stackTrace, action, afterWasRun);
      // Error is meant to be "swallowed".
      if (processedError == null)
        return;
      // Error was not changed. Rethrows.
      else if (identical(processedError, error))
        rethrow;
      // Error was wrapped. Rethrows, but loses stacktrace due to Dart architecture.
      // See: https://groups.google.com/a/dartlang.org/forum/#!topic/misc/O1OKnYTUcoo
      // See: https://github.com/dart-lang/sdk/issues/10297
      // This should be fixed when this issue is solved: https://github.com/dart-lang/sdk/issues/30741
      else
        throw processedError;
    } finally {
      _finalize(result, action, originalError, processedError, afterWasRun);
    }
  }

  FutureOr<void> _applyReducer(ReduxAction<St> action, {bool notify = true}) {
    _reduceCount++;

    var reducer = action.wrapReduce(action.reduce);

    // Sync reducer.
    if (reducer is St Function()) {
      St result = reducer();
      _registerState(result, action, notify: notify);
    }
    //
    // Async reducer.
    else if (reducer is Future<St> Function()) {
      // Make sure it's NOT a completed future.
      Future<St> result = (() async {
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
    else if (reducer is FutureOr<St> Function()) {
      throw StoreException("Reducer should return `St` or `Future<St>`. "
          "Do not return `FutureOr<St>`.");
    }
  }

  // Old code:
  // FutureOr<void> _applyReducer(ReduxAction<St> action, {bool notify = true}) {
  //   _reduceCount++;
  //
  //   var result = action.wrapReduce(action.reduce)();
  //
  //   if (result is Future<St>) {
  //     return result.then((state) => _registerState(
  //           state,
  //           action,
  //           notify: notify,
  //         ));
  //   } else if (result is St || result == null) {
  //     _registerState(result, action, notify: notify);
  //   } else
  //     throw AssertionError();
  // }

  /// Adds the state to the changeController, but only if the `reduce` method
  /// did not returned null, and if it did not return the same identical state.
  /// Note: We compare the state using `identical` (which is fast).
  void _registerState(
    St state,
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
        observer.observe(action, stateIni, stateEnd, dispatchCount);
      }

    if (_processPersistence != null)
      _processPersistence.process(
        action,
        stateEnd,
      );
  }

  /// Returns the processed error. Returns `null` if the error is meant to be "swallowed".
  dynamic _processError(
    error,
    stackTrace,
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

    if (_wrapError != null) {
      try {
        error = _wrapError.wrap(error, stackTrace, action) ?? error;
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
    else {
      if (_errorObserver.observe(error, stackTrace, action, this)) //
        return error;
    }

    return null;
  }

  void _finalize(
    Future result,
    ReduxAction<St> action,
    dynamic error,
    dynamic processedError,
    _Flag<bool> afterWasRun,
  ) {
    if (!afterWasRun.value) _after(action);

    createTestInfoSnapshot(state, action, error, processedError, ini: false);

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
  Future teardown() async {
    _state = null;
    _stateTimestamp = DateTime.now().toUtc();
    return _changeController.close();
  }
}

// /////////////////////////////////////////////////////////////////////////////

class ActionStatus {
  bool _isBeforeDone = false;
  bool _isReduceDone = false;
  bool _isAfterDone = false;

  bool get isBeforeDone => _isBeforeDone;

  bool get isReduceDone => _isReduceDone;

  bool get isAfterDone => _isAfterDone;

  bool get isFinished => _isBeforeDone && _isReduceDone && _isAfterDone;
}

// /////////////////////////////////////////////////////////////////////////////

/// Actions must extend this class.
///
/// Important: Do NOT override operator == and hashCode. Actions must retain
/// their default [Object] comparison by identity, or the StoreTester may not work.
///
abstract class ReduxAction<St> {
  Store<St> _store;
  ActionStatus _status;

  void setStore(Store<St> store) => _store = store;

  Store<St> get store => _store;

  ActionStatus get status => _status;

  St get state => _store.state;

  /// Returns true only if the action finished with no errors.
  /// In other words, if the methods before, reduce and after all finished executing
  /// without throwing any errors.
  bool get hasFinished => _status.isFinished;

  DateTime get stateTimestamp => _store.stateTimestamp;

  Dispatch<St> get dispatch => _store.dispatch;

  DispatchFuture<St> get dispatchFuture => _store.dispatchFuture;

  /// This is an optional method that may be overridden to run during action
  /// dispatching, before `reduce`. If this method throws an error, the
  /// `reduce` method will NOT run, but the method `after` will.
  /// It may be synchronous (returning `void`) ou async (returning `Future<void>`).
  FutureOr<void> before() {}

  /// This is an optional method that may be overridden to run during action
  /// dispatching, after `reduce`. If this method throws an error, the
  /// error will be swallowed (will not throw). So you should only run code that
  /// can't throw errors. It may be synchronous only.
  /// Note this method will always be called,
  /// even if errors were thrown by `before` or `reduce`.
  void after() {}

  /// The `reduce` method is the action reducer. It may read the action state,
  /// the store state, and then return a new state (or `null` if no state
  /// change is necessary).
  ///
  /// It may be synchronous (returning `AppState` or `null`)
  /// or async (returning `Future<AppState>` or `Future<null>`).
  ///
  /// The `StoreConnector`s may rebuild only if the `reduce` method returns
  /// a state which is both not `null` and different from the previous one
  /// (comparing by `identical`, not `equals`).
  FutureOr<St> reduce();

  /// You may wrap the reducer to allow for some pre or post-processing.
  /// For example, if you want to abort an async reducer if the state
  /// changed since when the reducer started:
  /// ```
  /// Reducer<St> wrapReduce(Reducer<St> reduce) => () async {
  ///    var oldState = state;
  ///    AppState newState = await reduce();
  ///    return identical(oldState, state) ? newState : null;
  /// };
  /// ```
  Reducer<St> wrapReduce(Reducer<St> reduce) => reduce;

  /// If any error is thrown by `reduce` or `before`, you have the chance
  /// to further process it by using `wrapError`. Usually this is used to wrap
  /// the error inside of another that better describes the failed action.
  /// For example, if some action converts a String into a number, then instead of
  /// throwing a FormatException you could do:
  /// `wrapError(error) => UserException("Please enter a valid number.", error: error)`
  Object wrapError(error) => error;

  /// If this returns true, the action will not be dispatched: `before`, `reduce`
  /// and `after` will not be called, and the action will not be visible to the
  /// `StoreTester`. This is only useful under rare circumstances, and you should
  /// only use it if you know what you are doing.
  bool abortDispatch() => false;

  /// Nest state reducers without dispatching another action.
  /// Example: return AddTaskAction(demoTask).reduceWithState(state);
  @Deprecated("This is deprecated and will be removed soon, "
      "because it's more difficult to use than it seems. "
      "Unless you completely understand what you're doing,"
      "you should only used it with sync reducers.")
  FutureOr<St> reduceWithState(Store<St> store, St state) {
    setStore(store);
    _store.defineState(state);
    return reduce();
  }

  @override
  String toString() => 'Action ' + runtimeType.toString();
}

// /////////////////////////////////////////////////////////////////////////////

abstract class ActionObserver<St> {
  /// If `ini==true` this is right before the action is dispatched.
  /// If `ini==false` this is right after the action finishes.
  void observe(
    ReduxAction<St> action,
    int dispatchCount, {
    @required bool ini,
  });
}

abstract class StateObserver<St> {
  void observe(
    ReduxAction<St> action,
    St stateIni,
    St stateEnd,
    int dispatchCount,
  );
}

/// This will be given all errors, including those of type [UserException].
/// Return true to throw the error. False to swallow it.
///
/// Don't use the store to dispatch any actions, as this may have
/// unpredictable results.
///
abstract class ErrorObserver<St> {
  bool observe(
    Object error,
    StackTrace stackTrace,
    ReduxAction<St> action,
    Store<St> store,
  );
}

/// This will be given all errors (including of type UserException).
/// * If it returns something, it will be used instead of the
///   original exception.
/// * Otherwise, just return null, so that the original exception will
///   not be modified.
///
/// Note this wrapper is called AFTER [ReduxAction.wrapError],
/// and BEFORE the [ErrorObserver].
///
/// A common use case for this is to have a global place to convert some
/// exceptions into [UserException]s. For example, Firebase may throw some
/// PlatformExceptions in response to a bad connection to the server.
/// In this case, you may want to show the user a dialog explaining that the
/// connection is bad, which you can do by converting it to a [UserException].
/// Note, this could also be done in the [ReduxAction.wrapError], but then
/// you'd have to add it to all actions that use Firebase.
///
/// Another use case is when you want to throw UserException causes which
/// are not UserExceptions, but still show the original UserException
/// in a dialog to the user:
/// ```
/// Object wrap(Object error, [StackTrace stackTrace, ReduxAction<St> action]) {
///   if (error is UserException) {
///     var hardCause = error.hardCause();
///     if (hardCause != null) {
///       Future.microtask(() =>
///         Business.store.dispatch(UserExceptionAction.from(error.withoutHardCause())));
///       return hardCause;
///     }}
///   return null; }
/// ```
abstract class WrapError<St> {
  Object wrap(
    Object error,
    StackTrace stackTrace,
    ReduxAction<St> action,
  );
}

/// This will be given all errors, including those of type UserException.
/// Return true to throw the error. False to swallow it.
/// Note:
/// * When isDistinct==true, it means the widget rebuilt because the model changed.
/// * When isDistinct==false, it means the widget didn't rebuilt because the model hasn't changed.
/// * When isDistinct==null, it means the widget rebuilds everytime, and the model is not relevant.
abstract class ModelObserver<Model> {
  void observe({
    Model modelPrevious,
    Model modelCurrent,
    bool isDistinct,
    StoreConnector storeConnector,
    int reduceCount,
    int dispatchCount,
  });
}

// /////////////////////////////////////////////////////////////////////////////

/// Don't use, this is deprecated. Please, use the recommended [Vm] class.
/// This should only be used for IMMUTABLE classes.
/// Lets you implement equals/hashcode without having to override these methods.
abstract class BaseModel<St> {
  /// The List of properties which will be used to determine whether two BaseModels are equal.
  final List<Object> equals;

  /// You can pass the connector widget, in case the view-model needs any info from it.
  final Widget widget;

  /// The constructor takes an optional List of fields which will be used
  /// to determine whether two [BaseModel] are equal.
  BaseModel({this.equals = const [], this.widget})
      : assert(_onlyContainFieldsOfAllowedTypes(equals));

  /// Fields should not contain functions.
  static bool _onlyContainFieldsOfAllowedTypes(List equals) {
    equals.forEach((Object field) {
      if (field is Function)
        throw StoreException("ViewModel equals "
            "has an invalid field of type ${field.runtimeType}.");
    });

    return true;
  }

  void _setStore(St state, Store store) {
    _state = state;
    _dispatch = store.dispatch;
    _dispatchFuture = store.dispatchFuture;
    _getAndRemoveFirstError = store.getAndRemoveFirstError;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BaseModel &&
          runtimeType == other.runtimeType &&
          listEquals(
            equals,
            other.equals,
          );

  @override
  int get hashCode => runtimeType.hashCode ^ _propsHashCode;

  int get _propsHashCode {
    int hashCode = 0;
    equals.forEach((Object prop) => hashCode = hashCode ^ prop.hashCode);
    return hashCode;
  }

  St _state;
  Dispatch<St> _dispatch;
  DispatchFuture<St> _dispatchFuture;
  UserException Function() _getAndRemoveFirstError;

  BaseModel fromStore();

  St get state => _state;

  Dispatch<St> get dispatch => _dispatch;

  DispatchFuture<St> get dispatchFuture => _dispatchFuture;

  UserException Function() get getAndRemoveFirstError => //
      _getAndRemoveFirstError;

  @override
  String toString() => '$runtimeType{${equals.join(', ')}}';
}

// /////////////////////////////////////////////////////////////////////////////

/// [Vm] is a base class for your view-models.
///
/// A view-model is a helper object to a [StoreConnector] widget. It holds the
/// part of the Store state the corresponding dumb-widget needs, and may also
/// convert this state part into a more convenient format for the dumb-widget
/// to work with.
///
/// Each time the state changes, all [StoreConnector]s in the widget tree will
/// create a view-model, and compare it with the view-model they created with
/// the previous state. Only if the view-model changed, the [StoreConnector]
/// will rebuild. For this to work, you must implement equals/hashcode for the
/// view-model class. Otherwise, the [StoreConnector] will think the view-model
/// changed everytime, and thus will rebuild everytime. This wouldn't create any
/// visible problems to your app, but would be inefficient and maybe slow.
///
/// Using the [Vm] class you can implement equals/hashcode without having to
/// override these methods. Instead, simply list all fields (which are not
/// immutable, like functions) to the [equals] parameter in the constructor.
/// For example:
///
/// ```
/// ViewModel({this.counter, this.onIncrement}) : super(equals: [counter]);
/// ```
///
/// Each listed state will be compared by equality (==), unless it is of type
/// [VmEquals], when it will be compared by the [VmEquals.vmEquals] method,
/// which by default is a comparison by identity (but can be overridden).
///
@immutable
abstract class Vm {
  /// The List of properties which will be used to determine whether two BaseModels are equal.
  final List<Object> equals;

  /// The constructor takes an optional List of fields which will be used
  /// to determine whether two [Vm] are equal.
  Vm({this.equals = const []}) : assert(_onlyContainFieldsOfAllowedTypes(equals));

  /// Fields should not contain functions.
  static bool _onlyContainFieldsOfAllowedTypes(List equals) {
    equals.forEach((Object field) {
      if (field is Function)
        throw StoreException("ViewModel equals "
            "has an invalid field of type ${field.runtimeType}.");
    });

    return true;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Vm &&
            runtimeType == other.runtimeType &&
            _listEquals(
              equals,
              other.equals,
            );
  }

  bool _listEquals<T>(List<T> list1, List<T> list2) {
    if (list1 == null) return list2 == null;
    if (list2 == null || list1.length != list2.length) return false;
    if (identical(list1, list2)) return true;
    for (int index = 0; index < list1.length; index++) {
      var item1 = list1[index];
      var item2 = list2[index];

      if ((item1 is VmEquals<T>) &&
          (item2 is VmEquals<T>) //
          &&
          !item1.vmEquals(item2)) return false;

      if (item1 != item2) return false;
    }
    return true;
  }

  @override
  int get hashCode => runtimeType.hashCode ^ _propsHashCode;

  int get _propsHashCode {
    int hashCode = 0;
    equals.forEach((Object prop) => hashCode = hashCode ^ prop.hashCode);
    return hashCode;
  }

  @override
  String toString() => '$runtimeType{${equals.join(', ')}}';
}

// /////////////////////////////////////////////////////////////////////////////

abstract class VmEquals<T> {
  bool vmEquals(T other) => identical(this, other);
}

// /////////////////////////////////////////////////////////////////////////////

/// Factory that creates a view-model of type [Vm], for the [StoreConnector]:
///
/// ```
/// return StoreConnector<AppState, _ViewModel>(
///      vm: _Factory(),
///      builder: ...
/// ```
///
/// You must override the [fromStore] method:
///
/// ```
/// class _Factory extends VmFactory {
///    _ViewModel fromStore() => _ViewModel(
///        counter: state,
///        onIncrement: () => dispatch(IncrementAction(amount: 1)));
/// }
/// ```
///
/// If necessary, you can pass the [StoreConnector] widget to the factory:
///
/// ```
/// return StoreConnector<AppState, _ViewModel>(
///      vm: _Factory(this),
///      builder: ...
///
/// ...
/// class _Factory extends VmFactory<AppState, MyHomePageConnector> {
///    _Factory(widget) : super(widget);
///    _ViewModel fromStore() => _ViewModel(
///        counter: state,
///        onIncrement: () => dispatch(IncrementAction(amount: widget.amount)));
/// }
/// ```
///
abstract class VmFactory<St, T> {
  /// A reference to the connector widget that will instantiate the view-model.
  final T widget;

  /// You need to pass the connector widget only if the view-model needs any info from it.
  VmFactory([this.widget]);

  Vm fromStore();

  void _setStore(St state, Store store) {
    _state = state;
    _dispatch = store.dispatch;
    _dispatchFuture = store.dispatchFuture;
    _getAndRemoveFirstError = store.getAndRemoveFirstError;
  }

  St _state;
  Dispatch<St> _dispatch;
  DispatchFuture<St> _dispatchFuture;
  UserException Function() _getAndRemoveFirstError;

  St get state => _state;

  Dispatch<St> get dispatch => _dispatch;

  DispatchFuture<St> get dispatchFuture => _dispatchFuture;

  UserException Function() get getAndRemoveFirstError => //
      _getAndRemoveFirstError;
}

// /////////////////////////////////////////////////////////////////////////////

/// Provides a Redux [Store] to all ancestors of this Widget.
/// This should generally be a root widget in your App.
/// Connect to the Store provided by this Widget using a [StoreConnector].
class StoreProvider<St> extends InheritedWidget {
  final Store<St> _store;

  const StoreProvider({
    Key key,
    @required Store<St> store,
    @required Widget child,
  })  : assert(store != null),
        assert(child != null),
        _store = store,
        super(key: key, child: child);

  static Store<St> of<St>(BuildContext context, Object debug) {
    final StoreProvider<St> provider =
        context.dependOnInheritedWidgetOfExactType<StoreProvider<St>>();

    if (provider == null)
      throw StoreConnectorError(
        _typeOf<StoreProvider<St>>(),
        debug,
      );

    return provider._store;
  }

  /// Dispatch an action without a StoreConnector.
  static void dispatch<St>(
    BuildContext context,
    ReduxAction<St> action, {
    Object debug,
  }) {
    of<St>(context, debug).dispatch(action);
  }

  /// Dispatch an action without a StoreConnector,
  /// and get a `Future<void>` which completes when the action is done.
  static Future<void> dispatchFuture<St>(
    BuildContext context,
    ReduxAction<St> action, {
    Object debug,
  }) async =>
      of<St>(context, debug).dispatchFuture(action);

  /// Get the state, without a StoreConnector.
  static St state<St>(BuildContext context, {Object debug}) => //
      of<St>(context, debug).state;

  /// Workaround to capture generics.
  static Type _typeOf<T>() => T;

  @override
  bool updateShouldNotify(StoreProvider<St> oldWidget) => //
      _store != oldWidget._store;
}

// /////////////////////////////////////////////////////////////////////////////

typedef Reducer<St> = FutureOr<St> Function();

/// Build a Widget using the [BuildContext] and [Model].
/// The [Model] is derived from the [Store] using a [StoreConverter].
typedef ViewModelBuilder<Model> = Widget Function(
  BuildContext context,
  Model vm,
);

/// Convert the entire [Store] into a [Model]. The [Model] will
/// be used to build a Widget using the [ViewModelBuilder].
typedef StoreConverter<St, Model> = Model Function(Store<St> store);

/// A function that will be run when the [StoreConnector] is initialized (using
/// the [State.initState] method). This can be useful for dispatching actions
/// that fetch data for your Widget when it is first displayed.
typedef OnInitCallback<St> = void Function(Store<St> store);

/// A function that will be run when the StoreConnector is removed from the Widget Tree.
/// It is run in the [State.dispose] method.
/// This can be useful for dispatching actions that remove stale data from your State tree.
typedef OnDisposeCallback<St> = void Function(Store<St> store);

/// A test of whether or not your `converter` or `vm` function should run in
/// response to a State change. For advanced use only.
/// Some changes to the State of your application will mean your `converter`
/// or `vm` function can't produce a useful Model. In these cases, such as when
/// performing exit animations on data that has been removed from your Store,
/// it can be best to ignore the State change while your animation completes.
/// To ignore a change, provide a function that returns true or false. If the
/// returned value is false, the change will be ignored.
/// If you ignore a change, and the framework needs to rebuild the Widget, the
/// `builder` function will be called with the latest Model produced
/// by your `converter` or `vm` functions.
typedef ShouldUpdateModel<St> = bool Function(St state);

/// A function that will be run on state change, before the build method.
/// This function is passed the `Model`, and if `distinct` is `true`,
/// it will only be called if the `Model` changes.
/// This is useful for making calls to other classes, such as a
/// `Navigator` or `TabController`, in response to state changes.
/// It can also be used to trigger an action based on the previous state.
typedef OnWillChangeCallback<Model> = void Function(
  Model previousViewModel,
  Model newViewModel,
);

/// A function that will be run on State change, after the build method.
///
/// This function is passed the `Model`, and if `distinct` is `true`,
/// it will only be called if the `Model` changes.
/// This can be useful for running certain animations after the build is complete.
/// Note: Using a [BuildContext] inside this callback can cause problems if
/// the callback performs navigation. For navigation purposes, please use
/// an [OnWillChangeCallback].
typedef OnDidChangeCallback<Model> = void Function(Model viewModel);

/// A function that will be run after the Widget is built the first time.
/// This function is passed the initial `Model` created by the [converter] function.
/// This can be useful for starting certain animations, such as showing
/// Snackbars, after the Widget is built the first time.
typedef OnInitialBuildCallback<Model> = void Function(Model viewModel);

// /////////////////////////////////////////////////////////////////////////////

/// Build a widget based on the state of the [Store].
///
/// Before the [builder] is run, the [converter] will convert the store into a
/// more specific `Model` tailored to the Widget being built.
///
/// Every time the store changes, the Widget will be rebuilt. As a performance
/// optimization, the Widget can be rebuilt only when the [Model] changes.
/// In order for this to work correctly, you must implement [==] and [hashCode] for
/// the [Model], and set the [distinct] option to true when creating your StoreConnector.
class StoreConnector<St, Model> extends StatelessWidget {
  //
  /// Build a Widget using the [BuildContext] and [Model]. The [Model]
  /// is created by the [converter] or [model] functions.
  final ViewModelBuilder<Model> builder;

  /// Convert the [Store] into a [Model]. The resulting [Model] will be
  /// passed to the [builder] function.
  final VmFactory vm;

  /// Convert the [Store] into a [Model]. The resulting [Model] will be
  /// passed to the [builder] function.
  final StoreConverter<St, Model> converter;

  /// Don't use, this is deprecated. Please, use the recommended
  /// `vm` parameter (of type [VmFactory]) or `converter`.
  @Deprecated("Please, use `vm` parameter. "
      "See classes `VmFactory` and `Vm`.")
  final BaseModel model;

  /// When [distinct] is true (the default), the Widget is rebuilt only
  /// when the [Model] changes. In order for this to work correctly, you
  /// must implement [==] and [hashCode] for the [Model].
  final bool distinct;

  /// A function that will be run when the StoreConnector is initially created.
  /// It is run in the [State.initState] method.
  /// This can be useful for dispatching actions that fetch data for your Widget
  /// when it is first displayed.
  final OnInitCallback<St> onInit;

  /// A function that will be run when the StoreConnector is removed from the
  /// Widget Tree. It is run in the [State.dispose] method.
  /// This can be useful for dispatching actions that remove stale data from your State tree.
  final OnDisposeCallback<St> onDispose;

  /// Determines whether the Widget should be rebuilt when the Store emits an onChange event.
  final bool rebuildOnChange;

  /// A test of whether or not your [vm] or [converter] function should run in
  /// response to a State change. For advanced use only.
  /// Some changes to the State of your application will mean your [vm] or
  /// [converter] function can't produce a useful Model. In these cases, such as
  /// when performing exit animations on data that has been removed from your Store,
  /// it can be best to ignore the State change while your animation completes.
  /// To ignore a change, provide a function that returns true or false.
  /// If the returned value is true, the change will be applied.
  /// If the returned value is false, the change will be ignored.
  /// If you ignore a change, and the framework needs to rebuild the Widget,
  /// the [builder] function will be called with the latest [Model] produced
  /// by your [vm] or [converter] function.
  final ShouldUpdateModel<St> shouldUpdateModel;

  /// A function that will be run on State change, before the Widget is built.
  /// This function is passed the `Model`, and if `distinct` is `true`,
  /// it will only be called if the `Model` changes.
  /// This can be useful for imperative calls to things like Navigator, TabController, etc
  final OnWillChangeCallback<Model> onWillChange;

  /// A function that will be run on State change, after the Widget is built.
  /// This function is passed the `Model`, and if `distinct` is `true`,
  /// it will only be called if the `Model` changes.
  /// This can be useful for running certain animations after the build is complete.
  /// Note: Using a [BuildContext] inside this callback can cause problems if
  /// the callback performs navigation. For navigation purposes, please use
  /// [onWillChange].
  final OnDidChangeCallback<Model> onDidChange;

  /// A function that will be run after the Widget is built the first time.
  /// This function is passed the initial `Model` created by the `converter`
  /// or `vm` function. This can be useful for starting certain animations,
  /// such as showing snackbars, after the Widget is built the first time.
  final OnInitialBuildCallback<Model> onInitialBuild;

  /// Pass the parameter `debug: this` to get a more detailed error message.
  final Object debug;

  const StoreConnector({
    Key key,
    @required this.builder,
    this.distinct,
    this.vm, // Recommended.
    this.converter, // Can be used instead of `vm`.
    this.model, // Deprecated.
    this.debug,
    this.onInit,
    this.onDispose,
    this.rebuildOnChange = true,
    this.shouldUpdateModel,
    this.onWillChange,
    this.onDidChange,
    this.onInitialBuild,
  })  : assert(builder != null),
        assert(converter != null || vm != null || model != null,
            "You should provide the `converter` or the `vm` parameter."),
        assert(converter == null || vm == null,
            "You can't provide both the `converter` and the `vm` parameters."),
        assert(converter == null || model == null,
            "You can't provide both the `converter` and the `model` parameters."),
        assert(vm == null || model == null,
            "You can't provide both the `vm` and the `model` parameters."),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return _StoreStreamListener<St, Model>(
      store: StoreProvider.of<St>(context, debug),
      debug: debug,
      storeConnector: this,
      builder: builder,
      converter: converter,
      vm: vm,
      model: model,
      distinct: distinct,
      onInit: onInit,
      onDispose: onDispose,
      rebuildOnChange: rebuildOnChange,
      shouldUpdateModel: shouldUpdateModel,
      onWillChange: onWillChange,
      onDidChange: onDidChange,
      onInitialBuild: onInitialBuild,
    );
  }

  /// This is not used directly by the store, but may be used in tests.
  /// If you have a store and a StoreConnector, and you want its associated
  /// ViewModel, you can do:
  /// `Model viewModel = storeConnector.getLatestModel(store);`
  ///
  /// And if you want to build the widget:
  /// `var widget = (storeConnector as dynamic).builder(context, viewModel);`
  ///
  Model getLatestModel(Store store) {
    if (converter != null)
      return converter(store);
    else if (vm != null) {
      vm._setStore(store.state, store);
      return vm.fromStore() as Model;
    } else if (model != null) {
      model._setStore(store.state, store);
      return model.fromStore() as Model;
    } else
      throw AssertionError();
  }
}

// /////////////////////////////////////////////////////////////////////////////

/// Listens to the store and calls builder whenever the store changes.
class _StoreStreamListener<St, Model> extends StatefulWidget {
  final ViewModelBuilder<Model> builder;
  final StoreConverter<St, Model> converter;
  final VmFactory vm;
  final BaseModel model; // Deprecated.
  final Store<St> store;
  final Object debug;
  final StoreConnector storeConnector;
  final bool rebuildOnChange;
  final bool distinct;
  final OnInitCallback<St> onInit;
  final OnDisposeCallback<St> onDispose;
  final ShouldUpdateModel<St> shouldUpdateModel;
  final OnWillChangeCallback<Model> onWillChange;
  final OnDidChangeCallback<Model> onDidChange;
  final OnInitialBuildCallback<Model> onInitialBuild;

  const _StoreStreamListener({
    Key key,
    @required this.builder,
    @required this.store,
    @required this.debug,
    @required this.converter,
    @required this.vm,
    @required this.model, // Deprecated.
    @required this.storeConnector,
    this.distinct,
    this.onInit,
    this.onDispose,
    this.rebuildOnChange = true,
    this.onWillChange,
    this.onDidChange,
    this.onInitialBuild,
    this.shouldUpdateModel,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _StoreStreamListenerState<St, Model>();
  }
}

// /////////////////////////////////////////////////////////////////////////////

/// If the StoreConnector throws an error.
class ConverterError extends Error {
  final Object debug;

  /// The error thrown while running the [StoreConnector.converter] function.
  final Object error;

  /// The stacktrace that accompanies the [error]
  @override
  final StackTrace stackTrace;

  /// Creates a ConverterError with the relevant error and stacktrace.
  ConverterError(this.error, this.stackTrace, this.debug);

  @override
  String toString() {
    return "Error creating the view model"
        "${debug == null ? '' : ' (${debug.runtimeType})'}: "
        "$error\n\n"
        "$stackTrace\n\n";
  }
}

// /////////////////////////////////////////////////////////////////////////////

class _StoreStreamListenerState<St, Model> //
    extends State<_StoreStreamListener<St, Model>> {
  Stream<Model> _stream;
  Model _latestModel;
  ConverterError _latestError;

  // If `widget.distinct` was passed, use it. Otherwise, use the store default.
  bool get _distinct => widget.distinct ?? widget.store._defaultDistinct;

  /// Reference to the last state.
  /// We need this so that we only recalculate the view-model if the state changed.
  St _previousState;

  /// if [StoreConnector.shouldUpdateModel] returns false, we need to know the
  /// most recent VALID state (it was valid when [StoreConnector.shouldUpdateModel]
  /// returned true). We save all valid states into [_mostRecentValidState], and
  /// when we need to use it we put it into [_forceLastValidStreamState].
  St _mostRecentValidState, _forceLastValidStreamState;

  @override
  void initState() {
    if (widget.onInit != null) {
      widget.onInit(widget.store);
    }

    _computeLatestModel();

    if (widget.onInitialBuild != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onInitialBuild(_latestModel);
      });
    }

    _createStream();

    super.initState();
  }

  @override
  void dispose() {
    if (widget.onDispose != null) {
      widget.onDispose(widget.store);
    }

    super.dispose();
  }

  @override
  void didUpdateWidget(_StoreStreamListener<St, Model> oldWidget) {
    _computeLatestModel();

    if (widget.store != oldWidget.store) {
      _createStream();
    }

    super.didUpdateWidget(oldWidget);
  }

  void _computeLatestModel() {
    try {
      _latestError = null;
      _latestModel = getLatestModel(widget.store.state);
    } catch (error, stacktrace) {
      _latestModel = null;
      _latestError = ConverterError(error, stacktrace, widget.debug);
    }
  }

  void _createStream() {
    _stream = widget.store.onChange
        .where(_stateChanged)
        .where(_shouldUpdateModel)
        .map(_mapConverter)
        // Don't use `Stream.distinct` because it cannot capture the initial
        // ViewModel produced by the `converter`.
        .where(_whereDistinct)
        // After each ViewModel is emitted from the Stream, we update the
        // latestValue. Important: This must be done after all other optional
        // transformations, such as shouldUpdateModel.
        .transform(StreamTransformer.fromHandlers(
          handleData: _handleData,
          handleError: _handleError,
        ));
  }

  // This prevents unnecessary calculations of the view-model.
  bool _stateChanged(St state) {
    return !identical(_previousState, widget.store.state);
  }

  // If `shouldUpdateModel` is provided, it will calculate if the STORE state contains
  // a valid state which may be used to calculate the view-model. If this is not the
  // case, we revert to the last known valid state, which may be a STORE state or a
  // STREAM state. Note the view-model is always calculated from the STORE state,
  // which is always the same or more recent than the STREAM state. We could greatly
  // simplify all of this if the view-model used the STREAM state. However, this would
  // mean some small delay in the UI, and there is also the problem that the converter
  // parameter uses the STORE.
  bool _shouldUpdateModel(St state) {
    if (widget.shouldUpdateModel == null)
      return true;
    else {
      _forceLastValidStreamState = null;
      bool ifStoreHasValidModel = widget.shouldUpdateModel(widget.store.state);
      if (ifStoreHasValidModel) {
        _mostRecentValidState = widget.store.state;
        return true;
      }
      //
      else {
        //
        bool ifStreamHasValidModel = widget.shouldUpdateModel(state);
        if (ifStreamHasValidModel) {
          _mostRecentValidState = state;
          return false;
        } else {
          if (identical(state, widget.store.state)) {
            _forceLastValidStreamState = _mostRecentValidState;
          }
        }
      }

      return (_forceLastValidStreamState != null);
    }
  }

  Model _mapConverter(St state) => getLatestModel(_forceLastValidStreamState ?? widget.store.state);

  // Don't use `Stream.distinct` since it can't capture the initial vm.
  bool _whereDistinct(Model vm) {
    if (_distinct) {
      bool isDistinct = vm != _latestModel;

      _observeWithTheModelObserver(
        modelPrevious: _latestModel,
        modelCurrent: vm,
        isDistinct: isDistinct,
      );

      return isDistinct;
    }

    return true;
  }

  void _handleData(Model vm, EventSink<Model> sink) {
    //
    if (!_distinct)
      _observeWithTheModelObserver(
        modelPrevious: _latestModel,
        modelCurrent: vm,
        isDistinct: null,
      );

    _latestError = null;

    if (widget.onWillChange != null) {
      widget.onWillChange(_latestModel, vm);
    }

    _latestModel = vm;

    if (widget.onDidChange != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onDidChange(_latestModel);
      });
    }

    sink.add(vm);
  }

  // If the view-model construction failed.
  void _handleError(
    Object error,
    StackTrace stackTrace,
    EventSink<Model> sink,
  ) {
    _latestModel = null;
    _latestError = ConverterError(error, stackTrace, widget.debug);
    sink.addError(error, stackTrace);
  }

  // If there is a ModelObserver, observe.
  // Note: This observer is only useful for tests.
  void _observeWithTheModelObserver({
    @required modelPrevious,
    @required modelCurrent,
    @required bool isDistinct,
  }) {
    ModelObserver modelObserver = widget.store._modelObserver;
    if (modelObserver != null) {
      try {
        modelObserver.observe(
          modelPrevious: modelPrevious,
          modelCurrent: modelCurrent,
          isDistinct: isDistinct,
          storeConnector: widget.storeConnector,
          reduceCount: widget.store.reduceCount,
          dispatchCount: widget.store.dispatchCount,
        );
      } catch (error, stackTrace) {
        _throws(
          "Model observer has thrown an error:\n '$error'.",
          error,
          stackTrace,
        );
      }
    }
  }

  /// The StoreConnector needs the converter or vm parameter (only one of them):
  /// 1) Converter gets the `store`.
  /// 2) Vm gets `state` and `dispatch`, so it's easier to use.
  ///
  Model getLatestModel(St state) {
    //
    if (widget.converter != null)
      return widget.converter(widget.store);
    else if (widget.vm != null) {
      widget.vm._setStore(state, widget.store);
      return widget.vm.fromStore() as Model;
    } else if (widget.model != null) {
      widget.model._setStore(state, widget.store);
      return widget.model.fromStore() as Model;
    } else
      throw AssertionError();
  }

  @override
  Widget build(BuildContext context) {
    return widget.rebuildOnChange
        ? StreamBuilder<Model>(
            stream: _stream,
            builder: (context, snapshot) {
              if (_latestError != null) throw _latestError;

              return widget.builder(context, _latestModel);
            },
          )
        : _latestError != null
            ? throw _latestError
            : widget.builder(context, _latestModel);
  }
}

// /////////////////////////////////////////////////////////////////////////////

/// A function that formats the message that will be logged:
///
///   final log = Log(formatter: onlyLogActionFormatter);
///   var store = new Store(initialState: 0, actionObservers:[log], stateObservers: [...]);
///
typedef MessageFormatter<St> = String Function(
  St state,
  ReduxAction<St> action,
  bool ini,
  int dispatchCount,
  DateTime timestamp,
);

/// Connects a [Logger] to the Redux Store.
/// Every action that is dispatched will be logged to the Logger, along with the new State
/// that was created as a result of the action reaching your Store's reducer.
///
/// By default, this class does not print anything to your console or to a web
/// service, such as Fabric or Sentry. It simply logs entries to a Logger instance.
/// You can then listen to the [Logger.onRecord] Stream, and print to the
/// console or send these actions to a web service.
///
/// Example: To print actions to the console as they are dispatched:
///
///     var store = Store(
///       initialValue: 0,
///       actionObservers: [Log.printer()]);
///
/// Example: If you only want to log actions to a Logger, use the default constructor.
///
///     // Create your own Logger and pass it to the Observer.
///     final logger = new Logger("Redux Logger");
///     final stateObserver = Log(logger: logger);
///
///     final store = new Store<int>(
///       initialState: 0,
///       stateObserver: [stateObserver]);
///
///     // Note: One quirk about listening to a logger instance is that you're
///     // actually listening to the Singleton instance of *all* loggers.
///     logger.onRecord
///       // Filter down to [LogRecord]s sent to your logger instance
///       .where((record) => record.loggerName == logger.name)
///       // Print them out (or do something more interesting!)
///       .listen((LogRecord) => print(LogRecord));
///
class Log<St> implements ActionObserver<St> {
  //
  final Logger logger;

  /// The log Level at which the actions will be recorded
  final Level level;

  /// A function that formats the String for printing
  final MessageFormatter<St> formatter;

  /// Logs actions to the given Logger, and does not print anything to the console.
  Log({
    Logger logger,
    this.level = Level.INFO,
    this.formatter = singleLineFormatter,
  }) : logger = logger ?? Logger("Log");

  /// Logs actions to the console.
  factory Log.printer({
    Logger logger,
    Level level = Level.INFO,
    MessageFormatter<St> formatter = singleLineFormatter,
  }) {
    final log = Log(logger: logger, level: level, formatter: formatter);
    log.logger.onRecord //
        .where((record) => record.loggerName == log.logger.name)
        .listen(print);
    return log;
  }

  /// A very simple formatter that writes only the action.
  static String verySimpleFormatter(
    dynamic state,
    ReduxAction action,
    bool ini,
    int dispatchCount,
    DateTime timestamp,
  ) =>
      "$action ${ini ? 'INI' : 'END'}";

  /// A simple formatter that puts all data on one line.
  static String singleLineFormatter(
    dynamic state,
    ReduxAction action,
    bool ini,
    int dispatchCount,
    DateTime timestamp,
  ) {
    return "{$action, St: $state, ts: ${new DateTime.now()}}";
  }

  /// A formatter that puts each attribute on it's own line.
  static String multiLineFormatter(
    dynamic state,
    ReduxAction action,
    bool ini,
    int dispatchCount,
    DateTime timestamp,
  ) {
    return "{\n"
        "  $dispatchCount) $action,\n"
        "  St: $state,\n"
        "  Timestamp: ${new DateTime.now()}\n"
        "}";
  }

  @override
  void observe(ReduxAction<St> action, int dispatchCount, {bool ini}) {
    logger.log(
      level,
      formatter(null, action, ini, dispatchCount, new DateTime.now()),
    );
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

class StoreConnectorError extends Error {
  final Type type;
  final Object debug;

  StoreConnectorError(this.type, this.debug);

  @override
  String toString() {
    return '''Error: No $type found. (debug info: ${debug.runtimeType})    
    
    To fix, please try:
          
  * Dart 2 (required) 
  * Wrapping your MaterialApp with the StoreProvider<St>, rather than an individual Route
  * Providing full type information to your Store<St>, StoreProvider<St> and StoreConnector<St, Model>
  * Ensure you are using consistent and complete imports. E.g. always use `import 'package:my_app/app_state.dart';
      ''';
  }
}

// /////////////////////////////////////////////////////////////////////////////

class StoreException implements Exception {
  final String msg;

  StoreException(this.msg);

  @override
  String toString() => msg;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoreException && //
          runtimeType == other.runtimeType &&
          msg == other.msg;

  @override
  int get hashCode => msg.hashCode;
}

// /////////////////////////////////////////////////////////////////////////////

/// Prints the error/stacktrace information to the console,
/// then throws the error after an asynchronous gap.
/// Note: We print the stacktrace because the rethrow loses
/// the stacktrace due to Dart architecture.
///  See: https://groups.google.com/a/dartlang.org/forum/#!topic/misc/O1OKnYTUcoo
///  See: https://github.com/dart-lang/sdk/issues/10297
///  This should be fixed when this issue is solved: https://github.com/dart-lang/sdk/issues/30741
///
void _throws(errorMsg, error, StackTrace stackTrace) {
  if (errorMsg != null) print(errorMsg);
  if (stackTrace != null) {
    print("\nStackTrace:\n$stackTrace");
    print("--- End of the StackTrace\n\n");
  }

  Future(() {
    throw error;
  });
}

// /////////////////////////////////////////////////////////////////////////////
