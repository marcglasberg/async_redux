import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/error_contract_support.dart';

void main() {
  for (final cloud in [false, true]) {
    for (final throwsSynchronously in [false, true]) {
      for (final source in [
        ErrorKind.error,
        ErrorKind.user,
        ErrorKind.noDialog,
        ErrorKind.abort,
      ]) {
        for (final (localKind, localThrows) in errorRules) {
          for (final (globalKind, globalThrows) in errorRules) {
            test('cloud=$cloud / syncThrow=$throwsSynchronously / $source / '
                'persistor=$localKind,throw=$localThrows / '
                'global=$globalKind,throw=$globalThrows', () {
              fakeAsync((async) {
                final original = errorValue(source, 'persistor original');
                final local = ErrorRule(localKind, localThrows, 'persistor replacement');
                final global = ErrorRule(globalKind, globalThrows, 'global replacement');
                final intermediate = local.expected(original);
                _checkPersistence(
                  async,
                  cloud,
                  throwsSynchronously,
                  original,
                  local.apply,
                  global.apply,
                  intermediate,
                  intermediate == null ? null : global.expected(intermediate),
                );
              });
            });
          }
        }
      }
    }
  }

  for (final kind in ErrorKind.values) {
    for (final cloud in [false, true]) {
      for (final layer in ['source', 'persistor', 'global']) {
        test('arbitrary $kind in $layer / cloud=$cloud', () {
          fakeAsync((async) {
            final value = errorValue(kind, 'arbitrary value');
            final original = layer == 'source' ? value : StateError('original');
            final intermediate = layer == 'persistor' ? value : original;
            _checkPersistence(
              async,
              cloud,
              false,
              original,
              (_) => intermediate,
              (_) => value,
              intermediate,
              value,
            );
          });
        });
      }
    }
  }

  for (final cloud in [false, true]) {
    for (final beforeConstruction in [false, true]) {
      for (final kind in ErrorKind.values) {
        test('added error $kind / cloud=$cloud / before store=$beforeConstruction', () {
          fakeAsync((async) {
            final original = errorValue(kind, 'added');
            final persistor = _FailingPersistor(original, false)..fail = false;
            final seen = <ObservedError>[];
            final uncaught = <(Object, StackTrace)>[];
            late Store<int> store;
            runZonedGuarded(() {
              if (beforeConstruction) persistor.queueError();
              store = Store<int>(
                initialState: 0,
                persistor: cloud ? null : persistor,
                cloudSync: cloud ? persistor : null,
                globalErrorObserver: (_) => ProbeGlobalObserver(seen, (error) => error),
              );
              if (!beforeConstruction) {
                persistor.queueError();
                store.dispatchSync(SyncErrorProbe());
              }
              async.flushMicrotasks();
              async.elapse(Duration.zero);
            }, (error, stack) => uncaught.add((error, stack)));
            expect(seen, hasLength(1));
            expect(seen.single.error, same(original));
            expect(seen.single.original, same(original));
            expect(seen.single.action, isNull);
            expect(seen.single.stack.toString(), persistor.trace.toString());
            expect(persistor.localInputs, isEmpty);
            expect(store.errors, opensDialog(original) ? [same(original)] : isEmpty);
            // Unlike an action abort, a persistence abort is an unhandled error.
            expect(uncaught, hasLength(original is UserException ? 0 : 1));
            if (uncaught.isNotEmpty) expect(uncaught.single.$1, same(original));
            store.teardown();
            async.flushMicrotasks();
          });
        });
      }
    }
  }

  for (final cloud in [false, true]) {
    for (final kind in [ErrorKind.user, ErrorKind.abort, ErrorKind.error]) {
      test('persistence global factory throws $kind / cloud=$cloud', () {
        fakeAsync((async) {
          final original = StateError('persistor');
          final factoryError = errorValue(kind, 'factory');
          final persistor = _FailingPersistor(original, false);
          final uncaught = <Object>[];
          final action = SyncErrorProbe();
          late Store<int> store;
          runZonedGuarded(() {
            store = Store<int>(
              initialState: 0,
              persistor: cloud ? null : persistor,
              cloudSync: cloud ? persistor : null,
              globalErrorObserver: (_) => throw factoryError,
            );
            store.dispatchSync(action);
            async.flushMicrotasks();
          }, (error, stack) => uncaught.add(error));
          expect(uncaught, [same(factoryError)]);
          expect(store.errors, isEmpty);
          expect(action.status.isCompletedOk, isTrue);
          expect(action.localInputs, isEmpty);
          expect(store.state, 1);
          expect(store.getLastPersistedStateFromPersistor(), cloud ? isNull : 0);
          expect(store.getLastPersistedStateFromCloudSync(), cloud ? 0 : isNull);
          store.teardown();
          async.flushMicrotasks();
        });
      });
    }
  }

  test('local and cloud failures are independent and neither fails the action', () {
    fakeAsync((async) {
      final localError = StateError('disk');
      final cloudError = StateError('network');
      final local = _FailingPersistor(localError, true);
      final cloud = _FailingPersistor(cloudError, false);
      final seen = <ObservedError>[];
      const localUser = UserException('disk dialog');
      final cloudUser = const UserException('network inline').noDialog;
      final action = SyncErrorProbe();
      final store = Store<int>(
        initialState: 0,
        persistor: local,
        cloudSync: cloud,
        globalErrorObserver: (_) => ProbeGlobalObserver(
          seen,
          (error) => identical(error, localError) ? localUser : cloudUser,
        ),
      );
      final result = dispatchCapturing(store, action, async);
      expect(result.error, isNull);
      expect(result.status!.isCompletedOk, isTrue);
      expect(seen.map((e) => e.original), unorderedEquals([localError, cloudError]));
      expect(seen.every((e) => e.action == null), isTrue);
      expect(store.errors, [same(localUser)]);
      expect(store.isFailed(action.runtimeType), isFalse);
      expect(store.getLastPersistedStateFromPersistor(), 0);
      expect(store.getLastPersistedStateFromCloudSync(), 0);
      expect(action.localInputs, isEmpty);
      store.teardown();
      async.flushMicrotasks();
    });
  });
}

