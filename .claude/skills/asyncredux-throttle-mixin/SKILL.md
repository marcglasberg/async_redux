---
name: asyncredux-throttle-mixin
description: Limit how often an AsyncRedux action starts, including per-entity throttle locks and manual refresh.
---

# Throttle rapid dispatches

`Throttle` admits the first dispatch immediately and silently skips further dispatches
within its interval. Override `int get throttle` to set milliseconds (default 1000).
The default lock is the action type. Override `lockBuilder()` with an immutable key
such as `(runtimeType, itemId)` to throttle each entity independently.

Override `ignoreThrottle` for a deliberate forced refresh. A failure keeps the lock
by default. Set `removeLockOnError` to true if a failure should allow immediate retry.
`removeLock()` and `removeAllLocks()` clear one lock or all throttle locks in the store.
If the goal is to prevent overlapping runs, use `NonReentrant` on its own. Use
`Fresh` for data freshness and `Debounce` for waiting until input settles.

## References

- [Control mixins](https://asyncredux.com/flutter/advanced-actions/control-mixins)
- [Action mixin compatibility](https://asyncredux.com/flutter/advanced-actions/action-mixins)
