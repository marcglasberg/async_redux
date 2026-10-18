// ignore_for_file: async_redux_lints/extend_base_action

import 'dart:async';
import 'dart:convert';

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';

// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

late Store<AppState> store;

/// This example is the same as the one in `main_before_and_after.dart`.
/// However, instead of declaring a `MyWaitAction` that puts a boolean flag in the
/// state, the view-model factory simply asks the store if the action is running:
///
/// ```
/// isWaiting: isWaiting(IncrementAndGetDescriptionAction),
/// ```
///
/// While the async action `IncrementAndGetDescriptionAction` is running, `isWaiting`
/// is true, and the widget shows a modal barrier. Nothing needs to be added to the
/// state, and nothing needs to be cleaned up when the action finishes or fails.
///
void main() {
  var state = AppState.initialState();
  store = Store<AppState>(initialState: state);
  runApp(MyApp());
}

@stateClass
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
        child: MaterialApp(home: MyHomePageConnector()),
      );
}

class IncrementAndGetDescriptionAction extends ReduxAction<AppState> {
  @override
  Future<AppState> reduce() async {
    dispatch(IncrementAction(amount: 1));

    // Then, we start and wait for some asynchronous process.
    Response response = await get(
      Uri.parse("https://swapi.dev/api/people/${state.counter}/"),
    );
    Map<String, dynamic> json = jsonDecode(response.body);
    String description = json['name'] ?? 'Unknown character';

    return state.copy(description: description);
  }
}

class IncrementAction extends ReduxAction<AppState> {
  final int amount;

  IncrementAction({required this.amount});

  @override
  AppState reduce() => state.copy(counter: state.counter + amount);
}

/// This widget is a connector. It connects the store to "dumb-widget".
class MyHomePageConnector extends StatelessWidget {
  MyHomePageConnector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, ViewModel>(
      vm: () => Factory(this),
      builder: (BuildContext context, ViewModel vm) => MyHomePage(
        counter: vm.counter,
        description: vm.description,
        onIncrement: vm.onIncrement,
        isWaiting: vm.isWaiting,
      ),
    );
  }
}

/// Factory that creates a view-model for the StoreConnector.
class Factory extends VmFactory<AppState, MyHomePageConnector, ViewModel> {
  Factory(connector) : super(connector);

  @override
  ViewModel fromStore() => ViewModel(
        counter: state.counter,
        description: state.description,

        /// While action `IncrementAndGetDescriptionAction` is running,
        /// [isWaiting] will be true.
        isWaiting: isWaiting(IncrementAndGetDescriptionAction),

        onIncrement: () => dispatch(IncrementAndGetDescriptionAction()),
      );
}

/// The view-model holds the part of the Store state the dumb-widget needs.
class ViewModel extends Vm {
  final int counter;
  final String description;
  final bool isWaiting;
  final VoidCallback onIncrement;

  ViewModel({
    required this.counter,
    required this.description,
    required this.isWaiting,
    required this.onIncrement,
  }) : super(equals: [counter, description, isWaiting]);
}

class MyHomePage extends StatelessWidget {
  final int counter;
  final String description;
  final bool isWaiting;
  final VoidCallback onIncrement;

  MyHomePage({
    Key? key,
    required this.counter,
    required this.description,
    required this.isWaiting,
    required this.onIncrement,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: const Text('Is Waiting Example')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('You have pushed the button this many times:'),
                Text('$counter', style: const TextStyle(fontSize: 30)),
                Text(description,
                    style: const TextStyle(fontSize: 15), textAlign: TextAlign.center),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: onIncrement,
            child: const Icon(Icons.add),
          ),
        ),
        if (isWaiting) ModalBarrier(color: Colors.red.withAlpha((255.0 * 0.4).round())),
      ],
    );
  }
}
