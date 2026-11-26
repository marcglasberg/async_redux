import 'dart:math';

import 'package:async_redux/async_redux.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/waiting_failed_support.dart';

// A small public-contract model: running action identities, plus the most recent
// failure event for each exact (type, key). It does not inspect private fields or
// derive expected answers from the store's statuses.
void main() {
  for (var seed = 0; seed < 24; seed++) {
    test('tracking agrees with the model after every operation / seed=$seed', () {
      fakeAsync((async) {
        final random = Random(seed);
        final store = Store<int>(initialState: 0);
        final model = _Model();
        final liveView = store.actionsInProgress();
        final keys = <Object?>[
          null,
          'a',
          'b',
          const TrackingKey('a'),
          const TrackingKey('b'),
          // Equal but nonidentical keys exercise value-based matching.
          // ignore: prefer_const_constructors
          TrackingKey('a'),
          ('record', 1),
          Object(),
        ];
        final types = <Type>[
          TrackingAction<int>,
          TrackingAction<String>,
          DerivedTrackingAction,
          EqualTrackingAction,
          SyncTrackingAction<int>,
          SyncTrackingAction<String>,
        ];
        final active = <_Running>[];
        final allDispatched = <TrackingAction>[];
        var sequence = 0;

        void verify(String reason) {
          final expected = Set<ReduxAction<int>>.identity()
            ..addAll(active.map((entry) => entry.action));
          expect(store.actionsInProgressEqualTo(expected), isTrue, reason: reason);
          expect(liveView.length, expected.length, reason: reason);
          expect(
            store.copyActionsInProgress().containsAll(expected),
            isTrue,
            reason: reason,
          );
          for (final action in allDispatched) {
            expect(
              store.isWaiting(action, statusKey: 'ignored for instances'),
              expected.contains(action),
              reason: reason,
            );
          }
          for (final type in types) {
            for (final key in [...keys, 'missing']) {
              final waiting = active.any(
                (entry) =>
                    entry.action.runtimeType == type &&
                    (key == null || entry.action.key == key),
              );
              expect(store.isWaiting(type, statusKey: key), waiting, reason: reason);
              expect(
                store.isFailed(type, statusKey: key),
                model.failed(type, key),
                reason: reason,
              );
              expect(
                store.exceptionFor(type, statusKey: key),
                same(model.exception(type, key)),
                reason: reason,
              );
            }
          }
          final ordered = random.nextBool() ? types : types.reversed.toList();
          expect(
            store.isFailed(ordered),
            ordered.any((type) => model.failed(type, null)),
            reason: reason,
          );
          UserException? expectedException;
          for (final type in ordered) {
            expectedException ??= model.exception(type, null);
          }
          expect(store.exceptionFor(ordered), same(expectedException), reason: reason);
          expect(store.isWaiting(ordered), active.isNotEmpty, reason: reason);
        }

        void finish(_Running entry) {
          entry.action.release();
          async.flushMicrotasks();
          active.removeWhere((other) => identical(other, entry));
          final error = entry.expectedError;
          if (error != null && error is! AbortDispatchException) {
            model.fail(entry.action.runtimeType, entry.action.key, error, sequence++);
          }
          expect(entry.action.status.isCompleted, isTrue);
          expect(
            entry.result.error,
            error != null && error is! UserException && error is! AbortDispatchException
                ? same(error)
                : isNull,
          );
        }

        verify('initial');
        for (var step = 0; step < 220; step++) {
          final operation = random.nextInt(9);
          final key = keys[random.nextInt(keys.length)];
          if ((operation <= 2 && active.length < 8) || active.isEmpty && operation == 3) {
            final outcome = random.nextInt(6);
            final Object? original = switch (outcome) {
              0 => null,
              1 => UserException('$seed/$step'),
              2 => UserException('$seed/$step inline').noDialog,
              3 || 5 => StateError('$seed/$step'),
              _ => AbortDispatchException(),
            };
            final expectedError = outcome == 5 ? null : original;
            final action = _action(random.nextInt(4), key, original);
            if (outcome == 5) action.transformError = (_) => null;
            model.start(action.runtimeType, key);
            active.add(
              _Running(
                action,
                expectedError,
                trackDispatch(store, action, notify: random.nextBool()),
              ),
            );
            allDispatched.add(action);
            async.flushMicrotasks();
          } else if (operation == 3 && active.isNotEmpty) {
            finish(active[random.nextInt(active.length)]);
          } else if (operation == 4) {
            final type = types[random.nextInt(types.length)];
            store.clearExceptionFor(type, statusKey: key);
            model.clear(type, key);
          } else if (operation == 5) {
            store.clearAllExceptions();
            model.entries.clear();
          } else if (operation == 6) {
            store.internalMixinProps.clear();
            model.entries.clear();
          } else if (operation == 7) {
            final aborted = TrackingAction<int>(key: key, abort: true);
            final result = trackDispatch(store, aborted);
            expect(result.status!.isDispatchAborted, isTrue);
            // No event is applied to the model: early abort changes neither registry.
          } else {
            final error = random.nextBool()
                ? UserException('sync $seed/$step').noDialog
                : null;
            final action = random.nextBool()
                ? SyncTrackingAction<int>(key: key, error: error)
                : SyncTrackingAction<String>(key: key, error: error);
            model.start(action.runtimeType, key);
            trackDispatch(store, action, notify: false);
            if (error != null) model.fail(action.runtimeType, key, error, sequence++);
          }
          verify('seed=$seed step=$step operation=$operation');
        }
        while (active.isNotEmpty) {
          finish(active[random.nextInt(active.length)]);
          verify('draining seed=$seed remaining=${active.length}');
        }
        store.clearAllExceptions();
        model.entries.clear();
        verify('final clear');
        expect(store.actionsInProgress(), isEmpty);
        store.teardown();
        async.flushMicrotasks();
      });
    });
  }
}

TrackingAction _action(int type, Object? key, Object? error) => switch (type) {
  0 => TrackingAction<int>(key: key, error: error),
  1 => TrackingAction<String>(key: key, error: error),
  2 => DerivedTrackingAction(key: key, error: error),
  _ => EqualTrackingAction(key: key, error: error),
};

class _Running {
  _Running(this.action, this.expectedError, this.result);
  final TrackingAction action;
  final Object? expectedError;
  final TrackingDispatch result;
}

class _Model {
  final entries = <(Type, Object?), (Object, int)>{};

  void start(Type type, Object? key) => entries.remove((type, key));
  void fail(Type type, Object? key, Object error, int sequence) =>
      entries[(type, key)] = (error, sequence);
  void clear(Type type, Object? key) => entries.removeWhere(
    (entry, value) => entry.$1 == type && (key == null || entry.$2 == key),
  );
  bool failed(Type type, Object? key) =>
      entries.keys.any((entry) => entry.$1 == type && (key == null || entry.$2 == key));
  UserException? exception(Type type, Object? key) {
    UserException? result;
    var mostRecent = -1;
    for (final entry in entries.entries) {
      if (entry.key.$1 != type || (key != null && entry.key.$2 != key)) continue;
      if (entry.value.$1 is UserException && entry.value.$2 > mostRecent) {
        result = entry.value.$1 as UserException;
        mostRecent = entry.value.$2;
      }
    }
    return result;
  }
}
