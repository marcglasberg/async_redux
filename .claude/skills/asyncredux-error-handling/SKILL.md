---
name: asyncredux-error-handling
description: Handle AsyncRedux errors locally with wrapError and centrally with globalErrorObserver, including reporting and testing.
---

# Handle and report action errors

Use `wrapError(error, stackTrace)` on an action to translate expected failures into
`UserException`, preserve an error, or intentionally swallow it by returning `null`.
Keep unexpected errors visible. When a caller should handle a failure, use the
dispatch status for handled user errors and catch only errors that can propagate to
that caller.

Pass a factory to `Store<AppState>(globalErrorObserver: ...)` that creates a fresh
`GlobalErrorObserver<AppState>` per error. In `observe()`, read `error` after local
wrapping, plus `originalError`, `stackTrace`, `action`, and `store`. The action is
nullable because persistence errors can occur outside a dispatch. Keep dispatches
out of the observer. Return `error` to preserve normal processing, a replacement
to translate it, or `null` to swallow it. Exceptions from `after` are reported
asynchronously, outside this error handling path.

This observer uses `AppState` from the setup skill.

```dart
class AppErrorObserver extends GlobalErrorObserver<AppState> {
  AppErrorObserver(this.report);
  final void Function(Object, StackTrace) report;

  @override
  Object observe() {
    if (error is! UserException && error is! AbortDispatchException) {
      report(error, stackTrace);
    }
    return error;
  }
}

Store<AppState> createObservedStore(void Function(Object, StackTrace) report) =>
    Store<AppState>(
      initialState: const AppState(),
      globalErrorObserver: (_) => AppErrorObserver(report),
    );
```

Use `UserExceptionDialog` for dialog-eligible user errors and keyed failure helpers
for inline UI. In tests, assert both `originalError` and `wrappedError` when the
translation is part of the contract.

## References

- [Errors thrown by actions](https://asyncredux.com/flutter/advanced-actions/errors-thrown-by-actions)
- [Global error observer](https://asyncredux.com/flutter/miscellaneous/error-monitoring)
