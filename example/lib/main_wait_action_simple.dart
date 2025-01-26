import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';

// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

late Store<AppState> store;

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
/// The [ViewModel] will read this info from `state.wait.isWaitingAny` to
/// turn on the modal barrier.
///
/// When the async process finishes, the action's before method will
/// remove the action from the wait-flag set:
///
/// ```
/// void after() => dispatch(WaitAction.remove(this));
/// ```
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

/// The app state contains a [wait] object of type [Wait].
@immutable
class AppState {
  final int counter;
  final String description;
  final Wait wait;

  AppState({
    required this.counter,
    required this.description,
    required this.wait,
  });

  /// The copy method has a named [wait] parameter of type [Wait].
  AppState copy({int? counter, String? description, Wait? wait}) => AppState(
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

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => StoreProvider<AppState>(
        store: store,
        child: MaterialApp(home: MyHomePageConnector()),
      );
}

/// Use it like this:
/// `class MyAction extends ReduxAction<AppState> with WithWaitState`
mixin WithWaitState implements ReduxAction<AppState> {
  // Wait starts here. Add the action itself (`this`) as a wait-flag reference.
  @override
  void before() => dispatch(WaitAction.add(this));

  // Wait ends here. Remove the action from the wait-flag references.
  @override
  void after() => dispatch(WaitAction.remove(this));
}

class IncrementAndGetDescriptionAction extends ReduxAction<AppState> with WithWaitState {
  @override
  Future<AppState> reduce() async {
    dispatch(IncrementAction(amount: 1));
    String description = await read(Uri.http("numbersapi.com", "${state.counter}"));
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
        isWaiting: state.wait.isWaitingForType<IncrementAndGetDescriptionAction>(),

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
          appBar: AppBar(title: const Text('Wait Action Example')),
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
        if (isWaiting) ModalBarrier(color: Colors.red.withOpacity(0.4)),
      ],
    );
  }
}
