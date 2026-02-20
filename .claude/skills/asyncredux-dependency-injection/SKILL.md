---
name: asyncredux-dependency-injection
description: Inject dependencies into actions using the environment, dependencies, and configuration pattern. Covers creating an Environment enum, a Dependencies class, passing them to the Store, accessing them from actions and widgets, and using dependency injection for testability.
---

# Dependency Injection with Environment, Dependencies, and Configuration

AsyncRedux provides dependency injection through three Store parameters:

- **`environment`**: Specifies if the app is running in production, staging, development, testing, etc. Should be immutable and not change during app execution. Accessible from both actions and widgets.
- **`dependencies`**: A container for injected services (repositories, APIs, etc.), created via a factory that receives the `Store`, so it can vary based on the environment. Usually not accessible from widgets.
- **`configuration`**: For feature flags and other configuration values. Accessible from both actions and widgets.

## Step 1: Define the Environment

Create an enum (or class) specifying the app's running context:

```dart
enum Environment {
  production,
  staging,
  testing;

  bool get isProduction => this == Environment.production;
  bool get isStaging => this == Environment.staging;
  bool get isTesting => this == Environment.testing;
}
```

## Step 2: Define the Dependencies

Create an abstract class with a factory that returns different implementations based on the environment:

```dart
abstract class Dependencies {
  factory Dependencies(Store store) {
    if (store.environment == Environment.production) {
      return DependenciesProduction();
    } else if (store.environment == Environment.staging) {
      return DependenciesStaging();
    } else {
      return DependenciesTesting();
    }
  }

  ApiClient get apiClient;
  AuthService get authService;
  int limit(int value);
}

class DependenciesProduction implements Dependencies {
  @override
  ApiClient get apiClient => RealApiClient();

  @override
  AuthService get authService => FirebaseAuthService();

  @override
  int limit(int value) => min(value, 5);
}

class DependenciesTesting implements Dependencies {
  @override
  ApiClient get apiClient => MockApiClient();

  @override
  AuthService get authService => MockAuthService();

  @override
  int limit(int value) => min(value, 1000); // Higher limit in tests
}
```

## Step 3: Define the Configuration (optional)

```dart
class Config {
  bool isABtestingOn = false;
  bool showAdminConsole = false;
}
```

## Step 4: Pass All Three to the Store

When creating the store, pass the environment, dependencies factory, and configuration factory:

```dart
void main() {
  var store = Store<AppState>(
    initialState: AppState.initialState(),
    environment: Environment.production,
    dependencies: (store) => Dependencies(store),
    configuration: (store) => Config(),
  );

  runApp(
    StoreProvider<AppState>(
      store: store,
      child: MyApp(),
    ),
  );
}
```

The `dependencies` and `configuration` parameters are factories that receive the `Store`, so they can read `store.environment` to vary their behavior.

## Step 5: Access from Actions via a Base Action Class

Define a base action class with typed getters for `dependencies`, `environment`, and `configuration`:

```dart
abstract class Action extends ReduxAction<AppState> {
  Dependencies get dependencies => super.store.dependencies as Dependencies;
  Environment get environment => super.store.environment as Environment;
  Config get config => super.store.configuration as Config;
}
```

Now use them in your actions:

```dart
class FetchUserAction extends Action {
  final String userId;
  FetchUserAction(this.userId);

  @override
  Future<AppState?> reduce() async {
    final user = await dependencies.apiClient.fetchUser(userId);
    return state.copy(user: user);
  }
}

class IncrementAction extends Action {
  final int amount;
  IncrementAction({required this.amount});

  @override
  AppState reduce() {
    int newState = state.counter + amount;
    int limitedState = dependencies.limit(newState);
    return state.copy(counter: limitedState);
  }
}
```

## Step 6: Access from Widgets via BuildContext Extension

Create a `BuildContext` extension. The `environment` and `configuration` are available via `getEnvironment` and `getConfiguration`. Note: `dependencies` should usually NOT be accessed from widgets.

```dart
extension BuildContextExtension on BuildContext {
  AppState get state => getState<AppState>();

  R select<R>(R Function(AppState state) selector) =>
      getSelect<AppState, R>(selector);

  /// Access the environment from widgets (does not trigger rebuilds).
  Environment get environment => getEnvironment<AppState>() as Environment;

  /// Access the configuration from widgets (does not trigger rebuilds).
  Config get config => getConfiguration<AppState>() as Config;
}
```

Use in widgets:

