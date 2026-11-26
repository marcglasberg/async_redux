import 'package:async_redux/async_redux.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/waiting_failed_support.dart';

void main() {
  test('action helpers query and clear the same registries as the store', () {
    fakeAsync((async) {
      final store = Store<int>(initialState: 0);
      final errorA = const UserException('a').noDialog;
      final errorB = const UserException('b').noDialog;
      _fail(store, SyncTrackingAction<int>(key: 'a', error: errorA));
      _fail(store, SyncTrackingAction<int>(key: 'b', error: errorB));
      final pending = TrackingAction<String>(key: 'pending');
      trackDispatch(store, pending);
      store.dispatchSync(_TrackingClient(pending, errorA, errorB, store));
      expect(store.actionsInProgress(), [same(pending)]);
      pending.release();
      async.flushMicrotasks();
      expect(store.actionsInProgress(), isEmpty);
      store.teardown();
      async.flushMicrotasks();
    });
  });

  for (final firstOutcome in _Outcome.values) {
    for (final secondOutcome in _Outcome.values) {
      for (final sameKey in [false, true]) {
        for (final watched in [false, true]) {
          test('failure replacement $firstOutcome -> $secondOutcome / '
              'same key=$sameKey / observed before failure=$watched', () {
            fakeAsync((async) {
              final store = Store<int>(initialState: 0);
              if (watched) {
                expect(store.isFailed(TrackingAction<int>), isFalse);
                expect(store.exceptionFor(TrackingAction<int>), isNull);
              }
              final (first, firstError) = _action(firstOutcome, 'a', 'first');
              final firstResult = trackDispatch(store, first);
              first.release();
              async.flushMicrotasks();
              _expectOutcome(store, first, firstError, firstResult);
              final (second, secondError) = _action(
                secondOutcome,
                sameKey ? 'a' : 'b',
                'next',
              );
              final secondResult = trackDispatch(store, second);
              // Clearing happens at dispatch, before before()/reduce() finish,
              // including when nobody subscribed to isFailed beforehand.
              expect(store.isFailed(TrackingAction<int>, statusKey: second.key), isFalse);
              expect(
                store.exceptionFor(TrackingAction<int>, statusKey: second.key),
                isNull,
              );
              expect(
                store.isFailed(TrackingAction<int>, statusKey: 'a'),
                !sameKey && _recorded(firstError),
              );
              expect(store.isWaiting(second), isTrue);
              second.release();
              async.flushMicrotasks();
              _expectOutcome(store, second, secondError, secondResult);
              if (!sameKey) {
                expect(
                  store.isFailed(TrackingAction<int>, statusKey: 'a'),
                  _recorded(firstError),
                );
                expect(
                  store.exceptionFor(TrackingAction<int>, statusKey: 'a'),
                  firstError is UserException ? same(firstError) : isNull,
                );
              }
              final expectedLatestUser = secondError is UserException
                  ? secondError
                  : !sameKey && firstError is UserException
                  ? firstError
                  : null;
              expect(store.exceptionFor(TrackingAction<int>), same(expectedLatestUser));
              expect(
                store.isFailed(TrackingAction<int>),
                _recorded(secondError) || (!sameKey && _recorded(firstError)),
              );
              expect(store.actionsInProgress(), isEmpty);
              store.teardown();
              async.flushMicrotasks();
            });
          });
        }
      }
    }
  }

  test(
    'exceptionFor selects latest UserException by completion, then by iterable order',
    () {
      fakeAsync((async) {
        final store = Store<int>(initialState: 0);
        final older = const UserException('older').noDialog;
        final newer = const UserException('newer').noDialog;
        final otherType = const UserException('other type').noDialog;
        _fail(store, SyncTrackingAction<int>(key: 'old', error: older));
        _fail(store, SyncTrackingAction<int>(key: 'new', error: newer));
        _fail(
          store,
          SyncTrackingAction<int>(key: 'ordinary', error: StateError('latest')),
        );
        _fail(store, SyncTrackingAction<String>(key: 'other', error: otherType));
        expect(store.isFailed(SyncTrackingAction<int>, statusKey: 'ordinary'), isTrue);
        expect(
          store.exceptionFor(SyncTrackingAction<int>, statusKey: 'ordinary'),
          isNull,
        );
        expect(store.exceptionFor(SyncTrackingAction<int>), same(newer));
        expect(
          store.exceptionFor([SyncTrackingAction<int>, SyncTrackingAction<String>]),
          same(newer),
        );
        expect(
          store.exceptionFor([SyncTrackingAction<String>, SyncTrackingAction<int>]),
          same(otherType),
        );
        expect(
          store.exceptionFor([
            SyncTrackingAction<String>,
            SyncTrackingAction<int>,
          ], statusKey: 'old'),
          same(older),
        );
        store.clearExceptionFor(SyncTrackingAction<int>, statusKey: 'new');
        expect(store.exceptionFor(SyncTrackingAction<int>), same(older));
        store.clearExceptionFor(SyncTrackingAction<int>, statusKey: 'old');
        expect(store.isFailed(SyncTrackingAction<int>), isTrue);
        expect(store.exceptionFor(SyncTrackingAction<int>), isNull);
        expect(
          store.exceptionFor([SyncTrackingAction<int>, SyncTrackingAction<String>]),
          same(otherType),
        );
        store.clearExceptionFor(SyncTrackingAction<int>, statusKey: 'ordinary');
        expect(store.isFailed(SyncTrackingAction<int>), isFalse);
        store.teardown();
        async.flushMicrotasks();
      });
    },
  );

  test('a null key is a wildcard when querying/clearing, but exact when dispatching', () {
    final store = Store<int>(initialState: 0);
    final a = const UserException('a').noDialog;
    final b = const UserException('b').noDialog;
    final unkeyed = const UserException('null key').noDialog;
    _fail(store, SyncTrackingAction<int>(key: 'a', error: a));
    _fail(store, SyncTrackingAction<int>(key: 'b', error: b));
    _fail(store, SyncTrackingAction<int>(error: unkeyed));
    expect(store.exceptionFor(SyncTrackingAction<int>, statusKey: null), same(unkeyed));
    store.dispatchSync(SyncTrackingAction<int>());
    expect(store.exceptionFor(SyncTrackingAction<int>), same(b));
    expect(store.isFailed(SyncTrackingAction<int>, statusKey: 'a'), isTrue);
    expect(store.isFailed(SyncTrackingAction<int>, statusKey: 'b'), isTrue);
    store.clearExceptionFor(SyncTrackingAction<int>, statusKey: null);
    expect(store.isFailed(SyncTrackingAction<int>), isFalse);
    expect(store.exceptionFor(SyncTrackingAction<int>, statusKey: 'a'), isNull);
    expect(store.exceptionFor(SyncTrackingAction<int>, statusKey: 'b'), isNull);
    store.teardown();
  });

  test('equal keys replace one entry, colliding unequal keys and identity keys stay separate', () {
    final store = Store<int>(initialState: 0);
    final first = const UserException('first').noDialog;
    final replacement = const UserException('replacement').noDialog;
    final separate = const UserException('separate').noDialog;
    _fail(store, SyncTrackingAction<int>(key: const TrackingKey('a'), error: first));
    _fail(store, SyncTrackingAction<int>(key: const TrackingKey('b'), error: separate));
    _fail(
      store,
      SyncTrackingAction<int>(key: const TrackingKey('a'), error: replacement),
    );
    expect(store.exceptionFor(SyncTrackingAction<int>), same(replacement));
    expect(
      store.exceptionFor(SyncTrackingAction<int>, statusKey: const TrackingKey('b')),
      same(separate),
    );
    store.clearExceptionFor(SyncTrackingAction<int>, statusKey: const TrackingKey('a'));
    expect(store.exceptionFor(SyncTrackingAction<int>), same(separate));
    // Removing the key must not reveal the older, replaced error.
    expect(
      store.exceptionFor(SyncTrackingAction<int>, statusKey: const TrackingKey('a')),
      isNull,
    );
    final listKey = <int>[1];
    _fail(store, SyncTrackingAction<int>(key: listKey, error: first));
    expect(store.isFailed(SyncTrackingAction<int>, statusKey: <int>[1]), isFalse);
    expect(store.exceptionFor(SyncTrackingAction<int>, statusKey: listKey), same(first));
    store.clearExceptionFor(SyncTrackingAction<int>, statusKey: <int>[1]);
    expect(store.isFailed(SyncTrackingAction<int>, statusKey: listKey), isTrue);
    store.clearExceptionFor(SyncTrackingAction<int>, statusKey: listKey);
    expect(store.isFailed(SyncTrackingAction<int>, statusKey: listKey), isFalse);
    store.teardown();
  });

  for (final method in ['type', 'iterable', 'all', 'mixins', 'shutdown']) {
    test('clearing via $method removes failures but leaves the dialog queue intact', () {
      fakeAsync((async) {
        final store = Store<int>(initialState: 0, syncStream: true);
        const a = UserException('a');
        const b = UserException('b');
        _fail(store, SyncTrackingAction<int>(key: 'a', error: a));
        _fail(store, SyncTrackingAction<String>(key: 'b', error: b));
        final pending = TrackingAction<double>();
        trackDispatch(store, pending);
        async.flushMicrotasks();
        final notifications = <int>[];
        final subscription = store.onChange.listen(notifications.add);
        void clear() {
          switch (method) {
            case 'type':
              store.clearExceptionFor(SyncTrackingAction<int>);
              store.clearExceptionFor(SyncTrackingAction<String>);
            case 'iterable':
              store.clearExceptionFor([
                SyncTrackingAction<int>,
                SyncTrackingAction<String>,
                SyncTrackingAction<int>,
              ]);
            case 'all':
              store.clearAllExceptions();
            case 'mixins':
              store.internalMixinProps.clear();
            case 'shutdown':
              store.shutdown();
          }
        }

        clear();
        expect(notifications, hasLength(method == 'type' ? 2 : 1));
        clear();
        expect(notifications, hasLength(method == 'type' ? 2 : 1));
        expect(
          store.isFailed([SyncTrackingAction<int>, SyncTrackingAction<String>]),
          isFalse,
        );
        expect(
          store.exceptionFor([SyncTrackingAction<int>, SyncTrackingAction<String>]),
          isNull,
        );
        expect(store.errors, [same(a), same(b)]);
        expect(store.isWaiting(pending), isTrue);
        pending.release();
        async.flushMicrotasks();
        expect(store.actionsInProgress(), isEmpty);
        subscription.cancel();
        store.teardown();
        async.flushMicrotasks();
      });
    });
  }

  test('removing queued dialogs does not clear failures, and clearing failures does not remove dialogs', () {
    final store = Store<int>(initialState: 0);
    final a = SyncTrackingAction<int>(key: 'a', error: const UserException('a'));
    final b = SyncTrackingAction<int>(key: 'b', error: const UserException('b'));
    _fail(store, a);
    _fail(store, b);
    expect(store.getAndRemoveFirstError(), same(a.error));
    expect(store.isFailed(SyncTrackingAction<int>, statusKey: 'a'), isTrue);
    expect(store.exceptionFor(SyncTrackingAction<int>, statusKey: 'a'), same(a.error));
    store.removeError(b);
    expect(store.errors, isEmpty);
    expect(store.isFailed(SyncTrackingAction<int>, statusKey: 'b'), isTrue);
    store.clearAllExceptions();
    expect(store.isFailed(SyncTrackingAction<int>), isFalse);
    store.teardown();
  });

  test('early-aborted retry does not erase the previous failure', () {
    fakeAsync((async) {
      final store = Store<int>(initialState: 0);
      final original = const UserException('kept').noDialog;
      final failed = TrackingAction<int>(key: 'a', error: original);
      trackDispatch(store, failed);
      failed.release();
      async.flushMicrotasks();
      final retry = TrackingAction<int>(key: 'a', abort: true);
      final result = trackDispatch(store, retry);
      expect(result.status!.isDispatchAborted, isTrue);
      expect(store.exceptionFor(TrackingAction<int>, statusKey: 'a'), same(original));
      expect(store.isWaiting(retry), isFalse);
      expect(store.actionsInProgress(), isEmpty);
      expect(store.dispatchCount, 1);
      store.teardown();
      async.flushMicrotasks();
    });
  });

  for (final shutdown in [false, true]) {
    test(
      'clearing while reduce is pending does not discard its later failure / shutdown=$shutdown',
      () {
        fakeAsync((async) {
          final store = Store<int>(initialState: 0);
          final error = const UserException('later').noDialog;
          final action = TrackingAction<int>(key: 'a', error: error);
          trackDispatch(store, action);
          async.flushMicrotasks();
          expect(action.stages, contains('reduce:start'));
          if (shutdown) {
            store.shutdown();
          } else {
            store.clearAllExceptions();
          }
          expect(store.isFailed(TrackingAction<int>), isFalse);
          expect(store.isWaiting(action), isTrue);
          action.release();
          async.flushMicrotasks();
          expect(store.isFailed(TrackingAction<int>), isTrue);
          expect(store.exceptionFor(TrackingAction<int>), same(error));
          expect(store.isWaiting(action), isFalse);
          store.teardown();
          async.flushMicrotasks();
        });
      },
    );
  }
}

