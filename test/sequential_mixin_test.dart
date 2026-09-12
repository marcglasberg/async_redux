import 'package:async_redux/async_redux.dart';
import 'package:bdd_framework/bdd_framework.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart' hide Retry;

/// Records the order in which things happen, so tests can assert on it.
List<String> log = [];

void main() {
  var feature = BddFeature('Sequential mixin');

  setUp(() {
    log = [];
  });

  // ==========================================================================
  // Case 1: Actions run one at a time, in dispatch order
  // ==========================================================================

  Bdd(feature)
      .scenario('Actions run one at a time, in dispatch order.')
      .given('A slow action and a fast action, both with Sequential.')
      .when('The slow action is dispatched, and then the fast one.')
      .then('The fast action only starts after the slow one finishes.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));

    var slow = store.dispatch(SlowAction('A', millis: 60));
    var fast = store.dispatch(SlowAction('B', millis: 1));

    await Future.wait([slow as Future, fast as Future]);

    expect(log, ['A start', 'A end', 'B start', 'B end']);
    expect(store.state.count, 2);
    expect(store.internalMixinProps.sequentialQueueMap, isEmpty);
  });

  // ==========================================================================
  // Case 2: Same type twice also enters the queue
  // ==========================================================================

  Bdd(feature)
      .scenario('Two actions of the same type both run, one after the other.')
      .given('An action with Sequential.')
      .when('It is dispatched twice in a row.')
      .then('Both run (none is aborted), the second after the first.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));

    var first = store.dispatchAndWait(SlowAction('A', millis: 30));
    var second = store.dispatchAndWait(SlowAction('A', millis: 1));

    var statuses = await Future.wait([first, second]);

    expect(statuses[0].isCompletedOk, isTrue);
    expect(statuses[1].isCompletedOk, isTrue);
    expect(log, ['A start', 'A end', 'A start', 'A end']);
    expect(store.state.count, 2);
  });

  // ==========================================================================
  // Case 3: Order is preserved for many dispatches
  // ==========================================================================

  Bdd(feature)
      .scenario('Dispatch order is preserved for many actions of different types.')
      .given('Several actions of different types, all with Sequential.')
      .when('They are dispatched in quick succession, some from a later event-loop turn.')
      .then('They run strictly in the order they were dispatched.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));

    // Random-ish durations, so that a parallel run would reorder them.
    var durations = [40, 5, 25, 1, 15, 3, 30, 2];

    var futures = <Future>[];
    for (int i = 0; i < 4; i++) {
      futures.add(store.dispatch(SlowAction('$i', millis: durations[i])) as Future);
      futures.add(store.dispatch(OtherAction('x$i', millis: durations[i + 4])) as Future);
    }

    // Some more dispatches after an async gap, while the first ones are running.
    await Future.delayed(const Duration(milliseconds: 10));
    futures.add(store.dispatch(SlowAction('late1', millis: 1)) as Future);
    futures.add(store.dispatch(OtherAction('late2', millis: 1)) as Future);

    await Future.wait(futures);

    var expected = <String>[];
    for (var name in ['0', 'x0', '1', 'x1', '2', 'x2', '3', 'x3', 'late1', 'late2']) {
      expected.add('$name start');
      expected.add('$name end');
    }

    expect(log, expected);
    expect(store.state.count, 10);
    expect(store.internalMixinProps.sequentialQueueMap, isEmpty);
  });

  // ==========================================================================
  // Case 4: Different keys run in parallel
  // ==========================================================================

  Bdd(feature)
      .scenario('Actions with different keys do not wait for each other.')
      .given('Actions with Sequential that use a custom key.')
      .when('A slow action with key "A" and a fast action with key "B" are dispatched.')
      .then('The fast action finishes before the slow one.')
      .and('Actions with the same key still wait for each other.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));

    var f1 = store.dispatch(KeyedAction('A1', key: 'A', millis: 50)) as Future;
    var f2 = store.dispatch(KeyedAction('B1', key: 'B', millis: 1)) as Future;
    var f3 = store.dispatch(KeyedAction('A2', key: 'A', millis: 1)) as Future;

    await Future.wait([f1, f2, f3]);

    expect(log, ['A1 start', 'B1 start', 'B1 end', 'A1 end', 'A2 start', 'A2 end']);
    expect(store.internalMixinProps.sequentialQueueMap, isEmpty);
  });

  // ==========================================================================
  // Case 5: Failure releases the queue
  // ==========================================================================

  Bdd(feature)
      .scenario('An action that fails releases the queue.')
      .given('An action that throws in its reducer, followed by a normal action.')
      .when('Both are dispatched.')
      .then('The normal action runs after the failing one.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));

    var f1 = store.dispatchAndWait(FailingAction('F'));
    var f2 = store.dispatchAndWait(SlowAction('A', millis: 1));

    var statuses = await Future.wait([f1, f2]);

    expect(statuses[0].originalError, isA<UserException>());
    expect(statuses[1].isCompletedOk, isTrue);
    expect(log, ['F start', 'A start', 'A end']);
    expect(store.state.count, 1);
    expect(store.internalMixinProps.sequentialQueueMap, isEmpty);
  });

  // ==========================================================================
  // Case 6: Aborting in `before` releases the queue
  // ==========================================================================

  Bdd(feature)
      .scenario('An action aborted in `before` releases the queue.')
      .given('An action that throws AbortDispatchException in `before` (after super.before).')
      .when('It is dispatched, followed by a normal action.')
      .then('The normal action runs.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));

    var f1 = store.dispatchAndWait(AbortInBeforeAction('X'));
    var f2 = store.dispatchAndWait(SlowAction('A', millis: 1));

    var statuses = await Future.wait([f1, f2]);

    expect(statuses[0].isCompletedOk, isFalse);
    expect(statuses[0].originalError, isA<AbortDispatchException>());
    expect(statuses[1].isCompletedOk, isTrue);
    expect(log, ['X before', 'A start', 'A end']);
    expect(store.internalMixinProps.sequentialQueueMap, isEmpty);
  });

  // ==========================================================================
  // Case 7: `abortDispatch` returning true never enters the queue
  // ==========================================================================

  Bdd(feature)
      .scenario('An action whose abortDispatch returns true does not block the queue.')
      .given('An action with Sequential whose abortDispatch returns true.')
      .when('It is dispatched, followed by a normal action.')
      .then('The normal action runs right away.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));

    var status = await store.dispatchAndWait(AbortDispatchAction());
    expect(status.isDispatchAborted, isTrue);
    expect(store.internalMixinProps.sequentialQueueMap, isEmpty);

    await store.dispatchAndWait(SlowAction('A', millis: 1));
    expect(log, ['A start', 'A end']);
  });

  // ==========================================================================
  // Case 8: Overriding `before` and `after` with super calls
  // ==========================================================================

  Bdd(feature)
      .scenario('Overriding before/after with super calls keeps the queue working.')
      .given('An action that overrides before and after, calling super.')
      .when('It is dispatched while a slow action holds the queue.')
      .then('Its own before-code runs only when its turn comes.')
      .and('The queue is released after it finishes.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));

    var f1 = store.dispatch(SlowAction('A', millis: 30)) as Future;
    var f2 = store.dispatch(OverridesBeforeAfterAction('O')) as Future;
    var f3 = store.dispatch(SlowAction('B', millis: 1)) as Future;

    await Future.wait([f1, f2, f3]);

    expect(log, [
      'A start',
      'A end',
      'O before',
      'O reduce',
      'O after',
      'B start',
      'B end',
    ]);
    expect(store.internalMixinProps.sequentialQueueMap, isEmpty);
  });

  // ==========================================================================
  // Case 9: isWaiting and isWaitingInSequentialQueue
  // ==========================================================================

  Bdd(feature)
      .scenario('A queued action counts as waiting.')
      .given('A slow action holding the queue, and another action queued behind it.')
      .when('We check the waiting state while the first one runs.')
      .then('Both are in progress, and only the second is waiting in the queue.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));

    var actionA = SlowAction('A', millis: 30);
    var actionB = SlowAction('B', millis: 1);

    var f1 = store.dispatch(actionA) as Future;
    var f2 = store.dispatch(actionB) as Future;

    expect(store.isWaiting(SlowAction), isTrue);
    expect(actionA.isWaitingInSequentialQueue, isFalse);
    expect(actionB.isWaitingInSequentialQueue, isTrue);

    await f1;

    // B is released by a microtask, so we let the event loop turn once.
    await Future.delayed(Duration.zero);
    expect(actionB.isWaitingInSequentialQueue, isFalse);

    await f2;
    expect(store.isWaiting(SlowAction), isFalse);
  });

  // ==========================================================================
  // Case 10: Dispatching (without waiting) a child in the same queue
  // ==========================================================================

  Bdd(feature)
      .scenario('A running action can dispatch (without awaiting) a child in the same queue.')
      .given('A parent action that dispatches a child with the same queue.')
      .when('The parent is dispatched.')
      .then('The child runs after the parent finishes.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));

    await store.dispatchAndWait(ParentAction());
    await store.waitAllActions(null, completeImmediately: true);

    expect(log, ['parent start', 'parent end', 'child start', 'child end']);
    expect(store.internalMixinProps.sequentialQueueMap, isEmpty);
  });

  // ==========================================================================
  // Case 11: The mixin makes the action async
  // ==========================================================================

  Bdd(feature)
      .scenario('Actions with the mixin are async, even with a sync reducer.')
      .given('An action with Sequential and a sync reducer.')
      .when('dispatchSync is called.')
      .then('It throws, because the action is async.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));

    var action = SyncReducerAction();
    expect(action.isSync(), isFalse);
    expect(() => store.dispatchSync(action), throwsA(isA<StoreException>()));

    await store.dispatchAndWait(SyncReducerAction());
    expect(store.state.count, 1);
  });

  // ==========================================================================
  // Case 12: Clearing the internal props resets the queue
  // ==========================================================================

  Bdd(feature)
      .scenario('Clearing the internal mixin props starts a new queue.')
      .given('A slow action holding the queue.')
      .when('store.internalMixinProps.clear() is called, and another action is dispatched.')
      .then('The new action does not wait for the slow one.')
      .and('The slow action still finishes normally.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));

    var f1 = store.dispatch(SlowAction('A', millis: 40)) as Future;
    store.internalMixinProps.clear();
    var f2 = store.dispatch(SlowAction('B', millis: 1)) as Future;

    await Future.wait([f1, f2]);

    expect(log, ['A start', 'B start', 'B end', 'A end']);
    expect(store.state.count, 2);
    expect(store.internalMixinProps.sequentialQueueMap, isEmpty);
  });

  // ==========================================================================
  // Case 13: Retry while holding the queue
  // ==========================================================================

  Bdd(feature)
      .scenario('Combined with Retry, retries happen while holding the queue.')
      .given('An action with Sequential and Retry, that fails once.')
      .when('It is dispatched, followed by a normal action.')
      .then('The normal action runs only after the retry succeeded.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));

    var f1 = store.dispatchAndWait(RetryOnceAction());
    var f2 = store.dispatchAndWait(SlowAction('A', millis: 1));

    var statuses = await Future.wait([f1, f2]);

    expect(statuses[0].isCompletedOk, isTrue);
    expect(log, ['retry attempt 1', 'retry attempt 2', 'A start', 'A end']);
    expect(store.state.count, 2);
  });

  // ==========================================================================
  // Case 14: Combined with CheckInternet (Sequential listed last)
  // ==========================================================================

  Bdd(feature)
      .scenario('Combined with CheckInternet, the internet check happens when the turn comes.')
      .given('A slow action holding the queue, and an action with CheckInternet and Sequential.')
      .when('The internet action is dispatched with internet on.')
      .then('Its internet check and reducer run only after the slow action finishes.')
      .and('With internet off, it fails and still releases the queue.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));
    store.forceInternetOnOffSimulation = () => true;

    var f1 = store.dispatch(SlowAction('A', millis: 30)) as Future;
    var f2 = store.dispatchAndWait(InternetThenSequentialAction('I'));
    var f3 = store.dispatch(SlowAction('B', millis: 1)) as Future;
    await Future.wait([f1, f2, f3]);

    expect(log, ['A start', 'A end', 'I check', 'I reduce', 'B start', 'B end']);
    expect(store.internalMixinProps.sequentialQueueMap, isEmpty);

    log = [];
    store.forceInternetOnOffSimulation = () => false;

    var status = await store.dispatchAndWait(InternetThenSequentialAction('I'));
    await store.dispatchAndWait(SlowAction('C', millis: 1));

    expect(status.originalError, isA<UserException>());
    expect(log, ['I check', 'C start', 'C end']);
    expect(store.internalMixinProps.sequentialQueueMap, isEmpty);
  });

  // ==========================================================================
  // Case 15: Combined with CheckInternet (Sequential listed first)
  // ==========================================================================

  Bdd(feature)
      .scenario('Combined with CheckInternet in the reverse mixin order, it still works.')
      .given('A slow action holding the queue, and an action with Sequential and CheckInternet.')
      .when('The internet action is dispatched with internet on.')
      .then('Its internet check and reducer run only after the slow action finishes.')
      .and('With internet off, it fails and still releases the queue.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));
    store.forceInternetOnOffSimulation = () => true;

    var f1 = store.dispatch(SlowAction('A', millis: 30)) as Future;
    var f2 = store.dispatchAndWait(SequentialThenInternetAction('I'));
    var f3 = store.dispatch(SlowAction('B', millis: 1)) as Future;
    await Future.wait([f1, f2, f3]);

    expect(log, ['A start', 'A end', 'I check', 'I reduce', 'B start', 'B end']);
    expect(store.internalMixinProps.sequentialQueueMap, isEmpty);

    log = [];
    store.forceInternetOnOffSimulation = () => false;

    var status = await store.dispatchAndWait(SequentialThenInternetAction('I'));
    await store.dispatchAndWait(SlowAction('C', millis: 1));

    expect(status.originalError, isA<UserException>());
    expect(log, ['I check', 'C start', 'C end']);
    expect(store.internalMixinProps.sequentialQueueMap, isEmpty);
  });

  // ==========================================================================
  // Case 16: Combined with AbortWhenNoInternet, in both mixin orders
  // ==========================================================================

  Bdd(feature)
      .scenario('Combined with AbortWhenNoInternet, aborting releases the queue in both mixin orders.')
      .given('Actions with AbortWhenNoInternet and Sequential, in both orders.')
      .when('They are dispatched with internet off, followed by a normal action.')
      .then('Both are aborted, and the normal action runs.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));
    store.forceInternetOnOffSimulation = () => false;

    var f1 = store.dispatchAndWait(AbortInternetThenSequentialAction('X'));
    var f2 = store.dispatchAndWait(SequentialThenAbortInternetAction('Y'));
    var f3 = store.dispatchAndWait(SlowAction('A', millis: 1));
    var statuses = await Future.wait([f1, f2, f3]);

    expect(statuses[0].originalError, isA<AbortDispatchException>());
    expect(statuses[1].originalError, isA<AbortDispatchException>());
    expect(statuses[2].isCompletedOk, isTrue);
    expect(log, ['X check', 'Y check', 'A start', 'A end']);
    expect(store.internalMixinProps.sequentialQueueMap, isEmpty);
  });

  // ==========================================================================
  // Case 17: Combined with NonReentrant, in both mixin orders
  // ==========================================================================

  Bdd(feature)
      .scenario('Combined with NonReentrant, duplicates are dropped and the queue is released.')
      .given('Actions with NonReentrant and Sequential, in both mixin orders.')
      .when('Each is dispatched three times in a row, while a slow action holds the queue.')
      .then('Only the first of each runs, in dispatch order, and the queue ends empty.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));

    var futures = <Future>[
      store.dispatch(SlowAction('A', millis: 20)) as Future,
      for (int i = 0; i < 3; i++) store.dispatchAndWait(NonReentrantThenSequentialAction()),
      for (int i = 0; i < 3; i++) store.dispatchAndWait(SequentialThenNonReentrantAction()),
      store.dispatch(SlowAction('B', millis: 1)) as Future,
    ];
    await Future.wait(futures);

    expect(log, ['A start', 'A end', 'NR1 reduce', 'NR2 reduce', 'B start', 'B end']);
    expect(store.state.count, 4);
    expect(store.internalMixinProps.sequentialQueueMap, isEmpty);
    expect(store.internalMixinProps.nonReentrantKeySet, isEmpty);
  });

  // ==========================================================================
  // Case 18: Combined with Throttle, in both mixin orders
  // ==========================================================================

  Bdd(feature)
      .scenario('Combined with Throttle, throttled dispatches are dropped and the queue is released.')
      .given('Actions with Throttle and Sequential, in both mixin orders.')
      .when('Each is dispatched twice in a row, while a slow action holds the queue.')
      .then('Only the first of each runs, in dispatch order, and the queue ends empty.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));

    var futures = <Future>[
      store.dispatch(SlowAction('A', millis: 20)) as Future,
      store.dispatchAndWait(ThrottleThenSequentialAction()),
      store.dispatchAndWait(ThrottleThenSequentialAction()),
      store.dispatchAndWait(SequentialThenThrottleAction()),
      store.dispatchAndWait(SequentialThenThrottleAction()),
      store.dispatch(SlowAction('B', millis: 1)) as Future,
    ];
    await Future.wait(futures);

    expect(log, ['A start', 'A end', 'T1 reduce', 'T2 reduce', 'B start', 'B end']);
    expect(store.state.count, 4);
    expect(store.internalMixinProps.sequentialQueueMap, isEmpty);
  });

  // ==========================================================================
  // Case 19: discardQueueOnError aborts the waiting actions
  // ==========================================================================

  Bdd(feature)
      .scenario('A failing action with discardQueueOnError aborts the actions waiting behind it.')
      .given('A failing action that discards the queue, with two actions queued behind it.')
      .when('It fails, and then another action is dispatched.')
      .then('The two queued actions are aborted without running.')
      .and('The action dispatched after the failure runs normally.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));

    var failing = DiscardingFailAction('F');
    var queuedA = SlowAction('A', millis: 1);
    var queuedB = OtherAction('B', millis: 1);

    var f1 = store.dispatchAndWait(failing);
    var f2 = store.dispatchAndWait(queuedA);
    var f3 = store.dispatchAndWait(queuedB);
    expect(queuedA.isWaitingInSequentialQueue, isTrue);

    var status1 = await f1;
    expect(status1.originalError, isA<UserException>());

    var f4 = store.dispatchAndWait(SlowAction('C', millis: 1));
    var statuses = await Future.wait([f2, f3, f4]);

    expect(statuses[0].originalError, isA<AbortDispatchException>());
    expect(statuses[1].originalError, isA<AbortDispatchException>());
    expect(statuses[2].isCompletedOk, isTrue);
    expect(queuedA.wasDiscardedFromSequentialQueue, isTrue);
    expect(queuedB.wasDiscardedFromSequentialQueue, isTrue);
    expect(queuedA.isWaitingInSequentialQueue, isFalse);
    expect(failing.wasDiscardedFromSequentialQueue, isFalse);
    expect(log, ['F start', 'C start', 'C end']);
    expect(store.state.count, 1);
    expect(store.internalMixinProps.sequentialQueueMap, isEmpty);
  });

  // ==========================================================================
  // Case 20: discardQueueOnError can ignore some errors
  // ==========================================================================

  Bdd(feature)
      .scenario('discardQueueOnError receives the error, and may keep the queue for some errors.')
      .given('An action that discards the queue only for errors that are not AbortDispatchException.')
      .when('It is aborted in before, with an action queued behind it.')
      .then('The queued action still runs.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));

    var f1 = store.dispatchAndWait(DiscardingAbortInBeforeAction('X'));
    var f2 = store.dispatchAndWait(SlowAction('A', millis: 1));
    var statuses = await Future.wait([f1, f2]);

    expect(statuses[0].originalError, isA<AbortDispatchException>());
    expect(statuses[1].isCompletedOk, isTrue);
    expect(log, ['X before', 'A start', 'A end']);
    expect(store.internalMixinProps.sequentialQueueMap, isEmpty);
  });

  // ==========================================================================
  // Case 21: Discarding only affects the same key
  // ==========================================================================

  Bdd(feature)
      .scenario('Discarding the queue only affects actions with the same key.')
      .given('A failing action that discards the queue, with actions queued in its key and in another key.')
      .when('It fails.')
      .then('Only the actions in the same key are aborted.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));

    var f1 = store.dispatchAndWait(DiscardingFailAction('F', key: 'A'));
    var f2 = store.dispatchAndWait(KeyedAction('A1', key: 'A', millis: 1));
    var f3 = store.dispatchAndWait(KeyedAction('B1', key: 'B', millis: 30));
    var f4 = store.dispatchAndWait(KeyedAction('B2', key: 'B', millis: 1));
    var statuses = await Future.wait([f1, f2, f3, f4]);

    expect(statuses[0].originalError, isA<UserException>());
    expect(statuses[1].originalError, isA<AbortDispatchException>());
    expect(statuses[2].isCompletedOk, isTrue);
    expect(statuses[3].isCompletedOk, isTrue);
    expect(log, ['F start', 'B1 start', 'B1 end', 'B2 start', 'B2 end']);
    expect(store.internalMixinProps.sequentialQueueMap, isEmpty);
  });

  // ==========================================================================
  // Case 22: A discarded action does not release or block anyone
  // ==========================================================================

  Bdd(feature)
      .scenario('Discarded actions finish without disturbing a queue started after the discard.')
      .given('A failing action that discards the queue, with several actions queued behind it.')
      .when('It fails, and new actions are dispatched right away, before the discarded ones finish.')
      .then('The new actions run in order, exactly once.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));

    var futures = <Future<ActionStatus>>[
      store.dispatchAndWait(DiscardingFailAction('F')),
      for (int i = 0; i < 5; i++) store.dispatchAndWait(SlowAction('old$i', millis: 1)),
    ];
    await futures.first;

    // Dispatched synchronously right after the failure, while the discarded
    // actions have not finished yet.
    futures.add(store.dispatchAndWait(SlowAction('new1', millis: 10)));
    futures.add(store.dispatchAndWait(SlowAction('new2', millis: 1)));
    await Future.wait(futures);

    expect(log, ['F start', 'new1 start', 'new1 end', 'new2 start', 'new2 end']);
    expect(store.state.count, 2);
    expect(store.internalMixinProps.sequentialQueueMap, isEmpty);
  });

  // ==========================================================================
  // Sequential cannot be combined with Debounce, OptimisticSync,
  // OptimisticSyncWithPush or ServerPush.
  // ==========================================================================

  Bdd(feature)
      .scenario('Sequential cannot be combined with Debounce.')
      .given('An action that combines Sequential and Debounce.')
      .when('The action is dispatched.')
      .then('It fails with an AssertionError.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));

    await expectLater(
      store.dispatchAndWait(SequentialWithDebounceAction()),
      throwsA(isA<AssertionError>().having(
        (error) => error.message,
        'message',
        'The Sequential mixin cannot be combined with the Debounce mixin.',
      )),
    );
  });

  Bdd(feature)
      .scenario('Sequential cannot be combined with UnlimitedRetryCheckInternet.')
      .given('An action that combines Sequential and UnlimitedRetryCheckInternet.')
      .when('The action is dispatched.')
      .then('It fails with an AssertionError.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));

    expect(
      () => store.dispatchAndWait(SequentialWithUnlimitedRetryCheckInternetAction()),
      throwsA(isA<AssertionError>().having(
        (error) => error.message,
        'message',
        'The UnlimitedRetryCheckInternet mixin cannot be combined '
            'with the Sequential mixin.',
      )),
    );
  });

  Bdd(feature)
      .scenario('Sequential cannot be combined with OptimisticSync.')
      .given('An action that combines Sequential and OptimisticSync.')
      .when('The action is dispatched.')
      .then('It fails with an AssertionError.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));

    await expectLater(
      store.dispatchAndWait(SequentialWithOptimisticSyncAction()),
      throwsA(isA<AssertionError>().having(
        (error) => error.message,
        'message',
        'The Sequential mixin cannot be combined '
            'with the OptimisticSync mixin.',
      )),
    );
  });

  Bdd(feature)
      .scenario('Sequential cannot be combined with OptimisticSyncWithPush.')
      .given('An action that combines Sequential and OptimisticSyncWithPush.')
      .when('The action is dispatched.')
      .then('It fails with an AssertionError.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));

    await expectLater(
      store.dispatchAndWait(SequentialWithOptimisticSyncWithPushAction()),
      throwsA(isA<AssertionError>().having(
        (error) => error.message,
        'message',
        'The Sequential mixin cannot be combined '
            'with the OptimisticSyncWithPush mixin.',
      )),
    );
  });

  Bdd(feature)
      .scenario('Sequential cannot be combined with ServerPush.')
      .given('An action that combines Sequential and ServerPush.')
      .when('The action is dispatched.')
      .then('It fails with an AssertionError.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));

    await expectLater(
      store.dispatchAndWait(SequentialWithServerPushAction()),
      throwsA(isA<AssertionError>().having(
        (error) => error.message,
        'message',
        'The Sequential mixin cannot be combined with the ServerPush mixin.',
      )),
    );
  });
}


