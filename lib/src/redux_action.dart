// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// Based upon packages redux by Brian Egan, and flutter_redux by Brian Egan and John Ryan.
// Uses code from package equatable by Felix Angelov.
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

part of async_redux_store;

/// All actions you create must extend this class `ReduxAction`.
///
/// Important: Do NOT override operator == and hashCode. Actions must retain
/// their default [Object] comparison by identity, for AsyncRedux to work.
///
/// ---
///
/// This class comes with a lot of useful fields and methods:
///
/// Most important ones are:
///
/// > `state` - Returns current state in the store. This is a getter, and can change after every await, for async actions.
/// > `reduce` - The action reducer that returns the new state. Must be overridden.
/// > `dispatch` - Dispatches an action (sync or async).
/// > `dispatchAndWait` - Dispatches an action and returns a `Future` that resolves when it finishes.
/// > `isWaiting` - Checks if a specific action or action type is currently being processed.
/// > `isFailed` - Returns true if an action failed with a `UserException`.
///
/// Useful ones are:
///
/// > `store` - Returns the store instance.
/// > `before` - Optional method that runs before `reduce` during action dispatching.
/// > `after` - Optional method that runs after `reduce` during action dispatching.
/// > `wrapError` - Optionally catches or modifies errors thrown by `reduce` or `before` methods.
/// > `dispatchAndWaitAll` - Dispatches multiple actions in parallel and waits for all to finish.
/// > `dispatchAll` - Dispatches multiple actions in parallel.
/// > `dispatchSync` - Dispatches a sync action, throws if the action is async.
/// > `exceptionFor` - Returns the `UserException` of the action that failed.
/// > `clearExceptionFor` - Removes the given action type from the failed actions list.
/// > `initialState` - Returns the state as it was when the action was dispatched. This does NOT change.
/// > `waitCondition` - Returns a future that completes when the given state condition is true.
/// > `waitAllActions` - Returns a future that completes when all given actions finish.
/// > `status` - Returns the current status of the action (waiting, failed, completed, etc.).
/// > `prop` - Gets a property from the store (timers, streams, etc.).
/// > `setProp` - Sets a property in the store.
/// > `disposeProp` - Disposes a single property by its key.
/// > `disposeProps` - Disposes all or selected properties (timers, streams, futures).
/// > `env` - Gets the store environment, useful for global values scoped to the store.
/// > `microtask` - Returns a future that completes in the next microtask.
/// > `assertUncompletedFuture` - Asserts that an async reducer has at least one await.
///
/// Useful mixins:
///
/// > `CheckInternet` - Checks if there is internet before running the action, shows dialog if not.
/// > `NoDialog` - Used with `CheckInternet` to turn off the dialog when there is no internet.
/// > `AbortWhenNoInternet` - Silently aborts the action if there is no internet.
/// > `NonReentrant` - Prevents the action from being dispatched if it's already running.
/// > `Retry` - Retries the action if it fails, with configurable delays and max retries.
/// > `UnlimitedRetries` - Used with `Retry` to retry indefinitely.
/// > `OptimisticCommand` - Updates the state optimistically before saving to the cloud.
/// > `Throttle` - Ensures the action is dispatched at most once per throttle period.
/// > `Debounce` - Delays action execution until after a period of inactivity.
/// > `UnlimitedRetryCheckInternet` - Retries indefinitely with internet checking, prevents reentrant dispatches.
///
/// Finally, these are one-off methods that you may use in special situations:
///
/// > `stateTimestamp` - Returns the timestamp of the last state change.
/// > `wrapReduce` - Wraps the `reduce` method for pre/post-processing.
/// > `abortDispatch` - Returns true to abort the action dispatch before it runs.
/// > `isSync` - Returns true if the action is sync, false if async.
/// > `ifWrapReduceOverridden_Sync` - Returns true if `wrapReduce` is overridden synchronously.
/// > `ifWrapReduceOverridden_Async` - Returns true if `wrapReduce` is overridden asynchronously.
/// > `ifWrapReduceOverridden` - Returns true if `wrapReduce` is overridden (sync or async).
/// > `runtimeTypeString` - Returns the `runtimeType` without the generic part.
///
abstract class ReduxAction<St> {
  late Store<St> _store;
  late St _initialState;
  ActionStatus _status = ActionStatus(context: null);
  bool _completedFuture = false;

