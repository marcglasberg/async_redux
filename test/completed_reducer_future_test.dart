import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

// These are runtime contract tests, including intentionally invalid reducers.
// ignore_for_file: async_redux_lints/reduce_without_await
// Completion, including failed statuses, is deliberately observed in these tests.
// ignore_for_file: async_redux_lints/then_on_dispatch_and_wait

void main() {
  for (final kind in ['value', 'sync', 'microtask', 'timer', 'wait', 'completer']) {
    test('awaiting $kind keeps the reducer future incomplete until commit', () {
      fakeAsync((async) {
        final store = Store<int>(initialState: 0);
        final action = _AwaitKind(kind);
        store.dispatch(action);
        expect(store.state, 0);
        expect(action.status.hasFinishedMethodReduce, isFalse);
        async.flushMicrotasks();
        async.elapse(Duration.zero);
        // The reducer's increment must be committed before the nested one.
        expect(store.state, 2);
        expect(action.status.isCompletedOk, isTrue);
        store.teardown();
        async.flushMicrotasks();
      });
    });
  }

  for (final wrapped in [false, true]) {
    for (final globalWrapper in [false, true]) {
      for (final suspends in [false, true]) {
        for (final returnsNull in [false, true]) {
          test('completed-future diagnostic: action wrapper=$wrapped, '
              'store wrapper=$globalWrapper, await=$suspends, null=$returnsNull', () {
            fakeAsync((async) {
              final errors = <Object>[];
              final store = Store<int>(
                initialState: 0,
                wrapReduce: globalWrapper ? _IdentityWrapper() : null,
              );
              final action = wrapped
                  ? _WrappedCheckedReducer(suspends, returnsNull)
                  : _CheckedReducer(suspends, returnsNull);
              ActionStatus? result;

              runZonedGuarded(() {
                store.dispatchAndWait(action).then((status) => result = status);
              }, (error, stack) => errors.add(error));
              async.flushMicrotasks();

              // The diagnostic is an uncaught asynchronous error, not an action
              // failure. It must not be accidentally swallowed by wrapError.
              expect(errors, hasLength(suspends ? 0 : 1));
              if (!suspends) {
                expect(errors.single, contains('returned a completed Future'));
                expect(errors.single, contains('state changes being lost'));
                expect(errors.single, contains('await microtask;'));
              }
              expect(result, same(action.status));
              expect(result!.isCompletedOk, isTrue);
              expect(result!.originalError, isNull);
              expect(result!.wrappedError, isNull);
              expect(action.afterCalls, 1);
              expect(action.wrapErrorCalls, 0);
              expect(store.state, returnsNull ? 0 : 1);
              expect(store.isFailed(action.runtimeType), isFalse);
              expect(store.actionsInProgress(), isEmpty);
              expect(store.errors, isEmpty);
              store.teardown();
              async.flushMicrotasks();
            });
          });
        }
      }
    }
  }

  for (final kind in ['value', 'sync', 'completer', 'sync completer']) {
    test('diagnoses an explicitly completed $kind future', () {
      fakeAsync((async) {
        final errors = <Object>[];
        final store = Store<int>(initialState: 0);
        final action = _ExplicitFuture(kind);
        runZonedGuarded(() {
          store.dispatch(action);
        }, (error, stack) => errors.add(error));
        async.flushMicrotasks();
        expect(errors, hasLength(1));
        expect(errors.single, contains('returned a completed Future'));
        expect(action.status.isCompletedOk, isTrue);
        expect(store.state, 1);
        store.teardown();
        async.flushMicrotasks();
      });
    });
  }

  test('pending future commits before a microtask scheduled at its completion', () {
    fakeAsync((async) {
      final store = Store<int>(initialState: 0);
      final gate = Completer<void>();
      final action = _IncrementAfterGate(gate.future);
      store.dispatch(action);
      store.dispatchSync(_Increment());
      expect(store.state, 1);
      expect(action.status.hasFinishedMethodBefore, isTrue);
      expect(action.status.hasFinishedMethodReduce, isFalse);

      gate.complete();
      async.flushMicrotasks();
      // The reducer returns 2 and schedules another increment. Inserting an
      // asynchronous gap before registering 2 would lose the nested increment.
      expect(store.state, 3);
      expect(action.status.isCompletedOk, isTrue);
      expect(store.actionsInProgress(), isEmpty);
      store.teardown();
      async.flushMicrotasks();
    });
  });

  for (final firstWaits in [false, true]) {
    for (final secondWaits in [false, true]) {
      test('concurrent increments: awaits=$firstWaits/$secondWaits', () {
        fakeAsync((async) {
          final store = Store<int>(initialState: 0);
          final first = _UncheckedIncrement(firstWaits);
          final second = _UncheckedIncrement(secondWaits);
          store.dispatch(first);
          store.dispatch(second);
          async.flushMicrotasks();
          // Without the opt-in assertion, the current implementation accepts
          // completed futures. Pin down the lost update instead of pretending
          // that every invalid reducer is automatically rejected by the store.
          expect(store.state, secondWaits ? 2 : 1);
          expect(first.status.isCompletedOk, isTrue);
          expect(second.status.isCompletedOk, isTrue);
          expect(store.dispatchCount, 2);
          expect(store.reduceCount, 2);
          store.teardown();
          async.flushMicrotasks();
        });
      });
    }
  }

  test('await in before does not replace the required await in reduce', () {
    fakeAsync((async) {
      final errors = <Object>[];
      final store = Store<int>(initialState: 0);
      final action = _AsyncBeforeCheckedReducer();
      runZonedGuarded(() {
        store.dispatch(action);
      }, (error, stack) => errors.add(error));
      async.flushMicrotasks();
      expect(errors, hasLength(1));
      expect(errors.single, contains('returned a completed Future'));
      expect(action.status.isCompletedOk, isTrue);
      store.teardown();
      async.flushMicrotasks();
    });
  });
}

