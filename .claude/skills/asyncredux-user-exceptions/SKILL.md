---
name: asyncredux-user-exceptions
description: Create actionable user-facing AsyncRedux errors and display or test them through the error queue.
---

# Report user-facing failures

Throw a `UserException` from `before` or `reduce` for a failure the user can act on.
Let unexpected failures reach the normal error reporting path. Attach the underlying
cause with `addCause` when translating a known error. Place `UserExceptionDialog<AppState>`
inside the app near the navigator for default dialogs, or supply
`onShowUserExceptionDialog` for a custom presentation.

For an inline-only failure, use `ifOpenDialog: false` and render it with
`context.isFailed` and `context.exceptionFor`. A dialog-eligible exception enters the
store's error queue and is consumed by the dialog widget. The queue and the remembered
failure for an action serve different UI behavior.

```dart
class SetCounter extends AppAction {
  SetCounter(this.value);
  final int value;

  @override
  AppState reduce() {
    if (value < 0) {
      throw const UserException('Enter a count of zero or more.', ifOpenDialog: false);
    }
    return state.copy(counter: value);
  }
}
```

This reducer uses the setup skill's base action and state. In tests, await
`dispatchAndWait` and assert the failure plus the type and message of
`status.wrappedError`. Check `store.errors` separately when testing dialog eligibility.

## References

- [Failed actions](https://asyncredux.com/flutter/basics/failed-actions)
- [Testing UserExceptions](https://asyncredux.com/flutter/testing/testing-user-exceptions)
