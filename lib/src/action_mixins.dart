import 'dart:async';
import 'package:async_redux/async_redux.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// This mixin can be used to check if there is internet when you run some action that needs
/// internet connection. Just add `with CheckInternet` to your action. For example:
///
/// ```dart
/// class LoadText extends ReduxAction<AppState> with CheckInternet {
///   Future<String> reduce() async {
///     var response = await http.get('http://numbersapi.com/42');
///     return response.body;
///   }}
/// ```
///
/// I will automatically check if there is internet before running the action. If there is no
/// internet, the action will fail, stop executing, and will show a dialog to the user
/// with title: 'There is no Internet' and content: 'Please, verify your connection.'.
///
/// Also, you can display some information in your widgets when the action fails:
///
/// ```dart
/// if (context.isFailed(LoadText)) Text('No Internet connection');
/// ```
///
/// Or you can use the exception text itself:
/// ```dart
/// if (context.isFailed(LoadText)) Text(context.exceptionFor(LoadText)?.errorText ?? 'No Internet connection');
/// ```
///
/// If you don't want the dialog to open, you can add the [NoDialog] mixin.
///
/// If you want to customize the dialog or the `errorText`, you can override the
/// method [connectionException] and return an [UserException] with the desired message.
///
/// IMPORTANT: It only checks if the internet is on or off on the device, not if the internet
/// provider is really providing the service or if the server is available. So, it is possible that
/// this function returns true and the request still fails.
///
/// Notes:
/// - This mixin can safely be combined with [NonReentrant].
/// - It should not be combined with other mixins that override [before].
/// - It should not be combined with other mixins that check the internet connection.
///
/// See also:
/// * [NoDialog] - To just show a message in your widget, and not open a dialog.
/// * [AbortWhenNoInternet] - If you want to silently abort the action when there is no internet.
///
mixin CheckInternet<St> on ReduxAction<St> {
  bool get ifOpenDialog => true;

  UserException connectionException(ConnectivityResult result) =>
      ConnectionException.noConnectivity;

  /// If you are running tests, you can override this method to simulate the internet connection
  /// as permanently on or off.
  /// Return `true` if there is internet, and `false` if there is no internet.
  /// Return `null` to use the real internet connection status.
  bool? get internetOnOffSimulation => forceInternetOnOffSimulation();

  /// If you have a configuration object that specifies if the internet connection should be
  /// simulated as on or off, you can replace this method to return that configuration value.
  /// For example: `CheckInternet.forceInternetOnOffSimulation = () => Config.isInternetOn;`
  /// Return `true` if there is internet, and `false` if there is no internet.
  /// Return `null` to use the real internet connection status.
  static bool? Function() forceInternetOnOffSimulation = () => null;

  Future<ConnectivityResult> checkConnectivity() async {
    if (internetOnOffSimulation != null)
      return internetOnOffSimulation! ? ConnectivityResult.wifi : ConnectivityResult.none;

    return await (Connectivity().checkConnectivity());
  }

  @override
  Future<void> before() async {
    var result = await checkConnectivity();

    if (result == ConnectivityResult.none)
      throw connectionException(result).withDialog(ifOpenDialog);
  }
}

/// This mixin can only be applied on [CheckInternet]. Example:
///
/// ```dart
/// class LoadText extends ReduxAction<AppState> with CheckInternet, NoDialog {
///   Future<String> reduce() async {
///     var response = await http.get('http://numbersapi.com/42');
///     return response.body;
///   }}
/// ```
///
/// It will turn off showing a dialog when there is no internet. But you can still display
/// some information in your widgets:
///
/// ```dart
/// if (context.isFailed(LoadText)) Text('No Internet connection');
/// ```
///
/// Or you can use the exception text itself:
/// ```dart
/// if (context.isFailed(LoadText)) Text(context.exceptionFor(LoadText)?.errorText ?? 'No Internet connection');
/// ```
///
mixin NoDialog<St> on CheckInternet<St> {
  @override
  bool get ifOpenDialog => false;
}

