import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final notify in [false, true]) {
    for (final waiting in [false, true]) {
      for (final failure in [false, true]) {
        for (final outcome in _Outcome.values) {
          test('notifications: notify=$notify, waiting=$waiting, '
              'failure=$failure, outcome=$outcome', () async {
            final store = Store<int>(initialState: 0, syncStream: true);
            final gate = Completer<void>();
            final action = _Action(gate.future, outcome);
            if (waiting) expect(store.isWaiting(_Action), isFalse);
            if (failure) expect(store.isFailed(_Action), isFalse);
            final events = <(int, bool)>[];
            final subscription = store.onChange.listen((state) {
              events.add((state, store.actionsInProgress().contains(action)));
            });
            final future = store.dispatchAndWait(action, notify: notify);
            expect(events, waiting ? [(0, true)] : []);
            gate.complete();
            await future;

            final failed = outcome == _Outcome.dialog || outcome == _Outcome.noDialog;
            final finalState = outcome == _Outcome.changed ? 1 : 0;
            expect(events, [
              if (waiting) (0, true),
              if (!failed && notify) (finalState, true),
              if (outcome == _Outcome.dialog) (0, true),
              if ((waiting && (failed || !notify)) || (failure && failed))
                (finalState, false),
            ]);
            expect(store.state, finalState);
            expect(store.isWaiting(action), isFalse);
            expect(store.isFailed(_Action), failed);
            expect(action.status.isCompletedFailed, failed);
            expect(store.errors, hasLength(outcome == _Outcome.dialog ? 1 : 0));
            await subscription.cancel();
            await store.teardown();
          });
        }
      }
    }
  }

  test(
    'redispatch clears failure before marking waiting, with one start event',
    () async {
      final store = Store<int>(initialState: 0, syncStream: true);
      await store.dispatchAndWait(_Action(Future<void>.value(), _Outcome.noDialog));
      expect(store.isFailed(_Action), isTrue);
      expect(store.isWaiting(_Action), isFalse);
      final events = <(bool, bool)>[];
      final subscription = store.onChange.listen((_) {
        events.add((store.isFailed(_Action), store.isWaiting(_Action)));
      });
      final gate = Completer<void>();
      final retry = _Action(gate.future, _Outcome.unchanged);
      final future = store.dispatchAndWait(retry, notify: false);
      expect(events, [(false, false)]);
      expect(store.isWaiting(retry), isTrue);
      expect(store.exceptionFor(_Action), isNull);
      gate.complete();
      await future;
      expect(events, [(false, false), (false, false)]);
      await subscription.cancel();
      await store.teardown();
    },
  );

  test(
    'default stream delivers notifications after synchronous dispatch finishes',
    () async {
      final store = Store<int>(initialState: 0);
      final events = <(int, bool)>[];
      final action = UpdateStateAction<int>(1);
      final subscription = store.onChange.listen((value) {
        events.add((value, action.status.isCompleted));
      });
      store.dispatchSync(action);
      expect(events, isEmpty);
      await Future<void>.value();
      expect(events, [(1, true)]);
      await subscription.cancel();
      await store.teardown();
    },
  );

  for (final source in ['error', 'status', 'action']) {
    test('removeError accepts $source and preserves unrelated queue entries', () async {
      final store = Store<int>(initialState: 0);
      final a = _UserError(const UserException('a'));
      final b = _UserError(const UserException('b'));
      store.dispatchSync(a);
      store.dispatchSync(b);
      store.dispatchSync(_UserError(const UserException('a')));
      // errors is a defensive copy, while removal matches equal exceptions.
      store.errors.clear();
      expect(store.errors, hasLength(3));
      store.removeError(switch (source) {
        'error' => a.error,
        'status' => a.status,
        _ => a,
      });
      expect(store.errors.toList(), [b.error]);
      expect(store.getAndRemoveFirstError(), same(b.error));
      expect(store.getAndRemoveFirstError(), isNull);
      expect(store.errors, isEmpty);
      await store.teardown();
    });
  }

  test(
    'removeError ignores successful actions, statuses and unrelated objects',
    () async {
      final store = Store<int>(initialState: 0);
      store.dispatchSync(_UserError(const UserException('kept')));
      final success = UpdateStateAction<int>(1);
      store.dispatchSync(success);
      for (final source in [success, success.status, Object()]) {
        store.removeError(source);
        expect(store.errors, hasLength(1));
      }
      await store.teardown();
    },
  );

  test(
    'error queue keeps FIFO order within its configured capacity',
    () async {
      final store = Store<int>(initialState: 0, maxErrorsQueued: 2);
      for (var i = 0; i < 5; i++) {
        store.dispatchSync(_UserError(UserException('$i')));
      }
      // Discard the oldest errors while preserving FIFO order among those retained.
      expect(store.errors.toList(), [
        const UserException('3'),
        const UserException('4'),
      ]);
      expect(store.getAndRemoveFirstError(), const UserException('3'));
      expect(store.getAndRemoveFirstError(), const UserException('4'));
      expect(store.getAndRemoveFirstError(), isNull);
      await store.teardown();
    },
  );
}

enum _Outcome { changed, unchanged, dialog, noDialog }

class _Action extends ReduxAction<int> {
  _Action(this.gate, this.outcome);

  final Future<void> gate;
  final _Outcome outcome;

  @override
  Future<int?> reduce() async {
    await gate;
    return switch (outcome) {
      _Outcome.changed => state + 1,
      _Outcome.unchanged => null,
      _Outcome.dialog => throw const UserException('failed'),
      _Outcome.noDialog => throw const UserException('failed').noDialog,
    };
  }
}

class _UserError extends ReduxAction<int> {
  _UserError(this.error);

  final UserException error;

  @override
  int? reduce() => throw error;
}