// ============================================================================
// State and actions
// ============================================================================

class State {
  final int count;

  State(this.count);

  @override
  String toString() => 'State($count)';
}

/// Logs start/end and takes [millis] to finish.
class SlowAction extends ReduxAction<State> with Sequential {
  final String name;
  final int millis;

  SlowAction(this.name, {required this.millis});

  @override
  Future<State?> reduce() async {
    log.add('$name start');
    await Future.delayed(Duration(milliseconds: millis));
    log.add('$name end');
    return State(state.count + 1);
  }
}

/// A different type, sharing the default (null) queue with [SlowAction].
class OtherAction extends ReduxAction<State> with Sequential {
  final String name;
  final int millis;

  OtherAction(this.name, {required this.millis});

  @override
  Future<State?> reduce() async {
    log.add('$name start');
    await Future.delayed(Duration(milliseconds: millis));
    log.add('$name end');
    return State(state.count + 1);
  }
}

class KeyedAction extends ReduxAction<State> with Sequential {
  final String name;
  final String key;
  final int millis;

  KeyedAction(this.name, {required this.key, required this.millis});

  @override
  Object? sequentialKeyParams() => key;

  @override
  Future<State?> reduce() async {
    log.add('$name start');
    await Future.delayed(Duration(milliseconds: millis));
    log.add('$name end');
    return null;
  }
}

