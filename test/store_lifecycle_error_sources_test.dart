import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/error_contract_support.dart';

void main() {
  for (final kind in <ErrorKind?>[null, ...ErrorKind.values]) {
    for (final asyncAction in [false, true]) {
      test('after returning $kind is ignored / async=$asyncAction', () {
        fakeAsync((async) {
          final dynamic value = kind == null
              ? null
              : kind == ErrorKind.future
              ? Completer<void>().future
              : errorValue(kind, 'after return');
          final action = asyncAction ? _AsyncReturningAfter() : _SyncReturningAfter();
          action.returnedValue = value;
          final store = Store<int>(initialState: 0);
          final result = dispatchCapturing(store, action, async);
          expect(result.error, isNull);
          expect(result.status!.isCompletedOk, isTrue);
          expect(action.status.originalError, isNull);
          expect(action.localInputs, isEmpty);
          expect(action.afterStates, [1]);
          expect(store.state, 1);
          expect(store.errors, isEmpty);
          expect(store.actionsInProgress(), isEmpty);
          store.teardown();
          async.flushMicrotasks();
        });
      });
    }
  }

  for (final kind in ErrorKind.values) {
    for (final beforeAsync in [false, true]) {
      for (final reduceAsync in [false, true]) {
        for (final site in _Site.values) {
          for (final recovery in [
            ErrorConversion.keep,
            ErrorConversion.swallow,
            ErrorConversion.user,
          ]) {
            test('$site throws $kind / beforeAsync=$beforeAsync / '
                'reduceAsync=$reduceAsync / $recovery', () {
              fakeAsync((async) {
                final error = errorValue(kind, 'lifecycle');
                final trace = StackTrace.fromString('lifecycle source stack');
                Never fail() => Error.throwWithStackTrace(error, trace);
                final rule = ErrorRule(recovery, false, 'wrapped');
                final action = _createAction(beforeAsync, reduceAsync, site);
                if (site == _Site.abort) action.onAbort = fail;
                if (site == _Site.after) action.onAfter = fail;
                if (action is _WrappingFailure) {
                  action.fail = fail;
                  action.failAfterReduce = site == _Site.wrapAfter;
                }
                action.onWrapError = (error, _) => rule.apply(error);
                final global = <ObservedError>[];
                final uncaught = <(Object, StackTrace)>[];
                late Store<int> store;
                late DispatchResult result;
                runZonedGuarded(() {
                  store = Store<int>(
                    initialState: 0,
                    wrapReduce:
                        site == _Site.globalFactory ||
                            site == _Site.globalPredicate ||
                            site == _Site.globalProcess
                        ? _GlobalFailure(site, fail)
                        : null,
                    globalErrorObserver: (_) =>
                        ProbeGlobalObserver(global, (error) => error),
                  );
                  result = dispatchCapturing(store, action, async);
                  async.elapse(Duration.zero);
                }, (error, stack) => uncaught.add((error, stack)));

                final standardPipeline = site != _Site.abort && site != _Site.after;
                final expected = rule.expected(error);
                if (site == _Site.after) {
                  expect(result.error, isNull);
                  expect(uncaught, hasLength(1));
                  expect(uncaught.single.$1, isA<String>());
                  expect(uncaught.single.$1.toString(), contains(error.toString()));
                  expect(uncaught.single.$2.toString(), trace.toString());
                  expect(action.status.isCompletedOk, isTrue);
                } else {
                  expect(uncaught, isEmpty);
                  expect(
                    result.error,
                    same(
                      site == _Site.abort
                          ? error
                          : isActionErrorRethrown(expected)
                          ? expected
                          : null,
                    ),
                  );
                  if (result.error != null)
                    expect(result.stack.toString(), trace.toString());
                }
                expect(action.status.isDispatched, site != _Site.abort);
                expect(action.status.hasFinishedMethodBefore, site != _Site.abort);
                expect(action.status.hasFinishedMethodReduce, site == _Site.after);
                expect(action.status.isCompleted, site != _Site.abort);
                expect(
                  action.status.originalError,
                  standardPipeline ? same(error) : isNull,
                );
                expect(
                  action.status.wrappedError,
                  standardPipeline ? same(expected) : isNull,
                );
                expect(
                  action.status.isDispatchAborted,
                  standardPipeline && expected is AbortDispatchException,
                );
                expect(action.localInputs, hasLength(standardPipeline ? 1 : 0));
                expect(global, hasLength(standardPipeline && expected != null ? 1 : 0));
                expect(action.afterStatuses, hasLength(site == _Site.abort ? 0 : 1));
                expect(
                  store.isFailed(action.runtimeType),
                  standardPipeline && isRecordedFailure(expected),
                );
                expect(
                  store.errors,
                  standardPipeline && opensDialog(expected) ? [same(expected)] : isEmpty,
                );
                expect(store.state, site == _Site.after ? 1 : 0);
                expect(store.actionsInProgress(), isEmpty);
                expect(store.dispatchCount, site == _Site.abort ? 0 : 1);
                expect(
                  action.events.where((event) => event == 'reduce'),
                  hasLength(
                    site == _Site.after ||
                            site == _Site.wrapAfter ||
                            site == _Site.globalProcess
                        ? 1
                        : 0,
                  ),
                );
                store.teardown();
                async.flushMicrotasks();
              });
            });
          }
        }
      }
    }
  }

  for (final afterKind in ErrorKind.values) {
    for (final originalKind in [ErrorKind.error, ErrorKind.user, ErrorKind.abort]) {
      for (final asyncAction in [false, true]) {
        for (final site in ['before', 'reduce']) {
          test('after throws $afterKind without replacing $originalKind from '
              '$site / async=$asyncAction', () {
            fakeAsync((async) {
              final original = errorValue(originalKind, 'primary');
              final after = errorValue(afterKind, 'secondary');
              final uncaught = <Object>[];
              final action = errorProbe(asyncAction, asyncAction)
                ..onAfter = () => throw after;
              if (site == 'before') action.onBefore = () => throw original;
              if (site == 'reduce') action.onReduce = () => throw original;
              final store = Store<int>(initialState: 0);
              late DispatchResult result;
              runZonedGuarded(() {
                result = dispatchCapturing(store, action, async);
                async.elapse(Duration.zero);
              }, (error, stack) => uncaught.add(error));
              expect(
                result.error,
                same(isActionErrorRethrown(original) ? original : null),
              );
              expect(action.status.originalError, same(original));
              expect(action.status.wrappedError, same(original));
              expect(action.status.isCompletedFailed, isTrue);
              expect(action.status.isDispatchAborted, original is AbortDispatchException);
              expect(action.afterStatuses, hasLength(1));
              expect(action.localInputs, hasLength(1));
              expect(uncaught, hasLength(1));
              expect(uncaught.single.toString(), contains(after.toString()));
              expect(store.errors, opensDialog(original) ? [same(original)] : isEmpty);
              expect(store.actionsInProgress(), isEmpty);
              store.teardown();
              async.flushMicrotasks();
            });
          });
        }
      }
    }
  }

  for (final invalid in ['null', 'text', 'object', 'future']) {
    for (final site in _InvalidSite.values) {
      // These two combinations satisfy the declared type; their successful
      // behavior is exercised by the return-value and dispatch timing matrices.
      if (site == _InvalidSite.reduce && invalid == 'null') continue;
      if (site == _InvalidSite.wrap && invalid == 'future') continue;
      test('dynamic $invalid violates the declared type of $site', () {
        fakeAsync((async) {
          final dynamic value = switch (invalid) {
            'null' => null,
            'text' => 'not the declared type',
            'future' => Future<int?>.value(1),
            _ => Object(),
          };
          final action = switch (site) {
            _InvalidSite.abort => _InvalidAbort(value),
            _InvalidSite.reduce => _InvalidReduce(value),
            _InvalidSite.wrap => _InvalidWrap(value),
            _ => SyncErrorProbe(),
          };
          final store = Store<int>(
            initialState: 0,
            wrapReduce:
                site == _InvalidSite.globalFactory ||
                    site == _InvalidSite.globalPredicate ||
                    site == _InvalidSite.globalProcess
                ? _InvalidGlobal(site, value)
                : null,
          );
          final result = dispatchCapturing(store, action, async);
          expect(result.error, isA<TypeError>());
          final inPipeline = site != _InvalidSite.abort;
          expect(action.status.originalError, inPipeline ? same(result.error) : isNull);
          expect(action.status.wrappedError, inPipeline ? same(result.error) : isNull);
          expect(action.localInputs, hasLength(inPipeline ? 1 : 0));
          expect(action.afterStatuses, hasLength(inPipeline ? 1 : 0));
          expect(store.isFailed(action.runtimeType), inPipeline);
          expect(store.errors, isEmpty);
          expect(store.state, 0);
          expect(store.actionsInProgress(), isEmpty);
          store.teardown();
          async.flushMicrotasks();
        });
      });
    }
  }

  for (final asyncReduce in [false, true]) {
    for (final returned in ['null', 'integer', 'user', 'future']) {
      test('dynamic before returns $returned with async reduce=$asyncReduce', () {
        fakeAsync((async) {
          final dynamic value = switch (returned) {
            'null' => null,
            'integer' => 42,
            'user' => const UserException('returned, not thrown'),
            _ => Future<void>.value(),
          };
          final action = asyncReduce
              ? _DynamicBeforeAsync(value)
              : _DynamicBeforeSync(value);
          final store = Store<int>(initialState: 0);
          final result = dispatchCapturing(store, action, async);
          final invalidFuture = returned == 'future' && !asyncReduce;
          expect(result.error, invalidFuture ? isA<StoreException>() : isNull);
          expect(action.status.isCompletedOk, !invalidFuture);
          expect(action.status.hasFinishedMethodBefore, !invalidFuture);
          expect(action.status.hasFinishedMethodReduce, !invalidFuture);
          expect(store.state, invalidFuture ? 0 : 1);
          expect(store.errors, isEmpty);
          expect(store.actionsInProgress(), isEmpty);
          store.teardown();
          async.flushMicrotasks();
        });
      });
    }
  }
}

