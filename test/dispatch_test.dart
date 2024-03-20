import 'package:async_redux/async_redux.dart';
import 'package:bdd_framework/bdd_framework.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var feature = BddFeature('Dispatch');

  Bdd(feature)
      .scenario('Waiting for a dispatch to end.')
      .given('A SYNC or ASYNC action.')
      .when('The action is dispatched with `dispatch(action)`.')
      .then('The SYNC action changes the state synchronously.')
      .and('The ASYNC action changes the state asynchronously.')
      .run((_) async {
    final store = Store<State>(initialState: State(1));

    // The SYNC action changes the state synchronously.
    expect(store.state.count, 1);
    store.dispatch(IncrementSync());
    expect(store.state.count, 2);

    // The ASYNC action does NOT change the state synchronously.
    store.dispatch(IncrementAsync());
    expect(store.state.count, 2);

    // But the ASYNC action changes the state asynchronously.
    await Future.delayed(const Duration(milliseconds: 50));
    expect(store.state.count, 3);
  });

  Bdd(feature)
      .scenario('Knowing when some action dispatched with `dispatch` is being processed.')
      .given('A SYNC or ASYNC action.')
      .when('The action is dispatched.')
      .then('We can check if the action is processing with `Store.isWaiting(action)`.')
      .run((_) async {
    final store = Store<State>(initialState: State(1));

    // SYNC ACTION: isWaiting is always false.
    expect(store.isWaiting(IncrementSync), false);
    expect(store.state.count, 1);

    var actionSync = IncrementSync();
    store.dispatch(actionSync);
    expect(store.isWaiting(IncrementSync), false);
    expect(store.state.count, 2);

    // ASYNC ACTION: isWaiting is true while we wait for it to finish.
    expect(store.isWaiting(IncrementAsync), false);
    expect(store.state.count, 2);

    var actionAsync = IncrementAsync();
    store.dispatch(actionAsync);
    expect(store.isWaiting(IncrementAsync), true); // True!
    expect(store.state.count, 2);

    // Since it's ASYNC, it really waits until it finishes.
    await Future.delayed(const Duration(milliseconds: 50));

    expect(store.isWaiting(IncrementAsync), false);
    expect(store.state.count, 3);
  });
}

class State {
  final int count;

  State(this.count);
}

class IncrementSync extends ReduxAction<State> {
  @override
  State reduce() {
    return State(state.count + 1);
  }
}

class IncrementAsync extends ReduxAction<State> {
  @override
  Future<State> reduce() async {
    await Future.delayed(const Duration(milliseconds: 1));
    return State(state.count + 1);
  }
}
