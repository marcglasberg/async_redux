import 'package:async_redux/async_redux.dart';
import 'package:bdd_framework/bdd_framework.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Retry;

void main() {
  var feature = BddFeature('Polling mixin');

  // ==========================================================================
  // Case 1: Poll.start runs reduce immediately and starts polling
  // ==========================================================================

  Bdd(feature)
      .scenario('Poll.start runs reduce immediately and starts polling')
      .given('A polling action with Poll.start')
      .when('The action is dispatched')
      .then('It should run reduce and schedule periodic timer ticks')
      .run((_) async {
    fakeAsync((fake) {
      var store = Store<AppState>(initialState: AppState(0));

      store.dispatch(SimplePollAction(poll: Poll.start));
      fake.elapse(Duration.zero);
      expect(store.state.count, 1);

      fake.elapse(const Duration(milliseconds: 100));
      expect(store.state.count, 2);

      fake.elapse(const Duration(milliseconds: 100));
      expect(store.state.count, 3);

      fake.elapse(const Duration(milliseconds: 100));
      expect(store.state.count, 4);

      store.dispatch(SimplePollAction(poll: Poll.stop));
      fake.elapse(Duration.zero);
    });
  });

  // ==========================================================================
  // Case 2: Poll.start is no-op when polling is already active
  // ==========================================================================

  Bdd(feature)
      .scenario('Poll.start is no-op when polling is already active')
      .given('Polling is already active for an action type')
      .when('Poll.start is dispatched again')
      .then('It should do nothing — no reduce, no timer restart')
      .run((_) async {
    fakeAsync((fake) {
      var store = Store<AppState>(initialState: AppState(0));

      store.dispatch(SimplePollAction(poll: Poll.start));
      fake.elapse(Duration.zero);
      expect(store.state.count, 1);

      // Dispatch start again — should be no-op
      store.dispatch(SimplePollAction(poll: Poll.start));
      fake.elapse(Duration.zero);
      expect(store.state.count, 1); // No change

      // Original timer still ticks
      fake.elapse(const Duration(milliseconds: 100));
      expect(store.state.count, 2);

      store.dispatch(SimplePollAction(poll: Poll.stop));
      fake.elapse(Duration.zero);
    });
  });

  // ==========================================================================
  // Case 3: Poll.stop cancels the timer and skips reduce
  // ==========================================================================

  Bdd(feature)
      .scenario('Poll.stop cancels the timer and skips reduce')
      .given('Polling is active')
      .when('Poll.stop is dispatched')
      .then('The timer should be cancelled and reduce should not run')
      .run((_) async {
    fakeAsync((fake) {
      var store = Store<AppState>(initialState: AppState(0));

      store.dispatch(SimplePollAction(poll: Poll.start));
      fake.elapse(Duration.zero);
      expect(store.state.count, 1);

      store.dispatch(SimplePollAction(poll: Poll.stop));
      fake.elapse(Duration.zero);
      expect(store.state.count, 1); // Stop did not run reduce

      // Wait for when ticks would have fired
      fake.elapse(const Duration(milliseconds: 500));
      expect(store.state.count, 1); // No ticks
    });
  });

  // ==========================================================================
  // Case 4: Poll.stop when not active is a safe no-op
  // ==========================================================================

  Bdd(feature)
      .scenario('Poll.stop when not active is a safe no-op')
      .given('No polling is active')
      .when('Poll.stop is dispatched')
      .then('Nothing should happen and no error is thrown')
      .run((_) async {
    fakeAsync((fake) {
      var store = Store<AppState>(initialState: AppState(0));

      store.dispatch(SimplePollAction(poll: Poll.stop));
      fake.elapse(Duration.zero);
      expect(store.state.count, 0); // No error, no state change
    });
  });

  // ==========================================================================
  // Case 5: Poll.runNowAndRestart runs reduce and restarts the timer
  // ==========================================================================

  Bdd(feature)
      .scenario('Poll.runNowAndRestart runs reduce immediately and restarts the timer')
      .given('Polling is active')
      .when('Poll.runNowAndRestart is dispatched')
      .then('Reduce should run and the timer should restart from that moment')
      .run((_) async {
    fakeAsync((fake) {
      var store = Store<AppState>(initialState: AppState(0));

      store.dispatch(SimplePollAction(poll: Poll.start));
      fake.elapse(Duration.zero);
      expect(store.state.count, 1);

      // Wait 60ms (not enough for a tick at 100ms)
      fake.elapse(const Duration(milliseconds: 60));
      expect(store.state.count, 1);

      // Poll.runNowAndRestart runs reduce and restarts timer
      store.dispatch(SimplePollAction(poll: Poll.runNowAndRestart));
      fake.elapse(Duration.zero);
      expect(store.state.count, 2);

      // Timer restarted from this moment. 60ms later: no tick yet
      fake.elapse(const Duration(milliseconds: 60));
      expect(store.state.count, 2);

      // 100ms after now: tick fires
      fake.elapse(const Duration(milliseconds: 40));
      expect(store.state.count, 3);

      store.dispatch(SimplePollAction(poll: Poll.stop));
      fake.elapse(Duration.zero);
    });
  });

  // ==========================================================================
  // Case 6: Poll.runNowAndRestart when not active behaves like Poll.start
  // ==========================================================================

  Bdd(feature)
      .scenario('Poll.runNowAndRestart when not active behaves like Poll.start')
      .given('No polling is active')
      .when('Poll.runNowAndRestart is dispatched')
      .then('Reduce should run and polling should start')
      .run((_) async {
    fakeAsync((fake) {
      var store = Store<AppState>(initialState: AppState(0));

      store.dispatch(SimplePollAction(poll: Poll.runNowAndRestart));
      fake.elapse(Duration.zero);
      expect(store.state.count, 1);

      fake.elapse(const Duration(milliseconds: 100));
      expect(store.state.count, 2);

      fake.elapse(const Duration(milliseconds: 100));
      expect(store.state.count, 3);

      store.dispatch(SimplePollAction(poll: Poll.stop));
      fake.elapse(Duration.zero);
    });
  });

  // ==========================================================================
  // Case 7: Poll.once runs reduce without affecting active timer
  // ==========================================================================

  Bdd(feature)
      .scenario('Poll.once runs reduce without affecting the active timer')
      .given('Polling is active')
      .when('Poll.once is dispatched')
      .then('Reduce should run but the timer continues unchanged')
      .run((_) async {
    fakeAsync((fake) {
      var store = Store<AppState>(initialState: AppState(0));

      store.dispatch(SimplePollAction(poll: Poll.start));
      fake.elapse(Duration.zero);
      expect(store.state.count, 1);

      // Wait 50ms, then dispatch Poll.once
      fake.elapse(const Duration(milliseconds: 50));
      store.dispatch(SimplePollAction(poll: Poll.once));
      fake.elapse(Duration.zero);
      expect(store.state.count, 2); // Reduce ran

      // Original timer still fires at 100ms from start
      fake.elapse(const Duration(milliseconds: 50));
      expect(store.state.count, 3); // Timer tick

      // Next tick at 200ms from start
      fake.elapse(const Duration(milliseconds: 100));
      expect(store.state.count, 4);

      store.dispatch(SimplePollAction(poll: Poll.stop));
      fake.elapse(Duration.zero);
    });
  });

  // ==========================================================================
  // Case 8: Poll.once without active polling just runs reduce once
  // ==========================================================================

  Bdd(feature)
      .scenario('Poll.once without active polling just runs reduce once')
      .given('No polling is active')
      .when('Poll.once is dispatched')
      .then('Reduce runs once and no timer is started')
      .run((_) async {
    fakeAsync((fake) {
      var store = Store<AppState>(initialState: AppState(0));

      store.dispatch(SimplePollAction(poll: Poll.once));
      fake.elapse(Duration.zero);
      expect(store.state.count, 1);

      // No timer should fire
      fake.elapse(const Duration(milliseconds: 500));
      expect(store.state.count, 1);
    });
  });

  // ==========================================================================
  // Case 9: Timer ticks dispatch createPollingAction
  // ==========================================================================

  Bdd(feature)
      .scenario('Timer ticks dispatch the action from createPollingAction')
      .given('A polling action whose createPollingAction returns a different action type')
      .when('Timer ticks fire')
      .then('The action from createPollingAction should be dispatched')
      .run((_) async {
    fakeAsync((fake) {
      var store = Store<AppState>(initialState: AppState(0));

      // ControllerAction increments by 1; its createPollingAction
      // returns WorkerAction which increments by 10.
      store.dispatch(ControllerAction(poll: Poll.start));
      fake.elapse(Duration.zero);
      expect(store.state.count, 1); // Controller ran (+1)

      fake.elapse(const Duration(milliseconds: 100));
      expect(store.state.count, 11); // Worker ran (+10)

      fake.elapse(const Duration(milliseconds: 100));
      expect(store.state.count, 21); // Worker ran again (+10)

      store.dispatch(ControllerAction(poll: Poll.stop));
      fake.elapse(Duration.zero);
    });
  });

  // ==========================================================================
  // Case 10: Long-running polling accumulates correct tick count
  // ==========================================================================

  Bdd(feature)
      .scenario('Long-running polling accumulates correct number of ticks')
      .given('Polling is active with 100ms interval')
      .when('1 second passes')
      .then('There should be 10 timer ticks plus the initial reduce')
      .run((_) async {
    fakeAsync((fake) {
      var store = Store<AppState>(initialState: AppState(0));

      store.dispatch(SimplePollAction(poll: Poll.start));
      fake.elapse(Duration.zero);
      expect(store.state.count, 1);

      fake.elapse(const Duration(seconds: 1));
      expect(store.state.count, 11); // 1 initial + 10 ticks

      store.dispatch(SimplePollAction(poll: Poll.stop));
      fake.elapse(Duration.zero);
    });
  });

  // ==========================================================================
  // Case 11: Poll.start after Poll.stop restarts polling
  // ==========================================================================

  Bdd(feature)
      .scenario('Poll.start after Poll.stop restarts polling')
      .given('Polling was active and then stopped')
      .when('Poll.start is dispatched again')
      .then('Polling should restart from scratch')
      .run((_) async {
    fakeAsync((fake) {
      var store = Store<AppState>(initialState: AppState(0));

      store.dispatch(SimplePollAction(poll: Poll.start));
      fake.elapse(Duration.zero);
      expect(store.state.count, 1);

      fake.elapse(const Duration(milliseconds: 100));
      expect(store.state.count, 2);

      // Stop
      store.dispatch(SimplePollAction(poll: Poll.stop));
      fake.elapse(Duration.zero);

      fake.elapse(const Duration(milliseconds: 300));
      expect(store.state.count, 2); // No ticks

      // Restart
      store.dispatch(SimplePollAction(poll: Poll.start));
      fake.elapse(Duration.zero);
      expect(store.state.count, 3); // Reduce ran immediately

      fake.elapse(const Duration(milliseconds: 100));
      expect(store.state.count, 4); // First tick after restart

      store.dispatch(SimplePollAction(poll: Poll.stop));
      fake.elapse(Duration.zero);
    });
  });

  // ==========================================================================
  // Case 12: Poll.stop in the middle of ticks prevents further ticks
  // ==========================================================================

  Bdd(feature)
      .scenario('Poll.stop in the middle of ticks prevents further ticks')
      .given('Polling is active and some ticks have fired')
      .when('Poll.stop is dispatched')
      .then('No more ticks should fire')
      .run((_) async {
    fakeAsync((fake) {
      var store = Store<AppState>(initialState: AppState(0));

      store.dispatch(SimplePollAction(poll: Poll.start));
      fake.elapse(Duration.zero);

      fake.elapse(const Duration(milliseconds: 250)); // ~2 ticks
      expect(store.state.count, 3); // 1 initial + 2 ticks

      store.dispatch(SimplePollAction(poll: Poll.stop));
      fake.elapse(Duration.zero);

      final countAtStop = store.state.count;

      fake.elapse(const Duration(seconds: 1));
      expect(store.state.count, countAtStop); // No more ticks
    });
  });

  // ==========================================================================
  // Case 13: Different action types have independent timers
  // ==========================================================================

  Bdd(feature)
      .scenario('Different action types have independent timers')
      .given('Two different action types with Polling')
      .when('Both are started and one is stopped')
      .then('The other should continue polling independently')
      .run((_) async {
    fakeAsync((fake) {
      var store = Store<AppState>(initialState: AppState(0));

      store.dispatch(PollActionA(poll: Poll.start));
      fake.elapse(Duration.zero);
      expect(store.state.count, 1);

      store.dispatch(PollActionB(poll: Poll.start));
      fake.elapse(Duration.zero);
      expect(store.state.count, 2);

      // Both tick
      fake.elapse(const Duration(milliseconds: 100));
      expect(store.state.count, 4); // +1 from A, +1 from B

      // Stop A only
      store.dispatch(PollActionA(poll: Poll.stop));
      fake.elapse(Duration.zero);

      // Only B ticks
      fake.elapse(const Duration(milliseconds: 100));
      expect(store.state.count, 5); // +1 from B only

      fake.elapse(const Duration(milliseconds: 100));
      expect(store.state.count, 6); // +1 from B only

      store.dispatch(PollActionB(poll: Poll.stop));
      fake.elapse(Duration.zero);
    });
  });

  // ==========================================================================
  // Case 14: pollingKeyParams creates independent timers per param
  // ==========================================================================

  Bdd(feature)
      .scenario('pollingKeyParams creates independent timers per param')
      .given('A polling action that uses pollingKeyParams')
      .when('Dispatched with different params')
      .then('Each param should get its own independent timer')
      .run((_) async {
    fakeAsync((fake) {
      var store = Store<AppState>(initialState: AppState(0));

      store.dispatch(ParamPollAction('A', poll: Poll.start));
      fake.elapse(Duration.zero);
      expect(store.state.count, 1);

      store.dispatch(ParamPollAction('B', poll: Poll.start));
      fake.elapse(Duration.zero);
      expect(store.state.count, 2);

      // Both tick independently
      fake.elapse(const Duration(milliseconds: 100));
      expect(store.state.count, 4);

      // Stop only "A"
      store.dispatch(ParamPollAction('A', poll: Poll.stop));
      fake.elapse(Duration.zero);

      // Only "B" ticks
      fake.elapse(const Duration(milliseconds: 100));
      expect(store.state.count, 5);

      // Start "A" again
      store.dispatch(ParamPollAction('A', poll: Poll.start));
      fake.elapse(Duration.zero);
      expect(store.state.count, 6);

      // Both tick
      fake.elapse(const Duration(milliseconds: 100));
      expect(store.state.count, 8);

      store.dispatch(ParamPollAction('A', poll: Poll.stop));
      store.dispatch(ParamPollAction('B', poll: Poll.stop));
      fake.elapse(Duration.zero);
    });
  });

  // ==========================================================================
  // Case 15: Same pollingKeyParams shares timer
  // ==========================================================================

  Bdd(feature)
      .scenario('Same pollingKeyParams shares a timer')
      .given('Polling is active for a specific param')
      .when('Poll.start is dispatched with the same param')
      .then('It should be a no-op')
      .run((_) async {
    fakeAsync((fake) {
      var store = Store<AppState>(initialState: AppState(0));

      store.dispatch(ParamPollAction('X', poll: Poll.start));
      fake.elapse(Duration.zero);
      expect(store.state.count, 1);

      // Same param, start again — no-op
      store.dispatch(ParamPollAction('X', poll: Poll.start));
      fake.elapse(Duration.zero);
      expect(store.state.count, 1);

      // Timer still ticks once
      fake.elapse(const Duration(milliseconds: 100));
      expect(store.state.count, 2);

      store.dispatch(ParamPollAction('X', poll: Poll.stop));
      fake.elapse(Duration.zero);
    });
  });

  // ==========================================================================
  // Case 16: pollingKeyParams with tuple
  // ==========================================================================

  Bdd(feature)
      .scenario('pollingKeyParams with tuple creates independent timers')
      .given('Actions using tuple pollingKeyParams')
      .when('Dispatched with different tuple values')
      .then('Each tuple gets its own timer')
      .run((_) async {
    fakeAsync((fake) {
      var store = Store<AppState>(initialState: AppState(0));

      store.dispatch(TupleParamPollAction('u1', 'w1', poll: Poll.start));
      fake.elapse(Duration.zero);
      expect(store.state.count, 1);

      store.dispatch(TupleParamPollAction('u1', 'w2', poll: Poll.start));
      fake.elapse(Duration.zero);
      expect(store.state.count, 2);

      // Same (u1, w1) — no-op
      store.dispatch(TupleParamPollAction('u1', 'w1', poll: Poll.start));
      fake.elapse(Duration.zero);
      expect(store.state.count, 2);

      // Both tick
      fake.elapse(const Duration(milliseconds: 100));
      expect(store.state.count, 4);

      store.dispatch(TupleParamPollAction('u1', 'w1', poll: Poll.stop));
      store.dispatch(TupleParamPollAction('u1', 'w2', poll: Poll.stop));
      fake.elapse(Duration.zero);
    });
  });

  // ==========================================================================
  // Case 17: computePollingKey shares timer across action types
  // ==========================================================================

  Bdd(feature)
      .scenario('computePollingKey shares a timer across action types')
      .given('Two action types that return the same computePollingKey')
      .when('The first starts polling and the second tries to start')
      .then('The second should be a no-op')
      .run((_) async {
    fakeAsync((fake) {
      var store = Store<AppState>(initialState: AppState(0));

      store.dispatch(SharedKeyActionA(poll: Poll.start));
      fake.elapse(Duration.zero);
      expect(store.state.count, 1);

      // SharedKeyActionB with same key — start is no-op
      store.dispatch(SharedKeyActionB(poll: Poll.start));
      fake.elapse(Duration.zero);
      expect(store.state.count, 1);

      // Tick from A's createPollingAction
      fake.elapse(const Duration(milliseconds: 100));
      expect(store.state.count, 2);

      // Stop using B (same shared key)
      store.dispatch(SharedKeyActionB(poll: Poll.stop));
      fake.elapse(Duration.zero);

      // No more ticks
      fake.elapse(const Duration(milliseconds: 300));
      expect(store.state.count, 2);
    });
  });

  // ==========================================================================
  // Case 18: Poll.runNowAndRestart resets the timer interval
  // ==========================================================================

  Bdd(feature)
      .scenario('Poll.runNowAndRestart resets the timer interval')
      .given('Polling is active and 80ms have passed (out of 100ms interval)')
      .when('Poll.runNowAndRestart is dispatched')
      .then('The timer restarts — next tick is 100ms from now, not 20ms')
      .run((_) async {
    fakeAsync((fake) {
      var store = Store<AppState>(initialState: AppState(0));

      store.dispatch(SimplePollAction(poll: Poll.start));
      fake.elapse(Duration.zero);
      expect(store.state.count, 1);

      // Wait 80ms — almost time for the first tick
      fake.elapse(const Duration(milliseconds: 80));
      expect(store.state.count, 1);

      // Poll.runNowAndRestart resets the timer
      store.dispatch(SimplePollAction(poll: Poll.runNowAndRestart));
      fake.elapse(Duration.zero);
      expect(store.state.count, 2); // Reduce ran

      // 80ms after now — no tick (timer was reset to 100ms from now)
      fake.elapse(const Duration(milliseconds: 80));
      expect(store.state.count, 2);

      // 20ms more = 100ms after now — tick fires
      fake.elapse(const Duration(milliseconds: 20));
      expect(store.state.count, 3);

      store.dispatch(SimplePollAction(poll: Poll.stop));
      fake.elapse(Duration.zero);
    });
  });

  // ==========================================================================
  // Case 19: Rapid start/stop/start cycle
  // ==========================================================================

  Bdd(feature)
      .scenario('Rapid start/stop/start cycle works correctly')
      .given('Polling is started, stopped, and started again quickly')
      .when('Timer ticks fire')
      .then('Only the last start should produce ticks')
      .run((_) async {
    fakeAsync((fake) {
      var store = Store<AppState>(initialState: AppState(0));

      store.dispatch(SimplePollAction(poll: Poll.start));
      fake.elapse(Duration.zero);
      expect(store.state.count, 1);

      store.dispatch(SimplePollAction(poll: Poll.stop));
      fake.elapse(Duration.zero);

      store.dispatch(SimplePollAction(poll: Poll.start));
      fake.elapse(Duration.zero);
      expect(store.state.count, 2); // Second start ran reduce

      // Only one timer active
      fake.elapse(const Duration(milliseconds: 100));
      expect(store.state.count, 3); // One tick

      store.dispatch(SimplePollAction(poll: Poll.stop));
      fake.elapse(Duration.zero);
    });
  });

  // ==========================================================================
  // Case 20: Multiple Poll.runNowAndRestart dispatches restart each time
  // ==========================================================================

  Bdd(feature)
      .scenario('Multiple Poll.runNowAndRestart dispatches restart the timer each time')
      .given('Polling is active')
      .when('Poll.runNowAndRestart is dispatched repeatedly')
      .then('Each dispatch runs reduce and restarts the timer')
      .run((_) async {
    fakeAsync((fake) {
      var store = Store<AppState>(initialState: AppState(0));

      store.dispatch(SimplePollAction(poll: Poll.runNowAndRestart));
      fake.elapse(Duration.zero);
      expect(store.state.count, 1);

      fake.elapse(const Duration(milliseconds: 50));
      store.dispatch(SimplePollAction(poll: Poll.runNowAndRestart));
      fake.elapse(Duration.zero);
      expect(store.state.count, 2);

      fake.elapse(const Duration(milliseconds: 50));
      store.dispatch(SimplePollAction(poll: Poll.runNowAndRestart));
      fake.elapse(Duration.zero);
      expect(store.state.count, 3);

      // Timer restarts from last now — tick at +100ms
      fake.elapse(const Duration(milliseconds: 80));
      expect(store.state.count, 3);

      fake.elapse(const Duration(milliseconds: 20));
      expect(store.state.count, 4);

      store.dispatch(SimplePollAction(poll: Poll.stop));
      fake.elapse(Duration.zero);
    });
  });

  // ==========================================================================
  // Case 21: Default key uses (runtimeType, null)
  // ==========================================================================

  Bdd(feature)
      .scenario('Default key is based on (runtimeType, null)')
      .given('Two instances of the same action type with default pollingKeyParams')
      .when('One starts and the other tries to start')
      .then('The second should be a no-op')
      .run((_) async {
    fakeAsync((fake) {
      var store = Store<AppState>(initialState: AppState(0));

      store.dispatch(SimplePollAction(poll: Poll.start));
      fake.elapse(Duration.zero);
      expect(store.state.count, 1);

      store.dispatch(SimplePollAction(poll: Poll.start));
      fake.elapse(Duration.zero);
      expect(store.state.count, 1); // No-op

      store.dispatch(SimplePollAction(poll: Poll.stop));
      fake.elapse(Duration.zero);
    });
  });

  // ==========================================================================
  // Case 22: Option 1 pattern — single action for everything
  // ==========================================================================

  Bdd(feature)
      .scenario('Option 1: single action controls and performs polling')
      .given('A single action type that handles all poll values')
      .when('Various poll values are used')
      .then('It should correctly control polling and run work')
      .run((_) async {
    fakeAsync((fake) {
      var store = Store<AppState>(initialState: AppState(0));

      // Start
      store.dispatch(SingleAction(poll: Poll.start));
      fake.elapse(Duration.zero);
      expect(store.state.count, 1);

      fake.elapse(const Duration(milliseconds: 100));
      expect(store.state.count, 2); // Tick

      // Run once without affecting timer
      store.dispatch(SingleAction(poll: Poll.once));
      fake.elapse(Duration.zero);
      expect(store.state.count, 3);

      // Timer still ticks
      fake.elapse(const Duration(milliseconds: 100));
      expect(store.state.count, 4);

      // Force refresh + restart
      store.dispatch(SingleAction(poll: Poll.runNowAndRestart));
      fake.elapse(Duration.zero);
      expect(store.state.count, 5);

      fake.elapse(const Duration(milliseconds: 100));
      expect(store.state.count, 6);

      // Stop
      store.dispatch(SingleAction(poll: Poll.stop));
      fake.elapse(Duration.zero);

      fake.elapse(const Duration(milliseconds: 300));
      expect(store.state.count, 6); // No more ticks
    });
  });

  // ==========================================================================
  // Case 23: Option 2 pattern — separate controller and worker
  // ==========================================================================

  Bdd(feature)
      .scenario('Option 2: separate controller and worker actions')
      .given('A controller action that dispatches a worker via createPollingAction')
      .when('Polling starts')
      .then('Timer ticks should dispatch the worker action')
      .run((_) async {
    fakeAsync((fake) {
      var store = Store<AppState>(initialState: AppState(0));

      // Controller's reduce increments by 1
      store.dispatch(ControllerAction(poll: Poll.start));
      fake.elapse(Duration.zero);
      expect(store.state.count, 1);

      // Timer dispatches WorkerAction (+10)
      fake.elapse(const Duration(milliseconds: 100));
      expect(store.state.count, 11);

      fake.elapse(const Duration(milliseconds: 100));
      expect(store.state.count, 21);

      // Stop via controller
      store.dispatch(ControllerAction(poll: Poll.stop));
      fake.elapse(Duration.zero);

      fake.elapse(const Duration(milliseconds: 300));
      expect(store.state.count, 21);
    });
  });

  // ==========================================================================
  // Case 24: Clearing internal mixin props cancels all polling timers
  // ==========================================================================

  Bdd(feature)
      .scenario('Clearing internal mixin props cancels all polling timers')
      .given('Multiple pollers are active')
      .when('The store internal mixin props are cleared')
      .then('All polling timers should be cancelled')
      .run((_) async {
    fakeAsync((fake) {
      var store = Store<AppState>(initialState: AppState(0));

      store.dispatch(PollActionA(poll: Poll.start));
      fake.elapse(Duration.zero);
      store.dispatch(PollActionB(poll: Poll.start));
      fake.elapse(Duration.zero);
      expect(store.state.count, 2);

      // Clear all mixin props
      store.internalMixinProps.clear();

      // No more ticks from either
      fake.elapse(const Duration(milliseconds: 500));
      expect(store.state.count, 2);
    });
  });

  // ==========================================================================
  // Case 25: Poll.once dispatched many times does not start any timer
  // ==========================================================================

  Bdd(feature)
      .scenario('Multiple Poll.once dispatches never start a timer')
      .given('No polling is active')
      .when('Poll.once is dispatched multiple times')
      .then('Each dispatch runs reduce but no timer is ever created')
      .run((_) async {
    fakeAsync((fake) {
      var store = Store<AppState>(initialState: AppState(0));

      store.dispatch(SimplePollAction(poll: Poll.once));
      fake.elapse(Duration.zero);
      store.dispatch(SimplePollAction(poll: Poll.once));
      fake.elapse(Duration.zero);
      store.dispatch(SimplePollAction(poll: Poll.once));
      fake.elapse(Duration.zero);
      expect(store.state.count, 3);

      // No timer
      fake.elapse(const Duration(seconds: 1));
      expect(store.state.count, 3);
    });
  });

  // ==========================================================================
  // Case 26: Poll.runNowAndRestart followed by Poll.stop stops immediately
  // ==========================================================================

  Bdd(feature)
      .scenario('Poll.runNowAndRestart followed immediately by Poll.stop stops cleanly')
      .given('Poll.runNowAndRestart is dispatched')
      .when('Poll.stop is dispatched immediately after')
      .then('Reduce ran once from now, then no more ticks')
      .run((_) async {
    fakeAsync((fake) {
      var store = Store<AppState>(initialState: AppState(0));

      store.dispatch(SimplePollAction(poll: Poll.runNowAndRestart));
      fake.elapse(Duration.zero);
      expect(store.state.count, 1);

      store.dispatch(SimplePollAction(poll: Poll.stop));
      fake.elapse(Duration.zero);

      fake.elapse(const Duration(milliseconds: 500));
      expect(store.state.count, 1); // No ticks
    });
  });

  // ==========================================================================
  // Case 27: Poll.start with different pollingKeyParams are all independent
  // ==========================================================================

  Bdd(feature)
      .scenario('Stopping one param does not affect other params')
      .given('Three params are polling independently')
      .when('One is stopped')
      .then('The other two continue')
      .run((_) async {
    fakeAsync((fake) {
      var store = Store<AppState>(initialState: AppState(0));

      store.dispatch(ParamPollAction('A', poll: Poll.start));
      fake.elapse(Duration.zero);
      store.dispatch(ParamPollAction('B', poll: Poll.start));
      fake.elapse(Duration.zero);
      store.dispatch(ParamPollAction('C', poll: Poll.start));
      fake.elapse(Duration.zero);
      expect(store.state.count, 3);

      fake.elapse(const Duration(milliseconds: 100));
      expect(store.state.count, 6); // 3 ticks

      // Stop B
      store.dispatch(ParamPollAction('B', poll: Poll.stop));
      fake.elapse(Duration.zero);

      fake.elapse(const Duration(milliseconds: 100));
      expect(store.state.count, 8); // 2 ticks (A and C)

      // Stop A
      store.dispatch(ParamPollAction('A', poll: Poll.stop));
      fake.elapse(Duration.zero);

      fake.elapse(const Duration(milliseconds: 100));
      expect(store.state.count, 9); // 1 tick (C only)

      store.dispatch(ParamPollAction('C', poll: Poll.stop));
      fake.elapse(Duration.zero);
    });
  });

  // ==========================================================================
  // Case 28: Polling mixin cannot be combined with Retry
  // ==========================================================================

  Bdd(feature)
      .scenario('Polling mixin cannot be combined with Retry')
      .given('An action that combines Polling and Retry mixins')
      .when('The action is dispatched')
      .then('It should throw an AssertionError')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));

    expect(
      () => store.dispatch(PollingWithRetryAction(poll: Poll.once)),
      throwsA(isA<AssertionError>().having(
        (e) => e.message,
        'message',
        'The Polling mixin cannot be combined with the Retry mixin.',
      )),
    );
  });

  // ==========================================================================
  // Case 29: Polling mixin cannot be combined with UnlimitedRetries
  // ==========================================================================

  Bdd(feature)
      .scenario('Polling mixin cannot be combined with UnlimitedRetries')
      .given('An action that combines Polling and UnlimitedRetries mixins')
      .when('The action is dispatched')
      .then('It should throw an AssertionError')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));

    expect(
      () => store.dispatch(PollingWithUnlimitedRetriesAction(poll: Poll.once)),
      throwsA(isA<AssertionError>().having(
        (e) => e.message,
        'message',
        'The Polling mixin cannot be combined with the Retry mixin.',
      )),
    );
  });

  // ==========================================================================
  // Case 30: Polling mixin cannot be combined with Debounce
  // ==========================================================================

  Bdd(feature)
      .scenario('Polling mixin cannot be combined with Debounce')
      .given('An action that combines Polling and Debounce mixins')
      .when('The action is dispatched')
      .then('It should throw an AssertionError')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));

    expect(
      () => store.dispatch(PollingWithDebounceAction(poll: Poll.once)),
      throwsA(isA<AssertionError>().having(
        (e) => e.message,
        'message',
        'The Polling mixin cannot be combined with the Debounce mixin.',
      )),
    );
  });

  // ==========================================================================
  // Case 31: Polling mixin cannot be combined with UnlimitedRetryCheckInternet
  // ==========================================================================

  Bdd(feature)
      .scenario(
          'Polling mixin cannot be combined with UnlimitedRetryCheckInternet')
      .given(
          'An action that combines Polling and UnlimitedRetryCheckInternet mixins')
      .when('The action is dispatched')
      .then('It should throw an AssertionError')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));

    expect(
      () => store.dispatch(
          PollingWithUnlimitedRetryCheckInternetAction(poll: Poll.once)),
      throwsA(isA<AssertionError>().having(
        (e) => e.message,
        'message',
        'The UnlimitedRetryCheckInternet mixin cannot be combined with the Polling mixin.',
      )),
    );
  });

  // ==========================================================================
  // Case 32: Polling mixin cannot be combined with OptimisticCommand
  // ==========================================================================

  Bdd(feature)
      .scenario('Polling mixin cannot be combined with OptimisticCommand')
      .given('An action that combines Polling and OptimisticCommand mixins')
      .when('The action is dispatched')
      .then('It should throw an AssertionError')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));

    expect(
      () =>
          store.dispatch(PollingWithOptimisticCommandAction(poll: Poll.once)),
      throwsA(isA<AssertionError>().having(
        (e) => e.message,
        'message',
        'The OptimisticCommand mixin cannot be combined with the Polling mixin.',
      )),
    );
  });

  // ==========================================================================
  // Case 33: Polling mixin cannot be combined with OptimisticSync
  // ==========================================================================

  Bdd(feature)
      .scenario('Polling mixin cannot be combined with OptimisticSync')
      .given('An action that combines Polling and OptimisticSync mixins')
      .when('The action is dispatched')
      .then('It should throw an AssertionError')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));

    expect(
      () => store.dispatch(PollingWithOptimisticSyncAction(poll: Poll.once)),
      throwsA(isA<AssertionError>().having(
        (e) => e.message,
        'message',
        'The Polling mixin cannot be combined with the OptimisticSync mixin.',
      )),
    );
  });

  // ==========================================================================
  // Case 34: Polling mixin cannot be combined with OptimisticSyncWithPush
  // ==========================================================================

  Bdd(feature)
      .scenario(
          'Polling mixin cannot be combined with OptimisticSyncWithPush')
      .given(
          'An action that combines Polling and OptimisticSyncWithPush mixins')
      .when('The action is dispatched')
      .then('It should throw an AssertionError')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));

    expect(
      () => store.dispatch(
          PollingWithOptimisticSyncWithPushAction(poll: Poll.once)),
      throwsA(isA<AssertionError>().having(
        (e) => e.message,
        'message',
        'The Polling mixin cannot be combined with the OptimisticSyncWithPush mixin.',
      )),
    );
  });

  // ==========================================================================
  // Case 35: Polling mixin cannot be combined with ServerPush
  // ==========================================================================

  Bdd(feature)
      .scenario('Polling mixin cannot be combined with ServerPush')
      .given('An action that combines Polling and ServerPush mixins')
      .when('The action is dispatched')
      .then('It should throw an AssertionError')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));

    expect(
      () => store.dispatch(PollingWithServerPushAction(poll: Poll.once)),
      throwsA(isA<AssertionError>().having(
        (e) => e.message,
        'message',
        'The Polling mixin cannot be combined with the ServerPush mixin.',
      )),
    );
  });

  // ==========================================================================
  // Case 36: By default, the next tick waits for the previous run to finish
  // ==========================================================================

  Bdd(feature)
      .scenario('By default, the next tick waits for the previous run')
      .given('A polling action whose run takes longer than the poll interval')
      .when('Polling is started')
      .then('The interval is measured from the END of each run, and runs never '
          'overlap')
      .run((_) async {
    fakeAsync((fake) {
      SlowPollAction.reset();
      var store = Store<AppState>(initialState: AppState(0));

      // The interval is 100ms, and each run takes 250ms.
      // So the period is 250 + 100 = 350ms.
      store.dispatch(SlowPollAction(poll: Poll.start));

      // The immediate run only finishes at 250ms.
      fake.elapse(const Duration(milliseconds: 249));
      expect(store.state.count, 0);
      expect(SlowPollAction.concurrentRuns, 1);

      fake.elapse(const Duration(milliseconds: 1)); // 250ms
      expect(store.state.count, 1);

      // The first tick only starts at 350ms, and finishes at 600ms.
      fake.elapse(const Duration(milliseconds: 349)); // 599ms
      expect(store.state.count, 1);

      fake.elapse(const Duration(milliseconds: 1)); // 600ms
      expect(store.state.count, 2);

      // Second tick: starts at 700ms, and finishes at 950ms.
      fake.elapse(const Duration(milliseconds: 349)); // 949ms
      expect(store.state.count, 2);

      fake.elapse(const Duration(milliseconds: 1)); // 950ms
      expect(store.state.count, 3);

      // Runs never overlapped.
      expect(SlowPollAction.maxConcurrentRuns, 1);

      store.dispatch(SlowPollAction(poll: Poll.stop));
      fake.elapse(const Duration(seconds: 1));
    });
  });

  // ==========================================================================
  // Case 37: With pollWaitsForRun false, ticks happen at a fixed rate
  // ==========================================================================

  Bdd(feature)
      .scenario('With pollWaitsForRun false, ticks happen at a fixed rate')
      .given('A polling action with pollWaitsForRun false, whose run takes '
          'longer than the poll interval')
      .when('Polling is started')
      .then('The interval is measured from the START of each run, and runs '
          'may overlap')
      .run((_) async {
    fakeAsync((fake) {
      SlowPollAction.reset();
      var store = Store<AppState>(initialState: AppState(0));

      // The interval is 100ms, and each run takes 250ms.
      // So a new run starts every 100ms, and runs overlap.
      store.dispatch(SlowPollAction(poll: Poll.start, pollWaitsForRun: false));

      // Runs start at 0, 100, 200, 300... and each one takes 250ms.
      // So they finish at 250, 350, 450, 550...
      fake.elapse(const Duration(milliseconds: 250));
      expect(store.state.count, 1);

      fake.elapse(const Duration(milliseconds: 100)); // 350ms
      expect(store.state.count, 2);

      fake.elapse(const Duration(milliseconds: 100)); // 450ms
      expect(store.state.count, 3);

      // Runs did overlap.
      expect(SlowPollAction.maxConcurrentRuns, greaterThan(1));

      store.dispatch(SlowPollAction(poll: Poll.stop, pollWaitsForRun: false));
      fake.elapse(const Duration(seconds: 1));
    });
  });

  // ==========================================================================
  // Case 38: Poll.start is a no-op while the previous run is still in progress
  // ==========================================================================

  Bdd(feature)
      .scenario('Poll.start is a no-op while a run is still in progress')
      .given('Polling was started and the first run has not finished yet')
      .when('Poll.start is dispatched again')
      .then('It should do nothing, since polling is already active')
      .run((_) async {
    fakeAsync((fake) {
      SlowPollAction.reset();
      var store = Store<AppState>(initialState: AppState(0));

      store.dispatch(SlowPollAction(poll: Poll.start));

      // In the middle of the first run, which only finishes at 250ms.
      fake.elapse(const Duration(milliseconds: 100));
      expect(store.state.count, 0);

      store.dispatch(SlowPollAction(poll: Poll.start));
      fake.elapse(Duration.zero);

      // Only the original run finishes, at 250ms.
      fake.elapse(const Duration(milliseconds: 150)); // 250ms
      expect(store.state.count, 1);

      // And a single polling cycle is running: one tick every 350ms.
      fake.elapse(const Duration(milliseconds: 350)); // 600ms
      expect(store.state.count, 2);

      expect(SlowPollAction.maxConcurrentRuns, 1);

      store.dispatch(SlowPollAction(poll: Poll.stop));
      fake.elapse(const Duration(seconds: 1));
    });
  });

  // ==========================================================================
  // Case 39: Poll.stop during a run prevents the next tick
  // ==========================================================================

  Bdd(feature)
      .scenario('Poll.stop during a run prevents the next tick')
      .given('Polling was started and the first run has not finished yet')
      .when('Poll.stop is dispatched')
      .then('The in-progress run finishes, but no other tick is scheduled')
      .run((_) async {
    fakeAsync((fake) {
      SlowPollAction.reset();
      var store = Store<AppState>(initialState: AppState(0));

      store.dispatch(SlowPollAction(poll: Poll.start));

      fake.elapse(const Duration(milliseconds: 100));
      store.dispatch(SlowPollAction(poll: Poll.stop));
      fake.elapse(Duration.zero);

      // The in-progress run can't be cancelled, so it still finishes.
      fake.elapse(const Duration(milliseconds: 150)); // 250ms
      expect(store.state.count, 1);

      // But no further ticks happen.
      fake.elapse(const Duration(seconds: 5));
      expect(store.state.count, 1);
    });
  });

  // ==========================================================================
  // Case 40: Poll.runNowAndRestart during a run doesn't duplicate the polling
  // ==========================================================================

  Bdd(feature)
      .scenario('Poll.runNowAndRestart during a run does not duplicate polling')
      .given('Polling was started and the first run has not finished yet')
      .when('Poll.runNowAndRestart is dispatched')
      .then('The old cycle is abandoned, and a single polling cycle remains')
      .run((_) async {
    fakeAsync((fake) {
      SlowPollAction.reset();
      var store = Store<AppState>(initialState: AppState(0));

      store.dispatch(SlowPollAction(poll: Poll.start));

      // In the middle of the first run, restart the polling.
      // The restarted run finishes at 50 + 250 = 300ms.
      fake.elapse(const Duration(milliseconds: 50));
      store.dispatch(SlowPollAction(poll: Poll.runNowAndRestart));

      // The abandoned run still finishes at 250ms.
      fake.elapse(const Duration(milliseconds: 200)); // 250ms
      expect(store.state.count, 1);

      // The restarted run finishes at 300ms.
      fake.elapse(const Duration(milliseconds: 50)); // 300ms
      expect(store.state.count, 2);

      // Only the new cycle ticks: next tick starts at 400ms, ends at 650ms.
      fake.elapse(const Duration(milliseconds: 349)); // 649ms
      expect(store.state.count, 2);

      fake.elapse(const Duration(milliseconds: 1)); // 650ms
      expect(store.state.count, 3);

      store.dispatch(SlowPollAction(poll: Poll.stop));
      fake.elapse(const Duration(seconds: 1));
    });
  });

  // ==========================================================================
  // Case 41: Errors in the tick don't stop the polling (pollWaitsForRun true)
  // ==========================================================================

  Bdd(feature)
      .scenario('Errors in the tick do not stop the polling (waiting mode)')
      .given('A polling action whose runs fail')
      .when('The ticks keep failing, and then start succeeding')
      .then('The polling keeps ticking, and recovers once the runs succeed')
      .run((_) async {
    fakeAsync((fake) {
      TrackedPollAction.reset();
      TrackedPollAction.failure = PollFailure.userException;
      var store = Store<AppState>(initialState: AppState(0));

      // The interval is 100ms, and each run takes 50ms.
      // So a failing run goes 0-50, then 150-200, then 300-350...
      store.dispatch(TrackedPollAction(poll: Poll.start));

      fake.elapse(const Duration(milliseconds: 50));
      expect(TrackedPollAction.runsStarted, 1);
      expect(TrackedPollAction.errorCount, 1);

      // The failed run didn't stop the polling: the next tick starts at 150ms.
      fake.elapse(const Duration(milliseconds: 100)); // 150ms
      expect(TrackedPollAction.runsStarted, 2);

      fake.elapse(const Duration(milliseconds: 50)); // 200ms
      expect(TrackedPollAction.errorCount, 2);

      fake.elapse(const Duration(milliseconds: 100)); // 300ms
      expect(TrackedPollAction.runsStarted, 3);

      // The state never changed, since every run failed.
      expect(store.state.count, 0);

      // Now the runs start succeeding, and the polling recovers.
      // The run that started at 300ms succeeds at 350ms.
      TrackedPollAction.failure = PollFailure.none;

      fake.elapse(const Duration(milliseconds: 50)); // 350ms
      expect(store.state.count, 1);

      fake.elapse(const Duration(milliseconds: 150)); // 500ms
      expect(store.state.count, 2);

      store.dispatch(TrackedPollAction(poll: Poll.stop));
      fake.elapse(const Duration(seconds: 1));
    });
  });

  // ==========================================================================
  // Case 42: Errors in the tick don't stop the polling (pollWaitsForRun false)
  // ==========================================================================

  Bdd(feature)
      .scenario('Errors in the tick do not stop the polling (fixed rate mode)')
      .given('A polling action with pollWaitsForRun false, whose runs fail')
      .when('The ticks keep failing')
      .then('The polling keeps ticking at the fixed rate')
      .run((_) async {
    fakeAsync((fake) {
      TrackedPollAction.reset();
      TrackedPollAction.failure = PollFailure.userException;
      var store = Store<AppState>(initialState: AppState(0));

      store.dispatch(
          TrackedPollAction(poll: Poll.start, pollWaitsForRun: false));

      // Runs start at 0, 100, 200, 300... and all of them fail.
      fake.elapse(const Duration(milliseconds: 350));
      expect(TrackedPollAction.runsStarted, 4);
      expect(TrackedPollAction.errorCount, 4);
      expect(store.state.count, 0);

      store.dispatch(
          TrackedPollAction(poll: Poll.stop, pollWaitsForRun: false));
      fake.elapse(const Duration(seconds: 1));
    });
  });

  // ==========================================================================
  // Case 43: An error in the immediate Poll.start run still starts the polling
  // ==========================================================================

  Bdd(feature)
      .scenario('An error in the immediate Poll.start run still starts polling')
      .given('A polling action whose first run fails')
      .when('Poll.start is dispatched')
      .then('The polling is started anyway, and the next ticks run')
      .run((_) async {
    fakeAsync((fake) {
      TrackedPollAction.reset();
      TrackedPollAction.failure = PollFailure.userException;
      var store = Store<AppState>(initialState: AppState(0));

      store.dispatch(TrackedPollAction(poll: Poll.start));

      // The first run fails at 50ms.
      fake.elapse(const Duration(milliseconds: 50));
      expect(TrackedPollAction.errorCount, 1);

      // But polling is active: a Poll.start now is a no-op.
      TrackedPollAction.failure = PollFailure.none;
      store.dispatch(TrackedPollAction(poll: Poll.start));
      fake.elapse(Duration.zero);
      expect(TrackedPollAction.runsStarted, 1);

      // And the polling keeps ticking, from the failed run onwards.
      fake.elapse(const Duration(milliseconds: 150)); // 200ms
      expect(store.state.count, 1);

      store.dispatch(TrackedPollAction(poll: Poll.stop));
      fake.elapse(const Duration(seconds: 1));
    });
  });

  // ==========================================================================
  // Case 44: pollWaitsForRun false — Poll.stop during in-flight runs
  // ==========================================================================

  Bdd(feature)
      .scenario('With pollWaitsForRun false, Poll.stop prevents new ticks')
      .given('Polling at a fixed rate, with runs overlapping')
      .when('Poll.stop is dispatched while runs are in flight')
      .then('No new ticks start, but the in-flight runs still finish')
      .run((_) async {
    fakeAsync((fake) {
      SlowPollAction.reset();
      var store = Store<AppState>(initialState: AppState(0));

      // The interval is 100ms, and each run takes 250ms.
      store.dispatch(SlowPollAction(poll: Poll.start, pollWaitsForRun: false));

      // Runs started at 0ms and at 100ms. The tick at 200ms is cancelled.
      fake.elapse(const Duration(milliseconds: 150));
      store.dispatch(SlowPollAction(poll: Poll.stop, pollWaitsForRun: false));
      fake.elapse(Duration.zero);

      // The two in-flight runs still finish, at 250ms and 350ms.
      fake.elapse(const Duration(milliseconds: 100)); // 250ms
      expect(store.state.count, 1);

      fake.elapse(const Duration(milliseconds: 100)); // 350ms
      expect(store.state.count, 2);

      // And nothing else ever happens.
      fake.elapse(const Duration(seconds: 5));
      expect(store.state.count, 2);
    });
  });

  // ==========================================================================
  // Case 45: pollWaitsForRun false — runNowAndRestart doesn't duplicate ticks
  // ==========================================================================

  Bdd(feature)
      .scenario('With pollWaitsForRun false, runNowAndRestart does not '
          'duplicate polling')
      .given('Polling at a fixed rate')
      .when('Poll.runNowAndRestart is dispatched between two ticks')
      .then('The old cycle timer is cancelled, and the rate stays the same')
      .run((_) async {
    fakeAsync((fake) {
      TrackedPollAction.reset();
      var store = Store<AppState>(initialState: AppState(0));

      // The interval is 100ms, and each run takes 50ms.
      store.dispatch(
          TrackedPollAction(poll: Poll.start, pollWaitsForRun: false));

      // Runs start at 0ms and 100ms. The tick at 200ms gets cancelled below.
      fake.elapse(const Duration(milliseconds: 150));
      expect(TrackedPollAction.runsStarted, 2);

      // Restarts at 150ms: runs now, and then ticks at 250, 350, 450...
      store.dispatch(TrackedPollAction(
          poll: Poll.runNowAndRestart, pollWaitsForRun: false));
      fake.elapse(Duration.zero);
      expect(TrackedPollAction.runsStarted, 3);

      // Runs at 0, 100, 150, 250, 350, 450 — that is, 6 runs by 500ms.
      // If the old cycle had leaked, there would also be runs at 200, 300,
      // 400 and 500, for a total of 10.
      fake.elapse(const Duration(milliseconds: 350)); // 500ms
      expect(TrackedPollAction.runsStarted, 6);

      store.dispatch(
          TrackedPollAction(poll: Poll.stop, pollWaitsForRun: false));
      fake.elapse(const Duration(seconds: 1));
    });
  });

  // ==========================================================================
  // Case 46: NonReentrant on the tick action prevents ticks from piling up
  // ==========================================================================

  Bdd(feature)
      .scenario('NonReentrant on the tick action prevents ticks piling up')
      .given('A fixed-rate poller whose worker action is NonReentrant')
      .when('The worker takes longer than the poll interval')
      .then('Overlapping ticks are aborted, and runs never overlap')
      .run((_) async {
    fakeAsync((fake) {
      NonReentrantWorker.reset();
      var store = Store<AppState>(initialState: AppState(0));

      // The interval is 100ms, and each worker run takes 250ms.
      store.dispatch(FixedRateControllerAction(poll: Poll.start));

      // Ticks at 100, 200, 300... but the worker only accepts a new run when
      // the previous one finished. Worker runs: 100-350, 400-650, 700-950.
      fake.elapse(const Duration(milliseconds: 350));
      expect(store.state.count, 1);

      fake.elapse(const Duration(milliseconds: 300)); // 650ms
      expect(store.state.count, 2);

      fake.elapse(const Duration(milliseconds: 300)); // 950ms
      expect(store.state.count, 3);

      // Ticks were aborted instead of piling up.
      expect(NonReentrantWorker.maxConcurrentRuns, 1);
      expect(NonReentrantWorker.abortedCount, greaterThan(0));

      store.dispatch(FixedRateControllerAction(poll: Poll.stop));
      fake.elapse(const Duration(seconds: 1));
    });
  });

  // ==========================================================================
  // Case 47: Sequential on the tick action makes ticks run one at a time
  // ==========================================================================

  Bdd(feature)
      .scenario('Sequential on the tick action makes ticks run one at a time')
      .given('A fixed-rate poller whose worker action is Sequential')
      .when('The worker takes longer than the poll interval')
      .then('The ticks queue up and run one at a time, in order')
      .run((_) async {
    fakeAsync((fake) {
      SequentialWorker.reset();
      var store = Store<AppState>(initialState: AppState(0));

      // The interval is 100ms, and each worker run takes 250ms.
      store.dispatch(SequentialControllerAction(poll: Poll.start));

      // Ticks are queued at 100, 200, 300... and run one at a time:
      // 100-350, 350-600, 600-850.
      fake.elapse(const Duration(milliseconds: 350));
      expect(store.state.count, 1);

      fake.elapse(const Duration(milliseconds: 250)); // 600ms
      expect(store.state.count, 2);

      fake.elapse(const Duration(milliseconds: 250)); // 850ms
      expect(store.state.count, 3);

      expect(SequentialWorker.maxConcurrentRuns, 1);

      store.dispatch(SequentialControllerAction(poll: Poll.stop));
      fake.elapse(const Duration(seconds: 1));
    });
  });

  // ==========================================================================
  // Case 48: isWaiting and isFailed track the worker action
  // ==========================================================================

  Bdd(feature)
      .scenario('isWaiting and isFailed track the worker action')
      .given('A poller whose worker action fails and then succeeds')
      .when('The polling ticks')
      .then('isWaiting is true during each run, and isFailed reflects the '
          'last result')
      .run((_) async {
    fakeAsync((fake) {
      TrackedPollAction.reset();
      // Note: `isFailed` only becomes true for `UserException`s.
      TrackedPollAction.failure = PollFailure.userException;
      var store = Store<AppState>(initialState: AppState(0));

      // Registers the action type, so failures start being tracked.
      expect(store.isFailed(TrackedPollAction), false);
      expect(store.isWaiting(TrackedPollAction), false);

      // The interval is 100ms, and each run takes 50ms.
      store.dispatch(TrackedPollAction(poll: Poll.start));
      fake.elapse(const Duration(milliseconds: 25));
      expect(store.isWaiting(TrackedPollAction), true);

      // The run failed at 50ms.
      fake.elapse(const Duration(milliseconds: 25)); // 50ms
      expect(store.isWaiting(TrackedPollAction), false);
      expect(store.isFailed(TrackedPollAction), true);

      // The next tick starts at 150ms, and this one succeeds.
      TrackedPollAction.failure = PollFailure.none;
      fake.elapse(const Duration(milliseconds: 125)); // 175ms
      expect(store.isWaiting(TrackedPollAction), true);
      expect(store.isFailed(TrackedPollAction), false);

      fake.elapse(const Duration(milliseconds: 25)); // 200ms
      expect(store.isWaiting(TrackedPollAction), false);
      expect(store.isFailed(TrackedPollAction), false);
      expect(store.state.count, 1);

      store.dispatch(TrackedPollAction(poll: Poll.stop));
      fake.elapse(const Duration(seconds: 1));
    });
  });

  // ==========================================================================
  // Case 49: Polling is independent per store
  // ==========================================================================

  Bdd(feature)
      .scenario('Polling is independent per store')
      .given('Two stores and the same polling action type')
      .when('Polling is started in one store only')
      .then('Only that store ticks, and stopping it does not affect the other')
      .run((_) async {
    fakeAsync((fake) {
      var store1 = Store<AppState>(initialState: AppState(0));
      var store2 = Store<AppState>(initialState: AppState(0));

      store1.dispatch(SimplePollAction(poll: Poll.start));
      fake.elapse(const Duration(milliseconds: 250));
      expect(store1.state.count, 3);
      expect(store2.state.count, 0);

      // Now both stores poll, independently.
      store2.dispatch(SimplePollAction(poll: Poll.start));
      fake.elapse(const Duration(milliseconds: 200)); // 450ms
      expect(store1.state.count, 5);
      expect(store2.state.count, 3);

      // Stopping store1 doesn't stop store2.
      store1.dispatch(SimplePollAction(poll: Poll.stop));
      fake.elapse(const Duration(milliseconds: 200)); // 650ms
      expect(store1.state.count, 5);
      expect(store2.state.count, 5);

      store2.dispatch(SimplePollAction(poll: Poll.stop));
      fake.elapse(const Duration(seconds: 1));
    });
  });

  // ==========================================================================
  // Case 50: Throttle on the CONTROLLER action can block Poll.stop
  // ==========================================================================

  Bdd(feature)
      .scenario('Throttle on the controller action can block Poll.stop')
      .given('A polling controller action that also uses Throttle')
      .when('Poll.stop is dispatched inside the throttle period')
      .then('The stop is aborted by the throttle, and the polling continues')
      .run((_) async {
    fakeAsync((fake) {
      var store = Store<AppState>(initialState: AppState(0));

      // Throttle is 1000ms, and the poll interval is 100ms.
      store.dispatch(ThrottledPollAction(poll: Poll.start));
      fake.elapse(const Duration(milliseconds: 250));
      expect(store.state.count, 3);

      // This Poll.stop is aborted by Throttle, so polling is NOT stopped.
      store.dispatch(ThrottledPollAction(poll: Poll.stop));
      fake.elapse(const Duration(milliseconds: 200)); // 450ms
      expect(store.state.count, 5);

      // Only once the throttle period is over does the stop go through.
      // Note `Throttle` reads the real wall clock, which `fakeAsync` can't
      // advance, so here we clear the lock to simulate the period expiring.
      store.internalMixinProps.throttleLockMap.clear();

      store.dispatch(ThrottledPollAction(poll: Poll.stop));
      fake.elapse(Duration.zero);
      var countWhenStopped = store.state.count;

      fake.elapse(const Duration(seconds: 2));
      expect(store.state.count, countWhenStopped);
    });
  });

  // ==========================================================================
  // Case 51: NonReentrant on the CONTROLLER action can block Poll.stop
  // ==========================================================================

  Bdd(feature)
      .scenario('NonReentrant on the controller action can block Poll.stop')
      .given('A polling controller action that also uses NonReentrant')
      .when('Poll.stop is dispatched while the immediate run is in progress')
      .then('The stop is aborted by NonReentrant, and the polling continues')
      .run((_) async {
    fakeAsync((fake) {
      var store = Store<AppState>(initialState: AppState(0));

      // Each run takes 250ms, and the poll interval is 100ms.
      store.dispatch(NonReentrantPollAction(poll: Poll.start));

      // In the middle of the immediate run, the controller action is still
      // in progress, so this Poll.stop is aborted by NonReentrant.
      fake.elapse(const Duration(milliseconds: 100));
      store.dispatch(NonReentrantPollAction(poll: Poll.stop));
      fake.elapse(const Duration(milliseconds: 250)); // 350ms
      expect(store.state.count, 1);

      // The polling was not stopped: the next tick runs 350-600ms.
      fake.elapse(const Duration(milliseconds: 250)); // 600ms
      expect(store.state.count, 2);

      // Once no run is in progress, the stop goes through.
      store.dispatch(NonReentrantPollAction(poll: Poll.stop));
      fake.elapse(const Duration(seconds: 2));
      expect(store.state.count, 2);
    });
  });

  // ==========================================================================
  // Case 52: A zero poll interval works, in waiting mode
  // ==========================================================================

  Bdd(feature)
      .scenario('A zero poll interval works, in waiting mode')
      .given('A polling action with a zero interval and a 50ms run')
      .when('Polling is started')
      .then('Ticks run back-to-back, without overlapping or locking up')
      .run((_) async {
    fakeAsync((fake) {
      ZeroIntervalPollAction.reset();
      var store = Store<AppState>(initialState: AppState(0));

      store.dispatch(ZeroIntervalPollAction(poll: Poll.start));

      // Each run takes 50ms, and the next tick starts right after.
      // So runs finish at 50, 100, 150, 200 and 250ms.
      fake.elapse(const Duration(milliseconds: 250));
      expect(store.state.count, 5);
      expect(ZeroIntervalPollAction.maxConcurrentRuns, 1);

      // The run that is in flight when Poll.stop arrives still finishes,
      // but no further tick happens.
      store.dispatch(ZeroIntervalPollAction(poll: Poll.stop));
      fake.elapse(const Duration(milliseconds: 50)); // 300ms
      expect(store.state.count, 6);

      fake.elapse(const Duration(seconds: 5));
      expect(store.state.count, 6);
    });
  });

  // ==========================================================================
  // Case 53: Generic errors (not UserException) don't stop the polling either
  // ==========================================================================

  Bdd(feature)
      .scenario('Generic errors do not stop the polling either')
      .given('A polling action whose runs throw a generic error, and a global '
          'error observer that swallows it')
      .when('The ticks keep failing')
      .then('The polling keeps ticking')
      .run((_) async {
    fakeAsync((fake) {
      TrackedPollAction.reset();
      TrackedPollAction.failure = PollFailure.genericError;
      var store = Store<AppState>(
        initialState: AppState(0),
        globalErrorObserver: (store) => SwallowErrorObserver(),
      );

      // Failing runs go 0-50, then 150-200, then 300-350...
      store.dispatch(TrackedPollAction(poll: Poll.start));

      fake.elapse(const Duration(milliseconds: 50));
      expect(TrackedPollAction.errorCount, 1);

      fake.elapse(const Duration(milliseconds: 150)); // 200ms
      expect(TrackedPollAction.errorCount, 2);

      fake.elapse(const Duration(milliseconds: 150)); // 350ms
      expect(TrackedPollAction.errorCount, 3);

      expect(store.state.count, 0);

      store.dispatch(TrackedPollAction(poll: Poll.stop));
      fake.elapse(const Duration(seconds: 1));
    });
  });

  // ==========================================================================
  // Case 54: AbortWhenNoInternet on the tick action
  // ==========================================================================

  Bdd(feature)
      .scenario('AbortWhenNoInternet on the tick action skips ticks offline')
      .given('A poller whose worker action has AbortWhenNoInternet')
      .when('There is no internet, and then the internet comes back')
      .then('The ticks are aborted while offline, and the polling recovers')
      .run((_) async {
    fakeAsync((fake) {
      var store = Store<AppState>(initialState: AppState(0));
      store.forceInternetOnOffSimulation = () => false;

      // The interval is 100ms, so ticks happen at 100, 200, 300...
      store.dispatch(InternetControllerAction(poll: Poll.start));

      // While offline, every tick is aborted, but the polling keeps going.
      fake.elapse(const Duration(milliseconds: 350));
      expect(store.state.count, 0);

      // The internet comes back.
      store.forceInternetOnOffSimulation = () => true;

      fake.elapse(const Duration(milliseconds: 100)); // 450ms
      expect(store.state.count, 1);

      fake.elapse(const Duration(milliseconds: 100)); // 550ms
      expect(store.state.count, 2);

      store.dispatch(InternetControllerAction(poll: Poll.stop));
      fake.elapse(const Duration(seconds: 1));
      expect(store.state.count, 2);
    });
  });

  // ==========================================================================
  // Case 55: CheckInternet on the CONTROLLER action can block Poll.stop
  // ==========================================================================

  Bdd(feature)
      .scenario('CheckInternet on the controller action can block Poll.stop')
      .given('A polling controller action that also uses CheckInternet')
      .when('Poll.stop is dispatched while there is no internet')
      .then('The stop fails in `before`, and the polling continues')
      .run((_) async {
    fakeAsync((fake) {
      var store = Store<AppState>(initialState: AppState(0));
      store.forceInternetOnOffSimulation = () => true;

      // The interval is 100ms, so ticks happen at 100, 200, 300...
      store.dispatch(CheckInternetPollAction(poll: Poll.start));
      fake.elapse(const Duration(milliseconds: 250));
      expect(store.state.count, 2);

      // The internet goes away, and now Poll.stop can't get through:
      // CheckInternet throws in `before`, so `wrapReduce` never runs.
      store.forceInternetOnOffSimulation = () => false;
      store.dispatch(CheckInternetPollAction(poll: Poll.stop));

      // The polling was NOT stopped. Note the worker action has no internet
      // check of its own, so the ticks keep incrementing the count.
      fake.elapse(const Duration(milliseconds: 300)); // 550ms
      expect(store.state.count, 5);

      // Once the internet is back, the stop finally goes through.
      store.forceInternetOnOffSimulation = () => true;
      store.dispatch(CheckInternetPollAction(poll: Poll.stop));
      fake.elapse(Duration.zero);
      var countWhenStopped = store.state.count;

      fake.elapse(const Duration(seconds: 2));
      expect(store.state.count, countWhenStopped);
    });
  });

  // ==========================================================================
  // Case 56: store.shutdown() cancels the polling
  // ==========================================================================

  Bdd(feature)
      .scenario('store.shutdown() cancels the polling')
      .given('Polling is active')
      .when('The store is shut down')
      .then('The polling timer is cancelled and no other tick happens')
      .run((_) async {
    fakeAsync((fake) {
      var store = Store<AppState>(initialState: AppState(0));

      store.dispatch(SimplePollAction(poll: Poll.start));
      fake.elapse(const Duration(milliseconds: 250));
      expect(store.state.count, 3);
      expect(store.internalMixinProps.pollingMap, isNotEmpty);

      store.shutdown();
      expect(store.internalMixinProps.pollingMap, isEmpty);

      fake.elapse(const Duration(seconds: 5));
      expect(store.state.count, 3);
    });
  });

  // ==========================================================================
  // Case 57: store.shutdown() during a run doesn't schedule another tick
  // ==========================================================================

  Bdd(feature)
      .scenario('store.shutdown() during a run does not schedule another tick')
      .given('Polling is active and a run is in progress')
      .when('The store is shut down')
      .then('When the in-flight run ends, no other tick is scheduled')
      .run((_) async {
    fakeAsync((fake) {
      SlowPollAction.reset();
      var store = Store<AppState>(initialState: AppState(0));

      // Each run takes 250ms, and the interval is 100ms.
      store.dispatch(SlowPollAction(poll: Poll.start));

      // Shuts down in the middle of the immediate run.
      fake.elapse(const Duration(milliseconds: 100));
      store.shutdown();

      // The in-flight run ends at 250ms, but it must not reschedule.
      fake.elapse(const Duration(seconds: 5));
      expect(store.internalMixinProps.pollingMap, isEmpty);
      expect(SlowPollAction.maxConcurrentRuns, 1);
      expect(SlowPollAction.concurrentRuns, 0);
    });
  });

  // ==========================================================================
  // Case 58: Polling works with the real clock (no fakeAsync)
  // ==========================================================================

  Bdd(feature)
      .scenario('Polling works with the real clock')
      .given('A polling action with a short interval, using real timers')
      .when('Polling runs for a while and is then stopped')
      .then('It ticks repeatedly, and stops for good')
      .run((_) async {
    RealClockPollAction.reset();
    var store = Store<AppState>(initialState: AppState(0));

    // The interval is 20ms, and each run takes 10ms, so the period is ~30ms.
    store.dispatch(RealClockPollAction(poll: Poll.start));
    await Future.delayed(const Duration(milliseconds: 400));

    var countWhilePolling = store.state.count;
    expect(countWhilePolling, greaterThanOrEqualTo(3));
    expect(RealClockPollAction.maxConcurrentRuns, 1);

    store.dispatch(RealClockPollAction(poll: Poll.stop));

    // Waits for any in-flight run to finish, and then checks it really stopped.
    await Future.delayed(const Duration(milliseconds: 100));
    var countWhenStopped = store.state.count;
    await Future.delayed(const Duration(milliseconds: 300));
    expect(store.state.count, countWhenStopped);
  });

  // ==========================================================================
  // Case 59: With the real clock, waiting mode really is slower than fixed rate
  // ==========================================================================

  Bdd(feature)
      .scenario('With the real clock, waiting mode is slower than fixed rate')
      .given('The same action polled in both modes, for the same wall time')
      .when('Each run takes longer than the poll interval')
      .then('Waiting mode does fewer, non-overlapping runs than fixed rate')
      .run((_) async {
    // Waiting mode: the period is run + interval = 100 + 50 = ~150ms.
    RealClockPollAction.reset();
    var store1 = Store<AppState>(initialState: AppState(0));
    store1.dispatch(RealClockPollAction(
      poll: Poll.start,
      runMillis: 100,
      intervalMillis: 50,
    ));
    await Future.delayed(const Duration(milliseconds: 600));
    store1.dispatch(RealClockPollAction(
      poll: Poll.stop,
      runMillis: 100,
      intervalMillis: 50,
    ));
    var waitingRuns = RealClockPollAction.runsStarted;
    var waitingMaxConcurrent = RealClockPollAction.maxConcurrentRuns;
    await Future.delayed(const Duration(milliseconds: 200));

    // Fixed-rate mode: a run starts every 50ms, so runs overlap.
    RealClockPollAction.reset();
    var store2 = Store<AppState>(initialState: AppState(0));
    store2.dispatch(RealClockPollAction(
      poll: Poll.start,
      runMillis: 100,
      intervalMillis: 50,
      pollWaitsForRun: false,
    ));
    await Future.delayed(const Duration(milliseconds: 600));
    store2.dispatch(RealClockPollAction(
      poll: Poll.stop,
      runMillis: 100,
      intervalMillis: 50,
      pollWaitsForRun: false,
    ));
    var fixedRateRuns = RealClockPollAction.runsStarted;
    var fixedRateMaxConcurrent = RealClockPollAction.maxConcurrentRuns;
    await Future.delayed(const Duration(milliseconds: 200));

    expect(waitingMaxConcurrent, 1);
    expect(fixedRateMaxConcurrent, greaterThan(1));
    expect(fixedRateRuns, greaterThan(waitingRuns));
  });

  // ==========================================================================
  // Case 60: With the real clock, Throttle on the controller blocks Poll.stop
  // ==========================================================================

  Bdd(feature)
      .scenario('With the real clock, Throttle on the controller blocks '
          'Poll.stop until the throttle period is over')
      .given('A polling controller action that also uses Throttle')
      .when('Poll.stop is dispatched inside and then after the throttle period')
      .then('The first stop is aborted, and only the second one works')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));

    // The throttle is 200ms, and the poll interval is 20ms.
    store.dispatch(RealClockThrottledPollAction(poll: Poll.start));
    await Future.delayed(const Duration(milliseconds: 100));

    // Inside the throttle period: this stop is silently aborted.
    store.dispatch(RealClockThrottledPollAction(poll: Poll.stop));
    await Future.delayed(const Duration(milliseconds: 100));
    var countAfterIgnoredStop = store.state.count;
    expect(countAfterIgnoredStop, greaterThan(2));

    // Waits for the throttle period to really expire, on the real clock.
    await Future.delayed(const Duration(milliseconds: 250));
    expect(store.state.count, greaterThan(countAfterIgnoredStop));

    // Now the stop goes through.
    store.dispatch(RealClockThrottledPollAction(poll: Poll.stop));
    await Future.delayed(const Duration(milliseconds: 100));
    var countWhenStopped = store.state.count;
    await Future.delayed(const Duration(milliseconds: 300));
    expect(store.state.count, countWhenStopped);
  });

  // ==========================================================================
  // Case 61: Fresh on the tick action skips ticks while the data is fresh
  // ==========================================================================

  Bdd(feature)
      .scenario('Fresh on the tick action skips ticks while data is fresh')
      .given('A poller whose worker action uses Fresh')
      .when('The poll interval is much shorter than the freshness period')
      .then('Most ticks are skipped, and the worker runs at the fresh rate')
      .run((_) async {
    FreshWorker.reset();
    var store = Store<AppState>(initialState: AppState(0));

    // The interval is 20ms, but the worker stays fresh for 150ms.
    store.dispatch(FreshControllerAction(poll: Poll.start));
    await Future.delayed(const Duration(milliseconds: 600));
    store.dispatch(FreshControllerAction(poll: Poll.stop));
    await Future.delayed(const Duration(milliseconds: 100));

    // Many ticks were dispatched, but few of them actually ran.
    expect(FreshControllerAction.ticksDispatched, greaterThan(10));
    expect(store.state.count, greaterThanOrEqualTo(2));
    expect(store.state.count, lessThan(FreshControllerAction.ticksDispatched));
  });

  // ==========================================================================
  // Case 62: Fresh on the CONTROLLER action can block Poll.stop
  // ==========================================================================

  Bdd(feature)
      .scenario('Fresh on the controller action can block Poll.stop')
      .given('A polling controller action that also uses Fresh')
      .when('Poll.stop is dispatched while the controller is still fresh')
      .then('The stop is aborted, and the polling continues')
      .run((_) async {
    var store = Store<AppState>(initialState: AppState(0));

    // The controller stays fresh for 250ms, and the poll interval is 20ms.
    store.dispatch(FreshPollAction(poll: Poll.start));
    await Future.delayed(const Duration(milliseconds: 100));

    // Still fresh: this stop is silently aborted.
    store.dispatch(FreshPollAction(poll: Poll.stop));
    await Future.delayed(const Duration(milliseconds: 100));
    var countAfterIgnoredStop = store.state.count;
    expect(countAfterIgnoredStop, greaterThan(2));

    // Waits for the freshness to really expire, on the real clock.
    await Future.delayed(const Duration(milliseconds: 250));
    expect(store.state.count, greaterThan(countAfterIgnoredStop));

    // Now the stop goes through.
    store.dispatch(FreshPollAction(poll: Poll.stop));
    await Future.delayed(const Duration(milliseconds: 100));
    var countWhenStopped = store.state.count;
    await Future.delayed(const Duration(milliseconds: 300));
    expect(store.state.count, countWhenStopped);
  });

  // ---------------------------------------------------------------------------

  // ==========================================================================
  // Case 63 and 64: Polling drives widget rebuilds
  // ==========================================================================

  group('Polling with widgets', () {
    //
    testWidgets('A StoreConnector rebuilds on each polling tick',
        (tester) async {
      var store = Store<AppState>(initialState: AppState(0));

      await tester.pumpWidget(_CountApp(store: store));
      expect(find.text('Count: 0'), findsOneWidget);

      // The interval is 100ms, and the reduce is sync.
      store.dispatch(SimplePollAction(poll: Poll.start));
      await tester.pump();
      expect(find.text('Count: 1'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Count: 2'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Count: 3'), findsOneWidget);

      // Stopping the polling stops the rebuilds.
      store.dispatch(SimplePollAction(poll: Poll.stop));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Count: 3'), findsOneWidget);
    });

    testWidgets('A StoreConnector shows the waiting state of each tick',
        (tester) async {
      TrackedPollAction.reset();
      var store = Store<AppState>(initialState: AppState(0));

      await tester.pumpWidget(_WaitingApp(store: store));
      expect(find.text('idle'), findsOneWidget);

      // The interval is 100ms, and each run takes 50ms.
      store.dispatch(TrackedPollAction(poll: Poll.start));
      await tester.pump();
      expect(find.text('waiting'), findsOneWidget);

      // The run ends at 50ms.
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('idle'), findsOneWidget);

      // The next tick runs from 150ms to 200ms.
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('waiting'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('idle'), findsOneWidget);

      store.dispatch(TrackedPollAction(poll: Poll.stop));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    });
  });
}

