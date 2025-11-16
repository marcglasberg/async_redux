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
/// isWaiting(IncrementAction) || context.isWaiting(MultiplyAction)
/// ```
///
/// See how the `isCalculating` variable is defined in the [CounterVmFactory].
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

  /// The code below, which uses a [StoreConnector], [CounterVmFactory],
  /// and [CounterVm], is equivalent to:
  ///
  /// ```dart
  /// return MyHomePageContent(
  ///   title: 'IsWaiting multiple actions',
  ///   counter: context.select((state) => state.counter),
  ///   isCalculating: context.isWaiting([IncrementAction, MultiplyAction]),
  ///   increment: () => context.dispatch(IncrementAction()),
  ///   multiply: () => context.dispatch(MultiplyAction()),
  /// );
  /// ```
  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, CounterVm>(
      vm: () => CounterVmFactory(),
      shouldUpdateModel: (s) => s.counter >= 0,
      builder: (context, vm) {
        return MyHomePageContent(
          title: 'IsWaiting multiple actions (Store Connector)',
          counter: vm.counter,
          isCalculating: vm.isCalculating,
          increment: vm.increment,
          multiply: vm.multiply,
        );
      },
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

class CounterVm extends Vm {
  final int counter;
  final bool isCalculating;
  final VoidCallback increment, multiply;

  CounterVm({
    required this.counter,
    required this.isCalculating,
    required this.increment,
    required this.multiply,
  }) : super(equals: [counter, isCalculating]);
}

class CounterVmFactory extends VmFactory<AppState, MyHomePage, CounterVm> {
  @override
  CounterVm fromStore() => CounterVm(
        counter: state.counter,
        isCalculating: isWaiting([IncrementAction, MultiplyAction]),
        increment: () => dispatch(IncrementAction()),
        multiply: () => dispatch(MultiplyAction()),
      );
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
