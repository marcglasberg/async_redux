// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';

// Recommended to create this extension.
extension BuildContextExtension on BuildContext {
  AppState get state => getState<AppState>();
  AppState read() => getRead<AppState>();
  R select<R>(R Function(AppState state) selector) => getSelect<AppState, R>(selector);
}

void main() {
  final store = Store<AppState>(initialState: AppState.initialState());
  runApp(MyApp(store: store));
}

class MyApp extends StatelessWidget {
  final Store<AppState> store;

  const MyApp({Key? key, required this.store}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StoreProvider<AppState>(
      store: store,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Select Demo',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const MainScreen(),
      ),
    );
  }
}

class MainScreen extends StatelessWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AsyncRedux Select Demo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Display widgets
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Widget States:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    ContextStateWidget(),
                    SizedBox(height: 8),
                    ContextReadWidget(),
                    SizedBox(height: 8),
                    SelectDateWidget(),
                    SizedBox(height: 8),
                    SelectFlagWidget(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Control buttons
            const Text(
              'Actions:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: () => context.dispatch(IncrementNumberAction()),
              icon: const Icon(Icons.add),
              label: const Text('Increment Number'),
            ),
            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: () => context.dispatch(AddXToTextAction()),
              icon: const Icon(Icons.text_fields),
              label: const Text('Add X to Text'),
            ),
            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: () => context.dispatch(AddDayToDateAction()),
              icon: const Icon(Icons.calendar_today),
              label: const Text('Add Day to Date'),
            ),
            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: () => context.dispatch(ToggleFlagAction()),
              icon: const Icon(Icons.flag),
              label: const Text('Toggle Flag'),
            ),
          ],
        ),
      ),
    );
  }
}

/// WIDGET 1: Uses `context.state` which uses `getState<AppState>()`.
/// This widget rebuilds on ANY state change.
///
class ContextStateWidget extends StatelessWidget {
  const ContextStateWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('🔴 ContextStateWidget rebuilt');

    // Will rebuild automatically on ANY state changes.
    var state = context.state;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '1. getState (notify: true)',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
          ),
          Text('Number: ${state.number}'),
          Text('Text: ${state.text}'),
          Text('Date: ${state.date.toString().split(' ')[0]}'),
          Text('Flag: ${state.flag}'),
          const Text(
            'Rebuilds on ANY change',
            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

/// WIDGET 2: Uses `context.read()` which uses `getRead<AppState>()`.
/// This widget does NOT rebuild on ANY state change.
///
class ContextReadWidget extends StatelessWidget {
  const ContextReadWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('🟡 ContextReadWidget rebuilt');

    // It will NEVER rebuild automatically on state changes.
    final state = context.read();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.yellow.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.yellow.shade700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '2. getState (notify: false)',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
          ),
          Text('Number: ${state.number}'),
          Text('Text: ${state.text}'),
          Text('Date: ${state.date.toString().split(' ')[0]}'),
          Text('Flag: ${state.flag}'),
          const Text(
            'Never rebuilds (shows initial state)',
            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

/// WIDGET 3: Uses `context.select()` which uses `getSelect<AppState, R>()`.
/// This widget rebuilds ONLY when the selected part of the state changes.
///
class SelectDateWidget extends StatelessWidget {
  const SelectDateWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('🟢 SelectDateWidget rebuilt');

    // Will rebuild automatically ONLY when `state.date` changes.
    // The return type (DateTime) is automatically inferred!
    final date = context.select((st) => st.date);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade400),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '3. select (date only)',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
          ),
          Text('Date: ${date.toString().split(' ')[0]}'),
          const Text(
            'Only rebuilds when date changes',
            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

/// WIDGET 3: Uses `context.select()` which uses `getSelect<AppState, R>()`.
/// This widget rebuilds ONLY when the selected part of the state changes.
///
class SelectFlagWidget extends StatelessWidget {
  const SelectFlagWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('🔵 SelectFlagWidget rebuilt');

    // Will rebuild automatically ONLY when `state.flag` changes.
    // The return type (bool) is automatically inferred!
    final flag = context.select((st) => st.flag);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade400),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '4. select (flag only)',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
          ),
          Text('Flag: $flag'),
          const Text(
            'Only rebuilds when flag changes',
            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

class AppState {
  final int number;
  final String text;
  final DateTime date;
  final bool flag;

  AppState({
    required this.number,
    required this.text,
    required this.date,
    required this.flag,
  });

  static AppState initialState() => AppState(
    number: 0,
    text: 'Hello',
    date: DateTime(2024, 1, 1),
    flag: false,
  );

  AppState copyWith({
    int? number,
    String? text,
    DateTime? date,
    bool? flag,
  }) {
    return AppState(
      number: number ?? this.number,
      text: text ?? this.text,
      date: date ?? this.date,
      flag: flag ?? this.flag,
    );
  }

  @override
  String toString() => 'AppState(number: $number, text: $text, date: $date, flag: $flag)';
}

class IncrementNumberAction extends ReduxAction<AppState> {
  @override
  AppState reduce() {
    return state.copyWith(number: state.number + 1);
  }
}

class AddXToTextAction extends ReduxAction<AppState> {
  @override
  AppState reduce() {
    return state.copyWith(text: state.text + 'X');
  }
}

class AddDayToDateAction extends ReduxAction<AppState> {
  @override
  AppState reduce() {
    return state.copyWith(date: state.date.add(const Duration(days: 1)));
  }
}

class ToggleFlagAction extends ReduxAction<AppState> {
  @override
  AppState reduce() {
    return state.copyWith(flag: !state.flag);
  }
}

////////////////////////////////////////////////////////////////////////////////

// USAGE NOTES

/*
This example shows the difference between various state access methods:

1. **ContextStateWidget** (Red):
   - Uses: `context.state` (via extension)
   - Rebuilds on ANY state change
   - Shows all state values
   - Watch the console: prints on every action

2. **ContextReadWidget** (Yellow):
   - Uses: `context.read()` (via extension)
   - NEVER rebuilds automatically
   - Always shows initial state values
   - Only prints once during initial build

3. **SelectDateWidget** (Green):
   - Uses: `context.select((state) => state.date)` (via extension, type inferred)
   - Only rebuilds when date changes
   - Only shows date value
   - Watch the console: only prints when "Add Day" is pressed

4. **SelectFlagWidget** (Blue):
   - Uses: `context.select((state) => state.flag)` (via extension, type inferred)
   - Only rebuilds when flag changes
   - Only shows flag value
   - Watch the console: only prints when "Toggle Flag" is pressed

Run the app and watch the console output to see which widgets rebuild!

Expected behavior:
- Press "Increment Number": Only red widget rebuilds
- Press "Add X to Text": Only red widget rebuilds
- Press "Add Day to Date": Red and green widgets rebuild
- Press "Toggle Flag": Red and blue widgets rebuild
*/
