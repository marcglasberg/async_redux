import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';

// Developed by Marcelo Glasberg (Aug 2019).
// For more info, see: https://pub.dartlang.org/packages/async_redux

Store<AppState> store;

/// This example is the same as the one in `main_before_and_after.dart`.
/// However, instead of declaring a `MyWaitAction`, it uses the build-in
/// [WaitAction].
///
/// For this to work, the [AppState] must have a [wait] field of type [Wait],
/// and this field must be in the [AppState.copy] method as a named parameter.
///
/// While the async process is running, the action's `before` method will
/// add the action itself as a wait-flag reference:
///
/// ```
/// void before() => dispatch(WaitAction.add(this));
/// ```
///
/// The [ViewModel] will read this info from `state.wait.isWaiting` to
/// turn on the modal barrier.
///
/// When the async process finishes, the action's before method will
/// remove the action from the wait-flag set:
///
/// ```
/// void after() => dispatch(WaitAction.remove(this));
/// ```
///
void main() {
  var state = AppState.initialState();
  store = Store<AppState>(initialState: state);
  runApp(MyApp());
}

///////////////////////////////////////////////////////////////////////////////

/// The app state contains a [wait] object of type [Wait].
class AppState {
  final int counter;
  final String description;
  final Wait wait;

  AppState({this.counter, this.description, this.wait});

  /// The copy method has a named [wait] parameter of type [Wait].
  AppState copy({int counter, String description, Wait wait}) => AppState(
        counter: counter ?? this.counter,
        description: description ?? this.description,
        wait: wait ?? this.wait,
      );

  /// The [wait] parameter is instantiated to `Wait()`.
  static AppState initialState() => AppState(
        counter: 0,
        description: "",
        wait: Wait(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppState &&
          runtimeType == other.runtimeType &&
          counter == other.counter &&
          description == other.description &&
          wait == other.wait;

  @override
  int get hashCode => counter.hashCode ^ description.hashCode ^ wait.hashCode;
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

class IncrementAndGetDescriptionAction extends ReduxAction<AppState> {
  @override
  Future<AppState> reduce() async {
    dispatch(IncrementAction(amount: 1));
    String description = await read("http://numbersapi.com/${state.counter}");
    return state.copy(description: description);
  }

  // The wait starts here. We add the action itself (`this`)
  // as a wait-flag reference.
  void before() => dispatch(WaitAction.add(this));

  // The wait ends here. We remove the action from the
  // wait-flag references.
  void after() => dispatch(WaitAction.remove(this));
}

///////////////////////////////////////////////////////////////////////////////

class IncrementAction extends ReduxAction<AppState> {
  final int amount;

  IncrementAction({@required this.amount}) : assert(amount != null);

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

        /// If there is any waiting, `state.wait.isWaiting` will return true.
        waiting: state.wait.isWaiting,

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
          appBar: AppBar(title: Text('Wait Action Example')),
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
