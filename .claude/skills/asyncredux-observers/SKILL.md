---
name: asyncredux-observers
description: Set up observers for debugging and monitoring. Covers implementing actionObservers for dispatch logging, stateObserver for state change tracking, observing errors with globalErrorObserver, and using observers for analytics.
---

# Setting Up Observers for Debugging and Monitoring

AsyncRedux provides several observer types for monitoring actions, state changes, errors, and widget rebuilds. These observers are configured when creating the Store.

## Overview of Observer Types

| Observer Type | Purpose |
|--------------|---------|
| `ActionObserver` | Monitor action dispatch (start and end) |
| `StateObserver` | Monitor state changes after actions |
| `GlobalErrorObserver` | Monitor, transform, and handle action errors |
| `ModelObserver` | Monitor widget rebuilds (for StoreConnector) |

## Store Configuration with Observers

```dart
var store = Store<AppState>(
  initialState: AppState.initialState(),
  actionObservers: [ConsoleActionObserver()],
  stateObservers: [MyStateObserver()],
  globalErrorObserver: (store) => MyGlobalErrorObserver(),
  modelObserver: DefaultModelObserver(),
);
```

## ActionObserver

The `ActionObserver` monitors when actions are dispatched and when they complete. It triggers twice per action: at the start (INI) and at the end (END).

### ActionObserver Abstract Class

```dart
abstract class ActionObserver<St> {
  void observe(
    ReduxAction<St> action,
    int dispatchCount, {
    required bool ini,
  });
}
```

### Parameters

- `action`: The dispatched action instance
- `dispatchCount`: Sequential number of this dispatch
- `ini`: `true` when action starts (INI phase), `false` when it ends (END phase)

### Observation Phases

**INI Phase**: Action dispatch begins. The reducer hasn't modified state yet. Sync reducers may complete during this phase; async reducers start their async process.

**END Phase**: The reducer has finished and returned the new state. State modifications are now observable.

**Important**: Receiving an END observation does not guarantee all effects have finished. Async operations that were not awaited may continue running and dispatch additional actions later.

### Built-in ConsoleActionObserver

AsyncRedux provides `ConsoleActionObserver` for development debugging:

```dart
var store = Store<AppState>(
  initialState: AppState.initialState(),
  actionObservers: kReleaseMode ? null : [ConsoleActionObserver()],
);
```

This prints actions in yellow to the console. Override `toString()` in your actions to display additional information:

```dart
class LoadUserAction extends AppAction {
  final String username;
  LoadUserAction(this.username);

  @override
  Future<AppState?> reduce() async {
    // ...
  }

  @override
  String toString() => 'LoadUserAction(username: $username)';
}
```

### Using Log.printer for Formatted Output

```dart
var store = Store<AppState>(
  initialState: AppState.initialState(),
  actionObservers: [Log.printer(formatter: Log.verySimpleFormatter)],
);
```

### Custom ActionObserver Implementation

```dart
class MyActionObserver implements ActionObserver<AppState> {
  @override
  void observe(
    ReduxAction<AppState> action,
    int dispatchCount, {
    required bool ini,
  }) {
    final phase = ini ? 'START' : 'END';
    print('[$phase] Action #$dispatchCount: ${action.runtimeType}');
  }
}
```

## StateObserver

The `StateObserver` is notified of all state changes, allowing you to track, log, or record state history.

### StateObserver Abstract Class

```dart
abstract class StateObserver<St> {
  void observe(
    ReduxAction<St> action,
    St prevState,
    St newState,
    Object? error,
    int dispatchCount,
  );
}
```

### Parameters

- `action`: The action that triggered the change
- `prevState`: State before the reducer executed
- `newState`: State returned by the reducer
- `error`: Null if successful; contains the thrown error otherwise
- `dispatchCount`: Sequential dispatch number

### Detecting State Changes

Compare states using `identical()` to detect actual changes:

```dart
bool stateChanged = !identical(prevState, newState);
```

### Custom StateObserver for Logging

```dart
class StateLogger implements StateObserver<AppState> {
  @override
  void observe(
    ReduxAction<AppState> action,
    AppState prevState,
    AppState newState,
    Object? error,
    int dispatchCount,
  ) {
    final changed = !identical(prevState, newState);
    print('Action #$dispatchCount: ${action.runtimeType}');
    print('  State changed: $changed');
    if (error != null) {
      print('  Error: $error');
    }
  }
}
```

