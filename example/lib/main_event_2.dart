import 'dart:async';
import 'dart:convert';

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';

// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

late Store<AppState> store;

/// This example is similar to example `main_event.dart`, meant to demonstrate
/// the use of "events" (of type [Event] or [Evt]) to change a controller state,
/// or perform any other one-time operation.
///
/// However, here we consume the events in the `didChangeDependencies()` method
/// of the stateful widget, instead of in the `build()` method.
///
/// To allow that, we need to turn off the debug mode of the `getEvent()` method,
/// as shown in the extension method below:
///
/// ```dart
/// extension BuildContextExtension on BuildContext {
///   R? event<R>(Evt<R> Function(AppState state) selector) =>
///       getEvent<AppState, R>(selector, debug: false);
/// }
/// ```
///
/// Use with care, as invalid usage in methods like `initState` will
/// no longer be detected once the debug check is off.
///
void main() {
  var state = AppState.initialState();
  store = Store<AppState>(initialState: state);
  runApp(MyApp());
}

/// The app state, which in this case is a counter and two events.
@immutable
class AppState {
  final int counter;
  final bool waiting;
  final Event clearTextEvt;
  final Event<String> changeTextEvt;

  AppState({
    required this.counter,
    required this.waiting,
    required this.clearTextEvt,
    required this.changeTextEvt,
  });

  AppState copy({
    int? counter,
    bool? waiting,
    Event? clearTextEvt,
    Event<String>? changeTextEvt,
  }) =>
      AppState(
        counter: counter ?? this.counter,
        waiting: waiting ?? this.waiting,
        clearTextEvt: clearTextEvt ?? this.clearTextEvt,
        changeTextEvt: changeTextEvt ?? this.changeTextEvt,
      );

  static AppState initialState() => AppState(
        counter: 1,
        waiting: false,
        clearTextEvt: Event.spent(),
        changeTextEvt: Event<String>.spent(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppState &&
          runtimeType == other.runtimeType &&
          counter == other.counter &&
          waiting == other.waiting;

  @override
  int get hashCode => counter.hashCode ^ waiting.hashCode;
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => StoreProvider<AppState>(
        store: store,
        child: MaterialApp(
          home: MyHomePage(),
        ),
      );
}

/// This action orders the text-controller to clear.
class ClearTextAction extends ReduxAction<AppState> {
  @override
  AppState reduce() => state.copy(clearTextEvt: Event());
}

/// Actions that extend [BarrierAction] show a modal barrier while their async processes run.
abstract class BarrierAction extends ReduxAction<AppState> {
  @override
  void before() => dispatch(_WaitAction(true));

  @override
  void after() => dispatch(_WaitAction(false));
}

class _WaitAction extends ReduxAction<AppState> {
  final bool waiting;

  _WaitAction(this.waiting);

  @override
  AppState reduce() => state.copy(waiting: waiting);
}

/// This action downloads some new text, and then creates an event
/// that tells the text-controller to display that new text.
class ChangeTextAction extends BarrierAction {
  @override
  Future<AppState> reduce() async {
    //
    // Then, we start and wait for some asynchronous process.
    Response response = await get(
      Uri.parse("https://swapi.dev/api/people/${state.counter}/"),
    );
    Map<String, dynamic> json = jsonDecode(response.body);
    String newText = json['name'] ?? 'Unknown Star Wars character';

    return state.copy(
      counter: state.counter + 1,
      changeTextEvt: Event<String>(newText),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Event that tells the controller to clear its text.
    var clearText = context.event((state) => state.clearTextEvt);
    if (clearText) controller.clear();

    // Event that tells the controller to change its text.
    var newText = context.event((state) => state.changeTextEvt);
    if (newText != null) controller.text = newText;
  }

  @override
  Widget build(BuildContext context) {
    //
    var waiting = context.select((state) => state.waiting);

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: const Text('Event in didChangeDependencies Example')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('This is a TextField. Click to edit it:'),
                TextField(controller: controller),
                const SizedBox(height: 20),
                FloatingActionButton(
                  onPressed: () => context.dispatch(ChangeTextAction()),
                  child: const Text("Change"),
                ),
                const SizedBox(height: 20),
                FloatingActionButton(
                  onPressed: () => context.dispatch(ClearTextAction()),
                  child: const Text("Clear"),
                ),
              ],
            ),
          ),
        ),
        if (waiting) ModalBarrier(color: Colors.red.withOpacity(0.4)),
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
      getEvent<AppState, R>(selector, debug: false);
}