void _checkPersistence(
  FakeAsync async,
  bool cloud,
  bool throwsSynchronously,
  Object original,
  Object? Function(Object) local,
  Object? Function(Object) global,
  Object? expectedLocal,
  Object? expectedFinal,
) {
  final persistor = _FailingPersistor(original, throwsSynchronously)..transform = local;
  final seen = <ObservedError>[];
  final uncaught = <(Object, StackTrace)>[];
  final action = SyncErrorProbe();
  late Store<int> store;
  runZonedGuarded(() {
    store = Store<int>(
      initialState: 0,
      persistor: cloud ? null : persistor,
      cloudSync: cloud ? persistor : null,
      globalErrorObserver: (_) => ProbeGlobalObserver(seen, global),
    );
    store.dispatchSync(action);
    async.flushMicrotasks();
  }, (error, stack) => uncaught.add((error, stack)));
  final rethrown = expectedFinal != null && expectedFinal is! UserException;
  expect(uncaught, hasLength(rethrown ? 1 : 0));
  if (rethrown) {
    expect(uncaught.single.$1, same(expectedFinal));
    expect(uncaught.single.$2.toString(), persistor.trace.toString());
  }
  expect(persistor.localInputs, [same(original)]);
  expect(seen, hasLength(expectedLocal == null ? 0 : 1));
  if (seen.isNotEmpty) {
    expect(seen.single.error, same(expectedLocal));
    expect(seen.single.original, same(original));
    expect(seen.single.action, isNull);
    expect(seen.single.store, same(store));
    expect(seen.single.stack.toString(), persistor.trace.toString());
  }
  expect(action.status.isCompletedOk, isTrue);
  expect(action.status.originalError, isNull);
  expect(action.localInputs, isEmpty);
  expect(action.afterStatuses, hasLength(1));
  expect(store.state, 1);
  expect(store.isFailed(action.runtimeType), isFalse);
  expect(store.errors, opensDialog(expectedFinal) ? [same(expectedFinal)] : isEmpty);
  expect(
    cloud
        ? store.getLastPersistedStateFromCloudSync()
        : store.getLastPersistedStateFromPersistor(),
    0,
  );
  expect(store.actionsInProgress(), isEmpty);
  // Swallowing a save error must not falsely mark the state as persisted.
  // The next successful save still starts from the old persisted state.
  persistor.fail = false;
  store.dispatchSync(SyncErrorProbe());
  async.flushMicrotasks();
  expect(persistor.saved, [(0, 2)]);
  expect(
    cloud
        ? store.getLastPersistedStateFromCloudSync()
        : store.getLastPersistedStateFromPersistor(),
    2,
  );
  store.teardown();
  async.flushMicrotasks();
}

class _FailingPersistor extends Persistor<int> {
  _FailingPersistor(this.error, this.throwsSynchronously);
  final Object error;
  final bool throwsSynchronously;
  final trace = StackTrace.fromString('persistence original stack');
  final localInputs = <Object>[];
  final saved = <(int?, int)>[];
  Object? Function(Object)? transform;
  bool fail = true;
  @override
  Duration? get throttle => null;
  void queueError() => addError(error, trace);
  @override
  Future<void> persistDifference({
    required int? lastPersistedState,
    required int newState,
  }) {
    if (!fail) {
      saved.add((lastPersistedState, newState));
      return Future<void>.value();
    }
    if (throwsSynchronously) Error.throwWithStackTrace(error, trace);
    return Future<void>.error(error, trace);
  }

  @override
  Object? wrapError(Object error, StackTrace stackTrace) {
    localInputs.add(error);
    return transform == null ? error : transform!(error);
  }

  @override
  Future<int?> readState() async => null;
  @override
  Future<void> deleteState() async {}
}
