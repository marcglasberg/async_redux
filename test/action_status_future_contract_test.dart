import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final onSuccess in [false, true]) {
    final method = onSuccess ? 'thenIfCompletedOk' : 'thenIfCompletedFailed';
    for (final kind in _Kind.values) {
      for (final asyncCallback in [false, true]) {
        test(
          '$method on $kind awaits callback=$asyncCallback and preserves identity',
          () {
            fakeAsync((clock) {
              final status = _status(kind);
              final source = Completer<ActionStatus>();
              final callbackGate = Completer<void>();
              final seen = <ActionStatus>[];
              ActionStatus? returned;
              void syncCallback(ActionStatus value) => seen.add(value);
              Future<void> delayedCallback(ActionStatus value) async {
                seen.add(value);
                await callbackGate.future;
              }

              final future = _chain(
                source.future,
                onSuccess,
                asyncCallback ? delayedCallback : syncCallback,
              );
              future.then((value) => returned = value);
              clock.flushMicrotasks();
              expect(seen, isEmpty);
              expect(returned, isNull);
              source.complete(status);
              clock.flushMicrotasks();
              final runs = onSuccess
                  ? kind == _Kind.success
                  : [_Kind.failed, _Kind.swallowed, _Kind.lateAbort].contains(kind);
              expect(seen, runs ? [same(status)] : isEmpty);
              if (runs && asyncCallback) {
                expect(returned, isNull);
                callbackGate.complete();
                clock.flushMicrotasks();
              }
              expect(returned, same(status));
              expect(seen, runs ? [same(status)] : isEmpty);
            });
          },
        );
      }
    }

    for (final asyncError in [false, true]) {
      test('$method propagates callback failure and stack: async=$asyncError', () async {
        final status = _status(onSuccess ? _Kind.success : _Kind.failed);
        final error = StateError('callback');
        final stack = StackTrace.fromString('callback original stack');
        Future<void> asyncCallback(ActionStatus value) async {
          await Future<void>.value();
          Error.throwWithStackTrace(error, stack);
        }

        void syncCallback(ActionStatus value) => Error.throwWithStackTrace(error, stack);
        final chained = _chain(
          Future.value(status),
          onSuccess,
          asyncError ? asyncCallback : syncCallback,
        );
        Object? caught;
        StackTrace? caughtStack;
        var nextCallbackRan = false;
        try {
          await chained
              .thenIfCompletedOk((_) => nextCallbackRan = true)
              .thenIfCompletedFailed((_) => nextCallbackRan = true);
        } catch (value, trace) {
          caught = value;
          caughtStack = trace;
        }
        expect(caught, same(error));
        expect(caughtStack.toString(), stack.toString());
        expect(nextCallbackRan, isFalse);
        expect(status.isCompleted, isTrue);
        expect(status.originalError, isNot(same(error)));
      });
    }

    test(
      '$method preserves a failed source Future without invoking its callback',
      () async {
        final error = StateError('source future');
        final stack = StackTrace.fromString('source original stack');
        var callbackRan = false;
        final source = Future<ActionStatus>.error(error, stack);
        Object? caught;
        StackTrace? caughtStack;
        try {
          await _chain(source, onSuccess, (_) => callbackRan = true);
        } catch (value, trace) {
          caught = value;
          caughtStack = trace;
        }
        expect(callbackRan, isFalse);
        expect(caught, same(error));
        expect(caughtStack.toString(), stack.toString());
      },
    );

    for (final asynchronous in [false, true]) {
      for (final failure in [false, true]) {
        test('$method receives final live action status: '
            'async=$asynchronous failure=$failure', () async {
          final store = Store<int>(initialState: 0);
          addTearDown(store.teardown);
          final action = asynchronous ? _AsyncAction() : _SyncAction();
          action.fail = failure;
          var calls = 0;
          final chained = _chain(store.dispatchAndWait(action), onSuccess, (status) {
            calls++;
            expect(action.afterRan, isTrue);
            expect(status, same(action.status));
            expect(status.hasFinishedMethodAfter, isTrue);
            expect(store.actionsInProgress(), isEmpty);
            expect(status.context!.$1, same(action));
            expect(status.context!.$2, same(store));
          });
          final status = await chained;
          expect(calls, onSuccess != failure ? 1 : 0);
          expect(status, same(action.status));
          expect(status.isCompletedOk, !failure);
          expect(status.isCompletedFailed, failure);
          expect(status.originalError, failure ? same(action.error) : isNull);
          // Swallowing the action error must not route it into the success callback.
          expect(status.wrappedError, isNull);
        });
      }
    }
  }

  for (final successFirst in [false, true]) {
    for (final failed in [false, true]) {
      test('mixed chains preserve status and await each matching callback: '
          'successFirst=$successFirst failed=$failed', () {
        fakeAsync((clock) {
          final status = _status(failed ? _Kind.swallowed : _Kind.success);
          final gate = Completer<void>();
          final events = <String>[];
          Future<void> callback(ActionStatus value) async {
            expect(value, same(status));
            events.add('start');
            await gate.future;
            events.add('end');
          }

          final first = _chain(Future.value(status), successFirst, callback);
          final second = _chain(first, !successFirst, callback);
          ActionStatus? returned;
          second.then((value) => returned = value);
          clock.flushMicrotasks();
          expect(events, ['start']);
          expect(returned, isNull);
          gate.complete();
          clock.flushMicrotasks();
          expect(events, ['start', 'end']);
          expect(returned, same(status));
        });
      });
    }
  }
}

Future<ActionStatus> _chain(
  Future<ActionStatus> future,
  bool onSuccess,
  FutureOr<void> Function(ActionStatus) callback,
) => onSuccess
    ? future.thenIfCompletedOk(callback)
    : future.thenIfCompletedFailed(callback);

enum _Kind { fresh, pendingError, success, failed, swallowed, earlyAbort, lateAbort }

ActionStatus _status(_Kind kind) => ActionStatus(
  isDispatched: kind != _Kind.fresh && kind != _Kind.earlyAbort,
  hasFinishedMethodBefore: kind != _Kind.fresh && kind != _Kind.earlyAbort,
  hasFinishedMethodReduce: kind == _Kind.success,
  hasFinishedMethodAfter: [
    _Kind.success,
    _Kind.failed,
    _Kind.swallowed,
    _Kind.lateAbort,
  ].contains(kind),
  isDispatchAborted: kind == _Kind.earlyAbort || kind == _Kind.lateAbort,
  originalError:
      [_Kind.pendingError, _Kind.failed, _Kind.swallowed, _Kind.lateAbort].contains(kind)
      ? 'original'
      : null,
  wrappedError: kind == _Kind.failed ? 'wrapped' : null,
  context: null,
);

abstract class _Action extends ReduxAction<int> {
  final error = StateError('swallowed failure');
  bool fail = false;
  bool afterRan = false;
  int runReducer() {
    if (fail) throw error;
    return 1;
  }

  @override
  Object? wrapError(Object error, StackTrace stackTrace) => null;
  @override
  void after() => afterRan = true;
}

class _SyncAction extends _Action {
  @override
  int reduce() => runReducer();
}

class _AsyncAction extends _Action {
  @override
  Future<int> reduce() async {
    await Future<void>.value();
    return runReducer();
  }
}
