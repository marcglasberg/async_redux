import "package:async_redux/async_redux.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group('MockBuildContext', () {
    test('allows testing widgets with context.state extension', () {
      var store =
          Store<AppState>(initialState: AppState(name: 'Mark', age: 30));
      var context = MockBuildContext(store);
      var widget = MyConnector().build(context) as MyWidget;
      expect(widget.name, 'Mark');
    });

    test('onChange callback dispatches ChangeName action', () async {
      var store =
          Store<AppState>(initialState: AppState(name: 'Initial', age: 25));
      var context = MockBuildContext(store);
      var widget = MyConnector().build(context) as MyWidget;
      expect(store.state.name, 'Initial');

      // Trigger action `ChangeName('John')` via onChange callback.
      widget.onChange();

      // State should be updated (synchronous action completes immediately).
      expect(store.state.name, 'John');
    });

    test('rebuilding widget after state change shows new name', () async {
      var store =
          Store<AppState>(initialState: AppState(name: 'Original', age: 20));
      var context = MockBuildContext(store);

      // Build widget with original state.
      var widget1 = MyConnector().build(context) as MyWidget;
      expect(widget1.name, 'Original');

      // Dispatch action to change name (synchronous action completes immediately).
      await store.dispatchAndWait(ChangeName('Updated'));

      // Rebuild widget - should reflect new state.
      var widget2 = MyConnector().build(context) as MyWidget;
      expect(widget2.name, 'Updated');
    });

    test('context.read() returns state without rebuilding', () {
      var store =
          Store<AppState>(initialState: AppState(name: 'ReadTest', age: 35));
      var context = MockBuildContext(store);
      var widget = MyConnector().build(context) as MyWidget;

      // In MockBuildContext, read() should work the same as state.
      expect(widget.nameFromRead, 'ReadTest');
      expect(widget.nameFromRead, widget.name);
    });

    test('context.select() selects specific part of state', () {
      var store =
          Store<AppState>(initialState: AppState(name: 'SelectTest', age: 40));
      var context = MockBuildContext(store);
      var widget = MyConnector().build(context) as MyWidget;

      // select should return the selected part of the state
      expect(widget.nameFromSelect, 'SelectTest');
      expect(widget.nameFromSelect, widget.name);
    });

    test('context.event() returns null when event is spent', () {
      var store =
          Store<AppState>(initialState: AppState(name: 'EventTest', age: 50));
      var context = MockBuildContext(store);
      var widget = MyConnector().build(context) as MyWidget;

      // Initial event is spent, should return null
      expect(widget.nameFromEvent, null);
    });

    test('context.event() returns event value when event is dispatched',
        () async {
      var store =
          Store<AppState>(initialState: AppState(name: 'Initial', age: 18));
      var context = MockBuildContext(store);

      // Build widget - event is spent
      var widget1 = MyConnector().build(context) as MyWidget;
      expect(widget1.nameFromEvent, null);

      // Dispatch action with event
      await store.dispatchAndWait(ChangeNameWithEvent('NewName'));

      // Rebuild widget - event should be consumed and return the value
      var widget2 = MyConnector().build(context) as MyWidget;
      expect(widget2.nameFromEvent, 'NewName');
      expect(widget2.name, 'NewName');
    });

    test('context.event() consumes event only once', () async {
      var store =
          Store<AppState>(initialState: AppState(name: 'Initial', age: 22));
      var context = MockBuildContext(store);

      // Dispatch action with event
      await store.dispatchAndWait(ChangeNameWithEvent('FirstEvent'));

      // First build - event should be consumed
      var widget1 = MyConnector().build(context) as MyWidget;
      expect(widget1.nameFromEvent, 'FirstEvent');

      // Second build - event is now spent
      var widget2 = MyConnector().build(context) as MyWidget;
      expect(widget2.nameFromEvent, null);
    });

    test('all context methods work together in MyConnector', () async {
      var store =
          Store<AppState>(initialState: AppState(name: 'AllMethods', age: 28));
      var context = MockBuildContext(store);
      var widget = MyConnector().build(context) as MyWidget;

      // All methods should return the same name
      expect(widget.name, 'AllMethods');
      expect(widget.nameFromRead, 'AllMethods');
      expect(widget.nameFromSelect, 'AllMethods');
      expect(widget.nameFromEvent, null); // Event is spent

      // Dispatch action with event
      await store.dispatchAndWait(ChangeNameWithEvent('UpdatedWithEvent'));

      // Rebuild and verify all methods work
      var widget2 = MyConnector().build(context) as MyWidget;
      expect(widget2.name, 'UpdatedWithEvent');
      expect(widget2.nameFromRead, 'UpdatedWithEvent');
      expect(widget2.nameFromSelect, 'UpdatedWithEvent');
      expect(widget2.nameFromEvent, 'UpdatedWithEvent');
    });

    test(
        'context.read() and context.state return same value after state change',
        () async {
      var store =
          Store<AppState>(initialState: AppState(name: 'Before', age: 33));
      var context = MockBuildContext(store);

      // Change state
      await store.dispatchAndWait(ChangeName('After'));

      // Build widget and verify both methods return updated state
      var widget = MyConnector().build(context) as MyWidget;
      expect(widget.name, 'After');
      expect(widget.nameFromRead, 'After');
      expect(widget.name, widget.nameFromRead);
    });

    test('context.dispatchAll() dispatches multiple actions', () async {
      var store =
          Store<AppState>(initialState: AppState(name: 'Initial', age: 0));
      var context = MockBuildContext(store);
      var widget = MyConnector().build(context) as MyWidget;

      // Dispatch multiple actions via MyConnector
      widget.onDispatchAll();

      // Both actions should be applied
      expect(store.state.name, 'Updated');
      expect(store.state.age, 42);
    });

    test('context.dispatchSync() dispatches synchronous action', () {
      var store =
          Store<AppState>(initialState: AppState(name: 'Initial', age: 10));
      var context = MockBuildContext(store);
      var widget = MyConnector().build(context) as MyWidget;

      // Dispatch sync action via MyConnector
      widget.onDispatchSync();

      // Action completes immediately
      expect(store.state.name, 'Sync');
    });

    test('context.dispatchAndWait() waits for async action then dispatches',
        () async {
      var store =
          Store<AppState>(initialState: AppState(name: 'Initial', age: 0));
      var context = MockBuildContext(store);
      var widget = MyConnector().build(context) as MyWidget;

      // Age should be 0 initially
      expect(store.state.age, 0);

      // Dispatch async action via MyConnector - waits for WaitAndChangeAge(10), then DuplicateAge
      await widget.onDispatchAndWait();

      // After waiting, age should be 10 * 2 = 20
      expect(store.state.age, 20);
    });

    test('context.dispatchAndWaitAll() waits for all actions then dispatches',
        () async {
      var store =
          Store<AppState>(initialState: AppState(name: 'Initial', age: 0));
      var context = MockBuildContext(store);
      var widget = MyConnector().build(context) as MyWidget;

      // Initial values
      expect(store.state.age, 0);
      expect(store.state.name, 'Initial');

      // Dispatch multiple async actions - waits for both, then DuplicateAge
      await widget.onDispatchAndWaitAll();

      // After waiting, age should be 5 * 2 = 10, name should be 'AsyncAll'
      expect(store.state.age, 10);
      expect(store.state.name, 'AsyncAll');
    });

    test('context.env returns store environment', () {
      var env = TestEnvironment(apiUrl: 'https://api.test.com');
      var store = Store<AppState>(
        initialState: AppState(name: 'Test', age: 45),
        environment: env,
      );
      var context = MockBuildContext(store);
      var widget = MyConnector().build(context) as MyWidget;

      // Get environment via MyConnector
      expect(widget.environment, env);
      expect(widget.environment?.apiUrl, 'https://api.test.com');
    });
  });
}

