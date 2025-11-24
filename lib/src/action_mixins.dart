import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:meta/meta.dart';

/// This mixin can be used to check if there is internet when you run some
/// action that needs internet connection. Just add `with CheckInternet` to
/// your action. For example:
///
/// ```dart
/// class LoadText extends ReduxAction<AppState> with CheckInternet {
///   Future<String> reduce() async {
///
///   Response response = await get(Uri.parse("https://swapi.dev/api/people/42/"));
///   Map<String, dynamic> json = jsonDecode(response.body);
///   return json['name'] ?? 'Unknown';
///   }
/// }
/// ```
///
/// It will automatically check if there is internet before running the action.
/// If there is no internet, the action will fail, stop executing, and will
/// show a dialog to the user with title:
/// 'There is no Internet' and content: 'Please, verify your connection.'.
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
/// method [connectionException] and return a [UserException] with the desired
/// message.
///
/// IMPORTANT: It only checks if the internet is on or off on the device,
/// not if the internet provider is really providing the service or if the
/// server is available. So, it is possible that the check succeeds
/// but internet requests still fail.
///
/// Notes:
/// - This mixin can safely be combined with [NonReentrant] or [Throttle] (not both).
/// - It should not be combined with other mixins that override [before].
/// - It should not be combined with other mixins that check the internet connection.
///
/// See also:
/// * [NoDialog] - To just show a message in your widget, and not open a dialog.
/// * [AbortWhenNoInternet] - If you want to silently abort the action when there is no internet.
///
mixin CheckInternet<St> on ReduxAction<St> {
  bool get ifOpenDialog => true;

  UserException connectionException(List<ConnectivityResult> result) =>
      ConnectionException.noConnectivity;

  /// If you are running tests, you can override this getter to simulate the
  /// internet connection as on or off:
  ///
  /// - Return `true` if there IS internet.
  /// - Return `false` if there is NO internet.
  /// - Return `null` to use the real internet connection status (default).
  ///
  /// If you want to change this for all actions using mixins [CheckInternet],
  /// [AbortWhenNoInternet], and [UnlimitedRetryCheckInternet], you can
  /// do that at the store level:
  ///
  /// ```dart
  /// store.forceInternetOnOffSimulation = () => false;
  /// ```
  ///
  /// Using [Store.forceInternetOnOffSimulation] is also useful during tests,
  /// for testing what happens when you have no internet connection. And since
  /// it's tied to the store, it automatically resets when the store is
  /// recreated.
  ///
  bool? get internetOnOffSimulation => store.forceInternetOnOffSimulation();

  Future<List<ConnectivityResult>> checkConnectivity() async {
    if (internetOnOffSimulation != null)
      return internetOnOffSimulation!
          ? [ConnectivityResult.wifi]
          : [ConnectivityResult.none];

    return await (Connectivity().checkConnectivity());
  }

  @mustCallSuper
  @override
  Future<void> before() async {
    super.before();
    var result = await checkConnectivity();

    if (result.contains(ConnectivityResult.none))
      throw connectionException(result).withDialog(ifOpenDialog);
  }
}

/// This mixin can only be applied on [CheckInternet]. Example:
///
/// ```dart
/// class LoadText extends ReduxAction<AppState> with CheckInternet, NoDialog {
///   Future<String> reduce() async {
///     Response response = await get(Uri.parse("https://swapi.dev/api/people/42/"));
///     Map<String, dynamic> json = jsonDecode(response.body);
///     return json['name'] ?? 'Unknown';
///   }
/// }
/// ```
///
/// It will turn off showing a dialog when there is no internet.
/// But you can still display some information in your widgets:
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

