import 'package:async_redux/async_redux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('offline actions retain the default connection error', () async {
    final store = Store<int>(
      initialState: 0,
      options: StoreOptions(hasConnection: () async => false),
    );
    addTearDown(store.teardown);

    final status = await store.dispatchAndWait(_Check());
    expect(status.originalError, isA<ConnectionException>());
    expect((status.originalError as UserException).errorText, 'No Internet connection');
    expect(store.state, 0);
  });

  test('the store factory applies to different CheckInternet actions', () async {
    var calls = 0;
    final store = Store<int>(
      initialState: 0,
      options: StoreOptions(
        hasConnection: () async => false,
        connectionException: () {
          calls++;
          return UserException('Offline $calls', errorText: 'Connection $calls');
        },
      ),
    );
    addTearDown(store.teardown);

    for (final action in [_Check(), _OtherCheck()]) {
      final status = await store.dispatchAndWait(action);
      final error = status.wrappedError as UserException;
      expect(error.message, 'Offline $calls');
      expect(error.errorText, 'Connection $calls');
      expect(store.exceptionFor(action.runtimeType), same(error));
    }
    expect(calls, 2);
    expect(store.state, 0);
  });

  test('exception factories are isolated between stores', () async {
    final first = Store<int>(
      initialState: 0,
      options: StoreOptions(
        hasConnection: () async => false,
        connectionException: () => const UserException('First connection error'),
      ),
    );
    final second = Store<int>(
      initialState: 0,
      options: StoreOptions(hasConnection: () async => false),
    );
    addTearDown(first.teardown);
    addTearDown(second.teardown);

    final custom = await first.dispatchAndWait(_Check());
    final standard = await second.dispatchAndWait(_Check());
    expect((custom.originalError as UserException).message, 'First connection error');
    expect(standard.originalError, isA<ConnectionException>());
  });

  test('an action exception override takes precedence over the store factory', () async {
    final store = Store<int>(
      initialState: 0,
      options: StoreOptions(
        hasConnection: () async => false,
        connectionException: () => throw StateError('Must not be called'),
      ),
    );
    addTearDown(store.teardown);

    final status = await store.dispatchAndWait(_CustomException());
    expect((status.originalError as UserException).message, 'Action connection error');
  });

  test('the factory is unused online and by the other internet mixins', () async {
    final store = Store<int>(
      initialState: 0,
      options: StoreOptions(
        hasConnection: () async => true,
        connectionException: () => throw StateError('Must not be called'),
      ),
    );
    addTearDown(store.teardown);

    expect((await store.dispatchAndWait(_Check())).isCompletedOk, isTrue);
    store.options.hasConnection = () async => false;
    expect((await store.dispatchAndWait(_Abort())).isDispatchAborted, isTrue);
    final retry = await store.dispatchAndWait(_Retry());
    expect(retry.originalError, isA<UserException>());
    expect(store.state, 1);
  });

  test('a factory error enters the normal action error pipeline', () async {
    final failure = StateError('Exception factory failed');
    final store = Store<int>(
      initialState: 0,
      options: StoreOptions(
        hasConnection: () async => false,
        connectionException: () => throw failure,
      ),
    );
    addTearDown(store.teardown);
    final action = _Check();

    await expectLater(store.dispatchAndWait(action), throwsA(same(failure)));
    expect(action.status.originalError, same(failure));
    expect(store.actionsInProgress(), isEmpty);
    expect(store.state, 0);
  });

  for (final quiet in [false, true]) {
    test(
      'dialog handling preserves the configured retry callback; quiet=$quiet',
      () async {
        var retries = 0;
        void retry() => retries++;
        final store = Store<int>(
          initialState: 0,
          options: StoreOptions(
            hasConnection: () async => false,
            connectionException: () => ConnectionException.noConnectionWithRetry(retry),
          ),
        );
        addTearDown(store.teardown);

        final status = await store.dispatchAndWait(quiet ? _QuietCheck() : _Check());
        final error = status.wrappedError as UserException;
        expect(error, isA<ConnectionException>());
        expect(error.onOk, same(retry));
        expect(error.ifOpenDialog, !quiet);
        expect(store.errors.length, quiet ? 0 : 1);
        expect(retries, 0);
        expect(store.state, 0);
      },
    );
  }

  for (final dismiss in [false, true]) {
    testWidgets('configured retry work runs after dialog dismissal=$dismiss', (
      tester,
    ) async {
      var retries = 0;
      late final Store<int> store;
      store = Store<int>(
        initialState: 0,
        options: StoreOptions(
          hasConnection: () async => false,
          connectionException: () => ConnectionException.noConnectionWithRetry(() {
            retries++;
            store.options.hasConnection = () async => true;
            store.dispatch(_Check());
          }),
        ),
      );
      addTearDown(store.teardown);
      await tester.pumpWidget(
        StoreProvider<int>(
          store: store,
          child: MaterialApp(
            home: UserExceptionDialog<int>(
              useLocalContext: true,
              child: const Scaffold(body: SizedBox()),
            ),
          ),
        ),
      );
      await tester.runAsync(() => store.dispatchAndWait(_Check()));
      await tester.pumpAndSettle();
      expect(find.text('There is no Internet'), findsOneWidget);
      expect(retries, 0);
      expect(store.state, 0);

      if (dismiss) {
        Navigator.of(tester.element(find.byType(AlertDialog))).pop();
      } else {
        await tester.tap(find.text('OK'));
      }
      await tester.pumpAndSettle();
      expect(retries, 1);
      expect(store.state, 1);
      expect(find.byType(AlertDialog), findsNothing);
    });
  }
}

abstract class _Increment extends ReduxAction<int> {
  @override
  int reduce() => state + 1;
}

class _Check extends _Increment with CheckInternet<int> {}

class _OtherCheck extends _Check {}

class _QuietCheck extends _Check with NoDialog<int> {}

class _CustomException extends _Check {
  @override
  UserException connectionException() => const UserException('Action connection error');
}

class _Abort extends _Increment with AbortWhenNoInternet<int> {}

class _Retry extends _Increment with UnlimitedRetryCheckInternet<int> {
  @override
  int get maxRetries => 0;

  @override
  void printRetries(String message) {}
}
