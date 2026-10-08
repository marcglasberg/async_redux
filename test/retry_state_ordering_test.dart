import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:flutter_test/flutter_test.dart' hide Retry;

/// Checks that the state returned by the reducer of a [Retry] action is applied to the
/// store in the same microtask in which the reducer returns. If it's not, another action
/// running in the gap changes the state, and that change is then overwritten (lost).
///
/// To detect the gap, the reducer schedules a microtask that dispatches [AddTen]. The
/// correct final state is 1 + 10 = 11. If the [Retry] action's state is applied late, it
/// overwrites the [AddTen] change and the final state is 1.
void main() {
  for (var failures in [0, 1, 2]) {
    test('Retry action whose reducer fails $failures time(s) does not lose state',
        () async {
      var store = Store<int>(initialState: 0);

      var action = AddOneWithRetry(failures: failures);
      await store.dispatchAndWait(action);
      await Future<void>.delayed(Duration.zero);

      expect(action.attempts, failures);
      expect(store.state, 11);
    });
  }
}

class AddOneWithRetry extends ReduxAction<int> with Retry {
  AddOneWithRetry({required this.failures});

  final int failures;
  int _calls = 0;

  @override
  Duration get initialDelay => const Duration(milliseconds: 10);

  @override
  int reduce() {
    _calls++;
    if (_calls <= failures) throw const UserException('Fail');

    // Runs after the reducer returns, in the next microtask.
    scheduleMicrotask(() => dispatchSync(AddTen()));

    return state + 1;
  }
}

class AddTen extends ReduxAction<int> {
  @override
  int reduce() => state + 10;
}
