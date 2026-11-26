import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all persistence methods accept an absent destination', () async {
    final store = Store<int>(initialState: 7);
    addTearDown(store.teardown);

    for (final destination in _Destination.values) {
      destination.pause(store);
      destination.pause(store);
      destination.persistAndPause(store);
      destination.resume(store);
      await destination.save(store, 10);
      expect(await destination.read(store), isNull);
      await destination.delete(store);
      expect(destination.last(store), isNull);
    }
    expect(store.state, 7);
    expect(store.dispatchCount, 0);
    expect(store.reduceCount, 0);
  });

  for (final destination in _Destination.values) {
    group('$destination', () {
      test('an absent destination never falls back to the other persistor', () async {
        final other = _ControlledPersistor(0);
        final store = Store<int>(
          initialState: 0,
          persistor: destination == _Destination.cloud ? other : null,
          cloudSync: destination == _Destination.local ? other : null,
        );
        addTearDown(store.teardown);
        destination.pause(store);
        destination.persistAndPause(store);
        destination.resume(store);
        await destination.save(store, 9);
        expect(await destination.read(store), isNull);
        await destination.delete(store);
        expect(destination.last(store), isNull);
        expect(other.calls, isEmpty);

        store.dispatchSync(_SetState(1));
        expect(other.calls.single.next, 1);
        other.calls.single.complete();
        await pumpEventQueue();
        expect(other.stored, 1);
      });

      test(
        'explicit operations work while paused without resuming automatic saves',
        () async {
          final persistor = _ControlledPersistor(0);
          final store = destination.store(persistor);
          addTearDown(store.teardown);
          destination.pause(store);
          for (final operation in ['read', 'save', 'delete']) {
            final pending = destination.operation(store, operation);
            expect(persistor.calls.last.kind, operation);
            persistor.calls.last.complete();
            await pending;
          }
          store.dispatchSync(_SetState(1));
          await pumpEventQueue();
          expect(persistor.calls, hasLength(3));
          destination.resume(store);
          expect(persistor.calls, hasLength(4));
          expect(persistor.calls.last.previous, isNull);
          expect(persistor.calls.last.next, 1);
          persistor.calls.last.complete();
          await pumpEventQueue();
          expect(destination.last(store), 1);
        },
      );

      test('read, save and delete affect only the selected destination', () async {
        final local = _ControlledPersistor(10);
        final cloud = _ControlledPersistor(20);
        final store = Store<int>(initialState: 0, persistor: local, cloudSync: cloud);
        addTearDown(store.teardown);
        final selected = destination == _Destination.local ? local : cloud;
        final other = destination == _Destination.local ? cloud : local;
        final changes = <int>[];
        final subscription = store.onChange.listen(changes.add);
        addTearDown(subscription.cancel);
        final timestamp = store.stateTimestamp;

        final reading = destination.read(store);
        selected.calls.single.complete();
        expect(await reading, destination == _Destination.local ? 10 : 20);
        expect(destination.last(store), selected.stored);

        final saving = destination.save(store, 30);
        expect(selected.calls.last.kind, 'save');
        expect(selected.calls.last.next, 30);
        selected.calls.last.complete();
        await saving;
        expect(destination.last(store), 30);
        expect(selected.stored, 30);

        final deleting = destination.delete(store);
        expect(selected.calls.last.kind, 'delete');
        selected.calls.last.complete();
        await deleting;
        expect(destination.last(store), isNull);
        expect(selected.stored, isNull);
        expect(other.calls, isEmpty);
        expect(store.state, 0);
        expect(store.stateTimestamp, timestamp);
        expect(changes, isEmpty);
        expect(store.dispatchCount, 0);
      });

      test('a missing saved state replaces the remembered persistence state', () async {
        final persistor = _ControlledPersistor(null);
        final store = destination.store(persistor);
        addTearDown(store.teardown);
        expect(destination.last(store), 0);

        final reading = destination.read(store);
        persistor.calls.single.complete();
        expect(await reading, isNull);
        expect(destination.last(store), isNull);

        store.dispatchSync(_SetState(1));
        expect(persistor.calls.last.previous, isNull);
        persistor.calls.last.complete();
        await pumpEventQueue();
        expect(destination.last(store), 1);
      });

      test(
        'pause preserves an active save and resume saves only the latest state',
        () async {
          final persistor = _ControlledPersistor(0);
          final store = destination.store(persistor);
          addTearDown(store.teardown);
          destination.resume(store);
          destination.pause(store);
          destination.pause(store);
          destination.resume(store);
          expect(persistor.calls, isEmpty);

          store.dispatchSync(_SetState(1));
          destination.pause(store);
          store.dispatchSync(_SetState(2));
          store.dispatchSync(_SetState(3));
          expect(persistor.calls, hasLength(1));
          expect(destination.last(store), 0);
          persistor.calls.single.complete();
          await pumpEventQueue();
          expect(destination.last(store), 1);
          expect(persistor.calls, hasLength(1));

          destination.resume(store);
          destination.resume(store);
          expect(persistor.calls, hasLength(2));
          expect(persistor.calls.last.previous, 1);
          expect(persistor.calls.last.next, 3);
          persistor.calls.last.complete();
          await pumpEventQueue();
          expect(destination.last(store), 3);
          expect(persistor.maxActive, 1);
          destination.pause(store);
          destination.resume(store);
          expect(persistor.calls, hasLength(2));
        },
      );

      test(
        'persist-and-pause bypasses throttle and snapshots the requested state',
        () async {
          final persistor = _ControlledPersistor(0, delay: const Duration(days: 1));
          final store = destination.store(persistor);
          addTearDown(store.teardown);
          destination.persistAndPause(store);
          destination.resume(store);
          expect(persistor.calls, isEmpty);

          store.dispatchSync(_SetState(1));
          expect(persistor.calls, isEmpty);
          destination.persistAndPause(store);
          expect(persistor.calls.single.next, 1);
          store.dispatchSync(_SetState(2));
          destination.persistAndPause(store);
          store.dispatchSync(_SetState(3));
          persistor.calls.single.complete();
          await pumpEventQueue();
          expect(persistor.calls, hasLength(2));
          expect(persistor.calls.last.previous, 1);
          expect(persistor.calls.last.next, 2);
          persistor.calls.last.complete();
          await pumpEventQueue();
          expect(destination.last(store), 2);
          expect(persistor.calls, hasLength(2));

          // An explicit flush of the paused destination saves the later state too.
          destination.persistAndPause(store);
          expect(persistor.calls.last.next, 3);
          persistor.calls.last.complete();
          await pumpEventQueue();
          destination.persistAndPause(store);
          expect(persistor.calls, hasLength(3));
          expect(destination.last(store), 3);
          expect(persistor.maxActive, 1);
        },
      );

      for (final operation in ['read', 'save', 'delete']) {
        test('$operation waits for an active save and blocks subsequent saves', () async {
          final persistor = _ControlledPersistor(0);
          final store = destination.store(persistor);
          addTearDown(store.teardown);
          store.dispatchSync(_SetState(1));
          final pending = destination.operation(store, operation);
          expect(persistor.calls, hasLength(1));
          persistor.calls.single.complete();
          await pumpEventQueue();
          expect(persistor.calls, hasLength(2));
          expect(persistor.calls.last.kind, operation);
          store.dispatchSync(_SetState(2));
          expect(persistor.calls, hasLength(2));
          persistor.calls.last.complete();
          final result = await pending;
          if (operation == 'read') expect(result, 1);
          expect(persistor.calls, hasLength(3));
          expect(persistor.calls.last.kind, 'difference');
          expect(
            persistor.calls.last.previous,
            operation == 'read'
                ? 1
                : operation == 'save'
                ? 9
                : null,
          );
          expect(persistor.calls.last.next, 2);
          persistor.calls.last.complete();
          await pumpEventQueue();
          expect(destination.last(store), 2);
          expect(persistor.stored, 2);
          expect(persistor.maxActive, 1);
        });

        for (final synchronous in [false, true]) {
          test('$operation propagates ${synchronous ? 'sync' : 'async'} errors '
              'and releases the operation lock', () async {
            final persistor = _ControlledPersistor(0);
            final store = destination.store(persistor);
            addTearDown(store.teardown);
            final error = StateError('failed $operation');
            if (synchronous) persistor.synchronousError = error;
            final pending = destination.operation(store, operation);
            final assertion = expectLater(pending, throwsA(same(error)));
            if (!synchronous) persistor.calls.single.fail(error);
            await assertion;
            persistor.synchronousError = null;
            expect(store.errors, isEmpty);
            expect(persistor.wrapCalls, 0);

            final recovery = destination.save(store, 5);
            persistor.calls.last.complete();
            await recovery;
            expect(destination.last(store), 5);
            store.dispatchSync(_SetState(6));
            expect(persistor.calls.last.previous, 5);
            persistor.calls.last.complete();
            await pumpEventQueue();
            expect(destination.last(store), 6);
            expect(persistor.maxActive, 1);
          });
        }
      }

      test('explicit operations serialize with one another', () async {
        final persistor = _ControlledPersistor(0);
        final store = destination.store(persistor);
        addTearDown(store.teardown);
        final saving = destination.save(store, 9);
        final reading = destination.read(store);
        final deleting = destination.delete(store);
        expect(persistor.calls.map((call) => call.kind), ['save']);
        persistor.calls.single.complete();
        await saving;
        await pumpEventQueue();
        expect(persistor.calls.map((call) => call.kind), ['save', 'read']);
        persistor.calls.last.complete();
        expect(await reading, 9);
        await pumpEventQueue();
        expect(persistor.calls.map((call) => call.kind), ['save', 'read', 'delete']);
        persistor.calls.last.complete();
        await deleting;
        expect(destination.last(store), isNull);
        expect(persistor.maxActive, 1);
      });
    });
  }

  test('a busy local persistor does not block explicit cloud operations', () async {
    final local = _ControlledPersistor(0);
    final cloud = _ControlledPersistor(0);
    final store = Store<int>(initialState: 0, persistor: local, cloudSync: cloud);
    addTearDown(store.teardown);
    final localSave = store.saveInitialStateInPersistence(1);
    final cloudSave = store.saveInitialStateInCloud(2);
    expect(local.active, 1);
    expect(cloud.active, 1);
    cloud.calls.single.complete();
    await cloudSave;
    expect(cloud.stored, 2);
    expect(local.stored, 0);
    local.calls.single.complete();
    await localSave;
    expect(local.stored, 1);
  });

  test(
    'teardown drains queued events before done and preserves state by default',
    () async {
      final store = Store<int>(initialState: 0);
      final events = <Object>[];
      final subscription = store.onChange.listen(
        events.add,
        onDone: () => events.add('done'),
      );
      addTearDown(subscription.cancel);
      store.dispatchSync(_SetState(1));
      await store.teardown();
      expect(events, [1, 'done']);
      await subscription.cancel();
      expect(store.state, 1);
      expect(store.stateTimestamp.isUtc, isTrue);
      await store.teardown();
      expect(events, [1, 'done']);
    },
  );

  test('teardown waits for a paused subscriber to consume the done event', () async {
    final store = Store<int>(initialState: 0);
    final events = <Object>[];
    final subscription = store.onChange.listen(
      events.add,
      onDone: () => events.add('done'),
    );
    subscription.pause();
    var finished = false;
    final closing = store.teardown(emptyState: 7).then((_) => finished = true);
    await pumpEventQueue();
    expect(store.state, 7);
    expect(events, isEmpty);
    expect(finished, isFalse);
    subscription.resume();
    await closing;
    expect(events, ['done']);
    expect(finished, isTrue);
    await subscription.cancel();
  });

  test('teardown supports nullable state and late stream subscribers', () async {
    final store = Store<int?>(initialState: null);
    await store.teardown();
    expect(store.state, isNull);
    expect(await store.onChange.toList(), isEmpty);
  });
}

