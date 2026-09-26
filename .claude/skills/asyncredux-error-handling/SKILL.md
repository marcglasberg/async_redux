---
name: asyncredux-error-handling
description: Implement comprehensive error handling for actions. Covers the `wrapError()` method for action-level error wrapping, GlobalErrorObserver for app-wide error transformation and logging/monitoring, and the error handling flow (before → reduce → after).
---

# Error Handling in AsyncRedux

AsyncRedux provides a comprehensive error handling system with multiple layers: action-level wrapping, global error transformation, and error observation for logging/monitoring.

## Error Flow and Action Lifecycle

When errors occur during action execution:

1. If `before()` throws an error, the reducer doesn't execute and state remains unchanged
2. If `reduce()` throws an error, execution halts without state modification
3. The `after()` method **always** runs, even when errors occur (like a `finally` block)

**Processing order:** `wrapError()` → `GlobalErrorObserver`

## Throwing Errors from Actions

Actions can throw errors using `throw`. When an error is thrown, the reducer stops and state is not modified:

```dart
class TransferMoney extends AppAction {
  final double amount;
  TransferMoney(this.amount);

  AppState? reduce() {
    if (amount == 0) {
      throw UserException('You cannot transfer zero money.');
    }
    return state.copy(cash: state.cash - amount);
  }
}
```

## UserException for User-Facing Errors

`UserException` is a built-in class for errors that users can understand and potentially fix (not code bugs):

```dart
class SaveUser extends AppAction {
  final String name;
  SaveUser(this.name);

  Future<AppState?> reduce() async {
    if (name.length < 4)
      throw UserException('Name must have 4 letters.');

    await saveUser(name);
    return null;
  }
}
```

When a `UserException` is thrown, it's added to a special error queue in the store and can be displayed via `UserExceptionDialog`.

### Displaying UserExceptions

Wrap your home page with `UserExceptionDialog` below both `StoreProvider` and `MaterialApp`:

```dart
UserExceptionDialog<AppState>(
  onShowUserExceptionDialog: (context, exception) => showDialog(...),
  child: MyHomePage(),
)
```

## Action-Level Error Wrapping with wrapError()

The `wrapError()` method acts as a catch block for entire actions. It receives the original error and stack trace, and must return:
- A modified error (to transform the error)
- `null` (to suppress/disable the error)
- The unchanged error (to pass it through)

```dart
class LogoutAction extends AppAction {
  @override
  Object? wrapError(Object error, StackTrace stackTrace) {
    return LogoutError("Logout failed", cause: error);
  }

  Future<AppState?> reduce() async {
    await authService.logout();
    return state.copy(user: null);
  }
}
```

### Mixin Pattern for Reusable Error Handling

Create mixins for consistent error transformation across multiple actions:

```dart
mixin ShowUserException on AppAction {
  String getErrorMessage();

  @override
  Object? wrapError(Object error, StackTrace stackTrace) {
    return UserException(getErrorMessage()).addCause(error);
  }
}

class LoadDataAction extends AppAction with ShowUserException {
  @override
  String getErrorMessage() => 'Failed to load data. Please try again.';

  Future<AppState?> reduce() async {
    var data = await api.loadData();
    return state.copy(data: data);
  }
}
```

### Suppressing Errors

Return `null` from `wrapError()` to suppress errors without further propagation:

```dart
@override
Object? wrapError(Object error, StackTrace stackTrace) {
  if (error is CancelledException) {
    return null; // Silently ignore cancellation
  }
  return error;
}
```

## Global Error Handling with GlobalErrorObserver

`GlobalErrorObserver` processes all action errors centrally, after the action's `wrapError()`. Use it to transform third-party library errors (like Firebase or platform exceptions) into `UserException`s, and to log errors to services like Sentry or Crashlytics:

```dart
var store = Store<AppState>(
  initialState: AppState.initialState(),
  globalErrorObserver: (store) => MyGlobalErrorObserver(),
);

class MyGlobalErrorObserver extends GlobalErrorObserver<AppState> {
  @override
  Object? observe() {
    // Transform platform exceptions to user-friendly messages
    if (error is PlatformException && (error as PlatformException).code == "Error performing get") {
      return UserException('Check your internet connection').addCause(error);
    }

    // Transform Firebase errors
    if (error is FirebaseException) {
      return UserException('Service temporarily unavailable').addCause(error);
    }

    // Log unexpected errors (not UserExceptions) to crash reporting
    if (error is! UserException) {
      print("Error during ${action.runtimeType}: $error");
      crashlytics.recordError(error, stackTrace);
    }

    // Pass through all other errors unchanged
    return error;
  }
}
```

