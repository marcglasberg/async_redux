import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/error_contract_support.dart';

void main() {
  for (final kind in ErrorKind.values) {
    for (final asyncAction in [false, true]) {
      for (final phase in ['start', 'end']) {
        for (final position in [0, 1, 2]) {
          for (final reducerOutcome in ['success', 'ordinary', 'user']) {
            test('action observer $phase[$position] throws $kind / '
                'async=$asyncAction / reducer=$reducerOutcome', () {
              fakeAsync((async) {
                final observerError = errorValue(kind, 'observer');
                final original = reducerOutcome == 'user'
                    ? const UserException('reducer').noDialog
                    : StateError('reducer');
                final events = <String>[];
                final seen = <ObservedError>[];
                final action = errorProbe(asyncAction, asyncAction);
                if (reducerOutcome != 'success') action.onReduce = () => throw original;
                final store = Store<int>(
                  initialState: 0,
                  actionObservers: [
                    for (var i = 0; i < 3; i++)
                      _ActionObserver((_, ini) {
                        events.add('${ini ? 'start' : 'end'}:$i');
                        if (i == position && ini == (phase == 'start'))
                          throw observerError;
                      }),
                  ],
                  globalErrorObserver: (_) => ProbeGlobalObserver(seen, (error) => error),
                );
                final result = dispatchCapturing(store, action, async);
                final failed = reducerOutcome != 'success';
                expect(result.error,
                    reducerOutcome == 'ordinary' ? same(original) : isNull);
                expect(result.threwSynchronously,
                    reducerOutcome == 'ordinary' && !asyncAction);
                expect(events, [
                  for (var i = 0; i < 3; i++) 'start:$i',
                  for (var i = 0; i < 3; i++) 'end:$i',
                ]);
                expect(action.status.isDispatched, isTrue);
                expect(action.status.isCompleted, isTrue);
                expect(action.status.originalError, failed ? same(original) : isNull);
                expect(action.status.wrappedError, failed ? same(original) : isNull);
                expect(action.localInputs, hasLength(failed ? 1 : 0));
                expect(seen, hasLength(failed ? 2 : 1));
                expect(seen.where((e) => identical(e.original, observerError)),
                    hasLength(1));
                expect(action.afterStatuses, hasLength(1));
                expect(store.state, failed ? 0 : 1);
                expect(store.isFailed(action.runtimeType), failed);
                expect(store.errors,
                    opensDialog(observerError) ? [same(observerError)] : isEmpty);
                expect(store.actionsInProgress(), isEmpty);
                store.teardown();
                async.flushMicrotasks();
              });
            });
          }
        }
      }
    }
  }

  for (final kind in ErrorKind.values) {
    for (final asyncAction in [false, true]) {
      for (final position in [0, 1, 2]) {
        for (final phase in ['success', 'beforeError', 'reduceError', 'both']) {
          final conversions = phase == 'success'
              ? [
                  ErrorConversion.keep,
                  ErrorConversion.swallow,
                  ErrorConversion.user,
                  ErrorConversion.abort,
                ]
              : [ErrorConversion.keep];
          for (final conversion in conversions) {
            test('state observer $phase[$position] throws $kind / '
                'async=$asyncAction / local=$conversion', () {
              fakeAsync((async) {
                final first = errorValue(kind, 'observer on success');
                final second = errorValue(kind, 'observer on error');
                final original = StateError('action');
                final rule = ErrorRule(conversion, false, 'local');
                final events = <(int, int, int, Object?)>[];
                final seen = <ObservedError>[];
                final persistor = _CountingPersistor();
                final cloud = _CountingPersistor();
                final action = errorProbe(asyncAction, asyncAction)
                  ..onWrapError = (error, _) => rule.apply(error);
                if (phase == 'beforeError') action.onBefore = () => throw original;
                if (phase == 'reduceError') action.onReduce = () => throw original;
                final store = Store<int>(
                  initialState: 0,
                  persistor: persistor,
                  cloudSync: cloud,
                  stateObservers: [
                    for (var i = 0; i < 3; i++)
                      _StateObserver((_, previous, next, error) {
                        events.add((i, previous, next, error));
                        if (i == position) {
                          if (error == null) throw first;
                          if (phase != 'success') throw second;
                        }
                      }),
                  ],
                  globalErrorObserver: (_) => ProbeGlobalObserver(seen, (error) => error),
                );
                final result = dispatchCapturing(store, action, async);
                final registered = phase == 'success' || phase == 'both';
                final state = registered ? 1 : 0;
                final actionFailed = !registered;
                final observerError = registered ? first : second;
                expect(result.error, actionFailed ? same(original) : isNull);
                expect(store.state, state);
                expect(action.afterStates, [state]);
                expect(action.status.hasFinishedMethodBefore, phase != 'beforeError');
                expect(action.status.hasFinishedMethodReduce, registered);
                expect(action.status.isCompleted, isTrue);
                // Reporting a failure must not replace the action's error or
                // mark a successful action as failed, even if the observer fails.
                expect(
                  action.status.originalError,
                  actionFailed ? same(original) : isNull,
                );
                expect(
                  action.status.wrappedError,
                  actionFailed ? same(original) : isNull,
                );
                expect(action.status.isCompletedOk, registered);
                expect(action.localInputs, hasLength(actionFailed ? 1 : 0));
                expect(seen, hasLength(actionFailed ? 2 : 1));
                expect(events, [
                  for (var i = 0; i < 3; i++)
                    (i, 0, state, registered ? null : original),
                ]);
                expect(store.isFailed(action.runtimeType), actionFailed);
                expect(store.errors,
                    opensDialog(observerError) ? [same(observerError)] : isEmpty);
                expect(persistor.saves, registered ? 1 : 0);
                expect(cloud.saves, registered ? 1 : 0);
                expect(store.actionsInProgress(), isEmpty);
                store.teardown();
                async.flushMicrotasks();
              });
            });
          }
        }
      }
    }
  }

  for (final kind in ErrorKind.values) {
    for (final asyncAction in [false, true]) {
      test('global observer factory throws $kind / async=$asyncAction', () {
        fakeAsync((async) {
          final factoryError = errorValue(kind, 'factory');
          final original = StateError('original');
          const local = UserException('local');
          final action = errorProbe(asyncAction, asyncAction)
            ..onReduce = () {
              throw original;
            }
            ..onWrapError = (_, _) => local;
          final store = Store<int>(
            initialState: 0,
            globalErrorObserver: (_) => throw factoryError,
          );
          final result = dispatchCapturing(store, action, async);
          expect(result.error, same(factoryError));
          expect(action.status.originalError, same(original));
          expect(action.status.wrappedError, isNull);
          expect(action.status.isCompletedFailed, isTrue);
          expect(action.localInputs, hasLength(1));
          expect(action.afterStatuses, hasLength(1));
          expect(store.isFailed(action.runtimeType), isFalse);
          expect(store.errors, isEmpty);
          expect(store.actionsInProgress(), isEmpty);
          store.teardown();
          async.flushMicrotasks();
        });
      });
    }
  }

  for (final invalid in ['null', 'object', 'future', 'string']) {
    test('global observer factory returning dynamic $invalid fails at its boundary', () {
      fakeAsync((async) {
        final original = StateError('original');
        final action = SyncErrorProbe()..onReduce = () => throw original;
        final dynamic value = switch (invalid) {
          'null' => null,
          'future' => Future<GlobalErrorObserver<int>>.value(
            GlobalErrorObserverDummy<int>(),
          ),
          'string' => 'invalid observer',
          _ => Object(),
        };
        final store = Store<int>(initialState: 0, globalErrorObserver: (_) => value);
        final result = dispatchCapturing(store, action, async);
        expect(result.error, isA<TypeError>());
        expect(action.status.originalError, same(original));
        expect(action.status.wrappedError, isNull);
        expect(action.afterStatuses, hasLength(1));
        expect(store.isFailed(action.runtimeType), isFalse);
        expect(store.errors, isEmpty);
        expect(store.actionsInProgress(), isEmpty);
        store.teardown();
        async.flushMicrotasks();
      });
    });
  }

  for (final swallowed in [false, true]) {
    test(
      'factory is not called for ${swallowed ? 'locally swallowed error' : 'success'}',
      () {
        fakeAsync((async) {
          final action = SyncErrorProbe()..onWrapError = (_, _) => null;
          if (swallowed) action.onReduce = () => throw StateError('swallowed');
          var calls = 0;
          final store = Store<int>(
            initialState: 0,
            globalErrorObserver: (_) {
              calls++;
              throw StateError('must not be called');
            },
          );
          final result = dispatchCapturing(store, action, async);
          expect(result.error, isNull);
          expect(calls, 0);
          expect(action.status.isCompleted, isTrue);
          expect(store.isFailed(action.runtimeType), isFalse);
          store.teardown();
          async.flushMicrotasks();
        });
      },
    );
  }

  test(
    'reusing a global observer exposes initialization failure on its second action',
    () {
      fakeAsync((async) {
        final seen = <ObservedError>[];
        final observer = ProbeGlobalObserver(seen, (_) => null);
        final store = Store<int>(initialState: 0, globalErrorObserver: (_) => observer);
        final firstError = StateError('first');
        final secondError = StateError('second');
        final first = SyncErrorProbe()..onReduce = () => throw firstError;
        final second = SyncErrorProbe()..onReduce = () => throw secondError;
        expect(dispatchCapturing(store, first, async).error, isNull);
        final result = dispatchCapturing(store, second, async);
        expect(result.error, isA<Error>());
        expect(result.error.toString(), contains('already been initialized'));
        expect(seen, hasLength(1));
        expect(second.status.originalError, same(secondError));
        expect(second.status.wrappedError, same(result.error));
        expect(second.status.isCompletedFailed, isTrue);
        expect(second.afterStatuses, hasLength(1));
        expect(store.isFailed(second.runtimeType), isTrue);
        expect(store.actionsInProgress(), isEmpty);
        store.teardown();
        async.flushMicrotasks();
      });
    },
  );

  for (final observerType in ['action', 'state']) {
    for (final kind in ErrorKind.values) {
      test('$observerType observer return value $kind is ignored', () {
        fakeAsync((async) {
          final value = errorValue(kind, 'unused return value');
          var calls = 0;
          dynamic ignored() {
            calls++;
            return value;
          }

          final action = SyncErrorProbe();
          final store = Store<int>(
            initialState: 0,
            actionObservers: observerType == 'action'
                ? [_ReturningActionObserver(ignored)]
                : null,
            stateObservers: observerType == 'state'
                ? [_ReturningStateObserver(ignored)]
                : null,
          );
          final result = dispatchCapturing(store, action, async);
          expect(result.error, isNull);
          expect(action.status.isCompletedOk, isTrue);
          expect(calls, observerType == 'action' ? 2 : 1);
          expect(store.state, 1);
          expect(store.errors, isEmpty);
          store.teardown();
          async.flushMicrotasks();
        });
      });
    }

    for (final kind in [
      ErrorKind.error,
      ErrorKind.user,
      ErrorKind.abort,
      ErrorKind.text,
    ]) {
      test('async $observerType observer failure $kind does not fail the action', () {
        fakeAsync((async) {
          final gate = Completer<void>();
          final error = errorValue(kind, 'async observer');
          final uncaught = <Object>[];
          late Store<int> store;
          final action = SyncErrorProbe();
          runZonedGuarded(() {
            store = Store<int>(
              initialState: 0,
              actionObservers: observerType == 'action'
                  ? [_AsyncActionObserver(gate.future, error)]
                  : null,
              stateObservers: observerType == 'state'
                  ? [_AsyncStateObserver(gate.future, error)]
                  : null,
            );
            store.dispatchSync(action);
          }, (error, stack) => uncaught.add(error));
          expect(store.state, 1);
          expect(action.status.isCompletedOk, isTrue);
          expect(uncaught, isEmpty);
          gate.complete();
          async.flushMicrotasks();
          expect(uncaught, isEmpty);
          expect(action.status.originalError, isNull);
          expect(action.localInputs, isEmpty);
          expect(store.errors, opensDialog(error)
              ? [for (var i = 0; i < (observerType == 'action' ? 2 : 1); i++) same(error)]
              : isEmpty);
          expect(store.isFailed(action.runtimeType), isFalse);
          store.teardown();
          async.flushMicrotasks();
        });
      });
    }
  }
}

