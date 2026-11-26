import 'package:async_redux/async_redux.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/waiting_failed_support.dart';

void main() {
  for (final failInBefore in [false, true]) {
    for (final errorKind in ['success', 'user', 'ordinary', 'abort', 'swallowed']) {
      test(
        'waiting spans every lifecycle: $errorKind / before failure=$failInBefore',
        () {
          fakeAsync((async) {
            final error = switch (errorKind) {
              'success' => null,
              'user' => const UserException('failed').noDialog,
              'abort' => AbortDispatchException(),
              _ => StateError('failed'),
            };
            final store = Store<int>(initialState: 0);
            final action = TrackingAction<int>(
              key: 'a',
              error: error,
              failInBefore: failInBefore,
              holdBefore: true,
            );
            if (errorKind == 'swallowed') action.transformError = (_) => null;
            final seen = <(String, bool, bool, bool)>[];
            action.onStage = (stage, action) {
              seen.add((
                stage,
                store.isWaiting(action),
                store.isWaiting(TrackingAction<int>, statusKey: 'a'),
                store.isFailed(TrackingAction<int>, statusKey: 'a'),
              ));
            };
            final result = trackDispatch(store, action);
            expect(seen, [
              ('abort', false, false, false),
              ('before:start', true, true, false),
            ]);
            expect(store.actionsInProgress(), [same(action)]);
            async.flushMicrotasks();
            expect(action.status.hasFinishedMethodBefore, isFalse);
            expect(result.status, isNull);
            action.releaseBefore();
            async.flushMicrotasks();
            final beforeFailed = failInBefore && error != null;
            expect(store.isWaiting(action), !beforeFailed);
            if (!beforeFailed) {
              expect(action.status.hasFinishedMethodBefore, isTrue);
              expect(action.status.hasFinishedMethodReduce, isFalse);
              expect(store.isWaiting(TrackingAction<int>), isTrue);
              action.release();
              async.flushMicrotasks();
            }
            final failed = errorKind == 'user' || errorKind == 'ordinary';
            expect(seen.last, ('after', true, true, failed));
            expect(seen.where((e) => e.$1 != 'abort').every((e) => e.$2 && e.$3), isTrue);
            expect(store.actionsInProgress(), isEmpty);
            expect(store.isWaiting(action), isFalse);
            expect(store.isWaiting(TrackingAction<int>), isFalse);
            expect(store.isFailed(TrackingAction<int>, statusKey: 'a'), failed);
            expect(action.status.isCompleted, isTrue);
            expect(result.error, errorKind == 'ordinary' ? same(error) : isNull);
            store.teardown();
            async.flushMicrotasks();
          });
        },
      );
    }
  }

  for (final error in [null, const UserException('sync').noDialog]) {
    test('sync actions are in the identity set during hooks / error=$error', () {
      final store = Store<int>(initialState: 0);
      final action = SyncTrackingAction<int>(key: 'sync', error: error);
      final seen = <(String, bool, bool)>[];
      action.onStage = (stage, action) {
        seen.add((
          stage,
          store.isWaiting(action),
          // This query runs inside the synchronous lifecycle, before dispatch returns.
          // ignore: async_redux_lints/wait_fail_never_matches
          store.isWaiting(SyncTrackingAction<int>, statusKey: 'sync'),
        ));
      };
      expect(store.isWaiting(action), isFalse);
      final status = store.dispatchSync(action);
      expect(seen, [
        ('abort', false, false),
        ('before', true, true),
        ('reduce', true, true),
        ('after', true, true),
      ]);
      expect(status.isCompleted, isTrue);
      expect(store.isWaiting(action), isFalse);
      expect(store.actionsInProgress(), isEmpty);
      store.teardown();
    });
  }

  for (final order in _permutations([0, 1, 2])) {
    test('same-type/key actions remain waiting until last completion: $order', () {
      fakeAsync((async) {
        final store = Store<int>(initialState: 0);
        final actions = List.generate(3, (_) => EqualTrackingAction(key: 'a'));
        final inactiveEqual = EqualTrackingAction(key: 'a');
        for (final action in actions) trackDispatch(store, action);
        final live = store.actionsInProgress();
        final snapshot = store.copyActionsInProgress();
        expect(live, hasLength(3));
        expect(snapshot, hasLength(3));
        expect(store.isWaiting(inactiveEqual), isFalse);
        expect(live.contains(inactiveEqual), isFalse);
        expect(store.actionsInProgressEqualTo(snapshot), isTrue);
        expect(() => live.add(inactiveEqual), throwsUnsupportedError);
        expect(() => live.remove(actions.first), throwsUnsupportedError);
        expect(() => live.clear(), throwsUnsupportedError);
        final expected = Set<ReduxAction<int>>.identity()..addAll(actions);
        for (final index in order) {
          // A changed hashCode must not strand the action in the store's set.
          actions[index].mutableHash++;
          actions[index].release();
          async.flushMicrotasks();
          expected.remove(actions[index]);
          expect(store.actionsInProgressEqualTo(expected), isTrue);
          expect(live, hasLength(expected.length));
          expect(
            store.isWaiting(EqualTrackingAction, statusKey: 'a'),
            expected.isNotEmpty,
          );
          expect(store.isWaiting(actions[index]), isFalse);
          for (final other in expected) expect(store.isWaiting(other), isTrue);
          expect(snapshot, hasLength(3));
        }
        snapshot.clear();
        expect(store.actionsInProgress(), isEmpty);
        store.teardown();
        async.flushMicrotasks();
      });
    });
  }

  test(
    'waiting uses exact runtime type, generic arguments, and value equality of keys',
    () {
      fakeAsync((async) {
        final store = Store<int>(initialState: 0);
        final a = TrackingAction<int>(key: const TrackingKey('a'));
        final b = TrackingAction<String>(key: const TrackingKey('b'));
        final derived = DerivedTrackingAction(key: ('record', 1));
        final nullKey = TrackingAction<int>();
        final identityKey = <int>[1];
        final keyedByList = TrackingAction<int>(key: identityKey);
        final actions = [a, b, derived, nullKey, keyedByList];
        for (final action in actions) trackDispatch(store, action);
        expect(
          store.isWaiting(TrackingAction<int>, statusKey: const TrackingKey('a')),
          isTrue,
        );
        expect(
          store.isWaiting(TrackingAction<int>, statusKey: const TrackingKey('b')),
          isFalse,
        );
        expect(
          store.isWaiting(TrackingAction<String>, statusKey: const TrackingKey('b')),
          isTrue,
        );
        expect(store.isWaiting(TrackingAction<num>), isFalse);
        expect(store.isWaiting(TrackingAction<int>, statusKey: ('record', 1)), isFalse);
        expect(store.isWaiting(DerivedTrackingAction, statusKey: ('record', 1)), isTrue);
        expect(store.isWaiting(TrackingAction<int>, statusKey: <int>[1]), isFalse);
        expect(store.isWaiting(TrackingAction<int>, statusKey: identityKey), isTrue);
        expect(store.isWaiting(a, statusKey: 'unrelated'), isTrue);
        expect(
          store.isWaiting([TrackingAction<String>, a], statusKey: 'unrelated'),
          isTrue,
        );
        expect(
          store.isWaiting([
            TrackingAction<String>,
            TrackingAction<int>,
          ], statusKey: const TrackingKey('a')),
          isTrue,
        );
        for (final action in actions) action.release();
        async.flushMicrotasks();
        expect(store.actionsInProgress(), isEmpty);
        store.teardown();
        async.flushMicrotasks();
      });
    },
  );

  for (final firstError in [false, true]) {
    for (final secondError in [false, true]) {
      for (final reverse in [false, true]) {
        for (final sameKey in [false, true]) {
          test('overlapping failures/successes: $firstError/$secondError / '
              'reverse=$reverse / sameKey=$sameKey', () {
            fakeAsync((async) {
              final store = Store<int>(initialState: 0);
              final errorA = const UserException('a').noDialog;
              final errorB = const UserException('b').noDialog;
              final a = TrackingAction<int>(key: 'a', error: firstError ? errorA : null);
              final b = TrackingAction<int>(
                key: sameKey ? 'a' : 'b',
                error: secondError ? errorB : null,
              );
              trackDispatch(store, a);
              trackDispatch(store, b);
              final order = reverse ? [b, a] : [a, b];
              final failures = <Object?, Object>{};
              for (final action in order) {
                action.release();
                async.flushMicrotasks();
                if (action.error != null) failures[action.key] = action.error!;
                expect(store.isFailed(TrackingAction<int>), failures.isNotEmpty);
                for (final key in ['a', 'b']) {
                  expect(
                    store.exceptionFor(TrackingAction<int>, statusKey: key),
                    failures[key] == null ? isNull : same(failures[key]),
                  );
                }
              }
              // Success only cleared the failure when it STARTED. It cannot
              // erase a concurrent failure that happened after that point.
              expect(store.isFailed(TrackingAction<int>), firstError || secondError);
              expect(store.actionsInProgress(), isEmpty);
              store.teardown();
              async.flushMicrotasks();
            });
          });
        }
      }
    }
  }

  test('condition observers see exact start/removal transitions and unregister', () {
    fakeAsync((async) {
      final store = Store<int>(initialState: 0);
      final a = TrackingAction<int>();
      final b = TrackingAction<String>();
      final seen = <(Set<ReduxAction<int>>, ReduxAction<int>?)>[];
      var done = false;
      store
          .waitActionCondition((actions, trigger) {
            seen.add((Set<ReduxAction<int>>.identity()..addAll(actions), trigger));
            return trigger != null && actions.isEmpty;
          }, timeoutMillis: -1)
          .then((_) => done = true);
      trackDispatch(store, a);
      trackDispatch(store, b);
      expect(seen.map((e) => e.$1.length), [0, 1, 2]);
      a.release();
      async.flushMicrotasks();
      expect(done, isFalse);
      expect(seen.last.$1, [same(b)]);
      expect(seen.last.$2, same(a));
      b.release();
      async.flushMicrotasks();
      expect(done, isTrue);
      expect(seen.map((e) => e.$1.length), [0, 1, 2, 1, 0]);
      expect(seen.last.$2, same(b));
      store.dispatchSync(SyncTrackingAction<int>());
      expect(seen, hasLength(5));
      store.teardown();
      async.flushMicrotasks();
    });
  });
}

Iterable<List<int>> _permutations(List<int> values) sync* {
  if (values.isEmpty) {
    yield [];
    return;
  }
  for (final value in values) {
    for (final rest in _permutations(values.where((v) => v != value).toList())) {
      yield [value, ...rest];
    }
  }
}
