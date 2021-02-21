import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';

// Developed by Marcelo Glasberg (Aug 2019).
// For more info, see: https://pub.dartlang.org/packages/async_redux

Store<AppState> store;

/// This example shows how to use [WaitAction] in advanced ways.
/// For this to work, the [AppState] must have a [wait] field of type [Wait],
/// and this field must be in the [AppState.copy] method as a named parameter.
///
/// 10 buttons are shown. When a button is clicked it will be
/// replaced by a downloaded text description. Each button shows a progress
/// indicator while its description is downloading. The screen title shows
/// the text "Downloading..." if any of the buttons is currently downloading.
///
/// Note: This example uses http. It works in Android, debug mode. If you use iOS, please see:
/// https://flutter.dev/docs/release/breaking-changes/network-policy-ios-android
///
void main() {
  var state = AppState.initialState();
  store = Store<AppState>(initialState: state);
  runApp(MyApp());
}

///////////////////////////////////////////////////////////////////////////////

/// The app state contains a [wait] object of type [Wait].
class AppState {
  final Map<int, String> descriptions;
  final Wait wait;

  AppState({this.descriptions, this.wait});

  /// The copy method has a named [wait] parameter of type [Wait].
  AppState copy({int counter, Map<int, String> descriptions, Wait wait}) =>
      AppState(
        descriptions: descriptions ?? this.descriptions,
        wait: wait ?? this.wait,
      );

  /// The [wait] parameter is instantiated to `Wait()`.
  static AppState initialState() => AppState(
        descriptions: {},
        wait: Wait(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppState &&
          runtimeType == other.runtimeType &&
          descriptions == other.descriptions &&
          wait == other.wait;

  @override
  int get hashCode => descriptions.hashCode ^ wait.hashCode;
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

class GetDescriptionAction extends ReduxAction<AppState> {
  int index;

  GetDescriptionAction(this.index);

  @override
  Future<AppState> reduce() async {
    String description = await read("http://numbersapi.com/$index");
    await Future.delayed(const Duration(seconds: 2)); // Adds some more delay.

    Map<int, String> newDescriptions = Map.of(state.descriptions);
    newDescriptions[index] = description;

    return state.copy(descriptions: newDescriptions);
  }

  // The wait starts here. We use the index as a wait-flag reference.
  @override
  void before() => dispatch(WaitAction.add(index));

  // The wait ends here. We remove the index from the wait-flag references.
  @override
  void after() => dispatch(WaitAction.remove(index));
}

///////////////////////////////////////////////////////////////////////////////

/// This widget is a connector. It connects the store to "dumb-widget".
class MyHomePageConnector extends StatelessWidget {
  MyHomePageConnector({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, PageViewModel>(
      vm: () => PageViewModelFactory(this),
      builder: (BuildContext context, PageViewModel vm) => MyHomePage(
        onGetDescription: vm.onGetDescription,
        waiting: vm.waiting,
      ),
    );
  }
}

/// Factory that creates a view-model for the StoreConnector.
class PageViewModelFactory extends VmFactory<AppState, MyHomePageConnector> {
  PageViewModelFactory(widget) : super(widget);

  @override
  PageViewModel fromStore() => PageViewModel(
        /// If there is any waiting, `state.wait.isWaiting` will return true.
        waiting: state.wait.isWaiting,

        onGetDescription: (int index) => dispatch(GetDescriptionAction(index)),
      );
}

class PageViewModel extends Vm {
  final bool waiting;
  final void Function(int) onGetDescription;

  PageViewModel({
    @required this.waiting,
    @required this.onGetDescription,
  }) : super(equals: [waiting]);
}

///////////////////////////////////////////////////////////////////////////////

/// This widget is a connector. It connects the store to "dumb-widget".
class MyItemConnector extends StatelessWidget {
  final int index;
  final void Function(int) onGetDescription;

  MyItemConnector({
    @required this.index,
    @required this.onGetDescription,
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, ItemViewModel>(
      vm: () => ItemViewModelFactory(this),
      builder: (BuildContext context, ItemViewModel vm) => MyItem(
        description: vm.description,
        waiting: vm.waiting,
        index: index,
        onGetDescription: onGetDescription,
      ),
    );
  }
}

/// Factory that creates a view-model for the StoreConnector.
class ItemViewModelFactory extends VmFactory<AppState, MyItemConnector> {
  ItemViewModelFactory(widget) : super(widget);

  @override
  ItemViewModel fromStore() => ItemViewModel(
        description: state.descriptions[widget.index],

        /// If index is waiting, `state.wait.isWaitingFor(index)` returns true.
        waiting: state.wait.isWaitingFor(widget.index),
      );
}

class ItemViewModel extends Vm {
  final String description;
  final bool waiting;

  ItemViewModel({
    @required this.description,
    @required this.waiting,
  }) : super(equals: [description, waiting]);
}

///////////////////////////////////////////////////////////////////////////////

class MyItem extends StatelessWidget {
  final String description;
  final bool waiting;
  final int index;
  final void Function(int) onGetDescription;

  MyItem({
    this.description,
    this.waiting,
    this.index,
    this.onGetDescription,
  });

  @override
  Widget build(BuildContext context) {
    Widget contents;

    if (waiting)
      contents = _progressIndicator();
    else if (description != null)
      contents = _indexDescription();
    else
      contents = _button();

    return Container(height: 70, child: Center(child: contents));
  }

  MaterialButton _button() => MaterialButton(
        color: Colors.blue,
        child: Text("CLICK $index",
            style: const TextStyle(fontSize: 15), textAlign: TextAlign.center),
        onPressed: () => onGetDescription(index),
      );

  Text _indexDescription() => Text(description,
      style: const TextStyle(fontSize: 15), textAlign: TextAlign.center);

  CircularProgressIndicator _progressIndicator() =>
      const CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
      );
}

///////////////////////////////////////////////////////////////////////////////

class MyHomePage extends StatelessWidget {
  final bool waiting;
  final void Function(int) onGetDescription;

  MyHomePage({
    Key key,
    this.waiting,
    this.onGetDescription,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
              title: Text(waiting
                  ? "Downloading..."
                  : "Advanced WaitAction Example 1")),
          body: ListView.builder(
            itemCount: 10,
            itemBuilder: (context, index) => MyItemConnector(
              index: index,
              onGetDescription: onGetDescription,
            ),
          ),
        ),
      ],
    );
  }
}
