part of async_redux_store;

// Developed by Marcelo Glasberg (Aug 2019).
// Based upon packages redux by Brian Egan, and flutter_redux by Brian Egan and John Ryan.
// Uses code from package equatable by Felix Angelov.
// For more info, see: https://pub.dartlang.org/packages/async_redux

/// Actions must extend this class.
///
/// Important: Do NOT override operator == and hashCode. Actions must retain
/// their default [Object] comparison by identity, or the StoreTester may not work.
///
abstract class ReduxAction<St> {
  late Store<St> _store;
  final ActionStatus _status = ActionStatus();

  void setStore(Store<St> store) => _store = store;

  Store<St> get store => _store;

  ActionStatus get status => _status;

  Object? get env => _store._environment;

  St get state => _store.state;

  /// Returns true only if the action finished with no errors.
  /// In other words, if the methods before, reduce and after all finished executing
  /// without throwing any errors.
  bool get isFinished => _status.isFinished;

  @Deprecated("Use `isFinished` instead. This will be removed soon.")
  bool get hasFinished => _status.isFinished;

  DateTime get stateTimestamp => _store.stateTimestamp;

  Dispatch<St> get dispatch => _store.dispatch;

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
  ///     wrapError(error) => UserException("Please enter a valid number.", error: error)
  ///
  /// If you want to disable the error you can return `null`. For example, if you want
  /// to disable errors of type `MyException`:
  ///
  ///     wrapError(error) => (error is MyException) ? null : error
  ///
  /// IMPORTANT: The action [wrapError] behaves differently from the global [WrapError]
  /// because returning `null` will DISABLE the error, while in the global [WrapError]
  /// returning `null` will keep the error unchanged. This difference is confusing,
  /// and I will, in the future, change the global [WrapError] to match the action.
  Object? wrapError(error) => error;

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
  FutureOr<St?> reduceWithState(Store<St> store, St state) {
    setStore(store);
    _store.defineState(state);
    return reduce();
  }

  /// Returns the runtimeType, without the generic part.
  String runtimeTypeString() {
    var text = runtimeType.toString();
    return text.substring(0, text.indexOf('<'));
  }

  @override
  String toString() => 'Action ${runtimeTypeString()}';
}

// /////////////////////////////////////////////////////////////////////////////
