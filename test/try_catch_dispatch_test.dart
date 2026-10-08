import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:bdd_framework/bdd_framework.dart';
import 'package:flutter_test/flutter_test.dart';

// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

/// Documents which combinations of action type (sync/async), exception type
/// (UserException/custom), and dispatch method (dispatch/dispatchAndWait) let
/// the caller catch the error with a plain `try/catch` around the dispatch.
void main() {
  var feature = BddFeature('Catching action errors with try/catch around dispatch');

  // ---------------------------------------------------------------------------
  // dispatch (not awaited)
  // ---------------------------------------------------------------------------

  Bdd(feature)
      .scenario('dispatch: sync action throwing a custom exception.')
      .given('A sync action that throws a custom (non-UserException) exception.')
      .when('It is dispatched with `try { dispatch(...) } catch`.')
      .then('The error IS caught.')
      .run((_) async {
    var result = await _tryCatch((store) {
      store.dispatch(SyncAction(MyException()));
    });
    expect(result, Outcome.caught);
  });

  Bdd(feature)
      .scenario('dispatch: sync action throwing a UserException.')
      .given('A sync action that throws a UserException.')
      .when('It is dispatched with `try { dispatch(...) } catch`.')
      .then(
          'The error is NOT caught: the store swallows it (it goes to the error queue).')
      .run((_) async {
    var result = await _tryCatch((store) {
      store.dispatch(SyncAction(const UserException('msg')));
    });
    expect(result, Outcome.swallowed);
  });

  Bdd(feature)
      .scenario('dispatch: async action throwing a custom exception.')
      .given('An async action that throws a custom (non-UserException) exception.')
      .when('It is dispatched with `try { dispatch(...) } catch`.')
      .then('The error is NOT caught: it escapes as an uncaught async error.')
      .run((_) async {
    var result = await _tryCatch((store) {
      store.dispatch(AsyncAction(MyException()));
    });
    expect(result, Outcome.uncaught);
  });

  Bdd(feature)
      .scenario('dispatch: async action throwing a UserException.')
      .given('An async action that throws a UserException.')
      .when('It is dispatched with `try { dispatch(...) } catch`.')
      .then(
          'The error is NOT caught: the store swallows it (it goes to the error queue).')
      .run((_) async {
    var result = await _tryCatch((store) {
      store.dispatch(AsyncAction(const UserException('msg')));
    });
    expect(result, Outcome.swallowed);
  });

  // ---------------------------------------------------------------------------
  // dispatchAndWait (awaited)
  // ---------------------------------------------------------------------------

  Bdd(feature)
      .scenario('dispatchAndWait: sync action throwing a custom exception.')
      .given('A sync action that throws a custom (non-UserException) exception.')
      .when('It is dispatched with `try { await dispatchAndWait(...) } catch`.')
      .then('The error IS caught.')
      .run((_) async {
    var result = await _tryCatch((store) async {
      await store.dispatchAndWait(SyncAction(MyException()));
    });
    expect(result, Outcome.caught);
  });

  Bdd(feature)
      .scenario('dispatchAndWait: sync action throwing a UserException.')
      .given('A sync action that throws a UserException.')
      .when('It is dispatched with `try { await dispatchAndWait(...) } catch`.')
      .then(
          'The error is NOT caught: the store swallows it (it goes to the error queue).')
      .run((_) async {
    var result = await _tryCatch((store) async {
      await store.dispatchAndWait(SyncAction(const UserException('msg')));
    });
    expect(result, Outcome.swallowed);
  });

  Bdd(feature)
      .scenario('dispatchAndWait: async action throwing a custom exception.')
      .given('An async action that throws a custom (non-UserException) exception.')
      .when('It is dispatched with `try { await dispatchAndWait(...) } catch`.')
      .then('The error IS caught.')
      .run((_) async {
    var result = await _tryCatch((store) async {
      await store.dispatchAndWait(AsyncAction(MyException()));
    });
    expect(result, Outcome.caught);
  });

  Bdd(feature)
      .scenario('dispatchAndWait: async action throwing a UserException.')
      .given('An async action that throws a UserException.')
      .when('It is dispatched with `try { await dispatchAndWait(...) } catch`.')
      .then(
          'The error is NOT caught: the store swallows it (it goes to the error queue).')
      .run((_) async {
    var result = await _tryCatch((store) async {
      await store.dispatchAndWait(AsyncAction(const UserException('msg')));
    });
    expect(result, Outcome.swallowed);
  });
}

enum Outcome {
  /// The `catch` block received the error.
  caught,

  /// The error escaped the `try/catch` and surfaced as an uncaught zone error.
  uncaught,

  /// Nobody saw the error: the store handled it internally.
  swallowed,
}

/// Runs [body] inside `try/catch`, in a guarded zone, with a default store.
/// Returns where the error ended up.
Future<Outcome> _tryCatch(FutureOr<void> Function(Store<int> store) body) async {
  var store = Store<int>(initialState: 0);
  bool caught = false;
  bool uncaught = false;

  await runZonedGuarded(() async {
    try {
      await body(store);
    } catch (_) {
      caught = true;
    }
    // Give async actions time to finish and any escaped error time to surface.
    await Future.delayed(const Duration(milliseconds: 50));
  }, (error, stackTrace) {
    uncaught = true;
  });

  if (caught) return Outcome.caught;
  if (uncaught) return Outcome.uncaught;
  return Outcome.swallowed;
}

class MyException implements Exception {}

class SyncAction extends ReduxAction<int> {
  final Object error;

  SyncAction(this.error);

  @override
  int reduce() => throw error;
}

class AsyncAction extends ReduxAction<int> {
  final Object error;

  AsyncAction(this.error);

  @override
  Future<int> reduce() async {
    await Future.delayed(const Duration(milliseconds: 10));
    throw error;
  }
}
