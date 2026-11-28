import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final (results, online) in <(List<Connection>, bool)>[
    ([], false),
    ([Connection.none], false),
    ([Connection.none, Connection.none], false),
    ([Connection.wifi], true),
    ([Connection.mobile], true),
    ([Connection.ethernet], true),
    ([Connection.bluetooth], true),
    ([Connection.other], true),
    ([Connection.vpn], true),
    ([Connection.wifi, Connection.none], true),
    ([Connection.none, Connection.bluetooth], true),
  ]) {
    test('default provider interprets $results as $online', () async {
      const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var checks = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'check');
        checks++;
        return results.map((result) => result.name).toList();
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      expect(await StoreOptions().hasConnection(), online);
      expect(checks, 1);
    });
  }

  test('custom policies inspect transports using the AsyncRedux enum', () async {
    const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var transports = ['bluetooth'];
    messenger.setMockMethodCallHandler(channel, (_) async => transports);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final options = StoreOptions(
      hasConnection: () async {
        final results = await Connection.checkConnections();
        return results.contains(Connection.wifi);
      },
    );

    expect(await options.hasConnection(), isFalse);
    transports = ['wifi', 'bluetooth'];
    expect(await options.hasConnection(), isTrue);
  });

  test('default options are separate, with a stable shared device identity', () {
    final first = Store<int>(initialState: 0);
    final second = Store<int>(initialState: 0);
    addTearDown(first.teardown);
    addTearDown(second.teardown);

    expect(first.options, isNot(same(second.options)));
    final deviceId = first.options.deviceId();
    expect(first.options.deviceId(), deviceId);
    expect(second.options.deviceId(), deviceId);
    final secondCheck = second.options.hasConnection;
    first.options.hasConnection = () async => false;
    expect(second.options.hasConnection, same(secondCheck));
  });

  test('explicit options are available during construction and in MockStore', () {
    final options = StoreOptions(defaultTimeoutMillis: 123, deviceId: () => 42);
    final store = Store<int>(
      initialState: 0,
      options: options,
      configuration: (store) {
        expect(store.options, same(options));
        return null;
      },
      dependencies: (store) {
        expect(store.options, same(options));
        return null;
      },
    );
    final mock = MockStore<int>(initialState: 0, options: options);
    addTearDown(store.teardown);
    addTearDown(mock.teardown);
    expect(mock.options, same(options));
  });

  final factories = <String, ReduxAction<int> Function()>{
    'CheckInternet': _Check.new,
    'AbortWhenNoInternet': _Abort.new,
    'UnlimitedRetryCheckInternet': _Retry.new,
  };

  for (final entry in factories.entries) {
    for (final online in [false, true]) {
      test('${entry.key} obeys the configured decision: $online', () async {
        final store = Store<int>(
          initialState: 0,
          options: StoreOptions(hasConnection: () async => online),
        );
        addTearDown(store.teardown);
        final status = await store.dispatchAndWait(entry.value());
        expect(store.state, online ? 1 : 0);
        if (online) {
          expect(status.isCompletedOk, isTrue);
        } else if (entry.key == 'AbortWhenNoInternet') {
          expect(status.isDispatchAborted, isTrue);
        } else {
          expect(status.originalError, isA<UserException>());
        }
      });
    }

    test('${entry.key} awaits the configured connectivity callback', () async {
      final connectivity = Completer<bool>();
      var calls = 0;
      final store = Store<int>(
        initialState: 0,
        options: StoreOptions(
          hasConnection: () {
            calls++;
            return connectivity.future;
          },
        ),
      );
      addTearDown(store.teardown);
      final pending = store.dispatchAndWait(entry.value());
      await Future<void>.delayed(Duration.zero);
      expect(store.state, 0);
      expect(calls, 1);
      connectivity.complete(true);
      expect((await pending).isCompletedOk, isTrue);
      expect(store.state, 1);
    });

    test('${entry.key} rereads a replaced connectivity callback', () async {
      final store = Store<int>(
        initialState: 0,
        options: StoreOptions(hasConnection: () async => false),
      );
      addTearDown(store.teardown);
      final action = entry.value();
      // ignore: invalid_use_of_protected_member
      action.setStore(store);
      expect(await _hasConnection(action), isFalse);

      store.options.hasConnection = () async => true;
      expect(await _hasConnection(action), isTrue);
    });

    test('${entry.key} can read a captured connectivity variable', () async {
      var online = false;
      final store = Store<int>(
        initialState: 0,
        options: StoreOptions(hasConnection: () async => online),
      );
      addTearDown(store.teardown);
      await store.dispatchAndWait(entry.value());
      expect(store.state, 0);
      online = true;
      expect((await store.dispatchAndWait(entry.value())).isCompletedOk, isTrue);
      expect(store.state, 1);
    });
  }

  test('action check overrides the store callback', () async {
    final store = Store<int>(
      initialState: 0,
      options: StoreOptions(hasConnection: () async => false),
    );
    addTearDown(store.teardown);
    expect((await store.dispatchAndWait(_CustomCheck())).isCompletedOk, isTrue);
  });

  test('a test can replace and restore the real connectivity callback', () async {
    const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var checks = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'check');
      checks++;
      return ['wifi'];
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final options = StoreOptions();
    final realCheck = options.hasConnection;
    options.hasConnection = () async => false;
    expect(await options.hasConnection(), isFalse);
    options.hasConnection = () async => true;
    expect(await options.hasConnection(), isTrue);
    expect(checks, 0);
    options.hasConnection = realCheck;
    expect(await options.hasConnection(), isTrue);
    expect(checks, 1);
  });

  test('connectivity callbacks are isolated between stores', () async {
    final online = Store<int>(
      initialState: 0,
      options: StoreOptions(hasConnection: () async => true),
    );
    final offline = Store<int>(
      initialState: 0,
      options: StoreOptions(hasConnection: () async => false),
    );
    addTearDown(online.teardown);
    addTearDown(offline.teardown);
    expect((await online.dispatchAndWait(_Check())).isCompletedOk, isTrue);
    expect((await offline.dispatchAndWait(_Check())).originalError, isA<UserException>());
    expect((await offline.dispatchAndWait(_Abort())).isDispatchAborted, isTrue);
  });

  test('action overrides take precedence over store options', () async {
    final store = Store<int>(
      initialState: 0,
      options: StoreOptions(hasConnection: () => throw StateError('Must not be called')),
    );
    addTearDown(store.teardown);
    expect((await store.dispatchAndWait(_CustomCheck())).isCompletedOk, isTrue);
  });

  test('a configured connectivity error reaches the action error pipeline', () async {
    final error = StateError('Connection failed');
    final store = Store<int>(
      initialState: 0,
      options: StoreOptions(hasConnection: () async => throw error),
    );
    addTearDown(store.teardown);
    final action = _Check();
    await expectLater(store.dispatchAndWait(action), throwsA(same(error)));
    expect(action.status.originalError, same(error));
    expect(store.state, 0);
  });

  test('sync requests use each store device identity', () async {
    for (final deviceId in [42, 73]) {
      final store = Store<int>(
        initialState: 0,
        options: StoreOptions(deviceId: () => deviceId),
      );
      addTearDown(store.teardown);
      final action = _Sync();
      expect((await store.dispatchAndWait(action)).isCompletedOk, isTrue);
      expect(action.sentDeviceId, deviceId);
    }
  });
}

