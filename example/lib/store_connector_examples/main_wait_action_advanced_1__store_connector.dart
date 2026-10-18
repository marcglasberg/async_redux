// ignore_for_file: async_redux_lints/extend_base_action

import 'dart:async';
import 'dart:convert';

import 'package:async_redux/async_redux.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';

// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

late Store<AppState> store;

/// This example shows how to use the action's `statusKey` to tell apart the actions
/// of the same class, in `isWaiting()`, with `StoreConnector`s and view-models.
///
/// 10 buttons are shown. When a button is clicked it will be replaced by a downloaded
/// text description. Each button shows a progress indicator while its own description
/// is downloading. The screen title shows the text "Downloading..." if any of the
/// buttons is currently downloading.
///
/// The action that downloads a description has an `index`, and its `statusKey` is that
/// index. So, in the view-model factory, `isWaiting(GetDescriptionAction, statusKey: index)`
/// is true only while the description of that index is downloading, while
/// `isWaiting(GetDescriptionAction)` is true while any description is.
///
void main() {
  var state = AppState.initialState();
  store = Store<AppState>(initialState: state);
  runApp(MyApp());
}

@stateClass
class AppState {
  final IMap<int, String> descriptions;

  AppState({required this.descriptions});

  AppState copy({IMap<int, String>? descriptions}) =>
      AppState(descriptions: descriptions ?? this.descriptions);

  static AppState initialState() => AppState(descriptions: const IMapConst({}));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppState &&
          runtimeType == other.runtimeType &&
          descriptions == other.descriptions;

  @override
  int get hashCode => descriptions.hashCode;
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => StoreProvider<AppState>(
      store: store,
      child: MaterialApp(
        home: MyHomePageConnector(),
      ));
}

class GetDescriptionAction extends ReduxAction<AppState> {
  final int index;

  GetDescriptionAction(this.index);

  /// The status key is the index. It must come from the action's own fields, and never
  /// change. Then, `isWaiting(GetDescriptionAction, statusKey: index)` is true only while
  /// the action for this index is running.
  @override
  Object? get statusKey => index;

  @override
  Future<AppState> reduce() async {
    // Then, we start and wait for some asynchronous process.
    Response response = await get(
      Uri.parse("https://swapi.dev/api/people/$index/"),
    );
    Map<String, dynamic> json = jsonDecode(response.body);
    String description = json['name'] ?? 'Unknown character';

    await Future.delayed(const Duration(seconds: 2)); // Adds some more delay.

    return state.copy(descriptions: state.descriptions.add(index, description));
  }
}

/// This widget is a connector. It connects the store to "dumb-widget".
class MyHomePageConnector extends StatelessWidget {
  MyHomePageConnector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, PageViewModel>(
      vm: () => PageVmFactory(this),
      builder: (BuildContext context, PageViewModel vm) => MyHomePage(
        onGetDescription: vm.onGetDescription,
        waiting: vm.waiting,
      ),
    );
  }
}

/// Factory that creates a view-model for the StoreConnector.
class PageVmFactory extends VmFactory<AppState, MyHomePageConnector, PageViewModel> {
  PageVmFactory(connector) : super(connector);

  @override
  PageViewModel fromStore() => PageViewModel(
        /// Without a statusKey, true while the action is running for ANY index.
        waiting: isWaiting(GetDescriptionAction),

        onGetDescription: (int index) => dispatch(GetDescriptionAction(index)),
      );
}

class PageViewModel extends Vm {
  final bool waiting;
  final void Function(int) onGetDescription;

  PageViewModel({
    required this.waiting,
    required this.onGetDescription,
  }) : super(equals: [waiting]);
}

/// This widget is a connector. It connects the store to "dumb-widget".
class MyItemConnector extends StatelessWidget {
  final int index;
  final void Function(int) onGetDescription;

  MyItemConnector({
    required this.index,
    required this.onGetDescription,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, ItemViewModel>(
      vm: () => ItemVmFactory(this),
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
class ItemVmFactory extends VmFactory<AppState, MyItemConnector, ItemViewModel> {
  ItemVmFactory(connector) : super(connector);

  @override
  ItemViewModel fromStore() => ItemViewModel(
        description: state.descriptions[connector.index] ?? "",

        /// True only while the action for this index is running.
        waiting: isWaiting(GetDescriptionAction, statusKey: connector.index),
      );
}

class ItemViewModel extends Vm {
  final String description;
  final bool waiting;

  ItemViewModel({
    required this.description,
    required this.waiting,
  }) : super(equals: [description, waiting]);
}

class MyItem extends StatelessWidget {
  final String description;
  final bool waiting;
  final int index;
  final void Function(int) onGetDescription;

  MyItem({
    required this.description,
    required this.waiting,
    required this.index,
    required this.onGetDescription,
  });

  @override
  Widget build(BuildContext context) {
    Widget contents;

    if (waiting)
      contents = _progressIndicator();
    else if (description.isNotEmpty)
      contents = _indexDescription();
    else
      contents = _button();

    return Container(height: 70, child: Center(child: contents));
  }

  MaterialButton _button() => MaterialButton(
        color: Colors.blue,
        child:
            Text("CLICK $index", style: const TextStyle(fontSize: 15), textAlign: TextAlign.center),
        onPressed: () => onGetDescription(index),
      );

  Text _indexDescription() =>
      Text(description, style: const TextStyle(fontSize: 15), textAlign: TextAlign.center);

  CircularProgressIndicator _progressIndicator() => const CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
      );
}

class MyHomePage extends StatelessWidget {
  final bool waiting;
  final void Function(int) onGetDescription;

  MyHomePage({
    Key? key,
    required this.waiting,
    required this.onGetDescription,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
              title: Text(waiting ? "Downloading..." : "Advanced Is Waiting Example 1")),
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
