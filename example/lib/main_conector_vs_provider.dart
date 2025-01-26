// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux
import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';

late Store<AppState> store;

/// This example shows a counter and a button.
/// When the button is tapped, the counter will increment synchronously.
void main() {
  store = Store<AppState>(initialState: AppState(counter: 0, something: 0));
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => StoreProvider<AppState>(
        store: store,
        child: const MaterialApp(home: HomePage()),
      );
}

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connector vs Provider Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GetsStateFromStoreConnector(),
            const SizedBox(height: 40),
            GetsStateFromStoreProvider(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        disabledElevation: 0,
        onPressed: () => context.dispatch(IncrementAction()),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class IncrementAction extends ReduxAction<AppState> {
  @override
  AppState reduce() {
    return AppState(
      counter: state.counter + 1,
      something: state.something,
    );
  }
}

class GetsStateFromStoreConnector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StoreConnector(
      converter: (Store<AppState> store) => store.state.counter,
      builder: (context, value) => Column(
        children: [
          Text('$value', style: const TextStyle(fontSize: 30, color: Colors.black)),
          const Text(
            'Value read with the StoreConnector:\n`StoreConnector(builder: (context, value) => ...)`',
            style: const TextStyle(fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class GetsStateFromStoreProvider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('${context.state.counter}', style: const TextStyle(fontSize: 30, color: Colors.black)),
        const Text(
          'Value read with the StoreProvider:\n`context.state.counter`',
          style: TextStyle(fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

extension _BuildContextExtension on BuildContext {
  AppState get state => getState<AppState>();
}

class AppState {
  int counter;
  int something;

  AppState({
    required this.counter,
    required this.something,
  });

  @override
  String toString() => 'AppState{counter: $counter}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppState && runtimeType == other.runtimeType && counter == other.counter;

  @override
  int get hashCode => counter.hashCode;
}
