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
/// In case you use [StoreConnector], you should also extend [VmFactory] to
/// provide typed access to the [Environment] inside your factories.
///
void main() {
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

/// Extend [VmFactory] to provide typed access to the [Environment] when
/// using [StoreConnector].
abstract class AppFactory<T extends Widget?, Model extends Vm>
    extends VmFactory<int, T, Model> {
  AppFactory([T? connector]) : super(connector);

  @override
  Environment get env => super.env as Environment;
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => StoreProvider<int>(
      store: store,
      child: MaterialApp(
        home: MyHomePageConnector(),
      ));
}

/// This action increments the counter by [amount], using [env].
class IncrementAction extends Action {
  final int amount;

  IncrementAction({required this.amount});

  @override
  int reduce() => env.incrementer(state, amount);
}

/// This widget is a connector. It uses a [StoreConnector] to connect the store
/// to [MyHomePage] (the dumb-widget). Each time the state changes, it creates
/// a view-model, and compares it with the view-model created with the previous
/// state. If the view-model changed, the connector rebuilds. If you don't need
/// to use connectors, you can just use `context.state`, `context.select`,
/// `context.dispatch` etc, directly in your widgets.
class MyHomePageConnector extends StatelessWidget {
  MyHomePageConnector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StoreConnector<int, ViewModel>(
      vm: () => Factory(this),
      builder: (BuildContext context, ViewModel vm) => MyHomePage(
        counter: vm.counter,
        onIncrement: vm.onIncrement,
      ),
    );
  }
}

/// Factory that creates a view-model ([ViewModel]) for the [StoreConnector].
/// It uses [env].
class Factory extends AppFactory<MyHomePageConnector, ViewModel> {
  Factory(connector) : super(connector);

  @override
  ViewModel fromStore() => ViewModel(
        counter: env.limit(state),
        onIncrement: () => dispatch(IncrementAction(amount: 1)),
      );
}

/// A view-model is a helper object to a [StoreConnector] widget. It holds the
/// part of the Store state the corresponding dumb-widget needs.
class ViewModel extends Vm {
  final int counter;
  final VoidCallback onIncrement;

  ViewModel({
    required this.counter,
    required this.onIncrement,
  }) : super(equals: [counter]);
}

class MyHomePage extends StatelessWidget {
  final int? counter;
  final VoidCallback? onIncrement;

  MyHomePage({
    Key? key,
    this.counter,
    this.onIncrement,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
        onPressed: onIncrement,
        child: const Icon(Icons.add),
      ),
    );
  }
}
