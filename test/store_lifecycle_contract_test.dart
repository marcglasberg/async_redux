import 'package:async_redux/async_redux.dart';
import 'package:flutter_test/flutter_test.dart';

// A cross-product of public lifecycle contracts. Expectations are deliberately
// about externally visible order and values, not the store's private methods.
void main() {
  for (final mode in _Mode.values) {
    for (final notify in [false, true]) {
      for (final result in <int?>[null, 0, 1]) {
        test('$mode success, notify=$notify, result=$result', () async {
          final events = <String>[];
          final observed = <_Observation>[];
          final actionObservations = <_ActionObservation>[];
          final local = _Persistor(events, 'local');
          final cloud = _Persistor(events, 'cloud');
          final store = Store<int>(
            initialState: 0,
            syncStream: true,
            stateObservers: [
              _StateObserver(events, 'state1', observed),
              _StateObserver(events, 'state2', observed),
            ],
            actionObservers: [
              _ActionObserver(events, 'action1', actionObservations),
              _ActionObserver(events, 'action2', actionObservations),
            ],
            persistor: local,
            cloudSync: cloud,
          );
          final subscription = store.onChange.listen((state) {
            events.add('stream:$state');
          });
          final action = _action(mode, events)..result = result;
          final snapshots = <String, ActionStatus>{};
          action.onBefore = () {
            snapshots['before'] = action.status;
            expect(store.actionsInProgress(), contains(action));
          };
          action.onReduce = () => snapshots['reduce'] = action.status;
          action.onAfter = () {
            snapshots['after'] = action.status;
            expect(store.actionsInProgress(), contains(action));
            expect(store.state, result ?? 0);
          };

          final dispatchResult = store.dispatch(action, notify: notify);
          if (mode == _Mode.sync) {
            expect(dispatchResult, isA<ActionStatus>());
            expect(action.status.isCompleted, isTrue);
          } else {
            expect(dispatchResult, isA<Future<ActionStatus>>());
            expect(action.status.isCompleted, isFalse);
          }
          final status = await dispatchResult;

          expect(events, [
            'action1:start',
            'action2:start',
            'before',
            if (mode == _Mode.wrapped) 'wrap:start',
            'reduce',
            if (mode == _Mode.wrapped) 'wrap:end',
            if (notify) 'stream:${result ?? 0}',
            'state1',
            'state2',
            if (result == 1) ...['local:0->1', 'cloud:0->1'],
            'after',
            'action1:end',
            'action2:end',
          ]);
          expect(status, same(action.status));
          expect(status.isCompletedOk, isTrue);
          expect(status.isDispatchAborted, isFalse);
          expect(status.originalError, isNull);
          expect(status.wrappedError, isNull);
          expect(snapshots['before']!.isDispatched, isTrue);
          expect(snapshots['before']!.hasFinishedMethodBefore, isFalse);
          expect(snapshots['reduce']!.hasFinishedMethodBefore, isTrue);
          expect(snapshots['reduce']!.hasFinishedMethodReduce, isFalse);
          expect(snapshots['after']!.hasFinishedMethodReduce, isTrue);
          expect(snapshots['after']!.hasFinishedMethodAfter, isFalse);
          expect(observed, hasLength(2));
          for (final observation in observed) {
            expect(observation.action, same(action));
            expect(observation.previous, 0);
            expect(observation.next, result ?? 0);
            expect(observation.error, isNull);
            expect(observation.count, 1);
          }
          expect(actionObservations.map((o) => o.inProgress), [
            false,
            false,
            false,
            false,
          ]);
          expect(actionObservations.map((o) => o.status.isCompleted), [
            false,
            false,
            true,
            true,
          ]);
          expect(store.dispatchCount, 1);
          expect(store.reduceCount, 1);
          expect(store.actionsInProgress(), isEmpty);
          // Persistence is started before after(), but may finish afterwards.
          await store.readStateFromPersistence();
          await store.readStateFromCloudSync();
          expect(local.saved, result ?? 0);
          expect(cloud.saved, result ?? 0);
          await subscription.cancel();
          await store.teardown();
        });
      }
    }
  }

  for (final mode in _Mode.values) {
    for (final stage in ['before', 'reduce']) {
      for (final handling in _Handling.values) {
        test('$mode failure in $stage, $handling', () async {
          final events = <String>[];
          final observations = <_Observation>[];
          final original = StateError('original');
          final replacement = ArgumentError('replacement');
          final trace = StackTrace.fromString('original reducer stack');
          const userError = UserException('user error');
          final abort = AbortDispatchException();
          final action = _action(mode, events);
          final globalObservations = <_GlobalObserver>[];
          final actionObservations = <_ActionObservation>[];
          Object? expected = switch (handling) {
            _Handling.swallowAction || _Handling.swallowGlobal => null,
            _Handling.replaceAction ||
            _Handling.throwAction ||
            _Handling.replaceGlobal ||
            _Handling.throwGlobal => replacement,
            _Handling.user => userError,
            _Handling.noDialog => userError.noDialog,
            _Handling.abort => abort,
            _Handling.propagate => original,
          };
          final store = Store<int>(
            initialState: 0,
            stateObservers: [_StateObserver(events, 'state', observations)],
            actionObservers: [_ActionObserver(events, 'action', actionObservations)],
            persistor: _Persistor(events, 'local'),
            cloudSync: _Persistor(events, 'cloud'),
            globalErrorObserver: (store) {
              events.add('global:factory');
              final observer = _GlobalObserver(() {
                events.add('global');
                if (handling == _Handling.throwGlobal) throw replacement;
                return switch (handling) {
                  _Handling.swallowGlobal => null,
                  _Handling.replaceGlobal => replacement,
                  _ => globalObservations.last.error,
                };
              });
              globalObservations.add(observer);
              return observer;
            },
          );
          void fail() => Error.throwWithStackTrace(original, trace);
          if (stage == 'before') {
            action.onBefore = fail;
          } else {
            action.onReduce = fail;
          }
          action.onWrapError = (error, stack) {
            expect(error, same(original));
            expect(stack.toString(), trace.toString());
            expect(action.status.originalError, same(original));
            if (handling == _Handling.throwAction) throw replacement;
            return switch (handling) {
              _Handling.swallowAction => null,
              _Handling.replaceAction => replacement,
              _Handling.user || _Handling.noDialog || _Handling.abort => expected,
              _ => error,
            };
          };
          action.onAfter = () {
            expect(action.status.originalError, same(original));
            expect(action.status.wrappedError, same(expected));
            expect(store.actionsInProgress(), contains(action));
            // after runs before queuing a dialog or marking an abort.
            expect(store.errors, isEmpty);
            expect(action.status.isDispatchAborted, isFalse);
            expect(
              store.isFailed(action.runtimeType),
              expected != null && expected is! AbortDispatchException,
            );
          };

          Object? thrown;
          StackTrace? thrownStack;
          try {
            await store.dispatch(action);
          } catch (error, stack) {
            thrown = error;
            thrownStack = stack;
          }

          final propagates =
              expected != null &&
              expected is! UserException &&
              expected is! AbortDispatchException;
          expect(thrown, same(propagates ? expected : null));
          if (propagates) expect(thrownStack.toString(), trace.toString());
          expect(events, [
            'action:start',
            'before',
            if (stage == 'reduce') ...[if (mode == _Mode.wrapped) 'wrap:start', 'reduce'],
            'state',
            'wrapError',
            if (handling != _Handling.swallowAction) ...['global:factory', 'global'],
            'after',
            'action:end',
          ]);
          expect(observations, hasLength(1));
          expect(observations.single.error, same(original));
          expect(observations.single.previous, 0);
          expect(observations.single.next, 0);
          for (final global in globalObservations) {
            expect(global.originalError, same(original));
            expect(global.action, same(action));
            expect(global.store, same(store));
            expect(global.stackTrace.toString(), trace.toString());
          }
          expect(action.status.isCompletedFailed, isTrue);
          expect(action.status.hasFinishedMethodBefore, stage == 'reduce');
          expect(action.status.hasFinishedMethodReduce, isFalse);
          expect(action.status.originalError, same(original));
          expect(action.status.wrappedError, same(expected));
          expect(action.status.isDispatchAborted, handling == _Handling.abort);
          expect(store.errors.toList(), handling == _Handling.user ? [expected] : []);
          expect(store.state, 0);
          expect(store.dispatchCount, 1);
          expect(store.reduceCount, stage == 'reduce' ? 1 : 0);
          expect(store.actionsInProgress(), isEmpty);
          expect(actionObservations.last.status, same(action.status));
          await store.teardown();
        });
      }
    }
  }
}

