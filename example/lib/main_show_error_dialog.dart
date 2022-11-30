import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';

// Developed by Marcelo Glasberg (Aug 2019).
// For more info, see: https://pub.dartlang.org/packages/async_redux

late Store<AppState> store;

/// This example lets you enter a name and click save.
/// If the name has less than 4 chars, an error dialog will be shown.
///
void main() {
  var state = AppState.initialState();
  store = Store<AppState>(initialState: state);
  runApp(MyApp());
}

///////////////////////////////////////////////////////////////////////////////

/// The app state, which in this case is the user name.
@immutable
class AppState {
  final String? name;

  AppState({this.name});

  AppState copy({String? name}) => AppState(name: name ?? this.name);

  static AppState initialState() => AppState(name: "");

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppState && runtimeType == other.runtimeType && name == other.name;

  @override
  int get hashCode => name.hashCode;
}

///////////////////////////////////////////////////////////////////////////////

/// To display errors, put the [UserExceptionDialog] below [StoreProvider] and [MaterialApp].
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => StoreProvider<AppState>(
        store: store,
        child: MaterialApp(
          home: UserExceptionDialog<AppState>(
            child: MyHomePageConnector(),
          ),
        ),
      );
}

///////////////////////////////////////////////////////////////////////////////

class SaveUserAction extends ReduxAction<AppState> {
  final String name;

  SaveUserAction(this.name);

  @override
  AppState reduce() {
    print("Saving '$name'.");
    if (name.length < 4) throw const UserException("Name must have at least 4 letters.");
    return state.copy(name: name);
  }

  @override
  Object wrapError(error, stackTrace) => UserException(
        "Save failed",
        cause: error,
        onOk: () {
          print("Dialog was dismissed.");
        },
        //
        // Note we could also have a CANCEL button:
        // onOk: () { print("OK was pressed."); },
        // onCancel: () { print("CANCEL was pressed, or dialog dismissed."); },
      );
}

///////////////////////////////////////////////////////////////////////////////

/// This widget is a connector. It connects the store to "dumb-widget".
class MyHomePageConnector extends StatelessWidget {
  MyHomePageConnector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, ViewModel>(
      vm: () => Factory(this),
      builder: (BuildContext context, ViewModel vm) => MyHomePage(
        name: vm.name,
        onSaveName: vm.onSaveName,
      ),
    );
  }
}

/// Factory that creates a view-model for the StoreConnector.
class Factory extends VmFactory<AppState, MyHomePageConnector> {
  Factory(widget) : super(widget);

  @override
  ViewModel fromStore() => ViewModel(
        name: state.name,
        onSaveName: (String name) => dispatch(SaveUserAction(name)),
      );
}

/// The view-model holds the part of the Store state the dumb-widget needs.
class ViewModel extends Vm {
  final String? name;
  final ValueChanged<String> onSaveName;

  ViewModel({
    required this.name,
    required this.onSaveName,
  }) : super(equals: [name!]);
}

///////////////////////////////////////////////////////////////////////////////

class MyHomePage extends StatefulWidget {
  final String? name;
  final ValueChanged<String>? onSaveName;

  MyHomePage({
    Key? key,
    this.name,
    this.onSaveName,
  }) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  TextEditingController? controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: const Text('Show Error Dialog Example')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Type a name and save:\n(See error if less than 4 chars)',
                    textAlign: TextAlign.center),
                TextField(controller: controller, onSubmitted: widget.onSaveName),
                const SizedBox(height: 30),
                Text('Current Name: ${widget.name}'),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => widget.onSaveName!(controller!.text),
            child: const Text("Save"),
          ),
        ),
      ],
    );
  }
}