enum _Destination {
  local,
  cloud;

  Store<int> store(Persistor<int> persistor) => Store<int>(
    initialState: 0,
    persistor: this == local ? persistor : null,
    cloudSync: this == cloud ? persistor : null,
  );

  void pause(Store<int> store) =>
      this == local ? store.pausePersistor() : store.pauseCloudSync();

  void resume(Store<int> store) =>
      this == local ? store.resumePersistor() : store.resumeCloudSync();

  void persistAndPause(Store<int> store) =>
      this == local ? store.persistAndPausePersistor() : store.persistAndPauseCloudSync();

  Future<void> save(Store<int> store, int state) => this == local
      ? store.saveInitialStateInPersistence(state)
      : store.saveInitialStateInCloud(state);

  Future<int?> read(Store<int> store) =>
      this == local ? store.readStateFromPersistence() : store.readStateFromCloudSync();

  Future<void> delete(Store<int> store) =>
      this == local ? store.deleteStateFromPersistence() : store.deleteStateFromCloud();

  int? last(Store<int> store) => this == local
      ? store.getLastPersistedStateFromPersistor()
      : store.getLastPersistedStateFromCloudSync();

  Future<Object?> operation(Store<int> store, String operation) async {
    switch (operation) {
      case 'read':
        return await read(store);
      case 'save':
        await save(store, 9);
      case 'delete':
        await delete(store);
    }
    return null;
  }
}

