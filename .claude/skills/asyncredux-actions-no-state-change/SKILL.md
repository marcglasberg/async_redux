---
name: asyncredux-actions-no-state-change
description: Implement AsyncRedux actions that coordinate other actions, perform side effects, or leave state unchanged.
---

# Return no state change

Return `null` to leave state unchanged. Use a reducer returning `AppState?` for
synchronous work or `Future<AppState?>` when the action must await work. An action
can still update state indirectly by dispatching other actions.

Use `dispatchAndWait` when a caller needs the parent action to finish after a child.
A child `UserException` can produce a failed status without throwing to the parent,
so check that status before dependent work. Use `dispatchAll` for independent child
actions that may keep running.

This action uses the base class from the setup skill.

```dart
class FlushDrafts extends AppAction {
  FlushDrafts(this.flush);
  final Future<void> Function() flush;

  @override
  Future<AppState?> reduce() async {
    await flush();
    return null;
  }
}
```

## References

- [Changing state is optional](https://asyncredux.com/flutter/basics/changing-state-is-optional)
- [Dispatching actions](https://asyncredux.com/flutter/basics/dispatching-actions)
