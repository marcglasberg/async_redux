import 'dart:async';
import 'package:async_redux/async_redux.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// This mixin can be used to check if there is internet when you run some action that needs
/// internet connection. Just add `with CheckInternet<AppState>` to your action. For example:
///
/// ```dart
/// class LoadText extends ReduxAction<AppState> with CheckInternet<AppState> {
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
/// If you don't want the dialog to open, you can use the mixin [CheckInternetNoDialog] instead.
///
/// If you want to customize the dialog, you can override the method [connectionException] and
/// return an [UserException] with the desired message.
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
/// * [CheckInternetNoDialog] - If you want to show a message in your widget when there is no internet.
/// * [OnlyWithInternet] - If you want to silently abort the action when there is no internet.
///
mixin CheckInternet<St> implements ReduxAction<St> {
  bool get ifOpenDialog => true;

  UserException connectionException(ConnectivityResult result) =>
      ConnectionException.noConnectivity;

  /// If you are running tests, you can override this method to simulate the internet connection.
  /// Return true if there is internet, and false if there is no internet.
  /// If you return null, it will use the real internet connection status.
  bool? get internetOnOffSimulation => forceInternetOnOffSimulation();

  /// If you have a configuration variable in your app, that you want to use to simulate the
  /// internet connection, you can replace this method to return the value of the configuration
  /// variable. For example: `CheckInternet.forceInternetOnOffSimulation = () => Config.isInternetOn;`
  /// Return true if there is internet, and false if there is no internet.
  /// If you return null, it will use the real internet connection status.
  static bool? Function() forceInternetOnOffSimulation = () => null;

  /// Returns true if there is internet.
  /// Note: This can be used to check if there is internet before making a request to the server.
  /// However, it only checks if the internet is on or off on the device, not if the internet
  /// provider is really providing the service or if the server is available. So, it is possible that
  /// this function returns true and the request still fails.
  Future<ConnectivityResult> checkConnectivity() async {
    if (internetOnOffSimulation != null)
      return internetOnOffSimulation! ? ConnectivityResult.wifi : ConnectivityResult.none;

    return await (Connectivity().checkConnectivity());
  }

  @override
  Future<void> before() async {
    var result = await checkConnectivity();

    if (result == ConnectivityResult.none) {
      var _exception = connectionException(result).withDialog(ifOpenDialog);
      throw ifOpenDialog ? _exception : _exception.noDialog;
    }
  }
}

/// This mixin can be used to check if there is internet when you run some action that needs
/// internet connection. Just add `with CheckInternetNoDialog<AppState>` to your action. Example:
///
/// ```dart
/// class LoadText extends ReduxAction<AppState> with CheckInternetNoDialog<AppState> {
///   Future<String> reduce() async {
///     var response = await http.get('http://numbersapi.com/42');
///     return response.body;
///   }}
/// ```
///
/// I will automatically check if there is internet before running the action. If there is no
/// internet, the action will fail, stop executing, and if you want you can display some
/// information in your widgets:
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
/// If you also want a dialog to open, you can use the mixin [CheckInternet] instead.
///
/// If you want to customize the exception `errorText`, you can override the
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
/// * [CheckInternet] - If you want to show a dialog to the user when there is no internet.
/// * [OnlyWithInternet] - If you want to silently abort the action when there is no internet.
///
mixin CheckInternetNoDialog<St> on CheckInternet<St> {
  @override
  bool get ifOpenDialog => false;
}

/// This mixin can be used to check if there is internet when you run some action that needs
/// internet connection. Just add `with OnlyWithInternet<AppState>` to your action. For example:
///
/// ```dart
/// class LoadText extends ReduxAction<AppState> with OnlyWithInternet<AppState> {
///   Future<String> reduce() async {
///     var response = await http.get('http://numbersapi.com/42');
///     return response.body;
///   }}
/// ```
///
/// I will automatically check if there is internet before running the action. If there is no
/// internet, the action will abort silently, as if it had never been dispatched.
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
/// * [CheckInternetNoDialog] - If you want to show a message in your widget when there is no internet.
///
mixin OnlyWithInternet<St> implements ReduxAction<St> {
  bool get ifOpenDialog => true;

  /// If you are running tests, you can override this method to simulate the internet connection.
  /// Return true if there is internet, and false if there is no internet.
  /// If you return null, it will use the real internet connection status.
  bool? get internetOnOffSimulation => CheckInternet.forceInternetOnOffSimulation();

  UserException connectionException(ConnectivityResult result) =>
      ConnectionException.noConnectivity;

  @override
  Future<void> before() async {
    var result = await (Connectivity().checkConnectivity());
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
/// - This mixin can safely be combined with [CheckInternet], [CheckInternetNoDialog], and [OnlyWithInternet].
/// - It should not be combined with other mixins that override [abortDispatch].
mixin NonReentrant<St> implements ReduxAction<St> {
  @override
  bool abortDispatch() => isWaiting(runtimeType);
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

/// The [ConnectionException] is a type of [UserException] that warns the user when the connection
/// is not working. Use [ConnectionException.noConnectivity] for a simple version that warns the
/// users they should check the connection. Use factory [create] to give more complete messages,
/// indicating the host that is having problems.
///
class ConnectionException extends AdvancedUserException {
  //
  // Usage: `throw ConnectionException.noConnectivity`;
  static const noConnectivity = ConnectionException();

  /// Usage: `throw ConnectionException.noConnectivityWithRetry(() {...})`;
  ///
  /// A dialog will open. When the user presses OK or dismisses the dialog in any way,
  /// the [onRetry] callback will be called.
  ///
  static ConnectionException noConnectivityWithRetry(void Function()? onRetry) =>
      ConnectionException(onRetry: onRetry);

  /// Creates a [ConnectionException].
  ///
  /// If you pass it an [onRetry] callback, it will call it when the user presses
  /// the "Ok" button in the dialog. Otherwise, it will just close the dialog.
  ///
  /// If you pass it a [host], it will say "It was not possible to connect to $host".
  /// Otherwise, it will simply say "There is no Internet connection".
  ///
  const ConnectionException({
    void Function()? onRetry,
    this.host,
    String? errorText,
    bool ifOpenDialog = true,
  }) : super(
          (host != null) ? 'There is no Internet' : 'It was not possible to connect to $host.',
          reason: 'Please, verify your connection.',
          code: null,
          onOk: onRetry,
          onCancel: null,
          hardCause: null,
          errorText: errorText ?? 'No Internet connection',
          ifOpenDialog: ifOpenDialog,
        );

  final String? host;

  @override
  UserException addReason(String? reason) {
    throw UnsupportedError('You cannot use this.');
  }

  @override
  UserException mergedWith(UserException? anotherUserException) {
    throw UnsupportedError('You cannot use this.');
  }

  @override
  UserException withErrorText(String? newErrorText) => ConnectionException(
        host: host,
        onRetry: onOk,
        errorText: newErrorText,
        ifOpenDialog: ifOpenDialog,
      );

  @override
  UserException withDialog(bool ifOpenDialog) => ConnectionException(
        host: host,
        onRetry: onOk,
        errorText: errorText,
        ifOpenDialog: ifOpenDialog,
      );

  @override
  UserException get noDialog => ConnectionException(
        host: host,
        onRetry: onOk,
        errorText: errorText,
        ifOpenDialog: ifOpenDialog,
      );
}
