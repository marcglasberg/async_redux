import 'dart:math';

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';

// Developed by Marcelo Glasberg (Aug 2019).
// For more info, see: https://pub.dartlang.org/packages/async_redux

late Store<int> store;

/// This example shows how to provide an environment to the Store, to help
/// with dependency injection. The environment is a container for the
/// injected services. We can have many environment implementations, one
/// for production, others for tests etc. In this case, we're using the [EnvironmentImpl].
/// We extend [VmFactory] and [ReduxAction] to provide typed access to the [Environment].
///
void main() {
  store = Store<int>(
    initialState: 0,
    environment: EnvironmentImpl(),
  );
  runApp(MyApp());
}

// ////////////////////////////////////////////////////////////////////////////

/// The environment is a container for the injected services.
abstract class Environment {
  int incrementer(int value, int amount);

  int limit(int value);
}

// ////////////////////////////////////////////////////////////////////////////

/// We can have many environment implementations, one for production,
/// others for tests etc. In this case, we're using the [EnvironmentImpl].
class EnvironmentImpl implements Environment {
  @override
  int incrementer(int value, int amount) => value + amount;

  /// We'll limit the counter at 5.
  @override
  int limit(int value) => min(value, 5);
}

// ////////////////////////////////////////////////////////////////////////////

/// We extend [VmFactory] to provide typed access to the [Environment].
abstract class AppFactory<T> extends VmFactory<int, T> {
  AppFactory([T? widget]) : super(widget);

  @override
  Environment get env => super.env as Environment;
}

// ////////////////////////////////////////////////////////////////////////////

/// We extend [ReduxAction] to provide typed access to the [Environment].
abstract class Action extends ReduxAction<int> {
  @override
  Environment get env => super.env as Environment;
}

// ////////////////////////////////////////////////////////////////////////////

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => StoreProvider<int>(
      store: store,
      child: MaterialApp(
        home: MyHomePageConnector(),
      ));
}

///////////////////////////////////////////////////////////////////////////////

/// This action increments the counter by [amount]].
class IncrementAction extends Action {
  final int amount;

  IncrementAction({required this.amount});

  @override
  int reduce() => env.incrementer(state, amount);
}

///////////////////////////////////////////////////////////////////////////////

/// This widget is a connector.
/// It connects the store to [MyHomePage] (the dumb-widget).
/// Each time the state changes, it creates a view-model, and compares it
/// with the view-model created with the previous state.
/// Only if the view-model changed, the connector rebuilds.
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

/// Factory that creates a view-model for the StoreConnector.
class Factory extends AppFactory<MyHomePageConnector> {
  Factory(widget) : super(widget);

  @override
  ViewModel fromStore() => ViewModel(
        counter: env.limit(state),
        onIncrement: () => dispatch(IncrementAction(amount: 1)),
      );
}

/// A view-model is a helper object to a [StoreConnector] widget. It holds the
/// part of the Store state the corresponding dumb-widget needs, and may also
/// convert this state part into a more convenient format for the dumb-widget
/// to work with.
///
/// You must implement equals/hashcode for the view-model class to work.
/// Otherwise, the [StoreConnector] will think the view-model changed everytime,
/// and thus will rebuild everytime. This won't create any visible problems
/// to your app, but is inefficient and may be slow.
///
/// By extending the [Vm] class you can implement equals/hashcode without
/// having to override these methods. Instead, simply list all fields
/// (which are not immutable, like functions) to the [equals] parameter
/// in the constructor.
///
class ViewModel extends Vm {
  final int counter;
  final VoidCallback onIncrement;

  ViewModel({
    required this.counter,
    required this.onIncrement,
  }) : super(equals: [counter]);
}

///////////////////////////////////////////////////////////////////////////////

/// This is the "dumb-widget". It has no notion of the store, the state, the
/// connector or the view-model. It just gets the parameters it needs to display
/// itself, and callbacks it should call when reacting to the user interface.
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
