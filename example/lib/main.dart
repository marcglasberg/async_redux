import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';

// Developed by Marcelo Glasberg (Aug 2019).
// For more info, see: https://pub.dartlang.org/packages/async_redux

Store<int> store;

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

  IncrementAction({@required this.amount}) : assert(amount != null);

  @override
  int reduce() => state + amount;
}

///////////////////////////////////////////////////////////////////////////////

/// This widget connects the dumb-widget (`MyHomePage`) with the store.
class MyHomePageConnector extends StatelessWidget {
  MyHomePageConnector({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StoreConnector<int, ViewModel>(
      model: ViewModel(),
      builder: (BuildContext context, ViewModel vm) => MyHomePage(
        counter: vm.counter,
        onIncrement: vm.onIncrement,
      ),
    );
  }
}

/// Helper class to the connector widget. Holds the part of the State the widget needs,
/// and may perform conversions to the type of data the widget can conveniently work with.
class ViewModel extends BaseModel<int> {
  ViewModel();

  int counter;
  VoidCallback onIncrement;

  ViewModel.build({
    @required this.counter,
    @required this.onIncrement,
  }) : super(equals: [counter]);

  @override
  ViewModel fromStore() => ViewModel.build(
        counter: state,
        onIncrement: () => dispatch(IncrementAction(amount: 1)),
      );
}

///////////////////////////////////////////////////////////////////////////////

class MyHomePage extends StatelessWidget {
  final int counter;
  final VoidCallback onIncrement;

  MyHomePage({
    Key key,
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
        child: Icon(Icons.add),
      ),
    );
  }
}