class FailingAction extends ReduxAction<State> with Sequential {
  final String name;

  FailingAction(this.name);

  @override
  Future<State?> reduce() async {
    log.add('$name start');
    await Future.delayed(const Duration(milliseconds: 5));
    throw const UserException('Failed on purpose.');
  }
}

class AbortInBeforeAction extends ReduxAction<State> with Sequential {
  final String name;

  AbortInBeforeAction(this.name);

  @override
  Future<void> before() async {
    await super.before();
    log.add('$name before');
    throw AbortDispatchException();
  }

  @override
  Future<State?> reduce() async {
    log.add('$name reduce'); // Should never happen.
    return null;
  }
}

class AbortDispatchAction extends ReduxAction<State> with Sequential {
  @override
  bool abortDispatch() => true;

  @override
  Future<State?> reduce() async {
    log.add('aborted reduce'); // Should never happen.
    return null;
  }
}

class OverridesBeforeAfterAction extends ReduxAction<State> with Sequential {
  final String name;

  OverridesBeforeAfterAction(this.name);

  @override
  Future<void> before() async {
    await super.before();
    log.add('$name before');
  }

  @override
  Future<State?> reduce() async {
    log.add('$name reduce');
    return null;
  }

  @override
  void after() {
    try {
      log.add('$name after');
    } finally {
      super.after();
    }
  }
}

