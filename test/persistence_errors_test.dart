import 'dart:async';

import "package:async_redux/async_redux.dart";
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  //
  test('A UserException thrown by the persistor goes to the error queue.', () async {
    var persistor = FailingPersistor();
    var store = Store<int>(initialState: 0, persistor: persistor);

    persistor.errorToThrow = const UserException('Could not save');
    await store.dispatchAndWait(SetAction(1));
    await pumpEventQueue();

    expect(store.state, 1);
    expect(store.errors.length, 1);
    expect(store.errors.first.message, 'Could not save');
  });

  test('A UserException with noDialog does NOT go to the error queue.', () async {
    var persistor = FailingPersistor();
    var store = Store<int>(initialState: 0, persistor: persistor);

    persistor.errorToThrow = const UserException('Could not save').noDialog;
    await store.dispatchAndWait(SetAction(1));
    await pumpEventQueue();

    expect(store.errors, isEmpty);
  });

  test('Persistor errors are given to the GlobalErrorObserver, with a null action.',
      () async {
    var persistor = FailingPersistor();
    var observed = <(Object, Object, ReduxAction<int>?)>[];

    var store = Store<int>(
      initialState: 0,
      persistor: persistor,
      globalErrorObserver: (store) => RecordingObserver(observed, (error) => error),
    );

    persistor.errorToThrow = const UserException('Could not save');
    await store.dispatchAndWait(SetAction(1));
    await pumpEventQueue();

    expect(observed.length, 1);
    expect(observed[0].$1, const UserException('Could not save'));
    expect(observed[0].$2, const UserException('Could not save'));
    expect(observed[0].$3, isNull);
    expect(store.errors.length, 1);
  });

  test('The GlobalErrorObserver can turn a persistor error into a UserException.',
      () async {
    var persistor = FailingPersistor();

    var store = Store<int>(
      initialState: 0,
      persistor: persistor,
      globalErrorObserver: (store) => RecordingObserver(
        [],
        (error) => (error is StateError) ? const UserException('Disk full') : error,
      ),
    );

    persistor.errorToThrow = StateError('disk full');
    await store.dispatchAndWait(SetAction(1));
    await pumpEventQueue();

    expect(store.errors.length, 1);
    expect(store.errors.first.message, 'Disk full');
  });

  test('The GlobalErrorObserver can swallow a persistor error.', () async {
    var persistor = FailingPersistor();

    var store = Store<int>(
      initialState: 0,
      persistor: persistor,
      globalErrorObserver: (store) => RecordingObserver([], (error) => null),
    );

    // If not swallowed, this would be an unhandled error, and would fail the test.
    persistor.errorToThrow = StateError('disk full');
    await store.dispatchAndWait(SetAction(1));
    await pumpEventQueue();

    expect(store.errors, isEmpty);
  });

  test('Other persistor errors are thrown as unhandled async errors.', () async {
    var persistor = FailingPersistor();
    var uncaught = <Object>[];

    await runZonedGuarded(() async {
      var store = Store<int>(initialState: 0, persistor: persistor);
      persistor.errorToThrow = StateError('disk full');
      await store.dispatchAndWait(SetAction(1));
      await pumpEventQueue();
      expect(store.errors, isEmpty);
    }, (error, stackTrace) => uncaught.add(error));

    expect(uncaught.length, 1);
    expect(uncaught.single, isA<StateError>());
  });

  test('Persistence keeps working after an error, '
      'and the failed difference is persisted next time.', () async {
    var persistor = FailingPersistor();
    var store = Store<int>(initialState: 0, persistor: persistor);

    persistor.errorToThrow = const UserException('Could not save');
    await store.dispatchAndWait(SetAction(1));
    await pumpEventQueue();

    // The failed state is not considered persisted.
    expect(store.getLastPersistedStateFromPersistor(), 0);
    expect(persistor.saved, isEmpty);

    persistor.errorToThrow = null;
    await store.dispatchAndWait(SetAction(2));
    await pumpEventQueue();

    // The difference is calculated from the last state that was actually persisted.
    expect(persistor.saved, [(0, 2)]);
    expect(store.getLastPersistedStateFromPersistor(), 2);
  });

  test('CloudSync errors are also processed.', () async {
    var cloudSync = FailingPersistor();
    var store = Store<int>(initialState: 0, cloudSync: cloudSync);

    cloudSync.errorToThrow = const UserException('Could not sync');
    await store.dispatchAndWait(SetAction(1));
    await pumpEventQueue();

    expect(store.errors.single.message, 'Could not sync');
  });

  test('The persistor wrapError can turn an error into a UserException, '
      'and the GlobalErrorObserver gets both the wrapped and the original error.', () async {
    var persistor = FailingPersistor()
      ..wrapper = ((error) => (error is StateError) ? const UserException('Disk full') : error);
    var observed = <(Object, Object, ReduxAction<int>?)>[];

    var store = Store<int>(
      initialState: 0,
      persistor: persistor,
      globalErrorObserver: (store) => RecordingObserver(observed, (error) => error),
    );

    var stateError = StateError('disk full');
    persistor.errorToThrow = stateError;
    await store.dispatchAndWait(SetAction(1));
    await pumpEventQueue();

    expect(observed.length, 1);
    expect(observed[0].$1, const UserException('Disk full'));
    expect(observed[0].$2, same(stateError));
    expect(observed[0].$3, isNull);
    expect(store.errors.single.message, 'Disk full');
  });

  test('If the persistor wrapError returns null, the error is swallowed, '
      'and the GlobalErrorObserver is not called.', () async {
    var persistor = FailingPersistor()..wrapper = ((error) => null);
    var observed = <(Object, Object, ReduxAction<int>?)>[];

    var store = Store<int>(
      initialState: 0,
      persistor: persistor,
      globalErrorObserver: (store) => RecordingObserver(observed, (error) => error),
    );

    // If not swallowed, this would be an unhandled error, and would fail the test.
    persistor.errorToThrow = StateError('disk full');
    await store.dispatchAndWait(SetAction(1));
    await pumpEventQueue();

    expect(observed, isEmpty);
    expect(store.errors, isEmpty);
  });

  test('If the persistor wrapError throws, the thrown error is used.', () async {
    var persistor = FailingPersistor()
      ..wrapper = ((error) => throw const UserException('Thrown by wrapError'));
    var store = Store<int>(initialState: 0, persistor: persistor);

    persistor.errorToThrow = StateError('disk full');
    await store.dispatchAndWait(SetAction(1));
    await pumpEventQueue();

    expect(store.errors.single.message, 'Thrown by wrapError');
  });

  test('The PersistorPrinterDecorator delegates wrapError.', () async {
    var persistor = FailingPersistor()
      ..wrapper = ((error) => const UserException('Wrapped'));
    var store = Store<int>(
      initialState: 0,
      persistor: PersistorPrinterDecorator(persistor),
    );

    persistor.errorToThrow = StateError('disk full');
    await store.dispatchAndWait(SetAction(1));
    await pumpEventQueue();

    expect(store.errors.single.message, 'Wrapped');
  });

  test('Errors added by readState before the store exists go to the error queue '
      'when the store is created.', () async {
    var persistor = FailingPersistor()
      ..errorToAddOnRead = const UserException('Data was reset');

    var initialState = await persistor.readState();
    expect(initialState, isNull);

    var store = Store<int>(initialState: 0, persistor: persistor);

    // Available right away, synchronously.
    expect(store.errors.single.message, 'Data was reset');
  });

  test('Errors added by the persistor are given to the GlobalErrorObserver, '
      'but NOT to the persistor wrapError.', () async {
    var wrapErrorCalls = 0;
    var persistor = FailingPersistor()
      ..errorToAddOnRead = StateError('bad format')
      ..wrapper = ((error) {
        wrapErrorCalls++;
        return error;
      });
    var observed = <(Object, Object, ReduxAction<int>?)>[];

    await persistor.readState();

    var store = Store<int>(
      initialState: 0,
      persistor: persistor,
      globalErrorObserver: (store) => RecordingObserver(
        observed,
        (error) => (error is StateError) ? const UserException('Data was reset') : error,
      ),
    );

    expect(wrapErrorCalls, 0);
    expect(observed.length, 1);
    expect(observed[0].$1, isA<StateError>());
    expect(observed[0].$2, isA<StateError>());
    expect(observed[0].$3, isNull);
    expect(store.errors.single.message, 'Data was reset');
  });

  test('Errors added by the persistor, which are not UserExceptions, '
      'are thrown as unhandled async errors.', () async {
    var persistor = FailingPersistor()..errorToAddOnRead = StateError('bad format');
    var uncaught = <Object>[];

    await runZonedGuarded(() async {
      await persistor.readState();
      var store = Store<int>(initialState: 0, persistor: persistor);
      await pumpEventQueue();
      expect(store.errors, isEmpty);
    }, (error, stackTrace) => uncaught.add(error));

    expect(uncaught.single, isA<StateError>());
  });

  test('The GlobalErrorObserver can swallow errors added by the persistor.', () async {
    var persistor = FailingPersistor()..errorToAddOnRead = StateError('bad format');

    await persistor.readState();

    // If not swallowed, this would be an unhandled error, and would fail the test.
    var store = Store<int>(
      initialState: 0,
      persistor: persistor,
      globalErrorObserver: (store) => RecordingObserver([], (error) => null),
    );
    await pumpEventQueue();

    expect(store.errors, isEmpty);
  });

  test('Errors added when reading the state through the store '
      'go to the error queue right away.', () async {
    var persistor = FailingPersistor();
    var store = Store<int>(initialState: 0, persistor: persistor);
    expect(store.errors, isEmpty);

    persistor.errorToAddOnRead = const UserException('Data was reset');
    await store.readStateFromPersistence();

    expect(store.errors.single.message, 'Data was reset');
  });

  test('Errors added while persisting the state go to the error queue.', () async {
    var persistor = FailingPersistor();
    var store = Store<int>(initialState: 0, persistor: persistor);

    persistor.errorToAddOnPersist = const UserException('Saved, but with a warning');
    await store.dispatchAndWait(SetAction(1));
    await pumpEventQueue();

    expect(persistor.saved, [(0, 1)]);
    expect(store.errors.single.message, 'Saved, but with a warning');
  });

  test('The PersistorPrinterDecorator forwards the errors added by its persistor.',
      () async {
    var persistor = FailingPersistor()
      ..errorToAddOnRead = const UserException('Data was reset');
    var decorator = PersistorPrinterDecorator(persistor);

    await decorator.readState();
    var store = Store<int>(initialState: 0, persistor: decorator);

    expect(store.errors.single.message, 'Data was reset');
  });

  test('CloudSync added errors are also processed.', () async {
    var cloudSync = FailingPersistor()
      ..errorToAddOnRead = const UserException('Cloud data was reset');

    await cloudSync.readState();
    var store = Store<int>(initialState: 0, cloudSync: cloudSync);

    expect(store.errors.single.message, 'Cloud data was reset');
  });

  // ---------------------------------------------------------------------------------------------
  // Errors thrown by persistDifference.
  // ---------------------------------------------------------------------------------------------

  test('A persistDifference that throws synchronously does not break the dispatch.',
      () async {
    var persistor = FailingPersistor()
      ..throwSynchronously = true
      ..errorToThrow = const UserException('Could not save');
    var store = Store<int>(initialState: 0, persistor: persistor);

    var status = await store.dispatchAndWait(SetAction(1));
    await pumpEventQueue();

    expect(persistor.persistCalls, 1);
    expect(store.state, 1);
    expect(status.isCompletedOk, isTrue);
    expect(store.isFailed(SetAction), isFalse);
    expect(store.errors.single.message, 'Could not save');
    expect(store.getLastPersistedStateFromPersistor(), 0);
  });

  test('A persistDifference that throws synchronously, with a non-UserException, '
      'does not break the dispatch, and the error is thrown as unhandled.', () async {
    var persistor = FailingPersistor()
      ..throwSynchronously = true
      ..errorToThrow = StateError('disk full');
    var uncaught = <Object>[];
    late ActionStatus status;
    late Store<int> store;

    await runZonedGuarded(() async {
      store = Store<int>(initialState: 0, persistor: persistor);
      status = await store.dispatchAndWait(SetAction(1));
      await pumpEventQueue();
    }, (error, stackTrace) => uncaught.add(error));

    expect(store.state, 1);
    expect(status.isCompletedOk, isTrue);
    expect(uncaught.single, isA<StateError>());
  });

  test('A persistor error does not make the action fail.', () async {
    var persistor = FailingPersistor()..errorToThrow = const UserException('Could not save');
    var store = Store<int>(initialState: 0, persistor: persistor);

    var status = await store.dispatchAndWait(SetAction(1));
    await pumpEventQueue();

    expect(status.isCompletedOk, isTrue);
    expect(status.originalError, isNull);
    expect(store.isFailed(SetAction), isFalse);
    expect(store.exceptionFor(SetAction), isNull);
    expect(store.errors.single.message, 'Could not save');
  });

  test('If the GlobalErrorObserver throws, the thrown error is used.', () async {
    var persistor = FailingPersistor()..errorToThrow = StateError('disk full');

    var store = Store<int>(
      initialState: 0,
      persistor: persistor,
      globalErrorObserver: (store) =>
          RecordingObserver([], (error) => throw const UserException('Thrown by observer')),
    );

    await store.dispatchAndWait(SetAction(1));
    await pumpEventQueue();

    expect(store.errors.single.message, 'Thrown by observer');
  });

  test('If the GlobalErrorObserver returns another error (not a UserException), '
      'that error is thrown as unhandled, and not the original one.', () async {
    var persistor = FailingPersistor()..errorToThrow = StateError('disk full');
    var uncaught = <Object>[];

    await runZonedGuarded(() async {
      var store = Store<int>(
        initialState: 0,
        persistor: persistor,
        globalErrorObserver: (store) =>
            RecordingObserver([], (error) => ArgumentError('replaced')),
      );
      await store.dispatchAndWait(SetAction(1));
      await pumpEventQueue();
      expect(store.errors, isEmpty);
    }, (error, stackTrace) => uncaught.add(error));

    expect(uncaught.single, isA<ArgumentError>());
    expect((uncaught.single as ArgumentError).message, 'replaced');
  });

  test('If the persistor wrapError returns another error (not a UserException), '
      'the GlobalErrorObserver gets it, and also the original error.', () async {
    var persistor = FailingPersistor()
      ..wrapper = ((error) => ArgumentError('wrapped'))
      ..errorToThrow = StateError('disk full');
    var observed = <(Object, Object, ReduxAction<int>?)>[];

    var store = Store<int>(
      initialState: 0,
      persistor: persistor,
      globalErrorObserver: (store) => RecordingObserver(observed, (error) => null),
    );

    await store.dispatchAndWait(SetAction(1));
    await pumpEventQueue();

    expect(observed.single.$1, isA<ArgumentError>());
    expect(observed.single.$2, isA<StateError>());
    expect(store.errors, isEmpty);
  });

  test('The GlobalErrorObserver gets the stack trace of the persistor error.', () async {
    var persistor = FailingPersistor()..errorToThrow = StateError('disk full');
    var stackTraces = <StackTrace>[];

    Store<int> store = Store<int>(
      initialState: 0,
      persistor: persistor,
      globalErrorObserver: (store) =>
          RecordingObserver([], (error) => null, stackTraces: stackTraces),
    );

    await store.dispatchAndWait(SetAction(1));
    await pumpEventQueue();

    expect(stackTraces.single.toString(), contains('_persistDifference'));
  });

  test('An error in a persist started by the throttle timer is also processed.', () async {
    var persistor = FailingPersistor()
      ..throttleDuration = const Duration(milliseconds: 50)
      ..errorToThrow = const UserException('Could not save');
    var store = Store<int>(initialState: 0, persistor: persistor);

    // The store was just created, so the throttle is not over, and a timer is created.
    await store.dispatchAndWait(SetAction(1));
    await pumpEventQueue();
    expect(persistor.persistCalls, 0);
    expect(store.errors, isEmpty);

    await Future.delayed(const Duration(milliseconds: 150));

    expect(persistor.persistCalls, 1);
    expect(store.errors.single.message, 'Could not save');
    expect(store.getLastPersistedStateFromPersistor(), 0);
  });

  test('If the state changes while a save is failing, the newest state is saved next, '
      'with the difference from the last state that was actually persisted.', () async {
    var persistor = FailingPersistor()
      ..saveDuration = const Duration(milliseconds: 100)
      ..throwOnce = true
      ..errorToThrow = const UserException('Could not save');
    var store = Store<int>(initialState: 0, persistor: persistor);

    // Starts saving state 1, which will fail.
    await store.dispatchAndWait(SetAction(1));

    // Changes the state while the save is still running.
    await store.dispatchAndWait(SetAction(2));
    expect(persistor.persistCalls, 1);

    await Future.delayed(const Duration(milliseconds: 350));

    expect(persistor.persistCalls, 2);
    expect(store.errors.single.message, 'Could not save');
    expect(persistor.saved, [(0, 2)]);
    expect(store.getLastPersistedStateFromPersistor(), 2);
  });

  test('After a failed save, dispatching PersistAction retries it, '
      'even if the state did not change.', () async {
    var persistor = FailingPersistor()..errorToThrow = const UserException('Could not save');
    var store = Store<int>(initialState: 0, persistor: persistor);

    await store.dispatchAndWait(SetAction(1));
    await pumpEventQueue();
    expect(persistor.saved, isEmpty);
    expect(store.getLastPersistedStateFromPersistor(), 0);

    persistor.errorToThrow = null;
    await store.dispatchAndWait(PersistAction());
    await pumpEventQueue();

    expect(persistor.saved, [(0, 1)]);
    expect(store.getLastPersistedStateFromPersistor(), 1);
  });

  test('If persistAndPausePersistor fails, the persistor stays paused, '
      'and resuming it retries the save.', () async {
    var persistor = FailingPersistor()
      ..throttleDuration = const Duration(seconds: 10)
      ..errorToThrow = const UserException('Could not save');
    var store = Store<int>(initialState: 0, persistor: persistor);

    // Not saved yet, because of the throttle.
    await store.dispatchAndWait(SetAction(1));
    expect(persistor.persistCalls, 0);

    // Saves right away (ignoring the throttle), and fails.
    store.persistAndPausePersistor();
    await pumpEventQueue();
    expect(persistor.persistCalls, 1);
    expect(store.errors.single.message, 'Could not save');

    // Still paused, so it does not try to save again.
    persistor.errorToThrow = null;
    await store.dispatchAndWait(SetAction(2));
    await pumpEventQueue();
    expect(persistor.persistCalls, 1);

    // When resumed, it saves again (the timer was canceled when paused).
    persistor.throttleDuration = null;
    store.resumePersistor();
    await pumpEventQueue();
    expect(persistor.persistCalls, 2);
    expect(persistor.saved, [(0, 2)]);
  });

  test('Repeated failures generate one error each, '
      'and the next successful save includes all the failed changes.', () async {
    var persistor = FailingPersistor()..errorToThrow = const UserException('Could not save');
    var store = Store<int>(initialState: 0, persistor: persistor);

    for (var i = 1; i <= 3; i++) {
      await store.dispatchAndWait(SetAction(i));
      await pumpEventQueue();
    }

    expect(persistor.persistCalls, 3);
    expect(store.errors.length, 3);
    expect(store.getLastPersistedStateFromPersistor(), 0);

    persistor.errorToThrow = null;
    await store.dispatchAndWait(SetAction(4));
    await pumpEventQueue();

    expect(persistor.saved, [(0, 4)]);
    expect(store.getLastPersistedStateFromPersistor(), 4);
  });

  test('When a persistor UserException goes to the error queue, '
      'the store notifies its listeners (so that the UI can show it).', () async {
    var persistor = FailingPersistor()
      ..saveDuration = const Duration(milliseconds: 50)
      ..errorToThrow = const UserException('Could not save');
    var store = Store<int>(initialState: 0, persistor: persistor);

    await store.dispatchAndWait(SetAction(1));

    // The dispatch is over, but the save is still running.
    var changes = 0;
    var subscription = store.onChange.listen((_) => changes++);

    await Future.delayed(const Duration(milliseconds: 150));
    await subscription.cancel();

    expect(store.errors.single.message, 'Could not save');
    expect(changes, 1);
  });

  test('A persistor error that happens after the store teardown does not throw.', () async {
    var persistor = FailingPersistor()
      ..saveDuration = const Duration(milliseconds: 50)
      ..errorToThrow = const UserException('Could not save');
    var uncaught = <Object>[];

    await runZonedGuarded(() async {
      var store = Store<int>(initialState: 0, persistor: persistor);
      await store.dispatchAndWait(SetAction(1));
      await store.teardown();
      await Future.delayed(const Duration(milliseconds: 150));
    }, (error, stackTrace) => uncaught.add(error));

    expect(persistor.persistCalls, 1);
    expect(uncaught, isEmpty);
  });

  // ---------------------------------------------------------------------------------------------
  // Errors added with Persistor.addError.
  // ---------------------------------------------------------------------------------------------

  test('Persistor.getAndRemoveFirstError returns the added errors in order, '
      'removing them, and then returns null.', () {
    var persistor = FailingPersistor();
    expect(persistor.getAndRemoveFirstError(), isNull);

    var stackTrace = StackTrace.current;
    persistor.report('error 1', stackTrace);
    persistor.report('error 2');

    var first = persistor.getAndRemoveFirstError()!;
    expect(first.$1, 'error 1');
    expect(first.$2, same(stackTrace));

    var second = persistor.getAndRemoveFirstError()!;
    expect(second.$1, 'error 2');
    expect(second.$2, isNotNull); // Uses the current stack trace when not given.

    expect(persistor.getAndRemoveFirstError(), isNull);
  });

  test('All errors added before the store exists are processed in order.', () async {
    var persistor = FailingPersistor();
    persistor.report(const UserException('Error 1'));
    persistor.report(const UserException('Error 2'));
    persistor.report(const UserException('Error 3'));

    var store = Store<int>(initialState: 0, persistor: persistor);

    expect(store.errors.map((e) => e.message), ['Error 1', 'Error 2', 'Error 3']);
    expect(persistor.getAndRemoveFirstError(), isNull);
  });

  test('The GlobalErrorObserver gets the stack trace given to addError.', () async {
    var persistor = FailingPersistor();
    var stackTrace = StackTrace.current;
    persistor.report(StateError('bad format'), stackTrace);
    var stackTraces = <StackTrace>[];

    Store<int>(
      initialState: 0,
      persistor: persistor,
      globalErrorObserver: (store) =>
          RecordingObserver([], (error) => null, stackTraces: stackTraces),
    );

    expect(stackTraces.single, same(stackTrace));
  });

  test('A UserException with noDialog added by the persistor '
      'does NOT go to the error queue.', () async {
    var persistor = FailingPersistor();
    persistor.report(const UserException('Data was reset').noDialog);

    var store = Store<int>(initialState: 0, persistor: persistor);

    expect(store.errors, isEmpty);
  });

  test('When processing errors added before the store exists, '
      'the GlobalErrorObserver can already use the store configuration and dependencies.',
      () async {
    var persistor = FailingPersistor();
    persistor.report(StateError('bad format'));

    var store = Store<int>(
      initialState: 0,
      persistor: persistor,
      configuration: (store) => 'config',
      dependencies: (store) => 'deps',
      globalErrorObserver: (store) => ConfigObserver(),
    );

    expect(store.errors.single.message, 'config deps');
  });

  test('Errors added when deleting the state through the store '
      'go to the error queue right away.', () async {
    var persistor = FailingPersistor();
    var store = Store<int>(initialState: 0, persistor: persistor);

    persistor.errorToAddOnDelete = const UserException('Could not delete everything');
    await store.deleteStateFromPersistence();

    expect(store.errors.single.message, 'Could not delete everything');
  });

  test('Errors added when saving the initial state through the store '
      'go to the error queue right away.', () async {
    var persistor = FailingPersistor();
    var store = Store<int>(initialState: 0, persistor: persistor);

    persistor.errorToAddOnPersist = const UserException('Saved, but with a warning');
    await store.saveInitialStateInPersistence(5);

    expect(persistor.saved, [(null, 5)]);
    expect(store.errors.single.message, 'Saved, but with a warning');
  });

  test('If readState adds an error and then throws, through the store, '
      'the thrown error goes to the caller, and the added error is still processed.',
      () async {
    var persistor = FailingPersistor();
    var store = Store<int>(initialState: 0, persistor: persistor);

    persistor.errorToAddOnRead = const UserException('Data was reset');
    persistor.errorToThrowOnRead = StateError('cannot read');

    await expectLater(store.readStateFromPersistence(), throwsA(isA<StateError>()));
    expect(store.errors.single.message, 'Data was reset');
  });

  test('If persistDifference adds an error and then throws, both are processed.', () async {
    var persistor = FailingPersistor()
      ..errorToAddOnPersist = const UserException('Added error')
      ..errorToThrow = const UserException('Thrown error');
    var store = Store<int>(initialState: 0, persistor: persistor);

    await store.dispatchAndWait(SetAction(1));
    await pumpEventQueue();

    expect(
      store.errors.map((e) => e.message),
      unorderedEquals(['Added error', 'Thrown error']),
    );
  });

  test('Errors added after the store was created, outside of a persistence operation, '
      'are processed after the next persistence operation.', () async {
    var persistor = FailingPersistor();
    var store = Store<int>(initialState: 0, persistor: persistor);

    persistor.report(const UserException('Reported later'));
    expect(store.errors, isEmpty);

    await store.dispatchAndWait(SetAction(1));
    await pumpEventQueue();

    expect(store.errors.single.message, 'Reported later');
  });

  testWidgets('An error added by readState before the store exists '
      'is shown by the UserExceptionDialog.', (tester) async {
    var persistor = FailingPersistor()
      ..errorToAddOnRead = const UserException('Data was reset');

    await tester.runAsync(() => persistor.readState());
    var store = Store<int>(initialState: 0, persistor: persistor);

    var shown = <String?>[];
    await tester.pumpWidget(StoreProvider<int>(
      store: store,
      child: MaterialApp(
        home: UserExceptionDialog<int>(
          useLocalContext: true,
          onShowUserExceptionDialog: (context, exception, useLocalContext) =>
              shown.add(exception.message),
          child: const SizedBox(),
        ),
      ),
    ));
    await tester.pump();

    expect(shown, ['Data was reset']);
    expect(store.errors, isEmpty);
  });
}

