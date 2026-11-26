import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

// Intentionally inspect all completion statuses, not just successful ones.
// ignore_for_file: async_redux_lints/then_on_dispatch_and_wait

void main() {
  group('before x reduce x returned state x both wrappers x notify', () {
    for (final before in _Before.values) {
      for (final asyncReduce in [false, true]) {
        for (final returned in _Returned.values) {
          for (final wrapper in _ActionWrap.values) {
            for (final global in _GlobalWrap.values) {
              for (final notify in [false, true]) {
                test('$before / asyncReduce=$asyncReduce / $returned / '
                    '$wrapper / $global / notify=$notify', () {
                  fakeAsync((async) {
                    final c = _Case(before, asyncReduce, returned, wrapper, global);
                    _exerciseSuccess(c, async, notify: notify);
                  });
                });
              }
            }
          }
        }
      }
    }
  });

  group('synchronous state changes before dispatch returns', () {
    for (final api in _Dispatch.values) {
      for (final before in [_Before.syncVoid, _Before.syncNull]) {
        for (final returned in _Returned.values) {
          for (final global in _GlobalWrap.values) {
            for (final notify in [false, true]) {
              test('$api / $before / $returned / $global / notify=$notify', () {
                fakeAsync((async) {
                  final c = _Case(before, false, returned, _ActionWrap.none, global);
                  _exerciseSuccess(c, async, notify: notify, api: api);
                });
              });
            }
          }
        }
      }
    }
  });

  group('abortDispatch precedes every before/reduce/wrapper combination', () {
    for (final before in _Before.values) {
      for (final asyncReduce in [false, true]) {
        for (final wrapper in _ActionWrap.values) {
          test('$before / asyncReduce=$asyncReduce / $wrapper', () {
            fakeAsync((async) {
              final c = _Case(
                before,
                asyncReduce,
                _Returned.changed,
                wrapper,
                _GlobalWrap.changed,
              )..abort = true;
              final store = c.createStore();
              final action = _createAction(c);
              final result = store.dispatch(action);
              // Even an otherwise async action is aborted synchronously.
              expect(result, isA<ActionStatus>());
              expect((result as ActionStatus).isDispatchAborted, isTrue);
              expect(result.isDispatched, isFalse);
              expect(c.events, ['abort']);
              expect(store.state, same(c.initial));
              expect(store.dispatchCount, 0);
              expect(store.reduceCount, 0);
              expect(store.actionsInProgress(), isEmpty);
              c.beforeGate.complete();
              c.reduceGate.complete();
              async.flushMicrotasks();
              expect(c.events, ['abort']);
              store.teardown();
              async.flushMicrotasks();
            });
          });
        }
      }
    }
  });

  group('before x reduce x failure site x wrapError x global error result', () {
    for (final before in _Before.values) {
      for (final asyncReduce in [false, true]) {
        for (final site in ['before', 'reduce']) {
          for (final local in _ErrorResult.values) {
            for (final global in _ErrorResult.values) {
              test('$before / asyncReduce=$asyncReduce / $site / '
                  'local=$local / global=$global', () {
                fakeAsync((async) {
                  final c =
                      _Case(
                          before,
                          asyncReduce,
                          _Returned.changed,
                          _ActionWrap.none,
                          _GlobalWrap.none,
                        )
                        ..failureSite = site
                        ..localErrorResult = local
                        ..globalErrorResult = global;
                  _exerciseFailure(c, async);
                });
              });
            }
          }
        }
      }
    }
  });

  group('after failure does not replace any successful reducer result', () {
    for (final before in _Before.values) {
      for (final asyncReduce in [false, true]) {
        for (final returned in _Returned.values) {
          test('$before / asyncReduce=$asyncReduce / $returned', () {
            fakeAsync((async) {
              final c = _Case(
                before,
                asyncReduce,
                returned,
                _ActionWrap.none,
                _GlobalWrap.none,
              )..afterThrows = true;
              final uncaught = <Object>[];
              runZonedGuarded(() {
                _exerciseSuccess(c, async);
              }, (error, stack) => uncaught.add(error));
              async.elapse(Duration.zero);
              expect(uncaught, hasLength(1));
              expect(uncaught.single.toString(), contains('after failure'));
              expect(c.localErrors, isEmpty);
              expect(c.globalErrors, isEmpty);
            });
          });
        }
      }
    }
  });
}