// Define AppState with name, age fields and event
class AppState {
  final String name;
  final int age;
  final Event<String> nameChangedEvent;

  AppState({
    required this.name,
    required this.age,
    Event<String>? nameChangedEvent,
  }) : nameChangedEvent = nameChangedEvent ?? Event<String>.spent();

  AppState copy({
    String? name,
    int? age,
    Event<String>? nameChangedEvent,
  }) =>
      AppState(
        name: name ?? this.name,
        age: age ?? this.age,
        nameChangedEvent: nameChangedEvent ?? this.nameChangedEvent,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppState &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          age == other.age &&
          nameChangedEvent == other.nameChangedEvent;

  @override
  int get hashCode => name.hashCode ^ age.hashCode ^ nameChangedEvent.hashCode;
}

// Define extension for BuildContext
extension BuildContextExtension on BuildContext {
  AppState get state => getState<AppState>();

  AppState read() => getRead<AppState>();

  R select<R>(R Function(AppState state) selector) =>
      getSelect<AppState, R>(selector);

  R? event<R>(Evt<R> Function(AppState state) selector) =>
      getEvent<AppState, R>(selector);

  TestEnvironment? get env => getEnvironment<AppState>() as TestEnvironment?;
}

// Define ChangeName action
class ChangeName extends ReduxAction<AppState> {
  final String newName;

