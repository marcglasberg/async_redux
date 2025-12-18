import 'dart:math';

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';

// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

late Store<int> store;

/// This example shows how to provide an environment to the Store, to help
/// with dependency injection. The environment is a container for the
/// injected services. You can have many environment implementations, one
/// for production, others for tests etc. In this case, we're using the
/// [EnvironmentImpl].
///
/// You should extend [ReduxAction] to provide typed access to the [Environment]
/// inside your actions.
///
/// You should also define a context extension (See [BuildContextExtension.env]
/// below) to provide typed access to the [Environment] inside your widgets. 
///
void main() {
  //
  store = Store<int>(
    initialState: 0,
    environment: EnvironmentImpl(),
  );

  runApp(MyApp());
}

/// The environment is a container for the injected services.
abstract class Environment {
  int incrementer(int value, int amount);

  int limit(int value);
}

/// We can have many environment implementations, one for production, others for
/// staging, tests etc. In this case, we're using the [EnvironmentImpl].
class EnvironmentImpl implements Environment {
  @override
  int incrementer(int value, int amount) => value + amount;

  /// We'll limit the counter at 5.
  @override
  int limit(int value) => min(value, 5);
}

/// Extend [ReduxAction] to provide typed access to the [Environment].
abstract class Action extends ReduxAction<int> {
  @override
  Environment get env => super.env as Environment;
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
  int reduce() => env.incrementer(state, amount);
}

class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Access the store environment.
    final env = context.env;

    // Use context.select to get the limited counter value
    final counter = context.select((state) => env.limit(state));

    return Scaffold(
      appBar: AppBar(title: const Text('Dependency Injection Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'You have pushed the button this many times:\n'
              '(limited to 5)',
              textAlign: TextAlign.center,
            ),
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

  R? event<R>(Evt<R> Function(int state) selector) =>
      getEvent<int, R>(selector);

  Environment get env => getEnvironment<int>() as Environment;
}
