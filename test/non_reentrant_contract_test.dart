import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart' hide Retry;

// These tests characterize NonReentrant before moving its hooks into Store.
// Gates control concurrency without relying on wall-clock delays.
void main() {
  for (final mode in _Mode.values) {
    test('holds the key throughout lifecycle and releases it: $mode', () async {
      final store = _store();
      final action = mode.create();
      final key = action.computeNonReentrantKey();
      final nested = <ActionStatus>[];
      void checkLocked() {
        expect(store.internalMixinProps.nonReentrantKeySet, {key});
        nested.add(store.dispatch(mode.create()) as ActionStatus);
      }

      action.onBefore = checkLocked;
      action.onReduce = checkLocked;
      action.onAfter = checkLocked;
      final result = store.dispatch(action);
      if (mode == _Mode.sync) {
        expect(result, isA<ActionStatus>());
        expect(store.state, 1);
        expect(store.internalMixinProps.nonReentrantKeySet, isEmpty);
      }
      final status = await result;
      expect(status.isCompletedOk, isTrue);
      expect(nested, hasLength(3));
      for (final aborted in nested) {
        _expectAborted(aborted);
      }
      expect(action.events, ['abort', 'key', 'before', 'reduce', 'after']);
      expect(action.keyCalls, 2); // One inspection above and one admission.
      expect(store.dispatchCount, 1);
      expect(store.reduceCount, 1);
      expect(store.actionsInProgress(), isEmpty);
      expect(store.internalMixinProps.nonReentrantKeySet, isEmpty);
      expect((await store.dispatch(mode.create())).isCompletedOk, isTrue);
      expect(store.state, 2);
    });

    for (final stage in ['before', 'reduce']) {
      for (final kind in ['user', 'abort', 'propagate', 'swallow']) {
        test('releases the same key after $kind in $stage: $mode', () async {
          final store = _store();
          final action = mode.create();
          final Object error = switch (kind) {
            'user' => const UserException('failure').noDialog,
            'abort' => AbortDispatchException(),
            _ => StateError('failure'),
          };
          void fail() => throw error;
          if (stage == 'before') {
            action.onBefore = fail;
          } else {
            action.onReduce = fail;
          }
          action.onWrapError = (original) {
            expect(original, same(error));
            _expectAborted(store.dispatch(mode.create()) as ActionStatus);
            return kind == 'swallow' ? null : original;
          };
          action.onAfter = () {
            _expectAborted(store.dispatch(mode.create()) as ActionStatus);
          };

          Object? thrown;
          try {
            await store.dispatch(action);
          } catch (caught) {
            thrown = caught;
          }
          expect(thrown, kind == 'propagate' ? same(error) : isNull);
          expect(action.status.originalError, same(error));
          expect(action.status.isDispatchAborted, kind == 'abort');
          expect(action.events.where((event) => event == 'after'), hasLength(1));
          expect(store.internalMixinProps.nonReentrantKeySet, isEmpty);
          expect(store.actionsInProgress(), isEmpty);
          expect((await store.dispatch(mode.create())).isCompletedOk, isTrue);
          expect(store.state, 1);
        });
      }
    }

    for (final unchanged in ['null', 'identical']) {
      test('releases the key when reduce returns $unchanged: $mode', () async {
        final store = _store();
        final action = mode.create()..result = unchanged;
        expect((await store.dispatch(action)).isCompletedOk, isTrue);
        expect(store.state, 0);
        expect(store.internalMixinProps.nonReentrantKeySet, isEmpty);
        expect((await store.dispatch(mode.create())).isCompletedOk, isTrue);
        expect(store.state, 1);
      });
    }

    test('after errors still release the key: $mode', () {
      fakeAsync((async) {
        final store = Store<int>(initialState: 0);
        final error = StateError('after');
        final uncaught = <Object>[];
        final action = mode.create()..onAfter = () => throw error;
        runZonedGuarded(() {
          store.dispatchAndWait(action);
        }, (caught, stack) => uncaught.add(caught));
        async.flushMicrotasks();
        async.elapse(Duration.zero);
        expect(uncaught, hasLength(1));
        expect(uncaught.single.toString(), contains(error.toString()));
        expect(action.status.isCompletedOk, isTrue);
        expect(store.internalMixinProps.nonReentrantKeySet, isEmpty);
        store.dispatch(mode.create());
        async.flushMicrotasks();
        expect(store.state, 2);
        store.teardown();
        async.flushMicrotasks();
      });
    });

    test('error observer factory failures release the key: $mode', () async {
      final secondary = StateError('factory');
      final store = _store(globalErrorObserver: (_) => throw secondary);
      final action = mode.create()..onReduce = () => throw StateError('reduce');
      Object? thrown;
      try {
        await store.dispatch(action);
      } catch (error) {
        thrown = error;
      }
      expect(thrown, same(secondary));
      expect(action.events.where((event) => event == 'after'), hasLength(1));
      expect(store.internalMixinProps.nonReentrantKeySet, isEmpty);
      expect((await store.dispatch(mode.create())).isCompletedOk, isTrue);
    });
  }

  for (final mode in [_Mode.asyncBefore, _Mode.asyncReduce]) {
    for (final notify in [false, true]) {
      test(
        'duplicates leave the running action untouched: $mode, notify=$notify',
        () async {
          final store = _store();
          final gate = Completer<void>();
          final first = mode.create()..gate = gate.future;
          final pending = store.dispatchAndWait(first, notify: notify);
          final duplicate = mode.create();
          final key = first.computeNonReentrantKey();
          expect(store.isWaiting(first.runtimeType), isTrue);
          final result = store.dispatch(duplicate, notify: notify);
          expect(result, isA<ActionStatus>());
          _expectAborted(result as ActionStatus);
          expect(duplicate.events, ['abort', 'key']);
          expect(store.actionsInProgress(), [first]);
          expect(store.internalMixinProps.nonReentrantKeySet, {key});
          expect(store.dispatchCount, 1);
          expect(store.errors, isEmpty);
          _expectAborted(await store.dispatchAndWait(mode.create()));
          gate.complete();
          expect((await pending).isCompletedOk, isTrue);
          expect(store.isWaiting(first.runtimeType), isFalse);
          expect(store.internalMixinProps.nonReentrantKeySet, isEmpty);
          // An aborted instance can be dispatched again once the key is free.
          expect((await store.dispatchAndWait(duplicate)).isCompletedOk, isTrue);
          expect(duplicate.status.isDispatchAborted, isFalse);
          expect(store.state, 2);
        },
      );
    }
  }

  test('dispatchSync returns the aborted status for a shared running key', () async {
    final store = _store();
    final gate = Completer<void>();
    final pending = store.dispatchAndWait(
      _AsyncAction()
        ..sharedKey = 'shared'
        ..gate = gate.future,
    );
    _expectAborted(store.dispatchSync(_SyncAction()..sharedKey = 'shared'));
    expect(store.dispatchCount, 1);
    gate.complete();
    await pending;
    expect(store.dispatchSync(_SyncAction()..sharedKey = 'shared').isCompletedOk, isTrue);
  });

  test('keys include runtimeType and use parameter equality', () async {
    final store = _store();
    final gate = Completer<void>();
    final first = _AsyncAction()
      ..params = ('item', 1)
      ..gate = gate.future;
    final second = _AsyncAction()
      ..params = ('item', 2)
      ..gate = gate.future;
    final pending = [store.dispatchAndWait(first), store.dispatchAndWait(second)];
    _expectAborted(store.dispatch(_AsyncAction()..params = ('item', 1)) as ActionStatus);
    // Same parameter, different runtimeType: independent default keys.
    expect(store.dispatchSync(_SyncAction()..params = ('item', 1)).isCompletedOk, isTrue);
    expect(store.internalMixinProps.nonReentrantKeySet, hasLength(2));
    gate.complete();
    await Future.wait(pending);
    expect(store.state, 3);
    expect(store.internalMixinProps.nonReentrantKeySet, isEmpty);
  });

  test('finishing one parameter does not release another parameter', () async {
    final store = _store();
    final a = Completer<void>();
    final b = Completer<void>();
    final first = store.dispatchAndWait(
      _AsyncAction()
        ..params = 'A'
        ..gate = a.future,
    );
    final second = store.dispatchAndWait(
      _AsyncAction()
        ..params = 'B'
        ..gate = b.future,
    );
    a.complete();
    await first;
    expect(
      (await store.dispatchAndWait(_AsyncAction()..params = 'A')).isCompletedOk,
      isTrue,
    );
    _expectAborted(store.dispatch(_AsyncAction()..params = 'B') as ActionStatus);
    b.complete();
    await second;
    expect(store.state, 3);
  });

  test('the same key in separate stores is independent', () async {
    final first = _store();
    final second = _store();
    final gate = Completer<void>();
    final pending = [
      first.dispatchAndWait(_AsyncAction()..gate = gate.future),
      second.dispatchAndWait(_AsyncAction()..gate = gate.future),
    ];
    expect(first.actionsInProgress(), hasLength(1));
    expect(second.actionsInProgress(), hasLength(1));
    gate.complete();
    expect((await Future.wait(pending)).every((status) => status.isCompletedOk), isTrue);
    expect(first.state, 1);
    expect(second.state, 1);
  });

  test('the admission key is computed once and retained if parameters change', () async {
    final store = _store();
    final gate = Completer<void>();
    final action = _AsyncAction()
      ..params = 'original'
      ..gate = gate.future;
    final pending = store.dispatchAndWait(action);
    action.params = 'changed';
    _expectAborted(store.dispatch(_AsyncAction()..params = 'original') as ActionStatus);
    expect(
      (await store.dispatchAndWait(_AsyncAction()..params = 'changed')).isCompletedOk,
      isTrue,
    );
    gate.complete();
    await pending;
    expect(action.keyCalls, 1);
    expect(store.internalMixinProps.nonReentrantKeySet, isEmpty);
    expect(
      (await store.dispatchAndWait(_AsyncAction()..params = 'original')).isCompletedOk,
      isTrue,
    );
  });

  for (final abort in ['return', 'throw', 'key', 'shutdown']) {
    test('admission $abort does not run lifecycle or acquire a key', () {
      final store = _store();
      final error = StateError('admission');
      final action = _SyncAction();
      if (abort == 'return') action.onAbort = () => true;
      if (abort == 'throw') action.onAbort = () => throw error;
      if (abort == 'key') action.onKey = () => throw error;
      if (abort == 'shutdown') store.shutdown();
      if (abort == 'throw' || abort == 'key') {
        expect(() => store.dispatchSync(action), throwsA(same(error)));
      } else {
        _expectAborted(store.dispatchSync(action));
      }
      expect(
        action.events,
        abort == 'shutdown' ? [] : ['abort', if (abort == 'key') 'key'],
      );
      expect(action.keyCalls, abort == 'key' ? 1 : 0);
      expect(store.dispatchCount, 0);
      expect(store.reduceCount, 0);
      expect(store.internalMixinProps.nonReentrantKeySet, isEmpty);
    });
  }

  test('observers see the lock at START and its release at END', () async {
    late Store<int> store;
    final phases = <bool>[];
    store = _store(
      actionObservers: [
        _Observer((action, ini) {
          phases.add(ini);
          expect(store.internalMixinProps.nonReentrantKeySet.isNotEmpty, ini);
          if (ini) _expectAborted(store.dispatch(_AsyncAction()) as ActionStatus);
        }),
      ],
    );
    await store.dispatchAndWait(_AsyncAction());
    expect(phases, [true, false]);
    expect(store.dispatchCount, 1);
  });

  test('clearing mixin state permits the same key again', () async {
    final store = _store();
    final gate = Completer<void>();
    final pending = store.dispatchAndWait(_AsyncAction()..gate = gate.future);
    store.internalMixinProps.clear();
    expect((await store.dispatchAndWait(_AsyncAction())).isCompletedOk, isTrue);
    gate.complete();
    await pending;
    expect(store.state, 2);
    expect(store.internalMixinProps.nonReentrantKeySet, isEmpty);
  });

  for (final create in <_RetryAction Function()>[
    _RetryFirst.new,
    _NonReentrantFirst.new,
  ]) {
    for (final fails in [false, true]) {
      test('keeps the key between retries: ${create().runtimeType}, fails=$fails', () {
        fakeAsync((async) {
          final store = Store<int>(initialState: 0);
          final action = create()..alwaysFail = fails;
          store.dispatch(action);
          async.flushMicrotasks();
          expect(action.runs, 1);
          _expectAborted(store.dispatch(create()) as ActionStatus);
          expect(store.internalMixinProps.nonReentrantKeySet, hasLength(1));
          async.elapse(const Duration(milliseconds: 10));
          expect(action.runs, 2);
          expect(action.status.isCompletedFailed, fails);
          expect(store.internalMixinProps.nonReentrantKeySet, isEmpty);
          final next = create();
          store.dispatch(next);
          async.flushMicrotasks();
          async.elapse(const Duration(milliseconds: 10));
          expect(next.status.isCompletedOk, isTrue);
          store.teardown();
          async.flushMicrotasks();
        });
      });
    }
  }

  for (final create in [
    _CheckFirst.new,
    _NonReentrantCheckFirst.new,
    _AbortInternetFirst.new,
    _NonReentrantAbortFirst.new,
  ]) {
    test('internet failure releases the key: ${create().runtimeType}', () async {
      final store = _store()..options.hasConnection = () async => false;
      final failed = create();
      final status = await store.dispatchAndWait(failed);
      expect(status.originalError, isNotNull);
      expect(store.internalMixinProps.nonReentrantKeySet, isEmpty);
      expect(store.state, 0);
      store.options.hasConnection = () async => true;
      expect((await store.dispatchAndWait(create())).isCompletedOk, isTrue);
      expect(store.state, 1);
    });
  }

  test('shutdown during before releases the key without running reduce', () async {
    final store = _store();
    final gate = Completer<void>();
    final action = _AsyncBeforeAction()..gate = gate.future;
    final pending = store.dispatchAndWait(action);
    store.shutdown();
    gate.complete();
    await pending;
    expect(action.events, ['abort', 'key', 'before', 'after']);
    expect(store.state, 0);
    expect(store.internalMixinProps.nonReentrantKeySet, isEmpty);
  });
}

