---
name: asyncredux-navigation
description: Use and test AsyncRedux NavigateAction in Flutter Navigator 1 apps.
---

# Navigate with AsyncRedux

`NavigateAction<AppState>` is optional support for Flutter's imperative Navigator.
Create one `GlobalKey<NavigatorState>` at startup, pass it to
`NavigateAction.setNavigatorKey`, and give the same key to `MaterialApp.navigatorKey`.
Configure the routes using the app's existing routing setup. Dispatch a typed action
such as `NavigateAction<AppState>.pushNamed('/details')` when app logic owns the
navigation.

Widgets can navigate directly with the app's router or `Navigator`. After an
awaited dispatch, verify success and `context.mounted` before navigating with the
context. Use `NavigateAction.getCurrentNavigatorRouteName(context)` when you need
the name of an imperative navigator route.

In a unit test, capture the action through an observer or a `MockStore` replacement
and assert its type and route details. Use a widget test with a navigator to verify
the route actually opens.

## References

- [Navigation](https://asyncredux.com/flutter/miscellaneous/navigation)
- [Testing navigation](https://asyncredux.com/flutter/testing/testing-navigation)
