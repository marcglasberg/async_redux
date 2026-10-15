import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:bdd_framework/bdd_framework.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// `statusKey` tells apart the actions of the same class, in `isWaiting`, `isFailed`,
/// `exceptionFor` and `clearExceptionFor`.
void main() {
  var feature = BddFeature('Status per key, with statusKey');

  // ---------------------------------------------------------------------------------------
  // isWaiting

  Bdd(feature)
      .scenario('`isWaiting` with a statusKey only sees the actions with that key.')
      .given('Two LoadUser actions running, for users "a" and "b".')
      .when('We ask `isWaiting` with and without a statusKey.')
      .then(
          'Without a key, it is true. With "a" or "b", it is true. With "c", it is false.')
      .and(
          'When "a" finishes, `isWaiting` with "a" is false, but with "b" and without a key '
          'is still true.')
      .run((_) async {
    final store = Store<State>(initialState: State());
    final finishA = Completer<void>();
    final finishB = Completer<void>();
    final futureA = store.dispatchAndWait(LoadUser('a', finish: finishA.future));
    final futureB = store.dispatchAndWait(LoadUser('b', finish: finishB.future));

    expect(store.isWaiting(LoadUser), true);
    expect(store.isWaiting(LoadUser, statusKey: 'a'), true);
    expect(store.isWaiting(LoadUser, statusKey: 'b'), true);
    expect(store.isWaiting(LoadUser, statusKey: 'c'), false);

    finishA.complete();
    await futureA;
    expect(store.isWaiting(LoadUser, statusKey: 'a'), false);
    expect(store.isWaiting(LoadUser, statusKey: 'b'), true);
    expect(store.isWaiting(LoadUser), true);

    finishB.complete();
    await futureB;
    expect(store.isWaiting(LoadUser), false);
    expect(store.state.loaded, ['a', 'b']);
  });

  Bdd(feature)
      .scenario('`isWaiting` with a list of types also accepts a statusKey.')
      .given('A LoadUser action running for user "a".')
      .when('We ask `isWaiting([LoadUser, LoadCart], statusKey: ...)`.')
      .then('It is true for "a", and false for "b".')
      .run((_) async {
    final store = Store<State>(initialState: State());
    final finish = Completer<void>();
    final future = store.dispatchAndWait(LoadUser('a', finish: finish.future));

    expect(store.isWaiting([LoadUser, LoadCart], statusKey: 'a'), true);
    expect(store.isWaiting([LoadUser, LoadCart], statusKey: 'b'), false);

    finish.complete();
    await future;
  });

  Bdd(feature)
      .scenario(
          '`isWaiting` with a statusKey is false for an action that has no statusKey.')
      .given('An action class that does not override `statusKey`, running.')
      .when('We ask `isWaiting` with some statusKey.')
      .then('It is false, while `isWaiting` without a key is true.')
      .run((_) async {
    final store = Store<State>(initialState: State());
    final finish = Completer<void>();
    final future = store.dispatchAndWait(LoadAll(finish: finish.future));

    expect(store.isWaiting(LoadAll), true);
    expect(store.isWaiting(LoadAll, statusKey: 'a'), false);

    finish.complete();
    await future;
  });

  // ---------------------------------------------------------------------------------------
  // isFailed and exceptionFor

  Bdd(feature)
      .scenario(
          '`isFailed` and `exceptionFor` with a statusKey only see the failures with '
          'that key.')
      .given('LoadUser failed for users "a" and "b", with different UserExceptions.')
      .when('We ask `isFailed` and `exceptionFor` with and without a statusKey.')
      .then('Without a key, `isFailed` is true, and `exceptionFor` is the most recent '
          'failure ("b").')
      .and(
          'With "a" or "b", `isFailed` is true and `exceptionFor` is the exception of that '
          'user.')
      .and('With "c", `isFailed` is false and `exceptionFor` is null.')
      .run((_) async {
    final store = Store<State>(initialState: State());
    await store.dispatchAndWait(LoadUser('a', outcome: Outcome.userException));
    await store.dispatchAndWait(LoadUser('b', outcome: Outcome.userException));

    expect(store.isFailed(LoadUser), true);
    expect(store.exceptionFor(LoadUser)?.message, 'User b failed.');

    expect(store.isFailed(LoadUser, statusKey: 'a'), true);
    expect(store.exceptionFor(LoadUser, statusKey: 'a')?.message, 'User a failed.');
    expect(store.isFailed(LoadUser, statusKey: 'b'), true);
    expect(store.exceptionFor(LoadUser, statusKey: 'b')?.message, 'User b failed.');

    expect(store.isFailed(LoadUser, statusKey: 'c'), false);
    expect(store.exceptionFor(LoadUser, statusKey: 'c'), null);
  });

  Bdd(feature)
      .scenario(
          'Dispatching an action again clears only the failure with the same statusKey.')
      .given('LoadUser failed for users "a" and "b".')
      .when('LoadUser for "a" is dispatched again, and succeeds.')
      .then('The failure of "a" is cleared, but "b" is still failed.')
      .and('`isFailed` without a key is still true, because of "b".')
      .run((_) async {
    final store = Store<State>(initialState: State());
    await store.dispatchAndWait(LoadUser('a', outcome: Outcome.userException));
    await store.dispatchAndWait(LoadUser('b', outcome: Outcome.userException));

    await store.dispatchAndWait(LoadUser('a'));

    expect(store.isFailed(LoadUser, statusKey: 'a'), false);
    expect(store.isFailed(LoadUser, statusKey: 'b'), true);
    expect(store.isFailed(LoadUser), true);
    expect(store.exceptionFor(LoadUser)?.message, 'User b failed.');
  });

  Bdd(feature)
      .scenario('Failing again with the same statusKey replaces the previous failure.')
      .given('LoadUser failed for user "a" with one message.')
      .when('LoadUser for "a" fails again with another message.')
      .then(
          '`exceptionFor` with "a" returns the new message, and there is only one failure '
          'for "a".')
      .run((_) async {
    final store = Store<State>(initialState: State());
    await store
        .dispatchAndWait(LoadUser('a', outcome: Outcome.userException, message: 'first'));
    await store.dispatchAndWait(
        LoadUser('a', outcome: Outcome.userException, message: 'second'));

    expect(store.exceptionFor(LoadUser, statusKey: 'a')?.message, 'second');

    // Clearing "a" once leaves nothing: there was a single failure for "a".
    store.clearExceptionFor(LoadUser, statusKey: 'a');
    expect(store.isFailed(LoadUser), false);
  });

  Bdd(feature)
      .scenario('A failure with a plain error is failed per key, but has no exception.')
      .given(
          'LoadUser failed for "a" with a plain error, then for "b" with a UserException, '
          'then for "c" with a plain error.')
      .when('We ask `isFailed` and `exceptionFor`.')
      .then('`isFailed` is true for "a", "b" and "c".')
      .and('`exceptionFor` is null for "a" and "c", and the UserException for "b".')
      .and(
          '`exceptionFor` without a key skips the plain errors and returns the UserException '
          'of "b".')
      .run((_) async {
    final store = Store<State>(initialState: State());
    await _dispatchAndSwallow(store, LoadUser('a', outcome: Outcome.error));
    await store.dispatchAndWait(LoadUser('b', outcome: Outcome.userException));
    await _dispatchAndSwallow(store, LoadUser('c', outcome: Outcome.error));

    expect(store.isFailed(LoadUser, statusKey: 'a'), true);
    expect(store.isFailed(LoadUser, statusKey: 'b'), true);
    expect(store.isFailed(LoadUser, statusKey: 'c'), true);

    expect(store.exceptionFor(LoadUser, statusKey: 'a'), null);
    expect(store.exceptionFor(LoadUser, statusKey: 'b')?.message, 'User b failed.');
    expect(store.exceptionFor(LoadUser, statusKey: 'c'), null);

    expect(store.isFailed(LoadUser), true);
    expect(store.exceptionFor(LoadUser)?.message, 'User b failed.');
  });

  Bdd(feature)
      .scenario('A statusKey that is a record is compared by its content.')
      .given(
          'LoadCart, whose statusKey is the record `(userId, cartId)`, failed for user "a" '
          'and cart 1.')
      .when('We ask `isFailed` with a new record with the same content, and with another '
          'content.')
      .then('The same content matches, and the other does not.')
      .run((_) async {
    final store = Store<State>(initialState: State());
    store.dispatch(LoadCart('a', 1));

    expect(store.isFailed(LoadCart, statusKey: ('a', 1)), true);
    expect(store.exceptionFor(LoadCart, statusKey: ('a', 1))?.message,
        'Cart 1 of a failed.');
    expect(store.isFailed(LoadCart, statusKey: ('a', 2)), false);
    expect(store.isFailed(LoadCart, statusKey: ('b', 1)), false);
  });

  Bdd(feature)
      .scenario(
          'An action without a statusKey is failed without a key, and is not seen with '
          'a key.')
      .given('LoadAll, which does not override `statusKey`, failed.')
      .when('We ask `isFailed` without a key, and with some key.')
      .then('Without a key, it is true. With a key, it is false.')
      .run((_) async {
    final store = Store<State>(initialState: State());
    await store.dispatchAndWait(LoadAll(outcome: Outcome.userException));

    expect(store.isFailed(LoadAll), true);
    expect(store.exceptionFor(LoadAll)?.message, 'All failed.');
    expect(store.isFailed(LoadAll, statusKey: 'a'), false);
    expect(store.exceptionFor(LoadAll, statusKey: 'a'), null);
  });

  // ---------------------------------------------------------------------------------------
  // Clearing

  Bdd(feature)
      .scenario(
          '`clearExceptionFor` with a statusKey clears only that failure; without it, '
          'all of the type.')
      .given('LoadUser failed for "a" and "b", and LoadAll failed.')
      .when('We call `clearExceptionFor(LoadUser, statusKey: "a")`.')
      .then('Only "a" is cleared.')
      .and(
          'When we call `clearExceptionFor(LoadUser)` without a key, "b" is cleared too, '
          'but LoadAll is still failed.')
      .run((_) async {
    final store = Store<State>(initialState: State());
    await store.dispatchAndWait(LoadUser('a', outcome: Outcome.userException));
    await store.dispatchAndWait(LoadUser('b', outcome: Outcome.userException));
    await store.dispatchAndWait(LoadAll(outcome: Outcome.userException));

    store.clearExceptionFor(LoadUser, statusKey: 'a');
    expect(store.isFailed(LoadUser, statusKey: 'a'), false);
    expect(store.isFailed(LoadUser, statusKey: 'b'), true);

    store.clearExceptionFor(LoadUser);
    expect(store.isFailed(LoadUser, statusKey: 'b'), false);
    expect(store.isFailed(LoadUser), false);
    expect(store.isFailed(LoadAll), true);
  });

  Bdd(feature)
      .scenario('`clearAllExceptions` clears the failures of all types and keys.')
      .given('LoadUser failed for "a" and "b", and LoadAll failed.')
      .when('We call `clearAllExceptions()` [How].')
      .then('Nothing is failed anymore.')
      .example(val('How', 'directly'))
      .example(val('How', 'through internalMixinProps.clear()'))
      .example(val('How', 'through shutdown()'))
      .run((ctx) async {
    final how = ctx.example.val('How') as String;
    final store = Store<State>(initialState: State());
    await store.dispatchAndWait(LoadUser('a', outcome: Outcome.userException));
    await store.dispatchAndWait(LoadUser('b', outcome: Outcome.userException));
    await store.dispatchAndWait(LoadAll(outcome: Outcome.userException));
    expect(store.isFailed(LoadUser), true);
    expect(store.isFailed(LoadAll), true);

    if (how == 'directly')
      store.clearAllExceptions();
    else if (how == 'through internalMixinProps.clear()')
      store.internalMixinProps.clear();
    else
      store.shutdown();

    expect(store.isFailed(LoadUser), false);
    expect(store.isFailed(LoadUser, statusKey: 'a'), false);
    expect(store.isFailed(LoadUser, statusKey: 'b'), false);
    expect(store.isFailed(LoadAll), false);
    expect(store.exceptionFor(LoadUser), null);
  });

  Bdd(feature)
      .scenario(
          '`exceptionFor` and `clearExceptionFor` with a list of types also accept a '
          'statusKey.')
      .given('LoadUser failed for "a" and "b", and LoadCart failed for ("a", 1).')
      .when('We call `exceptionFor([LoadCart, LoadUser], statusKey: "a")`.')
      .then(
          'It returns the exception of LoadUser "a", the first type in the list that failed '
          'with that key.')
      .and(
          '`clearExceptionFor([LoadCart, LoadUser], statusKey: "a")` clears only LoadUser "a". '
          'LoadUser "b" and LoadCart ("a", 1) are still failed.')
      .run((_) async {
    final store = Store<State>(initialState: State());
    await store.dispatchAndWait(LoadUser('a', outcome: Outcome.userException));
    await store.dispatchAndWait(LoadUser('b', outcome: Outcome.userException));
    store.dispatch(LoadCart('a', 1));

    expect(store.isFailed([LoadCart, LoadUser], statusKey: 'a'), true);
    expect(store.exceptionFor([LoadCart, LoadUser], statusKey: 'a')?.message,
        'User a failed.');
    expect(store.exceptionFor([LoadCart, LoadUser], statusKey: 'c'), null);

    store.clearExceptionFor([LoadCart, LoadUser], statusKey: 'a');
    expect(store.isFailed(LoadUser, statusKey: 'a'), false);
    expect(store.isFailed(LoadUser, statusKey: 'b'), true);
    expect(store.isFailed(LoadCart, statusKey: ('a', 1)), true);
  });

  Bdd(feature)
      .scenario(
          '`isWaiting` with an ACTION instance ignores the statusKey, since the action '
          'itself is checked.')
      .given('A LoadUser action instance for "a", running.')
      .when('We ask `isWaiting(action, statusKey: "b")`.')
      .then('It is true, because that exact action is running, whatever the key passed.')
      .run((_) async {
    final store = Store<State>(initialState: State());
    final finish = Completer<void>();
    final action = LoadUser('a', finish: finish.future);
    final future = store.dispatchAndWait(action);

    expect(store.isWaiting(action), true);
    expect(store.isWaiting(action, statusKey: 'b'), true);

    finish.complete();
    await future;
    expect(store.isWaiting(action, statusKey: 'a'), false);
  });

  Bdd(feature)
      .scenario(
          'A widget that asked `isFailed` with a statusKey is rebuilt when that key '
          'fails and when it is dispatched again.')
      .given('The store\'s onChange stream is being listened to, and `isFailed(LoadUser, '
          'statusKey: "a")` was asked (so the type is known to be checked).')
      .when('LoadUser "a" fails, and then is dispatched again.')
      .then(
          'The stream emits on the failure, and again on the new dispatch, which clears it.')
      .run((_) async {
    final store = Store<State>(initialState: State());
    int emissions = 0;
    final subscription = store.onChange.listen((_) => emissions++);
    expect(store.isFailed(LoadUser, statusKey: 'a'), false);

    await store.dispatchAndWait(
        LoadUser('a', finish: Future.value(), outcome: Outcome.userException));
    await Future.delayed(Duration.zero);
    final afterFailure = emissions;
    expect(afterFailure, greaterThan(0));
    expect(store.isFailed(LoadUser, statusKey: 'a'), true);

    final finish = Completer<void>();
    final future = store.dispatchAndWait(LoadUser('a', finish: finish.future));
    await Future.delayed(Duration.zero);
    expect(emissions, greaterThan(afterFailure));
    expect(store.isFailed(LoadUser, statusKey: 'a'), false);

    finish.complete();
    await future;
    await subscription.cancel();
  });

  // ---------------------------------------------------------------------------------------
  // Inside actions

  Bdd(feature)
      .scenario('Inside an action, `isWaiting`, `isFailed` and `exceptionFor` accept a '
          'statusKey.')
      .given('LoadUser is running for "a", and failed for "b".')
      .when('Another action checks "a" and "b" with a statusKey, in its reducer.')
      .then(
          'It sees "a" waiting and not failed, and "b" failed with its message, not waiting.')
      .run((_) async {
    final store = Store<State>(initialState: State());
    final finishA = Completer<void>();
    final futureA = store.dispatchAndWait(LoadUser('a', finish: finishA.future));
    await store.dispatchAndWait(LoadUser('b', outcome: Outcome.userException));

    final checkA = CheckUser('a');
    final checkB = CheckUser('b');
    store.dispatch(checkA);
    store.dispatch(checkB);

    expect(checkA.result, (waiting: true, failed: false, message: null));
    expect(checkB.result, (waiting: false, failed: true, message: 'User b failed.'));

    finishA.complete();
    await futureA;
  });

  // ---------------------------------------------------------------------------------------
  // Widgets

  testWidgets(
      'The BuildContext extensions with a statusKey show the status of one user only.',
      (WidgetTester tester) async {
    final store = Store<State>(initialState: State());

    await tester.pumpWidget(
      MaterialApp(
        home: StoreProvider<State>(
          store: store,
          child: const Scaffold(
            body: Column(children: [UserRow('a'), UserRow('b')]),
          ),
        ),
      ),
    );
    expect(find.text('a:idle:ok:-'), findsOneWidget);
    expect(find.text('b:idle:ok:-'), findsOneWidget);

    // LoadUser for "a" starts: only row "a" is waiting.
    final finish = Completer<void>();
    final future = store.dispatchAndWait(
        LoadUser('a', finish: finish.future, outcome: Outcome.userException));
    await tester.pump();
    await tester.pump();
    expect(find.text('a:waiting:ok:-'), findsOneWidget);
    expect(find.text('b:idle:ok:-'), findsOneWidget);

    // LoadUser for "a" fails: only row "a" is failed, with its message.
    finish.complete();
    await future;
    await tester.pump();
    await tester.pump();
    expect(find.text('a:idle:failed:User a failed.'), findsOneWidget);
    expect(find.text('b:idle:ok:-'), findsOneWidget);

    // LoadUser for "b" fails too.
    await store.dispatchAndWait(
        LoadUser('b', finish: Future.value(), outcome: Outcome.userException));
    await tester.pump();
    await tester.pump();
    expect(find.text('a:idle:failed:User a failed.'), findsOneWidget);
    expect(find.text('b:idle:failed:User b failed.'), findsOneWidget);

    // The clear button of row "a" calls `context.clearExceptionFor(LoadUser, statusKey: 'a')`.
    await tester.tap(find.byKey(const Key('clear-a')));
    await tester.pump();
    await tester.pump();
    expect(find.text('a:idle:ok:-'), findsOneWidget);
    expect(find.text('b:idle:failed:User b failed.'), findsOneWidget);
  });
}