// =============================================================================
// Widgets used by the widget tests
// =============================================================================

class _CountApp extends StatelessWidget {
  final Store<AppState> store;

  const _CountApp({required this.store});

  @override
  Widget build(BuildContext context) {
    return StoreProvider<AppState>(
      store: store,
      child: MaterialApp(
        home: StoreConnector<AppState, int>(
          converter: (store) => store.state.count,
          builder: (context, count) => Text('Count: $count'),
        ),
      ),
    );
  }
}

class _WaitingApp extends StatelessWidget {
  final Store<AppState> store;

  const _WaitingApp({required this.store});

  @override
  Widget build(BuildContext context) {
    return StoreProvider<AppState>(
      store: store,
      child: MaterialApp(
        home: StoreConnector<AppState, bool>(
          converter: (store) => store.isWaiting(TrackedPollAction),
          builder: (context, isWaiting) => Text(isWaiting ? 'waiting' : 'idle'),
        ),
      ),
    );
  }
}

// =============================================================================
// Actions used by the real-clock tests (no fakeAsync)
// =============================================================================

class RealClockPollAction extends ReduxAction<AppState> with Polling {
  static int runsStarted = 0;
  static int concurrentRuns = 0;
  static int maxConcurrentRuns = 0;

  static void reset() {
    runsStarted = 0;
    concurrentRuns = 0;
    maxConcurrentRuns = 0;
  }

