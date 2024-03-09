// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// Based upon packages redux by Brian Egan, and flutter_redux by Brian Egan and John Ryan.
// Uses code from package equatable by Felix Angelov.
// For more info, see: https://pub.dartlang.org/packages/async_redux

library async_redux_store;

import 'dart:async';
import 'dart:collection';
import 'package:async_redux/async_redux.dart';
import 'package:async_redux/src/process_persistence.dart';
import 'package:flutter/foundation.dart';

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

@Deprecated("Use `DispatchAndWait` instead. This will be removed.")
typedef DispatchAsync<St> = Future<ActionStatus> Function(
  ReduxAction<St> action, {
  bool notify,
});

typedef DispatchAndWait<St> = Future<ActionStatus> Function(
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
/// 5) `Object? wrapError(error)` ➜ If any error is thrown by `before` or `reduce`,
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
/// • StateObservers receive the action, prevState (state right before the new State is applied),
///   newState (state that was applied), and are used to track metrics and more.
///
/// • ErrorObservers may be used to observe or process errors thrown by actions.
///
/// • GlobalWrapError may be used to wrap action errors globally.
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
    @Deprecated("Use `globalWrapError` instead. This will be removed.") WrapError<St>? wrapError,
    GlobalWrapError<St>? globalWrapError,
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
        _globalWrapError = globalWrapError,
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

  @Deprecated("Use `_globalWrapError` instead. This will be removed.")
  final WrapError<St>? _wrapError;

  final GlobalWrapError<St>? _globalWrapError;

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
  /// The condition can access the state. You may also provide a [timeoutInSeconds], which
  /// by default is 10 minutes. If you want, you can modify [StoreTester.defaultTimeout] to change
  /// the default timeout. Note: To disable the timeout, modify this to a large value,
  /// like 300000000 (almost 10 years).
  ///
  /// This method is useful in tests, and it returns the action which changed
  /// the store state into the condition, in case you need it:
  ///
  /// ```dart
  /// var action = await store.waitCondition((state) => state.name == "Bill");
  /// expect(action, isA<ChangeNameAction>());
  /// ```
  ///
  /// This method is also eventually useful in production code, in which case you
  /// should avoid waiting for conditions that may take a very long time to complete,
  /// as checking the condition is an overhead to every state change.
  ///
  Future<ReduxAction<St>> waitCondition(
    bool Function(St) condition, {
    int? timeoutInSeconds,
  }) async {
    var conditionTester = StoreTester.simple(this);
    try {
      var info = await conditionTester.waitConditionGetLast(
        (TestInfo<St>? info) => condition(info!.state),
        timeoutInSeconds: timeoutInSeconds ?? StoreTester.defaultTimeout,
      );
      var action = info.action;
      if (action == null) throw StoreExceptionTimeout();
      return action;
    } finally {
      await conditionTester.cancel();
    }
  }

  /// Returns a future which will complete when an action of the given type is dispatched, and
  /// then waits until it finishes. Ignores other actions types.
  ///
  /// You may also provide a [timeoutInSeconds], which by default is 10 minutes.
  /// If you want, you can modify [StoreTester.defaultTimeout] to change the default timeout.
  ///
  /// This method returns the action, which you can use to check its `status`:
  ///
  /// ```dart
  /// var action = await store.waitActionType(MyAction);
  /// expect(action.status.originalError, isA<UserException>());
  /// ```
  ///
  /// You should only use this method in tests.
  @visibleForTesting
  Future<ReduxAction<St>> waitActionType(
    Type actionType, {
    int? timeoutInSeconds,
  }) async {
    var conditionTester = StoreTester.simple(this);
    try {
      var info = await conditionTester.waitUntil(
        actionType,
        timeoutInSeconds: timeoutInSeconds ?? StoreTester.defaultTimeout,
      );
      var action = info.action;
      if (action == null) throw StoreExceptionTimeout();
      return action;
    } finally {
      await conditionTester.cancel();
    }
  }

  /// Returns a future which will complete when an action of ANY of the given types is dispatched,
  /// and then waits until it finishes. Ignores other actions types.
  ///
  /// You may also provide a [timeoutInSeconds], which by default is 10 minutes.
  /// If you want, you can modify [StoreTester.defaultTimeout] to change the default timeout.
  ///
  /// This method returns the action, which you can use to check its `status`:
  ///
  /// ```dart
  /// var action = await store.waitAnyActionType([MyAction, OtherAction]);
  /// expect(action.status.originalError, isA<UserException>());
  /// ```
  ///
  /// You should only use this method in tests.
  @visibleForTesting
  Future<ReduxAction<St>> waitAnyActionType(
    List<Type> actionTypes, {
    bool ignoreIni = true,
    int? timeoutInSeconds,
  }) async {
    var conditionTester = StoreTester.simple(this);
    try {
      var info = await conditionTester.waitUntilAny(
        actionTypes,
        timeoutInSeconds: timeoutInSeconds ?? StoreTester.defaultTimeout,
      );
      var action = info.action;
      if (action == null) throw StoreExceptionTimeout();
      return action;
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

  /// Dispatches the action, applying its reducer, and possibly changing the store state.
  /// The action may be sync or async.
  ///
  /// ```dart
  /// store.dispatch(new MyAction());
  /// ```
  ///
  /// Method [dispatch] is of type [Dispatch].
  ///
  /// See also:
  /// - [dispatchSync] which dispatches sync actions, and throws if the action is async.
  /// - [dispatchAndWait] which dispatches both sync and async actions, and returns a Future.
  FutureOr<ActionStatus> dispatch(ReduxAction<St> action, {bool notify = true}) =>
      _dispatch(action, notify: notify);

  @Deprecated("Use `dispatchAndWait` instead. This will be removed.")
  Future<ActionStatus> dispatchAsync(ReduxAction<St> action, {bool notify = true}) =>
      dispatchAndWait(action, notify: notify);

  /// Dispatches the action, applying its reducer, and possibly changing the store state.
  /// The action may be sync or async. In both cases, it returns a [Future] that resolves when
  /// the action finishes.
  ///
  /// ```dart
  /// await store.dispatchAndWait(new DoThisFirstAction());
  /// store.dispatch(new DoThisSecondAction());
  /// ```
  ///
  /// Note: While the state change from the action's reducer will have been applied when the
  /// Future resolves, other independent processes that the action may have started may still
  /// be in progress.
  ///
  /// Method [dispatchAndWait] is of type [DispatchAndWait]. It returns `Future<ActionStatus>`,
  /// which means you can also get the final status of the action after you `await` it:
  ///
  /// ```dart
  /// var status = await store.dispatchAndWait(new MyAction());
  /// ```
  ///
  /// See also:
  /// - [dispatch] which dispatches both sync and async actions.
  /// - [dispatchSync] which dispatches sync actions, and throws if the action is async.
  Future<ActionStatus> dispatchAndWait(ReduxAction<St> action, {bool notify = true}) =>
      Future.value(_dispatch(action, notify: notify));

  /// Dispatches the action, applying its reducer, and possibly changing the store state.
  /// However, if the action is ASYNC, it will throw a [StoreException].
  ///
  /// Method [dispatchSync] is of type [DispatchSync].
  ///
  /// See also:
  /// - [dispatch] which dispatches both sync and async actions.
  /// - [dispatchAndWait] which dispatches both sync and async actions, and returns a Future.
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
    }
    //
    else {
      // Note: Only if the action is async it makes sense to add it to the list of active actions.
      // If it's sync it will finish immediately, so there's no need to add it.
      _activeAsyncActions.add(action);

      // If it's awaitable (that is to say, we have already called isWaitingForType/isWaitingForAction
      // for this action, then we notify the UI. We don't notify if the action was never checked.
      if (_awaitableAsyncActions.contains(action.runtimeType)) {
        _changeController.add(state);
      }

      return _processAction_Async(action, notify: notify);
    }
  }

  /// You can use [isWaitingFor] to check if:
  /// * A specific async ACTION is currently being processed.
  /// * An async action of a specific TYPE is currently being processed.
  /// * If any of a few given async actions or action types is currently being processed.
  ///
  /// If you wait for an action TYPE, then it returns false when:
  /// - The ASYNC action of type [actionType] is NOT currently being processed.
  /// - If [actionType] is not really a type that extends [ReduxAction].
  /// - The action of type [actionType] is a SYNC action (since those finish immediately).
  ///
  /// If you wait for an ACTION, then it returns false when:
  /// - The ASYNC [action] is NOT currently being processed.
  /// - If [action] is a SYNC action (since those finish immediately).
  //
  /// Examples:
  ///
  /// ```dart
  /// // Waiting for an action TYPE:
  /// dispatch(MyAction());
  /// if (store.isWaitingFor(MyAction)) { // Show a spinner }
  ///
  /// // Waiting for an ACTION:
  /// var action = MyAction();
  /// dispatch(action);
  /// if (store.isWaitingFor(action)) { // Show a spinner }
  ///
  /// // Waiting for any of the given action TYPES:
  /// dispatch(BuyAction());
  /// if (store.isWaitingFor([BuyAction, SellAction])) { // Show a spinner }
  /// ```
  bool isWaitingFor(Object actionOrTypeOrList) {
    //
    // 1) If a type was passed:
    if (actionOrTypeOrList is Type) {
      _awaitableAsyncActions.add(actionOrTypeOrList);
      return _activeAsyncActions.any((action) => action.runtimeType == actionOrTypeOrList);
    }
    //
    // 2) If an action was passed:
    else if (actionOrTypeOrList is ReduxAction<St>) {
      _awaitableAsyncActions.add(actionOrTypeOrList.runtimeType);
      return _activeAsyncActions.contains(actionOrTypeOrList);
    }
    //
    // 3) If a list was passed:
    else if (actionOrTypeOrList is Iterable) {
      for (var actionOrType in actionOrTypeOrList) {
        if (actionOrType is Type) {
          _awaitableAsyncActions.add(actionOrType);
          return _activeAsyncActions.any((action) => action.runtimeType == actionOrType);
        } else if (actionOrType is ReduxAction<St>) {
          _awaitableAsyncActions.add(actionOrType.runtimeType);
          return _activeAsyncActions.contains(actionOrType);
        } else {
          Future.microtask(() {
            throw StoreException("You can't do isWaitingFor([${actionOrTypeOrList.runtimeType}]), "
                "but only an action Type, a ReduxAction, or a List of them.");
          });
        }
      }
      return false;
    }
    // 4) If something different was passed, it's an error. We show the error after the
    // async gap, so we don't interrupt the code. But we return false (not waiting).
    else {
      Future.microtask(() {
        throw StoreException("You can't do isWaitingFor(${actionOrTypeOrList.runtimeType}), "
            "but only an action Type, a ReduxAction, or a List of them.");
      });

      return false;
    }
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
      action._status = ActionStatus();
      var result = action.before();
      if (result is Future) throw StoreException(_beforeTypeErrorMsg);

      action._status = action._status.copy(hasFinishedMethodBefore: true);
      if (_shutdown) return action._status;
      _applyReducer(action, notify: notify);
      action._status = action._status.copy(hasFinishedMethodReduce: true);
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
      action._status = new ActionStatus();
      result = action.before();
      if (result is Future) await result;
      action._status = action._status.copy(hasFinishedMethodBefore: true);
      if (_shutdown) return action._status;
      result = _applyReducer(action, notify: notify);
      if (result is Future) await result;
      action._status = action._status.copy(hasFinishedMethodReduce: true);
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
  /// did not return null, and if it did not return the same identical state.
  ///
  /// Note: We compare the state using `identical` (which is fast).
  ///
  /// The [StateObserver]s are always called (if defined). If you need to know if the state was
  /// changed or not, you can compare `bool ifStateChanged = identical(prevState, newState)`
  void _registerState(
    St? state,
    ReduxAction<St> action, {
    bool notify = true,
  }) {
    if (_shutdown) return;

    St prevState = _state;

    // Reducers may return null state, or the unaltered state, when they don't want to change the
    // state. Note: If the action is an "active action" it will be removed, so we have to
    // add the state to _changeController even if it's the same state.
    if (((state != null) && !identical(_state, state)) || _activeAsyncActions.contains(action)) {
      _state = state ?? _state;
      _stateTimestamp = DateTime.now().toUtc();

      if (notify) {
        _changeController.add(state ?? _state);
      }
    }
    St newState = _state;

    if (_stateObservers != null)
      for (StateObserver observer in _stateObservers) {
        observer.observe(action, prevState, newState, null, dispatchCount);
      }

    if (_processPersistence != null)
      _processPersistence.process(
        action,
        newState,
      );
  }

  /// The async actions that are currently being processed.
  final Set<ReduxAction<St>> _activeAsyncActions = HashSet<ReduxAction<St>>.identity();

  /// Async actions that we may put into [_activeAsyncActions].
  final Set<Type> _awaitableAsyncActions = HashSet<Type>.identity();

  /// Given a [newState] returns true if the state is different from the current state.
  bool ifStateChanged(St? newState, ReduxAction<St> action) {
    return (newState != null && !identical(_state, newState)) ||
        _activeAsyncActions.contains(action);
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

    action._status = action._status.copy(originalError: error);

    try {
      errorOrNull = action.wrapError(errorOrNull, stackTrace);
    } catch (_error) {
      // If the action's wrapError throws an error, it will be used instead
      // of the original error (but the recommended way is returning the error).
      errorOrNull = _error;
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

    if (_globalWrapError != null && errorOrNull != null) {
      try {
        errorOrNull = _globalWrapError.wrap(errorOrNull, stackTrace, action);
      } catch (_error) {
        // If the GlobalWrapError throws an error, it will be used instead
        // of the original error (but the recommended way is returning the error).
        errorOrNull = _error;
      }
    }

    action._status = action._status.copy(wrappedError: errorOrNull);

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

    _activeAsyncActions.remove(action);

    createTestInfoSnapshot(state!, action, error, processedError, ini: false);

    if (_actionObservers != null)
      for (ActionObserver observer in _actionObservers) {
        observer.observe(action, dispatchCount, ini: false);
      }
  }

  void _after(ReduxAction<St> action) {
    try {
      action.after();
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
    } finally {
      action._status = action._status.copy(hasFinishedMethodAfter: true);
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

enum CompareBy { byDeepEquals, byIdentity }

@immutable
class ActionStatus {
  ActionStatus({
    this.isDispatched = false,
    this.hasFinishedMethodBefore = false,
    this.hasFinishedMethodReduce = false,
    this.hasFinishedMethodAfter = false,
    this.originalError,
    this.wrappedError,
  });

  /// Returns true if the action was already dispatched. An action cannot be dispatched
  /// more than once, which means that you have to create a new action each time.
  ///
  /// Note this may be true even if the action has not yet FINISHED dispatching.
  /// To check if it has finished, use `action.isFinished`.
  final bool isDispatched;

  /// Is true when the `before` method finished executing normally.
  /// Is false if it has not yet finished executing or if it threw an error.
  final bool hasFinishedMethodBefore;

  /// Is true when the `reduce` method finished executing normally, returning a value.
  /// Is false if it has not yet finished executing or if it threw an error.
  final bool hasFinishedMethodReduce;

  /// Is true if the `after` method finished executing. Note the `after` method should
  /// never throw any errors, but if it does the error will be swallowed and ignored.
  /// Is false if it has not yet finished executing.
  final bool hasFinishedMethodAfter;

  /// Holds the error thrown by the action's before/reduce methods, if any.
  /// This may or may not be equal to the error thrown by the action, because the original error
  /// will still be processed by the action's `wrapError` and the `globalWrapError`. However,
  /// if `originalError` is non-null, it means the reducer did not finish running.
  final Object? originalError;

  /// Holds the error thrown by the action. This may or may not be the same as `originalError`,
  /// because any errors thrown by the action's before/reduce methods may still be changed or
  /// cancelled by the action's `wrapError` and the `globalWrapError`. This is the final error
  /// after all these wraps.
  final Object? wrappedError;

  @Deprecated("Use `hasFinishedMethodBefore` instead. This will be removed.")
  bool get isBeforeDone => hasFinishedMethodBefore;

  @Deprecated("Use `hasFinishedMethodReduce` instead. This will be removed.")
  bool get isReduceDone => hasFinishedMethodReduce;

  @Deprecated("Use `hasFinishedMethodAfter` instead. This will be removed.")
  bool get isAfterDone => hasFinishedMethodAfter;

  @Deprecated("Use `isCompletedOk` instead. This will be removed.")
  bool get isFinished => isBeforeDone && isReduceDone && isAfterDone;

  /// Returns true only if the action has completed, and none of the 'before' or 'reduce'
  /// methods have thrown an error. This indicates that the 'reduce' method completed and
  /// returned a result (even if the result was null). The 'after' method also already ran.
  ///
  /// This can be useful if you need to dispatch a second method only if the first method
  /// succeeded:
  ///
  /// ```ts
  /// let action = new LoadInfo();
  /// await dispatchAndWait(action);
  /// if (action.isCompletedOk) dispatch(new ShowInfo());
  /// ```
  ///
  /// Or you can also get the state directly from `dispatchAndWait`:
  ///
  /// ```ts
  /// var status = await dispatchAndWait(LoadInfo());
  /// if (status.isCompletedOk) dispatch(ShowInfo());
  /// ```
  bool get isCompletedOk => isCompleted && (originalError == null);

  /// Returns true only if the action has completed (the 'after' method already ran), but either
  /// the 'before' or the 'reduce' methods have thrown an error. If this is true, it indicates that
  /// the reducer could NOT complete, and could not return a value to change the state.
  bool get isCompletedFailed => isCompleted && (originalError != null);

  /// Returns true only if the action has completed executing, either with or without errors.
  /// If this is true, the 'after' method already ran.
  bool get isCompleted => hasFinishedMethodAfter;

  ActionStatus copy({
    bool? isDispatched,
    bool? hasFinishedMethodBefore,
    bool? hasFinishedMethodReduce,
    bool? hasFinishedMethodAfter,
    Object? originalError,
    Object? wrappedError,
  }) =>
      ActionStatus(
        isDispatched: isDispatched ?? this.isDispatched,
        hasFinishedMethodBefore: hasFinishedMethodBefore ?? this.hasFinishedMethodBefore,
        hasFinishedMethodReduce: hasFinishedMethodReduce ?? this.hasFinishedMethodReduce,
        hasFinishedMethodAfter: hasFinishedMethodAfter ?? this.hasFinishedMethodAfter,
        originalError: originalError ?? this.originalError,
        wrappedError: wrappedError ?? this.wrappedError,
      );
}

class _Flag<T> {
  T value;

  _Flag(this.value);

  @override
  bool operator ==(Object other) => true;

  @override
  int get hashCode => 0;
}
