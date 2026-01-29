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
  ActionStatus _status = ActionStatus();
  bool _completedFuture = false;

  @protected
  void setStore(Store<St> store) {
    _store = store;
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

  /// Gets the store environment.
  /// This can be used to create a global value, but scoped to the store.
  /// For example, you could have a service locator, here, or a configuration value.
  ///
  /// See also: [prop] and [setProp].
  Object? get env => _store.env;

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
  /// Note: The provided mixins, like [Throttle] and [Debounce] also use some
  /// props that you can dispose by doing `store.internalMixinProps.clear()`;
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

  /// Returns true only if the action finished with no errors.
  /// In other words, if the methods before, reduce and after all finished executing
  /// without throwing any errors.
  @Deprecated(
      "Use `action.status.isCompletedOk` instead. This will be removed.")
  bool get isFinished => _status.isFinished;

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
  Future<List<ReduxAction<St>>> Function(List<ReduxAction<St>> actions,
      {bool notify}) get dispatchAndWaitAll => _store.dispatchAndWaitAll;

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
  /// - [GlobalWrapError] which is a global error wrapper that will be called after this one.
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
  bool isWaiting(Object actionOrTypeOrList) =>
      _store.isWaiting(actionOrTypeOrList);

  /// Returns true if an [actionOrTypeOrList] failed with an [UserException].
  /// Note: This method uses the EXACT type in [actionOrTypeOrList]. Subtypes are not considered.
  @protected
  bool isFailed(Object actionOrTypeOrList) =>
      _store.isFailed(actionOrTypeOrList);

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
  /// You MUST provide at list one action, or an error will be thrown.
  ///
  /// If [completeImmediately] is `false` (the default), this method will throw [StoreException]
  /// if none of the given actions are in progress when the method is called. Otherwise, the future
  /// will complete immediately and throw no error.
  ///
  /// Example:
  ///
  /// ```ts
  /// // Dispatching two actions in PARALLEL and waiting for both to finish.
  /// var action1 = ChangeNameAction('Bill');
  /// var action2 = ChangeAgeAction(42);
  /// await waitAllActions([action1, action2]);
  ///
  /// // Compare this to dispatching the actions in SERIES:
  /// await dispatchAndWait(action1);
  /// await dispatchAndWait(action2);
  /// ```
  @protected
  Future<void> waitAllActions(List<ReduxAction<St>> actions,
      {bool completeImmediately = false}) {
    if (actions.isEmpty)
      throw StoreException('You have to provide a non-empty list of actions.');
    return _store.waitAllActions(actions,
        completeImmediately: completeImmediately);
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
  bool ifWrapReduceOverridden_Async() =>
      wrapReduce is Future<St?> Function(Reducer<St>);

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
  factory UpdateStateAction(St state) =>
      UpdateStateAction.withReducer((_) => state);

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
