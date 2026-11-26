import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

// Capture every completion, then assert the statuses explicitly.
// ignore_for_file: async_redux_lints/then_on_dispatch_and_wait

void main() {
  for (final actionWrapper in [false, true]) {
    for (final storeWrapper in [false, true]) {
      for (final asyncBefore in [false, true]) {
        for (final extraAwait in [false, true]) {
          for (final reverse in [false, true]) {
            test(
              'pending reducers commit in the same microtask: '
              'action wrapper=$actionWrapper, store wrapper=$storeWrapper, '
              'async before=$asyncBefore, extra await=$extraAwait, reverse=$reverse',
              () {
                fakeAsync((async) {
                  final events = <String>[];
                  final store = Store<int>(
                    initialState: 0,
                    wrapReduce: storeWrapper ? _IdentityWrapper() : null,
                    stateObservers: [_Observer(events)],
                  );
                  final gateA = Completer<void>();
                  final gateB = Completer<void>();
                  _GatedAction create(String name, int delta, Future<void> gate) {
                    if (actionWrapper) {
                      return asyncBefore
                          ? _WrappedWithAsyncBefore(name, delta, gate, events, extraAwait)
                          : _Wrapped(name, delta, gate, events, extraAwait);
                    }
                    return asyncBefore
                        ? _WithAsyncBefore(name, delta, gate, events, extraAwait)
                        : _GatedAction(name, delta, gate, events, extraAwait);
                  }

                  final a = create('A', 1, gateA.future);
                  final b = create('B', 10, gateB.future);
                  final statuses = <ActionStatus>[];
                  store.dispatchAndWait(a).then(statuses.add);
                  store.dispatchAndWait(b).then(statuses.add);
                  async.flushMicrotasks();
                  expect(store.state, 0);
                  expect(store.actionsInProgress(), unorderedEquals([a, b]));
                  expect(statuses, isEmpty);
                  expect(events, isEmpty);

                  final first = reverse ? b : a;
                  final second = reverse ? a : b;
                  (reverse ? gateB : gateA).complete();
                  async.flushMicrotasks();
                  final intermediate = first.delta + 100;
                  expect(store.state, intermediate);
                  expect(store.actionsInProgress(), [second]);
                  expect(statuses, [first.status]);
                  expect(events, [
                    'return:${first.name}:0',
                    'state:0->${first.delta}',
                    'microtask:${first.name}:${first.delta}',
                    'state:${first.delta}->$intermediate',
                  ]);

                  (reverse ? gateA : gateB).complete();
                  async.flushMicrotasks();
                  expect(store.state, 211);
                  expect(events.skip(4), [
                    'return:${second.name}:$intermediate',
                    'state:$intermediate->111',
                    'microtask:${second.name}:111',
                    'state:111->211',
                  ]);
                  expect(statuses, [first.status, second.status]);
                  expect(statuses.every((s) => s.isCompletedOk), isTrue);
                  expect(store.actionsInProgress(), isEmpty);
                  expect(store.dispatchCount, 4);
                  expect(store.reduceCount, 4);
                  store.teardown();
                  async.flushMicrotasks();
                });
              },
            );
          }
        }
      }
    }
  }

  for (final actionWrapper in [false, true]) {
    for (final storeWrapper in [false, true]) {
      test('simultaneous completions, wrappers=$actionWrapper/$storeWrapper', () {
        fakeAsync((async) {
          final events = <String>[];
          final gate = Completer<void>();
          final store = Store<int>(
            initialState: 0,
            wrapReduce: storeWrapper ? _IdentityWrapper() : null,
            stateObservers: [_Observer(events)],
          );
          final actions = List.generate(
            20,
            (i) => actionWrapper
                ? _Wrapped('$i', 1, gate.future, events, false)
                : _GatedAction('$i', 1, gate.future, events, false),
          );
          bool finished = false;
          store.dispatchAndWaitAll(actions).then((_) => finished = true);
          expect(store.state, 0);
          expect(finished, isFalse);
          gate.complete();
          async.flushMicrotasks();

          expect(finished, isTrue);
          expect(store.state, 2020);
          expect(actions.every((a) => a.status.isCompletedOk), isTrue);
          expect(store.actionsInProgress(), isEmpty);
          // Each returned state must be visible to the very next reducer.
          expect(events.take(40), [
            for (var i = 0; i < 20; i++) ...['return:$i:$i', 'state:$i->${i + 1}'],
          ]);
          store.teardown();
          async.flushMicrotasks();
        });
      });
    }
  }

  test('an incomplete reducer observes changes dispatched during before and await', () {
    fakeAsync((async) {
      final beforeGate = Completer<void>();
      final reduceGate = Completer<void>();
      final store = Store<int>(initialState: 0);
      final action = _TwoGates(beforeGate.future, reduceGate.future);
      store.dispatch(action);
      store.dispatchSync(_Add(1));
      expect(action.seenAtReduceStart, isNull);
      expect(action.status.hasFinishedMethodBefore, isFalse);
      beforeGate.complete();
      async.flushMicrotasks();
      expect(action.seenAtReduceStart, 1);
      expect(action.status.hasFinishedMethodBefore, isTrue);
      expect(action.status.hasFinishedMethodReduce, isFalse);
      store.dispatchSync(_Add(10));
      reduceGate.complete();
      async.flushMicrotasks();
      expect(action.stateAtDispatch, 0);
      expect(action.seenAfterAwait, 11);
      expect(store.state, 111);
      expect(action.status.isCompletedOk, isTrue);
      store.teardown();
      async.flushMicrotasks();
    });
  });
}