void _exerciseSuccess(
  _Case c,
  FakeAsync async, {
  bool notify = true,
  _Dispatch api = _Dispatch.dispatch,
}) {
  final store = c.createStore();
  final action = _createAction(c);
  final emissions = <_State>[];
  final subscription = store.onChange.listen(emissions.add);
  final synchronous =
      !c.before.isAsync && !c.asyncReduce && c.wrapper == _ActionWrap.none;
  final expected = c.expectedState;
  _State? seenByPreviouslyQueuedMicrotask;
  scheduleMicrotask(() => seenByPreviouslyQueuedMicrotask = store.state);
  final FutureOr<ActionStatus> result = switch (api) {
    _Dispatch.dispatch => store.dispatch(action, notify: notify),
    _Dispatch.dispatchSync => store.dispatchSync(action, notify: notify),
    _Dispatch.dispatchAndWait => store.dispatchAndWait(action, notify: notify),
  };

  expect(action.isSync(), synchronous);
  expect(
    result is Future<ActionStatus>,
    !synchronous || api == _Dispatch.dispatchAndWait,
  );
  if (synchronous) {
    // NO await or microtask flush before these assertions. Checking only the
    // returned ActionStatus would miss a state update accidentally deferred.
    expect(store.state, same(expected));
    expect(action.status.isCompletedOk, isTrue);
    expect(action.status.hasFinishedMethodBefore, isTrue);
    expect(action.status.hasFinishedMethodReduce, isTrue);
    expect(action.status.hasFinishedMethodAfter, isTrue);
    expect(c.afterStates, [same(expected)]);
    expect(store.actionsInProgress(), isEmpty);
    expect(c.events.last, 'end');
  } else {
    expect(store.state, same(c.initial));
    expect(action.status.isCompleted, isFalse);
    expect(store.actionsInProgress(), contains(action));
    if (c.before.isAsync) {
      expect(action.status.hasFinishedMethodBefore, isFalse);
      expect(c.reduceCalls, 0);
      expect(c.wrapperInputs, isEmpty);
    }
  }

  ActionStatus? returnedStatus;
  Future<ActionStatus>.value(result).then((status) => returnedStatus = status);
  async.flushMicrotasks();
  expect(seenByPreviouslyQueuedMicrotask, same(synchronous ? expected : c.initial));
  if (c.before == _Before.pendingFuture) {
    expect(action.status.hasFinishedMethodBefore, isFalse);
    expect(c.reduceCalls, 0);
    expect(c.events, ['abort', 'start', 'before:start']);
    expect(returnedStatus, isNull);
    c.beforeGate.complete();
    async.flushMicrotasks();
  }
  if (c.asyncReduce && !c.wrapper.skipsReducer) {
    expect(action.status.hasFinishedMethodBefore, isTrue);
    expect(action.status.hasFinishedMethodReduce, isFalse);
    expect(store.state, same(c.initial));
    expect(c.afterStates, isEmpty);
    expect(returnedStatus, isNull);
    c.reduceGate.complete();
    async.flushMicrotasks();
  }

  expect(store.state, same(expected));
  expect(returnedStatus, same(action.status));
  expect(action.status.isCompletedOk, isTrue);
  expect(action.status.originalError, isNull);
  expect(action.status.wrappedError, isNull);
  expect(action.status.isDispatchAborted, isFalse);
  expect(c.afterStates, [same(expected)]);
  expect(store.actionsInProgress(), isEmpty);
  expect(store.dispatchCount, 1);
  // Entering the reducer pipeline counts even if wrapReduce skips reduce().
  expect(store.reduceCount, 1);
  expect(c.reduceCalls, c.wrapper.skipsReducer ? 0 : 1);
  expect(c.globalInputs, c.globalProcesses ? [same(c.reduceOutput)] : isEmpty);
  expect(
    c.wrapperInputs,
    c.wrapper == _ActionWrap.none || c.wrapper.skipsReducer
        ? isEmpty
        : [same(c.globalOutput)],
  );
  expect(c.stateObservations, hasLength(1));
  expect(c.stateObservations.single.$1, same(c.initial));
  expect(c.stateObservations.single.$2, same(expected));
  expect(c.stateObservations.single.$3, isNull);
  expect(emissions, notify ? [same(expected)] : isEmpty);
  expect(c.localErrors, isEmpty);
  expect(c.globalErrors, isEmpty);
  expect(store.errors, isEmpty);
  expect(c.events, [
    'abort',
    'start',
    'before:start',
    'before:end',
    if (c.wrapper != _ActionWrap.none) 'wrapper:start',
    if (!c.wrapper.skipsReducer) ...[
      'reduce:start',
      'reduce:end',
      if (c.globalProcesses) 'global:process',
    ],
    if (c.wrapper != _ActionWrap.none) 'wrapper:end',
    'state',
    'after',
    'end',
  ]);

  subscription.cancel();
  store.teardown();
  async.flushMicrotasks();
}

