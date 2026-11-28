import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final online in [false, true]) {
    for (final notify in [false, true]) {
      test('connectivity=$online, notify=$notify', () async {
        final store = _store();
        final action = _Probe()..online = online;
        final offline = !online;
        final status = await store.dispatchAndWait(action, notify: notify);
        expect(status.isCompletedOk, !offline);
        expect(status.isDispatchAborted, offline);
        expect(status.hasFinishedMethodBefore, !offline);
        expect(status.hasFinishedMethodReduce, !offline);
        expect(status.hasFinishedMethodAfter, isTrue);
        expect(action.events, [
          'before',
          'check',
          if (offline) 'wrap' else 'reduce',
          'after',
        ]);
        expect(store.state, offline ? 0 : 1);
        expect(store.errors, isEmpty);
        expect(store.isFailed(_Probe), isFalse);
        expect(store.actionsInProgress(), isEmpty);
        if (offline) expect(status.originalError, isA<AbortDispatchException>());
      });
    }
  }

  test('waits for before and connectivity before running reduce', () async {
    final store = _store();
    final before = Completer<void>();
    final check = Completer<void>();
    final action = _Probe()
      ..beforeGate = before.future
      ..checkGate = check.future;
    final pending = store.dispatchAndWait(action);
    expect(action.events, ['before']);
    before.complete();
    await Future<void>.delayed(Duration.zero);
    expect(action.events, ['before', 'check']);
    expect(store.isWaiting(_Probe), isTrue);
    check.complete();
    expect((await pending).isCompletedOk, isTrue);
    expect(store.isWaiting(_Probe), isFalse);
  });

  for (final stage in ['before', 'check', 'reduce']) {
    for (final swallow in [false, true]) {
      test('failure in $stage, swallow=$swallow', () async {
        final store = _store();
        final error = StateError(stage);
        final action = _Probe()
          ..errorStage = stage
          ..error = error
          ..swallow = swallow;
        Object? thrown;
        try {
          await store.dispatchAndWait(action);
        } catch (caught) {
          thrown = caught;
        }
        expect(thrown, swallow ? isNull : same(error));
        expect(action.status.originalError, same(error));
        expect(action.status.isDispatchAborted, isFalse);
        expect(action.events.where((event) => event == 'after'), hasLength(1));
        expect(action.events.contains('check'), stage != 'before');
        expect(store.actionsInProgress(), isEmpty);
      });
    }
  }

  for (final swallow in [false, true]) {
    test('wrapError can replace or swallow the offline abort: $swallow', () async {
      final store = _store();
      const replacement = UserException('replacement');
      final action = _Probe()
        ..online = false
        ..swallow = swallow
        ..replacement = replacement;
      final status = await store.dispatchAndWait(action);
      expect(status.originalError, isA<AbortDispatchException>());
      expect(status.wrappedError, swallow ? isNull : same(replacement));
      expect(status.isDispatchAborted, isFalse);
      expect(store.errors, swallow ? isEmpty : [replacement]);
      expect(store.isFailed(_Probe), !swallow);
    });
  }

  for (final internet in [false, true]) {
    test('store simulation with sync reducer: $internet', () async {
      final store = _store()..options.hasConnection = () async => internet;
      final action = _Simulated();
      expect(action.isSync(), isFalse);
      // Intentionally verify the runtime rejection of synchronous dispatch.
      // ignore: async_redux_lints/dispatch_sync_async_action
      expect(() => store.dispatchSync(action), throwsA(isA<StoreException>()));
      expect((await store.dispatchAndWait(action)).isDispatchAborted, !internet);
      expect(store.state, internet ? 1 : 0);
    });
  }

  test('action simulation takes precedence over the store', () async {
    final store = _store()..options.hasConnection = () async => false;
    expect((await store.dispatchAndWait(_Online())).isCompletedOk, isTrue);
  });

  test('admission abort skips both checking and finalization', () async {
    final store = _store();
    final action = _Probe()..abort = true;
    expect((await store.dispatchAndWait(action)).isDispatchAborted, isTrue);
    expect(action.events, isEmpty);
    expect(store.dispatchCount, 0);
  });

  for (final online in [false, true]) {
    test('custom before without super still checks connectivity: $online', () async {
      final store = _store()..options.hasConnection = () async => online;
      final action = _CustomBefore();
      expect((await store.dispatchAndWait(action)).isCompletedOk, online);
      expect(action.beforeCalls, 1);
    });
  }
}

Store<int> _store() {
  final store = Store<int>(initialState: 0);
  addTearDown(store.teardown);
  return store;
}

abstract class _Hooks extends ReduxAction<int> {
  final events = <String>[];
  Future<void>? beforeGate;
  Future<void>? checkGate;
  String? errorStage;
  Object? error;
  Object? replacement;
  bool swallow = false;
  bool abort = false;

  void failAt(String stage) {
    if (errorStage == stage) throw error!;
  }

  @override
  bool abortDispatch() => abort;

  @override
  Future<void> before() async {
    events.add('before');
    await (beforeGate ?? microtask);
    failAt('before');
  }

  @override
  int reduce() {
    events.add('reduce');
    failAt('reduce');
    return state + 1;
  }

  @override
  Object? wrapError(Object error, StackTrace stackTrace) {
    events.add('wrap');
    return swallow ? null : replacement ?? error;
  }

  @override
  void after() => events.add('after');
}

class _Probe extends _Hooks with AbortWhenNoInternet {
  bool online = true;

  @override
  Future<bool> hasConnection() async {
    events.add('check');
    await (checkGate ?? microtask);
    failAt('check');
    return online;
  }
}

class _Simulated extends ReduxAction<int> with AbortWhenNoInternet {
  @override
  int reduce() => state + 1;
}

class _Online extends _Simulated {
  @override
  Future<bool> hasConnection() async => true;
}

class _CustomBefore extends _Simulated {
  int beforeCalls = 0;

  @override
  void before() => beforeCalls++;
}
