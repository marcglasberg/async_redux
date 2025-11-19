import 'dart:async';
import 'dart:convert';

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';

// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

late Store<AppState> store;

/// This example is the same as the one in `main_wait_action_advanced_1.dart`.
/// However, instead of only using flags in the [WaitAction], it uses both
/// flags and references.
///
void main() {
  var state = AppState.initialState();
  store = Store<AppState>(initialState: state);
  runApp(MyApp());
}

/// The app state contains a [wait] object of type [Wait].
@immutable
class AppState {
  final Map<int, String> descriptions;
  final Wait wait;

  AppState({
    required this.descriptions,
    required this.wait,
  });

  /// The copy method has a named [wait] parameter of type [Wait].
  AppState copy({int? counter, Map<int, String>? descriptions, Wait? wait}) =>
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

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => StoreProvider<AppState>(
      store: store,
      child: MaterialApp(
        home: MyHomePage(),
      ));
}

class GetDescriptionAction extends ReduxAction<AppState> {
  int index;

  GetDescriptionAction(this.index);

  @override
  Future<AppState> reduce() async {
    // Then, we start and wait for some asynchronous process.
    Response response = await get(
      Uri.parse("https://swapi.dev/api/people/$index/"),
    );
    Map<String, dynamic> json = jsonDecode(response.body);
    String description = json['name'] ?? 'Unknown character';

    await Future.delayed(const Duration(seconds: 2)); // Adds some more delay.

    Map<int, String> newDescriptions = Map.of(state.descriptions);
    newDescriptions[index] = description;

    return state.copy(descriptions: newDescriptions);
  }

  // The wait starts here. We use the index as a wait-flag reference.
  @override
  void before() => dispatch(WaitAction.add("button-download", ref: index));

  // The wait ends here. We remove the index from the wait-flag references.
  @override
  void after() => dispatch(WaitAction.remove("button-download", ref: index));
}

class MyItem extends StatelessWidget {
  final int index;

  MyItem({
    required this.index,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use context.select to get the description and waiting state for this specific index
    var description =
        context.select((AppState state) => state.descriptions[index] ?? "");

    /// If index is waiting, `state.wait.isWaiting("button-download", ref: index)` returns true.
    var waiting = context.select((AppState state) =>
        state.wait.isWaiting("button-download", ref: index));

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
        onPressed: () => context.dispatch(GetDescriptionAction(index)),
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
    /// If there is any waiting, `state.wait.isWaitingAny` will return true.
    var waiting = context.select((AppState state) => state.wait.isWaitingAny);

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
              title: Text(waiting
                  ? "Downloading..."
                  : "Advanced WaitAction Example 2")),
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
