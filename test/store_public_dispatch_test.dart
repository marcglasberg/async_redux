import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

// Completion callbacks are intentional: these tests inspect pending dispatches.
// ignore_for_file: async_redux_lints/then_on_dispatch_and_wait

void main() {
  test('initial state is retained by identity and timestamp is UTC', () async {
    final before = DateTime.now().toUtc();
    final initial = <int>[1];
    final store = Store<List<int>>(initialState: initial);
    final after = DateTime.now().toUtc();
    expect(store.state, same(initial));
    _expectTimestampBetween(store.stateTimestamp, before, after);
    expect(store.stateTimestamp, same(store.stateTimestamp));
    await store.teardown();
  });

  test('defineState is immediate and silent to every action observer', () async {
    final observer = _Observer();
    final persistor = _Persistor();
    final cloud = _Persistor();
    final store = Store<int>(
      initialState: 0,
      syncStream: true,
      actionObservers: [observer],
      stateObservers: [_StateObserver(observer)],
      persistor: persistor,
      cloudSync: cloud,
    );
    final events = <int>[];
    final subscription = store.onChange.listen(events.add);
    var completed = false;
    final pending = store.waitCondition((state) => state == 7, timeoutMillis: -1)
      ..then((_) => completed = true);
    final initialTimestamp = store.stateTimestamp;
    final before = DateTime.now().toUtc();
    store.defineState(7);
    final after = DateTime.now().toUtc();
    expect(store.state, 7);
    expect(store.stateTimestamp, isNot(same(initialTimestamp)));
    _expectTimestampBetween(store.stateTimestamp, before, after);
    await Future<void>.value();
    expect(completed, isFalse);
    expect(events, isEmpty);
    expect(observer.calls, 0);
    expect(persistor.writes, isEmpty);
    expect(cloud.writes, isEmpty);
    expect(store.dispatchCount, 0);
    expect(store.reduceCount, 0);
    expect(store.actionsInProgress(), isEmpty);
    final action = _Increment(0);
    store.dispatchSync(action);
    expect(await pending, same(action));
    expect(observer.calls, 3);
    await subscription.cancel();
    await store.teardown();
  });

  test('defineState accepts null and equal but nonidentical state', () async {
    final store = Store<List<int>?>(initialState: [1]);
    final replacement = <int>[1];
    store.defineState(replacement);
    expect(store.state, same(replacement));
    final timestamp = store.stateTimestamp;
    store.defineState(null);
    expect(store.state, isNull);
    expect(store.stateTimestamp, isNot(same(timestamp)));
    expect(store.dispatchCount, 0);
    expect(store.reduceCount, 0);
    await store.teardown();
  });

  for (final notify in [false, true]) {
    test('dispatch renews UTC timestamp with notify=$notify', () async {
      final store = Store<int>(initialState: 0);
      final initialTimestamp = store.stateTimestamp;
      final before = DateTime.now().toUtc();
      store.dispatchSync(_Increment(1), notify: notify);
      final after = DateTime.now().toUtc();
      expect(store.state, 1);
      expect(store.stateTimestamp, isNot(same(initialTimestamp)));
      _expectTimestampBetween(store.stateTimestamp, before, after);
      await store.teardown();
    });
  }

  for (final syncStream in [false, true]) {
    test(
      'broadcast subscribers have independent cancellation and pause: $syncStream',
      () async {
        final store = Store<int>(initialState: 0, syncStream: syncStream);
        final first = <int>[];
        final second = <int>[];
        expect(store.onChange.isBroadcast, isTrue);
        final firstSubscription = store.onChange.listen(first.add);
        final secondSubscription = store.onChange.listen(second.add)..pause();
        expect(first, isEmpty); // The initial state is not replayed.
        store.dispatchSync(_Increment(1));
        expect(first, syncStream ? [1] : isEmpty);
        await pumpEventQueue();
        expect(first, [1]);
        expect(second, isEmpty);
        await firstSubscription.cancel();
        store.dispatchSync(_Increment(1));
        secondSubscription.resume();
        await pumpEventQueue();
        expect(first, [1]);
        expect(second, [1, 2]);
        final lateEvents = <int>[];
        final lateSubscription = store.onChange.listen(lateEvents.add);
        await pumpEventQueue();
        expect(lateEvents, isEmpty);
        store.dispatchSync(_Increment(1));
        await pumpEventQueue();
        expect(second, [1, 2, 3]);
        expect(lateEvents, [3]);
        await secondSubscription.cancel();
        await lateSubscription.cancel();
        await store.teardown();
      },
    );

    for (final wait in [false, true]) {
      for (final notify in [false, true]) {
        test('batch forwards notify=$notify to all actions; wait=$wait, '
            'syncStream=$syncStream', () async {
          final store = Store<int>(initialState: 0, syncStream: syncStream);
          final events = <int>[];
          final subscription = store.onChange.listen(events.add);
          final held = _HeldIncrement(10);
          final actions = List<ReduxAction<int>>.unmodifiable([
            _Increment(1),
            held,
            _Increment(2),
          ]);
          Future<List<ReduxAction<int>>>? completion;
          if (wait) {
            completion = store.dispatchAndWaitAll(actions, notify: notify);
          } else {
            expect(store.dispatchAll(actions, notify: notify), same(actions));
          }
          expect(store.state, 3);
          expect(store.dispatchCount, 3);
          expect(store.reduceCount, 3);
          expect(held.status.isCompleted, isFalse);
          held.release();
          if (completion != null) expect(await completion, same(actions));
          await store.waitAllActions([], completeImmediately: true);
          await pumpEventQueue();
          expect(store.state, 13);
          expect(events, notify ? [1, 3, 13] : isEmpty);
          expect(actions.every((action) => action.status.isCompletedOk), isTrue);
          await subscription.cancel();
          await store.teardown();
        });
      }
    }
  }

  for (final wait in [false, true]) {
    test('empty batch is a no-op and returns the original list: wait=$wait', () async {
      final store = Store<int>(initialState: 0);
      final timestamp = store.stateTimestamp;
      final actions = List<ReduxAction<int>>.unmodifiable([]);
      final result = wait
          ? await store.dispatchAndWaitAll(actions)
          : store.dispatchAll(actions);
      expect(result, same(actions));
      expect(store.state, 0);
      expect(store.stateTimestamp, same(timestamp));
      expect(store.dispatchCount, 0);
      expect(store.reduceCount, 0);
      await store.teardown();
    });
  }

  test('dispatchAndWaitAll only waits for the supplied actions', () async {
    final store = Store<int>(initialState: 0);
    final unrelated = _HeldIncrement(100);
    final unrelatedCompletion = store.dispatchAndWait(unrelated);
    final supplied = _HeldIncrement(10);
    final actions = <ReduxAction<int>>[_Increment(1), supplied];
    final completion = store.dispatchAndWaitAll(actions);
    supplied.release();
    expect(await completion, same(actions));
    expect(store.state, 11);
    expect(store.actionsInProgress(), contains(unrelated));
    unrelated.release();
    await unrelatedCompletion;
    expect(store.state, 111);
    await store.teardown();
  });

  test('dispatchAndWaitAllActions timeout starts after its own action finishes', () {
    fakeAsync((clock) {
      final store = Store<int>(initialState: 0);
      final unrelated = _HeldIncrement(100);
      store.dispatch(unrelated);
      final own = _HeldIncrement(1);
      Object? error;
      store
          .dispatchAndWaitAllActions(own, timeoutMillis: 5)
          .then<void>(
            (_) => fail('The unrelated action is still running'),
            onError: (Object value) => error = value,
          );
      clock.elapse(const Duration(days: 1));
      expect(error, isNull);
      own.release();
      clock.flushMicrotasks();
      expect(store.state, 1);
      clock.elapse(const Duration(milliseconds: 4));
      expect(error, isNull);
      clock.elapse(const Duration(milliseconds: 1));
      expect(error, isA<TimeoutException>());
      expect(unrelated.status.isCompleted, isFalse);
      unrelated.release();
      clock.flushMicrotasks();
      expect(store.state, 101);
      store.teardown();
      clock.flushMicrotasks();
    });
  });

  for (final notify in [false, true]) {
    test('dispatchAndWaitAllActions forwards notify=$notify to its own action', () async {
      final store = Store<int>(initialState: 0, syncStream: true);
      final events = <int>[];
      final subscription = store.onChange.listen(events.add);
      final unrelated = _HeldIncrement(100);
      final unrelatedCompletion = store.dispatchAndWait(unrelated, notify: false);
      final own = _Increment(1);
      final completion = store.dispatchAndWaitAllActions(own, notify: notify);
      expect(store.state, 1);
      expect(events, notify ? [1] : isEmpty);
      unrelated.release();
      expect(await completion, same(own.status));
      await unrelatedCompletion;
      expect(events, notify ? [1] : isEmpty);
      await subscription.cancel();
      await store.teardown();
    });
  }

  test('a reducer error preserves state and the previous state timestamp', () async {
    final store = Store<int>(initialState: 0);
    final timestamp = store.stateTimestamp;
    store.dispatchSync(_OutcomeAction('user error'));
    expect(store.state, 0);
    expect(store.stateTimestamp, same(timestamp));
    expect(store.dispatchCount, 1);
    expect(store.reduceCount, 1);
    await store.teardown();
  });

  for (final defaultTimeout in [false, true]) {
    test(
      'dispatchAndWaitAllActions respects store/disabled timeout: $defaultTimeout',
      () {
        fakeAsync((clock) {
          final store = Store<int>(
            initialState: 0,
            options: StoreOptions(defaultTimeoutMillis: 5),
          );
          final unrelated = _HeldIncrement(100);
          store.dispatch(unrelated);
          final own = _Increment(1);
          ActionStatus? status;
          Object? error;
          store
              .dispatchAndWaitAllActions(
                own,
                timeoutMillis: defaultTimeout ? null : -1,
                notify: false,
              )
              .then<void>(
                (value) => status = value,
                onError: (Object value) => error = value,
              );
          clock.flushMicrotasks();
          clock.elapse(const Duration(days: 1));
          expect(status, isNull);
          expect(error, defaultTimeout ? isA<TimeoutException>() : isNull);
          unrelated.release();
          clock.flushMicrotasks();
          if (!defaultTimeout) expect(status, same(own.status));
          expect(store.state, 101);
          store.teardown();
          clock.flushMicrotasks();
        });
      },
    );
  }

  for (final outcome in ['ok', 'user error', 'aborted']) {
    test(
      'dispatchAndWaitAllActions preserves $outcome status while waiting for others',
      () async {
        final store = Store<int>(initialState: 0);
        final unrelated = _HeldIncrement(100);
        final unrelatedCompletion = store.dispatchAndWait(unrelated);
        final own = _OutcomeAction(outcome);
        var completed = false;
        final completion = store.dispatchAndWaitAllActions(own).then((status) {
          completed = true;
          return status;
        });
        await pumpEventQueue();
        expect(completed, isFalse);
        unrelated.release();
        final status = await completion;
        await unrelatedCompletion;
        expect(status.isDispatchAborted, outcome == 'aborted');
        expect(status.isCompletedFailed, outcome == 'user error');
        if (outcome != 'aborted') expect(status, same(own.status));
        expect(store.actionsInProgress(), isEmpty);
        await store.teardown();
      },
    );
  }

  test('shutdown is idempotent and preserves props and the open stream', () async {
    final store = Store<int>(initialState: 0, props: {'kept': 1});
    final events = <int>[];
    var done = false;
    final subscription = store.onChange.listen(events.add, onDone: () => done = true);
    final timestamp = store.stateTimestamp;
    expect(store.isShutdown, isFalse);
    store.shutdown();
    store.shutdown();
    expect(store.isShutdown, isTrue);
    expect(store.stateTimestamp, same(timestamp));
    expect(store.prop<int>('kept'), 1);
    expect(store.dispatchSync(_Increment(1)).isDispatchAborted, isTrue);
    expect((await store.dispatchAndWait(_HeldIncrement(1))).isDispatchAborted, isTrue);
    final batch = <ReduxAction<int>>[_Increment(1), _HeldIncrement(1)];
    expect(await store.dispatchAndWaitAll(batch), same(batch));
    await pumpEventQueue();
    expect(events, isEmpty);
    expect(done, isFalse);
    expect(store.state, 0);
    expect(store.dispatchCount, 0);
    expect(store.reduceCount, 0);
    expect(store.actionsInProgress(), isEmpty);
    await subscription.cancel();
    await store.teardown();
  });
}