/// This mixin can be used to check if there is internet when you run some action that needs it.
/// If there is no internet, the action will abort silently, as if it had never been dispatched.
///
/// Just add `with AbortWhenNoInternet<AppState>` to your action. For example:
///
/// ```dart
/// class LoadText extends ReduxAction<AppState> with AbortWhenNoInternet<AppState> {
///   Future<String> reduce() async {
///     var response = await http.get('http://numbersapi.com/42');
///     return response.body;
///   }}
/// ```
///
/// IMPORTANT: It only checks if the internet is on or off on the device, not if the internet
/// provider is really providing the service or if the server is available. So, it is possible that
/// this function returns true and the request still fails.
///
/// Notes:
/// - This mixin can safely be combined with [NonReentrant].
/// - It should not be combined with other mixins that override [before].
/// - It should not be combined with other mixins that check the internet connection.
///
/// See also:
/// * [CheckInternet] - If you want to show a dialog to the user when there is no internet.
/// * [NoDialog] - To just show a message in your widget, and not open a dialog.
///
mixin AbortWhenNoInternet<St> on ReduxAction<St> {
  /// If you are running tests, you can override this method to simulate the internet connection
  /// as permanently on or off.
  /// Return `true` if there is internet, and `false` if there is no internet.
  /// Return `null` to use the real internet connection status.
  bool? get internetOnOffSimulation => CheckInternet.forceInternetOnOffSimulation();

  Future<ConnectivityResult> checkConnectivity() async {
    if (internetOnOffSimulation != null)
      return internetOnOffSimulation! ? ConnectivityResult.wifi : ConnectivityResult.none;

    return await (Connectivity().checkConnectivity());
  }

  @override
  Future<void> before() async {
    var result = await checkConnectivity();
    if (result == ConnectivityResult.none) throw AbortDispatchException();
  }
}

/// This mixin can be used to abort the action in case the action is still running from
/// a previous dispatch. Just add `with NonReentrant<AppState>` to your action. For example:
///
/// ```dart
/// class SaveAction extends ReduxAction<AppState> with NonReentrant<AppState> {
///   Future<String> reduce() async {
///     await http.put('http://myapi.com/save', body: 'data');
///   }}
/// ```
///
/// Notes:
/// - This mixin can safely be combined with [CheckInternet], [NoDialog], and [AbortWhenNoInternet].
/// - It should not be combined with other mixins that override [abortDispatch].
mixin NonReentrant<St> on ReduxAction<St> {
  @override
  bool abortDispatch() => isWaiting(runtimeType);
}

/// This mixin will retry the [reduce] method if it throws an error.
/// Note: If the `before` method throws an error, the retry will NOT happen.
///
/// * Initial Delay: The delay before the first retry attempt.
/// * Multiplier: The factor by which the delay increases for each subsequent retry.
/// * Maximum Retries: The maximum number of retries before giving up.
/// * Maximum Delay: The maximum delay between retries to avoid excessively long wait times.
///
/// Default Parameters:
/// * [initialDelay] is `350` milliseconds.
/// * [multiplier] is `2`, which means the default delays are: 350 millis, 700 millis, and 1.4 seg.
/// * [maxRetries] is `3`, meaning it will try a total of 4 times.
/// * [maxDelay] is `5` seconds.
///
/// If you want to retry unlimited times, you can add the [UnlimitedRetries] mixin.
///
/// Note: The retry delay only starts after the reducer finishes executing. For example,
/// if the reducer takes 1 second to fail, and the retry delay is 350 millis, the first
/// retry will happen 1.35 seconds after the first reducer started.
///
/// When the action finally fails, the last error will be rethrown, and the previous ones will
/// be ignored.
///
/// You should NOT combine this with [CheckInternet] or [AbortWhenNoInternet],
/// because the retry will not work.
///
/// However, for most actions that use [Retry], consider also adding [NonReentrant] to avoid
/// multiple instances of the same action running at the same time:
///
/// ```dart
/// class MyAction extends ReduxAction<AppState> with Retry, NonReentrant { ... }
/// ```
///
/// Keep in mind that all actions using the [Retry] mixin will become asynchronous,
/// even if the original action was synchronous.
///
mixin Retry<St> on ReduxAction<St> {
  //
  /// The delay before the first retry attempt.
  Duration get initialDelay => const Duration(milliseconds: 350);

  /// The factor by which the delay increases for each subsequent retry.
  /// Must be greater than 1, otherwise it will be set to 2.
  double get multiplier => 2;

  /// The maximum number of retries before giving up.
  /// Must be greater than 0, otherwise it will not retry.
  /// The total number of attempts is maxRetries + 1.
  int get maxRetries => 3;

  /// The maximum delay between retries to avoid excessively long wait times.
  /// The default is 5 seconds.
  Duration get maxDelay => const Duration(milliseconds: 5000);

  int _attempts = 0;

  /// The number of retry attempts so far. If the action has not been retried yet, it will be 0.
  /// If the action finished successfully, it will be equal or less than [maxRetries].
  /// If the action failed and gave up, it will be equal to [maxRetries] plus 1.
  int get attempts => _attempts;

  @override
  Reducer<St> wrapReduce(Reducer<St> reduce) => () async {
        FutureOr<St?> newState;
        try {
          newState = reduce();
          if (newState is Future) newState = await newState;
        } catch (error) {
          _attempts++;
          if ((maxRetries >= 0) && (_attempts > maxRetries)) rethrow;

          var currentDelay = nextDelay();
          await Future.delayed(currentDelay);
          return wrapReduce(reduce)();
        }
        return newState;
      };

  Duration? _currentDelay;

  /// Start with the [initialDelay], and then increase it by [multiplier] each time this is called.
  /// If the delay exceeds [maxDelay], it will be set to [maxDelay].
  Duration nextDelay() {
    var _multiplier = multiplier;
    if (_multiplier <= 1) _multiplier = 2;

    _currentDelay = (_currentDelay == null) //
        ? initialDelay //
        : _currentDelay! * _multiplier;

    if (_currentDelay! > maxDelay) _currentDelay = maxDelay;

    return _currentDelay!;
  }
}

