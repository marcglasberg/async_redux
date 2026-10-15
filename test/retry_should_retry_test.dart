import 'dart:math';

import 'package:async_redux/async_redux.dart';
import 'package:bdd_framework/bdd_framework.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart' hide Retry;

void main() {
  var feature = BddFeature('Retry predicate (shouldRetry)');

  // ---------------------------------------------------------------------------
  // Retry mixin

  Bdd(feature)
      .scenario('By default, an action with Retry retries every error, '
          'including a UserException.')
      .given('An action with the Retry mixin, that does not override "shouldRetry".')
      .and('Its reducer fails with a UserException twice, then succeeds.')
      .when('The action is dispatched.')
      .then('The reducer runs 3 times, and the action completes OK.')
      .run((_) async {
    var store = Store<State>(initialState: State(''));
    var action =
        LoadText(errors: [const UserException('Failed'), const UserException('Failed')]);
    await dispatchAndCatch(store, action);

    expect(action.reduceCount, 3);
    expect(action.attempts, 2);
    expect(action.status.isCompletedOk, isTrue);
    expect(store.state.text, 'A');
  });

  Bdd(feature)
      .scenario('When "shouldRetry" returns false, the action fails right away with '
          'that error, without retrying.')
      .given('An action with the Retry mixin, and up to 3 retries.')
      .and('Its "shouldRetry" returns false for a NotFoundError.')
      .and('Its reducer always fails with a NotFoundError.')
      .when('The action is dispatched.')
      .then('The reducer runs only once.')
      .and('The action fails with the NotFoundError.')
      .run((_) async {
    var store = Store<State>(initialState: State(''));
    var error = const NotFoundError();
    var action = LoadText(
      errors: [error, error, error, error],
      predicate: (e, _) => e is! NotFoundError,
    );
    await dispatchAndCatch(store, action);

    expect(action.reduceCount, 1);
    expect(action.attempts, 1);
    expect(action.status.isCompletedFailed, isTrue);
    expect(action.status.originalError, same(error));
    expect(store.state.text, '');
  });

  Bdd(feature)
      .scenario('"shouldRetry" gets the error and the attempt number, and the action '
          'retries while it returns true.')
      .given('An action with the Retry mixin, and up to 10 retries.')
      .and('Its reducer always fails, with a different error each time.')
      .and(
          'Its "shouldRetry" returns true for the first 2 attempts, and false for the 3rd.')
      .when('The action is dispatched.')
      .then('"shouldRetry" is called 3 times, with the error of each failed attempt, '
          'and the attempt numbers 1, 2 and 3.')
      .and(
          'The reducer runs 3 times, and the action fails with the error of the 3rd attempt.')
      .run((_) async {
    var store = Store<State>(initialState: State(''));
    var errors = [Exception('1'), Exception('2'), Exception('3'), Exception('4')];
    var action = LoadText(
      errors: errors,
      maxRetries: 10,
      predicate: (_, attempt) => attempt < 3,
    );
    await dispatchAndCatch(store, action);

    expect(action.shouldRetryCalls, [(errors[0], 1), (errors[1], 2), (errors[2], 3)]);
    expect(action.reduceCount, 3);
    expect(action.attempts, 3);
    expect(action.status.isCompletedFailed, isTrue);
    expect(action.status.originalError, same(errors[2]));
  });

  Bdd(feature)
      .scenario('"shouldRetry" is not called when the retries ran out.')
      .given('An action with the Retry mixin, and up to 2 retries.')
      .and('Its reducer always fails.')
      .and('Its "shouldRetry" always returns true.')
      .when('The action is dispatched.')
      .then('The reducer runs 3 times, and the action fails with the last error.')
      .and('"shouldRetry" is called only twice, for attempts 1 and 2, since after the '
          '3rd failure the action fails anyway.')
      .run((_) async {
    var store = Store<State>(initialState: State(''));
    var errors = [Exception('1'), Exception('2'), Exception('3'), Exception('4')];
    var action = LoadText(errors: errors, maxRetries: 2, predicate: (_, __) => true);
    await dispatchAndCatch(store, action);

    expect(action.reduceCount, 3);
    expect(action.attempts, 3);
    expect(action.shouldRetryCalls.map((call) => call.$2), [1, 2]);
    expect(action.status.originalError, same(errors[2]));
  });

  Bdd(feature)
      .scenario('If "shouldRetry" itself throws, the action fails with that error.')
      .given('An action with the Retry mixin, whose "shouldRetry" throws an error.')
      .and('Its reducer fails with a UserException.')
      .when('The action is dispatched.')
      .then('The reducer runs only once.')
      .and('The action fails with the error thrown by "shouldRetry", not with the '
          'UserException.')
      .run((_) async {
    var store = Store<State>(initialState: State(''));
    var predicateError = Exception('shouldRetry failed');
    var action = LoadText(
      errors: [const UserException('Failed')],
      predicate: (_, __) => throw predicateError,
    );
    await dispatchAndCatch(store, action);

    expect(action.reduceCount, 1);
    expect(action.status.isCompletedFailed, isTrue);
    expect(action.status.originalError, same(predicateError));
  });

  // ---------------------------------------------------------------------------
  // UnlimitedRetryCheckInternet mixin

  Bdd(feature)
      .scenario('With UnlimitedRetryCheckInternet, "shouldRetry" returning false stops '
          'the unlimited retries.')
      .given(
          'An action with the UnlimitedRetryCheckInternet mixin, and there is internet.')
      .and('Its reducer fails with a UserException twice, then always fails with a '
          'NotFoundError.')
      .and('Its "shouldRetry" returns false for a NotFoundError.')
      .when('The action is dispatched.')
      .then('The UserExceptions are retried, but the NotFoundError is not.')
      .and('The reducer runs 3 times, and the action fails with the NotFoundError.')
      .note('Without "shouldRetry", the action would retry the NotFoundError forever.')
      .run((_) async {
    var store = Store<State>(initialState: State(''));
    var notFound = const NotFoundError();
    var action = LoadTextUnlimited(
      internet: [true],
      errors: [
        const UserException('Failed'),
        const UserException('Failed'),
        notFound,
        notFound
      ],
      predicate: (e, _) => e is! NotFoundError,
    );
    await dispatchAndCatch(store, action);

    expect(action.reduceCount, 3);
    expect(action.shouldRetryCalls.map((call) => call.$2), [1, 2, 3]);
    expect(action.status.isCompletedFailed, isTrue);
    expect(action.status.originalError, same(notFound));
    expect(store.state.text, '');
  });

  Bdd(feature)
      .scenario('With UnlimitedRetryCheckInternet, "shouldRetry" is not called while '
          'there is no internet.')
      .given('An action with the UnlimitedRetryCheckInternet mixin, whose "shouldRetry" '
          'always returns false.')
      .and('There is no internet for the first 3 checks, and then there is.')
      .and('Its reducer always succeeds.')
      .when('The action is dispatched.')
      .then(
          'The action keeps waiting for the internet, since "shouldRetry" is not called '
          'for the no-internet case.')
      .and('When the internet comes back, the reducer runs, and the action completes OK.')
      .run((_) async {
    var store = Store<State>(initialState: State(''));
    var action = LoadTextUnlimited(
      internet: [false, false, false, true],
      errors: [],
      predicate: (_, __) => false,
    );
    await dispatchAndCatch(store, action);

    expect(action.checks, 4);
    expect(action.shouldRetryCalls, isEmpty);
    expect(action.reduceCount, 1);
    expect(action.status.isCompletedOk, isTrue);
    expect(store.state.text, 'A');
  });

  Bdd(feature)
      .scenario('With UnlimitedRetryCheckInternet, the attempt number given to '
          '"shouldRetry" also counts the no-internet attempts.')
      .given('An action with the UnlimitedRetryCheckInternet mixin.')
      .and('There is no internet for the first 2 checks, and then there is.')
      .and('Its reducer fails once with a UserException, then succeeds.')
      .when('The action is dispatched.')
      .then('"shouldRetry" is called once, with attempt number 3: two attempts aborted '
          'for no internet, plus the one that failed.')
      .and('This is the same number as "action.attempts".')
      .run((_) async {
    var store = Store<State>(initialState: State(''));
    var error = const UserException('Failed');
    var action = LoadTextUnlimited(
      internet: [false, false, true],
      errors: [error],
      predicate: (_, __) => true,
    );
    await dispatchAndCatch(store, action);

    expect(action.shouldRetryCalls, [(error, 3)]);
    expect(action.attempts, 3);
    expect(action.status.isCompletedOk, isTrue);
  });

  // ---------------------------------------------------------------------------
  // OptimisticCommand with Retry

  Bdd(feature)
      .scenario('An OptimisticCommand with Retry retries every error by default, '
          'including a UserException.')
      .given(
          'An OptimisticCommand with the Retry mixin, that does not override "shouldRetry".')
      .and('Its server call fails with a UserException twice, then succeeds.')
      .when('The command is dispatched.')
      .then('The server call runs 3 times, the optimistic value stays, and the command '
          'completes OK.')
      .run((_) async {
    var store = Store<State>(initialState: State('old'));
    var action =
        SaveText(errors: [const UserException('Failed'), const UserException('Failed')]);
    await dispatchAndCatch(store, action);

    expect(action.sendCount, 3);
    expect(action.attempts, 2);
    expect(action.changes, ['new']);
    expect(action.status.isCompletedOk, isTrue);
    expect(store.state.text, 'new');
  });

  Bdd(feature)
      .scenario('An OptimisticCommand with Retry gives up right away when "shouldRetry" '
          'returns false: it rolls back and fails.')
      .given('An OptimisticCommand with the Retry mixin, and up to 3 retries.')
      .and('Its "shouldRetry" returns false for a NotFoundError.')
      .and('Its server call always fails with a NotFoundError.')
      .when('The command is dispatched.')
      .then('The server call runs only once.')
      .and('The optimistic value is applied, and then rolled back.')
      .and('The command fails with the NotFoundError.')
      .run((_) async {
    var store = Store<State>(initialState: State('old'));
    var error = const NotFoundError();
    var action = SaveText(
      errors: [error, error, error, error],
      predicate: (e, _) => e is! NotFoundError,
    );
    await dispatchAndCatch(store, action);

    expect(action.sendCount, 1);
    expect(action.attempts, 1);
    expect(action.shouldRetryCalls, [(error, 1)]);
    expect(action.changes, ['new', 'old']);
    expect(action.status.isCompletedFailed, isTrue);
    expect(action.status.originalError, same(error));
    expect(store.state.text, 'old');
  });

  Bdd(feature)
      .scenario('An OptimisticCommand with Retry calls "shouldRetry" with the error and '
          'the attempt number of each failed server call.')
      .given('An OptimisticCommand with the Retry mixin, and up to 10 retries.')
      .and('Its server call always fails, with a different error each time.')
      .and(
          'Its "shouldRetry" returns true for the first 2 attempts, and false for the 3rd.')
      .when('The command is dispatched.')
      .then(
          '"shouldRetry" is called 3 times, with the error of each failed call, and the '
          'attempt numbers 1, 2 and 3.')
      .and('The server call runs 3 times, and the command fails with the error of the '
          '3rd call.')
      .run((_) async {
    var store = Store<State>(initialState: State('old'));
    var errors = [Exception('1'), Exception('2'), Exception('3'), Exception('4')];
    var action = SaveText(
      errors: errors,
      maxRetries: 10,
      predicate: (_, attempt) => attempt < 3,
    );
    await dispatchAndCatch(store, action);

    expect(action.shouldRetryCalls, [(errors[0], 1), (errors[1], 2), (errors[2], 3)]);
    expect(action.sendCount, 3);
    expect(action.status.originalError, same(errors[2]));
    expect(store.state.text, 'old');
  });

  // ---------------------------------------------------------------------------
  // An AbortDispatchException is never retried

  Bdd(feature)
      .scenario('An action with Retry that aborts itself is not retried, and '
          '"shouldRetry" is not called.')
      .given('An action with the Retry mixin, whose "shouldRetry" always returns true.')
      .and('Its reducer throws an AbortDispatchException.')
      .when('The action is dispatched.')
      .then('The reducer runs only once, and the action is aborted, not failed.')
      .and('"shouldRetry" is not called.')
      .run((_) async {
    var store = Store<State>(initialState: State(''));
    var action = LoadText(errors: [AbortDispatchException()], predicate: (_, __) => true);
    await dispatchAndCatch(store, action);

    expect(action.reduceCount, 1);
    expect(action.attempts, 0);
    expect(action.shouldRetryCalls, isEmpty);
    expect(action.status.isDispatchAborted, isTrue);
    expect(store.isFailed(LoadText), isFalse);
    expect(store.state.text, '');
  });

  Bdd(feature)
      .scenario('An action with UnlimitedRetryCheckInternet that aborts itself is not '
          'retried, and "shouldRetry" is not called.')
      .given('An action with the UnlimitedRetryCheckInternet mixin, whose "shouldRetry" '
          'always returns true, and there is internet.')
      .and('Its reducer throws an AbortDispatchException.')
      .when('The action is dispatched.')
      .then('The reducer runs only once, and the action is aborted, not failed.')
      .and('"shouldRetry" is not called.')
      .note('Before, the action would retry the AbortDispatchException forever.')
      .run((_) async {
    var store = Store<State>(initialState: State(''));
    var action = LoadTextUnlimited(
      internet: [true],
      errors: [AbortDispatchException()],
      predicate: (_, __) => true,
    );
    await dispatchAndCatch(store, action);

    expect(action.reduceCount, 1);
    expect(action.attempts, 0);
    expect(action.shouldRetryCalls, isEmpty);
    expect(action.status.isDispatchAborted, isTrue);
    expect(store.isFailed(LoadTextUnlimited), isFalse);
    expect(store.state.text, '');
  });

  Bdd(feature)
      .scenario(
          'An OptimisticCommand with Retry whose server call aborts is not retried: '
          'it rolls back and is aborted.')
      .given('An OptimisticCommand with the Retry mixin, whose "shouldRetry" always '
          'returns true.')
      .and('Its server call throws an AbortDispatchException.')
      .when('The command is dispatched.')
      .then('The server call runs only once.')
      .and('The optimistic value is applied, and then rolled back.')
      .and('The command is aborted, not failed, and "shouldRetry" is not called.')
      .run((_) async {
    var store = Store<State>(initialState: State('old'));
    var action = SaveText(errors: [AbortDispatchException()], predicate: (_, __) => true);
    await dispatchAndCatch(store, action);

    expect(action.sendCount, 1);
    expect(action.attempts, 0);
    expect(action.shouldRetryCalls, isEmpty);
    expect(action.changes, ['new', 'old']);
    expect(action.status.isDispatchAborted, isTrue);
    expect(store.isFailed(SaveText), isFalse);
    expect(store.state.text, 'old');
  });
}

