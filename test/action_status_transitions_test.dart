import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart' hide Retry;

// Observe failed and successful dispatch completion in the same probe.
// ignore_for_file: async_redux_lints/then_on_dispatch_and_wait

void main() {
  for (final beforeAsync in [false, true]) {
    for (final reduceAsync in [false, true]) {
      for (final notify in [false, true]) {
        for (final result in <int?>[null, 0, 1]) {
          test(
            'every status field at every success boundary: '
            'before=$beforeAsync reduce=$reduceAsync notify=$notify result=$result',
            () {
              fakeAsync((clock) {
                final action = _create(beforeAsync, reduceAsync)..result = result;
                _exercise(clock, action, beforeAsync, reduceAsync, notify: notify);
              });
            },
          );
        }
      }

      for (final site in ['before', 'reduce']) {
        for (final errorKind in ['ordinary', 'user', 'abort']) {
          for (final route in _Route.values) {
            test('status snapshots during $site error=$errorKind via $route: '
                'before=$beforeAsync reduce=$reduceAsync', () {
              fakeAsync((clock) {
                final action = _create(beforeAsync, reduceAsync)
                  ..failureSite = site
                  ..original = switch (errorKind) {
                    'user' => const UserException('original').noDialog,
                    'abort' => AbortDispatchException(),
                    _ => StateError('original'),
                  }
                  ..route = route;
                _exercise(clock, action, beforeAsync, reduceAsync);
              });
            });
          }
        }
      }

      for (final reduceFails in [false, true]) {
        test('after error preserves all status fields and completes exactly once: '
            'before=$beforeAsync reduce=$reduceAsync failed=$reduceFails', () {
          fakeAsync((clock) {
            final action = _create(beforeAsync, reduceAsync)
              ..afterError = StateError('after failure');
            if (reduceFails) {
              action.failureSite = 'reduce';
              action.original = const UserException('reduce failure').noDialog;
            }
            final uncaught = <Object>[];
            runZonedGuarded(
              () => _exercise(clock, action, beforeAsync, reduceAsync),
              (error, stack) => uncaught.add(error),
            );
            clock.elapse(Duration.zero);
            expect(uncaught, hasLength(1));
            expect(uncaught.single.toString(), contains('after failure'));
            expect(action.status.originalError, same(action.original));
            expect(action.status.wrappedError, same(action.original));
            expect(action.status.hasFinishedMethodAfter, isTrue);
          });
        });
      }
    }
  }

  test(
    'overlapping actions keep independent context, errors and immutable snapshots',
    () {
      fakeAsync((clock) {
        final store = Store<int>(initialState: 0);
        final first = _AsyncBoth();
        final second = _AsyncBoth()
          ..failureSite = 'reduce'
          ..original = const UserException('second').noDialog;
        final firstInitial = first.status;
        final secondInitial = second.status;
        ActionStatus? firstReturned;
        ActionStatus? secondReturned;
        store.dispatchAndWait(first).then((status) => firstReturned = status);
        store.dispatchAndWait(second).then((status) => secondReturned = status);
        final firstPending = first.status;
        final secondPending = second.status;
        second.beforeGate.complete();
        clock.flushMicrotasks();
        second.reduceGate.complete();
        clock.flushMicrotasks();
        _expectStatus(first.status, action: first, store: store);
        _expectStatus(
          secondReturned!,
          before: true,
          after: true,
          original: second.original,
          wrapped: second.original,
          action: second,
          store: store,
        );
        expect(firstReturned, isNull);
        first.beforeGate.complete();
        clock.flushMicrotasks();
        first.reduceGate.complete();
        clock.flushMicrotasks();
        _expectStatus(
          firstReturned!,
          before: true,
          reduce: true,
          after: true,
          action: first,
          store: store,
        );
        expect(second.status, same(secondReturned));
        for (final initial in [firstInitial, secondInitial]) {
          _expectStatus(initial, dispatched: false);
        }
        _expectStatus(firstPending, action: first, store: store);
        _expectStatus(secondPending, action: second, store: store);
        store.teardown();
        clock.flushMicrotasks();
      });
    },
  );

  for (final phase in ['before:enter', 'reduce:enter', 'after']) {
    test('nested dispatch in $phase cannot advance or replace the parent status', () {
      final store = Store<int>(initialState: 0);
      addTearDown(store.teardown);
      final parent = _Sync();
      final child = _Sync()..result = 2;
      ActionStatus? capturedParent;
      parent.onRecord = (label, status) {
        if (label != phase) return;
        capturedParent = status;
        final returned = store.dispatchSync(child);
        expect(parent.status, same(status));
        _expectStatus(
          returned,
          before: true,
          reduce: true,
          after: true,
          action: child,
          store: store,
        );
      };
      final result = store.dispatchSync(parent);
      _expectStatus(
        result,
        before: true,
        reduce: true,
        after: true,
        action: parent,
        store: store,
      );
      _expectStatus(
        capturedParent!,
        before: phase != 'before:enter',
        reduce: phase == 'after',
        action: parent,
        store: store,
      );
      expect(parent.status.context!.$1, same(parent));
      expect(child.status.context!.$1, same(child));
    });
  }

  for (final fails in [false, true]) {
    test(
      'reduce remains unfinished until the entire wrapReduce finishes: fails=$fails',
      () {
        fakeAsync((clock) {
          final action = _Wrapped()..wrapperFails = fails;
          final store = Store<int>(initialState: 0);
          ActionStatus? returned;
          store.dispatchAndWait(action).then((status) => returned = status);
          clock.flushMicrotasks();
          expect(action.labels, contains('reduce:return'));
          expect(action.labels, contains('wrapper:pending'));
          _expectStatus(action.status, before: true, action: action, store: store);
          expect(returned, isNull);
          final pendingSnapshot = action.status;
          action.wrapperGate.complete();
          clock.flushMicrotasks();
          _expectStatus(
            returned!,
            before: true,
            reduce: !fails,
            after: true,
            original: fails ? action.wrapperError : null,
            wrapped: fails ? action.wrapperError : null,
            action: action,
            store: store,
          );
          _expectStatus(pendingSnapshot, before: true, action: action, store: store);
          expect(store.state, fails ? 0 : 1);
          store.teardown();
          clock.flushMicrotasks();
        });
      },
    );
  }

  test('failed redispatch preserves every completed field and saved snapshot', () {
    final store = Store<int>(initialState: 0);
    addTearDown(store.teardown);
    final action = _Sync()
      ..failureSite = 'reduce'
      ..original = const UserException('original').noDialog;
    final finished = store.dispatchSync(action);
    final labels = List.of(action.labels);
    expect(() => store.dispatchSync(action), throwsA(isA<StoreException>()));
    _expectStatus(
      action.status,
      before: true,
      after: true,
      original: action.original,
      wrapped: action.original,
      action: action,
      store: store,
    );
    expect(action.status, finished);
    expect(action.labels, [...labels, 'abort']);
    expect(finished.isCompletedFailed, isTrue);
  });

  test('dispatchSync rejects async action without changing its initial status', () {
    final store = Store<int>(initialState: 0);
    addTearDown(store.teardown);
    for (final action in [_AsyncBefore(), _AsyncReduce(), _AsyncBoth()]) {
      final initial = action.status;
      expect(() => store.dispatchSync(action), throwsA(isA<StoreException>()));
      expect(action.status, same(initial));
      _expectStatus(action.status, dispatched: false);
      expect(action.labels, isEmpty);
    }
  });

  test(
    'an action aborted before dispatch can later succeed without stale abort flags',
    () {
      final store = Store<int>(initialState: 0);
      addTearDown(store.teardown);
      final action = _Sync()..abort = true;
      final aborted = store.dispatchSync(action);
      _expectStatus(
        aborted,
        dispatched: false,
        aborted: true,
        action: action,
        store: store,
      );
      action.abort = false;
      final completed = store.dispatchSync(action);
      _expectStatus(
        completed,
        before: true,
        reduce: true,
        after: true,
        action: action,
        store: store,
      );
      expect(completed, same(action.status));
      _expectStatus(
        aborted,
        dispatched: false,
        aborted: true,
        action: action,
        store: store,
      );
      expect(store.dispatchCount, 1);
    },
  );

  test(
    'abortDispatch exception leaves lifecycle pristine and permits later dispatch',
    () {
      final store = Store<int>(initialState: 0);
      addTearDown(store.teardown);
      final action = _AbortThrows();
      expect(() => store.dispatchSync(action), throwsA(same(action.abortError)));
      final rejected = action.status;
      _expectStatus(rejected, dispatched: false, action: action, store: store);
      expect(store.dispatchCount, 0);
      action.shouldThrow = false;
      final completed = store.dispatchSync(action);
      _expectStatus(
        completed,
        before: true,
        reduce: true,
        after: true,
        action: action,
        store: store,
      );
      _expectStatus(rejected, dispatched: false, action: action, store: store);
    },
  );

  for (final failure in [false, true]) {
    test('wait predicates observe pending and completed status: failure=$failure', () {
      fakeAsync((clock) {
        final store = Store<int>(initialState: 0, syncStream: true);
        final action = _AsyncReduce();
        if (failure) {
          action.failureSite = 'reduce';
          action.original = const UserException('failure').noDialog;
        }
        ActionStatus? entered;
        ActionStatus? exited;
        ActionStatus? statePredicate;
        ActionStatus? awaitedCompletion;
        store.waitActionCondition((actions, trigger) {
          if (!identical(trigger, action) || !actions.contains(action)) return false;
          entered = action.status;
          return true;
        });
        store.waitActionCondition((actions, trigger) {
          if (!identical(trigger, action) || actions.contains(action)) return false;
          exited = action.status;
          return true;
        });
        if (!failure) {
          store
              .waitCondition((state) {
                if (state != 1) return false;
                statePredicate = action.status;
                return true;
              })
              .then((_) => awaitedCompletion = action.status);
        }
        final emissions = <ActionStatus>[];
        final subscription = store.onChange.listen((_) => emissions.add(action.status));
        store.dispatch(action);
        _expectStatus(entered!, action: action, store: store);
        expect(exited, isNull);
        action.reduceGate.complete();
        clock.flushMicrotasks();
        _expectStatus(
          exited!,
          before: true,
          reduce: !failure,
          after: true,
          original: action.original,
          wrapped: action.original,
          action: action,
          store: store,
        );
        if (!failure) {
          _expectStatus(statePredicate!, before: true, action: action, store: store);
          expect(awaitedCompletion, same(action.status));
          expect(emissions, hasLength(1));
          _expectStatus(emissions.single, before: true, action: action, store: store);
        } else {
          expect(emissions, isEmpty);
        }
        subscription.cancel();
        store.teardown();
        clock.flushMicrotasks();
      });
    });
  }

  for (final api in ['dispatchAll', 'dispatchAndWaitAll']) {
    test('$api maintains independent status for every batch item', () {
      fakeAsync((clock) {
        final store = Store<int>(initialState: 0);
        final sync = _Sync();
        final failure = _AsyncReduce()
          ..failureSite = 'reduce'
          ..original = const UserException('batch failure').noDialog;
        final success = _AsyncBoth();
        final actions = <ReduxAction<int>>[sync, failure, success];
        var batchCompleted = false;
        if (api == 'dispatchAll') {
          expect(store.dispatchAll(actions), same(actions));
        } else {
          store.dispatchAndWaitAll(actions).then((value) {
            expect(value, same(actions));
            batchCompleted = true;
          });
        }
        _expectStatus(
          sync.status,
          before: true,
          reduce: true,
          after: true,
          action: sync,
          store: store,
        );
        _expectStatus(failure.status, before: true, action: failure, store: store);
        _expectStatus(success.status, action: success, store: store);
        final finishedSync = sync.status;
        failure.reduceGate.complete();
        clock.flushMicrotasks();
        _expectStatus(
          failure.status,
          before: true,
          after: true,
          original: failure.original,
          wrapped: failure.original,
          action: failure,
          store: store,
        );
        expect(batchCompleted, isFalse);
        success.beforeGate.complete();
        clock.flushMicrotasks();
        _expectStatus(success.status, before: true, action: success, store: store);
        success.reduceGate.complete();
        clock.flushMicrotasks();
        _expectStatus(
          success.status,
          before: true,
          reduce: true,
          after: true,
          action: success,
          store: store,
        );
        expect(sync.status, same(finishedSync));
        expect(batchCompleted, api == 'dispatchAndWaitAll');
        store.teardown();
        clock.flushMicrotasks();
      });
    });
  }

  for (final recovers in [false, true]) {
    test('Retry preserves pending status until final outcome: recovers=$recovers', () {
      fakeAsync((clock) {
        final store = Store<int>(initialState: 0);
        final action = _Retrying()..recovers = recovers;
        ActionStatus? returned;
        store.dispatchAndWait(action).then((status) => returned = status);
        clock.flushMicrotasks();
        expect(action.attemptStatuses, hasLength(1));
        _expectStatus(action.status, before: true, action: action, store: store);
        expect(action.afterCalls, 0);
        clock.elapse(const Duration(milliseconds: 10));
        expect(action.attemptStatuses, hasLength(2));
        _expectStatus(action.status, before: true, action: action, store: store);
        expect(returned, isNull);
        clock.elapse(const Duration(milliseconds: 20));
        expect(action.attemptStatuses, hasLength(3));
        for (final snapshot in action.attemptStatuses) {
          _expectStatus(snapshot, before: true, action: action, store: store);
        }
        final error = recovers ? null : action.errors.last;
        _expectStatus(
          returned!,
          before: true,
          reduce: recovers,
          after: true,
          original: error,
          wrapped: error,
          action: action,
          store: store,
        );
        expect(action.afterCalls, 1);
        expect(action.status, same(returned));
        expect(store.state, recovers ? 1 : 0);
        store.teardown();
        clock.flushMicrotasks();
      });
    });
  }

  for (final skip in [false, true]) {
    test('wrapper recovery or short circuit completes successfully: skip=$skip', () {
      fakeAsync((clock) {
        final store = Store<int>(initialState: 0);
        final action = _RecoveringWrapper()..skip = skip;
        ActionStatus? returned;
        store.dispatchAndWait(action).then((value) => returned = value);
        clock.flushMicrotasks();
        expect(action.reduceCalls, skip ? 0 : 1);
        _expectStatus(
          returned!,
          before: true,
          reduce: true,
          after: true,
          action: action,
          store: store,
        );
        expect(store.state, 7);
        expect(action.wrapErrorCalls, 0);
        expect(store.isFailed(action.runtimeType), isFalse);
        store.teardown();
        clock.flushMicrotasks();
      });
    });
  }
}

