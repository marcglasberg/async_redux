import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';

/// Developed by Marcelo Glasberg (Aug 2019).
/// For more info, see: https://pub.dartlang.org/packages/async_redux

Store<AppState> store;

/// This example shows a counter, a text description, and a button.
/// When the button is tapped, the counter will increment synchronously,
/// while an async process downloads some text description that relates
/// to the counter number (using the NumberAPI: http://numbersapi.com).
///
/// While the async process is running, a redish modal barrier will prevent
/// the user from tapping the button. The model barrier is removed even if
/// the async process ends with an error, which can be simulated by turning
/// off the internet connection (putting the phone in airplane mode).
///
void main() {
  var state = AppState.initialState();
  store = Store<AppState>(initialState: state);
  runApp(MyApp());
}

///////////////////////////////////////////////////////////////////////////////

/// The app state, which in this case is a counter, a description, and a waiting flag.
class AppState {
  final int counter;
  final String description;
  final bool waiting;

  AppState({this.counter, this.description, this.waiting});

  AppState copy({int counter, String description, bool waiting}) => AppState(
        counter: counter ?? this.counter,
        description: description ?? this.description,
        waiting: waiting ?? this.waiting,
      );

  static AppState initialState() => AppState(counter: 0, description: "", waiting: false);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppState &&
          runtimeType == other.runtimeType &&
          counter == other.counter &&
          description == other.description &&
          waiting == other.waiting;

  @override
  int get hashCode => counter.hashCode ^ description.hashCode ^ waiting.hashCode;
}

///////////////////////////////////////////////////////////////////////////////

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => StoreProvider<AppState>(
      store: store,
      child: MaterialApp(
        home: MyHomePageConnector(),
      ));
}

///////////////////////////////////////////////////////////////////////////////

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
    String description = await read("http://numbersapi.com/${state.counter}");

    // After we get the response, we can modify the state with it,
    // without having to dispatch another action.
    return state.copy(description: description);
  }

  // This adds a modal barrier while the async process is running.
  void before() => dispatch(WaitAction(true));

  // This removes the modal barrier when the async process ends,
  // even if there was some error in the process.
  // You can test it by turning off the internet connection.
  void after() => dispatch(WaitAction(false));
}

///////////////////////////////////////////////////////////////////////////////

class WaitAction extends ReduxAction<AppState> {
  final bool waiting;

  WaitAction(this.waiting);

  @override
  AppState reduce() {
    return state.copy(waiting: waiting);
  }
}

///////////////////////////////////////////////////////////////////////////////

/// This action increments the counter by [amount]].
class IncrementAction extends ReduxAction<AppState> {
  final int amount;

  IncrementAction({@required this.amount}) : assert(amount != null);

  // Synchronous reducer.
  @override
  AppState reduce() => state.copy(counter: state.counter + amount);
}

///////////////////////////////////////////////////////////////////////////////

/// This widget connects the dumb-widget (`MyHomePage`) with the store.
class MyHomePageConnector extends StatelessWidget {
  MyHomePageConnector({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, ViewModel>(
      model: ViewModel(),
      builder: (BuildContext context, ViewModel vm) => MyHomePage(
        counter: vm.counter,
        description: vm.description,
        onIncrement: vm.onIncrement,
        waiting: vm.waiting,
      ),
    );
  }
}

/// Helper class to the connector widget. Holds the part of the State the widget needs,
/// and may perform conversions to the type of data the widget can conveniently work with.
class ViewModel extends BaseModel<AppState> {
  ViewModel();

  int counter;
  String description;
  bool waiting;
  VoidCallback onIncrement;

  ViewModel.build({
    @required this.counter,
    @required this.description,
    @required this.waiting,
    @required this.onIncrement,
  }) : super(equals: [counter, description, waiting]);

  @override
  ViewModel fromStore() => ViewModel.build(
        counter: state.counter,
        description: state.description,
        waiting: state.waiting,
        onIncrement: () => dispatch(IncrementAndGetDescriptionAction()),
      );
}

///////////////////////////////////////////////////////////////////////////////

class MyHomePage extends StatelessWidget {
  final int counter;
  final String description;
  final bool waiting;
  final VoidCallback onIncrement;

  MyHomePage({
    Key key,
    this.counter,
    this.description,
    this.waiting,
    this.onIncrement,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: Text('Before and After Example')),
          body: Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('You have pushed the button this many times:'),
            Text('$counter', style: TextStyle(fontSize: 30)),
            Text(description, style: TextStyle(fontSize: 15), textAlign: TextAlign.center),
          ])),
          floatingActionButton: FloatingActionButton(
            onPressed: onIncrement,
            child: Icon(Icons.add),
          ),
        ),
        if (waiting) ModalBarrier(color: Colors.red.withOpacity(0.4)),
      ],
    );
  }
}
