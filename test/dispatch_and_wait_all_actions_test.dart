// File: test/dispatch_and_wait_all_actions_test.dart
import 'package:async_redux/async_redux.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  //
  test('Completes for a sync action', () async {
    final store = Store<State>(initialState: State(1));
    final status = await store.dispatchAndWaitAllActions(IncrementSync());
    expect(status.isCompletedOk, true);
    expect(store.state.count, 2);
  });

  test('Completes for an async action', () async {
    final store = Store<State>(initialState: State(1));
    final status = await store.dispatchAndWaitAllActions(IncrementAsync());
    expect(status.isCompletedOk, true);
    expect(store.state.count, 2);
  });

  test('Waits for nested async dispatch in reduce', () async {
    var store = Store<State>(initialState: State(1));

    var status =
        await store.dispatchAndWaitAllActions(DispatchMultipleActions());

    expect(status.isCompletedOk, true);

    // 1 → DispatchMultipleActions.reduce → 2 → then IncrementAsync → 3
    expect(store.state.count, 3);

    // ---

    // Compare it to a normal dispatchAndWait:

    store = Store<State>(initialState: State(1));

    status =
    await store.dispatchAndWait(DispatchMultipleActions());

    expect(status.isCompletedOk, true);

    // 1 → DispatchMultipleActions.reduce → 2 → then IncrementAsync → 3
    expect(store.state.count, 2);
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

class IncrementAsync extends ReduxAction<State> {
  @override
  Future<State> reduce() async {
    await Future.delayed(const Duration(milliseconds: 10));
    return State(state.count + 1);
  }
}

class DispatchMultipleActions extends ReduxAction<State> {
  @override
  Future<State> reduce() async {
    // First, update the state synchronously.
    final updated = State(state.count + 1);

    // Then dispatch another async action.
    dispatch(IncrementAsync());
    
    return updated;
  }
}