Inside `observe()` you have access to:
- `error`: The error, after the action's `wrapError()`
- `originalError`: The error before `wrapError()`
- `stackTrace`: The stack trace
- `action`: The action that failed
- `store`: Use it to read `store.state`, `store.environment` or `store.configuration`. Do **not** use it to dispatch actions.

The `observe` method returns:
- The error (unchanged or modified) to keep it. `UserException`s then go to the error queue (shown by `UserExceptionDialog`) and are not thrown; other errors are thrown.
- `null` to swallow the error silently

AsyncRedux also provides `GlobalErrorObserverDummy` (does nothing), `GlobalErrorObserverForDevelopment` (also shows non-`UserException` errors in the dialog), and `SwallowGlobalErrorObserver` (swallows all errors, not recommended).

## UserExceptionAction for Mid-Action Errors

For showing error feedback while allowing the action to continue (without stopping execution):

```dart
class ConvertAction extends AppAction {
  final String text;
  ConvertAction(this.text);

  Future<AppState?> reduce() async {
    var value = int.tryParse(text);
    if (value == null) {
      // Show error but continue action
      dispatch(UserExceptionAction('Please enter a valid number'));
      return null; // No state change
    }
    return state.copy(counter: value);
  }
}
```

## Checking Action Failure Status

### Using ActionStatus

After dispatching with `dispatchAndWait()`, check the status:

```dart
var status = await store.dispatchAndWait(SaveAction());

if (status.isCompletedOk) {
  Navigator.pop(context);
} else if (status.isCompletedFailed) {
  var error = status.wrappedError;
  print('Save failed: $error');
}
```

**ActionStatus properties:**
- `isCompletedOk`: Action finished without errors
- `isCompletedFailed`: Action encountered errors
- `originalError`: The error as thrown from `before` or `reduce`
- `wrappedError`: The error after transformation by `wrapError()`

### Using isFailed in Widgets

Check action failure state in the UI:

```dart
Widget build(BuildContext context) {
  if (context.isFailed(LoadDataAction)) {
    var exception = context.exceptionFor(LoadDataAction);
    return Column(
      children: [
        Text('Error: ${exception?.message}'),
        ElevatedButton(
          onPressed: () => context.dispatch(LoadDataAction()),
          child: Text('Retry'),
        ),
      ],
    );
  }

  if (context.isWaiting(LoadDataAction)) {
    return CircularProgressIndicator();
  }

  return DataWidget(data: context.state.data);
}
```

The error is cleared automatically when the action is dispatched again.

To manually clear the error:
```dart
context.clearExceptionFor(LoadDataAction);
```

## Testing Error Handling

Test that actions fail with expected errors:

```dart
test('action throws UserException for invalid input', () async {
  var store = Store<AppState>(initialState: AppState.initialState());

  var status = await store.dispatchAndWait(SaveUser('abc')); // too short

  expect(status.isCompletedFailed, isTrue);
  var error = status.wrappedError;
  expect(error, isA<UserException>());
  expect((error as UserException).msg, 'Name must have 4 letters.');
});
```

Test multiple exceptions via the error queue:

```dart
test('multiple actions accumulate errors', () async {
  var store = Store<AppState>(initialState: AppState.initialState());

  await store.dispatchAndWaitAll([
    InvalidAction1(),
    InvalidAction2(),
    InvalidAction3(),
  ]);

  var errors = store.errors;
  expect(errors.length, 3);
  expect(errors[0].msg, 'First error message');
});
```

## Complete Store Setup with Error Handling

```dart
var store = Store<AppState>(
  initialState: AppState.initialState(),
  globalErrorObserver: (store) => MyGlobalErrorObserver(),
  actionObservers: [Log.printer(formatter: Log.verySimpleFormatter)],
);

class MyGlobalErrorObserver extends GlobalErrorObserver<AppState> {
  @override
  Object? observe() {
    if (error is SocketException) {
      return UserException('No internet connection').addCause(error);
    }
    // Skip logging UserExceptions (they're expected)
    if (error is! UserException) {
      crashlytics.recordError(error, stackTrace);
    }
    return error;
  }
}
```

## References

URLs from the documentation:
- https://asyncredux.com/sitemap.xml
- https://asyncredux.com/flutter/advanced-actions/errors-thrown-by-actions
- https://asyncredux.com/flutter/advanced-actions/wrapping-the-reducer
- https://asyncredux.com/flutter/basics/failed-actions
- https://asyncredux.com/flutter/advanced-actions/before-and-after-the-reducer
- https://asyncredux.com/flutter/basics/store
- https://asyncredux.com/flutter/testing/testing-user-exceptions
- https://asyncredux.com/flutter/basics/wait-fail-succeed
- https://asyncredux.com/flutter/miscellaneous/logging
- https://asyncredux.com/flutter/advanced-actions/action-status