// -----------------------------------------------------------------------------

/// Dispatches and waits. Errors that are not a `UserException` are rethrown by
/// `dispatchAndWait`, so they are caught here. The tests check the action status instead.
Future<void> dispatchAndCatch(Store<State> store, ReduxAction<State> action) async {
  try {
    await store.dispatchAndWait(action);
  } catch (_) {}
}

class State {
  final String text;

  State(this.text);

  @override
  String toString() => 'State($text)';
}

/// An error that is permanent: retrying it would fail again.
class NotFoundError implements Exception {
  const NotFoundError();
}

typedef Predicate = bool Function(Object error, int attempt);

/// An action with [Retry]. The reducer throws the [errors], one per attempt, and succeeds
/// after the last one. It records the calls to [shouldRetry] as `(error, attempt)` pairs.
/// When [predicate] is null, the default [shouldRetry] is used.
// ignore: async_redux_lints/retry_without_non_reentrant
class LoadText extends ReduxAction<State> with Retry {
  final List<Object> errors;
  final Predicate? predicate;
  final int _maxRetries;
  int reduceCount = 0;
  final List<(Object, int)> shouldRetryCalls = [];

  LoadText({required this.errors, this.predicate, int maxRetries = 3})
      : _maxRetries = maxRetries;

  @override
  Duration get initialDelay => const Duration(milliseconds: 1);

