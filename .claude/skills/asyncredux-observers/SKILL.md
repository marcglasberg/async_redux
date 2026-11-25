---
name: asyncredux-observers
description: Observe AsyncRedux action lifecycles and state transitions for logging and metrics.
---

# Observe actions and state changes

Register typed observers on the store at creation.

- `ActionObserver<AppState>` sees the start and end of dispatch. Implement
  `observe(ReduxAction<AppState> action, int dispatchCount, {required bool ini})`.
  Use `ini` to distinguish start and finish. Use `ConsoleActionObserver` for
  console tracing.
- `StateObserver<AppState>` receives the action, previous state, proposed or
  resulting state, error, and dispatch count. Check the error and compare the
  relevant slice before recording a change. Use this for state-change logging and
  metrics tied to a transition.
- Use `globalErrorObserver` on the store for centralized reporting, error
  translation, and persistence errors.

Keep observer work small and avoid exceptions from observer callbacks. Log only
the fields needed for diagnosis.

## References

- [Logging](https://asyncredux.com/flutter/miscellaneous/logging)
- [Metrics](https://asyncredux.com/flutter/miscellaneous/metrics)
- [Error monitoring](https://asyncredux.com/flutter/miscellaneous/error-monitoring)
