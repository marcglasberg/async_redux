import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';

// Developed by Marcelo Glasberg (Aug 2019).
// For more info, see: https://pub.dartlang.org/packages/async_redux

late Store<int> store;

/// This example shows how to prevent creating view-models from invalid states.
/// When the button is tapped, the counter will increment 5 times, synchronously.
/// So, the sequence would be 0, 5, 10, 15, 20, 25 etc.
///
/// However, we consider odd numbers invalid.
/// Therefore, it will display 0, 4, 10, 14, 20, 24 etc.
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

class MyHomePageConnector extends StatelessWidget {
  MyHomePageConnector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StoreConnector<int, ViewModel>(
      vm: () => Factory(this),
      //
      // Should update the view-model only when the counter is even.
      shouldUpdateModel: (int count) => count % 2 == 0,
      //
      builder: (BuildContext context, ViewModel vm) => MyHomePage(
        counter: vm.counter,
        onIncrement: vm.onIncrement,
      ),
    );
  }
}

/// Factory that creates a view-model for the StoreConnector.
class Factory extends VmFactory<int, MyHomePageConnector> {
  Factory(widget) : super(widget);

  @override
  ViewModel fromStore() {
    return ViewModel(
      counter: state,
      onIncrement: () {
        // Increment 5 times.
        dispatch!(IncrementAction(amount: 1));
        dispatch!(IncrementAction(amount: 1));
        dispatch!(IncrementAction(amount: 1));
        dispatch!(IncrementAction(amount: 1));
        dispatch!(IncrementAction(amount: 1));
      },
    );
  }
}

class ViewModel extends Vm {
  final int counter;
  final VoidCallback onIncrement;

  ViewModel({
    required this.counter,
    required this.onIncrement,
  }) : super(equals: [counter]);
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
      appBar: AppBar(title: const Text('Increment Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text('Each time you push the button it increments 5 times.\n\n'
                  'But only even values are valid to appear in the UI.\n\n'
                  'This demonstrates the use of StoreConnector.shouldUpdateModel.'),
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
