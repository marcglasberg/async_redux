import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaultTimeoutMillis starts at ten minutes', () {
    expect(Store<int>(initialState: 0).options.defaultTimeoutMillis, 600000);
  });

  for (final kind in _WaitKind.values) {
    group(kind.name, () {
      for (final timeout in [0, 17]) {
        test('uses explicit timeout $timeout instead of store default', () {
          fakeAsync((clock) {
            final store = Store<int>(
              initialState: 0,
              options: StoreOptions(defaultTimeoutMillis: 100),
            );
            final action = _HeldAction();
            store.dispatch(action);
            Object? error;
            var completed = false;
            _wait(kind, store, action, timeout).then<void>(
              (_) => completed = true,
              onError: (Object value) => error = value,
            );
            clock.flushMicrotasks();
            expect(error, isNull);
            if (timeout > 0) {
              clock.elapse(Duration(milliseconds: timeout - 1));
              expect(error, isNull);
            }
            clock.elapse(Duration(milliseconds: timeout == 0 ? 0 : 1));
            expect(
              error,
              isA<TimeoutException>().having(
                (error) => error.duration,
                'duration',
                Duration(milliseconds: timeout),
              ),
            );
            expect(completed, isFalse);
            action.release();
            clock.flushMicrotasks();
            expect(completed, isFalse);
            expect(store.actionsInProgress(), isEmpty);
          });
        });
      }

      test('uses independent defaults for each store', () {
        fakeAsync((clock) {
          final store = Store<int>(
            initialState: 0,
            options: StoreOptions(defaultTimeoutMillis: 13),
          );
          final other = Store<int>(
            initialState: 0,
            options: StoreOptions(defaultTimeoutMillis: 100),
          );
          final action = _HeldAction();
          final otherAction = _HeldAction();
          store.dispatch(action);
          other.dispatch(otherAction);
          Object? error;
          Object? otherError;
          _wait(kind, store, action, null).then<void>(
            (_) => fail('The action has not finished'),
            onError: (Object value) => error = value,
          );
          _wait(kind, other, otherAction, null).then<void>(
            (_) => fail('The other action has not finished'),
            onError: (Object value) => otherError = value,
          );
          clock.elapse(const Duration(milliseconds: 12));
          expect(error, isNull);
          clock.elapse(const Duration(milliseconds: 1));
          expect(
            error,
            isA<TimeoutException>().having(
              (error) => error.duration,
              'duration',
              const Duration(milliseconds: 13),
            ),
          );
          expect(otherError, isNull);
          clock.elapse(const Duration(milliseconds: 87));
          expect(otherError, isA<TimeoutException>());
          action.release();
          otherAction.release();
          clock.flushMicrotasks();
          store.teardown();
          other.teardown();
          clock.flushMicrotasks();
        });
      });

      for (final disableByDefault in [false, true]) {
        test('negative timeout disables expiry; default=$disableByDefault', () {
          fakeAsync((clock) {
            final store = Store<int>(
              initialState: 0,
              options: StoreOptions(
                defaultTimeoutMillis: disableByDefault ? -1 : 1,
              ),
            );
            final action = _HeldAction();
            store.dispatch(action);
            var completed = false;
            _wait(
              kind,
              store,
              action,
              disableByDefault ? null : -1,
            ).then<void>((_) => completed = true);
            clock.elapse(const Duration(days: 1));
            expect(completed, isFalse);
            expect(clock.nonPeriodicTimerCount, 0);
            action.release();
            clock.flushMicrotasks();
            expect(completed, isTrue);
            expect(clock.nonPeriodicTimerCount, 0);
          });
        });
      }

      test('successful completion cancels its timeout', () {
        fakeAsync((clock) {
          final store = Store<int>(initialState: 0);
          final action = _HeldAction();
          store.dispatch(action);
          var completed = false;
          _wait(kind, store, action, 100).then<void>((_) => completed = true);
          expect(clock.nonPeriodicTimerCount, 1);
          action.release();
          clock.flushMicrotasks();
          expect(completed, isTrue);
          expect(clock.nonPeriodicTimerCount, 0);
          clock.elapse(const Duration(seconds: 1));
        });
      });
    });
  }

  group('waitCondition', () {
    test('returns null immediately, but returns the exact later trigger', () async {
      final store = Store<int>(initialState: 0);
      expect(await store.waitCondition((state) => state == 0), isNull);
      final action = _SetState(2);
      final waiting = store.waitCondition((state) => state == 2);
      store.dispatchSync(action, notify: false);
      expect(await waiting, same(action));
    });

    test('initial predicate errors are forwarded without registering a wait', () async {
      final store = Store<int>(initialState: 0);
      final failure = StateError('condition');
      var calls = 0;
      await expectLater(
        store.waitCondition((_) {
          calls++;
          throw failure;
        }),
        throwsA(same(failure)),
      );
      store.dispatchSync(_SetState(1));
      expect(calls, 1);
    });

    for (final expire in [false, true]) {
      test('removes predicate after ${expire ? 'timeout' : 'success'}', () {
        fakeAsync((clock) {
          final store = Store<int>(initialState: 0);
          var calls = 0;
          Object? error;
          final waiting = store.waitCondition((state) {
            calls++;
            return state == 1;
          }, timeoutMillis: 10);
          waiting.then<void>((_) {}, onError: (Object value) => error = value);
          if (expire) {
            clock.elapse(const Duration(milliseconds: 10));
            expect(error, isA<TimeoutException>());
          } else {
            store.dispatchSync(_SetState(1));
            clock.flushMicrotasks();
          }
          final previousCalls = calls;
          store.dispatchSync(_SetState(2));
          clock.flushMicrotasks();
          expect(calls, previousCalls);
        });
      });
    }

    test(
      'independent simultaneous predicates resolve only their own conditions',
      () async {
        final store = Store<int>(initialState: 0);
        var secondCompleted = false;
        final first = store.waitCondition((state) => state == 1);
        final second = store.waitCondition((state) => state == 2)
          ..then((_) => secondCompleted = true);
        final firstAction = _SetState(1);
        store.dispatchSync(firstAction);
        expect(await first, same(firstAction));
        expect(secondCompleted, isFalse);
        final secondAction = _SetState(2);
        store.dispatchSync(secondAction);
        expect(await second, same(secondAction));
        expect(secondCompleted, isTrue);
      },
    );
  });

  group('waitActionCondition', () {
    test('initial call receives immutable actions and null trigger', () async {
      final store = Store<int>(initialState: 0);
      final action = _HeldAction();
      final dispatch = store.dispatchAndWait(action);
      final result = await store.waitActionCondition((actions, trigger) {
        expect(actions, [same(action)]);
        expect(trigger, isNull);
        expect(() => actions.clear(), throwsUnsupportedError);
        return true;
      }, completeImmediately: true);
      expect(result.$1, [same(action)]);
      expect(result.$2, isNull);
      expect(() => result.$1.add(_HeldAction()), throwsUnsupportedError);
      action.release();
      await dispatch;
    });

    test('custom immediate error and predicate exception are synchronous', () {
      final store = Store<int>(initialState: 0);
      expect(
        () => store.waitActionCondition(
          (_, _) => true,
          completedErrorMessage: 'custom condition',
        ),
        throwsA(
          isA<StoreException>().having(
            (error) => error.toString(),
            'message',
            contains('custom condition'),
          ),
        ),
      );
      final error = StateError('predicate');
      expect(
        () => store.waitActionCondition((_, _) => throw error),
        throwsA(same(error)),
      );
    });

    test('separate waiters observe entry and exit of the exact action', () async {
      final store = Store<int>(initialState: 0);
      final action = _HeldAction();
      final entered = store.waitActionCondition(
        (actions, trigger) => identical(trigger, action) && actions.contains(action),
      );
      final exited = store.waitActionCondition(
        (actions, trigger) => identical(trigger, action) && !actions.contains(action),
      );
      final dispatch = store.dispatchAndWait(action);
      final entry = await entered;
      expect(entry.$2, same(action));
      expect(entry.$1, [same(action)]);
      action.release();
      final exit = await exited;
      expect(exit.$2, same(action));
      expect(exit.$1, isEmpty);
      await dispatch;
    });

    for (final expire in [false, true]) {
      test('removes action predicate after ${expire ? 'timeout' : 'success'}', () {
        fakeAsync((clock) {
          final store = Store<int>(initialState: 0);
          var calls = 0;
          Object? error;
          store
              .waitActionCondition((actions, trigger) {
                calls++;
                return trigger != null;
              }, timeoutMillis: 10)
              .then<void>((_) {}, onError: (Object value) => error = value);
          if (expire) {
            clock.elapse(const Duration(milliseconds: 10));
            expect(error, isA<TimeoutException>());
          } else {
            store.dispatchSync(_SetState(1));
            clock.flushMicrotasks();
          }
          final previousCalls = calls;
          store.dispatchSync(_SetState(2));
          clock.flushMicrotasks();
          expect(calls, previousCalls);
        });
      });
    }
  });

  for (final form in ['null actions', 'empty actions', 'empty types']) {
    test('$form waits for all actions including ones started later', () async {
      final store = Store<int>(initialState: 0);
      final first = _HeldAction();
      final firstDispatch = store.dispatchAndWait(first);
      final waiting = switch (form) {
        'null actions' => store.waitAllActions(null),
        'empty actions' => store.waitAllActions([]),
        _ => store.waitAllActionTypes([]),
      };
      var completed = false;
      waiting.then((_) => completed = true);
      final later = _OtherHeldAction();
      final laterDispatch = store.dispatchAndWait(later);
      first.release();
      await firstDispatch;
      expect(completed, isFalse);
      later.release();
      await laterDispatch;
      await waiting;
      expect(completed, isTrue);
    });
  }

  test(
    'waitAllActions selects instances, ignores duplicates and absent actions',
    () async {
      final store = Store<int>(initialState: 0);
      final selected = _HeldAction();
      final unrelated = _HeldAction();
      final selectedDispatch = store.dispatchAndWait(selected);
      final unrelatedDispatch = store.dispatchAndWait(unrelated);
      final waiting = store.waitAllActions([selected, selected, _HeldAction()]);
      selected.release();
      await waiting;
      expect(store.actionsInProgress(), [same(unrelated)]);
      unrelated.release();
      await Future.wait([selectedDispatch, unrelatedDispatch]);
    },
  );

  test('waitActionType waits for last exact type, including later instances', () async {
    final store = Store<int>(initialState: 0);
    final first = _HeldAction();
    final subclass = _OtherHeldAction();
    final firstDispatch = store.dispatchAndWait(first);
    final subclassDispatch = store.dispatchAndWait(subclass);
    final waiting = store.waitActionType(_HeldAction);
    var completed = false;
    waiting.then((_) => completed = true);
    final later = _HeldAction();
    final laterDispatch = store.dispatchAndWait(later);
    first.release();
    await firstDispatch;
    expect(completed, isFalse);
    later.release();
    expect(await waiting, same(later));
    expect(store.actionsInProgress(), [same(subclass)]);
    subclass.release();
    await Future.wait([laterDispatch, subclassDispatch]);
  });

  test('waitAllActionTypes ignores duplicates and unrelated types', () async {
    final store = Store<int>(initialState: 0);
    final selected = _HeldAction();
    final unrelated = _OtherHeldAction();
    final selectedDispatch = store.dispatchAndWait(selected);
    final unrelatedDispatch = store.dispatchAndWait(unrelated);
    final waiting = store.waitAllActionTypes([_HeldAction, _HeldAction, String]);
    selected.release();
    await waiting;
    expect(store.actionsInProgress(), [same(unrelated)]);
    unrelated.release();
    await Future.wait([selectedDispatch, unrelatedDispatch]);
  });

  test(
    'immediate action waits reject absence by default and accept it explicitly',
    () async {
      final store = Store<int>(initialState: 0);
      for (final actions in [
        null,
        <ReduxAction<int>>[],
        [_HeldAction()],
      ]) {
        expect(() => store.waitAllActions(actions), throwsA(isA<StoreException>()));
        await store.waitAllActions(actions, completeImmediately: true, timeoutMillis: 0);
      }
      for (final types in [
        <Type>[],
        [_HeldAction],
        [String],
      ]) {
        await expectLater(
          store.waitAllActionTypes(types),
          throwsA(isA<StoreException>()),
        );
        await store.waitAllActionTypes(
          types,
          completeImmediately: true,
          timeoutMillis: 0,
        );
      }
      await expectLater(
        store.waitActionType(_HeldAction),
        throwsA(isA<StoreException>()),
      );
      expect(await store.waitActionType(_HeldAction, completeImmediately: true), isNull);
    },
  );

  for (final failure in [false, true]) {
    test(
      'waitAnyActionTypeFinishes accepts later dispatch and failed=$failure',
      () async {
        final store = Store<int>(initialState: 0);
        var completed = false;
        final waiting = store.waitAnyActionTypeFinishes([_HeldAction, _HeldAction]);
        waiting.then((_) => completed = true);
        final unrelated = _OtherHeldAction();
        final unrelatedDispatch = store.dispatchAndWait(unrelated);
        unrelated.release();
        await unrelatedDispatch;
        expect(completed, isFalse);
        final selected = _HeldAction(failure: failure);
        final selectedDispatch = store.dispatchAndWait(selected);
        await Future<void>.value();
        expect(completed, isFalse);
        selected.release();
        expect(await waiting, same(selected));
        expect(selected.status.isCompleted, isTrue);
        expect(selected.status.isCompletedFailed, failure);
        await selectedDispatch;
      },
    );
  }

  test('waitAnyActionTypeFinishes with no types cannot match and times out', () {
    fakeAsync((clock) {
      final store = Store<int>(initialState: 0);
      Object? error;
      store
          .waitAnyActionTypeFinishes([], timeoutMillis: 2)
          .then<void>(
            (_) => fail('An empty type list cannot match'),
            onError: (Object value) => error = value,
          );
      store.dispatchSync(_SetState(1));
      clock.elapse(const Duration(milliseconds: 2));
      expect(error, isA<TimeoutException>());
    });
  });

  test('progress view is live and immutable; copy is mutable and independent', () async {
    final store = Store<int>(initialState: 0);
    final view = store.actionsInProgress();
    final initialCopy = store.copyActionsInProgress();
    expect(store.actionsInProgressEqualTo({}), isTrue);
    final first = _HeldAction();
    final second = _HeldAction();
    final firstDispatch = store.dispatchAndWait(first);
    final secondDispatch = store.dispatchAndWait(second);
    expect(view, unorderedEquals([same(first), same(second)]));
    expect(initialCopy, isEmpty);
    final copy = store.copyActionsInProgress();
    expect(store.actionsInProgressEqualTo(copy), isTrue);
    expect(() => view.remove(first), throwsUnsupportedError);
    expect(() => view.add(_HeldAction()), throwsUnsupportedError);
    expect(() => view.clear(), throwsUnsupportedError);
    copy.remove(first);
    expect(view.length, 2);
    expect(store.actionsInProgressEqualTo(copy), isFalse);
    copy.add(_HeldAction());
    expect(store.actionsInProgressEqualTo(copy), isFalse);
    first.release();
    await firstDispatch;
    expect(view, [same(second)]);
    expect(copy.length, 2);
    second.release();
    await secondDispatch;
    expect(view, isEmpty);
    expect(copy.length, 2);
    expect(store.actionsInProgressEqualTo({}), isTrue);
  });
}

