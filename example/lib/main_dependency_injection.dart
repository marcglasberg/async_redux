import 'dart:math';

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';

// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

late Store<int> store;

/// This example shows how to provide both an environment and dependencies to the Store,
/// to help with dependency injection. The "dependencies" is a container for the
/// injected services. You can have many dependency implementations, one
/// for production, others for tests etc. In this case, we're using the
/// [DependenciesProduction].
///
/// You should extend [ReduxAction] to provide typed access to the [Dependencies]
/// inside your actions.
///
/// You should also define a context extension (See [BuildContextExtension.environment]
/// below) to provide typed access to the [Environment] inside your widgets.
///
void main() {
  //
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

/// The Dependencies class is a container for the injected services.
/// We can have many dependency implementations, one for production, others for
/// staging, tests etc.
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

  /// This demonstrates how the environment can be used to change the behavior of the
  /// dependencies. In this case, we have a method that limits the counter value,
  /// and the limit is different in production:
  /// - We limit the counter at 5, when in production
  /// - We limit the counter at 1000, when in staging or testing.
  int limit(int value);
}

/// Limit is 5 in production. 
class DependenciesProduction implements Dependencies {
  @override
  int limit(int value) => min(value, 5);
}

/// Limit is 25 in staging.
class DependenciesStaging implements Dependencies {
  @override
  int limit(int value) => min(value, 25);
}

/// Limit is 1000 in testing.
class DependenciesTesting implements Dependencies {
  @override
  int limit(int value) => min(value, 1000);
}

/// Extend [ReduxAction] to provide typed access to the [Dependencies].
abstract class Action extends ReduxAction<int> {
  Dependencies get dependencies => super.store.dependencies as Dependencies;
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StoreProvider<int>(
      store: store,
      child: MaterialApp(
        home: MyHomePage(),
      ),
    );
  }
}

/// This action increments the counter by [amount], using [env].
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
            // We can use the environment to change the UI as well.
            Text('Running in ${env}.', textAlign: TextAlign.center),
            //
            const Text(
              'You have pushed the button this many times:\n'
              '(limited by the environment)',
              textAlign: TextAlign.center,
            ),
            //
            Text('$counter', style: const TextStyle(fontSize: 30))
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

  /// This is in case the UI needs to know if we are in production, staging or testing.
  Environment get environment => getEnvironment<int>() as Environment;
}
