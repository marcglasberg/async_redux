import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
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

/// The [NonReentrant] mixin can be used to abort the action in case the action
/// is still running from a previous dispatch. Just add `with NonReentrant`
/// to your action. For example:
///
/// ```dart
/// class SaveAction extends ReduxAction<AppState> with NonReentrant {
///   Future<String> reduce() async {
///     await http.put('http://myapi.com/save', body: 'data');
///   }}
/// ```
///
/// ## Advanced usage
///
/// The non-reentrant check is, by default, based on the action [runtimeType].
/// This means it will abort an action if another action of the same runtimeType
/// is currently running. If you want to check based on more than simply the
/// [runtimeType], you can override the [nonReentrantKeyParams] method.
/// For example, here we use a field of the action to differentiate:
///
/// ```dart
/// class SaveItem extends ReduxAction<AppState> with NonReentrant {
///    final String itemId;
///    SaveItem(this.itemId);
///
///    Object? nonReentrantKeyParams() => itemId;
///    ...
/// }
/// ```
///
/// With this setup, `SaveItem('A')` and `SaveItem('B')` can run in parallel,
/// but two `SaveItem('A')` cannot.
///
/// You can also use [computeNonReentrantKey] if you want different action types
/// to share the same non-reentrant key. Check the documentation of that method
/// for more information.
///
/// Notes:
/// - This mixin can safely be combined with [CheckInternet], [NoDialog], and [AbortWhenNoInternet].
/// - It should not be combined with other mixins that override [abortDispatch] or [after].
/// - It should not be combined with [Throttle], [UnlimitedRetryCheckInternet], or [Fresh].
///
mixin NonReentrant<St> on ReduxAction<St> {
  //
  /// By default the non-reentrant key is based on the action [runtimeType].
  /// Override [nonReentrantKeyParams] so that actions of the SAME TYPE
  /// but with different parameters do not block each other.
  ///
  /// For example:
  ///
  /// ```dart
  /// class SaveItem extends ReduxAction<AppState> with NonReentrant {
  ///   final String itemId;
  ///   SaveItem(this.itemId);
  ///
  ///   Object? nonReentrantKeyParams() => itemId;
  ///   ...
  /// }
  /// ```
  ///
  /// Now `SaveItem('A')` and `SaveItem('B')` can run in parallel,
  /// but two concurrent dispatches of `SaveItem('A')` will not both run.
  ///
  Object? nonReentrantKeyParams() => null;

  /// By default the non-reentrant key combines the action [runtimeType]
  /// with [nonReentrantKeyParams]. Override this method if you want
  /// different action types to share the same non-reentrant key.
  ///
  /// ```dart
  /// class SaveUser extends ReduxAction<AppState> with NonReentrant {
  ///   final String oderId;
  ///   SaveUser(this.oderId);
  ///
  ///   Object? computeNonReentrantKey() => orderId;
  ///   ...
  /// }
  ///
  /// class DeleteUser extends ReduxAction<AppState> with NonReentrant {
  ///   final String oderId;
  ///   DeleteUser(this.oderId);
  ///
  ///   Object? computeNonReentrantKey() => orderId;
  ///   ...
  /// }
  /// ```
  ///
  /// With this setup, `SaveUser('123')` and `DeleteUser('123')` cannot run
  /// at the same time because they share the same key.
  ///
  Object computeNonReentrantKey() => (runtimeType, nonReentrantKeyParams());

  /// The set of keys that are currently running.
  Set<Object?> get _nonReentrantKeySet =>
      store.internalMixinProps.nonReentrantKeySet;

  Object? _nonReentrantKey;

  @override
  bool abortDispatch() {
    _cannot_combine_mixins_Fresh_Throttle_NonReentrant_UnlimitedRetryCheckInternet();

    _nonReentrantKey = computeNonReentrantKey();

    // If the key is already in the set, abort.
    if (_nonReentrantKeySet.contains(_nonReentrantKey))
      return true;
    //
    // Otherwise, add the key and allow dispatch.
    else {
      _nonReentrantKeySet.add(_nonReentrantKey);
      return false;
    }
  }

  @override
  void after() {
    // Remove the key when the action finishes (success or failure).
    _nonReentrantKeySet.remove(_nonReentrantKey);
  }

  void
      _cannot_combine_mixins_Fresh_Throttle_NonReentrant_UnlimitedRetryCheckInternet() {
    _incompatible<NonReentrant, Fresh>(this);
    _incompatible<NonReentrant, Throttle>(this);
    _incompatible<NonReentrant, UnlimitedRetryCheckInternet>(this);
    _incompatible<NonReentrant, OptimisticCommand>(this);
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
///   internet but the action fails for some other reason. To retry indefinitely
///   until internet is available, use [UnlimitedRetryCheckInternet] instead.
/// - It should not be combined with [Debounce], [UnlimitedRetryCheckInternet].
/// - When combined with [OptimisticCommand], the retry logic is handled by
///   [OptimisticCommand] to avoid UI flickering. Only the
///   [OptimisticCommand.sendCommandToServer] call is retried, keeping the
///   optimistic state in place. See [OptimisticCommand] for more details.
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
    _cannot_combine_mixins_Retry_UnlimitedRetryCheckInternet_OptimisticSync_OptimisticSyncWithPush_ServerPush();

    // When combined with OptimisticCommand, we skip the retry logic here.
    // OptimisticCommand will handle retries internally to avoid UI flickering.
    // See OptimisticCommand.reduce for details.
    if (this is OptimisticCommand) {
      FutureOr<St?> newState = reduce();
      if (newState is Future) newState = await newState;
      return newState;
    }

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

  void
      _cannot_combine_mixins_Retry_UnlimitedRetryCheckInternet_OptimisticSync_OptimisticSyncWithPush_ServerPush() {
    _incompatible<Retry, UnlimitedRetryCheckInternet>(this);
    _incompatible<Retry, OptimisticSync>(this);
    _incompatible<Retry, OptimisticSyncWithPush>(this);
    _incompatible<Retry, ServerPush>(this);
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

/// The [OptimisticCommand] mixin is for actions that represent a command.
/// A command is something you want to run on the server once per dispatch.
/// Typical examples are:
///
/// * Create something (add todo, create comment, send message)
/// * Delete something
/// * Submit a form
/// * Upload a file
/// * Checkout, place order, confirm payment
///
/// This mixin gives fast UI feedback by applying an optimistic state change
/// immediately, then running the command on the server, and optionally rolling
/// back and reloading.
///
///
/// ## When to use the `OptimisticSync` mixin instead
///
/// Use [OptimisticSync] or [OptimisticSyncWithPush] when the action is a save
/// operation, meaning only the final value matters and intermediate values
/// can be skipped. Typical examples are:
///
/// * Like or follow toggle
/// * Settings switch
/// * Slider, checkbox
/// * Update a field where the last value wins
///
/// In save operations, users may tap many times quickly. `OptimisticSync` is
/// built for that and will coalesce rapid changes into a minimal number of
/// server calls. [OptimisticCommand] is not built for that.
///
///
/// ## The problem
///
/// Let's use a Todo app as an example. We want to save a new Todo to a
/// TodoList. This code saves the Todo, then reloads the TodoList from the cloud:
///
/// ```dart
/// class SaveTodo extends ReduxAction<AppState> {
///   final Todo newTodo;
///   SaveTodo(this.newTodo);
///
///   Future<AppState> reduce() async {
///     try {
///       // Saves the new Todo to the cloud.
///       await saveTodo(newTodo);
///     } finally {
///       // Loads the complete TodoList from the cloud.
///       var reloadedTodoList = await loadTodoList();
///       return state.copy(todoList: reloadedTodoList);
///     }
///   }
/// }
/// ```
///
/// The problem with the above code is that it may take a second to update the
/// todoList on screen, while we save then load.
///
/// The solution is to optimistically update the TodoList before saving:
///
/// ```dart
/// class SaveTodo extends ReduxAction<AppState> {
///   final Todo newTodo;
///   SaveTodo(this.newTodo);
///
///   Future<AppState> reduce() async {
///     // Updates the TodoList optimistically.
///     dispatch(UpdateStateAction((state)
///       => state.copy(todoList: state.todoList.add(newTodo))));
///
///     try {
///       // Saves the new Todo to the cloud.
///       await saveTodo(newTodo);
///     } finally {
///       // Loads the complete TodoList from the cloud.
///       var reloadedTodoList = await loadTodoList();
///       return state.copy(todoList: reloadedTodoList);
///     }
///   }
/// }
/// ```
///
/// That's better. But if saving fails, users still have to wait for the reload
/// until they see the reverted state. We can further improve this:
///
/// ```dart
/// class SaveTodo extends ReduxAction<AppState> {
///   final Todo newTodo;
///   SaveTodo(this.newTodo);
///
///   Future<AppState> reduce() async {
///     // Updates the TodoList optimistically.
///     var newTodoList = state.todoList.add(newTodo);
///     dispatchState(state.copy(todoList: newTodoList));
///
///     try {
///       // Saves the new Todo to the cloud.
///       await saveTodo(newTodo);
///     } catch (e) {
///       // If the state still contains our optimistic update, we rollback.
///       // If the state now contains something else, we do not rollback.
///       if (state.todoList == newTodoList) {
///         return state.copy(todoList: initialState.todoList); // Rollback.
///       }
///       rethrow;
///     } finally {
///       // Loads the complete TodoList from the cloud.
///       var reloadedTodoList = await loadTodoList();
///       dispatchState(state.copy(todoList: reloadedTodoList));
///     }
///   }
/// }
/// ```
///
/// Now the user sees the rollback immediately after the saving fails. The
/// [OptimisticCommand] mixin helps you implement this pattern easily, and
/// takes care of the edge cases.
///
/// ## How to use this mixin
///
/// You must provide:
/// * [optimisticValue] returns the optimistic value you want to apply right away
/// * [getValueFromState] extracts the current value from a given state
/// * [applyValueToState] applies a value to a given state and returns the new state
/// * [sendCommandToServer] runs the server command (it may use the action fields)
/// * [reloadFromServer] optionally reloads from the server (do not override to skip)
/// * [applyReloadResultToState] applies the reload result to the state (the default uses [applyValueToState])
///
/// Important details:
///
/// * The optimistic update is applied immediately.
///
/// * If [sendCommandToServer] fails, rollback happens only if the current state
///   still matches the optimistic value created by this dispatch. The rollback
///   restores the value from [initialState].
///
/// * Reload is optional. If implemented, it runs after [sendCommandToServer]
///   finishes, only in case of error (this can be changed by overriding
///   [shouldReload] to return true).
///
/// ### Complete example using the mixin
///
/// ```dart
/// class SaveTodo extends AppAction with OptimisticCommand {
///   final Todo newTodo;
///   SaveTodo(this.newTodo);
///
///   // The new Todo is going to be optimistically applied to the state, right away.
///   @override
///   Object? optimisticValue() => newTodo;
///
///   // We teach the action how to read the Todo from the state.
///   @override
///   Object? getValueFromState(AppState state) => state.todoList.getById(newTodo.id);
///
///   // Apply the value to the state.
///   @override
///   AppState applyValueToState(AppState state, Object? value)
///     => state.copy(todoList: state.todoList.add(newTodo));
///
///   // Contact the server to send the command (save the Todo). I
///   @override
///   Future<Todo> sendCommandToServer(Object? newTodo) async => await saveTodo(newTodo);
///
///   // If the server returns a value, we may apply it to the state.
///   @override
///   AppState applyServerResponseToState(AppState state, Todo todo)
///     => state.copy(todoList: state.todoList.add(todo));
///
///   // Reload from the cloud (in case of error).
///   @override
///   Future<Object?> reloadFromServer() async => await loadTodo();
/// }
/// ```
///
///
/// ## Non-reentrant behavior
///
/// [OptimisticCommand] is always non-reentrant. If the same action is
/// dispatched while a previous dispatch is still running, the new dispatch
/// is aborted. This prevents race conditions such as:
///
/// * Conflicting optimistic updates overwriting each other
/// * Incorrect rollback behavior (the rollback check may no longer match)
/// * Race conditions in the reload phase
/// * Server side conflicts from concurrent requests
///
/// Your UI should let the user know that the command is in progress,
/// so they do not try to dispatch it again until it finishes. That's easy
/// to do with AsyncRedux, just check if the action is in progress:
///
/// ```dart
/// bool isSaving = context.isWaiting(SaveTodo);
/// ```
///
/// By default, the non-reentrant check is based on the action [runtimeType].
/// If your action has parameters and you want to allow concurrent dispatches
/// for different parameters (for example, saving different items), override
/// [nonReentrantKeyParams]. For example:
///
/// ```dart
/// class SaveTodo extends AppAction with OptimisticCommand {
///   final String orderId;
///   SaveTodo(this.orderId);
///
///   @override
///   Object? nonReentrantKeyParams() => orderId;
///   ...
/// }
/// ```
///
/// This allows SaveTodo('A') and SaveTodo('B') to run concurrently, while
/// blocking concurrent dispatches of SaveTodo('A') with itself.
///
/// This is useful for commands that you **do** want to run in parallel,
/// as long as they are for different items. Common examples include:
///
/// * Uploading multiple files at the same time (key by fileId)
/// * Sending multiple chat messages at the same time (key by clientMessageId)
/// * Enqueuing multiple jobs at the same time (key by jobId)
///
/// In these cases, each key runs non-reentrantly, but different keys can run
/// concurrently.
///
/// You can also use [computeNonReentrantKey] if you want different action types
/// to share the same non-reentrant key. Check the documentation of that method
/// for more information.
///
///
/// ## [Retry]
///
/// When combined with [Retry], only the [sendCommandToServer] call is retried,
/// not the optimistic update or rollback. This prevents UI flickering that
/// would otherwise occur if the entire reduce was retried on each attempt.
///
/// The optimistic state remains in place during retries, and rollback only
/// happens if all retry attempts fail.
///
///
/// # [CheckInternet] or [AbortWhenNoInternet]
///
/// When combined with [CheckInternet] and [AbortWhenNoInternet], when offline:
///
/// * No optimistic state is applied
/// * No lock is acquired
/// * No server call is attempted
/// * The action fails and your dialog shows (for [CheckInternet])
///
///
/// Notes:
/// - Equality checks use the == operator. Make sure your value type implements
///   == in a way that makes sense for optimistic checks.
/// - It can be combined with [Retry], [CheckInternet] and [AbortWhenNoInternet].
/// - It should not be combined with [NonReentrant], [Throttle], [Debounce],
///   [Fresh], [UnlimitedRetryCheckInternet], [UnlimitedRetries],
///   [OptimisticSync], [OptimisticSyncWithPush], or [ServerPush].
///
/// See also:
/// * [OptimisticSync] and [OptimisticSyncWithPush] for save operations.
///
mixin OptimisticCommand<St> on ReduxAction<St> {
  //
  /// Override this method to return the value that you want to update, and
  /// that you want to apply optimistically to the state.
  ///
  /// You can access the fields of the action, and the current [state], and
  /// return the new value.
  ///
  /// ```dart
  /// Object? optimisticValue() => newTodo;
  /// ```
  Object? optimisticValue();

  /// Using the given [state], you should apply the given [value] to it, and
  /// return the result. This will be used to apply the optimistic value to
  /// the state, and also later to rollback, if necessary, by applying the
  /// initial value.
  ///
  /// ```dart
  /// AppState applyValueToState(state, newTodoList)
  ///   => state.copy(todoList: newTodoList);
  /// ```
  St applyValueToState(St state, Object? value);

  /// Using the given [state], you should return the current value from that
  /// state. This is used to check if the state still contains the optimistic
  /// value, so the mixin knows whether it is safe to rollback.
  ///
  /// ```dart
  /// Object? getValueFromState(AppState state) => state.todoList;
  /// ```
  Object? getValueFromState(St state);

  /// You should save the [optimisticValue] or other related value in the cloud,
  /// and optionally return the server's response.
  ///
  /// Note: You can ignore [optimisticValue] and use the action fields instead,
  /// if that makes more sense for your API.
  ///
  /// If [sendCommandToServer] returns a non-null value, that value will be
  /// passed to [applyServerResponseToState] to update the state.
  ///
  /// ```dart
  /// Future<Object?> sendCommandToServer(newTodoList) async {
  ///   var response = await saveTodo(newTodo);
  ///   return response; // Return server-confirmed value, or null.
  /// }
  /// ```
  Future<Object?> sendCommandToServer(Object? optimisticValue);

  /// Override [applyServerResponseToState] to return a new state, where the
  /// given [serverResponse] (previously received from the server when running
  /// [sendCommandToServer]) is applied to the current [state]. Example:
  ///
  /// ```dart
  /// AppState? applyServerResponseToState(state, serverResponse) =>
  ///     state.copyWith(todoList: serverResponse.todoList);
  /// ```
  ///
  /// Note [serverResponse] is never `null` here, because this method is only
  /// called when [sendCommandToServer] returned a non-null value.
  ///
  /// If you decide you DO NOT want to apply the server response to the state,
  /// simply return `null`.
  ///
  St? applyServerResponseToState(St state, Object serverResponse) => null;

  /// Override to reload the value from the cloud.
  /// If you want to skip reload, do not override this method.
  ///
  /// Note: If you are using a realtime database or WebSockets to receive
  /// server pushed updates, you may not need to reload here.
  ///
  /// ```dart
  /// Future<Object?> reloadFromServer() => loadTodoList();
  /// ```
  Future<Object?> reloadFromServer() {
    throw UnimplementedError();
  }

  /// Returns the state to apply when the command fails and the mixin decides
  /// it is safe to rollback.
  ///
  /// This method is called only when:
  /// * [sendCommandToServer] throws, AND
  /// * [shouldRollback] returns true. By default it returns true only if the
  ///   current value in the store still matches the optimistic value created
  ///   by this dispatch (so we do not rollback over newer changes).
  ///
  /// Parameters:
  ///
  /// * [initialValue] is the value extracted from [initialState] using
  ///   [getValueFromState]. It represents what the value was when this action
  ///   was first dispatched.
  ///
  /// * [optimisticValue] is the value returned by [optimisticValue] and applied
  ///   optimistically by this dispatch.
  ///
  /// * [error] is the error thrown by [sendCommandToServer].
  ///
  /// By default, the mixin restores [initialValue] by calling [applyValueToState].
  ///
  /// Override this method if rollback is not simply "put the old value back".
  /// For example, you may want to:
  /// * Keep the optimistic item but mark it as failed.
  /// * Remove only the item you added, while keeping other local changes.
  /// * Roll back multiple parts of the state, not just the value handled by
  ///   [applyValueToState].
  ///
  /// Return `null` to skip rollback even when the mixin would normally rollback.
  ///
  St? rollbackState({
    required Object? initialValue,
    required Object? optimisticValue,
    required Object error,
  }) =>
      applyValueToState(state, initialValue);

  /// Returns true if the mixin should rollback after [sendCommandToServer]
  /// fails. This method is called only when [sendCommandToServer] throws.
  ///
  /// The default behavior is:
  /// Rollback only if the current value in the store still matches the
  /// optimistic value created by this dispatch. This avoids rolling back over
  /// newer changes that may have happened while the request was in flight.
  ///
  /// Override this if you need a different safety rule. For example:
  /// * You want to always rollback, even if something else changed.
  /// * You want to rollback only if a specific item is still present.
  /// * You want to rollback only for some errors.
  ///
  bool shouldRollback({
    required Object? currentValue,
    required Object? initialValue,
    required Object? optimisticValue,
    required Object error,
  }) {
    // Default: rollback only if we are still seeing our own optimistic value.
    if (currentValue is ImmutableCollection &&
        optimisticValue is ImmutableCollection) {
      return currentValue.same(optimisticValue);
    } else {
      return currentValue == optimisticValue;
    }
  }

  /// Whether the mixin should call [reloadFromServer].
  ///
  /// This method is called in `finally`, both on success and on error, before
  /// the reload happens.
  ///
  /// Parameters:
  /// * [currentValue] is the value currently in the store (extracted with
  ///   [getValueFromState]) at the moment we are deciding whether to reload.
  ///
  /// * [lastAppliedValue] is the last value this action applied for the same
  ///   state slice. It is the optimistic value on success, or the rollback value
  ///   if rollback was applied.
  ///
  /// * [optimisticValue] is the value returned by [optimisticValue] and applied
  ///   optimistically by this dispatch.
  ///
  /// * [rollbackValue] is `null` if no rollback state was applied. If rollback
  ///   was applied, this is the value extracted from the rollback state using
  ///   [getValueFromState].
  ///
  /// * [error] is `null` on success, or the error thrown by [sendCommandToServer]
  ///   on failure.
  ///
  /// Default behavior:
  /// Returns true, meaning: If [reloadFromServer] is implemented, we reload.
  ///
  /// Override this method if you want to skip reloading in some cases.
  /// For example, reload only on error, or skip reload when the value already
  /// changed to something else. For example:
  ///
  /// ```dart
  /// bool shouldReload(...) => currentValue == lastAppliedValue;
  /// bool shouldApplyReload(...) => currentValue == lastAppliedValue;
  /// ```
  ///
  bool shouldReload({
    required Object? currentValue,
    required Object? lastAppliedValue,
    required Object? optimisticValue,
    required Object? rollbackValue,
    required Object? error, // null on success
  }) =>
      error != null;

  /// Returns true if the mixin should apply the result returned by
  /// [reloadFromServer] to the state.
  ///
  /// This method is called after [reloadFromServer] completes, both on success
  /// and on error.
  ///
  /// Parameters are the same as [shouldReload], plus:
  /// * [reloadResult] is whatever [reloadFromServer] returned.
  ///
  /// Default behavior:
  /// Always apply the reload result. This matches the common expectation that
  /// if you chose to reload, the server is the source of truth.
  ///
  /// Override this method if you want to avoid overwriting newer local changes,
  /// or if you need custom rules based on [reloadResult] or [error].
  ///
  bool shouldApplyReload({
    required Object? currentValue,
    required Object? lastAppliedValue,
    required Object? optimisticValue,
    required Object? rollbackValue,
    required Object? reloadResult,
    required Object? error, // null on success
  }) =>
      true;

  /// Applies the result returned by [reloadFromServer] to the state.
  ///
  /// Override this method when [reloadFromServer] returns something that is not
  /// the same type or shape expected by [applyValueToState], or when applying
  /// the reload requires updating multiple parts of the state.
  ///
  /// Return `null` to ignore the reload result.
  ///
  St? applyReloadResultToState(St state, Object? reloadResult) =>
      applyValueToState(state, reloadResult);

  /// By default the non-reentrant key is based on the action [runtimeType].
  /// Override [nonReentrantKeyParams] so that actions of the SAME TYPE
  /// but with different parameters do not block each other.
  ///
  /// For example:
  ///
  /// ```dart
  /// class SaveItem extends AppAction with OptimisticCommand {
  ///   final String itemId;
  ///   SaveItem(this.itemId);
  ///
  ///   Object? nonReentrantKeyParams() => itemId;
  ///   ...
  /// }
  /// ```
  ///
  /// Now `SaveItem('A')` and `SaveItem('B')` can run in parallel,
  /// but two concurrent dispatches of `SaveItem('A')` will not both run.
  ///
  Object? nonReentrantKeyParams() => null;

  /// By default the non-reentrant key combines the action [runtimeType]
  /// with [nonReentrantKeyParams]. Override this method if you want
  /// different action types to share the same non-reentrant key.
  ///
  /// ```dart
  /// class SaveUser extends ReduxAction<AppState> with OptimisticCommand {
  ///   final String oderId;
  ///   SaveUser(this.oderId);
  ///
  ///   Object? computeNonReentrantKey() => orderId;
  ///   ...
  /// }
  ///
  /// class DeleteUser extends ReduxAction<AppState> with OptimisticCommand {
  ///   final String oderId;
  ///   DeleteUser(this.oderId);
  ///
  ///   Object? computeNonReentrantKey() => orderId;
  ///   ...
  /// }
  /// ```
  ///
  /// With this setup, `SaveUser('123')` and `DeleteUser('123')` cannot run
  /// at the same time because they share the same key.
  ///
  Object computeNonReentrantKey() => (runtimeType, nonReentrantKeyParams());

  @override
  Future<St?> reduce() async {
    // Updates the value optimistically.
    final optimistic = optimisticValue();
    dispatchState(applyValueToState(state, optimistic));

    Object? commandError;
    Object? lastAppliedValue = optimistic; // what this action last wrote
    Object? rollbackValue; // value slice after rollback, if any

    try {
      // Saves the new value to the cloud.
      // If this action also uses the Retry mixin, we handle retries here
      // to avoid UI flickering (applying/rolling back on each retry attempt).
      final serverResponse = await _sendCommandWithRetryIfNeeded(optimistic);

      // Apply server response if not null.
      if (serverResponse != null) {
        final St? newState = applyServerResponseToState(state, serverResponse);

        if (newState != null) {
          dispatchState(newState);

          // Keep lastAppliedValue in sync with what we just wrote for the slice.
          lastAppliedValue = getValueFromState(newState);
        }
      }
    } catch (error) {
      commandError = error;

      // Decide if it is safe to rollback (default: only if we are still seeing
      // our own optimistic value, to avoid undoing newer changes made while
      // the request was in flight).
      final currentValue = getValueFromState(state);
      final initialValue = getValueFromState(initialState);

      if (shouldRollback(
        currentValue: currentValue,
        initialValue: initialValue,
        optimisticValue: optimistic,
        error: error,
      )) {
        final rollback = rollbackState(
          initialValue: initialValue,
          optimisticValue: optimistic,
          error: error,
        );

        if (rollback != null) {
          dispatchState(rollback);

          // Update "lastAppliedValue" to match what rollback wrote for the value slice.
          rollbackValue = getValueFromState(rollback);
          lastAppliedValue = rollbackValue;
        }
      }

      rethrow;
    } finally {
      try {
        // Snapshot current value before deciding whether to reload.
        final Object? currentValueBefore = getValueFromState(state);

        final bool doReload = shouldReload(
          currentValue: currentValueBefore,
          lastAppliedValue: lastAppliedValue,
          optimisticValue: optimistic,
          rollbackValue: rollbackValue,
          error: commandError, // null on success
        );

        if (doReload) {
          final Object? reloadResult = await reloadFromServer();

          // Re-read after await, because state may have changed while reloading.
          final Object? currentValueAfter = getValueFromState(state);

          final bool apply = shouldApplyReload(
            currentValue: currentValueAfter,
            lastAppliedValue: lastAppliedValue,
            optimisticValue: optimistic,
            rollbackValue: rollbackValue,
            reloadResult: reloadResult,
            error: commandError, // null on success
          );

          if (apply) {
            final St? newState = applyReloadResultToState(state, reloadResult);
            if (newState != null) dispatchState(newState);
          }
        }
      } on UnimplementedError catch (_) {
        // If reloadFromServer was not implemented, do nothing.
      } catch (reloadError) {
        // Important: Do not let reload failure hide the original command error.
        if (commandError == null) rethrow;
      }
    }

    return null;
  }

  /// When combined with Retry, this method retries only the [sendCommandToServer]
  /// call, keeping the optimistic update in place and avoiding UI flickering.
  Future<Object?> _sendCommandWithRetryIfNeeded(
      Object? _optimisticValue) async {
    // If this action doesn't use the Retry mixin,
    // just call sendCommandToServer directly.
    if (this is! Retry) {
      return sendCommandToServer(_optimisticValue);
    }

    // Access the Retry mixin's properties via casting.
    final retryMixin = this as Retry<St>;

    while (true) {
      try {
        return await sendCommandToServer(_optimisticValue);
      } catch (error) {
        retryMixin._attempts++;

        // If maxRetries is reached (and not unlimited), rethrow the error.
        if ((retryMixin.maxRetries >= 0) &&
            (retryMixin._attempts > retryMixin.maxRetries)) {
          rethrow;
        }

        // Wait before retrying.
        final currentDelay = retryMixin.nextDelay();
        await Future.delayed(currentDelay);
        // Loop continues, retrying sendCommandToServer.
      }
    }
  }

  /// The set of keys that are currently running.
  Set<Object?> get _nonReentrantCommandKeySet =>
      store.internalMixinProps.nonReentrantKeySet;

  Object? _nonReentrantCommandKey;

  @override
  bool abortDispatch() {
    _cannot_combine_mixins_OptimisticCommand();
    _cannot_combine_mixins_UnlimitedRetryCheckInternet_OptimisticCommand_OptimisticSync_OptimisticSyncWithPush_ServerPush();

    _nonReentrantCommandKey = computeNonReentrantKey();

    // If the key is already in the set, abort.
    if (_nonReentrantCommandKeySet.contains(_nonReentrantCommandKey))
      return true;
    //
    // Otherwise, add the key and allow dispatch.
    else {
      _nonReentrantCommandKeySet.add(_nonReentrantCommandKey);
      return false;
    }
  }

  @override
  void after() {
    // Remove the key when the action finishes (success or failure).
    _nonReentrantCommandKeySet.remove(_nonReentrantCommandKey);
  }

  /// Only [Retry], [CheckInternet] and [AbortWhenNoInternet] can be combined
  /// with [OptimisticCommand].
  ///
  void _cannot_combine_mixins_OptimisticCommand() {
    _incompatible<OptimisticCommand, NonReentrant>(this);
    _incompatible<OptimisticCommand, Fresh>(this);
    _incompatible<OptimisticCommand, Throttle>(this);
    _incompatible<OptimisticCommand, Debounce>(this);
    _incompatible<OptimisticCommand, UnlimitedRetries>(this);
  }

  void
      _cannot_combine_mixins_UnlimitedRetryCheckInternet_OptimisticCommand_OptimisticSync_OptimisticSyncWithPush_ServerPush() {
    _incompatible<OptimisticCommand, UnlimitedRetryCheckInternet>(this);
    _incompatible<OptimisticCommand, OptimisticSync>(this);
    _incompatible<OptimisticCommand, OptimisticSyncWithPush>(this);
    _incompatible<OptimisticCommand, ServerPush>(this);
  }
}

/// Throttling ensures the action will be dispatched at most once in the
/// specified throttle period. It acts as a simple rate limit, so the action
/// does not run too often.
///
/// If an action is dispatched multiple times within a throttle period, only
/// the first dispatch runs and the others are aborted. After the throttle
/// period has passed, the next dispatch is allowed to run again, which starts
/// a new throttle period.
///
/// This is useful when an action may be triggered many times in a short time,
/// for example by fast user input or widget rebuilds, but you only want it to
/// run from time to time instead of on every dispatch.
///
/// For example, if you are using a `StatefulWidget` that needs to load some
/// information, you can dispatch the loading action when the widget is
/// created in `initState()` and specify a throttle period so that it does not
/// reload that information too often:
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
/// and then:
///
/// ```dart
/// class LoadInformation extends ReduxAction<AppState> with Throttle {
///
///   int throttle = 5000;
///
///   Future<AppState> reduce() async {
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
/// The throttle lock is NOT removed if the action fails. This means that if
/// the action throws and you dispatch it again within the throttle period, it
/// will not run a second time.
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
/// be dispatched again right away. Note, this currently implemented in the
/// [after] method, which means you can override it to customize this behavior:
///
/// ```dart
/// @override
/// void after() {
///   if (removeLockOnError && (status.originalError != null)) removeLock();
/// }
/// ```
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
    _incompatible<Throttle, OptimisticCommand>(this);
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
/// IMPORTANT: This mixin combines [Retry], [UnlimitedRetries],
/// [AbortWhenNoInternet] and [NonReentrant] mixins, but there is
/// difference. Combining [Retry] with [CheckInternet] or [AbortWhenNoInternet]
/// will not retry when there is no internet. It will only retry if there IS
/// internet but the action fails for some other reason. To retry indefinitely
/// until internet is available, then you should use [UnlimitedRetryCheckInternet].
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
/// - All retries will be printed to the console.
///
mixin UnlimitedRetryCheckInternet<St> on ReduxAction<St> {
  //
  @override
  bool abortDispatch() {
    _cannot_combine_mixins_Fresh_Throttle_NonReentrant_UnlimitedRetryCheckInternet();
    _cannot_combine_mixins_CheckInternet_AbortWhenNoInternet_UnlimitedRetryCheckInternet();
    _cannot_combine_mixins_Debounce_Retry_UnlimitedRetryCheckInternet();
    _cannot_combine_mixins_UnlimitedRetryCheckInternet_OptimisticCommand_OptimisticSync_OptimisticSyncWithPush_ServerPush();

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
    _incompatible<UnlimitedRetryCheckInternet, Debounce>(this);
    _incompatible<UnlimitedRetryCheckInternet, Retry>(this);
  }

  void
      _cannot_combine_mixins_UnlimitedRetryCheckInternet_OptimisticCommand_OptimisticSync_OptimisticSyncWithPush_ServerPush() {
    _incompatible<UnlimitedRetryCheckInternet, OptimisticCommand>(this);
    _incompatible<UnlimitedRetryCheckInternet, OptimisticSync>(this);
    _incompatible<UnlimitedRetryCheckInternet, OptimisticSyncWithPush>(this);
    _incompatible<UnlimitedRetryCheckInternet, ServerPush>(this);
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
    _incompatible<Fresh, OptimisticCommand>(this);
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

      // Only rollback if the map still contains the expiry written by this action.
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

/// The [OptimisticSync] mixin is designed for actions where user interactions
/// (like toggling a "like" button) should update the UI immediately and
/// send the updated value to the server, making sure the server and the UI
/// are eventually consistent.
///
/// ---
///
/// The action is not throttled or debounced in any way, and every dispatch
/// applies an optimistic update to the state immediately. This guarantees a
/// very good user experience, because there is immediate feedback on every
/// interaction.
///
/// However, while the first updated value (created by the first time the action
/// is dispatched) is immediately sent to the server, any other value changes
/// that occur while the first request is in flight will NOT be sent immediately.
///
/// Instead, when the first request completes, it checks if the state is still
/// the same as the value that was sent. If not, a follow-up request is sent
/// with the latest value. This process repeats until the state stabilizes.
///
/// Note this guarantees that only **one** request is in flight at a time per
/// key, potentially reducing the number of requests sent to the server while
/// still coalescing intermediate changes.
///
/// Optionally:
///
/// * If the server responds with a value, that value is applied to the state.
///   This is useful when the server normalizes or modifies values.
///
/// * When the state finally stabilizes and the request finishes, a callback
///   function is called, allowing you to perform side-effects.
///
/// * In special, if the last request fails, the optimistic state remains, but
///   in the callback you can then load the current state from the server or
///   handle the error as you see first by returning a value that will be
///   applied to the state.
///
/// In other words, the mixin makes it easy for you to maintain perfect UI
/// responsiveness while minimizing server load, and making sure the server and
/// the UI eventually agree on the same value.
///
/// ---
///
/// ## How it works
///
/// 1. **Immediate UI feedback**: Every dispatch applies [valueToApply] to the
///    state immediately via [applyOptimisticValueToState].
///
/// 2. **Single in-flight request**: Only one request runs at a time per key
///    (as defined by [optimisticSyncKeyParams]). The first dispatch acquires a lock
///    and calls [sendValueToServer] to send a request to the server.
///
/// 3. **OptimisticSync changes**: If the store state changed while a request started
///    by [sendValueToServer] was in flight (for example, the user tapped a
///    "like" button again while the first request was pending), a follow-up
///    request is automatically sent after the current one completes. The change
///    is detected by comparing [getValueFromState] with the sent value returned
///    by [valueToApply].
///
/// 4. **No unnecessary requests**: If, while the request is in-flight, the
///    state changes but then returns to the same value as before (for example,
///    the user tapped a "like" button again TWICE while the first request was
///    pending), [getValueFromState] matches the sent value and no follow-up
///    request is needed.
///
/// 5. **Server response handling**: If [sendValueToServer] returns a non-null
///    value, it is applied to the state via [applyServerResponseToState] when
///    the state stabilizes. This is optional but useful.
///
/// 6. **Completion callback**: When the state stabilizes and the last request
///    finishes, [onFinish] is called, allowing you to handle errors or perform
///    side-effects, like showing a message or reloading data.
///
/// ```
/// State: liked = false (server confirmed)
///
/// User taps LIKE:
///   → State: liked = true (optimistic)
///   → Lock acquired, Request 1 sends: setLiked(true)
///
/// User taps UNLIKE (Request 1 still in flight):
///   → State: liked = false (optimistic)
///   → No request sent (locked)
///
/// User taps LIKE (Request 1 still in flight):
///   → State: liked = true (optimistic)
///   → No request sent (locked)
///
/// Request 1 completes:
///   → Sent value was `true`, current state is `true`
///   → They match, no follow-up needed, lock released
/// ```
///
/// If the state had been `false` when Request 1 completed, a follow-up
/// Request 2 would automatically be sent with `false`.
///
/// ## Usage
///
/// ```dart
/// class ToggleLike extends AppAction with OptimisticSync<AppState, bool> {
///   final String itemId;
///   ToggleLike(this.itemId);
///
///   // Different items can have concurrent requests
///   @override
///   Object? optimisticSyncKeyParams() => itemId;
///
///   // The new value to apply (toggle current state)
///   @override
///   bool valueToApply() => !state.items[itemId].liked;
///
///   // Apply the optimistic value to the state
///   @override
///   AppState applyOptimisticValueToState(bool isLiked) =>
///       state.copyWith(items: state.items.setLiked(itemId, isLiked));
///
///   // Apply the server response to the state (can be different from optimistic)
///   @override
///   AppState? applyServerResponseToState(Object? serverResponse) =>
///       state.copyWith(items: state.items.setLiked(itemId, serverResponse as bool));
///
///   // Read the current value from state (used to detect if follow-up needed)
///   @override
///   Object? getValueFromState(AppState state) => state.items[itemId].liked;
///
///   // Send the value to the server, optionally return server-confirmed value
///   @override
///   Future<Object?> sendValueToServer(Object? optimisticValue) async {
///     final response = await api.setLiked(itemId, optimisticValue);
///     return response.liked; // Or return null if server doesn't return a value
///   }
///
///   // Called when state stabilizes (optional). Return state to apply, or null.
///   @override
///   Future<AppState?> onFinish(Object? error) async {
///     if (error != null) {
///       // Handle error: reload from server to restore correct state
///       final reloaded = await api.getItem(itemId);
///       return state.copyWith(items: state.items.update(itemId, reloaded));
///     }
///     return null; // Success, no state change needed
///   }
/// }
/// ```
///
/// ## Server response handling
///
/// [sendValueToServer] can return a value from the server. If non-null, this value is
/// applied to the state **only when the state stabilizes** (no pending changes).
/// This is useful when:
/// - The server normalizes or modifies values
/// - You want to confirm the server accepted the change
/// - The server returns the current state after the update
///
/// If the server response differs from the current optimistic state when the
/// state stabilizes, a follow-up request will be sent automatically.
///
/// ## Error handling
///
/// On failure, the optimistic state remains and [onFinish] is called with
/// the error.
///
/// ## Difference from other mixins
///
/// - **vs [Debounce]**: Debounce waits for inactivity before sending *any*
///   request. OptimisticSync sends the first request immediately and only coalesces
///   subsequent changes.
///
/// - **vs [NonReentrant]**: NonReentrant aborts subsequent dispatches entirely.
///   OptimisticSync applies the optimistic update and queues a follow-up request.
///
/// - **vs [OptimisticCommand]**: OptimisticCommand has rollback logic that breaks
///   with concurrent dispatches. OptimisticSync is designed for rapid toggling where
///   only the final state matters.
///
/// ## Rollback support
///
/// The mixin exposes two fields to help with rollback logic in [onFinish].
///
/// - [optimisticValue]: The value returned by [valueToApply] for the current
///   dispatch. This is set once at the start of reduce() and remains available
///   throughout the action lifecycle, including in [onFinish].
///
/// - [lastSentValue]: The most recent value passed to [sendValueToServer].
///   Updated right before each server request. Useful for debugging/logging.
///
/// Example rollback guard using [optimisticValue]:
///
/// ```dart
/// Future<St?> onFinish(Object? error) async {
///   if (error != null) {
///     // Only rollback if the state still reflects our optimistic update.
///     // If the user made another change, don't overwrite it.
///     if (getValueFromState(state) == optimisticValue) {
///       return applyOptimisticValueToState(state, initialValue);
///     }
///   }
///   return null;
/// }
/// ```
///
/// Another possibility is to use [onFinish] to reload the value from the
/// server. Here is an example:
///
/// ```dart
/// Future<St?> onFinish(Object? error) async {
///   try {
///     final fresh = await api.fetchValue(itemId);
///     return applyServerResponseToState(state, fresh);
///   } catch (_) {
///     return null; // Ignore reload failures and keep the current state.
///   }
/// }
/// ```
///
/// Notes:
/// - It can be combined with [CheckInternet] and [AbortWhenNoInternet].
/// - It should not be combined with [NonReentrant], [Throttle], [Debounce],
///   [Fresh], [UnlimitedRetryCheckInternet], [UnlimitedRetries],
///   [OptimisticCommand], [OptimisticSyncWithPush], or [ServerPush].
///
mixin OptimisticSync<St, T> on ReduxAction<St> {
  //
  /// The optimistic value that was applied to the state for the current
  /// dispatch. This is set once at the start of [reduce] to the value returned
  /// by [valueToApply], and remains available in [onFinish] for rollback logic.
  late final T optimisticValue;

  /// The most recent value that was passed to [sendValueToServer].
  /// This is updated right before each server request (including follow-ups).
  /// Useful for debugging, logging, or implementing custom guards.
  /// Reset to `null` at the start of each dispatch.
  T? lastSentValue;

  /// Optionally, override [optimisticSyncKeyParams] to differentiate coalescing by
  /// action parameters. For example, if you have a like button per item,
  /// return the item ID so that different items can have concurrent requests:
  ///
  /// ```dart
  /// Object? optimisticSyncKeyParams() => itemId;
  /// ```
  ///
  /// You can also return a record of values:
  ///
  /// ```dart
  /// Object? optimisticSyncKeyParams() => (userId, itemId);
  /// ```
  ///
  /// See also: [computeOptimisticSyncKey], which uses this method by default to
  /// build the key.
  ///
  Object? optimisticSyncKeyParams() => null;

  /// By default the coalescing key combines the action [runtimeType]
  /// with [optimisticSyncKeyParams]. Override this method if you want
  /// different action types to share the same coalescing key.
  Object computeOptimisticSyncKey() => (runtimeType, optimisticSyncKeyParams());

  /// Override [valueToApply] to return the value that should be applied
  /// optimistically to the state and then sent to the server. This is called
  /// synchronously and only once per dispatch, when the reducer starts.
  ///
  /// The value to apply can be anything, and is usually constructed from the
  /// action fields, and/or from the current [state]. Valid examples are:
  ///
  /// ```dart
  /// // Set the like button to "liked".
  /// bool valueToApply() => true
  ///
  /// // Set the like button to "liked" or "not liked", according to
  /// // the field `isLiked` of the action.
  /// bool valueToApply() => isLiked;
  ///
  /// // Toggles the current state of the like button.
  /// bool valueToApply() => !state.items[itemId].isLiked;
  /// ```
  ///
  T valueToApply();

  /// Override [applyOptimisticValueToState] to return a new state where the
  /// given [optimisticValue] is applied to the current [state].
  ///
  /// Note, Async Redux calculated [optimisticValue] by previously
  /// calling [valueToApply].
  ///
  /// ```dart
  /// AppState applyOptimisticValueToState(state, isLiked) =>
  ///     state.copyWith(items: state.items.setLiked(itemId, isLiked));
  /// ```
  St applyOptimisticValueToState(St state, T optimisticValue);

  /// Override [applyServerResponseToState] to return a new state, where the
  /// given [serverResponse] (previously received from the server when running
  /// [sendValueToServer]) is applied to the current [state]. Example:
  ///
  /// ```dart
  /// AppState? applyServerResponseToState(state, serverResponse) =>
  ///     state.copyWith(items: state.items.setLiked(itemId, serverResponse.date.isLiked));
  /// ```
  ///
  /// Note [serverResponse] is never `null` here, because this method is only
  /// called when [sendValueToServer] returned a non-null value.
  ///
  /// If you decide you DO NOT want to apply the server response to the state,
  /// simply return `null`.
  ///
  St? applyServerResponseToState(St state, Object serverResponse);

  /// Override [getValueFromState] to extract the value from the current [state].
  /// This value will be later compared to one returned by [valueToApply] to
  /// determine if a follow-up request is needed.
  ///
  /// Here is the rationale:
  /// When a request completes, if the value in the state is different from
  /// the value that was optimistically applied, it means the user changed it
  /// again while the request was in flight, so a follow-up request is needed
  /// to sync the latest value with the server.
  ///
  /// ```dart
  /// bool getValueFromState(state) => state.items[itemId].liked;
  /// ```
  T getValueFromState(St state);

  /// Override [sendValueToServer] to send the given [optimisticValue] to the
  /// server, and optionally return the server's response.
  ///
  /// Note, Async Redux calculated [optimisticValue] by previously
  /// calling [valueToApply].
  ///
  /// If [sendValueToServer] returns a non-null value, that value will be
  /// applied to the state, but **only when the state stabilizes** (i.e., when
  /// there are no more pending requests and the lock is about to be released).
  /// This prevents the server response from overwriting subsequent user
  /// interactions that occurred while the request was in flight.
  ///
  /// The value in the store state may change while the request is in flight.
  /// For example, if the user presses a like button once, but then
  /// presses it again before the first request finishes, the value in the
  /// store state is now different from the optimistic value that was previously
  /// applied. In this case, [sendValueToServer] will be called again to create
  /// a follow-up request to sync the updated state with the server.
  ///
  /// If [sendValueToServer] returns `null`, the current optimistic state is
  /// assumed to be correct and valid.
  ///
  /// ```dart
  /// Future<Object?> saveValue(Object? optimisticValue) async {
  ///   var response = await api.setLiked(itemId, optimisticValue);
  ///   return response?.liked; // Return server-confirmed value, or null.
  /// }
  /// ```
  Future<Object?> sendValueToServer(Object? optimisticValue);

  /// Optionally, override [onFinish] to run any code after the synchronization
  /// process completes. For example, you might want to reload related data from
  /// the server, show a confirmation message, or perform cleanup.
  ///
  /// Note [onFinish] is called in both success and failure scenarios, but only
  /// after the state stabilizes for this key (that is, after the last request
  /// finishes and no follow-up request is needed).
  ///
  /// Important: The synchronization lock is released *before* [onFinish] runs.
  /// This means new dispatches for the same key may start a new request while
  /// [onFinish] is still executing.
  ///
  /// The [error] parameter will be `null` on success, or contain the error
  /// object if the request failed.
  ///
  /// If [onFinish] returns a non-null state, it will be applied automatically.
  /// If it returns `null`, no state change is made.
  ///
  /// ```dart
  /// Future<St?> onFinish(Object? error) async {
  ///   if (error == null) {
  ///     // Success: show confirmation, log analytics, etc.
  ///     return null;
  ///   } else {
  ///     // Failure: reload data from the server.
  ///     var reloadedInfo = await api.loadInfo();
  ///     return state.copy(info: reloadedInfo);
  ///   }
  /// }
  /// ```
  ///
  /// Important:
  ///
  /// - If `onFinish(error)` throws, the original [error] is lost and the error
  ///   thrown by [onFinish] becomes the action error. You can handle it in
  ///   [wrapError].
  ///
  /// - Same on success: If `onFinish(null)` throws, the whole action fails
  ///   even though the server request succeeded.  You can handle it in
  ///   [wrapError].
  ///
  Future<St?> onFinish(Object? error) async => null;

  @override
  Future<St?> reduce() async {
    _cannot_combine_mixins_OptimisticSync();
    _cannot_combine_mixins_UnlimitedRetryCheckInternet_OptimisticCommand_OptimisticSync_OptimisticSyncWithPush_ServerPush();

    // Reset per-dispatch tracking fields.
    lastSentValue = null;

    // Compute and cache the key for this dispatch.
    var _currentKey = computeOptimisticSyncKey();

    final value = valueToApply();

    // Store the optimistic value for this dispatch (available in onFinish).
    optimisticValue = value;

    // Always apply optimistic update immediately.
    dispatchState(applyOptimisticValueToState(state, value));

    // If locked, another request is in flight. The optimistic update is
    // already applied, so just return. When the in-flight request completes,
    // it will check if a follow-up is needed.
    if (_optimisticSyncKeySet.contains(_currentKey)) return null;

    // Acquire lock and send request.
    _optimisticSyncKeySet.add(_currentKey);
    await _sendAndFollowUp(_currentKey, value);

    return null;
  }

  /// Set that tracks which keys are currently locked (requests in flight).
  Set<Object?> get _optimisticSyncKeySet =>
      store.internalMixinProps.optimisticSyncKeySet;

  /// Sends the request and handles follow-up requests if the state changed
  /// (by comparing the value returned by [getValueFromState] with [sentValue])
  /// while the request was in flight.
  ///
  Future<void> _sendAndFollowUp(Object? key, T sentValue) async {
    T _sentValue = sentValue;

    int requestCount = 0;

    while (true) {
      requestCount++;

      try {
        // Track the value being sent (for debugging/rollback guards).
        lastSentValue = _sentValue;

        // Send the value and get the server response (may be null).
        final Object? serverResponse = await sendValueToServer(_sentValue);

        // Read the current value from the store.
        // WARNING: In push mode this may reflect a server push, not local intent.
        final stateValue = getValueFromState(state);

        bool needFollowUp = false;

        // Original value-based behavior (no push compatibility):
        // If the store value differs from what we sent, send a follow-up with
        // the current store value.
        needFollowUp = ifShouldSendAnotherRequest(
          stateValue: stateValue,
          sentValue: _sentValue,
          requestCount: requestCount,
        );

        if (needFollowUp) _sentValue = stateValue;

        // If we need a follow-up, loop again without applying server response.
        // The state is not stable yet.
        if (needFollowUp) continue;

        // State is stable for this key. Now we may apply the server response,
        // but only if it is not stale relative to newer pushes.
        if (serverResponse != null) {
          final newState = applyServerResponseToState(state, serverResponse);
          if (newState != null) dispatchState(newState);
        }

        // Release lock and finish.
        _optimisticSyncKeySet.remove(key);
        await _callOnFinish(null);
        break;
      } catch (error) {
        // Request failed: release lock, run onFinish(error), then rethrow so the
        // action still fails as before.
        _optimisticSyncKeySet.remove(key);
        await _callOnFinish(error);
        rethrow;
      }
    }
  }

  /// Calls [onFinish], applying the returned state if non-null.
  Future<void> _callOnFinish(Object? error) async {
    final newState = await onFinish(error);
    if (newState != null) dispatchState(newState);
  }

  /// If [ifShouldSendAnotherRequest] returns true, the action will perform one
  /// more request to try and send the value from the state to the server.
  ///
  /// The default behavior of this method is to compare:
  /// - The [stateValue], which is the value currently in the store state.
  /// - The [sentValue], which is the value that was sent to the server.
  ///
  /// If both are different, it means that the state was changed after
  /// we sent the request, so we should send another request with the new value.
  ///
  /// Optionally, override this method if you need custom equality logic.
  /// The default implementation uses the `==` operator.
  ///
  /// The number of follow-up requests is limited at [maxFollowUpRequests] to
  /// avoid infinite loops. If that limit is exceeded, a [StateError] is thrown.
  ///
  bool ifShouldSendAnotherRequest({
    required T stateValue,
    required T sentValue,
    required int requestCount,
  }) {
    // Safety check to avoid infinite loops.
    if ((maxFollowUpRequests != -1) && (requestCount > maxFollowUpRequests)) {
      throw StateError('Too many follow-up requests '
          'in action $runtimeType (> $maxFollowUpRequests).');
    }

    return (stateValue is ImmutableCollection &&
            sentValue is ImmutableCollection)
        ? !stateValue.same(sentValue)
        : stateValue != sentValue;
  }

  /// Maximum number of follow-up requests to send before throwing an error.
  /// This is a safety limit to avoid infinite loops. Override if you need a
  /// different limit. Use `-1` for no limit.
  int get maxFollowUpRequests => 10000;

  /// Only [CheckInternet] and [AbortWhenNoInternet] can be combined
  /// with [OptimisticSync].
  void _cannot_combine_mixins_OptimisticSync() {
    _incompatible<OptimisticSync, NonReentrant>(this);
    _incompatible<OptimisticSync, Fresh>(this);
    _incompatible<OptimisticSync, Throttle>(this);
    _incompatible<OptimisticSync, Debounce>(this);
    _incompatible<OptimisticSync, UnlimitedRetries>(this);
  }

  void
      _cannot_combine_mixins_UnlimitedRetryCheckInternet_OptimisticCommand_OptimisticSync_OptimisticSyncWithPush_ServerPush() {
    _incompatible<OptimisticSync, UnlimitedRetryCheckInternet>(this);
    _incompatible<OptimisticSync, OptimisticCommand>(this);
    _incompatible<OptimisticSync, OptimisticSyncWithPush>(this);
    _incompatible<OptimisticSync, ServerPush>(this);
    _incompatible<OptimisticSync, Retry>(this);
  }
}

/// The [OptimisticSyncWithPush] mixin is designed for actions where:
///
/// 1. Your app receives server-pushed updates (like WebSockets, Server-Sent
///    Events (SSE), Firebase) that may modify the same state this action
///    controls.
///
/// 2. Non-blocking user interactions (like toggling a "like" button) should
///    update the UI immediately and send the updated value to the server,
///    making sure the server and the UI are eventually consistent.
///
/// 3. Multiple devices can modify the same data (optional).
///
/// 4. Resilient to out of order delivery.
///
/// 4. You want "last write wins" semantics across devices. In other words,
///    with multiple devices, that's how we decide what truth is when two
///    devices disagree.
///
/// **IMPORTANT:** If your app does not receive server-pushed updates,
/// use the [OptimisticSync] mixin instead.
///
/// ---
///
/// ## How it works
///
/// Please read the documentation of [OptimisticSync] first, as this mixin builds
/// upon that behavior with additional logic to handle server-pushed updates.
///
/// The [OptimisticSyncWithPush] mixin extends [OptimisticSync] by adding this:
///
/// - Each local dispatch increments a `localRevision` counter
/// - Server-pushed updates do NOT increment localRevision
/// - Follow-up logic compares revisions instead of values
/// - This prevents push updates from incorrectly marking state as "stable"
///
/// **Example:**
///
/// ```dart
/// class ToggleLikeAction extends ReduxAction<AppState>
///     with OptimisticSyncWithPush<AppState, bool> {
///
///   @override
///   Future<Object?> sendValueToServer(Object? value) async {
///     int localRev = localRevision(); // Get current revision
///     var response = await api.setLiked(itemId, value, localRev: localRev);
///     informServerRevision(response.serverRev); // Track server revision
///     return response.liked;
///   }
/// }
/// ```
///
/// Notes:
/// - It can be combined with [CheckInternet] and [AbortWhenNoInternet].
/// - It should not be combined with [NonReentrant], [Throttle], [Debounce],
///   [Fresh], [UnlimitedRetryCheckInternet], [UnlimitedRetries],
///   [OptimisticCommand], [OptimisticSyncWithPush], or [ServerPush].
///
mixin OptimisticSyncWithPush<St, T> on ReduxAction<St> {
  //
  /// Optionally, override [optimisticSyncKeyParams] to differentiate coalescing by
  /// action parameters. For example, if you have a like button per item,
  /// return the item ID so that different items can have concurrent requests:
  ///
  /// ```dart
  /// Object? optimisticSyncKeyParams() => itemId;
  /// ```
  ///
  /// You can also return a record of values:
  ///
  /// ```dart
  /// Object? optimisticSyncKeyParams() => (userId, itemId);
  /// ```
  ///
  /// See also: [computeOptimisticSyncKey], which uses this method by default to
  /// build the key.
  ///
  Object? optimisticSyncKeyParams() => null;

  /// By default the coalescing key combines the action [runtimeType]
  /// with [optimisticSyncKeyParams]. Override this method if you want
  /// different action types to share the same coalescing key.
  Object computeOptimisticSyncKey() => (runtimeType, optimisticSyncKeyParams());

  /// Override [valueToApply] to return the value that should be applied
  /// optimistically to the state and then sent to the server. This is called
  /// synchronously and only once per dispatch, when the reducer starts.
  ///
  /// The value to apply can be anything, and is usually constructed from the
  /// action fields, and/or from the current [state]. Valid examples are:
  ///
  /// ```dart
  /// // Set the like button to "liked".
  /// bool valueToApply() => true
  ///
  /// // Set the like button to "liked" or "not liked", according to
  /// // the field `isLiked` of the action.
  /// bool valueToApply() => isLiked;
  ///
  /// // Toggles the current state of the like button.
  /// bool valueToApply() => !state.items[itemId].isLiked;
  /// ```
  ///
  T valueToApply();

  /// Override [applyOptimisticValueToState] to return a new state where the
  /// given [optimisticValue] is applied to the current [state].
  ///
  /// Note, Async Redux calculated [optimisticValue] by previously
  /// calling [valueToApply].
  ///
  /// ```dart
  /// AppState applyOptimisticValueToState(state, isLiked) =>
  ///     state.copyWith(items: state.items.setLiked(itemId, isLiked));
  /// ```
  St applyOptimisticValueToState(St state, T optimisticValue);

  /// Override [applyServerResponseToState] to return a new state, where the
  /// given [serverResponse] (previously received from the server when running
  /// [sendValueToServer]) is applied to the current [state]. Example:
  ///
  /// ```dart
  /// AppState? applyServerResponseToState(state, serverResponse) =>
  ///     state.copyWith(items: state.items.setLiked(itemId, serverResponse.date.isLiked));
  /// ```
  ///
  /// Note [serverResponse] is never `null` here, because this method is only
  /// called when [sendValueToServer] returned a non-null value.
  ///
  /// If you decide you DO NOT want to apply the server response to the state,
  /// simply return `null`.
  ///
  St? applyServerResponseToState(St state, Object serverResponse);

  /// Override [getValueFromState] to extract the value from the current [state].
  /// This value will be later compared to one returned by [valueToApply] to
  /// determine if a follow-up request is needed.
  ///
  /// Here is the rationale:
  /// When a request completes, if the value in the state is different from
  /// the value that was optimistically applied, it means the user changed it
  /// again while the request was in flight, so a follow-up request is needed
  /// to sync the latest value with the server.
  ///
  /// ```dart
  /// bool getValueFromState(state) => state.items[itemId].liked;
  /// ```
  T getValueFromState(St state);

  /// Override [sendValueToServer] to send the given [optimisticValue] to the
  /// server, and optionally return the server's response.
  ///
  /// Note, Async Redux calculated [optimisticValue] by previously
  /// calling [valueToApply].
  ///
  /// If [sendValueToServer] returns a non-null value, that value will be
  /// applied to the state, but **only when the state stabilizes** (i.e., when
  /// there are no more pending requests and the lock is about to be released).
  /// This prevents the server response from overwriting subsequent user
  /// interactions that occurred while the request was in flight.
  ///
  /// The value in the store state may change while the request is in flight.
  /// For example, if the user presses a like button once, but then
  /// presses it again before the first request finishes, the value in the
  /// store state is now different from the optimistic value that was previously
  /// applied. In this case, [sendValueToServer] will be called again to create
  /// a follow-up request to sync the updated state with the server.
  ///
  /// If [sendValueToServer] returns `null`, the current optimistic state is
  /// assumed to be correct and valid.
  ///
  /// ```dart
  /// Future<Object?> saveValue(Object? optimisticValue) async {
  ///   var response = await api.setLiked(itemId, optimisticValue);
  ///   return response?.liked; // Return server-confirmed value, or null.
  /// }
  /// ```
  Future<Object?> sendValueToServer(Object? optimisticValue);

  /// If your app listens to server-pushed updates (e.g., via WebSockets),
  /// call [localRevision] to enable revision-based synchronization that
  /// correctly handles concurrent updates from multiple devices.
  ///
  /// **When to use:**
  /// Call [localRevision] from [sendValueToServer] to get the revision number
  /// to send with your request. The server should echo this back in its
  /// response so the client knows which request completed.
  ///
  /// **How it works:**
  /// - Each dispatch that calls [localRevision] increments the revision for
  ///   this key (the first call per dispatch increments; subsequent calls in
  ///   the same dispatch return the same value).
  /// - When a request completes, the framework compares the current
  ///   localRevision with what was sent. If they differ, a follow-up request
  ///   is sent automatically.
  /// - Server-pushed updates should NOT call [localRevision] (they are not
  ///   local intent). Instead, use [informServerRevision] to track server state.
  ///
  /// **Important:** Call [localRevision] BEFORE any `await` in your
  /// [sendValueToServer] implementation to ensure the captured value is
  /// consistent.
  ///
  /// **Example:**
  /// ```dart
  /// Future<Object?> sendValueToServer(Object? optimisticValue) async {
  ///   int localRev = localRevision(); // Capture BEFORE await
  ///   var response = await api.setLiked(itemId, optimisticValue, localRev: localRev);
  ///   informServerRevision(response.serverRev);
  ///   return response.liked; // The mixin decides whether to apply this
  /// }
  /// ```
  ///
  /// **Note:** If your app does not listen to server-pushed updates, you can
  /// ignore this method. The default value-comparison logic will still work.
  ///
  int localRevision() {
    final key = _currentKey!;

    if (!_localRevisionCalled) {
      _localRevisionCalled = true;

      // Increment for this dispatch.
      final entry = _revisionMap[key];
      final int newLocalRev = (entry?.localRevision ?? 0) + 1;

      // Snapshot the current known server revision at the moment this local intent is created.
      final int? fromMap = entry?.serverRevision;
      final int? fromState = getServerRevisionFromState(key);
      final int baseServerRev = _bestKnownServerRevision(key);

      // Keep null only if we truly know nothing.
      final int? storedServerRev =
          (fromMap == null && fromState == null) ? null : baseServerRev;

      _revisionMap[key] = (
        localRevision: newLocalRev,
        serverRevision: storedServerRev,
        intentBaseServerRevision: baseServerRev,
        localValue: entry?.localValue, // preserve latest local intent value
      );
    }

    // Always return the current value (might have been updated by other dispatches)
    return _revisionMap[key]!.localRevision;
  }

  /// Tracks whether [localRevision] has been called in this dispatch.
  /// Reset at the start of [reduce].
  bool _localRevisionCalled = false;

  /// Tracks the server revision informed by the user during [sendValueToServer].
  /// Used by _sendAndFollowUp to determine if the response should be applied.
  /// Reset before each call to [sendValueToServer].
  int? _informedServerRev;

  /// Cached coalescing key for the current dispatch.
  /// Computed once in [reduce] and reused by [localRevision],
  /// [_serverRevision], and [informServerRevision].
  Object? _currentKey;

  /// Note: This mutates `_revisionMap`.
  int _bestKnownServerRevision(Object? key) {
    final entry = _revisionMap[key];
    final int fromMap = entry?.serverRevision ?? 0;
    final int fromState = getServerRevisionFromState(key) ?? 0;

    if (fromState > fromMap) {
      _revisionMap[key] = (
        localRevision: entry?.localRevision ?? 0,
        serverRevision: fromState,
        intentBaseServerRevision: entry?.intentBaseServerRevision ?? fromState,
        localValue: entry?.localValue,
      );
      return fromState;
    }

    return fromMap;
  }

  /// Returns the current known server revision for this key.
  ///
  /// The serverRevision represents the server's view of the latest write
  /// (under "last write wins" semantics).
  ///
  /// Returns 0 if no server revision has been set for this key.
  ///
  /// See also: [informServerRevision].
  ///
  int _serverRevision() {
    final key = _currentKey!;
    return _bestKnownServerRevision(key);
  }

  /// You must override this to return the server revision you saved in the
  /// state in [ServerPush.applyServerPushToState] for the given [key].
  ///
  /// You MUST return `null` when unknown (not `0`).
  int? getServerRevisionFromState(Object? key);

  /// Call this from [sendValueToServer] to inform the mixin about the
  /// server revision returned in the response.
  ///
  /// The mixin uses this information internally to:
  /// - Track the latest known server revision (for "last write wins" ordering)
  /// - Determine whether to apply the server response (stale responses are
  ///   automatically ignored)
  ///
  /// **Usage:** Just call this method with the serverRevision from the response.
  /// The mixin handles all the logic - you don't need to check or compare
  /// anything yourself.
  ///
  /// **Example:**
  /// ```dart
  /// Future<Object?> sendValueToServer(Object? optimisticValue) async {
  ///   int localRev = localRevision();
  ///   var response = await api.setLiked(itemId, optimisticValue, localRev: localRev);
  ///   informServerRevision(response.serverRev);
  ///   return response.liked; // The mixin decides whether to apply this
  /// }
  /// ```
  ///
  /// **Behavior:**
  /// - Only updates the stored serverRevision if [revision] is greater than
  ///   the current value (prevents regression from stale/out-of-order updates)
  /// - The mixin will only apply the returned server response if this revision
  ///   is still the newest (no newer push has arrived in the meantime)
  ///
  /// See also: [informServerRevisionAsDateTime].
  ///
  void informServerRevision(int revision) {
    _informedServerRev = revision;

    final key = _currentKey!;
    final entry = _revisionMap[key];

    final int currentServerRev = _bestKnownServerRevision(key);

    // Only move forward, but keep local intent info.
    if (revision > currentServerRev) {
      _revisionMap[key] = (
        localRevision: entry?.localRevision ?? 0,
        serverRevision: revision,
        intentBaseServerRevision:
            entry?.intentBaseServerRevision ?? currentServerRev,
        localValue: entry?.localValue,
      );
    }
  }

  /// Convenience method to inform the server revision from a DateTime.
  /// Uses `millisecondsSinceEpoch` as the revision number.
  ///
  /// See also: [informServerRevision].
  ///
  void informServerRevisionAsDateTime(DateTime revision) {
    informServerRevision(revision.millisecondsSinceEpoch);
  }

  /// Convenience method to get the server revision as a DateTime.
  /// Interprets the revision number as `millisecondsSinceEpoch`.
  ///
  /// Returns `DateTime.fromMillisecondsSinceEpoch(0)` if no revision is set.
  ///
  DateTime serverRevisionAsDateTime() =>
      DateTime.fromMillisecondsSinceEpoch(_serverRevision(), isUtc: true);

  /// Optionally, override [onFinish] to run any code after the synchronization
  /// process completes. For example, you might want to reload related data from
  /// the server, show a confirmation message, or perform cleanup.
  ///
  /// Note [onFinish] is called in both success and failure scenarios, but only
  /// after the state stabilizes for this key (that is, after the last request
  /// finishes and no follow-up request is needed).
  ///
  /// Important: The synchronization lock is released *before* [onFinish] runs.
  /// This means new dispatches for the same key may start a new request while
  /// [onFinish] is still executing.
  ///
  /// The [error] parameter will be `null` on success, or contain the error
  /// object if the request failed.
  ///
  /// If [onFinish] returns a non-null state, it will be applied automatically.
  /// If it returns `null`, no state change is made.
  ///
  /// ```dart
  /// Future<St?> onFinish(Object? error) async {
  ///   if (error == null) {
  ///     // Success: show confirmation, log analytics, etc.
  ///     return null;
  ///   } else {
  ///     // Failure: reload data from the server.
  ///     var reloadedInfo = await api.loadInfo();
  ///     return state.copy(info: reloadedInfo);
  ///   }
  /// }
  /// ```
  ///
  /// Important:
  ///
  /// - If `onFinish(error)` throws, the original [error] is lost and the error
  ///   thrown by [onFinish] becomes the action error. You can handle it in
  ///   [wrapError].
  ///
  /// - Same on success: If `onFinish(null)` throws, the whole action fails
  ///   even though the server request succeeded.  You can handle it in
  ///   [wrapError].
  ///
  Future<St?> onFinish(Object? error) async => null;

  @override
  Future<St?> reduce() async {
    _cannot_combine_mixins_OptimisticSyncWithPush();
    _cannot_combine_mixins_UnlimitedRetryCheckInternet_OptimisticCommand_OptimisticSync_OptimisticSyncWithPush_ServerPush();

    // Reset the flag so localRevision() can increment for this dispatch.
    _localRevisionCalled = false;

    // Compute and cache the key for this dispatch.
    _currentKey = computeOptimisticSyncKey();

    // We automatically track revisions for every dispatch.
    // This ensures blocked dispatches also increment the revision counter.
    localRevision();

    final value = valueToApply();

    // Record the latest local intended value for this key, so follow-ups don't
    // depend on store state (which may be overwritten by pushes).
    final entry = _revisionMap[_currentKey];
    _revisionMap[_currentKey] = (
      localRevision: entry?.localRevision ?? 0,
      serverRevision: entry?.serverRevision,
      intentBaseServerRevision:
          entry?.intentBaseServerRevision ?? (entry?.serverRevision ?? 0),
      localValue: value,
    );

    // Always apply optimistic update immediately.
    dispatchState(applyOptimisticValueToState(state, value));

    // If locked, another request is in flight. The optimistic update is
    // already applied, so just return. When the in-flight request completes,
    // it will check if a follow-up is needed.
    if (_optimisticSyncKeySet.contains(_currentKey)) return null;

    // Acquire lock and send request.
    _optimisticSyncKeySet.add(_currentKey);
    await _sendAndFollowUp(_currentKey, value);

    return null;
  }

  /// Set that tracks which keys are currently locked (requests in flight).
  Set<Object?> get _optimisticSyncKeySet =>
      store.internalMixinProps.optimisticSyncKeySet;

  /// Map that tracks local and server revisions for the given key.
  /// The values can be retrieved by methods [localRevision] and [serverRevision].
  Map<
      Object?,
      ({
        int localRevision,
        int? serverRevision,
        int intentBaseServerRevision,
        Object? localValue,
      })> get _revisionMap => store.internalMixinProps.revisionMap;

  T? _getLatestLocalValue(Object? key) {
    final v = _revisionMap[key]?.localValue;
    return (v is T) ? v : null;
  }

  /// Sends the request and handles follow-up requests if the state changed
  /// while the request was in flight.
  ///
  /// When revision tracking is enabled (`isPushCompatible == true`), follow-up
  /// logic is primarily based on `localRevision` (local intent order), and the
  /// value to resend comes from the latest *local intent value* saved in
  /// `_revisionMap` (so it can't be corrupted by server pushes that overwrite
  /// the store while a request is in flight).
  ///
  /// When revision tracking is disabled, the original behavior is preserved:
  /// follow-up logic compares `stateValue` vs the sent value.
  Future<void> _sendAndFollowUp(Object? key, T sentValue) async {
    T _sentValue = sentValue;

    int requestCount = 0;

    while (true) {
      requestCount++;

      // Capture the local revision representing the intent we are about to send.
      // This is captured before `sendValueToServer` so it represents "what this
      // request corresponds to", even if new local dispatches happen while the
      // request is in flight.
      final int? sentLocalRev = _getLocalRevision(key);

      // Reset before each request so we can detect whether the user called
      // `informServerRevision()` while executing `sendValueToServer`.
      _informedServerRev = null;

      try {
        // Send the value and get the server response (may be null).
        final Object? serverResponse = await sendValueToServer(_sentValue);

        // Validate that the developer called informServerRevision().
        if (_informedServerRev == null) {
          throw StateError(
            'The OptimisticSyncWithPush mixin requires calling '
            'informServerRevision() inside sendValueToServer(). '
            'If you don\'t need server-push handling, use OptimisticSync instead.',
          );
        }

        // Read the current value from the store.
        // WARNING: In push mode this may reflect a server push, not local intent.
        final stateValue = getValueFromState(state);

        bool needFollowUp = false;

        // Revision-based follow-up decision:
        // If localRevision advanced since this request started, the user changed
        // intent while the request was in flight, so we may need a follow-up.
        final int currentLocalRev = _getLocalRevision(key);

        if (currentLocalRev > sentLocalRev!) {
          final entry = _revisionMap[key];
          final int currentServerRev = _bestKnownServerRevision(key);
          final int intentBaseServerRev = entry?.intentBaseServerRevision ?? 0;

          // Remote-wins guard:
          // If a newer server revision arrived than the revision returned by THIS response,
          // and that newer server revision is also newer than the server revision that was
          // current when the latest local intent was created, then the latest local intent
          // is considered superseded under last-write-wins. Do not follow up.
          final bool remoteSupersededThisResponse =
              currentServerRev > _informedServerRev!;

          final bool remoteSupersededLatestIntent =
              currentServerRev > intentBaseServerRev;

          if (remoteSupersededThisResponse && remoteSupersededLatestIntent) {
            needFollowUp = false;
          } else {
            // IMPORTANT: Use the latest *local intent* value for this key, which
            // we saved at dispatch time. Do not rely on store state here, because
            // pushes can overwrite the store while the request is in flight.
            final T latestLocalValue = _getLatestLocalValue(key) ?? stateValue;

            // Optimization (restores old behavior):
            // If the user changed intent during the request but ended up back at
            // the same value we already sent, skip the follow-up request.
            needFollowUp = ifShouldSendAnotherRequest(
              stateValue: latestLocalValue,
              sentValue: _sentValue,
              requestCount: requestCount,
            );

            // If we do need a follow-up, resend the latest local intent value.
            if (needFollowUp) _sentValue = latestLocalValue;
          }
        }

        // If we need a follow-up, loop again without applying server response.
        // The state is not stable yet.
        if (needFollowUp) continue;

        // State is stable for this key. Now we may apply the server response,
        // but only if it is not stale relative to newer pushes.
        if (serverResponse != null) {
          // Only apply if the informed server revision still matches the latest
          // known server revision for this key (i.e., no newer push arrived).
          final bool shouldApply = _informedServerRev == _serverRevision();

          if (shouldApply) {
            final newState = applyServerResponseToState(state, serverResponse);
            if (newState != null) dispatchState(newState);
          }
        }

        // Release lock and finish.
        _optimisticSyncKeySet.remove(key);
        await _callOnFinish(null);
        break;
      } catch (error) {
        // Request failed: release lock, run onFinish(error), then rethrow so the
        // action still fails as before.
        _optimisticSyncKeySet.remove(key);
        await _callOnFinish(error);
        rethrow;
      }
    }
  }

  /// Returns the current localRevision for this key, or 0 if not tracking.
  int _getLocalRevision(Object? key) => _revisionMap[key]?.localRevision ?? 0;

  /// Calls [onFinish], applying the returned state if non-null.
  Future<void> _callOnFinish(Object? error) async {
    final newState = await onFinish(error);
    if (newState != null) dispatchState(newState);
  }

  /// If [ifShouldSendAnotherRequest] returns true, the action will perform one
  /// more request to try and send the value from the state to the server.
  ///
  /// The default behavior of this method is to compare:
  /// - The [stateValue], which is the value currently in the store state.
  /// - The [sentValue], which is the value that was sent to the server.
  ///
  /// If both are different, it means that the state was changed after
  /// we sent the request, so we should send another request with the new value.
  ///
  /// Optionally, override this method if you need custom equality logic.
  /// The default implementation uses the `==` operator.
  ///
  /// The number of follow-up requests is limited at [maxFollowUpRequests] to
  /// avoid infinite loops. If that limit is exceeded, a [StateError] is thrown.
  ///
  bool ifShouldSendAnotherRequest({
    required T stateValue,
    required T sentValue,
    required int requestCount,
  }) {
    // Safety check to avoid infinite loops.
    if ((maxFollowUpRequests != -1) && (requestCount > maxFollowUpRequests)) {
      throw StateError('Too many follow-up requests '
          'in action $runtimeType (> $maxFollowUpRequests).');
    }

    return (stateValue is ImmutableCollection &&
            sentValue is ImmutableCollection)
        ? !stateValue.same(sentValue)
        : stateValue != sentValue;
  }

  /// Maximum number of follow-up requests to send before throwing an error.
  /// This is a safety limit to avoid infinite loops. Override if you need a
  /// different limit. Use `-1` for no limit.
  int get maxFollowUpRequests => 10000;

  /// Only [CheckInternet] and [AbortWhenNoInternet] can be combined
  /// with [OptimisticSyncWithPush].
  void _cannot_combine_mixins_OptimisticSyncWithPush() {
    _incompatible<OptimisticSyncWithPush, NonReentrant>(this);
    _incompatible<OptimisticSyncWithPush, Fresh>(this);
    _incompatible<OptimisticSyncWithPush, Throttle>(this);
    _incompatible<OptimisticSyncWithPush, Debounce>(this);
    _incompatible<OptimisticSyncWithPush, UnlimitedRetries>(this);
  }

  void
      _cannot_combine_mixins_UnlimitedRetryCheckInternet_OptimisticCommand_OptimisticSync_OptimisticSyncWithPush_ServerPush() {
    _incompatible<OptimisticSyncWithPush, UnlimitedRetryCheckInternet>(this);
    _incompatible<OptimisticSyncWithPush, OptimisticCommand>(this);
    _incompatible<OptimisticSyncWithPush, OptimisticSync>(this);
    _incompatible<OptimisticSyncWithPush, ServerPush>(this);
    _incompatible<OptimisticSyncWithPush, Retry>(this);
  }
}

mixin ServerPush<St> on ReduxAction<St> {
  /// Return the Type of the OptimisticSync/OptimisticSyncWithPush action that owns
  /// this value (so both compute the same stable-sync key).
  Type associatedAction();

  /// Same meaning as in OptimisticSync: the params that differentiate keys.
  Object? optimisticSyncKeyParams() => null;

  /// Must match the OptimisticSync action key computation.
  /// Default: (associatedActionType, optimisticSyncKeyParams)
  Object computeOptimisticSyncKey() =>
      (associatedAction(), optimisticSyncKeyParams());

  /// You must override this to provide the revision number that came with
  /// the push. For example:
  ///
  /// ```dart
  /// class PushLikeUpdate extends AppAction with ServerPush {
  ///   final bool liked;
  ///   final int serverRev;
  ///   PushLikeUpdate({required this.liked, required this.serverRev});
  ///
  ///   Type associatedAction() => ToggleLikeStableAction;
  ///
  ///   int serverRevision() => serverRev;
  ///
  ///   AppState? applyServerPushToState(AppState state)
  ///     => state.copy(liked: liked, serverRevision: serverRev);
  /// }
  /// ```dart
  int serverRevision();

  /// You must override this to:
  /// - Apply the pushed data to [state].
  /// - Save the [serverRevision] for the current [key] to the [state].
  ///
  /// Return `null` to ignore the push.
  ///
  /// IMPORTANT: This should be a pure state transform and must NOT call
  /// localRevision() or sendValueToServer().
  ///
  St? applyServerPushToState(St state, Object? key, int serverRevision);

  /// You must override this to return the server revision you saved in the
  /// state in [applyServerPushToState] for the given [key].
  ///
  /// You MUST return `null` when unknown (not `0`).
  int? getServerRevisionFromState(Object? key);

  /// If true (default), applies the push even while the stable-sync key is locked.
  /// If you set this to false, you must handle deferral elsewhere, otherwise the
  /// push will be ignored while locked.
  bool get applyEvenIfLocked => true;

  @override
  St? reduce() {
    _cannot_combine_mixins_ServerPush();
    _cannot_combine_mixins_UnlimitedRetryCheckInternet_OptimisticCommand_OptimisticSync_OptimisticSyncWithPush_ServerPush();

    final key = computeOptimisticSyncKey();
    final incomingServerRev = serverRevision();

    final entry0 = _revisionMap[key];
    final fromMap = entry0?.serverRevision;
    final fromState = getServerRevisionFromState(key);

    final currentServerRev = (fromMap == null && fromState == null)
        ? null
        : ((fromMap ?? 0) > (fromState ?? 0)
            ? (fromMap ?? 0)
            : (fromState ?? 0));

    // Seed the map from persisted state if needed.
    // This is important even when we ignore the push as stale.
    if (fromMap == null && fromState != null) {
      _revisionMap[key] = (
        localRevision: entry0?.localRevision ?? 0,
        serverRevision: fromState,
        intentBaseServerRevision: entry0?.intentBaseServerRevision ?? fromState,
        localValue: entry0?.localValue,
      );
    }

    // Ignore stale/out-of-order pushes.
    if (currentServerRev != null && incomingServerRev <= currentServerRev) {
      return null;
    }

    // Optionally ignore while locked (not deferred by default).
    if (!applyEvenIfLocked && _optimisticSyncKeySet.contains(key)) {
      return null;
    }

    // Apply pushed state.
    final newState = applyServerPushToState(state, key, incomingServerRev);
    if (newState == null) return null;

    // Record newest known server revision for this key (preserve local intent info).
    final entry = _revisionMap[key];
    _revisionMap[key] = (
      localRevision: entry?.localRevision ?? 0,
      serverRevision: incomingServerRev,
      intentBaseServerRevision:
          entry?.intentBaseServerRevision ?? (currentServerRev ?? 0),
      localValue: entry?.localValue,
    );

    return newState;
  }

  Set<Object?> get _optimisticSyncKeySet =>
      store.internalMixinProps.optimisticSyncKeySet;

  Map<
      Object?,
      ({
        int localRevision,
        int? serverRevision,
        int intentBaseServerRevision,
        Object? localValue,
      })> get _revisionMap => store.internalMixinProps.revisionMap;

  void _cannot_combine_mixins_ServerPush() {
    _incompatible<ServerPush, CheckInternet>(this);
    _incompatible<ServerPush, AbortWhenNoInternet>(this);
    _incompatible<ServerPush, NonReentrant>(this);
    _incompatible<ServerPush, Fresh>(this);
    _incompatible<ServerPush, Throttle>(this);
    _incompatible<ServerPush, Debounce>(this);
    _incompatible<ServerPush, UnlimitedRetries>(this);
  }

  void
      _cannot_combine_mixins_UnlimitedRetryCheckInternet_OptimisticCommand_OptimisticSync_OptimisticSyncWithPush_ServerPush() {
    _incompatible<ServerPush, UnlimitedRetryCheckInternet>(this);
    _incompatible<ServerPush, OptimisticCommand>(this);
    _incompatible<ServerPush, OptimisticSync>(this);
    _incompatible<ServerPush, Retry>(this);
  }
}
