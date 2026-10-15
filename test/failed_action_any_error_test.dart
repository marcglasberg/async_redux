import 'package:async_redux/async_redux.dart';
import 'package:bdd_framework/bdd_framework.dart';
import 'package:flutter_test/flutter_test.dart';

/// `isFailed` must be true when the action failed with ANY error, not only with a
/// `UserException`. Only `exceptionFor` is limited to `UserException`, because that's the
/// error type it returns.
void main() {
  var feature = BddFeature('Failed action with any error');

  Bdd(feature)
      .scenario('A SYNC action that fails with an error which is not a UserException.')
      .given('A SYNC action that throws a plain exception (not a UserException).')
      .when('The action is dispatched, and the error is caught.')
      .then('`isFailed` is true for the action type.')
      .and('`exceptionFor` is null, since the error is not a UserException.')
      .and('Dispatching the action again, and succeeding, clears the failed state.')
      .run((_) async {
    final store = Store<State>(initialState: State(1));
    expect(store.isFailed(SyncAction), false);

    try {
      store.dispatch(SyncAction(MyException('Plain error')));
    } catch (_) {}

    expect(store.isFailed(SyncAction), true);
    expect(store.exceptionFor(SyncAction), null);

    store.dispatch(SyncAction(null));
    expect(store.isFailed(SyncAction), false);
    expect(store.exceptionFor(SyncAction), null);
  });

  Bdd(feature)
      .scenario('An ASYNC action that fails with an error which is not a UserException.')
      .given('An ASYNC action that throws a plain exception (not a UserException).')
      .when('The action is dispatched with `dispatchAndWait`, and the error is caught.')
      .then('`isFailed` is true for the action type.')
      .and('`exceptionFor` is null, since the error is not a UserException.')
      .and('Dispatching the action again, and succeeding, clears the failed state.')
      .run((_) async {
    final store = Store<State>(initialState: State(1));
    expect(store.isFailed(AsyncAction), false);

    try {
      await store.dispatchAndWait(AsyncAction(MyException('Plain error')));
    } catch (_) {}

    expect(store.isFailed(AsyncAction), true);
    expect(store.exceptionFor(AsyncAction), null);

    await store.dispatchAndWait(AsyncAction(null));
    expect(store.isFailed(AsyncAction), false);
    expect(store.exceptionFor(AsyncAction), null);
  });

  Bdd(feature)
      .scenario(
          'A failed action with a plain error, and `isFailed` with a list of types.')
      .given('An action that failed with a plain exception (not a UserException).')
      .when('We call `isFailed` with a list of types that includes it.')
      .then('`isFailed` is true.')
      .and('`exceptionFor` with the same list is null.')
      .run((_) async {
    final store = Store<State>(initialState: State(1));

    try {
      store.dispatch(SyncAction(MyException('Plain error')));
    } catch (_) {}

    expect(store.isFailed([AsyncAction, SyncAction]), true);
    expect(store.exceptionFor([AsyncAction, SyncAction]), null);

    expect(store.isFailed([AsyncAction]), false);
  });

  Bdd(feature)
      .scenario('`clearExceptionFor` clears an action that failed with a plain error.')
      .given('An action that failed with a plain exception (not a UserException).')
      .when('We call `clearExceptionFor` for its type.')
      .then('`isFailed` is false.')
      .run((_) async {
    final store = Store<State>(initialState: State(1));

    try {
      store.dispatch(SyncAction(MyException('Plain error')));
    } catch (_) {}
    expect(store.isFailed(SyncAction), true);

    store.clearExceptionFor(SyncAction);
    expect(store.isFailed(SyncAction), false);
  });

  Bdd(feature)
      .scenario('Both errors are reported: first a plain error, then a UserException.')
      .given('An action that failed with a plain exception.')
      .when('The same action type is dispatched again, and fails with a UserException.')
      .then('`isFailed` is true, and `exceptionFor` returns the UserException.')
      .run((_) async {
    final store = Store<State>(initialState: State(1));

    try {
      store.dispatch(SyncAction(MyException('Plain error')));
    } catch (_) {}
    expect(store.isFailed(SyncAction), true);
    expect(store.exceptionFor(SyncAction), null);

    store.dispatch(SyncAction(const UserException('User error')));
    expect(store.isFailed(SyncAction), true);
    expect(store.exceptionFor(SyncAction), const UserException('User error'));
  });

  Bdd(feature)
      .scenario('An action whose error is swallowed by `wrapError` did not fail.')
      .given(
          'An action that throws, but its `wrapError` returns null (swallows the error).')
      .when('The action is dispatched.')
      .then('`isFailed` is false, since the error was swallowed.')
      .run((_) async {
    final store = Store<State>(initialState: State(1));

    store.dispatch(SyncActionThatSwallows());

    expect(store.isFailed(SyncActionThatSwallows), false);
    expect(store.exceptionFor(SyncActionThatSwallows), null);
  });

  Bdd(feature)
      .scenario('An action aborted with `AbortDispatchException` did not fail.')
      .given('An action that throws `AbortDispatchException`.')
      .when('The action is dispatched.')
      .then('`isFailed` is false, since the action was aborted, not failed.')
      .run((_) async {
    final store = Store<State>(initialState: State(1));

    store.dispatch(SyncAction(AbortDispatchException()));

    expect(store.isFailed(SyncAction), false);
    expect(store.exceptionFor(SyncAction), null);
  });

  Bdd(feature)
      .scenario('Inside an action, `isFailed` sees a failure with a plain error.')
      .given('An action that failed with a plain exception (not a UserException).')
      .when('Another action calls `isFailed` for that type, in its reducer.')
      .then('It gets true.')
      .run((_) async {
    final store = Store<State>(initialState: State(1));

    try {
      store.dispatch(SyncAction(MyException('Plain error')));
    } catch (_) {}

    var checker = CheckIfFailed(SyncAction);
    store.dispatch(checker);
    expect(checker.result, true);
  });
}

class State {
  final int count;

  State(this.count);
}

class MyException implements Exception {
  final String message;

  MyException(this.message);

  @override
  String toString() => 'MyException($message)';
}

/// Throws [error] if it's not null.
class SyncAction extends ReduxAction<State> {
  final Object? error;

  SyncAction(this.error);

  @override
  State? reduce() {
    if (error != null) throw error!;
    return null;
  }
}

/// Throws [error] if it's not null.
class AsyncAction extends ReduxAction<State> {
  final Object? error;

  AsyncAction(this.error);

  @override
  Future<State?> reduce() async {
    await Future.delayed(const Duration(milliseconds: 1));
    if (error != null) throw error!;
    return null;
  }
}

class SyncActionThatSwallows extends ReduxAction<State> {
  @override
  State? reduce() => throw MyException('Swallowed');

  @override
  Object? wrapError(Object error, StackTrace stackTrace) => null;
}

class CheckIfFailed extends ReduxAction<State> {
  final Type type;
  bool? result;

  CheckIfFailed(this.type);

  @override
  State? reduce() {
    result = isFailed(type);
    return null;
  }
}
