---
name: asyncredux-base-action
description: Define an app-specific AsyncRedux base action for shared type-safe select helpers or dependencies.
---

# Define an app base action

An abstract `AppAction extends ReduxAction<AppState>` lets concrete actions use the
app's state type without repeating it. Reuse the app's existing base class. Add typed
getters for shared dependencies and pure selectors that several actions use. Keep
feature-specific rules in feature state classes or actions.

A selector exposed by the base action should read current `state` each time. After
an `await`, a previously captured state or selector instance still points to the earlier
snapshot. Put shared error and lifecycle overrides in the base class only when they
apply to all actions. Use a mixin for behavior actions opt into.

## References

- [Action simplification](https://asyncredux.com/flutter/basics/action-simplification)
- [Action selectors](https://asyncredux.com/flutter/advanced-actions/action-selectors)
- [Dependency injection](https://asyncredux.com/flutter/miscellaneous/dependency-injection)
