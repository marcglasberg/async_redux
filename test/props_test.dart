import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Add and dispose store properties', () {
    test('without dispose predicate', () async {
      final store = Store<int>(initialState: 1);

      final sub = Stream.periodic(
        const Duration(milliseconds: 10),
        (i) => i,
      ).listen((event) {});

      store.setProp(
        'future',
        Future.delayed(
          const Duration(seconds: 1),
          () => 'foo',
        ),
      );
      store.setProp(
        'subscription',
        sub,
      );
      store.setProp('value', 'bar');

      expect(store.props, hasLength(3));

      store.disposeProps();

      expect(store.props, hasLength(1));
      expect(store.props.containsKey('value'), isTrue);
    });

    test('with dispose predicate', () async {
      final store = Store<int>(initialState: 1);

      final sub = Stream.periodic(
        const Duration(milliseconds: 10),
        (i) => i,
      ).listen((event) {});

      store.setProp(
        'future',
        Future.delayed(
          const Duration(seconds: 1),
          () => 'foo',
        ),
      );
      store.setProp(
        'subscription',
        sub,
      );
      store.setProp('value', 'bar');

      expect(store.props, hasLength(3));

      store.disposeProps(({key, value}) => key == 'value');

      expect(store.props, hasLength(2));
      expect(store.props.containsKey('value'), isFalse);
    });
  });
}