  @protected
  void setStore(Store<St> store) {
    _store = store;
    _status = _status.copy(context: (this, store));
    _initialState = _store.state;
  }

  /// Returns the state as it was when the action was dispatched.
  ///
  /// It can be the same or different from `this.state`, which is the current state in the store,
  /// because other actions may have changed the current state since this action was dispatched.
  ///
  /// In the case of SYNC actions that do not dispatch other SYNC actions,
  /// `this.state` and `this.initialState` will be the same.
  @protected
  St get initialState => _initialState;

  @protected
  Store<St> get store => _store;

  ActionStatus get status => _status;

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
  /// See also: [setProp] and [env].
  ///
  @protected
  V prop<V>(Object? key) => store.prop<V>(key);

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
  /// See also: [prop] and [env].
  ///
  @protected
  void setProp(Object? key, Object? value) => store.setProp(key, value);

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
  /// right before or after you called the [Store.shutdown] method.
  ///
  /// Example usage:
  ///
  /// ```dart
  /// // Dispose of all Timers, Futures, Stream related etc.
  /// disposeProps();
  ///
  /// // Dispose only Timers.
  /// disposeProps(({Object? key, Object? value}) => value is Timer);
  /// ```
  ///
  /// Note: The provided mixins, like [Polling], [Throttle], [Debounce] etc, also use
  /// some props that you can dispose by doing `store.internalMixinProps.clear()`;
  ///
  /// See also: [disposeProp], to dispose a single property by its key.
  ///
  @protected
  void disposeProps([bool Function({Object? key, Object? value})? predicate]) =>
      store.disposeProps(predicate);

  /// Uses [disposeProps] to dispose and a single property identified by
  /// its key [keyToDispose], and remove it from the props.
  ///
  /// This method will close/cancel/ignore the property if it's a Timer, Future,
  /// or Stream related object, and then remove it from the props.
  ///
  /// Example usage:
  ///
  /// ```dart
  /// // Dispose a specific timer property
  /// store.disposeProp("myTimer");
  /// ```
  @protected
  void disposeProp(Object? keyToDispose) => store.disposeProp(keyToDispose);

  /// To wait for the next microtask: `await microtask;`
  @protected
  Future get microtask => Future.microtask(() {});

  @protected
  St get state => _store.state;

  DateTime get stateTimestamp => _store.stateTimestamp;

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
  /// - [dispatchAll] which dispatches all given actions in parallel.
  /// - [dispatchSync] which dispatches sync actions, and throws if the action is async.
  /// - [dispatchAndWaitAll] which dispatches all given actions, and returns a Future.
  /// - [dispatchAndWait] which dispatches both sync and async actions, and returns a Future.
  /// - [dispatchState] which dispatches a sync action that applies a given reducer to the current state.
  ///
  @protected
  Dispatch<St> get dispatch => _store.dispatch;

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
  /// - [dispatchAll] which dispatches all given actions in parallel.
  /// - [dispatchAndWait] which dispatches both sync and async actions, and returns a Future.
  /// - [dispatchAndWaitAll] which dispatches all given actions, and returns a Future.
  /// - [dispatchState] which dispatches a sync action that applies a given reducer to the current state.
  ///
  @protected
  DispatchSync<St> get dispatchSync => _store.dispatchSync;

  @Deprecated("Use `dispatchAndWait` instead. This will be removed.")
  @protected
  DispatchAsync<St> get dispatchAsync => _store.dispatchAndWait;

