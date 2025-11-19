// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AsyncRedux context.env functionality', () {
    testWidgets('Environment is accessible via context.env',
        (WidgetTester tester) async {
      final initialState = AppState(counter: 0);
      final environment = TestEnvironment(
        apiUrl: 'https://api.example.com',
        apiKey: 'test-key-123',
      );

      final store = Store<AppState>(
        initialState: initialState,
        environment: environment,
      );

      TestEnvironment? capturedEnv;

      await tester.pumpWidget(
        MaterialApp(
          home: StoreProvider<AppState>(
            store: store,
            child: Scaffold(
              body: Builder(builder: (context) {
                capturedEnv = context.env;
                return Text('API: ${capturedEnv!.apiUrl}');
              }),
            ),
          ),
        ),
      );

      expect(capturedEnv, isNotNull);
      expect(capturedEnv!.apiUrl, 'https://api.example.com');
      expect(capturedEnv!.apiKey, 'test-key-123');
      expect(find.text('API: https://api.example.com'), findsOneWidget);
    });

    testWidgets('Accessing environment does not trigger rebuilds',
        (WidgetTester tester) async {
      final initialState = AppState(counter: 0);
      final environment = TestEnvironment(
        apiUrl: 'https://api.example.com',
        apiKey: 'test-key-123',
      );

      final store = Store<AppState>(
        initialState: initialState,
        environment: environment,
      );

      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StoreProvider<AppState>(
            store: store,
            child: Scaffold(
              body: Builder(builder: (context) {
                buildCount++;
                // Access environment - should not cause rebuilds
                var env = context.env;
                return Text('API: ${env.apiUrl}');
              }),
            ),
          ),
        ),
      );

      expect(buildCount, 1);

      // Dispatch action that changes state
      store.dispatch(IncrementAction());
      await tester.pump();
      await tester.pump();

      // Widget should NOT rebuild because it only accessed env, not state
      expect(buildCount, 1);

      // Dispatch another action
      store.dispatch(IncrementAction());
      await tester.pump();
      await tester.pump();

      // Still no rebuild
      expect(buildCount, 1);
    });

    testWidgets('Environment access combined with state access',
        (WidgetTester tester) async {
      final initialState = AppState(counter: 0);
      final environment = TestEnvironment(
        apiUrl: 'https://api.example.com',
        apiKey: 'test-key-123',
      );

      final store = Store<AppState>(
        initialState: initialState,
        environment: environment,
      );

      int envOnlyBuildCount = 0;
      int stateAndEnvBuildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StoreProvider<AppState>(
            store: store,
            child: Scaffold(
              body: Column(
                children: [
                  // Widget that only accesses env
                  Builder(builder: (context) {
                    envOnlyBuildCount++;
                    var env = context.env;
                    return Text('URL: ${env.apiUrl}');
                  }),
                  // Widget that accesses both env and state
                  Builder(builder: (context) {
                    stateAndEnvBuildCount++;
                    var env = context.env;
                    var counter = context.select((st) => st.counter);
                    return Text('${env.apiKey}: $counter');
                  }),
                ],
              ),
            ),
          ),
        ),
      );

      expect(envOnlyBuildCount, 1);
      expect(stateAndEnvBuildCount, 1);

      // Dispatch action
      store.dispatch(IncrementAction());
      await tester.pump();
      await tester.pump();

      // Only the widget with state access should rebuild
      expect(envOnlyBuildCount, 1); // No rebuild
      expect(stateAndEnvBuildCount, 2); // Rebuilt due to state change
    });

    testWidgets('Environment is same instance across widgets',
        (WidgetTester tester) async {
      final initialState = AppState(counter: 0);
      final environment = TestEnvironment(
        apiUrl: 'https://api.example.com',
        apiKey: 'test-key-123',
      );

      final store = Store<AppState>(
        initialState: initialState,
        environment: environment,
      );

      TestEnvironment? env1;
      TestEnvironment? env2;

      await tester.pumpWidget(
        MaterialApp(
          home: StoreProvider<AppState>(
            store: store,
            child: Scaffold(
              body: Column(
                children: [
                  Builder(builder: (context) {
                    env1 = context.env;
                    return const Text('Widget 1');
                  }),
                  Builder(builder: (context) {
                    env2 = context.env;
                    return const Text('Widget 2');
                  }),
                ],
              ),
            ),
          ),
        ),
      );

      expect(env1, isNotNull);
      expect(env2, isNotNull);
      expect(identical(env1, env2), true);
      expect(identical(env1, environment), true);
    });

    testWidgets('Null environment returns null', (WidgetTester tester) async {
      final initialState = AppState(counter: 0);

      // Store without environment
      final store = Store<AppState>(initialState: initialState);

      Object? capturedEnv;

      await tester.pumpWidget(
        MaterialApp(
          home: StoreProvider<AppState>(
            store: store,
            child: Scaffold(
              body: Builder(builder: (context) {
                capturedEnv = context.getEnvironment<AppState>();
                return Text('Env: $capturedEnv');
              }),
            ),
          ),
        ),
      );

      expect(capturedEnv, isNull);
      expect(find.text('Env: null'), findsOneWidget);
    });

    testWidgets('Environment accessible in nested widgets',
        (WidgetTester tester) async {
      final initialState = AppState(counter: 0);
      final environment = TestEnvironment(
        apiUrl: 'https://api.example.com',
        apiKey: 'nested-test',
      );

      final store = Store<AppState>(
        initialState: initialState,
        environment: environment,
      );

      TestEnvironment? deepNestedEnv;

      await tester.pumpWidget(
        MaterialApp(
          home: StoreProvider<AppState>(
            store: store,
            child: Scaffold(
              body: Container(
                child: Column(
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Builder(builder: (context) {
                          deepNestedEnv = context.env;
                          return Text('Key: ${deepNestedEnv!.apiKey}');
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(deepNestedEnv, isNotNull);
      expect(deepNestedEnv!.apiKey, 'nested-test');
      expect(find.text('Key: nested-test'), findsOneWidget);
    });
  });
}

// Extension for BuildContext
extension BuildContextExtension on BuildContext {
  AppState get state => getState<AppState>();
  R select<R>(R Function(AppState state) selector) =>
      getSelect<AppState, R>(selector);
  TestEnvironment get env => getEnvironment<AppState>() as TestEnvironment;
}

// Test environment class
class TestEnvironment {
  final String apiUrl;
  final String apiKey;

  TestEnvironment({required this.apiUrl, required this.apiKey});
}

// Test state class
class AppState {
  final int counter;

  AppState({required this.counter});

  AppState copyWith({int? counter}) {
    return AppState(counter: counter ?? this.counter);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppState && other.counter == counter;
  }

  @override
  int get hashCode => counter.hashCode;
}

// Test action
class IncrementAction extends ReduxAction<AppState> {
  @override
  AppState reduce() {
    return state.copyWith(counter: state.counter + 1);
  }
}