/// This mixin can be used to check if there is internet when you run some
/// action that needs it. If there is no internet, the action will abort
/// silently, as if it had never been dispatched.
///
/// Just add `with AbortWhenNoInternet` to your action. For example:
///
/// ```dart
/// class LoadText extends ReduxAction<AppState> with AbortWhenNoInternet {
///   Future<String> reduce() async {
///     Response response = await get(Uri.parse("https://swapi.dev/api/people/42/"));
///     Map<String, dynamic> json = jsonDecode(response.body);
///     return json['name'] ?? 'Unknown';
///   }
/// }
/// ```
///
/// IMPORTANT: It only checks if the internet is on or off on the device, not if the internet
/// provider is really providing the service or if the server is available. So, it is possible that
/// this function returns true and the request still fails.
///
/// Notes:
/// - This mixin can safely be combined with [NonReentrant] or [Throttle] (not both).
/// - It should not be combined with other mixins that override [before].
/// - It should not be combined with other mixins that check the internet connection.
///
/// See also:
/// * [CheckInternet] - If you want to show a dialog to the user when there is no internet.
/// * [NoDialog] - To just show a message in your widget, and not open a dialog.
///
mixin AbortWhenNoInternet<St> on ReduxAction<St> {
  //
  /// If you are running tests, you can override this getter to simulate the
  /// internet connection as on or off:
  ///
  /// - Return `true` if there IS internet.
  /// - Return `false` if there is NO internet.
  /// - Return `null` to use the real internet connection status (default).
  ///
  /// If you want to change this for all actions using mixins [CheckInternet],
  /// [AbortWhenNoInternet], and [UnlimitedRetryCheckInternet], you can
  /// do that at the store level:
  ///
  /// ```dart
  /// store.forceInternetOnOffSimulation = () => false;
  /// ```
  ///
  /// Using [Store.forceInternetOnOffSimulation] is also useful during tests,
  /// for testing what happens when you have no internet connection. And since
  /// it's tied to the store, it automatically resets when the store is
  /// recreated.
  ///
  bool? get internetOnOffSimulation => store.forceInternetOnOffSimulation();

  Future<List<ConnectivityResult>> checkConnectivity() async {
    if (internetOnOffSimulation != null)
      return internetOnOffSimulation!
          ? [ConnectivityResult.wifi]
          : [ConnectivityResult.none];

    return await (Connectivity().checkConnectivity());
  }

  @mustCallSuper
  @override
  Future<void> before() async {
    super.before();
    var result = await checkConnectivity();
    if (result.contains(ConnectivityResult.none))
      throw AbortDispatchException();
  }
}

/// This mixin can be used to abort the action in case the action is still
/// running from a previous dispatch. Just add `with NonReentrant`
/// to your action. For example:
///
/// ```dart
/// class SaveAction extends ReduxAction<AppState> with NonReentrant {
///   Future<String> reduce() async {
///     await http.put('http://myapi.com/save', body: 'data');
///   }}
/// ```
///
/// Notes:
/// - This mixin can safely be combined with [CheckInternet], [NoDialog], and [AbortWhenNoInternet].
/// - It should not be combined with other mixins that override [abortDispatch].
/// - It should not be combined with [Throttle] or [UnlimitedRetryCheckInternet].
///
mixin NonReentrant<St> on ReduxAction<St> {
  @override
  bool abortDispatch() => isWaiting(runtimeType);
}

/// This mixin will retry the [reduce] method if it throws an error.
/// Note: If the `before` method throws an error, the retry will NOT happen.
///
/// You can override the following parameters:
///
/// * [initialDelay]: The delay before the first retry attempt.
///   Default is `350` milliseconds.
///
/// * [multiplier]: The factor by which the delay increases for each subsequent
///   retry. Default is `2`, which means the default delays are: 350 millis,
///   700 millis, and 1.4 seg.
///
/// * [maxRetries]: The maximum number of retries before giving up.
///   Default is `3`, meaning it will try a total of 4 times.
///
/// * [maxDelay]: The maximum delay between retries to avoid excessively long
///   wait times. Default is `5` seconds.
///
/// If you want to retry unlimited times, you can add the [UnlimitedRetries] mixin.
///
/// Note: The retry delay only starts after the reducer finishes executing. For example,
/// if the reducer takes 1 second to fail, and the retry delay is 350 millis, the first
/// retry will happen 1.35 seconds after the first reducer started.
///
/// When the action finally fails (`maxRetries` was reached),
/// the last error will be rethrown, and the previous ones will be ignored.
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
  Future<St?> wrapReduce(Reducer<St> reduce) async {
    FutureOr<St?> newState;

    try {
      await microtask;
      newState = reduce();
      if (newState is Future) newState = await newState;
    }
    //
    catch (error) {
      _attempts++;
      if ((maxRetries >= 0) && (_attempts > maxRetries)) rethrow;

      var currentDelay = nextDelay();
      await Future.delayed(currentDelay);

      // Retry the action.
      return wrapReduce(reduce);
    }
    return newState;
  }

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

