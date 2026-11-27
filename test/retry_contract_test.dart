import 'package:async_redux/async_redux.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart' hide Retry;

void main() {
  for (final create in <_Config Function()>[_Sync.new, _Async.new]) {
    for (final limit in [-1, 0, 1, 3]) {
      for (final failures in [0, 1, 4]) {
        test('${create().runtimeType}: limit=$limit, failures=$failures', () {
          fakeAsync((async) {
            final store = Store<int>(initialState: 0);
            final action = create()
              ..limit = limit
              ..failures = failures;
            expect(action.isSync(), isFalse);
            store.dispatch(action);
            expect(action.runs, 0); // The first attempt also crosses a microtask.
            async.elapse(const Duration(seconds: 1));
            final success = limit < 0 || failures <= limit;
            final failedAttempts = success ? failures : limit + 1;
            expect(action.attempts, failedAttempts);
            expect(action.runs, failedAttempts + (success ? 1 : 0));
            expect(
              action.decisions,
              List.generate(success ? failures : limit, (i) => i + 1),
            );
            expect(action.beforeCalls, 1);
            expect(action.afterCalls, 1);
            expect(action.wrapCalls, success ? 0 : 1);
            expect(action.status.isCompletedOk, success);
            expect(
              action.status.originalError,
              success ? isNull : same(action.errors.last),
            );
            expect(store.dispatchCount, 1);
            expect(store.reduceCount, 1);
            expect(store.state, success ? 1 : 0);
            expect(store.internalMixinProps.nonReentrantKeySet, isEmpty);
            store.teardown();
            async.flushMicrotasks();
          });
        });
      }
    }
  }

  test('retry backoff uses 10, 20, then the 25ms cap', () {
    fakeAsync((async) {
      final store = Store<int>(initialState: 0);
      final times = <int>[];
      final action = _Sync()
        ..failures = 3
        ..onRun = () => times.add(async.elapsed.inMilliseconds);
      store.dispatch(action);
      async.flushMicrotasks();
      expect(times, [0]);
      async.elapse(const Duration(milliseconds: 9));
      expect(times, [0]);
      async.elapse(const Duration(milliseconds: 1));
      expect(times, [0, 10]);
      async.elapse(const Duration(milliseconds: 20));
      expect(times, [0, 10, 30]);
      async.elapse(const Duration(milliseconds: 25));
      expect(times, [0, 10, 30, 55]);
      expect(action.status.isCompletedOk, isTrue);
      store.teardown();
      async.flushMicrotasks();
    });
  });

  test('the backoff starts only after the async reducer fails', () {
    fakeAsync((async) {
      final store = Store<int>(initialState: 0);
      final times = <int>[];
      final action = _Async()
        ..failures = 2
        ..workMillis = 7
        ..onRun = () => times.add(async.elapsed.inMilliseconds);
      store.dispatch(action);
      async.elapse(const Duration(milliseconds: 51));
      expect(times, [7, 24, 51]);
      expect(action.status.isCompletedOk, isTrue);
      store.teardown();
      async.flushMicrotasks();
    });
  });

  for (final factor in [-1.0, 0.0, 1.0, 1.5, 3.0]) {
    test('nextDelay preserves multiplier normalization and cap: $factor', () {
      final action = _Sync()..factor = factor;
      final multiplier = factor <= 1 ? 2 : factor;
      expect(action.nextDelay(), const Duration(milliseconds: 10));
      final next = Duration(milliseconds: (10 * multiplier).round());
      expect(action.nextDelay(), next > action.maxDelay ? action.maxDelay : next);
      for (var i = 0; i < 20; i++) action.nextDelay();
      expect(action.nextDelay(), action.maxDelay);
    });
  }

  for (final initial in [-1, 0, 100]) {
    test('initial delay $initial is used with the configured cap', () {
      fakeAsync((async) {
        final store = Store<int>(initialState: 0);
        final action = _Sync()
          ..delayMillis = initial
          ..failures = 1;
        store.dispatch(action);
        async.elapse(const Duration(milliseconds: 25));
        expect(action.runs, 2);
        expect(action.status.isCompletedOk, isTrue);
        store.teardown();
        async.flushMicrotasks();
      });
    });
  }

  test('before errors never reach the retry loop', () {
    fakeAsync((async) {
      final store = Store<int>(initialState: 0);
      final action = _Sync()..failBefore = true;
      store.dispatch(action);
      async.elapse(const Duration(seconds: 1));
      expect(action.runs, 0);
      expect(action.attempts, 0);
      expect(action.decisions, isEmpty);
      expect(action.afterCalls, 1);
      expect(action.status.isCompletedFailed, isTrue);
      store.teardown();
      async.flushMicrotasks();
    });
  });

  test('an abort in reduce is not retried or counted as an attempt', () {
    fakeAsync((async) {
      final store = Store<int>(initialState: 0);
      final action = _Sync()..abortReduce = true;
      store.dispatch(action);
      async.elapse(const Duration(seconds: 1));
      expect(action.runs, 1);
      expect(action.attempts, 0);
      expect(action.decisions, isEmpty);
      expect(action.status.isDispatchAborted, isTrue);
      store.teardown();
      async.flushMicrotasks();
    });
  });

  test('CheckInternet runs once before all retry attempts', () {
    fakeAsync((async) {
      final store = Store<int>(initialState: 0)
        ..forceInternetOnOffSimulation = () => true;
      final action = _Internet()..failures = 2;
      store.dispatch(action);
      async.elapse(const Duration(seconds: 1));
      expect(action.runs, 3);
      expect(action.checks, 1);
      expect(action.beforeCalls, 1);
      expect(action.status.isCompletedOk, isTrue);
      store.teardown();
      async.flushMicrotasks();
    });
  });

  test('a wrapReduce override delegating to super still retries', () {
    fakeAsync((async) {
      final store = Store<int>(initialState: 0);
      final action = _SuperWrap()..failures = 2;
      store.dispatch(action);
      async.elapse(const Duration(seconds: 1));
      expect(action.runs, 3);
      expect(action.wrapperCalls, 3);
      expect(action.status.isCompletedOk, isTrue);
      store.teardown();
      async.flushMicrotasks();
    });
  });

  test('custom wrapReduce without super still retries', () {
    fakeAsync((async) {
      final store = Store<int>(initialState: 0);
      final action = _NoSuperWrap()..failures = 2;
      store.dispatch(action);
      async.elapse(const Duration(seconds: 1));
      expect(action.runs, 3);
      expect(action.wrapperCalls, 3);
      expect(action.status.isCompletedOk, isTrue);
      store.teardown();
      async.flushMicrotasks();
    });
  });
}

