import 'package:async_redux/async_redux.dart';
import 'package:bdd_framework/bdd_framework.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the order in which things happen, so tests can assert on it.
List<String> log = [];

void main() {
  var feature = BddFeature('Check internet actions');

  setUp(() {
    log = [];
  });

  // ==========================================================================
  // Case 1: CheckInternet fails when there is no internet
  // ==========================================================================

  Bdd(feature)
      .scenario('CheckInternet fails the action when there is no internet.')
      .given('An action with CheckInternet.')
      .when('It is dispatched while the internet is simulated as off.')
      .then('The action fails with a UserException, and the reducer does not run.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));
    store.forceInternetOnOffSimulation = () => false;

    var status = await store.dispatchAndWait(CheckInternetAction());

    expect(status.isCompletedOk, isFalse);
    expect(status.originalError, isA<UserException>());
    expect(log, ['base before start', 'base before end', 'check internet']);
    expect(store.state.count, 0);
  });

  // ==========================================================================
  // Case 2: CheckInternet waits for an async base-class `before`
  // ==========================================================================

  Bdd(feature)
      .scenario('CheckInternet awaits the base-class before method.')
      .given('An action with CheckInternet, whose base class has an ASYNC before method.')
      .when('It is dispatched with internet on.')
      .then('The internet check and the reducer only run after the base before finishes.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));
    store.forceInternetOnOffSimulation = () => true;

    var status = await store.dispatchAndWait(CheckInternetAction());

    expect(status.isCompletedOk, isTrue);
    expect(log, ['base before start', 'base before end', 'check internet', 'reduce']);
    expect(store.state.count, 1);
  });

  // ==========================================================================
  // Case 3: CheckInternet propagates errors from an async base-class `before`
  // ==========================================================================

  Bdd(feature)
      .scenario('CheckInternet propagates an error thrown by the base-class before method.')
      .given('An action with CheckInternet, whose base class has an ASYNC before that throws.')
      .when('It is dispatched with internet on.')
      .then('The action fails with that error, and the reducer does not run.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));
    store.forceInternetOnOffSimulation = () => true;

    var status = await store.dispatchAndWait(CheckInternetAction(throwInBefore: true));

    expect(status.isCompletedOk, isFalse);
    expect(status.originalError, same(baseBeforeError));
    expect(log, ['base before start']);
    expect(store.state.count, 0);
  });

  // ==========================================================================
  // Case 4: AbortWhenNoInternet aborts when there is no internet
  // ==========================================================================

  Bdd(feature)
      .scenario('AbortWhenNoInternet aborts the action when there is no internet.')
      .given('An action with AbortWhenNoInternet.')
      .when('It is dispatched while the internet is simulated as off.')
      .then('The action is aborted silently, and the reducer does not run.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));
    store.forceInternetOnOffSimulation = () => false;

    var status = await store.dispatchAndWait(AbortWhenNoInternetAction());

    expect(status.isCompletedOk, isFalse);
    expect(status.originalError, isA<AbortDispatchException>());
    expect(log, ['base before start', 'base before end', 'check internet']);
    expect(store.state.count, 0);
  });

  // ==========================================================================
  // Case 5: AbortWhenNoInternet waits for an async base-class `before`
  // ==========================================================================

  Bdd(feature)
      .scenario('AbortWhenNoInternet awaits the base-class before method.')
      .given('An action with AbortWhenNoInternet, whose base class has an ASYNC before method.')
      .when('It is dispatched with internet on.')
      .then('The internet check and the reducer only run after the base before finishes.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));
    store.forceInternetOnOffSimulation = () => true;

    var status = await store.dispatchAndWait(AbortWhenNoInternetAction());

    expect(status.isCompletedOk, isTrue);
    expect(log, ['base before start', 'base before end', 'check internet', 'reduce']);
    expect(store.state.count, 1);
  });

  // ==========================================================================
  // Case 6: AbortWhenNoInternet propagates errors from an async base-class `before`
  // ==========================================================================

  Bdd(feature)
      .scenario('AbortWhenNoInternet propagates an error thrown by the base-class before method.')
      .given('An action with AbortWhenNoInternet, whose base class has an ASYNC before that throws.')
      .when('It is dispatched with internet on.')
      .then('The action fails with that error, and the reducer does not run.')
      .run((_) async {
    var store = Store<State>(initialState: State(0));
    store.forceInternetOnOffSimulation = () => true;

    var status = await store.dispatchAndWait(AbortWhenNoInternetAction(throwInBefore: true));

    expect(status.isCompletedOk, isFalse);
    expect(status.originalError, same(baseBeforeError));
    expect(log, ['base before start']);
    expect(store.state.count, 0);
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

/// A [UserException], so that the store swallows it and records it in the
/// action status, instead of rethrowing it to the dispatcher.
const baseBeforeError = UserException('Thrown by the base before method.');

/// A base class with an ASYNC `before` method, which may throw after an await.
abstract class AppAction extends ReduxAction<State> {
  final bool throwInBefore;

  AppAction({this.throwInBefore = false});

  @override
  Future<void> before() async {
    log.add('base before start');
    await Future.delayed(const Duration(milliseconds: 10));
    if (throwInBefore) throw baseBeforeError;
    log.add('base before end');
  }

  @override
  Future<State?> reduce() async {
    log.add('reduce');
    return State(state.count + 1);
  }
}

class CheckInternetAction extends AppAction with CheckInternet {
  CheckInternetAction({super.throwInBefore});

  @override
  Future<List<ConnectivityResult>> checkConnectivity() {
    log.add('check internet');
    return super.checkConnectivity();
  }
}

class AbortWhenNoInternetAction extends AppAction with AbortWhenNoInternet {
  AbortWhenNoInternetAction({super.throwInBefore});

  @override
  Future<List<ConnectivityResult>> checkConnectivity() {
    log.add('check internet');
    return super.checkConnectivity();
  }
}
