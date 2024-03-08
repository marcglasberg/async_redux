// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// For more info, see: https://pub.dartlang.org/packages/async_redux
import 'dart:async';
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
      appBar: AppBar(title: const Text('StateConnector vs StateProvider')),
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
        onPressed: () => context.dispatch(IncrementAction()),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// This action increments the counter by [amount]].
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
          Text('$value', style: const TextStyle(fontSize: 30)),
          const Text(
              'Value read with the StoreConnector:\n`StoreConnector(builder: (context, value) => ...)`',
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.center),
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
        Text('${context.state.counter}', style: const TextStyle(fontSize: 30)),
        const Text('Value read with the StoreProvider:\n`context.state.counter`',
            style: const TextStyle(fontSize: 13), textAlign: TextAlign.center),
      ],
    );
  }
}

extension BuildContextExtension on BuildContext {
  //
  AppState get state => StoreProvider.state<AppState>(this);

  FutureOr<ActionStatus> dispatch(ReduxAction<AppState> action, {bool notify = true}) =>
      StoreProvider.dispatch(this, action, notify: notify);

  Future<ActionStatus> dispatchAndWait(ReduxAction<AppState> action, {bool notify = true}) =>
      StoreProvider.dispatchAndWait(this, action, notify: notify);

  ActionStatus dispatchSync(ReduxAction<AppState> action, {bool notify = true}) =>
      StoreProvider.dispatchSync(this, action, notify: notify);
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
