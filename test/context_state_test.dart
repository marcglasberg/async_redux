// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AsyncRedux context.state functionality', () {
    testWidgets('context.state rebuilds on any state change',
        (WidgetTester tester) async {
      final initialState = AppState(
        name: 'Alice',
        counter: 0,
        flag: false,
      );

      final store = Store<AppState>(initialState: initialState);
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StoreProvider<AppState>(
            store: store,
            child: Scaffold(
              body: Builder(builder: (context) {
                buildCount++;
                var state = context.state;
                return Text('Name: ${state.name}');
              }),
            ),
          ),
        ),
      );

      expect(buildCount, 1);
      expect(find.text('Name: Alice'), findsOneWidget);

      // Change name - should rebuild
      store.dispatch(ChangeNameAction('Bob'));
      await tester.pump();
      await tester.pump();
      expect(buildCount, 2);
      expect(find.text('Name: Bob'), findsOneWidget);

      // Change counter (unrelated to displayed value) - should still rebuild
      store.dispatch(IncrementCounterAction());
      await tester.pump();
      await tester.pump();
      expect(buildCount, 3);

      // Change flag (also unrelated) - should still rebuild
      store.dispatch(ToggleFlagAction());
      await tester.pump();
      await tester.pump();
      expect(buildCount, 4);
    });

    testWidgets(
        'context.state always rebuilds even when accessing single field',
        (WidgetTester tester) async {
      final initialState = AppState(
        name: 'Alice',
        counter: 0,
        flag: false,
      );

      final store = Store<AppState>(initialState: initialState);
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StoreProvider<AppState>(
            store: store,
            child: Scaffold(
              body: Builder(builder: (context) {
                buildCount++;
                // Only accessing name, but using context.state
                var name = context.state.name;
                return Text('Name: $name');
              }),
            ),
          ),
        ),
      );

      expect(buildCount, 1);

      // Change counter (not name) - should still rebuild because we used context.state
      store.dispatch(IncrementCounterAction());
      await tester.pump();
      await tester.pump();
      expect(buildCount, 2);

      // Compare with select - only rebuilds when selected value changes
      // (This is tested in context_select_test.dart)
    });
  });

  group('AsyncRedux context.read() functionality', () {
    testWidgets('context.read() does not trigger rebuilds',
        (WidgetTester tester) async {
      final initialState = AppState(
        name: 'Alice',
        counter: 0,
        flag: false,
      );

      final store = Store<AppState>(initialState: initialState);
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StoreProvider<AppState>(
            store: store,
            child: Scaffold(
              body: Builder(builder: (context) {
                buildCount++;
                var state = context.read();
                return Text('Name: ${state.name}');
              }),
            ),
          ),
        ),
      );

      expect(buildCount, 1);
      expect(find.text('Name: Alice'), findsOneWidget);

      // Change name - should NOT rebuild
      store.dispatch(ChangeNameAction('Bob'));
      await tester.pump();
      await tester.pump();
      expect(buildCount, 1);
      // Still shows old value because widget didn't rebuild
      expect(find.text('Name: Alice'), findsOneWidget);

      // Change counter - should NOT rebuild
      store.dispatch(IncrementCounterAction());
      await tester.pump();
      await tester.pump();
      expect(buildCount, 1);

      // Change flag - should NOT rebuild
      store.dispatch(ToggleFlagAction());
      await tester.pump();
      await tester.pump();
      expect(buildCount, 1);
    });

    testWidgets('context.read() can be used in initState',
        (WidgetTester tester) async {
      final initialState = AppState(
        name: 'Alice',
        counter: 42,
        flag: false,
      );

      final store = Store<AppState>(initialState: initialState);
      int? capturedCounter;

      await tester.pumpWidget(
        MaterialApp(
          home: StoreProvider<AppState>(
            store: store,
            child: Scaffold(
              body: InitStateTestWidget(
                onInitState: (context) {
                  // This should work - reading state in initState
                  capturedCounter = context.read().counter;
                },
              ),
            ),
          ),
        ),
      );

      expect(capturedCounter, 42);
    });

    testWidgets('context.read() returns current state value',
        (WidgetTester tester) async {
      final initialState = AppState(
        name: 'Alice',
        counter: 0,
        flag: false,
      );

      final store = Store<AppState>(initialState: initialState);
      List<String> readValues = [];

      await tester.pumpWidget(
        MaterialApp(
          home: StoreProvider<AppState>(
            store: store,
            child: Scaffold(
              body: Builder(builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    // Read current state on button press
                    readValues.add(context.read().name);
                  },
                  child: const Text('Read'),
                );
              }),
            ),
          ),
        ),
      );

      // Read initial value
      await tester.tap(find.text('Read'));
      expect(readValues, ['Alice']);

      // Change state
      store.dispatch(ChangeNameAction('Bob'));
      await tester.pump();
      await tester.pump();

      // Read new value
      await tester.tap(find.text('Read'));
      expect(readValues, ['Alice', 'Bob']);

      // Change again
      store.dispatch(ChangeNameAction('Charlie'));
      await tester.pump();
      await tester.pump();

      // Read newest value
      await tester.tap(find.text('Read'));
      expect(readValues, ['Alice', 'Bob', 'Charlie']);
    });
  });

  group('context.state vs context.read() comparison', () {
    testWidgets('state rebuilds, read does not', (WidgetTester tester) async {
      final initialState = AppState(
        name: 'Alice',
        counter: 0,
        flag: false,
      );

      final store = Store<AppState>(initialState: initialState);
      int stateBuildCount = 0;
      int readBuildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StoreProvider<AppState>(
            store: store,
            child: Scaffold(
              body: Column(
                children: [
                  // Widget using context.state
                  Builder(builder: (context) {
                    stateBuildCount++;
                    var state = context.state;
                    return Text('State: ${state.name}');
                  }),
                  // Widget using context.read()
                  Builder(builder: (context) {
                    readBuildCount++;
                    var state = context.read();
                    return Text('Read: ${state.name}');
                  }),
                ],
              ),
            ),
          ),
        ),
      );

      expect(stateBuildCount, 1);
      expect(readBuildCount, 1);

      // Change state
      store.dispatch(ChangeNameAction('Bob'));
      await tester.pump();
      await tester.pump();

      expect(stateBuildCount, 2); // Rebuilt
      expect(readBuildCount, 1); // Not rebuilt

      // Change again
      store.dispatch(IncrementCounterAction());
      await tester.pump();
      await tester.pump();

      expect(stateBuildCount, 3); // Rebuilt again
      expect(readBuildCount, 1); // Still not rebuilt
    });

    testWidgets('Multiple dispatches - state rebuilds each time, read never',
        (WidgetTester tester) async {
      final initialState = AppState(
        name: 'Alice',
        counter: 0,
        flag: false,
      );

      final store = Store<AppState>(initialState: initialState);
      int stateBuildCount = 0;
      int readBuildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StoreProvider<AppState>(
            store: store,
            child: Scaffold(
              body: Column(
                children: [
                  Builder(builder: (context) {
                    stateBuildCount++;
                    return Text('Counter: ${context.state.counter}');
                  }),
                  Builder(builder: (context) {
                    readBuildCount++;
                    return Text('Read Counter: ${context.read().counter}');
                  }),
                ],
              ),
            ),
          ),
        ),
      );

      expect(stateBuildCount, 1);
      expect(readBuildCount, 1);

      // Dispatch 5 actions
      for (int i = 0; i < 5; i++) {
        store.dispatch(IncrementCounterAction());
        await tester.pump();
        await tester.pump();
      }

      expect(stateBuildCount, 6); // 1 initial + 5 rebuilds
      expect(readBuildCount, 1); // Never rebuilt
    });
  });

  group('Edge cases and error handling', () {
    testWidgets('context.state throws when used in initState',
        (WidgetTester tester) async {
      final initialState = AppState(
        name: 'Alice',
        counter: 0,
        flag: false,
      );

      final store = Store<AppState>(initialState: initialState);
      Object? caughtError;

      await tester.pumpWidget(
        MaterialApp(
          home: StoreProvider<AppState>(
            store: store,
            child: Scaffold(
              body: InitStateTestWidget(
                onInitState: (context) {
                  try {
                    // This should throw - using context.state in initState
                    context.state;
                  } catch (e) {
                    caughtError = e;
                  }
                },
              ),
            ),
          ),
        ),
      );

      // context.state should throw when used in initState
      expect(caughtError, isNotNull);
    });

    testWidgets('context.read() works in callbacks',
        (WidgetTester tester) async {
      final initialState = AppState(
        name: 'Alice',
        counter: 0,
        flag: false,
      );

      final store = Store<AppState>(initialState: initialState);
      String? capturedName;

      await tester.pumpWidget(
        MaterialApp(
          home: StoreProvider<AppState>(
            store: store,
            child: Scaffold(
              body: Builder(builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    capturedName = context.read().name;
                  },
                  child: const Text('Capture'),
                );
              }),
            ),
          ),
        ),
      );

      // Change state before pressing button
      store.dispatch(ChangeNameAction('Bob'));
      await tester.pump();
      await tester.pump();

      // Now press button to read current state
      await tester.tap(find.text('Capture'));
      expect(capturedName, 'Bob');
    });

    testWidgets('context.state in nested StoreProvider uses correct store',
        (WidgetTester tester) async {
      final outerState = AppState(name: 'Outer', counter: 1, flag: false);
      final innerState = AppState(name: 'Inner', counter: 2, flag: true);

      final outerStore = Store<AppState>(initialState: outerState);
      final innerStore = Store<AppState>(initialState: innerState);

      String? outerName;
      String? innerName;

      await tester.pumpWidget(
        MaterialApp(
          home: StoreProvider<AppState>(
            store: outerStore,
            child: Column(
              children: [
                Builder(builder: (context) {
                  outerName = context.state.name;
                  return Text('Outer: $outerName');
                }),
                StoreProvider<AppState>(
                  store: innerStore,
                  child: Builder(builder: (context) {
                    innerName = context.state.name;
                    return Text('Inner: $innerName');
                  }),
                ),
              ],
            ),
          ),
        ),
      );

      expect(outerName, 'Outer');
      expect(innerName, 'Inner');
    });
  });
}

