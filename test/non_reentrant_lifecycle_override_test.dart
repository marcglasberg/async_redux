import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final callSuper in [false, true]) {
    for (final fail in [false, true]) {
      test('custom lifecycle: callSuper=$callSuper, fail=$fail', () async {
        final store = Store<int>(initialState: 0);
        addTearDown(store.teardown);
        final gate = Completer<void>();
        final first = _Action(callSuper: callSuper, fail: fail, gate: gate.future);
        final pending = store.dispatchAndWait(first);
        final duplicate = _Action(callSuper: callSuper);
        expect((await store.dispatchAndWait(duplicate)).isDispatchAborted, isTrue);
        expect(duplicate.events, ['abort']);
        expect(store.dispatchCount, 1);
        expect(store.internalMixinProps.nonReentrantKeySet, hasLength(1));
        gate.complete();
        await pending;
        expect(first.events, [
          'abort',
          'before',
          'wrapReduce',
          'reduce',
          if (fail) 'wrapError',
          'after',
        ]);
        expect(first.status.isCompleted, isTrue);
        expect(first.status.isCompletedOk, !fail);
        expect(first.status.wrappedError, isNull); // wrapError swallows the error.
        expect(store.internalMixinProps.nonReentrantKeySet, isEmpty);
        expect((await store.dispatchAndWait(duplicate)).isCompletedOk, isTrue);
        expect(store.state, fail ? 1 : 2);
      });
    }
  }

  test('custom abort after super does not leave a key behind', () async {
    final store = Store<int>(initialState: 0);
    addTearDown(store.teardown);
    final action = _Action(callSuper: true)..abort = true;
    expect((await store.dispatchAndWait(action)).isDispatchAborted, isTrue);
    expect(action.events, ['abort']);
    expect(store.internalMixinProps.nonReentrantKeySet, isEmpty);
    expect((await store.dispatchAndWait(_Action())).isCompletedOk, isTrue);
  });

  test('a throwing after without super still releases its key', () {
    fakeAsync((async) {
      final store = Store<int>(initialState: 0);
      final errors = <Object>[];
      final action = _Action(callSuper: true)..throwAfter = true;
      runZonedGuarded(() {
        store.dispatch(action);
      }, (error, stack) => errors.add(error));
      async.flushMicrotasks();
      async.elapse(Duration.zero);
      expect(errors, hasLength(1));
      expect(errors.single.toString(), contains('after failed'));
      expect(store.internalMixinProps.nonReentrantKeySet, isEmpty);
      final next = _Action();
      store.dispatch(next);
      async.flushMicrotasks();
      expect(next.status.isCompletedOk, isTrue);
      store.teardown();
      async.flushMicrotasks();
    });
  });
}

class _Action extends ReduxAction<int> with NonReentrant {
  _Action({this.callSuper = false, this.fail = false, this.gate});

  final bool callSuper;
  final bool fail;
  final Future<void>? gate;
  final events = <String>[];
  bool abort = false;
  bool throwAfter = false;

  @override
  bool abortDispatch() {
    events.add('abort');
    if (callSuper && super.abortDispatch()) return true;
    return abort;
  }

  @override
  void before() => events.add('before');

  @override
  Future<int?> wrapReduce(Reducer<int> reduce) async {
    events.add('wrapReduce');
    return await reduce();
  }

  @override
  Future<int?> reduce() async {
    events.add('reduce');
    await (gate ?? microtask);
    if (fail) throw StateError('reduce failed');
    return state + 1;
  }

  @override
  Object? wrapError(Object error, StackTrace stackTrace) {
    events.add('wrapError');
    return null;
  }

  @override
  void after() {
    events.add('after');
    // Deliberately exercise Store's cleanup when user code throws here.
    // ignore: async_redux_lints/after_throws
    if (throwAfter) throw StateError('after failed');
    if (callSuper) super.after();
  }
}