  @override
  final Poll poll;

  @override
  final bool pollWaitsForRun;

  final int runMillis;
  final int intervalMillis;

  RealClockPollAction({
    required this.poll,
    this.pollWaitsForRun = true,
    this.runMillis = 10,
    this.intervalMillis = 20,
  });

  @override
  Duration get pollInterval => Duration(milliseconds: intervalMillis);

  @override
  ReduxAction<AppState> createPollingAction() => RealClockPollAction(
        poll: Poll.once,
        pollWaitsForRun: pollWaitsForRun,
        runMillis: runMillis,
        intervalMillis: intervalMillis,
      );

  @override
  Future<AppState?> reduce() async {
    runsStarted++;
    concurrentRuns++;
    if (concurrentRuns > maxConcurrentRuns) maxConcurrentRuns = concurrentRuns;
    try {
      await Future.delayed(Duration(milliseconds: runMillis));
      return state.copy(count: state.count + 1);
    } finally {
      concurrentRuns--;
    }
  }
}

/// Note `Throttle` reads the real wall clock, so this is tested without
/// `fakeAsync`.
class RealClockThrottledPollAction extends ReduxAction<AppState>
    with Throttle, Polling {
  @override
  final Poll poll;

  RealClockThrottledPollAction({required this.poll});

  @override
  int get throttle => 200;

  @override
  Duration get pollInterval => const Duration(milliseconds: 20);

  @override
  ReduxAction<AppState> createPollingAction() => SimpleWorkerAction();

  @override
  AppState? reduce() => null;
}

