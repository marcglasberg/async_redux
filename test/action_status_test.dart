import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:flutter_test/flutter_test.dart';

// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// For more info, see: https://pub.dartlang.org/packages/async_redux

late List<String> info;

enum When { before, reduce, after }

/// IMPORTANT:
/// These tests may print errors to the console. This is normal.
///
void main() {
  test('Test detecting that the BEFORE method of an action threw an error.', () async {
    //
    info = [];
    Store<String> store = Store<String>(initialState: "");

    var actionA = MyAction(whenToThrow: When.before);
    store.dispatch(actionA);
    expect(actionA.status.isBeforeDone, false);
    expect(actionA.status.isReduceDone, false);
    expect(actionA.status.isAfterDone, true);
    expect(actionA.isFinished, false);

    expect(actionA.status.hasFinishedMethodBefore, false);
    expect(actionA.status.hasFinishedMethodReduce, false);
    expect(actionA.status.hasFinishedMethodAfter, true);
    expect(actionA.status.isCompleted, true);
    expect(actionA.status.isCompletedOk, false);
    expect(actionA.status.isCompletedFailed, true);
    expect(actionA.status.originalError, const UserException('During before'));
    expect(actionA.status.wrappedError, const UserException('During before'));
  });

  test('Test detecting that the REDUCE method of an action threw an error.', () async {
    //
    info = [];
    Store<String> store = Store<String>(initialState: "");

    var actionA = MyAction(whenToThrow: When.reduce);
    store.dispatch(actionA);
    expect(actionA.status.isBeforeDone, true);
    expect(actionA.status.isReduceDone, false);
    expect(actionA.status.isAfterDone, true);
    expect(actionA.isFinished, false);

    expect(actionA.status.hasFinishedMethodBefore, true);
    expect(actionA.status.hasFinishedMethodReduce, false);
    expect(actionA.status.hasFinishedMethodAfter, true);
    expect(actionA.status.isCompleted, true);
    expect(actionA.status.isCompletedOk, false);
    expect(actionA.status.isCompletedFailed, true);
    expect(actionA.status.originalError, const UserException('During reduce'));
    expect(actionA.status.wrappedError, const UserException('During reduce'));
  });

  test('Test wrapping the error in the action.', () async {
    //
    info = [];
    Store<String> store = Store<String>(initialState: "");

    var actionA = MyActionWithWrapError(whenToThrow: When.reduce);
    try {
      store.dispatch(actionA);
    } catch (e) {
      // This is expected.
    }
    expect(actionA.status.isBeforeDone, true);
    expect(actionA.status.isReduceDone, false);
    expect(actionA.status.isAfterDone, true);
    expect(actionA.isFinished, false);

    expect(actionA.status.hasFinishedMethodBefore, true);
    expect(actionA.status.hasFinishedMethodReduce, false);
    expect(actionA.status.hasFinishedMethodAfter, true);
    expect(actionA.status.isCompleted, true);
    expect(actionA.status.isCompletedOk, false);
    expect(actionA.status.isCompletedFailed, true);
    expect(actionA.status.originalError, const UserException('During reduce'));
    expect(actionA.status.wrappedError, 'wrapped error in action: UserException{During reduce}');
  });

  test('Test wrapping the error globally with the globalWrapError (Store constructor).', () async {
    //
    info = [];
    Store<String> store = Store<String>(
      initialState: "",
      globalWrapError: MyGlobalWrapError<String>(),
    );

    var actionA = MyAction(whenToThrow: When.reduce);
    try {
      store.dispatch(actionA);
    } catch (e) {
      // This is expected.
    }
    expect(actionA.status.isBeforeDone, true);
    expect(actionA.status.isReduceDone, false);
    expect(actionA.status.isAfterDone, true);
    expect(actionA.isFinished, false);

    expect(actionA.status.hasFinishedMethodBefore, true);
    expect(actionA.status.hasFinishedMethodReduce, false);
    expect(actionA.status.hasFinishedMethodAfter, true);
    expect(actionA.status.isCompleted, true);
    expect(actionA.status.isCompletedOk, false);
    expect(actionA.status.isCompletedFailed, true);
    expect(actionA.status.originalError, const UserException('During reduce'));
    expect(actionA.status.wrappedError, 'global wrapped error: UserException{During reduce}');
  });

  test(
      "Test detecting that the AFTER method of an action threw an error. "
      "An AFTER method shouldn't throw. But if it does, the error will be "
      "thrown asynchronously (after the async gap).", () async {
    //
    info = [];
    Store<String> store = Store<String>(initialState: "");

    var hasThrown = false;
    runZonedGuarded(() {
      var actionA = MyAction(whenToThrow: When.after);
      store.dispatch(actionA);
      expect(actionA.status.isBeforeDone, true);
      expect(actionA.status.isReduceDone, true);
      expect(actionA.status.isAfterDone, true);
      expect(actionA.isFinished, true);

      expect(actionA.status.hasFinishedMethodBefore, true);
      expect(actionA.status.hasFinishedMethodReduce, true);
      expect(actionA.status.hasFinishedMethodAfter, true);
      expect(actionA.status.isCompleted, true);
      expect(actionA.status.isCompletedOk, true);
      expect(actionA.status.isCompletedFailed, false);
      expect(actionA.status.originalError, isNull);
      expect(actionA.status.wrappedError, isNull);
    }, (error, stackTrace) {
      hasThrown = true;

      expect(
          error,
          "Method 'MyAction.after()' has thrown an error:\n"
          " 'UserException{During after}'.:\n"
          "  UserException{During after}");
    });

    await Future.delayed(const Duration(milliseconds: 10));
    expect(hasThrown, isTrue);
  });

  test('Test detecting that the action threw no errors.', () async {
    //
    info = [];
    Store<String> store = Store<String>(initialState: "");

    var actionA = MyAction(whenToThrow: null);
    store.dispatch(actionA);
    expect(actionA.status.isBeforeDone, true);
    expect(actionA.status.isReduceDone, true);
    expect(actionA.status.isAfterDone, true);
    expect(actionA.isFinished, true);

    expect(actionA.status.hasFinishedMethodBefore, true);
    expect(actionA.status.hasFinishedMethodReduce, true);
    expect(actionA.status.hasFinishedMethodAfter, true);
    expect(actionA.status.isCompleted, true);
    expect(actionA.status.isCompletedOk, true);
    expect(actionA.status.isCompletedFailed, false);
    expect(actionA.status.originalError, isNull);
    expect(actionA.status.wrappedError, isNull);
  });
}

