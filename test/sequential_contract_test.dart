import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final create in <_Queued Function()>[_Sync.new, _Async.new]) {
    for (final failure in ['success', 'before', 'reduce', 'abort']) {
      for (final discard in [false, true]) {
        for (final swallow in [false, true]) {
          test('${create().runtimeType} $failure discard=$discard swallow=$swallow', () {
            fakeAsync((async) {
              final store = Store<int>(initialState: 0);
              final first = create()
                ..failure = failure
                ..discard = discard
                ..swallow = swallow;
              final second = create();
              final third = create();
              expect(first.isWaitingInSequentialQueue, isFalse);
              store.dispatch(first);
              store.dispatch(second);
              store.dispatch(third);
              expect(second.isWaitingInSequentialQueue, isTrue);
              expect(third.isWaitingInSequentialQueue, isTrue);
              expect(second.events, ['key']);
              expect(store.internalMixinProps.sequentialQueueMap[null], hasLength(3));
              expect(store.isWaiting(first.runtimeType), isTrue);
              async.flushMicrotasks();
              final discarded = failure != 'success' && discard;
              for (final next in [second, third]) {
                expect(next.isWaitingInSequentialQueue, isFalse);
                expect(next.wasDiscardedFromSequentialQueue, discarded);
                expect(next.status.isDispatchAborted, discarded);
                expect(next.status.hasFinishedMethodAfter, isTrue);
                expect(next.events.contains('reduce'), !discarded);
                expect(next.events.contains('before'), !discarded);
                expect(next.events.last, 'after');
                expect(next.discardCalls, 0);
              }
              expect(first.discardCalls, failure == 'success' ? 0 : 1);
              expect(
                first.status.originalError,
                failure == 'success' ? isNull : same(first.error),
              );
              expect(store.state, (failure == 'success' ? 1 : 0) + (discarded ? 0 : 2));
              expect(store.internalMixinProps.sequentialQueueMap, isEmpty);
              expect(store.isWaiting(first.runtimeType), isFalse);
              store.teardown();
              async.flushMicrotasks();
            });
          });
        }
      }
    }
  }

  test('queue position is reserved before an asynchronous user before', () {
    fakeAsync((async) {
      final store = Store<int>(initialState: 0);
      final gate = Completer<void>();
      final first = _Sync()..beforeGate = gate.future;
      final second = _Async();
      store.dispatch(first);
      store.dispatch(second);
      async.flushMicrotasks();
      expect(first.events, ['key', 'before']);
      expect(second.events, ['key']);
      expect(second.isWaitingInSequentialQueue, isTrue);
      gate.complete();
      async.flushMicrotasks();
      expect(first.events, ['key', 'before', 'reduce', 'after']);
      expect(second.events, ['key', 'before', 'reduce', 'after']);
      expect(store.state, 2);
      expect(store.internalMixinProps.sequentialQueueMap, isEmpty);
      store.teardown();
      async.flushMicrotasks();
    });
  });

  test('captured keys survive mutation and equal record keys share a queue', () {
    fakeAsync((async) {
      final store = Store<int>(initialState: 0);
      final gate = Completer<void>();
      final first = _Sync()
        ..key = ('user', 1)
        ..beforeGate = gate.future;
      final second = _Sync()..key = ('user', 1);
      final independent = _Sync()..key = ('user', 2);
      store.dispatch(first);
      store.dispatch(second);
      store.dispatch(independent);
      first.key = 'changed';
      async.flushMicrotasks();
      expect(second.isWaitingInSequentialQueue, isTrue);
      expect(independent.status.isCompletedOk, isTrue);
      gate.complete();
      async.flushMicrotasks();
      expect(first.keyCalls, 1);
      expect(store.state, 3);
      expect(store.internalMixinProps.sequentialQueueMap, isEmpty);
      store.teardown();
      async.flushMicrotasks();
    });
  });

  for (final failure in ['key', 'after', 'discard']) {
    test('$failure failure cannot strand the next action', () {
      fakeAsync((async) {
        final store = Store<int>(initialState: 0);
        final reported = <Object>[];
        final first = _Sync()
          ..failure = failure == 'discard' ? 'reduce' : failure
          ..throwDiscard = failure == 'discard';
        final next = _Sync();
        runZonedGuarded(() {
          store.dispatch(first);
          store.dispatch(next);
        }, (error, stack) => reported.add(error));
        async.flushMicrotasks();
        async.elapse(Duration.zero);
        expect(next.status.isCompletedOk, isTrue);
        expect(first.status.hasFinishedMethodAfter, isTrue);
        expect(first.events.where((e) => e == 'after'), hasLength(1));
        expect(reported, hasLength(failure == 'key' ? 0 : 1));
        expect(store.internalMixinProps.sequentialQueueMap, isEmpty);
        store.teardown();
        async.flushMicrotasks();
      });
    });
  }

  test('a reset discards waiters without letting an old owner release a new queue', () {
    fakeAsync((async) {
      final store = Store<int>(initialState: 0);
      final oldGate = Completer<void>();
      final newGate = Completer<void>();
      final oldOwner = _Sync()..beforeGate = oldGate.future;
      final oldWaiter = _Sync();
      store.dispatch(oldOwner);
      store.dispatch(oldWaiter);
      store.internalMixinProps.clear();
      final newOwner = _Sync()..beforeGate = newGate.future;
      final newWaiter = _Sync();
      store.dispatch(newOwner);
      store.dispatch(newWaiter);
      oldGate.complete();
      async.flushMicrotasks();
      expect(oldWaiter.wasDiscardedFromSequentialQueue, isTrue);
      expect(newWaiter.isWaitingInSequentialQueue, isTrue);
      expect(store.internalMixinProps.sequentialQueueMap[null], hasLength(2));
      newGate.complete();
      async.flushMicrotasks();
      expect(store.state, 3);
      expect(newWaiter.status.isCompletedOk, isTrue);
      expect(store.internalMixinProps.sequentialQueueMap, isEmpty);
      store.teardown();
      async.flushMicrotasks();
    });
  });
  test('overriding before and after without super still orders and releases', () {
    fakeAsync((async) {
      final store = Store<int>(initialState: 0);
      final gate = Completer<void>();
      final first = _NoSuper()..beforeGate = gate.future;
      final second = _NoSuper();
      store.dispatch(first);
      store.dispatch(second);
      async.flushMicrotasks();
      expect(second.events, ['key']);
      gate.complete();
      async.flushMicrotasks();
      for (final action in [first, second]) {
        expect(action.events, ['key', 'custom before', 'reduce', 'custom after']);
        expect(action.status.isCompletedOk, isTrue);
      }
      expect(store.state, 2);
      expect(store.internalMixinProps.sequentialQueueMap, isEmpty);
      store.teardown();
      async.flushMicrotasks();
    });
  });
}

