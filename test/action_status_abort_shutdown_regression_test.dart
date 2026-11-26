import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:flutter_test/flutter_test.dart';

// Assert the documented status contract, not the current defects. These tests
// remain active: this task only adds tests and does not change production code.
void main() {
  for (final shutdown in [false, true]) {
    for (final api in ['dispatch', 'dispatchSync', 'dispatchAndWait']) {
      test(
        '$api publishes the early aborted status on the action: shutdown=$shutdown',
        () async {
          final store = Store<int>(initialState: 0);
          addTearDown(store.teardown);
          final action = _SyncAction()..abort = !shutdown;
          final initial = action.status;
          if (shutdown) store.shutdown();
          final result = await switch (api) {
            'dispatch' => store.dispatch(action),
            'dispatchSync' => store.dispatchSync(action),
            _ => store.dispatchAndWait(action),
          };
          expect(result.isDispatchAborted, isTrue);
          expect(result.isDispatched, isFalse);
          expect(result.isCompleted, isFalse);
          expect(action.beforeRan, isFalse);
          expect(action.reduceRan, isFalse);
          expect(action.afterRan, isFalse);
          expect(initial.isDispatchAborted, isFalse);
          expect(initial.context, isNull);
          // Currently only the returned status records the abortion.
          expect(action.status.isDispatchAborted, isTrue);
          expect(action.status, result);
          expect(action.status.context!.$1, same(action));
          expect(action.status.context!.$2, same(store));
        },
      );
    }
  }

  for (final asynchronous in [false, true]) {
    for (final phase in ['before', 'reduce']) {
      for (final check in ['completed result', 'shutdown abortion']) {
        test('shutdown during $phase publishes $check: async=$asynchronous', () async {
          final store = Store<int>(initialState: 0);
          addTearDown(store.teardown);
          final action = asynchronous ? _AsyncAction() : _SyncAction();
          action.shutdownPhase = phase;
          ActionStatus? observerStatus;
          action.afterCallback = () => observerStatus = action.status;
          final future = store.dispatchAndWait(action);
          if (asynchronous) {
            // The action is paused within the selected lifecycle method.
            await action.entered.future;
            expect(action.beforeRan, isTrue);
            expect(action.reduceRan, phase == 'reduce');
            store.shutdown();
            action.gate.complete();
          }
          final result = await future;
          expect(action.afterRan, isTrue);
          expect(observerStatus!.hasFinishedMethodAfter, isFalse);
          expect(action.status.hasFinishedMethodAfter, isTrue);
          expect(action.status.originalError, isNull);
          expect(action.status.wrappedError, isNull);
          expect(store.isShutdown, isTrue);
          expect(store.actionsInProgress(), isEmpty);
          if (check == 'completed result') {
            // Currently return captures the immutable status before finally/after.
            expect(result.hasFinishedMethodAfter, isTrue);
            expect(result.isCompleted, isTrue);
            expect(result, action.status);
          } else {
            // ActionStatus documents shutdown as an abortion source.
            expect(action.status.isDispatchAborted, isTrue);
            expect(result.isDispatchAborted, isTrue);
          }
        });
      }
    }
  }
}

abstract class _Action extends ReduxAction<int> {
  final gate = Completer<void>();
  final entered = Completer<void>();
  bool abort = false;
  String? shutdownPhase;
  bool beforeRan = false;
  bool reduceRan = false;
  bool afterRan = false;
  void Function()? afterCallback;
  @override
  bool abortDispatch() => abort;
  @override
  void after() {
    afterCallback?.call();
    afterRan = true;
  }
}

class _SyncAction extends _Action {
  @override
  void before() {
    beforeRan = true;
    if (shutdownPhase == 'before') store.shutdown();
  }

  @override
  int reduce() {
    reduceRan = true;
    if (shutdownPhase == 'reduce') store.shutdown();
    return 1;
  }
}

class _AsyncAction extends _Action {
  @override
  Future<void> before() async {
    beforeRan = true;
    if (shutdownPhase == 'before') {
      entered.complete();
      await gate.future;
    }
  }

  @override
  Future<int> reduce() async {
    reduceRan = true;
    if (shutdownPhase == 'reduce') {
      entered.complete();
    }
    await gate.future;
    return 1;
  }
}