void _exercise(
  FakeAsync clock,
  _Probe action,
  bool beforeAsync,
  bool reduceAsync, {
  bool notify = true,
}) {
  final snapshots = <(String, ActionStatus)>[];
  action.onRecord = (label, status) => snapshots.add((label, status));
  final store = Store<int>(
    initialState: 0,
    actionObservers: [_ActionObserver(action)],
    stateObservers: [_StateObserver(action)],
    globalErrorObserver: (_) => _GlobalObserver(action),
  );
  final initial = action.status;
  _expectStatus(initial, dispatched: false);
  ActionStatus? returned;
  Object? thrown;
  try {
    final result = store.dispatch(action, notify: notify);
    if (result is Future<ActionStatus>) {
      result.then<void>((value) => returned = value, onError: (Object e) => thrown = e);
    } else {
      returned = result;
    }
  } catch (error) {
    thrown = error;
  }
  if (beforeAsync) {
    _expectStatus(action.status, action: action, store: store);
    expect(action.labels, ['abort', 'observer:start', 'before:enter']);
    expect(returned, isNull);
  } else if (reduceAsync && action.failureSite != 'before') {
    _expectStatus(action.status, before: true, action: action, store: store);
  }
  clock.flushMicrotasks();
  action.beforeGate.complete();
  clock.flushMicrotasks();
  if (reduceAsync && action.failureSite != 'before') {
    _expectStatus(action.status, before: true, action: action, store: store);
    expect(returned, isNull);
    expect(action.labels, isNot(contains('after')));
  }
  action.reduceGate.complete();
  clock.flushMicrotasks();

  final failed = action.failureSite != null;
  final wrapped = failed ? action.expectedWrapped : null;
  final propagates =
      wrapped != null && wrapped is! UserException && wrapped is! AbortDispatchException;
  expect(thrown, same(propagates ? wrapped : null));
  if (!propagates) expect(returned, same(action.status));
  _expectStatus(
    action.status,
    before: action.failureSite != 'before',
    reduce: !failed,
    after: true,
    aborted: wrapped is AbortDispatchException,
    original: action.original,
    wrapped: wrapped,
    action: action,
    store: store,
  );
  _expectStatus(initial, dispatched: false);
  expect(action.labels.where((label) => label == 'after'), hasLength(1));
  expect(action.labels.last, 'observer:end');
  expect(store.state, failed ? 0 : action.result ?? 0);
  expect(store.actionsInProgress(), isEmpty);

  // Recheck saved immutable objects AFTER dispatch: replacing status must never
  // retroactively mark an earlier snapshot completed or populate its errors.
  for (final (label, status) in snapshots) {
    final errorStage = ['wrapError', 'global', 'after', 'observer:end'].contains(label);
    final wrappedStage = label == 'after' || label == 'observer:end';
    final before = switch (label) {
      'abort' || 'observer:start' || 'before:enter' || 'before:return' => false,
      _ => action.failureSite != 'before',
    };
    _expectStatus(
      status,
      dispatched: label != 'abort',
      before: before,
      reduce: !failed && (label == 'after' || label == 'observer:end'),
      after: label == 'observer:end',
      aborted: label == 'observer:end' && wrapped is AbortDispatchException,
      original: errorStage ? action.original : null,
      wrapped: wrappedStage ? wrapped : null,
      action: action,
      store: store,
    );
  }
  expect(action.labels, [
    'abort',
    'observer:start',
    'before:enter',
    if (action.failureSite != 'before') ...[
      'before:return',
      'reduce:enter',
      if (!failed) 'reduce:return',
    ],
    'observer:state',
    if (failed) ...['wrapError', if (action.route != _Route.localSwallow) 'global'],
    'after',
    'observer:end',
  ]);
  store.teardown();
  clock.flushMicrotasks();
}