/// Add [UnlimitedRetries] to the [Retry] mixin, to retry indefinitely:
///
/// ```dart
/// class MyAction extends ReduxAction<AppState> with Retry, UnlimitedRetries { ... }
/// ```
///
/// This is the same as setting [maxRetries] to -1.
///
/// Note: If you `await dispatchAndWait(action)` and the action uses [UnlimitedRetries],
/// it may never finish if it keeps failing. So, be careful when using it.
///
mixin UnlimitedRetries<St> on Retry<St> {
  @override
  int get maxRetries => -1;
}

/// The [OptimisticUpdate] mixin is still EXPERIMENTAL. You can use it, but test it well.
/// ---
///
/// Let's use a "Todo" app as an example. We want to save a new Todo to a TodoList.
///
/// This code saves the Todo, then reloads the TotoList from the cloud:
///
/// ```dart
/// class SaveTodo extends ReduxAction<AppState> {
///    final Todo newTodo;
///    SaveTodo(this.newTodo);
///
///    Future<AppState> reduce() async {
///
///       try {
///          // Saves the new Todo to the cloud.
///          await saveTodo(newTodo);
///       }
///       finally {
///          // Loads the complete TodoList from the cloud.
///          var reloadedTodoList = await loadTodoList();
///          return state.copy(todoList: reloadedTodoList);
///       }
///    }
/// }
/// ```
///
/// The problem with the above code is that it make take a second to update the todoList in
/// the screen, while we save then load, which is not a good user experience.
///
/// The solution is optimistically updating the TodoList before saving the new Todo to the cloud:
///
/// ```dart
/// class SaveTodo extends ReduxAction<AppState> {
///    final Todo newTodo;
///    SaveTodo(this.newTodo);
///
///    Future<AppState> reduce() async {
///
///       // Updates the TodoList optimistically.
///       dispatch(UpdateStateAction((state) => state.copy(todoList: state.todoList.add(newTodo))));
///
///       try {
///          // Saves the new Todo to the cloud.
///          await saveTodo(newTodo);
///       }
///       finally {
///          // Loads the complete TodoList from the cloud.
///          var reloadedTodoList = await loadTodoList();
///          return state.copy(todoList: reloadedTodoList);
///       }
///    }
/// }
/// ```
///
/// That's better. But if the saving fails, the users still have to wait for the reload until
/// they see the reverted state. We can further improve this:
///
/// ```dart
/// class SaveTodo extends ReduxAction<AppState> {
///    final Todo newTodo;
///    SaveTodo(this.newTodo);
///
///    Future<AppState> reduce() async {
///
///       // Updates the TodoList optimistically.
///       var newTodoList = state.todoList.add(newTodo);
///       dispatch(UpdateStateAction((state) => state.copy(todoList: newTodoList)));
///
///       try {
///          // Saves the new Todo to the cloud.
///          await saveTodo(newTodo);
///       }
///       catch (e) {
///          // If the state still contains our optimistic update, we rollback.
///          // If the state now contains something else, we DO NOT rollback.
///          if (state.todoList == newTodoList) {
///             return state.copy(todoList: initialState.todoList); // Rollback.
///          }
///       }
///       finally {
///          // Loads the complete TodoList from the cloud.
///          var reloadedTodoList = await loadTodoList();
///          dispatch(UpdateStateAction((state) => state.copy(todoList: reloadedTodoList)));
///       }
///    }
/// }
/// ```
///
/// Now the user sees the rollback immediately after the saving fails.
///
/// Note: If you are using a realtime database or Websockets to receive real-time updates from the
/// server, you may not need the finally block above, as long as the `newTodoList` above can be
/// told apart from the current `state.todoList`. This can be a problem if the state in question
/// is a primitive (boolean, number etc) or string.
///
/// The [OptimisticUpdate] mixin helps you implement the above code for you, when you
/// provide the following:
///
/// * newValue: Is the new value, that you want to see saved and applied to the sate.
/// * getValueFromState: Is a function that extract the value from the given state.
/// * reloadValue: Is a function that reloads the value from the cloud.
/// * applyState: Is a function that applies the given value to the given state.
///
mixin OptimisticUpdate<St> on ReduxAction<St> {
  //
  /// You should return here the value that you want to update. For example, if you want to add
  /// a new Todo to the todoList, you should return the new todoList with the new Todo added.
  ///
  /// You can access the fields of the action, and the state, and return the new value.
  ///
  /// ```
  /// Object? newValue() => state.todoList.add(newTodo);
  /// ```
  Object? newValue();

  /// Using the given `state`, you should return the `value` from that state.
  ///
  /// ```
  /// Object? getValueFromState(state) => state.todoList.add(newTodo);
  /// ```
  Object? getValueFromState(St state);

  /// Using the given `state`, you should apply the given `value` to it, and return the result.
  ///
  /// ```
  /// St applyState(state) => state.copy(todoList: newTodoList);
  /// ```
  St applyState(Object? value, St state);

  /// You should save the `value` or other related value in the cloud.
  ///
  /// ```
  /// void saveValue(newTodoList) => saveTodo(todo);
  /// ```
  Future<void> saveValue(Object? newValue) {
    throw UnimplementedError();
  }

  /// You should reload the `value` from the cloud.
  /// If you want to skip this step, simply don't provide this method.
  ///
  /// ```
  /// Object? reloadValue() => loadTodoList();
  /// ```
  Future<Object?> reloadValue() {
    throw UnimplementedError();
  }

  @override
  Future<St?> reduce() async {
    // Updates the value optimistically.
    final _newValue = newValue();
    final action = UpdateStateAction((St state) => applyState(_newValue, state));
    dispatch(action);

    try {
      // Saves the new value to the cloud.
      await saveValue(_newValue);
    } catch (e) {
      // If the state still contains our optimistic update, we rollback.
      // If the state now contains something else, we DO NOT rollback.
      if (getValueFromState(state) == _newValue) {
        final initialValue = getValueFromState(initialState);
        return applyState(initialValue, state); // Rollback.
      }
    } finally {
      try {
        final Object? reloadedValue = await reloadValue();
        final action = UpdateStateAction((St state) => applyState(reloadedValue, state));
        dispatch(action);
      } on UnimplementedError catch (_) {
        // If the reload was not implemented, do nothing.
      }
    }

    return null;
  }
}