abstract class _Hooks extends ReduxAction<int> {
  String failure = 'success';
  bool swallow = false;
  Future<void>? beforeGate;
  final events = <String>[];
  late final Object error = failure == 'abort'
      ? AbortDispatchException()
      : const UserException('failure').noDialog;

  @override
  Future<void> before() async {
    events.add('before');
    if (beforeGate != null) await beforeGate;
    if (failure == 'before') throw error;
  }

  @override
  Object? wrapError(Object error, StackTrace stackTrace) => swallow ? null : error;

  @override
  void after() {
    events.add('after');
    if (failure == 'after') throw error;
  }

  int run() {
    events.add('reduce');
    if (failure == 'reduce' || failure == 'abort') throw error;
    return state + 1;
  }
}

abstract class _Queued extends _Hooks with Sequential {
  Object? key;
  int keyCalls = 0;
  bool discard = false;
  bool throwDiscard = false;
  int discardCalls = 0;

  @override
  Object? sequentialKeyParams() {
    keyCalls++;
    events.add('key');
    if (failure == 'key') throw error;
    return key;
  }

  @override
  bool discardQueueOnError(Object error) {
    discardCalls++;
    expect(error, same(this.error));
    if (throwDiscard) throw StateError('discard predicate');
    return discard;
  }
}

class _Sync extends _Queued {
  @override
  int reduce() => run();
}

class _Async extends _Queued {
  @override
  Future<int> reduce() async => run();
}

class _NoSuper extends _Sync {
  @override
  Future<void> before() async {
    events.add('custom before');
    if (beforeGate != null) await beforeGate;
  }

  @override
  void after() => events.add('custom after');
}
