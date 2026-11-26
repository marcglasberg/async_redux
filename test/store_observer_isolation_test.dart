import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/error_contract_support.dart';

void main() {
  for (final phase in ['start', 'state', 'stateError', 'end']) {
    for (final asyncAction in [false, true]) {
      for (final (conversion, throwsResult) in errorRules) {
        test('$phase diagnostic: async action=$asyncAction / '
            '$conversion, throws=$throwsResult', () {
          fakeAsync((async) {
            final observerError = StateError('observer failure');
            final actionError = StateError('action failure');
            final trace = StackTrace.fromString('observer source stack');
            final rule = ErrorRule(conversion, throwsResult, 'global replacement');
            final globals = <_Snapshot>[];
            final continued = <String>[];
            final local = _Persistor();
            final cloud = _Persistor();
            final action = errorProbe(asyncAction, asyncAction);
            if (phase == 'stateError') action.onReduce = () => throw actionError;
            Never fail() => Error.throwWithStackTrace(observerError, trace);
            final Object observer = phase.startsWith('state')
                ? _StateObserver((_, _, _, _) => fail())
                : _ActionObserver((_, ini) {
                    if (ini == (phase == 'start')) fail();
                  });
            final store = Store<int>(
              initialState: 0,
              persistor: local,
              cloudSync: cloud,
              actionObservers: [
                if (observer is ActionObserver<int>) observer,
                _ActionObserver((_, ini) => continued.add(ini ? 'start' : 'end')),
              ],
              stateObservers: [
                if (observer is StateObserver<int>) observer,
                _StateObserver((_, _, _, _) => continued.add('state')),
              ],
              globalErrorObserver: (_) => _Global(
                globals,
                (global) => global.errorSource == GlobalErrorSource.action
                    ? global.error
                    : rule.apply(global.error),
              ),
            );
            final result = dispatchCapturing(store, action, async);
            final failed = phase == 'stateError';
            expect(result.error, failed ? same(actionError) : isNull);
            expect(continued, ['start', 'state', 'end']);
            expect(action.status.isCompletedOk, !failed);
            expect(action.status.isCompletedFailed, failed);
            expect(action.status.originalError, failed ? same(actionError) : isNull);
            expect(action.status.wrappedError, failed ? same(actionError) : isNull);
            expect(action.afterStatuses, hasLength(1));
            expect(action.localInputs, hasLength(failed ? 1 : 0));
            expect(action.afterStates, [failed ? 0 : 1]);
            expect(store.state, failed ? 0 : 1);
            expect(store.isFailed(action.runtimeType), failed);
            expect(store.isWaiting(action), isFalse);
            expect(store.actionsInProgress(), isEmpty);
            expect(local.saves, failed ? [] : [(0, 1)]);
            expect(cloud.saves, failed ? [] : [(0, 1)]);
            expect(globals, hasLength(failed ? 2 : 1));
            final diagnostic = globals.first;
            expect(diagnostic.error, same(observerError));
            expect(diagnostic.originalError, same(observerError));
            expect(diagnostic.stack.toString(), trace.toString());
            expect(diagnostic.observer, same(observer));
            expect(diagnostic.action, same(action));
            expect(diagnostic.store, same(store));
            expect(
              diagnostic.source,
              phase.startsWith('state')
                  ? GlobalErrorSource.stateObserver
                  : GlobalErrorSource.actionObserver,
            );
            expect(diagnostic.ini, phase.startsWith('state') ? null : phase == 'start');
            if (failed) {
              expect(globals.last.source, GlobalErrorSource.action);
              expect(globals.last.observer, isNull);
              expect(globals.last.ini, isNull);
              expect(globals.last.originalError, same(actionError));
            }
            final replacement = rule.expected(observerError);
            expect(
              store.errors,
              opensDialog(replacement) ? [same(replacement)] : isEmpty,
            );
            store.teardown();
            async.flushMicrotasks();
          });
        });
      }
    }
  }

  for (final phase in ['start', 'state', 'end']) {
    for (final lifecycle in ['running', 'shutdown', 'teardown']) {
      for (final (conversion, throwsResult) in errorRules) {
        test('async $phase observer / store=$lifecycle / '
            '$conversion, throws=$throwsResult', () {
          fakeAsync((async) {
            final gate = Completer<void>();
            final error = StateError('late observer failure');
            final trace = StackTrace.fromString('late observer stack');
            final globals = <_Snapshot>[];
            final rule = ErrorRule(conversion, throwsResult, 'global result');
            Future<void> failLater() async {
              await gate.future;
              Error.throwWithStackTrace(error, trace);
            }

            final Object observer = phase == 'state'
                ? _ReturningStateObserver(failLater)
                : _ReturningActionObserver(
                    (ini) => ini == (phase == 'start') ? failLater() : null,
                  );
            final store = Store<int>(
              initialState: 0,
              stateObservers: observer is StateObserver<int> ? [observer] : null,
              actionObservers: observer is ActionObserver<int> ? [observer] : null,
              globalErrorObserver: (_) => _Global(globals, (g) => rule.apply(g.error)),
            );
            final action = SyncErrorProbe();
            final status = store.dispatchSync(action);
            // Dispatch must neither await the observer nor delay the state.
            expect(store.state, 1);
            expect(status.isCompletedOk, isTrue);
            expect(action.afterStatuses, hasLength(1));
            expect(globals, isEmpty);
            if (lifecycle == 'shutdown') store.shutdown();
            if (lifecycle == 'teardown') store.teardown();
            async.flushMicrotasks();
            expect(globals, isEmpty);
            gate.complete();
            async.flushMicrotasks();
            expect(globals, hasLength(1));
            expect(globals.single.error, same(error));
            expect(globals.single.stack.toString(), trace.toString());
            expect(globals.single.observer, same(observer));
            expect(globals.single.ini, phase == 'state' ? null : phase == 'start');
            expect(action.status, same(status));
            expect(action.localInputs, isEmpty);
            expect(store.isFailed(action.runtimeType), isFalse);
            expect(store.actionsInProgress(), isEmpty);
            final result = rule.expected(error);
            expect(store.errors, opensDialog(result) ? [same(result)] : isEmpty);
            if (lifecycle != 'teardown') store.teardown();
            async.flushMicrotasks();
          });
        });
      }
    }
  }

  for (final kind in ErrorKind.values) {
    for (final phase in ['start', 'state', 'end']) {
      test('global factory failure $kind while reporting $phase is contained', () {
        fakeAsync((async) {
          final error = errorValue(kind, 'global factory');
          var factories = 0;
          final store = Store<int>(
            initialState: 0,
            actionObservers: phase == 'state'
                ? null
                : [
                    _ActionObserver((_, ini) {
                      if (ini == (phase == 'start')) throw StateError('observer');
                    }),
                  ],
            stateObservers: phase == 'state'
                ? [_StateObserver((_, _, _, _) => throw StateError('observer'))]
                : null,
            globalErrorObserver: (_) {
              factories++;
              throw error;
            },
          );
          final action = SyncErrorProbe();
          expect(store.dispatchSync(action).isCompletedOk, isTrue);
          async.flushMicrotasks();
          expect(factories, 1);
          expect(store.state, 1);
          expect(action.localInputs, isEmpty);
          expect(action.afterStatuses, hasLength(1));
          expect(store.errors, opensDialog(error) ? [same(error)] : isEmpty);
          expect(store.isFailed(action.runtimeType), isFalse);
          store.teardown();
          async.flushMicrotasks();
        });
      });
    }
  }

  for (final invalid in ['null', 'object', 'future']) {
    test(
      'invalid global factory return $invalid does not escape diagnostic reporting',
      () {
        fakeAsync((async) {
          final dynamic result = switch (invalid) {
            'null' => null,
            'future' => Future.value(GlobalErrorObserverDummy<int>()),
            _ => Object(),
          };
          final store = Store<int>(
            initialState: 0,
            stateObservers: [
              _StateObserver((_, _, _, _) => throw StateError('observer')),
            ],
            globalErrorObserver: (_) => result,
          );
          final action = SyncErrorProbe();
          expect(store.dispatchSync(action).isCompletedOk, isTrue);
          async.flushMicrotasks();
          expect(store.state, 1);
          expect(store.errors, isEmpty);
          store.teardown();
          async.flushMicrotasks();
        });
      },
    );
  }

  test('invalid async global observer cannot leak its rejected future', () {
    fakeAsync((async) {
      final error = StateError('global async failure');
      final snapshots = <_Snapshot>[];
      final store = Store<int>(
        initialState: 0,
        stateObservers: [_StateObserver((_, _, _, _) => throw StateError('observer'))],
        globalErrorObserver: (_) =>
            _Global(snapshots, (_) => Future<Object>.error(error)),
      );
      final action = SyncErrorProbe();
      expect(store.dispatchSync(action).isCompletedOk, isTrue);
      async.flushMicrotasks();
      expect(snapshots, hasLength(1));
      expect(action.status.originalError, isNull);
      expect(store.errors, isEmpty);
      store.teardown();
      async.flushMicrotasks();
    });
  });

  test(
    'development global observer queues diagnostics without recursively dispatching',
    () {
      fakeAsync((async) {
        final store = Store<int>(
          initialState: 0,
          actionObservers: [
            _ActionObserver((_, _) => throw StateError('action observer')),
          ],
          stateObservers: [
            _StateObserver((_, _, _, _) => throw StateError('state observer')),
          ],
          globalErrorObserver: (_) => GlobalErrorObserverForDevelopment<int>(),
        );
        final action = SyncErrorProbe();
        expect(store.dispatchSync(action).isCompletedOk, isTrue);
        async.flushMicrotasks();
        expect(store.dispatchCount, 1);
        expect(store.state, 1);
        expect(store.errors, hasLength(3));
        expect(store.isFailed(action.runtimeType), isFalse);
        expect(store.actionsInProgress(), isEmpty);
        store.teardown();
        async.flushMicrotasks();
      });
    },
  );

  test(
    'a global observer that dispatches recursively cannot recursively report diagnostics',
    () {
      fakeAsync((async) {
        final snapshots = <_Snapshot>[];
        late Store<int> store;
        store = Store<int>(
          initialState: 0,
          actionObservers: [
            _ActionObserver((_, ini) {
              if (ini) throw StateError('observer');
            }),
          ],
          globalErrorObserver: (_) => _Global(snapshots, (_) {
            store.dispatchSync(SyncErrorProbe());
            return null;
          }),
        );
        final action = SyncErrorProbe();
        expect(store.dispatchSync(action).isCompletedOk, isTrue);
        expect(snapshots, hasLength(1));
        expect(store.dispatchCount, 2);
        expect(store.state, 2);
        expect(store.actionsInProgress(), isEmpty);
        store.teardown();
        async.flushMicrotasks();
      });
    },
  );

  test(
    'reusing a global observer does not let diagnostic initialization errors escape',
    () {
      fakeAsync((async) {
        final snapshots = <_Snapshot>[];
        final global = _Global(snapshots, (_) => null);
        final store = Store<int>(
          initialState: 0,
          actionObservers: [_ActionObserver((_, _) => throw StateError('observer'))],
          globalErrorObserver: (_) => global,
        );
        final action = SyncErrorProbe();
        expect(store.dispatchSync(action).isCompletedOk, isTrue);
        expect(snapshots, hasLength(1));
        expect(store.state, 1);
        expect(action.afterStatuses, hasLength(1));
        store.teardown();
        async.flushMicrotasks();
      });
    },
  );

  for (final cloud in [false, true]) {
    test('persistence reports its source and no action observer / cloud=$cloud', () {
      fakeAsync((async) {
        final snapshots = <_Snapshot>[];
        final persistence = _Persistor()..error = StateError('save failure');
        final store = Store<int>(
          initialState: 0,
          persistor: cloud ? null : persistence,
          cloudSync: cloud ? persistence : null,
          globalErrorObserver: (_) => _Global(snapshots, (_) => null),
        );
        final action = SyncErrorProbe();
        expect(store.dispatchSync(action).isCompletedOk, isTrue);
        async.flushMicrotasks();
        expect(snapshots, hasLength(1));
        expect(snapshots.single.source, GlobalErrorSource.persistor);
        expect(snapshots.single.observer, isNull);
        expect(snapshots.single.ini, isNull);
        expect(snapshots.single.action, isNull);
        store.teardown();
        async.flushMicrotasks();
      });
    });
  }
}

