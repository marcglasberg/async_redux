import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final create in <_Config Function()>[_Sync.new, _Async.new]) {
    for (final stage in ['success', 'before', 'reduce']) {
      for (final remove in [false, true]) {
        test('${create().runtimeType}: $stage, removeOnError=$remove', () async {
          final store = _store();
          final action = create()
            ..failure = stage
            ..removeOnError = remove;
          action.onAfter = () {
            expect(store.internalMixinProps.throttleLockMap, contains(null));
            expect((store.dispatch(create()) as ActionStatus).isDispatchAborted, isTrue);
          };
          final result = store.dispatch(action);
          if (action is _Sync) expect(result, isA<ActionStatus>());
          await result;
          final failed = stage != 'success';
          expect(action.status.isCompletedFailed, failed);
          expect(action.events, [
            'abort',
            'key',
            'before',
            if (stage != 'before') 'reduce',
            'after',
          ]);
          expect(store.dispatchCount, 1);
          expect(store.actionsInProgress(), isEmpty);
          expect(store.internalMixinProps.throttleLockMap.isEmpty, failed && remove);
          final next = await store.dispatchAndWait(create());
          expect(next.isDispatchAborted, !(failed && remove));
        });
      }
    }

    for (final ttl in [-1, 0]) {
      test('${create().runtimeType}: nonpositive period $ttl leaves no lock', () async {
        final store = _store();
        await store.dispatchAndWait(create()..period = ttl);
        expect(store.internalMixinProps.throttleLockMap, isEmpty);
        expect((await store.dispatchAndWait(create())).isCompletedOk, isTrue);
      });
    }

    test('${create().runtimeType}: custom admission abort leaves no lock', () async {
      final store = _store();
      final action = create()..abort = true;
      expect((await store.dispatchAndWait(action)).isDispatchAborted, isTrue);
      expect(action.events, ['abort']);
      expect(store.internalMixinProps.throttleLockMap, isEmpty);
      expect(store.dispatchCount, 0);
    });

    test('${create().runtimeType}: swallowed errors still remove the lock', () async {
      final store = _store();
      final action = create()
        ..failure = 'reduce'
        ..swallow = true
        ..removeOnError = true;
      await store.dispatchAndWait(action);
      expect(action.status.originalError, isNotNull);
      expect(action.status.wrappedError, isNull);
      expect(store.internalMixinProps.throttleLockMap, isEmpty);
    });
  }

  test('ignoreThrottle replaces the expiry; ordinary duplicates do not extend it', () {
    final store = _store();
    final locks = store.internalMixinProps.throttleLockMap;
    store.dispatchSync(_Sync());
    final first = locks[null];
    expect(store.dispatchSync(_Sync()).isDispatchAborted, isTrue);
    expect(locks[null], same(first));
    expect(store.dispatchSync(_Sync()..ignore = true).isCompletedOk, isTrue);
    expect(identical(locks[null], first), isFalse);
    expect(store.dispatchSync(_Sync()).isDispatchAborted, isTrue);
    expect(store.state, 2);
  });

  test('expired locks are replaced and pruned; live independent locks survive', () {
    final store = _store();
    final locks = store.internalMixinProps.throttleLockMap;
    locks[null] = DateTime.utc(2000);
    locks['expired'] = DateTime.utc(2000);
    locks['live'] = DateTime.utc(9999);
    expect(store.dispatchSync(_Sync()).isCompletedOk, isTrue);
    expect(locks.keys, unorderedEquals([null, 'live']));
    expect(locks[null]!.isUtc, isTrue);
    expect(locks[null]!.isAfter(DateTime.now()), isTrue);
  });

  test('removeLock and removeAllLocks permit dispatch immediately', () {
    final store = _store();
    final action = _Sync();
    store.dispatchSync(action);
    store.dispatchSync(_Sync()..key = 'other');
    action.removeLock();
    expect(store.internalMixinProps.throttleLockMap.keys, ['other']);
    expect(store.dispatchSync(_Sync()).isCompletedOk, isTrue);
    action.removeAllLocks();
    expect(store.internalMixinProps.throttleLockMap, isEmpty);
    expect(store.dispatchSync(_Sync()..key = 'other').isCompletedOk, isTrue);
  });

  test('failure releases the acquired key even if lockBuilder later changes', () async {
    final store = _store();
    final gate = Completer<void>();
    final action = _Async()
      ..key = 'original'
      ..gate = gate.future
      ..failure = 'reduce'
      ..removeOnError = true;
    final pending = store.dispatchAndWait(action);
    action.key = 'changed';
    store.dispatchSync(_Sync()..key = 'changed');
    gate.complete();
    await pending;
    expect(store.internalMixinProps.throttleLockMap.keys, ['changed']);
  });

  test(
    'a lock of equal timestamp but different identity belongs to a newer run',
    () async {
      final store = _store();
      final gate = Completer<void>();
      final action = _Async()
        ..gate = gate.future
        ..failure = 'reduce'
        ..removeOnError = true;
      final pending = store.dispatchAndWait(action);
      final locks = store.internalMixinProps.throttleLockMap;
      final original = locks[null]!;
      final newer = DateTime.fromMicrosecondsSinceEpoch(
        original.microsecondsSinceEpoch,
        isUtc: true,
      );
      expect(newer, original);
      expect(identical(newer, original), isFalse);
      locks[null] = newer;
      gate.complete();
      await pending;
      expect(locks[null], same(newer));
    },
  );

  for (final failReduce in [false, true]) {
    test('throwing after still performs cleanup: reducer failed=$failReduce', () {
      fakeAsync((async) {
        final store = Store<int>(initialState: 0);
        final errors = <Object>[];
        final action = _Sync()
          ..failure = failReduce ? 'reduce' : 'success'
          ..removeOnError = true
          ..onAfter = () => throw StateError('after');
        runZonedGuarded(
          () => store.dispatch(action),
          (error, stack) => errors.add(error),
        );
        async.flushMicrotasks();
        async.elapse(Duration.zero);
        expect(errors, hasLength(1));
        expect(store.internalMixinProps.throttleLockMap.isEmpty, failReduce);
        expect(action.status.hasFinishedMethodAfter, isTrue);
        store.teardown();
        async.flushMicrotasks();
      });
    });
  }

  test('custom abortDispatch and after without super keep throttling and cleanup', () {
    final store = _store();
    final failed = _Custom()
      ..failure = 'reduce'
      ..removeOnError = true;
    store.dispatchSync(failed);
    expect(failed.events, ['custom abort', 'key', 'before', 'reduce', 'custom after']);
    expect(store.internalMixinProps.throttleLockMap, isEmpty);
    final next = _Custom();
    expect(store.dispatchSync(next).isCompletedOk, isTrue);
    expect(store.dispatchSync(_Custom()).isDispatchAborted, isTrue);
  });
}

