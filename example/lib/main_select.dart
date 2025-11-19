import 'dart:async';
import 'dart:convert';

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';

// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

late Store<AppState> store;

/// This example shows a counter, a text character, and a button.
/// When the button is tapped, the counter will increment synchronously,
/// while an async process downloads some text character that relates
/// to the counter number (using the Star Wars API: https://swapi.dev).
///
/// Open the console to see when each widget rebuilds. Here are the 4 widgets:
///
/// 1. MyHomePage (red): rebuilds only during the initial build.
///
/// 2. CounterWidget (blue): rebuilds when you press the `+` button.
///
/// 3. DescriptionWidget (yellow): rebuilds only when the character loads.
///
/// 4. LoadingStatusWidget (grey): rebuilds when [IncrementAndGetDescriptionAction]
///    is dispatched, and when it finishes (either successfully or with error).
///
/// It should start like this:
///
/// ```
/// Restarted application in 271ms.
/// 🔴 MyHomePage rebuilt
/// 🔵 CounterWidget rebuilt
/// 💛 DescriptionWidget rebuilt
/// 🍏 LoadingStatusWidget rebuilt
/// 🔴 MyHomePage rebuilt
/// 🔵 CounterWidget rebuilt
/// 💛 DescriptionWidget rebuilt
/// 🍏 LoadingStatusWidget rebuilt
/// ```
///
/// When you press the `+` button, you should immediately see these extra lines:
/// ```
/// 🍏 LoadingStatusWidget rebuilt
/// 🔵 CounterWidget rebuilt
/// ```
///
/// And then, a moment later, when the character loads:
///
/// ```
/// 🍏 LoadingStatusWidget rebuilt
/// 💛 DescriptionWidget rebuilt
/// ```
///
void main() {
  var state = AppState.initialState();
  store = Store<AppState>(initialState: state);
  runApp(MyApp());
}

/// The app state, which in this case is a counter and a character.
@immutable
class AppState {
  final int counter;
  final String character;

  AppState({
    required this.counter,
    required this.character,
  });

  AppState copy({int? counter, String? character}) => AppState(
        counter: counter ?? this.counter,
        character: character ?? this.character,
      );

  static AppState initialState() => AppState(counter: 0, character: "");

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppState &&
          runtimeType == other.runtimeType &&
          counter == other.counter &&
          character == other.character;

  @override
  int get hashCode => counter.hashCode ^ character.hashCode;
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => StoreProvider<AppState>(
      store: store,
      child: MaterialApp(
        home: MyHomePage(),
      ));
}

/// This action increments the counter by 1,
/// and then gets some character text relating to the new counter number.
class IncrementAndGetDescriptionAction extends ReduxAction<AppState> {
  //
  // Async reducer.
  // To make it async we simply return Future<AppState> instead of AppState.
  @override
  Future<AppState> reduce() async {
    // First, we increment the counter, synchronously.
    dispatch(IncrementAction(amount: 1));

    // Then, we start and wait for some asynchronous process.
    Response response = await get(
      Uri.parse("https://swapi.dev/api/people/${state.counter}/"),
    );
    Map<String, dynamic> json = jsonDecode(response.body);
    String character = json['name'] ?? 'Unknown character';

    // After we get the response, we can modify the state with it,
    // without having to dispatch another action.
    return state.copy(character: character);
  }

  @override
  Object? wrapError(error, StackTrace stackTrace) {
    print('Error in IncrementAndGetDescriptionAction: $error');
    return const UserException('Failed to load.');
  }
}

/// This action increments the counter by [amount]].
class IncrementAction extends ReduxAction<AppState> {
  final int amount;

  IncrementAction({required this.amount});

  // Synchronous reducer.
  @override
  AppState reduce() => state.copy(counter: state.counter + amount);
}

/// This is a "smart-widget" that directly accesses the store to dispatch actions.
/// It uses extracted widgets (CounterWidget and DescriptionWidget) that each
/// independently select their own state and rebuild only when needed.
class MyHomePage extends StatelessWidget {
  MyHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('🔴 MyHomePage rebuilt');

    return Scaffold(
      appBar: AppBar(title: const Text('Star Wars Character Example')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CounterWidget(),
            DescriptionWidget(),
            LoadingStatusWidget(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        // Dispatch action directly from widget
        onPressed: () => context.dispatch(IncrementAndGetDescriptionAction()),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Widget that selects and displays ONLY the counter.
/// Rebuilds ONLY when the counter changes, not when character changes.
class CounterWidget extends StatelessWidget {
  const CounterWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('🔵 CounterWidget rebuilt');

    // Select only counter. Rebuilds only when counter changes.
    final counter = context.select((st) => st.counter);

    return Column(
      children: [
        const Text('Star Wars character for counter:'),
        Text('$counter', style: const TextStyle(fontSize: 30)),
      ],
    );
  }
}

/// Widget that selects and displays ONLY the character.
/// Rebuilds ONLY when the character changes, not when counter changes.
class DescriptionWidget extends StatelessWidget {
  const DescriptionWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('💛 DescriptionWidget rebuilt');

    return Text(
      context.select((st) => st.character),
      style: const TextStyle(fontSize: 15, color: Colors.black),
      textAlign: TextAlign.center,
    );
  }
}

/// Widget that selects and displays ONLY the character.
/// Rebuilds ONLY when the character changes, not when counter changes.
class LoadingStatusWidget extends StatelessWidget {
  const LoadingStatusWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('🍏 LoadingStatusWidget rebuilt');

    bool isWaiting = context.isWaiting(IncrementAndGetDescriptionAction);
    bool isFailed = context.isFailed(IncrementAndGetDescriptionAction);

    return Text(
      isFailed
          ? 'Error loading character!'
          : isWaiting
              ? 'Loading character...'
              : '',
      style: const TextStyle(fontSize: 15, color: Colors.grey),
      textAlign: TextAlign.center,
    );
  }
}

/// Recommended to create this extension.
extension BuildContextExtension on BuildContext {
  AppState get state => getState<AppState>();

  AppState read() => getRead<AppState>();

  R select<R>(R Function(AppState state) selector) =>
      getSelect<AppState, R>(selector);

  R? event<R>(Evt<R> Function(AppState state) selector) =>
      getEvent<AppState, R>(selector);
}
