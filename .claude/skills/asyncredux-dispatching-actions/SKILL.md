---
name: asyncredux-dispatching-actions
description: Dispatch AsyncRedux actions from widgets, the store, and reducers. Choose immediate, awaited, parallel, or synchronous dispatch.
---

# Dispatch actions

Use `context.dispatch(action)` in widget callbacks, `store.dispatch(action)` outside
widgets, and `dispatch(action)` inside actions. Construct a fresh action per dispatch.

| Method | Use when |
| --- | --- |
| `dispatch` | Start work and let the UI react to selected state. Sync actions apply changes immediately. |
| `dispatchAndWait` | Wait for one action to finish, then read state or use its `ActionStatus`. |
| `dispatchAll` | Start independent actions without waiting. Returns the dispatched actions. |
| `dispatchAndWaitAll` | Start independent actions and wait for all. Inspect `action.status` on the returned actions if success matters. |
| `dispatchSync` | Require a synchronous action. AsyncRedux throws if the action is asynchronous. |

Await each `dispatchAndWait` separately for ordered work. Check `isCompletedOk` when
the next step requires success. Completion can occur without a state change. Check
`context.mounted` before using a widget's context after an await. With multiple
providers, dispatch through the local context. Leave `notify` at its default unless you
intend to suppress store-driven notifications for that dispatch.

## References

- [Dispatching actions](https://asyncredux.com/flutter/basics/dispatching-actions)
- [Action status](https://asyncredux.com/flutter/advanced-actions/action-status)
