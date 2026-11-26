import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

// Reusing a predicate must not couple the completion or timeout of separate waits.
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

    for (final firstExpires in [true, false]) {
      test('$method expires only its own registration: first=$firstExpires', () {
        fakeAsync((clock) {
          final store = Store<int>(initialState: 0);
          final condition = _Conditions();
          final completed = <int>[];
          final errors = <int, Object>{};
          final expiring = firstExpires ? 0 : 1;
          for (var index = 0; index < 2; index++) {
            _register(store, condition, stateCondition, index == expiring ? 5 : 20)
                .then<void>(
              (_) => completed.add(index),
              onError: (Object error) => errors[index] = error,
            );
          }

          clock.elapse(const Duration(milliseconds: 5));
          expect(errors.keys, [expiring]);
          expect(errors[expiring], isA<TimeoutException>());
          expect(completed, isEmpty);
          store.dispatchSync(_Increment());
          clock.flushMicrotasks();
          clock.elapse(const Duration(milliseconds: 15));

          expect(completed, [1 - expiring]);
          expect(errors.keys, [expiring]);
          store.teardown();
          clock.flushMicrotasks();
        });
      });
    }
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