Future<void> _dispatchAndSwallow(Store<State> store, ReduxAction<State> action) async {
  try {
    await store.dispatchAndWait(action);
  } catch (_) {}
}

class State {
  final List<String> loaded;

  State([this.loaded = const []]);
}

enum Outcome { ok, userException, error }

/// Loads one user. Its `statusKey` is the user id. Stays pending until [finish] completes.
class LoadUser extends ReduxAction<State> {
  final String userId;
  final Future<void>? finish;
  final Outcome outcome;
  final String? message;

  LoadUser(this.userId, {this.finish, this.outcome = Outcome.ok, this.message});

  @override
  Object? get statusKey => userId;

  @override
  Future<State?> reduce() async {
    await (finish ?? Future.delayed(const Duration(milliseconds: 1)));
    if (outcome == Outcome.userException)
      throw UserException(message ?? 'User $userId failed.').noDialog;
    if (outcome == Outcome.error) throw StateError(message ?? 'User $userId failed.');
    return State([...state.loaded, userId]);
  }
}

/// Its `statusKey` is a record, compared by content.
class LoadCart extends ReduxAction<State> {
  final String userId;
  final int cartId;

  LoadCart(this.userId, this.cartId);

  @override
  Object? get statusKey => (userId, cartId);

  @override
  State? reduce() => throw UserException('Cart $cartId of $userId failed.').noDialog;
}

