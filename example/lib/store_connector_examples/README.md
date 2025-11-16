# StoreConnector Examples

This directory contains examples of how to use the `StoreConnector` widget from
the AsyncRedux package.

The `StoreConnector` widget is used to connect your Flutter widgets to the
Redux store, allowing them to access the state and dispatch actions.

It's generally not necessary to use the `StoreConnector` widget directly, as
`AsyncRedux` allows you to use the extensions `context.state`,
`context.select()`, `context.read()`, `context.dispatch()`, etc.

However, the `StoreConnector` allows you to completely separate the
presentation layer from the business logic, including the selection of
the part of the state that the widget needs. This can make your code
more modular and easier to maintain.

When should you use the `StoreConnector`?

* When you want to create a reusable widget that is not coupled to AsyncRedux
  and the Redux store.

* When you want to test the presentation layer of your app in isolation, without
  needing to set up the Redux store.

* When the selection of the state is complex, and you want to encapsulate it in
  a separate class (ViewModel).

A good rule of thumb is to start with using `context.state`, `context.select()`,
`context.dispatch()`, etc. and only switch to using the `StoreConnector` when
you find a specific need for it.

## Code examples:

The code below uses "context extensions" directly in the widget
(no smart/dumb widget separation):

```dart
// Dumb widget (Uses Context extensions)
class MyHomePageContent extends StatelessWidget {
  ...
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Counter: ${context.select((AppState state) => state.counter)}'),
        if (context.isWaiting([IncrementAction, MultiplyAction])) CircularProgressIndicator(),
        Row(
          children: [
            ElevatedButton(
              onPressed: () => context.dispatch(IncrementAction()),
              child: Text('Increment')
            ),
            ElevatedButton(
              onPressed: () => context.dispatch(MultiplyAction()),
              child: Text('Multiply')
            ),
          ],
        ),
      ],
    );
```

The code below is equivalent.
It uses "context extensions" and also smart/dumb widget separation:

```dart
// Smart widget (Uses Context extensions)
return MyHomePageContent(
   title: 'IsWaiting multiple actions',
   counter: context.select((state) => state.counter),
   isCalculating: context.isWaiting([IncrementAction, MultiplyAction]),
   increment: () => context.dispatch(IncrementAction()),
   multiply: () => context.dispatch(MultiplyAction()),
);

// Dumb widget (no direct Redux usage)
class MyHomePageContent extends StatelessWidget {
  ...
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Counter: $counter'),
        if (isCalculating) CircularProgressIndicator(),
        Row(          
          children: [
            ElevatedButton(onPressed: increment, child: Text('Increment')),            
            ElevatedButton(onPressed: multiply, child: Text('Multiply')),
            ...
```

The code below is equivalent.
It uses StoreConnector, Factory, View Model,
and also smart/dumb widget separation:

```
// Smart widget (Uses StoreConnector/Factory/Vm)
Widget build(BuildContext context) {
  return StoreConnector<AppState, CounterVm>(
    vm: () => CounterVmFactory(), // Here, uses the factory defined below.
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

class CounterVmFactory extends VmFactory<AppState, MyHomePage, CounterVm> {
  CounterVm fromStore() => CounterVm( // Here, uses the view model defined below.
    counter: state.counter,
    isCalculating: isWaiting([IncrementAction, MultiplyAction]),
    increment: () => dispatch(IncrementAction()),
    multiply: () => dispatch(MultiplyAction()),
  );
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

// Dumb widget (no direct Redux usage)
class MyHomePageContent extends StatelessWidget {
  ...
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Counter: $counter'),
        if (isCalculating) CircularProgressIndicator(),
        Row(          
          children: [
            ElevatedButton(onPressed: increment, child: Text('Increment')),            
            ElevatedButton(onPressed: multiply, child: Text('Multiply')),
            ...  
```

## The difference between the 3 approaches

### Approach 1: Context Extensions (No Separation)