// =============================================================================
// Polling combined with the Fresh mixin (which also reads the real wall clock)
// =============================================================================

/// The controller has no freshness; the worker is the one that is `Fresh`.
class FreshControllerAction extends ReduxAction<AppState> with Polling {
  static int ticksDispatched = 0;

  @override
  final Poll poll;

  FreshControllerAction({required this.poll});

  @override
  Duration get pollInterval => const Duration(milliseconds: 20);

  @override
  ReduxAction<AppState> createPollingAction() {
    ticksDispatched++;
    return FreshWorker();
  }

  @override
  AppState? reduce() => null;
}

class FreshWorker extends ReduxAction<AppState> with Fresh {
  static void reset() => FreshControllerAction.ticksDispatched = 0;

  @override
  int get freshFor => 150;

  @override
  AppState reduce() => state.copy(count: state.count + 1);
}

/// The controller itself is `Fresh`, which is the problematic setup.
class FreshPollAction extends ReduxAction<AppState> with Fresh, Polling {
  @override
  final Poll poll;

  FreshPollAction({required this.poll});

  @override
  int get freshFor => 250;

  @override
  Duration get pollInterval => const Duration(milliseconds: 20);

  @override
  ReduxAction<AppState> createPollingAction() => SimpleWorkerAction();

  @override
  AppState? reduce() => null;
}

