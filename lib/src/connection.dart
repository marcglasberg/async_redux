import 'package:async_redux/async_redux.dart';
import 'package:connectivity_plus/connectivity_plus.dart' as connectivity_plus;
import 'package:connectivity_plus/connectivity_plus.dart';

/// Network transport types reported by [checkConnections].
///
/// This can be used to implement a custom [StoreOptions.hasConnection] policy:
///
/// ```dart
/// List<Connection> results = await Connection.checkConnections();
/// bool hasWifi = results.contains(Connection.wifi);
/// ```
///
/// See also:
/// - [ConnectionException]
///
enum Connection {
  /// No network transport is reported.
  none,

  /// A Wi-Fi connection is reported.
  wifi,

  /// A cellular connection is reported.
  mobile,

  /// An Ethernet connection is reported.
  ethernet,

  /// A Bluetooth network connection is reported, which may provide internet
  /// access through tethering.
  bluetooth,

  /// A VPN connection is reported. Some platforms, including iOS and macOS,
  /// report VPN connections as [other] instead.
  vpn,

  /// A satellite connection is reported. This depends on support in the platform
  /// and the underlying connectivity plugin version.
  satellite,

  /// A network transport is unclassified, or the plugin reports a transport
  /// introduced after this enum was defined.
  other;

  /// Queries the device's network transports and returns AsyncRedux enum values.
  /// Clients do not need to import connectivity_plus to use this method.
  ///
  /// The result preserves the plugin's ordering, duplicate entries, and empty
  /// lists. It does not resolve mixed results containing [none] and a transport.
  /// StoreOptions.hasConnection applies the default policy: any entry other
  /// than [none] permits the action; an empty list or only [none] does not.
  ///
  /// Plugin transports without a matching value in this enum become [other].
  /// Errors from the underlying platform check propagate to the caller.
  static Future<List<Connection>> checkConnections() async {
    //
    final List<ConnectivityResult> results = await connectivity_plus.Connectivity()
        .checkConnectivity();

    return [
      for (final result in results)
        switch (result.name) {
          'none' => none,
          'wifi' => wifi,
          'mobile' => mobile,
          'ethernet' => ethernet,
          'bluetooth' => bluetooth,
          'vpn' => vpn,
          'satellite' => satellite,
          _ => other,
        },
    ];
  }
}