### StateObserver for Undo/Redo

A common use case is recording state history for undo/redo functionality:

```dart
class UndoRedoObserver implements StateObserver<AppState> {
  final List<AppState> _history = [];
  int _currentIndex = -1;
  final int maxHistorySize;

  UndoRedoObserver({this.maxHistorySize = 50});

  bool get canUndo => _currentIndex > 0;
  bool get canRedo => _currentIndex < _history.length - 1;

  @override
  void observe(
    ReduxAction<AppState> action,
    AppState prevState,
    AppState newState,
    Object? error,
    int dispatchCount,
  ) {
    // Skip undo/redo actions to avoid recording navigation
    if (action is UndoAction || action is RedoAction) return;

    // Skip if state didn't change
    if (identical(prevState, newState)) return;

    // Remove "future" states if we're navigating
    if (_currentIndex < _history.length - 1) {
      _history.removeRange(_currentIndex + 1, _history.length);
    }

    // Add new state
    _history.add(newState);
    _currentIndex = _history.length - 1;

    // Enforce max history size
    if (_history.length > maxHistorySize) {
      _history.removeAt(0);
      _currentIndex--;
    }
  }

  AppState? getPreviousState() {
    if (!canUndo) return null;
    _currentIndex--;
    return _history[_currentIndex];
  }

  AppState? getNextState() {
    if (!canRedo) return null;
    _currentIndex++;
    return _history[_currentIndex];
  }
}
```

## GlobalErrorObserver

The `GlobalErrorObserver` monitors all errors thrown by actions. It can log them, transform them (for example, into `UserException`s), or suppress them.

### Error Handling Flow

The error handling order is:
1. `wrapError()` (action-level)
2. `GlobalErrorObserver` (app-level transformation and monitoring/logging)

After that, `UserException`s go to the error queue (shown by `UserExceptionDialog`) and are not thrown, while other errors are thrown.

### GlobalErrorObserver Implementation

Extend `GlobalErrorObserver` and override `observe()`. Inside it you can access `error` (after `wrapError`), `originalError` (before `wrapError`), `stackTrace`, `action`, and `store`. Do not use `store` to dispatch actions.

```dart
class MyGlobalErrorObserver extends GlobalErrorObserver<AppState> {
  @override
  Object? observe() {
    // Transform platform errors to user-friendly messages
    if (error is PlatformException) {
      return UserException('Check your internet connection').addCause(error);
    }

    // Log unexpected errors and send them to a crash reporting service
    if (error is! UserException) {
      print('Error in ${action.runtimeType}: $error');
      print(stackTrace);
      crashReporter.recordError(error, stackTrace, reason: action.runtimeType.toString());
    }

    // Return the error to keep it, or null to suppress it
    return error;
  }
}
```

### Store Configuration with GlobalErrorObserver

```dart
var store = Store<AppState>(
  initialState: AppState.initialState(),
  globalErrorObserver: (store) => MyGlobalErrorObserver(),
);
```

AsyncRedux also provides `GlobalErrorObserverDummy` (does nothing), `GlobalErrorObserverForDevelopment` (also shows non-`UserException` errors in the dialog), and `SwallowGlobalErrorObserver` (swallows all errors, not recommended).

## ModelObserver

The `ModelObserver` monitors widget rebuilds when using `StoreConnector`. This is useful for debugging rebuild behavior and ensuring efficient state updates.

### Setup

```dart
var store = Store<AppState>(
  initialState: AppState.initialState(),
  modelObserver: DefaultModelObserver(),
);
```

### Console Output

`DefaultModelObserver` prints rebuild information:

```
Model D:1 R:1 = Rebuild:true, Connector:MyWidgetConnector, Model:MyViewModel{B}.
Model D:2 R:2 = Rebuild:false, Connector:MyWidgetConnector, Model:MyViewModel{B}.
Model D:3 R:3 = Rebuild:true, Connector:MyWidgetConnector, Model:MyViewModel{C}.
```

- `D`: Dispatch count
- `R`: Rebuild count
- `Rebuild`: Whether the widget actually rebuilt
- `Connector`: The StoreConnector type
- `Model`: The ViewModel with current state

### Configuration for Better Output

Pass `debug: this` to `StoreConnector` to enable connector type printing:

