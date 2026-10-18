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
/// of the same class, in `context.isWaiting()`.
///
/// 10 buttons are shown. When a button is clicked it will be replaced by a downloaded
/// text description. Each button shows a progress indicator while its own description
/// is downloading. The screen title shows the text "Downloading..." if any of the
/// buttons is currently downloading.
///
/// The action that downloads a description has an `index`, and its `statusKey` is that
/// index. So, `context.isWaiting(GetDescriptionAction, statusKey: index)` is true only
/// while the description of that index is downloading, while
/// `context.isWaiting(GetDescriptionAction)` is true while any description is.
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
        home: MyHomePage(),
      ));
}

class GetDescriptionAction extends ReduxAction<AppState> {
  final int index;

  GetDescriptionAction(this.index);

  /// The status key is the index. It must come from the action's own fields, and never
  /// change. Then, `context.isWaiting(GetDescriptionAction, statusKey: index)` is true
  /// only while the action for this index is running.
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

class MyItem extends StatelessWidget {
  final int index;

  MyItem({
    required this.index,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use context.select to get the description for this specific index.
    var description =
        context.select((AppState state) => state.descriptions[index] ?? "");

    /// True only while the action for this index is running.
    var waiting = context.isWaiting(GetDescriptionAction, statusKey: index);

    Widget contents;

    if (waiting)
      contents = _progressIndicator();
    else if (description.isNotEmpty)
      contents = _indexDescription(description);
    else
      contents = _button(context);

    return Container(height: 70, child: Center(child: contents));
  }

  MaterialButton _button(BuildContext context) => MaterialButton(
        color: Colors.blue,
        child: Text("CLICK $index",
            style: const TextStyle(fontSize: 15), textAlign: TextAlign.center),
        onPressed: () => dispatch(GetDescriptionAction(index)),
      );

  Text _indexDescription(String description) => Text(description,
      style: const TextStyle(fontSize: 15), textAlign: TextAlign.center);

  CircularProgressIndicator _progressIndicator() =>
      const CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
      );
}

class MyHomePage extends StatelessWidget {
  MyHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    /// Without a statusKey, true while the action is running for ANY index.
    var waiting = context.isWaiting(GetDescriptionAction);

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
              title: Text(waiting
                  ? "Downloading..."
                  : "Advanced Is Waiting Example 1")),
          body: ListView.builder(
            itemCount: 10,
            itemBuilder: (context, index) => MyItem(index: index),
          ),
        ),
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
