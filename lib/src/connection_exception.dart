import 'package:async_redux/async_redux.dart';

/// A [UserException] that warns the user when a connection is unavailable.
/// Use [noConnection] for the standard message, or [noConnectionWithRetry] to
/// supply retry work that runs after the standard error dialog closes.
/// Pass a [host] to the constructor to identify the server that could not be reached.
///
/// See also:
/// - The [Connection] enum
/// - [Connection.checkConnections]
///
class ConnectionException extends AdvancedUserException {
  //
  // Usage: `throw ConnectionException.noConnection`;
  static const noConnection = ConnectionException();

  /// Usage: `throw ConnectionException.noConnectionWithRetry(() {...})`;
  ///
  /// A dialog will open. When the user presses OK or dismisses the dialog in any way,
  /// the [onRetry] callback will be called.
  ///
  static ConnectionException noConnectionWithRetry(
          void Function()? onRetry) =>
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
          (host == null || host == 'null')
              ? 'There is no Internet'
              : 'It was not possible to connect to $host.',
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