Store<int> _store() {
  final store = Store<int>(initialState: 0);
  addTearDown(store.teardown);
  return store;
}

abstract class _Hooks extends ReduxAction<int> {
  final events = <String>[];
  String failure = 'success';
  bool abort = false;
  bool swallow = false;
  Future<void>? gate;
  void Function()? onAfter;

  @override
  bool abortDispatch() {
    events.add('abort');
    return abort;
  }

  @override
  void before() {
    events.add('before');
    if (failure == 'before') throw const UserException('before').noDialog;
  }

  int runReduce() {
    events.add('reduce');
    if (failure == 'reduce') throw const UserException('reduce').noDialog;
    return state + 1;
  }

  @override
  Object? wrapError(Object error, StackTrace stackTrace) => swallow ? null : error;

  @override
  void after() {
    events.add('after');
    onAfter?.call();
  }
}

abstract class _Config extends _Hooks with Throttle {
  Object? key;
  int period = 100000;
  bool ignore = false;
  bool removeOnError = false;

  @override
  Object? lockBuilder() {
    events.add('key');
    return key;
  }

  @override
  int get throttle => period;

  @override
  bool get ignoreThrottle => ignore;

  @override
  bool get removeLockOnError => removeOnError;
}

class _Sync extends _Config {
  @override
  int reduce() => runReduce();
}

class _Async extends _Config {
  @override
  Future<int> reduce() async {
    await (gate ?? microtask);
    return runReduce();
  }
}

class _Custom extends _Sync {
  @override
  bool abortDispatch() {
    events.add('custom abort');
    return false;
  }

  @override
  void after() => events.add('custom after');
}
