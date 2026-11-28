import 'package:async_redux/async_redux.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final internet in [false, true]) {
    for (final notify in [false, true]) {
      test('NoDialog: internet=$internet, notify=$notify', () async {
        final store = Store<int>(initialState: 0)
          ..options.hasConnection = () async => internet;
        addTearDown(store.teardown);
        final action = _Quiet();
        expect(action.ifOpenDialog, isFalse);
        expect(action.isSync(), isFalse);
        final status = await store.dispatchAndWait(action, notify: notify);
        expect(status.isCompletedOk, internet);
        expect(status.isDispatchAborted, isFalse);
        expect(status.hasFinishedMethodBefore, internet);
        expect(status.hasFinishedMethodAfter, isTrue);
        expect(store.isFailed(_Quiet), !internet);
        expect(store.state, internet ? 1 : 0);
        expect(store.errors, isEmpty);
        if (!internet) {
          expect(status.wrappedError, isA<UserException>());
          expect((status.wrappedError as UserException).ifOpenDialog, isFalse);
          expect(store.exceptionFor(_Quiet), same(status.wrappedError));
        }
      });
    }
  }

  test('NoDialog only suppresses connectivity errors, not reducer errors', () async {
    final store = Store<int>(initialState: 0)
      ..options.hasConnection = () async => true;
    addTearDown(store.teardown);
    const error = UserException('reduce failed');
    final action = _Quiet()..error = error;
    final status = await store.dispatchAndWait(action);
    expect(status.wrappedError, same(error));
    expect(store.errors, [error]);
  });

  test('an action can explicitly reenable connectivity dialogs', () async {
    final store = Store<int>(initialState: 0)
      ..options.hasConnection = () async => false;
    addTearDown(store.teardown);
    final status = await store.dispatchAndWait(_Loud());
    expect((status.wrappedError as UserException).ifOpenDialog, isTrue);
    expect(store.errors, [status.wrappedError]);
  });

  test('a later successful dispatch clears the failure without a dialog', () async {
    final store = Store<int>(initialState: 0)
      ..options.hasConnection = () async => false;
    addTearDown(store.teardown);
    await store.dispatchAndWait(_Quiet());
    expect(store.isFailed(_Quiet), isTrue);
    store.options.hasConnection = () async => true;
    await store.dispatchAndWait(_Quiet());
    expect(store.isFailed(_Quiet), isFalse);
    expect(store.errors, isEmpty);
  });
}

class _Quiet extends ReduxAction<int> with CheckInternet, NoDialog {
  Object? error;

  @override
  int reduce() {
    if (error != null) throw error!;
    return state + 1;
  }
}

class _Loud extends _Quiet {
  @override
  bool get ifOpenDialog => true;
}
