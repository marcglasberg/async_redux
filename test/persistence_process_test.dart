import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:bdd_framework/bdd_framework.dart';
import 'package:flutter_test/flutter_test.dart';

/// The throttle used by the scenarios that need one. These scenarios use the real time
/// (the persistence uses `DateTime.now()`, which `fakeAsync` doesn't change), so the
/// checks are made well before and well after the throttle ends.
const throttle = Duration(milliseconds: 300);

Future<void> wait(int millis) => Future.delayed(Duration(milliseconds: millis));

void main() {
  var feature = BddFeature('Persistence');

  // ==========================================================================
  // The initial state, and simple saves.
  // ==========================================================================

  Bdd(feature)
      .scenario('The initial-state of the store is considered already persisted.')
      .given('A persistor.')
      .when('The store is created with an initial-state.')
      .then('The initial-state is not saved again.')
      .and('It is the last persisted state.')
      .run((_) async {
    var s0 = S(0);
    var p = ControlledPersistor(stored: s0);
    var store = Store<S>(initialState: s0, persistor: p);
    await pumpEventQueue();

    expect(p.saves, isEmpty);
    expect(store.getLastPersistedStateFromPersistor(), same(s0));
  });

  Bdd(feature)
      .scenario('Without throttle, a state change is saved right away.')
      .given('A persistor with no throttle.')
      .when('The state changes twice, each time after the previous save finished.')
      .then('Each new state is saved right away.')
      .and('Each save gets the difference from the last persisted state.')
      .run((_) async {
    var (s0, s1, s2) = (S(0), S(1), S(2));
    var p = ControlledPersistor(stored: s0);
    var store = Store<S>(initialState: s0, persistor: p);

    store.dispatch(SetState(s1));
    expect(p.saves.length, 1);
    expect(p.saves[0].lastPersistedState, same(s0));
    expect(p.saves[0].newState, same(s1));
    await p.finish(0);
    expect(store.getLastPersistedStateFromPersistor(), same(s1));

    store.dispatch(SetState(s2));
    expect(p.saves.length, 2);
    expect(p.saves[1].lastPersistedState, same(s1));
    expect(p.saves[1].newState, same(s2));
    await p.finish(1);
    expect(p.stored, same(s2));
    expect(store.getLastPersistedStateFromPersistor(), same(s2));
  });

  Bdd(feature)
      .scenario('An action that does not change the state does not save it.')
      .given('A persistor with no throttle.')
      .when('An action returns null.')
      .and('An action returns the same state object.')
      .then('Nothing is saved.')
      .run((_) async {
    var s0 = S(0);
    var p = ControlledPersistor(stored: s0);
    var store = Store<S>(initialState: s0, persistor: p);

    await store.dispatchAndWait(ReturnNull());
    await store.dispatchAndWait(ReturnSameState());
    await pumpEventQueue();

    expect(p.saves, isEmpty);
  });

  Bdd(feature)
      .scenario('A new state object equal to the persisted one is saved.')
      .given('A persistor with no throttle.')
      .when('An action returns a new state object, equal to the persisted state.')
      .then('It is saved, since states are compared by identity, not by equality.')
      .run((_) async {
    var s0 = S(0);
    var p = ControlledPersistor(stored: s0);
    var store = Store<S>(initialState: s0, persistor: p);

    var s0copy = S(0);
    store.dispatch(SetState(s0copy));
    await p.finish(0);

    expect(p.saves.length, 1);
    expect(p.saves[0].newState, same(s0copy));
    expect(store.getLastPersistedStateFromPersistor(), same(s0copy));
  });

  Bdd(feature)
      .scenario(
          'The state changed by an async action is saved when its reducer finishes.')
      .given('A persistor with no throttle.')
      .when('An async action is dispatched.')
      .then('Nothing is saved while its reducer is running.')
      .and('The new state is saved when the reducer finishes.')
      .run((_) async {
    var (s0, s1) = (S(0), S(1));
    var p = ControlledPersistor(stored: s0);
    var store = Store<S>(initialState: s0, persistor: p);

    var reducerCanFinish = Completer<void>();
    store.dispatch(SetStateAsync(s1, reducerCanFinish.future));
    await pumpEventQueue();
    expect(p.saves, isEmpty);

    reducerCanFinish.complete();
    await pumpEventQueue();
    expect(p.saves.length, 1);
    expect(p.saves[0].newState, same(s1));
  });

  // ==========================================================================
  // State changes while a save is running.
  // ==========================================================================

  Bdd(feature)
      .scenario('Saves never overlap, and only the newest state is saved next.')
      .given('A persistor with no throttle.')
      .and('The state changed, and its save is running.')
      .when('The state changes two more times, while the save is still running.')
      .then('No other save starts while the first one is running.')
      .and('When it finishes, only the newest state is saved,')
      .and('with the difference from the state that was just saved.')
      .run((_) async {
    var (s0, s1, s2, s3) = (S(0), S(1), S(2), S(3));
    var p = ControlledPersistor(stored: s0);
    var store = Store<S>(initialState: s0, persistor: p);

    store.dispatch(SetState(s1));
    store.dispatch(SetState(s2));
    store.dispatch(SetState(s3));
    await pumpEventQueue();
    expect(p.saves.length, 1);

    await p.finish(0);
    expect(p.saves.length, 2);
    expect(p.saves[1].lastPersistedState, same(s1));
    expect(p.saves[1].newState, same(s3));

    await p.finish(1);
    expect(p.saves.length, 2);
    expect(p.stored, same(s3));
    expect(store.getLastPersistedStateFromPersistor(), same(s3));
  });

  Bdd(feature)
      .scenario('A state that goes back to the one being saved is not saved again.')
      .given('A persistor with no throttle.')
      .and('The state changed, and its save is running.')
      .when('The state changes to another state,')
      .and('and then back to the state being saved, while the save is running.')
      .then('When the save finishes, nothing else is saved.')
      .run((_) async {
    var (s0, s1, s2) = (S(0), S(1), S(2));
    var p = ControlledPersistor(stored: s0);
    var store = Store<S>(initialState: s0, persistor: p);

    store.dispatch(SetState(s1));
    store.dispatch(SetState(s2));
    store.dispatch(SetState(s1));

    await p.finish(0);
    expect(p.saves.length, 1);
    expect(p.stored, same(store.state));
    expect(store.getLastPersistedStateFromPersistor(), same(s1));
  });

  // Bug: process() returns early when the new state is identical to the last persisted
  // state, before it checks if a save is running. So it doesn't remember that, when the
  // running save finishes, the state must be saved again.

  Bdd(feature)
      .scenario(
          'The state goes back to the last persisted state while a save is running.')
      .given('A persistor with no throttle.')
      .and('The state changed, and its save is running.')
      .when('The state goes back to the last persisted state object (an undo).')
      .and('The running save finishes.')
      .then('The last persisted state is saved again,')
      .and('so that the saved state is the same as the state of the store.')
      .run((_) async {
    var (s0, s1) = (S(0), S(1));
    var p = ControlledPersistor(stored: s0);
    var store = Store<S>(initialState: s0, persistor: p);

    store.dispatch(SetState(s1));
    store.dispatch(SetState(s0));

    await p.finish(0);
    expect(p.saves.length, 2);
    expect(p.saves[1].lastPersistedState, same(s1));
    expect(p.saves[1].newState, same(s0));

    await p.finish(1);
    expect(p.stored, same(store.state));
    expect(store.getLastPersistedStateFromPersistor(), same(s0));
  });

  Bdd(feature)
      .scenario('An undo to a saved state while a save is running is saved.')
      .given('A persistor with no throttle.')
      .and('The state changed to a state that was saved.')
      .and('The state changed again, and its save is running.')
      .when('The state goes back to the saved state object (an undo).')
      .and('The running save finishes.')
      .then('The saved state is saved again.')
      .run((_) async {
    var (s0, s1, s2) = (S(0), S(1), S(2));
    var p = ControlledPersistor(stored: s0);
    var store = Store<S>(initialState: s0, persistor: p);

    store.dispatch(SetState(s1));
    await p.finish(0);

    store.dispatch(SetState(s2));
    store.dispatch(SetState(s1));

    await p.finish(1);
    expect(p.saves.length, 3);
    expect(p.saves[2].lastPersistedState, same(s2));
    expect(p.saves[2].newState, same(s1));

    await p.finish(2);
    expect(p.stored, same(store.state));
    expect(store.getLastPersistedStateFromPersistor(), same(s1));
  });

  Bdd(feature)
      .scenario(
          'The state goes back to the last persisted state while a save is running, '
          'with a throttle.')
      .given('A persistor with a throttle.')
      .and('The throttle is over, the state changed, and its save is running.')
      .when('The state goes back to the last persisted state object (an undo).')
      .and('The running save finishes.')
      .then('The last persisted state is saved again, when the throttle is over.')
      .run((_) async {
    var (s0, s1) = (S(0), S(1));
    var p = ControlledPersistor(stored: s0, throttle: throttle);
    var store = Store<S>(initialState: s0, persistor: p);
    await wait(400);

    store.dispatch(SetState(s1));
    expect(p.saves.length, 1);
    store.dispatch(SetState(s0));

    await p.finish(0);
    await wait(500);
    expect(p.saves.length, 2);
    expect(p.saves[1].lastPersistedState, same(s1));
    expect(p.saves[1].newState, same(s0));

    await p.finish(1);
    expect(p.stored, same(store.state));
  });

  Bdd(feature)
      .scenario(
          'The state goes back to the last persisted state, and then changes again, '
          'while a save is running.')
      .given('A persistor with no throttle.')
      .and('The state changed, and its save is running.')
      .when('The state goes back to the last persisted state object,')
      .and('and then changes to another state, while the save is running.')
      .then('When the save finishes, the newest state is saved.')
      .run((_) async {
    var (s0, s1, s2) = (S(0), S(1), S(2));
    var p = ControlledPersistor(stored: s0);
    var store = Store<S>(initialState: s0, persistor: p);

    store.dispatch(SetState(s1));
    store.dispatch(SetState(s0));
    store.dispatch(SetState(s2));

    await p.finish(0);
    expect(p.saves.length, 2);
    expect(p.saves[1].lastPersistedState, same(s1));
    expect(p.saves[1].newState, same(s2));

    await p.finish(1);
    expect(p.stored, same(s2));
  });

  Bdd(feature)
      .scenario(
          'The state goes back to the last persisted state while a save is running, '
          'and that save fails.')
      .given('A persistor with no throttle.')
      .and('The state changed, and its save is running.')
      .when('The state goes back to the last persisted state object.')
      .and('The running save fails.')
      .then('Nothing else is saved, since the saved state is the state of the store.')
      .run((_) async {
    var (s0, s1) = (S(0), S(1));
    var p = ControlledPersistor(stored: s0)..swallowErrors = true;
    var store = Store<S>(initialState: s0, persistor: p);

    store.dispatch(SetState(s1));
    store.dispatch(SetState(s0));

    await p.fail(0);
    expect(p.saves.length, 1);
    expect(p.stored, same(store.state));
    expect(store.getLastPersistedStateFromPersistor(), same(s0));
  });

  Bdd(feature)
      .scenario('The state changes while a save is running, and that save fails.')
      .given('A persistor with no throttle.')
      .and('The state changed, and its save is running.')
      .when('The state changes again, while the save is running.')
      .and('The running save fails.')
      .then('The newest state is saved,')
      .and('with the difference from the last state that was actually persisted.')
      .run((_) async {
    var (s0, s1, s2) = (S(0), S(1), S(2));
    var p = ControlledPersistor(stored: s0)..swallowErrors = true;
    var store = Store<S>(initialState: s0, persistor: p);

    store.dispatch(SetState(s1));
    store.dispatch(SetState(s2));

    await p.fail(0);
    expect(p.saves.length, 2);
    expect(p.saves[1].lastPersistedState, same(s0));
    expect(p.saves[1].newState, same(s2));

    await p.finish(1);
    expect(p.stored, same(s2));
    expect(store.getLastPersistedStateFromPersistor(), same(s2));
  });

  // ==========================================================================
  // Throttle.
  // ==========================================================================

  Bdd(feature)
      .scenario('The throttle starts counting when the store is created.')
      .given('A persistor with a throttle.')
      .when('The state changes 3 times, right after the store is created.')
      .then('Nothing is saved before the throttle is over.')
      .and('When the throttle is over, only the newest state is saved, once.')
      .run((_) async {
    var (s0, s1, s2, s3) = (S(0), S(1), S(2), S(3));
    var p = ControlledPersistor(stored: s0, throttle: throttle, autoFinish: true);
    var store = Store<S>(initialState: s0, persistor: p);

    store.dispatch(SetState(s1));
    store.dispatch(SetState(s2));
    store.dispatch(SetState(s3));
    await wait(100);
    expect(p.saves, isEmpty);

    await wait(400);
    expect(p.saves.length, 1);
    expect(p.saves[0].lastPersistedState, same(s0));
    expect(p.saves[0].newState, same(s3));
    expect(p.stored, same(s3));
  });

  Bdd(feature)
      .scenario('A state change after the throttle is over is saved right away.')
      .given('A persistor with a throttle.')
      .and('The throttle is over.')
      .when('The state changes.')
      .then('It is saved right away.')
      .run((_) async {
    var (s0, s1) = (S(0), S(1));
    var p = ControlledPersistor(stored: s0, throttle: throttle, autoFinish: true);
    var store = Store<S>(initialState: s0, persistor: p);
    await wait(400);

    store.dispatch(SetState(s1));
    expect(p.saves.length, 1);
    expect(p.saves[0].newState, same(s1));
  });

  Bdd(feature)
      .scenario('The throttle counts from the start of the last save.')
      .given('A persistor with a throttle.')
      .and('The state changed after the throttle was over, so it was saved right away.')
      .when('The state changes again, before the throttle is over.')
      .then('It is not saved right away.')
      .and('It is saved when the throttle, counted from the start of the last save, '
          'is over.')
      .run((_) async {
    var (s0, s1, s2) = (S(0), S(1), S(2));
    var p = ControlledPersistor(stored: s0, throttle: throttle, autoFinish: true);
    var store = Store<S>(initialState: s0, persistor: p);
    await wait(400);

    store.dispatch(SetState(s1));
    expect(p.saves.length, 1);

    await wait(50);
    store.dispatch(SetState(s2));
    await wait(100);
    expect(p.saves.length, 1);

    await wait(350);
    expect(p.saves.length, 2);
    expect(p.saves[1].lastPersistedState, same(s1));
    expect(p.saves[1].newState, same(s2));
  });

  Bdd(feature)
      .scenario(
          'A state that goes back to the persisted state before the throttle is over '
          'is not saved.')
      .given('A persistor with a throttle.')
      .when('The state changes, and then goes back to the persisted state object,')
      .and('before the throttle is over.')
      .then('Nothing is saved when the throttle is over.')
      .run((_) async {
    var (s0, s1) = (S(0), S(1));
    var p = ControlledPersistor(stored: s0, throttle: throttle, autoFinish: true);
    var store = Store<S>(initialState: s0, persistor: p);

    store.dispatch(SetState(s1));
    store.dispatch(SetState(s0));
    await wait(500);

    expect(p.saves, isEmpty);
    expect(p.stored, same(store.state));
  });

  Bdd(feature)
      .scenario('A state waiting for a running save is saved when it finishes, '
          'if the throttle is over.')
      .given('A persistor with a throttle.')
      .and('The throttle is over, the state changed, and its save is running.')
      .and('The state changed again, while the save is running.')
      .when('The running save finishes after the throttle is over.')
      .then('The newest state is saved right away.')
      .run((_) async {
    var (s0, s1, s2) = (S(0), S(1), S(2));
    var p = ControlledPersistor(stored: s0, throttle: throttle);
    var store = Store<S>(initialState: s0, persistor: p);
    await wait(400);

    store.dispatch(SetState(s1));
    store.dispatch(SetState(s2));
    await wait(400);
    expect(p.saves.length, 1);

    await p.finish(0);
    expect(p.saves.length, 2);
    expect(p.saves[1].lastPersistedState, same(s1));
    expect(p.saves[1].newState, same(s2));
  });

  Bdd(feature)
      .scenario('A state waiting for a running save is saved when the throttle is over, '
          'if the save finishes before that.')
      .given('A persistor with a throttle.')
      .and('The throttle is over, the state changed, and its save is running.')
      .and('The state changed again, while the save is running.')
      .when('The running save finishes before the throttle is over.')
      .then('The newest state is not saved right away.')
      .and('It is saved when the throttle, counted from the start of the last save, '
          'is over.')
      .run((_) async {
    var (s0, s1, s2) = (S(0), S(1), S(2));
    var p = ControlledPersistor(stored: s0, throttle: throttle);
    var store = Store<S>(initialState: s0, persistor: p);
    await wait(400);

    store.dispatch(SetState(s1));
    store.dispatch(SetState(s2));
    await wait(50);
    await p.finish(0);
    expect(p.saves.length, 1);

    await wait(450);
    expect(p.saves.length, 2);
    expect(p.saves[1].lastPersistedState, same(s1));
    expect(p.saves[1].newState, same(s2));
  });

  // ==========================================================================
  // PersistAction.
  // ==========================================================================

  Bdd(feature)
      .scenario('PersistAction saves the state right away, ignoring the throttle.')
      .given('A persistor with a throttle.')
      .and('The state changed, and is waiting for the throttle.')
      .when('A PersistAction is dispatched.')
      .then('The state is saved right away.')
      .and('It is not saved again when the throttle is over.')
      .run((_) async {
    var (s0, s1) = (S(0), S(1));
    var p = ControlledPersistor(stored: s0, throttle: throttle, autoFinish: true);
    var store = Store<S>(initialState: s0, persistor: p);

    store.dispatch(SetState(s1));
    expect(p.saves, isEmpty);

    store.dispatch(PersistAction<S>());
    expect(p.saves.length, 1);
    expect(p.saves[0].newState, same(s1));

    await wait(500);
    expect(p.saves.length, 1);
    expect(p.stored, same(s1));
  });

  Bdd(feature)
      .scenario('PersistAction while a save is running saves the newest state '
          'when the save finishes, ignoring the throttle.')
      .given('A persistor with a throttle.')
      .and('The throttle is over, the state changed, and its save is running.')
      .and('The state changed again, while the save is running.')
      .when('A PersistAction is dispatched.')
      .and('The running save finishes before the throttle is over.')
      .then('The newest state is saved right away, ignoring the throttle.')
      .run((_) async {
    var (s0, s1, s2) = (S(0), S(1), S(2));
    var p = ControlledPersistor(stored: s0, throttle: throttle);
    var store = Store<S>(initialState: s0, persistor: p);
    await wait(400);

    store.dispatch(SetState(s1));
    store.dispatch(SetState(s2));
    store.dispatch(PersistAction<S>());
    expect(p.saves.length, 1);

    await p.finish(0);
    expect(p.saves.length, 2);
    expect(p.saves[1].lastPersistedState, same(s1));
    expect(p.saves[1].newState, same(s2));
  });

  Bdd(feature)
      .scenario('PersistAction while a save is running does nothing else, '
          'if the state did not change after the save started.')
      .given('A persistor with a throttle.')
      .and('The throttle is over, the state changed, and its save is running.')
      .when('A PersistAction is dispatched.')
      .and('The running save finishes.')
      .then('Nothing else is saved, not even after the throttle is over.')
      .run((_) async {
    var (s0, s1) = (S(0), S(1));
    var p = ControlledPersistor(stored: s0, throttle: throttle);
    var store = Store<S>(initialState: s0, persistor: p);
    await wait(400);

    store.dispatch(SetState(s1));
    store.dispatch(PersistAction<S>());

    await p.finish(0);
    await wait(500);
    expect(p.saves.length, 1);
    expect(p.stored, same(s1));
  });

  Bdd(feature)
      .scenario('PersistAction does nothing if the state is already persisted.')
      .given('A persistor with a throttle.')
      .and('The state did not change.')
      .when('A PersistAction is dispatched.')
      .then('Nothing is saved.')
      .run((_) async {
    var s0 = S(0);
    var p = ControlledPersistor(stored: s0, throttle: throttle, autoFinish: true);
    var store = Store<S>(initialState: s0, persistor: p);

    store.dispatch(PersistAction<S>());
    await wait(500);
    expect(p.saves, isEmpty);
  });

  // ==========================================================================
  // Pause and resume.
  // ==========================================================================

  Bdd(feature)
      .scenario('A paused persistor does not save, and saves the newest state '
          'when resumed.')
      .given('A persistor with no throttle.')
      .and('The persistor is paused.')
      .when('The state changes 3 times.')
      .then('Nothing is saved.')
      .and('When the persistor is resumed, only the newest state is saved.')
      .run((_) async {
    var (s0, s1, s2, s3) = (S(0), S(1), S(2), S(3));
    var p = ControlledPersistor(stored: s0, autoFinish: true);
    var store = Store<S>(initialState: s0, persistor: p);

    store.pausePersistor();
    store.dispatch(SetState(s1));
    store.dispatch(SetState(s2));
    store.dispatch(SetState(s3));
    await pumpEventQueue();
    expect(p.saves, isEmpty);

    store.resumePersistor();
    await pumpEventQueue();
    expect(p.saves.length, 1);
    expect(p.saves[0].lastPersistedState, same(s0));
    expect(p.saves[0].newState, same(s3));
    expect(p.stored, same(s3));
  });

  Bdd(feature)
      .scenario('PersistAction does not save while the persistor is paused.')
      .given('A persistor with no throttle.')
      .and('The persistor is paused, and the state changed.')
      .when('A PersistAction is dispatched.')
      .then('Nothing is saved.')
      .run((_) async {
    var (s0, s1) = (S(0), S(1));
    var p = ControlledPersistor(stored: s0, autoFinish: true);
    var store = Store<S>(initialState: s0, persistor: p);

    store.pausePersistor();
    store.dispatch(SetState(s1));
    store.dispatch(PersistAction<S>());
    await pumpEventQueue();
    expect(p.saves, isEmpty);
  });

  Bdd(feature)
      .scenario('Resuming the persistor does nothing if the state is already persisted.')
      .given('A persistor with no throttle.')
      .when('The persistor is paused and resumed, before any state change.')
      .and('The persistor is paused, the state changes and goes back to the '
          'persisted state object, and the persistor is resumed.')
      .then('Nothing is saved.')
      .run((_) async {
    var (s0, s1) = (S(0), S(1));
    var p = ControlledPersistor(stored: s0, autoFinish: true);
    var store = Store<S>(initialState: s0, persistor: p);

    store.pausePersistor();
    store.resumePersistor();
    await pumpEventQueue();
    expect(p.saves, isEmpty);

    store.pausePersistor();
    store.dispatch(SetState(s1));
    store.dispatch(SetState(s0));
    store.resumePersistor();
    await pumpEventQueue();
    expect(p.saves, isEmpty);
  });

  Bdd(feature)
      .scenario('Pausing the persistor does not affect the running save.')
      .given('A persistor with no throttle.')
      .and('The state changed, and its save is running.')
      .when('The persistor is paused, and the state changes again.')
      .then('The running save finishes, and the new state is not saved.')
      .and('When the persistor is resumed, the new state is saved.')
      .run((_) async {
    var (s0, s1, s2) = (S(0), S(1), S(2));
    var p = ControlledPersistor(stored: s0);
    var store = Store<S>(initialState: s0, persistor: p);

    store.dispatch(SetState(s1));
    store.pausePersistor();
    store.dispatch(SetState(s2));

    await p.finish(0);
    expect(p.saves.length, 1);
    expect(p.stored, same(s1));

    store.resumePersistor();
    await pumpEventQueue();
    expect(p.saves.length, 2);
    expect(p.saves[1].lastPersistedState, same(s1));
    expect(p.saves[1].newState, same(s2));
  });

  Bdd(feature)
      .scenario(
          'The state goes back to the last persisted state while a save is running, '
          'and the persistor is paused.')
      .given('A persistor with no throttle.')
      .and('The state changed, and its save is running.')
      .when('The persistor is paused,')
      .and('and the state goes back to the last persisted state object.')
      .and('The running save finishes.')
      .then('When the persistor is resumed, the last persisted state is saved again.')
      .run((_) async {
    var (s0, s1) = (S(0), S(1));
    var p = ControlledPersistor(stored: s0);
    var store = Store<S>(initialState: s0, persistor: p);

    store.dispatch(SetState(s1));
    store.pausePersistor();
    store.dispatch(SetState(s0));

    await p.finish(0);
    expect(p.saves.length, 1);

    store.resumePersistor();
    await pumpEventQueue();
    expect(p.saves.length, 2);
    expect(p.saves[1].lastPersistedState, same(s1));
    expect(p.saves[1].newState, same(s0));

    await p.finish(1);
    expect(p.stored, same(store.state));
  });

  Bdd(feature)
      .scenario('A paused persistor does not save when the throttle is over.')
      .given('A persistor with a throttle.')
      .and('The state changed, and is waiting for the throttle.')
      .when('The persistor is paused, and the throttle is over.')
      .then('Nothing is saved.')
      .and('When the persistor is resumed, the state is saved.')
      .run((_) async {
    var (s0, s1) = (S(0), S(1));
    var p = ControlledPersistor(stored: s0, throttle: throttle, autoFinish: true);
    var store = Store<S>(initialState: s0, persistor: p);

    store.dispatch(SetState(s1));
    store.pausePersistor();
    await wait(500);
    expect(p.saves, isEmpty);

    store.resumePersistor();
    await pumpEventQueue();
    expect(p.saves.length, 1);
    expect(p.saves[0].newState, same(s1));
  });

  Bdd(feature)
      .scenario('persistAndPausePersistor saves the state right away, and then pauses.')
      .given('A persistor with a throttle.')
      .and('The state changed, and is waiting for the throttle.')
      .when('persistAndPausePersistor is called.')
      .then('The state is saved right away, ignoring the throttle.')
      .and('Later state changes are not saved, even after the throttle is over.')
      .and('When the persistor is resumed, the newest state is saved.')
      .run((_) async {
    var (s0, s1, s2) = (S(0), S(1), S(2));
    var p = ControlledPersistor(stored: s0, throttle: throttle, autoFinish: true);
    var store = Store<S>(initialState: s0, persistor: p);

    store.dispatch(SetState(s1));
    store.persistAndPausePersistor();
    expect(p.saves.length, 1);
    expect(p.saves[0].newState, same(s1));

    store.dispatch(SetState(s2));
    await wait(500);
    expect(p.saves.length, 1);
    expect(p.stored, same(s1));

    store.resumePersistor();
    await pumpEventQueue();
    expect(p.saves.length, 2);
    expect(p.saves[1].lastPersistedState, same(s1));
    expect(p.saves[1].newState, same(s2));
  });

  Bdd(feature)
      .scenario('persistAndPausePersistor does not save if the state is already '
          'persisted.')
      .given('A persistor with no throttle.')
      .when('persistAndPausePersistor is called before any state change.')
      .and('persistAndPausePersistor is called after the state changed and was saved.')
      .then('Nothing else is saved.')
      .run((_) async {
    var (s0, s1) = (S(0), S(1));
    var p = ControlledPersistor(stored: s0, autoFinish: true);
    var store = Store<S>(initialState: s0, persistor: p);

    store.persistAndPausePersistor();
    await pumpEventQueue();
    expect(p.saves, isEmpty);

    store.resumePersistor();
    store.dispatch(SetState(s1));
    await pumpEventQueue();
    expect(p.saves.length, 1);

    store.persistAndPausePersistor();
    await pumpEventQueue();
    expect(p.saves.length, 1);
  });

  Bdd(feature)
      .scenario('persistAndPausePersistor while a save is running saves the newest state '
          'when the save finishes.')
      .given('A persistor with a throttle.')
      .and('The throttle is over, the state changed, and its save is running.')
      .and('The state changed again, while the save is running.')
      .when('persistAndPausePersistor is called.')
      .then('No other save starts while the running save is running.')
      .and(
          'When it finishes, the newest state is saved right away, ignoring the throttle.')
      .and('Then the persistor is paused, so later state changes are not saved.')
      .and('When the persistor is resumed, the newest state is saved.')
      .run((_) async {
    var (s0, s1, s2, s3) = (S(0), S(1), S(2), S(3));
    var p = ControlledPersistor(stored: s0, throttle: throttle);
    var store = Store<S>(initialState: s0, persistor: p);
    await wait(400);

    store.dispatch(SetState(s1));
    store.dispatch(SetState(s2));
    store.persistAndPausePersistor();
    expect(p.saves.length, 1);

    await p.finish(0);
    expect(p.saves.length, 2);
    expect(p.saves[1].lastPersistedState, same(s1));
    expect(p.saves[1].newState, same(s2));
    await p.finish(1);
    expect(p.stored, same(s2));

    store.dispatch(SetState(s3));
    await wait(500);
    expect(p.saves.length, 2);

    store.resumePersistor();
    await pumpEventQueue();
    expect(p.saves.length, 3);
    expect(p.saves[2].lastPersistedState, same(s2));
    expect(p.saves[2].newState, same(s3));
  });

  Bdd(feature)
      .scenario('persistAndPausePersistor while a save is running does nothing else, '
          'if the state did not change after the save started.')
      .given('A persistor with no throttle.')
      .and('The state changed, and its save is running.')
      .when('persistAndPausePersistor is called.')
      .and('The running save finishes.')
      .then('Nothing else is saved.')
      .and('The persistor is paused.')
      .run((_) async {
    var (s0, s1, s2) = (S(0), S(1), S(2));
    var p = ControlledPersistor(stored: s0);
    var store = Store<S>(initialState: s0, persistor: p);

    store.dispatch(SetState(s1));
    store.persistAndPausePersistor();

    await p.finish(0);
    expect(p.saves.length, 1);
    expect(p.stored, same(s1));

    store.dispatch(SetState(s2));
    await pumpEventQueue();
    expect(p.saves.length, 1);
  });

  Bdd(feature)
      .scenario('persistAndPausePersistor while a save is running does not save the '
          'state changes made after it was called.')
      .given('A persistor with no throttle.')
      .and('The state changed, and its save is running.')
      .when('persistAndPausePersistor is called.')
      .and('The state changes again, before the running save finishes.')
      .then('When the running save finishes, nothing else is saved.')
      .and('When the persistor is resumed, the newest state is saved.')
      .run((_) async {
    var (s0, s1, s2) = (S(0), S(1), S(2));
    var p = ControlledPersistor(stored: s0);
    var store = Store<S>(initialState: s0, persistor: p);

    store.dispatch(SetState(s1));
    store.persistAndPausePersistor();
    store.dispatch(SetState(s2));

    await p.finish(0);
    expect(p.saves.length, 1);
    expect(p.stored, same(s1));

    store.resumePersistor();
    await pumpEventQueue();
    expect(p.saves.length, 2);
    expect(p.saves[1].lastPersistedState, same(s1));
    expect(p.saves[1].newState, same(s2));
  });

  Bdd(feature)
      .scenario('persistAndPausePersistor while a save is running saves the state it was '
          'called with, not a later one.')
      .given('A persistor with no throttle.')
      .and('The state changed, and its save is running.')
      .and('The state changed again, while the save is running.')
      .when('persistAndPausePersistor is called.')
      .and('The state changes again, before the running save finishes.')
      .then('When the running save finishes, the state at the time of the call is saved.')
      .and('Nothing else is saved, until the persistor is resumed.')
      .run((_) async {
    var (s0, s1, s2, s3) = (S(0), S(1), S(2), S(3));
    var p = ControlledPersistor(stored: s0);
    var store = Store<S>(initialState: s0, persistor: p);

    store.dispatch(SetState(s1));
    store.dispatch(SetState(s2));
    store.persistAndPausePersistor();
    store.dispatch(SetState(s3));

    await p.finish(0);
    expect(p.saves.length, 2);
    expect(p.saves[1].lastPersistedState, same(s1));
    expect(p.saves[1].newState, same(s2));

    await p.finish(1);
    expect(p.saves.length, 2);
    expect(p.stored, same(s2));

    store.resumePersistor();
    await pumpEventQueue();
    expect(p.saves.length, 3);
    expect(p.saves[2].lastPersistedState, same(s2));
    expect(p.saves[2].newState, same(s3));
  });

  Bdd(feature)
      .scenario('persistAndPausePersistor while a save is running, and then resumed '
          'before the save finishes.')
      .given('A persistor with no throttle.')
      .and('The state changed, and its save is running.')
      .and('The state changed again, while the save is running.')
      .when('persistAndPausePersistor is called.')
      .and('The state changes again.')
      .and('The persistor is resumed, before the running save finishes.')
      .then('When the running save finishes, the state at the time of the call is saved.')
      .and('When that save finishes, the newest state is saved.')
      .run((_) async {
    var (s0, s1, s2, s3) = (S(0), S(1), S(2), S(3));
    var p = ControlledPersistor(stored: s0);
    var store = Store<S>(initialState: s0, persistor: p);

    store.dispatch(SetState(s1));
    store.dispatch(SetState(s2));
    store.persistAndPausePersistor();
    store.dispatch(SetState(s3));
    store.resumePersistor();

    await p.finish(0);
    expect(p.saves.length, 2);
    expect(p.saves[1].newState, same(s2));

    await p.finish(1);
    expect(p.saves.length, 3);
    expect(p.saves[2].lastPersistedState, same(s2));
    expect(p.saves[2].newState, same(s3));
  });

  // ==========================================================================
  // Reading, deleting, and saving the initial state, through the store.
  // ==========================================================================

  Bdd(feature)
      .scenario('Reading the state through the store makes it the last persisted state.')
      .given('A persistor with a saved state.')
      .when('The state is read with readStateFromPersistence.')
      .then('It returns the saved state.')
      .and('The saved state becomes the last persisted state.')
      .run((_) async {
    var (s0, s5) = (S(0), S(5));
    var p = ControlledPersistor(stored: s0);
    var store = Store<S>(initialState: s0, persistor: p);

    p.stored = s5;
    var read = await store.readStateFromPersistence();
    expect(read, same(s5));
    expect(store.getLastPersistedStateFromPersistor(), same(s5));
  });

  Bdd(feature)
      .scenario('Reading the state while a save is running: '
          'it waits for the save, and reads the saved state.')
      .given('A persistor with no throttle.')
      .and('The state changed, and its save is running.')
      .when('The state is read with readStateFromPersistence.')
      .then('The read waits for the running save to finish.')
      .and('It returns the state that was just saved.')
      .and('That state is the last persisted state.')
      .run((_) async {
    var (s0, s1) = (S(0), S(1));
    var p = ControlledPersistor(stored: s0);
    var store = Store<S>(initialState: s0, persistor: p);

    store.dispatch(SetState(s1));
    S? read;
    store.readStateFromPersistence().then((state) => read = state);
    await pumpEventQueue();
    expect(read, isNull);

    await p.finish(0);
    expect(read, same(s1));
    expect(store.getLastPersistedStateFromPersistor(), same(s1));
  });

  Bdd(feature)
      .scenario('A state change while the state is being read '
          'is saved after the read finishes.')
      .given('A persistor with no throttle, where reading the state takes some time.')
      .when('The state is read with readStateFromPersistence.')
      .and('The state changes while the read is running.')
      .then('Nothing is saved while the read is running.')
      .and('When the read finishes, the new state is saved,')
      .and('with the difference from the state that was read.')
      .run((_) async {
    var (s0, s1) = (S(0), S(1));
    var p = ControlledPersistor(stored: s0)..readCanFinish = Completer();
    var store = Store<S>(initialState: s0, persistor: p);

    var reading = store.readStateFromPersistence();
    store.dispatch(SetState(s1));
    await pumpEventQueue();
    expect(p.saves, isEmpty);

    p.readCanFinish!.complete();
    expect(await reading, same(s0));
    await pumpEventQueue();
    expect(p.saves.length, 1);
    expect(p.saves[0].lastPersistedState, same(s0));
    expect(p.saves[0].newState, same(s1));
  });

  Bdd(feature)
      .scenario('If reading the state fails, the error goes to the caller, '
          'and the state keeps being saved.')
      .given('A persistor with no throttle, where reading the state takes some time,')
      .and('and then fails.')
      .when('The state is read with readStateFromPersistence.')
      .and('The state changes while the read is running.')
      .then('The read throws the error.')
      .and('The last persisted state does not change.')
      .and('When the read finishes, the new state is saved.')
      .run((_) async {
    var (s0, s1) = (S(0), S(1));
    var p = ControlledPersistor(stored: s0)
      ..readCanFinish = Completer()
      ..readError = StateError('Read failed');
    var store = Store<S>(initialState: s0, persistor: p);

    var reading = store.readStateFromPersistence();
    store.dispatch(SetState(s1));
    await pumpEventQueue();
    expect(p.saves, isEmpty);

    p.readCanFinish!.complete();
    await expectLater(reading, throwsA(isA<StateError>()));
    expect(store.getLastPersistedStateFromPersistor(), same(s0));

    await pumpEventQueue();
    expect(p.saves.length, 1);
    expect(p.saves[0].lastPersistedState, same(s0));
    expect(p.saves[0].newState, same(s1));
  });

  Bdd(feature)
      .scenario('Saving the initial state through the store saves the whole state.')
      .given('A persistor.')
      .when('A state is saved with saveInitialStateInPersistence.')
      .then('It is saved with no last persisted state (so the whole state is saved).')
      .and('It becomes the last persisted state.')
      .run((_) async {
    var (s0, s5) = (S(0), S(5));
    var p = ControlledPersistor(stored: s0, autoFinish: true);
    var store = Store<S>(initialState: s0, persistor: p);

    await store.saveInitialStateInPersistence(s5);
    expect(p.saves.length, 1);
    expect(p.saves[0].lastPersistedState, isNull);
    expect(p.saves[0].newState, same(s5));
    expect(p.stored, same(s5));
    expect(store.getLastPersistedStateFromPersistor(), same(s5));
  });

  Bdd(feature)
      .scenario('Deleting the state while a save is running: the state stays deleted.')
      .given('A persistor with no throttle.')
      .and('The state changed, and its save is running.')
      .when('The state is deleted with deleteStateFromPersistence.')
      .and('The running save finishes.')
      .then('The state stays deleted.')
      .and('There is no last persisted state.')
      .run((_) async {
    var (s0, s1) = (S(0), S(1));
    var p = ControlledPersistor(stored: s0);
    var store = Store<S>(initialState: s0, persistor: p);

    store.dispatch(SetState(s1));
    var deleting = store.deleteStateFromPersistence();
    await pumpEventQueue();

    await p.finish(0);
    await deleting;
    expect(p.saves.length, 1);
    expect(p.stored, isNull);
    expect(store.getLastPersistedStateFromPersistor(), isNull);
  });

  Bdd(feature)
      .scenario('A state change while the state is being deleted '
          'is saved after the delete finishes.')
      .given('A persistor with no throttle, where deleting the state takes some time.')
      .when('The state is deleted with deleteStateFromPersistence.')
      .and('The state changes while the delete is running.')
      .then('Nothing is saved while the delete is running.')
      .and('When the delete finishes, the whole new state is saved.')
      .run((_) async {
    var (s0, s1) = (S(0), S(1));
    var p = ControlledPersistor(stored: s0)..deleteCanFinish = Completer();
    var store = Store<S>(initialState: s0, persistor: p);

    var deleting = store.deleteStateFromPersistence();
    store.dispatch(SetState(s1));
    await pumpEventQueue();
    expect(p.saves, isEmpty);

    p.deleteCanFinish!.complete();
    await deleting;
    await pumpEventQueue();
    expect(p.saves.length, 1);
    expect(p.saves[0].lastPersistedState, isNull);
    expect(p.saves[0].newState, same(s1));

    await p.finish(0);
    expect(p.stored, same(s1));
    expect(store.getLastPersistedStateFromPersistor(), same(s1));
  });

  Bdd(feature)
      .scenario('Saving the initial state while a save is running: '
          'the initial state stays saved.')
      .given('A persistor with no throttle.')
      .and('The state changed, and its save is running.')
      .when('A state is saved with saveInitialStateInPersistence.')
      .then('It is saved after the running save finishes.')
      .and('It stays saved, and is the last persisted state.')
      .run((_) async {
    var (s0, s1, s5) = (S(0), S(1), S(5));
    var p = ControlledPersistor(stored: s0);
    var store = Store<S>(initialState: s0, persistor: p);

    store.dispatch(SetState(s1));
    var saving = store.saveInitialStateInPersistence(s5);
    await pumpEventQueue();
    expect(p.saves.length, 1);

    await p.finish(0);
    expect(p.saves.length, 2);
    expect(p.saves[1].lastPersistedState, isNull);
    expect(p.saves[1].newState, same(s5));

    await p.finish(1);
    await saving;
    expect(p.stored, same(s5));
    expect(store.getLastPersistedStateFromPersistor(), same(s5));
  });

  Bdd(feature)
      .scenario(
          'After the state is deleted, the next state change saves the whole state.')
      .given('A persistor with no throttle.')
      .when('The state is deleted with deleteStateFromPersistence.')
      .then('There is no last persisted state.')
      .and('The next state change is saved with no last persisted state '
          '(so the whole state is saved).')
      .run((_) async {
    var (s0, s1) = (S(0), S(1));
    var p = ControlledPersistor(stored: s0, autoFinish: true);
    var store = Store<S>(initialState: s0, persistor: p);

    await store.deleteStateFromPersistence();
    expect(p.stored, isNull);
    expect(store.getLastPersistedStateFromPersistor(), isNull);

    store.dispatch(SetState(s1));
    await pumpEventQueue();
    expect(p.saves.length, 1);
    expect(p.saves[0].lastPersistedState, isNull);
    expect(p.saves[0].newState, same(s1));
    expect(p.stored, same(s1));
  });

  // ==========================================================================
  // Cloud sync, and the persistor decorator.
  // ==========================================================================

  Bdd(feature)
      .scenario('The cloud sync works like the persistor, independently from it.')
      .given('A store with a persistor and a cloud sync, both with no throttle.')
      .when('Only the persistor is paused, and the state changes.')
      .and('Then only the cloud sync is paused, and the state changes again.')
      .then('Each one saves the state only while it is not paused.')
      .and('Each one, when resumed, saves the newest state.')
      .run((_) async {
    var (s0, s1, s2) = (S(0), S(1), S(2));
    var p = ControlledPersistor(stored: s0, autoFinish: true);
    var cloud = ControlledPersistor(stored: s0, autoFinish: true);
    var store = Store<S>(initialState: s0, persistor: p, cloudSync: cloud);

    store.pausePersistor();
    store.dispatch(SetState(s1));
    await pumpEventQueue();
    expect(p.saves, isEmpty);
    expect(cloud.saves.length, 1);
    expect(cloud.stored, same(s1));
    expect(store.getLastPersistedStateFromCloudSync(), same(s1));
    expect(store.getLastPersistedStateFromPersistor(), same(s0));

    store.pauseCloudSync();
    store.resumePersistor();
    await pumpEventQueue();
    expect(p.saves.length, 1);
    expect(p.saves[0].lastPersistedState, same(s0));
    expect(p.saves[0].newState, same(s1));

    store.dispatch(SetState(s2));
    await pumpEventQueue();
    expect(p.saves.length, 2);
    expect(p.saves[1].lastPersistedState, same(s1));
    expect(p.saves[1].newState, same(s2));
    expect(cloud.saves.length, 1);

    store.resumeCloudSync();
    await pumpEventQueue();
    expect(cloud.saves.length, 2);
    expect(cloud.saves[1].lastPersistedState, same(s1));
    expect(cloud.saves[1].newState, same(s2));
  });

  Bdd(feature)
      .scenario('The cloud sync has its own read, delete, save, and persist-and-pause.')
      .given('A store with a persistor and a cloud sync.')
      .when('The cloud state is read, saved, deleted, and persisted-and-paused.')
      .then('Only the cloud sync is affected.')
      .run((_) async {
    var (s0, s1, s5, s6) = (S(0), S(1), S(5), S(6));
    var p = ControlledPersistor(stored: s0, throttle: throttle, autoFinish: true);
    var cloud = ControlledPersistor(stored: s0, throttle: throttle, autoFinish: true);
    var store = Store<S>(initialState: s0, persistor: p, cloudSync: cloud);

    cloud.stored = s5;
    expect(await store.readStateFromCloudSync(), same(s5));
    expect(store.getLastPersistedStateFromCloudSync(), same(s5));
    expect(store.getLastPersistedStateFromPersistor(), same(s0));

    await store.saveInitialStateInCloud(s6);
    expect(cloud.stored, same(s6));
    expect(store.getLastPersistedStateFromCloudSync(), same(s6));

    await store.deleteStateFromCloud();
    expect(cloud.stored, isNull);
    expect(store.getLastPersistedStateFromCloudSync(), isNull);
    expect(p.stored, same(s0));

    store.dispatch(SetState(s1));
    store.persistAndPauseCloudSync();
    await pumpEventQueue();
    expect(cloud.saves.last.newState, same(s1));
    expect(p.saves, isEmpty);
  });

  Bdd(feature)
      .scenario('The PersistorPrinterDecorator delegates to its persistor.')
      .given('A persistor with a throttle, inside a PersistorPrinterDecorator.')
      .when('The state is read, saved, deleted, and changed.')
      .then('The persistor does each of these.')
      .and('The throttle of the persistor is used.')
      .run((_) async {
    var (s0, s1, s5) = (S(0), S(1), S(5));
    var p = ControlledPersistor(stored: s0, throttle: throttle, autoFinish: true);
    var store = Store<S>(initialState: s0, persistor: PersistorPrinterDecorator(p));

    p.stored = s5;
    expect(await store.readStateFromPersistence(), same(s5));

    await store.saveInitialStateInPersistence(s0);
    expect(p.saves.single.lastPersistedState, isNull);
    expect(p.stored, same(s0));

    store.dispatch(SetState(s1));
    await wait(100);
    expect(p.saves.length, 1);
    await wait(400);
    expect(p.saves.length, 2);
    expect(p.saves[1].lastPersistedState, same(s0));
    expect(p.saves[1].newState, same(s1));

    await store.deleteStateFromPersistence();
    expect(p.stored, isNull);
  });
}

