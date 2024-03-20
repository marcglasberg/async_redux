import 'package:async_redux/async_redux.dart';
import 'package:bdd_framework/bdd_framework.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var feature = BddFeature('DispatchSync');

  Bdd(feature)
      .scenario('DispatchSync only dispatches SYNC actions.')
      .given('A SYNC or ASYNC action.')
      .when('The action is dispatched with `dispatchSync(action)`.')
      .then('It throws a `StoreException` when the action is ASYNC.')
      .and('It fails synchronously.')
      .note('We have to separately test with async "before", async "reduce", '
          'and both "before" and "reduce" being async, because they fail in different ways.')
      .run((_) async {
    var store = Store<State>(initialState: State(1));

    // Works
    store.dispatchSync(IncrementSync());

    // Fails synchronously with a `StoreException`.
    expect(() => store.dispatchSync(IncrementAsyncBefore()), throwsA(isA<StoreException>()));
    expect(() => store.dispatchSync(IncrementAsyncReduce()), throwsA(isA<StoreException>()));
    expect(() => store.dispatchSync(IncrementAsyncBeforeReduce()), throwsA(isA<StoreException>()));
  });
}

class State {
  final int count;

  State(this.count);
}

class IncrementSync extends ReduxAction<State> {
  @override
  State reduce() => State(state.count + 1);
}

class IncrementAsyncBefore extends ReduxAction<State> {
  @override
  Future<void> before() async {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  @override
  State reduce() => State(state.count + 1);
}

class IncrementAsyncReduce extends ReduxAction<State> {
  @override
  Future<State> reduce() async {
    return State(state.count + 1);
  }
}

class IncrementAsyncBeforeReduce extends ReduxAction<State> {
  @override
  Future<void> before() async {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  @override
  Future<State> reduce() async {
    return State(state.count + 1);
  }
}
