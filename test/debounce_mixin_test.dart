import 'package:async_redux/async_redux.dart';
import 'package:bdd_framework/bdd_framework.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var feature = BddFeature('Debounce actions');

  Bdd(feature)
      .scenario(
          'Sync action is debounced when dispatched multiple times quickly')
      .given('A sync action with the Debounce mixin')
      .when(
          'The action is dispatched multiple times within the debounce period')
      .then('It should only execute once after the debounce period')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));
    store.dispatch(DebounceAction());
    store.dispatch(DebounceAction());
    store.dispatch(DebounceAction());
    expect(store.state.count, 0);

    // Wait for a bit more than the debounce period (150 ms).
    await Future.delayed(const Duration(milliseconds: 150));
    expect(store.state.count, 1);
  });

  Bdd(feature)
      .scenario(
          'Async action is debounced when dispatched multiple times quickly')
      .given('An async action with the Debounce mixin')
      .when(
          'The action is dispatched multiple times within the debounce period')
      .then('It should only execute once after the debounce period')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));
    store.dispatch(DebounceActionAsync());
    store.dispatch(DebounceActionAsync());
    store.dispatch(DebounceActionAsync());
    expect(store.state.count, 0);

    // Wait for a bit more than the debounce period (150 ms).
    await Future.delayed(const Duration(milliseconds: 150));
    expect(store.state.count, 1);
  });

  Bdd(feature)
      .scenario('A sync action executes again after debounce period expires')
      .given('A sync action with the Debounce mixin')
      .when('The action is dispatched, '
          'then after waiting for the debounce period, dispatched again')
      .then('Each dispatch should execute after the debounce period')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));
    store.dispatch(DebounceAction());
    expect(store.state.count, 0);

    // Wait for a bit more than the debounce period (150 ms).
    await Future.delayed(const Duration(milliseconds: 150));
    expect(store.state.count, 1);

    store.dispatch(DebounceAction());
    expect(store.state.count, 1);

    // Wait for a bit more than the debounce period (150 ms).
    await Future.delayed(const Duration(milliseconds: 150));
    expect(store.state.count, 2);
  });

  Bdd(feature)
      .scenario('An async action executes again after debounce period expires')
      .given('An async action with the Debounce mixin')
      .when('The action is dispatched, '
          'then after waiting for the debounce period, dispatched again')
      .then('Each dispatch should execute after the debounce period')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));
    store.dispatch(DebounceActionAsync());
    expect(store.state.count, 0);

    // Wait for a bit more than the debounce period (150 ms).
    await Future.delayed(const Duration(milliseconds: 150));
    expect(store.state.count, 1);

    store.dispatch(DebounceActionAsync());
    expect(store.state.count, 1);

    // Wait for a bit more than the debounce period (150 ms).
    await Future.delayed(const Duration(milliseconds: 150));
    expect(store.state.count, 2);
  });

  Bdd(feature)
      .scenario(
          'Sync actions with different runtime types are not debounced together')
      .given(
          'Two sync actions with the Debounce mixin but different runtime types')
      .when('Both actions are dispatched in quick succession')
      .then(
          'Each action should execute independently after their debounce periods')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));
    store.dispatch(DebounceActionA());
    store.dispatch(DebounceActionB());
    expect(store.state.count, 0);

    // The debounce period is 200ms.
    // Wait for a bit more than that, but less than double that: 300ms.
    await Future.delayed(const Duration(milliseconds: 300));
    expect(store.state.count, 2);
  });

  Bdd(feature)
      .scenario(
          'Async actions with different runtime types are not debounced together')
      .given(
          'Two async actions with the Debounce mixin but different runtime types')
      .when('Both actions are dispatched in quick succession')
      .then(
          'Each action should execute independently after their debounce periods')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));
    store.dispatch(DebounceActionAAsync());
    store.dispatch(DebounceActionBAsync());
    expect(store.state.count, 0);

    // The debounce period is 200ms.
    // Wait for a bit more than that, but less than double that: 300ms.
    await Future.delayed(const Duration(milliseconds: 300));
    expect(store.state.count, 2);
  });
}

// A simple state that holds a count.
class AppState {
  final int count;

  AppState(this.count);

  AppState copy({int? count}) => AppState(count ?? this.count);

  @override
  String toString() => 'AppState($count)';
}

// An action that uses the Debounce mixin to increment the state.
class DebounceAction extends ReduxAction<AppState> with Debounce {
  @override
  int debounce = 100;

  @override
  AppState reduce() {
    return state.copy(count: state.count + 1);
  }
}

// Two actions that override lockBuilder to return the same lock.
class DebounceAction1 extends ReduxAction<AppState> with Debounce {
  @override
  int debounce = 100;

  @override
  AppState reduce() {
    return state.copy(count: state.count + 1);
  }
}

class DebounceAction2 extends ReduxAction<AppState> with Debounce {
  @override
  int debounce = 100;

  @override
  AppState reduce() {
    return state.copy(count: state.count + 1);
  }
}

// Two actions with default lock (their runtime types differ).
class DebounceActionA extends ReduxAction<AppState> with Debounce {
  @override
  int debounce = 200;

  @override
  AppState reduce() {
    return state.copy(count: state.count + 1);
  }
}

class DebounceActionB extends ReduxAction<AppState> with Debounce {
  @override
  int debounce = 200;

  @override
  AppState reduce() {
    return state.copy(count: state.count + 1);
  }
}

// Async versions:

// An action that uses the Debounce mixin to increment the state.
class DebounceActionAsync extends ReduxAction<AppState> with Debounce {
  @override
  int debounce = 100;

  @override
  Future<AppState> reduce() async {
    await microtask;
    return state.copy(count: state.count + 1);
  }
}

// Two actions that override lockBuilder to return the same lock.
class DebounceAction1Async extends ReduxAction<AppState> with Debounce {
  @override
  int debounce = 100;

  @override
  Future<AppState> reduce() async {
    await microtask;
    return state.copy(count: state.count + 1);
  }
}

class DebounceAction2Async extends ReduxAction<AppState> with Debounce {
  @override
  int debounce = 100;

  @override
  Future<AppState> reduce() async {
    await microtask;
    return state.copy(count: state.count + 1);
  }
}

// Two actions with default lock (their runtime types differ).
class DebounceActionAAsync extends ReduxAction<AppState> with Debounce {
  @override
  int debounce = 200;

  @override
  Future<AppState> reduce() async {
    await microtask;
    return state.copy(count: state.count + 1);
  }
}

class DebounceActionBAsync extends ReduxAction<AppState> with Debounce {
  @override
  int debounce = 200;

  @override
  Future<AppState> reduce() async {
    await microtask;
    return state.copy(count: state.count + 1);
  }
}