  /// This is a shortcut, equivalent to:
  ///
  /// ```dart
  /// var status = dispatchSync(
  ///   UpdateStateAction.withReducer(state),
  /// );
  /// ```
  ///
  /// In other words, it dispatches a sync action that applies the given [state].
  ///
  /// If you pass the [notify] parameter as `false`, widgets will not
  /// necessarily rebuild because of this action, even if it changes the state.
  ///
  /// This dispatch method is to be used ONLY inside other actions, and is not
  /// available as an widget extension.
  ///
  /// See also:
  /// - [dispatch] which dispatches both sync and async actions.
  /// - [dispatchAll] which dispatches all given actions in parallel.
  /// - [dispatchAndWait] which dispatches both sync and async actions, and returns a Future.
  /// - [dispatchAndWaitAll] which dispatches all given actions, and returns a Future.
  ///
  @protected
  ActionStatus dispatchState(St state, {bool notify = true}) =>
      dispatchSync(UpdateStateAction(state), notify: notify);

  /// Dispatches the action, applying its reducer, and possibly changing the store state.
  /// The action may be sync or async. In both cases, it returns a [Future] that resolves when
  /// the action finishes.
  ///
  /// ```dart
  /// await store.dispatchAndWait(DoThisFirstAction());
  /// store.dispatch(DoThisSecondAction());
  /// ```
  ///
  /// If you pass the [notify] parameter as `false`, widgets will not necessarily rebuild
  /// because of this action, even if it changes the state.
  ///
  /// Note: While the state change from the action's reducer will have been applied when
  /// the Future resolves, other independent processes that the action may have started
  /// may still be in progress.
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
  /// - [dispatchAll] which dispatches all given actions in parallel.
  /// - [dispatchAndWaitAll] which dispatches all given actions, and returns a Future.
  /// - [dispatchSync] which dispatches sync actions, and throws if the action is async.
  /// - [dispatchState] which dispatches a sync action that applies a given reducer to the current state.
  ///
  @protected
  DispatchAndWait<St> get dispatchAndWait => _store.dispatchAndWait;

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
  /// - [dispatchState] which dispatches a sync action that applies a given reducer to the current state.
  ///
  @protected
  Future<List<ReduxAction<St>>> Function(List<ReduxAction<St>> actions, {bool notify})
      get dispatchAndWaitAll => _store.dispatchAndWaitAll;

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
  /// - [dispatchState] which dispatches a sync action that applies a given reducer to the current state.
  ///
  @protected
  List<ReduxAction<St>> Function(List<ReduxAction<St>> actions, {bool notify})
      get dispatchAll => _store.dispatchAll;

  /// This is an optional method that may be overridden to run during action
  /// dispatching, before `reduce`. If this method throws an error, the
  /// `reduce` method will NOT run, but the method `after` will.
  /// It may be synchronous (returning `void`) ou async (returning `Future<void>`).
  /// You should NOT return `FutureOr`.
  @protected
  FutureOr<void> before() {}

  /// This is an optional method that may be overridden to run during action
  /// dispatching, after `reduce`. If this method throws an error, the
  /// error will be swallowed (will not throw). So you should only run code that
  /// can't throw errors. It may be synchronous only.
  /// Note this method will always be called,
  /// even if errors were thrown by `before` or `reduce`.
  ///
  /// Note: For both synchronous and asynchronous actions, when after runs the store
  /// already contains the new state returned by reduce, so accessing [state] in [after]
  /// will return the new state.
  ///
  /// Note: Accessing [initialState] in [after] always returns the state as it was when
  /// the action was dispatched, regardless of when after runs.
  @protected
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
  @protected
  FutureOr<St?> reduce();

  /// You may override [wrapReduce] to wrap the [reduce] method and allow for
  /// some pre- or post-processing. For example, if you want to prevent an
  /// async reducer to change the current state in cases where the current
  /// state has already changed since when the reducer started:
  ///
  /// ```dart
  /// Future<St?> wrapReduce(Reducer<St> reduce) async {
  ///    var oldState = state;
  ///    AppState? newState = await reduce();
  ///    return identical(oldState, state) ? newState : null;
  /// };
  /// ```
  ///
  /// IMPORTANT:
  ///
  /// * Your [wrapReduce] method MUST always return `Future<St?>`. If it
  /// returns a `FutureOr`, it will NOT be called, and no error will be shown.
  /// This is because AsyncRedux uses the return type to determine if
  /// [wrapReduce] was overridden or not.
  ///
  /// * If [wrapReduce] returns `St` or `St?`, an error will be thrown.
  ///
  /// * Once you override [wrapReduce] the action will always be ASYNC,
  /// regardless of the [before] and [reduce] methods.
  ///
  /// See mixins [Retry], [Throttle], and [Debounce] for real [wrapReduce]
  /// examples.
  ///
  @protected
  FutureOr<St?> wrapReduce(Reducer<St> reduce) {
    return null;
  }