// =============================================================================
// Polling combined with the internet-check mixins
// =============================================================================

/// The controller has no internet check; the worker aborts when offline.
class InternetControllerAction extends ReduxAction<AppState> with Polling {
  @override
  final Poll poll;

  InternetControllerAction({required this.poll});

  @override
  Duration get pollInterval => const Duration(milliseconds: 100);

  @override
  ReduxAction<AppState> createPollingAction() => OfflineAwareWorker();

  @override
  AppState? reduce() => null;
}

class OfflineAwareWorker extends ReduxAction<AppState>
    with AbortWhenNoInternet {
  @override
  AppState reduce() => state.copy(count: state.count + 1);
}

/// The controller itself checks the internet, which is the problematic setup.
class CheckInternetPollAction extends ReduxAction<AppState>
    with CheckInternet, Polling {
  @override
  final Poll poll;

  CheckInternetPollAction({required this.poll});

  @override
  Duration get pollInterval => const Duration(milliseconds: 100);

  @override
  ReduxAction<AppState> createPollingAction() => SimpleWorkerAction();

  @override
  AppState? reduce() => null;
}

// =============================================================================
// Error observer that swallows all errors, so they don't reach the zone
// =============================================================================

class SwallowErrorObserver extends GlobalErrorObserver<AppState> {
  @override
  Object? observe() => null;
}

