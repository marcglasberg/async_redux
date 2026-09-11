import 'package:async_redux/async_redux.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for [ReduxAction.waitActionType], [ReduxAction.waitAllActionTypes] and
/// [ReduxAction.waitAllActions], which are used inside an action's reducer, especially
/// the guards that prevent an action from deadlocking by waiting for itself.
void main() {
  group('ReduxAction.waitActionType', () {
    //
    test('waits for another action type that is in progress.', () async {
      var store = Store<State>(initialState: State(1));

      store.dispatch(DelayedAction(10, delayMillis: 50));
      var waiter = WaitForTypeAction(DelayedAction, thenAdd: 100);
      var status = await store.dispatchAndWait(waiter);

      expect(status.isCompletedOk, isTrue);
      // The waiter read the state only after DelayedAction finished.
      expect(waiter.stateWhenDone, 11);
      expect(waiter.awaitedAction, isA<DelayedAction>());
      expect(store.state.count, 111);
    });

    test('completes at once and returns null when nothing is in progress.', () async {
      var store = Store<State>(initialState: State(1));

      var waiter = WaitForTypeAction(DelayedAction, thenAdd: 100);
      var status = await store.dispatchAndWait(waiter);

      expect(status.isCompletedOk, isTrue);
      expect(waiter.awaitedAction, isNull);
      expect(store.state.count, 101);
    });

    test("throws StoreException when given the action's own type (would deadlock).", () async {
      var store = Store<State>(initialState: State(1));

      // The action tries to wait for its own type. Instead of hanging forever,
      // it fails right away with a StoreException.
      var action = WaitForOwnTypeAction();
      await expectLater(
        store.dispatchAndWait(action).timeout(const Duration(seconds: 2)),
        throwsA(isA<StoreException>()),
      );

      expect(action.status.isCompletedFailed, isTrue);
      expect(action.status.originalError, isA<StoreException>());
      expect(action.status.originalError.toString(), contains('WaitForOwnTypeAction'));
      expect(action.status.originalError.toString(), contains('waitActionType'));
      expect(store.state.count, 1);
      expect(store.isWaiting(WaitForOwnTypeAction), isFalse);
    });

    test('the own-type check is synchronous, so the error is thrown even without await.', () {
      var store = Store<State>(initialState: State(1));
      var action = WaitForOwnTypeAction();
      // ignore: invalid_use_of_protected_member
      action.setStore(store);

      expect(
        () => action.waitActionType(WaitForOwnTypeAction),
        throwsA(isA<StoreException>()),
      );
    });

    test('never times out, even if the store default timeout is very short.', () async {
      var originalTimeout = Store.defaultTimeoutMillis;
      Store.defaultTimeoutMillis = 10;
      addTearDown(() => Store.defaultTimeoutMillis = originalTimeout);

      var store = Store<State>(initialState: State(1));

      // The awaited action takes much longer than the store default timeout.
      store.dispatch(DelayedAction(10, delayMillis: 200));
      var waiter = WaitForTypeAction(DelayedAction, thenAdd: 100);
      var status = await store.dispatchAndWait(waiter);

      expect(status.isCompletedOk, isTrue);
      expect(waiter.stateWhenDone, 11);
      expect(store.state.count, 111);
    });
  });

  group('ReduxAction.waitAllActionTypes', () {
    //
    test('waits for other action types that are in progress.', () async {
      var store = Store<State>(initialState: State(1));

      store.dispatch(DelayedAction(10, delayMillis: 50));
      store.dispatch(AnotherDelayedAction(1000, delayMillis: 20));
      var waiter = WaitForTypesAction([DelayedAction, AnotherDelayedAction], thenAdd: 100);
      var status = await store.dispatchAndWait(waiter);

      expect(status.isCompletedOk, isTrue);
      // The waiter read the state only after both delayed actions finished.
      expect(waiter.stateWhenDone, 1011);
      expect(store.state.count, 1111);
    });

    test('completes at once when nothing is in progress.', () async {
      var store = Store<State>(initialState: State(1));

      var waiter = WaitForTypesAction([DelayedAction, AnotherDelayedAction], thenAdd: 100);
      var status = await store.dispatchAndWait(waiter);

      expect(status.isCompletedOk, isTrue);
      expect(waiter.stateWhenDone, 1);
      expect(store.state.count, 101);
    });

    test("ignores the action's own type and waits for the other types (no deadlock).", () async {
      var store = Store<State>(initialState: State(1));

      store.dispatch(DelayedAction(10, delayMillis: 50));

      // The list contains the action's own type. It must be ignored, otherwise the
      // action would wait forever for itself.
      var waiter = WaitForTypesAction([WaitForTypesAction, DelayedAction], thenAdd: 100);
      var status = await store.dispatchAndWait(waiter).timeout(const Duration(seconds: 2));

      expect(status.isCompletedOk, isTrue);
      expect(waiter.stateWhenDone, 11);
      expect(store.state.count, 111);
    });

    test("completes immediately when the only type given is the action's own type.", () async {
      var store = Store<State>(initialState: State(1));

      var waiter = WaitForTypesAction([WaitForTypesAction], thenAdd: 100);
      var status = await store.dispatchAndWait(waiter).timeout(const Duration(seconds: 2));

      expect(status.isCompletedOk, isTrue);
      expect(waiter.stateWhenDone, 1);
      expect(store.state.count, 101);
    });

    test(
        'after removing the own type, completes at once if no other type is in progress.',
        () async {
      var store = Store<State>(initialState: State(1));

      // DelayedAction is NOT in progress. The own type is removed from the list,
      // so only DelayedAction remains, and since it's not in progress, it completes at once.
      var waiter = WaitForTypesAction([WaitForTypesAction, DelayedAction], thenAdd: 100);
      var status = await store.dispatchAndWait(waiter).timeout(const Duration(seconds: 2));

      expect(status.isCompletedOk, isTrue);
      expect(waiter.stateWhenDone, 1);
      expect(store.state.count, 101);
    });

    test('throws StoreException when given an empty list.', () async {
      var store = Store<State>(initialState: State(1));

      var waiter = WaitForTypesAction([], thenAdd: 100);
      await expectLater(store.dispatchAndWait(waiter), throwsA(isA<StoreException>()));

      expect(waiter.status.isCompletedFailed, isTrue);
      expect(waiter.status.originalError, isA<StoreException>());
      expect(store.state.count, 1);
    });

    test('the empty-list check is synchronous, so the error is thrown even without await.', () {
      var store = Store<State>(initialState: State(1));
      var action = WaitForTypesAction([], thenAdd: 100);
      // ignore: invalid_use_of_protected_member
      action.setStore(store);

      expect(
        () => action.waitAllActionTypes([]),
        throwsA(isA<StoreException>()),
      );
    });

    test('never times out, even if the store default timeout is very short.', () async {
      var originalTimeout = Store.defaultTimeoutMillis;
      Store.defaultTimeoutMillis = 10;
      addTearDown(() => Store.defaultTimeoutMillis = originalTimeout);

      var store = Store<State>(initialState: State(1));

      // The awaited actions take much longer than the store default timeout.
      store.dispatch(DelayedAction(10, delayMillis: 200));
      store.dispatch(AnotherDelayedAction(1000, delayMillis: 150));
      var waiter = WaitForTypesAction([DelayedAction, AnotherDelayedAction], thenAdd: 100);
      var status = await store.dispatchAndWait(waiter);

      expect(status.isCompletedOk, isTrue);
      expect(waiter.stateWhenDone, 1011);
      expect(store.state.count, 1111);
    });
  });

  group('ReduxAction.waitAllActions', () {
    //
    test('waits for other actions that are in progress.', () async {
      var store = Store<State>(initialState: State(1));

      var action1 = DelayedAction(10, delayMillis: 50);
      var action2 = AnotherDelayedAction(1000, delayMillis: 20);
      store.dispatch(action1);
      store.dispatch(action2);
      var waiter = WaitForActionsAction([action1, action2], thenAdd: 100);
      var status = await store.dispatchAndWait(waiter);

      expect(status.isCompletedOk, isTrue);
      // The waiter read the state only after both delayed actions finished.
      expect(waiter.stateWhenDone, 1011);
      expect(store.state.count, 1111);
    });

    test('ignores the action itself and waits for the other actions (no deadlock).', () async {
      var store = Store<State>(initialState: State(1));

      var action1 = DelayedAction(10, delayMillis: 50);
      store.dispatch(action1);

      // The list contains the action itself. It must be ignored, otherwise the
      // action would wait forever for itself.
      var waiter = WaitForActionsAction([action1], thenAdd: 100, includeItself: true);
      var status = await store.dispatchAndWait(waiter).timeout(const Duration(seconds: 2));

      expect(status.isCompletedOk, isTrue);
      expect(waiter.stateWhenDone, 11);
      expect(store.state.count, 111);
    });

    test('completes immediately when the only action given is the action itself.', () async {
      var store = Store<State>(initialState: State(1));

      var waiter = WaitForActionsAction([], thenAdd: 100, includeItself: true);
      var status = await store.dispatchAndWait(waiter).timeout(const Duration(seconds: 2));

      expect(status.isCompletedOk, isTrue);
      expect(waiter.stateWhenDone, 1);
      expect(store.state.count, 101);
    });

    test(
        'fails if none of the given actions is in progress '
        'and completeImmediately is false (the default).', () async {
      var store = Store<State>(initialState: State(1));

      // action1 already finished, action2 was never dispatched.
      var action1 = DelayedAction(10, delayMillis: 1);
      var action2 = AnotherDelayedAction(1000, delayMillis: 1);
      await store.dispatchAndWait(action1);
      var waiter = WaitForActionsAction([action1, action2], thenAdd: 100);
      await expectLater(
        store.dispatchAndWait(waiter).timeout(const Duration(seconds: 2)),
        throwsA(isA<StoreException>()),
      );

      expect(waiter.status.isCompletedFailed, isTrue);
      expect(waiter.status.originalError, isA<StoreException>());
      expect(store.state.count, 11);
    });

    test(
        'completes at once if none of the given actions is in progress '
        'and completeImmediately is true.', () async {
      var store = Store<State>(initialState: State(1));

      // action1 already finished, action2 was never dispatched.
      var action1 = DelayedAction(10, delayMillis: 1);
      var action2 = AnotherDelayedAction(1000, delayMillis: 1);
      await store.dispatchAndWait(action1);
      var waiter = WaitForActionsAction(
        [action1, action2],
        thenAdd: 100,
        completeImmediately: true,
      );
      var status = await store.dispatchAndWait(waiter).timeout(const Duration(seconds: 2));

      expect(status.isCompletedOk, isTrue);
      expect(waiter.stateWhenDone, 11);
      expect(store.state.count, 111);
    });

    test(
        'after removing itself, fails if no other action is in progress '
        'and completeImmediately is false.', () async {
      var store = Store<State>(initialState: State(1));

      // action1 is NOT in progress (never dispatched). The action itself is removed
      // from the list, so only action1 remains, and since it's not in progress, it throws.
      var action1 = DelayedAction(10, delayMillis: 50);
      var waiter = WaitForActionsAction([action1], thenAdd: 100, includeItself: true);
      await expectLater(
        store.dispatchAndWait(waiter).timeout(const Duration(seconds: 2)),
        throwsA(isA<StoreException>()),
      );

      expect(waiter.status.isCompletedFailed, isTrue);
      expect(waiter.status.originalError, isA<StoreException>());
      expect(store.state.count, 1);
    });

    test(
        'after removing itself, completes if no other action is in progress '
        'and completeImmediately is true.', () async {
      var store = Store<State>(initialState: State(1));

      var action1 = DelayedAction(10, delayMillis: 50);
      var waiter = WaitForActionsAction(
        [action1],
        thenAdd: 100,
        includeItself: true,
        completeImmediately: true,
      );
      var status = await store.dispatchAndWait(waiter).timeout(const Duration(seconds: 2));

      expect(status.isCompletedOk, isTrue);
      expect(waiter.stateWhenDone, 1);
      expect(store.state.count, 101);
    });

    test('throws StoreException when given an empty list.', () async {
      var store = Store<State>(initialState: State(1));

      var waiter = WaitForActionsAction([], thenAdd: 100);
      await expectLater(store.dispatchAndWait(waiter), throwsA(isA<StoreException>()));

      expect(waiter.status.isCompletedFailed, isTrue);
      expect(waiter.status.originalError, isA<StoreException>());
      expect(store.state.count, 1);
    });

    test('the empty-list check is synchronous, so the error is thrown even without await.', () {
      var store = Store<State>(initialState: State(1));
      var action = WaitForActionsAction([], thenAdd: 100);
      // ignore: invalid_use_of_protected_member
      action.setStore(store);

      expect(
        // ignore: invalid_use_of_protected_member
        () => action.waitAllActions([]),
        throwsA(isA<StoreException>()),
      );
    });

    test('never times out, even if the store default timeout is very short.', () async {
      var originalTimeout = Store.defaultTimeoutMillis;
      Store.defaultTimeoutMillis = 10;
      addTearDown(() => Store.defaultTimeoutMillis = originalTimeout);

      var store = Store<State>(initialState: State(1));

      // The awaited action takes much longer than the store default timeout.
      var action1 = DelayedAction(10, delayMillis: 200);
      store.dispatch(action1);
      var waiter = WaitForActionsAction([action1], thenAdd: 100);
      var status = await store.dispatchAndWait(waiter);

      expect(status.isCompletedOk, isTrue);
      expect(waiter.stateWhenDone, 11);
      expect(store.state.count, 111);
    });
  });
}

