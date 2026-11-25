---
name: asyncredux-testing-wait-methods
description: Wait deterministically for AsyncRedux actions, spawned work, or state transitions in tests.
---

# Wait for deterministic test outcomes

| Outcome | Method |
| --- | --- |
| Finish the dispatched action | `dispatchAndWait(action)` |
| Finish a batch of independently dispatched actions | `dispatchAndWaitAll(actions)` |
| Reach a state condition | `waitCondition(predicate)` |
| Finish specific in-flight instances, or become idle | `waitAllActions(actions)`, using an empty list or `null` for idle |
| Finish all in-flight actions of the specified types | `waitActionType(type)` or `waitAllActionTypes(types)` |
| See a matching action finish, even if it has yet to be dispatched | `waitAnyActionTypeFinishes(types)` |
| Reach a condition over the in-flight set | `waitActionCondition((actions, triggerAction) => ...)` |

Register a wait for a future completion before triggering work that could finish
immediately. `waitCondition` accepts an already-true predicate by default and
returns `null` in that case. The in-flight waits reject an already-satisfied
condition by default. Set `completeImmediately: true` when an already-idle store
is valid. Use a bounded `timeoutMillis` for a test that waits on indirect work.

Assert the final state or relevant action status. Remove an expected queued
`UserException` with `store.removeError(status)` if the test also checks that the
queue contains no unexpected errors.

## References

- [Dispatch, wait and expect](https://asyncredux.com/flutter/testing/dispatch-wait-and-expect)
- [Testing UserExceptions](https://asyncredux.com/flutter/testing/testing-user-exceptions)
