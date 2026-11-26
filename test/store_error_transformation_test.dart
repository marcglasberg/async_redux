import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/error_contract_support.dart';

void main() {
  for (final layer in ['local', 'global']) {
    for (final asyncAction in [false, true]) {
      for (final completesWithError in [false, true]) {
        test('pending Future returned by $layer is not awaited / '
            'async=$asyncAction / future fails=$completesWithError', () {
          fakeAsync((async) {
            final original = StateError('original');
            const futureError = UserException('future completion');
            final seen = <ObservedError>[];
            final uncaught = <Object>[];
            late Completer<Object?> completer;
            late Store<int> store;
            late DispatchResult result;
            final action = errorProbe(asyncAction, asyncAction)
              ..onReduce = () => throw original;
            runZonedGuarded(() {
              completer = Completer<Object?>();
              action.onWrapError = (error, _) =>
                  layer == 'local' ? completer.future : error;
              store = Store<int>(
                initialState: 0,
                globalErrorObserver: (_) => ProbeGlobalObserver(
                  seen,
                  (error) => layer == 'global' ? completer.future : error,
                ),
              );
              result = dispatchCapturing(store, action, async);
            }, (error, stack) => uncaught.add(error));
            expect(completer.isCompleted, isFalse);
            expect(result.error, same(completer.future));
            expect(action.status.originalError, same(original));
            expect(action.status.wrappedError, same(completer.future));
            expect(action.status.isCompletedFailed, isTrue);
            expect(action.afterStatuses, hasLength(1));
            expect(store.errors, isEmpty);
            expect(uncaught, isEmpty);
            if (completesWithError) {
              completer.completeError(futureError);
            } else {
              completer.complete(futureError);
            }
            async.flushMicrotasks();
            expect(uncaught, completesWithError ? [same(futureError)] : isEmpty);
            expect(action.status.wrappedError, same(completer.future));
            expect(store.errors, isEmpty);
            expect(store.actionsInProgress(), isEmpty);
            store.teardown();
            async.flushMicrotasks();
          });
        });
      }
    }
  }

  // Exhaustive product over the documented error categories and both ways of
  // replacing an error. In particular, UserException and abort are INPUTS too.
  for (final source in [
    ErrorKind.exception,
    ErrorKind.error,
    ErrorKind.user,
    ErrorKind.noDialog,
    ErrorKind.abort,
  ]) {
    for (final asyncBefore in [false, true]) {
      for (final asyncReduce in [false, true]) {
        for (final site in ['before', 'reduce']) {
          for (final (localKind, localThrows) in errorRules) {
            for (final (globalKind, globalThrows) in errorRules) {
              test('$source / beforeAsync=$asyncBefore / reduceAsync=$asyncReduce / '
                  '$site / local=$localKind,throw=$localThrows / '
                  'global=$globalKind,throw=$globalThrows', () {
                fakeAsync((async) {
                  final original = errorValue(source, 'original');
                  final local = ErrorRule(localKind, localThrows, 'local');
                  final global = ErrorRule(globalKind, globalThrows, 'global');
                  _checkPipeline(
                    async,
                    asyncBefore,
                    asyncReduce,
                    site,
                    original,
                    local.apply,
                    global.apply,
                    local.expected(original),
                    local.expected(original) == null
                        ? null
                        : global.expected(local.expected(original)!),
                  );
                });
              });
            }
          }
        }
      }
    }
  }

  for (final kind in ErrorKind.values) {
    for (final asyncAction in [false, true]) {
      for (final site in ['before', 'reduce']) {
        test('arbitrary original $kind / async=$asyncAction / $site', () {
          fakeAsync((async) {
            final original = errorValue(kind, 'original');
            _checkPipeline(
              async,
              asyncAction,
              asyncAction,
              site,
              original,
              (error) => error,
              (error) => error,
              original,
              original,
            );
          });
        });
      }
      for (final layer in ['local', 'global']) {
        for (final throwsValue in [false, true]) {
          test('$layer ${throwsValue ? 'throws' : 'returns'} $kind / '
              'async=$asyncAction', () {
            fakeAsync((async) {
              final original = StateError('original');
              final replacement = errorValue(kind, 'replacement');
              Object? transform(Object _) {
                if (throwsValue) throw replacement;
                return replacement;
              }

              _checkPipeline(
                async,
                asyncAction,
                asyncAction,
                'reduce',
                original,
                layer == 'local' ? transform : (error) => error,
                layer == 'global' ? transform : (error) => error,
                layer == 'local' ? replacement : original,
                replacement,
              );
            });
          });
        }
      }
    }
  }

  for (final asyncAction in [false, true]) {
    for (final site in ['before', 'reduce', 'local', 'global']) {
      test('throwing dynamic null becomes a TypeError in $site / async=$asyncAction', () {
        fakeAsync((async) {
          final action = errorProbe(asyncAction, asyncAction);
          final original = StateError('original');
          final seen = <ObservedError>[];
          Never throwNull() {
            dynamic invalid;
            throw invalid;
          }

          action.onBefore = site == 'before' ? throwNull : null;
          action.onReduce = () {
            if (site == 'reduce') throwNull();
            throw original;
          };
          action.onWrapError = (error, stack) => site == 'local' ? throwNull() : error;
          final store = Store<int>(
            initialState: 0,
            globalErrorObserver: (_) => ProbeGlobalObserver(
              seen,
              (error) => site == 'global' ? throwNull() : error,
            ),
          );
          final result = dispatchCapturing(store, action, async);
          expect(result.error, isA<TypeError>());
          expect(action.status.wrappedError, same(result.error));
          expect(
            action.status.originalError,
            site == 'before' || site == 'reduce' ? same(result.error) : same(original),
          );
          expect(action.status.isCompletedFailed, isTrue);
          expect(action.afterStatuses, hasLength(1));
          expect(store.errors, isEmpty);
          expect(store.isFailed(action.runtimeType), isTrue);
          expect(store.actionsInProgress(), isEmpty);
          store.teardown();
          async.flushMicrotasks();
        });
      });
    }
  }

  test('UserException metadata and callbacks survive both wrappers unchanged', () {
    fakeAsync((async) {
      var callbacks = 0;
      final error = const UserException('message', reason: 'reason')
          .addCause(StateError('cause'))
          .addProps({'key': 'value'})
          .addCallbacks(onOk: () => callbacks++, onCancel: () => callbacks++);
      _checkPipeline(
        async,
        true,
        true,
        'reduce',
        error,
        (error) => error,
        (error) => error,
        error,
        error,
      );
      expect(callbacks, 0);
    });
  });

  for (final asyncAction in [false, true]) {
    test('no global observer preserves the local result / async=$asyncAction', () {
      fakeAsync((async) {
        final original = StateError('original');
        const replacement = UserException('local');
        final action = errorProbe(asyncAction, asyncAction)
          ..onReduce = () {
            throw original;
          }
          ..onWrapError = (_, _) => replacement;
        final store = Store<int>(initialState: 0);
        final result = dispatchCapturing(store, action, async);
        expect(result.error, isNull);
        expect(result.status, same(action.status));
        expect(action.status.originalError, same(original));
        expect(action.status.wrappedError, same(replacement));
        expect(store.errors.single, same(replacement));
        store.teardown();
        async.flushMicrotasks();
      });
    });
  }
}