Future<bool> _hasConnection(ReduxAction<int> action) => switch (action) {
  CheckInternet<int> action => action.hasConnection(),
  AbortWhenNoInternet<int> action => action.hasConnection(),
  UnlimitedRetryCheckInternet<int> action => action.hasConnection(),
  _ => throw StateError('Expected an internet mixin'),
};

abstract class _Increment extends ReduxAction<int> {
  @override
  int reduce() => state + 1;
}

class _Check extends _Increment with CheckInternet<int> {}

class _Abort extends _Increment with AbortWhenNoInternet<int> {}

class _Retry extends _Increment with UnlimitedRetryCheckInternet<int> {
  @override
  int get maxRetries => 0;

  @override
  void printRetries(String message) {}
}

class _CustomCheck extends _Check {
  @override
  Future<bool> hasConnection() async => true;
}

class _Sync extends ReduxAction<int> with OptimisticSyncWithPush<int, int> {
  int? sentDeviceId;

  @override
  int valueToApply() => state + 1;

  @override
  int getValueFromState(int state) => state;

  @override
  int applyOptimisticValueToState(int state, int optimisticValue) => optimisticValue;

  @override
  int? applyServerResponseToState(int state, Object serverResponse) => null;

  @override
  int getServerRevisionFromState(Object? key) => -1;

  @override
  Future<Object?> sendValueToServer(
    Object? optimisticValue,
    int localRevision,
    int deviceId,
  ) async {
    sentDeviceId = deviceId;
    informServerRevision(1);
    return null;
  }
}
