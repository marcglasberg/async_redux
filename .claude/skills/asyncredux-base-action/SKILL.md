---
name: asyncredux-base-action
description: Create a custom base action class for your app. Covers adding getter shortcuts to state parts, adding selector methods, implementing shared wrapError logic, and establishing project-wide action conventions.
---

# Creating a Custom Base Action Class

Every AsyncRedux application should define an abstract base action class that all actions extend. This provides a central place for:
- Convenient getter shortcuts to state parts
- Selector methods for common queries
- Shared error handling logic
- Type-safe environment access
- Project-wide conventions

## Basic Base Action Setup

Create an abstract class extending `ReduxAction<AppState>`:

```dart
abstract class AppAction extends ReduxAction<AppState> {
  // All your actions will extend this class
}
```

Then extend `AppAction` instead of `ReduxAction<AppState>` in all your actions:

```dart
class IncrementCounter extends AppAction {
  @override
  AppState reduce() => state.copy(counter: state.counter + 1);
}
```

## Adding Getter Shortcuts to State Parts

When your state has nested objects, add getters to simplify access:

```dart
abstract class AppAction extends ReduxAction<AppState> {
  // Shortcuts to nested state parts
  User get user => state.user;
  Settings get settings => state.settings;
  IList<Todo> get todos => state.todos;
  Cart get cart => state.cart;
}
```

Now actions can write cleaner code:

```dart
class UpdateUserName extends AppAction {
  final String name;
  UpdateUserName(this.name);

  @override
  AppState reduce() {
    // Instead of: state.user.name
    // You can write: user.name
    return state.copy(user: user.copy(name: name));
  }
}
```

## Adding Selector Methods

For common data lookups, add selector methods directly to your base action:

```dart
abstract class AppAction extends ReduxAction<AppState> {
  // Getters for state parts
  User get user => state.user;
  IList<Item> get items => state.items;

  // Selector methods
  Item? findItemById(String id) =>
      items.firstWhereOrNull((item) => item.id == id);

  List<Item> get completedItems =>
      items.where((item) => item.isCompleted).toList();

  bool get isLoggedIn => user.isAuthenticated;
}
```

Actions can then use these selectors:

```dart
class MarkItemComplete extends AppAction {
  final String itemId;
  MarkItemComplete(this.itemId);

  @override
  AppState reduce() {
    final item = findItemById(itemId);
    if (item == null) return null; // No change

    return state.copy(
      items: items.replaceFirstWhere(
        (i) => i.id == itemId,
        item.copy(isCompleted: true),
      ),
    );
  }
}
```

### Using a Separate Selector Class

For larger applications, use a dedicated selector class to keep the base action clean:

```dart
class ActionSelect {
  final AppState state;
  ActionSelect(this.state);

  Item? findById(String id) =>
      state.items.firstWhereOrNull((item) => item.id == id);

  List<Item> get completed =>
      state.items.where((item) => item.isCompleted).toList();

  List<Item> get pending =>
      state.items.where((item) => !item.isCompleted).toList();
}

abstract class AppAction extends ReduxAction<AppState> {
  ActionSelect get select => ActionSelect(state);
}
```

This namespaces selectors under `select`, enabling IDE autocompletion:

```dart
class ProcessItem extends AppAction {
  final String itemId;
  ProcessItem(this.itemId);

  @override
  AppState reduce() {
    // IDE autocomplete shows: select.findById, select.completed, etc.
    final item = select.findById(itemId);
    // ...
  }
}
```

## Implementing Shared wrapError Logic

Override `wrapError()` in your base action to provide consistent error handling:

```dart
abstract class AppAction extends ReduxAction<AppState> {

  @override
  Object? wrapError(Object error, StackTrace stackTrace) {
    // Log all errors
    print('Action ${runtimeType} failed: $error');

    // Convert specific errors to user-friendly messages
    if (error is SocketException) {
      return UserException('Network error. Please check your connection.')
          .addCause(error);
    }

    if (error is TimeoutException) {
      return UserException('Request timed out. Please try again.')
          .addCause(error);
    }

    // Pass through other errors unchanged
    return error;
  }
}
```

Individual actions can still override `wrapError()` for action-specific handling:

