---
name: asyncredux-sync-actions
description: Implement synchronous AsyncRedux reducers for immediate, immutable state updates.
---

# Write synchronous actions

Extend the app's base action or `ReduxAction<AppState>`. Override `reduce()` with
`AppState` or `AppState?`. Use current `state` and immutable constructor arguments.
Return new state when there is a change and `null` for a no-op. A plain `dispatch`
applies a synchronous action's change before returning. Keep the full lifecycle
synchronous when callers rely on that timing.

This reducer uses the state and base action from the setup skill.

```dart
class IncrementBy extends AppAction {
  IncrementBy(this.amount);
  final int amount;

  @override
  AppState? reduce() {
    if (amount == 0) return null;
    return state.copy(counter: state.counter + amount);
  }
}
```

## References

- [Sync actions](https://asyncredux.com/flutter/basics/sync-actions)
- [Actions and reducers](https://asyncredux.com/flutter/basics/actions-and-reducers)