void _exerciseFailure(_Case c, FakeAsync async) {
  final store = c.createStore();
  final action = _createAction(c);
  Object? thrown;
  StackTrace? thrownStack;
  ActionStatus? result;
  void recordError(Object error, StackTrace stack) {
    thrown = error;
    thrownStack = stack;
  }

  try {
    final dispatched = store.dispatch(action);
    if (dispatched is Future<ActionStatus>) {
      dispatched.then<void>((value) {
        result = value;
      }, onError: recordError);
    } else {
      result = dispatched;
    }
  } catch (error, stack) {
    recordError(error, stack);
  }
  c.beforeGate.complete();
  c.reduceGate.complete();
  async.flushMicrotasks();

  final local = c.errorResult(c.localErrorResult, c.originalError, local: true);
  final finalError = local == null
      ? null
      : c.errorResult(c.globalErrorResult, local, local: false);
  final propagates =
      finalError != null &&
      finalError is! UserException &&
      finalError is! AbortDispatchException;
  expect(thrown, same(propagates ? finalError : null));
  if (propagates) {
    expect(thrownStack.toString(), c.errorStack.toString());
  } else {
    expect(result, same(action.status));
  }
  expect(c.localErrors, [same(c.originalError)]);
  expect(c.globalErrors, local == null ? isEmpty : [same(local)]);
  expect(action.status.originalError, same(c.originalError));
  expect(action.status.wrappedError, same(finalError));
  expect(action.status.hasFinishedMethodBefore, c.failureSite == 'reduce');
  expect(action.status.hasFinishedMethodReduce, isFalse);
  expect(action.status.isCompletedFailed, isTrue);
  expect(action.status.isDispatchAborted, finalError is AbortDispatchException);
  expect(store.state, same(c.initial));
  expect(c.afterStates, [same(c.initial)]);
  expect(store.actionsInProgress(), isEmpty);
  expect(store.reduceCount, c.failureSite == 'reduce' ? 1 : 0);
  expect(
    store.isFailed(action.runtimeType),
    finalError != null && finalError is! AbortDispatchException,
  );
  expect(
    store.errors,
    finalError is UserException && finalError.ifOpenDialog ? [same(finalError)] : isEmpty,
  );
  expect(c.events, [
    'abort',
    'start',
    'before:start',
    if (c.failureSite == 'reduce') ...['before:end', 'reduce:start'],
    'state',
    'wrapError',
    if (local != null) 'globalError',
    'after',
    'end',
  ]);
  expect(c.stateObservations, hasLength(1));
  expect(c.stateObservations.single.$1, same(c.initial));
  expect(c.stateObservations.single.$2, same(c.initial));
  expect(c.stateObservations.single.$3, same(c.originalError));
  store.teardown();
  async.flushMicrotasks();
}

enum _Before {
  syncVoid,
  syncNull,
  completedFuture,
  pendingFuture;

  bool get isAsync => this == completedFuture || this == pendingFuture;
}

enum _Returned { nullState, identical, equal, changed }

enum _ActionWrap {
  none,
  pass,
  nullState,
  initial,
  changed,
  skipNull,
  skipChanged;

  bool get skipsReducer => this == skipNull || this == skipChanged;
}

enum _GlobalWrap { none, disabled, pass, initial, changed }

enum _Dispatch { dispatch, dispatchSync, dispatchAndWait }

enum _ErrorResult { pass, swallow, ordinary, user, noDialog, abort, throwing }

class _State {
  _State(this.value);

  final int value;

