import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

// The callback must capture both successful and failed completion statuses.
// ignore_for_file: async_redux_lints/then_on_dispatch_and_wait

void main() {
  test('abortDispatch sees the store but runs no lifecycle or observers', () async {
    final events = <String>[];
    final store = _store(events);
    final action = _Sync(events)..abort = () => true;
    final result = store.dispatchSync(action);
    expect(events, ['abort:0']);
    expect(result.isDispatchAborted, isTrue);
    expect(result.isDispatched, isFalse);
    expect(action.status.isDispatchAborted, isFalse);
    expect(action.status.isDispatched, isFalse);
    expect(store.dispatchCount, 0);
    expect(store.reduceCount, 0);
    expect(store.actionsInProgress(), isEmpty);
    await store.teardown();
  });

  test('shutdown short-circuits even abortDispatch', () async {
    final events = <String>[];
    final store = _store(events)..shutdown();
    final action = _Sync(events);
    final result = await store.dispatchAndWait(action);
    expect(store.isShutdown, isTrue);
    expect(result.isDispatchAborted, isTrue);
    expect(events, isEmpty);
    expect(store.dispatchCount, 0);
    expect(store.reduceCount, 0);
    expect(store.state, 0);
    await store.teardown();
  });

  test('abortDispatch errors escape before any lifecycle work', () async {
    final events = <String>[];
    final store = _store(events);
    final error = StateError('abortDispatch');
    final action = _Sync(events)..abort = () => throw error;
    expect(() => store.dispatch(action), throwsA(same(error)));
    expect(events, ['abort:0']);
    expect(action.status.isDispatched, isFalse);
    expect(action.status.originalError, isNull);
    expect(store.dispatchCount, 0);
    expect(store.actionsInProgress(), isEmpty);
    await store.teardown();
  });

  test('redispatch fails without running hooks twice', () async {
    final events = <String>[];
    final store = _store(events);
    final action = _Sync(events);
    final firstStatus = store.dispatchSync(action);
    events.clear();
    expect(() => store.dispatch(action), throwsA(isA<StoreException>()));
    expect(events, ['abort:1']);
    expect(action.status, firstStatus);
    // The counter is incremented before detecting a reused action.
    expect(store.dispatchCount, 2);
    expect(store.reduceCount, 1);
    expect(store.state, 1);
    expect(store.actionsInProgress(), isEmpty);
    await store.teardown();
  });

  for (final phase in ['before', 'reduce']) {
    test('shutdown during sync $phase still finalizes exactly once', () async {
      final events = <String>[];
      final store = _store(events);
      final action = _Sync(events);
      if (phase == 'before') {
        action.beforeCallback = store.shutdown;
      } else {
        action.reduceCallback = () {
          store.shutdown();
          return 1;
        };
      }
      final returned = store.dispatchSync(action);
      expect(events, [
        'abort:0',
        'start:1',
        'before',
        if (phase == 'reduce') 'reduce',
        'after',
        'end:1',
      ]);
      expect(store.state, 0);
      expect(store.reduceCount, phase == 'reduce' ? 1 : 0);
      expect(action.status.isCompletedOk, isTrue);
      expect(action.status.hasFinishedMethodReduce, phase == 'reduce');
      // The early return captures the immutable status before finally runs.
      expect(returned.hasFinishedMethodAfter, isFalse);
      expect(action.status.hasFinishedMethodAfter, isTrue);
      expect(store.actionsInProgress(), isEmpty);
      await store.teardown();
    });

    test('shutdown while async $phase is pending ignores its result', () async {
      final events = <String>[];
      final gate = Completer<void>();
      final store = _store(events);
      final action = phase == 'before'
          ? _PendingBefore(events, gate.future)
          : _PendingReduce(events, gate.future);
      final future = store.dispatchAndWait(action);
      expect(store.actionsInProgress(), contains(action));
      store.shutdown();
      gate.complete();
      final returned = await future;
      expect(store.state, 0);
      expect(events.where((s) => s == 'after'), hasLength(1));
      expect(events.where((s) => s.startsWith('state:')), isEmpty);
      expect(events.last, 'end:1');
      expect(store.reduceCount, phase == 'reduce' ? 1 : 0);
      expect(action.status.isCompletedOk, isTrue);
      expect(returned.hasFinishedMethodAfter, isFalse);
      expect(store.actionsInProgress(), isEmpty);
      await store.teardown();
    });
  }

  for (final isAsync in [false, true]) {
    for (final reducerFails in [false, true]) {
      test('after throws: async=$isAsync, reducer fails=$reducerFails', () {
        fakeAsync((async) {
          final events = <String>[];
          final uncaught = <Object>[];
          final store = _store(events);
          final original = const UserException('reduce failed').noDialog;
          final action = isAsync
              ? _PendingReduce(events, Future<void>.value())
              : _Sync(events);
          action.afterCallback = () => throw StateError('after failed');
          if (reducerFails) action.reduceCallback = () => throw original;
          ActionStatus? returned;
          runZonedGuarded(() {
            store.dispatchAndWait(action).then((status) => returned = status);
          }, (error, stack) => uncaught.add(error));
          async.flushMicrotasks();
          async.elapse(Duration.zero);
          expect(uncaught, hasLength(1));
          expect(uncaught.single.toString(), contains('after failed'));
          expect(returned, same(action.status));
          expect(action.status.isCompleted, isTrue);
          expect(action.status.originalError, reducerFails ? same(original) : isNull);
          expect(action.status.wrappedError, reducerFails ? same(original) : isNull);
          expect(store.state, reducerFails ? 0 : 1);
          expect(store.actionsInProgress(), isEmpty);
          expect(events.where((e) => e == 'after'), hasLength(1));
          expect(events.last, 'end:1');
          store.teardown();
          async.flushMicrotasks();
        });
      });
    }
  }

  for (final notify in [false, true]) {
    test('wait conditions and finalization work with notify=$notify', () async {
      final events = <String>[];
      final gate = Completer<void>();
      final store = _store(events);
      final action = _PendingReduce(events, gate.future);
      final stateWait = store.waitCondition((state) => state == 1);
      final startWait = store.waitActionCondition(
        (actions, trigger) => actions.contains(action),
      );
      final finished = store.dispatchAndWait(action, notify: notify);
      final (started, startTrigger) = await startWait;
      expect(started, contains(action));
      expect(startTrigger, same(action));
      final endWait = store.waitAllActions([action]);
      gate.complete();
      expect(await stateWait, same(action));
      await finished;
      await endWait;
      expect(action.status.isCompletedOk, isTrue);
      expect(store.actionsInProgress(), isEmpty);
      await store.teardown();
    });
  }

  test('actions in progress use identity and snapshots do not mutate', () async {
    final events = <String>[];
    final store = _store(events);
    final gate = Completer<void>();
    final a = _EqualPending(events, gate.future);
    final b = _EqualPending(events, gate.future);
    expect(a, b);
    final futureA = store.dispatchAndWait(a);
    final futureB = store.dispatchAndWait(b);
    final view = store.actionsInProgress();
    final snapshot = store.copyActionsInProgress();
    expect(view, hasLength(2));
    expect(snapshot, hasLength(2));
    expect(store.actionsInProgressEqualTo(snapshot), isTrue);
    expect(store.actionsInProgressEqualTo(<ReduxAction<int>>{}), isFalse);
    final other = Set<ReduxAction<int>>.identity()
      ..add(a)
      ..add(_EqualPending(events, gate.future));
    expect(store.actionsInProgressEqualTo(other), isFalse);
    expect(() => view.clear(), throwsUnsupportedError);
    gate.complete();
    await Future.wait([futureA, futureB]);
    expect(view, isEmpty);
    expect(snapshot, hasLength(2));
    expect(store.state, 2);
    await store.teardown();
  });

  test('nested sync dispatches expose current counters and current state', () async {
    final events = <String>[];
    final store = _store(events);
    final parent = _Sync(events);
    final child = _Sync(events);
    parent.reduceCallback = () {
      store.dispatchSync(child);
      return store.state + 10;
    };
    store.dispatchSync(parent);
    expect(store.state, 11);
    expect(store.dispatchCount, 2);
    expect(store.reduceCount, 2);
    expect(events, [
      'abort:0',
      'start:1',
      'before',
      'reduce',
      'abort:0',
      'start:2',
      'before',
      'reduce',
      'state:0->1:2',
      'after',
      'end:2',
      'state:1->11:2',
      'after',
      'end:2',
    ]);
    expect(parent.status.isCompletedOk, isTrue);
    expect(child.status.isCompletedOk, isTrue);
    await store.teardown();
  });

  for (final phase in ['start', 'state', 'end']) {
    test('observer failure in $phase does not interrupt the action', () async {
      final events = <String>[];
      final error = StateError('observer');
      final store = Store<int>(
        initialState: 0,
        actionObservers: [_ActionObserver(events, failAt: phase, error: error)],
        stateObservers: [_StateObserver(events, fail: phase == 'state', error: error)],
      );
      final action = _Sync(events);
      expect(store.dispatchSync(action).isCompletedOk, isTrue);
      expect(action.status.isDispatched, isTrue);
      expect(action.status.isCompleted, isTrue);
      expect(action.status.originalError, isNull);
      expect(store.state, 1);
      expect(store.actionsInProgress(), isEmpty);
      expect(events.where((e) => e == 'after'), hasLength(1));
      if (phase == 'state') {
        expect(events, [
          'abort:0',
          'start:1',
          'before',
          'reduce',
          'state:0->1:1',
          'after',
          'end:1',
        ]);
      }
      await store.teardown();
    });
  }

  test('teardown can replace state and closes onChange', () async {
    final store = Store<int>(initialState: 0);
    final values = <int>[];
    bool done = false;
    store.onChange.listen(values.add, onDone: () => done = true);
    await store.teardown(emptyState: 99);
    expect(store.state, 99);
    expect(values, isEmpty);
    expect(done, isTrue);
  });
}

