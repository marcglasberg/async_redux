import 'package:async_redux/async_redux.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final create in <_Config Function()>[_Sync.new, _Async.new]) {
    test(
      '${create().runtimeType}: only the latest reducer runs, all lifecycles finish',
      () {
        fakeAsync((async) {
          final store = Store<int>(initialState: 0);
          final first = create();
          final last = create();
          store.dispatch(first);
          async.elapse(const Duration(milliseconds: 5));
          store.dispatch(last);
          async.elapse(const Duration(milliseconds: 5));
          expect(first.status.isCompletedOk, isTrue);
          expect(first.status.isDispatchAborted, isFalse);
          expect(first.events, ['before', 'key', 'after']);
          expect(last.status.isCompleted, isFalse);
          expect(store.isWaiting(last.runtimeType), isTrue);
          expect(store.state, 0);
          async.elapse(const Duration(milliseconds: 5));
          expect(last.events, ['before', 'key', 'reduce', 'after']);
          expect(last.status.isCompletedOk, isTrue);
          expect(store.state, 1);
          expect(store.dispatchCount, 2);
          expect(store.reduceCount, 2);
          expect(store.internalMixinProps.debounceLockMap, isEmpty);
          store.teardown();
          async.flushMicrotasks();
        });
      },
    );

    for (final period in [-1, 0, 10, 333]) {
      test(
        '${create().runtimeType}: timing and asynchronous classification, $period',
        () {
          fakeAsync((async) {
            final store = Store<int>(initialState: 0);
            final action = create()..period = period;
            expect(action.isSync(), isFalse);
            // ignore: async_redux_lints/dispatch_sync_async_action
            expect(() => store.dispatchSync(action), throwsA(isA<StoreException>()));
            store.dispatch(action);
            async.flushMicrotasks();
            expect(store.state, 0);
            if (period > 0) {
              async.elapse(Duration(milliseconds: period - 1));
              expect(store.state, 0);
              async.elapse(const Duration(milliseconds: 1));
            } else {
              async.elapse(Duration.zero);
            }
            expect(store.state, 1);
            expect(action.status.isCompletedOk, isTrue);
            store.teardown();
            async.flushMicrotasks();
          });
        },
      );
    }

    for (final failure in ['before', 'key', 'reduce']) {
      test('${create().runtimeType}: $failure failure does not poison a later run', () {
        fakeAsync((async) {
          final store = Store<int>(initialState: 0);
          final action = create()..failure = failure;
          store.dispatch(action);
          async.elapse(const Duration(milliseconds: 10));
          expect(action.status.isCompletedFailed, isTrue);
          expect(action.events.last, 'after');
          expect(store.internalMixinProps.debounceLockMap, isEmpty);
          expect(store.state, 0);
          final next = create();
          store.dispatch(next);
          async.elapse(const Duration(milliseconds: 10));
          expect(next.status.isCompletedOk, isTrue);
          expect(store.state, 1);
          store.teardown();
          async.flushMicrotasks();
        });
      });
    }
  }

  for (final clear in ['method', 'props']) {
    test('$clear clears pending locks and skips their reducers', () {
      fakeAsync((async) {
        final store = Store<int>(initialState: 0);
        final action = _Sync();
        store.dispatch(action);
        if (clear == 'method') {
          action.removeAllLocks();
        } else {
          store.internalMixinProps.clear();
        }
        async.elapse(const Duration(milliseconds: 10));
        expect(action.status.isCompletedOk, isTrue);
        expect(store.state, 0);
        expect(store.internalMixinProps.debounceLockMap, isEmpty);
        store.teardown();
        async.flushMicrotasks();
      });
    });
  }

  test('custom keys share across types, while different keys run independently', () {
    fakeAsync((async) {
      final store = Store<int>(initialState: 0);
      final first = _Sync();
      final last = _Async();
      final other = _Sync()..key = 'other';
      store.dispatch(first);
      store.dispatch(last);
      store.dispatch(other);
      async.elapse(const Duration(milliseconds: 10));
      expect(first.events.contains('reduce'), isFalse);
      expect(last.events.contains('reduce'), isTrue);
      expect(other.events.contains('reduce'), isTrue);
      expect(store.state, 2);
      store.teardown();
      async.flushMicrotasks();
    });
  });

  test('the lock is captured once even when its parameter changes', () {
    fakeAsync((async) {
      final store = Store<int>(initialState: 0);
      final action = _Sync();
      store.dispatch(action);
      action.key = 'changed';
      async.elapse(const Duration(milliseconds: 10));
      expect(action.events.where((event) => event == 'key'), hasLength(1));
      expect(store.state, 1);
      expect(store.internalMixinProps.debounceLockMap, isEmpty);
      store.teardown();
      async.flushMicrotasks();
    });
  });

  test('run counter wraps at the existing JavaScript-safe bound', () {
    fakeAsync((async) {
      final store = Store<int>(initialState: 0);
      final map = store.internalMixinProps.debounceLockMap;
      map[null] = 9000000000000000;
      final first = _Sync();
      final last = _Sync();
      store.dispatch(first);
      expect(map[null], 0);
      store.dispatch(last);
      expect(map[null], 1);
      async.elapse(const Duration(milliseconds: 10));
      expect(first.events.contains('reduce'), isFalse);
      expect(last.events.contains('reduce'), isTrue);
      expect(map, isEmpty);
      store.teardown();
      async.flushMicrotasks();
    });
  });

  test('an existing wrapReduce override can delegate to super', () {
    fakeAsync((async) {
      final store = Store<int>(initialState: 0);
      final action = _SuperWrap();
      store.dispatch(action);
      expect(store.state, 0);
      async.elapse(const Duration(milliseconds: 10));
      expect(store.state, 1);
      expect(action.status.isCompletedOk, isTrue);
      expect(action.wrapCalls, 1);
      store.teardown();
      async.flushMicrotasks();
    });
  });

  test('custom wrapReduce without super is debounced together with reduce', () {
    fakeAsync((async) {
      final store = Store<int>(initialState: 0);
      final first = _NoSuperWrap();
      final last = _NoSuperWrap();
      store.dispatch(first);
      store.dispatch(last);
      expect(store.state, 0);
      async.elapse(const Duration(milliseconds: 10));
      expect(store.state, 1);
      expect(first.wrapCalls, 0);
      expect(last.wrapCalls, 1);
      expect(first.status.isCompletedOk, isTrue);
      expect(last.status.isCompletedOk, isTrue);
      store.teardown();
      async.flushMicrotasks();
    });
  });

  for (final create in <_Config Function()>[
    _NonReentrant.new,
    _Throttled.new,
    _Fresh.new,
    _Internet.new,
  ]) {
    test('cooperates with ${create().runtimeType}', () {
      fakeAsync((async) {
        final store = Store<int>(initialState: 0)
          ..forceInternetOnOffSimulation = () => true;
        final first = create();
        final second = create();
        store.dispatch(first);
        store.dispatch(second);
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 10));
        expect(store.state, 1);
        expect(first.status.isCompleted, isTrue);
        expect(second.status.isDispatchAborted, second is! CheckInternet);
        expect(store.internalMixinProps.debounceLockMap, isEmpty);
        store.teardown();
        async.flushMicrotasks();
      });
    });
  }
}