class ParentAction extends ReduxAction<State> with Sequential {
  @override
  Future<State?> reduce() async {
    log.add('parent start');
    // Note: We must NOT `await dispatchAndWait(ChildAction())` here,
    // because the child would wait for the parent, and the parent for the
    // child (a deadlock). We just dispatch it without waiting.
    dispatch(ChildAction());
    await Future.delayed(const Duration(milliseconds: 10));
    log.add('parent end');
    return null;
  }
}

class ChildAction extends ReduxAction<State> with Sequential {
  @override
  Future<State?> reduce() async {
    log.add('child start');
    await Future.delayed(const Duration(milliseconds: 1));
    log.add('child end');
    return null;
  }
}

class SyncReducerAction extends ReduxAction<State> with Sequential {
  @override
  State? reduce() => State(state.count + 1);
}

class RetryOnceAction extends ReduxAction<State> with Retry, Sequential {
  int _attempt = 0;

  @override
  Duration get initialDelay => const Duration(milliseconds: 1);

  @override
  Future<State?> reduce() async {
    _attempt++;
    log.add('retry attempt $_attempt');
    await Future.delayed(const Duration(milliseconds: 5));
    if (_attempt == 1) throw const UserException('Fails the first time.');
    return State(state.count + 1);
  }
}

class InternetThenSequentialAction extends ReduxAction<State>
    with CheckInternet, Sequential {
  final String name;

  InternetThenSequentialAction(this.name);

  @override
  Future<List<ConnectivityResult>> checkConnectivity() {
    log.add('$name check');
    return super.checkConnectivity();
  }

  @override
  Future<State?> reduce() async {
    log.add('$name reduce');
    return null;
  }
}