enum _Outcome {
  success,
  ordinary,
  user,
  noDialog,
  abort,
  swallowed,
  wrappedUser,
  wrappedOrdinary,
  wrappedAbort,
}

(TrackingAction<int>, Object?) _action(_Outcome outcome, Object? key, String label) {
  final original = switch (outcome) {
    _Outcome.success => null,
    _Outcome.user || _Outcome.wrappedOrdinary => UserException(label),
    _Outcome.noDialog => UserException(label).noDialog,
    _Outcome.abort => AbortDispatchException(),
    _ => StateError(label),
  };
  final finalError = switch (outcome) {
    _Outcome.swallowed => null,
    _Outcome.wrappedUser => UserException('wrapped $label'),
    _Outcome.wrappedOrdinary => StateError('wrapped $label'),
    _Outcome.wrappedAbort => AbortDispatchException(),
    _ => original,
  };
  final action = TrackingAction<int>(key: key, error: original)
    ..transformError = (_) => finalError;
  return (action, finalError);
}

bool _recorded(Object? error) => error != null && error is! AbortDispatchException;

void _expectOutcome(
  Store<int> store,
  TrackingAction<int> action,
  Object? expectedError,
  TrackingDispatch result,
) {
  expect(
    store.isFailed(action.runtimeType, statusKey: action.key),
    _recorded(expectedError),
  );
  expect(
    store.exceptionFor(action.runtimeType, statusKey: action.key),
    expectedError is UserException ? same(expectedError) : isNull,
  );
  expect(action.status.wrappedError, same(expectedError));
  expect(action.status.isCompleted, isTrue);
  expect(
    result.error,
    expectedError != null &&
            expectedError is! UserException &&
            expectedError is! AbortDispatchException
        ? same(expectedError)
        : isNull,
  );
}