```dart
class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final env = context.environment;
    int counter = context.state;

    return Scaffold(
      appBar: AppBar(title: const Text('Dependency Injection Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Use the environment to change the UI.
            Text('Running in ${env}.', textAlign: TextAlign.center),
            Text('$counter', style: const TextStyle(fontSize: 30)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => dispatch(IncrementAction(amount: 1)),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

## Step 7 (if using StoreConnector): Access from VmFactory

If you use `StoreConnector`, extend `VmFactory` with typed getters:

```dart
abstract class AppFactory<T extends Widget?, Model extends Vm>
    extends VmFactory<AppState, T, Model> {
  AppFactory([T? connector]) : super(connector);

  Dependencies get dependencies => store.dependencies as Dependencies;
  Environment get environment => store.environment as Environment;
  Config get config => store.configuration as Config;
}
```

## Testing with Different Environments

The pattern makes testing straightforward by injecting test implementations:

```dart
void main() {
  group('IncrementAction', () {
    test('increments counter with test dependencies', () async {
      var store = Store<AppState>(
        initialState: AppState(counter: 0),
        environment: Environment.testing,
        dependencies: (store) => Dependencies(store), // Returns DependenciesTesting
      );

      await store.dispatchAndWait(IncrementAction(amount: 5));

      // DependenciesTesting has limit of 1000, so value is 5
      expect(store.state.counter, 5);
    });

    test('production dependencies limit counter', () async {
      var store = Store<AppState>(
        initialState: AppState(counter: 3),
        environment: Environment.production,
        dependencies: (store) => Dependencies(store), // Returns DependenciesProduction
      );

      await store.dispatchAndWait(IncrementAction(amount: 10));

      // DependenciesProduction limits to 5
      expect(store.state.counter, 5);
    });
  });
}
```

## Complete Working Example

```dart
import 'dart:math';
import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';

late Store<int> store;

void main() {
  store = Store<int>(
    initialState: 0,
    environment: Environment.production,
    dependencies: (store) => Dependencies(store),
  );
  runApp(MyApp());
}

enum Environment {
  production,
  staging,
  testing;

  bool get isProduction => this == Environment.production;
  bool get isStaging => this == Environment.staging;
  bool get isTesting => this == Environment.testing;
}

abstract class Dependencies {
  factory Dependencies(Store store) {
    if (store.environment == Environment.production) {
      return DependenciesProduction();
    } else if (store.environment == Environment.staging) {
      return DependenciesStaging();
    } else {
      return DependenciesTesting();
    }
  }

  int limit(int value);
}

class DependenciesProduction implements Dependencies {
  @override
  int limit(int value) => min(value, 5);
}

class DependenciesStaging implements Dependencies {
  @override
  int limit(int value) => min(value, 25);
}

class DependenciesTesting implements Dependencies {
  @override
  int limit(int value) => min(value, 1000);
}

abstract class Action extends ReduxAction<int> {
  Dependencies get dependencies => super.store.dependencies as Dependencies;
}

class IncrementAction extends Action {
  final int amount;
  IncrementAction({required this.amount});

  @override
  int reduce() {
    int newState = state + amount;
    int limitedState = dependencies.limit(newState);
    return limitedState;
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StoreProvider<int>(
      store: store,
      child: MaterialApp(home: MyHomePage()),
    );
  }
}

class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final env = context.environment;
    int counter = context.state;

    return Scaffold(
      appBar: AppBar(title: const Text('Dependency Injection Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Running in ${env}.', textAlign: TextAlign.center),
            const Text(
              'You have pushed the button this many times:\n'
              '(limited by the environment)',
              textAlign: TextAlign.center,
            ),
            Text('$counter', style: const TextStyle(fontSize: 30)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => dispatch(IncrementAction(amount: 1)),
        child: const Icon(Icons.add),
      ),
    );
  }
}

extension BuildContextExtension on BuildContext {
  int get state => getState<int>();
  int read() => getRead<int>();
  R select<R>(R Function(int state) selector) => getSelect<int, R>(selector);
  R? event<R>(Evt<R> Function(int state) selector) => getEvent<int, R>(selector);
  Environment get environment => getEnvironment<int>() as Environment;
}
```

## Key Benefits

- **Separation of concerns**: `environment` identifies the running context, `dependencies` provides services, `configuration` holds feature flags
- **Testability**: Swap implementations by changing the environment, without changing action code
- **Type safety**: Typed getters in base action class provide compile-time checking
- **Factory pattern**: The `dependencies` and `configuration` factories receive the `Store`, allowing them to vary based on `environment`
- **Scoped dependencies**: Each store instance has its own environment/dependencies/configuration, preventing test contamination

## References

URLs from the documentation:
- https://asyncredux.com/sitemap.xml
- https://asyncredux.com/flutter/miscellaneous/dependency-injection
- https://asyncredux.com/flutter/testing/mocking
- https://asyncredux.com/flutter/basics/store
- https://asyncredux.com/flutter/advanced-actions/redux-action
- https://asyncredux.com/flutter/connector/store-connector
- https://asyncredux.com/flutter/testing/store-tester
- https://asyncredux.com/flutter/testing/dispatch-wait-and-expect
- https://github.com/marcglasberg/async_redux/blob/master/example/lib/main_dependency_injection.dart
