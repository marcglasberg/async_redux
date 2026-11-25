---
name: asyncredux-streams-timers
description: Own AsyncRedux streams and timers in store props, dispatch updates from callbacks, and bind start/stop to the Flutter lifecycle.
---

# Manage streams and timers

Keep stream subscriptions and timers in store props, outside immutable state.
Start them in an action or store-scoped service. Each tick or received value
dispatches a fresh action that updates state. Route stream errors through the
app's error handling and ignore updates from subscriptions that are no longer current
when teardown and callbacks can overlap.

Use a stable prop key and dispose any previous resource before replacing it.
Create a stop action using `disposeProp(key)`. At store teardown, call
`store.disposeProps()` to release remaining resources. For regular server polling,
prefer the `Polling` mixin.

For a screen-scoped resource, pass start and stop callbacks already bound to the
store to a stateful widget. Invoke them from `initState` and `dispose`. This avoids
an inherited-widget lookup during disposal. Test both callbacks by pumping the
screen, then replacing it.

## References

- [Streams and timers](https://asyncredux.com/flutter/miscellaneous/streams-and-timers)
- [Testing widget lifecycle](https://asyncredux.com/flutter/testing/testing-oninit-ondispose)
- [Control mixins](https://asyncredux.com/flutter/advanced-actions/control-mixins)