Uses context extensions directly in the widget without any smart/dumb widget
separation. All logic and presentation are in one place.

### Approach 2: Context Extensions (With Smart/Dumb Separation)

Uses context extensions in a "smart" container widget that passes data and
callbacks to a "dumb" presentational widget.

### Approach 3: StoreConnector with VmFactory

Uses StoreConnector, VmFactory, and ViewModels with smart/dumb widget separation
for maximum decoupling.

## Key Differences:

### 1. Boilerplate & Complexity

- **Approach 1 (Direct Context Extensions)**: Minimal boilerplate, everything
  inline. Simplest to write and understand initially.
- **Approach 2 (Context Extensions + Separation)**: Moderate boilerplate,
  requires defining props for the dumb widget.
- **Approach 3 (StoreConnector)**: Most boilerplate, requires 3 additional
  classes (`CounterVm`, `CounterVmFactory`, and using `StoreConnector`).

### 2. Where Business Logic Lives

- **Approach 1**: Business logic (selectors, dispatches) mixed directly with UI
  code in the build method.
- **Approach 2**: Business logic in the smart widget, but still uses context
  extensions directly.
- **Approach 3**: Business logic fully encapsulated in `VmFactory.fromStore()`
  with no direct Redux dependencies in widgets.

### 3. Separation of Concerns

- **Approach 1**: No separation - Redux awareness and UI are completely
  intertwined.
- **Approach 2**: Partial separation - UI is isolated in dumb widget, but smart
  widget still directly uses Redux.
- **Approach 3**: Full separation - Complete decoupling through ViewModel
  abstraction.

### 4. Reusability

- **Approach 1**: Widget is tightly coupled to Redux store structure. Hard to
  reuse or test without full Redux setup.
- **Approach 2**: Dumb widget is reusable with any data source. Smart widget
  still tied to Redux.
- **Approach 3**: Both dumb widget and ViewModel pattern are highly reusable.
  VmFactory can be shared across multiple widgets.

### 5. Testing Strategy

- **Approach 1**: Requires full Redux store setup to test. Cannot test UI in
  isolation.
- **Approach 2**: Can test dumb widget with simple props. Smart widget still
  needs Redux for testing.
- **Approach 3**: Can test dumb widget with props, and separately unit test
  VmFactory business logic without UI.

### 6. Refactoring & Maintenance

- **Approach 1**: Changes to store structure require updates throughout the
  widget. Hard to track all dependencies.
- **Approach 2**: Store changes only affect smart widget. Dumb widget remains
  stable.
- **Approach 3**: Store changes isolated to VmFactory. Both widgets and
  ViewModel interface can remain stable.

## Recommendations:

### Use Approach 1 (Direct Context Extensions) when:

- You're building simple widgets or prototypes
- The widget is used in only one place
- Testing the full widget with Redux is acceptable
- You want minimal boilerplate and fastest development

### Use Approach 2 (Context Extensions + Smart/Dumb) when:

- You want better testability without full ViewModel complexity
- The UI component might be reused with different data
- You prefer a balance between simplicity and separation
- Your team is familiar with Redux but wants cleaner components

### Use Approach 3 (StoreConnector/VmFactory) when:

- You have complex business logic requiring isolated testing
- Multiple widgets need the same state transformations
- You want complete decoupling and maximum testability
- You're building large, team-based applications
- You need to enforce consistent architectural patterns

### General Guidelines:

The "dumb widget" pattern (used in Approaches 2 & 3) is valuable because:

1. It makes widgets easily testable without store
2. It makes the UI reusable with different data sources
3. It clearly shows the widget's API (what data it needs)

Start with Approach 1 for simplicity, then refactor to Approach 2 or 3 as your
needs grow. The transition path is natural:

- **1 → 2**: Extract props to create a dumb widget
- **2 → 3**: Replace context extensions with StoreConnector and VmFactory