/// The [OptimisticUpdate] mixin is still EXPERIMENTAL. You can use it,
/// but test it well.
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
/// The problem with the above code is that it make take a second to update the
/// todoList in the screen, while we save then load, which is not a good user
/// experience.
///
/// The solution is optimistically updating the TodoList before saving the new
/// Todo to the cloud:
///
/// ```dart
/// class SaveTodo extends ReduxAction<AppState> {
///    final Todo newTodo;
///    SaveTodo(this.newTodo);
///
///    Future<AppState> reduce() async {
///
///       // Updates the TodoList optimistically.
///       dispatch(UpdateStateAction((state)
///         => state.copy(todoList: state.todoList.add(newTodo))));
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
/// That's better. But if the saving fails, the users still have to wait for
/// the reload until they see the reverted state. We can further improve this:
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
/// Note: If you are using a realtime database or Websockets to receive
/// real-time updates from the server, you may not need the finally block above,
/// as long as the `newTodoList` above can be told apart from the current
/// `state.todoList`. This can be a problem if the state in question is a
/// primitive (boolean, number etc) or string.
///
/// The [OptimisticUpdate] mixin helps you implement the above code for you,
/// when you provide the following:
///
/// * [newValue]: Is the new value, that you want to see saved and applied to the state.
/// * [getValueFromState]: Is a function that extract the value from the given state.
/// * [applyState]: Is a function that applies the given value to the given state.
/// * [saveValue]: Is a function that saves the value to the cloud.
/// * [reloadValue]: Is a function that reloads the value from the cloud.
///
/// Here is the complete example using the mixin:
///
/// ```dart
/// class SaveTodo extends AppAction with OptimisticUpdate {
///   final Todo newTodo;
///   SaveTodo(this.newTodo);
///
///   // The optimistic value to be applied right away.
///   @override
///   Object? newValue() => state.todoList.add(newTodo);
///
///   // Read the current value from the state.
///   @override
///   Object? getValueFromState(AppState state) => state.todoList;
///
///   // Apply the value to the state.
///   @override
///   AppState applyState(AppState state, Object? value) => state.copy(todoList: value);
///
///   // Save the value to the cloud.
///   @override
///   Future<void> saveValue(Object? value) async => await saveTodo(newTodo);
///
///   // Reload the value from the cloud. Omit to not reload.
///   @override
///   Future<Object?> reloadValue() async => await loadTodoList();
/// }
///
/// ```
mixin OptimisticUpdate<St> on ReduxAction<St> {
  //
  /// You should return here the value that you want to update.
  /// For example, if you want to add a new Todo to the todoList,
  /// you should return the new todoList with the new Todo added.
  ///
  /// You can access the fields of the action, and the state,
  /// and return the new value.
  ///
  /// ```dart
  /// Object? newValue() => state.todoList.add(newTodo);
  /// ```
  Object? newValue();

  /// Using the given `state`, you should return the `value` from that state.
  ///
  /// ```dart
  /// Object? getValueFromState(AppState state) => state.todoList;
  /// ```
  Object? getValueFromState(St state);

  /// Using the given `state`, you should apply the given `value` to it,
  /// and return the result.
  ///
  /// ```dart
  /// AppState applyState(newTodoList, state) => state.copy(todoList: newTodoList);
  /// ```
  St applyState(Object? value, St state);

  /// You should save the `value` or other related value in the cloud.
  ///
  /// ```dart
  /// Future<void> saveValue(newTodoList) => saveTodo(newTodo);
  /// ```
  Future<void> saveValue(Object? newValue) {
    throw UnimplementedError();
  }

  /// You should reload the `value` from the cloud.
  /// If you want to skip this step, simply don't provide this method.
  ///
  /// ```dart
  /// Future<Object?> reloadValue() => loadTodoList();
  /// ```
  Future<Object?> reloadValue() {
    throw UnimplementedError();
  }

  @override
  Future<St?> reduce() async {
    // Updates the value optimistically.
    final _newValue = newValue();
    final action = UpdateStateAction.withReducer(
        (St state) => applyState(_newValue, state));
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
        final action = UpdateStateAction.withReducer(
            (St state) => applyState(reloadedValue, state));
        dispatch(action);
      } on UnimplementedError catch (_) {
        // If the reload was not implemented, do nothing.
      }
    }

    return null;
  }
}

