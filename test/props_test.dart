import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Add and dispose store properties', () {
    //

    // If you don't provide a predicate function, all properties which are `Timer`, `Future`, or
    // `Stream` related will be closed/cancelled/ignored as appropriate, and then removed from the
    // props. Other properties will not be removed.
    test('Predicate not provided', () async {
      final store = Store<int>(initialState: 1);

      // Future prop
      final future = Future.delayed(const Duration(seconds: 1), () => 'foo');
      store.setProp('future', future);

      // Timer prop
      final timer = ManagedTimer(const Duration(milliseconds: 100), () => 'foo');
      store.setProp('timer', timer);

      // Stream prop
      final sub = Stream.periodic(const Duration(milliseconds: 10), (i) => i).listen((event) {});
      store.setProp('subscription', sub);

      // Regular prop
      store.setProp('value', 'bar');

      expect(timer.isCancelled, isFalse);
      expect(store.props, hasLength(4));

      // Should dispose/cancel the `future` and `subscription` props
      // but keep the `value` prop.
      store.disposeProps();

      expect(timer.isCancelled, isTrue);
      expect(store.props, hasLength(1));
      expect(store.props.containsKey('value'), isTrue);
    });

    test('Predicate provided, does not remove Future/Timer/Stream', () async {
      final store = Store<int>(initialState: 1);

      // Future prop
      store.setProp('future', Future.delayed(const Duration(seconds: 1), () => 'foo'));

      // Timer prop
      final timer = ManagedTimer(const Duration(milliseconds: 100), () => 'foo');
      store.setProp('timer', timer);

      // Stream prop
      final sub = Stream.periodic(const Duration(milliseconds: 10), (i) => i).listen((event) {});
      store.setProp('subscription', sub);

      // Regular prop
      store.setProp('value', 'bar');

      expect(timer.isCancelled, isFalse);
      expect(store.props, hasLength(4));

      // Predicate: Only remove the regular prop.
      store.disposeProps(({key, value}) => key == 'value');

      // Does NOT close the Timer.
      expect(timer.isCancelled, isFalse);

      // Does NOT close the Future/Timer/Stream.
      // Removes the regular prop.
      expect(store.props, hasLength(3));
      expect(store.props.containsKey('value'), isFalse);
    });
  });

  test('Predicate provided, removes Future/Timer/Stream', () async {
    final store = Store<int>(initialState: 1);

    // Future prop
    store.setProp('future', Future.delayed(const Duration(seconds: 1), () => 'foo'));

    // Timer prop
    final timer = ManagedTimer(const Duration(milliseconds: 100), () => 'foo');
    store.setProp('timer', timer);

    // Stream prop
    final sub = Stream.periodic(const Duration(milliseconds: 10), (i) => i).listen((event) {});
    store.setProp('subscription', sub);

    // Regular prop
    store.setProp('value', 'bar');

    expect(timer.isCancelled, isFalse);
    expect(store.props, hasLength(4));

    // Predicate: Only remove the regular prop.
    store.disposeProps(({key, value}) => true);

    // Closes the Timer.
    expect(timer.isCancelled, isTrue);

    // Removes all.
    expect(store.props, hasLength(0));
  });
}

class ManagedTimer implements Timer {
  Timer? _timer;
  bool _isCancelled = false;

  ManagedTimer(Duration duration, void Function() callback) {
    _timer = Timer(duration, callback);
  }

  @override
  void cancel() {
    _timer?.cancel();
    _isCancelled = true;
  }

  bool get isCancelled => _isCancelled;

  @override
  bool get isActive => throw UnimplementedError();

  @override
  int get tick => throw UnimplementedError();
}