// Extension for BuildContext
extension BuildContextExtension on BuildContext {
  AppState get state => getState<AppState>();

  AppState read() => getRead<AppState>();

  R select<R>(R Function(AppState state) selector) =>
      getSelect<AppState, R>(selector);
}

// Test state class
class AppState {
  final String name;
  final int counter;
  final bool flag;

  AppState({
    required this.name,
    required this.counter,
    required this.flag,
  });

  AppState copyWith({
    String? name,
    int? counter,
    bool? flag,
  }) {
    return AppState(
      name: name ?? this.name,
      counter: counter ?? this.counter,
      flag: flag ?? this.flag,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppState &&
        other.name == name &&
        other.counter == counter &&
        other.flag == flag;
  }

  @override
  int get hashCode => Object.hash(name, counter, flag);
}

// Test actions
class ChangeNameAction extends ReduxAction<AppState> {
  final String name;

  ChangeNameAction(this.name);

  @override
  AppState reduce() {
    return state.copyWith(name: name);
  }
}

class IncrementCounterAction extends ReduxAction<AppState> {
  @override
  AppState reduce() {
    return state.copyWith(counter: state.counter + 1);
  }
}

class ToggleFlagAction extends ReduxAction<AppState> {
  @override
  AppState reduce() {
    return state.copyWith(flag: !state.flag);
  }
}

// Widget to test initState behavior
class InitStateTestWidget extends StatefulWidget {
  final void Function(BuildContext context) onInitState;

  const InitStateTestWidget({
    Key? key,
    required this.onInitState,
  }) : super(key: key);

  @override
  State<InitStateTestWidget> createState() => _InitStateTestWidgetState();
}

class _InitStateTestWidgetState extends State<InitStateTestWidget> {
  @override
  void initState() {
    super.initState();
    widget.onInitState(context);
  }

  @override
  Widget build(BuildContext context) {
    return const Text('InitState Test');
  }
}