/// The state. It's compared by identity in the persistence,
/// so the scenarios use `same()` to check it.
class S {
  final int n;

  S(this.n);

  @override
  bool operator ==(Object other) => other is S && other.n == n;

  @override
  int get hashCode => n.hashCode;

  @override
  String toString() => 'S($n)';
}

/// A call to [Persistor.persistDifference].
class Save {
  final S? lastPersistedState;
  final S newState;
  final Completer<void> completer = Completer();

  Save(this.lastPersistedState, this.newState);
}

/// A persistor where each save keeps running until the scenario calls [finish] or [fail],
/// unless [autoFinish] is true. The saved state ([stored]) changes when the save finishes.
class ControlledPersistor extends Persistor<S> {
  ControlledPersistor({
    this.stored,
    Duration? throttle,
    this.autoFinish = false,
  }) : _throttle = throttle;

  final Duration? _throttle;

  /// If true, each save finishes right away.
  final bool autoFinish;

  /// If true, [wrapError] swallows the errors of the saves that [fail].
  bool swallowErrors = false;

  /// The saved state.
  S? stored;

  /// All calls to [persistDifference], in order.
  final saves = <Save>[];

  @override
  Duration? get throttle => _throttle;

  /// If set, [readState] only finishes after this completes.
  Completer<void>? readCanFinish;