  ChangeName(this.newName);

  @override
  AppState reduce() => state.copy(name: newName);
}

// Define ChangeAge action
class ChangeAge extends ReduxAction<AppState> {
  final int newAge;

  ChangeAge(this.newAge);

  @override
  AppState reduce() => state.copy(age: newAge);
}

// Define WaitAndChangeAge - async action that waits 200ms
class WaitAndChangeAge extends ReduxAction<AppState> {
  final int newAge;

  WaitAndChangeAge(this.newAge);

  @override
  Future<AppState> reduce() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return state.copy(age: newAge);
  }
}

// Define DuplicateAge - doubles the current age
class DuplicateAge extends ReduxAction<AppState> {
  @override
  AppState reduce() => state.copy(age: state.age * 2);
}

// Define ChangeNameWithEvent action that also triggers an event
class ChangeNameWithEvent extends ReduxAction<AppState> {
  final String newName;

  ChangeNameWithEvent(this.newName);

  @override
  AppState reduce() => state.copy(
        name: newName,
        nameChangedEvent: Event<String>(newName),
      );
}

// Define MyWidget - the dumb widget
class MyWidget extends StatelessWidget {
  final String name;
  final String nameFromRead;
  final String nameFromSelect;
  final String? nameFromEvent;
  final VoidCallback onChange;
  final VoidCallback onDispatchAll;
  final VoidCallback onDispatchSync;
  final Future<void> Function() onDispatchAndWait;
  final Future<void> Function() onDispatchAndWaitAll;
  final TestEnvironment? environment;

  const MyWidget({
    Key? key,
    required this.name,
    required this.nameFromRead,
    required this.nameFromSelect,
    required this.nameFromEvent,
    required this.onChange,
    required this.onDispatchAll,
    required this.onDispatchSync,
    required this.onDispatchAndWait,
    required this.onDispatchAndWaitAll,
    required this.environment,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(name),
        Text(nameFromRead),
        Text(nameFromSelect),
        if (nameFromEvent != null) Text(nameFromEvent!),
        ElevatedButton(
          onPressed: onChange,
          child: const Text('Change Name'),
        ),
      ],
    );
  }
}

// Define MyConnector - the smart widget using context extensions
class MyConnector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MyWidget(
      name: context.state.name,
      nameFromRead: context.read().name,
      nameFromSelect: context.select((AppState state) => state.name),
      nameFromEvent: context.event((AppState state) => state.nameChangedEvent),
      onChange: () => context.dispatch(ChangeName('John')),
      onDispatchAll: () => context.dispatchAll([
        ChangeName('Updated'),
        ChangeAge(42),
      ]),
      onDispatchSync: () => context.dispatchSync(ChangeName('Sync')),
      onDispatchAndWait: () async {
        await context.dispatchAndWait(WaitAndChangeAge(10));
        context.dispatch(DuplicateAge());
      },
      onDispatchAndWaitAll: () async {
        await context.dispatchAndWaitAll([
          WaitAndChangeAge(5),
          ChangeName('AsyncAll'),
        ]);
        context.dispatch(DuplicateAge());
      },
      environment: context.env,
    );
  }
}

// Define TestEnvironment for testing getEnvironment
class TestEnvironment {
  final String apiUrl;

  TestEnvironment({required this.apiUrl});
}