class _GatedAction extends ReduxAction<int> {
  _GatedAction(this.name, this.delta, this.gate, this.events, this.extraAwait);

  final String name;
  final int delta;
  final Future<void> gate;
  final List<String> events;
  final bool extraAwait;

  @override
  Future<int?> reduce() async {
    await gate;
    if (extraAwait) await microtask;
    events.add('return:$name:$state');
    scheduleMicrotask(() {
      events.add('microtask:$name:$state');
      dispatchSync(_Add(100));
    });
    assertUncompletedFuture();
    return state + delta;
  }
}

class _WithAsyncBefore extends _GatedAction {
  _WithAsyncBefore(super.name, super.delta, super.gate, super.events, super.extraAwait);

  @override
  Future<void> before() async => await microtask;
}

class _Wrapped extends _GatedAction {
  _Wrapped(super.name, super.delta, super.gate, super.events, super.extraAwait);

  @override
  Future<int?> wrapReduce(Reducer<int> reduce) async => await reduce();
}

class _WrappedWithAsyncBefore extends _Wrapped {
  _WrappedWithAsyncBefore(
    super.name,
    super.delta,
    super.gate,
    super.events,
    super.extraAwait,
  );

  @override
  Future<void> before() async => await microtask;
}

class _TwoGates extends ReduxAction<int> {
  _TwoGates(this.beforeGate, this.reduceGate);

  final Future<void> beforeGate;
  final Future<void> reduceGate;
  int? seenAtReduceStart;
  int? seenAfterAwait;

  int get stateAtDispatch => initialState;

  @override
  Future<void> before() async => await beforeGate;

  @override
  Future<int?> reduce() async {
    seenAtReduceStart = state;
    await reduceGate;
    seenAfterAwait = state;
    return state + 100;
  }
}

class _Add extends ReduxAction<int> {
  _Add(this.delta);

  final int delta;

  @override
  int reduce() => state + delta;
}

class _IdentityWrapper extends WrapReduce<int> {
  @override
  int process({required int oldState, required int newState}) => newState;
}

class _Observer extends StateObserver<int> {
  _Observer(this.events);

  final List<String> events;

  @override
  void observe(
    ReduxAction<int> action,
    int prevState,
    int newState,
    Object? error,
    int dispatchCount,
  ) {
    events.add('state:$prevState->$newState');
  }
}
