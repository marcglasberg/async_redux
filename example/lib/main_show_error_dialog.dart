// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux
import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';

late Store<AppState> store;

/// This example lets you enter a name and click save.
/// If the name has less than 4 chars, an error dialog will be shown.
///
void main() {
  var state = AppState.initialState();
  store = Store<AppState>(initialState: state);
  runApp(MyApp());
}

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

class SaveUserAction extends ReduxAction<AppState> {
  final String name;

  SaveUserAction(this.name);

  @override
  AppState reduce() {
    print("Saving '$name'.");

    if (name.length < 4)
      throw const UserException("Name needs 4 letters or more.", errorText: 'At least 4 letters.');

    return state.copy(name: name);
  }

  @override
  Object wrapError(error, stackTrace) => //
      const UserException("Save failed")
          .addCause(error)
          .addCallbacks(onOk: () => print("Dialog was dismissed."));
// Note we could also have a CANCEL button here:
// .addCallbacks(onOk: ..., onCancel: () => print("CANCEL pressed, or dialog dismissed."));
}

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
class Factory extends VmFactory<AppState, MyHomePageConnector, ViewModel> {
  Factory(connector) : super(connector);

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
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Type a name and save:\n(See error if less than 4 chars)',
                      textAlign: TextAlign.center),
                  //
                  TextField(
                    controller: controller,
                    onChanged: (text) {
                      // This is optional, as the exception is already cleared when the
                      // action dispatches again. Comment it out to see the difference.
                      if (text.length >= 4) context.clearExceptionFor(SaveUserAction);
                    },
                    onSubmitted: widget.onSaveName,
                  ),
                  const SizedBox(height: 30),
                  //
                  // If the save failed, show the error message in red text.
                  if (context.isFailed(SaveUserAction))
                    Text(
                      context.exceptionFor(SaveUserAction)?.errorText ?? '',
                      style: const TextStyle(color: Colors.red),
                    ),
                  //
                  Text('Current Name: ${widget.name}'),
                ],
              ),
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