  /// If any error is thrown by `reduce` or `before`, you have the chance
  /// to further process it by using `wrapError`. Usually this is used to wrap
  /// the error inside of another that better describes the failed action.
  /// For example, if some action converts a String into a number, then instead of
  /// throwing a FormatException you could do:
  ///
  /// ```dart
  /// wrapError(error, _) => UserException("Please enter a valid number.", cause: error)
  /// ```
  ///
  /// If you want to disable the error you can return `null`. For example, if you want
  /// to disable errors of type `MyException`:
  ///
  /// ```dart
  /// wrapError(error, _) => (error is MyException) ? null : error
  /// ```
  ///
  /// If you don't want to modify the error, just return it unaltered
  /// (or don't override this method).
  ///
  /// See also:
  /// - [GlobalErrorObserver] which is a global way to wrap errors thrown by actions,
  ///   and is called after this method.
  ///
  @protected
  Object? wrapError(Object error, StackTrace stackTrace) => error;

  /// If [abortDispatch] returns true, the action will NOT be dispatched:
  /// `before`, `reduce` and `after` will not be called, and the action will not
  /// be visible to the store observers.
  ///
  /// Note: No observer will be called. It will be as if the action was never
  /// dispatched. The action status will be `isDispatchAborted: true`.
  ///
  /// For example, this mixin prevents reentrant actions (you can only call the
  /// action if it's not already running):
  ///
  /// ```dart
  /// /// This mixin prevents reentrant actions. You can only call the action if it's not already
  /// /// running. Example: `class LoadInfo extends ReduxAction<AppState> with NonReentrant { ... }`
  /// mixin NonReentrant implements ReduxAction<AppState> {
  ///   bool abortDispatch() => isWaiting(runtimeType);
  /// }
  /// ```
  ///
  /// Using [abortDispatch] is only useful under rare circumstances, and you should
  /// only use it if you know what you are doing.
  ///
  /// See also:
  /// - [AbortDispatchException] which is a way to abort the action by throwing an exception.
  ///
  @protected
  bool abortDispatch() => false;

  /// You can use [isWaiting] to check if:
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
  @protected
  bool isWaiting(Object actionOrTypeOrList) => _store.isWaiting(actionOrTypeOrList);

  /// Returns true if an [actionOrTypeOrList] failed with an [UserException].
  /// Note: This method uses the EXACT type in [actionOrTypeOrList]. Subtypes are not considered.
  @protected
  bool isFailed(Object actionOrTypeOrList) => _store.isFailed(actionOrTypeOrList);

  /// Returns the [UserException] of the [actionTypeOrList] that failed.
  ///
  /// [actionTypeOrList] can be a [Type], or an Iterable of types. Any other type
  /// of object will return null and throw a [StoreException] after the async gap.
  ///
  /// Note: This method uses the EXACT type in [actionTypeOrList]. Subtypes are not considered.
  @protected
  UserException? exceptionFor(Object actionTypeOrList) =>
      _store.exceptionFor(actionTypeOrList);

  /// Removes the given [actionTypeOrList] from the list of action types that failed.
  ///
  /// Note that dispatching an action already removes that action type from the exceptions list.
  /// This removal happens as soon as the action is dispatched, not when it finishes.
  ///
  /// [actionTypeOrList] can be a [Type], or an Iterable of types. Any other type
  /// of object will return null and throw a [StoreException] after the async gap.
  ///
  /// Note: This method uses the EXACT type in [actionTypeOrList]. Subtypes are not considered.
  @protected
  void clearExceptionFor(Object actionTypeOrList) =>
      _store.clearExceptionFor(actionTypeOrList);