void _expectStatus(
  ActionStatus value, {
  bool dispatched = true,
  bool before = false,
  bool reduce = false,
  bool after = false,
  bool aborted = false,
  Object? original,
  Object? wrapped,
  ReduxAction<int>? action,
  Store<int>? store,
}) {
  expect(value.isDispatched, dispatched);
  expect(value.hasFinishedMethodBefore, before);
  expect(value.hasFinishedMethodReduce, reduce);
  expect(value.hasFinishedMethodAfter, after);
  expect(value.isDispatchAborted, aborted);
  expect(value.originalError, same(original));
  expect(value.wrappedError, same(wrapped));
  expect(value.isCompleted, after);
  expect(value.isCompletedOk, after && original == null);
  expect(value.isCompletedFailed, after && original != null);
  if (action == null) {
    expect(value.context, isNull);
  } else {
    expect(value.context!.$1, same(action));
    expect(value.context!.$2, same(store));
  }
}

enum _Route {
  keep,
  localSwallow,
  globalSwallow,
  localReplace,
  globalReplace,
  localThrow,
  globalThrow,
}

abstract class _Probe extends ReduxAction<int> {
  final beforeGate = Completer<void>();
  final reduceGate = Completer<void>();
  final labels = <String>[];
  void Function(String, ActionStatus)? onRecord;
  String? failureSite;
  Object? original;
  Object? afterError;
  int? result = 1;
  bool abort = false;
  _Route route = _Route.keep;
  final localError = const UserException('local replacement').noDialog;
  final globalError = AbortDispatchException();