class _CheckedReducer extends ReduxAction<int> {
  _CheckedReducer(this.suspends, this.returnsNull);

  final bool suspends;
  final bool returnsNull;
  int afterCalls = 0;
  int wrapErrorCalls = 0;

  @override
  Future<int?> reduce() async {
    if (suspends) await microtask;
    assertUncompletedFuture();
    return returnsNull ? null : state + 1;
  }

  @override
  void after() => afterCalls++;

  @override
  Object? wrapError(Object error, StackTrace stackTrace) {
    wrapErrorCalls++;
    return error;
  }
}

class _WrappedCheckedReducer extends _CheckedReducer {
  _WrappedCheckedReducer(super.suspends, super.returnsNull);

  @override
  Future<int?> wrapReduce(Reducer<int> reduce) => reduce() as Future<int?>;
}

class _AsyncBeforeCheckedReducer extends _CheckedReducer {
  _AsyncBeforeCheckedReducer() : super(false, false);

  @override
  Future<void> before() async => await microtask;
}

class _IdentityWrapper extends WrapReduce<int> {
  @override
  int process({required int oldState, required int newState}) => newState;
}

class _ExplicitFuture extends ReduxAction<int> {
  _ExplicitFuture(this.kind);

  final String kind;

  @override
  Future<int?> reduce() {
    assertUncompletedFuture();
    switch (kind) {
      case 'value':
        return Future<int?>.value(state + 1);
      case 'sync':
        return Future<int?>.sync(() => state + 1);
      default:
        final completer = kind == 'completer'
            ? Completer<int?>()
            : Completer<int?>.sync();
        completer.complete(state + 1);
        return completer.future;
    }
  }
}

class _UncheckedIncrement extends ReduxAction<int> {
  _UncheckedIncrement(this.suspends);

  final bool suspends;

  @override
  Future<int?> reduce() async {
    if (suspends) await microtask;
    return state + 1;
  }
}

class _Increment extends ReduxAction<int> {
  @override
  int reduce() => state + 1;
}

class _IncrementAfterGate extends ReduxAction<int> {
  _IncrementAfterGate(this.gate);

  final Future<void> gate;

  @override
  Future<int?> reduce() async {
    await gate;
    scheduleMicrotask(() => dispatchSync(_Increment()));
    assertUncompletedFuture();
    return state + 1;
  }
}

class _AwaitKind extends ReduxAction<int> {
  _AwaitKind(this.kind);

  final String kind;

  @override
  Future<int?> reduce() async {
    switch (kind) {
      case 'value':
        await Future<void>.value();
      case 'sync':
        await Future<void>.sync(() {});
      case 'microtask':
        await Future<void>.microtask(() {});
      case 'timer':
        await Future<void>.delayed(Duration.zero);
      case 'wait':
        await Future.wait([Future<void>.value(), Future<void>.value()]);
      case 'completer':
        final completer = Completer<void>.sync()..complete();
        await completer.future;
    }
    scheduleMicrotask(() => dispatchSync(_Increment()));
    assertUncompletedFuture();
    return state + 1;
  }
}
