import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

// These regressions intentionally assert independent registrations of the same
// public predicate. Store currently keys pending waits by predicate identity,
// so the second registration overwrites the first. Fixing Store is outside this
// tests-only change; keep these assertions active to expose that missing behavior.
void main() {
  for (final stateCondition in [true, false]) {
    final method = stateCondition ? 'waitCondition' : 'waitActionCondition';

    test('$method completes both registrations of the same predicate', () {
      fakeAsync((clock) {
        final store = Store<int>(initialState: 0);
        final condition = _Conditions();
        final completed = <int>[];
        final errors = <Object>[];
        for (var index = 0; index < 2; index++) {
          _register(store, condition, stateCondition, 20).then<void>(
            (_) => completed.add(index),
            onError: (Object error) => errors.add(error),
          );
        }

        store.dispatchSync(_Increment());
        clock.flushMicrotasks();
        clock.elapse(const Duration(milliseconds: 20));

        expect(
          completed,
          unorderedEquals([0, 1]),
          reason: 'Both calls awaited the same condition, which became true',
        );
        expect(errors, isEmpty);
      });
    });

    test('$method timeout of an earlier registration preserves the later one', () {
      fakeAsync((clock) {
        final store = Store<int>(initialState: 0);
        final condition = _Conditions();
        Object? firstError;
        Object? secondError;
        var secondCompleted = false;
        _register(store, condition, stateCondition, 5).then<void>(
          (_) => fail('The first wait must time out before any dispatch'),
          onError: (Object error) => firstError = error,
        );
        _register(store, condition, stateCondition, 20).then<void>(
          (_) => secondCompleted = true,
          onError: (Object error) => secondError = error,
        );

        clock.elapse(const Duration(milliseconds: 5));
        expect(firstError, isA<TimeoutException>());
        expect(secondCompleted, isFalse);
        expect(secondError, isNull);
        store.dispatchSync(_Increment());
        clock.flushMicrotasks();
        clock.elapse(const Duration(milliseconds: 15));

        expect(
          secondCompleted,
          isTrue,
          reason: 'Expiring another call must not unregister this pending wait',
        );
        expect(secondError, isNull);
      });
    });
  }
}

Future<Object?> _register(
  Store<int> store,
  _Conditions conditions,
  bool stateCondition,
  int timeoutMillis,
) async {
  if (stateCondition) {
    return store.waitCondition(conditions.state, timeoutMillis: timeoutMillis);
  }
  return store.waitActionCondition(conditions.action, timeoutMillis: timeoutMillis);
}

class _Conditions {
  final bool Function(int) state = (state) => state == 1;
  final bool Function(Set<ReduxAction<int>>, ReduxAction<int>?) action = (
    actions,
    trigger,
  ) => trigger != null && actions.isEmpty;
}

class _Increment extends ReduxAction<int> {
  @override
  int reduce() => state + 1;
}