class SequentialThenInternetAction extends ReduxAction<State>
    with Sequential, CheckInternet {
  final String name;

  SequentialThenInternetAction(this.name);

  @override
  Future<List<ConnectivityResult>> checkConnectivity() {
    log.add('$name check');
    return super.checkConnectivity();
  }

  @override
  Future<State?> reduce() async {
    log.add('$name reduce');
    return null;
  }
}

class AbortInternetThenSequentialAction extends ReduxAction<State>
    with AbortWhenNoInternet, Sequential {
  final String name;

  AbortInternetThenSequentialAction(this.name);

  @override
  Future<List<ConnectivityResult>> checkConnectivity() {
    log.add('$name check');
    return super.checkConnectivity();
  }

  @override
  Future<State?> reduce() async {
    log.add('$name reduce'); // Should never happen.
    return null;
  }
}

class SequentialThenAbortInternetAction extends ReduxAction<State>
    with Sequential, AbortWhenNoInternet {
  final String name;

  SequentialThenAbortInternetAction(this.name);

  @override
  Future<List<ConnectivityResult>> checkConnectivity() {
    log.add('$name check');
    return super.checkConnectivity();
  }

  @override
  Future<State?> reduce() async {
    log.add('$name reduce'); // Should never happen.
    return null;
  }
}

