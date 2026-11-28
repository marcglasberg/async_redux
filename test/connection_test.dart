import 'package:async_redux/async_redux.dart';
import 'package:connectivity_plus/connectivity_plus.dart' as connectivity_plus;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<String> platformResults;
  late int checks;
  PlatformException? platformFailure;

  setUp(() {
    platformResults = [];
    checks = 0;
    platformFailure = null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'check');
      checks++;
      if (platformFailure != null) throw platformFailure!;
      return platformResults;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  const translations = <String, Connection>{
    'none': Connection.none,
    'wifi': Connection.wifi,
    'mobile': Connection.mobile,
    'ethernet': Connection.ethernet,
    'bluetooth': Connection.bluetooth,
    'vpn': Connection.vpn,
    'satellite': Connection.satellite,
    'other': Connection.other,
  };

  // Enumerate the installed plugin's values so the tests also work with supported
  // older plugin versions, and check the fallback when future values are added.
  for (final transport in connectivity_plus.ConnectivityResult.values) {
    test('translates the plugin connection type ${transport.name}', () async {
      platformResults = [transport.name];
      expect(await Connection.checkConnections(), [
        translations[transport.name] ?? Connection.other,
      ]);
      expect(checks, 1);
    });
  }

  test('preserves an empty transport list', () async {
    expect(await Connection.checkConnections(), isEmpty);
    expect(checks, 1);
  });

  test('preserves transport order, duplicates, and mixed none results', () async {
    platformResults = ['none', 'wifi', 'bluetooth', 'wifi'];
    expect(await Connection.checkConnections(), [
      Connection.none,
      Connection.wifi,
      Connection.bluetooth,
      Connection.wifi,
    ]);
  });

  test('propagates platform errors', () async {
    platformFailure = PlatformException(code: 'network_failure', message: 'Unavailable');
    await expectLater(
      Connection.checkConnections(),
      throwsA(
        isA<PlatformException>()
            .having((error) => error.code, 'code', 'network_failure')
            .having((error) => error.message, 'message', 'Unavailable'),
      ),
    );
    expect(checks, 1);
  });
}
