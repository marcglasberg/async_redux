// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// Based upon packages redux by Brian Egan, and flutter_redux by Brian Egan and John Ryan.
// Uses code from package equatable by Felix Angelov.
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

library async_redux_store;

import 'dart:async';
import 'dart:collection';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:async_redux/async_redux.dart';
import 'package:async_redux/src/process_persistence.dart';
import 'package:collection/collection.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:meta/meta.dart';

part 'action_mixins.dart';
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
/// • StateObservers receive the action, prevState (state right before the new State is
///   applied), newState (state that was applied), and are used to track metrics and more.
///
/// • GlobalErrorObserver may be used to observe, modify, and swallow action errors
///   globally, as well as log them to monitoring services like Sentry and Firebase
///   Crashlytics.
///
/// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux
///
class Store<St> {
  Store({
    required St initialState,
    this._environment,
    Object? Function(Store<St>)? dependencies,
    Object? Function(Store<St>)? configuration,
    Map<Object?, Object?> props = const {},
    bool syncStream = false,
    List<ActionObserver<St>>? this._actionObservers,
    List<StateObserver<St>>? this._stateObservers,
    Persistor<St>? persistor,
    Persistor<St>? cloudSync,
    this._wrapReduce,
    this._globalErrorObserver,
    int? maxErrorsQueued,
  })  : _state = initialState,
        _props = HashMap()..addAll(props),
        _stateTimestamp = DateTime.now().toUtc(),
        _changeController = StreamController.broadcast(sync: syncStream),
        _processPersistence = (persistor == null)
            ? null //
            : ProcessPersistence(persistor, initialState),
        _processCloudSync = (cloudSync == null)
            ? null //
            : ProcessPersistence(cloudSync, initialState),
        _errors = Queue<UserException>(),
        _maxErrorsQueued = maxErrorsQueued ?? 10,
        _dispatchCount = 0,
        _reduceCount = 0,
        _shutdown = false {
    _processPersistence?.onError = _processPersistorError;
    _processCloudSync?.onError = _processPersistorError;

    // Init the config first, so that it can be used by the dependencies.
    _configuration = configuration?.call(this);

    // Dependencies can use `store` and `store.configuration`, if necessary.
    _dependencies = dependencies?.call(this);

    // Process the errors the persistor added (usually when reading the state, before the
    // store was created). This must come last, since the GlobalErrorObserver may use the
    // store's configuration and dependencies.
    _processPersistence?.processAddedErrors();
    _processCloudSync?.processAddedErrors();
  }

  St _state;

  final Object? _environment;
  Object? _configuration;
  Object? _dependencies;

  final Map<Object?, Object?> _props;

  /// Gets the store environment.
  /// This can be used to specify if the app is running in production, staging,
  /// development, test, etc, and to save other global values that are not expected to
  /// change during the app execution.
  ///
  /// If you use this, it's recommended that you make this directly accessible in your
  /// base action that extends [ReduxAction].
  ///
  /// Note the environment is accessible in widgets through
  /// [BuildContextExtensionForProvider.getEnvironment], so that your widgets
  /// can respond to different environments, if necessary.
  ///
  /// See also:
  /// - [prop] and [setProp], for saving global values that may change during app execution.
  /// - [dependencies], for injecting dependencies (like services, repositories, etc).
  /// - [configuration], for setting configuration (like feature flags, etc).
  ///
  Object? get environment => _environment;

  /// Gets the store dependencies.
  /// This can be used to create a global value, but scoped to the store, serving
  /// in practice as dependency injection.
  ///
  /// If you use this, it's recommended that you make this directly accessible in your
  /// base action that extends [ReduxAction].
  ///
  /// Usually, this should not be accessible in widgets, as they should not be aware of
  /// the dependencies.
  ///
  /// See also:
  /// - [prop] and [setProp], for saving global values that may change during app execution.
  /// - [env], for specifying if the app is running in production, staging, development, etc.
  /// - [configuration], for setting configuration (like feature flags, etc).
  ///
  Object? get dependencies => _dependencies;

  /// Gets the store configuration.
  /// This can be used to create a global value, but scoped to the store, serving
  /// in practice as configuration injection. For example, you could save feature flags
  /// in the configuration.
  ///
  /// If you use this, it's recommended that you make this directly accessible in your
  /// base action that extends [ReduxAction].
  ///
  /// See also:
  /// - [prop] and [setProp], for saving global values that may change during app execution.
  /// - [dependencies], for injecting dependencies (like services, repositories, etc).
  /// - [env], for specifying if the app is running in production, staging, development, etc.
  ///
  Object? get configuration => _configuration;

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
  /// This is also directly accessible in [ReduxAction], as `prop`.
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
  /// This is also directly accessible in [ReduxAction], as `prop`.
  ///
  /// See also: [prop] and [env].
  void setProp(Object? key, Object? value) => _props[key] = value;

  /// The [disposeProps] method is used to clean up resources associated with
  /// the store's properties, by stopping, closing, ignoring and removing timers,
  /// streams, sinks, and futures that are saved as properties in the store.
  ///
  /// In more detail: This method accepts an optional predicate function that
  /// takes a prop `key` and a `value` as an argument and returns a boolean.
  ///
  /// * If you don't provide a predicate function, all properties which are
  /// `Timer`, `Future`, or `Stream` related will be closed/cancelled/ignored as
  /// appropriate, and then removed from the props. Other properties will not be
  /// removed.
  ///
  /// * If the predicate function is provided and returns `true` for a given
  /// property, that property will be removed from the props and, if the property
  /// is also a `Timer`, `Future`, or `Stream` related, it will be
  /// closed/cancelled/ignored as appropriate.
  ///
  /// * If the predicate function is provided and returns `false` for a given
  /// property, that property will not be removed from the props, and it will
  /// not be closed/cancelled/ignored.
  ///
  /// This method is particularly useful when the store is being shut down,
  /// right before or after you called the [shutdown] method.
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
  /// Note: The provided mixins, like [Polling], [Throttle], [Debounce] etc, also use
  /// some props that you can dispose by doing `store.internalMixinProps.clear()`;
  ///
  /// See also: [disposeProp], to dispose a single property by its key.
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