class NonReentrantThenSequentialAction extends ReduxAction<State>
    with NonReentrant, Sequential {
  @override
  Future<State?> reduce() async {
    log.add('NR1 reduce');
    await Future.delayed(const Duration(milliseconds: 5));
    return State(state.count + 1);
  }
}

class SequentialThenNonReentrantAction extends ReduxAction<State>
    with Sequential, NonReentrant {
  @override
  Future<State?> reduce() async {
    log.add('NR2 reduce');
    await Future.delayed(const Duration(milliseconds: 5));
    return State(state.count + 1);
  }
}

class ThrottleThenSequentialAction extends ReduxAction<State>
    with Throttle, Sequential {
  @override
  Future<State?> reduce() async {
    log.add('T1 reduce');
    await Future.delayed(const Duration(milliseconds: 5));
    return State(state.count + 1);
  }
}

class SequentialThenThrottleAction extends ReduxAction<State>
    with Sequential, Throttle {
  @override
  Future<State?> reduce() async {
    log.add('T2 reduce');
    await Future.delayed(const Duration(milliseconds: 5));
    return State(state.count + 1);
  }
}

/// Fails in `reduce`, and discards the queue.
class DiscardingFailAction extends ReduxAction<State> with Sequential {
  final String name;
  final Object? key;

