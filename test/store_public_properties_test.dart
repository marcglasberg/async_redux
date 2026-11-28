import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Store construction and injected values', () {
    test('defaults are independent and nullable state is preserved', () async {
      final first = Store<int?>(initialState: null);
      final second = Store<int?>(initialState: 2);
      expect(first.state, isNull);
      expect(first.environment, isNull);
      expect(first.configuration, isNull);
      expect(first.dependencies, isNull);
      expect(first.props, isEmpty);
      expect(first.dispatchCount, 0);
      expect(first.reduceCount, 0);
      expect(first.isShutdown, isFalse);
      expect(first.errors, isEmpty);
      expect(first.internalHasErrors, isFalse);
      first.setProp('first', 1);
      expect(second.props, isEmpty);
      await first.teardown();
      await second.teardown();
    });

    test(
      'configuration precedes dependencies and both see the initialized store',
      () async {
        final environment = Object();
        final configuration = Object();
        final dependencies = Object();
        final calls = <String>[];
        final receivedStores = <Store<int>>[];
        final store = Store<int>(
          initialState: 7,
          environment: environment,
          props: {'seed': 10},
          configuration: (store) {
            calls.add('configuration');
            receivedStores.add(store);
            expect(store.state, 7);
            expect(store.environment, same(environment));
            expect(store.configuration, isNull);
            expect(store.dependencies, isNull);
            expect(store.prop<int>('seed'), 10);
            store.setProp('configured', true);
            return configuration;
          },
          dependencies: (store) {
            calls.add('dependencies');
            receivedStores.add(store);
            expect(store.configuration, same(configuration));
            expect(store.environment, same(environment));
            expect(store.dependencies, isNull);
            expect(store.prop<bool>('configured'), isTrue);
            return dependencies;
          },
        );
        expect(calls, ['configuration', 'dependencies']);
        expect(receivedStores, everyElement(same(store)));
        expect(store.environment, same(environment));
        expect(store.configuration, same(configuration));
        expect(store.dependencies, same(dependencies));
        // Reading injected values never invokes a factory again.
        expect(store.configuration, same(configuration));
        expect(store.dependencies, same(dependencies));
        expect(calls, ['configuration', 'dependencies']);
        await store.teardown();
      },
    );

    test('factories may return null and are scoped to each store', () async {
      var calls = 0;
      Object? config(Store<int> store) {
        calls++;
        return null;
      }

      Object? deps(Store<int> store) {
        calls++;
        expect(store.configuration, isNull);
        return null;
      }

      final first = Store<int>(
        initialState: 0,
        configuration: config,
        dependencies: deps,
      );
      final second = Store<int>(
        initialState: 1,
        configuration: config,
        dependencies: deps,
      );
      expect(calls, 4);
      expect(first.configuration, isNull);
      expect(first.dependencies, isNull);
      expect(second.configuration, isNull);
      expect(second.dependencies, isNull);
      await first.teardown();
      await second.teardown();
    });

    for (final failingFactory in ['configuration', 'dependencies']) {
      test('$failingFactory errors escape construction unchanged', () {
        final error = StateError(failingFactory);
        final calls = <String>[];
        expect(
          () => Store<int>(
            initialState: 0,
            configuration: (store) {
              calls.add('configuration');
              if (failingFactory == 'configuration') throw error;
              return 'configuration';
            },
            dependencies: (store) {
              calls.add('dependencies');
              expect(store.configuration, 'configuration');
              throw error;
            },
          ),
          throwsA(same(error)),
        );
        expect(
          calls,
          failingFactory == 'configuration'
              ? ['configuration']
              : ['configuration', 'dependencies'],
        );
      });
    }
  });

  group('Store properties', () {
    test('constructor copies the map, preserving values by reference', () async {
      final value = <int>[1];
      final initial = <Object?, Object?>{'value': value, null: 'null key'};
      final store = Store<int>(initialState: 0, props: initial);
      expect(store.props, isNot(same(initial)));
      expect(store.prop<List<int>>('value'), same(value));
      expect(store.prop<String>(null), 'null key');
      initial['external'] = true;
      initial.remove('value');
      expect(store.props.containsKey('external'), isFalse);
      expect(store.prop<List<int>>('value'), same(value));
      store.setProp('internal', true);
      expect(initial.containsKey('internal'), isFalse);
      value.add(2);
      expect(store.prop<List<int>>('value'), [1, 2]);
      await store.teardown();
    });

    test('props is a live map and setProp replaces values without notifying', () async {
      final store = Store<int>(initialState: 0, syncStream: true);
      final changes = <int>[];
      final subscription = store.onChange.listen(changes.add);
      final props = store.props;
      props['direct'] = 'visible';
      expect(store.prop<String>('direct'), 'visible');
      store.setProp('direct', 42);
      expect(props['direct'], 42);
      store.setProp(null, null);
      expect(props.containsKey(null), isTrue);
      expect(store.prop<Object?>(null), isNull);
      expect(store.props, same(props));
      expect(store.state, 0);
      expect(store.dispatchCount, 0);
      expect(store.reduceCount, 0);
      expect(changes, isEmpty);
      await subscription.cancel();
      await store.teardown();
    });

    test('typed reads reject wrong types and missing non-null values', () async {
      final store = Store<int>(initialState: 0, props: {'value': 42, 'null': null});
      expect(store.prop<int>('value'), 42);
      expect(store.prop<num>('value'), 42);
      expect(store.prop<int?>('missing'), isNull);
      expect(store.prop<int?>('null'), isNull);
      expect(() => store.prop<String>('value'), throwsA(isA<TypeError>()));
      expect(() => store.prop<int>('missing'), throwsA(isA<TypeError>()));
      expect(() => store.prop<int>('null'), throwsA(isA<TypeError>()));
      await store.teardown();
    });

    test('default disposal handles all resources and retains ordinary values', () async {
      final store = Store<int>(initialState: 0);
      final timer = Timer(const Duration(days: 1), () => fail('timer survived disposal'));
      final future = Completer<void>();
      var cancelled = false;
      final controller = StreamController<int>(onCancel: () => cancelled = true);
      final received = <int>[];
      final subscription = controller.stream.listen(received.add);
      final consumer = _Consumer();
      final sink = _Sink();
      const stream = Stream<int>.empty();
      store.props.addAll({
        'timer': timer,
        'future': future.future,
        'subscription': subscription,
        'consumer': consumer,
        'sink': sink,
        'ordinary': 42,
        'null': null,
        'stream': stream,
      });
      store.disposeProps();
      expect(timer.isActive, isFalse);
      expect(cancelled, isTrue);
      expect(consumer.closes, 1);
      expect(sink.closes, 1);
      expect(store.props, {'ordinary': 42, 'null': null, 'stream': stream});
      // Ignoring a Future must handle eventual errors, not merely remove its key.
      future.completeError(StateError('disposed future'));
      controller.add(1);
      await pumpEventQueue();
      expect(received, isEmpty);
      await subscription.cancel();
      store.disposeProps();
      expect(consumer.closes, 1);
      expect(sink.closes, 1);
      await controller.close();
      await store.teardown();
    });

    test(
      'predicate sees original entries and only selected resources are closed',
      () async {
        final retained = _Sink();
        final removed = _Consumer();
        final store = Store<int>(
          initialState: 0,
          props: {'keep': retained, 'remove': removed, 'ordinary': 42, null: null},
        );
        final visited = <Object?, Object?>{};
        store.disposeProps(({key, value}) {
          visited[key] = value;
          return key != 'keep';
        });
        expect(visited, {
          'keep': retained,
          'remove': removed,
          'ordinary': 42,
          null: null,
        });
        expect(retained.closes, 0);
        expect(removed.closes, 1);
        expect(store.props, {'keep': retained});
        store.disposeProps();
        expect(retained.closes, 1);
        await store.teardown();
      },
    );

    test('false predicate retains every value and resource', () async {
      final sink = _Sink();
      final store = Store<int>(initialState: 0, props: {'sink': sink, null: 42});
      store.disposeProps(({key, value}) => false);
      expect(store.props, {'sink': sink, null: 42});
      expect(sink.closes, 0);
      store.disposeProps(({key, value}) => true);
      expect(store.props, isEmpty);
      expect(sink.closes, 1);
      await store.teardown();
    });

    test('disposeProp selects by equality, supports null and is idempotent', () async {
      final removed = _Sink();
      final retained = _Sink();
      final store = Store<int>(
        initialState: 0,
        props: {_Key(1): removed, _Key(2): retained, null: 42},
      );
      store.disposeProp(_Key(1));
      expect(removed.closes, 1);
      expect(retained.closes, 0);
      expect(store.props.containsKey(_Key(1)), isFalse);
      expect(store.prop<_Sink>(_Key(2)), same(retained));
      store.disposeProp(_Key(1));
      store.disposeProp('absent');
      expect(removed.closes, 1);
      store.disposeProp(null);
      expect(store.props.containsKey(null), isFalse);
      store.disposeProps();
      await store.teardown();
    });

    test('predicate and synchronous disposal errors propagate to the caller', () async {
      final error = StateError('cannot dispose');
      final sink = _Sink(error: error);
      final store = Store<int>(initialState: 0, props: {'sink': sink});
      expect(
        () => store.disposeProps(({key, value}) => throw error),
        throwsA(same(error)),
      );
      expect(sink.closes, 0);
      expect(() => store.disposeProp('sink'), throwsA(same(error)));
      expect(store.prop<_Sink>('sink'), same(sink));
      expect(sink.closes, 1);
      store.props.clear();
      await store.teardown();
    });
  });

  group('Store mixin properties', () {
    test('mixin storage is stable per store and isolated between stores', () async {
      final first = Store<int>(initialState: 0);
      final second = Store<int>(initialState: 0);
      final props = first.internalMixinProps;
      expect(first.internalMixinProps, same(props));
      expect(second.internalMixinProps, isNot(same(props)));
      props.nonReentrantKeySet.add('key');
      expect(second.internalMixinProps.nonReentrantKeySet, isEmpty);
      await first.teardown();
      await second.teardown();
    });

    test(
      'clear releases locks, cancels polling, discards queues and clears failures',
      () {
        fakeAsync((async) {
          final store = Store<int>(initialState: 0, props: {'ordinary': 'retained'});
          store.dispatchSync(_Fail());
          expect(store.isFailed(_Fail), isTrue);
          final props = store.internalMixinProps;
          props.throttleLockMap['a'] = DateTime.utc(2020);
          props.freshKeyMap['a'] = (DateTime.utc(2020), Object());
          props.debounceLockMap['a'] = 1;
          props.nonReentrantKeySet.add('a');
          props.optimisticSyncKeySet.add('a');
          props.optimisticSyncWithPushRevisionMap['a'] = (
            localRevision: 1,
            serverRevision: 1,
            isPush: false,
          );
          final timer = Timer(const Duration(seconds: 1), () => fail('poll survived'));
          props.pollingMap['active'] = (id: Object(), timer: timer);
          props.pollingMap['running'] = (id: Object(), timer: null);
          final running = Completer<bool>();
          final waiting = Completer<bool>();
          final loneRunning = Completer<bool>();
          final queue = [running, waiting];
          props.sequentialQueueMap['queue'] = queue;
          props.sequentialQueueMap['lone'] = [loneRunning];
          props.sequentialQueueMap['empty'] = [];
          bool? discarded;
          waiting.future.then((value) => discarded = value);
          props.clear();
          async.flushMicrotasks();
          expect(props.throttleLockMap, isEmpty);
          expect(props.freshKeyMap, isEmpty);
          expect(props.debounceLockMap, isEmpty);
          expect(props.nonReentrantKeySet, isEmpty);
          expect(props.optimisticSyncKeySet, isEmpty);
          expect(props.optimisticSyncWithPushRevisionMap, isEmpty);
          expect(props.pollingMap, isEmpty);
          expect(timer.isActive, isFalse);
          expect(props.sequentialQueueMap, isEmpty);
          expect(discarded, isTrue);
          expect(queue, [running]);
          expect(running.isCompleted, isFalse);
          expect(loneRunning.isCompleted, isFalse);
          expect(store.isFailed(_Fail), isFalse);
          expect(store.exceptionFor(_Fail), isNull);
          expect(store.props, {'ordinary': 'retained'});
          expect(store.errors, hasLength(1));
          expect(store.isShutdown, isFalse);
          props.clear();
          async.elapse(const Duration(seconds: 2));
          store.teardown();
          async.flushMicrotasks();
        });
      },
    );

    test('connectivity callback changes are isolated between stores', () async {
      final first = Store<int>(initialState: 0);
      final second = Store<int>(initialState: 0);
      final secondCheck = second.options.hasConnection;
      var online = false;
      first.options.hasConnection = () async => online;
      expect(await first.options.hasConnection(), isFalse);
      expect(second.options.hasConnection, same(secondCheck));
      online = true;
      expect(await first.options.hasConnection(), isTrue);
      await first.teardown();
      await second.teardown();
    });

    test('actions reread the connectivity callback on each dispatch', () async {
      final store = Store<int>(initialState: 0);
      var online = false;
      var calls = 0;
      store.options.hasConnection = () async {
        calls++;
        return online;
      };
      final failed = await store.dispatchAndWait(_NeedsInternet());
      expect(failed.originalError, isA<UserException>());
      expect(store.state, 0);
      expect(calls, greaterThan(0));
      calls = 0;
      online = true;
      final succeeded = await store.dispatchAndWait(_NeedsInternet());
      expect(succeeded.isCompletedOk, isTrue);
      expect(store.state, 1);
      expect(calls, greaterThan(0));
      calls = 0;
      store.options.hasConnection = () async => false;
      final failedAgain = await store.dispatchAndWait(_NeedsInternet());
      expect(failedAgain.originalError, isA<UserException>());
      expect(store.state, 1);
      expect(calls, 0);
      await store.teardown();
    });
  });
}

class _Sink implements Sink<Object?> {
  final Object? error;
  int closes = 0;

  _Sink({this.error});

  @override
  void add(Object? data) {}

  @override
  void close() {
    closes++;
    if (error != null) throw error!;
  }
}

class _Consumer implements StreamConsumer<Object?> {
  int closes = 0;

  @override
  Future<void> addStream(Stream<Object?> stream) => stream.drain<void>();

  @override
  Future<void> close() async {
    closes++;
  }
}

class _Key {
  final int value;

  _Key(this.value);

  @override
  bool operator ==(Object other) => other is _Key && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class _Fail extends ReduxAction<int> {
  @override
  int reduce() => throw const UserException('failure');
}

class _NeedsInternet extends ReduxAction<int> with CheckInternet {
  @override
  int reduce() => state + 1;
}
