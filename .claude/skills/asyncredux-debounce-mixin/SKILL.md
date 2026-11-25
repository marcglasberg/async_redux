---
name: asyncredux-debounce-mixin
description: Delay AsyncRedux actions until input settles, including per-field debounce keys and protection against stale results.
---

# Debounce rapid dispatches

Use `Debounce` for search input or validation that should run after a quiet period.
Dispatch a new action from the input callback. Override `int get debounce` for the
delay in milliseconds (default 333). The default lock is the action type. Override
`lockBuilder()` with an immutable key such as `(runtimeType, fieldId)` for independent
inputs.

Debounce supersedes actions still waiting for their quiet period. A reducer that has
already started may finish after new input arrives. For remote search, keep the current
query or request ID and check it after the await before applying results. Use
`Throttle` when the first dispatch should run immediately and later dispatches within
the interval should be dropped.

## References

- [Control mixins](https://asyncredux.com/flutter/advanced-actions/control-mixins)
- [Action mixin compatibility](https://asyncredux.com/flutter/advanced-actions/action-mixins)