  DiscardingFailAction(this.name, {this.key});

  @override
  Object? sequentialKeyParams() => key;

  @override
  bool discardQueueOnError(Object error) => true;

  @override
  Future<State?> reduce() async {
    log.add('$name start');
    await Future.delayed(const Duration(milliseconds: 10));
    throw const UserException('Failed on purpose.');
  }
}

/// Aborts in `before`, and discards the queue only for real errors.
class DiscardingAbortInBeforeAction extends ReduxAction<State> with Sequential {
  final String name;

  DiscardingAbortInBeforeAction(this.name);

  @override
  bool discardQueueOnError(Object error) => error is! AbortDispatchException;

  @override
  Future<void> before() async {
    await super.before();
    log.add('$name before');
    throw AbortDispatchException();
  }

  @override
  Future<State?> reduce() async {
    log.add('$name reduce'); // Should never happen.
    return null;
  }
}

/// Combines Sequential and Debounce (not allowed).
class SequentialWithDebounceAction extends ReduxAction<State>
    with Sequential, Debounce {
  @override
  State? reduce() => null;
}

/// Combines Sequential and UnlimitedRetryCheckInternet (not allowed).
class SequentialWithUnlimitedRetryCheckInternetAction extends ReduxAction<State>
    with Sequential, UnlimitedRetryCheckInternet {
  @override
  State? reduce() => null;
}