Store<int> _store({
  List<ActionObserver<int>>? actionObservers,
  GlobalErrorObserver<int> Function(Store<int>)? globalErrorObserver,
}) {
  final store = Store<int>(
    initialState: 0,
    actionObservers: actionObservers,
    globalErrorObserver: globalErrorObserver,
  );
  addTearDown(store.teardown);
  return store;
}

void _expectAborted(ActionStatus status) {
  expect(status.isDispatchAborted, isTrue);
  expect(status.isDispatched, isFalse);
  expect(status.hasFinishedMethodBefore, isFalse);
  expect(status.hasFinishedMethodReduce, isFalse);
  expect(status.hasFinishedMethodAfter, isFalse);
  expect(status.originalError, isNull);
  expect(status.wrappedError, isNull);
}

enum _Mode {
  sync,
  asyncBefore,
  asyncReduce;

  _NonReentrantAction create() => switch (this) {
    sync => _SyncAction(),
    asyncBefore => _AsyncBeforeAction(),
    asyncReduce => _AsyncAction(),
  };
}

// Hooks live in the base class so the original mixin calls them before releasing
// its key. Overrides without super are covered separately after the migration.
abstract class _Hooks extends ReduxAction<int> {
  final events = <String>[];
  void Function()? onBefore;
  void Function()? onReduce;
  void Function()? onAfter;
  bool Function()? onAbort;
  Object? Function(Object)? onWrapError;
  Future<void>? gate;
  String? result;

