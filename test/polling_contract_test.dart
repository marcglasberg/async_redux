import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final create in <_Controller Function()>[_Sync.new, _Async.new]) {
    for (final poll in Poll.values) {
      for (final active in [false, true]) {
        for (final failure in ['success', 'before', 'reduce']) {
          test('${create().runtimeType} $poll active=$active failure=$failure', () {
            fakeAsync((async) {
              final store = Store<int>(initialState: 0);
              if (active) {
                store.dispatch(_Sync());
                async.flushMicrotasks();
              }
              final previous = store.internalMixinProps.pollingMap['shared'];
              final action = create()
                ..poll = poll
                ..failure = failure;
              expect(action.isSync(), isFalse);
              store.dispatch(action);
              async.flushMicrotasks();
              final runs =
                  failure != 'before' &&
                  (poll == Poll.once ||
                      poll == Poll.runNowAndRestart ||
                      (poll == Poll.start && !active));
              final failed = failure == 'before' || (runs && failure == 'reduce');
              expect(action.events.where((e) => e == 'before'), hasLength(1));
              expect(action.events.where((e) => e == 'reduce'), hasLength(runs ? 1 : 0));
              expect(action.events.last, 'after');
              expect(action.keyCalls, failure == 'before' ? 0 : 1);
              expect(action.status.isCompletedOk, !failed);
              expect(action.status.isDispatchAborted, isFalse);
              expect(action.status.originalError, failed ? same(action.error) : isNull);
              final isActive = failure == 'before' || poll == Poll.once
                  ? active
                  : poll != Poll.stop;
              final current = store.internalMixinProps.pollingMap['shared'];
              expect(current != null, isActive);
              if (isActive) {
                expect(current!.timer!.isActive, isTrue);
                final kept =
                    failure == 'before' ||
                    poll == Poll.once ||
                    (poll == Poll.start && active);
                expect(identical(current.id, previous?.id), kept);
              }
              expect(store.state, (active ? 1 : 0) + (runs && !failed ? 1 : 0));
              store.shutdown();
              store.teardown();
              async.flushMicrotasks();
              expect(async.nonPeriodicTimerCount, 0);
            });
          });
        }
      }
    }
  }

  for (final wait in [false, true]) {
    for (final operation in ['stop', 'restart', 'clear']) {
      test('$operation during a pending immediate run, wait=$wait', () {
        fakeAsync((async) {
          final store = Store<int>(initialState: 0);
          final gate = Completer<void>();
          final old = _Async()
            ..wait = wait
            ..gate = gate.future;
          store.dispatch(old);
          async.flushMicrotasks();
          final oldEntry = store.internalMixinProps.pollingMap['shared']!;
          expect(oldEntry.timer == null, wait);
          final replacement = _Sync()
            ..wait = wait
            ..poll = operation == 'restart' ? Poll.runNowAndRestart : Poll.stop;
          if (operation == 'clear') {
            store.internalMixinProps.clear();
          } else {
            store.dispatch(replacement);
          }
          async.flushMicrotasks();
          final newEntry = store.internalMixinProps.pollingMap['shared'];
          gate.complete();
          async.flushMicrotasks();
          expect(old.status.isCompletedOk, isTrue);
          if (operation == 'restart') {
            expect(newEntry!.id, isNot(same(oldEntry.id)));
            expect(store.internalMixinProps.pollingMap['shared']!.id, same(newEntry.id));
          } else {
            expect(store.internalMixinProps.pollingMap, isEmpty);
          }
          async.elapse(const Duration(milliseconds: 30));
          expect(old.created, isEmpty);
          expect(replacement.created, hasLength(operation == 'restart' ? 3 : 0));
          store.shutdown();
          store.teardown();
          async.flushMicrotasks();
          expect(async.nonPeriodicTimerCount, 0);
        });
      });
    }
  }

  for (final wait in [false, true]) {
    test('factory failure retains the existing scheduling behavior, wait=$wait', () {
      fakeAsync((async) {
        final store = Store<int>(initialState: 0);
        final errors = <Object>[];
        final action = _Sync()
          ..wait = wait
          ..factoryThrows = true;
        runZonedGuarded(
          () => store.dispatch(action),
          (error, stack) => errors.add(error),
        );
        async.elapse(const Duration(milliseconds: 20));
        expect(errors, hasLength(wait ? 2 : 1));
        expect(action.factoryCalls, wait ? 2 : 1);
        final entry = store.internalMixinProps.pollingMap['shared']!;
        expect(entry.timer != null, wait);
        expect(action.status.isCompletedOk, isTrue);
        store.shutdown();
        store.teardown();
        async.flushMicrotasks();
      });
    });
  }

  test('key is captured once, while the interval is read again for each tick', () {
    fakeAsync((async) {
      final store = Store<int>(initialState: 0);
      final action = _Sync();
      store.dispatch(action);
      async.flushMicrotasks();
      action.key = 'changed';
      action.interval = const Duration(milliseconds: 25);
      async.elapse(const Duration(milliseconds: 10));
      expect(action.created, hasLength(1));
      expect(action.keyCalls, 1);
      expect(store.internalMixinProps.pollingMap.keys, ['shared']);
      async.elapse(const Duration(milliseconds: 24));
      expect(action.created, hasLength(1));
      async.elapse(const Duration(milliseconds: 1));
      expect(action.created, hasLength(2));
      store.dispatch(_Sync()..poll = Poll.stop);
      async.flushMicrotasks();
      expect(store.internalMixinProps.pollingMap, isEmpty);
      store.shutdown();
      store.teardown();
      async.flushMicrotasks();
    });
  });

  for (final abort in [true, false]) {
    test('admission or key failure leaves an active cycle untouched: abort=$abort', () {
      fakeAsync((async) {
        final store = Store<int>(initialState: 0);
        store.dispatch(_Sync());
        async.flushMicrotasks();
        final entry = store.internalMixinProps.pollingMap['shared']!;
        final action = _Sync()
          ..poll = Poll.stop
          ..abort = abort
          ..failure = 'key';
        store.dispatch(action);
        async.flushMicrotasks();
        expect(action.status.isDispatchAborted, abort);
        expect(action.events, abort ? isEmpty : ['before', 'after']);
        expect(store.internalMixinProps.pollingMap['shared']!.id, same(entry.id));
        expect(entry.timer!.isActive, isTrue);
        store.shutdown();
        store.teardown();
        async.flushMicrotasks();
      });
    });
  }

  test('dispatchSync rejects polling even when the reducer is synchronous', () {
    final store = Store<int>(initialState: 0);
    // ignore: async_redux_lints/dispatch_sync_async_action
    expect(() => store.dispatchSync(_Sync()), throwsA(isA<StoreException>()));
    expect(store.internalMixinProps.pollingMap, isEmpty);
    store.shutdown();
    store.teardown();
  });

  test('a legacy super.wrapReduce call still delegates the reducer once', () {
    fakeAsync((async) {
      final store = Store<int>(initialState: 0);
      final action = _SuperWrap();
      store.dispatch(action);
      async.elapse(const Duration(milliseconds: 10));
      expect(action.wrapperCalls, 1);
      expect(action.events.where((e) => e == 'reduce'), hasLength(1));
      expect(action.created, hasLength(1));
      expect(action.status.isCompletedOk, isTrue);
      store.shutdown();
      store.teardown();
      async.flushMicrotasks();
    });
  });
  test('custom wrapper without super retains start, duplicate, stop and once', () {
    fakeAsync((async) {
      final store = Store<int>(initialState: 0);
      final start = _NoSuper();
      store.dispatch(start);
      async.flushMicrotasks();
      final duplicate = _NoSuper();
      store.dispatch(duplicate);
      async.elapse(const Duration(milliseconds: 10));
      expect(start.wrapperCalls, 1);
      expect(start.created, hasLength(1));
      expect(duplicate.events, ['before', 'after']);
      final stop = _NoSuper()..poll = Poll.stop;
      store.dispatch(stop);
      async.flushMicrotasks();
      expect(stop.events, ['before', 'after']);
      expect(store.internalMixinProps.pollingMap, isEmpty);
      final once = _NoSuper()..poll = Poll.once;
      store.dispatch(once);
      async.flushMicrotasks();
      expect(once.events, ['before', 'reduce', 'after']);
      expect(once.wrapperCalls, 1);
      expect(store.internalMixinProps.pollingMap, isEmpty);
      store.shutdown();
      store.teardown();
      async.flushMicrotasks();
    });
  });
}