class FailingPersistor extends Persistor<int> {
  Object? errorToThrow;

  /// If true, [errorToThrow] is cleared after being thrown once.
  bool throwOnce = false;

  /// If true, [persistDifference] throws synchronously (before returning a Future).
  bool throwSynchronously = false;

  /// How long each [persistDifference] takes, before succeeding or failing.
  Duration? saveDuration;

  /// The persistor throttle. The default is no throttle.
  Duration? throttleDuration;

  /// How many times [persistDifference] was called.
  int persistCalls = 0;

  /// Records (lastPersistedState, newState) for each successful persist.
  final saved = <(int?, int)>[];

  /// If set, [readState] adds this error with [addError].
  Object? errorToAddOnRead;

  /// If set, [readState] throws this error.
  Object? errorToThrowOnRead;

  /// If set, [persistDifference] adds this error with [addError] (and still succeeds).
  Object? errorToAddOnPersist;

  /// If set, [deleteState] adds this error with [addError].
  Object? errorToAddOnDelete;

  /// Adds an error, from outside of the persistor methods.
  void report(Object error, [StackTrace? stackTrace]) => addError(error, stackTrace);

  @override
  Future<int?> readState() async {
    if (errorToAddOnRead != null) {
      addError(errorToAddOnRead!);
      errorToAddOnRead = null;
    }
    if (errorToThrowOnRead != null) throw errorToThrowOnRead!;
    return null;
  }

