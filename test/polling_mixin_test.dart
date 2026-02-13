import 'package:async_redux/async_redux.dart';
import 'package:bdd_framework/bdd_framework.dart';
import 'package:fake_async/fake_async.dart';
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

  // ---------------------------------------------------------------------------
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
