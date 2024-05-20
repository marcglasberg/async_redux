// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// For more info, see: https://pub.dartlang.org/packages/async_redux
import 'dart:async';
import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';

late Store<AppState> store;

/// This example shows a counter and a button.
/// When the button is tapped, the counter will increment synchronously.
void main() {
  store = Store<AppState>(initialState: AppState(counter: 0, something: 0));
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => StoreProvider<AppState>(
        store: store,
        child: const MaterialApp(home: HomePage()),
      );
}

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spinner With StoreConnector')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('You have pushed the button this many times:'),
            CounterWidget(),
          ],
        ),
      ),
      // Here we disable the button while the `WaitAndIncrementAction` action is running.
      floatingActionButton: _PlusButtonConnector(),
    );
  }
}

class _PlusButtonConnector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, ViewModel>(
      vm: () => Factory(this),
      builder: (context, vm) {
        return vm.isWaiting
            ? const FloatingActionButton(
                disabledElevation: 0,
                onPressed: null,
                child: SizedBox(width: 25, height: 25, child: CircularProgressIndicator()))
            : FloatingActionButton(
                disabledElevation: 0,
                onPressed: () => context.dispatch(WaitAndIncrementAction()),
                child: const Icon(Icons.add),
              );
      },
    );
  }
}

class Factory extends VmFactory<AppState, _PlusButtonConnector, ViewModel> {
  Factory(connector) : super(connector);

  @override
  ViewModel fromStore() {
    return ViewModel(
      isWaiting: isWaiting(WaitAndIncrementAction),
    );
  }
}

class ViewModel extends Vm {
  final bool isWaiting;

  ViewModel({
    required this.isWaiting,
  }) : super(equals: [isWaiting]);
}

/// This action waits for 2 seconds, then increments the counter by [amount]].
class WaitAndIncrementAction extends ReduxAction<AppState> {
  @override
  Future<AppState?> reduce() async {
    await Future.delayed(const Duration(seconds: 2));
    return AppState(
      counter: state.counter + 1,
      something: state.something,
    );
  }
}

class CounterWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var isWaiting = context.isWaiting(WaitAndIncrementAction);

    return Text(
      '${context.state.counter}',
      style: TextStyle(fontSize: 40, color: isWaiting ? Colors.grey[350] : Colors.black),
    );
  }
}

extension _BuildContextExtension on BuildContext {
  AppState get state => getState<AppState>();
}

class AppState {
  int counter;
  int something;

  AppState({
    required this.counter,
    required this.something,
  });

  @override
  String toString() => 'AppState{counter: $counter}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppState && runtimeType == other.runtimeType && counter == other.counter;

  @override
  int get hashCode => counter.hashCode;
}