```dart
class MyWidgetConnector extends StatelessWidget with StoreConnector<AppState, MyViewModel> {
  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, MyViewModel>(
      debug: this, // Enable for ModelObserver output
      converter: (store) => MyViewModel.fromStore(store),
      builder: (context, vm) => MyWidget(vm),
    );
  }
}
```

Override `ViewModel.toString()` for custom diagnostic information.

## Using Observers for Analytics

### Metrics Observer Pattern

Create a metrics observer that delegates to action-specific tracking methods:

```dart
abstract class AppAction extends ReduxAction<AppState> {
  /// Override in specific actions to track metrics
  void trackEvent(MetricsService metrics) {}
}

class MetricsObserver implements StateObserver<AppState> {
  final MetricsService metrics;

  MetricsObserver(this.metrics);

  @override
  void observe(
    ReduxAction<AppState> action,
    AppState prevState,
    AppState newState,
    Object? error,
    int dispatchCount,
  ) {
    if (action is AppAction) {
      action.trackEvent(metrics);
    }
  }
}
```

Then override `trackEvent` in specific actions:

```dart
class PurchaseAction extends AppAction {
  final Product product;
  PurchaseAction(this.product);

  @override
  Future<AppState?> reduce() async {
    await purchaseService.buy(product);
    return state.copy(purchases: state.purchases.add(product));
  }

  @override
  void trackEvent(MetricsService metrics) {
    metrics.trackPurchase(productId: product.id, price: product.price);
  }
}
```

### Analytics ActionObserver

Track all dispatched actions for analytics:

```dart
class AnalyticsObserver implements ActionObserver<AppState> {
  final AnalyticsService analytics;

  AnalyticsObserver(this.analytics);

  @override
  void observe(
    ReduxAction<AppState> action,
    int dispatchCount, {
    required bool ini,
  }) {
    // Only track at start (ini) to avoid double-counting
    if (ini) {
      analytics.trackEvent(
        'action_dispatched',
        parameters: {'action_type': action.runtimeType.toString()},
      );
    }
  }
}
```

## Complete Example: Store with All Observers

```dart
// observers.dart
class ConsoleStateObserver implements StateObserver<AppState> {
  @override
  void observe(
    ReduxAction<AppState> action,
    AppState prevState,
    AppState newState,
    Object? error,
    int dispatchCount,
  ) {
    final changed = !identical(prevState, newState);
    print('[$dispatchCount] ${action.runtimeType} - Changed: $changed');
    if (error != null) print('  Error: $error');
  }
}

class CrashReportingErrorObserver extends GlobalErrorObserver<AppState> {
  @override
  Object? observe() {
    // Transform errors globally
    if (error is PlatformException) {
      return UserException('Check your internet connection').addCause(error);
    }
    // Don't report UserExceptions (they're expected)
    if (error is! UserException) {
      FirebaseCrashlytics.instance.recordError(error, stackTrace);
    }
    return error; // Keep the error
  }
}

// main.dart
void main() {
  final store = Store<AppState>(
    initialState: AppState.initialState(),
    // Only enable console observers in debug mode
    actionObservers: kDebugMode ? [ConsoleActionObserver()] : null,
    stateObservers: kDebugMode ? [ConsoleStateObserver()] : null,
    // Always enable error observer (also transforms errors globally)
    globalErrorObserver: (store) => CrashReportingErrorObserver(),
  );

  runApp(StoreProvider<AppState>(
    store: store,
    child: MyApp(),
  ));
}
```

## Multiple Observers

You can use multiple observers of the same type:

```dart
var store = Store<AppState>(
  initialState: AppState.initialState(),
  actionObservers: [
    ConsoleActionObserver(),
    AnalyticsObserver(analyticsService),
    PerformanceObserver(),
  ],
  stateObservers: [
    StateLogger(),
    UndoRedoObserver(),
    MetricsObserver(metricsService),
  ],
);
```

All observers will be notified in the order they are listed.

## References

URLs from the documentation:
- https://asyncredux.com/flutter/miscellaneous/logging
- https://asyncredux.com/flutter/miscellaneous/metrics
- https://asyncredux.com/flutter/miscellaneous/observing-rebuilds
- https://asyncredux.com/flutter/miscellaneous/undo-and-redo
- https://asyncredux.com/flutter/advanced-actions/errors-thrown-by-actions
- https://asyncredux.com/flutter/advanced-actions/redux-action
- https://asyncredux.com/flutter/basics/store
