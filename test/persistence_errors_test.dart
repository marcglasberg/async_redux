import 'dart:async';

import "package:async_redux/async_redux.dart";
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
}

class FailingPersistor extends Persistor<int> {
  Object? errorToThrow;

  /// Records (lastPersistedState, newState) for each successful persist.
  final saved = <(int?, int)>[];

  @override
  Future<int?> readState() async => null;

  @override
  Future<void> deleteState() async {}

  @override
  Future<void> persistDifference({
    required int? lastPersistedState,
    required int newState,
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
    saved.add((lastPersistedState, newState));
  }

  @override
  Duration? get throttle => null;

  /// If set, used by [wrapError].
  Object? Function(Object error)? wrapper;

  @override
  Object? wrapError(Object error, StackTrace stackTrace) =>
      (wrapper == null) ? error : wrapper!(error);
}

class RecordingObserver extends GlobalErrorObserver<int> {
  final List<(Object, Object, ReduxAction<int>?)> observed;
  final Object? Function(Object error) result;

  RecordingObserver(this.observed, this.result);

  @override
  Object? observe() {
    observed.add((error, originalError, action));
    return result(error);
  }
}

class SetAction extends ReduxAction<int> {
  final int value;

  SetAction(this.value);

  @override
  int reduce() => value;
}