Store<int> _store(List<String> events) => Store<int>(
  initialState: 0,
  actionObservers: [_ActionObserver(events)],
  stateObservers: [_StateObserver(events)],
);

abstract class _Base extends ReduxAction<int> {
  _Base(this.events);

  final List<String> events;
  bool Function()? abort;
  void Function()? beforeCallback;
  int? Function()? reduceCallback;
  void Function()? afterCallback;

  @override
  bool abortDispatch() {
    events.add('abort:$state');
    return abort?.call() ?? false;
  }

  @override
  void before() {
    events.add('before');
    beforeCallback?.call();
  }

  int? runReducer() {
    events.add('reduce');
    return reduceCallback == null ? state + 1 : reduceCallback!();
  }

  @override
  void after() {
    events.add('after');
    afterCallback?.call();
  }

  @override
  Object? wrapError(Object error, StackTrace stackTrace) {
    events.add('wrapError');
    return error;
  }
}

class _Sync extends _Base {
  _Sync(super.events);

  @override
  int? reduce() => runReducer();
}

class _PendingBefore extends _Sync {
  _PendingBefore(super.events, this.gate);

  final Future<void> gate;

  @override
  Future<void> before() async {
    await gate;
    super.before();
  }
}

class _PendingReduce extends _Base {
  _PendingReduce(super.events, this.gate);

  final Future<void> gate;

  @override
  Future<int?> reduce() async {
    await gate;
    return runReducer();
  }
}

class _EqualPending extends _PendingReduce {
  _EqualPending(super.events, super.gate);

  @override
  bool operator ==(Object other) => other is _EqualPending;

  @override
  int get hashCode => 0;
}

class _ActionObserver extends ActionObserver<int> {
  _ActionObserver(this.events, {this.failAt, this.error});

  final List<String> events;
  final String? failAt;
  final Object? error;

  @override
  void observe(ReduxAction<int> action, int dispatchCount, {required bool ini}) {
    final phase = ini ? 'start' : 'end';
    events.add('$phase:$dispatchCount');
    if (failAt == phase) throw error!;
  }
}

class _StateObserver extends StateObserver<int> {
  _StateObserver(this.events, {this.fail = false, this.error});

  final List<String> events;
  final bool fail;
  final Object? error;

  @override
  void observe(
    ReduxAction<int> action,
    int prevState,
    int newState,
    Object? error,
    int dispatchCount,
  ) {
    events.add(
      '${error == null ? 'state' : 'state-error'}:'
      '$prevState->$newState:$dispatchCount',
    );
    if (fail && error == null) throw this.error!;
  }
}
