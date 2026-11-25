---
name: asyncredux-async-actions
description: Implement AsyncRedux reducers that await I/O and apply their result to current state safely.
---

# Write asynchronous actions

Override `reduce()` with `Future<AppState?>`, or `Future<AppState>` when every
successful path returns state. Each path returning non-null state must execute an
`await` in the reducer itself. A path returning `null` may exit immediately. Use a
synchronous reducer for sync work. If an asynchronous reducer needs to return state on
a path with no I/O, use `await microtask` on that path. The
[AsyncRedux analyzer plugin](https://pub.dev/packages/async_redux_lints#reduce_without_await)
checks this rule.

After each `await`, `state` may contain changes from other actions. Apply your update
to the current state. Use `initialState` for the state at dispatch time. If an operation
can become obsolete while awaiting, check that its result still belongs to the current
account, item, or request.

This reducer uses the state and base action from the setup skill.

```dart
class FetchAndIncrement extends AppAction {
  FetchAndIncrement(this.fetchAmount);
  final Future<int> Function() fetchAmount;

  @override
  Future<AppState?> reduce() async {
    final amount = await fetchAmount();
    if (amount == 0) return null;
    return state.copy(counter: state.counter + amount);
  }
}
```

## References

- [Async actions](https://asyncredux.com/flutter/basics/async-actions)
- [ReduxAction](https://asyncredux.com/flutter/advanced-actions/redux-action)