  /// Returns a future which will complete when the given state [condition] is true.
  /// If the condition is already true when the method is called, the future completes immediately.
  ///
  /// You may also provide a [timeoutMillis], which by default is 10 minutes.
  /// To disable the timeout, make it -1.
  /// If you want, you can modify [Store.defaultTimeoutMillis] to change the default timeout.
  ///
  /// ```dart
  /// var action = await store.waitCondition((state) => state.name == "Bill");
  /// expect(action, isA<ChangeNameAction>());
  /// ```
  @protected
  Future<ReduxAction<St>?> waitCondition(
    bool Function(St) condition, {
    int? timeoutMillis,
  }) =>
      _store.waitCondition(condition, timeoutMillis: timeoutMillis);

  /// Returns a future that completes when ALL given [actions] finished dispatching.
  /// You MUST provide at least one action, or a [StoreException] will be thrown.
  ///
  /// If [completeImmediately] is `false` (the default), this method throws a [StoreException]
  /// if none of the given actions is in progress when the method is called (for example,
  /// because they already finished). If it's `true`, the future completes immediately
  /// and throws no error.
  ///
  /// This method never times out. It waits for as long as it takes for the given actions
  /// to finish. If you need a deadline, apply it to the awaited actions themselves, or use
  /// Dart's `Future.timeout`.
  ///
  /// Example:
  ///
  /// ```dart
  /// // Dispatching two actions in PARALLEL and waiting for both to finish.
  /// var action1 = ChangeNameAction('Bill');
  /// var action2 = ChangeAgeAction(42);
  /// dispatch(action1);
  /// dispatch(action2);
  /// await waitAllActions([action1, action2]);
  ///
  /// // Compare this to dispatching the actions in SERIES:
  /// await dispatchAndWait(action1);
  /// await dispatchAndWait(action2);
  /// ```
  ///
  /// The current action itself is ignored if present in [actions]. The current action is
  /// in progress while its reducer runs, so waiting for it would never complete (a deadlock).
  /// If [actions] contains only the current action, there is nothing else to wait for, and
  /// the future completes immediately.
  ///
  /// WARNING: The current action stays in progress while it waits, and the wait never times
  /// out, so waiting for an action that, directly or indirectly, waits for the current action
  /// is a deadlock: both hang forever. Only wait for actions that never wait for you. See
  /// [waitActionType] for a detailed description of the cases to avoid, and note that this
  /// method is not a way to make actions run one at a time. For that, use the [Sequential]
  /// mixin.
  @protected
  Future<void> waitAllActions(List<ReduxAction<St>> actions,
      {bool completeImmediately = false}) {
    if (actions.isEmpty)
      throw StoreException('You have to provide a non-empty list of actions.');

    // The current action is in progress, so waiting for it would deadlock.
    var otherActions = actions.where((action) => !identical(action, this)).toList();

    // Nothing else to wait for.
    if (otherActions.isEmpty) return Future.value();

    return _store.waitAllActions(otherActions,
        completeImmediately: completeImmediately, timeoutMillis: -1);
  }

