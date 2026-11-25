---
name: asyncredux-abort-dispatch
description: Silently skip a dispatch with AsyncRedux abortDispatch when an action's precondition already rules it out.
---

# Abort a dispatch

Use `abortDispatch()` for a synchronous guard when the action should be skipped
silently. Returning `true` bypasses `before`, `reduce`, and `after`. Keep the predicate
free of side effects. If the action can run but has nothing to change, return `null`
from its reducer. If the user should be told why it cannot run, use a
`UserException` in `before`. Use `NonReentrant` for duplicate in-flight actions.

When an action or mixin already supplies an abort guard, preserve it by calling
`super.abortDispatch()`. An asynchronous guard belongs in `before`. An
`AbortDispatchException` there aborts silently, while lifecycle cleanup still runs.

## References

- [Aborting the dispatch](https://asyncredux.com/flutter/advanced-actions/aborting-the-dispatch)
- [Internet mixins](https://asyncredux.com/flutter/advanced-actions/internet-mixins)