enum _Site {
  abort,
  after,
  wrapBefore,
  wrapAfter,
  globalFactory,
  globalPredicate,
  globalProcess,
}

mixin _ReturningAfter on ErrorProbeAction {
  dynamic returnedValue;
  @override
  dynamic after() {
    super.after();
    return returnedValue;
  }
}

class _SyncReturningAfter = SyncErrorProbe with _ReturningAfter;
class _AsyncReturningAfter = AsyncErrorProbe with _ReturningAfter;

mixin _WrappingFailure on ErrorProbeAction {
  late Never Function() fail;
  bool failAfterReduce = false;
  @override
  Future<int?> wrapReduce(Reducer<int> reduce) async {
    await microtask;
    if (failAfterReduce) await reduce();
    fail();
  }
}

class _WrappedSync = SyncErrorProbe with _WrappingFailure;
class _WrappedAsync = AsyncErrorProbe with _WrappingFailure;
class _WrappedBeforeSync = AsyncBeforeSyncErrorProbe with _WrappingFailure;
class _WrappedBeforeAsync = AsyncBeforeAsyncErrorProbe with _WrappingFailure;

ErrorProbeAction _createAction(bool asyncBefore, bool asyncReduce, _Site site) {
  if (site != _Site.wrapBefore && site != _Site.wrapAfter) {
    return errorProbe(asyncBefore, asyncReduce);
  }
  return asyncBefore
      ? (asyncReduce ? _WrappedBeforeAsync() : _WrappedBeforeSync())
      : (asyncReduce ? _WrappedAsync() : _WrappedSync());
}

