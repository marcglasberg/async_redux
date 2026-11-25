---
name: asyncredux-debugging
description: Diagnose AsyncRedux dispatch timing, state changes, failures, and unexpected Flutter widget rebuilds.
---

# Debug AsyncRedux apps

Start with the dispatch and the exact slice of state the widget selects. Inspect
`store.state` and `store.actionsInProgress()` at the relevant point. For a known
dispatch, use `dispatchAndWait` and inspect its status and resulting state. Check
for silent aborts, a reducer returning `null`, and async reducers copying state
captured before an `await`. For failures, compare `originalError` with `wrappedError`.

Register `ConsoleActionObserver<AppState>()` in the store's `actionObservers` to
trace actions during development. `dispatchCount` helps correlate work with other logs.

When a widget rebuilds unexpectedly, inspect whether the selector returns a new
collection or a value whose equality changes each time. Inspect parent rebuilds
as well. Keep selectors pure and use Flutter's widget rebuild diagnostics to trace
the build. For missing rebuilds, verify the widget is under the intended provider
and that the selected value changes through an immutable state update.

## References

- [Logging](https://asyncredux.com/flutter/miscellaneous/logging)
- [Metrics](https://asyncredux.com/flutter/miscellaneous/metrics)
- [Using the store state](https://asyncredux.com/flutter/basics/using-the-store-state)
- [Action status](https://asyncredux.com/flutter/advanced-actions/action-status)
