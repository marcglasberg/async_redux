import 'package:async_redux/async_redux.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _CollectionFactory = Object Function(List<int> items, bool isDeepEquals);

final _factories = <String, _CollectionFactory>{
  'IList': (items, deep) => IList.withConfig(items, ConfigList(isDeepEquals: deep)),
  'ISet': (items, deep) => ISet.withConfig(items, ConfigSet(isDeepEquals: deep)),
  'IMap': (items, deep) => IMap.withConfig({
    for (final item in items) item: item * 10,
  }, ConfigMap(isDeepEquals: deep)),
  'IMapOfSets': (items, deep) => IMapOfSets.withConfig({
    for (final item in items) item: [item * 10],
  }, ConfigMapOfSets(isDeepEquals: deep)),
};

void main() {
  final ordinaryFactories = <String, Object Function(List<int>)>{
    'List': (items) => List<int>.of(items),
    'Set': (items) => Set<int>.of(items),
    'Map': (items) => {for (final item in items) item: item * 10},
    'Iterable': (items) => items.where((_) => true),
  };
  for (final entry in ordinaryFactories.entries) {
    for (final policy in [
      CompareBy.byEquals,
      CompareBy.byIdentity,
      CompareBy.byDeepEquals,
    ]) {
      testWidgets('${entry.key}: same instance and equal contents under $policy', (
        tester,
      ) async {
        final first = entry.value([1, 2]);
        await _expectBuilds(
          tester,
          policy: policy,
          values: [
            first,
            first,
            entry.value([1, 2]),
            entry.value([1, 3]),
          ],
          builds: policy == CompareBy.byDeepEquals ? [1, 1, 1, 2] : [1, 1, 2, 3],
        );
      });
    }
    testWidgets('${entry.key}: deep comparison order', (tester) async {
      await _expectBuilds(
        tester,
        policy: CompareBy.byDeepEquals,
        values: [
          entry.value([1, 2]),
          entry.value([2, 1]),
        ],
        builds: [1, entry.key == 'Set' || entry.key == 'Map' ? 1 : 2],
      );
    });
  }

  for (final policy in [
    CompareBy.byEquals,
    CompareBy.byIdentity,
    CompareBy.byDeepEquals,
  ]) {
    testWidgets('records use field equality under $policy', (tester) async {
      final items = [1, 2];
      await _expectBuilds(
        tester,
        policy: policy,
        values: [
          (items, 1),
          (items, 1),
          ([1, 2], 1),
        ],
        builds: [1, 1, 2],
      );
    });
    testWidgets('records respect FIC equality under $policy', (tester) async {
      await _expectBuilds(
        tester,
        policy: policy,
        values: [
          (IList([1, 2]), 1),
          (IList([1, 2]), 1),
          (IList([1, 3]), 1),
        ],
        builds: [1, 1, 2],
      );
    });
  }

  testWidgets('deep comparison stops at FIC items', (tester) async {
    Object value() => [
      [
        IList([
          [1, 2],
        ]),
      ],
    ];
    await _expectBuilds(
      tester,
      policy: CompareBy.byDeepEquals,
      values: [value(), value()],
      builds: [1, 2],
    );
  });

  for (final entry in _factories.entries) {
    final create = entry.value;

    testWidgets('${entry.key}: default honors item equality', (tester) async {
      final first = create([1, 2], true);
      await _expectBuilds(
        tester,
        values: [
          first,
          first,
          create([1, 2], true),
          create([1, 3], true),
        ],
        builds: [1, 1, 1, 2],
      );
    });

    testWidgets('${entry.key}: default honors identity equality', (tester) async {
      final first = create([1, 2], false);
      await _expectBuilds(
        tester,
        values: [
          first,
          first,
          create([1, 2], false),
          create([1, 3], false),
        ],
        builds: [1, 1, 2, 3],
      );
    });

    testWidgets('${entry.key}: default honors configuration differences', (tester) async {
      await _expectBuilds(
        tester,
        values: [
          create([1, 2], true),
          create([1, 2], false),
        ],
        builds: [1, 2],
      );
    });

    testWidgets('${entry.key}: item override ignores outer configuration', (
      tester,
    ) async {
      await _expectBuilds(
        tester,
        policy: CompareBy.byDeepEquals,
        // IMapOfSets propagates isDeepEquals to its nested sets. Change only its
        // outer key sorting configuration here, keeping item equality unchanged.
        values: entry.key == 'IMapOfSets'
            ? [
                create([1, 2], true),
                IMapOfSets.withConfig({
                  1: [10],
                  2: [20],
                }, const ConfigMapOfSets(sortKeys: true)),
                create([1, 3], true),
              ]
            : [
                create([1, 2], false),
                create([1, 2], false),
                create([1, 2], true),
                create([1, 3], false),
              ],
        builds: entry.key == 'IMapOfSets' ? [1, 1, 2] : [1, 1, 1, 2],
      );
    });

    testWidgets('${entry.key}: identity override detects new internals', (tester) async {
      final first = create([1, 2], true);
      await _expectBuilds(
        tester,
        policy: CompareBy.byIdentity,
        values: [
          first,
          first,
          create([1, 2], true),
          create([1, 3], true),
        ],
        builds: [1, 1, 2, 3],
      );
    });

    for (final policy in [CompareBy.byEquals, CompareBy.byDeepEquals]) {
      testWidgets('${entry.key}: insertion order under $policy', (tester) async {
        await _expectBuilds(
          tester,
          policy: policy,
          values: [
            create([1, 2], true),
            create([2, 1], true),
          ],
          builds: [1, entry.key == 'IList' ? 2 : 1],
        );
      });
    }
  }

  final wrappers = <String, Object Function(Object)>{
    'list': (value) => [value],
    'iterable': (value) => [value].where((_) => true),
    'set': (value) => {value},
    'map value': (value) => {'key': value},
    'map key': (value) => {value: 'value'},
    'nested containers': (value) => {
      'key': [
        {value},
      ],
    },
  };

  for (final wrapper in wrappers.entries) {
    for (final policy in [
      CompareBy.byEquals,
      CompareBy.byDeepEquals,
      CompareBy.byIdentity,
    ]) {
      testWidgets('FIC inside ${wrapper.key} follows $policy', (tester) async {
        final create = _factories['IList']!;
        final wrap = wrapper.value;
        final first = create([1, 2], false);
        final comparesItems = policy == CompareBy.byDeepEquals;
        await _expectBuilds(
          tester,
          policy: policy,
          values: [
            wrap(first),
            wrap(first),
            wrap(create([1, 2], false)),
            wrap(create([1, 3], false)),
          ],
          builds: comparesItems ? [1, 1, 1, 2] : [1, 2, 3, 4],
        );
      });
    }

    testWidgets('ISet order inside ${wrapper.key} in deep mode', (tester) async {
      await _expectBuilds(
        tester,
        policy: CompareBy.byDeepEquals,
        values: [
          wrapper.value(ISet([1, 2])),
          wrapper.value(ISet([2, 1])),
        ],
        builds: [1, 1],
      );
    });

    testWidgets('item override hashes FIC inside ${wrapper.key} consistently', (
      tester,
    ) async {
      final create = _factories['IList']!;
      await _expectBuilds(
        tester,
        policy: CompareBy.byDeepEquals,
        values: [
          wrapper.value(create([1, 2], false)),
          wrapper.value(create([1, 2], true)),
          wrapper.value(create([1, 3], true)),
        ],
        builds: [1, 1, 2],
      );
    });
  }

  for (final policy in [
    CompareBy.byEquals,
    CompareBy.byDeepEquals,
    CompareBy.byIdentity,
  ]) {
    testWidgets('ordinary nested collections follow $policy', (tester) async {
      Object value(int last) => {
        'list': [1, last],
        'set': {last, 1},
        'map': {last: 'last', 1: 'first'},
      };
      await _expectBuilds(
        tester,
        policy: policy,
        values: [value(2), value(2), value(3)],
        builds: policy == CompareBy.byDeepEquals ? [1, 1, 2] : [1, 2, 3],
      );
    });

    testWidgets('null and collection family changes under $policy', (tester) async {
      await _expectBuilds(
        tester,
        policy: policy,
        values: [
          null,
          IList([1]),
          ISet([1]),
          [1],
          IMap({1: 1}),
          null,
        ],
        builds: [1, 2, 3, 4, 5, 6],
      );
    });
  }

  testWidgets('identity compares FIC internals rather than wrapper identity', (
    tester,
  ) async {
    const source = [1, 2];
    // Intentionally create distinct wrappers around the same backing list.
    // ignore: non_const_call_to_literal_constructor
    final original = IListConst(source);
    // ignore: non_const_call_to_literal_constructor
    final otherWrapper = IListConst(source);
    expect(identical(original, otherWrapper), isFalse);
    expect(areSameImmutableCollection(original, otherWrapper), isTrue);
    await _expectBuilds(
      tester,
      policy: CompareBy.byIdentity,
      values: [original, otherWrapper],
      builds: [1, 1],
    );
  });

  testWidgets('FIC item comparison preserves nested items equality', (tester) async {
    final create = _factories['IMapOfSets']!;
    await _expectBuilds(
      tester,
      policy: CompareBy.byDeepEquals,
      values: [
        create([1, 2], false),
        create([1, 2], false),
      ],
      builds: [1, 2],
    );
  });

  testWidgets('selector policies are isolated between stores', (tester) async {
    final first = IList([1, 2]);
    final stores = [
      Store<_State>(initialState: _State(first)),
      Store<_State>(
        initialState: _State(first),
        options: StoreOptions(collectionEquality: CompareBy.byIdentity),
      ),
    ];
    final builds = [0, 0];
    for (final store in stores) {
      addTearDown(store.teardown);
    }
    await tester.pumpWidget(
      Row(
        textDirection: TextDirection.ltr,
        children: [
          for (var i = 0; i < stores.length; i++)
            StoreProvider<_State>(
              store: stores[i],
              child: Builder(
                builder: (context) {
                  context.getSelect<_State, Object?>((state) => state.value);
                  builds[i]++;
                  return const SizedBox();
                },
              ),
            ),
        ],
      ),
    );
    for (final store in stores) {
      store.dispatchSync(_SetValue(IList([1, 2])));
    }
    await tester.pump();
    await tester.pump();
    expect(builds, [1, 2]);
  });
}

Future<void> _expectBuilds(
  WidgetTester tester, {
  required List<Object?> values,
  required List<int> builds,
  CompareBy policy = CompareBy.byEquals,
}) async {
  final store = Store<_State>(
    initialState: _State(values.first),
    options: StoreOptions(collectionEquality: policy),
  );
  addTearDown(store.teardown);
  var buildCount = 0;
  Object? rendered;
  await tester.pumpWidget(
    StoreProvider<_State>(
      store: store,
      child: Builder(
        builder: (context) {
          rendered = context.getSelect<_State, Object?>((state) => state.value);
          buildCount++;
          return const SizedBox();
        },
      ),
    ),
  );
  expect(buildCount, builds.first);
  for (var i = 1; i < values.length; i++) {
    store.dispatchSync(_SetValue(values[i]));
    await tester.pump();
    await tester.pump();
    expect(buildCount, builds[i], reason: 'State update $i');
    if (builds[i] > builds[i - 1]) expect(rendered, same(values[i]));
  }
}

class _State {
  _State(this.value);

  final Object? value;
}

class _SetValue extends ReduxAction<_State> {
  _SetValue(this.value);

  final Object? value;

  @override
  _State reduce() => _State(value);
}
