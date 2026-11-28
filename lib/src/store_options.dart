import 'dart:math';

import 'package:async_redux_core/async_redux_core.dart' show UserException;

import 'connection.dart';
import 'connection_exception.dart';

/// Configures library behavior for all actions dispatched through a store.
///
/// Each store creates its own options by default. Pass the same options object to
/// multiple stores only when they should share changes to the connectivity callback.
/// These options are separate from the application's `Store.configuration`.
class StoreOptions {
  StoreOptions({
    //
    // The default timeout is 10 minutes.
    this.defaultTimeoutMillis = 60 * 1000 * 10,
    //
    this.hasConnection = _hasConnection,
    //
    this.connectionException = _connectionException,
    //
    // The default is a random id.
    this.deviceId = _defaultDeviceId,
  });

  /// Default timeout for store waits, in milliseconds. A negative value disables it.
  /// An explicit timeout supplied to a wait takes precedence over this default.
  final int defaultTimeoutMillis;

  /// Decides whether the internet mixins may proceed, unless the action overrides
  /// its check. Replace this callback to customize the policy or simulate a
  /// connection during tests. It takes no arguments and returns the final decision.
  ///
  /// The default returns true when [Connection.checkConnections] reports a transport
  /// different from none. Empty lists and lists containing only none return false.
  /// This reports network connectivity, not whether a server is reachable.
  ///
  /// For example, configure a wifi-only policy using AsyncRedux's [Connection] enum:
  ///
  /// ```dart
  /// import 'package:async_redux/async_redux.dart';
  ///
  /// StoreOptions(
  ///   hasConnection: () async {
  ///     final results = await Connection.checkConnections();
  ///     return results.contains(Connection.wifi);
  ///   },
  /// );
  /// ```
  ///
  /// In tests, switch connectivity without recreating the store:
  ///
  /// ```dart
  /// final realCheck = store.options.hasConnection;
  /// store.options.hasConnection = () async => false;
  /// store.options.hasConnection = () async => true;
  /// store.options.hasConnection = realCheck; // Restore the original policy.
  /// ```
  Future<bool> Function() hasConnection;

  /// Creates the error for CheckInternet actions when connectivity is unavailable.
  /// Defaults to [ConnectionException.noConnection]. The factory runs only when
  /// a CheckInternet action's connectivity check returns false. An action can
  /// override its connectionException method to customize its own error instead.
  /// AbortWhenNoInternet and UnlimitedRetryCheckInternet do not use this factory.
  ///
  /// For example, customize the message for all CheckInternet actions:
  ///
  /// ```dart
  /// StoreOptions(
  ///   connectionException: () => const UserException(
  ///     'Please check your connection.',
  ///     errorText: 'Connection unavailable',
  ///   ),
  /// );
  /// ```
  ///
  /// To run application-defined retry work after the dialog closes, use
  /// [ConnectionException.noConnectionWithRetry]:
  ///
  /// ```dart
  /// StoreOptions(
  ///   connectionException: () => ConnectionException.noConnectionWithRetry(
  ///     () => retryPendingRequests(),
  ///   ),
  /// );
  /// ```
  ///
  /// Here retryPendingRequests is an application function that performs the work
  /// to retry. The standard UserExceptionDialog calls it after the user presses OK
  /// or otherwise dismisses the dialog. Creating the exception does not call it.
  /// The helper does not automatically redispatch the failed action or wait for
  /// connectivity; the supplied callback must perform the desired retry work.
  /// Since this factory has no action argument, override an action's
  /// connectionException method when the retry work depends on that action.
  ///
  /// The action's ifOpenDialog getter, including the NoDialog mixin, controls
  /// whether the error is shown. Without a dialog, its retry callback is not
  /// automatically invoked. A custom dialog presenter must invoke the exception's
  /// onOk callback itself if it wants the same retry behavior.
  final UserException Function() connectionException;

  /// Identifies outgoing revisions and self echoes in OptimisticSyncWithPush and
  /// ServerPush. Return a stable value while syncing. By default, a random identity
  /// is generated once per isolate and shared by all stores.
  final int Function() deviceId;

  static UserException _connectionException() => ConnectionException.noConnection;

  /// Default connectivity check.
  ///
  /// Queries [Connection.checkConnections] and interprets the results here. The
  /// internet mixins receive a boolean and do not interpret transports.
  ///
  /// All three internet mixins (CheckInternet, AbortWhenNoInternet, and
  /// UnlimitedRetryCheckInternet) use this default decision. It returns true if ANY
  /// entry differs from [Connection.none]:
  ///
  /// - `[]` and `[none]` mean offline, as do repeated none entries.
  /// - Wifi, mobile, ethernet, vpn, bluetooth, satellite, and other allow the action.
  /// - An available transport wins over none in a mixed result such as `[none, wifi]`.
  /// - New transport types are accepted without needing a whitelist update.
  ///
  /// This default favors attempting a potentially successful request over blocking
  /// a valid connection. Bluetooth can carry internet through tethering. The other
  /// result is not necessarily unusable: connectivity_plus reports VPN connections
  /// as other on iOS and macOS. Rejecting either type by default could prevent an
  /// otherwise working request. An empty list, however, reports no transport at all.
  ///
  /// This is a network-availability check, not proof of internet or server access.
  /// Even wifi may require a captive-portal login, a VPN may only reach a private
  /// network, and the application's server may be unavailable. The actual request
  /// must still handle errors and timeouts. A successful preflight check also cannot
  /// guarantee that connectivity will remain available during the request.
  ///
  /// Choose a different policy if the application needs one. For example, a wifi-only
  /// application can supply [hasConnection] with a callback that queries
  /// [Connection.checkConnections] and returns whether the results contain wifi.
  /// The callback returns the final yes/no decision, without inventing transports.
  /// To customize a single action, override its hasConnection method instead.
  ///
  /// If actual backend reachability matters, a custom callback can check an endpoint
  /// relevant to the application. Such a probe adds latency and traffic, and a probe
  /// to an unrelated public service does not establish that the application's server
  /// is reachable. The default therefore relies on reported transports and lets the
  /// request determine whether it can succeed.
  ///
  /// See [issue #156](https://github.com/marcglasberg/async_redux/issues/156)
  /// for the discussion about Bluetooth and configurable connection policies.
  static Future<bool> _hasConnection() async {
    final results = await Connection.checkConnections();
    return results.any((result) => result != Connection.none);
  }

  static final int _randomDeviceId =
      Random().nextInt(4294967296) + (Random().nextInt(10000) * 10000000000);

  static int _defaultDeviceId() => _randomDeviceId;
}
