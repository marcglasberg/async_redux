import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:flutter_test/flutter_test.dart';

// Invalid overrides below are intentional runtime validation fixtures.
// ignore_for_file: async_redux_lints/reduce_return_type

void main() {
  for (final asyncReducer in [false, true]) {
    for (final enabled in [false, true]) {
      for (final resultKind in ['null', 'identical', 'equal', 'changed']) {
        test('global wrapper: async=$asyncReducer, enabled=$enabled, '
            'result=$resultKind', () async {
          final initial = _State(0);
          final result = switch (resultKind) {
            'null' => null,
            'identical' => initial,
            'equal' => _State(0),
            _ => _State(1),
          };
          final wrapper = _Wrapper(enabled);
          final store = Store<_State>(initialState: initial, wrapReduce: wrapper);
          final action = asyncReducer ? _Async(result) : _Sync(result);
          final status = await store.dispatch(action);
          final processed = enabled && (resultKind == 'equal' || resultKind == 'changed');
          expect(wrapper.calls, processed ? [(initial, result)] : []);
          expect(store.state, same(processed ? wrapper.output : result ?? initial));
          expect(status.isCompletedOk, isTrue);
          expect(action.calls, 1);
          await store.teardown();
        });
      }
    }
  }

  test(
    'action wrapper surrounds the global wrapper and its transformed result',
    () async {
      final events = <String>[];
      final store = Store<_State>(
        initialState: _State(0),
        wrapReduce: _Wrapper(true, events: events),
      );
      final action = _ActionWrapper(events);
      await store.dispatchAndWait(action);
      expect(events, ['action:start', 'reduce', 'global:0->1', 'action:end:10']);
      expect(store.state.value, 110);
      expect(action.calls, 1);
      await store.teardown();
    },
  );

  test('global async wrapper sees state at completion, not at dispatch', () async {
    final wrapper = _Wrapper(true);
    final initial = _State(0);
    final store = Store<_State>(initialState: initial, wrapReduce: wrapper);
    final gate = Completer<void>();
    final action = _Async(_State(5), gate: gate.future);
    final future = store.dispatchAndWait(action);
    // A concurrent dispatch changes the state through the same global wrapper.
    store.dispatchSync(_Sync(_State(2)));
    final concurrent = store.state;
    gate.complete();
    await future;
    expect(wrapper.calls, [(initial, _State(2)), (concurrent, _State(5))]);
    expect(store.state.value, 50);
    await store.teardown();
  });

  for (final invalidActionWrapper in [false, true]) {
    test(
      'invalid ${invalidActionWrapper ? 'action' : 'global'} wrapper finalizes',
      () async {
        final store = Store<_State>(
          initialState: _State(0),
          wrapReduce: invalidActionWrapper ? null : _InvalidGlobalWrapper(),
        );
        final action = invalidActionWrapper ? _InvalidActionWrapper() : _Sync(_State(1));
        await expectLater(
          Future.sync(() => store.dispatch(action)),
          throwsA(isA<StoreException>()),
        );
        expect(action.calls, 0);
        expect(action.status.hasFinishedMethodBefore, isTrue);
        expect(action.status.hasFinishedMethodReduce, isFalse);
        expect(action.status.isCompletedFailed, isTrue);
        expect(store.reduceCount, 1);
        expect(store.state.value, 0);
        expect(store.actionsInProgress(), isEmpty);
        await store.teardown();
      },
    );
  }

  for (final asyncReducer in [false, true]) {
    test(
      'a global wrapper error follows the action error pipeline, async=$asyncReducer',
      () async {
        final error = StateError('global wrapper');
        final store = Store<_State>(
          initialState: _State(0),
          wrapReduce: _Wrapper(true, error: error),
        );
        final action = asyncReducer ? _Async(_State(1)) : _Sync(_State(1));
        await expectLater(
          Future.sync(() => store.dispatch(action)),
          throwsA(same(error)),
        );
        expect(action.calls, 1);
        expect(action.status.originalError, same(error));
        expect(action.status.wrappedError, same(error));
        expect(action.status.isCompletedFailed, isTrue);
        expect(store.state.value, 0);
        expect(store.actionsInProgress(), isEmpty);
        await store.teardown();
      },
    );
  }
}

class _State {
  _State(this.value);

  final int value;

  @override
  bool operator ==(Object other) => other is _State && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

abstract class _Base extends ReduxAction<_State> {
  _Base(this.result);

  final _State? result;
  int calls = 0;
}

class _Sync extends _Base {
  _Sync(super.result);

  @override
  _State? reduce() {
    calls++;
    return result;
  }
}

class _Async extends _Base {
  _Async(super.result, {this.gate});

  final Future<void>? gate;

  @override
  Future<_State?> reduce() async {
    await (gate ?? microtask);
    calls++;
    return result;
  }
}

class _ActionWrapper extends _Base {
  _ActionWrapper(this.events) : super(null);

  final List<String> events;

  @override
  Future<_State?> reduce() async {
    await microtask;
    events.add('reduce');
    calls++;
    return _State(1);
  }

  @override
  Future<_State?> wrapReduce(Reducer<_State> reduce) async {
    events.add('action:start');
    final result = await reduce();
    events.add('action:end:${result!.value}');
    return _State(result.value + 100);
  }
}

class _Wrapper extends WrapReduce<_State> {
  _Wrapper(this.enabled, {this.events, this.error});

  final bool enabled;
  final List<String>? events;
  final Object? error;
  final calls = <(_State, _State)>[];
  _State? output;

  @override
  bool ifShouldProcess() => enabled;

  @override
  _State process({required _State oldState, required _State newState}) {
    calls.add((oldState, newState));
    events?.add('global:${oldState.value}->${newState.value}');
    if (error != null) throw error!;
    return output = _State(newState.value * 10);
  }
}

class _InvalidGlobalWrapper extends _Wrapper {
  _InvalidGlobalWrapper() : super(true);

  @override
  Reducer<_State> wrapReduce(Reducer<_State> reduce, Store<_State> store) {
    FutureOr<_State?> invalid() => null;
    return invalid;
  }
}

class _InvalidActionWrapper extends _Sync {
  _InvalidActionWrapper() : super(_State(1));

  @override
  // ignore: async_redux_lints/wrap_reduce_return_type
  _State? wrapReduce(Reducer<_State> reduce) => null;
}