  @override
  bool operator ==(Object other) => other is _State && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class _Case {
  _Case(this.before, this.asyncReduce, this.returned, this.wrapper, this.global);

  final _Before before;
  final bool asyncReduce;
  final _Returned returned;
  final _ActionWrap wrapper;
  final _GlobalWrap global;
  final initial = _State(0);
  final equal = _State(0);
  final changed = _State(1);
  final globalChanged = _State(10);
  final actionChanged = _State(100);
  final beforeGate = Completer<void>();
  final reduceGate = Completer<void>();
  final events = <String>[];
  final afterStates = <_State>[];
  final wrapperInputs = <_State?>[];
  final globalInputs = <_State>[];
  final stateObservations = <(_State, _State, Object?)>[];
  final localErrors = <Object>[];
  final globalErrors = <Object>[];
  final originalError = StateError('original');
  final localReplacement = ArgumentError('local');
  final globalReplacement = ArgumentError('global');
  final userError = const UserException('dialog');
  final noDialogError = const UserException('no dialog').noDialog;
  final abortError = AbortDispatchException();
  final errorStack = StackTrace.fromString('lifecycle matrix original stack');
  _ErrorResult localErrorResult = _ErrorResult.pass;
  _ErrorResult globalErrorResult = _ErrorResult.pass;
  String? failureSite;
  bool afterThrows = false;
  bool abort = false;
  int reduceCalls = 0;

  _State? get reduceOutput => switch (returned) {
    _Returned.nullState => null,
    _Returned.identical => initial,
    _Returned.equal => equal,
    _Returned.changed => changed,
  };

  bool get globalProcesses =>
      !wrapper.skipsReducer &&
      global != _GlobalWrap.none &&
      global != _GlobalWrap.disabled &&
      (returned == _Returned.equal || returned == _Returned.changed);

  _State? get globalOutput => !globalProcesses
      ? reduceOutput
      : switch (global) {
          _GlobalWrap.initial => initial,
          _GlobalWrap.changed => globalChanged,
          _ => reduceOutput,
        };

  _State get expectedState => switch (wrapper) {
    _ActionWrap.none || _ActionWrap.pass => globalOutput ?? initial,
    _ActionWrap.nullState || _ActionWrap.skipNull || _ActionWrap.initial => initial,
    _ActionWrap.changed || _ActionWrap.skipChanged => actionChanged,
  };

  Store<_State> createStore() => Store<_State>(
    initialState: initial,
    syncStream: true,
    wrapReduce: global == _GlobalWrap.none ? null : _GlobalWrapper(this),
    stateObservers: [_StateObserver(this)],
    actionObservers: [_ActionObserver(this)],
    globalErrorObserver: (_) => _ErrorObserver(this),
  );

  void beforeStart() => events.add('before:start');

  void beforeEnd() {
    if (failureSite == 'before') Error.throwWithStackTrace(originalError, errorStack);
    events.add('before:end');
  }

  void reduceStart() {
    events.add('reduce:start');
    reduceCalls++;
  }

  _State? reduceEnd() {
    if (failureSite == 'reduce') Error.throwWithStackTrace(originalError, errorStack);
    events.add('reduce:end');
    return reduceOutput;
  }

  Object? errorResult(_ErrorResult choice, Object input, {required bool local}) =>
      switch (choice) {
        _ErrorResult.pass => input,
        _ErrorResult.swallow => null,
        _ErrorResult.ordinary ||
        _ErrorResult.throwing => local ? localReplacement : globalReplacement,
        _ErrorResult.user => userError,
        _ErrorResult.noDialog => noDialogError,
        _ErrorResult.abort => abortError,
      };
}

abstract class _MatrixAction extends ReduxAction<_State> {
  _MatrixAction(this.c);

  final _Case c;

  @override
  bool abortDispatch() {
    c.events.add('abort');
    return c.abort;
  }

  @override
  void before() {
    c.beforeStart();
    c.beforeEnd();
  }

  @override
  void after() {
    c.events.add('after');
    c.afterStates.add(state);
    // Intentionally verify the store's handling of an invalid after hook.
    // ignore: async_redux_lints/after_throws
    if (c.afterThrows) throw StateError('after failure');
  }