/// Throttling ensures the action will be dispatched at most once in the
/// specified throttle period. In other words, it prevents the action from
/// running too frequently.
///
/// If an action is dispatched multiple times within a throttle period, it will
/// only execute the first time, and the others will be aborted. After the
/// throttle period has passed, the action will be allowed to execute again,
/// which will reset the throttle period.
///
/// If you use the action to load information, the throttle period may be
/// considered as the time the loaded information is "fresh". After the
/// throttle period, the information is considered "stale" and the action will
/// be allowed to load the information again.
///
/// For example, if you are using a `StatefulWidget` that needs to load some
/// information, you can dispatch the loading action when widget is created,
/// and specify a throttle period so that it doesn't load the information again
/// too often.
///
/// If you are using a `StoreConnector`, you can use the `onInit` parameter:
///
/// ```dart
/// class MyScreenConnector extends StatelessWidget {
///   Widget build(BuildContext context) => StoreConnector<AppState, _Vm>(
///     vm: () => _Factory(),
///     onInit: _onInit, // Here!
///     builder: (context, vm) {
///       return MyScreenConnector(
///         information: vm.information,
///         ...
///       ),
///     );
///
///   void _onInit(Store<AppState> store) {
///     store.dispatch(LoadAction());
///   }
/// }
/// ```
///
/// and then:
///
/// ```dart
/// class LoadAction extends ReduxAction<AppState> with Throttle {
///
///   int throttle = 5000;
///
///   Future<AppState?> reduce() async {
///     var information = await loadInformation();
///     return state.copy(information: information);
///   }
/// }
/// ```
///
/// The [throttle] value is given in milliseconds, and the default is 1000
/// milliseconds (1 second). You can override this default:
///
/// ```dart
/// class MyAction extends ReduxAction<AppState> with Throttle {
///    int throttle = 500; // Here!
///    ...
/// }
/// ```
///
/// You can also override [ignoreThrottle] if you want the action to ignore the
/// throttle period under some conditions. For example, suppose you want the
/// action to provide a flag called `force` that will ignore the throttle
/// period:
///
/// ```dart
/// class MyAction extends ReduxAction<AppState> with Throttle {
///    final bool force;
///    MyAction({this.force = false});
///
///    bool ignoreThrottle => force; // Here!
///
///    int throttle = 500;
///    ...
/// }
/// ```
///
/// # If the action fails
///
/// The throttle period is NOT reset if the action fails. This means that if
/// the action fails, it will not run a second time if you dispatch it again
/// within the throttle period.
///
/// If you want, you can specify a different behavior by making
/// [removeLockOnError] true, like this:
///
/// ```dart
/// class MyAction extends ReduxAction<AppState> with Throttle {
///    bool removeLockOnError = true; // Here!
///    ...
/// }
/// ```
///
/// Now, if the action fails, it will remove the lock and allow the action to
/// be dispatched again right away. Note this currently implemented in the
/// [after] method, like this:
///
/// ```dart
/// @override
/// void after() {
///   if (removeLockOnError && (status.originalError != null)) removeLock();
/// }
/// ```
///
/// You can override the [after] method to customize this behavior of removing
/// the lock under some conditions.
///
/// # Advanced usage
///
/// The throttle is, by default, based on the action [runtimeType]. This means
/// it will throttle an action if another action of the same runtimeType was
/// previously dispatched within the throttle period. In other words, the
/// runtimeType is the "lock". If you want to throttle based on a different
/// lock, you can override the [lockBuilder] method. For example, here
/// we throttle two different actions based on the same lock:
///
/// ```dart
/// class MyAction1 extends ReduxAction<AppState> with Throttle {
///    Object? lockBuilder() => 'myLock';
///    ...
/// }
///
/// class MyAction2 extends ReduxAction<AppState> with Throttle {
///    Object? lockBuilder() => 'myLock';
///    ...
/// }
/// ```
///
/// Another example is to throttle based on some field of the action:
///
/// ```dart
/// class MyAction extends ReduxAction<AppState> with Throttle {
///    final String lock;
///    MyAction(this.lock);
///    Object? lockBuilder() => lock;
///    ...
/// }
/// ```
///
/// If you override the [lockBuilder], ensure the number of different locks you
/// create is limited, as the lock map is never cleared.
///
/// Notes:
/// - It should not be combined with other mixins that override [abortDispatch] or [after].
/// - It should not be combined with [NonReentrant] or [UnlimitedRetryCheckInternet].
///
mixin Throttle<St> on ReduxAction<St> {
  //
  int get throttle => 1000; // Milliseconds

  bool get removeLockOnError => false;

  bool get ignoreThrottle => false;

  /// The default lock for throttling is the action's [runtimeType],
  /// meaning it will throttle the dispatch of actions of the same type.
  /// Override this method to customize the lock to any value.
  /// For example, you can return a string or an enum, and actions with the
  /// same lock value will throttle each other.
  /// Ensure the number of different locks you create is limited, as
  /// the lock map is never cleared.
  Object? lockBuilder() => runtimeType;

  /// Map that stores the last time an action with a specific lock dispatched.
  Map<Object?, DateTime> get _throttleLockMap =>
      store.internalMixinProps.throttleLockMap;

  /// Removes the lock, allowing an action of the same type to be dispatched
  /// again right away. You generally don't need to call this method.
  void removeLock() => _throttleLockMap.remove(lockBuilder());

  /// Removes all locks, allowing all actions to be dispatched again right away.
  /// You generally don't need to call this method.
  void removeAllLocks() => _throttleLockMap.clear();

  @override
  bool abortDispatch() {
    var lock = lockBuilder();
    var now = DateTime.now().toUtc();

    // If should ignore the throttle, then update time and allow the dispatch.
    if (ignoreThrottle) {
      _throttleLockMap[lock] = now;
      return false;
    }
    //
    else {
      var time = _throttleLockMap[lock];

      if (time == null) {
        _throttleLockMap[lock] = now;
        return false;
      }
      //
      else {
        // If the throttle time has NOT elapsed since last dispatch, abort.
        if (now.difference(time).inMilliseconds < throttle)
          return true;
        //
        // Otherwise, update the time and allow the dispatch.
        else {
          _throttleLockMap[lock] = now;
          return false;
        }
      }
    }
  }

  @override
  void after() {
    if (removeLockOnError && (status.originalError != null)) removeLock();
  }
}