// =============================================================================
// Tracked polling action — 50ms runs, 100ms interval, can be made to fail
// =============================================================================

class TrackedPollAction extends ReduxAction<AppState> with Polling {
  static int runsStarted = 0;
  static int errorCount = 0;
  static PollFailure failure = PollFailure.none;

  static void reset() {
    runsStarted = 0;
    errorCount = 0;
    failure = PollFailure.none;
  }

  @override
  final Poll poll;

  @override
  final bool pollWaitsForRun;

  TrackedPollAction({required this.poll, this.pollWaitsForRun = true});

  @override
  Duration get pollInterval => const Duration(milliseconds: 100);

  @override
  ReduxAction<AppState> createPollingAction() =>
      TrackedPollAction(poll: Poll.once, pollWaitsForRun: pollWaitsForRun);

  @override
  Future<AppState?> reduce() async {
    runsStarted++;
    await Future.delayed(const Duration(milliseconds: 50));
    switch (failure) {
      case PollFailure.none:
        return state.copy(count: state.count + 1);
      case PollFailure.userException:
        errorCount++;
        throw const UserException('The polling run failed.');
      case PollFailure.genericError:
        errorCount++;
        throw const _PollFailure();
    }
  }
}

/// How a polling run should fail, if at all.
///
/// Note a [UserException] is "handled" by AsyncRedux (it goes to the error
/// queue, to be shown to the user), while a generic error is rethrown, unless
/// some global error handling swallows it.
enum PollFailure { none, userException, genericError }

