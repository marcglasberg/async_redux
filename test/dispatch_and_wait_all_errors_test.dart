import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:bdd_framework/bdd_framework.dart';
import 'package:flutter_test/flutter_test.dart';

// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

List<String> log = [];

void main() {
  var feature = BddFeature('dispatchAndWaitAll when actions fail');

  setUp(() => log = []);

  Bdd(feature)
      .scenario('A sync action fails in the middle of the list.')
      .given(
          'A list with a sync action that succeeds, one that fails, and one that succeeds.')
      .when('The list is dispatched with dispatchAndWaitAll.')
      .then('All actions are dispatched.')
      .and('The error of the failed action is thrown.')
      .run((_) async {
    var result = await _run([Ok('ok1'), SyncFail(), Ok('ok2')]);
    expect(log, ['ok1', 'syncFail', 'ok2']);
    expect(result.caught, ['sync']);
    expect(result.uncaught, isEmpty);
  });

  Bdd(feature)
      .scenario('A sync action fails while an async action is still running.')
      .given('A list with an async action that succeeds, then a failing sync action.')
      .when('The list is dispatched with dispatchAndWaitAll.')
      .then('The error is only thrown after the async action finishes.')
      .run((_) async {
    var result = await _run([AsyncOk(), SyncFail(), Ok('ok2')]);
    expect(result.caught, ['sync']);
    // The async action had already finished when the error was caught.
    expect(result.logWhenCaught, containsAll(['asyncOk', 'syncFail', 'ok2']));
    expect(result.uncaught, isEmpty);
  });

  Bdd(feature)
      .scenario('A sync action and an async action both fail.')
      .given('A list with a failing async action, then a failing sync action.')
      .when('The list is dispatched with dispatchAndWaitAll.')
      .then('All actions are dispatched and waited for.')
      .and('One of the errors is thrown.')
      .and('The other error is not lost as an uncaught async error.')
      .run((_) async {
    var result = await _run([AsyncFail(), SyncFail(), Ok('ok2')]);
    expect(result.logWhenCaught, containsAll(['asyncFail', 'syncFail', 'ok2']));
    expect(result.caught, hasLength(1));
    expect(result.caught.single, anyOf('sync', 'async'));
    expect(result.uncaught, isEmpty);
  });

  Bdd(feature)
      .scenario('An async action fails in the middle of the list.')
      .given('A list with a sync action, a failing async action, and a sync action.')
      .when('The list is dispatched with dispatchAndWaitAll.')
      .then('All actions are dispatched.')
      .and('The error of the failed action is thrown.')
      .run((_) async {
    var result = await _run([Ok('ok1'), AsyncFail(), Ok('ok2')]);
    expect(result.logWhenCaught, ['ok1', 'ok2', 'asyncFail']);
    expect(result.caught, ['async']);
    expect(result.uncaught, isEmpty);
  });

  Bdd(feature)
      .scenario('No action fails.')
      .given('A list of sync and async actions that succeed.')
      .when('The list is dispatched with dispatchAndWaitAll.')
      .then('All actions finish and nothing is thrown.')
      .run((_) async {
    var result = await _run([Ok('ok1'), AsyncOk(), Ok('ok2')]);
    expect(log, ['ok1', 'ok2', 'asyncOk']);
    expect(result.caught, isEmpty);
    expect(result.uncaught, isEmpty);
  });
  var featureAll = BddFeature('dispatchAll when actions fail');

  Bdd(featureAll)
      .scenario('dispatchAll: A sync action fails in the middle of the list.')
      .given(
          'A list with a sync action that succeeds, one that fails, and one that succeeds.')
      .when('The list is dispatched with dispatchAll.')
      .then('All actions are dispatched.')
      .and('The error of the failed action is thrown.')
      .run((_) async {
    var result = await _runDispatchAll([Ok('ok1'), SyncFail(), Ok('ok2')]);
    expect(result.logWhenCaught, ['ok1', 'syncFail', 'ok2']);
    expect(result.caught, ['sync']);
    expect(result.uncaught, isEmpty);
  });

  Bdd(featureAll)
      .scenario('dispatchAll: Two sync actions fail.')
      .given('A list with two failing sync actions, and one that succeeds.')
      .when('The list is dispatched with dispatchAll.')
      .then('All actions are dispatched.')
      .and('Only the error of the first failed action is thrown.')
      .run((_) async {
    var result =
        await _runDispatchAll([SyncFail('first'), SyncFail('second'), Ok('ok2')]);
    expect(result.logWhenCaught, ['syncFail', 'syncFail', 'ok2']);
    expect(result.caught, ['first']);
    expect(result.uncaught, isEmpty);
  });

  Bdd(featureAll)
      .scenario('dispatchAll: An async action fails.')
      .given('A list with a sync action, a failing async action, and a sync action.')
      .when('The list is dispatched with dispatchAll.')
      .then('All actions are dispatched, and dispatchAll returns without throwing.')
      .and('The async error is not thrown by dispatchAll, since it does not wait.')
      .run((_) async {
    var result = await _runDispatchAll([Ok('ok1'), AsyncFail(), Ok('ok2')]);
    expect(result.caught, isEmpty);
    expect(log, ['ok1', 'ok2', 'asyncFail']);
    expect(result.uncaught, hasLength(1));
  });
}

