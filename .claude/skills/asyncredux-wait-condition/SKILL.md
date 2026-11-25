---
name: asyncredux-wait-condition
description: Wait for an AsyncRedux state predicate in an action or test, with explicit timeout and dependency handling.
---

# Wait for a state condition

Use `waitCondition((st) => ...)` on the store or in a reducer when progress depends
on state that another action may update. The predicate receives current state and
should be pure. In reducers, await the condition, then apply updates to the current
`state`. If the awaited operation itself can be dispatched directly and fail, prefer
`dispatchAndWait` and check its status when that is the real prerequisite.

The future returns the action that met the condition, or `null` when the condition
was already true. On the store, `completeImmediately: false` is available when a
test specifically expects a transition. Pass `timeoutMillis` when a condition might
never be met. Ensure that the action producing the state can run independently of
the waiting action, especially if both use `Sequential`.

## References

- [Waiting for a certain condition](https://asyncredux.com/flutter/miscellaneous/wait-condition)
- [Dispatch, wait and expect](https://asyncredux.com/flutter/testing/dispatch-wait-and-expect)