abstract class _Hooks extends ReduxAction<int> {
  bool abort = false;
  String failure = 'success';
  final events = <String>[];
  final error = const UserException('failure').noDialog;

  @override
  bool abortDispatch() => abort;
  @override
  void before() {
    events.add('before');
    if (failure == 'before') throw error;
  }

  @override
  void after() => events.add('after');

  int run() {
    events.add('reduce');
    if (failure == 'reduce') throw error;
    return state + 1;
  }
}

abstract class _Controller extends _Hooks with Polling {
  @override
  Poll poll = Poll.start;
  bool wait = true;
  Object key = 'shared';
  int keyCalls = 0;
  Duration interval = const Duration(milliseconds: 10);
  Future<void>? gate;
  bool factoryThrows = false;
  int factoryCalls = 0;
  final created = <_Tick>[];

  @override
  bool get pollWaitsForRun => wait;
  @override
  Duration get pollInterval => interval;
  @override
  Object computePollingKey() {
    keyCalls++;
    if (failure == 'key') throw error;
    return key;
  }

  @override
  ReduxAction<int> createPollingAction() {
    factoryCalls++;
    if (factoryThrows) throw StateError('factory');
    final tick = _Tick();
    created.add(tick);
    return tick;
  }
}

class _Sync extends _Controller {
  @override
  int reduce() => run();
}

class _Async extends _Controller {
  @override
  Future<int> reduce() async {
    await (gate ?? microtask);
    return run();
  }
}

class _Tick extends ReduxAction<int> {
  @override
  int reduce() => state + 1;
}

class _SuperWrap extends _Sync {
  int wrapperCalls = 0;
  @override
  Future<int?> wrapReduce(Reducer<int> reduce) async {
    wrapperCalls++;
    return super.wrapReduce(reduce);
  }
}

class _NoSuper extends _Sync {
  int wrapperCalls = 0;
  @override
  Future<int?> wrapReduce(Reducer<int> reduce) async {
    wrapperCalls++;
    return reduce();
  }
}
