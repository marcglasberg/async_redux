import 'package:async_redux/async_redux.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart' hide Retry;

void main() {
  for (final create in <_Unlimited Function()>[_Sync.new, _Async.new]) {
    for (final failures in [0, 1, 10, 30]) {
      test('${create().runtimeType} retries $failures failures until success', () {
        fakeAsync((async) {
          final store = Store<int>(initialState: 0);
          final action = create()..failures = failures;
          expect(action.maxRetries, -1);
          expect(action.isSync(), isFalse);
          store.dispatch(action);
          async.flushMicrotasks();
          expect(action.runs, 1);
          if (failures > 0) {
            final duplicate = create();
            store.dispatch(duplicate);
            expect(duplicate.status.isDispatchAborted, isTrue);
            expect(duplicate.runs, 0);
            expect(store.isWaiting(action.runtimeType), isTrue);
          }
          async.elapse(const Duration(seconds: 1));
          expect(action.runs, failures + 1);
          expect(action.attempts, failures);
          expect(action.decisions, List.generate(failures, (i) => i + 1));
          expect(action.beforeCalls, 1);
          expect(action.afterCalls, 1);
          expect(action.status.isCompletedOk, isTrue);
          expect(store.state, 1);
          expect(store.internalMixinProps.nonReentrantKeySet, isEmpty);
          store.teardown();
          async.flushMicrotasks();
        });
      });
    }
  }

  for (final mode in ['give up', 'decision throws', 'before throws', 'abort']) {
    test('unlimited retries still terminate when $mode', () {
      fakeAsync((async) {
        final store = Store<int>(initialState: 0);
        final action = _Sync()
          ..failures = 100
          ..mode = mode;
        store.dispatch(action);
        async.elapse(const Duration(seconds: 1));
        final beforeFailed = mode == 'before throws';
        final aborted = mode == 'abort';
        expect(action.runs, beforeFailed ? 0 : 1);
        expect(action.attempts, beforeFailed || aborted ? 0 : 1);
        expect(action.decisions, beforeFailed || aborted ? isEmpty : [1]);
        expect(action.afterCalls, 1);
        expect(action.status.isDispatchAborted, aborted);
        expect(action.status.isCompletedFailed, isTrue);
        if (!aborted) {
          expect(
            action.status.originalError,
            same(mode == 'decision throws' ? action.decisionError : action.error),
          );
        }
        expect(async.nonPeriodicTimerCount, 0);
        expect(store.internalMixinProps.nonReentrantKeySet, isEmpty);
        store.teardown();
        async.flushMicrotasks();
      });
    });
  }

  test('an explicit maxRetries override still takes precedence over the modifier', () {
    fakeAsync((async) {
      final store = Store<int>(initialState: 0);
      final action = _Limited()..failures = 100;
      store.dispatch(action);
      async.elapse(const Duration(seconds: 1));
      expect(action.runs, 3);
      expect(action.attempts, 3);
      expect(action.decisions, [1, 2]);
      expect(action.status.isCompletedFailed, isTrue);
      expect(async.nonPeriodicTimerCount, 0);
      store.teardown();
      async.flushMicrotasks();
    });
  });
}

abstract class _Hooks extends ReduxAction<int> {
  int beforeCalls = 0;
  int afterCalls = 0;
  String? mode;
  final error = const UserException('failure').noDialog;

  @override
  void before() {
    beforeCalls++;
    if (mode == 'before throws') throw error;
  }

  @override
  void after() => afterCalls++;
}

abstract class _Unlimited extends _Hooks with Retry, UnlimitedRetries, NonReentrant {
  int failures = 0;
  int runs = 0;
  final decisions = <int>[];
  final decisionError = const UserException('decision').noDialog;

  @override
  Duration get initialDelay => const Duration(milliseconds: 1);

  @override
  Duration get maxDelay => const Duration(milliseconds: 2);

  @override
  bool shouldRetry(Object error, int attempt) {
    decisions.add(attempt);
    if (mode == 'decision throws') throw decisionError;
    return mode != 'give up';
  }

  int run() {
    runs++;
    if (mode == 'abort') throw AbortDispatchException();
    if (runs <= failures) throw error;
    return state + 1;
  }
}

class _Sync extends _Unlimited {
  @override
  int reduce() => run();
}

class _Async extends _Unlimited {
  @override
  Future<int> reduce() async {
    await microtask;
    return run();
  }
}

class _Limited extends _Sync {
  @override
  int get maxRetries => 2;
}