  /// Returns a future that completes when NO action of the given type is in progress
  /// (none is being dispatched):
  ///
  /// - If NO action of the given type is in progress when the method is called,
  ///   the future completes immediately and returns `null`.
  ///
  /// - If an action of the given type is in progress, the future completes when the last
  ///   action of that type finishes, and returns that action. You can use the returned
  ///   action to check its `status`.
  ///
  /// This method never throws because nothing was in progress, and it never times out.
  /// It waits for as long as it takes for the awaited type to finish. If you need a
  /// deadline, apply it to the awaited action itself, or use Dart's `Future.timeout`.
  ///
  /// # Intended use
  ///
  /// This method is for one-directional dependencies: the current action needs data that
  /// another action may be producing right now. For example, if a `LoadUser` action may be
  /// running, wait for it to finish before reading the user from the state:
  ///
  /// ```dart
  /// class ShowGreeting extends ReduxAction<AppState> {
  ///   Future<AppState?> reduce() async {
  ///     // If LoadUser is running, let it finish first. If not, continue at once.
  ///     await waitActionType(LoadUser);
  ///     return state.copy(greeting: 'Hello, ${state.user.name}');
  ///   }
  /// }
  /// ```
  ///
  /// # WARNING: Do NOT use this method to run actions one at a time
  ///
  /// This method is NOT a lock or a queue, and it CANNOT make actions run sequentially:
  ///
  /// - It gives no exclusivity. When the awaited type becomes idle, ALL actions waiting for
  ///   it resume at the same time, and a new action of that type may start right after.
  ///
  /// - It gives no ordering. Waiting actions resume in no particular order.
  ///
  /// - It may starve. It completes only at an instant when NO action of the type is in
  ///   progress. If actions of that type are dispatched often enough that they overlap, that
  ///   instant may never come, and the current action never completes.
  ///
  /// If your goal is to make actions run one at a time, in order, use the [Sequential] mixin
  /// instead. To simply drop an action while another of the same type is running, use the
  /// [NonReentrant] mixin.
  ///
  /// # WARNING: Deadlocks
  ///
  /// The current action stays in progress while it waits, and the wait never times out.
  /// Any wait that, directly or indirectly, depends on the current action finishing is a
  /// deadlock: all involved actions hang forever, showing as waiting (spinners stay on) and
  /// never completing or failing. Cases to avoid:
  ///
  /// - **Waiting for your own type.** Since this can never complete, it throws a
  ///   [StoreException] right away instead of hanging.
  ///
  /// - **Circular waits.** `ActionA` waits for `ActionB` while `ActionB` waits for `ActionA`.
  ///   Cycles may be longer (`A` waits for `B`, `B` waits for `C`, `C` waits for `A`), and
  ///   may pass through dispatch: `A` waits for type `B` while `B` does
  ///   `await dispatchAndWait(A())`, since the new `A` also waits for `B`. The rule is: only
  ///   wait for actions that never wait for you, directly or indirectly. Your wait
  ///   dependencies must form no cycles.
  ///
  /// - **Waiting for an action queued behind you.** If the current action uses the
  ///   [Sequential] mixin, do not wait for the type of an action that may be in the same
  ///   queue. Queued actions count as in progress while they wait for their turn, and they
  ///   cannot start until the current action finishes.
  ///
  /// - **Waiting for an action that waits for the state you produce.** This is a circular
  ///   wait through [waitCondition]: don't wait for an action whose reducer awaits a state
  ///   change that only the current action makes.
  ///
  /// # Aborting instead of waiting
  ///
  /// If, instead of waiting for `Action1` to finish, you want to abort the current action
  /// while `Action1` is running, add this to the current action:
  ///
  /// ```dart
  /// bool abortDispatch() => isWaiting(Action1);
  /// ```
  ///
  /// See also:
  /// [waitCondition] - Waits until the state is in a given condition.
  /// [waitAllActions] - Waits until the given actions are NOT in progress.
  /// [waitAllActionTypes] - Waits until no action of the given types is in progress.
  ///
  Future<ReduxAction<St>?> waitActionType(Type actionType) {
    if (actionType == runtimeType)
      throw StoreException('Action $runtimeType cannot wait for its own type '
          'with waitActionType($runtimeType), because it would wait forever for itself '
          'to finish. To run actions of the same type one at a time, '
          'use the Sequential mixin instead.');

    return _store.waitActionType(actionType, completeImmediately: true, timeoutMillis: -1);
  }