  @override
  int get maxRetries => _maxRetries;

  @override
  bool shouldRetry(Object error, int attempt) {
    shouldRetryCalls.add((error, attempt));
    return (predicate == null)
        ? super.shouldRetry(error, attempt)
        : predicate!(error, attempt);
  }

  @override
  Future<State> reduce() async {
    await microtask;
    final index = reduceCount++;
    if (index < errors.length) throw errors[index];
    return State('${state.text}A');
  }
}

/// An action with [UnlimitedRetryCheckInternet]. The [internet] list is the status of each
/// check. After the last one, the last status is repeated.
class LoadTextUnlimited extends ReduxAction<State> with UnlimitedRetryCheckInternet {
  final List<Object> errors;
  final List<bool> internet;
  final Predicate? predicate;
  int reduceCount = 0;
  int checks = 0;
  final List<(Object, int)> shouldRetryCalls = [];

  LoadTextUnlimited({required this.errors, required this.internet, this.predicate});

  @override
  Duration get initialDelay => const Duration(milliseconds: 1);

  @override
  void printRetries(String message) {}

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    final isOnline = internet[min(checks++, internet.length - 1)];
    return [isOnline ? ConnectivityResult.wifi : ConnectivityResult.none];
  }

  @override
  bool shouldRetry(Object error, int attempt) {
    shouldRetryCalls.add((error, attempt));
    return (predicate == null)
        ? super.shouldRetry(error, attempt)
        : predicate!(error, attempt);
  }

  @override
  Future<State> reduce() async {
    await microtask;
    final index = reduceCount++;
    if (index < errors.length) throw errors[index];
    return State('${state.text}A');
  }
}