/// Has no `statusKey`.
class LoadAll extends ReduxAction<State> {
  final Future<void>? finish;
  final Outcome outcome;

  LoadAll({this.finish, this.outcome = Outcome.ok});

  @override
  Future<State?> reduce() async {
    await (finish ?? Future.delayed(const Duration(milliseconds: 1)));
    if (outcome == Outcome.userException)
      throw const UserException('All failed.').noDialog;
    return null;
  }
}

/// Checks the status of a user, from inside an action.
class CheckUser extends ReduxAction<State> {
  final String userId;
  ({bool waiting, bool failed, String? message})? result;

  CheckUser(this.userId);

  @override
  State? reduce() {
    result = (
      waiting: isWaiting(LoadUser, statusKey: userId),
      failed: isFailed(LoadUser, statusKey: userId),
      message: exceptionFor(LoadUser, statusKey: userId)?.message,
    );
    return null;
  }
}

/// A row for one user, showing its waiting, failed and exception status, and a button to
/// clear its failure.
class UserRow extends StatelessWidget {
  final String userId;

  const UserRow(this.userId, {super.key});

  @override
  Widget build(BuildContext context) {
    final isWaiting = context.isWaiting(LoadUser, statusKey: userId);
    final isFailed = context.isFailed(LoadUser, statusKey: userId);
    final error = context.exceptionFor(LoadUser, statusKey: userId);
    return Row(children: [
      Text('$userId:${isWaiting ? 'waiting' : 'idle'}:${isFailed ? 'failed' : 'ok'}'
          ':${error?.message ?? '-'}'),
      TextButton(
        key: Key('clear-$userId'),
        onPressed: () => context.clearExceptionFor(LoadUser, statusKey: userId),
        child: const Text('clear'),
      ),
    ]);
  }
}
