---
name: asyncredux-optimistic-update-mixin
description: Apply optimistic AsyncRedux updates with OptimisticCommand, OptimisticSync, OptimisticSyncWithPush, and ServerPush.
---

# Apply optimistic updates

Choose the mixin by what the server must receive.

| Mixin | Use when |
| --- | --- |
| `OptimisticCommand` | Each accepted dispatch represents a discrete server command, such as creating or deleting an item. |
| `OptimisticSync` | Only the latest desired value matters, such as a like or setting. Intermediate values can be coalesced. |
| `OptimisticSyncWithPush` and `ServerPush` | Other clients can change the same value and the backend supplies monotonic per-key revisions. |

Implement the selected mixin's hooks in place of a custom `reduce`. For
`OptimisticCommand`, implement `optimisticValue`, `getValueFromState`,
`applyValueToState`, and `sendCommandToServer`. Override `reloadFromServer` if
needed. Use the command's key hooks for independent in-flight commands. The
default rollback restores the affected value only if it still matches what the
action applied. Preserve unrelated state in the update hook.

For `OptimisticSync`, implement `valueToApply`, `applyOptimisticValueToState`,
`getValueFromState`, `sendValueToServer`, and `applyServerResponseToState`. Return
`null` from the latter when there is no state update to apply. Scope independent writes with
`optimisticSyncKeyParams`. Use `onFinish` to define recovery for the feature and
check whether the failed value is still current before applying a rollback. For
server pushes, use matching optimistic keys and revisions in both action types
so stale acknowledgments or pushes cannot overwrite newer values.

This command uses the state and base action from the setup skill. The redemption
API redeems one credit per successful request. The mixin applies the counter update
immediately and rolls it back if the request fails and the counter is still unchanged.

```dart
class RedeemCredit extends AppAction with OptimisticCommand<AppState> {
  RedeemCredit(this.redeem);
  final Future<void> Function() redeem;

  @override
  int optimisticValue() => state.counter + 1;

  @override
  int getValueFromState(AppState state) => state.counter;

  @override
  AppState applyValueToState(AppState state, Object? value) =>
      state.copy(counter: value as int);

  @override
  Future<Object?> sendCommandToServer(Object? optimisticValue) async {
    await redeem();
    return null;
  }
}
```

Test optimistic state before the request completes, failure recovery, rapid
dispatches for the same key, and independent keys when applicable.

## References

- [Optimistic mixins](https://asyncredux.com/flutter/advanced-actions/optimistic-mixins)
- [Action mixin compatibility](https://asyncredux.com/flutter/advanced-actions/action-mixins)
