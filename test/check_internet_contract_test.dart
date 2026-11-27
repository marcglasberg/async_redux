import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final results in <List<ConnectivityResult>>[
    [],
    [ConnectivityResult.wifi],
    [ConnectivityResult.mobile, ConnectivityResult.ethernet],
    [ConnectivityResult.none],
    [ConnectivityResult.wifi, ConnectivityResult.none],
  ]) {
    for (final dialog in [false, true]) {
      test('connectivity=$results, dialog=$dialog', () async {
        final store = _store();
        final action = _Probe()
          ..results = results
          ..dialog = dialog;
        final offline = results.contains(ConnectivityResult.none);
        final status = await store.dispatchAndWait(action);
        expect(status.isCompletedOk, !offline);
        expect(status.isDispatchAborted, isFalse);
        expect(status.hasFinishedMethodBefore, !offline);
        expect(status.hasFinishedMethodReduce, !offline);
        expect(status.hasFinishedMethodAfter, isTrue);
        expect(action.events, [
          'before',
          'check',
          if (offline) 'exception',
          if (offline) 'wrap' else 'reduce',
          'after',
        ]);
        expect(action.receivedResults, offline ? same(results) : isNull);
        expect(store.state, offline ? 0 : 1);
        expect(store.errors.length, offline && dialog ? 1 : 0);
        if (offline) {
          final error = status.wrappedError as UserException;
          expect(error.errorText, 'custom connection error');
          expect(error.ifOpenDialog, dialog);
          expect(store.exceptionFor(_Probe), same(error));
        }
      });
    }
  }

  test(
    'waits for before and connectivity, publishing waiting until completion',
    () async {
      final store = _store();
      final before = Completer<void>();
      final check = Completer<void>();
      final action = _Probe()
        ..beforeGate = before.future
        ..checkGate = check.future;
      final pending = store.dispatchAndWait(action);
      expect(store.isWaiting(_Probe), isTrue);
      expect(action.events, ['before']);
      before.complete();
      await Future<void>.delayed(Duration.zero);
      expect(action.events, ['before', 'check']);
      expect(store.state, 0);
      check.complete();
      expect((await pending).isCompletedOk, isTrue);
      expect(store.isWaiting(_Probe), isFalse);
    },
  );

  for (final stage in ['before', 'check', 'exception', 'reduce']) {
    for (final swallow in [false, true]) {
      test('error in $stage, swallow=$swallow', () async {
        final store = _store();
        final error = StateError(stage);
        final action = _Probe()
          ..errorStage = stage
          ..error = error
          ..swallow = swallow;
        if (stage == 'exception') action.results = [ConnectivityResult.none];
        Object? thrown;
        try {
          await store.dispatchAndWait(action);
        } catch (caught) {
          thrown = caught;
        }
        expect(thrown, swallow ? isNull : same(error));
        expect(action.status.originalError, same(error));
        expect(action.status.wrappedError, swallow ? isNull : same(error));
        expect(action.events.where((event) => event == 'after'), hasLength(1));
        expect(action.events.where((event) => event == 'wrap'), hasLength(1));
        expect(action.events.contains('reduce'), stage == 'reduce');
        expect(action.events.contains('check'), stage != 'before');
        expect(store.actionsInProgress(), isEmpty);
      });
    }
  }

  for (final internet in [false, true]) {
    test('store simulation supplies connectivity: $internet', () async {
      final store = _store()..forceInternetOnOffSimulation = () => internet;
      final action = _Simulated();
      expect(action.isSync(), isFalse); // Its reducer is synchronous.
      // Intentionally verify the runtime rejection of synchronous dispatch.
      // ignore: async_redux_lints/dispatch_sync_async_action
      expect(() => store.dispatchSync(action), throwsA(isA<StoreException>()));
      final status = await store.dispatchAndWait(action);
      expect(status.isCompletedOk, internet);
      expect(store.state, internet ? 1 : 0);
    });
  }

  test('action simulation overrides the store simulation', () async {
    final store = _store()..forceInternetOnOffSimulation = () => false;
    expect((await store.dispatchAndWait(_LocallyOnline())).isCompletedOk, isTrue);
  });

  test('an admission abort does not check connectivity or run after', () async {
    final store = _store();
    final action = _Probe()..abort = true;
    final status = await store.dispatchAndWait(action);
    expect(status.isDispatchAborted, isTrue);
    expect(action.events, isEmpty);
    expect(store.dispatchCount, 0);
  });

  for (final online in [false, true]) {
    test('custom before without super still checks connectivity: $online', () async {
      final store = _store()..forceInternetOnOffSimulation = () => online;
      final action = _CustomBefore();
      expect((await store.dispatchAndWait(action)).isCompletedOk, online);
      expect(action.beforeCalls, 1);
      expect(store.state, online ? 1 : 0);
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
    return swallow ? null : error;
  }

  @override
  void after() => events.add('after');
}

class _Probe extends _Hooks with CheckInternet {
  List<ConnectivityResult> results = [ConnectivityResult.wifi];
  List<ConnectivityResult>? receivedResults;
  bool dialog = true;

  @override
  bool get ifOpenDialog => dialog;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    events.add('check');
    await (checkGate ?? microtask);
    failAt('check');
    return results;
  }

  @override
  UserException connectionException(List<ConnectivityResult> result) {
    events.add('exception');
    failAt('exception');
    receivedResults = result;
    return const UserException('Connection', errorText: 'custom connection error');
  }
}

class _Simulated extends ReduxAction<int> with CheckInternet {
  @override
  int reduce() => state + 1;
}

class _LocallyOnline extends _Simulated {
  @override
  bool? get internetOnOffSimulation => true;
}

class _CustomBefore extends _Simulated {
  int beforeCalls = 0;

  @override
  void before() => beforeCalls++;
}
