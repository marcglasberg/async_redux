import 'package:async_redux/async_redux.dart';
import 'package:bdd_framework/bdd_framework.dart';
import 'package:flutter_test/flutter_test.dart';

// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// For more info, see: https://pub.dartlang.org/packages/async_redux

List<String>? info;

void main() {
  var feature = BddFeature('Abort dispatch of actions');

  test('Test aborting an action.', () async {
    //
    info = [];
    Store<String> store = Store<String>(initialState: "");

    store.dispatch(ActionA(abort: false));
    expect(store.state, "X");
    expect(info, ['1', '2', '3']);

    store.dispatch(ActionA(abort: false));
    expect(store.state, "XX");
    expect(info, ['1', '2', '3', '1', '2', '3']);

    // Won't dispatch, because abortDispatch checks the abort flag.
    store.dispatch(ActionA(abort: true));
    expect(store.state, "XX");
    expect(info, ['1', '2', '3', '1', '2', '3']);
  });

  test('Test aborting an action, where the abortDispatch method accesses the state.', () async {
    //
    info = [];
    Store<String> store = Store<String>(initialState: "");

    store.dispatch(ActionB());
    expect(store.state, "X");
    expect(info, ['1', '2', '3']);

    store.dispatch(ActionB());
    expect(store.state, "XX");
    expect(info, ['1', '2', '3', '1', '2', '3']);

    // Won't dispatch, because abortDispatch checks that the state has length 2.
    store.dispatch(ActionB());
    expect(store.state, "XX");
    expect(info, ['1', '2', '3', '1', '2', '3']);
  });

  Bdd(feature)
      .scenario('The action can abort its own dispatch.')
      .given('An action that returns true (or false) in its abortDispatch method.')
      .when('The action is dispatched (with dispatch, or dispatchSync, or dispatchAndWait).')
      .then('It is aborted (or is not aborted, respectively).')
      .note(
          'We have to test dispatch/dispatchSync/dispatchAndWait separately, because they abort in different ways.')
      .run((_) async {
    // Dispatch
    var store = Store<State>(initialState: State(1));

    // Doesn't abort, so it increments.
    store.dispatch(Increment(false));
    expect(store.state.count, 2);

    // Aborts, so it doesn't change.
    store.dispatch(Increment(true));
    expect(store.state.count, 2);

    // Doesn't abort, so it increments again.
    store.dispatch(Increment(false));
    expect(store.state.count, 3);

    // DispatchSync
    store = Store<State>(initialState: State(1));

    // Doesn't abort, so it increments.
    store.dispatchSync(Increment(false));
    expect(store.state.count, 2);

    // Aborts, so it doesn't change.
    store.dispatchSync(Increment(true));
    expect(store.state.count, 2);

    // Doesn't abort, so it increments again.
    store.dispatchSync(Increment(false));
    expect(store.state.count, 3);

    // DispatchAndWait
    store = Store<State>(initialState: State(1));

    // Doesn't abort, so it increments.
    await store.dispatchAndWait(Increment(false));
    expect(store.state.count, 2);

    // Aborts, so it doesn't change.
    await store.dispatchAndWait(Increment(true));
    expect(store.state.count, 2);

    // Doesn't abort, so it increments again.
    await store.dispatchAndWait(Increment(false));
    expect(store.state.count, 3);
  });
}

class ActionA extends ReduxAction<String> {
  bool abort;

  ActionA({required this.abort});

  @override
  bool abortDispatch() => abort;

  @override
  void before() {
    info!.add('1');
  }

  @override
  String reduce() {
    info!.add('2');
    return state + 'X';
  }

  @override
  void after() {
    info!.add('3');
  }
}

class ActionB extends ReduxAction<String> {
  @override
  bool abortDispatch() => state.length >= 2;

  @override
  void before() {
    info!.add('1');
  }

  @override
  String reduce() {
    info!.add('2');
    return state + 'X';
  }

  @override
  void after() {
    info!.add('3');
  }
}

class State {
  final int count;

  State(this.count);

  @override
  String toString() => 'State($count)';
}

class Increment extends ReduxAction<State> {
  final bool ifAbort;

  Increment(this.ifAbort);

  @override
  bool abortDispatch() => ifAbort;

  @override
  State reduce() => State(state.count + 1);
}
