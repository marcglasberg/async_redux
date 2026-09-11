import 'package:async_redux/async_redux.dart';
import 'package:bdd_framework/bdd_framework.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the order in which things happen, so tests can assert on it.
List<String> log = [];

/// The provided mixins that override `after` must call `super.after()`, so that
/// a base class `after` method (for example, in an `AppAction` base class) still
/// runs when the mixin is added to an action. They must also still do their
/// own cleanup after the base `after` runs.
void main() {
  var feature = BddFeature('Mixins that override after call super.after()');

  setUp(() {
    log = [];
  });

  // ==========================================================================
  // Case 1: NonReentrant
  // ==========================================================================

  Bdd(feature)
      .scenario('NonReentrant calls the base-class after method, then releases its key.')
      .given('A base class with an after method, and an action with NonReentrant.')
      .when('The action is dispatched, and then dispatched again.')
      .then('The base after runs, the key is released, and the second dispatch runs.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));

    await store.dispatchAndWait(NonReentrantAction());
    expect(log, ['reduce', 'base after']);
    expect(store.internalMixinProps.nonReentrantKeySet, isEmpty);

    var status = await store.dispatchAndWait(NonReentrantAction());
    expect(status.isDispatchAborted, isFalse);
    expect(store.state.count, 2);
  });

  // ==========================================================================
  // Case 2: Throttle
  // ==========================================================================

  Bdd(feature)
      .scenario('Throttle calls the base-class after method, then does its cleanup.')
      .given('A base class with an after method, and an action with Throttle and removeLockOnError.')
      .when('The action fails, and then is dispatched again right away.')
      .then('The base after runs, the lock is removed, and the second dispatch runs.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));

    var status1 = await store.dispatchAndWait(ThrottleAction(shouldFail: true));
    expect(status1.isCompletedFailed, isTrue);
    expect(log, ['reduce', 'base after']);
    expect(store.internalMixinProps.throttleLockMap, isEmpty);

    var status2 = await store.dispatchAndWait(ThrottleAction(shouldFail: false));
    expect(status2.isDispatchAborted, isFalse);
    expect(status2.isCompletedOk, isTrue);
    expect(log, ['reduce', 'base after', 'reduce', 'base after']);
    expect(store.state.count, 1);
  });

  // ==========================================================================
  // Case 3: Fresh
  // ==========================================================================

  Bdd(feature)
      .scenario('Fresh calls the base-class after method, then rolls back its key on error.')
      .given('A base class with an after method, and an action with Fresh.')
      .when('The action fails, and then is dispatched again right away.')
      .then('The base after runs, the key is rolled back, and the second dispatch runs.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));

    var status1 = await store.dispatchAndWait(FreshAction(shouldFail: true));
    expect(status1.isCompletedFailed, isTrue);
    expect(log, ['reduce', 'base after']);
    expect(store.internalMixinProps.freshKeyMap, isEmpty);

    var status2 = await store.dispatchAndWait(FreshAction(shouldFail: false));
    expect(status2.isDispatchAborted, isFalse);
    expect(status2.isCompletedOk, isTrue);
    expect(log, ['reduce', 'base after', 'reduce', 'base after']);
    expect(store.state.count, 1);
  });

  // ==========================================================================
  // Case 4: OptimisticCommand
  // ==========================================================================

  Bdd(feature)
      .scenario('OptimisticCommand calls the base-class after method, then releases its key.')
      .given('A base class with an after method, and an action with OptimisticCommand.')
      .when('The action is dispatched, and then dispatched again.')
      .then('The base after runs, the key is released, and the second dispatch runs.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));

    var status1 = await store.dispatchAndWait(OptimisticCommandAction());
    expect(status1.isCompletedOk, isTrue);
    expect(log, ['send', 'base after']);
    expect(store.state.count, 1);

    var status2 = await store.dispatchAndWait(OptimisticCommandAction());
    expect(status2.isDispatchAborted, isFalse);
    expect(status2.isCompletedOk, isTrue);
    expect(store.state.count, 2);
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

/// A base class with an `after` method, like an app's `AppAction` would have.
abstract class AppAction extends ReduxAction<State> {
  @override
  void after() {
    log.add('base after');
  }
}

class NonReentrantAction extends AppAction with NonReentrant {
  @override
  Future<State?> reduce() async {
    log.add('reduce');
    await Future.delayed(const Duration(milliseconds: 5));
    return State(state.count + 1);
  }
}

class ThrottleAction extends AppAction with Throttle {
  final bool shouldFail;

  ThrottleAction({required this.shouldFail});

  @override
  bool get removeLockOnError => true;

  @override
  Future<State?> reduce() async {
    log.add('reduce');
    await Future.delayed(const Duration(milliseconds: 5));
    if (shouldFail) throw const UserException('Failed on purpose.');
    return State(state.count + 1);
  }
}

class FreshAction extends AppAction with Fresh {
  final bool shouldFail;

  FreshAction({required this.shouldFail});

  @override
  Future<State?> reduce() async {
    log.add('reduce');
    await Future.delayed(const Duration(milliseconds: 5));
    if (shouldFail) throw const UserException('Failed on purpose.');
    return State(state.count + 1);
  }
}

class OptimisticCommandAction extends AppAction with OptimisticCommand<State> {
  @override
  Object? optimisticValue() => state.count + 1;

  @override
  Object? getValueFromState(State state) => state.count;

  @override
  State applyValueToState(State state, Object? value) => State(value as int);

  @override
  Future<void> sendCommandToServer(Object? newValue) async {
    log.add('send');
    await Future.delayed(const Duration(milliseconds: 5));
  }

  @override
  bool shouldReload({
    required Object? currentValue,
    required Object? lastAppliedValue,
    required Object? optimisticValue,
    required Object? rollbackValue,
    required Object? error,
  }) =>
      false;
}