enum _Mode { sync, asyncBefore, asyncReduce, both, wrapped }

enum _Handling {
  propagate,
  replaceAction,
  throwAction,
  swallowAction,
  replaceGlobal,
  throwGlobal,
  swallowGlobal,
  user,
  noDialog,
  abort,
}

_ProbeAction _action(_Mode mode, List<String> events) => switch (mode) {
  _Mode.sync => _SyncAction(events),
  _Mode.asyncBefore => _AsyncBeforeAction(events),
  _Mode.asyncReduce => _AsyncReduceAction(events),
  _Mode.both => _BothAsyncAction(events),
  _Mode.wrapped => _WrappedAction(events),
};

abstract class _ProbeAction extends ReduxAction<int> {
  _ProbeAction(this.events);

  final List<String> events;
  int? result = 1;
  void Function()? onBefore;
  void Function()? onReduce;
  void Function()? onAfter;
  Object? Function(Object, StackTrace)? onWrapError;

  bool get inProgress => store.actionsInProgress().contains(this);

  @override
  void before() {
    events.add('before');
    onBefore?.call();
  }

  int? runReducer() {
    events.add('reduce');
    onReduce?.call();
    return result;
  }

  @override
  void after() {
    events.add('after');
    onAfter?.call();
  }

  @override
  Object? wrapError(Object error, StackTrace stackTrace) {
    events.add('wrapError');
    return onWrapError == null ? error : onWrapError!(error, stackTrace);
  }
}