void _fail(Store<int> store, ReduxAction<int> action) {
  final result = trackDispatch(store, action);
  expect(action.status.isCompletedFailed, isTrue);
  if (action.status.wrappedError is! UserException) {
    expect(result.error, same(action.status.wrappedError));
  }
}

class _TrackingClient extends ReduxAction<int> {
  _TrackingClient(this.pending, this.errorA, this.errorB, this.inspectedStore);
  final TrackingAction<String> pending;
  final UserException errorA;
  final UserException errorB;
  final Store<int> inspectedStore;

  @override
  int? reduce() {
    expect(isWaiting(pending), isTrue);
    expect(isWaiting(TrackingAction<String>, statusKey: 'pending'), isTrue);
    expect(isWaiting(TrackingAction<String>, statusKey: 'absent'), isFalse);
    expect(isFailed(SyncTrackingAction<int>, statusKey: 'a'), isTrue);
    expect(exceptionFor(SyncTrackingAction<int>, statusKey: 'a'), same(errorA));
    clearExceptionFor(SyncTrackingAction<int>, statusKey: 'a');
    expect(isFailed(SyncTrackingAction<int>, statusKey: 'a'), isFalse);
    expect(exceptionFor(SyncTrackingAction<int>, statusKey: 'a'), isNull);
    expect(exceptionFor([SyncTrackingAction<int>]), same(errorB));
    expect(inspectedStore.exceptionFor(SyncTrackingAction<int>), same(errorB));
    clearAllExceptions();
    expect(isFailed([SyncTrackingAction<int>]), isFalse);
    expect(inspectedStore.exceptionFor(SyncTrackingAction<int>), isNull);
    expect(isWaiting(pending), isTrue);
    return null;
  }
}
