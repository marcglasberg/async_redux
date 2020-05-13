import 'dart:async';

import 'package:async_redux/async_redux.dart';
import "package:test/test.dart";

// Developed by Marcelo Glasberg (Aug 2019).
// For more info, see: https://pub.dartlang.org/packages/async_redux

///////////////////////////////////////////////////////////////////////////////

List<String> info;

void main() {
  /////////////////////////////////////////////////////////////////////////////

  test('Method call sequence for sync reducer.', () async {
    //
    info = [];
    Store<String> store = Store<String>(initialState: "");
    store.dispatch(ActionA());
    expect(store.state, "A");
    expect(info, [
      'A.before state=""',
      'A.reduce state=""',
      'A.after state="A"',
    ]);
  });

  /////////////////////////////////////////////////////////////////////////////

  test(
      'Method call sequence for async reducer. '
      'The reducer is async because the method returns Future.', () async {
    //
    info = [];
    Store<String> store = Store<String>(initialState: "");
    await store.dispatchFuture(ActionB());
    expect(store.state, "B");
    expect(info, [
      'B.before state=""',
      'B.reduce state=""',
      'B.reduce state=""',
      'B.after state="B"',
    ]);
  });

  /////////////////////////////////////////////////////////////////////////////

  test(
      'Method call sequence for async reducer. '
      'The reducer is async because the REDUCE method returns Future.', () async {
    //
    info = [];
    Store<String> store = Store<String>(initialState: "");

    // B is dispatched first, but will finish last, because it's async.
    var f1 = store.dispatchFuture(ActionB());
    var f2 = store.dispatchFuture(ActionA());

    await Future.wait([f1, f2]);
    expect(store.state, "AB");
    expect(info, [
      'B.before state=""',
      'B.reduce state=""',
      'A.before state=""',
      'A.reduce state=""',
      'A.after state="A"',
      'B.reduce state="A"',
      'B.after state="AB"'
    ]);
  });

  /////////////////////////////////////////////////////////////////////////////

  test(
      'Method call sequence for async reducer. '
      'The reducer is async because the BEFORE method returns Future.', () async {
    //
    info = [];
    Store<String> store = Store<String>(initialState: "");

    // C is dispatched first, but will finish last, because it's async.
    var f1 = store.dispatchFuture(ActionC());
    var f2 = store.dispatchFuture(ActionA());

    await Future.wait([f1, f2]);
    expect(store.state, "AC");
    expect(info, [
      'C.before state=""',
      'A.before state=""',
      'A.reduce state=""',
      'A.after state="A"',
      'C.reduce state="A"',
      'C.after state="AC"'
    ]);
  });

  /////////////////////////////////////////////////////////////////////////////

  test(
      'Method call sequence for async reducer. '
      'The reducer is async because the BEFORE method returns Future.'
      'Shows what happens if the before method actually awaits.', () async {
    //
    info = [];
    Store<String> store = Store<String>(initialState: "");

    // D is dispatched first, but will finish last, because it's async.
    var f1 = store.dispatchFuture(ActionD());
    var f2 = store.dispatchFuture(ActionA());

    await Future.wait([f1, f2]);
    expect(store.state, "AD");
    expect(info, [
      'D.before state=""',
      'A.before state=""',
      'A.reduce state=""',
      'A.after state="A"',
      'D.before state="A"',
      'D.reduce state="A"',
      'D.after state="AD"'
    ]);
  });

  /////////////////////////////////////////////////////////////////////////////

  test(
      'What happens when the after method of a sync reducer dispatches another action? '
      'The state is changed by the reduce method before the after method is executed.', () async {
    //
    info = [];
    Store<String> store = Store<String>(initialState: "");
    await store.dispatchFuture(ActionE());

    //
    expect(store.state, "EA");
    expect(info, [
      'E.before state=""',
      'E.reduce state=""',
      'E.after state="E"',
      'A.before state="E"',
      'A.reduce state="E"',
      'A.after state="EA"',
      'E.after state="EA"'
    ]);
  });

  /////////////////////////////////////////////////////////////////////////////

  test(
      'What happens when the after method of a async reducer dispatches another action? '
      'The state is changed by the reduce method before the after method is executed.', () async {
    //
    info = [];
    Store<String> store = Store<String>(initialState: "");
    await store.dispatchFuture(ActionF());

    //
    expect(store.state, "FA");
    expect(info, [
      'F.before state=""',
      'F.reduce state=""',
      'F.reduce state=""',
      'F.after state="F"',
      'A.before state="F"',
      'A.reduce state="F"',
      'A.after state="FA"',
      'F.after state="FA"'
    ]);
  });

  /////////////////////////////////////////////////////////////////////////////

  /////////////////////////////////////////////////////////////////////////////
}

// ----------------------------------------------

class ActionA extends ReduxAction<String> {
  @override
  void before() {
    info.add('A.before state="$state"');
  }

  @override
  String reduce() {
    info.add('A.reduce state="$state"');
    return state + 'A';
  }

  @override
  void after() {
    info.add('A.after state="$state"');
  }
}

// ----------------------------------------------

class ActionB extends ReduxAction<String> {
  @override
  void before() {
    info.add('B.before state="$state"');
  }

  @override
  Future<String> reduce() async {
    info.add('B.reduce state="$state"');
    await Future.delayed(const Duration(milliseconds: 50));
    info.add('B.reduce state="$state"');
    return state + 'B';
  }

  @override
  void after() {
    info.add('B.after state="$state"');
  }
}

// ----------------------------------------------

class ActionC extends ReduxAction<String> {
  @override
  Future<void> before() async {
    info.add('C.before state="$state"');
  }

  @override
  String reduce() {
    info.add('C.reduce state="$state"');
    return state + 'C';
  }

  @override
  void after() {
    info.add('C.after state="$state"');
  }
}

// ----------------------------------------------

class ActionD extends ReduxAction<String> {
  @override
  Future<void> before() async {
    info.add('D.before state="$state"');
    await Future.delayed(const Duration(milliseconds: 10));
    info.add('D.before state="$state"');
  }

  @override
  String reduce() {
    info.add('D.reduce state="$state"');
    return state + 'D';
  }

  @override
  void after() {
    info.add('D.after state="$state"');
  }
}

// ----------------------------------------------

class ActionE extends ReduxAction<String> {
  @override
  void before() async {
    info.add('E.before state="$state"');
  }

  @override
  String reduce() {
    info.add('E.reduce state="$state"');
    return state + 'E';
  }

  @override
  void after() {
    info.add('E.after state="$state"');
    store.dispatch(ActionA());
    info.add('E.after state="$state"');
  }
}

// ----------------------------------------------

class ActionF extends ReduxAction<String> {
  @override
  void before() async {
    info.add('F.before state="$state"');
  }

  @override
  Future<String> reduce() async {
    info.add('F.reduce state="$state"');
    await Future.delayed(const Duration(milliseconds: 10));
    info.add('F.reduce state="$state"');
    return state + 'F';
  }

  @override
  void after() {
    info.add('F.after state="$state"');
    store.dispatch(ActionA());
    info.add('F.after state="$state"');
  }
}

// ----------------------------------------------