  /// Uses [disposeProps] to dispose and a single property identified by
  /// its key [keyToDispose], and remove it from the props.
  ///
  /// This method will close/cancel/ignore the property if it's a Timer,
  /// Future, or Stream related object, and then remove it from the props.
  ///
  /// Example usage:
  ///
  /// ```dart
  /// // Dispose a specific timer property
  /// store.disposeProp("myTimer");
  /// ```
  void disposeProp(Object? keyToDispose) {
    disposeProps(({Object? key, Object? value}) => key == keyToDispose);
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

  int get dispatchCount => _dispatchCount;

  int get reduceCount => _reduceCount;

  final StreamController<St> _changeController;

  final List<ActionObserver>? _actionObservers;

  final List<StateObserver>? _stateObservers;

  final ProcessPersistence<St>? _processPersistence;

  final ProcessPersistence<St>? _processCloudSync;

  final GlobalErrorObserver<St> Function(Store<St>)? _globalErrorObserver;

  final WrapReduce<St>? _wrapReduce;

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
  /// When [persistAndPausePersistor] is called, if no persistence process is running, it
  /// will immediately start a new persistence process (ignoring [Persistor.throttle]).
  /// If one is currently running, it will not be affected, and the state at the time of
  /// the call will be persisted as soon as it finishes (if it's not yet persisted).
  ///
  /// Then, the Persistor will not start another persistence process, until method
  /// [resumePersistor] is called. State changes made after the call are only persisted
  /// when it's resumed.
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
  /// When [persistAndPauseCloudSync] is called, if no cloud save process is running, it
  /// will immediately start a new save process (ignoring [CloudSync.throttle]).
  /// If one is currently running, it will not be affected, and the state at the time of
  /// the call will be saved as soon as it finishes (if it's not yet saved).
  ///
  /// Then, the CloudSync will not start another cloud save process, until method
  /// [resumeCloudSync] is called. State changes made after the call are only saved
  /// when it's resumed.
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
  /// If a save is running, it waits for it to finish first, so that it can't overwrite
  /// the [initialState] later.
  Future<void> saveInitialStateInPersistence(St initialState) async =>
      _processPersistence?.saveInitialState(initialState);

  /// Asks the [CloudSync] to save the [initialState] in the cloud.
  /// If a save is running, it waits for it to finish first, so that it can't overwrite
  /// the [initialState] later.
  Future<void> saveInitialStateInCloud(St initialState) async =>
      _processCloudSync?.saveInitialState(initialState);

  /// Asks the [Persistor] to read the state from the local persistence.
  /// Important: If you use this, you MUST put this state into the store.
  /// The Persistor will assume that's the case, and will not work properly otherwise.
  ///
  /// If a save is running, it waits for it to finish first, so that it reads the saved
  /// state. State changes made while the state is being read are saved after it's read.
  Future<St?> readStateFromPersistence() async => _processPersistence?.readState();

  /// Asks the [CloudSync] to read the state from the cloud.
  /// Important: If you use this, you MUST put this state into the store.
  /// The CloudSync will assume that's the case, and will not work properly otherwise.
  ///
  /// If a save is running, it waits for it to finish first, so that it reads the saved
  /// state. State changes made while the state is being read are saved after it's read.
  Future<St?> readStateFromCloudSync() async => _processCloudSync?.readState();

  /// Asks the [Persistor] to delete the saved state from the local persistence.
  /// If a save is running, it waits for it to finish first, so that it can't put the
  /// deleted state back. State changes made while the state is being deleted are saved
  /// after it's deleted.
  Future<void> deleteStateFromPersistence() async => _processPersistence?.deleteState();

  /// Asks the [CloudSync] to delete the saved state from the cloud.
  /// If a save is running, it waits for it to finish first, so that it can't put the
  /// deleted state back. State changes made while the state is being deleted are saved
  /// after it's deleted.
  Future<void> deleteStateFromCloud() async => _processCloudSync?.deleteState();

  /// Gets, from the [Persistor], the last state that was saved to the local persistence.
  St? getLastPersistedStateFromPersistor() => _processPersistence?.lastPersistedState;

  /// Gets, from the [CloudSync], the last state that was saved to the cloud.
  St? getLastPersistedStateFromCloudSync() => _processCloudSync?.lastPersistedState;

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
  /// Calls with the same predicate register independent waits, each with its own
  /// completion and timeout.
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
  /// // Dispatches an action and waits until no action of its type is in progress.
  /// dispatch(ChangeNameAction("Bill"));
  /// var action = await store.waitActionType(ChangeNameAction);
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

      _stateConditionCompleters[completer] = condition;

      int timeout = timeoutMillis ?? defaultTimeoutMillis;
      var future = completer.future;

      if (timeout >= 0)
        future = completer.future.timeout(
          Duration(milliseconds: timeout),
          onTimeout: () {
            _stateConditionCompleters.remove(completer);
            throw TimeoutException(null, Duration(milliseconds: timeout));
          },
        );

      return future;
    }
  }

  // Each completer identifies one wait, even when callers reuse the same predicate.
  // Completion or timeout removes only that registration.
  final _actionConditionCompleters =
      <Completer<(Set<ReduxAction<St>>, ReduxAction<St>?)>,
          bool Function(Set<ReduxAction<St>>, ReduxAction<St>?)>{};

  final _stateConditionCompleters =
      <Completer<ReduxAction<St>?>, bool Function(St)>{};

  /// Returns a future that completes when some actions meet the given [condition].
  ///
  /// Calls with the same predicate register independent waits, each with its own
  /// completion and timeout.
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
  /// // Dispatches an action and waits until no action of its type is in progress.
  /// dispatch(ChangeNameAction("Bill"));
  /// var action = await store.waitActionType(ChangeNameAction);
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
    bool Function(Set<ReduxAction<St>> actions, ReduxAction<St>? triggerAction)
        condition, {
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
        throw StoreException(
            completedErrorMessage + ", and the future completed immediately.");
    }
    //
    else {
      var completer = Completer<(Set<ReduxAction<St>>, ReduxAction<St>?)>();

      _actionConditionCompleters[completer] = condition;

      int timeout = timeoutMillis ?? defaultTimeoutMillis;
      var future = completer.future;

      if (timeout >= 0)
        future = completer.future.timeout(
          Duration(milliseconds: timeout),
          onTimeout: () {
            _actionConditionCompleters.remove(completer);
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
  /// // Dispatches an action and waits until no action of its type is in progress.
  /// dispatch(ChangeNameAction("Bill"));
  /// var action = await store.waitActionType(ChangeNameAction);
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
      return waitActionCondition(
          completeImmediately: completeImmediately,
          completedErrorMessage: "No actions were in progress",
          timeoutMillis: timeoutMillis,
          (actions, triggerAction) => actions.isEmpty);
    } else {
      return waitActionCondition(
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
  /// // Dispatches an action and waits until no action of its type is in progress.
  /// dispatch(ChangeNameAction("Bill"));
  /// var action = await store.waitActionType(ChangeNameAction);
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
  /// You should only use this method in tests. However, there is an equivalent
  /// [ReduxAction.waitActionType] method that can be used in production code,
  /// inside action reducers.
  ///
  @visibleForTesting
  Future<ReduxAction<St>?> waitActionType(
    Type actionType, {
    bool completeImmediately = false,
    int? timeoutMillis,
  }) async {
    var (_, triggerAction) = await waitActionCondition(
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
  /// // Dispatches an action and waits until no action of its type is in progress.
  /// dispatch(ChangeNameAction("Bill"));
  /// var action = await store.waitActionType(ChangeNameAction);
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
  /// You should only use this method in tests. However, there is an equivalent
  /// [ReduxAction.waitAllActionTypes] method that can be used in production code,
  /// inside action reducers.
  ///
  @visibleForTesting
  Future<void> waitAllActionTypes(
    List<Type> actionTypes, {
    bool completeImmediately = false,
    int? timeoutMillis,
  }) async {
    if (actionTypes.isEmpty) {
      await waitActionCondition(
        completeImmediately: completeImmediately,
        completedErrorMessage: "No actions are in progress",
        timeoutMillis: timeoutMillis,
        (actions, triggerAction) => actions.isEmpty,
      );
    } else {
      await waitActionCondition(
        completeImmediately: completeImmediately,
        completedErrorMessage: "No action of the given types was in progress",
        timeoutMillis: timeoutMillis,
        //
        (actionsInProgress, triggerAction) {
          for (var actionType in actionTypes) {
            if (actionsInProgress.any((action) => action.runtimeType == actionType))
              return false;
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
  /// // Dispatches an action and waits until no action of its type is in progress.
  /// dispatch(ChangeNameAction("Bill"));
  /// var action = await store.waitActionType(ChangeNameAction);
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
    var (_, triggerAction) = await waitActionCondition(
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
    _errors.addLast(error);
    // Trim after insertion so the limit also works when no errors may be queued.
    if (_errors.length > _maxErrorsQueued) _errors.removeFirst();
  }

  /// Gets the first error from the error queue, and removes it from the queue.
  UserException? getAndRemoveFirstError() => //
      (_errors.isEmpty) //
          ? null
          : _errors.removeFirst();

  /// Remove an error from the error queue, if it's in the queue.
  /// Pass it a [source]:
  /// - A [UserException] object, to remove that error from the queue.
  /// - An [ActionStatus] object, to remove the error that caused the action to fail.
  /// - An action ([ReduxAction]), to remove the error that caused the action to fail.
  ///
  /// Do nothing if:
  /// - The error that caused the action to fail is not in the queue.
  /// - The action did not fail.
  /// - The status has no [ActionStatus.wrappedError].
  /// - The [source] is not a [UserException], [ActionStatus], or [ReduxAction].
  ///
  /// This is sometimes useful in tests. For example:
  ///
  /// ```dart
  /// // Dispatch some action
  /// var status = await store.dispatchAndWait(SomeAction());
  ///
  /// // Check the action failed as expected
  /// expect(status.originalError, isError<CloudException>('Insufficient balance.'));
  ///
  /// // Make sure there are no more errors
  /// store.removeError(status);
  /// expect(store.errors, isEmpty);
  /// ```
  ///
  /// You can also use the action to remove the error:
  ///
  /// ```dart
  /// // Dispatch some action
  /// var action = SomeAction();
  /// var status = await store.dispatchAndWait(action);
  /// store.removeError(action);
  /// ```
  ///
  void removeError(Object source) {
    Object error;
    if (source is UserException)
      error = source;
    else if (source is ActionStatus && source.wrappedError != null)
      error = source.wrappedError!;
    else if (source is ReduxAction && source.status.wrappedError != null)
      error = source.status.wrappedError!;
    else
      return;

    _errors.removeWhere((queuedError) => queuedError == error);
  }

  /// Call this method to shut down the store.
  /// It won't accept dispatches or change the state anymore.
  ///
  /// See also: [isShutdown] and [disposeProps].
  void shutdown() {
    _shutdown = true;
    internalMixinProps.clear();
  }

  /// Properties used internally by the provided mixins.
  /// You should not use this directly.
  @internal
  late final internalMixinProps = _InternalMixinProps(onClear: clearAllExceptions);

  /// If you are running tests, you can change [forceInternetOnOffSimulation] to
  /// simulate the internet connection as ON or OFF for the provided mixins
  /// [CheckInternet], [AbortWhenNoInternet], and [UnlimitedRetryCheckInternet].
  ///
  /// - Return `true` if there IS internet.
  /// - Return `false` if there is NO internet.
  /// - Return `null` to use the real internet connection status (default).
  ///
  /// Example:
  ///
  /// ```dart
  /// store.forceInternetOnOffSimulation = () => false;
  /// ```
  ///
  /// This is specially useful during tests, for testing what happens when you
  /// have no internet connection. And since it's tied to the store, it
  /// automatically resets when the store is recreated.
  ///
  bool? Function() forceInternetOnOffSimulation = () => null;

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
  /// - [dispatchAndWaitAll] which dispatches all given actions, and returns a Future.
  /// - [dispatchAll] which dispatches all given actions in parallel.
  /// - [dispatchAndWaitAllActions] which dispatches an action then waits for all actions to finish.
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
  /// - [dispatchAndWaitAllActions] which dispatches an action then waits for all actions to finish.
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
  /// - [dispatchAndWaitAllActions] which dispatches an action then waits for all actions to finish.
  ///
  Future<ActionStatus> dispatchAndWait(ReduxAction<St> action, {bool notify = true}) =>
      Future.value(_dispatch(action, notify: notify));

  /// The [dispatchAndWaitAllActions] should be used in tests only.
  ///
  /// It first dispatches the given [action], applying its reducer, and
  /// possibly changing the store state. The action may be sync or async.
  /// In both cases, it returns a [Future] that resolves when the action
  /// finishes.
  ///
  /// Then, it waits until ALL current actions in progress finish dispatching.
  /// In other words, when no other actions are currently in progress.
  ///
  /// This dispatch method is meant to be used in tests, not in production,
  /// as it's very easy to create a deadlock. However, if you do use it in
  /// production, you may provide a [timeoutMillis], which by default is 10
  /// minutes. To disable the timeout, make it -1. This timeout only starts
  /// counting after the given [action] finished dispatching. Note: If you want,
  /// you can modify [defaultTimeoutMillis] to change the default timeout.
  ///
  /// ```dart
  /// await store.dispatchAndWaitAllActions(MyAction());
  /// ```
  ///
  Future<ActionStatus> dispatchAndWaitAllActions(ReduxAction<St> action,
      {bool notify = true, int? timeoutMillis}) async {
    var actionStatus = await dispatchAndWait(action, notify: notify);
    await waitAllActions([], completeImmediately: true, timeoutMillis: timeoutMillis);
    return actionStatus;
  }

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
  /// If some sync actions throw, all actions are still dispatched, and only then the error
  /// of the first one that threw is rethrown.
  ///
  /// See also:
  /// - [dispatch] which dispatches both sync and async actions.
  /// - [dispatchAndWait] which dispatches both sync and async actions, and returns a Future.
  /// - [dispatchAndWaitAll] which dispatches all given actions, and returns a Future.
  /// - [dispatchSync] which dispatches sync actions, and throws if the action is async.
  /// - [dispatchAndWaitAllActions] which dispatches an action then waits for all actions to finish.
  ///
  List<ReduxAction<St>> dispatchAll(List<ReduxAction<St>> actions, {bool notify = true}) {
    // A sync action may throw synchronously. Keep the first error, so that all actions are
    // still dispatched before it is rethrown.
    Object? firstError;
    StackTrace? firstStackTrace;

    for (var action in actions) {
      try {
        dispatch(action, notify: notify);
      } catch (error, stackTrace) {
        if (firstError == null) {
          firstError = error;
          firstStackTrace = stackTrace;
        }
      }
    }

    if (firstError != null) Error.throwWithStackTrace(firstError, firstStackTrace!);

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
  /// If some actions fail, all actions are still dispatched and waited for, and only then
  /// the Future completes with the error of one of the failed actions.
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
  /// - [dispatchAndWaitAllActions] which dispatches an action then waits for all actions to finish.
  ///
  Future<List<ReduxAction<St>>> dispatchAndWaitAll(
    List<ReduxAction<St>> actions, {
    bool notify = true,
  }) async {
    var futures = <Future<ActionStatus>>[];

    for (var action in actions) {
      // A sync action may throw synchronously. Turn it into a failed future, so that
      // all actions are still dispatched and waited for, before the error is rethrown.
      Future<ActionStatus> future;
      try {
        future = dispatchAndWait(action, notify: notify);
      } catch (error, stackTrace) {
        future = Future.error(error, stackTrace);
      }
      futures.add(future);
    }
    await Future.wait(futures);

    return actions;
  }

  /// Returns a copy of the error queue, containing user exception errors thrown by
  /// dispatched actions. Note that this is a copy of the queue, so you can't modify the original
  /// queue here. Instead, use [getAndRemoveFirstError] to consume the errors, one by one.
  Queue<UserException> get errors => Queue<UserException>.of(_errors);

  /// Checks for pending dialogs without copying or consuming the error queue.
  @internal
  bool get internalHasErrors => _errors.isNotEmpty;

  /// The [triggerAction] is the action that was just added or removed in the list
  /// of [_actionsInProgress] that triggered the check.
  ///
  void _checkAllActionConditions(ReduxAction<St> triggerAction) {
    List<Completer<(Set<ReduxAction<St>>, ReduxAction<St>?)>> keysToRemove = [];

    _actionConditionCompleters.forEach((completer, condition) {
      if (condition(actionsInProgress(), triggerAction)) {
        completer.complete((actionsInProgress(), triggerAction));
        keysToRemove.add(completer);
      }
    });

    keysToRemove.forEach((key) {
      _actionConditionCompleters.remove(key);
    });
  }

  /// The [triggerAction] is the action that modified the state to trigger the condition.
  void _checkAllStateConditions(ReduxAction<St> triggerAction) {
    List<Completer<ReduxAction<St>?>> keysToRemove = [];

    _stateConditionCompleters.forEach((completer, condition) {
      if (condition(_state)) {
        completer.complete(triggerAction);
        keysToRemove.add(completer);
      }
    });

    keysToRemove.forEach((key) {
      _stateConditionCompleters.remove(key);
    });
  }

  /// You can use [isWaiting] and pass it [actionOrTypeOrList] to check if:
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
  ///
  /// Pass [statusKey] to consider only the actions of the type with that
  /// [ReduxAction.statusKey]: `isWaiting(LoadUser, statusKey: userId)`. Without it, all
  /// actions of the type are considered, whatever their keys. The [statusKey] is not used
  /// when you pass an ACTION, since then that exact action is checked.
  bool isWaiting(Object actionOrTypeOrList, {Object? statusKey}) {
    //
    // 1) If a type was passed:
    if (actionOrTypeOrList is Type) {
      _awaitableActions.add(actionOrTypeOrList);
      return _isWaitingType(actionOrTypeOrList, statusKey);
    }
    //
    // 2) If an action was passed (the statusKey is not used: that action is checked):
    else if (actionOrTypeOrList is ReduxAction) {
      _awaitableActions.add(actionOrTypeOrList.runtimeType);
      return _actionsInProgress.contains(actionOrTypeOrList);
    }
    //
    // 3) If an iterable was passed:
    // 3.1) For each action or action type in the iterable...
    else if (actionOrTypeOrList is Iterable) {
      bool isWaiting = false;
      for (var actionOrType in actionOrTypeOrList) {
        //
        // 3.2) If it's a type.
        if (actionOrType is Type) {
          _awaitableActions.add(actionOrType);

          // 3.2.1) Is waiting if any of the actions in progress has that exact type
          // (and the statusKey, if given).
          if (!isWaiting) isWaiting = _isWaitingType(actionOrType, statusKey);
        }
        //
        // 3.3) If it's an action.
        else if (actionOrType is ReduxAction) {
          _awaitableActions.add(actionOrType.runtimeType);

          // 3.3.1) Is waiting if any of the actions in progress is the exact action.
          if (!isWaiting) isWaiting = _actionsInProgress.contains(actionOrType);
        }
        //
        // 3.4) If it's not an action and not an action type, throw an exception.
        // The exception is thrown after the async gap, so that it doesn't interrupt the processes.
        else {
          Future.microtask(() {
            throw StoreException(
                "You can't do isWaiting([${actionOrTypeOrList.runtimeType}]). "
                "Use only actions, action types, or a list of them.");
          });
        }
      }

      // 3.5) If the `for` finished without matching any items, return false (it's NOT waiting).
      return isWaiting;
    }
    // 4) If something different was passed, it's an error. We show the error after the
    // async gap, so we don't interrupt the code. But we return false (not waiting).
    else {
      Future.microtask(() {
        throw StoreException("You can't do isWaiting(${actionOrTypeOrList.runtimeType}), "
            "Use only actions, action types, or a list of them.");
      });

      return false;
    }
  }

  /// Returns true if some action in progress has the exact [type], and, when [statusKey]
  /// is not null, also that [ReduxAction.statusKey].
  bool _isWaitingType(Type type, Object? statusKey) => _actionsInProgress.any((action) =>
      action.runtimeType == type && (statusKey == null || action.statusKey == statusKey));

  /// Returns true if an action of the given type failed, with any error, not only with a
  /// [UserException]. Use [exceptionFor] to get the error, if it was a [UserException].
  /// An error swallowed by `wrapError` or the `GlobalErrorObserver` (they returned null),
  /// and an [AbortDispatchException], don't count as failures.
  ///
  /// [actionTypeOrList] can be an action [Type], or an Iterable of action types, in
  /// which case it returns true if any of them failed. Note it does NOT accept an
  /// action, only its type. Any other object, including an action, will return false
  /// and throw a [StoreException] after the async gap.
  ///
  /// Note: This method uses the EXACT type in [actionTypeOrList]. Subtypes are not considered.
  ///
  /// Pass [statusKey] to consider only the failures with that [ReduxAction.statusKey]:
  /// `isWaiting(LoadUser, statusKey: userId)`. Without it, all actions of the type are
  /// considered, whatever their keys.
  bool isFailed(Object actionTypeOrList, {Object? statusKey}) {
    //
    // 1) If a type was passed:
    if (actionTypeOrList is Type) {
      _actionsWeCanCheckFailed.add(actionTypeOrList);
      return _hasFailure(actionTypeOrList, statusKey);
    }
    //
    // 2) If a list was passed:
    else if (actionTypeOrList is Iterable) {
      bool result = false;
      for (var actionType in actionTypeOrList) {
        if (actionType is Type) {
          // Doesn't stop at the first failure, because all types must be added here.
          _actionsWeCanCheckFailed.add(actionType);
          if (_hasFailure(actionType, statusKey)) result = true;
        } else {
          Future.microtask(() {
            throw StoreException(
                "You can't do isFailed([${actionTypeOrList.runtimeType}]), "
                "but only an action Type, or a List of types.");
          });
        }
      }
      return result;
    }
    // 3) If something different was passed, it's an error. We show the error after the
    // async gap, so we don't interrupt the code. But we return false.
    else {
      Future.microtask(() {
        throw StoreException(
            "You can't do isFailed(${actionTypeOrList.runtimeType}), "
            "but only an action Type, or a List of types.");
      });

      return false;
    }
  }

  /// Returns the [UserException] of the [actionTypeOrList] that failed. Returns null if
  /// it didn't fail, or if it failed with an error that is not a [UserException] (in
  /// that case, [isFailed] is still true).
  ///
  /// [actionTypeOrList] can be a [Type], or an Iterable of types. Any other type
  /// of object will return null and throw a [StoreException] after the async gap.
  ///
  /// If an Iterable is passed, returns the exception of the first of its types that
  /// failed, or null if none failed.
  ///
  /// Note: This method uses the EXACT type in [actionTypeOrList]. Subtypes are not considered.
  ///
  /// Pass [statusKey] to get the exception of the failure with that
  /// [ReduxAction.statusKey]: `exceptionFor(LoadUser, statusKey: userId)`. Without it, if
  /// actions with different keys failed, you get the [UserException] of the most recent
  /// failure.
  UserException? exceptionFor(Object actionTypeOrList, {Object? statusKey}) {
    //
    // 1) If a type was passed:
    if (actionTypeOrList is Type) {
      _actionsWeCanCheckFailed.add(actionTypeOrList);
      return _userExceptionFor(actionTypeOrList, statusKey);
    }
    //
    // 2) If a list was passed:
    else if (actionTypeOrList is Iterable) {
      UserException? result;
      for (var actionType in actionTypeOrList) {
        if (actionType is Type) {
          // Doesn't stop at the first exception, because all types must be added here.
          _actionsWeCanCheckFailed.add(actionType);
          result ??= _userExceptionFor(actionType, statusKey);
        } else {
          Future.microtask(() {
            throw StoreException(
                "You can't do exceptionFor([${actionTypeOrList.runtimeType}]), "
                "but only an action Type, or a List of types.");
          });
        }
      }
      return result;
    }
    // 3) If something different was passed, it's an error. We show the error after the
    // async gap, so we don't interrupt the code. But we return null.
    else {
      Future.microtask(() {
        throw StoreException(
            "You can't do exceptionFor(${actionTypeOrList.runtimeType}), "
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
  ///
  /// Pass [statusKey] to clear only the failure with that [ReduxAction.statusKey]:
  /// `clearExceptionFor(LoadUser, statusKey: userId)`. Without it, all the failures of
  /// the type are cleared, whatever their keys.
  void clearExceptionFor(Object actionTypeOrList, {Object? statusKey}) {
    //
    // 1) If a type was passed:
    if (actionTypeOrList is Type) {
      if (_clearFailures(actionTypeOrList, statusKey)) _changeController.add(state);
    }
    //
    // 2) If a list was passed:
    else if (actionTypeOrList is Iterable) {
      bool removedAny = false;
      for (var actionType in actionTypeOrList) {
        if (actionType is Type) {
          if (_clearFailures(actionType, statusKey)) removedAny = true;
        } else {
          Future.microtask(() {
            throw StoreException(
                "You can't clearExceptionFor([${actionTypeOrList.runtimeType}]), "
                "but only an action Type, or a List of types.");
          });
        }
      }
      if (removedAny) _changeController.add(state);
    }
    // 3) If something different was passed, it's an error. We show the error after the
    // async gap, so we don't interrupt the code. But we return null.
    else {
      Future.microtask(() {
        throw StoreException(
            "You can't clearExceptionFor(${actionTypeOrList.runtimeType}), "
            "but only an action Type, or a List of types.");
      });
    }
  }

  /// Clears the failures of all action types, so that [isFailed] is false and
  /// [exceptionFor] is null for all of them. The widgets that use them are rebuilt.
  ///
  /// You rarely need to call this yourself, since `store.internalMixinProps.clear()`
  /// (which you call on logout) and [shutdown] already call it. The failures kept for
  /// actions with a [ReduxAction.statusKey] (one per key that failed) are also released
  /// here.
  void clearAllExceptions() {
    if (_failedActions.isEmpty) return;
    _failedActions.clear();
    _changeController.add(state);
  }

  /// Returns true if some action of the exact [type] failed, and, when [statusKey] is not
  /// null, with that [ReduxAction.statusKey].
  bool _hasFailure(Type type, Object? statusKey) {
    var failures = _failedActions[type];
    if (failures == null) return false;
    if (statusKey == null) return true;
    return failures.any((failure) => failure.statusKey == statusKey);
  }

  /// The [UserException] of the failure of [type] with [statusKey]. When [statusKey] is
  /// null, the [UserException] of the most recent failure of the type, skipping the
  /// failures with other kinds of errors. Returns null if there is none.
  UserException? _userExceptionFor(Type type, Object? statusKey) {
    var failures = _failedActions[type];
    if (failures == null) return null;
    for (int i = failures.length - 1; i >= 0; i--) {
      var failure = failures[i];
      if (statusKey != null && failure.statusKey != statusKey) continue;
      var error = failure.error;
      if (error is UserException) return error;
      if (statusKey != null) return null;
    }
    return null;
  }

  /// Records a failure, replacing the previous one of the same [type] and [statusKey].
  void _addFailure(Type type, Object? statusKey, Object error) {
    _removeFailure(type, statusKey);
    (_failedActions[type] ??= []).add(_Failure(statusKey, error));
  }

  /// Removes the failure of the exact [type] and [statusKey]. Returns true if there was
  /// one.
  bool _removeFailure(Type type, Object? statusKey) {
    var failures = _failedActions[type];
    if (failures == null) return false;
    var index = failures.indexWhere((failure) => failure.statusKey == statusKey);
    if (index == -1) return false;
    failures.removeAt(index);
    if (failures.isEmpty) _failedActions.remove(type);
    return true;
  }

  /// Removes the failure of [type] with [statusKey], or all the failures of [type] when
  /// [statusKey] is null. Returns true if something was removed.
  bool _clearFailures(Type type, Object? statusKey) => (statusKey == null)
      ? _failedActions.remove(type) != null
      : _removeFailure(type, statusKey);

  /// The actions that are currently being processed.
  /// Use [isWaiting] to know if an action is currently being processed.
  final Set<ReduxAction<St>> _actionsInProgress = HashSet<ReduxAction<St>>.identity();

  /// Returns an unmodifiable set of the actions on progress.
  Set<ReduxAction<St>> actionsInProgress() {
    return new UnmodifiableSetView(_actionsInProgress);
  }

  /// Returns a copy of the set of actions on progress.
  Set<ReduxAction<St>> copyActionsInProgress() =>
      HashSet<ReduxAction<St>>.identity()..addAll(actionsInProgress());

  /// Returns true if the actions in progress are equal to the given set.
  bool actionsInProgressEqualTo(Set<ReduxAction<St>> set) {
    if (set.length != _actionsInProgress.length) {
      return false;
    }
    return set.containsAll(_actionsInProgress) && _actionsInProgress.containsAll(set);
  }

  /// Actions that we may put into [_actionsInProgress].
  /// This helps to know when to rebuild to make [isWaiting] work.
  final Set<Type> _awaitableActions = HashSet<Type>.identity();

  /// The failures of the actions that have failed recently, indexed by the action type.
  /// When an action fails with any error (that was not swallowed, and is not an
  /// `AbortDispatchException`), its error is added here together with the action's
  /// `statusKey`. Only the type, the key and the error are kept, not the action, so that
  /// it doesn't stay in memory. A failure is removed when an action of the same type and
  /// `statusKey` is dispatched again, by [clearExceptionFor], or by [clearAllExceptions]
  /// (which `internalMixinProps.clear()` and [shutdown] call). Use [isFailed],
  /// [exceptionFor] and [clearExceptionFor] to know if you should display some error
  /// message due to an action failure.
  ///
  /// Throwing a UserException can show a modal dialog and an error message in the UI.
  /// To skip the dialog, use `throw UserException('Invalid input').noDialog`.
  ///
  final Map<Type, List<_Failure>> _failedActions = HashMap<Type, List<_Failure>>();

  /// Async actions that we may put into [_failedActions].
  /// This helps to know when to rebuild to make [isWaiting] work.
  final Set<Type> _actionsWeCanCheckFailed = HashSet<Type>.identity();

  /// Dispatch has three boundaries: admission, execution, and finalization.
  /// Admission errors escape directly; execution errors go through wrapError.
  /// Keep the sync path synchronous and the async path's await points unchanged.
  FutureOr<ActionStatus> _dispatch(ReduxAction<St> action, {required bool notify}) {
    // Even abortDispatch may read the store or dispatch another action.
    action.setStore(this);

    if (_abortDispatch(action)) {
      action._status = action._status.copy(isDispatchAborted: true);
      return action._status;
    }

    _dispatchCount++;
    if (action.status.isDispatched) {
      throw StoreException('The action was already dispatched. '
          'Please, create a new action each time.');
    }
    // An earlier attempt may have aborted before this action started executing.
    action._status = action._status.copy(isDispatched: true, isDispatchAborted: false);

    if (_actionObservers != null) {
      for (final observer in _actionObservers) {
        _observeAction(observer, action, ini: true);
      }
    }

    _startAction(action);
    return action.isSync()
        ? _runActionSync(action, notify: notify)
        : _runActionAsync(action, notify: notify);
  }

  /// Check admission before observers, waiting status, or any lifecycle execution.
  /// NonReentrant keeps its lock in the existing store-scoped mixin properties.
  bool _abortDispatch(ReduxAction<St> action) {
    if (_shutdown) return true;

    if (action is UnlimitedRetryCheckInternet) {
      final retry = action as UnlimitedRetryCheckInternet;
      retry
          ._cannot_combine_mixins_CheckInternet_AbortWhenNoInternet_UnlimitedRetryCheckInternet_ServerPush();
      retry
          ._cannot_combine_mixins_NonReentrant_UnlimitedRetryCheckInternet_Throttle_Fresh_OptimisticCommand_OptimisticSync_OptimisticSyncWithPush_ServerPush();
      retry
          ._cannot_combine_mixins_Retry_UnlimitedRetryCheckInternet_Debounce_OptimisticSync_OptimisticSyncWithPush_ServerPush_Polling();
      retry
          ._cannot_combine_mixins_UnlimitedRetryCheckInternet_Debounce_OptimisticSync_OptimisticSyncWithPush_ServerPush_Sequential();
    }

    if (action is NonReentrant) {
      (action as NonReentrant)
          ._cannot_combine_mixins_NonReentrant_UnlimitedRetryCheckInternet_Throttle_Fresh_OptimisticCommand_OptimisticSync_OptimisticSyncWithPush_ServerPush();
    }

    if (action is Throttle) {
      (action as Throttle)
          ._cannot_combine_mixins_NonReentrant_UnlimitedRetryCheckInternet_Throttle_Fresh_OptimisticCommand_OptimisticSync_OptimisticSyncWithPush_ServerPush();
    }

    if (action is Fresh) {
      (action as Fresh)
          ._cannot_combine_mixins_NonReentrant_UnlimitedRetryCheckInternet_Throttle_Fresh_OptimisticCommand_OptimisticSync_OptimisticSyncWithPush_ServerPush();
    }

    // Only acquire a key once the action's own admission check allows dispatch.
    if (action.abortDispatch()) return true;

    if (action is UnlimitedRetryCheckInternet) return isWaiting(action.runtimeType);

    if (action is NonReentrant) {
      final key = (action as NonReentrant).computeNonReentrantKey();
      action._nonReentrantKey = key;
      final keys = internalMixinProps.nonReentrantKeySet;
      if (keys.contains(key)) return true;
      keys.add(key);
    }
    if (action is Throttle) return _abortThrottle(action as Throttle);
    if (action is Fresh) return _abortFresh(action as Fresh);

    return false;
  }

  bool _abortFresh(Fresh action) {
    final map = internalMixinProps.freshKeyMap;
    action._keysRemoved = false;
    action._freshKey = action.computeFreshKey();
    action._current = map[action._freshKey];
    final now = DateTime.now().toUtc();
    final ignore = action.ignoreFresh;
    final expiresAt = action._current?.$1;
    if (!ignore && expiresAt != null && expiresAt.isAfter(now)) {
      action._newToken = null;
      return true;
    }
    final expiry = now.add(Duration(milliseconds: action.freshFor));
    final token = Object();
    map[action._freshKey] = (expiry, token);
    action._newToken = token;
    if (ignore) action._current = null;
    return false;
  }

  void _finishFresh(Fresh action) {
    final map = internalMixinProps.freshKeyMap;
    if (!action._keysRemoved &&
        action.status.originalError != null &&
        action._freshKey != null) {
      final current = map[action._freshKey];
      // Roll back only the entry written by this dispatch, never a newer owner.
      if (current != null && identical(current.$2, action._newToken)) {
        if (action._current == null) {
          map.remove(action._freshKey);
        } else {
          map[action._freshKey] = action._current!;
        }
      }
    }
    final now = DateTime.now().toUtc();
    map.removeWhere((_, value) => !value.$1.isAfter(now));
  }

  bool _abortThrottle(Throttle action) {
    final lock = action.lockBuilder();
    final now = DateTime.now().toUtc();
    final locks = internalMixinProps.throttleLockMap;
    if (!action.ignoreThrottle) {
      final expiresAt = locks[lock];
      if (expiresAt != null && expiresAt.isAfter(now)) return true;
    }
    final expiresAt = now.add(Duration(milliseconds: action.throttle));
    locks[lock] = expiresAt;
    action._ownLock = lock;
    action._ownLockExpiresAt = expiresAt;
    return false;
  }

  void _finishThrottle(Throttle action) {
    final locks = internalMixinProps.throttleLockMap;
    if (action.removeLockOnError && action.status.originalError != null) {
      if (action._ownLockExpiresAt != null &&
          identical(locks[action._ownLock], action._ownLockExpiresAt)) {
        locks.remove(action._ownLock);
      }
    }
    final now = DateTime.now().toUtc();
    locks.removeWhere((_, expiresAt) => !expiresAt.isAfter(now));
  }

  /// Clear the previous failure and publish waiting status before running hooks.
  /// These notifications do not depend on the dispatch's notify argument.
  void _startAction(ReduxAction<St> action) {
    final fallible = _actionsWeCanCheckFailed.contains(action.runtimeType);
    // Clear the failure even if nobody queried it yet; a later isFailed call must
    // not find a stale error. Only previously queried types need a UI notification.
    final removedFailure = _removeFailure(action.runtimeType, action.statusKey);
    final notifiedFailure = fallible && removedFailure;

    if (notifiedFailure) _changeController.add(state);

    // Track sync actions too: a nested dispatch may check NonReentrant/isWaiting.
    if (_actionsInProgress.add(action)) _checkAllActionConditions(action);

    if (!notifiedFailure && _awaitableActions.contains(action.runtimeType)) {
      _changeController.add(state);
    }
  }

  ActionStatus _runActionSync(ReduxAction<St> action, {required bool notify}) {
    assert(action.store == this);
    Object? originalError;

    try {
      final result = action.before();
      if (result is Future) throw StoreException(_beforeTypeErrorMsg);
      action._status = action._status.copy(hasFinishedMethodBefore: true);

      if (!_shutdown) {
        _runReducer(action, notify: notify);
        action._status = action._status.copy(hasFinishedMethodReduce: true);
      }
    } catch (error, stackTrace) {
      originalError = error;
      final processedError = _processActionError(action, error, stackTrace);
      if (processedError == null) return action._status;
      if (identical(processedError, error)) rethrow;
      Error.throwWithStackTrace(processedError, stackTrace);
    } finally {
      _finishAction(action, originalError, notify: notify);
    }

    return action._status;
  }

  /// Mirrors the sync lifecycle, awaiting only hooks that actually return a Future.
  /// Keep both runners: adding an await to the sync path would defer state changes.
  Future<ActionStatus> _runActionAsync(
    ReduxAction<St> action, {
    required bool notify,
  }) async {
    assert(action.store == this);
    Object? originalError;

    try {
      final before = _runBefore(action);
      if (before is Future) await before;
      action._status = action._status.copy(hasFinishedMethodBefore: true);

      if (!_shutdown) {
        final reduce = _runReducer(action, notify: notify);
        if (reduce is Future) await reduce;
        action._status = action._status.copy(hasFinishedMethodReduce: true);
      }
    } catch (error, stackTrace) {
      originalError = error;
      final processedError = _processActionError(action, error, stackTrace);
      if (processedError == null) return action._status;
      if (identical(processedError, error)) rethrow;
      Error.throwWithStackTrace(processedError, stackTrace);
    } finally {
      _finishAction(action, originalError, notify: notify);
    }

    return action._status;
  }

  FutureOr<void> _runBefore(ReduxAction<St> action) {
    if (action is Sequential) return _beforeSequential(action);
    return _beforeWithoutSequential(action);
  }

  FutureOr<void> _beforeWithoutSequential(ReduxAction<St> action) {
    if (action is CheckInternet) return _beforeWithCheckInternet(action);
    if (action is AbortWhenNoInternet) return _beforeWithAbortWhenNoInternet(action);
    return action.before();
  }

  Future<void> _beforeSequential(ReduxAction<St> action) async {
    final sequential = action as Sequential;
    sequential
        ._cannot_combine_mixins_UnlimitedRetryCheckInternet_Debounce_OptimisticSync_OptimisticSyncWithPush_ServerPush_Sequential();
    // Reserve synchronously, before any user hook or await, to keep dispatch order.
    final key = sequential.sequentialKeyParams();
    final queue = internalMixinProps.sequentialQueueMap.putIfAbsent(key, () => []);
    final completer = Completer<bool>();
    final mustWait = queue.isNotEmpty;
    queue.add(completer);
    sequential._sequentialKey = key;
    sequential._sequentialQueue = queue;
    sequential._sequentialCompleter = completer;

    if (mustWait) {
      sequential._isWaitingInSequentialQueue = true;
      bool discarded;
      try {
        discarded = await completer.future;
      } finally {
        sequential._isWaitingInSequentialQueue = false;
      }
      if (discarded) {
        sequential._wasDiscardedFromSequentialQueue = true;
        throw AbortDispatchException();
      }
    }
    await _beforeWithoutSequential(action);
  }

  void _finishSequential(Sequential action) {
    final queue = action._sequentialQueue;
    final completer = action._sequentialCompleter;
    if (queue == null || completer == null) return;
    action._sequentialCompleter = null;
    if (action._wasDiscardedFromSequentialQueue) return;

    bool discard = false;
    try {
      final error = action.status.originalError;
      if (error != null) discard = action.discardQueueOnError(error);
    } finally {
      queue.remove(completer);
      if (discard) {
        final discarded = List.of(queue);
        queue.clear();
        for (final other in discarded) other.complete(true);
      } else if (queue.isNotEmpty) {
        queue.first.complete(false);
      }
      // An old owner must leave a replacement queue created after clear() alone.
      final map = internalMixinProps.sequentialQueueMap;
      if (queue.isEmpty && identical(map[action._sequentialKey], queue)) {
        map.remove(action._sequentialKey);
      }
    }
  }

  Future<void> _beforeWithAbortWhenNoInternet(ReduxAction<St> action) async {
    final check = action as AbortWhenNoInternet;
    check
        ._cannot_combine_mixins_CheckInternet_AbortWhenNoInternet_UnlimitedRetryCheckInternet_ServerPush();
    await action.before();
    final result = await check.checkConnectivity();
    if (result.contains(ConnectivityResult.none)) throw AbortDispatchException();
  }

  Future<void> _beforeWithCheckInternet(ReduxAction<St> action) async {
    final check = action as CheckInternet;
    check
        ._cannot_combine_mixins_CheckInternet_AbortWhenNoInternet_UnlimitedRetryCheckInternet_ServerPush();
    await action.before();
    final result = await check.checkConnectivity();
    if (result.contains(ConnectivityResult.none)) {
      throw check.connectionException(result).withDialog(check.ifOpenDialog);
    }
  }

  /// Runs after exactly once, removes waiting status, then notifies END observers.
  /// On failure, after already ran before the error was queued or propagated.
  void _finishAction(
    ReduxAction<St> action,
    Object? originalError, {
    required bool notify,
  }) {
    // _runAfter marks completion in finally, even when after itself throws. This
    // also prevents a second call if error handling fails after running after.
    if (!action._status.hasFinishedMethodAfter) _runAfter(action);

    if (_actionsInProgress.remove(action)) _checkAllActionConditions(action);

    // Rebuild widgets that queried waiting/failure status, even with notify=false.
    // Use the original error: swallowed errors also finish a pending action.
    // Failure notifications cover ordinary errors and noDialog UserExceptions,
    // which do not trigger the dialog queue's notification.
    final awaitable = _awaitableActions.contains(action.runtimeType);
    final fallible = _actionsWeCanCheckFailed.contains(action.runtimeType);
    if ((awaitable && (originalError != null || !notify)) ||
        (fallible && originalError != null)) {
      _changeController.add(state);
    }

    if (_actionObservers != null) {
      for (final observer in _actionObservers) {
        _observeAction(observer, action, ini: false);
      }
    }
  }

  void _runAfter(ReduxAction<St> action) {
    try {
      try {
        action.after();
      } finally {
        // Cleanup is part of finalization even when user code omits super or throws.
        if (action is NonReentrant) {
          internalMixinProps.nonReentrantKeySet.remove(action._nonReentrantKey);
        }
        if (action is Throttle) _finishThrottle(action as Throttle);
        if (action is Fresh) _finishFresh(action as Fresh);
        if (action is Sequential) _finishSequential(action as Sequential);
      }
    } catch (error, stackTrace) {
      // Report asynchronously without replacing the action's own error.
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

  FutureOr<void> _runReducer(ReduxAction<St> action, {required bool notify}) {
    _reduceCount++;
    _checkReducerType(action.reduce);

    if (action.ifWrapReduceOverridden() || _hasStoreReducerMixin(action)) {
      return _runWrappedReducer(action, notify: notify);
    }

    final reduce = (_wrapReduce != null)
        ? _wrapReduce.wrapReduce(action.reduce, this)
        : action.reduce;

    if (reduce is St? Function()) {
      _commitState(reduce(), action, notify: notify);
    } else if (reduce is Future<St?> Function()) {
      action._completedFuture = false;
      return _commitAsyncReducer(reduce(), action, notify: notify);
    } else {
      throw StoreException("Reducer should return `St?` or `Future<St?>`. "
          "Do not return `FutureOr<St?>`. "
          "Reduce is of type: '${reduce.runtimeType}'.");
    }
  }

  Future<void> _runWrappedReducer(ReduxAction<St> action, {required bool notify}) {
    assert(action.ifWrapReduceOverridden() || _hasStoreReducerMixin(action));
    if (action.ifWrapReduceOverridden_Sync()) {
      throw StoreException("The ${action.runtimeType}.wrapReduce method "
          "should return `Future<St?>`, not `<St>` or `<St?>`.");
    }

    // Reset before invoking either wrapper, which may itself run user code.
    action._completedFuture = false;
    final reduce = (_wrapReduce != null)
        ? _wrapReduce.wrapReduce(action.reduce, this)
        : action.reduce;

    final Future<St?> result;
    if (_hasStoreReducerMixin(action)) {
      action._wrapReduceInStore = true;
      final wrapped = action.ifWrapReduceOverridden()
          ? () => action.wrapReduce(reduce)
          : reduce;
      if (action is Debounce) {
        result = _reduceDebounced(action as Debounce, wrapped);
      } else if (action is UnlimitedRetryCheckInternet) {
        result = _reduceWithInternetRetry(action as UnlimitedRetryCheckInternet, wrapped);
      } else if (action is Polling) {
        result = _reduceWithPolling(action as Polling, wrapped);
      } else {
        result = _reduceWithRetry(action as Retry, wrapped);
      }
    } else {
      result = action.wrapReduce(reduce) as Future<St?>;
    }
    return _commitAsyncReducer(result, action, notify: notify);
  }

  bool _hasStoreReducerMixin(ReduxAction<St> action) =>
      action is Debounce || action is Retry ||
      action is UnlimitedRetryCheckInternet || action is Polling;

  Future<St?> _reduceWithPolling(Polling action, Reducer<St> reduce) async {
    action
        ._cannot_combine_mixins_Retry_UnlimitedRetryCheckInternet_Debounce_OptimisticSync_OptimisticSyncWithPush_ServerPush_Polling();
    action
        ._cannot_combine_mixins_UnlimitedRetries_Debounce_OptimisticCommand_OptimisticSync_OptimisticSyncWithPush_ServerPush_Polling();
    final key = action.computePollingKey();
    final map = internalMixinProps.pollingMap;
    switch (action.poll) {
      case Poll.start:
        if (map.containsKey(key)) return null;
        return _startPollingCycle(action, key, reduce);
      case Poll.stop:
        map.remove(key)?.timer?.cancel();
        return null;
      case Poll.runNowAndRestart:
        map.remove(key)?.timer?.cancel();
        return _startPollingCycle(action, key, reduce);
      case Poll.once:
        return reduce();
    }
  }

  Future<St?> _startPollingCycle(Polling action, Object key, Reducer<St> reduce) async {
    final id = Object();
    internalMixinProps.pollingMap[key] = (id: id, timer: null);
    if (!action.pollWaitsForRun) {
      _schedulePollingTick(action, key, id);
      return reduce();
    } else {
      try {
        return await reduce();
      } finally {
        _schedulePollingTick(action, key, id);
      }
    }
  }

  void _schedulePollingTick(Polling action, Object key, Object id) {
    final map = internalMixinProps.pollingMap;
    // A stopped or replaced cycle must never schedule a new tick.
    if (!identical(map[key]?.id, id)) return;
    final timer = Timer(action.pollInterval, () {
      if (!identical(map[key]?.id, id)) return;
      map[key] = (id: id, timer: null);
      if (!action.pollWaitsForRun) {
        action.dispatch(action.createPollingAction());
        _schedulePollingTick(action, key, id);
      } else {
        _dispatchPollingTick(action, key, id);
      }
    });
    map[key] = (id: id, timer: timer);
  }

  Future<void> _dispatchPollingTick(Polling action, Object key, Object id) async {
    try {
      await action.dispatchAndWait(action.createPollingAction());
    } finally {
      _schedulePollingTick(action, key, id);
    }
  }

  Future<St?> _reduceWithInternetRetry(
    UnlimitedRetryCheckInternet action,
    Reducer<St> reduce,
  ) async {
    FutureOr<St?> newState;
    bool hasInternet = true;
    try {
      final result = await action.checkConnectivity();
      if (result.contains(ConnectivityResult.none)) {
        hasInternet = false;
        throw const UserException('');
      }

      if (action.attempts == 0) {
        action.printRetries('Trying ${action.runtimeType}.');
      } else {
        action.printRetries(
            'Retrying ${action.runtimeType} (attempt ${action.attempts}).');
      }
      newState = reduce();
      if (newState is Future) newState = await newState;
    } catch (error) {
      if (error is AbortDispatchException) rethrow;
      if (!hasInternet) {
        if (action.attempts == 0) {
          action.printRetries(
              'Trying ${action.runtimeType}; aborted because of no internet.');
        } else {
          action.printRetries('Retrying ${action.runtimeType}; aborted because of '
              'no internet (attempt ${action.attempts}).');
        }
      }
      action._attempts++;
      if (action.maxRetries >= 0 && action._attempts > action.maxRetries) rethrow;
      if (hasInternet && !action.shouldRetry(error, action._attempts)) rethrow;
      await Future.delayed(action.nextDelay(hasInternet: hasInternet));
      return _reduceWithInternetRetry(action, reduce);
    }
    return newState;
  }

  Future<St?> _reduceWithRetry(Retry action, Reducer<St> reduce) async {
    action
        ._cannot_combine_mixins_Retry_UnlimitedRetryCheckInternet_Debounce_OptimisticSync_OptimisticSyncWithPush_ServerPush_Polling();
    // OptimisticCommand retries only the server command in its own implementation.
    if (action is OptimisticCommand) {
      FutureOr<St?> result = reduce();
      if (result is Future) result = await result;
      return result;
    }
    FutureOr<St?> result;
    try {
      await action.microtask;
      result = reduce();
      if (result is Future) result = await result;
    } catch (error) {
      if (error is AbortDispatchException) rethrow;
      action._attempts++;
      if (action.maxRetries >= 0 && action._attempts > action.maxRetries) rethrow;
      if (!action.shouldRetry(error, action._attempts)) rethrow;
      await Future.delayed(action.nextDelay());
      return _reduceWithRetry(action, reduce);
    }
    return result;
  }

  Future<St?> _reduceDebounced(Debounce action, Reducer<St> reduce) async {
    action
        ._cannot_combine_mixins_Retry_UnlimitedRetryCheckInternet_Debounce_OptimisticSync_OptimisticSyncWithPush_ServerPush_Polling();
    action
        ._cannot_combine_mixins_UnlimitedRetries_Debounce_OptimisticCommand_OptimisticSync_OptimisticSyncWithPush_ServerPush_Polling();
    action
        ._cannot_combine_mixins_UnlimitedRetryCheckInternet_Debounce_OptimisticSync_OptimisticSyncWithPush_ServerPush_Sequential();
    final lock = action.lockBuilder();
    final map = internalMixinProps.debounceLockMap;
    var run = (map[lock] ?? 0) + 1;
    if (run > Debounce._SAFE_INTEGER) run = 0;
    map[lock] = run;
    await Future.delayed(Duration(milliseconds: action.debounce));
    if (map[lock] != run) return null;
    map.remove(lock);
    return reduce();
  }

  /// Commit directly in the reducer Future's then callback, without another await
  /// or Future in between. A pending async reducer that returns a value after an
  /// await delivers it here in the same microtask. Deferring the commit could let
  /// another reducer read stale state and overwrite a concurrent state change.
  ///
  /// Without an await, the reducer can return an already completed Future. Attaching
  /// then to it schedules the callback in a later microtask, leaving a window for
  /// another reducer to read the old state. Every async reducer path must await
  /// before returning its state; adding `await microtask` is sufficient.
  ///
  /// This relies on Dart's scheduling behavior, not a documented API guarantee.
  /// Future does not expose whether it is already complete, so we cannot check it
  /// directly. assertUncompletedFuture provides an opt-in scheduling check instead.
  /// See store_microtask_order_test.dart and completed_reducer_future_test.dart.
  Future<void> _commitAsyncReducer(
    Future<St?> result,
    ReduxAction<St> action, {
    required bool notify,
  }) =>
      result.then((state) {
        _commitState(state, action, notify: notify);

        if (action._completedFuture) {
          Future.error(
            "The reducer of action ${action.runtimeType} returned a completed Future. "
            "This may result in state changes being lost. "
            "Please make sure all code paths in the reducer pass through at least "
            "one `await`. "
            "If necessary, add `await microtask;` to the start of the reducer.",
          );
        }
      });

  static const _beforeTypeErrorMsg =
      "Before should return `void` or `Future<void>`. Do not return `FutureOr`.";

  static const _reducerTypeErrorMsg = "Reducer should return `St?` or `Future<St?>`. ";

  void _checkReducerType(FutureOr<St?> Function() reduce) {
    if (reduce is St? Function()) return;
    if (reduce is Future<St?> Function()) return;

    if (reduce is Future<St>? Function()) {
      throw StoreException(_reducerTypeErrorMsg + "Do not return `Future<St>?`.");
    }
    if (reduce is Future<St?>? Function()) {
      throw StoreException(_reducerTypeErrorMsg + "Do not return `Future<St?>?`.");
    }
    throw StoreException(_reducerTypeErrorMsg + "Do not return `FutureOr`.");
  }

  /// Publish state and check wait conditions before observers and persistence.
  /// Null/identical results still notify while the action is in progress, so that
  /// widgets can stop waiting (unless notify is false). Change detection uses identity,
  /// avoiding the cost of state equality checks. Outside shutdown, state observers
  /// and persistors see even null/identical results; they decide how to handle them.
  void _commitState(St? state, ReduxAction<St> action, {required bool notify}) {
    if (_shutdown) return;

    final previousState = _state;
    if ((state != null && !identical(_state, state)) ||
        _actionsInProgress.contains(action)) {
      _state = state ?? _state;
      _stateTimestamp = DateTime.now().toUtc();

      if (notify) _changeController.add(state ?? _state);
      _checkAllStateConditions(action);
    }

    // Capture once: observers may dispatch nested actions before persistence runs.
    final newState = _state;
    if (_stateObservers != null) {
      for (final observer in _stateObservers) {
        _observeState(observer, action, previousState, newState, null);
      }
    }

    _processPersistence?.process(action, newState);
    _processCloudSync?.process(action, newState);
  }

  /// Transform and record the error, run after, then queue a dialog or mark an abort.
  /// Returns only errors that must escape dispatch; null means no rethrow.
  Object? _processActionError(
    ReduxAction<St> action,
    Object error,
    StackTrace stackTrace,
  ) {
    if (_stateObservers != null) {
      for (final observer in _stateObservers) {
        // Read the live state for each observer, including after nested dispatches.
        _observeState(observer, action, _state, _state, error);
      }
    }

    action._status = action._status.copy(originalError: error);
    final wrappedError = _wrapActionError(action, error, stackTrace);
    action._status = action._status.copy(wrappedError: wrappedError);

    // Store only type/key/error, without keeping the action alive.
    if (wrappedError != null && wrappedError is! AbortDispatchException) {
      _addFailure(action.runtimeType, action.statusKey, wrappedError);
    }

    _runAfter(action);

    if (wrappedError is UserException) {
      if (wrappedError.ifOpenDialog) {
        _addError(wrappedError);
        _changeController.add(state);
      }
      return null;
    }
    if (wrappedError is AbortDispatchException) {
      action._status = action._status.copy(isDispatchAborted: true);
      return null;
    }
    return wrappedError;
  }

  /// Local wrapping precedes global wrapping; either may replace or swallow errors.
  /// A thrown replacement is treated like a returned one, though returning is the
  /// intended API. Propagation still uses the original action error's stack trace.
  Object? _wrapActionError(
    ReduxAction<St> action,
    Object error,
    StackTrace stackTrace,
  ) {
    Object? wrappedError;
    try {
      wrappedError = action.wrapError(error, stackTrace);
    } catch (replacement) {
      wrappedError = replacement;
    }
    if (wrappedError == null) return null;

    // Factory errors escape this pipeline, but finalization must still run after.
    final observer = _globalErrorObserver?.call(this);
    if (observer == null) return wrappedError;

    try {
      observer._init(
        error: wrappedError,
        originalError: action.status.originalError,
        stackTrace: stackTrace,
        action: action,
        store: this,
        errorSource: GlobalErrorSource.action,
      );
      return observer.observe();
    } catch (replacement) {
      return replacement;
    }
  }

  /// Processes errors thrown by the [Persistor] (or the cloud-sync) when persisting the state.
  /// The [error] was already processed by [Persistor.wrapError], while [originalError] is the
  /// error before it. The error is given to the [GlobalErrorObserver], if defined. Then:
  /// - If the processed error is a [UserException], it's added to the error queue.
  /// - If it's `null`, it's swallowed.
  /// - Otherwise, it's returned, to be thrown as an unhandled async error.
  Object? _processPersistorError(Object error, Object originalError, StackTrace stackTrace) {
    Object? errorOrNull = error;

    var globalErrorObserver = _globalErrorObserver?.call(this);
    if (globalErrorObserver != null) {
      try {
        globalErrorObserver._init(
          error: error,
          originalError: originalError,
          stackTrace: stackTrace,
          action: null,
          store: this,
          errorSource: GlobalErrorSource.persistor,
        );
        errorOrNull = globalErrorObserver.observe();
      } catch (_error) {
        // If the GlobalErrorObserver throws an error, it will be used instead
        // of the original error (but the recommended way is returning the error).
        errorOrNull = _error;
      }
    }

    // Memorizes errors of type UserException (in the error queue).
    if (errorOrNull is UserException) {
      if (errorOrNull.ifOpenDialog) {
        _addError(errorOrNull);
        if (!_changeController.isClosed) _changeController.add(state);
      }
      return null;
    }

    return errorOrNull;
  }

  void _observeAction(ActionObserver observer, ReduxAction<St> action,
      {required bool ini}) {
    _runObserver(observer, action, GlobalErrorSource.actionObserver,
        () => (observer as dynamic).observe(action, dispatchCount, ini: ini),
        observerIni: ini);
  }

  void _observeState(StateObserver observer, ReduxAction<St> action,
      St previous, St next, Object? error) {
    _runObserver(observer, action, GlobalErrorSource.stateObserver,
        () => (observer as dynamic)
            .observe(action, previous, next, error, dispatchCount));
  }

  /// An observer must never interrupt the action it observes. Although its API
  /// returns void, Dart also permits async overrides; handle their failures
  /// without waiting for them or making synchronous dispatch asynchronous.
  void _runObserver(Object observer, ReduxAction<St> action,
      GlobalErrorSource source, Object? Function() observe, {bool? observerIni}) {
    void report(Object error, StackTrace stackTrace) =>
        _processObserverError(error, stackTrace, action, observer, source, observerIni);
    try {
      final result = observe();
      if (result is Future) result.then<void>((_) {}, onError: report);
    } catch (error, stackTrace) {
      report(error, stackTrace);
    }
  }

  bool _isReportingObserverError = false;

  /// Diagnostic errors do not enter the action's error pipeline. In particular,
  /// they must not replace its original error or affect isFailed/isWaiting.
  void _processObserverError(Object error, StackTrace stackTrace,
      ReduxAction<St> action, Object observer, GlobalErrorSource source,
      bool? observerIni) {
    if (_isReportingObserverError) {
      _logObserverError(error, stackTrace, source);
      return;
    }

    _isReportingObserverError = true;
    try {
      Object? processedError = error;
      try {
        final globalObserver = _globalErrorObserver?.call(this);
        if (globalObserver != null) {
          globalObserver._init(
            error: error,
            originalError: error,
            stackTrace: stackTrace,
            action: action,
            store: this,
            errorSource: source,
            observer: observer,
            observerIni: observerIni,
          );
          processedError = globalObserver.observe();
        }
      } catch (replacement, replacementStack) {
        processedError = replacement;
        stackTrace = replacementStack;
      }

      if (processedError is UserException) {
        if (processedError.ifOpenDialog) {
          _addError(processedError);
          if (!_changeController.isClosed) _changeController.add(state);
        }
      } else if (processedError != null) {
        // The global observer is synchronous. An invalid async override is a
        // diagnostic value, not a new asynchronous failure of the action.
        if (processedError is Future) {
          processedError.then<void>((_) {}, onError: (Object error, StackTrace stack) {
            _logObserverError(error, stack, source);
          });
        }
        _logObserverError(processedError, stackTrace, source);
      }
    } catch (reportingError, reportingStack) {
      // Reporting a diagnostic (including queueing a dialog) must also remain
      // isolated. Never recursively call the global observer with this error.
      _logObserverError(reportingError, reportingStack, source);
    } finally {
      _isReportingObserverError = false;
    }
  }

  void _logObserverError(Object error, StackTrace stackTrace, GlobalErrorSource source) {
    try {
      developer.log('Error in ${source.name}.', name: 'AsyncRedux', level: 1000,
          error: error, stackTrace: stackTrace);
    } catch (_) {
      // Even a malformed diagnostic object must not break the observed action.
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
    this.isDispatchAborted = false,
    this.originalError,
    this.wrappedError,
    required this.context,
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
  /// - If an [AbortDispatchException] was thrown by the action's `before` or `reduce`
  ///   methods (and survived the `wrapError` and `globalErrorObserver`). Or,
  /// - Rejected because the store was already shut down when dispatched.
  ///
  /// Calling [Store.shutdown] during execution does not guarantee a particular
  /// final action status.
  final bool isDispatchAborted;

  /// Holds the error thrown by the action's before/reduce methods, if any.
  /// This may or may not be equal to the error thrown by the action, because the original error
  /// will still be processed by the action's `wrapError` and the `globalErrorObserver`. However,
  /// if `originalError` is non-null, it means the reducer did not finish running.
  final Object? originalError;

  /// Holds the error thrown by the action. This may or may not be the same as `originalError`,
  /// because any errors thrown by the action's before/reduce methods may still be changed
  /// or cancelled by the action's `wrapError` and the `globalErrorObserver`. This is the
  /// final error after all these wraps.
  final Object? wrappedError;

  /// The action and store related to this status.
  final (ReduxAction, Store)? context;

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
    (ReduxAction, Store)? context,
  }) =>
      ActionStatus(
        isDispatched: isDispatched ?? this.isDispatched,
        hasFinishedMethodBefore: hasFinishedMethodBefore ?? this.hasFinishedMethodBefore,
        hasFinishedMethodReduce: hasFinishedMethodReduce ?? this.hasFinishedMethodReduce,
        hasFinishedMethodAfter: hasFinishedMethodAfter ?? this.hasFinishedMethodAfter,
        isDispatchAborted: isDispatchAborted ?? this.isDispatchAborted,
        originalError: originalError ?? this.originalError,
        wrappedError: wrappedError ?? this.wrappedError,
        context: context ?? this.context,
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
          wrappedError == other.wrappedError &&
          context == other.context;

  @override
  int get hashCode => Object.hash(
      isDispatched,
      hasFinishedMethodBefore,
      hasFinishedMethodReduce,
      hasFinishedMethodAfter,
      isDispatchAborted,
      originalError,
      wrappedError,
      context);
}

/// Extension methods on `Future<ActionStatus>`, which is the type returned by
/// [Store.dispatchAndWait]. They let you chain code that should run only if the
/// action completed OK, or only if it failed, without having to `await` and
/// check the status manually.
extension FutureActionStatusExtension on Future<ActionStatus> {
  //
  /// Runs the given [callback] only if the action completed OK, meaning
  /// [ActionStatus.isCompletedOk] is true: the action finished, and its
  /// 'before' and 'reduce' methods did not throw any errors.
  ///
  /// This is important because `dispatchAndWait` completes with an [ActionStatus]
  /// even when the action fails, so a plain `.then()` would run regardless of
  /// success or failure:
  ///
  /// ```dart
  /// // The `PollBlockNumber` action will be dispatched only
  /// // if `InitializeWeb3` succeeds:
  /// dispatchAndWait(InitializeWeb3())
  ///     .thenIfCompletedOk((_) => dispatch(PollBlockNumber()));
  /// ```
  ///
  /// It returns a future that completes with the same [ActionStatus], after the
  /// callback finishes (if it ran). This means you can chain it with
  /// [thenIfCompletedFailed], to handle both cases:
  ///
  /// ```dart
  /// dispatchAndWait(InitializeWeb3())
  ///     .thenIfCompletedOk((_) => dispatch(PollBlockNumber()))
  ///     .thenIfCompletedFailed((status) => log(status.wrappedError));
  /// ```
  ///
  /// If the callback throws, the returned future completes with that error,
  /// just like a regular `.then()`.
  ///
  /// See also:
  /// - [thenIfCompletedFailed] which runs the callback only if the action failed.
  ///
  Future<ActionStatus> thenIfCompletedOk(
    FutureOr<void> Function(ActionStatus status) callback,
  ) =>
      then((status) async {
        if (status.isCompletedOk) await callback(status);
        return status;
      });

  /// Runs the given [callback] only if the action failed, meaning
  /// [ActionStatus.isCompletedFailed] is true: the action finished, but its
  /// 'before' or 'reduce' methods threw an error, and the reducer could not
  /// return a value to change the state.
  ///
  /// The callback gets the [ActionStatus], from which you can read the error:
  /// [ActionStatus.originalError] is the error originally thrown by the action,
  /// and [ActionStatus.wrappedError] is the final error, after being processed
  /// by the action's `wrapError` and the `globalErrorObserver`.
  ///
  /// ```dart
  /// dispatchAndWait(InitializeWeb3())
  ///     .thenIfCompletedFailed((status) => log(status.wrappedError));
  /// ```
  ///
  /// It returns a future that completes with the same [ActionStatus], after the
  /// callback finishes (if it ran). This means you can chain it with
  /// [thenIfCompletedOk], to handle both cases:
  ///
  /// ```dart
  /// dispatchAndWait(InitializeWeb3())
  ///     .thenIfCompletedOk((_) => dispatch(PollBlockNumber()))
  ///     .thenIfCompletedFailed((status) => log(status.wrappedError));
  /// ```
  ///
  /// If the callback throws, the returned future completes with that error,
  /// just like a regular `.then()`.
  ///
  /// See also:
  /// - [thenIfCompletedOk] which runs the callback only if the action succeeded.
  ///
  Future<ActionStatus> thenIfCompletedFailed(
    FutureOr<void> Function(ActionStatus status) callback,
  ) =>
      then((status) async {
        if (status.isCompletedFailed) await callback(status);
        return status;
      });
}

typedef OptimisticSyncWithPushRevisionEntry = ({
  /// Monotonic counter for *local intents* (dispatches) for this key.
  /// Incremented once per dispatch of an [OptimisticSyncWithPush] action
  /// for a given key. Used to decide if a follow-up request may be needed.
  int localRevision,

  /// Latest known server revision for this key.
  /// This is updated by both [OptimisticSyncWithPush] and [ServerPush].
  /// It only moves forward (never regresses) to guard against
  /// out-of-order responses/pushes. Value `-1` means the app doesn't know
  /// any server revision yet for this key.
  int serverRevision,

  /// True if the latest value in memory is from a server push.
  /// False if it's from a local dispatch.
  bool isPush,
});

/// Some properties used by the Mixins. These are scoped to the store, so they
/// reset when the store is recreated, for example during tests.
class _InternalMixinProps {
  /// Called at the end of [clear]. The store uses it to also clear the failures it keeps
  /// for `isFailed` and `exceptionFor`.
  final void Function()? onClear;

  _InternalMixinProps({this.onClear});

  final Map<Object?, DateTime> throttleLockMap = {};
  final Map<Object?, (DateTime, Object)> freshKeyMap = {};
  final Map<Object?, int> debounceLockMap = {};
  final Set<Object?> nonReentrantKeySet = {};

  /// Set for the [OptimisticSync] mixin. Tracks which keys are currently locked.
  final Set<Object?> optimisticSyncKeySet = {};

  /// Map used by the [OptimisticSyncWithPush] and [ServerPush] mixins.
  final Map<Object?, OptimisticSyncWithPushRevisionEntry>
      optimisticSyncWithPushRevisionMap = {};

  /// Map used by the [Polling] mixin. Stores the currently active polling
  /// cycle for each polling key.
  ///
  /// Each cycle is identified by the object identity of its `id`. A new `id`
  /// is created each time polling starts or restarts for a given polling key,
  /// so that timers and pending runs belonging to an old cycle can detect that
  /// they are stale, and stop.
  ///
  /// While a tick is running (when [Polling.pollWaitsForRun] is `true`) the
  /// `timer` is `null`, but the entry is still present in the map, meaning
  /// polling is active.
  final Map<Object?, ({Object id, Timer? timer})> pollingMap = {};

  /// Map used by the [Sequential] mixin. For each queue key, stores
  /// the completers of the queued actions, in the order they will run.
  final Map<Object?, List<Completer<bool>>> sequentialQueueMap = {};

  /// Removes the locks for Throttle, Debounce, Fresh, NonReentrant,
  /// OptimisticSync, OptimisticSyncWithPush, Polling, and Sequential.
  ///
  /// For Sequential, the actions waiting in the queues are discarded: they
  /// are aborted without running, as if a failed action had discarded its
  /// queue. Actions that are already running keep running.
  void clear() {
    throttleLockMap.clear();
    freshKeyMap.clear();
    debounceLockMap.clear();
    nonReentrantKeySet.clear();
    optimisticSyncKeySet.clear();
    optimisticSyncWithPushRevisionMap.clear();
    for (final cycle in pollingMap.values) cycle.timer?.cancel();
    pollingMap.clear();
    _discardSequentialQueues();
    onClear?.call();
  }

  /// Discards the actions waiting in all Sequential queues (all but the first
  /// of each queue, which is running). They are removed from their queue
  /// before being released, so that the running action doesn't release them
  /// again when it finishes.
  void _discardSequentialQueues() {
    for (final queue in sequentialQueueMap.values) {
      if (queue.length <= 1) continue;
      final waiting = queue.sublist(1);
      queue.removeRange(1, queue.length);
      for (final completer in waiting) completer.complete(true);
    }
    sequentialQueueMap.clear();
  }
}

/// Identifies the component whose error is given to [GlobalErrorObserver].
enum GlobalErrorSource { action, persistor, actionObserver, stateObserver }

/// You may subclass [GlobalErrorObserver] and pass it to the store constructor,
/// if you want to have a global observer for errors thrown in your actions:
///
/// ```dart
/// var store = Store<AppState>(
///   initialState: AppState(),
///   globalErrorObserver: (store) => AppGlobalErrorObserver(),
/// }
///
/// class MyGlobalErrorObserver extends GlobalErrorObserver {
///   @override
///   void wrap() {
///     // Do something.
///   }
/// }
/// ```
///
/// Your observer error object will be given all errors thrown in your actions
/// (including those of type `UserException`), and also the errors thrown by the
/// [Persistor] (and the cloud-sync) when persisting the state. Then:
/// * If it returns the same [error] unaltered, this original error will be used.
/// * If it returns something else, that it will be used instead of [error].
/// * If it returns `null`, [error] will be disabled (swallowed).
///
/// IMPORTANT: If instead of RETURNING an error you THROW an error inside the `observe`
/// method, AsyncRedux will catch this error and use it instead of [error].
/// In other words, returning an error or throwing an error has the same effect. However,
/// it is still recommended to return the error rather than throwing it.
///
/// Note this observer is called AFTER the action's [ReduxAction.wrapError].
///
/// # Errors not thrown by actions
///
/// Errors thrown by [Persistor.persistDifference] (for both the `persistor` and the
/// `cloudSync` of the store) are also given to this observer, AFTER the persistor's
/// [Persistor.wrapError]. In this case, the [action] will be `null`, and [originalError]
/// will be the error before [Persistor.wrapError]. Then:
/// * If it returns a [UserException], it will be added to the store's error queue,
///   so that it can be shown to the user (for example, by the `UserExceptionDialog`).
/// * If it returns `null`, the error will be swallowed.
/// * If it returns any other error, it will be thrown as an unhandled async error.
///
/// Errors from [ActionObserver] and [StateObserver] are also reported here, without
/// invoking the action's `wrapError` or changing its status. See [errorSource],
/// [observer] and [observerIni] to identify these diagnostic errors. Returning null
/// suppresses them; a UserException may open a dialog; any other result is logged
/// with `dart:developer.log` under the name `AsyncRedux`, without being rethrown.
/// An exception thrown while handling these diagnostics is never reported back to
/// this observer recursively. Observer callbacks are not awaited; failures of a
/// Future returned by a callback are reported when that Future completes.
///
/// # Use cases
///
/// 1. Use this to set up your app to use 3rd-party services like Sentry or Firebase
/// Crashlytics to monitor your app for errors in production, and print them to the
/// console in development and testing. Since you are setting it up in a centralized way,
/// you don't have to "pollute" your code with logging calls.
///
/// 2. Use this to have a global place to convert some exceptions into [UserException]s.
/// For example, Firebase may throw some `PlatformException`s in response to a bad
/// connection to the server. In this case, you may want to show the user a dialog
/// explaining that the connection is bad, which you can do by converting it to
/// a [UserException]. Note, this could also be done in the [ReduxAction.wrapError],
/// but then you'd have to add it to all actions that use Firebase.
///
/// # Parameters you can access in the `observe` method:
///
/// - `error`: The error thrown by the action, AFTER `wrapError`.
/// - `originalError`: The action error BEFORE `wrapError`.
/// - `stackTrace`: The stack trace associated with the error.
/// - `action`: The action that failed or was being observed, or `null` for persistence.
/// - `errorSource`: Distinguishes action, persistence and observer errors.
/// - `observer`: The failing ActionObserver or StateObserver, when applicable.
/// - `observerIni`: For an ActionObserver failure, identifies INI (true) or END (false).
/// - `store`: Use it to read `store.environment` or `store.configuration`.
///    Do **not** use it to dispatch new actions.
///
abstract class GlobalErrorObserver<St> {
  //
  /// The error thrown by the action, AFTER being processed by the action's `wrapError`.
  /// If the error came from the [Persistor] (see [action]), this is the error AFTER being
  /// processed by [Persistor.wrapError].
  /// Errors from ActionObserver and StateObserver are passed here without wrapping.
  late final Object error;

  /// The error thrown by the action, BEFORE being processed by the action's `wrapError`.
  /// If the error came from the [Persistor] (see [action]), this is the error BEFORE being
  /// processed by [Persistor.wrapError].
  /// For an observer failure, this is the observer's error, not the action's error.
  late final Object originalError;

  /// The stack trace of the error.
  late final StackTrace stackTrace;

  /// The action that threw the error, or the action being observed when an
  /// [ActionObserver] or [StateObserver] failed. Check [errorSource] to distinguish
  /// these cases: a diagnostic error does not mean this action failed.
  ///
  /// This is `null` for errors from the [Persistor] or cloud sync. An observer's
  /// diagnostic keeps the action being observed, even when that action succeeded.
  /// Always check for `null` and [errorSource] before using it:
  ///
  /// ```dart
  /// Object? observe() {
  ///   if (action == null) log('Persistence error: $error');
  ///   else log('$errorSource related to ${action.runtimeType}: $error');
  ///   return error;
  /// }
  /// ```
  late final ReduxAction<St>? action;

  /// The component which produced this error. Persistence includes cloud sync.
  late final GlobalErrorSource errorSource;

  /// The failing ActionObserver or StateObserver, or null for other error sources.
  late final Object? observer;

  /// For an ActionObserver failure, true means INI and false means END.
  /// Null for all other error sources.
  late final bool? observerIni;

  /// You can access the store, but do NOT use it to dispatch actions,
  /// because the store is still processing the current action, and dispatching another
  /// action may cause unexpected behavior. You can use it to read the environment,
  /// configuration, and state, if they are relevant to the error you want to return.
  /// Example:
  ///
  /// ```dart
  /// Environment get environment => store.environment;
  /// Config get configuration => store.configuration;
  /// AppState get state => store.state;
  /// ```
  ///
  late Store<St> store;

  GlobalErrorObserver();

  /// Override this method to return the error you want to be used
  /// instead of the original error. Or, if you want to keep the original error,
  /// return it unaltered. If you want to disable the error, return `null`.
  Object? observe();

  void _init({
    required Object error,
    required Object? originalError,
    required StackTrace stackTrace,
    required ReduxAction<St>? action,
    required Store<St> store,
    required GlobalErrorSource errorSource,
    Object? observer,
    bool? observerIni,
  }) {
    this.error = error;
    this.originalError = originalError ?? '';
    this.stackTrace = stackTrace;
    this.action = action;
    this.store = store;
    this.errorSource = errorSource;
    this.observer = observer;
    this.observerIni = observerIni;
  }
}

/// A dummy global error observer that does nothing (same as not providing it).
///
/// See also: [GlobalErrorObserverForDevelopment] and [SwallowGlobalErrorObserver].
///
class GlobalErrorObserverDummy<St> extends GlobalErrorObserver<St> {
  @override
  Object? observe() => error;
}

/// During development you may use this global error observer if you want all errors
/// to be shown to the user in a dialog, not only [UserException]s.
///
/// In more detail:
///
/// - Wraps all errors into [UserException]s, and put them all into the error queue.
/// - Errors which are NOT originally [UserException]s will still be thrown.
///
/// Use it in the store like this:
///
/// ```dart
/// var store = Store(
///    globalErrorObserver: (store) => GlobalErrorObserverForDevelopment()
/// );
/// ```
///
/// See also: [GlobalErrorObserverDummy] and [SwallowGlobalErrorObserver].
///
class GlobalErrorObserverForDevelopment<St> extends GlobalErrorObserver<St> {
  @override
  Object? observe() {
    if (error is! UserException) {
      if (errorSource == GlobalErrorSource.actionObserver ||
          errorSource == GlobalErrorSource.stateObserver) {
        return UserException(error.toString()).addCause(error);
      }
      Future.microtask(() => store.dispatch(
            UserExceptionAction(error.toString(), cause: error),
          ));
    }

    return error;
  }
}

/// Swallows all errors (not recommended).
///
/// Use it in the store like this:
///
/// ```dart
/// var store = Store(
///    globalErrorObserver: (store) => SwallowGlobalErrorObserver()
/// );
/// ```
///
/// See also: [GlobalErrorObserverDummy] and [GlobalErrorObserverForDevelopment].
///
class SwallowGlobalErrorObserver<St> extends GlobalErrorObserver<St> {
  @override
  Object? observe() => null;
}

/// One failure kept for [Store.isFailed] and [Store.exceptionFor]: the action's
/// `statusKey` and its error.
class _Failure {
  final Object? statusKey;
  final Object error;

  _Failure(this.statusKey, this.error);
}