abstract class _Hooks extends ReduxAction<int> {
  int runs = 0;
  int failures = 0;
  int beforeCalls = 0;
  int afterCalls = 0;
  int wrapCalls = 0;
  bool failBefore = false;
  bool abortReduce = false;
  void Function()? onRun;
  final errors = <Object>[];

  @override
  void before() {
    beforeCalls++;
    if (failBefore) throw const UserException('before').noDialog;
  }

  int runReduce() {
    runs++;
    onRun?.call();
    if (abortReduce) throw AbortDispatchException();
    if (runs <= failures) {
      final error = UserException('attempt $runs').noDialog;
      errors.add(error);
      throw error;
    }
    return state + 1;
  }

  @override
  Object? wrapError(Object error, StackTrace stackTrace) {
    wrapCalls++;
    return error;
  }

  @override
  void after() => afterCalls++;
}

abstract class _Config extends _Hooks with Retry, NonReentrant {
  int limit = 3;
  int delayMillis = 10;
  double factor = 2;
  final decisions = <int>[];

  @override
  int get maxRetries => limit;

  @override
  Duration get initialDelay => Duration(milliseconds: delayMillis);

  @override
  Duration get maxDelay => const Duration(milliseconds: 25);

  @override
  double get multiplier => factor;

  @override
  bool shouldRetry(Object error, int attempt) {
    expect(error, same(errors.last));
    expect(attempt, attempts);
    decisions.add(attempt);
    return true;
  }
}

class _Sync extends _Config {
  @override
  int reduce() => runReduce();
}

class _Async extends _Config {
  int workMillis = 0;

  @override
  Future<int> reduce() async {
    await Future<void>.delayed(Duration(milliseconds: workMillis));
    return runReduce();
  }
}

class _Internet extends _Sync with CheckInternet {
  int checks = 0;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() {
    checks++;
    return super.checkConnectivity();
  }
}

class _SuperWrap extends _Sync {
  int wrapperCalls = 0;

  @override
  Future<int?> wrapReduce(Reducer<int> reduce) async {
    wrapperCalls++;
    return super.wrapReduce(reduce);
  }
}

class _NoSuperWrap extends _Sync {
  int wrapperCalls = 0;

  @override
  Future<int?> wrapReduce(Reducer<int> reduce) async {
    wrapperCalls++;
    return reduce();
  }
}