class State {
  final int count;

  State(this.count);

  @override
  String toString() => 'State($count)';
}

class DelayedAction extends ReduxAction<State> {
  final int increment;
  final int delayMillis;

  DelayedAction(this.increment, {required this.delayMillis});

  @override
  Future<State> reduce() async {
    await Future.delayed(Duration(milliseconds: delayMillis));
    return State(state.count + increment);
  }
}

class AnotherDelayedAction extends DelayedAction {
  AnotherDelayedAction(int increment, {required int delayMillis})
      : super(increment, delayMillis: delayMillis);
}

/// Waits for [actionType] using [ReduxAction.waitActionType], then adds [thenAdd].
class WaitForTypeAction extends ReduxAction<State> {
  final Type actionType;
  final int thenAdd;

  int? stateWhenDone;
  ReduxAction<State>? awaitedAction;

  WaitForTypeAction(this.actionType, {required this.thenAdd});

  @override
  Future<State> reduce() async {
    awaitedAction = await waitActionType(actionType);
    stateWhenDone = state.count;
    return State(state.count + thenAdd);
  }
}

/// Waits for its OWN type using [ReduxAction.waitActionType].
class WaitForOwnTypeAction extends ReduxAction<State> {
  @override
  Future<State> reduce() async {
    await waitActionType(WaitForOwnTypeAction);
    return State(state.count + 1);
  }
}