  Object? get expectedWrapped => switch (route) {
    _Route.localSwallow || _Route.globalSwallow => null,
    _Route.localReplace || _Route.localThrow => localError,
    _Route.globalReplace || _Route.globalThrow => globalError,
    _Route.keep => original,
  };

  void record(String label) {
    labels.add(label);
    onRecord?.call(label, status);
  }

  @override
  bool abortDispatch() {
    record('abort');
    return abort;
  }

  void finishBefore() {
    if (failureSite == 'before') throw original!;
    record('before:return');
  }

  int? finishReduce() {
    if (failureSite == 'reduce') throw original!;
    record('reduce:return');
    return result;
  }

  @override
  void before() {
    record('before:enter');
    finishBefore();
  }

  @override
  void after() {
    record('after');
    // Intentionally verify status finalization when this forbidden hook throws.
    // ignore: async_redux_lints/after_throws
    if (afterError != null) throw afterError!;
  }

  @override
  Object? wrapError(Object error, StackTrace stackTrace) {
    record('wrapError');
    if (route == _Route.localThrow) throw localError;
    return switch (route) {
      _Route.localSwallow => null,
      _Route.localReplace => localError,
      _ => error,
    };
  }
}

mixin _PendingBefore on _Probe {
  @override
  Future<void> before() async {
    record('before:enter');
    await beforeGate.future;
    finishBefore();
  }
}

