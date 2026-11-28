import 'package:async_redux/async_redux.dart';
import 'package:bdd_framework/flutter_widget_test.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Factory = Object Function(List<int>);

void main() {
  final feature = BddFeature('context.select collection equality');
  final ordinary = <String, _Factory>{
    'List': (items) => List<int>.of(items),
    'Set': (items) => Set<int>.of(items),
    'Map': (items) => {for (final item in items) item: item * 10},
    'Iterable': (items) => items.where((_) => true),
  };
  final fic = <String, _Factory>{
    'IList': (items) => IList(items),
    'ISet': (items) => ISet(items),
    'IMap': (items) => IMap({for (final item in items) item: item * 10}),
    'IMapOfSets': (items) => IMapOfSets({
      for (final item in items) item: [item],
    }),
  };

  for (final mode in CompareBy.values) {
    for (final entry in {...ordinary, ...fic}.entries) {
      final byContents =
          mode == CompareBy.byDeepEquals ||
          (mode == CompareBy.byEquals && fic.containsKey(entry.key));
      Bdd(feature)
          .scenario('${entry.key} rebuilds according to ${mode.name}')
          .given('A mounted selector and a store configured with ${mode.name}')
          .when(
            'An unrelated field changes, then an equal replacement, then changed contents',
          )
          .then('Keeping the same collection instance does not rebuild the widget')
          .and(
            byContents
                ? 'An independently created equal replacement does not rebuild the widget'
                : 'An independently created equal replacement rebuilds the widget',
          )
          .and('Changed contents rebuild the widget and update its displayed value')
          .run((_, tester) async {
            final first = entry.value([1, 2]);
            final h = await _Harness.mount(tester, first, mode: mode);
            await h.change(first);
            h.expectBuilds(1);
            await h.change(entry.value([1, 2]));
            h.expectBuilds(byContents ? 1 : 2);
            final changed = entry.value([1, 3]);
            await h.change(changed);
            h.expectBuilds(byContents ? 2 : 3);
            expect(h.rendered, same(changed));
            expect(find.text('$changed'), findsOneWidget);
          });

      final ignoresOrder = (entry.key == 'Set' || entry.key == 'Map')
          ? mode == CompareBy.byDeepEquals
          : (entry.key == 'ISet' || entry.key == 'IMap' || entry.key == 'IMapOfSets')
          ? mode != CompareBy.byIdentity
          : false;
      Bdd(feature)
          .scenario('${entry.key} insertion order under ${mode.name}')
          .given('A selector displaying a collection with items 1 and 2')
          .when('It is replaced by a collection created in the order 2 then 1')
          .then(ignoresOrder ? 'The widget does not rebuild' : 'The widget rebuilds')
          .run((_, tester) async {
            final h = await _Harness.mount(tester, entry.value([1, 2]), mode: mode);
            await h.change(entry.value([2, 1]));
            h.expectBuilds(ignoresOrder ? 1 : 2);
          });
    }

    final groups = <String, Object Function(_State)>{
      'record': (st) => (st.name, st.counter),
      'List literal': (st) => [st.name, st.counter],
      'Set literal': (st) => {st.name, st.counter},
      'Map literal': (st) => {'name': st.name, 'counter': st.counter},
    };
    for (final group in groups.entries) {
      final byContents = group.key == 'record' || mode == CompareBy.byDeepEquals;
      Bdd(feature)
          .scenario('A ${group.key} groups fields under ${mode.name}')
          .given('A selector grouping name and counter on each execution')
          .when('An unrelated field changes, then name changes, then counter changes')
          .then(byContents ? 'The widget does not rebuild' : 'The widget rebuilds')
          .and('Name and counter changes each rebuild and update the displayed value')
          .run((_, tester) async {
            final h = await _Harness.mount(tester, null, mode: mode, select: group.value);
            await h.change(null);
            final baseline = byContents ? 1 : 2;
            h.expectBuilds(baseline);
            await h.update(const _State(null, name: 'Bob', tick: 2));
            h.expectBuilds(baseline + 1);
            expect(find.text('${group.value(h.store.state)}'), findsOneWidget);
            await h.update(const _State(null, name: 'Bob', counter: 2, tick: 3));
            h.expectBuilds(baseline + 2);
            expect(find.text('${group.value(h.store.state)}'), findsOneWidget);
          });
    }

    for (final kind in ['IList', 'ISet', 'IMap']) {
      Object create() => switch (kind) {
        'IList' => IList.withConfig([1, 2], const ConfigList(isDeepEquals: false)),
        'ISet' => ISet.withConfig([1, 2], const ConfigSet(isDeepEquals: false)),
        _ => IMap.withConfig({1: 10, 2: 20}, const ConfigMap(isDeepEquals: false)),
      };
      Bdd(feature)
          .scenario('$kind identity configuration under ${mode.name}')
          .given('A FIC collection configured with isDeepEquals false')
          .when('A new collection with the same contents replaces it')
          .then(
            mode == CompareBy.byDeepEquals
                ? 'Item comparison suppresses the rebuild'
                : 'The widget rebuilds',
          )
          .run((_, tester) async {
            final h = await _Harness.mount(tester, create(), mode: mode);
            await h.change(create());
            h.expectBuilds(mode == CompareBy.byDeepEquals ? 1 : 2);
          });
    }

    Bdd(feature)
        .scenario('Ordinary collections recurse under ${mode.name}')
        .given('A selected List containing a Map, a Set, and another List')
        .when('Fresh equal containers replace it, then an innermost value changes')
        .then(
          mode == CompareBy.byDeepEquals
              ? 'Only changing the innermost value rebuilds the widget'
              : 'Both replacements rebuild the widget',
        )
        .run((_, tester) async {
          Object create(int last) => [
            {
              'set': {1, 2},
              'list': [1, last],
            },
          ];
          final h = await _Harness.mount(tester, create(2), mode: mode);
          await h.change(create(2));
          h.expectBuilds(mode == CompareBy.byDeepEquals ? 1 : 2);
          await h.change(create(3));
          h.expectBuilds(mode == CompareBy.byDeepEquals ? 2 : 3);
          expect(find.text('${create(3)}'), findsOneWidget);
        });

    Bdd(feature)
        .scenario('Non-collection objects keep their own equality under ${mode.name}')
        .given('A selected object that implements value equality')
        .when('A fresh equal object replaces it, then a different value replaces it')
        .then('Only the different value rebuilds the widget in every mode')
        .run((_, tester) async {
          final h = await _Harness.mount(tester, _Value(1), mode: mode);
          await h.change(_Value(1));
          h.expectBuilds(1);
          await h.change(_Value(2));
          h.expectBuilds(2);
          expect(find.text('Value: 2'), findsOneWidget);
        });

    Bdd(feature)
        .scenario('Deep recursion stops at FIC collections under ${mode.name}')
        .given('An ordinary List containing an IList containing an ordinary List')
        .when('The nested structure is replaced with equal contents in fresh objects')
        .then('The widget rebuilds, including in deep mode')
        .run((_, tester) async {
          Object create() => [
            IList([
              [1, 2],
            ]),
          ];
          final h = await _Harness.mount(tester, create(), mode: mode);
          await h.change(create());
          h.expectBuilds(2);
        });

    Bdd(feature)
        .scenario('Records keep their field equality under ${mode.name}')
        .given('A selected record containing an ordinary List')
        .when(
          'A record with the same List is selected, then a record with a fresh equal List',
        )
        .then('Keeping the same List instance does not rebuild the widget')
        .and('A fresh equal List rebuilds the widget, including in deep mode')
        .run((_, tester) async {
          final items = [1, 2];
          final h = await _Harness.mount(tester, (items, 1), mode: mode);
          await h.change((items, 1));
          h.expectBuilds(1);
          await h.change(([1, 2], 1));
          h.expectBuilds(2);
        });

    Bdd(feature)
        .scenario('Null and collection kind changes under ${mode.name}')
        .given('A selector initially returning null')
        .when('It returns a List, an IList, a Set, an ISet, a Map, an IMap, then null')
        .then('Every transition rebuilds the widget without throwing')
        .run((_, tester) async {
          final h = await _Harness.mount(tester, null, mode: mode);
          var builds = 1;
          for (final value in [
            [1],
            IList([1]),
            {1},
            ISet([1]),
            {1: 1},
            IMap({1: 1}),
            null,
          ]) {
            await h.change(value);
            h.expectBuilds(++builds);
            expect(h.rendered, same(value));
          }
          expect(tester.takeException(), isNull);
        });
  }

  Bdd(feature)
      .scenario('Omitting StoreOptions uses byEquals')
      .given('A store constructed without options and a selector returning a List')
      .when('An unrelated field changes, then a fresh equal List replaces the selection')
      .then('Only replacing the List rebuilds the widget')
      .run((_, tester) async {
        final items = [1, 2];
        final h = await _Harness.mount(tester, items);
        expect(h.store.options.collectionEquality, CompareBy.byEquals);
        await h.change(items);
        h.expectBuilds(1);
        await h.change([1, 2]);
        h.expectBuilds(2);
      });

  Bdd(feature)
      .scenario('byIdentity accepts distinct FIC wrappers sharing internals')
      .given('Two distinct IList wrappers with the same backing list and configuration')
      .when('The second replaces the first under byIdentity')
      .then('The widget does not rebuild')
      .run((_, tester) async {
        const backing = [1, 2];
        // Intentionally non-const so the wrappers are distinct objects.
        // ignore: non_const_call_to_literal_constructor
        final first = IListConst(backing);
        // ignore: non_const_call_to_literal_constructor
        final second = IListConst(backing);
        expect(identical(first, second), isFalse);
        expect(first.same(second), isTrue);
        final h = await _Harness.mount(tester, first, mode: CompareBy.byIdentity);
        await h.change(second);
        h.expectBuilds(1);
      });
}

