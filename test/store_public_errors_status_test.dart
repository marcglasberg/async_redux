import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'error snapshots retain order and identity across later queue mutations',
    () async {
      final store = Store<int>(initialState: 0);
      addTearDown(store.teardown);
      const first = UserException('first');
      const second = UserException('second');
      const third = UserException('third');
      store.dispatchSync(_Fail(first));
      store.dispatchSync(_Fail(second));
      final snapshot = store.errors;
      final anotherSnapshot = store.errors;
      expect(identical(snapshot, anotherSnapshot), isFalse);
      expect(store.getAndRemoveFirstError(), same(first));
      store.dispatchSync(_Fail(third));
      expect(snapshot, [same(first), same(second)]);
      snapshot.removeLast();
      snapshot.addFirst(third);
      expect(anotherSnapshot, [same(first), same(second)]);
      expect(store.errors, [same(second), same(third)]);
      expect(store.internalHasErrors, isTrue);
    },
  );

  test('queue consumption is FIFO and silent and leaves keyed failures intact', () async {
    final store = Store<int>(initialState: 0, syncStream: true);
    addTearDown(store.teardown);
    const first = UserException('first');
    const second = UserException('second');
    store.dispatchSync(_Fail(first, key: 'a'));
    store.dispatchSync(_Fail(second, key: 'b'));
    final events = <int>[];
    final subscription = store.onChange.listen(events.add);
    addTearDown(subscription.cancel);
    for (var i = 0; i < 3; i++) {
      expect(store.internalHasErrors, isTrue);
      expect(store.errors, [same(first), same(second)]);
    }
    expect(store.getAndRemoveFirstError(), same(first));
    expect(store.internalHasErrors, isTrue);
    expect(store.getAndRemoveFirstError(), same(second));
    expect(store.internalHasErrors, isFalse);
    expect(store.getAndRemoveFirstError(), isNull);
    expect(store.internalHasErrors, isFalse);
    expect(events, isEmpty);
    expect(store.exceptionFor(_Fail, statusKey: 'a'), same(first));
    expect(store.exceptionFor(_Fail, statusKey: 'b'), same(second));
    expect(store.isFailed(_Fail), isTrue);
  });

  for (final source in ['action', 'status']) {
    test('removeError with $source removes the wrapped error, not original', () async {
      final store = Store<int>(initialState: 0, syncStream: true);
      addTearDown(store.teardown);
      const original = UserException('original');
      const wrapped = UserException('wrapped');
      store.dispatchSync(_Fail(original, key: 'kept'));
      final action = _Fail(original, key: 'wrapped', wrapped: wrapped);
      store.dispatchSync(action);
      expect(action.status.originalError, same(original));
      expect(action.status.wrappedError, same(wrapped));
      final events = <int>[];
      final subscription = store.onChange.listen(events.add);
      addTearDown(subscription.cancel);
      store.removeError(source == 'action' ? action : action.status);
      expect(store.errors, [same(original)]);
      expect(store.internalHasErrors, isTrue);
      expect(store.exceptionFor(_Fail, statusKey: 'wrapped'), same(wrapped));
      store.removeError(original);
      expect(store.internalHasErrors, isFalse);
      expect(events, isEmpty);
    });
  }

  test('removeError ignores absent, undispatched, and non-user error sources', () async {
    final store = Store<int>(initialState: 0);
    addTearDown(store.teardown);
    const kept = UserException('kept');
    store.dispatchSync(_Fail(kept));
    final failed = _Fail(StateError('ordinary'));
    expect(() => store.dispatchSync(failed), throwsStateError);
    final undispatched = _Fail(kept);
    for (final source in <Object>[
      const UserException('absent'),
      undispatched,
      undispatched.status,
      failed,
      failed.status,
      ActionStatus(context: null, originalError: kept),
      ActionStatus(context: null, wrappedError: StateError('ordinary')),
    ]) {
      store.removeError(source);
      expect(store.errors, [same(kept)]);
      expect(store.internalHasErrors, isTrue);
    }
  });

  test('pending dialogs are independent of failure eligibility', () async {
    final store = Store<int>(initialState: 0);
    addTearDown(store.teardown);
    final hidden = const UserException('hidden').noDialog;
    store.dispatchSync(_Fail(hidden, key: 'hidden'));
    expect(store.internalHasErrors, isFalse);
    expect(store.isFailed(_Fail, statusKey: 'hidden'), isTrue);
    expect(store.exceptionFor(_Fail, statusKey: 'hidden'), same(hidden));
    final ordinary = StateError('ordinary');
    expect(
      () => store.dispatchSync(_Fail(ordinary, key: 'ordinary')),
      throwsA(same(ordinary)),
    );
    expect(store.internalHasErrors, isFalse);
    expect(store.isFailed(_Fail, statusKey: 'ordinary'), isTrue);
    expect(store.exceptionFor(_Fail, statusKey: 'ordinary'), isNull);
    store.dispatchSync(_Fail(const UserException('dialog'), key: 'dialog'));
    expect(store.internalHasErrors, isTrue);
    store.clearAllExceptions();
    expect(store.isFailed(_Fail), isFalse);
    expect(store.internalHasErrors, isTrue);
    store.removeError(const UserException('dialog'));
    expect(store.internalHasErrors, isFalse);
  });

  test('waiting, failures, queue reads and clearing are scoped to each store', () async {
    final first = Store<int>(initialState: 0);
    final second = Store<int>(initialState: 0);
    addTearDown(first.teardown);
    addTearDown(second.teardown);
    const firstError = UserException('first');
    const secondError = UserException('second');
    first.dispatchSync(_Fail(firstError, key: 'same'));
    second.dispatchSync(_Fail(secondError, key: 'same'));
    final held = _Held();
    final done = first.dispatchAndWait(held);
    expect(first.isWaiting(held), isTrue);
    expect(second.isWaiting(held), isFalse);
    expect(first.isWaiting(_Held), isTrue);
    expect(second.isWaiting(_Held), isFalse);
    first.clearExceptionFor(_Fail, statusKey: 'same');
    expect(first.isFailed(_Fail), isFalse);
    expect(second.isFailed(_Fail), isTrue);
    expect(second.exceptionFor(_Fail), same(secondError));
    first.removeError(firstError);
    expect(first.internalHasErrors, isFalse);
    expect(second.internalHasErrors, isTrue);
    expect(second.getAndRemoveFirstError(), same(secondError));
    second.clearAllExceptions();
    expect(second.isFailed(_Fail), isFalse);
    expect(first.isWaiting(held), isTrue);
    held.gate.complete();
    await done;
    expect(first.isWaiting(_Held), isFalse);
  });

  for (final method in ['isWaiting', 'isFailed', 'exceptionFor', 'clearExceptionFor']) {
    test('$method consumes a lazy query only once', () async {
      final store = Store<int>(initialState: 0);
      addTearDown(store.teardown);
      const error = UserException('failure');
      store.dispatchSync(_Fail(error));
      var enumerations = 0;
      var visits = 0;
      Iterable<Type> query() sync* {
        enumerations++;
        yield _Fail;
        visits++;
        yield String;
        visits++;
      }

      switch (method) {
        case 'isWaiting':
          expect(store.isWaiting(query()), isFalse);
        case 'isFailed':
          expect(store.isFailed(query()), isTrue);
        case 'exceptionFor':
          expect(store.exceptionFor(query()), same(error));
        case 'clearExceptionFor':
          store.clearExceptionFor(query());
          expect(store.isFailed(_Fail), isFalse);
      }
      expect(enumerations, 1);
      expect(visits, 2);
    });
  }
}

class _Fail extends ReduxAction<int> {
  _Fail(this.error, {this.key, this.wrapped});
  final Object error;
  final Object? key;
  final Object? wrapped;

  @override
  Object? get statusKey => key;

  @override
  int? reduce() => throw error;

  @override
  Object? wrapError(Object error, StackTrace stackTrace) => wrapped ?? error;
}

class _Held extends ReduxAction<int> {
  final gate = Completer<void>();

  @override
  Future<int?> reduce() async {
    await gate.future;
    return null;
  }
}
