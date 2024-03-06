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
  final ActionStatus _status = ActionStatus();
  bool _completedFuture = false;

  void setStore(Store<St> store) => _store = store;

  Store<St> get store => _store;

  ActionStatus get status => _status;

  Object? get env => _store._environment;

  /// To wait for the next microtask: `await microtask;`
  Future get microtask => Future.microtask(() {});

  St get state => _store.state;

  /// Returns true only if the action finished with no errors.
  /// In other words, if the methods before, reduce and after all finished executing
  /// without throwing any errors.
  bool get isFinished => _status.isFinished;

  DateTime get stateTimestamp => _store.stateTimestamp;

  /// Dispatches the action, applying its reducer, and possibly changing the store state.
  /// The action may be sync or async.
  ///
  /// ```dart
  /// dispatch(new MyAction());
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
  /// await dispatchAndWait(new DoThisFirstAction());
  /// dispatch(new DoThisSecondAction());
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
  /// var status = await dispatchAndWait(new MyAction());
  /// ```
  ///
  /// See also:
  /// - [dispatch] which dispatches both sync and async actions.
  /// - [dispatchSync] which dispatches sync actions, and throws if the action is async.
  DispatchAndWait<St> get dispatchAndWait => _store.dispatchAndWait;

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
  /// For example, if you want to abort an async reducer if the state
  /// changed since when the reducer started:
  /// ```
  /// Reducer<St> wrapReduce(Reducer<St> reduce) => () async {
  ///    var oldState = state;
  ///    AppState? newState = await reduce();
  ///    return identical(oldState, state) ? newState : null;
  /// };
  /// ```
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

  /// If this returns true, the action will not be dispatched: `before`, `reduce`
  /// and `after` will not be called, and the action will not be visible to the
  /// `StoreTester`. This is only useful under rare circumstances, and you should
  /// only use it if you know what you are doing.
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

  /// Nest state reducers without dispatching another action.
  /// Example: return AddTaskAction(demoTask).reduceWithState(state);
  @Deprecated("This is deprecated and will be removed soon, "
      "because it's more difficult to use than it seems. "
      "Unless you completely understand what you're doing,"
      "you should only used it with sync reducers.")
  FutureOr<St?> reduceWithState(Store<St> store, St state) {
    setStore(store);
    _store.defineState(state);
    return reduce();
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