/// Waits for [actionTypes] using [ReduxAction.waitAllActionTypes], then adds [thenAdd].
class WaitForTypesAction extends ReduxAction<State> {
  final List<Type> actionTypes;
  final int thenAdd;

  int? stateWhenDone;

  WaitForTypesAction(this.actionTypes, {required this.thenAdd});

  @override
  Future<State> reduce() async {
    await waitAllActionTypes(actionTypes);
    stateWhenDone = state.count;
    return State(state.count + thenAdd);
  }
}

/// Waits for [actions] using [ReduxAction.waitAllActions], then adds [thenAdd].
/// If [includeItself] is true, the action adds ITSELF to the list of actions to wait for.
class WaitForActionsAction extends ReduxAction<State> {
  final List<ReduxAction<State>> actions;
  final int thenAdd;
  final bool includeItself;
  final bool completeImmediately;

  int? stateWhenDone;

  WaitForActionsAction(
    this.actions, {
    required this.thenAdd,
    this.includeItself = false,
    this.completeImmediately = false,
  });

  @override
  Future<State> reduce() async {
    await waitAllActions(
      includeItself ? [...actions, this] : actions,
      completeImmediately: completeImmediately,
    );
    stateWhenDone = state.count;
    return State(state.count + thenAdd);
  }
}
