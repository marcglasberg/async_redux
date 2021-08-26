import 'package:async_redux/async_redux.dart';
import 'package:example/main_before_and_after.dart';
import "package:test/test.dart";

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
    var storeTester =
        StoreTester<AppState>(initialState: AppState.initialState());

    expect(storeTester.state.counter, 0);
    expect(storeTester.state.description, "");
    expect(storeTester.state.waiting, false);
  });

  /////////////////////////////////////////////////////////////////////////////

  test('Increment counter.', () async {
    //
    var storeTester =
        StoreTester<AppState>(initialState: AppState.initialState());
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
    var storeTester =
        StoreTester<AppState>(initialState: AppState.initialState());
    expect(storeTester.state.counter, 0);
    expect(storeTester.state.description, isEmpty);

    storeTester.dispatch(IncrementAndGetDescriptionAction());

    TestInfo<AppState> info =
        await storeTester.waitUntil(IncrementAndGetDescriptionAction);
    expect(info.state.counter, 1);
    expect(info.state.description, isNotEmpty);
  });

  /////////////////////////////////////////////////////////////////////////////

  test('Turn on/off the modal barrier.', () async {
    //
    var storeTester =
        StoreTester<AppState>(initialState: AppState.initialState());
    expect(storeTester.state.waiting, false);

    storeTester.dispatch(BarrierAction(true));
    TestInfo<AppState> info = await storeTester.wait(BarrierAction);
    expect(info.state.waiting, true);

    storeTester.dispatch(BarrierAction(false));
    info = await storeTester.wait(BarrierAction);
    expect(info.state.waiting, false);
  });

  /////////////////////////////////////////////////////////////////////////////

  test('Modal barrier exists while downloading description.', () async {
    //
    var storeTester =
        StoreTester<AppState>(initialState: AppState.initialState());
    expect(storeTester.state.counter, 0);
    expect(storeTester.state.description, isEmpty);

    storeTester.dispatch(IncrementAndGetDescriptionAction());

    TestInfoList<AppState> infos = await storeTester.waitAll([
      IncrementAndGetDescriptionAction,
      BarrierAction,
      IncrementAction,
      BarrierAction,
    ]);

    // Modal barrier is turned on (first time BarrierAction is dispatched).
    var info = infos.get(BarrierAction, 1)!;
    expect(info.state.waiting, true);
    expect(info.state.description, isEmpty);
    expect(info.state.counter, 0);

    // While the counter was incremented the barrier was on.
    info = infos[IncrementAction]!;
    expect(info.state.counter, 1);
    expect(info.state.waiting, true);

    // Then the modal barrier is dismissed (second time BarrierAction is dispatched).
    info = infos.get(BarrierAction, 2)!;
    expect(info.state.waiting, false);
    expect(info.state.description, isNotEmpty);
    expect(info.state.counter, 1);

    // In the end, counter is incremented, description is created, and barrier is dismissed.
    info = infos[IncrementAndGetDescriptionAction]!;
    expect(info.state.waiting, false);
    expect(info.state.description, isNotEmpty);
    expect(info.state.counter, 1);
  });

  /////////////////////////////////////////////////////////////////////////////
}
