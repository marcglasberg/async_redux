// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// Based upon packages redux by Brian Egan, and flutter_redux by Brian Egan and John Ryan.
// Uses code from package equatable by Felix Angelov.
// For more info, see: https://pub.dartlang.org/packages/async_redux

library async_redux_store;

import 'dart:async';
import 'dart:collection';
import 'package:async_redux/async_redux.dart';
import 'package:async_redux/src/process_persistence.dart';
import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';

import 'connector_tester.dart';

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
/// dispatched: `before`, `reduce` and `after` will not be called. This is only useful
/// under rare circumstances, and you should only use it if you know what you are doing.
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
    Map<Object?, Object?> props = const {},
    bool syncStream = false,
    TestInfoPrinter? testInfoPrinter,
    List<ActionObserver<St>>? actionObservers,
    List<StateObserver<St>>? stateObservers,
    Persistor<St>? persistor,
    Persistor<St>? cloudSync,
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
        _props = HashMap()..addAll(props),
        _stateTimestamp = DateTime.now().toUtc(),
        _changeController = StreamController.broadcast(sync: syncStream),
        _actionObservers = actionObservers,
        _stateObservers = stateObservers,
        _processPersistence = (persistor == null)
            ? null //
            : ProcessPersistence(persistor, initialState),
        _processCloudSync = (cloudSync == null)
            ? null //
            : ProcessPersistence(cloudSync, initialState),
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

  final Map<Object?, Object?> _props;

  /// Gets the store environment.
  /// This can be used to create a global value, but scoped to the store.
  /// For example, you could have a service locator, here, or a configuration value.
  ///
  /// This is also directly accessible in [ReduxAction] and in [VmFactory], as `env`.
  ///
  /// See also: [prop] and [setProp].
  Object? get env => _environment;

  /// Gets the store properties.
  @visibleForTesting
  Map<Object?, Object?> get props => _props;

  /// Gets a property from the store.
  /// This can be used to save global values, but scoped to the store.
  /// For example, you could save timers, streams or futures used by actions.
  ///
  /// ```dart
  /// setProp("timer", Timer(Duration(seconds: 1), () => print("tick")));
  /// var timer = prop<Timer>("timer");
  /// timer.cancel();
  /// ```
  ///
  /// This is also directly accessible in [ReduxAction] and in [VmFactory], as `prop`.
  ///
  /// See also: [setProp] and [env].
  V prop<V>(Object? key) => _props[key] as V;

  /// Sets a property in the store.
  /// This can be used to save global values, but scoped to the store.
  /// For example, you could save timers, streams or futures used by actions.
  ///
  /// ```dart
  /// setProp("timer", Timer(Duration(seconds: 1), () => print("tick")));
  /// var timer = prop<Timer>("timer");
  /// timer.cancel();
  /// ```
  ///
  /// This is also directly accessible in [ReduxAction] and in [VmFactory], as `prop`.
  ///
  /// See also: [prop] and [env].
  void setProp(Object? key, Object? value) => _props[key] = value;

  /// The [disposeProps] method is used to clean up resources associated with the store's
  /// properties, by stopping, closing, ignoring and removing timers, streams, sinks, and futures
  /// that are saved as properties in the store.
  ///
  /// In more detail: This method accepts an optional predicate function that takes a prop `key`
  /// and a `value` as an argument and returns a boolean.
  ///
  /// * If you don't provide a predicate function, all properties which are `Timer`, `Future`, or
  /// `Stream` related will be closed/cancelled/ignored as appropriate, and then removed from the
  /// props. Other properties will not be removed.
  ///
  /// * If the predicate function is provided and returns `true` for a given property, that
  /// property will be removed from the props and, if the property is also a `Timer`, `Future`,
  /// or `Stream` related, it will be closed/cancelled/ignored as appropriate.
  ///
  /// * If the predicate function is provided and returns `false` for a given property,
  /// that property will not be removed from the props, and it will not be closed/cancelled/ignored.
  ///
  /// This method is particularly useful when the store is being shut down, right before or after
  /// you called the [shutdown] method.
  ///
  /// Example usage:
  ///
  /// ```dart
  /// // Dispose of all Timers, Futures, Stream related etc.
  /// store.disposeProps();
  ///
  /// // Dispose only Timers.
  /// store.disposeProps(({Object? key, Object? value}) => value is Timer);
  /// ```
  ///
  void disposeProps([bool Function({Object? key, Object? value})? predicate]) {
    var keysToRemove = [];

    for (var MapEntry(key: key, value: value) in _props.entries) {
      final removeIt = predicate?.call(key: key, value: value) ?? true;

      if (removeIt) {
        final ifTimerFutureStream = _closeTimerFutureStream(value);

        // Removes the key if the predicate was provided and returned true,
        // or it was not provided but the value is Timer/Future/Stream.
        if ((predicate != null) || ifTimerFutureStream) keysToRemove.add(key);
      }
    }

    // After the iteration, remove all keys at the same time.
    keysToRemove.forEach((key) => _props.remove(key));
  }

  /// If [obj] is a timer, future or stream related, it will be closed/cancelled/ignored,
  /// and `true` will be returned. For other object types, the method returns `false`.
  bool _closeTimerFutureStream(Object? obj) {
    if (obj is Timer)
      obj.cancel();
    else if (obj is Future)
      obj.ignore();
    else if (obj is StreamSubscription)
      obj.cancel();
    else if (obj is StreamConsumer)
      obj.close();
    else if (obj is Sink)
      obj.close();
    else
      return false;

    return true;
  }

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

  final ProcessPersistence<St>? _processCloudSync;

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
  /// When [pausePersistor] is called, the Persistor will not start a new persistence process,
  /// until method [resumePersistor] is called. This will not affect the current persistence
  /// process, if one is currently running.
  ///
  /// Note: A persistence process starts when the [Persistor.persistDifference] method is called,
  /// and finishes when the future returned by that method completes.
  ///
  void pausePersistor() {
    _processPersistence?.pause();
  }

  /// Pause the [CloudSync] temporarily.
  ///
  /// When [pauseCloudSync] is called, the cloud sync will not start a new persistence process,
  /// until method [resumeCloudSync] is called. This will not affect the current persistence
  /// process, if one is currently running.
  ///
  /// Note: A cloud sync process starts when the [CloudSync.persistDifference] method is called,
  /// and finishes when the future returned by that method completes.
  ///
  void pauseCloudSync() {
    _processCloudSync?.pause();
  }

  /// Persists the current state (if it's not yet persisted), then pauses the [Persistor]
  /// temporarily.
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

  /// Saves the current state (if it's not yet saved) to the cloud, then pauses
  /// the [CloudSync] temporarily.
  ///
  /// When [persistAndPauseCloudSync] is called, this will not affect the current cloud save
  /// process, if one is currently running. If no cloud save process was running, it will
  /// immediately start a new save process (ignoring [CloudSync.throttle]).
  ///
  /// Then, the CloudSync will not start another cloud save process, until method
  /// [resumeCloudSync] is called.
  ///
  /// Note: A cloud save process starts when the [CloudSync.persistDifference] method is called,
  /// and finishes when the future returned by that method completes.
  ///
  void persistAndPauseCloudSync() {
    _processCloudSync?.persistAndPause();
  }

  /// Resumes persistence by the [Persistor],
  /// after calling [pausePersistor] or [persistAndPausePersistor].
  void resumePersistor() {
    _processPersistence?.resume();
  }

  /// Resumes persistence by the [CloudSync],
  /// after calling [pauseCloudSync] or [persistAndPauseCloudSync].
  void resumeCloudSync() {
    _processCloudSync?.resume();
  }

  /// Asks the [Persistor] to save the [initialState] in the local persistence.
  Future<void> saveInitialStateInPersistence(St initialState) async =>
      _processPersistence?.saveInitialState(initialState);

  /// Asks the [CloudSync] to save the [initialState] in the cloud.
  Future<void> saveInitialStateInCloud(St initialState) async =>
      _processCloudSync?.saveInitialState(initialState);

  /// Asks the [Persistor] to read the state from the local persistence.
  /// Important: If you use this, you MUST put this state into the store.
  /// The Persistor will assume that's the case, and will not work properly otherwise.
  Future<St?> readStateFromPersistence() async => _processPersistence?.readState();

  /// Asks the [CloudSync] to read the state from the cloud.
  /// Important: If you use this, you MUST put this state into the store.
  /// The CloudSync will assume that's the case, and will not work properly otherwise.
  Future<St?> readStateFromCloudSync() async => _processCloudSync?.readState();

  /// Asks the [Persistor] to delete the saved state from the cloud.
  Future<void> deleteStateFromPersistence() async => _processPersistence?.deleteState();

  /// Asks the [CloudSync] to delete the saved state from the cloud.
  Future<void> deleteStateFromCloud() async => _processCloudSync?.deleteState();

  /// Gets, from the [Persistor], the last state that was saved to the local persistence.
  St? getLastPersistedStateFromPersistor() => _processPersistence?.lastPersistedState;

  /// Gets, from the [CloudSync], the last state that was saved to the cloud.
  St? getLastPersistedStateFromCloudSync() => _processCloudSync?.lastPersistedState;

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
  /// This will not notify the listeners nor complete wait conditions.
  void defineState(St state) {
    _state = state;
    _stateTimestamp = DateTime.now().toUtc();
  }

  /// The global default timeout for the wait functions like [waitCondition] etc
  /// is 10 minutes. This value is not final and can be modified.
  /// To disable the timeout, make it -1.
  static int defaultTimeoutMillis = 60 * 1000 * 10;

  /// Returns a future which will complete when the given state [condition] is true.
  ///
  /// If [completeImmediately] is `true` (the default) and the condition was already true when
  /// the method was called, the future will complete immediately and throw no errors.
  ///
  /// If [completeImmediately] is `false` and the condition was already true when
  /// the method was called, it will throw a [StoreException].
  ///
  /// Note: The default here is `true`, while in the other `wait` methods
  /// like [waitActionCondition] it's `false`. This makes sense because of
  /// the different use cases for these methods.
  ///
  /// You may also provide a [timeoutMillis], which by default is 10 minutes.
  /// To disable the timeout, make it -1.
  /// If you want, you can modify [defaultTimeoutMillis] to change the default timeout.
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
  /// Examples:
  ///
  /// ```ts
  /// // Dispatches an actions that changes the state, then await for the state change:
  /// expect(store.state.name, 'John')
  /// dispatch(ChangeNameAction("Bill"));
  /// var action = await store.waitCondition((state) => state.name == "Bill");
  /// expect(action, isA<ChangeNameAction>());
  /// expect(store.state.name, 'Bill');
  ///
  /// // Dispatches actions and wait until no actions are in progress.
  /// dispatch(BuyStock('IBM'));
  /// dispatch(BuyStock('TSLA'));
  /// await waitAllActions([]);
  /// expect(state.stocks, ['IBM', 'TSLA']);
  ///
  /// // Dispatches two actions in PARALLEL and wait for their TYPES:
  /// expect(store.state.portfolio, ['TSLA']);
  /// dispatch(BuyAction('IBM'));
  /// dispatch(SellAction('TSLA'));
  /// await store.waitAllActionTypes([BuyAction, SellAction]);
  /// expect(store.state.portfolio, ['IBM']);
  ///
  /// // Dispatches actions in PARALLEL and wait until no actions are in progress.
  /// dispatch(BuyAction('IBM'));
  /// dispatch(BuyAction('TSLA'));
  /// await store.waitAllActions([]);
  /// expect(store.state.portfolio.containsAll('IBM', 'TSLA'), isFalse);
  ///
  /// // Dispatches two actions in PARALLEL and wait for them:
  /// let action1 = BuyAction('IBM');
  /// let action2 = SellAction('TSLA');
  /// dispatch(action1);
  /// dispatch(action2);
  /// await store.waitAllActions([action1, action2]);
  /// expect(store.state.portfolio.contains('IBM'), isTrue);
  /// expect(store.state.portfolio.contains('TSLA'), isFalse);
  ///
  /// // Dispatches two actions in SERIES and wait for them:
  /// await dispatchAndWait(BuyAction('IBM'));
  /// await dispatchAndWait(SellAction('TSLA'));
  /// expect(store.state.portfolio.containsAll('IBM', 'TSLA'), isFalse);
  ///
  /// // Wait until some action of a given type is dispatched.
  /// dispatch(DoALotOfStuffAction());
  /// var action = store.waitActionType(ChangeNameAction);
  /// expect(action, isA<ChangeNameAction>());
  /// expect(action.status.isCompleteOk, isTrue);
  /// expect(store.state.name, 'Bill');
  ///
  /// // Wait until some action of the given types is dispatched.
  /// dispatch(ProcessStocksAction());
  /// var action = store.waitAnyActionTypeFinishes([BuyAction, SellAction]);
  /// expect(store.state.portfolio.contains('IBM'), isTrue);
  /// ```
  ///
  /// See also:
  /// [waitCondition] - Waits until the state is in a given condition.
  /// [waitActionCondition] - Waits until the actions in progress meet a given condition.
  /// [waitAllActions] - Waits until the given actions are NOT in progress, or no actions are in progress.
  /// [waitActionType] - Waits until an action of a given type is NOT in progress.
  /// [waitAllActionTypes] - Waits until all actions of the given type are NOT in progress.
  /// [waitAnyActionTypeFinishes] - Waits until ANY action of the given types finish dispatching.
  ///
  Future<ReduxAction<St>?> waitCondition(
    bool Function(St) condition, {
    //
    /// If `completeImmediately` is `true` (the default) and the condition was already true when
    /// the method was called, the future will complete immediately and throw no errors.
    ///
    /// If `completeImmediately` is `false` and the condition was already true when
    /// the method was called, it will throw a [StoreException].
    ///
    /// Note: The default here is `true`, while in the other `wait` methods
    /// like [waitActionCondition] it's `false`. This makes sense because of
    /// the different use cases for these methods.
    bool completeImmediately = true,
    //
    /// The maximum time to wait for the condition to be met. The default is 10 minutes.
    /// To disable the timeout, make it -1.
    int? timeoutMillis,
  }) async {
    //
    // If the condition is already true when `waitCondition` is called.
    if (condition(_state)) {
      // Complete and return null (no trigger action).
      if (completeImmediately)
        return Future.value(null);
      // else throw an error.
      else
        throw StoreException("Awaited state condition was already true, "
            "and the future completed immediately.");
    }
    //
    else {
      var completer = Completer<ReduxAction<St>?>();

      _stateConditionCompleters[condition] = completer;

      int timeout = timeoutMillis ?? defaultTimeoutMillis;
      var future = completer.future;

      if (timeout >= 0)
        future = completer.future.timeout(
          Duration(milliseconds: timeout),
          onTimeout: () {
            _stateConditionCompleters.remove(condition);
            throw TimeoutException(null, Duration(milliseconds: timeout));
          },
        );

      return future;
    }
  }

  // This map will hold the completers for each ACTION condition checker function.
  // 1) The set key is the condition checker function.
  // 2) The value is the completer, that informs of:
  //    - The set of actions in progress when the condition is met.
  //    - The action that triggered the condition.
  final _actionConditionCompleters = <bool Function(Set<ReduxAction<St>>, ReduxAction<St>?),
      Completer<(Set<ReduxAction<St>>, ReduxAction<St>?)>>{};

  // This map will hold the completers for each STATE condition checker function.
  // 1) The set key is the condition checker function.
  // 2) The value is the completer, that informs the action that triggered the condition.
  final _stateConditionCompleters = <bool Function(St), Completer<ReduxAction<St>?>>{};

  /// Returns a future that completes when some actions meet the given [condition].
  ///
  /// If [completeImmediately] is `false` (the default), this method will throw [StoreException]
  /// if the condition was already true when the method was called. Otherwise, the future will
  /// complete immediately and throw no error.
  ///
  /// The [condition] is a function that takes the set of actions "in progress", as well as an
  /// action that just entered the set (by being dispatched) or left the set (by finishing
  /// dispatching). The function should return `true` when the condition is met, and `false`
  /// otherwise. For example:
  ///
  /// ```dart
  /// var action = await store.waitActionCondition((actionsInProgress, triggerAction) { ... }
  /// ```
  ///
  /// You get back an unmodifiable set of the actions being dispatched that met the condition,
  /// as well as the action that triggered the condition by being added or removed from the set.
  ///
  /// Note: The condition is only checked when some action is dispatched or finishes dispatching.
  /// It's not checked every time action statuses change.
  ///
  /// You may also provide a [timeoutMillis], which by default is 10 minutes.
  /// To disable the timeout, make it -1.
  /// If you want, you can modify [defaultTimeoutMillis] to change the default timeout.
  ///
  /// Examples:
  ///
  /// ```ts
  /// // Dispatches an actions that changes the state, then await for the state change:
  /// expect(store.state.name, 'John')
  /// dispatch(ChangeNameAction("Bill"));
  /// var action = await store.waitCondition((state) => state.name == "Bill");
  /// expect(action, isA<ChangeNameAction>());
  /// expect(store.state.name, 'Bill');
  ///
  /// // Dispatches actions and wait until no actions are in progress.
  /// dispatch(BuyStock('IBM'));
  /// dispatch(BuyStock('TSLA'));
  /// await waitAllActions([]);
  /// expect(state.stocks, ['IBM', 'TSLA']);
  ///
  /// // Dispatches two actions in PARALLEL and wait for their TYPES:
  /// expect(store.state.portfolio, ['TSLA']);
  /// dispatch(BuyAction('IBM'));
  /// dispatch(SellAction('TSLA'));
  /// await store.waitAllActionTypes([BuyAction, SellAction]);
  /// expect(store.state.portfolio, ['IBM']);
  ///
  /// // Dispatches actions in PARALLEL and wait until no actions are in progress.
  /// dispatch(BuyAction('IBM'));
  /// dispatch(BuyAction('TSLA'));
  /// await store.waitAllActions([]);
  /// expect(store.state.portfolio.containsAll('IBM', 'TSLA'), isFalse);
  ///
  /// // Dispatches two actions in PARALLEL and wait for them:
  /// let action1 = BuyAction('IBM');
  /// let action2 = SellAction('TSLA');
  /// dispatch(action1);
  /// dispatch(action2);
  /// await store.waitAllActions([action1, action2]);
  /// expect(store.state.portfolio.contains('IBM'), isTrue);
  /// expect(store.state.portfolio.contains('TSLA'), isFalse);
  ///
  /// // Dispatches two actions in SERIES and wait for them:
  /// await dispatchAndWait(BuyAction('IBM'));
  /// await dispatchAndWait(SellAction('TSLA'));
  /// expect(store.state.portfolio.containsAll('IBM', 'TSLA'), isFalse);
  ///
  /// // Wait until some action of a given type is dispatched.
  /// dispatch(DoALotOfStuffAction());
  /// var action = store.waitActionType(ChangeNameAction);
  /// expect(action, isA<ChangeNameAction>());
  /// expect(action.status.isCompleteOk, isTrue);
  /// expect(store.state.name, 'Bill');
  ///
  /// // Wait until some action of the given types is dispatched.
  /// dispatch(ProcessStocksAction());
  /// var action = store.waitAnyActionTypeFinishes([BuyAction, SellAction]);
  /// expect(store.state.portfolio.contains('IBM'), isTrue);
  /// ```
  ///
  /// See also:
  /// [waitCondition] - Waits until the state is in a given condition.
  /// [waitActionCondition] - Waits until the actions in progress meet a given condition.
  /// [waitAllActions] - Waits until the given actions are NOT in progress, or no actions are in progress.
  /// [waitActionType] - Waits until an action of a given type is NOT in progress.
  /// [waitAllActionTypes] - Waits until all actions of the given type are NOT in progress.
  /// [waitAnyActionTypeFinishes] - Waits until ANY action of the given types finish dispatching.
  ///
  /// You should only use this method in tests.
  @visibleForTesting
  Future<(Set<ReduxAction<St>>, ReduxAction<St>?)> waitActionCondition(
    //
    //
    /// The condition receives the current actions in progress, and the action that triggered the condition.
    bool Function(Set<ReduxAction<St>> actions, ReduxAction<St>? triggerAction) condition, {
    //
    /// If `completeImmediately` is `false` (the default), this method will throw an error if the
    /// condition is already true when the method is called. Otherwise, the future will complete
    /// immediately and throw no error.
    bool completeImmediately = false,
    //
    /// Error message in case the condition was already true when the method was called,
    /// and `completeImmediately` is false.
    String completedErrorMessage = "Awaited action condition was already true",
    //
    /// The maximum time to wait for the condition to be met. The default is 10 minutes.
    /// To disable the timeout, make it -1.
    int? timeoutMillis,
  }) {
    //
    // If the condition is already true when `waitActionCondition` is called.
    if (condition(actionsInProgress(), null)) {
      // Complete and return the actions in progress and the trigger action.
      if (completeImmediately)
        return Future.value((actionsInProgress(), null));
      // else throw an error.
      else
        throw StoreException(completedErrorMessage + ", and the future completed immediately.");
    }
    //
    else {
      var completer = Completer<(Set<ReduxAction<St>>, ReduxAction<St>?)>();

      _actionConditionCompleters[condition] = completer;

      int timeout = timeoutMillis ?? defaultTimeoutMillis;
      var future = completer.future;

      if (timeout >= 0)
        future = completer.future.timeout(
          Duration(milliseconds: timeout),
          onTimeout: () {
            _actionConditionCompleters.remove(condition);
            throw TimeoutException(null, Duration(milliseconds: timeout));
          },
        );

      return future;
    }
  }

  /// Returns a future that completes when ALL given [actions] finish dispatching.
  ///
  /// If [completeImmediately] is `false` (the default), this method will throw [StoreException]
  /// if none of the given actions are in progress when the method is called. Otherwise, the future
  /// will complete immediately and throw no error.
  ///
  /// However, if you don't provide any actions (empty list or `null`), the future will complete
  /// when ALL current actions in progress finish dispatching. In other words, when no actions are
  /// currently in progress. In this case, if [completeImmediately] is `false`, the method will
  /// throw an error if no actions are in progress when the method is called.
  ///
  /// Note: Waiting until no actions are in progress should only be done in test, never in
  /// production, as it's very easy to create a deadlock. However, waiting for specific actions to
  /// finish is safe in production, as long as you're waiting for actions you just dispatched.
  ///
  /// You may also provide a [timeoutMillis], which by default is 10 minutes.
  /// To disable the timeout, make it -1.
  /// If you want, you can modify [defaultTimeoutMillis] to change the default timeout.
  ///
  /// Examples:
  ///
  /// ```ts
  /// // Dispatches an actions that changes the state, then await for the state change:
  /// expect(store.state.name, 'John')
  /// dispatch(ChangeNameAction("Bill"));
  /// var action = await store.waitCondition((state) => state.name == "Bill");
  /// expect(action, isA<ChangeNameAction>());
  /// expect(store.state.name, 'Bill');
  ///
  /// // Dispatches actions and wait until no actions are in progress.
  /// dispatch(BuyStock('IBM'));
  /// dispatch(BuyStock('TSLA'));
  /// await waitAllActions([]);
  /// expect(state.stocks, ['IBM', 'TSLA']);
  ///
  /// // Dispatches two actions in PARALLEL and wait for their TYPES:
  /// expect(store.state.portfolio, ['TSLA']);
  /// dispatch(BuyAction('IBM'));
  /// dispatch(SellAction('TSLA'));
  /// await store.waitAllActionTypes([BuyAction, SellAction]);
  /// expect(store.state.portfolio, ['IBM']);
  ///
  /// // Dispatches actions in PARALLEL and wait until no actions are in progress.
  /// dispatch(BuyAction('IBM'));
  /// dispatch(BuyAction('TSLA'));
  /// await store.waitAllActions([]);
  /// expect(store.state.portfolio.containsAll('IBM', 'TSLA'), isFalse);
  ///
  /// // Dispatches two actions in PARALLEL and wait for them:
  /// let action1 = BuyAction('IBM');
  /// let action2 = SellAction('TSLA');
  /// dispatch(action1);
  /// dispatch(action2);
  /// await store.waitAllActions([action1, action2]);
  /// expect(store.state.portfolio.contains('IBM'), isTrue);
  /// expect(store.state.portfolio.contains('TSLA'), isFalse);
  ///
  /// // Dispatches two actions in SERIES and wait for them:
  /// await dispatchAndWait(BuyAction('IBM'));
  /// await dispatchAndWait(SellAction('TSLA'));
  /// expect(store.state.portfolio.containsAll('IBM', 'TSLA'), isFalse);
  ///
  /// // Wait until some action of a given type is dispatched.
  /// dispatch(DoALotOfStuffAction());
  /// var action = store.waitActionType(ChangeNameAction);
  /// expect(action, isA<ChangeNameAction>());
  /// expect(action.status.isCompleteOk, isTrue);
  /// expect(store.state.name, 'Bill');
  ///
  /// // Wait until some action of the given types is dispatched.
  /// dispatch(ProcessStocksAction());
  /// var action = store.waitAnyActionTypeFinishes([BuyAction, SellAction]);
  /// expect(store.state.portfolio.contains('IBM'), isTrue);
  /// ```
  ///
  /// See also:
  /// [waitCondition] - Waits until the state is in a given condition.
  /// [waitActionCondition] - Waits until the actions in progress meet a given condition.
  /// [waitAllActions] - Waits until the given actions are NOT in progress, or no actions are in progress.
  /// [waitActionType] - Waits until an action of a given type is NOT in progress.
  /// [waitAllActionTypes] - Waits until all actions of the given type are NOT in progress.
  /// [waitAnyActionTypeFinishes] - Waits until ANY action of the given types finish dispatching.
  ///
  Future<void> waitAllActions(
    List<ReduxAction<St>>? actions, {
    bool completeImmediately = false,
    int? timeoutMillis,
  }) {
    if (actions == null || actions.isEmpty) {
      return this.waitActionCondition(
          completeImmediately: completeImmediately,
          completedErrorMessage: "No actions were in progress",
          timeoutMillis: timeoutMillis,
          (actions, triggerAction) => actions.isEmpty);
    } else {
      return this.waitActionCondition(
        completeImmediately: completeImmediately,
        completedErrorMessage: "None of the given actions were in progress",
        timeoutMillis: timeoutMillis,
        //
        (actionsInProgress, triggerAction) {
          for (var action in actions) {
            if (actionsInProgress.contains(action)) return false;
          }
          return true;
        },
      );
    }
  }

  /// Returns a future that completes when an action of the given type in NOT in progress
  /// (it's not being dispatched):
  ///
  /// - If NO action of the given type is currently in progress when the method is called,
  ///   and [completeImmediately] is `false` (the default), this method will throw an error.
  ///
  /// - If NO action of the given type is currently in progress when the method is called,
  ///   and [completeImmediately] is `true`, the future completes immediately, returns `null`,
  ///   and throws no error.
  ///
  /// - If an action of the given type is in progress, the future completes when the action
  ///   finishes, and returns the action. You can use the returned action to check its `status`:
  ///
  ///   ```dart
  ///   var action = await store.waitActionType(MyAction);
  ///   expect(action.status.originalError, isA<UserException>());
  ///   ```
  ///
  /// You may also provide a [timeoutMillis], which by default is 10 minutes.
  /// To disable the timeout, make it -1.
  /// If you want, you can modify [defaultTimeoutMillis] to change the default timeout.
  ///
  /// Examples:
  ///
  /// ```ts
  /// // Dispatches an actions that changes the state, then await for the state change:
  /// expect(store.state.name, 'John')
  /// dispatch(ChangeNameAction("Bill"));
  /// var action = await store.waitCondition((state) => state.name == "Bill");
  /// expect(action, isA<ChangeNameAction>());
  /// expect(store.state.name, 'Bill');
  ///
  /// // Dispatches actions and wait until no actions are in progress.
  /// dispatch(BuyStock('IBM'));
  /// dispatch(BuyStock('TSLA'));
  /// await waitAllActions([]);
  /// expect(state.stocks, ['IBM', 'TSLA']);
  ///
  /// // Dispatches two actions in PARALLEL and wait for their TYPES:
  /// expect(store.state.portfolio, ['TSLA']);
  /// dispatch(BuyAction('IBM'));
  /// dispatch(SellAction('TSLA'));
  /// await store.waitAllActionTypes([BuyAction, SellAction]);
  /// expect(store.state.portfolio, ['IBM']);
  ///
  /// // Dispatches actions in PARALLEL and wait until no actions are in progress.
  /// dispatch(BuyAction('IBM'));
  /// dispatch(BuyAction('TSLA'));
  /// await store.waitAllActions([]);
  /// expect(store.state.portfolio.containsAll('IBM', 'TSLA'), isFalse);
  ///
  /// // Dispatches two actions in PARALLEL and wait for them:
  /// let action1 = BuyAction('IBM');
  /// let action2 = SellAction('TSLA');
  /// dispatch(action1);
  /// dispatch(action2);
  /// await store.waitAllActions([action1, action2]);
  /// expect(store.state.portfolio.contains('IBM'), isTrue);
  /// expect(store.state.portfolio.contains('TSLA'), isFalse);
  ///
  /// // Dispatches two actions in SERIES and wait for them:
  /// await dispatchAndWait(BuyAction('IBM'));
  /// await dispatchAndWait(SellAction('TSLA'));
  /// expect(store.state.portfolio.containsAll('IBM', 'TSLA'), isFalse);
  ///
  /// // Wait until some action of a given type is dispatched.
  /// dispatch(DoALotOfStuffAction());
  /// var action = store.waitActionType(ChangeNameAction);
  /// expect(action, isA<ChangeNameAction>());
  /// expect(action.status.isCompleteOk, isTrue);
  /// expect(store.state.name, 'Bill');
  ///
  /// // Wait until some action of the given types is dispatched.
  /// dispatch(ProcessStocksAction());
  /// var action = store.waitAnyActionTypeFinishes([BuyAction, SellAction]);
  /// expect(store.state.portfolio.contains('IBM'), isTrue);
  /// ```
  ///
  /// See also:
  /// [waitCondition] - Waits until the state is in a given condition.
  /// [waitActionCondition] - Waits until the actions in progress meet a given condition.
  /// [waitAllActions] - Waits until the given actions are NOT in progress, or no actions are in progress.
  /// [waitActionType] - Waits until an action of a given type is NOT in progress.
  /// [waitAllActionTypes] - Waits until all actions of the given type are NOT in progress.
  /// [waitAnyActionTypeFinishes] - Waits until ANY action of the given types finish dispatching.
  ///
  /// You should only use this method in tests.
  @visibleForTesting
  Future<ReduxAction<St>?> waitActionType(
    Type actionType, {
    bool completeImmediately = false,
    int? timeoutMillis,
  }) async {
    var (_, triggerAction) = await this.waitActionCondition(
      completeImmediately: completeImmediately,
      completedErrorMessage: "No action of the given type was in progress",
      timeoutMillis: timeoutMillis,
      //
      (actionsInProgress, triggerAction) {
        return !actionsInProgress.any((action) => action.runtimeType == actionType);
      },
    );

    return triggerAction;
  }

  /// Returns a future that completes when ALL actions of the given types are NOT in progress
  /// (none of them are being dispatched):
  ///
  /// - If NO action of the given types is currently in progress when the method is called,
  ///   and [completeImmediately] is `false` (the default), this method will throw an error.
  ///
  /// - If NO action of the given type is currently in progress when the method is called,
  ///   and [completeImmediately] is `true`, the future completes immediately and throws no error.
  ///
  /// - If any action of the given types is in progress, the future completes only when
  ///   no action of the given types is in progress anymore.
  ///
  /// You may also provide a [timeoutMillis], which by default is 10 minutes.
  /// To disable the timeout, make it -1.
  /// If you want, you can modify [defaultTimeoutMillis] to change the default timeout.
  ///
  /// Examples:
  ///
  /// ```ts
  /// // Dispatches an actions that changes the state, then await for the state change:
  /// expect(store.state.name, 'John')
  /// dispatch(ChangeNameAction("Bill"));
  /// var action = await store.waitCondition((state) => state.name == "Bill");
  /// expect(action, isA<ChangeNameAction>());
  /// expect(store.state.name, 'Bill');
  ///
  /// // Dispatches actions and wait until no actions are in progress.
  /// dispatch(BuyStock('IBM'));
  /// dispatch(BuyStock('TSLA'));
  /// await waitAllActions([]);
  /// expect(state.stocks, ['IBM', 'TSLA']);
  ///
  /// // Dispatches two actions in PARALLEL and wait for their TYPES:
  /// expect(store.state.portfolio, ['TSLA']);
  /// dispatch(BuyAction('IBM'));
  /// dispatch(SellAction('TSLA'));
  /// await store.waitAllActionTypes([BuyAction, SellAction]);
  /// expect(store.state.portfolio, ['IBM']);
  ///
  /// // Dispatches actions in PARALLEL and wait until no actions are in progress.
  /// dispatch(BuyAction('IBM'));
  /// dispatch(BuyAction('TSLA'));
  /// await store.waitAllActions([]);
  /// expect(store.state.portfolio.containsAll('IBM', 'TSLA'), isFalse);
  ///
  /// // Dispatches two actions in PARALLEL and wait for them:
  /// let action1 = BuyAction('IBM');
  /// let action2 = SellAction('TSLA');
  /// dispatch(action1);
  /// dispatch(action2);
  /// await store.waitAllActions([action1, action2]);
  /// expect(store.state.portfolio.contains('IBM'), isTrue);
  /// expect(store.state.portfolio.contains('TSLA'), isFalse);
  ///
  /// // Dispatches two actions in SERIES and wait for them:
  /// await dispatchAndWait(BuyAction('IBM'));
  /// await dispatchAndWait(SellAction('TSLA'));
  /// expect(store.state.portfolio.containsAll('IBM', 'TSLA'), isFalse);
  ///
  /// // Wait until some action of a given type is dispatched.
  /// dispatch(DoALotOfStuffAction());
  /// var action = store.waitActionType(ChangeNameAction);
  /// expect(action, isA<ChangeNameAction>());
  /// expect(action.status.isCompleteOk, isTrue);
  /// expect(store.state.name, 'Bill');
  ///
  /// // Wait until some action of the given types is dispatched.
  /// dispatch(ProcessStocksAction());
  /// var action = store.waitAnyActionTypeFinishes([BuyAction, SellAction]);
  /// expect(store.state.portfolio.contains('IBM'), isTrue);
  /// ```
  ///
  /// See also:
  /// [waitCondition] - Waits until the state is in a given condition.
  /// [waitActionCondition] - Waits until the actions in progress meet a given condition.
  /// [waitAllActions] - Waits until the given actions are NOT in progress, or no actions are in progress.
  /// [waitActionType] - Waits until an action of a given type is NOT in progress.
  /// [waitAllActionTypes] - Waits until all actions of the given type are NOT in progress.
  /// [waitAnyActionTypeFinishes] - Waits until ANY action of the given types finish dispatching.
  ///
  /// You should only use this method in tests.
  @visibleForTesting
  Future<void> waitAllActionTypes(
    List<Type> actionTypes, {
    bool completeImmediately = false,
    int? timeoutMillis,
  }) async {
    if (actionTypes.isEmpty) {
      await this.waitActionCondition(
        completeImmediately: completeImmediately,
        completedErrorMessage: "No actions are in progress",
        timeoutMillis: timeoutMillis,
        (actions, triggerAction) => actions.isEmpty,
      );
    } else {
      await this.waitActionCondition(
        completeImmediately: completeImmediately,
        completedErrorMessage: "No action of the given types was in progress",
        timeoutMillis: timeoutMillis,
        //
        (actionsInProgress, triggerAction) {
          for (var actionType in actionTypes) {
            if (actionsInProgress.any((action) => action.runtimeType == actionType)) return false;
          }
          return true;
        },
      );
    }
  }

  /// Returns a future which will complete when ANY action of the given types FINISHES
  /// dispatching. IMPORTANT: This method is different from the other similar methods, because
  /// it does NOT complete immediately if no action of the given types is in progress. Instead,
  /// it waits until an action of the given types finishes dispatching, even if they
  /// were not yet in progress when the method was called.
  ///
  /// This method returns the action that completed the future, which you can use to check
  /// its `status`.
  ///
  /// It's useful when the actions you are waiting for are not yet dispatched when you call this
  /// method. For example, suppose action `StartAction` starts a process that takes some time
  /// to run and then dispatches an action called `MyFinalAction`. You can then write:
  ///
  /// ```dart
  /// dispatch(StartAction());
  /// var action = await store.waitAnyActionTypeFinishes([MyFinalAction]);
  /// expect(action.status.originalError, isA<UserException>());
  /// ```
  ///
  /// You may also provide a [timeoutMillis], which by default is 10 minutes.
  /// To disable the timeout, make it -1.
  /// If you want, you can modify [defaultTimeoutMillis] to change the default timeout.
  ///
  /// Examples:
  ///
  /// ```ts
  /// // Dispatches an actions that changes the state, then await for the state change:
  /// expect(store.state.name, 'John')
  /// dispatch(ChangeNameAction("Bill"));
  /// var action = await store.waitCondition((state) => state.name == "Bill");
  /// expect(action, isA<ChangeNameAction>());
  /// expect(store.state.name, 'Bill');
  ///
  /// // Dispatches actions and wait until no actions are in progress.
  /// dispatch(BuyStock('IBM'));
  /// dispatch(BuyStock('TSLA'));
  /// await waitAllActions([]);
  /// expect(state.stocks, ['IBM', 'TSLA']);
  ///
  /// // Dispatches two actions in PARALLEL and wait for their TYPES:
  /// expect(store.state.portfolio, ['TSLA']);
  /// dispatch(BuyAction('IBM'));
  /// dispatch(SellAction('TSLA'));
  /// await store.waitAllActionTypes([BuyAction, SellAction]);
  /// expect(store.state.portfolio, ['IBM']);
  ///
  /// // Dispatches actions in PARALLEL and wait until no actions are in progress.
  /// dispatch(BuyAction('IBM'));
  /// dispatch(BuyAction('TSLA'));
  /// await store.waitAllActions([]);
  /// expect(store.state.portfolio.containsAll('IBM', 'TSLA'), isFalse);
  ///
  /// // Dispatches two actions in PARALLEL and wait for them:
  /// let action1 = BuyAction('IBM');
  /// let action2 = SellAction('TSLA');
  /// dispatch(action1);
  /// dispatch(action2);
  /// await store.waitAllActions([action1, action2]);
  /// expect(store.state.portfolio.contains('IBM'), isTrue);
  /// expect(store.state.portfolio.contains('TSLA'), isFalse);
  ///
  /// // Dispatches two actions in SERIES and wait for them:
  /// await dispatchAndWait(BuyAction('IBM'));
  /// await dispatchAndWait(SellAction('TSLA'));
  /// expect(store.state.portfolio.containsAll('IBM', 'TSLA'), isFalse);
  ///
  /// // Wait until some action of a given type is dispatched.
  /// dispatch(DoALotOfStuffAction());
  /// var action = store.waitActionType(ChangeNameAction);
  /// expect(action, isA<ChangeNameAction>());
  /// expect(action.status.isCompleteOk, isTrue);
  /// expect(store.state.name, 'Bill');
  ///
  /// // Wait until some action of the given types is dispatched.
  /// dispatch(ProcessStocksAction());
  /// var action = store.waitAnyActionTypeFinishes([BuyAction, SellAction]);
  /// expect(store.state.portfolio.contains('IBM'), isTrue);
  /// ```
  ///
  /// See also:
  /// [waitCondition] - Waits until the state is in a given condition.
  /// [waitActionCondition] - Waits until the actions in progress meet a given condition.
  /// [waitAllActions] - Waits until the given actions are NOT in progress, or no actions are in progress.
  /// [waitActionType] - Waits until an action of a given type is NOT in progress.
  /// [waitAllActionTypes] - Waits until all actions of the given type are NOT in progress.
  /// [waitAnyActionTypeFinishes] - Waits until ANY action of the given types finish dispatching.
  ///
  /// You should only use this method in tests.
  @visibleForTesting
  Future<ReduxAction<St>> waitAnyActionTypeFinishes(
    List<Type> actionTypes, {
    int? timeoutMillis,
  }) async {
    var (_, triggerAction) = await this.waitActionCondition(
      completedErrorMessage: "Assertion error",
      timeoutMillis: timeoutMillis,
      //
      (actionsInProgress, triggerAction) {
        //
        // If the triggerAction is one of the actionTypes,
        if ((triggerAction != null) && actionTypes.contains(triggerAction.runtimeType)) {
          // If the actions in progress do not contain the triggerAction, then the triggerAction has finished.
          // Otherwise, the triggerAction has just been dispatched, which is not what we want.
          bool isFinished = !actionsInProgress.contains(triggerAction);
          return isFinished;
        }
        return false;
      },
    );

    // Always non-null, because the condition is only met when an action finishes.
    return triggerAction!;
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
  ///
  /// See also: [isShutdown] and [disposeProps].
  void shutdown() {
    _shutdown = true;
  }

  bool get isShutdown => _shutdown;

  /// Dispatches the action, applying its reducer, and possibly changing the store state.
  /// The action may be sync or async.
  ///
  /// ```dart
  /// store.dispatch(MyAction());
  /// ```
  /// If you pass the [notify] parameter as `false`, widgets will not necessarily rebuild because
  /// of this action, even if it changes the state.
  ///
  /// Method [dispatch] is of type [Dispatch].
  ///
  /// See also:
  /// - [dispatchSync] which dispatches sync actions, and throws if the action is async.
  /// - [dispatchAndWait] which dispatches both sync and async actions, and returns a Future.
  /// - [dispatchAll] which dispatches all given actions in parallel.
  ///
  FutureOr<ActionStatus> dispatch(ReduxAction<St> action, {bool notify = true}) =>
      _dispatch(action, notify: notify);

  /// Dispatches the action, applying its reducer, and possibly changing the store state.
  /// However, if the action is ASYNC, it will throw a [StoreException].
  ///
  /// If you pass the [notify] parameter as `false`, widgets will not necessarily rebuild because
  /// of this action, even if it changes the state.
  ///
  /// Method [dispatchSync] is of type [DispatchSync]. It returns `ActionStatus`,
  /// which means you can also get the final status of the action:
  ///
  /// ```dart
  /// var status = store.dispatchSync(MyAction());
  /// ```
  ///
  /// See also:
  /// - [dispatch] which dispatches both sync and async actions.
  /// - [dispatchAndWait] which dispatches both sync and async actions, and returns a Future.
  /// - [dispatchAndWaitAll] which dispatches all given actions, and returns a Future.
  /// - [dispatchAll] which dispatches all given actions in parallel.
  ///
  ActionStatus dispatchSync(ReduxAction<St> action, {bool notify = true}) {
    if (!action.isSync()) {
      throw StoreException(
          "Can't dispatchSync(${action.runtimeType}) because ${action.runtimeType} is async.");
    }

    return _dispatch(action, notify: notify) as ActionStatus;
  }

  /// Dispatches the action, applying its reducer, and possibly changing the store state.
  /// The action may be sync or async. In both cases, it returns a [Future] that resolves when
  /// the action finishes.
  ///
  /// ```dart
  /// await store.dispatchAndWait(DoThisFirstAction());
  /// store.dispatch(DoThisSecondAction());
  /// ```
  ///
  /// If you pass the [notify] parameter as `false`, widgets will not necessarily rebuild because
  /// of this action, even if it changes the state.
  ///
  /// Note: While the state change from the action's reducer will have been applied when the
  /// Future resolves, other independent processes that the action may have started may still
  /// be in progress.
  ///
  /// Method [dispatchAndWait] is of type [DispatchAndWait]. It returns `Future<ActionStatus>`,
  /// which means you can also get the final status of the action after you `await` it:
  ///
  /// ```dart
  /// var status = await store.dispatchAndWait(MyAction());
  /// ```
  ///
  /// See also:
  /// - [dispatch] which dispatches both sync and async actions.
  /// - [dispatchAndWaitAll] which dispatches all given actions, and returns a Future.
  /// - [dispatchSync] which dispatches sync actions, and throws if the action is async.
  /// - [dispatchAll] which dispatches all given actions in parallel.
  ///
  Future<ActionStatus> dispatchAndWait(ReduxAction<St> action, {bool notify = true}) =>
      Future.value(_dispatch(action, notify: notify));

  /// Dispatches all given [actions] in parallel, applying their reducer, and possibly changing
  /// the store state. It returns the same list of [actions], so that you can instantiate them
  /// inline, but still get a list of them.
  ///
  /// ```dart
  /// var actions = dispatchAll([BuyAction('IBM'), SellAction('TSLA')]);
  /// ```
  ///
  /// If you pass the [notify] parameter as `false`, widgets will not necessarily rebuild because
  /// of these actions, even if it changes the state.
  ///
  /// See also:
  /// - [dispatch] which dispatches both sync and async actions.
  /// - [dispatchAndWait] which dispatches both sync and async actions, and returns a Future.
  /// - [dispatchAndWaitAll] which dispatches all given actions, and returns a Future.
  /// - [dispatchSync] which dispatches sync actions, and throws if the action is async.
  ///
  List<ReduxAction<St>> dispatchAll(List<ReduxAction<St>> actions, {bool notify = true}) {
    for (var action in actions) {
      dispatch(action, notify: notify);
    }
    return actions;
  }

  /// Dispatches all given [actions] in parallel, applying their reducers, and possibly changing
  /// the store state. The actions may be sync or async. It returns a [Future] that resolves when
  /// ALL actions finish.
  ///
  /// ```dart
  /// var actions = await store.dispatchAndWaitAll([BuyAction('IBM'), SellAction('TSLA')]);
  /// ```
  ///
  /// Note this is exactly the same as doing:
  ///
  /// ```dart
  /// var action1 = BuyAction('IBM');
  /// var action2 = SellAction('TSLA');
  /// dispatch(action1);
  /// dispatch(action2);
  /// await store.waitAllActions([action1, action2], completeImmediately = true);
  /// var actions = [action1, action2];
  /// ```
  ///
  /// If you pass the [notify] parameter as `false`, widgets will not necessarily rebuild because
  /// of these actions, even if they change the state.
  ///
  /// Note: While the state change from the action's reducers will have been applied when the
  /// Future resolves, other independent processes that the action may have started may still
  /// be in progress.
  ///
  /// See also:
  /// - [dispatch] which dispatches both sync and async actions.
  /// - [dispatchAndWait] which dispatches both sync and async actions, and returns a Future.
  /// - [dispatchSync] which dispatches sync actions, and throws if the action is async.
  /// - [dispatchAll] which dispatches all given actions in parallel.
  ///
  Future<List<ReduxAction<St>>> dispatchAndWaitAll(
    List<ReduxAction<St>> actions, {
    bool notify = true,
  }) async {
    var futures = <Future<ActionStatus>>[];

    for (var action in actions) {
      futures.add(dispatchAndWait(action, notify: notify));
    }
    await Future.wait(futures);

    return actions;
  }

  @Deprecated("Use `dispatchAndWait` instead. This will be removed.")
  Future<ActionStatus> dispatchAsync(ReduxAction<St> action, {bool notify = true}) =>
      dispatchAndWait(action, notify: notify);

  FutureOr<ActionStatus> _dispatch(ReduxAction<St> action, {required bool notify}) {
    //
    // The action may access the store/state/dispatch as fields.
    action.setStore(this);

    if (_shutdown || action.abortDispatch()) return ActionStatus(isDispatchAborted: true);

    _dispatchCount++;

    if (action.status.isDispatched)
      throw new StoreException(
          'The action was already dispatched. Please, create a new action each time.');

    action._status = action._status.copy(isDispatched: true);

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

  /// Returns a copy of the error queue, containing user exception errors thrown by
  /// dispatched actions. Note that this is a copy of the queue, so you can't modify the original
  /// queue here. Instead, use [getAndRemoveFirstError] to consume the errors, one by one.
  Queue<UserException> get errors => Queue<UserException>.of(_errors);

  /// We check the return type of methods `before` and `reduce` to decide if the
  /// reducer is synchronous or asynchronous. It's important to run the reducer
  /// synchronously, if possible.
  FutureOr<ActionStatus> _processAction(
    ReduxAction<St> action, {
    bool notify = true,
  }) {
    //
    _calculateIsWaitingIsFailed(action);

    if (action.isSync())
      return _processAction_Sync(action, notify: notify);
    else
      return _processAction_Async(action, notify: notify);
  }

  void _calculateIsWaitingIsFailed(ReduxAction<St> action) {
    //
    // If the action is failable (that is to say, we have once called `isFailed` for this action),
    bool failable = _actionsWeCanCheckFailed.contains(action.runtimeType);

    bool theUIHasAlreadyUpdated = false;

    if (failable) {
      // Dispatch is starting, so we remove the action from the list of failed actions.
      var removedAction = _failedActions.remove(action.runtimeType);

      // Then we notify the UI. Note we don't notify if the action was never checked.
      if (removedAction != null) {
        theUIHasAlreadyUpdated = true;
        _changeController.add(state);
      }
    }

    // Add the action to the list of actions in progress.
    // Note: We add both SYNC and ASYNC actions. The SYNC actions are important too,
    // to prevent NonReentrant sync actions, where they call themselves.
    bool ifWasAdded = _actionsInProgress.add(action);
    if (ifWasAdded) _checkAllActionConditions(action);

    // Note: If the UI hasn't updated yet, AND
    // the action is awaitable (that is to say, we have already called `isWaiting` for this action),
    if (!theUIHasAlreadyUpdated && _awaitableActions.contains(action.runtimeType)) {
      _changeController.add(state);
    }
  }

  /// The [triggerAction] is the action that was just added or removed in the list
  /// of [_actionsInProgress] that triggered the check.
  ///
  void _checkAllActionConditions(ReduxAction<St> triggerAction) {
    List<bool Function(Set<ReduxAction<St>>, ReduxAction<St>?)> keysToRemove = [];

    _actionConditionCompleters.forEach((condition, completer) {
      if (condition(actionsInProgress(), triggerAction)) {
        completer.complete((actionsInProgress(), triggerAction));
        keysToRemove.add(condition);
      }
    });

    keysToRemove.forEach((key) {
      _actionConditionCompleters.remove(key);
    });
  }

  /// The [triggerAction] is the action that modified the state to trigger the condition.
  void _checkAllStateConditions(ReduxAction<St> triggerAction) {
    List<bool Function(St)> keysToRemove = [];

    _stateConditionCompleters.forEach((condition, completer) {
      if (condition(_state)) {
        completer.complete(triggerAction);
        keysToRemove.add(condition);
      }
    });

    keysToRemove.forEach((key) {
      _stateConditionCompleters.remove(key);
    });
  }

  /// You can use [isWaiting] and pass it [actionOrActionTypeOrList] to check if:
  /// * A specific async ACTION is currently being processed.
  /// * An async action of a specific TYPE is currently being processed.
  /// * If any of a few given async actions or action types is currently being processed.
  ///
  /// If you wait for an action TYPE, then it returns false when:
  /// - The ASYNC action of the type is NOT currently being processed.
  /// - If the type is not really a type that extends [ReduxAction].
  /// - The action of the type is a SYNC action (since those finish immediately).
  ///
  /// If you wait for an ACTION, then it returns false when:
  /// - The ASYNC action is NOT currently being processed.
  /// - If the action is a SYNC action (since those finish immediately).
  ///
  /// Trying to wait for any other type of object will return null and throw
  /// a [StoreException] after the async gap.
  ///
  /// Examples:
  ///
  /// ```dart
  /// // Waiting for an action TYPE:
  /// dispatch(MyAction());
  /// if (store.isWaiting(MyAction)) { // Show a spinner }
  ///
  /// // Waiting for an ACTION:
  /// var action = MyAction();
  /// dispatch(action);
  /// if (store.isWaiting(action)) { // Show a spinner }
  ///
  /// // Waiting for any of the given action TYPES:
  /// dispatch(BuyAction());
  /// if (store.isWaiting([BuyAction, SellAction])) { // Show a spinner }
  /// ```
  bool isWaiting(Object actionOrActionTypeOrList) {
    //
    // 1) If a type was passed:
    if (actionOrActionTypeOrList is Type) {
      _awaitableActions.add(actionOrActionTypeOrList);
      return _actionsInProgress.any((action) => action.runtimeType == actionOrActionTypeOrList);
    }
    //
    // 2) If an action was passed:
    else if (actionOrActionTypeOrList is ReduxAction) {
      _awaitableActions.add(actionOrActionTypeOrList.runtimeType);
      return _actionsInProgress.contains(actionOrActionTypeOrList);
    }
    //
    // 3) If an iterable was passed:
    // 3.1) For each action or action type in the iterable...
    else if (actionOrActionTypeOrList is Iterable) {
      for (var actionOrType in actionOrActionTypeOrList) {
        //
        // 3.2) If it's a type.
        if (actionOrType is Type) {
          _awaitableActions.add(actionOrType);

          // 3.2.1) Return true if any of the actions in progress has that exact type.
          return _actionsInProgress.any((action) => action.runtimeType == actionOrType);
        }
        //
        // 3.3) If it's an action.
        else if (actionOrType is ReduxAction) {
          _awaitableActions.add(actionOrType.runtimeType);

          // 3.3.1) Return true if any of the actions in progress is the exact action.
          return _actionsInProgress.contains(actionOrType);
        }
        //
        // 3.4) If it's not an action and not an action type, throw an exception.
        // The exception is thrown after the async gap, so that it doesn't interrupt the processes.
        else {
          Future.microtask(() {
            throw StoreException(
                "You can't do isWaiting([${actionOrActionTypeOrList.runtimeType}]), "
                "but only an action Type, a ReduxAction, or a List of them.");
          });
        }
      }

      // 3.5) If the `for` finished without matching any items, return false (it's NOT waiting).
      return false;
    }
    // 4) If something different was passed, it's an error. We show the error after the
    // async gap, so we don't interrupt the code. But we return false (not waiting).
    else {
      Future.microtask(() {
        throw StoreException("You can't do isWaiting(${actionOrActionTypeOrList.runtimeType}), "
            "but only an action Type, a ReduxAction, or a List of them.");
      });

      return false;
    }
  }

  /// Returns true if an [actionOrActionTypeOrList] failed with an [UserException].
  /// Note: This method uses the EXACT type in [actionOrActionTypeOrList]. Subtypes are not considered.
  bool isFailed(Object actionOrActionTypeOrList) => exceptionFor(actionOrActionTypeOrList) != null;

  /// Returns the [UserException] of the [actionTypeOrList] that failed.
  ///
  /// [actionTypeOrList] can be a [Type], or an Iterable of types. Any other type
  /// of object will return null and throw a [StoreException] after the async gap.
  ///
  /// Note: This method uses the EXACT type in [actionTypeOrList]. Subtypes are not considered.
  UserException? exceptionFor(Object actionTypeOrList) {
    //
    // 1) If a type was passed:
    if (actionTypeOrList is Type) {
      _actionsWeCanCheckFailed.add(actionTypeOrList);
      var action = _failedActions[actionTypeOrList];
      var error = action?.status.wrappedError;
      return (error is UserException) ? error : null;
    }
    //
    // 2) If a list was passed:
    else if (actionTypeOrList is Iterable) {
      for (var actionType in actionTypeOrList) {
        _actionsWeCanCheckFailed.add(actionType);
        if (actionType is Type) {
          var error = _failedActions.entries
              .firstWhereOrNull((entry) => entry.key == actionType)
              ?.value
              .status
              .wrappedError;
          return (error is UserException) ? error : null;
        } else {
          Future.microtask(() {
            throw StoreException("You can't do exceptionFor([${actionTypeOrList.runtimeType}]), "
                "but only an action Type, or a List of types.");
          });
        }
      }
      return null;
    }
    // 3) If something different was passed, it's an error. We show the error after the
    // async gap, so we don't interrupt the code. But we return null.
    else {
      Future.microtask(() {
        throw StoreException("You can't do exceptionFor(${actionTypeOrList.runtimeType}), "
            "but only an action Type, or a List of types.");
      });

      return null;
    }
  }

  /// Removes the given [actionTypeOrList] from the list of action types that failed.
  ///
  /// Note that dispatching an action already removes that action type from the exceptions list.
  /// This removal happens as soon as the action is dispatched, not when it finishes.
  ///
  /// [actionTypeOrList] can be a [Type], or an Iterable of types. Any other type
  /// of object will return null and throw a [StoreException] after the async gap.
  ///
  /// Note: This method uses the EXACT type in [actionTypeOrList]. Subtypes are not considered.
  void clearExceptionFor(Object actionTypeOrList) {
    //
    // 1) If a type was passed:
    if (actionTypeOrList is Type) {
      var result = _failedActions.remove(actionTypeOrList);
      if (result != null) _changeController.add(state);
    }
    //
    // 2) If a list was passed:
    else if (actionTypeOrList is Iterable) {
      Object? result;
      for (var actionType in actionTypeOrList) {
        if (actionType is Type) {
          result = _failedActions.remove(actionType);
        } else {
          Future.microtask(() {
            throw StoreException("You can't clearExceptionFor([${actionTypeOrList.runtimeType}]), "
                "but only an action Type, or a List of types.");
          });
        }
      }
      if (result != null) _changeController.add(state);
    }
    // 3) If something different was passed, it's an error. We show the error after the
    // async gap, so we don't interrupt the code. But we return null.
    else {
      Future.microtask(() {
        throw StoreException("You can't clearExceptionFor(${actionTypeOrList.runtimeType}), "
            "but only an action Type, or a List of types.");
      });
    }
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
      _finalize(action, originalError, processedError, afterWasRun, notify);
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
      _finalize(action, originalError, processedError, afterWasRun, notify);
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

    Reducer<St> _reduce = action.wrapReduce(action.reduce);

    // Make sure the wrapReduce also returns an acceptable type.
    _checkReducerType(action.reduce, true);

    if (_wrapReduce != null) _reduce = _wrapReduce.wrapReduce(_reduce, this);

    // Sync reducer.
    if (_reduce is St? Function()) {
      _registerState(_reduce(), action, notify: notify);
    }
    //
    // Async reducer.
    else if (_reduce is Future<St?> Function()) {
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

      return _reduce().then((state) {
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
          "Reduce is of type: '${_reduce.runtimeType}'.");
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
    if (((state != null) && !identical(_state, state)) || _actionsInProgress.contains(action)) {
      _state = state ?? _state;
      _stateTimestamp = DateTime.now().toUtc();

      if (notify) {
        _changeController.add(state ?? _state);
      }

      _checkAllStateConditions(action);
    }
    St newState = _state;

    if (_stateObservers != null)
      for (StateObserver observer in _stateObservers) {
        observer.observe(action, prevState, newState, null, dispatchCount);
      }

    if (_processPersistence != null) _processPersistence.process(action, newState);
    if (_processCloudSync != null) _processCloudSync.process(action, newState);
  }

  /// The actions that are currently being processed.
  /// Use [isWaiting] to know if an action is currently being processed.
  final Set<ReduxAction<St>> _actionsInProgress = HashSet<ReduxAction<St>>.identity();

  /// Returns an unmodifiable set of the actions on progress.
  Set<ReduxAction<St>> actionsInProgress() {
    return new UnmodifiableSetView(this._actionsInProgress);
  }

  /// Actions that we may put into [_actionsInProgress].
  /// This helps to know when to rebuild to make [isWaiting] work.
  final Set<Type> _awaitableActions = HashSet<Type>.identity();

  /// The async actions that have failed recently.
  /// When an action fails by throwing an UserException, it's added to this map (indexed by its
  /// action type), and removed when it's dispatched.
  /// Use [isFailed], [exceptionFor] and [clearExceptionFor] to know if you should display
  /// some error message due to an action failure.
  ///
  /// Note: Throwing an UserException can show a modal dialog to the user, and also show the error
  /// as a message in the UI. If you don't want to show the dialog you can use the `noDialog`
  /// getter in the error message: `throw UserException('Invalid input').noDialog`.
  ///
  final Map<Type, ReduxAction<St>> _failedActions = HashMap<Type, ReduxAction<St>>();

  /// Async actions that we may put into [_failedActions].
  /// This helps to know when to rebuild to make [isWaiting] work.
  final Set<Type> _actionsWeCanCheckFailed = HashSet<Type>.identity();

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
            "Method 'WrapError.wrap()' has thrown an error:\n '$_error'.", errorOrNull, stackTrace);
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

    // Memorizes the action that failed. We'll remove it when it's dispatched again.
    _failedActions[action.runtimeType] = action;

    afterWasRun.value = true;
    _after(action);

    // Memorizes errors of type UserException (in the error queue).
    // These errors are usually shown to the user in a modal dialog, and are not logged.
    if (errorOrNull is UserException) {
      if (errorOrNull.ifOpenDialog) {
        _addError(errorOrNull);
        _changeController.add(state);
      }
    } else if (errorOrNull is AbortDispatchException) {
      action._status = action._status.copy(isDispatchAborted: true);
    }

    // If an errorObserver was NOT defined, return (to throw) all errors which are
    // not UserException or AbortDispatchException.
    if (_errorObserver == null) {
      if ((errorOrNull is! UserException) && (errorOrNull is! AbortDispatchException))
        return errorOrNull;
    }
    // If an errorObserver was defined, observe the error.
    // Then, if the observer returns true, return the error to be thrown.
    else if (errorOrNull != null) {
      try {
        if (_errorObserver.observe(errorOrNull, stackTrace, action, this)) //
          return errorOrNull;
      } catch (_error) {
        // The errorObserver should never throw. However, if it does, print the error.
        _throws(
            "Method 'ErrorObserver.observe()' has thrown an error '$_error' "
            "when observing error '$errorOrNull'.",
            _error,
            stackTrace);

        return errorOrNull;
      }
    }

    return null;
  }

  void _finalize(
    ReduxAction<St> action,
    Object? error,
    Object? processedError,
    _Flag<bool> afterWasRun,
    bool notify,
  ) {
    if (!afterWasRun.value) _after(action);

    bool ifWasRemoved = _actionsInProgress.remove(action);
    if (ifWasRemoved) _checkAllActionConditions(action);

    // If we'll not be notifying, it's possible we need to trigger the change controller, when the
    // action is awaitable (that is to say, when we have already called `isWaiting` for this action).
    if (_awaitableActions.contains(action.runtimeType) && ((error != null) || !notify)) {
      _changeController.add(state);
    }

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

  /// Helps testing the `StoreConnector`s methods, such as `onInit`,
  /// `onDispose` and `onWillChange`.
  ///
  /// For example, suppose you have a `StoreConnector` which dispatches
  /// `SomeAction` on its `onInit`. How could you test that?
  ///
  /// ```
  /// class MyConnector extends StatelessWidget {
  ///   Widget build(BuildContext context) => StoreConnector<AppState, Vm>(
  ///         vm: () => _Factory(),
  ///         onInit: _onInit,
  ///         builder: (context, vm) { ... }
  ///   }
  ///
  ///   void _onInit(Store<AppState> store) => store.dispatch(SomeAction());
  /// }
  ///
  /// var store = Store(...);
  /// var connectorTester = store.getConnectorTester(MyConnector());
  /// connectorTester.runOnInit();
  /// var action = await store.waitAnyActionTypeFinishes([SomeAction]);
  /// expect(action.someValue, 123);
  /// ```
  ///
  ConnectorTester<St, Model> getConnectorTester<Model>(StatelessWidget widgetConnector) =>
      ConnectorTester<St, Model>(this, widgetConnector);

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
    this.isDispatchAborted = false,
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

  /// Is true if the action was:
  /// - Aborted with the [ReduxAction.abortDispatch] method,
  /// - If an [AbortDispatchException] was thrown by the action's `before` or `reduce` methods
  ///   (and survived the `wrapError` and `globalWrapError`). Or,
  /// - If the store was being shut down with the [Store.shutdown] method.
  final bool isDispatchAborted;

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
    bool? isDispatchAborted,
    Object? originalError,
    Object? wrappedError,
  }) =>
      ActionStatus(
        isDispatched: isDispatched ?? this.isDispatched,
        hasFinishedMethodBefore: hasFinishedMethodBefore ?? this.hasFinishedMethodBefore,
        hasFinishedMethodReduce: hasFinishedMethodReduce ?? this.hasFinishedMethodReduce,
        hasFinishedMethodAfter: hasFinishedMethodAfter ?? this.hasFinishedMethodAfter,
        isDispatchAborted: isDispatchAborted ?? this.isDispatchAborted,
        originalError: originalError ?? this.originalError,
        wrappedError: wrappedError ?? this.wrappedError,
      );

  @override
  String toString() => 'ActionStatus{'
      'isDispatched: $isDispatched, '
      'hasFinishedMethodBefore: $hasFinishedMethodBefore, '
      'hasFinishedMethodReduce: $hasFinishedMethodReduce, '
      'hasFinishedMethodAfter: $hasFinishedMethodAfter, '
      'isDispatchAborted: $isDispatchAborted, '
      'originalError: $originalError, '
      'wrappedError: $wrappedError'
      '}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActionStatus &&
          runtimeType == other.runtimeType &&
          isDispatched == other.isDispatched &&
          hasFinishedMethodBefore == other.hasFinishedMethodBefore &&
          hasFinishedMethodReduce == other.hasFinishedMethodReduce &&
          hasFinishedMethodAfter == other.hasFinishedMethodAfter &&
          isDispatchAborted == other.isDispatchAborted &&
          originalError == other.originalError &&
          wrappedError == other.wrappedError;

  @override
  int get hashCode =>
      isDispatched.hashCode ^
      hasFinishedMethodBefore.hashCode ^
      hasFinishedMethodReduce.hashCode ^
      hasFinishedMethodAfter.hashCode ^
      isDispatchAborted.hashCode ^
      originalError.hashCode ^
      wrappedError.hashCode;
}

class _Flag<T> {
  T value;

  _Flag(this.value);

  @override
  bool operator ==(Object other) => true;

  @override
  int get hashCode => 0;
}
