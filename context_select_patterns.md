# Extension Patterns for AsyncRedux `getSelect`

This guide demonstrates different extension patterns you can use with
AsyncRedux's `context.select()` method to create clean, type-safe selectors in
your Flutter apps.

## Table of Contents

- [Pattern 1: Basic Extension (Recommended Minimum)](#pattern-1-basic-extension-recommended-minimum)
- [Pattern 2: Type-Specific Selectors](#pattern-2-type-specific-selectors-for-better-intellisense)
- [Pattern 3: Domain-Specific Selectors](#pattern-3-domain-specific-selectors-for-complex-apps)
- [Pattern 4: Combined Selectors for Complex State](#pattern-4-combined-selectors-for-complex-state)
- [Pattern 5: Nullable State Handling](#pattern-5-nullable-state-handling)
- [Recommendations](#recommendations)

## Example App State

All patterns below assume the following app state structure:

```dart
import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';

// Your app state
class AppState {
  final User user;
  final List<Product> products;
  final Cart cart;
  final Settings settings;

  AppState({
    required this.user,
    required this.products,
    required this.cart,
    required this.settings,
  });
}

class User {
  final String name;
  final int age;
  final bool isPremium;

  User({required this.name, required this.age, required this.isPremium});
}

class Product {
  final String id;
  final String name;
  final double price;

  Product({required this.id, required this.name, required this.price});
}

class Cart {
  final List<Product> items;

  Cart({required this.items});
}

class Settings {
  final bool darkMode;
  final String language;

  Settings({required this.darkMode, required this.language});
}
```

---

## Pattern 1: Basic Extension (Recommended Minimum)

This is the **recommended** starting point for most apps. It provides a clean,
simple API with full type inference.

### Extension Definition

```dart
extension BuildContextExtension on BuildContext {
  AppState get state => getState<AppState>();
  AppState read() => getRead<AppState>();
  R select<R>(R Function(AppState state) selector) => getSelect<AppState, R>(selector);
}
```

### Usage Example

```dart
class BasicExample extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Clean and simple - types are inferred!
    final userName = context.select((st) => st.user.name);
    final userAge = context.select((st) => st.user.age);
    final isPremium = context.select((st) => st.user.isPremium);

    return Column(
      children: [
        Text('Name: $userName'),
        Text('Age: $userAge'),
        Text('Premium: $isPremium'),
      ],
    );
  }
}
```

### Benefits

- Simple and clean API
- Full type inference - no need to specify types repeatedly
- Minimal boilerplate
- Access to full state via `context.state` when needed

---

## Pattern 2: Type-Specific Selectors (For Better IntelliSense)

Add type-specific methods for common types to get better IDE autocomplete and
type safety.

### Extension Definition

```dart
extension TypedContextExtension on BuildContext {
  AppState get state => getState<AppState>();

  R _select<R>(R Function(AppState state) selector) =>
      getSelect<AppState, R>(selector);

  // Type-specific methods for common types
  String selectString(String Function(AppState state) selector) =>
      _select(selector);

  int selectInt(int Function(AppState state) selector) => _select(selector);

  bool selectBool(bool Function(AppState state) selector) => _select(selector);

  double selectDouble(double Function(AppState state) selector) =>
      _select(selector);

  List<T> selectList<T>(List<T> Function(AppState state) selector) =>
      _select(selector);

  Map<K, V> selectMap<K, V>(Map<K, V> Function(AppState state) selector) =>
      _select(selector);
}
```

### Usage Example

```dart
class TypedExample extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Explicit type methods can help with IDE autocomplete
    final userName = context.selectString((state) => state.user.name);
    final userAge = context.selectInt((state) => state.user.age);
    final isPremium = context.selectBool((state) => state.user.isPremium);
    final prices = context.selectList<double>(
      (state) => state.products.map((p) => p.price).toList(),
    );

    return Column(
      children: [
        Text('Name: $userName'),
        Text('Age: $userAge'),
        Text('Premium: $isPremium'),
        Text('Prices: ${prices.join(', ')}'),
      ],
    );
  }
}
```

### Benefits

- Better IDE autocomplete
- Explicit type declarations can help with complex nested types
- Still maintains type safety

---

## Pattern 3: Domain-Specific Selectors (For Complex Apps)

Create domain-specific getters for commonly accessed data. This is ideal for
large apps with many screens that repeatedly access the same state slices.

### Extension Definition

```dart
extension DomainContextExtension on BuildContext {
  AppState get state => getState<AppState>();

  R _select<R>(R Function(AppState state) selector) =>
      getSelect<AppState, R>(selector);

  // User-specific selectors
  User get user => _select((state) => state.user);

  String get userName => _select((state) => state.user.name);

  int get userAge => _select((state) => state.user.age);

  bool get isPremiumUser => _select((state) => state.user.isPremium);

  // Cart-specific selectors
  List<Product> get cartItems => _select((state) => state.cart.items);

  int get cartItemCount => _select((state) => state.cart.items.length);

  double get cartTotal => _select(
        (state) => state.cart.items.fold(0.0, (sum, item) => sum + item.price),
      );

  // Settings-specific selectors
  bool get isDarkMode => _select((state) => state.settings.darkMode);

  String get appLanguage => _select((state) => state.settings.language);

  // Computed selectors
  bool get hasItemsInCart => _select((state) => state.cart.items.isNotEmpty);

  bool get isEligibleForFreeShipping => _select(
        (state) =>
            state.cart.items.fold(0.0, (sum, item) => sum + item.price) > 50,
      );
}
```

### Usage Example

```dart
class DomainExample extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Super clean - like accessing properties!
    return Column(
      children: [
        Text('User: ${context.userName}'),
        Text('Age: ${context.userAge}'),
        Text('Premium: ${context.isPremiumUser}'),
        Text('Cart Items: ${context.cartItemCount}'),
        Text('Cart Total: \$${context.cartTotal}'),
        Text('Dark Mode: ${context.isDarkMode}'),
        if (context.hasItemsInCart)
          Text('Free Shipping: ${context.isEligibleForFreeShipping}'),
      ],
    );
  }
}
```

### Benefits

- Extremely clean usage - reads like natural properties
- Encapsulates complex selector logic
- Great for large apps with repeated access patterns
- Centralizes state access logic

---

## Pattern 4: Combined Selectors for Complex State

Use records or view models to select multiple related values at once, reducing
the number of selector calls.

### Extension Definition

```dart
extension CombinedContextExtension on BuildContext {
  R _select<R>(R Function(AppState state) selector) =>
      getSelect<AppState, R>(selector);

  // Select multiple related values at once using records
  ({String name, int age, bool isPremium}) get userInfo => _select(
        (state) => (
          name: state.user.name,
          age: state.user.age,
          isPremium: state.user.isPremium,
        ),
      );

  // Select computed view models
  CartSummary get cartSummary => _select(
        (state) => CartSummary(
          itemCount: state.cart.items.length,
          total: state.cart.items.fold(0.0, (sum, item) => sum + item.price),
          isEmpty: state.cart.items.isEmpty,
        ),
      );
}

class CartSummary {
  final int itemCount;
  final double total;
  final bool isEmpty;

  CartSummary({
    required this.itemCount,
    required this.total,
    required this.isEmpty,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartSummary &&
          itemCount == other.itemCount &&
          total == other.total &&
          isEmpty == other.isEmpty;

  @override
  int get hashCode => Object.hash(itemCount, total, isEmpty);
}
```

### Usage Example

```dart
class CombinedExample extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Get multiple values with one selector
    final user = context.userInfo;
    final cart = context.cartSummary;

    return Column(
      children: [
        Text('User: ${user.name}, ${user.age} years old'),
        Text('Premium: ${user.isPremium}'),
        Text('Cart: ${cart.itemCount} items, \$${cart.total}'),
        if (cart.isEmpty) Text('Your cart is empty'),
      ],
    );
  }
}
```

### Benefits

- Reduces number of selector calls
- Groups related data logically
- View models can encapsulate complex computations
- Better performance when multiple values change together

### Important Note

Remember to implement `==` and `hashCode` for view model classes to ensure
proper change detection and prevent unnecessary rebuilds.

---

## Pattern 5: Nullable State Handling

Handle optional or nullable state gracefully with default values and safe
selectors.

### Extension Definition

```dart
extension NullableContextExtension on BuildContext {
  R _select<R>(R Function(AppState state) selector) =>
      getSelect<AppState, R>(selector);

  // Safe selectors with default values
  String selectUserName({String defaultValue = 'Guest'}) => _select(
      (state) => state.user.name.isEmpty ? defaultValue : state.user.name);

  int selectUserAge({int defaultValue = 0}) =>
      _select((state) => state.user.age > 0 ? state.user.age : defaultValue);

  // Optional selectors
  T? selectOptional<T>(T? Function(AppState state) selector) =>
      _select(selector);
}
```

### Usage Example

```dart
class NullableExample extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Get values with fallbacks
    final userName = context.selectUserName(defaultValue: 'Anonymous');
    final userAge = context.selectUserAge(defaultValue: 18);

    return Column(
      children: [
        Text('Name: $userName'),
        Text('Age: $userAge'),
      ],
    );
  }
}
```

### Benefits

- Gracefully handles missing or empty data
- Provides sensible defaults
- Reduces null checks in UI code

---

## Recommendations

### 1. Start Simple

Use **Pattern 1** (Basic Extension) for most apps:

```dart
extension BuildContextExtension on BuildContext {
  AppState get state => getState<AppState>();

  R select<R>(R Function(AppState state) selector) =>
      getSelect<AppState, R>(selector);
}
```

This gives you:

- `context.state` for full state access
- `context.select((state) => ...)` with automatic type inference
- No need to specify AppState or return type repeatedly

### 2. Add Type-Specific Methods

If you find yourself repeatedly selecting the same types and want better IDE
support, add typed methods (Pattern 2).

### 3. Domain Methods for Large Apps

For complex apps with many screens, create domain-specific getters (Pattern 3)
for commonly accessed data. This makes your code more readable and maintainable.

### 4. Performance Tips

- The selector function is called on every state change to check if a rebuild is
  needed
- Keep selectors simple and fast
- For expensive computations, consider caching/memoization
- Avoid creating new objects in selectors unless necessary (or implement proper
  `==` and `hashCode`)

### 5. Testing

Extensions make testing easier:

- You can mock the context
- Create test-specific extensions
- Selectors are pure functions that are easy to test

### 6. Combining Patterns

You can combine multiple patterns in a single extension:

```dart
extension AppContextExtension on BuildContext {
  AppState get state => getState<AppState>();

  // Pattern 1: Generic selector
  R select<R>(R Function(AppState state) selector) =>
      getSelect<AppState, R>(selector);

  // Pattern 3: Domain-specific selectors for common use cases
  String get userName => select((state) => state.user.name);
  int get cartItemCount => select((state) => state.cart.items.length);
}
```

This provides both flexibility and convenience where you need it most.
