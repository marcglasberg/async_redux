import 'package:async_redux/async_redux.dart'
    show NavigateAction, NavigateType, Store, StoreProvider;
import 'package:async_redux/src/wait_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Store<AppState> store;

class AppState {
  final Wait wait;

  AppState({this.wait});

  AppState copy({Wait wait}) => AppState(wait: wait);
}

class MyAction {}

///////////////////////////////////////////////////////////////////////////

void main() {
  setUp(() async {
    store = Store<AppState>(initialState: AppState(wait: Wait()));
  });

  ///////////////////////////////////////////////////////////////////////////

  test("Wait class is immutable. Empty object is always the same instance.", () {
    var wait1 = Wait();

    var wait2 = wait1.add(flag: "x");
    expect(wait1, isNot(wait2));

    var wait3 = wait2.remove(flag: "x");
    expect(wait3, wait1);
    expect(wait3, isNot(wait2));

    var wait4 = wait2.clear();
    expect(wait4, wait1);
    expect(wait4, isNot(wait2));
    expect(wait4, wait3);
  });

  ///////////////////////////////////////////////////////////////////////////

  test("Waiting for some action to finish.", () {
    var action = MyAction();
    expect(store.state.wait.isWaiting, false);
    expect(store.state.wait.isWaitingFor(action), false);

    store.dispatch(WaitAction.add(action));
    expect(store.state.wait.isWaiting, true);
    expect(store.state.wait.isWaitingFor(action), true);

    store.dispatch(WaitAction.remove(action));
    expect(store.state.wait.isWaiting, false);
    expect(store.state.wait.isWaitingFor(action), false);
  });

  ///////////////////////////////////////////////////////////////////////////

  test("Waiting for 2 actions to finish.", () {
    var action1 = MyAction();
    var action2 = MyAction();
    expect(store.state.wait.isWaiting, false);
    expect(store.state.wait.isWaitingFor(action1), false);
    expect(store.state.wait.isWaitingFor(action2), false);

    store.dispatch(WaitAction.add(action1));
    expect(store.state.wait.isWaiting, true);
    expect(store.state.wait.isWaitingFor(action1), true);
    expect(store.state.wait.isWaitingFor(action2), false);

    store.dispatch(WaitAction.add(action2));
    expect(store.state.wait.isWaiting, true);
    expect(store.state.wait.isWaitingFor(action1), true);
    expect(store.state.wait.isWaitingFor(action2), true);

    store.dispatch(WaitAction.remove(action1));
    expect(store.state.wait.isWaiting, true);
    expect(store.state.wait.isWaitingFor(action1), false);
    expect(store.state.wait.isWaitingFor(action2), true);

    store.dispatch(WaitAction.remove(action2));
    expect(store.state.wait.isWaiting, false);
    expect(store.state.wait.isWaitingFor(action1), false);
    expect(store.state.wait.isWaitingFor(action2), false);
  });

  ///////////////////////////////////////////////////////////////////////////

  test("Clear the waiting (everything).", () {
    var action = MyAction();
    expect(store.state.wait.isWaiting, false);
    expect(store.state.wait.isWaitingFor(action), false);

    store.dispatch(WaitAction.add(action));
    expect(store.state.wait.isWaiting, true);

    store.dispatch(WaitAction.clear());
    expect(store.state.wait.isWaiting, false);
    expect(store.state.wait.isWaitingFor(action), false);
  });

  ///////////////////////////////////////////////////////////////////////////

  test("Clear the waiting (a specific flag).", () {
    var action1 = MyAction();
    store.dispatch(WaitAction.add(action1, ref: "X"));
    store.dispatch(WaitAction.add(action1, ref: "Y"));

    var action2 = MyAction();
    store.dispatch(WaitAction.add(action2, ref: "X"));
    store.dispatch(WaitAction.add(action2, ref: "A"));

    expect(store.state.wait.isWaiting, true);
    expect(store.state.wait.isWaitingFor(action1), true);
    expect(store.state.wait.isWaitingFor(action2), true);

    store.dispatch(WaitAction.clear(action1));
    expect(store.state.wait.isWaiting, true);
    expect(store.state.wait.isWaitingFor(action1), false);
    expect(store.state.wait.isWaitingFor(action2), true);
  });

  ///////////////////////////////////////////////////////////////////////////

  test("Waiting for some action with ref and ref.", () {
    var action = MyAction();
    expect(store.state.wait.isWaiting, false);
    expect(store.state.wait.isWaitingFor(action), false);

    store.dispatch(WaitAction.add(action, ref: 123));
    expect(store.state.wait.isWaiting, true);
    expect(store.state.wait.isWaitingFor(action), true);

    store.dispatch(WaitAction.add(action, ref: 456));
    expect(store.state.wait.isWaiting, true);
    expect(store.state.wait.isWaitingFor(action, ref: 123), true);
    expect(store.state.wait.isWaitingFor(action, ref: 456), true);
    expect(store.state.wait.isWaitingFor(action, ref: 789), false);
    expect(store.state.wait.isWaitingFor(action), true);

    /// Removing ref without ref removes ref (ignores subRefs).
    store.dispatch(WaitAction.remove(action));
    expect(store.state.wait.isWaiting, false);
    expect(store.state.wait.isWaitingFor(action, ref: 123), false);
    expect(store.state.wait.isWaitingFor(action, ref: 456), false);
    expect(store.state.wait.isWaitingFor(action, ref: 789), false);
    expect(store.state.wait.isWaitingFor(action), false);

    // ---

    // Now try again, removing ref by ref.

    action = MyAction();
    expect(store.state.wait.isWaiting, false);
    expect(store.state.wait.isWaitingFor(action), false);

    store.dispatch(WaitAction.add(action, ref: 123));
    expect(store.state.wait.isWaiting, true);
    expect(store.state.wait.isWaitingFor(action), true);

    store.dispatch(WaitAction.add(action, ref: 456));
    expect(store.state.wait.isWaiting, true);
    expect(store.state.wait.isWaitingFor(action), true);

    /// Removing ref with ref removes just the ref (until all are removed).
    store.dispatch(WaitAction.remove(action, ref: 123));
    expect(store.state.wait.isWaiting, true);
    expect(store.state.wait.isWaitingFor(action, ref: 123), false);
    expect(store.state.wait.isWaitingFor(action, ref: 456), true);
    expect(store.state.wait.isWaitingFor(action, ref: 789), false);
    expect(store.state.wait.isWaitingFor(action), true);

    store.dispatch(WaitAction.remove(action, ref: 456));
    expect(store.state.wait.isWaiting, false);
    expect(store.state.wait.isWaitingFor(action, ref: 123), false);
    expect(store.state.wait.isWaitingFor(action, ref: 456), false);
    expect(store.state.wait.isWaitingFor(action, ref: 789), false);
    expect(store.state.wait.isWaitingFor(action), false);
  });

  ///////////////////////////////////////////////////////////////////////////
}
