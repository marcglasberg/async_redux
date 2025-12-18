import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';

/// This example shows how to show a spinner while any of two actions
/// ([IncrementAction] and [MultiplyAction]) is running.
///
/// Writing this:
///
/// ```dart
/// isWaiting([IncrementAction, MultiplyAction])
/// ```
///
/// Is the same as writing this:
///
/// ```dart
/// isWaiting(IncrementAction) || isWaiting(MultiplyAction)
/// ```
///
/// The `isCalculating` variable is defined in the `build` method
/// of widget [MyHomePage]:
///
/// ```dart
/// bool isCalculating = isWaiting([IncrementAction, MultiplyAction]);
/// ```
///
/// In more detail:
/// - There are two floating action buttons: one to increment the counter
///   and another to multiply it by 2.
/// - When any of the buttons is tapped, its respective action is dispatched.
/// - While any of the actions is running, both buttons show a spinner
///   and are disabled.
///
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    var store = Store<AppState>(initialState: AppState(counter: 0));
    store.onChange.listen(print);

    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: StoreProvider(
        store: store,
        child: const MyHomePage(),
      ),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    int counter = context.select((state) => state.counter);
    bool isCalculating = context.isWaiting([IncrementAction, MultiplyAction]);

    return MyHomePageContent(
      title: 'IsWaiting multiple actions',
      counter: counter,
      isCalculating: isCalculating,
      increment: () => dispatch(IncrementAction()),
      multiply: () => dispatch(MultiplyAction()),
    );
  }
}

class MyHomePageContent extends StatelessWidget {
  const MyHomePageContent({
    super.key,
    required this.title,
    required this.counter,
    required this.isCalculating,
    required this.increment,
    required this.multiply,
  });

  final String title;
  final int counter;
  final bool isCalculating;
  final VoidCallback increment, multiply;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Result:'),
            Text(
              '$counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            onPressed: isCalculating ? null : increment,
            elevation: isCalculating ? 0 : 6,
            backgroundColor: isCalculating ? Colors.grey[300] : Colors.blue,
            child: isCalculating
                ? const Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: const CircularProgressIndicator(),
                  )
                : const Icon(Icons.add),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: isCalculating ? null : multiply,
            elevation: isCalculating ? 0 : 6,
            backgroundColor: isCalculating ? Colors.grey[300] : Colors.blue,
            child: isCalculating
                ? const Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: const CircularProgressIndicator(),
                  )
                : const Icon(Icons.close),
          )
        ],
      ),
    );
  }
}

class AppState {
  final int counter;

  AppState({required this.counter});

  AppState copy({int? counter}) => AppState(counter: counter ?? this.counter);

  @override
  String toString() {
    return '.\n.\n.\nAppState{counter: $counter}\n.\n.\n';
  }
}

class IncrementAction extends ReduxAction<AppState> {
  @override
  Future<AppState?> reduce() async {
    await Future.delayed(const Duration(seconds: 1));
    return AppState(counter: state.counter + 1);
  }
}

class MultiplyAction extends ReduxAction<AppState> {
  @override
  Future<AppState?> reduce() async {
    await Future.delayed(const Duration(seconds: 1));
    return AppState(counter: state.counter * 2);
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
