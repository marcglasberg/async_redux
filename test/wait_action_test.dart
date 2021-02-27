import 'package:async_redux/async_redux.dart';
import 'package:async_redux/src/wait.dart';
import 'package:async_redux/src/wait_action.dart';
import 'package:flutter_test/flutter_test.dart';

late Store<AppState> store;

///////////////////////////////////////////////////////////////////////////

class AppState {
  final Wait wait;

  AppState({this.wait = Wait.empty});

  AppState copy({Wait? wait}) => AppState(wait: wait ?? this.wait);
}

///////////////////////////////////////////////////////////////////////////

// This simulates using the Freezed package.
class AppStateFreezed {
  final Wait wait;

  AppStateFreezed({this.wait = Wait.empty});

  AppStateFreezed copyWith({Wait? wait}) => AppStateFreezed(wait: wait ?? this.wait);
}

///////////////////////////////////////////////////////////////////////////

// This simulates using the BuiltValue package.
class AppStateBuiltValue {
  Wait wait;

  AppStateBuiltValue({this.wait = Wait.empty});

  AppStateBuiltValue rebuild(dynamic func(dynamic state)) => func(AppStateBuiltValue(wait: Wait()));
}

///////////////////////////////////////////////////////////////////////////

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

  test("Test compatibility with the Freezed package.", () {
    Store<AppStateFreezed> freezedStore;
    freezedStore = Store<AppStateFreezed>(initialState: AppStateFreezed(wait: Wait()));

    var action = MyAction();
    expect(freezedStore.state.wait.isWaiting, false);
    expect(freezedStore.state.wait.isWaitingFor(action), false);

    freezedStore.dispatch(WaitAction.add(action));
    expect(freezedStore.state.wait.isWaiting, true);
    expect(freezedStore.state.wait.isWaitingFor(action), true);

    freezedStore.dispatch(WaitAction.remove(action));
    expect(freezedStore.state.wait.isWaiting, false);
    expect(freezedStore.state.wait.isWaitingFor(action), false);
  });

  ///////////////////////////////////////////////////////////////////////////

  test("Test compatibility with the BuiltValue package.", () {
    Store<AppStateBuiltValue> builtValueStore;
    builtValueStore = Store<AppStateBuiltValue>(initialState: AppStateBuiltValue(wait: Wait()));

    var action = MyAction();
    expect(builtValueStore.state.wait.isWaiting, false);
    expect(builtValueStore.state.wait.isWaitingFor(action), false);

    builtValueStore.dispatch(WaitAction.add(action));
    expect(builtValueStore.state.wait.isWaiting, true);
    expect(builtValueStore.state.wait.isWaitingFor(action), true);

    builtValueStore.dispatch(WaitAction.remove(action));
    expect(builtValueStore.state.wait.isWaiting, false);
    expect(builtValueStore.state.wait.isWaitingFor(action), false);
  });

  ///////////////////////////////////////////////////////////////////////////

  test("Test compatibility with the BuiltValue package.", () {
    Store<AppStateFreezed> freezedStore;
    freezedStore = Store<AppStateFreezed>(initialState: AppStateFreezed(wait: Wait()));

    var action = MyAction();
    expect(freezedStore.state.wait.isWaiting, false);
    expect(freezedStore.state.wait.isWaitingFor(action), false);

    freezedStore.dispatch(WaitAction.add(action));
    expect(freezedStore.state.wait.isWaiting, true);
    expect(freezedStore.state.wait.isWaitingFor(action), true);

    freezedStore.dispatch(WaitAction.remove(action));
    expect(freezedStore.state.wait.isWaiting, false);
    expect(freezedStore.state.wait.isWaitingFor(action), false);
  });

  ///////////////////////////////////////////////////////////////////////////
}
