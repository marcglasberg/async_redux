import 'package:async_redux/async_redux.dart';
import 'package:bdd_framework/bdd_framework.dart';
import 'package:flutter_test/flutter_test.dart';

class State {
  final int count;

  State(this.count);

  @override
  String toString() => 'State($count)';
}

class ChangeAction extends ReduxAction<State> {
  final int newValue;

  ChangeAction(this.newValue);

  @override
  State reduce() => State(newValue);
}

class IncrementSync extends ReduxAction<State> {
  String result = '';

  @override
  void before() {
    result += 'before initialState: $initialState|';
    result += 'before state: $state|';
    dispatch(ChangeAction(42));
    result += 'before initialState: $initialState|';
    result += 'before state: $state|';
  }

  @override
  State reduce() {
    result += 'reduce initialState: $initialState|';
    result += 'reduce state: $state|';
    dispatch(ChangeAction(100));
    result += 'reduce initialState: $initialState|';
    result += 'reduce state: $state|';
    return State(state.count + 1);
  }

  @override
  void after() {
    result += 'after initialState: $initialState|';
    result += 'after state: $state|';
    dispatch(ChangeAction(1350));
    result += 'after initialState: $initialState|';
    result += 'after state: $state|';
  }
}

class IncrementAsync extends ReduxAction<State> {
  String result = '';

  @override
  Future<void> before() async {
    result += 'before initialState: $initialState|';
    result += 'before state: $state|';
    dispatch(ChangeAction(42));
    result += 'before initialState: $initialState|';
    result += 'before state: $state|';
  }

  @override
  Future<State> reduce() async {
    result += 'reduce initialState: $initialState|';
    result += 'reduce state: $state|';
    dispatch(ChangeAction(100));
    result += 'reduce initialState: $initialState|';
    result += 'reduce state: $state|';
    return State(state.count + 1);
  }

  @override
  void after() {
    result += 'after initialState: $initialState|';
    result += 'after state: $state|';
    dispatch(ChangeAction(1350));
    result += 'after initialState: $initialState|';
    result += 'after state: $state|';
  }
}

void main() {
  var feature = BddFeature('Action initial state');

  Bdd(feature)
      .scenario('The action has access to its initial state.')
      .given('SYNC and ASYNC actions.')
      .when('The "before" and "reduce" and "after" methods are called.')
      .then('They have access to the store state as it was when the action was dispatched.')
      .note('The action initial state has nothing to do with the store initial state.')
      .run((_) async {
    // SYNC
    var store = Store<State>(initialState: State(1));

    var actionSync = IncrementSync();
    store.dispatch(actionSync);

    expect(
        actionSync.result,
        'before initialState: State(1)|'
        'before state: State(1)|'
        'before initialState: State(1)|'
        'before state: State(42)|'
        'reduce initialState: State(1)|'
        'reduce state: State(42)|'
        'reduce initialState: State(1)|'
        'reduce state: State(100)|'
        'after initialState: State(1)|'
        'after state: State(101)|'
        'after initialState: State(1)|'
        'after state: State(1350)|');

    // ASYNC
    store = Store<State>(initialState: State(1));

    var actionAsync = IncrementAsync();
    await store.dispatchAndWait(actionAsync);

    expect(
        actionAsync.result,
        'before initialState: State(1)|'
        'before state: State(1)|'
        'before initialState: State(1)|'
        'before state: State(42)|'
        'reduce initialState: State(1)|'
        'reduce state: State(42)|'
        'reduce initialState: State(1)|'
        'reduce state: State(100)|'
        'after initialState: State(1)|'
        'after state: State(101)|'
        'after initialState: State(1)|'
        'after state: State(1350)|');
  });
}
