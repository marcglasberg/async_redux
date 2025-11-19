import 'dart:async';
import 'dart:convert';

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
        child: MaterialApp(home: MyHomePage()),
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

class IncrementAndGetDescriptionAction extends ReduxAction<AppState>
    with WithWaitState {
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
    var isWaiting = context.select((AppState state) =>
        state.wait.isWaitingForType<IncrementAndGetDescriptionAction>());

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
                    style: const TextStyle(fontSize: 15),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () =>
                context.dispatch(IncrementAndGetDescriptionAction()),
            child: const Icon(Icons.add),
          ),
        ),
        if (isWaiting) ModalBarrier(color: Colors.red.withOpacity(0.4)),
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