abstract class _Hooks extends ReduxAction<int> {
  final events = <String>[];
  String? failure;

  void failAt(String stage) {
    if (failure == stage) throw UserException(stage).noDialog;
  }

  @override
  void before() {
    events.add('before');
    failAt('before');
  }

  int runReduce() {
    events.add('reduce');
    failAt('reduce');
    return state + 1;
  }

  @override
  void after() => events.add('after');
}

abstract class _Config extends _Hooks with Debounce {
  Object? key;
  int period = 10;

  @override
  int get debounce => period;

  @override
  Object? lockBuilder() {
    events.add('key');
    failAt('key');
    return key;
  }
}

class _Sync extends _Config {
  @override
  int reduce() => runReduce();
}

class _Async extends _Config {
  @override
  Future<int> reduce() async {
    await microtask;
    return runReduce();
  }
}

class _SuperWrap extends _Sync {
  int wrapCalls = 0;

  @override
  Future<int?> wrapReduce(Reducer<int> reduce) async {
    wrapCalls++;
    return super.wrapReduce(reduce);
  }
}

class _NoSuperWrap extends _Sync {
  int wrapCalls = 0;

  @override
  Future<int?> wrapReduce(Reducer<int> reduce) async {
    wrapCalls++;
    return reduce();
  }
}

class _NonReentrant extends _Sync with NonReentrant {}

class _Throttled extends _Sync with Throttle {}

class _Fresh extends _Sync with Fresh {}

class _Internet extends _Sync with CheckInternet {}