class _GlobalFailure extends WrapReduce<int> {
  _GlobalFailure(this.site, this.fail);
  final _Site site;
  final Never Function() fail;
  @override
  Reducer<int> wrapReduce(Reducer<int> reduce, Store<int> store) {
    if (site == _Site.globalFactory) fail();
    return super.wrapReduce(reduce, store);
  }

  @override
  bool ifShouldProcess() {
    if (site == _Site.globalPredicate) fail();
    return true;
  }

  @override
  int process({required int oldState, required int newState}) => fail();
}

enum _InvalidSite { abort, reduce, wrap, globalFactory, globalPredicate, globalProcess }

class _InvalidAbort extends SyncErrorProbe {
  _InvalidAbort(this.value);
  final dynamic value;
  @override
  bool abortDispatch() => value;
}

class _InvalidReduce extends SyncErrorProbe {
  _InvalidReduce(this.value);
  final dynamic value;
  @override
  int? reduce() => value;
}

class _InvalidWrap extends SyncErrorProbe {
  _InvalidWrap(this.value);
  final dynamic value;
  @override
  Future<int?> wrapReduce(Reducer<int> reduce) => value;
}

class _InvalidGlobal extends WrapReduce<int> {
  _InvalidGlobal(this.site, this.value);
  final _InvalidSite site;
  final dynamic value;
  @override
  Reducer<int> wrapReduce(Reducer<int> reduce, Store<int> store) =>
      site == _InvalidSite.globalFactory ? value : super.wrapReduce(reduce, store);
  @override
  bool ifShouldProcess() => site == _InvalidSite.globalPredicate ? value : true;
  @override
  int process({required int oldState, required int newState}) => value;
}

class _DynamicBeforeSync extends SyncErrorProbe {
  _DynamicBeforeSync(this.value);
  final dynamic value;
  @override
  // Intentionally violate the signature to exercise runtime validation.
  // ignore: async_redux_lints/before_return_type
  dynamic before() => value;
}

class _DynamicBeforeAsync extends AsyncErrorProbe {
  _DynamicBeforeAsync(this.value);
  final dynamic value;
  @override
  // Intentionally violate the signature to exercise runtime validation.
  // ignore: async_redux_lints/before_return_type
  dynamic before() => value;
}