class _ActionObserver extends ActionObserver<int> {
  _ActionObserver(this.callback);
  final void Function(ReduxAction<int>, bool) callback;
  @override
  void observe(ReduxAction<int> action, int dispatchCount, {required bool ini}) =>
      callback(action, ini);
}

class _StateObserver extends StateObserver<int> {
  _StateObserver(this.callback);
  final void Function(ReduxAction<int>, int, int, Object?) callback;
  @override
  void observe(
    ReduxAction<int> action,
    int prevState,
    int newState,
    Object? error,
    int dispatchCount,
  ) => callback(action, prevState, newState, error);
}

class _ReturningActionObserver extends ActionObserver<int> {
  _ReturningActionObserver(this.callback);
  final dynamic Function() callback;
  @override
  dynamic observe(ReduxAction<int> action, int dispatchCount, {required bool ini}) =>
      callback();
}

class _ReturningStateObserver extends StateObserver<int> {
  _ReturningStateObserver(this.callback);
  final dynamic Function() callback;
  @override
  dynamic observe(
    ReduxAction<int> action,
    int prevState,
    int newState,
    Object? error,
    int dispatchCount,
  ) => callback();
}

class _AsyncActionObserver extends ActionObserver<int> {
  _AsyncActionObserver(this.gate, this.error);
  final Future<void> gate;
  final Object error;
  @override
  Future<void> observe(
    ReduxAction<int> action,
    int dispatchCount, {
    required bool ini,
  }) async {
    await gate;
    throw error;
  }
}

class _AsyncStateObserver extends StateObserver<int> {
  _AsyncStateObserver(this.gate, this.failure);
  final Future<void> gate;
  final Object failure;
  @override
  Future<void> observe(
    ReduxAction<int> action,
    int prevState,
    int newState,
    Object? error,
    int dispatchCount,
  ) async {
    await gate;
    throw failure;
  }
}

class _CountingPersistor extends Persistor<int> {
  int saves = 0;
  @override
  Duration? get throttle => null;
  @override
  Future<void> persistDifference({
    required int? lastPersistedState,
    required int newState,
  }) async {
    saves++;
  }

  @override
  Future<int?> readState() async => null;
  @override
  Future<void> deleteState() async {}
}