  @override
  bool abortDispatch() {
    events.add('abort');
    return onAbort?.call() ?? false;
  }

  @override
  void before() {
    events.add('before');
    onBefore?.call();
  }

  int? runReduce() {
    events.add('reduce');
    onReduce?.call();
    return switch (result) {
      'null' => null,
      'identical' => state,
      _ => state + 1,
    };
  }

  @override
  Object? wrapError(Object error, StackTrace stackTrace) {
    events.add('wrapError');
    return onWrapError == null ? error : onWrapError!(error);
  }

  @override
  void after() {
    events.add('after');
    onAfter?.call();
  }
}

abstract class _NonReentrantAction extends _Hooks with NonReentrant {
  Object? params;
  Object? sharedKey;
  void Function()? onKey;
  int keyCalls = 0;

  @override
  Object? nonReentrantKeyParams() => params;

  @override
  Object computeNonReentrantKey() {
    keyCalls++;
    // Explicit inspections in a test must not appear in the lifecycle log.
    if (events.isNotEmpty) events.add('key');
    onKey?.call();
    return sharedKey ?? super.computeNonReentrantKey();
  }
}

class _SyncAction extends _NonReentrantAction {
  @override
  int? reduce() => runReduce();
}

class _AsyncAction extends _NonReentrantAction {
  @override
  Future<int?> reduce() async {
    await (gate ?? microtask);
    return runReduce();
  }
}