  /// If set, [readState] throws this error.
  Object? readError;

  @override
  Future<S?> readState() async {
    if (readCanFinish != null) await readCanFinish!.future;
    if (readError != null) throw readError!;
    return stored;
  }

  /// If set, [deleteState] only finishes after this completes.
  Completer<void>? deleteCanFinish;

  @override
  Future<void> deleteState() async {
    if (deleteCanFinish != null) await deleteCanFinish!.future;
    stored = null;
  }

  @override
  Future<void> persistDifference({
    required S? lastPersistedState,
    required S newState,
  }) {
    var save = Save(lastPersistedState, newState);
    saves.add(save);
    if (autoFinish) {
      stored = newState;
      save.completer.complete();
    }
    return save.completer.future;
  }

  /// Finishes the save with the given [index], successfully.
  Future<void> finish(int index) async {
    var save = saves[index];
    stored = save.newState;
    save.completer.complete();
    await pumpEventQueue();
  }

  /// Finishes the save with the given [index], with an error.
  Future<void> fail(int index) async {
    saves[index].completer.completeError(StateError('Save failed'));
    await pumpEventQueue();
  }

  @override
  Object? wrapError(Object error, StackTrace stackTrace) => swallowErrors ? null : error;
}

class SetState extends ReduxAction<S> {
  final S newState;

  SetState(this.newState);

  @override
  S reduce() => newState;
}

class SetStateAsync extends ReduxAction<S> {
  final S newState;
  final Future<void> canFinish;

  SetStateAsync(this.newState, this.canFinish);

  @override
  Future<S> reduce() async {
    await canFinish;
    return newState;
  }
}

class ReturnNull extends ReduxAction<S> {
  @override
  S? reduce() => null;
}

class ReturnSameState extends ReduxAction<S> {
  @override
  S reduce() => state;
}
