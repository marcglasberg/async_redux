---
name: asyncredux-flutter-hooks
description: Subscribe to AsyncRedux state in an existing flutter_hooks app using flutter_hooks_async_redux.
---

# Select state with Flutter Hooks

For an app already using `HookWidget` and Flutter Hooks, use the
`useSelector<T, AppState>` hook from `flutter_hooks_async_redux` to subscribe
to a portion of the store. Call it unconditionally during build, following hook
ordering rules. A typed app hook can fix `AppState` and forward the selector
and `distinct` option. Use pure selectors and select only what the widget renders.

Keep action dispatch in callbacks. Standard AsyncRedux widgets can use the typed
`context.select` and `context.read` extension without integrating a hooks package.

## References

- [flutter_hooks integration](https://asyncredux.com/flutter/other-packages/using-flutter-hooks-package)
- [Using the store state](https://asyncredux.com/flutter/basics/using-the-store-state)
