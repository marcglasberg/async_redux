import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

// Exercise supported signatures explicitly, including Null and Future<Null>.
// ignore_for_file: async_redux_lints/reduce_return_type

void main() {
  for (final beforeAsync in [false, true]) {
    for (final kind in _ReturnType.values) {
      for (final api in _Api.values) {
        for (final notify in [false, true]) {
          test('before async=$beforeAsync / $kind / $api / notify=$notify', () {
            fakeAsync((async) {
              final initial = _Value(0);
              final store = Store<_Value>(initialState: initial);
              final action = _create(kind, beforeAsync);
              final synchronous = !beforeAsync && !kind.isAsync;
              final expected = kind.returnsNull ? 0 : 1;
              expect(action.isSync(), synchronous);

              if (api == _Api.dispatchSync && !synchronous) {
                expect(
                  () => _dispatch(store, action, api, notify),
                  throwsA(isA<StoreException>()),
                );
                expect(action.events, isEmpty);
                expect(action.status.isDispatched, isFalse);
                expect(store.state, same(initial));
                expect(store.dispatchCount, 0);
                expect(store.reduceCount, 0);
                expect(store.actionsInProgress(), isEmpty);
                store.teardown();
                async.flushMicrotasks();
                return;
              }

              final result = _dispatch(store, action, api, notify);
              if (synchronous) {
                // A Future returned by dispatchAndWait is a completion handle;
                // it does not turn the action's before/reduce into async methods.
                expect(store.state.value, expected);
                expect(action.stateSeenByAfter, expected);
                expect(action.events, ['before', 'reduce', 'after']);
                expect(action.status.isCompletedOk, isTrue);
                expect(store.actionsInProgress(), isEmpty);
              } else {
                expect(store.state, same(initial));
                expect(action.stateSeenByAfter, isNull);
                expect(action.status.isCompleted, isFalse);
                expect(action.events, beforeAsync ? [] : ['before', 'reduce:start']);
              }
              expect(
                result is Future<ActionStatus>,
                !synchronous || api == _Api.dispatchAndWait,
              );

              if (beforeAsync) {
                action.beforeGate.complete();
                async.flushMicrotasks();
                expect(action.status.hasFinishedMethodBefore, isTrue);
                expect(action.status.hasFinishedMethodReduce, !kind.isAsync);
                expect(store.state.value, kind.isAsync ? 0 : expected);
              }
              if (kind.isAsync) {
                expect(action.status.hasFinishedMethodReduce, isFalse);
                action.reduceGate.complete();
              }
              async.flushMicrotasks();
              expect(store.state.value, expected);
              if (kind.returnsNull) expect(store.state, same(initial));
              expect(action.stateSeenByAfter, expected);
              expect(action.status.isCompletedOk, isTrue);
              expect(action.events, [
                'before',
                if (kind.isAsync) 'reduce:start',
                'reduce',
                'after',
              ]);
              expect(store.dispatchCount, 1);
              expect(store.reduceCount, 1);
              expect(store.actionsInProgress(), isEmpty);
              store.teardown();
              async.flushMicrotasks();
            });
          });
        }
      }
    }
  }

  for (final api in _Api.values) {
    test('$api consecutive sync actions see the preceding update immediately', () {
      fakeAsync((async) {
        final store = Store<_Value>(initialState: _Value(0));
        final first = _SyncValue();
        final second = _SyncValue();
        final laterStates = <int>[];
        scheduleMicrotask(() => laterStates.add(store.state.value));
        final firstResult = _dispatch(store, first, api, true);
        expect(store.state.value, 1);
        expect(first.stateSeenByAfter, 1);
        final secondResult = _dispatch(store, second, api, true);
        expect(store.state.value, 2);
        expect(second.stateSeenByAfter, 2);
        expect(first.status.isCompletedOk, isTrue);
        expect(second.status.isCompletedOk, isTrue);
        expect(firstResult is Future<ActionStatus>, api == _Api.dispatchAndWait);
        expect(secondResult is Future<ActionStatus>, api == _Api.dispatchAndWait);
        expect(laterStates, isEmpty);
        async.flushMicrotasks();
        expect(laterStates, [2]);
        expect(store.state.value, 2);
        store.teardown();
        async.flushMicrotasks();
      });
    });

    for (final phase in ['before', 'reduce', 'after']) {
      test('$api nested sync action in $phase commits before its caller continues', () {
        fakeAsync((async) {
          final store = Store<_Value>(initialState: _Value(0));
          final parent = _SyncValue();
          final child = _SyncValue();
          int? beforeNested;
          int? afterNested;
          void nestedDispatch() {
            beforeNested = store.state.value;
            _dispatch(store, child, api, false);
            afterNested = store.state.value;
            expect(child.status.isCompletedOk, isTrue);
          }

          switch (phase) {
            case 'before':
              parent.beforeCallback = nestedDispatch;
            case 'reduce':
              parent.reduceCallback = nestedDispatch;
            case 'after':
              parent.afterCallback = nestedDispatch;
          }
          _dispatch(store, parent, api, true);
          expect(beforeNested, phase == 'after' ? 1 : 0);
          expect(afterNested, phase == 'after' ? 2 : 1);
          expect(store.state.value, 2);
          expect(parent.status.isCompletedOk, isTrue);
          expect(store.actionsInProgress(), isEmpty);
          expect(store.dispatchCount, 2);
          expect(store.reduceCount, 2);
          async.flushMicrotasks();
          expect(store.state.value, 2);
          store.teardown();
          async.flushMicrotasks();
        });
      });
    }
  }
}

