import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';

// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

/// This example demonstrates that `isWaiting` works even for actions that
/// return `null` (i.e., actions that don't change the state).
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
    return StoreConnector<AppState, CounterVm>(
      vm: () => CounterVmFactory(),
      shouldUpdateModel: (s) => s.counter >= 0,
      builder: (context, vm) {
        return MyHomePageContent(
          title: 'IsWaiting works when state unchanged',
          counter: vm.counter,
          isIncrementing: vm.isIncrementing,
          increment: vm.increment,
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
    required this.isIncrementing,
    required this.increment,
  });

  final String title;
  final int counter;
  final bool isIncrementing;
  final VoidCallback increment;

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
            const Text('You pushed the button:'),
            Text(
              '$counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isIncrementing ? null : increment,
        elevation: isIncrementing ? 0 : 6,
        backgroundColor: isIncrementing ? Colors.grey[300] : Colors.blue,
        child: isIncrementing ? const Padding(
          padding: const EdgeInsets.all(16.0),
          child: const CircularProgressIndicator(),
        ) : const Icon(Icons.add),
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
  final bool isIncrementing;
  final VoidCallback increment;

  CounterVm({
    required this.counter,
    required this.isIncrementing,
    required this.increment,
  }) : super(equals: [
          counter,
          isIncrementing,
        ]);
}

class CounterVmFactory extends VmFactory<AppState, MyHomePage, CounterVm> {
  @override
  CounterVm fromStore() => CounterVm(
        counter: state.counter,
        isIncrementing: isWaiting(IncrementAction),
        increment: () => dispatch(IncrementAction()),
      );
}

class IncrementAction extends ReduxAction<AppState> {
  @override
  Future<AppState?> reduce() async {
    dispatch(DoIncrementAction());
    await Future.delayed(const Duration(milliseconds: 1250));
    return null;
  }
}

class DoIncrementAction extends ReduxAction<AppState> {
  @override
  AppState? reduce() {
    return AppState(counter: state.counter + 1);
  }
}