  @override
  Object? wrapError(Object error, StackTrace stackTrace) {
    c.events.add('wrapError');
    c.localErrors.add(error);
    final result = c.errorResult(c.localErrorResult, error, local: true);
    if (c.localErrorResult == _ErrorResult.throwing) throw result!;
    return result;
  }
}

mixin _NullBefore on _MatrixAction {
  @override
  Null before() {
    c.beforeStart();
    c.beforeEnd();
    return null;
  }
}

mixin _FutureBefore on _MatrixAction {
  @override
  Future<void> before() {
    c.beforeStart();
    if (c.before == _Before.completedFuture) {
      // A completed before future is allowed. Its continuation still must be
      // awaited before reduce, even if reduce itself is synchronous.
      return Future<void>.sync(c.beforeEnd);
    }
    return c.beforeGate.future.then((_) => c.beforeEnd());
  }
}

mixin _SyncReduce on _MatrixAction {
  @override
  _State? reduce() {
    c.reduceStart();
    return c.reduceEnd();
  }
}

mixin _AsyncReduce on _MatrixAction {
  @override
  Future<_State?> reduce() async {
    c.reduceStart();
    await c.reduceGate.future;
    return c.reduceEnd();
  }
}

mixin _Wrapped on _MatrixAction {
  @override
  Future<_State?> wrapReduce(Reducer<_State> reduce) async {
    c.events.add('wrapper:start');
    _State? input;
    if (c.wrapper.skipsReducer) {
      await microtask;
    } else {
      input = await reduce();
      c.wrapperInputs.add(input);
    }
    c.events.add('wrapper:end');
    return switch (c.wrapper) {
      _ActionWrap.pass => input,
      _ActionWrap.nullState || _ActionWrap.skipNull => null,
      _ActionWrap.initial => c.initial,
      _ActionWrap.changed || _ActionWrap.skipChanged => c.actionChanged,
      _ActionWrap.none => throw StateError('Use an action without the wrapper mixin'),
    };
  }
}

// Actual method signatures determine the store's sync/async dispatch path.
// Do not replace these with configurable FutureOr methods or override isSync().
class _Sync = _MatrixAction with _SyncReduce;
class _SyncNullBefore = _MatrixAction with _NullBefore, _SyncReduce;
class _SyncFutureBefore = _MatrixAction with _FutureBefore, _SyncReduce;
class _Async = _MatrixAction with _AsyncReduce;
class _AsyncNullBefore = _MatrixAction with _NullBefore, _AsyncReduce;
class _AsyncFutureBefore = _MatrixAction with _FutureBefore, _AsyncReduce;
class _WrappedSync = _MatrixAction with _SyncReduce, _Wrapped;
class _WrappedSyncNullBefore = _MatrixAction with _NullBefore, _SyncReduce, _Wrapped;
class _WrappedSyncFutureBefore = _MatrixAction with _FutureBefore, _SyncReduce, _Wrapped;
class _WrappedAsync = _MatrixAction with _AsyncReduce, _Wrapped;
class _WrappedAsyncNullBefore = _MatrixAction with _NullBefore, _AsyncReduce, _Wrapped;
class _WrappedAsyncFutureBefore = _MatrixAction
    with _FutureBefore, _AsyncReduce, _Wrapped;

_MatrixAction _createAction(_Case c) {
  final futureBefore = c.before.isAsync;
  final nullBefore = c.before == _Before.syncNull;
  if (c.wrapper != _ActionWrap.none) {
    if (c.asyncReduce) {
      return futureBefore
          ? _WrappedAsyncFutureBefore(c)
          : nullBefore
          ? _WrappedAsyncNullBefore(c)
          : _WrappedAsync(c);
    }
    return futureBefore
        ? _WrappedSyncFutureBefore(c)
        : nullBefore
        ? _WrappedSyncNullBefore(c)
        : _WrappedSync(c);
  }
  if (c.asyncReduce) {
    return futureBefore
        ? _AsyncFutureBefore(c)
        : nullBefore
        ? _AsyncNullBefore(c)
        : _Async(c);
  }
  return futureBefore
      ? _SyncFutureBefore(c)
      : nullBefore
      ? _SyncNullBefore(c)
      : _Sync(c);
}

class _GlobalWrapper extends WrapReduce<_State> {
  _GlobalWrapper(this.c);

  final _Case c;

  @override
  bool ifShouldProcess() => c.global != _GlobalWrap.disabled;

  @override
  _State process({required _State oldState, required _State newState}) {
    c.events.add('global:process');
    c.globalInputs.add(newState);
    return switch (c.global) {
      _GlobalWrap.initial => oldState,
      _GlobalWrap.changed => c.globalChanged,
      _ => newState,
    };
  }
}

class _StateObserver extends StateObserver<_State> {
  _StateObserver(this.c);

  final _Case c;

  @override
  void observe(
    ReduxAction<_State> action,
    _State prevState,
    _State newState,
    Object? error,
    int dispatchCount,
  ) {
    c.events.add('state');
    c.stateObservations.add((prevState, newState, error));
  }
}

class _ActionObserver extends ActionObserver<_State> {
  _ActionObserver(this.c);

  final _Case c;

  @override
  void observe(ReduxAction<_State> action, int dispatchCount, {required bool ini}) {
    c.events.add(ini ? 'start' : 'end');
  }
}

class _ErrorObserver extends GlobalErrorObserver<_State> {
  _ErrorObserver(this.c);

  final _Case c;

  @override
  Object? observe() {
    c.events.add('globalError');
    c.globalErrors.add(error);
    final result = c.errorResult(c.globalErrorResult, error, local: false);
    // Returning and throwing the replacement are distinct tested paths.
    // ignore: async_redux_lints/throw_in_global_error_observer
    if (c.globalErrorResult == _ErrorResult.throwing) throw result!;
    return result;
  }
}