enum _ReturnType {
  syncNull,
  syncValue,
  futureNull,
  futureValue;

  bool get isAsync => this == futureNull || this == futureValue;
  bool get returnsNull => this == syncNull || this == futureNull;
}

enum _Api { dispatch, dispatchSync, dispatchAndWait }

FutureOr<ActionStatus> _dispatch(
  Store<_Value> store,
  _Action action,
  _Api api,
  bool notify,
) => switch (api) {
  _Api.dispatch => store.dispatch(action, notify: notify),
  _Api.dispatchSync => store.dispatchSync(action, notify: notify),
  _Api.dispatchAndWait => store.dispatchAndWait(action, notify: notify),
};

class _Value {
  _Value(this.value);

  final int value;
}

abstract class _Action extends ReduxAction<_Value> {
  final beforeGate = Completer<void>();
  final reduceGate = Completer<void>();
  final events = <String>[];
  int? stateSeenByAfter;
  void Function()? beforeCallback;
  void Function()? reduceCallback;
  void Function()? afterCallback;

  @override
  void before() {
    events.add('before');
    beforeCallback?.call();
  }

  @override
  void after() {
    events.add('after');
    stateSeenByAfter = state.value;
    afterCallback?.call();
  }
}

mixin _FutureBefore on _Action {
  @override
  Future<void> before() async {
    await beforeGate.future;
    super.before();
  }
}

mixin _NullReduce on _Action {
  @override
  Null reduce() {
    events.add('reduce');
    return null;
  }
}

mixin _ValueReduce on _Action {
  @override
  _Value reduce() {
    events.add('reduce');
    reduceCallback?.call();
    return _Value(state.value + 1);
  }
}

mixin _FutureNullReduce on _Action {
  @override
  Future<Null> reduce() async {
    events.add('reduce:start');
    await reduceGate.future;
    events.add('reduce');
    return null;
  }
}

mixin _FutureValueReduce on _Action {
  @override
  Future<_Value> reduce() async {
    events.add('reduce:start');
    await reduceGate.future;
    events.add('reduce');
    return _Value(state.value + 1);
  }
}

class _SyncNull = _Action with _NullReduce;
class _SyncValue = _Action with _ValueReduce;
class _AsyncNull = _Action with _FutureNullReduce;
class _AsyncValue = _Action with _FutureValueReduce;
class _BeforeAsyncSyncNull = _Action with _FutureBefore, _NullReduce;
class _BeforeAsyncSyncValue = _Action with _FutureBefore, _ValueReduce;
class _BeforeAsyncAsyncNull = _Action with _FutureBefore, _FutureNullReduce;
class _BeforeAsyncAsyncValue = _Action with _FutureBefore, _FutureValueReduce;

_Action _create(_ReturnType kind, bool beforeAsync) => switch (kind) {
  _ReturnType.syncNull => beforeAsync ? _BeforeAsyncSyncNull() : _SyncNull(),
  _ReturnType.syncValue => beforeAsync ? _BeforeAsyncSyncValue() : _SyncValue(),
  _ReturnType.futureNull => beforeAsync ? _BeforeAsyncAsyncNull() : _AsyncNull(),
  _ReturnType.futureValue => beforeAsync ? _BeforeAsyncAsyncValue() : _AsyncValue(),
};