/// Debouncing delays the execution of a function until after a certain period
/// of inactivity. Each time the debounced function is called, the period of
/// inactivity (or wait time) is reset.
///
/// The function will only execute after it stops being called for the duration
/// of the wait time. Debouncing is useful in situations where you want to
/// ensure that a function is not called too frequently and only runs after
/// some “quiet time.”
///
/// For example, it’s commonly used for handling input validation in text fields,
/// where you might not want to validate the input every time the user presses
/// a key, but rather after they've stopped typing for a certain amount of time.
///
///
/// The [debounce] value is given in milliseconds, and the default is 333
/// milliseconds (1/3 of a second). You can override this default:
///
/// ```dart
/// class MyAction extends ReduxAction<AppState> with Debounce {
///    final int debounce = 1000; // Here!
///    ...
/// }
/// ```
///
/// # Advanced usage
///
/// The debounce is, by default, based on the action [runtimeType]. This means
/// it will reset the debounce period when another action of the same
/// runtimeType was is dispatched within the debounce period. In other words,
/// the runtimeType is the "lock". If you want to debounce based on a different
/// lock, you can override the [lockBuilder] method. For example, here
/// we debounce two different actions based on the same lock:
///
/// ```dart
/// class MyAction1 extends ReduxAction<AppState> with Debounce {
///    Object? lockBuilder() => 'myLock';
///    ...
/// }
///
/// class MyAction2 extends ReduxAction<AppState> with Debounce {
///    Object? lockBuilder() => 'myLock';
///    ...
/// }
/// ```
///
/// Another example is to debounce based on some field of the action:
///
/// ```dart
/// class MyAction extends ReduxAction<AppState> with Debounce {
///    final String lock;
///    MyAction(this.lock);
///    Object? lockBuilder() => lock;
///    ...
/// }
/// ```
///
/// Notes:
/// - It should not be combined with other mixins that override [wrapReduce].
/// - It should not be combined with [Retry] or [UnlimitedRetryCheckInternet].
///
mixin Debounce<St> on ReduxAction<St> {
  //
  int get debounce => 333; // Milliseconds

  /// The default lock for debouncing is the action's [runtimeType],
  /// meaning it will debounce the dispatch of actions of the same type.
  /// Override this method to customize the lock to any value.
  /// For example, you can return a string or an enum, and actions with the
  /// same lock value will debounce each other.
  Object? lockBuilder() => runtimeType;

  /// Map that stores the run-number for actions with a specific lock.
  Map<Object?, int> get _debounceLockMap =>
      store.internalMixinProps.debounceLockMap;

  // A large number that JavaScript can still represent.
  // In theory, it could be between -9007199254740991 and 9007199254740991.
  static const _SAFE_INTEGER = 9000000000000000;

  /// Removes all locks, allowing all actions to be dispatched again right away.
  /// You generally don't need to call this method.
  void removeAllLocks() => _debounceLockMap.clear();

  @override
  Future<St?> wrapReduce(Reducer<St> reduce) async {
    //
    var lock = lockBuilder();

    // Increment and update the map with the new run count.
    var before = (_debounceLockMap[lock] ?? 0) + 1;
    if (before > _SAFE_INTEGER) before = 0;
    _debounceLockMap[lock] = before;

    await Future.delayed(Duration(milliseconds: debounce));

    var after = _debounceLockMap[lock];

    // If the run has changed, it means the action was dispatched again
    // within the debounce period. So, we abort the reducer.
    if (after != before)
      return null;
    //
    // Otherwise, we remove the lock and run the reducer.
    else {
      _debounceLockMap.remove(lock);
      return reduce();
    }
  }
}

