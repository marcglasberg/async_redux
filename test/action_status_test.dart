import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:flutter_test/flutter_test.dart';

// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

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

    expect(actionA.status.hasFinishedMethodBefore, true);
    expect(actionA.status.hasFinishedMethodReduce, true);
    expect(actionA.status.hasFinishedMethodAfter, true);
    expect(actionA.status.isCompleted, true);
    expect(actionA.status.isCompletedOk, true);
    expect(actionA.status.isCompletedFailed, false);
    expect(actionA.status.originalError, isNull);
    expect(actionA.status.wrappedError, isNull);
  });

  test('The status.context contains the action and store after a successful dispatch.', () async {
    //
    info = [];
    Store<String> store = Store<String>(initialState: "");

    var actionA = MyAction(whenToThrow: null);
    store.dispatch(actionA);

    expect(actionA.status.context, isNotNull);
    var (action, ctxStore) = actionA.status.context!;
    expect(action, same(actionA));
    expect(ctxStore, same(store));
  });

  test('The status.context contains the action and store when the action threw an error.', () async {
    //
    info = [];
    Store<String> store = Store<String>(initialState: "");

    var actionA = MyAction(whenToThrow: When.before);
    store.dispatch(actionA);
    expect(actionA.status.isCompletedFailed, true);

    expect(actionA.status.context, isNotNull);
    var (action1, store1) = actionA.status.context!;
    expect(action1, same(actionA));
    expect(store1, same(store));

    var actionB = MyAction(whenToThrow: When.reduce);
    store.dispatch(actionB);
    expect(actionB.status.isCompletedFailed, true);

    expect(actionB.status.context, isNotNull);
    var (action2, store2) = actionB.status.context!;
    expect(action2, same(actionB));
    expect(store2, same(store));
  });

  test('The status.context contains the action and store when dispatch is aborted.', () async {
    //
    info = [];
    Store<String> store = Store<String>(initialState: "");

    var actionA = MyAbortAction();
    ActionStatus returnedStatus = await store.dispatchAndWait(actionA);
    expect(returnedStatus.isDispatchAborted, true);

    expect(returnedStatus.context, isNotNull);
    var (action, ctxStore) = returnedStatus.context!;
    expect(action, same(actionA));
    expect(ctxStore, same(store));
  });

  test('The status.context is null before the action is dispatched.', () async {
    //
    var actionA = MyAction(whenToThrow: null);
    expect(actionA.status.context, isNull);
  });

  test('thenIfCompletedOk runs the callback only when the action succeeds.', () async {
    //
    info = [];
    Store<String> store = Store<String>(initialState: "");

    // Action succeeds: the callback runs, and gets the status.
    ActionStatus? okStatus;
    var status = await store
        .dispatchAndWait(MyAction(whenToThrow: null))
        .thenIfCompletedOk((status) => okStatus = status);

    expect(okStatus, isNotNull);
    expect(okStatus!.isCompletedOk, true);

    // The returned future completes with the same status.
    expect(status, same(okStatus));

    // Action fails: the callback does NOT run.
    okStatus = null;
    status = await store
        .dispatchAndWait(MyAction(whenToThrow: When.reduce))
        .thenIfCompletedOk((status) => okStatus = status);

    expect(okStatus, isNull);
    expect(status.isCompletedFailed, true);
  });

  test('thenIfCompletedFailed runs the callback only when the action fails.', () async {
    //
    info = [];
    Store<String> store = Store<String>(initialState: "");

    // Action fails: the callback runs, and gets the status with the error.
    ActionStatus? failedStatus;
    var status = await store
        .dispatchAndWait(MyAction(whenToThrow: When.reduce))
        .thenIfCompletedFailed((status) => failedStatus = status);

    expect(failedStatus, isNotNull);
    expect(failedStatus!.isCompletedFailed, true);
    expect(failedStatus!.wrappedError, const UserException('During reduce'));

    // The returned future completes with the same status.
    expect(status, same(failedStatus));

    // Action succeeds: the callback does NOT run.
    failedStatus = null;
    status = await store
        .dispatchAndWait(MyAction(whenToThrow: null))
        .thenIfCompletedFailed((status) => failedStatus = status);

    expect(failedStatus, isNull);
    expect(status.isCompletedOk, true);
  });

  test('thenIfCompletedOk and thenIfCompletedFailed can be chained together.', () async {
    //
    info = [];
    Store<String> store = Store<String>(initialState: "");

    var result = <String>[];

    await store
        .dispatchAndWait(MyAction(whenToThrow: null))
        .thenIfCompletedOk((_) => result.add('ok'))
        .thenIfCompletedFailed((_) => result.add('failed'));

    expect(result, ['ok']);

    result = [];

    await store
        .dispatchAndWait(MyAction(whenToThrow: When.before))
        .thenIfCompletedOk((_) => result.add('ok'))
        .thenIfCompletedFailed((_) => result.add('failed'));

    expect(result, ['failed']);
  });

  test('thenIfCompletedOk awaits async callbacks before completing.', () async {
    //
    info = [];
    Store<String> store = Store<String>(initialState: "");

    var result = <String>[];

    await store.dispatchAndWait(MyAction(whenToThrow: null)).thenIfCompletedOk((_) async {
      await Future.delayed(const Duration(milliseconds: 10));
      result.add('callback');
    });
    result.add('after await');

    expect(result, ['callback', 'after await']);
  });

  test('Neither thenIfCompletedOk nor thenIfCompletedFailed run when dispatch is aborted.',
      () async {
    //
    info = [];
    Store<String> store = Store<String>(initialState: "");

    var result = <String>[];

    var status = await store
        .dispatchAndWait(MyAbortAction())
        .thenIfCompletedOk((_) => result.add('ok'))
        .thenIfCompletedFailed((_) => result.add('failed'));

    expect(status.isDispatchAborted, true);
    expect(result, isEmpty);
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

class MyAbortAction extends ReduxAction<String> {
  @override
  bool abortDispatch() => true;

  @override
  String reduce() => state;
}

class MyGlobalWrapError<St> implements GlobalWrapError<St> {
  @override
  Object? wrap(error, stackTrace, action) => 'global wrapped error: $error';
}
