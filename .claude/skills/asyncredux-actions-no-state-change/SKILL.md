---
name: asyncredux-actions-no-state-change
description: Create actions that perform side effects without changing state (returning null). Covers logging actions, analytics dispatch, triggering external services, and when to use null-returning reducers.
---

# Actions That Don't Change State

In AsyncRedux, returning a new state from reducers is **optional**. When you don't need to modify the application state, return `null` to keep the current state unchanged.

## Basic Pattern

Return `null` from `reduce()` when no state modification is needed:

```dart
class MyAction extends ReduxAction<AppState> {
  AppState? reduce() {
    // Perform side effects here
    return null; // State remains unchanged
  }
}
```

## When to Return Null

### 1. Conditional State Updates

Only update state when certain conditions are met:

```dart
class GetAmount extends ReduxAction<AppState> {
  Future<AppState?> reduce() async {
    int amount = await getAmount();
    if (amount == 0)
      return null; // No change needed
    else
      return state.copy(counter: state.counter + amount);
  }
}
```

### 2. Coordinating Other Actions

Actions that dispatch other actions but don't modify state directly:

```dart
class InitAction extends ReduxAction<AppState> {
  AppState? reduce() {
    dispatch(ReadDatabaseAction());
    dispatch(StartTimersAction());
    dispatch(TurnOnListenersAction());
    return null; // This action doesn't change state itself
  }
}
```

### 3. Logging Actions

Actions that log information without affecting state:

```dart
class LogUserActivity extends ReduxAction<AppState> {
  final String activity;
  LogUserActivity(this.activity);

  AppState? reduce() {
    print('User activity: $activity at ${DateTime.now()}');
    // Or send to logging service
    return null;
  }
}
```

### 4. Analytics Dispatch

Send analytics events without state changes:

```dart
class TrackScreenView extends ReduxAction<AppState> {
  final String screenName;
  TrackScreenView(this.screenName);

  Future<AppState?> reduce() async {
    await analytics.logScreenView(screenName: screenName);
    return null;
  }
}
```

### 5. Triggering External Services

Call external services without modifying app state:

```dart
class SendNotification extends ReduxAction<AppState> {
  final String message;
  SendNotification(this.message);

  Future<AppState?> reduce() async {
    await notificationService.send(message);
    return null;
  }
}
```

### 6. Navigation Actions

Trigger navigation as a side effect:

```dart
class GoToSettings extends ReduxAction<AppState> {
  AppState? reduce() {
    dispatch(NavigateAction.pushNamed('/settings'));
    return null;
  }
}
```

## Side Effects with before() and after()

For side effects that should run before or after the reducer, use the `before()` and `after()` methods:

```dart
class ShowBarrierWhileLoading extends ReduxAction<AppState> {
  Future<AppState?> reduce() async {
    await someAsyncWork();
    return null; // Or return new state
  }

  void before() => dispatch(BarrierAction(true));
  void after() => dispatch(BarrierAction(false)); // Always runs, like finally
}
```

The `after()` method executes regardless of errors, making it safe for cleanup.

## Using Observers for Logging and Analytics

For automatic logging/analytics without explicit actions, use observers:

```dart
var store = Store<AppState>(
  initialState: state,
  actionObservers: [ConsoleActionObserver()], // Built-in logging
  stateObservers: [MetricsObserver()],        // Custom analytics
);
```

Custom metrics observer:

```dart
class MetricsObserver implements StateObserver<AppState> {
  void observe(
    ReduxAction<AppState> action,
    AppState prevState,
    AppState newState,
    Object? error,
    int dispatchCount,
  ) {
    if (action is AppAction) {
      action.trackEvent(prevState, newState, error);
    }
  }
}
```

## Key Points

1. **Return type matters**: Use `AppState?` for sync, `Future<AppState?>` for async
2. **Null means no change**: The store keeps its current state
3. **Side effects are valid**: Actions can dispatch other actions, call services, or log data
4. **Observers are automatic**: For cross-cutting concerns like logging, prefer observers over explicit actions

## References

URLs read to create this skill:
- https://asyncredux.com/flutter/basics/changing-state-is-optional
- https://asyncredux.com/flutter/basics/actions-and-reducers
- https://asyncredux.com/flutter/basics/sync-actions
- https://asyncredux.com/flutter/basics/async-actions
- https://asyncredux.com/flutter/advanced-actions/redux-action
- https://asyncredux.com/flutter/advanced-actions/before-and-after-the-reducer
- https://asyncredux.com/flutter/miscellaneous/logging
- https://asyncredux.com/flutter/miscellaneous/metrics
- https://asyncredux.com/flutter/miscellaneous/business-logic
- https://asyncredux.com/flutter/miscellaneous/navigation