class _Snapshot {
  _Snapshot(GlobalErrorObserver<int> global)
    : error = global.error,
      originalError = global.originalError,
      stack = global.stackTrace,
      action = global.action,
      store = global.store,
      source = global.errorSource,
      observer = global.observer,
      ini = global.observerIni;
  final Object error;
  final Object originalError;
  final StackTrace stack;
  final ReduxAction<int>? action;
  final Store<int> store;
  final GlobalErrorSource source;
  final Object? observer;
  final bool? ini;
}

class _Global extends GlobalErrorObserver<int> {
  _Global(this.snapshots, this.callback);
  final List<_Snapshot> snapshots;
  final Object? Function(GlobalErrorObserver<int>) callback;
  @override
  Object? observe() {
    snapshots.add(_Snapshot(this));
    return callback(this);
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
  final dynamic Function(bool) callback;
  @override
  dynamic observe(ReduxAction<int> action, int dispatchCount, {required bool ini}) =>
      callback(ini);
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

class _Persistor extends Persistor<int> {
  final saves = <(int?, int)>[];
  Object? error;
  @override
  Duration? get throttle => null;
  @override
  Future<void> persistDifference({
    required int? lastPersistedState,
    required int newState,
  }) async {
    if (error != null) throw error!;
    saves.add((lastPersistedState, newState));
  }

  @override
  Future<int?> readState() async => null;
  @override
  Future<void> deleteState() async {}
}