/// Throttling is a technique that ensures a function is called at most once in a specified period.
/// If the function is triggered multiple times within this period, it will only execute once at
/// the start or end (depending on the implementation) of that period, and all other calls will be
/// ignored or deferred until the period expires.
///
/// Use Case: Throttling is often used in scenarios where you want to limit how often a function
/// can run. For example, it’s useful for handling events that can fire many times in a short
/// period, such as resizing a window or scrolling a webpage, where you want to ensure the event
/// handler doesn’t run so often that it causes performance issues.
///
/// Effect: It smoothens the execution rate of the function over time, preventing it from running
/// too frequently.
// TODO:
//mixin Throttle<St> implements ReduxAction<St> {}

/// Debouncing delays the execution of a function until after a certain period of inactivity.
/// Each time the debounced function is called, the period of inactivity (or wait time) is reset.
/// The function will only execute after it stops being called for the duration of the wait time.
/// Use Case: Debouncing is useful in situations where you want to ensure that a function is not
/// called too frequently and only runs after some “quiet time.” For example, it’s commonly used
/// for handling input validation in text fields, where you might not want to validate the input
/// every time the user presses a key, but rather after they've stopped typing for a certain amount
/// of time.
///
/// Effect: It delays the function execution until the triggering activity ceases for a defined
/// period, reducing the frequency of execution in scenarios where continuous input is possible.
// TODO:
//mixin Debounce<St> implements ReduxAction<St> {}

/// Caching is the process of storing data in a temporary storage area so that it can be retrieved
/// quickly. It is used to speed up the process of accessing data from the database or file system.
/// By using this mixin, you can cache the result of an action, so that if the action is dispatched
/// again with the same parameters, during a certain period of time, it will return the cached
/// result instead of running the action again.
// TODO:
//mixin Cache<St> implements ReduxAction<St> {}
