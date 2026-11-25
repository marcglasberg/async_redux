---
name: asyncredux-provider-integration
description: Integrate selected AsyncRedux state with an existing Flutter Provider app using provider_for_redux.
---

# Use AsyncRedux with Provider

When an existing app uses Provider and needs an AsyncRedux bridge, consult
`provider_for_redux` for its `ReduxSelector` integration. Use the package's
version-specific setup and subscribe to the smallest value each widget renders.
Keep the store as the source of shared state and dispatch actions through it.

For ordinary AsyncRedux widgets, use `StoreProvider<AppState>` with the app's
typed `context.select` and `context.read` extension.

## References

- [Provider integration](https://asyncredux.com/flutter/other-packages/using-the-provider-package)
- [Using the store state](https://asyncredux.com/flutter/basics/using-the-store-state)