/// Uses real StoreProvider subscriptions; no comparison logic is mocked here.
class _Harness {
  _Harness(this.tester, this.store);

  final WidgetTester tester;
  final Store<_State> store;
  int builds = 0;
  Object? rendered;

  static Future<_Harness> mount(
    WidgetTester tester,
    Object? value, {
    CompareBy? mode,
    Object? Function(_State)? select,
  }) async {
    final store = Store<_State>(
      initialState: _State(value),
      options: mode == null ? null : StoreOptions(collectionEquality: mode),
    );
    addTearDown(store.teardown);
    final h = _Harness(tester, store);
    final selector = select ?? (state) => state.value;
    await tester.pumpWidget(
      StoreProvider<_State>(
        store: store,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              h.rendered = context.select(selector);
              h.builds++;
              return Text('${h.rendered}');
            },
          ),
        ),
      ),
    );
    h.expectBuilds(1);
    return h;
  }

  Future<void> change(Object? value) => update(_State(value, tick: store.state.tick + 1));

  Future<void> update(_State state) async {
    store.dispatchSync(_Replace(state));
    await tester.pump();
    await tester.pump();
  }

  void expectBuilds(int expected) => expect(builds, expected);
}

class _State {
  const _State(this.value, {this.name = 'Alice', this.counter = 1, this.tick = 0});

  final Object? value;
  final String name;
  final int counter;
  final int tick;
}

class _Replace extends ReduxAction<_State> {
  _Replace(this.next);

  final _State next;

  @override
  _State reduce() => next;
}

extension on BuildContext {
  R select<R>(R Function(_State state) selector) => getSelect<_State, R>(selector);
}

class _Value {
  _Value(this.number);

  final int number;

  @override
  bool operator ==(Object other) => other is _Value && number == other.number;

  @override
  int get hashCode => number.hashCode;

  @override
  String toString() => 'Value: $number';
}