  @override
  Future<void> deleteState() async {
    if (errorToAddOnDelete != null) {
      addError(errorToAddOnDelete!);
      errorToAddOnDelete = null;
    }
  }

  @override
  Future<void> persistDifference({
    required int? lastPersistedState,
    required int newState,
  }) {
    persistCalls++;
    if (throwSynchronously && errorToThrow != null) throw _getErrorToThrow();
    return _persistDifference(lastPersistedState, newState);
  }

  Future<void> _persistDifference(int? lastPersistedState, int newState) async {
    if (saveDuration != null) await Future.delayed(saveDuration!);
    if (errorToAddOnPersist != null) {
      addError(errorToAddOnPersist!);
      errorToAddOnPersist = null;
    }
    if (errorToThrow != null) throw _getErrorToThrow();
    saved.add((lastPersistedState, newState));
  }

  Object _getErrorToThrow() {
    var error = errorToThrow!;
    if (throwOnce) errorToThrow = null;
    return error;
  }

  @override
  Duration? get throttle => throttleDuration;

  /// If set, used by [wrapError].
  Object? Function(Object error)? wrapper;

  @override
  Object? wrapError(Object error, StackTrace stackTrace) =>
      (wrapper == null) ? error : wrapper!(error);
}

class RecordingObserver extends GlobalErrorObserver<int> {
  final List<(Object, Object, ReduxAction<int>?)> observed;
  final Object? Function(Object error) result;
  final List<StackTrace>? stackTraces;

  RecordingObserver(this.observed, this.result, {this.stackTraces});

  @override
  Object? observe() {
    observed.add((error, originalError, action));
    stackTraces?.add(stackTrace);
    return result(error);
  }
}

/// Converts errors into UserExceptions that contain the store configuration
/// and dependencies, to check they are available to the observer.
class ConfigObserver extends GlobalErrorObserver<int> {
  @override
  // ignore: async_redux_lints/user_exception_without_cause
  Object? observe() => UserException('${store.configuration} ${store.dependencies}');
}

class SetAction extends ReduxAction<int> {
  final int value;

  SetAction(this.value);

  @override
  int reduce() => value;
}