class _ControlledPersistor extends Persistor<int> {
  _ControlledPersistor(this.stored, {this.delay});

  int? stored;
  final Duration? delay;
  final calls = <_Call>[];
  Object? synchronousError;
  int active = 0;
  int maxActive = 0;
  int wrapCalls = 0;

  @override
  Duration? get throttle => delay;

  Future<void> _start(String kind, {int? previous, int? next}) {
    if (synchronousError != null) throw synchronousError!;
    final call = _Call(kind, previous, next);
    calls.add(call);
    active++;
    if (active > maxActive) maxActive = active;
    return call.completer.future.whenComplete(() => active--);
  }

  @override
  Future<int?> readState() {
    final future = _start('read');
    return future.then((_) => stored);
  }

  @override
  Future<void> saveInitialState(int state) {
    final future = _start('save', next: state);
    return future.then((_) => stored = state);
  }

  @override
  Future<void> deleteState() {
    final future = _start('delete');
    return future.then((_) => stored = null);
  }

  @override
  Future<void> persistDifference({
    required int? lastPersistedState,
    required int newState,
  }) {
    final future = _start('difference', previous: lastPersistedState, next: newState);
    return future.then((_) => stored = newState);
  }

  @override
  Object? wrapError(Object error, StackTrace stackTrace) {
    wrapCalls++;
    return error;
  }
}

class _Call {
  _Call(this.kind, this.previous, this.next);

  final String kind;
  final int? previous;
  final int? next;
  final completer = Completer<void>();

  void complete() => completer.complete();

  void fail(Object error) => completer.completeError(error);
}

class _SetState extends ReduxAction<int> {
  _SetState(this.value);

  final int value;

  @override
  int reduce() => value;
}
