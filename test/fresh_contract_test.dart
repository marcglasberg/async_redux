import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final create in <_Config Function()>[_Sync.new, _Async.new]) {
    for (final previous in ['absent', 'stale', 'live']) {
      for (final ignore in [false, true]) {
        for (final failure in ['success', 'before', 'reduce']) {
          test('${create().runtimeType}: $previous, ignore=$ignore, $failure', () async {
            final store = _store();
            final map = store.internalMixinProps.freshKeyMap;
            if (previous != 'absent') {
              map['key'] = (DateTime.utc(previous == 'stale' ? 2000 : 9999), Object());
            }
            final original = map['key'];
            final action = create()
              ..ignore = ignore
              ..failure = failure;
            final status = await store.dispatchAndWait(action);
            final aborted = previous == 'live' && !ignore;
            expect(status.isDispatchAborted, aborted);
            expect(status.isCompletedFailed, !aborted && failure != 'success');
            expect(store.dispatchCount, aborted ? 0 : 1);
            expect(action.events, [
              'abort',
              'key',
              if (!aborted) ...['before', if (failure != 'before') 'reduce', 'after'],
            ]);
            expect(store.state, !aborted && failure == 'success' ? 1 : 0);
            if (aborted) {
              expect(map['key'], same(original));
            } else if (failure == 'success') {
              expect(map['key'], isNotNull);
              expect(map['key']!.$1.isUtc, isTrue);
              expect(identical(map['key']!.$2, original?.$2), isFalse);
            } else {
              expect(map, isEmpty); // Restored stale entries are pruned, too.
              expect((await store.dispatchAndWait(create())).isCompletedOk, isTrue);
            }
            expect(store.actionsInProgress(), isEmpty);
          });
        }
      }
    }

    for (final period in [0, -1]) {
      test('${create().runtimeType}: period $period is immediately stale', () async {
        final store = _store();
        await store.dispatchAndWait(create()..period = period);
        expect(store.internalMixinProps.freshKeyMap, isEmpty);
        expect((await store.dispatchAndWait(create())).isCompletedOk, isTrue);
      });
    }

    test(
      '${create().runtimeType}: admission abort neither computes nor changes a key',
      () async {
        final store = _store();
        final original = (DateTime.utc(2000), Object());
        store.internalMixinProps.freshKeyMap['key'] = original;
        final action = create()
          ..abort = true
          ..ignore = true;
        expect((await store.dispatchAndWait(action)).isDispatchAborted, isTrue);
        expect(action.events, ['abort']);
        expect(store.internalMixinProps.freshKeyMap['key'], same(original));
      },
    );

    test(
      '${create().runtimeType}: swallowed reducer failure still rolls back freshness',
      () async {
        final store = _store();
        final action = create()
          ..failure = 'reduce'
          ..swallow = true;
        await store.dispatchAndWait(action);
        expect(action.status.originalError, isNotNull);
        expect(action.status.wrappedError, isNull);
        expect(store.internalMixinProps.freshKeyMap, isEmpty);
      },
    );
  }

  test('key mutation during reduce does not change the key rolled back', () async {
    final store = _store();
    final gate = Completer<void>();
    final action = _Async()
      ..gate = gate.future
      ..failure = 'reduce';
    final pending = store.dispatchAndWait(action);
    action.key = 'changed';
    store.dispatchSync(_Sync()..key = 'changed');
    gate.complete();
    await pending;
    expect(store.internalMixinProps.freshKeyMap.keys, ['changed']);
  });

  for (final removeAll in [false, true]) {
    test('manual invalidation does not restore a removed key: all=$removeAll', () {
      final store = _store();
      final map = store.internalMixinProps.freshKeyMap;
      map['unrelated'] = (DateTime.utc(9999), Object());
      final action = _Sync()..failure = 'reduce';
      action.onReduce = removeAll ? action.removeAllKeys : action.removeKey;
      store.dispatchSync(action);
      expect(map.containsKey('key'), isFalse);
      expect(map.containsKey('unrelated'), !removeAll);
      expect(store.dispatchSync(_Sync()).isCompletedOk, isTrue);
    });
  }

  test('expired unrelated keys are pruned without touching live keys', () {
    final store = _store();
    final map = store.internalMixinProps.freshKeyMap;
    final live = (DateTime.utc(9999), Object());
    map['expired'] = (DateTime.utc(2000), Object());
    map['live'] = live;
    store.dispatchSync(_Sync());
    expect(map.keys, unorderedEquals(['live', 'key']));
    expect(map['live'], same(live));
  });

  for (final failReduce in [false, true]) {
    test('throwing after still finishes freshness: reducer failed=$failReduce', () {
      fakeAsync((async) {
        final store = Store<int>(initialState: 0);
        final errors = <Object>[];
        final action = _Sync()
          ..failure = failReduce ? 'reduce' : 'success'
          ..onAfter = () => throw StateError('after');
        runZonedGuarded(
          () => store.dispatch(action),
          (error, stack) => errors.add(error),
        );
        async.flushMicrotasks();
        async.elapse(Duration.zero);
        expect(errors, hasLength(1));
        expect(store.internalMixinProps.freshKeyMap.isEmpty, failReduce);
        expect(action.status.hasFinishedMethodAfter, isTrue);
        store.teardown();
        async.flushMicrotasks();
      });
    });
  }

  for (final create in <_Hooks Function()>[_FreshFirst.new, _SequentialFirst.new]) {
    test('freshness starts at admission while queued: ${create().runtimeType}', () async {
      final store = _store();
      final gate = Completer<void>();
      final blocker = store.dispatchAndWait(_Blocker(gate.future));
      final action = create();
      final pending = store.dispatchAndWait(action);
      expect(store.internalMixinProps.freshKeyMap, contains('key'));
      expect((store.dispatch(create()) as ActionStatus).isDispatchAborted, isTrue);
      expect(action.events.contains('reduce'), isFalse);
      gate.complete();
      await blocker;
      expect((await pending).isCompletedOk, isTrue);
      expect(store.state, 1);
      expect(store.internalMixinProps.sequentialQueueMap, isEmpty);
    });
  }

  test('custom lifecycle without super retains freshness and error rollback', () {
    final store = _store();
    final failed = _Custom()..failure = 'reduce';
    expect(store.dispatchSync(failed).isCompletedFailed, isTrue);
    expect(failed.events, ['custom abort', 'key', 'before', 'reduce', 'custom after']);
    expect(store.internalMixinProps.freshKeyMap, isEmpty);
    expect(store.dispatchSync(_Custom()).isCompletedOk, isTrue);
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
  void Function()? onReduce;
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
    onReduce?.call();
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

abstract class _Config extends _Hooks with Fresh {
  Object key = 'key';
  int period = 100000;
  bool ignore = false;

  @override
  Object computeFreshKey() {
    events.add('key');
    return key;
  }

  @override
  int get freshFor => period;

  @override
  bool get ignoreFresh => ignore;
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

class _FreshFirst extends _Config with Sequential {
  @override
  int reduce() => runReduce();
}

class _SequentialFirst extends _Hooks with Sequential, Fresh {
  @override
  Object computeFreshKey() => 'key';

  @override
  int get freshFor => 100000;

  @override
  int reduce() => runReduce();
}

class _Blocker extends ReduxAction<int> with Sequential {
  _Blocker(this.gate);
  final Future<void> gate;

  @override
  Future<int?> reduce() async {
    await gate;
    return null;
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
