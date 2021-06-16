import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';

// Developed by Marcelo Glasberg (Aug 2019).
// For more info, see: https://pub.dartlang.org/packages/async_redux

late Store<int, int> store;

/// This example shows how to use the same view-model architecture of the
/// flutter_redux package. This is specially useful if you are migrating
/// from flutter_redux.
///
/// Here, you use the `StoreConnector`'s `converter` parameter,
/// instead of the `vm` parameter.
/// Your `ViewModel` class may or may not extend `Vm`,
/// but it must have a static factory method, usually named `fromStore`:
///
/// `converter: (store) => ViewModel.fromStore(store)`.
///
void main() {
  store = Store<int, int>(initialState: 0, environment: 0);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => StoreProvider<int, int>(
      store: store,
      child: MaterialApp(
        home: MyHomePageConnector(),
      ));
}

///////////////////////////////////////////////////////////////////////////////

/// This action increments the counter by [amount]].
class IncrementAction extends ReduxAction<int, int> {
  final int amount;

  IncrementAction({required this.amount});

  @override
  int reduce({required int environment}) => state + amount;
}

///////////////////////////////////////////////////////////////////////////////

/// This widget is a connector. It connects the store to "dumb-widget".
class MyHomePageConnector extends StatelessWidget {
  MyHomePageConnector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StoreConnector<int, int, ViewModel>(
      converter: (store) => ViewModel.fromStore(store),
      builder: (BuildContext context, ViewModel vm) => MyHomePage(
        counter: vm.counter,
        onIncrement: vm.onIncrement,
      ),
    );
  }
}

/// The view-model holds the part of the Store state the dumb-widget needs.
class ViewModel extends Vm {
  final int counter;
  final VoidCallback onIncrement;

  ViewModel({
    required this.counter,
    required this.onIncrement,
  }) : super(equals: [counter]);

  /// Static factory called by the StoreConnector's converter parameter.
  static ViewModel fromStore(Store<int, int> store) {
    return ViewModel(
      counter: store.state,
      onIncrement: () => store.dispatch(IncrementAction(amount: 1)),
    );
  }
}

///////////////////////////////////////////////////////////////////////////////

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
      appBar: AppBar(
        title: const Text('Static Factory ViewModel Example'),
        backgroundColor: Colors.green,
      ),
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
        backgroundColor: Colors.green,
      ),
    );
  }
}