class _AsyncBeforeAction extends _NonReentrantAction {
  @override
  Future<void> before() async {
    await (gate ?? microtask);
    super.before();
  }

  @override
  int? reduce() => runReduce();
}

class _Observer extends ActionObserver<int> {
  _Observer(this.callback);

  final void Function(ReduxAction<int>, bool) callback;

  @override
  void observe(ReduxAction<int> action, int dispatchCount, {required bool ini}) =>
      callback(action, ini);
}

abstract class _RetryAction extends ReduxAction<int> {
  int runs = 0;
  bool alwaysFail = false;

  @override
  Future<int?> reduce() async {
    await microtask;
    if (++runs == 1 || alwaysFail) throw const UserException('retry').noDialog;
    return state + 1;
  }
}

class _RetryFirst extends _RetryAction with Retry, NonReentrant {
  @override
  int get maxRetries => 1;

  @override
  Duration get initialDelay => const Duration(milliseconds: 10);
}

class _NonReentrantFirst extends _RetryAction with NonReentrant, Retry {
  @override
  int get maxRetries => 1;

  @override
  Duration get initialDelay => const Duration(milliseconds: 10);
}

abstract class _InternetAction extends ReduxAction<int> {
  @override
  Future<int?> reduce() async {
    await microtask;
    return state + 1;
  }
}

class _CheckFirst extends _InternetAction with CheckInternet, NonReentrant {}

class _NonReentrantCheckFirst extends _InternetAction with NonReentrant, CheckInternet {}

class _AbortInternetFirst extends _InternetAction
    with AbortWhenNoInternet, NonReentrant {}

class _NonReentrantAbortFirst extends _InternetAction
    with NonReentrant, AbortWhenNoInternet {}