  /// Returns a future that completes when NO action of the given types is in progress
  /// (none of them is being dispatched):
  ///
  /// - If NO action of the given types is in progress when the method is called,
  ///   the future completes immediately.
  ///
  /// - If any action of the given types is in progress, the future completes only when
  ///   no action of the given types is in progress anymore.
  ///
  /// This method never throws because nothing was in progress, and it never times out.
  /// It waits for as long as it takes for the awaited types to finish. If you need a
  /// deadline, apply it to the awaited actions themselves, or use Dart's `Future.timeout`.
  ///
  /// You MUST provide at least one action type, or a [StoreException] will be thrown.
  ///
  /// The type of the current action itself is ignored if present in [actionTypes], since
  /// the current action is in progress while its reducer runs, and waiting for its own type
  /// would never complete. If [actionTypes] contains only the current action's own type,
  /// there is nothing else to wait for, and the future completes immediately.
  ///
  /// # Intended use
  ///
  /// This method is for one-directional dependencies: the current action needs data that
  /// other actions may be producing right now. For example, if `LoadUser` and
  /// `LoadSettings` may be running, wait for both to finish before reading the state:
  ///
  /// ```dart
  /// class ShowGreeting extends ReduxAction<AppState> {
  ///   Future<AppState?> reduce() async {
  ///     // If any of these is running, let them finish first. If not, continue at once.
  ///     await waitAllActionTypes([LoadUser, LoadSettings]);
  ///     return state.copy(greeting: '${state.settings.salutation}, ${state.user.name}');
  ///   }
  /// }
  /// ```
  ///
  /// # WARNING: Do NOT use this method to run actions one at a time
  ///
  /// This method is NOT a lock or a queue, and it CANNOT make actions run sequentially. It
  /// gives no exclusivity (all actions waiting for the same types resume at the same time,
  /// and new actions of those types may start right after), it gives no ordering, and it may
  /// starve if actions of the given types are dispatched often enough that they overlap.
  /// In particular, having `ActionA`, `ActionB` and `ActionC` each wait for
  /// `[ActionA, ActionB, ActionC]` does NOT make them run one at a time. It deadlocks
  /// as soon as two of them run at the same time, because each waits for the other.
  ///
  /// If your goal is to make actions run one at a time, in order, use the [Sequential] mixin
  /// instead. To simply drop an action while another of the same type is running, use the
  /// [NonReentrant] mixin.
  ///
  /// # WARNING: Deadlocks
  ///
  /// The current action stays in progress while it waits, and the wait never times out.
  /// Any wait that, directly or indirectly, depends on the current action finishing is a
  /// deadlock: all involved actions hang forever, showing as waiting (spinners stay on) and
  /// never completing or failing. Avoid circular waits (`A` waits for `B` while `B` waits
  /// for `A`, including longer cycles and cycles that pass through `dispatchAndWait` or
  /// [waitCondition]), and avoid waiting for an action that may be queued behind the current
  /// one in a [Sequential] queue. The rule is: only wait for actions that never wait for
  /// you, directly or indirectly.
  ///
  /// See the documentation of [waitActionType] for a detailed description of each of these
  /// cases.
  ///
  /// # Aborting instead of waiting
  ///
  /// If, instead of waiting for `Action1` and `Action2` to finish, you want to abort the
  /// current action while any of them is running, add this to the current action:
  ///
  /// ```dart
  /// bool abortDispatch() => isWaiting([Action1, Action2]);
  /// ```
  ///
  /// See also:
  /// [waitCondition] - Waits until the state is in a given condition.
  /// [waitAllActions] - Waits until the given actions are NOT in progress.
  /// [waitActionType] - Waits until no action of the given type is in progress.
  ///
  Future<void> waitAllActionTypes(List<Type> actionTypes) {
    if (actionTypes.isEmpty)
      throw StoreException('You have to provide a non-empty list of action types.');

    // The current action is in progress, so waiting for its own type would deadlock.
    var otherTypes = actionTypes.where((type) => type != runtimeType).toList();

    // Nothing else to wait for.
    if (otherTypes.isEmpty) return Future.value();

    return _store.waitAllActionTypes(otherTypes, completeImmediately: true, timeoutMillis: -1);
  }

  /// An async reducer (one that returns Future<AppState?>) must never complete without at least
  /// one await, because this may result in state changes being lost. It's up to you to make sure
  /// all code paths in the reducer pass through at least one `await`.
  ///
  /// Futures defined by async functions with no `await` are called "completed futures".
  /// It's generally easy to make sure an async reducer does not return a completed future.
  /// In the rare case when your reducer function is complex and you are unsure that all
  /// code paths pass through an await, there are 3 possible solutions:
  ///
  ///
  /// * Simplify your reducer, by applying clean-code techniques. That will make it easier for you
  /// to make sure all code paths have 'await'.
  ///
  /// * Add `await microtask;` to the very START of the reducer.
  ///
  /// * Call method [assertUncompletedFuture] at the very END of your [reduce] method, right before
  /// the return. If you do that, an error will be shown in the console in case the reduce method
  /// ever returns a completed future. Note there is no other way for AsyncRedux to warn you if
  /// your reducer returned a completed future, because although the completion information exists
  /// in the `FutureImpl` class, it's not exposed. Also note, the error will be thrown
  /// asynchronously (will not stop the action from returning a state).
  ///
  @protected
  void assertUncompletedFuture() {
    scheduleMicrotask(() {
      _completedFuture = true;
    });
  }