class _SyncAction extends _ProbeAction {
  _SyncAction(super.events);

  @override
  int? reduce() => runReducer();
}

class _AsyncBeforeAction extends _SyncAction {
  _AsyncBeforeAction(super.events);

  @override
  Future<void> before() async {
    await microtask;
    super.before();
  }
}

class _AsyncReduceAction extends _ProbeAction {
  _AsyncReduceAction(super.events);

  @override
  Future<int?> reduce() async {
    await microtask;
    return runReducer();
  }
}

class _BothAsyncAction extends _AsyncReduceAction {
  _BothAsyncAction(super.events);

  @override
  Future<void> before() async {
    await microtask;
    super.before();
  }
}

class _WrappedAction extends _AsyncReduceAction {
  _WrappedAction(super.events);

  @override
  Future<int?> wrapReduce(Reducer<int> reduce) async {
    events.add('wrap:start');
    final result = await reduce();
    events.add('wrap:end');
    return result;
  }
}

class _Observation {
  _Observation(this.action, this.previous, this.next, this.error, this.count);

  final ReduxAction<int> action;
  final int previous;
  final int next;
  final Object? error;
  final int count;
}

class _StateObserver extends StateObserver<int> {
  _StateObserver(this.events, this.name, this.observations);

  final List<String> events;
  final String name;
  final List<_Observation> observations;

  @override
  void observe(
    ReduxAction<int> action,
    int prevState,
    int newState,
    Object? error,
    int dispatchCount,
  ) {
    events.add(name);
    observations.add(_Observation(action, prevState, newState, error, dispatchCount));
  }
}

class _ActionObservation {
  _ActionObservation(this.status, this.inProgress);

  final ActionStatus status;
  final bool inProgress;
}

class _ActionObserver extends ActionObserver<int> {
  _ActionObserver(this.events, this.name, this.observations);

  final List<String> events;
  final String name;
  final List<_ActionObservation> observations;

  @override
  void observe(ReduxAction<int> action, int dispatchCount, {required bool ini}) {
    events.add('$name:${ini ? 'start' : 'end'}');
    observations.add(
      _ActionObservation(action.status, (action as _ProbeAction).inProgress),
    );
  }
}

class _GlobalObserver extends GlobalErrorObserver<int> {
  _GlobalObserver(this.callback);

  final Object? Function() callback;

  @override
  Object? observe() => callback();
}

class _Persistor extends Persistor<int> {
  _Persistor(this.events, this.name);

  final List<String> events;
  final String name;
  int saved = 0;

  @override
  Duration? get throttle => null;

  @override
  Future<void> persistDifference({
    required int? lastPersistedState,
    required int newState,
  }) async {
    events.add('$name:$lastPersistedState->$newState');
    saved = newState;
  }

  @override
  Future<int?> readState() async => saved;

  @override
  Future<void> deleteState() async => saved = 0;
}
