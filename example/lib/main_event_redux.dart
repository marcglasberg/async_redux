import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';

// Developed by Marcelo Glasberg (Aug 2019).
// For more info, see: https://pub.dartlang.org/packages/async_redux

Store<AppState> store;

/// This example shows a text-field, and two buttons.
/// When the first button is tapped, an async process downloads some text from the internet
/// and puts it in the text-field.
/// When the second button is tapped, the text-field is cleared.
///
/// This is meant to demonstrate the use of "events" to change a controller state.
///
/// It also demonstrates the use of an abstract class [BarrierAction]
/// to override the action's before() and after() methods.
///
void main() {
  var state = AppState.initialState();
  store = Store<AppState>(initialState: state);
  runApp(MyApp());
}

///////////////////////////////////////////////////////////////////////////////

/// The app state, which in this case is a counter and two events.
class AppState {
  final int counter;
  final bool waiting;
  final Event clearTextEvt;
  final Event<String> changeTextEvt;

  AppState({this.counter, this.waiting, this.clearTextEvt, this.changeTextEvt});

  AppState copy({int counter, bool waiting, Event clearTextEvt, Event<String> changeTextEvt}) =>
      AppState(
        counter: counter ?? this.counter,
        waiting: waiting ?? this.waiting,
        clearTextEvt: clearTextEvt ?? this.clearTextEvt,
        changeTextEvt: changeTextEvt ?? this.changeTextEvt,
      );

  static AppState initialState() => AppState(
        counter: 0,
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

/// This action orders the text-controller to clear.
class ClearTextAction extends ReduxAction<AppState> {
  @override
  AppState reduce() => state.copy(clearTextEvt: Event());
}

///////////////////////////////////////////////////////////////////////////////

/// Actions that extend [BarrierAction] show a modal barrier while their async processes run.
abstract class BarrierAction extends ReduxAction<AppState> {
  void before() => dispatch(WaitAction(true));

  void after() => dispatch(WaitAction(false));
}

///////////////////////////////////////////////////////////////////////////////

class WaitAction extends ReduxAction<AppState> {
  final bool waiting;

  WaitAction(this.waiting);

  @override
  AppState reduce() => state.copy(waiting: waiting);
}

///////////////////////////////////////////////////////////////////////////////

/// This action downloads some new text, and then creates an event
/// that tells the text-controller to display that new text.
class ChangeTextAction extends BarrierAction {
  @override
  Future<AppState> reduce() async {
    String newText = await read("http://numbersapi.com/${state.counter}");
    return state.copy(
      counter: state.counter + 1,
      changeTextEvt: Event<String>(newText),
    );
  }
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
        waiting: vm.waiting,
        clearTextEvt: vm.clearTextEvt,
        changeTextEvt: vm.changeTextEvt,
        onClear: vm.onClear,
        onChange: vm.onChange,
      ),
    );
  }
}

/// Helper class to the connector widget. Holds the part of the State the widget needs,
/// and may perform conversions to the type of data the widget can conveniently work with.
class ViewModel extends BaseModel<AppState> {
  ViewModel();

  bool waiting;
  Event clearTextEvt;
  Event<String> changeTextEvt;
  VoidCallback onClear;
  VoidCallback onChange;

  ViewModel.build({
    @required this.waiting,
    @required this.clearTextEvt,
    @required this.changeTextEvt,
    @required this.onClear,
    @required this.onChange,
  }) : super(equals: [waiting, clearTextEvt, changeTextEvt]);

  @override
  ViewModel fromStore() => ViewModel.build(
        waiting: state.waiting,
        clearTextEvt: state.clearTextEvt,
        changeTextEvt: state.changeTextEvt,
        onClear: () => dispatch(ClearTextAction()),
        onChange: () => dispatch(ChangeTextAction()),
      );
}

///////////////////////////////////////////////////////////////////////////////

class MyHomePage extends StatefulWidget {
  final bool waiting;
  final Event clearTextEvt;
  final Event<String> changeTextEvt;
  final VoidCallback onClear;
  final VoidCallback onChange;

  MyHomePage({
    Key key,
    this.waiting,
    this.clearTextEvt,
    this.changeTextEvt,
    this.onClear,
    this.onChange,
  }) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
  }

  @override
  void didUpdateWidget(MyHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    consumeEvents();
  }

  void consumeEvents() {
    if (widget.clearTextEvt.consume())
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) controller.clear();
      });

    String newText = widget.changeTextEvt.consume();
    if (newText != null)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) controller.value = controller.value.copyWith(text: newText);
      });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: Text('Event Example')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('This is a TextField. Click to edit it:'),
                TextField(controller: controller),
                SizedBox(height: 20),
                FloatingActionButton(onPressed: widget.onChange, child: Text("Change")),
                SizedBox(height: 20),
                FloatingActionButton(onPressed: widget.onClear, child: Text("Clear")),
              ],
            ),
          ),
        ),
        if (widget.waiting) ModalBarrier(color: Colors.red.withOpacity(0.4)),
      ],
    );
  }
}
