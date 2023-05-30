import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';

// Developed by Marcelo Glasberg (Aug 2019).
// For more info, see: https://pub.dartlang.org/packages/async_redux

late Store<AppState> store;

/// This example shows a counter, a text description, and a button.
/// When the button is tapped, the counter will increment synchronously,
/// while an async process downloads some text description that relates
/// to the counter number (using the NumberAPI: http://numbersapi.com).
///
/// Note: This example uses http. It was configured to work in Android, debug mode only.
/// If you use iOS, please see:
/// https://flutter.dev/docs/release/breaking-changes/network-policy-ios-android
///
void main() {
  var state = AppState.initialState();
  store = Store<AppState>(initialState: state);
  runApp(MyApp());
}

/// The app state, which in this case is a counter and a description.
@immutable
class AppState {
  final int counter;
  final String description;

  AppState({
    required this.counter,
    required this.description,
  });

  AppState copy({int? counter, String? description}) => AppState(
        counter: counter ?? this.counter,
        description: description ?? this.description,
      );

  static AppState initialState() => AppState(counter: 0, description: "");

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppState &&
          runtimeType == other.runtimeType &&
          counter == other.counter &&
          description == other.description;

  @override
  int get hashCode => counter.hashCode ^ description.hashCode;
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => StoreProvider<AppState>(
      store: store,
      child: MaterialApp(
        home: MyHomePageConnector(),
      ));
}

/// This action increments the counter by 1,
/// and then gets some description text relating to the new counter number.
class IncrementAndGetDescriptionAction extends ReduxAction<AppState> {
  //
  // Async reducer.
  // To make it async we simply return Future<AppState> instead of AppState.
  @override
  Future<AppState> reduce() async {
    // First, we increment the counter, synchronously.
    dispatch(IncrementAction(amount: 1));

    // Then, we start and wait for some asynchronous process.
    String description = await read(Uri.http("numbersapi.com", "${state.counter}"));

    // After we get the response, we can modify the state with it,
    // without having to dispatch another action.
    return state.copy(description: description);
  }
}

/// This action increments the counter by [amount]].
class IncrementAction extends ReduxAction<AppState> {
  final int amount;

  IncrementAction({required this.amount});

  // Synchronous reducer.
  @override
  AppState reduce() => state.copy(counter: state.counter + amount);
}

/// This widget is a connector. It connects the store to "dumb-widget".
class MyHomePageConnector extends StatelessWidget {
  MyHomePageConnector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, ViewModel>(
      vm: () => Factory(),
      builder: (BuildContext context, ViewModel vm) => MyHomePage(
        counter: vm.counter,
        description: vm.description,
        onIncrement: vm.onIncrement,
      ),
    );
  }
}

/// Factory that creates a view-model for the StoreConnector.
class Factory extends VmFactory<AppState, MyHomePageConnector, ViewModel> {
  @override
  ViewModel fromStore() => ViewModel(
        counter: state.counter,
        description: state.description,
        onIncrement: _onIncrement,
      );

  void _onIncrement() {
    dispatch(IncrementAndGetDescriptionAction());

    print('Counter in the the view-model = ${vm.counter}');
    print('Counter in the state when the view-model was created = ${state.counter}');
    print('Counter in the current state = ${currentState().counter}');
  }
}

/// The view-model holds the part of the Store state the dumb-widget needs.
class ViewModel extends Vm {
  final int counter;
  final String description;
  final VoidCallback onIncrement;

  ViewModel({
    required this.counter,
    required this.description,
    required this.onIncrement,
  }) : super(equals: [counter, description]);
}

class MyHomePage extends StatelessWidget {
  final int? counter;
  final String? description;
  final VoidCallback? onIncrement;

  MyHomePage({
    Key? key,
    this.counter,
    this.description,
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
            Text('$counter', style: const TextStyle(fontSize: 30)),
            Text(description!, style: const TextStyle(fontSize: 15), textAlign: TextAlign.center),
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