/// An [OptimisticCommand] with [Retry]. The server call throws the [errors], one per call,
/// and succeeds after the last one. It records the values applied to the state in [changes].
class SaveText extends ReduxAction<State> with OptimisticCommand<State>, Retry<State> {
  final List<Object> errors;
  final Predicate? predicate;
  final int _maxRetries;
  int sendCount = 0;
  final List<String> changes = [];
  final List<(Object, int)> shouldRetryCalls = [];

  SaveText({required this.errors, this.predicate, int maxRetries = 3})
      : _maxRetries = maxRetries;

  @override
  Duration get initialDelay => const Duration(milliseconds: 1);

  @override
  int get maxRetries => _maxRetries;

  @override
  bool shouldRetry(Object error, int attempt) {
    shouldRetryCalls.add((error, attempt));
    return (predicate == null)
        ? super.shouldRetry(error, attempt)
        : predicate!(error, attempt);
  }

  @override
  Object? optimisticValue() => 'new';

  @override
  Object? getValueFromState(State state) => state.text;

  @override
  State applyValueToState(State state, Object? value) {
    changes.add(value as String);
    return State(value);
  }

  @override
  Future<void> sendCommandToServer(Object? newValue) async {
    final index = sendCount++;
    if (index < errors.length) throw errors[index];
  }
}
