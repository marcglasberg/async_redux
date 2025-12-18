import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';

// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

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
          home: MyHomePage(),
        ),
      );
}

/// This action increments the counter by [amount]].
class IncrementAction extends ReduxAction<int> {
  final int amount;

  IncrementAction({required this.amount});

  @override
  int reduce() => state + amount;
}

/// This is a "smart-widget" that directly accesses the store state using
/// `context.state` and dispatches actions using `dispatch`.
class MyHomePage extends StatelessWidget {
  MyHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // In this simple example, the counter is the state.
    // This will rebuild whenever the state changes.
    // In more complex cases where we want the widget to rebuild only when
    // specific parts of the state change, we can use `context.select` instead.
    final counter = context.state;

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
        // Dispatch action directly from widget
        onPressed: () => dispatch(IncrementAction(amount: 1)),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Recommended to create this extension.
extension BuildContextExtension on BuildContext {
  int get state => getState<int>();

  int read() => getRead<int>();

  R select<R>(R Function(int state) selector) => getSelect<int, R>(selector);
}
