import 'package:async_redux/async_redux.dart';
import 'package:bdd_framework/bdd_framework.dart';
import 'package:flutter_test/flutter_test.dart' hide Retry;

void main() {
  var feature = BddFeature('Retry actions');

  Bdd(feature)
      .scenario('Action retries a few times and succeeds.')
      .given('An action that retries up to 10 times.')
      .and('The action fails with an user exception the first 4 times.')
      .when('The action is dispatched.')
      .then('It does change the state.')
      .run((_) async {
    var store = Store<State>(initialState: State(1));

    expect(store.state.count, 1);
    var action = ActionThatRetriesAndSucceeds();
    await store.dispatchAndWait(action);
    expect(action.attempts, 5);
    expect(action.log, '012345');
    expect(store.state.count, 2);
    expect(action.status.isCompletedOk, isTrue);
  });

  Bdd(feature)
      .scenario('Action retries unlimited tries until it succeeds.')
      .given('An action marked with "UnlimitedRetries".')
      .and('The action fails with an user exception the first 6 times.')
      .when('The action is dispatched.')
      .then('It does change the state.')
      .note('Without the "UnlimitedRetries" it would fail because the default is 3 retries.')
      .run((_) async {
    var store = Store<State>(initialState: State(1));

    expect(store.state.count, 1);
    var action = ActionThatRetriesUnlimitedAndFails();
    await store.dispatchAndWait(action);
    expect(action.attempts, 7);
    expect(action.log, '01234567');
    expect(store.state.count, 2);
    expect(action.status.isCompletedOk, isTrue);
  });

  Bdd(feature)
      .scenario('Action retries a few times and fails.')
      .given('An action that retries up to 3 times.')
      .and('The action fails with an user exception the first 4 times.')
      .when('The action is dispatched.')
      .then('It does NOT change the state.')
      .run((_) async {
    var store = Store<State>(initialState: State(1));

    expect(store.state.count, 1);
    var action = ActionThatRetriesAndFails();
    await store.dispatchAndWait(action);
    expect(store.state.count, 1);
    expect(action.attempts, 4);
    expect(action.log, '0123');
    expect(action.status.isCompletedFailed, isTrue);
  });

  Bdd(feature)
      .scenario('Sync action becomes ASYNC of it retries, even if it succeeds the first time.')
      .given('A SYNC action that retries up to 10 times.')
      .when('The action is dispatched and succeeds the first time.')
      .then('It cannot be dispatched SYNC anymore.')
      .run((_) async {
    var store = Store<State>(initialState: State(1));

    expect(store.state.count, 1);
    var action = ActionThatRetriesButSucceedsTheFirstTry();
    await store.dispatchAndWait(action);
    expect(action.attempts, 0);
    expect(action.log, '0');
    expect(store.state.count, 2);
    expect(action.status.isCompletedOk, isTrue);

    // The action cannot be dispatched SYNC anymore.
    expect(() => store.dispatchSync(action), throwsA(isA<StoreException>()));
  });
}

class State {
  final int count;

  State(this.count);

  @override
  String toString() => 'State($count)';
}

class ActionThatRetriesAndSucceeds extends ReduxAction<State> with Retry {
  @override
  Duration get initialDelay => const Duration(milliseconds: 10);

  @override
  int maxRetries = 10;

  String log = '';

  @override
  State reduce() {
    log += attempts.toString();
    if (attempts <= 4) throw UserException('Failed: $attempts');
    return State(state.count + 1);
  }
}

class ActionThatRetriesAndFails extends ReduxAction<State> with Retry {
  @override
  Duration get initialDelay => const Duration(milliseconds: 10);

  String log = '';

  @override
  State reduce() {
    log += attempts.toString();
    if (attempts <= 4) throw UserException('Failed: $attempts');
    return State(state.count + 1);
  }
}

class ActionThatRetriesButSucceedsTheFirstTry extends ReduxAction<State> with Retry {
  @override
  Duration get initialDelay => const Duration(milliseconds: 10);

  @override
  int maxRetries = 10;

  String log = '';

  @override
  State reduce() {
    log += attempts.toString();
    return State(state.count + 1);
  }
}

class ActionThatRetriesUnlimitedAndFails extends ReduxAction<State> with Retry, UnlimitedRetries {
  @override
  Duration get initialDelay => const Duration(milliseconds: 10);

  String log = '';

  @override
  State reduce() {
    log += attempts.toString();
    if (attempts <= 6) throw UserException('Failed: $attempts');
    return State(state.count + 1);
  }
}
