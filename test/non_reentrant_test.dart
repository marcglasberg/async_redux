import 'package:async_redux/async_redux.dart';
import 'package:bdd_framework/bdd_framework.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var feature = BddFeature('Non reentrant actions');

  Bdd(feature)
      .scenario('Sync action non-reentrant does not call itself.')
      .given('A SYNC action that calls itself.')
      .and('The action is non-reentrant.')
      .when('The action is dispatched.')
      .then('It runs once.')
      .and('Does not result in a stack overflow.')
      .run((_) async {
    var store = Store<State>(initialState: State(1));

    expect(store.state.count, 1);
    store.dispatchSync(NonReentrantSyncActionCallsItself());
    expect(store.state.count, 2);
  });

  Bdd(feature)
      .scenario('Async action non-reentrant does not call itself.')
      .given('An ASYNC action that calls itself.')
      .and('The action is non-reentrant.')
      .when('The action is dispatched.')
      .then('It runs once.')
      .and('Does not result in a stack overflow.')
      .run((_) async {
    var store = Store<State>(initialState: State(1));

    expect(store.state.count, 1);
    store.dispatch(NonReentrantAsyncActionCallsItself());
    expect(store.state.count, 2);
  });

  Bdd(feature)
      .scenario('Async action non-reentrant does start before an action of the same type finished.')
      .given('An ASYNC action takes some time to finish.')
      .and('The action is non-reentrant.')
      .when('The action is dispatched.')
      .and('Another action of the same type is dispatched before the previous one finished.')
      .then('It runs only once.')
      .run((_) async {
    var store = Store<State>(initialState: State(1));

    // We start with count 1.
    expect(store.state.count, 1);
    expect(store.isWaiting(NonReentrantAsyncAction), false);

    // We dispatch an action that will wait for 100 millis and increment 10.
    store.dispatch(NonReentrantAsyncAction(10, 100));
    expect(store.isWaiting(NonReentrantAsyncAction), true);

    // So far, we still have count 1.
    expect(store.state.count, 1);

    // We wait a little bit and dispatch ANOTHER action that will wait for 10 millis and increment 50.
    await Future.delayed(const Duration(milliseconds: 10));
    store.dispatch(NonReentrantAsyncAction(50, 10));
    expect(store.isWaiting(NonReentrantAsyncAction), true);

    // We wait for all actions to finish dispatching.
    await store.waitAllActions();
    expect(store.isWaiting(NonReentrantAsyncAction), false);

    // The only action that ran was the first one, which incremented by 10 (1+10 = 11).
    // The second action was aborted.
    expect(store.state.count, 11);
  });
}

class State {
  final int count;

  State(this.count);

  @override
  String toString() => 'State($count)';
}

class NonReentrantSyncActionCallsItself extends ReduxAction<State> with NonReentrant {
  @override
  State reduce() {
    dispatch(NonReentrantSyncActionCallsItself());
    return State(state.count + 1);
  }
}

class NonReentrantAsyncActionCallsItself extends ReduxAction<State> with NonReentrant {
  @override
  Future<State> reduce() async {
    dispatch(NonReentrantSyncActionCallsItself());
    return State(state.count + 1);
  }
}

class NonReentrantAsyncAction extends ReduxAction<State> with NonReentrant {
  final int increment;
  final int delayMillis;

  NonReentrantAsyncAction(this.increment, this.delayMillis);

  @override
  Future<State> reduce() async {
    await Future.delayed(Duration(milliseconds: delayMillis));
    return State(state.count + increment);
  }
}
