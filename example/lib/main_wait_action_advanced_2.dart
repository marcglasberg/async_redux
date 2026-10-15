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

/// This example is similar to the one in `main_wait_action_advanced_1.dart`.
/// However, each row now has two buttons: one downloads the character's name, and the
/// other its height. Both use the same action, `GetFieldAction`, with an `index` and a
/// `field`. So the action's `statusKey` is a composite key, the record `(index, field)`:
///
/// ```
/// Object? get statusKey => (index, field);
/// ```
///
/// Records are compared by content, so `context.isWaiting(GetFieldAction,
/// statusKey: (index, 'name'))` is true only while the name of that index is downloading.
///
void main() {
  var state = AppState.initialState();
  store = Store<AppState>(initialState: state);
  runApp(MyApp());
}

@immutable
class AppState {
  /// The downloaded values, by `(index, field)`.
  final IMap<(int, String), String> values;

  AppState({required this.values});

  AppState copy({IMap<(int, String), String>? values}) =>
      AppState(values: values ?? this.values);

  static AppState initialState() => AppState(values: const IMapConst({}));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppState && runtimeType == other.runtimeType && values == other.values;

  @override
  int get hashCode => values.hashCode;
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => StoreProvider<AppState>(
      store: store,
      child: MaterialApp(
        home: MyHomePage(),
      ));
}

class GetFieldAction extends ReduxAction<AppState> {
  final int index;
  final String field;

  GetFieldAction(this.index, this.field);

  /// A composite status key: a record with the index and the field. Records are
  /// compared by content, so a new `(index, field)` created in the widget matches it.
  @override
  Object? get statusKey => (index, field);

  @override
  Future<AppState> reduce() async {
    // Then, we start and wait for some asynchronous process.
    Response response = await get(
      Uri.parse("https://swapi.dev/api/people/$index/"),
    );
    Map<String, dynamic> json = jsonDecode(response.body);
    String value = json[field]?.toString() ?? 'Unknown';

    await Future.delayed(const Duration(seconds: 2)); // Adds some more delay.

    return state.copy(values: state.values.add((index, field), value));
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
    return Container(
      height: 70,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          MyField(index: index, field: 'name'),
          MyField(index: index, field: 'height'),
        ],
      ),
    );
  }
}

class MyField extends StatelessWidget {
  final int index;
  final String field;

  MyField({required this.index, required this.field, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use context.select to get the value for this specific index and field.
    var value = context.select((AppState state) => state.values[(index, field)] ?? "");

    /// True only while the action for this index AND field is running.
    var waiting = context.isWaiting(GetFieldAction, statusKey: (index, field));

    if (waiting)
      return _progressIndicator();
    else if (value.isNotEmpty)
      return _value(value);
    else
      return _button(context);
  }

  MaterialButton _button(BuildContext context) => MaterialButton(
        color: Colors.blue,
        child: Text("${field.toUpperCase()} $index",
            style: const TextStyle(fontSize: 15), textAlign: TextAlign.center),
        onPressed: () => dispatch(GetFieldAction(index, field)),
      );

  Text _value(String value) =>
      Text(value, style: const TextStyle(fontSize: 15), textAlign: TextAlign.center);

  CircularProgressIndicator _progressIndicator() =>
      const CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
      );
}

class MyHomePage extends StatelessWidget {
  MyHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    /// Without a statusKey, true while the action is running for ANY index and field.
    var waiting = context.isWaiting(GetFieldAction);

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
              title: Text(waiting
                  ? "Downloading..."
                  : "Advanced Is Waiting Example 2")),
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
