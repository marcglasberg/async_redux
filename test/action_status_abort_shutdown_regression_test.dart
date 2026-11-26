import 'package:async_redux/async_redux.dart';
import 'package:flutter_test/flutter_test.dart';

// AbortDispatch status is checked while the store remains operational.
void main() {
  for (final api in ['dispatch', 'dispatchSync', 'dispatchAndWait']) {
    test(
      '$api publishes the early aborted status on the action',
      () async {
        final store = Store<int>(initialState: 0);
        addTearDown(store.teardown);
        final action = _SyncAction()..abort = true;
        final initial = action.status;
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
        expect(action.status.isDispatchAborted, isTrue);
        expect(action.status, same(result));
        expect(action.status.context!.$1, same(action));
        expect(action.status.context!.$2, same(store));
      },
    );
  }

  test('an accepted attempt clears the previous aborted status', () {
    final store = Store<int>(initialState: 0);
    addTearDown(store.teardown);
    final action = _SyncAction()..abort = true;
    final aborted = store.dispatchSync(action);

    action.abort = false;
    final completed = store.dispatchSync(action);

    expect(aborted.isDispatchAborted, isTrue);
    expect(aborted.isDispatched, isFalse);
    expect(completed, same(action.status));
    expect(completed.isDispatchAborted, isFalse);
    expect(completed.isCompletedOk, isTrue);
    expect(store.state, 1);
    expect(store.dispatchCount, 1);
  });

  test('an aborted attempt cannot reset an already dispatched action', () {
    final store = Store<int>(initialState: 0);
    addTearDown(store.teardown);
    final action = _SyncAction();
    store.dispatchSync(action);

    action.abort = true;
    store.dispatchSync(action);
    expect(action.status.isDispatched, isTrue);

    action.abort = false;
    expect(() => store.dispatchSync(action), throwsA(isA<StoreException>()));
    expect(store.reduceCount, 1);
  });
}

class _SyncAction extends ReduxAction<int> {
  bool abort = false;
  bool beforeRan = false;
  bool reduceRan = false;
  bool afterRan = false;

  @override
  bool abortDispatch() => abort;

  @override
  void after() => afterRan = true;

  @override
  void before() {
    beforeRan = true;
  }

  @override
  int reduce() {
    reduceRan = true;
    return 1;
  }
}