void _expectTimestampBetween(DateTime value, DateTime before, DateTime after) {
  expect(value.isUtc, isTrue);
  expect(value.isBefore(before), isFalse);
  expect(value.isAfter(after), isFalse);
}

class _Increment extends ReduxAction<int> {
  _Increment(this.amount);
  final int amount;

  @override
  int reduce() => state + amount;
}

class _HeldIncrement extends ReduxAction<int> {
  _HeldIncrement(this.amount);
  final int amount;
  final _gate = Completer<void>();

  void release() => _gate.complete();

  @override
  Future<int> reduce() async {
    await _gate.future;
    return state + amount;
  }
}

class _OutcomeAction extends ReduxAction<int> {
  _OutcomeAction(this.outcome);
  final String outcome;

  @override
  bool abortDispatch() => outcome == 'aborted';

  @override
  int? reduce() {
    if (outcome == 'user error') throw const UserException('failed').noDialog;
    return null;
  }
}

class _Observer extends ActionObserver<int> {
  var calls = 0;

  @override
  void observe(ReduxAction<int> action, int dispatchCount, {required bool ini}) {
    calls++;
  }
}

class _StateObserver extends StateObserver<int> {
  _StateObserver(this.observer);
  final _Observer observer;

  @override
  void observe(
    ReduxAction<int> action,
    int prevState,
    int newState,
    Object? error,
    int dispatchCount,
  ) {
    observer.calls++;
  }
}

class _Persistor extends Persistor<int> {
  final writes = <int>[];

  @override
  Future<void> persistDifference({
    required int? lastPersistedState,
    required int newState,
  }) async {
    writes.add(newState);
  }

  @override
  Future<void> deleteState() async {}

  @override
  Future<int?> readState() async => null;

  @override
  Future<void> saveInitialState(int state) async {}
}
