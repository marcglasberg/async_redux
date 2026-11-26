import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

// Invalid arguments are deliberate runtime contract tests.
// ignore_for_file: async_redux_lints/wait_fail_invalid_argument

void main() {
  for (final method in ['isWaiting', 'isFailed', 'exceptionFor', 'clearExceptionFor']) {
    for (final list in [false, true]) {
      test(
        '$method invalid ${list ? 'list entry' : 'argument'} reports asynchronously',
        () {
          fakeAsync((async) {
            final store = Store<int>(initialState: 0);
            final errors = <Object>[];
            final Object argument = list ? <Object>[42] : 42;
            Object? returned;
            runZonedGuarded(() {
              switch (method) {
                case 'isWaiting':
                  returned = store.isWaiting(argument);
                case 'isFailed':
                  returned = store.isFailed(argument);
                case 'exceptionFor':
                  returned = store.exceptionFor(argument);
                case 'clearExceptionFor':
                  store.clearExceptionFor(argument);
              }
            }, (error, stack) => errors.add(error));
            expect(errors, isEmpty);
            expect(returned, method.startsWith('is') ? false : null);
            async.flushMicrotasks();
            expect(errors, hasLength(1));
            expect(errors.single, isA<StoreException>());
            expect(errors.single.toString(), contains(method));
            expect(store.state, 0);
            expect(store.dispatchCount, 0);
            store.teardown();
            async.flushMicrotasks();
          });
        },
      );
    }
  }

  test(
    'waiting accepts mixed action instances and types and waits for all types',
    () async {
      final store = Store<int>(initialState: 0);
      final gate = Completer<void>();
      final action = _Pending(gate.future);
      final idle = _Pending(gate.future);
      final future = store.dispatchAndWait(action);
      expect(store.isWaiting([idle, action]), isTrue);
      expect(store.isWaiting([action, idle]), isTrue);
      // Unrelated types must not hide a matching action or create a match.
      // ignore: async_redux_lints/wait_fail_never_matches
      expect(store.isWaiting([String, action]), isTrue);
      // ignore: async_redux_lints/wait_fail_never_matches
      expect(store.isWaiting([idle, String]), isFalse);
      final all = store.waitAllActionTypes([]);
      gate.complete();
      await future;
      await all;
      expect(store.isWaiting([action, _Pending]), isFalse);
      await store.teardown();
    },
  );

  test('ActionStatus value equality, hash and copies include every lifecycle field', () {
    final store = Store<int>(initialState: 0);
    final action = UpdateStateAction<int>(1);
    final status = store.dispatchSync(action);
    final copy = status.copy();
    expect(copy, status);
    expect(copy.hashCode, status.hashCode);
    expect(status, isNot(Object()));
    expect(status.toString(), contains('hasFinishedMethodAfter: true'));
    final variants = [
      status.copy(isDispatched: false),
      status.copy(hasFinishedMethodBefore: false),
      status.copy(hasFinishedMethodReduce: false),
      status.copy(hasFinishedMethodAfter: false),
      status.copy(isDispatchAborted: true),
      status.copy(originalError: StateError('original')),
      status.copy(wrappedError: StateError('wrapped')),
      status.copy(context: (UpdateStateAction<int>(1), store)),
    ];
    for (final variant in variants) {
      expect(variant, isNot(status));
    }
    expect(status.isCompletedOk, isTrue);
    expect(status.context, (action, store));
    store.teardown();
  });

  for (final observer in ['dummy', 'swallow', 'development']) {
    for (final userError in [false, true]) {
      test('$observer global error observer, user exception=$userError', () {
        fakeAsync((async) {
          final error = userError ? const UserException('user') : StateError('ordinary');
          final store = Store<int>(
            initialState: 0,
            globalErrorObserver: (_) => switch (observer) {
              'dummy' => GlobalErrorObserverDummy<int>(),
              'swallow' => SwallowGlobalErrorObserver<int>(),
              _ => GlobalErrorObserverForDevelopment<int>(),
            },
          );
          final action = _Throw(error);
          Object? thrown;
          try {
            store.dispatchSync(action);
          } catch (e) {
            thrown = e;
          }
          async.flushMicrotasks();
          expect(thrown, !userError && observer != 'swallow' ? same(error) : isNull);
          expect(action.status.originalError, same(error));
          expect(
            action.status.wrappedError,
            observer == 'swallow' ? isNull : same(error),
          );
          expect(action.status.isCompletedFailed, isTrue);
          final dialog =
              observer != 'swallow' && (userError || observer == 'development');
          expect(store.errors, hasLength(dialog ? 1 : 0));
          if (dialog) {
            if (userError) {
              expect(store.errors.single, same(error));
            } else {
              expect(store.errors.single.toString(), contains('ordinary'));
              // The development observer dispatches a separate dialog action.
              expect(store.dispatchCount, 2);
            }
          }
          expect(store.isFailed(_Throw), observer != 'swallow');
          expect(store.actionsInProgress(), isEmpty);
          store.teardown();
          async.flushMicrotasks();
        });
      });
    }
  }
}

class _Pending extends ReduxAction<int> {
  _Pending(this.gate);

  final Future<void> gate;

  @override
  Future<int?> reduce() async {
    await gate;
    return state + 1;
  }
}

class _Throw extends ReduxAction<int> {
  _Throw(this.error);

  final Object error;

  @override
  int? reduce() => throw error;
}