/// Runs `try { dispatchAll(actions) } catch` in a guarded zone.
Future<_Result> _runDispatchAll(List<ReduxAction<int>> actions) async {
  var result = _Result();
  var done = Completer<void>();

  runZonedGuarded(() async {
    var store = Store<int>(initialState: 0);
    try {
      store.dispatchAll(actions);
    } on MyException catch (error) {
      result.caught.add(error.msg);
      result.logWhenCaught = List.of(log);
    }
    // Give async actions time to finish and any escaped error time to surface.
    await Future.delayed(const Duration(milliseconds: 50));
    done.complete();
  }, (error, stackTrace) => result.uncaught.add('$error'));

  await done.future.timeout(const Duration(seconds: 2));
  result.logWhenCaught ??= List.of(log);
  return result;
}

class _Result {
  final List<String> caught = [];
  final List<String> uncaught = [];
  List<String>? logWhenCaught;
}

/// Runs `try { await dispatchAndWaitAll(actions) } catch` in a guarded zone, and records
/// what was caught, what escaped as an uncaught error, and what had run when it was caught.
Future<_Result> _run(List<ReduxAction<int>> actions) async {
  var result = _Result();
  var done = Completer<void>();

  runZonedGuarded(() async {
    var store = Store<int>(initialState: 0);
    try {
      await store.dispatchAndWaitAll(actions);
    } on MyException catch (error) {
      result.caught.add(error.msg);
      result.logWhenCaught = List.of(log);
    }
    // Give any escaped error time to surface.
    await Future.delayed(const Duration(milliseconds: 50));
    done.complete();
  }, (error, stackTrace) => result.uncaught.add('$error'));

  await done.future.timeout(const Duration(seconds: 2));
  result.logWhenCaught ??= List.of(log);
  return result;
}

class MyException implements Exception {
  final String msg;

  MyException(this.msg);

  @override
  String toString() => 'MyException($msg)';
}

class Ok extends ReduxAction<int> {
  final String name;

  Ok(this.name);

  @override
  int reduce() {
    log.add(name);
    return state + 1;
  }
}

class SyncFail extends ReduxAction<int> {
  final String msg;

  SyncFail([this.msg = 'sync']);

  @override
  int reduce() {
    log.add('syncFail');
    throw MyException(msg);
  }
}

class AsyncOk extends ReduxAction<int> {
  @override
  Future<int> reduce() async {
    await Future.delayed(const Duration(milliseconds: 10));
    log.add('asyncOk');
    return state + 1;
  }
}

class AsyncFail extends ReduxAction<int> {
  @override
  Future<int> reduce() async {
    await Future.delayed(const Duration(milliseconds: 10));
    log.add('asyncFail');
    throw MyException('async');
  }
}
