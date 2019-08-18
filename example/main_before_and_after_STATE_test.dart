import 'package:async_redux/async_redux.dart';
import "package:test/test.dart";

import './main_before_and_after.dart';

// Developed by Marcelo Glasberg (Aug 2019).
// For more info, see: https://pub.dartlang.org/packages/async_redux

/// This example displays the testing capabilities of AsyncRedux: How to test the store, actions, sync and async reducers,
/// by using the StoreTester. IMPORTANT: To run the tests, put this file in a test directory.
/// IMPORTANT: To run the tests, put this file in a test directory.
///
void main() {
  /////////////////////////////////////////////////////////////////////////////

  test('Initial state.', () {
    //
    var storeTester = StoreTester<AppState>(initialState: AppState.initialState());

    expect(storeTester.state.counter, 0);
    expect(storeTester.state.description, "");
    expect(storeTester.state.waiting, false);
  });

  /////////////////////////////////////////////////////////////////////////////

  test('Increment counter.', () async {
    //
    var storeTester = StoreTester<AppState>(initialState: AppState.initialState());
    expect(storeTester.state.counter, 0);

    storeTester.dispatch(IncrementAction(amount: 1));
    TestInfo<AppState> info = await storeTester.wait(IncrementAction);
    expect(info.state.counter, 1);

    storeTester.dispatch(IncrementAction(amount: 5));
    info = await storeTester.wait(IncrementAction);
    expect(info.state.counter, 6);
  });

  /////////////////////////////////////////////////////////////////////////////

  test('Increment counter and download description.', () async {
    //
    var storeTester = StoreTester<AppState>(initialState: AppState.initialState());
    expect(storeTester.state.counter, 0);
    expect(storeTester.state.description, isEmpty);

    storeTester.dispatch(IncrementAndGetDescriptionAction());

    TestInfo<AppState> info = await storeTester.waitUntil(IncrementAndGetDescriptionAction);
    expect(info.state.counter, 1);
    expect(info.state.description, isNotEmpty);
  });

  /////////////////////////////////////////////////////////////////////////////

  test('Turn on/off the modal barrier.', () async {
    //
    var storeTester = StoreTester<AppState>(initialState: AppState.initialState());
    expect(storeTester.state.waiting, false);

    storeTester.dispatch(WaitAction(true));
    TestInfo<AppState> info = await storeTester.wait(WaitAction);
    expect(info.state.waiting, true);

    storeTester.dispatch(WaitAction(false));
    info = await storeTester.wait(WaitAction);
    expect(info.state.waiting, false);
  });

  /////////////////////////////////////////////////////////////////////////////

  test('Modal barrier exists while downloading description.', () async {
    //
    var storeTester = StoreTester<AppState>(initialState: AppState.initialState());
    expect(storeTester.state.counter, 0);
    expect(storeTester.state.description, isEmpty);

    storeTester.dispatch(IncrementAndGetDescriptionAction());

    TestInfoList<AppState> infos = await storeTester.waitAll([
      IncrementAndGetDescriptionAction,
      WaitAction,
      IncrementAction,
      WaitAction,
    ]);

    // Modal barrier is turned on (first time WaitAction is dispatched).
    var info = infos.get(WaitAction, 1);
    expect(info.state.waiting, true);
    expect(info.state.description, isEmpty);
    expect(info.state.counter, 0);

    // While the counter was incremented the barrier was on.
    info = infos[IncrementAction];
    expect(info.state.counter, 1);
    expect(info.state.waiting, true);

    // Then the modal barrier is dismissed (second time WaitAction is dispatched).
    info = infos.get(WaitAction, 2);
    expect(info.state.waiting, false);
    expect(info.state.description, isNotEmpty);
    expect(info.state.counter, 1);

    // In the end, counter is incremented, description is created, and barrier is dismissed.
    info = infos[IncrementAndGetDescriptionAction];
    expect(info.state.waiting, false);
    expect(info.state.description, isNotEmpty);
    expect(info.state.counter, 1);
  });

  /////////////////////////////////////////////////////////////////////////////
}