class _PollFailure implements Exception {
  const _PollFailure();

  @override
  String toString() => 'The polling run failed.';
}

// =============================================================================
// Fixed-rate controller + NonReentrant worker (Option 2 pattern)
// =============================================================================

class FixedRateControllerAction extends ReduxAction<AppState> with Polling {
  @override
  final Poll poll;

  FixedRateControllerAction({required this.poll});

  @override
  bool get pollWaitsForRun => false;

  @override
  Duration get pollInterval => const Duration(milliseconds: 100);

  @override
  ReduxAction<AppState> createPollingAction() => NonReentrantWorker();

  @override
  AppState? reduce() => null;
}

class NonReentrantWorker extends ReduxAction<AppState> with NonReentrant {
  static int concurrentRuns = 0;
  static int maxConcurrentRuns = 0;
  static int abortedCount = 0;

  static void reset() {
    concurrentRuns = 0;
    maxConcurrentRuns = 0;
    abortedCount = 0;
  }

  @override
  bool abortDispatch() {
    var abort = super.abortDispatch();
    if (abort) abortedCount++;
    return abort;
  }

  @override
  Future<AppState?> reduce() async {
    concurrentRuns++;
    if (concurrentRuns > maxConcurrentRuns) maxConcurrentRuns = concurrentRuns;
    try {
      await Future.delayed(const Duration(milliseconds: 250));
      return state.copy(count: state.count + 1);
    } finally {
      concurrentRuns--;
    }
  }
}

// =============================================================================
// Fixed-rate controller + Sequential worker (Option 2 pattern)
// =============================================================================

class SequentialControllerAction extends ReduxAction<AppState> with Polling {
  @override
  final Poll poll;

  SequentialControllerAction({required this.poll});

  @override
  bool get pollWaitsForRun => false;

  @override
  Duration get pollInterval => const Duration(milliseconds: 100);

  @override
  ReduxAction<AppState> createPollingAction() => SequentialWorker();

  @override
  AppState? reduce() => null;
}

class SequentialWorker extends ReduxAction<AppState> with Sequential {
  static int concurrentRuns = 0;
  static int maxConcurrentRuns = 0;

  static void reset() {
    concurrentRuns = 0;
    maxConcurrentRuns = 0;
  }

  @override
  Object? sequentialKeyParams() => 'polling-worker';

  @override
  Future<AppState?> reduce() async {
    concurrentRuns++;
    if (concurrentRuns > maxConcurrentRuns) maxConcurrentRuns = concurrentRuns;
    try {
      await Future.delayed(const Duration(milliseconds: 250));
      return state.copy(count: state.count + 1);
    } finally {
      concurrentRuns--;
    }
  }
}

// =============================================================================
// Polling combined with Throttle and NonReentrant, on the CONTROLLER action
// =============================================================================

class ThrottledPollAction extends ReduxAction<AppState> with Throttle, Polling {
  @override
  final Poll poll;

  ThrottledPollAction({required this.poll});

  @override
  int get throttle => 1000;

  @override
  Duration get pollInterval => const Duration(milliseconds: 100);

  @override
  ReduxAction<AppState> createPollingAction() => SimpleWorkerAction();

  @override
  AppState reduce() => state.copy(count: state.count + 1);
}

class SimpleWorkerAction extends ReduxAction<AppState> {
  @override
  AppState reduce() => state.copy(count: state.count + 1);
}

class NonReentrantPollAction extends ReduxAction<AppState>
    with NonReentrant, Polling {
  @override
  final Poll poll;

  NonReentrantPollAction({required this.poll});

  @override
  Duration get pollInterval => const Duration(milliseconds: 100);

  @override
  ReduxAction<AppState> createPollingAction() =>
      NonReentrantPollAction(poll: Poll.once);

  @override
  Future<AppState?> reduce() async {
    await Future.delayed(const Duration(milliseconds: 250));
    return state.copy(count: state.count + 1);
  }
}

// =============================================================================
// Polling action with a zero interval
// =============================================================================

class ZeroIntervalPollAction extends ReduxAction<AppState> with Polling {
  static int concurrentRuns = 0;
  static int maxConcurrentRuns = 0;

  static void reset() {
    concurrentRuns = 0;
    maxConcurrentRuns = 0;
  }

  @override
  final Poll poll;

  ZeroIntervalPollAction({required this.poll});

  @override
  Duration get pollInterval => Duration.zero;

  @override
  ReduxAction<AppState> createPollingAction() =>
      ZeroIntervalPollAction(poll: Poll.once);

  @override
  Future<AppState?> reduce() async {
    concurrentRuns++;
    if (concurrentRuns > maxConcurrentRuns) maxConcurrentRuns = concurrentRuns;
    try {
      await Future.delayed(const Duration(milliseconds: 50));
      return state.copy(count: state.count + 1);
    } finally {
      concurrentRuns--;
    }
  }
}

// =============================================================================
// Slow polling action — each run takes 250ms, and the poll interval is 100ms
// =============================================================================

