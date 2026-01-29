---
name: asyncredux-setup
description: Initialize and configure AsyncRedux in a Flutter app. Covers adding the package dependency, creating the Store with initial state, wrapping the app with StoreProvider, and setting up required context extensions for state access.
---

# AsyncRedux Setup

## Adding the Dependency

Add AsyncRedux to your `pubspec.yaml`:

```yaml
dependencies:
  async_redux: ^25.6.1
```

Check [pub.dev](https://pub.dev/packages/async_redux) for the latest version.

## Creating the State Class

Create an immutable `AppState` class with a `copy()` method and `initialState()` factory:

```dart
class AppState {
  final String name;
  final int age;

  AppState({required this.name, required this.age});

  static AppState initialState() => AppState(name: "", age: 0);

  AppState copy({String? name, int? age}) =>
      AppState(
        name: name ?? this.name,
        age: age ?? this.age,
      );
}
```

All fields must be `final` (immutable). Add additional helper methods as needed:

```dart
AppState withName(String name) => copy(name: name);
AppState withAge(int age) => copy(age: age);
```

## Creating the Store

Create the store with your initial state:

```dart
var store = Store<AppState>(
  initialState: AppState.initialState(),
);
```

## Wrapping with StoreProvider

Wrap your app with `StoreProvider` to make the store accessible:

```dart
import 'package:async_redux/async_redux.dart';

Widget build(context) {
  return StoreProvider<AppState>(
    store: store,
    child: MaterialApp( ... ),
  );
}
```

## Required Context Extensions

Add this extension to your file containing `AppState` (required for state access in widgets):

```dart
extension BuildContextExtension on BuildContext {
  // State access
  AppState get state => getState<AppState>();
  AppState read() => getRead<AppState>();
  R select<R>(R Function(AppState state) selector) => getSelect<AppState, R>(selector);
  R? event<R>(Evt<R> Function(AppState state) selector) => getEvent<AppState, R>(selector);

  // Dispatching actions
  void dispatch(ReduxAction<AppState> action) => getStore<AppState>().dispatch(action);
  Future<ActionStatus> dispatchAndWait(ReduxAction<AppState> action) => getStore<AppState>().dispatchAndWait(action);
  void dispatchAll(List<ReduxAction<AppState>> actions) => getStore<AppState>().dispatchAll(actions);
  Future<void> dispatchAndWaitAll(List<ReduxAction<AppState>> actions) => getStore<AppState>().dispatchAndWaitAll(actions);
  void dispatchSync(ReduxAction<AppState> action) => getStore<AppState>().dispatchSync(action);
}
```

## State Access Methods

| Method | Use In | Rebuilds Widget |
|--------|--------|-----------------|
| `context.state` | build method | On any state change |
| `context.select()` | build method | Only when selected data changes |
| `context.read()` | initState, callbacks | Never |

## Dispatching Actions

```dart
Widget build(BuildContext context) {
  return ElevatedButton(
    onPressed: () => context.dispatch(Increment()),
    child: Text('Increment'),
  );
}
```

## Complete Minimal Example

```dart
import 'package:flutter/material.dart';
import 'package:async_redux/async_redux.dart';

// State
class AppState {
  final int counter;
  AppState({required this.counter});
  static AppState initialState() => AppState(counter: 0);
  AppState copy({int? counter}) => AppState(counter: counter ?? this.counter);
}

// Context extension
extension BuildContextExtension on BuildContext {
  AppState get state => getState<AppState>();
  void dispatch(ReduxAction<AppState> action) => getStore<AppState>().dispatch(action);
}

// Action
class Increment extends ReduxAction<AppState> {
  @override
  AppState reduce() => state.copy(counter: state.counter + 1);
}

// Store
final store = Store<AppState>(initialState: AppState.initialState());

// App
void main() => runApp(
  StoreProvider<AppState>(
    store: store,
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Count: ${context.state.counter}'),
                ElevatedButton(
                  onPressed: () => context.dispatch(Increment()),
                  child: Text('Increment'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);
```

## References

- https://asyncredux.com/flutter/intro
- https://asyncredux.com/flutter/basics/state
- https://asyncredux.com/flutter/basics/store
- https://asyncredux.com/flutter/basics/using-the-store-state
- https://asyncredux.com/flutter/basics/dispatching-actions
- https://asyncredux.com/flutter/basics/actions-and-reducers