void _checkPipeline(
  FakeAsync async,
  bool asyncBefore,
  bool asyncReduce,
  String site,
  Object original,
  Object? Function(Object) local,
  Object? Function(Object) global,
  Object? expectedLocal,
  Object? expectedFinal,
) {
  final trace = StackTrace.fromString('original lifecycle stack');
  final seen = <ObservedError>[];
  final stateErrors = <(int, int, Object?, ActionStatus)>[];
  final action = errorProbe(asyncBefore, asyncReduce)..key = 'failing key';
  final store = Store<int>(
    initialState: 0,
    syncStream: true,
    stateObservers: [_ErrorsObserver(stateErrors)],
    globalErrorObserver: (_) => ProbeGlobalObserver(seen, global),
  );
  final notifications = <int>[];
  final subscription = store.onChange.listen(notifications.add);
  void fail() => Error.throwWithStackTrace(original, trace);
  if (site == 'before') {
    action.onBefore = fail;
  } else {
    action.onReduce = () {
      fail();
      return null;
    };
  }
  action.onWrapError = (error, stack) => local(error);
  final result = dispatchCapturing(store, action, async, notify: false);
  expect(result.error, same(isActionErrorRethrown(expectedFinal) ? expectedFinal : null));
  if (result.error != null) {
    expect(result.stack.toString(), trace.toString());
    expect(result.threwSynchronously, !asyncBefore && !asyncReduce);
  } else {
    expect(result.status, same(action.status));
  }
  expect(action.localInputs, hasLength(1));
  expect(action.localInputs.single.$1, same(original));
  expect(action.localInputs.single.$2.toString(), trace.toString());
  expect(seen, hasLength(expectedLocal == null ? 0 : 1));
  if (seen.isNotEmpty) {
    expect(seen.single.error, same(expectedLocal));
    expect(seen.single.original, same(original));
    expect(seen.single.action, same(action));
    expect(seen.single.store, same(store));
    expect(seen.single.stack.toString(), trace.toString());
  }
  expect(stateErrors, hasLength(1));
  expect(stateErrors.single.$1, 0);
  expect(stateErrors.single.$2, 0);
  expect(stateErrors.single.$3, same(original));
  // State observers run before originalError is written into ActionStatus.
  expect(stateErrors.single.$4.originalError, isNull);
  expect(action.status.originalError, same(original));
  expect(action.status.wrappedError, same(expectedFinal));
  expect(action.status.isCompletedFailed, isTrue);
  expect(action.status.hasFinishedMethodBefore, site == 'reduce');
  expect(action.status.hasFinishedMethodReduce, isFalse);
  expect(action.status.isDispatchAborted, expectedFinal is AbortDispatchException);
  expect(action.afterStates, [0]);
  expect(action.afterStatuses.single.originalError, same(original));
  expect(action.afterStatuses.single.wrappedError, same(expectedFinal));
  expect(action.afterStatuses.single.isDispatchAborted, isFalse);
  expect(action.afterQueueLengths, [0]);
  expect(
    store.isFailed(action.runtimeType, statusKey: 'failing key'),
    isRecordedFailure(expectedFinal),
  );
  expect(store.isFailed(action.runtimeType, statusKey: 'other key'), isFalse);
  expect(
    store.exceptionFor(action.runtimeType, statusKey: 'failing key'),
    expectedFinal is UserException ? same(expectedFinal) : isNull,
  );
  expect(store.errors, opensDialog(expectedFinal) ? [same(expectedFinal)] : isEmpty);
  expect(notifications, opensDialog(expectedFinal) ? [0] : isEmpty);
  expect(store.state, 0);
  expect(store.actionsInProgress(), isEmpty);
  expect(store.dispatchCount, 1);
  expect(store.reduceCount, site == 'reduce' ? 1 : 0);
  subscription.cancel();
  store.teardown();
  async.flushMicrotasks();
}

class _ErrorsObserver extends StateObserver<int> {
  _ErrorsObserver(this.seen);

  final List<(int, int, Object?, ActionStatus)> seen;

  @override
  void observe(
    ReduxAction<int> action,
    int prevState,
    int newState,
    Object? error,
    int dispatchCount,
  ) {
    seen.add((prevState, newState, error, action.status));
  }
}
