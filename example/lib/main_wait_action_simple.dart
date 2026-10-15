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
/// state, it simply asks the store if the action is running:
///
/// ```
/// var isWaiting = context.isWaiting(IncrementAndGetDescriptionAction);
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
        child: MaterialApp(home: MyHomePage()),
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

class MyHomePage extends StatelessWidget {
  MyHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use context.select to get state values
    var counter = context.select((AppState state) => state.counter);
    var description = context.select((AppState state) => state.description);

    /// While action `IncrementAndGetDescriptionAction` is running,
    /// [isWaiting] will be true.
    var isWaiting = context.isWaiting(IncrementAndGetDescriptionAction);

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
                    style: const TextStyle(fontSize: 15),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => dispatch(IncrementAndGetDescriptionAction()),
            child: const Icon(Icons.add),
          ),
        ),
        if (isWaiting) ModalBarrier(color: Colors.red.withAlpha((255.0 * 0.4).round())),
      ],
    );
  }
}

extension BuildContextExtension on BuildContext {
  AppState get state => getState<AppState>();

  AppState read() => getRead<AppState>();

  R select<R>(R Function(AppState state) selector) =>
      getSelect<AppState, R>(selector);

  R? event<R>(Evt<R> Function(AppState state) selector) =>
      getEvent<AppState, R>(selector);
}
