---
name: asyncredux-action-status
description: Inspect one AsyncRedux action's completion, errors, or lifecycle for follow-up behavior and tests.
---

# Inspect dispatch completion

Await `dispatchAndWait` and use `status.isCompletedOk` for a follow-up that depends
on success. `isCompletedFailed` identifies a completed failure. Each `ActionStatus`
is an immutable snapshot, so read `action.status` again after waiting if you captured
it earlier. For reactive UI, use selected state and the waiting and failure helpers.

This helper uses the app base action from the setup skill.

```dart
Future<void> saveAndClose(BuildContext context, AppAction saveAction) async {
  final status = await context.dispatchAndWait(saveAction);
  if (status.isCompletedOk && context.mounted) {
    Navigator.of(context).pop();
  }
}
```

In tests, `originalError` is the error from the action and `wrappedError` is the
final error after local and global error handling. The `hasFinishedMethodBefore`,
`hasFinishedMethodReduce`, and `hasFinishedMethodAfter` flags help diagnose where
the lifecycle stopped. Unhandled errors can propagate from a dispatch.

## References

- [Action status](https://asyncredux.com/flutter/advanced-actions/action-status)
- [Testing UserExceptions](https://asyncredux.com/flutter/testing/testing-user-exceptions)
