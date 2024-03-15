import 'package:async_redux/async_redux.dart';

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