/// Combines Sequential and OptimisticSync (not allowed).
class SequentialWithOptimisticSyncAction extends ReduxAction<State>
    with Sequential, OptimisticSync<State, int> {
  @override
  int valueToApply() => 1;

  @override
  State applyOptimisticValueToState(State state, int optimisticValue) =>
      State(optimisticValue);

  @override
  State? applyServerResponseToState(State state, Object serverResponse) => null;

  @override
  int getValueFromState(State state) => state.count;

  @override
  Future<Object?> sendValueToServer(Object? optimisticValue) async => null;
}

/// Combines Sequential and OptimisticSyncWithPush (not allowed).
class SequentialWithOptimisticSyncWithPushAction extends ReduxAction<State>
    with Sequential, OptimisticSyncWithPush<State, int> {
  @override
  int valueToApply() => 1;

  @override
  State applyOptimisticValueToState(State state, int optimisticValue) =>
      State(optimisticValue);

  @override
  State? applyServerResponseToState(State state, Object serverResponse) => null;

  @override
  int getValueFromState(State state) => state.count;

  @override
  int getServerRevisionFromState(Object? key) => -1;

  @override
  Future<Object?> sendValueToServer(
    Object? optimisticValue,
    int localRevision,
    int deviceId,
  ) async =>
      null;
}

/// Combines Sequential and ServerPush (not allowed).
class SequentialWithServerPushAction extends ReduxAction<State>
    with Sequential, ServerPush {
  @override
  Type associatedAction() => SequentialWithOptimisticSyncWithPushAction;

  @override
  PushMetadata pushMetadata() =>
      (serverRevision: 1, localRevision: 1, deviceId: 1);

  @override
  State? applyServerPushToState(State state, Object? key, int serverRevision) =>
      null;

  @override
  int getServerRevisionFromState(Object? key) => -1;
}
