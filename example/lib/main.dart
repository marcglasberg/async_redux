import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';

// Developed by Marcelo Glasberg (Aug 2019).
// For more info, see: https://pub.dartlang.org/packages/async_redux

late Store<int> store;

/// This example shows a counter and a button.
/// When the button is tapped, the counter will increment synchronously.
///
/// In this simple example, the app state is simply a number (the counter),
/// and thus the store is defined as `Store<int>`. The initial state is 0.
///
void main() {
  store = Store<int>(initialState: 0);
  runApp(MyApp());
}

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
class IncrementAction extends ReduxAction<int> {
  final int amount;

  IncrementAction({required this.amount});

  @override
  int reduce() => state + amount;
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
class Factory extends VmFactory<int, MyHomePageConnector, ViewModel> {
  Factory(connector) : super(connector);

  @override
  ViewModel fromStore() => ViewModel(
        counter: state,
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
      appBar: AppBar(title: const Text('Increment Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('You have pushed the button this many times:'),
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
