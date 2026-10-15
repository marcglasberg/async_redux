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

/// This example is similar to the one in `main_wait_action_advanced_1__store_connector.dart`.
/// However, each row now has two buttons: one downloads the character's name, and the
/// other its height. Both use the same action, `GetFieldAction`, with an `index` and a
/// `field`. So the action's `statusKey` is a composite key, the record `(index, field)`:
///
/// ```
/// Object? get statusKey => (index, field);
/// ```
///
/// Records are compared by content, so `isWaiting(GetFieldAction, statusKey: (index, 'name'))`
/// in the view-model factory is true only while the name of that index is downloading.
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
        home: MyHomePageConnector(),
      ));
}

class GetFieldAction extends ReduxAction<AppState> {
  final int index;
  final String field;

  GetFieldAction(this.index, this.field);

  /// A composite status key: a record with the index and the field. Records are
  /// compared by content, so a new `(index, field)` created in the factory matches it.
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

/// This widget is a connector. It connects the store to "dumb-widget".
class MyHomePageConnector extends StatelessWidget {
  MyHomePageConnector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, PageViewModel>(
      vm: () => PageVmFactory(this),
      builder: (BuildContext context, PageViewModel vm) => MyHomePage(
        onGetField: vm.onGetField,
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
        /// Without a statusKey, true while the action is running for ANY index and field.
        waiting: isWaiting(GetFieldAction),

        onGetField: (int index, String field) => dispatch(GetFieldAction(index, field)),
      );
}

class PageViewModel extends Vm {
  final bool waiting;
  final void Function(int, String) onGetField;

  PageViewModel({
    required this.waiting,
    required this.onGetField,
  }) : super(equals: [waiting]);
}

/// This widget is a connector. It connects the store to "dumb-widget".
class MyFieldConnector extends StatelessWidget {
  final int index;
  final String field;
  final void Function(int, String) onGetField;

  MyFieldConnector({
    required this.index,
    required this.field,
    required this.onGetField,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, FieldViewModel>(
      vm: () => FieldVmFactory(this),
      builder: (BuildContext context, FieldViewModel vm) => MyField(
        value: vm.value,
        waiting: vm.waiting,
        index: index,
        field: field,
        onGetField: onGetField,
      ),
    );
  }
}

/// Factory that creates a view-model for the StoreConnector.
class FieldVmFactory extends VmFactory<AppState, MyFieldConnector, FieldViewModel> {
  FieldVmFactory(connector) : super(connector);

  @override
  FieldViewModel fromStore() => FieldViewModel(
        value: state.values[(connector.index, connector.field)] ?? "",

        /// True only while the action for this index AND field is running.
        waiting: isWaiting(GetFieldAction, statusKey: (connector.index, connector.field)),
      );
}

/// The view-model holds the part of the Store state the dumb-widget needs.
class FieldViewModel extends Vm {
  final String value;
  final bool waiting;

  FieldViewModel({
    required this.value,
    required this.waiting,
  }) : super(equals: [value, waiting]);
}

class MyField extends StatelessWidget {
  final String value;
  final bool waiting;
  final int index;
  final String field;
  final void Function(int, String) onGetField;

  MyField({
    required this.value,
    required this.waiting,
    required this.index,
    required this.field,
    required this.onGetField,
  });

  @override
  Widget build(BuildContext context) {
    if (waiting)
      return _progressIndicator();
    else if (value.isNotEmpty)
      return _value();
    else
      return _button();
  }

  MaterialButton _button() => MaterialButton(
        color: Colors.blue,
        child: Text("${field.toUpperCase()} $index",
            style: const TextStyle(fontSize: 15), textAlign: TextAlign.center),
        onPressed: () => onGetField(index, field),
      );

  Text _value() =>
      Text(value, style: const TextStyle(fontSize: 15), textAlign: TextAlign.center);

  CircularProgressIndicator _progressIndicator() => const CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
      );
}

class MyHomePage extends StatelessWidget {
  final bool waiting;
  final void Function(int, String) onGetField;

  MyHomePage({
    Key? key,
    required this.waiting,
    required this.onGetField,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
              title: Text(waiting ? "Downloading..." : "Advanced Is Waiting Example 2")),
          body: ListView.builder(
            itemCount: 10,
            itemBuilder: (context, index) => Container(
              height: 70,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  MyFieldConnector(index: index, field: 'name', onGetField: onGetField),
                  MyFieldConnector(index: index, field: 'height', onGetField: onGetField),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