/// This mixin can be used to check if there is internet when you run some
/// action that needs it. If there is no internet, the action will abort
/// silently, and then retry the [reduce] method unlimited times, until there
/// is internet. It will also retry if there is internet but the action failed.
///
/// Just add `with UnlimitedRetryCheckInternet` to your action.
/// For example:
///
/// ```dart
/// class LoadText extends AppAction UnlimitedRetryCheckInternet {
///   Future<String> reduce() async {
///     Response response = await get(Uri.parse("https://swapi.dev/api/people/42/"));
///     Map<String, dynamic> json = jsonDecode(response.body);
///     return json['name'] ?? 'Unknown';
///   }
/// }
/// ```
///
/// IMPORTANT: This mixin combines [Retry], [UnlimitedRetries], [AbortWhenNoInternet]
/// and [NonReentrant] mixins. You should NOT use it with those mixins,
/// or any other mixin that checks the internet connection.
///
/// IMPORTANT: It only checks if the internet is on or off on the device,
/// not if the internet provider is really providing the service or if the
/// server is available. So, it is possible that this function returns true
/// and the request still fails.
///
/// Notes:
/// - It should not be combined with other mixins that override [wrapReduce] or [abortDispatch].
/// - It should not be combined with other mixins that check the internet connection.
/// - Make sure your `before` method does not throw an error, or the retry will NOT happen.
/// - All retried will be printed to the console.
///
mixin UnlimitedRetryCheckInternet<St> on ReduxAction<St> {
  //
  @override
  bool abortDispatch() => isWaiting(runtimeType);

  /// The delay before the first retry attempt.
  Duration get initialDelay => const Duration(milliseconds: 350);

  /// The factor by which the delay increases for each subsequent retry.
  /// Must be greater than 1, otherwise it will be set to 2.
  double get multiplier => 2;

  /// Unlimited retries.
  int get maxRetries => -1;

  /// The maximum delay between retries to avoid excessively long wait times.
  /// This is for errors that are not related to the Internet.
  /// The default is 5 seconds.
  /// See also: [maxDelayNoInternet]
  Duration get maxDelay => const Duration(milliseconds: 5000);

  /// The maximum delay between retries when there is no Internet.
  /// The default is 1 second.
  /// See also: [maxDelay]
  Duration get maxDelayNoInternet => const Duration(seconds: 1);

  int _attempts = 0;

  /// The number of retry attempts so far. If the action has not been retried yet, it will be 0.
  /// If the action finished successfully, it will be equal or less than [maxRetries].
  /// If the action failed and gave up, it will be equal to [maxRetries] plus 1.
  int get attempts => _attempts;

  /// This prints the retries, including the action name, the attempt, and if
  /// the problem was no Internet or not. To remove the print message,
  /// override with:
  ///
  /// ```dart
  /// void printRetries(String message) {}
  /// ```
  void printRetries(String message) => print(message);

  @override
  Future<St?> wrapReduce(Reducer<St> reduce) async {
    FutureOr<St?> newState;
    bool hasInternet = true;
    try {
      // Note we don't have side-effects before the first await.
      var result = await checkConnectivity();

      // IMPORTANT: We throw this exception, but it will not ever be shown,
      // because we are retrying unlimited times. This simply triggers the next retry.
      if (result.contains(ConnectivityResult.none)) {
        hasInternet = false;
        throw const UserException('');
      }

      if (attempts == 0)
        printRetries('Trying $runtimeType.');
      else
        printRetries('Retrying $runtimeType (attempt $attempts).');

      newState = reduce();
      if (newState is Future) newState = await newState;
    }
    //
    catch (error) {
      //
      if (!hasInternet) {
        if (attempts == 0)
          printRetries('Trying $runtimeType; aborted because of no internet.');
        else
          printRetries(
              'Retrying $runtimeType; aborted because of no internet (attempt $attempts).');
      }

      _attempts++;

      if ((maxRetries >= 0) && (_attempts > maxRetries)) rethrow;

      var currentDelay = nextDelay(hasInternet: hasInternet);
      await Future.delayed(currentDelay);
      return wrapReduce(reduce);
    }
    return newState;
  }

  Duration? _currentDelay;

  /// Start with the [initialDelay], and then increase it by [multiplier] each time this is called.
  /// If the delay exceeds [maxDelay], it will be set to [maxDelay].
  Duration nextDelay({required bool hasInternet}) {
    var _multiplier = multiplier;
    if (_multiplier <= 1) _multiplier = 2;

    _currentDelay = (_currentDelay == null) //
        ? initialDelay //
        : _currentDelay! * _multiplier;

    if (hasInternet) {
      if (_currentDelay! > maxDelay) _currentDelay = maxDelay;
    } else {
      if (_currentDelay! > maxDelayNoInternet)
        _currentDelay = maxDelayNoInternet;
    }

    return _currentDelay!;
  }

  /// If you are running tests, you can override this getter to simulate the
  /// internet connection as on or off:
  ///
  /// - Return `true` if there IS internet.
  /// - Return `false` if there is NO internet.
  /// - Return `null` to use the real internet connection status (default).
  ///
  /// If you want to change this for all actions using mixins [CheckInternet],
  /// [AbortWhenNoInternet], and [UnlimitedRetryCheckInternet], you can
  /// do that at the store level:
  ///
  /// ```dart
  /// store.forceInternetOnOffSimulation = () => false;
  /// ```
  ///
  /// Using [Store.forceInternetOnOffSimulation] is also useful during tests,
  /// for testing what happens when you have no internet connection. And since
  /// it's tied to the store, it automatically resets when the store is
  /// recreated.
  ///
  bool? get internetOnOffSimulation => store.forceInternetOnOffSimulation();

  Future<List<ConnectivityResult>> checkConnectivity() async {
    if (internetOnOffSimulation != null)
      return internetOnOffSimulation!
          ? [ConnectivityResult.wifi]
          : [ConnectivityResult.none];

    return await (Connectivity().checkConnectivity());
  }
}

// TODO:
/// Caching is the process of storing data in a temporary storage area so that
/// it can be retrieved quickly. It is used to speed up the process of
/// accessing data from the database or file system.
///
/// By using this mixin, you can cache the result of an action, so that if
/// the action is dispatched again with the same parameters, during a certain
/// period of time, it will return the cached result instead of running the
/// action again.
//mixin Cache<St> on ReduxAction<St> {}