mixin _PendingReduce on _Probe {
  @override
  Future<int?> reduce() async {
    record('reduce:enter');
    await reduceGate.future;
    return finishReduce();
  }
}

mixin _ImmediateReduce on _Probe {
  @override
  int? reduce() {
    record('reduce:enter');
    return finishReduce();
  }
}

class _Sync = _Probe with _ImmediateReduce;
class _AsyncBefore = _Probe with _PendingBefore, _ImmediateReduce;
class _AsyncReduce = _Probe with _PendingReduce;
class _AsyncBoth = _Probe with _PendingBefore, _PendingReduce;

class _AbortThrows extends _Sync {
  final abortError = StateError('abortDispatch failed');
  bool shouldThrow = true;
  @override
  bool abortDispatch() {
    if (shouldThrow) throw abortError;
    return super.abortDispatch();
  }
}

_Probe _create(bool beforeAsync, bool reduceAsync) =>
    switch ((beforeAsync, reduceAsync)) {
      (false, false) => _Sync(),
      (true, false) => _AsyncBefore(),
      (false, true) => _AsyncReduce(),
      (true, true) => _AsyncBoth(),
    };

class _ActionObserver extends ActionObserver<int> {
  _ActionObserver(this.action);
  final _Probe action;
  @override
  void observe(ReduxAction<int> action, int dispatchCount, {required bool ini}) =>
      this.action.record(ini ? 'observer:start' : 'observer:end');
}