class MyAction extends ReduxAction<String> {
  When? whenToThrow;

  MyAction({this.whenToThrow});

  @override
  void before() {
    info.add('1');
    if (whenToThrow == When.before) throw const UserException("During before");
  }

  @override
  String reduce() {
    info.add('2');
    if (whenToThrow == When.reduce) throw const UserException("During reduce");
    return state + 'X';
  }

  @override
  void after() {
    if (whenToThrow == When.after) throw const UserException("During after");
    info.add('3');
  }
}

class MyActionWithWrapError extends ReduxAction<String> {
  When? whenToThrow;

  MyActionWithWrapError({this.whenToThrow});

  @override
  void before() {
    info.add('1');
    if (whenToThrow == When.before) throw const UserException("During before");
  }

  @override
  String reduce() {
    info.add('2');
    if (whenToThrow == When.reduce) throw const UserException("During reduce");
    return state + 'X';
  }

  @override
  void after() {
    if (whenToThrow == When.after) throw const UserException("During after");
    info.add('3');
  }

  @override
  Object? wrapError(Object error, StackTrace stackTrace) => 'wrapped error in action: $error';
}

class MyGlobalWrapError<St> implements GlobalWrapError<St> {
  @override
  Object? wrap(error, stackTrace, action) => 'global wrapped error: $error';
}
