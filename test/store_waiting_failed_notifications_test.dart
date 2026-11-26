import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/waiting_failed_support.dart';

void main() {
  for (final shape in ['list', 'set', 'lazy', 'duplicates']) {
    test('isWaiting registers every type in $shape after an earlier match', () {
      fakeAsync((async) {
        final store = Store<int>(initialState: 0, syncStream: true);
        final a = TrackingAction<int>();
        final b = TrackingAction<String>();
        trackDispatch(store, a, notify: false);
        var notifications = 0;
        final sub = store.onChange.listen((_) => notifications++);
        // Include both an instance and types. The second type must be cached
        // even though the first element already answers the query.
        expect(store.isWaiting(_shape(shape, [a, TrackingAction<String>])), isTrue);
        expect(notifications, 0);
        trackDispatch(store, b, notify: false);
        expect(notifications, 1);
        b.release();
        async.flushMicrotasks();
        expect(notifications, 2);
        expect(store.isWaiting(a), isTrue);
        a.release();
        async.flushMicrotasks();
        expect(notifications, 3);
        sub.cancel();
        store.teardown();
        async.flushMicrotasks();
      });
    });

    for (final method in ['isFailed', 'exceptionFor']) {
      test('$method registers every type in $shape after an earlier match', () {
        fakeAsync((async) {
          final store = Store<int>(initialState: 0, syncStream: true);
          final error = const UserException('a').noDialog;
          trackDispatch(store, SyncTrackingAction<int>(error: error), notify: false);
          var notifications = 0;
          final sub = store.onChange.listen((_) => notifications++);
          expect(
            _query(
              store,
              method,
              _shape(shape, [SyncTrackingAction<int>, SyncTrackingAction<String>]),
            ),
            method == 'isFailed' ? isTrue : same(error),
          );
          expect(notifications, 0);
          trackDispatch(
            store,
            SyncTrackingAction<String>(error: const UserException('b').noDialog),
            notify: false,
          );
          expect(notifications, 1);
          trackDispatch(store, SyncTrackingAction<String>(), notify: false);
          expect(notifications, 2);
          store.clearAllExceptions();
          expect(notifications, 3);
          // Clearing failures must not erase the notification subscriptions.
          trackDispatch(store, SyncTrackingAction<int>(error: error), notify: false);
          expect(notifications, 4);
          sub.cancel();
          store.teardown();
          async.flushMicrotasks();
        });
      });
    }
  }

  for (final method in ['isWaiting', 'isFailed', 'exceptionFor', 'clearExceptionFor']) {
    final invalidInputs = <Object>[
      false,
      17,
      'not a type',
      <Object, Object>{},
      Object(),
      if (method != 'isWaiting') SyncTrackingAction<int>(),
    ];
    for (var index = 0; index < invalidInputs.length; index++) {
      test('$method invalid input $index reports after returning', () {
        fakeAsync((async) {
          final store = Store<int>(initialState: 0);
          final diagnostics = <Object>[];
          runZonedGuarded(() {
            expect(_query(store, method, invalidInputs[index]), _emptyResult(method));
            expect(diagnostics, isEmpty);
          }, (error, _) => diagnostics.add(error));
          async.flushMicrotasks();
          expect(diagnostics, hasLength(1));
          expect(diagnostics.single, isA<StoreException>());
          expect(diagnostics.single.toString(), contains(method));
          expect(store.actionsInProgress(), isEmpty);
          expect(store.isFailed(SyncTrackingAction<int>), isFalse);
          store.teardown();
          async.flushMicrotasks();
        });
      });
    }

    test('$method visits valid and invalid entries even after an earlier match', () {
      fakeAsync((async) {
        final store = Store<int>(initialState: 0, syncStream: true);
        final diagnostics = <Object>[];
        final a = TrackingAction<int>();
        trackDispatch(store, a, notify: false);
        final error = const UserException('a').noDialog;
        trackDispatch(store, SyncTrackingAction<int>(error: error), notify: false);
        var notifications = 0;
        final sub = store.onChange.listen((_) => notifications++);
        final waiting = method == 'isWaiting';
        runZonedGuarded(() {
          final result = _query(store, method, [
            waiting ? TrackingAction<int> : SyncTrackingAction<int>,
            null,
            <Type>[SyncTrackingAction<int>], // Nested iterables are invalid.
            'invalid',
            waiting ? TrackingAction<String> : SyncTrackingAction<String>,
          ]);
          expect(result, switch (method) {
            'isWaiting' || 'isFailed' => isTrue,
            'exceptionFor' => same(error),
            _ => isNull,
          });
          expect(diagnostics, isEmpty);
        }, (error, _) => diagnostics.add(error));
        async.flushMicrotasks();
        expect(diagnostics, hasLength(3));
        expect(diagnostics, everyElement(isA<StoreException>()));
        if (method == 'clearExceptionFor') {
          expect(notifications, 1);
          expect(store.isFailed(SyncTrackingAction<int>), isFalse);
        } else if (waiting) {
          final b = TrackingAction<String>();
          trackDispatch(store, b, notify: false);
          expect(notifications, 1);
          b.release();
          async.flushMicrotasks();
          expect(notifications, 2);
        } else {
          trackDispatch(
            store,
            SyncTrackingAction<String>(error: const UserException('b').noDialog),
            notify: false,
          );
          expect(notifications, 1);
        }
        a.release();
        async.flushMicrotasks();
        sub.cancel();
        store.teardown();
        async.flushMicrotasks();
      });
    });

    test('$method empty iterables and unrelated types are valid nonmatches', () {
      final store = Store<int>(initialState: 0);
      for (final query in <Object>[
        <Type>[],
        <Type>{},
        String,
        [String, int],
      ]) {
        expect(_query(store, method, query), _emptyResult(method));
      }
      store.teardown();
    });

    test('$method rejects top-level null synchronously', () {
      final store = Store<int>(initialState: 0);
      dynamic invalid;
      expect(() {
        switch (method) {
          case 'isWaiting':
            store.isWaiting(invalid);
          case 'isFailed':
            store.isFailed(invalid);
          case 'exceptionFor':
            store.exceptionFor(invalid);
          default:
            store.clearExceptionFor(invalid);
        }
      }, throwsA(isA<TypeError>()));
      store.teardown();
    });
  }

  for (final method in ['isWaiting', 'isFailed', 'exceptionFor']) {
    test('$method subscriptions are per type and isolated between stores', () {
      fakeAsync((async) {
        final watched = Store<int>(initialState: 0, syncStream: true);
        final other = Store<int>(initialState: 0, syncStream: true);
        // Subscribing to one key also enables notifications for other keys.
        switch (method) {
          case 'isWaiting':
            watched.isWaiting(TrackingAction<int>, statusKey: 'a');
          case 'isFailed':
            watched.isFailed(TrackingAction<int>, statusKey: 'a');
          default:
            watched.exceptionFor(TrackingAction<int>, statusKey: 'a');
        }
        var observedEvents = 0;
        var otherEvents = 0;
        final sub = watched.onChange.listen((_) => observedEvents++);
        final otherSub = other.onChange.listen((_) => otherEvents++);
        final a = TrackingAction<int>(key: 'b', error: const UserException('b').noDialog);
        final b = TrackingAction<int>(key: 'b', error: const UserException('b').noDialog);
        trackDispatch(watched, a, notify: false);
        trackDispatch(other, b, notify: false);
        expect(observedEvents, method == 'isWaiting' ? 1 : 0);
        expect(otherEvents, 0);
        a.release();
        b.release();
        async.flushMicrotasks();
        expect(observedEvents, method == 'isWaiting' ? 2 : 1);
        expect(otherEvents, 0);
        expect(watched.isFailed(TrackingAction<int>, statusKey: 'a'), isFalse);
        expect(watched.exceptionFor(TrackingAction<int>, statusKey: 'a'), isNull);
        expect(other.isFailed(TrackingAction<int>, statusKey: 'b'), isTrue);
        sub.cancel();
        otherSub.cancel();
        watched.teardown();
        other.teardown();
        async.flushMicrotasks();
      });
    });
  }
}

Iterable<Object> _shape(String shape, List<Object> values) => switch (shape) {
  'set' => values.toSet(),
  'lazy' => values.map((value) => value),
  'duplicates' => [...values, ...values],
  _ => values,
};

Object? _query(Store<int> store, String method, Object value) {
  switch (method) {
    case 'isWaiting':
      return store.isWaiting(value);
    case 'isFailed':
      return store.isFailed(value);
    case 'exceptionFor':
      return store.exceptionFor(value);
    default:
      store.clearExceptionFor(value);
      return null;
  }
}

Matcher _emptyResult(String method) =>
    method == 'isWaiting' || method == 'isFailed' ? isFalse : isNull;