class _StateObserver extends StateObserver<int> {
  _StateObserver(this.action);
  final _Probe action;
  @override
  void observe(
    ReduxAction<int> action,
    int prevState,
    int newState,
    Object? error,
    int dispatchCount,
  ) => this.action.record('observer:state');
}

class _GlobalObserver extends GlobalErrorObserver<int> {
  _GlobalObserver(this.probe);
  final _Probe probe;
  @override
  Object? observe() {
    probe.record('global');
    // Throwing is intentional: status must retain the original and replacement.
    // ignore: async_redux_lints/throw_in_global_error_observer
    if (probe.route == _Route.globalThrow) throw probe.globalError;
    return switch (probe.route) {
      _Route.globalSwallow => null,
      _Route.globalReplace => probe.globalError,
      _ => error,
    };
  }
}

class _Wrapped extends _Sync {
  final wrapperGate = Completer<void>();
  final wrapperError = const UserException('wrapper').noDialog;
  bool wrapperFails = false;
  @override
  Future<int?> wrapReduce(Reducer<int> reduce) async {
    final result = await reduce();
    record('wrapper:pending');
    await wrapperGate.future;
    if (wrapperFails) throw wrapperError;
    return result;
  }
}

// Retry behavior is deliberately isolated from other mixins in this probe.
// ignore: async_redux_lints/retry_without_non_reentrant
class _Retrying extends ReduxAction<int> with Retry<int> {
  bool recovers = false;
  int afterCalls = 0;
  final attemptStatuses = <ActionStatus>[];
  final errors = <UserException>[];
  @override
  Duration get initialDelay => const Duration(milliseconds: 10);
  @override
  int get maxRetries => 2;
  @override
  int reduce() {
    attemptStatuses.add(status);
    if (recovers && attemptStatuses.length == 3) return 1;
    final error = UserException('attempt ${attemptStatuses.length}').noDialog;
    errors.add(error);
    throw error;
  }

  @override
  void after() => afterCalls++;
}

class _RecoveringWrapper extends ReduxAction<int> {
  bool skip = false;
  int reduceCalls = 0;
  int wrapErrorCalls = 0;
  @override
  int reduce() {
    reduceCalls++;
    throw const UserException('recovered inside wrapper').noDialog;
  }

  @override
  Future<int?> wrapReduce(Reducer<int> reduce) async {
    await Future<void>.value();
    if (skip) return 7;
    try {
      return await reduce();
    } on UserException {
      return 7;
    }
  }

  @override
  Object? wrapError(Object error, StackTrace stackTrace) {
    wrapErrorCalls++;
    return error;
  }
}
