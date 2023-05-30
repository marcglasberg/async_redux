import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';

// Developed by Marcelo Glasberg (Aug 2019).
// For more info, see: https://pub.dartlang.org/packages/async_redux

late Store<int> store;

/// This example shows a counter and a button. It's similar to the `main.dart`
/// example. However when the counter is `5` the view-model created by the
/// Factory's `fromStore()` will be `null`.
///
/// The `StoreConnector` accept `null` view-models. And when it gets a `null`
/// view-model it simply replaces the screen with a `ViewModel is null` text.
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

class IncrementAction extends ReduxAction<int> {
  final int amount;

  IncrementAction({required this.amount});

  @override
  int reduce() => state + amount;
}

class MyHomePageConnector extends StatelessWidget {
  MyHomePageConnector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ///
    /// 1) The StoreConnector uses `ViewModel?` instead of `ViewModel`.
    return StoreConnector<int, ViewModel?>(
      vm: () => Factory(this),

      /// 2) The builder uses `ViewModel?` instead of `ViewModel`.
      builder: (BuildContext context, ViewModel? vm) {
        return (vm == null)
            ? const Material(
                child: Center(
                  child: const Text("ViewModel is null"),
                ),
              )
            : MyHomePage(
                counter: vm.counter,
                onIncrement: vm.onIncrement,
              );
      },
    );
  }
}

class Factory extends VmFactory<int, MyHomePageConnector, ViewModel> {
  Factory(connector) : super(connector);

  /// 3) The `fromStore` method uses `ViewModel?` instead of `ViewModel`.
  @override
  ViewModel? fromStore() {
    return (store.state == 5)
        ? null
        : ViewModel(
            counter: state,
            onIncrement: () => dispatch(IncrementAction(amount: 1)),
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
      appBar: AppBar(title: const Text('Null ViewModel Example')),
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
