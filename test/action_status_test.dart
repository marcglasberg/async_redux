import 'dart:async';

import 'package:async_redux/async_redux.dart';
import "package:test/test.dart";

// Developed by Marcelo Glasberg (Aug 2019).
// For more info, see: https://pub.dartlang.org/packages/async_redux

///////////////////////////////////////////////////////////////////////////////

List<String> info;

enum When { before, reduce, after }

void main() {
  /////////////////////////////////////////////////////////////////////////////

  test('Test detecting that the BEFORE method of an action threw an error.', () async {
    //
    info = [];
    Store<String> store = Store<String>(initialState: "");

    var actionA = MyAction(whenToThrow: When.before);
    store.dispatch(actionA);
    expect(actionA.status.isBeforeDone, false);
    expect(actionA.status.isReduceDone, false);
    expect(actionA.status.isAfterDone, true);
    expect(actionA.hasFinished, false);
  });

  /////////////////////////////////////////////////////////////////////////////

  test('Test detecting that the REDUCE method of an action threw an error.', () async {
    //
    info = [];
    Store<String> store = Store<String>(initialState: "");

    var actionA = MyAction(whenToThrow: When.reduce);
    store.dispatch(actionA);
    expect(actionA.status.isBeforeDone, true);
    expect(actionA.status.isReduceDone, false);
    expect(actionA.status.isAfterDone, true);
    expect(actionA.hasFinished, false);
  });

  /////////////////////////////////////////////////////////////////////////////

  test(
      "Test detecting that the AFTER method of an action threw an error. "
      "An AFTER method shouldn't throw. But if it does, the error will be "
      "thrown asynchronously (after the async gap).", () async {
    //
    info = [];
    Store<String> store = Store<String>(initialState: "");

    var hasThrown = false;
    runZoned(() {
      var actionA = MyAction(whenToThrow: When.after);
      store.dispatch(actionA);
      expect(actionA.status.isBeforeDone, true);
      expect(actionA.status.isReduceDone, true);
      expect(actionA.status.isAfterDone, false);
      expect(actionA.hasFinished, false);
    }, onError: (error, stackTrace) {
      hasThrown = true;
      expect(error, const UserException("During after"));
    });

    await Future.delayed(const Duration(milliseconds: 10));
    expect(hasThrown, isTrue);
  });

  /////////////////////////////////////////////////////////////////////////////

  test('Test detecting that the action threw no errors.', () async {
    //
    info = [];
    Store<String> store = Store<String>(initialState: "");

    var actionA = MyAction(whenToThrow: null);
    store.dispatch(actionA);
    expect(actionA.status.isBeforeDone, true);
    expect(actionA.status.isReduceDone, true);
    expect(actionA.status.isAfterDone, true);
    expect(actionA.hasFinished, true);
  });

  /////////////////////////////////////////////////////////////////////////////
}

// ----------------------------------------------

class MyAction extends ReduxAction<String> {
  When whenToThrow;

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

// ----------------------------------------------
