// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests where `context.select` and `context.event` can be used: in `build`, in
/// `didChangeDependencies`, and in the builders of `LayoutBuilder` and lists. In
/// callbacks, like `onPressed` and post-frame callbacks, they throw.
void main() {
  late Store<AppState> store;

  setUp(() {
    store = Store<AppState>(
      initialState: AppState(counter: 0, name: 'Mary', evt: Event<String>.spent()),
    );
  });

  Widget app(Widget child) => MaterialApp(
        home: StoreProvider<AppState>(store: store, child: Scaffold(body: child)),
      );

  group('didChangeDependencies', () {
    testWidgets('select works, and runs it again only when the selected value changes',
        (tester) async {
      var calls = <int>[];
      await tester.pumpWidget(app(_DidChangeDependencies(
        onDidChangeDependencies: (context) =>
            calls.add(context.select((st) => st.counter)),
      )));

      expect(tester.takeException(), isNull);
      expect(calls, [0]);

      // The selected value changes.
      store.dispatch(IncrementAction());
      await tester.pump();
      expect(calls, [0, 1]);

      // Another part of the state changes.
      store.dispatch(ChangeNameAction('John'));
      await tester.pump();
      expect(calls, [0, 1]);
    });

    testWidgets('event works', (tester) async {
      var values = <String?>[];
      await tester.pumpWidget(app(_DidChangeDependencies(
        onDidChangeDependencies: (context) => values.add(context.event((st) => st.evt)),
      )));

      expect(tester.takeException(), isNull);
      expect(values, [null]);

      store.dispatch(FireEventAction('hello'));
      await tester.pump();
      expect(values, [null, 'hello']);
    });
  });

  group('builders', () {
    testWidgets('select works in the builder of a LayoutBuilder', (tester) async {
      await tester.pumpWidget(app(LayoutBuilder(
        builder: (context, constraints) => Text('${context.select((st) => st.counter)}'),
      )));

      expect(tester.takeException(), isNull);
      expect(find.text('0'), findsOneWidget);

      store.dispatch(IncrementAction());
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('select works in a Builder in the itemBuilder of a list', (tester) async {
      await tester.pumpWidget(app(ListView.builder(
        itemCount: 2,
        itemBuilder: (_, index) => Builder(
          builder: (context) => Text('$index ${context.select((st) => st.name)}'),
        ),
      )));

      expect(tester.takeException(), isNull);
      expect(find.text('0 Mary'), findsOneWidget);
      expect(find.text('1 Mary'), findsOneWidget);
    });
  });

  group('callbacks throw', () {
    testWidgets('select in onPressed', (tester) async {
      Object? error;
      await tester.pumpWidget(app(Builder(
        builder: (context) => ElevatedButton(
          onPressed: () {
            try {
              // ignore: async_redux_lints/select_outside_build
              context.select((st) => st.counter);
            } catch (e) {
              error = e;
            }
          },
          child: const Text('Click me'),
        ),
      )));

      await tester.tap(find.text('Click me'));
      expect(error, isA<FlutterError>());
      expect(
        error.toString(),
        contains('outside the widget `build` method and `didChangeDependencies`'),
      );
    });

    testWidgets('event in onPressed', (tester) async {
      Object? error;
      await tester.pumpWidget(app(Builder(
        builder: (context) => ElevatedButton(
          onPressed: () {
            try {
              // ignore: async_redux_lints/select_outside_build
              context.event((st) => st.evt);
            } catch (e) {
              error = e;
            }
          },
          child: const Text('Click me'),
        ),
      )));

      await tester.tap(find.text('Click me'));
      expect(error, isA<FlutterError>());
      expect(
        error.toString(),
        contains('outside the widget `build` method and `didChangeDependencies`'),
      );
    });

    testWidgets('select in a post-frame callback', (tester) async {
      Object? error;
      await tester.pumpWidget(app(Builder(
        builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              // ignore: async_redux_lints/select_outside_build
              context.select((st) => st.counter);
            } catch (e) {
              error = e;
            }
          });
          return const SizedBox();
        },
      )));

      expect(error, isA<FlutterError>());
    });
  });

  testWidgets('select in initState throws', (tester) async {
    await tester.pumpWidget(app(_InitState(
      // ignore: async_redux_lints/select_outside_build
      onInitState: (context) => context.select((st) => st.counter),
    )));

    expect(tester.takeException(), isA<FlutterError>());
  });
}

class AppState {
  final int counter;
  final String name;
  final Event<String> evt;

  AppState({required this.counter, required this.name, required this.evt});

  AppState copy({int? counter, String? name, Event<String>? evt}) => AppState(
        counter: counter ?? this.counter,
        name: name ?? this.name,
        evt: evt ?? this.evt,
      );
}

class IncrementAction extends ReduxAction<AppState> {
  @override
  AppState reduce() => state.copy(counter: state.counter + 1);
}

class ChangeNameAction extends ReduxAction<AppState> {
  final String name;

  ChangeNameAction(this.name);

  @override
  AppState reduce() => state.copy(name: name);
}

class FireEventAction extends ReduxAction<AppState> {
  final String value;

  FireEventAction(this.value);

  @override
  AppState reduce() => state.copy(evt: Event<String>(value));
}

class _DidChangeDependencies extends StatefulWidget {
  final void Function(BuildContext context) onDidChangeDependencies;

  const _DidChangeDependencies({required this.onDidChangeDependencies});

  @override
  State<_DidChangeDependencies> createState() => _DidChangeDependenciesState();
}

class _DidChangeDependenciesState extends State<_DidChangeDependencies> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.onDidChangeDependencies(context);
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _InitState extends StatefulWidget {
  final void Function(BuildContext context) onInitState;

  const _InitState({required this.onInitState});

  @override
  State<_InitState> createState() => _InitStateState();
}

class _InitStateState extends State<_InitState> {
  @override
  void initState() {
    super.initState();
    widget.onInitState(context);
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

extension BuildContextExtension on BuildContext {
  AppState get state => getState<AppState>();

  AppState read() => getRead<AppState>();

  R select<R>(R Function(AppState state) selector) => getSelect<AppState, R>(selector);

  R? event<R>(Evt<R> Function(AppState state) selector) =>
      getEvent<AppState, R>(selector);
}