class SlowPollAction extends ReduxAction<AppState> with Polling {
  /// How many runs are in progress right now.
  static int concurrentRuns = 0;

  /// The maximum number of runs that were ever in progress at the same time.
  static int maxConcurrentRuns = 0;

  static void reset() {
    concurrentRuns = 0;
    maxConcurrentRuns = 0;
  }

  @override
  final Poll poll;

  @override
  final bool pollWaitsForRun;

  SlowPollAction({required this.poll, this.pollWaitsForRun = true});

  @override
  Duration get pollInterval => const Duration(milliseconds: 100);

  @override
  ReduxAction<AppState> createPollingAction() =>
      SlowPollAction(poll: Poll.once, pollWaitsForRun: pollWaitsForRun);

  @override
  Future<AppState?> reduce() async {
    concurrentRuns++;
    if (concurrentRuns > maxConcurrentRuns) maxConcurrentRuns = concurrentRuns;
    try {
      await Future.delayed(const Duration(milliseconds: 250));
      return state.copy(count: state.count + 1);
    } finally {
      concurrentRuns--;
    }
  }
}

// =============================================================================
// Test state
// =============================================================================

class AppState {
  final int count;

  AppState(this.count);

  AppState copy({int? count}) => AppState(count ?? this.count);

  @override
  String toString() => 'AppState($count)';
}

// =============================================================================
// Simple polling action — increments count by 1, 100ms interval
// =============================================================================

class SimplePollAction extends ReduxAction<AppState> with Polling {
  @override
  final Poll poll;

  SimplePollAction({required this.poll});

  @override
  Duration get pollInterval => const Duration(milliseconds: 100);

  @override
  ReduxAction<AppState> createPollingAction() =>
      SimplePollAction(poll: Poll.once);

  @override
  AppState reduce() => state.copy(count: state.count + 1);
}

// =============================================================================
// Two independent action types for testing independent timers
// =============================================================================

class PollActionA extends ReduxAction<AppState> with Polling {
  @override
  final Poll poll;

  PollActionA({required this.poll});

  @override
  Duration get pollInterval => const Duration(milliseconds: 100);

  @override
  ReduxAction<AppState> createPollingAction() => PollActionA(poll: Poll.once);

  @override
  AppState reduce() => state.copy(count: state.count + 1);
}

class PollActionB extends ReduxAction<AppState> with Polling {
  @override
  final Poll poll;

  PollActionB({required this.poll});

  @override
  Duration get pollInterval => const Duration(milliseconds: 100);

  @override
  ReduxAction<AppState> createPollingAction() => PollActionB(poll: Poll.once);

  @override
  AppState reduce() => state.copy(count: state.count + 1);
}

// =============================================================================
// Action with pollingKeyParams
// =============================================================================

class ParamPollAction extends ReduxAction<AppState> with Polling {
  final String param;
  @override
  final Poll poll;

  ParamPollAction(this.param, {required this.poll});

  @override
  Duration get pollInterval => const Duration(milliseconds: 100);

  @override
  Object? pollingKeyParams() => param;

  @override
  ReduxAction<AppState> createPollingAction() =>
      ParamPollAction(param, poll: Poll.once);

  @override
  AppState reduce() => state.copy(count: state.count + 1);
}

// =============================================================================
// Action with tuple pollingKeyParams
// =============================================================================

class TupleParamPollAction extends ReduxAction<AppState> with Polling {
  final String userId;
  final String walletId;
  @override
  final Poll poll;

  TupleParamPollAction(this.userId, this.walletId, {required this.poll});

  @override
  Duration get pollInterval => const Duration(milliseconds: 100);

  @override
  Object? pollingKeyParams() => (userId, walletId);

  @override
  ReduxAction<AppState> createPollingAction() =>
      TupleParamPollAction(userId, walletId, poll: Poll.once);

  @override
  AppState reduce() => state.copy(count: state.count + 1);
}

// =============================================================================
// Shared key across action types
// =============================================================================

class SharedKeyActionA extends ReduxAction<AppState> with Polling {
  @override
  final Poll poll;

  SharedKeyActionA({required this.poll});

  @override
  Duration get pollInterval => const Duration(milliseconds: 100);

  @override
  Object computePollingKey() => 'shared-timer';

  @override
  ReduxAction<AppState> createPollingAction() =>
      SharedKeyActionA(poll: Poll.once);

  @override
  AppState reduce() => state.copy(count: state.count + 1);
}

class SharedKeyActionB extends ReduxAction<AppState> with Polling {
  @override
  final Poll poll;

  SharedKeyActionB({required this.poll});

  @override
  Duration get pollInterval => const Duration(milliseconds: 100);

  @override
  Object computePollingKey() => 'shared-timer';

  @override
  ReduxAction<AppState> createPollingAction() =>
      SharedKeyActionB(poll: Poll.once);

  @override
  AppState reduce() => state.copy(count: state.count + 1);
}

// =============================================================================
// Option 1: Single action pattern
// =============================================================================

class SingleAction extends ReduxAction<AppState> with Polling {
  @override
  final Poll poll;

  SingleAction({this.poll = Poll.once});

  @override
  Duration get pollInterval => const Duration(milliseconds: 100);

  @override
  ReduxAction<AppState> createPollingAction() => SingleAction(poll: Poll.once);

  @override
  AppState reduce() => state.copy(count: state.count + 1);
}

// =============================================================================
// Option 2: Controller + Worker pattern
// =============================================================================

class ControllerAction extends ReduxAction<AppState> with Polling {
  @override
  final Poll poll;

  ControllerAction({required this.poll});

  @override
  Duration get pollInterval => const Duration(milliseconds: 100);

  @override
  ReduxAction<AppState> createPollingAction() => WorkerAction();

  @override
  AppState reduce() => state.copy(count: state.count + 1);
}

class WorkerAction extends ReduxAction<AppState> {
  @override
  AppState reduce() => state.copy(count: state.count + 10);
}

// =============================================================================
// Incompatible mixin combinations
// =============================================================================

// Action that combines Polling with Retry (incompatible)
class PollingWithRetryAction extends ReduxAction<AppState>
    with
        Retry,
        // ignore: private_collision_in_mixin_application
        Polling {
  @override
  final Poll poll;

  PollingWithRetryAction({required this.poll});

  @override
  Duration get pollInterval => const Duration(milliseconds: 100);

  @override
  ReduxAction<AppState> createPollingAction() =>
      PollingWithRetryAction(poll: Poll.once);

  @override
  AppState reduce() => state.copy(count: state.count + 1);
}

// Action that combines Polling with UnlimitedRetries (incompatible)
class PollingWithUnlimitedRetriesAction extends ReduxAction<AppState>
    with
        Retry<AppState>,
        UnlimitedRetries,
        // ignore: private_collision_in_mixin_application
        Polling {
  @override
  final Poll poll;

  PollingWithUnlimitedRetriesAction({required this.poll});

  @override
  Duration get pollInterval => const Duration(milliseconds: 100);

  @override
  ReduxAction<AppState> createPollingAction() =>
      PollingWithUnlimitedRetriesAction(poll: Poll.once);

  @override
  AppState reduce() => state.copy(count: state.count + 1);
}

// Action that combines Polling with Debounce (incompatible)
class PollingWithDebounceAction extends ReduxAction<AppState>
    with
        Debounce,
        // ignore: private_collision_in_mixin_application
        Polling {
  @override
  final Poll poll;

  PollingWithDebounceAction({required this.poll});

  @override
  Duration get pollInterval => const Duration(milliseconds: 100);

  @override
  ReduxAction<AppState> createPollingAction() =>
      PollingWithDebounceAction(poll: Poll.once);

  @override
  AppState reduce() => state.copy(count: state.count + 1);
}

// Action that combines Polling with UnlimitedRetryCheckInternet (incompatible)
class PollingWithUnlimitedRetryCheckInternetAction
    extends ReduxAction<AppState>
    with
        UnlimitedRetryCheckInternet,
        // ignore: private_collision_in_mixin_application
        Polling {
  @override
  final Poll poll;

  PollingWithUnlimitedRetryCheckInternetAction({required this.poll});

  @override
  Duration get pollInterval => const Duration(milliseconds: 100);

  @override
  ReduxAction<AppState> createPollingAction() =>
      PollingWithUnlimitedRetryCheckInternetAction(poll: Poll.once);

  @override
  AppState reduce() => state.copy(count: state.count + 1);
}

// Action that combines Polling with OptimisticCommand (incompatible)
class PollingWithOptimisticCommandAction extends ReduxAction<AppState>
    with
        OptimisticCommand,
        // ignore: private_collision_in_mixin_application
        Polling {
  @override
  final Poll poll;

  PollingWithOptimisticCommandAction({required this.poll});

  @override
  Duration get pollInterval => const Duration(milliseconds: 100);

  @override
  ReduxAction<AppState> createPollingAction() =>
      PollingWithOptimisticCommandAction(poll: Poll.once);

  @override
  Object? optimisticValue() => null;

  @override
  AppState applyValueToState(AppState state, Object? value) => state;

  @override
  Object? getValueFromState(AppState state) => null;

  @override
  Future<Object?> sendCommandToServer(Object? optimisticValue) async => null;

  @override
  Future<AppState?> reduce() async => state.copy(count: state.count + 1);
}

// Action that combines Polling with OptimisticSync (incompatible)
class PollingWithOptimisticSyncAction extends ReduxAction<AppState>
    with
        OptimisticSync<AppState, int>,
        // ignore: private_collision_in_mixin_application
        Polling {
  @override
  final Poll poll;

  PollingWithOptimisticSyncAction({required this.poll});

  @override
  Duration get pollInterval => const Duration(milliseconds: 100);

  @override
  ReduxAction<AppState> createPollingAction() =>
      PollingWithOptimisticSyncAction(poll: Poll.once);

  @override
  int valueToApply() => 0;

  @override
  AppState applyOptimisticValueToState(AppState state, int optimisticValue) =>
      state;

  @override
  AppState? applyServerResponseToState(AppState state, Object serverResponse) =>
      null;

  @override
  int getValueFromState(AppState state) => state.count;

  @override
  Future<Object?> sendValueToServer(Object? optimisticValue) async => null;

  @override
  Future<AppState?> reduce() async => state.copy(count: state.count + 1);
}

// Action that combines Polling with OptimisticSyncWithPush (incompatible)
class PollingWithOptimisticSyncWithPushAction extends ReduxAction<AppState>
    with
        OptimisticSyncWithPush<AppState, int>,
        // ignore: private_collision_in_mixin_application
        Polling {
  @override
  final Poll poll;

  PollingWithOptimisticSyncWithPushAction({required this.poll});

  @override
  Duration get pollInterval => const Duration(milliseconds: 100);

  @override
  ReduxAction<AppState> createPollingAction() =>
      PollingWithOptimisticSyncWithPushAction(poll: Poll.once);

  @override
  int valueToApply() => 0;

  @override
  AppState applyOptimisticValueToState(AppState state, int optimisticValue) =>
      state;

  @override
  AppState? applyServerResponseToState(AppState state, Object serverResponse) =>
      null;

  @override
  int getValueFromState(AppState state) => state.count;

  @override
  int getServerRevisionFromState(Object? key) => -1;

  @override
  Future<Object?> sendValueToServer(
    Object? optimisticValue,
    int localRevision,
    int deviceId,
  ) async =>
      null;

  @override
  Future<AppState?> reduce() async => state.copy(count: state.count + 1);
}

// Action that combines Polling with ServerPush (incompatible)
class PollingWithServerPushAction extends ReduxAction<AppState>
    with
        ServerPush,
        // ignore: private_collision_in_mixin_application
        Polling {
  @override
  final Poll poll;

  PollingWithServerPushAction({required this.poll});

  @override
  Duration get pollInterval => const Duration(milliseconds: 100);

  @override
  ReduxAction<AppState> createPollingAction() =>
      PollingWithServerPushAction(poll: Poll.once);

  @override
  Type associatedAction() => SimplePollAction;

  @override
  PushMetadata pushMetadata() =>
      (serverRevision: 1, localRevision: 1, deviceId: 1);

  @override
  AppState? applyServerPushToState(
          AppState state, Object? key, int serverRevision) =>
      null;

  @override
  int getServerRevisionFromState(Object? key) => -1;

  @override
  AppState reduce() => state.copy(count: state.count + 1);
}
