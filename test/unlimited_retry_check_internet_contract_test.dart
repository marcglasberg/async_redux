import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final create in <_Retrying Function()>[_Sync.new, _Async.new]) {
    for (final offline in [0, 1, 5]) {
      for (final failures in [0, 1, 6]) {
        test('${create().runtimeType}: $offline offline, $failures reducer failures', () {
          fakeAsync((async) {
            final store = Store<int>(initialState: 0);
            final action = create()
              ..offline = offline
              ..failures = failures;
            expect(action.isSync(), isFalse);
            store.dispatch(action);
            expect(action.runs, 0);
            async.elapse(const Duration(seconds: 1));
            expect(action.runs, failures + 1);
            expect(action.checks, offline + failures + 1);
            expect(action.attempts, offline + failures);
            expect(action.decisions, List.generate(failures, (i) => offline + i + 1));
            expect(action.beforeCalls, 1);
            expect(action.afterCalls, 1);
            expect(action.wrapCalls, 0);
            expect(action.status.isCompletedOk, isTrue);
            expect(store.state, 1);
            expect(store.dispatchCount, 1);
            expect(store.reduceCount, 1);
            expect(store.errors, isEmpty);
            expect(store.isWaiting(action.runtimeType), isFalse);
            expect(store.isFailed(action.runtimeType), isFalse);
            store.teardown();
            async.flushMicrotasks();
          });
        });
      }
    }
  }

  for (final limit in [0, 1, 3]) {
    for (final online in [false, true]) {
      test('explicit retry limit $limit is honored online=$online', () {
        fakeAsync((async) {
          final store = Store<int>(initialState: 0);
          final action = _Sync()
            ..limit = limit
            ..offline = online ? 0 : 100
            ..failures = 100;
          store.dispatch(action);
          async.elapse(const Duration(seconds: 1));
          expect(action.attempts, limit + 1);
          expect(action.checks, limit + 1);
          expect(action.runs, online ? limit + 1 : 0);
          expect(action.decisions, online ? List.generate(limit, (i) => i + 1) : isEmpty);
          expect(action.status.isCompletedFailed, isTrue);
          expect(action.wrapCalls, 1);
          expect(action.afterCalls, 1);
          expect(async.nonPeriodicTimerCount, 0);
          store.teardown();
          async.flushMicrotasks();
        });
      });
    }
  }

  test(
    'internet and reducer errors share backoff, with separate caps and exact logs',
    () {
      fakeAsync((async) {
        final store = Store<int>(initialState: 0);
        final times = <int>[];
        final action = _Sync()
          ..offline = 3
          ..failures = 2
          ..onCheck = () => times.add(async.elapsed.inMilliseconds);
        store.dispatch(action);
        async.elapse(const Duration(milliseconds: 71));
        expect(times, [0, 10, 22, 34, 58]);
        expect(action.status.isCompleted, isFalse);
        async.elapse(const Duration(milliseconds: 12));
        expect(times, [0, 10, 22, 34, 58, 83]);
        expect(action.messages, [
          'Trying _Sync; aborted because of no internet.',
          'Retrying _Sync; aborted because of no internet (attempt 1).',
          'Retrying _Sync; aborted because of no internet (attempt 2).',
          'Retrying _Sync (attempt 3).',
          'Retrying _Sync (attempt 4).',
          'Retrying _Sync (attempt 5).',
        ]);
        expect(action.status.isCompletedOk, isTrue);
        store.teardown();
        async.flushMicrotasks();
      });
    },
  );

  for (final phase in [
    'before',
    'check',
    'reduce',
    'decision',
    'abort check',
    'abort reduce',
  ]) {
    test('$phase failure preserves the correct retry and termination path', () {
      fakeAsync((async) {
        final store = Store<int>(initialState: 0);
        final action = _Sync()
          ..phase = phase
          ..giveUp = true;
        store.dispatch(action);
        async.elapse(const Duration(seconds: 1));
        final abort = phase.startsWith('abort');
        final attempted = !abort && phase != 'before';
        expect(action.attempts, attempted ? 1 : 0);
        expect(action.decisions, attempted ? [1] : isEmpty);
        expect(action.checks, phase == 'before' ? 0 : 1);
        expect(
          action.runs,
          ['reduce', 'decision', 'abort reduce'].contains(phase) ? 1 : 0,
        );
        expect(action.status.isDispatchAborted, abort);
        expect(
          action.status.originalError,
          same(phase == 'decision' ? action.decisionError : action.error),
        );
        expect(action.afterCalls, 1);
        expect(async.nonPeriodicTimerCount, 0);
        store.teardown();
        async.flushMicrotasks();
      });
    });
  }

  test('connectivity exceptions are retried and passed to shouldRetry', () {
    fakeAsync((async) {
      final store = Store<int>(initialState: 0);
      final action = _Sync()..checkFailures = 2;
      store.dispatch(action);
      async.elapse(const Duration(seconds: 1));
      expect(action.checks, 3);
      expect(action.runs, 1);
      expect(action.decisions, [1, 2]);
      expect(action.messages, ['Retrying _Sync (attempt 2).']);
      expect(action.status.isCompletedOk, isTrue);
      store.teardown();
      async.flushMicrotasks();
    });
  });

  for (final online in [false, true]) {
    test('connectivity decision permits a request: $online', () {
      fakeAsync((async) {
        final store = Store<int>(initialState: 0);
        final action = _Sync()
          ..online = online
          ..limit = 0;
        store.dispatch(action);
        async.flushMicrotasks();
        expect(action.runs, online ? 1 : 0);
        expect(action.status.isCompletedOk, online);
        expect(action.attempts, online ? 0 : 1);
        expect(action.decisions, isEmpty);
        store.teardown();
        async.flushMicrotasks();
      });
    });
  }

  test('an offline decision waits until connectivity becomes available', () {
    fakeAsync((async) {
      final store = Store<int>(initialState: 0);
      final action = _Sync()..online = false;
      store.dispatch(action);
      async.flushMicrotasks();
      expect(action.checks, 1);
      expect(action.runs, 0);
      expect(action.attempts, 1);
      expect(action.decisions, isEmpty);
      expect(action.status.isCompleted, isFalse);

      action.online = true;
      async.elapse(const Duration(milliseconds: 10));
      expect(action.checks, 2);
      expect(action.runs, 1);
      expect(action.attempts, 1);
      expect(action.decisions, isEmpty);
      expect(action.status.isCompletedOk, isTrue);
      expect(store.state, 1);
      store.teardown();
      async.flushMicrotasks();
    });
  });

  test('duplicates are rejected throughout before, connectivity and backoff', () {
    fakeAsync((async) {
      final store = Store<int>(initialState: 0);
      final beforeGate = Completer<void>();
      final checkGate = Completer<void>();
      final action = _Sync()
        ..beforeGate = beforeGate.future
        ..checkGate = checkGate.future
        ..failures = 1;
      store.dispatch(action);
      void duplicate() {
        final next = _Sync();
        expect((store.dispatch(next) as ActionStatus).isDispatchAborted, isTrue);
        expect(next.beforeCalls, 0);
        expect(next.checks, 0);
        expect(next.afterCalls, 0);
        expect(next.status.isDispatched, isFalse);
      }

      duplicate();
      beforeGate.complete();
      async.flushMicrotasks();
      duplicate();
      checkGate.complete();
      async.flushMicrotasks();
      duplicate();
      final otherType = _Async();
      store.dispatch(otherType);
      async.flushMicrotasks();
      expect(otherType.status.isCompletedOk, isTrue);
      async.elapse(const Duration(milliseconds: 10));
      expect(action.status.isCompletedOk, isTrue);
      final later = _Sync();
      store.dispatch(later);
      async.flushMicrotasks();
      expect(later.status.isCompletedOk, isTrue);
      expect(store.internalMixinProps.nonReentrantKeySet, isEmpty);
      store.teardown();
      async.flushMicrotasks();
    });
  });

  test('custom admission and shutdown skip every lifecycle and connectivity hook', () {
    fakeAsync((async) {
      final store = Store<int>(initialState: 0);
      final aborted = _Sync()..abort = true;
      store.dispatch(aborted);
      expect(aborted.status.isDispatchAborted, isTrue);
      expect(aborted.beforeCalls, 0);
      expect(aborted.checks, 0);
      aborted.abort = false;
      store.dispatch(aborted);
      async.flushMicrotasks();
      expect(aborted.status.isCompletedOk, isTrue);
      store.shutdown();
      final stopped = _Sync();
      store.dispatch(stopped);
      expect(stopped.status.isDispatchAborted, isTrue);
      expect(stopped.beforeCalls, 0);
      expect(stopped.checks, 0);
      async.flushMicrotasks();
    });
  });

  for (final simulated in [false, true]) {
    test('store simulation can recover from offline=$simulated', () {
      fakeAsync((async) {
        final store = Store<int>(initialState: 0)
          ..options.hasConnection = () async => simulated;
        final action = _Simulated();
        store.dispatch(action);
        async.flushMicrotasks();
        expect(action.runs, simulated ? 1 : 0);
        store.options.hasConnection = () async => true;
        async.elapse(const Duration(milliseconds: 10));
        expect(action.status.isCompletedOk, isTrue);
        expect(action.runs, 1);
        store.teardown();
        async.flushMicrotasks();
      });
    });
  }

  test('legacy super.wrapReduce delegates each retry once', () {
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
  test('custom admission and wrapper without super preserve every feature', () {
    fakeAsync((async) {
      final store = Store<int>(initialState: 0);
      final action = _NoSuper()
        ..offline = 2
        ..failures = 2;
      store.dispatch(action);
      final duplicate = _NoSuper();
      expect((store.dispatch(duplicate) as ActionStatus).isDispatchAborted, isTrue);
      async.elapse(const Duration(seconds: 1));
      expect(action.runs, 3);
      expect(action.wrapperCalls, 3);
      expect(action.checks, 5);
      expect(action.status.isCompletedOk, isTrue);
      expect(duplicate.checks, 0);
      store.teardown();
      async.flushMicrotasks();
    });
  });
}

abstract class _Hooks extends ReduxAction<int> {
  bool abort = false;
  String? phase;
  int beforeCalls = 0;
  int afterCalls = 0;
  int wrapCalls = 0;
  Future<void>? beforeGate;
  late final Object error = phase?.startsWith('abort') == true
      ? AbortDispatchException()
      : const UserException('failure').noDialog;

  @override
  bool abortDispatch() => abort;

  @override
  Future<void> before() async {
    beforeCalls++;
    if (beforeGate != null) await beforeGate;
    if (phase == 'before') throw error;
  }

  @override
  void after() => afterCalls++;

  @override
  Object? wrapError(Object error, StackTrace stackTrace) {
    wrapCalls++;
    return error;
  }
}

abstract class _Retrying extends _Hooks with UnlimitedRetryCheckInternet {
  int offline = 0;
  int checks = 0;
  int runs = 0;
  int failures = 0;
  int checkFailures = 0;
  int limit = -1;
  bool giveUp = false;
  Future<void>? checkGate;
  bool? online;
  void Function()? onCheck;
  final decisions = <int>[];
  final messages = <String>[];
  final decisionError = const UserException('decision').noDialog;

  @override
  Duration get initialDelay => const Duration(milliseconds: 10);
  @override
  Duration get maxDelay => const Duration(milliseconds: 25);
  @override
  Duration get maxDelayNoInternet => const Duration(milliseconds: 12);
  @override
  int get maxRetries => limit;
  @override
  void printRetries(String message) => messages.add(message);

  @override
  Future<bool> hasConnection() async {
    checks++;
    onCheck?.call();
    if (checkGate != null) await checkGate;
    if (phase == 'check' || phase == 'abort check' || checks <= checkFailures) {
      throw error;
    }
    return online ?? checks > offline;
  }

  @override
  bool shouldRetry(Object error, int attempt) {
    expect(error, same(this.error));
    expect(attempt, attempts);
    decisions.add(attempt);
    if (phase == 'decision') throw decisionError;
    return !giveUp;
  }

  int run() {
    runs++;
    if (runs <= failures || ['reduce', 'decision', 'abort reduce'].contains(phase)) {
      throw error;
    }
    return state + 1;
  }
}

class _Sync extends _Retrying {
  @override
  int reduce() => run();
}

class _Async extends _Retrying {
  @override
  Future<int> reduce() async {
    await microtask;
    return run();
  }
}

class _Simulated extends ReduxAction<int> with UnlimitedRetryCheckInternet {
  int runs = 0;
  @override
  Duration get initialDelay => const Duration(milliseconds: 10);
  @override
  void printRetries(String message) {}
  @override
  int reduce() {
    runs++;
    return state + 1;
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

class _NoSuper extends _Sync {
  int wrapperCalls = 0;
  @override
  bool abortDispatch() => abort;
  @override
  Future<int?> wrapReduce(Reducer<int> reduce) async {
    wrapperCalls++;
    return reduce();
  }
}
