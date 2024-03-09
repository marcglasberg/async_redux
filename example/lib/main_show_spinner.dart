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
      appBar: AppBar(title: const Text('Show Spinner Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('You have pushed the button this many times:'),
            CounterWidget(),
          ],
        ),
      ),
      // Here we disable the button while the `WaitAndIncrementAction` action is running.
      floatingActionButton: context.isWaitingFor(WaitAndIncrementAction)
          ? const FloatingActionButton(
              disabledElevation: 0,
              onPressed: null,
              child: SizedBox(width: 25, height: 25, child: CircularProgressIndicator()))
          : FloatingActionButton(
              disabledElevation: 0,
              onPressed: () => context.dispatch(WaitAndIncrementAction()),
              child: const Icon(Icons.add),
            ),
    );
  }
}

/// This action waits for 2 seconds, then increments the counter by [amount]].
class WaitAndIncrementAction extends ReduxAction<AppState> {
  @override
  Future<AppState?> reduce() async {
    await Future.delayed(const Duration(seconds: 2));
    return AppState(
      counter: state.counter + 1,
      something: state.something,
    );
  }
}

class CounterWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var isWaiting = context.isWaitingFor(WaitAndIncrementAction);

    return Text(
      '${context.state.counter}',
      style: TextStyle(fontSize: 40, color: isWaiting ? Colors.grey[350] : Colors.black),
    );
  }
}

extension BuildContextExtension<T extends AppState> on BuildContext {
  //
  AppState get state => StoreProvider.state<AppState>(this);

  FutureOr<ActionStatus> dispatch(ReduxAction<AppState> action, {bool notify = true}) =>
      StoreProvider.dispatch(this, action, notify: notify);

  Future<ActionStatus> dispatchAndWait(ReduxAction<AppState> action, {bool notify = true}) =>
      StoreProvider.dispatchAndWait(this, action, notify: notify);

  ActionStatus dispatchSync(ReduxAction<AppState> action, {bool notify = true}) =>
      StoreProvider.dispatchSync(this, action, notify: notify);

  bool isWaitingFor(Object actionOrTypeOrList) =>
      StoreProvider.isWaitingFor<AppState>(this, actionOrTypeOrList);
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