enum _WaitKind { state, actionCondition, allActions, actionType, allTypes, anyType }

Future<Object?> _wait(
  _WaitKind kind,
  Store<int> store,
  _HeldAction action,
  int? timeoutMillis,
) async {
  switch (kind) {
    case _WaitKind.state:
      return store.waitCondition((state) => state == 1, timeoutMillis: timeoutMillis);
    case _WaitKind.actionCondition:
      return store.waitActionCondition(
        (actions, _) => actions.isEmpty,
        timeoutMillis: timeoutMillis,
      );
    case _WaitKind.allActions:
      await store.waitAllActions([action], timeoutMillis: timeoutMillis);
      return null;
    case _WaitKind.actionType:
      return store.waitActionType(_HeldAction, timeoutMillis: timeoutMillis);
    case _WaitKind.allTypes:
      await store.waitAllActionTypes([_HeldAction], timeoutMillis: timeoutMillis);
      return null;
    case _WaitKind.anyType:
      return store.waitAnyActionTypeFinishes([_HeldAction], timeoutMillis: timeoutMillis);
  }
}

class _HeldAction extends ReduxAction<int> {
  final _gate = Completer<void>();
  final bool failure;

  _HeldAction({this.failure = false});

  void release() => _gate.complete();

  @override
  Future<int> reduce() async {
    await _gate.future;
    if (failure) throw const UserException('held failure').noDialog;
    return state + 1;
  }
}

class _OtherHeldAction extends _HeldAction {}

class _SetState extends ReduxAction<int> {
  final int value;

  _SetState(this.value);

  @override
  int reduce() => value;
}
