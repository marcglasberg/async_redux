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
/// - It should not be combined with [AbortWhenNoInternet] and [UnlimitedRetryCheckInternet].
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
    _cannot_combine_mixins_CheckInternet_AbortWhenNoInternet_UnlimitedRetryCheckInternet();

    super.before();
    var result = await checkConnectivity();

    if (result.contains(ConnectivityResult.none))
      throw connectionException(result).withDialog(ifOpenDialog);
  }

  void
      _cannot_combine_mixins_CheckInternet_AbortWhenNoInternet_UnlimitedRetryCheckInternet() {
    _incompatible<CheckInternet, AbortWhenNoInternet>(this);
    _incompatible<CheckInternet, UnlimitedRetryCheckInternet>(this);
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
/// - It should not be combined with [CheckInternet], [NoDialog], and [UnlimitedRetryCheckInternet].
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
    _cannot_combine_mixins_CheckInternet_AbortWhenNoInternet_UnlimitedRetryCheckInternet();

    super.before();
    var result = await checkConnectivity();
    if (result.contains(ConnectivityResult.none))
      throw AbortDispatchException();
  }

  void
      _cannot_combine_mixins_CheckInternet_AbortWhenNoInternet_UnlimitedRetryCheckInternet() {
    _incompatible<AbortWhenNoInternet, CheckInternet>(this);
    _incompatible<AbortWhenNoInternet, UnlimitedRetryCheckInternet>(this);
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
/// - It should not be combined with [Throttle], [UnlimitedRetryCheckInternet], or [Fresh].
///
mixin NonReentrant<St> on ReduxAction<St> {
  @override
  bool abortDispatch() {
    _cannot_combine_mixins_Fresh_Throttle_NonReentrant_UnlimitedRetryCheckInternet();

    return isWaiting(runtimeType);
  }

  void
      _cannot_combine_mixins_Fresh_Throttle_NonReentrant_UnlimitedRetryCheckInternet() {
    _incompatible<NonReentrant, Fresh>(this);
    _incompatible<NonReentrant, Throttle>(this);
    _incompatible<NonReentrant, UnlimitedRetryCheckInternet>(this);
  }
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
/// Notes:
/// - Combining [Retry] with [CheckInternet] or [AbortWhenNoInternet] will
///   not retry when there is no internet. It will only retry if there IS
///   internet but the action fails for some other reason.
/// - It should not be combined with [Debounce], [UnlimitedRetryCheckInternet].
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
    _cannot_combine_mixins_Debounce_Retry_UnlimitedRetryCheckInternet();

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

  void _cannot_combine_mixins_Debounce_Retry_UnlimitedRetryCheckInternet() {
    _incompatible<Retry, Debounce>(this);
    _incompatible<Retry, UnlimitedRetryCheckInternet>(this);
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
/// * [applyValueToState]: Is a function that applies the given value to the given state.
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
///   AppState applyValueToState(AppState state, Object? value) => state.copy(todoList: value);
///
///   // Save the value to the cloud.
///   @override
///   Future<void> saveValue(Object? value) async => await saveTodo(newTodo);
///
///   // Reload the value from the cloud. Omit to not reload.
///   @override
///   Future<Object?> reloadValue() async => await loadTodoList();
/// }
/// ```
///
/// Notes:
/// - This mixin can be safely be combined with all others.
///
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
  /// AppState applyValueToState(state, newTodoList) => state.copy(todoList: newTodoList);
  /// ```
  St applyValueToState(St state, Object? value);

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
        (St state) => applyValueToState(state, _newValue));
    dispatch(action);

    try {
      // Saves the new value to the cloud.
      await saveValue(_newValue);
    } catch (e) {
      // If the state still contains our optimistic update, we rollback.
      // If the state now contains something else, we DO NOT rollback.
      if (getValueFromState(state) == _newValue) {
        final initialValue = getValueFromState(initialState);

        final rollbackAction = UpdateStateAction.withReducer(
            (St state) => applyValueToState(state, initialValue));
        dispatch(rollbackAction);
      }
      rethrow;
    } finally {
      try {
        final Object? reloadedValue = await reloadValue();
        final action = UpdateStateAction.withReducer(
            (St state) => applyValueToState(state, reloadedValue));
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
/// For example, you can dispatch the action in your widget's `initState`:
///
/// ```dart
/// class MyScreen extends StatefulWidget {
///   State<MyScreen> createState() => _MyScreenState();
/// }
///
/// class _MyScreenState extends State<MyScreen> {
///
///   void initState() {
///     super.initState();
///     context.dispatch(LoadInformation());
///   }
///
///   Widget build(BuildContext context) {
///     var information = context.state.information;
///     return Text('Information: $information');
///   }
/// }
/// ```
///
/// and then:
///
/// ```dart
/// class LoadInformation extends ReduxAction<AppState> with Throttle {
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
///    bool get ignoreThrottle => force; // Here!
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
/// Note: Expired locks are removed when expired, to prevent memory leaks.
///
/// Notes:
/// - It should not be combined with other mixins that override [abortDispatch] or [after].
/// - It should not be combined with [Fresh], [NonReentrant] or [UnlimitedRetryCheckInternet].
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
  /// Note: Expired locks are removed when expired, to prevent memory leaks.
  Object? lockBuilder() => runtimeType;

  /// Map that stores the expiry time for each lock.
  /// The value is the instant when the throttle period ends.
  Map<Object?, DateTime> get _throttleLockMap =>
      store.internalMixinProps.throttleLockMap;

  /// Removes the lock, allowing an action of the same type to be dispatched
  /// again right away. You generally do not need to call this method.
  void removeLock() => _throttleLockMap.remove(lockBuilder());

  /// Removes all locks, allowing all actions to be dispatched again right away.
  /// You generally don't need to call this method.
  void removeAllLocks() => _throttleLockMap.clear();

  @override
  bool abortDispatch() {
    _cannot_combine_mixins_Fresh_Throttle_NonReentrant_UnlimitedRetryCheckInternet();

    final lock = lockBuilder();
    final now = DateTime.now().toUtc();

    // If should ignore the throttle, then set a new expiry and allow dispatch.
    if (ignoreThrottle) {
      _throttleLockMap[lock] = _expiringLockFrom(now);
      return false;
    }

    final expiresAt = _throttleLockMap[lock];

    // If there is no lock, or it has expired, set a new expiry and allow.
    if (expiresAt == null || !expiresAt.isAfter(now)) {
      _throttleLockMap[lock] = _expiringLockFrom(now);
      return false;
    }

    // Still inside the throttle period, abort dispatch.
    return true;
  }

  DateTime _expiringLockFrom(DateTime now) =>
      now.add(Duration(milliseconds: throttle));

  /// Remove locks whose expiry time is in the past or now.
  void _prune() {
    final now = DateTime.now().toUtc();
    _throttleLockMap.removeWhere((_, expiresAt) => !expiresAt.isAfter(now));
  }

  @override
  void after() {
    if (removeLockOnError && (status.originalError != null)) removeLock();
    _prune();
  }

  void
      _cannot_combine_mixins_Fresh_Throttle_NonReentrant_UnlimitedRetryCheckInternet() {
    _incompatible<Throttle, Fresh>(this);
    _incompatible<Throttle, NonReentrant>(this);
    _incompatible<Throttle, UnlimitedRetryCheckInternet>(this);
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
/// - It should not be combined with [Retry], [UnlimitedRetries], or [UnlimitedRetryCheckInternet].
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
    _cannot_combine_mixins_Debounce_Retry_UnlimitedRetryCheckInternet();

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

  void _cannot_combine_mixins_Debounce_Retry_UnlimitedRetryCheckInternet() {
    _incompatible<Debounce, Retry>(this);
    _incompatible<Debounce, UnlimitedRetryCheckInternet>(this);
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
  bool abortDispatch() {
    _cannot_combine_mixins_Fresh_Throttle_NonReentrant_UnlimitedRetryCheckInternet();
    _cannot_combine_mixins_CheckInternet_AbortWhenNoInternet_UnlimitedRetryCheckInternet();
    _cannot_combine_mixins_Debounce_Retry_UnlimitedRetryCheckInternet();

    return isWaiting(runtimeType);
  }

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

  void
      _cannot_combine_mixins_Fresh_Throttle_NonReentrant_UnlimitedRetryCheckInternet() {
    _incompatible<UnlimitedRetryCheckInternet, Fresh>(this);
    _incompatible<UnlimitedRetryCheckInternet, Throttle>(this);
    _incompatible<UnlimitedRetryCheckInternet, NonReentrant>(this);
  }

  void
      _cannot_combine_mixins_CheckInternet_AbortWhenNoInternet_UnlimitedRetryCheckInternet() {
    _incompatible<UnlimitedRetryCheckInternet, CheckInternet>(this);
    _incompatible<UnlimitedRetryCheckInternet, AbortWhenNoInternet>(this);
  }

  void _cannot_combine_mixins_Debounce_Retry_UnlimitedRetryCheckInternet() {
    _incompatible<Retry, Debounce>(this);
    _incompatible<Retry, UnlimitedRetryCheckInternet>(this);
  }
}

/// The [Fresh] mixin lets you treat the result of an action as fresh for a
/// given time period. While the information is fresh, repeated dispatches of
/// the same action (or other actions with the same "fresh-key") are skipped,
/// because that information is assumed to still be valid in the state.
///
/// After the fresh period ends, the information is considered "stale".
/// The next dispatch of an action with the same "fresh-key" is allowed to
/// run again, update the state, and start a new fresh period.
///
/// In short, [Fresh] helps you avoid reloading the same information too often.
///
///
/// ## Basic usage
///
/// This is often used for actions that load information from a server. You can
/// think of the fresh period as the time during which the loaded data is still
/// good to use. After that time, a new dispatch will reload it.
///
/// A simple example in a `StatefulWidget` that loads information once when
/// the widget is created:
///
/// ```dart
/// class MyScreen extends StatefulWidget {
///   State<MyScreen> createState() => _MyScreenState();
/// }
///
/// class _MyScreenState extends State<MyScreen> {
///   void initState() {
///     super.initState();
///     context.dispatch(LoadInformation()); // Here!
///   }
///
///   Widget build(BuildContext context) {
///     var information = context.state.information;
///     return Text('Information: $information');
///   }
/// }
/// ```
///
/// Use [Fresh] on the loading action so it does not run again while its data
/// is still fresh:
///
/// ```dart
/// class LoadInformation extends ReduxAction<AppState> with Fresh {
///
///   Future<AppState> reduce() async {
///     var information = await loadInformation();
///     return state.copy(information: information);
///   }
/// }
/// ```
///
///
/// ## How fresh-keys work
///
/// * Dispatched actions with different fresh-keys are not affected.
///
/// * Dispatched actions with the same fresh-key:
///   - Are aborted while the data is fresh (the fresh period has not passed).
///   - Run again when the data is stale (after the fresh period has passed).
///
/// In other words, freshness is tracked per fresh-key. Any two dispatches that
/// share the same fresh-key share the same fresh period.
///
/// By default, the key is based on:
/// * The action type (its `runtimeType`), and
/// * The value returned by [freshKeyParams].
///
/// In the previous example, the fresh-key of the `LoadInformation` action is
/// simply the action [runtimeType], since it did not override [freshKeyParams].
///
/// If you dispatch `LoadInformation` many times in a short period, only the
/// first one runs while the data is fresh. The others are aborted. Later,
/// when the fresh period ends, the next dispatch will run the action again.
///
/// The default [freshKeyParams] returns `null`, so the key is only the action
/// type. This means all actions of the same type share the same fresh period,
/// and different action types do not affect each other.
///
/// ### Using [freshKeyParams] to separate instances
///
/// Many actions need a separate fresh period per id, url, or some other field.
/// In that case, override [freshKeyParams]. Actions of the same type but with
/// different [freshKeyParams] values do not affect each other.
///
/// ```dart
/// class LoadUserCart extends ReduxAction<AppState> with Fresh {
///   final String userId;
///   LoadUserCart(this.userId);
///
///   // The fresh-key parameter here is the `userId`, which means
///   // each different `(LoadUserCart, userId)` has its own fresh period.
///   Object? freshKeyParams() => userId;
///   ...
/// ```
///
/// You can also return more than one field by using a tuple:
///
/// ```dart
/// // Each different `(LoadUserCart, userId, cartId)` has its own fresh period.
/// Object? freshKeyParams() => (userId, cartId);
/// ```
///
/// ## Configuring how long data stays fresh
///
/// The [freshFor] value is given in milliseconds. The default is `1000`
/// (1 second).
///
/// To keep the data fresh for 5 seconds:
///
///
/// ```dart
/// class LoadInformation extends ReduxAction<AppState> with Fresh {
///    int freshFor = 500; // Here!
///    ...
/// }
/// ```
///
///
/// ## Forcing the action to run
///
/// Sometimes you want to run the action even if the data is still fresh. For
/// that, you can override [ignoreFresh]. When [ignoreFresh] is `true`, the
/// action always runs and also starts a new fresh period for its key.
///
/// A common pattern is to add a `force` flag:
///
/// ```dart
/// class LoadInformation extends ReduxAction<AppState> with Fresh {
///    final bool force;
///    LoadInformation({this.force = false});
///
///    bool get ignoreFresh => force; // Here!
///    ...
/// }
/// ```
///
/// With this setup:
/// * `LoadInformation()` runs only when its key is stale.
/// * `LoadInformation(force: true)` always runs and also refreshes the key.
///
///
/// ## When the action fails
///
/// If an action that uses [Fresh] throws an error, the mixin tries to behave
/// as if that failing run did not make the key stay fresh for longer.
///
/// In practice:
/// * If there was no fresh entry for that key before the action started,
///   the key is cleared. You can dispatch the action again right away.
/// * If there was already a fresh time stored for that key, that time is kept.
/// * If another action using the same key finished after this one started and
///   changed the fresh time, that newer fresh time is kept as is.
///
/// This means:
/// * Errors never extend the fresh time by themselves.
/// * A failure from an older action does not cancel a newer successful action
///   that used the same fresh-key.
///
/// You can also control this by hand:
///
/// * Call [removeKey] from your action (for example inside [reduce] or
///   [before]) to remove the key used by that action, so the next dispatch
///   for that key can run immediately.
/// * Call [removeAllKeys] from your action to clear all keys and let all
///   actions run again as if nothing was fresh. This is probably useful
///   during logout or similar scenarios.
///
/// Expired keys are cleaned automatically over time, so you usually do not
/// need to worry about old entries.
///
///
/// ## Using [computeFreshKey] to share keys across actions
///
/// If you want different action types to share the same key, override
/// [computeFreshKey]. This is useful when several actions read or write the
/// same logical resource and should respect the same fresh period.
///
/// For example, two actions that work on the same user data:
///
/// ```dart
/// class LoadUserProfile extends ReduxAction<AppState> with Fresh {
///   final String userId;
///   LoadUserProfile(this.userId);
///
///   Object computeFreshKey() => userId; // key is only userId
///   ...
/// }
///
/// class LoadUserSettings extends ReduxAction<AppState> with Fresh {
///   final String userId;
///   LoadUserSettings(this.userId);
///
///   Object computeFreshKey() => userId; // same key as above
///   ...
/// }
/// ```
///
/// Here:
/// * `LoadUserProfile('123')` and `LoadUserSettings('123')` share one fresh
///   period, because they use the same key.
/// * Any object can be a key, for example an enum or a constant string.
///
///
/// Notes:
/// - It should not be combined with other mixins that override [abortDispatch] or [after].
/// - It should not be combined with [Throttle], [NonReentrant] or [UnlimitedRetryCheckInternet].
///
mixin Fresh<St> on ReduxAction<St> {
  //
  int get freshFor => 1000; // Milliseconds

  bool get ignoreFresh => false;

  /// By default the fresh key is based on the action [runtimeType].
  /// For example, all actions of type `LoadText` share the same
  /// freshness:
  ///
  /// ```dart
  /// // This action runs.
  /// dispatch(LoadText(url: 'https://example.com'));
  ///
  /// // This does NOT run, because the previous LoadText is still fresh.
  /// dispatch(LoadText(url: 'https://another-url.com'));
  /// ```dart
  ///
  /// You can override [freshKeyParams] so that actions of the SAME TYPE
  /// but with different parameters do not affect each other's freshness.
  /// In this example, the `url` field becomes part of the fresh-key:
  ///
  /// ```dart
  /// class LoadText extends ReduxAction<AppState> with Fresh {
  ///   final String url;
  ///   LoadText(this.url);
  ///
  ///   // The fresh-key includes the url.
  ///   Object? freshKeyParams() => url;
  ///   ...
  /// }
  /// ```
  ///
  /// Now, dispatching two `LoadText` actions with different `url` values
  /// allows both of them to run, because each one uses a different fresh-key:
  ///
  /// ```dart
  /// // This action runs.
  /// dispatch(LoadText(url: 'https://example.com'));
  ///
  /// // This also runs, because the url is different, so it has a different fresh-key.
  /// dispatch(LoadText(url: 'https://another-url.com'));
  /// ```
  ///
  /// ## In more detail
  ///
  /// The default fresh-key, as returned by [computeFreshKey], combines the
  /// action [runtimeType] with the value returned by [freshKeyParams].
  ///
  /// Most of the time you override [freshKeyParams] to return one field,
  /// or a tuple of fields:
  ///
  /// ```dart
  /// // Fresh-key is runtimeType + url
  /// Object? freshKeyParams() => url;
  ///
  /// // Fresh-key is runtimeType + userId + cartId
  /// Object? freshKeyParams() => (userId, cartId);
  /// ```
  ///
  /// When [freshKeyParams] returns `null`, the key is just the action type.
  /// In that case all actions of that type share the same freshness.
  ///
  /// See also:
  /// - [computeFreshKey] if you want full control over how the key is built.
  ///
  Object? freshKeyParams() => null;

  /// In most cases you want to use the default fresh-key computation, which
  /// combines the action's [runtimeType] with the value returned by
  /// [freshKeyParams]:
  ///
  /// ```dart
  /// Object? computeFreshKey() => (runtimeType, freshKeyParams());
  /// ```
  ///
  /// However, if you want different action types to share the same fresh
  /// period, you must override [computeFreshKey] and return any key you want.
  /// Some examples:
  ///
  /// ```dart
  /// // The fresh-key is only the url, without the runtimeType.
  /// Object? computeFreshKey() => url;
  ///
  /// // The fresh-key is a pair of values, without the runtimeType.
  /// Object? computeFreshKey() => (userId, cartId);
  ///
  /// // The fresh-key is a constant string.
  /// Object? computeFreshKey() => 'myKey';
  ///
  /// // The fresh-key is an enum value.
  /// Object? computeFreshKey() => MyFreshnessKey.myKey;
  /// ```
  ///
  /// For example, suppose you have two different actions, and you want
  /// them to share the same fresh-key:
  ///
  /// ```dart
  /// class LoadUserProfile extends ReduxAction<AppState> with Fresh {
  ///   final String userId;
  ///   LoadUserProfile(this.userId);
  ///
  ///   // The key is the userId only, without the runtimeType.
  ///   Object? computeFreshKey() => userId;
  ///   ...
  /// }
  ///
  /// class LoadUserSettings extends ReduxAction<AppState> with Fresh {
  ///   final String userId;
  ///   LoadUserSettings(this.userId);
  ///
  ///   // The key is the userId only, without the runtimeType.
  ///   Object? computeFreshKey() => userId;
  ///   ...
  /// }
  /// ```
  ///
  /// With this setup, if you dispatch `LoadUserProfile('123')`,
  /// then `LoadUserSettings('123')` will be aborted if dispatched within the
  /// fresh period of the first action.
  ///
  /// See also:
  /// - [freshKeyParams] when you want to differentiate fresh-keys by some
  ///   of the fields of the action.
  ///
  Object computeFreshKey() => (runtimeType, freshKeyParams());

  /// Map that stores the expiry time for each key.
  /// The value is the instant when the fresh period ends.
  Map<Object?, DateTime> get _freshKeyMap =>
      store.internalMixinProps.freshKeyMap;

  /// Removes the fresh-key used by this action, allowing an action using the
  /// same fresh-key to be dispatched and run again, right away.
  /// Calling this method will make the action stale immediately.
  /// You generally do not need to call this method, but if you do, use
  /// it only from your action's [reduce] or [before] methods.
  void removeKey() {
    _freshKeyMap.remove(_freshKey);
    _keysRemoved = true;
  }

  /// Removes all fresh-key, allowing all actions to be dispatched and
  /// run again right away.
  /// Calling this method will make all actions stale immediately.
  /// You generally do not need to call this method, but if you do, use
  /// it only from your action's [reduce] or [before] methods.
  void removeAllKeys() {
    _freshKeyMap.clear();
    _keysRemoved = true;
  }

  DateTime? _current;
  Object? _freshKey;
  bool _keysRemoved = false;
  DateTime? _newExpiry;

  @override
  bool abortDispatch() {
    _cannot_combine_mixins_Fresh_Throttle_NonReentrant_UnlimitedRetryCheckInternet();

    _keysRemoved = false; // good to reset here
    _freshKey = computeFreshKey();
    _current = _freshKeyMap[_freshKey];
    final now = DateTime.now().toUtc();

    if (ignoreFresh) {
      final expiry = _expiringKeyFrom(now);
      _freshKeyMap[_freshKey] = expiry;
      _newExpiry = expiry;
      _current = null; // Make it stale if the action fails.
      return false;
    }

    final expiresAt = _current;

    if (expiresAt == null || !expiresAt.isAfter(now)) {
      final expiry = _expiringKeyFrom(now);
      _freshKeyMap[_freshKey] = expiry;
      _newExpiry = expiry;
      return false;
    }

    // Still fresh, abort.
    _newExpiry = null;
    return true;
  }

  void
      _cannot_combine_mixins_Fresh_Throttle_NonReentrant_UnlimitedRetryCheckInternet() {
    _incompatible<Fresh, Throttle>(this);
    _incompatible<Fresh, NonReentrant>(this);
    _incompatible<Fresh, UnlimitedRetryCheckInternet>(this);
  }

  DateTime _expiringKeyFrom(DateTime now) =>
      now.add(Duration(milliseconds: freshFor));

  /// Remove keys whose expiry time is in the past or now.
  void _prune() {
    final now = DateTime.now().toUtc();
    _freshKeyMap.removeWhere((_, expiresAt) => !expiresAt.isAfter(now));
  }

  @override
  void after() {
    if (!_keysRemoved && status.originalError != null && _freshKey != null) {
      final current = _freshKeyMap[_freshKey];

      // Only roll back if the map still contains the expiry written by this action.
      if (current == _newExpiry) {
        if (_current == null) {
          // No previous expiry: remove key (stale).
          _freshKeyMap.remove(_freshKey);
        } else {
          // Restore previous expiry.
          _freshKeyMap[_freshKey] = _current!;
        }
      }
    }

    _prune();
  }
}

void _incompatible<T1, T2>(Object instance) {
  assert(
    instance is! T2,
    'The ${T1.toString().split('<').first} mixin '
    'cannot be combined with the ${T2.toString().split('<').first} mixin.',
  );
}