```dart
class SubmitPayment extends AppAction {
  @override
  Future<AppState?> reduce() async {
    await paymentService.process();
    return state.copy(paymentComplete: true);
  }

  @override
  Object? wrapError(Object error, StackTrace stackTrace) {
    // Handle payment-specific errors
    if (error is PaymentDeclinedException) {
      return UserException('Payment was declined. Please try another card.')
          .addCause(error);
    }
    // Fall back to base class handling
    return super.wrapError(error, stackTrace);
  }
}
```

### Creating Error Handling Mixins

For reusable error patterns, create mixins:

```dart
mixin ShowUserException on AppAction {
  /// Override in actions to provide the error message
  String getErrorMessage();

  @override
  Object? wrapError(Object error, StackTrace stackTrace) =>
      UserException(getErrorMessage()).addCause(error);
}

class ConvertNumber extends AppAction with ShowUserException {
  final String text;
  ConvertNumber(this.text);

  @override
  String getErrorMessage() => 'Please enter a valid number.';

  @override
  AppState reduce() => state.copy(number: int.parse(text));
}
```

## Type-Safe Environment Access

For dependency injection, override the `env` getter in your base action:

```dart
class Environment {
  final ApiClient api;
  final AuthService auth;
  final AnalyticsService analytics;

  Environment({
    required this.api,
    required this.auth,
    required this.analytics,
  });
}

abstract class AppAction extends ReduxAction<AppState> {
  // Type-safe access to environment
  @override
  Environment get env => super.env as Environment;

  // Convenience getters for common services
  ApiClient get api => env.api;
  AuthService get auth => env.auth;
}
```

Actions can then use services directly:

```dart
class FetchUserProfile extends AppAction {
  @override
  Future<AppState?> reduce() async {
    // Uses the api getter from base action
    final profile = await api.getUserProfile();
    return state.copy(user: profile);
  }
}
```

## Complete Base Action Example

Here's a comprehensive base action class:

```dart
abstract class AppAction extends ReduxAction<AppState> {
  // ========== Type-safe environment access ==========
  @override
  Environment get env => super.env as Environment;

  ApiClient get api => env.api;
  AuthService get auth => env.auth;

  // ========== State part getters ==========
  User get user => state.user;
  Settings get settings => state.settings;
  IList<Item> get items => state.items;

  // ========== Selector methods ==========
  Item? findItemById(String id) =>
      items.firstWhereOrNull((item) => item.id == id);

  bool get isLoggedIn => user.isAuthenticated;

  // ========== Shared error handling ==========
  @override
  Object? wrapError(Object error, StackTrace stackTrace) {
    // Log errors for debugging
    print('[${runtimeType}] Error: $error');

    // Convert network errors to user-friendly messages
    if (error is SocketException) {
      return UserException('Network error. Check your connection.')
          .addCause(error);
    }

    if (error is TimeoutException) {
      return UserException('Request timed out. Try again.')
          .addCause(error);
    }

    return error;
  }
}
```

## Using the Base Action

All actions in your app extend `AppAction`:

```dart
class LoadItems extends AppAction {
  @override
  Future<AppState?> reduce() async {
    // Uses api from base action
    final fetchedItems = await api.getItems();

    return state.copy(items: fetchedItems.toIList());
  }
}

class DeleteItem extends AppAction {
  final String itemId;
  DeleteItem(this.itemId);

  @override
  Future<AppState?> reduce() async {
    // Uses findItemById selector from base action
    final item = findItemById(itemId);
    if (item == null) return null;

    await api.deleteItem(itemId);
    return state.copy(
      items: items.removeWhere((i) => i.id == itemId),
    );
  }
}
```

## References

URLs from the documentation:
- https://asyncredux.com/flutter/advanced-actions/redux-action
- https://asyncredux.com/flutter/advanced-actions/action-selectors
- https://asyncredux.com/flutter/advanced-actions/errors-thrown-by-actions
- https://asyncredux.com/flutter/advanced-actions/wrapping-the-reducer
- https://asyncredux.com/flutter/advanced-actions/action-mixins
- https://asyncredux.com/flutter/advanced-actions/aborting-the-dispatch
- https://asyncredux.com/flutter/basics/actions-and-reducers
- https://asyncredux.com/flutter/basics/state
- https://asyncredux.com/flutter/basics/using-the-store-state
- https://asyncredux.com/flutter/miscellaneous/business-logic
- https://asyncredux.com/flutter/miscellaneous/dependency-injection
