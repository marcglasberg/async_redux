// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// Based upon packages redux by Brian Egan, and flutter_redux by Brian Egan and John Ryan.
// Uses code from package equatable by Felix Angelov.
// For more info, see: https://pub.dartlang.org/packages/async_redux

part of async_redux_store;

/// Actions must extend this class.
///
/// Important: Do NOT override operator == and hashCode. Actions must retain
/// their default [Object] comparison by identity, or the StoreTester may not work.
///
abstract class ReduxAction<St> {
  late Store<St> _store;
  late St _initialState;
  ActionStatus _status = ActionStatus();
  bool _completedFuture = false;

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
  St get initialState => _initialState;

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
  void setProp(Object? key, Object? value) => store.setProp(key, value);

  /// To wait for the next microtask: `await microtask;`
  Future get microtask => Future.microtask(() {});

  St get state => _store.state;

  /// Returns true only if the action finished with no errors.
  /// In other words, if the methods before, reduce and after all finished executing
  /// without throwing any errors.
  @Deprecated("Use `action.status.isCompletedOk` instead. This will be removed.")
  bool get isFinished => _status.isFinished;

  DateTime get stateTimestamp => _store.stateTimestamp;

  /// Dispatches the action, applying its reducer, and possibly changing the store state.
  /// The action may be sync or async.
  ///
  /// ```dart
  /// dispatch(MyAction());
  /// ```
  ///
  /// Method [dispatch] is of type [Dispatch].
  ///
  /// See also:
  /// - [dispatchSync] which dispatches sync actions, and throws if the action is async.
  /// - [dispatchAndWait] which dispatches both sync and async actions, and returns a Future.
  Dispatch<St> get dispatch => _store.dispatch;

  /// Dispatches the action, applying its reducer, and possibly changing the store state.
  /// However, if the action is ASYNC, it will throw a [StoreException].
  ///
  /// Method [dispatchSync] is of type [DispatchSync].
  ///
  /// See also:
  /// - [dispatch] which dispatches both sync and async actions.
  /// - [dispatchAndWait] which dispatches both sync and async actions, and returns a Future.
  DispatchSync<St> get dispatchSync => _store.dispatchSync;

  @Deprecated("Use `dispatchAndWait` instead. This will be removed.")
  DispatchAsync<St> get dispatchAsync => _store.dispatchAndWait;

  /// Dispatches the action, applying its reducer, and possibly changing the store state.
  /// The action may be sync or async. In both cases, it returns a [Future] that resolves when
  /// the action finishes.
  ///
  /// ```dart
  /// await dispatchAndWait(DoThisFirstAction());
  /// dispatch(DoThisSecondAction());
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
  /// var status = await dispatchAndWait(MyAction());
  /// ```
  ///
  /// See also:
  /// - [dispatch] which dispatches both sync and async actions.
  /// - [dispatchSync] which dispatches sync actions, and throws if the action is async.
  DispatchAndWait<St> get dispatchAndWait => _store.dispatchAndWait;

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
  bool isWaiting(Object actionOrTypeOrList) => _store.isWaiting(actionOrTypeOrList);

  /// This is an optional method that may be overridden to run during action
  /// dispatching, before `reduce`. If this method throws an error, the
  /// `reduce` method will NOT run, but the method `after` will.
  /// It may be synchronous (returning `void`) ou async (returning `Future<void>`).
  /// You should NOT return `FutureOr`.
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
  FutureOr<St?> reduce();

  /// You may wrap the reducer to allow for some pre or post-processing.
  /// For example, if you want to prevent an async reducer to change the current state,
  /// if the current state has already changed since when the reducer started:
  /// ```
  /// Reducer<St> wrapReduce(Reducer<St> reduce) => () async {
  ///    var oldState = state;
  ///    AppState? newState = await reduce();
  ///    return identical(oldState, state) ? newState : null;
  /// };
  /// ```
  ///
  /// Note: If you return a function that returns a `Future`, the action will be ASYNC.
  /// If you return a function that returns `St`, the action will be SYNC only if the
  /// `before` and `reduce` methods are also SYNC.
  ///
  Reducer<St> wrapReduce(Reducer<St> reduce) => reduce;

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
  Object? wrapError(Object error, StackTrace stackTrace) => error;

  /// If [abortDispatch] returns true, the action will NOT be dispatched: `before`, `reduce`
  /// and `after` will not be called, and the action will not be visible to the store observers.
  ///
  /// Note: No observer will be called. It will be as if the action was never dispatched.
  /// The action status will be `isDispatchAborted: true`.
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
  /// Using [abortDispatch] is only useful under rare circumstances, and you should
  /// only use it if you know what you are doing.
  ///
  /// See also:
  /// - [AbortDispatchException] which is a way to abort the action by throwing an exception.
  ///
  bool abortDispatch() => false;

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
  void assertUncompletedFuture() {
    scheduleMicrotask(() {
      _completedFuture = true;
    });
  }

  /// Returns true if the action is SYNC, and false if the action is ASYNC.
  /// The action is considered SYNC if the `before` method, the `reduce` method,
  /// and the `wrapReduce` methods are all synchronous.
  bool isSync() {
    //
    /// Must check that it's NOT `Future<void> Function()`, as `void Function()` doesn't work.
    bool beforeMethodIsSync = before is! Future<void> Function();

    bool reduceMethodIsSync = reduce is St? Function();

    bool wrapReduceMethodIsSync = wrapReduce(() => null) is! Future<St?> Function();

    return (beforeMethodIsSync && reduceMethodIsSync && wrapReduceMethodIsSync);
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
      identical(this, other) || other is AbortDispatchException && runtimeType == other.runtimeType;

  @override
  int get hashCode => 0;
}

/// The [UpdateStateAction] action is used to update the state of the Redux store, by applying
/// the given [updateFunction] to the current state.
class UpdateStateAction<St> extends ReduxAction<St> {
  //
  final St Function(St) updateFunction;

  UpdateStateAction(this.updateFunction);

  @override
  St reduce() => updateFunction(state);
}