  @protected
  bool ifWrapReduceOverridden_Sync() => wrapReduce is St? Function(Reducer<St>);

  @protected
  bool ifWrapReduceOverridden_Async() => wrapReduce is Future<St?> Function(Reducer<St>);

  @protected
  bool ifWrapReduceOverridden() =>
      ifWrapReduceOverridden_Async() || ifWrapReduceOverridden_Sync();

  /// Returns true if the action is SYNC, and false if the action is ASYNC.
  /// The action is considered SYNC if the `before` method, the `reduce` method,
  /// and the `wrapReduce` methods are all synchronous.
  bool isSync() {
    //
    /// Must check that it's NOT `Future<void> Function()`, as `void Function()` doesn't work.
    bool beforeMethodIsSync = before is! Future<void> Function();
    if (!beforeMethodIsSync) return false;

    bool reduceMethodIsSync = reduce is St? Function();
    if (!reduceMethodIsSync) return false;

    // `wrapReduce` is sync if it's not overridden.
    // `wrapReduce` is sync if it's overridden and SYNC.
    // `wrapReduce` is NOT sync if it's overridden and ASYNC.
    return (!ifWrapReduceOverridden_Async());
  }

  /// Returns the runtimeType, without the generic part.
  String runtimeTypeString() {
    var text = runtimeType.toString();
    var pos = text.indexOf('<');
    return (pos == -1) ? text : text.substring(0, pos);
  }

  @override
  String toString() => 'Action ${runtimeTypeString()}';
}

/// If an action throws an [AbortDispatchException] the action will abort immediately
/// (But note the `after` method will still be called no mather what).
/// The action status will be `isDispatchAborted: true`.
///
/// You can use it in the `before` method to abort the action before the `reduce` method
/// is called. That's similar to throwing an `UserException`, but without showing any
/// errors to the user.
///
/// For example, this mixin prevents reentrant actions (you can only call the action if it's not
/// already running):
///
/// ```dart
/// /// This mixin prevents reentrant actions. You can only call the action if it's not already
/// /// running. Example: `class LoadInfo extends ReduxAction<AppState> with NonReentrant { ... }`
/// mixin NonReentrant implements ReduxAction<AppState> {
///   bool abortDispatch() => isWaiting(runtimeType);
/// }
/// ```
///
/// See also:
/// - [ReduxAction.abortDispatch] which is a way to abort the action's dispatch.
///
class AbortDispatchException implements Exception {
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AbortDispatchException && runtimeType == other.runtimeType;

  @override
  int get hashCode => 0;
}

/// The [UpdateStateAction] action is used to update the state of the Redux
/// store, by applying the given [reducerFunction] to the current state.
///
/// Note that inside actions you can directly use [ReduxAction.dispatchState]
/// which is a shortcut to dispatch an [UpdateStateAction].
///
class UpdateStateAction<St> extends ReduxAction<St> {
  //
  final St? Function(St) reducerFunction;

  /// When you don't need to use the current state to create the new state, you
  /// can use the `UpdateStateAction` factory.
  ///
  /// Example:
  /// ```
  /// var newState = AppState(...);
  /// store.dispatch(UpdateStateAction(newState));
  /// ```
  factory UpdateStateAction(St state) => UpdateStateAction.withReducer((_) => state);

  /// When you need to use the current state to create the new state, you
  /// can use `UpdateStateAction.withReducer`.
  ///
  /// Example:
  /// ```
  /// store.dispatch(UpdateStateAction.withReducer((state) => state.copy(...)));
  /// ```
  UpdateStateAction.withReducer(this.reducerFunction);

  @override
  St? reduce() => reducerFunction(state);
}
