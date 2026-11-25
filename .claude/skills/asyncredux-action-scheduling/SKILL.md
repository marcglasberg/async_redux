---
name: asyncredux-action-scheduling
description: Use AsyncRedux Fresh, Polling, and Sequential for freshness windows, periodic actions, and FIFO execution.
---

# Schedule AsyncRedux actions

## Freshness

Use `Fresh` to skip fetches within a freshness window. Override `freshFor` in
milliseconds and return an immutable entity key from `freshKeyParams()` when needed.
Override `ignoreFresh` for a forced fetch. A failed run restores the previous key
state. Use `removeKey()` to invalidate the current key.

## Polling

Use `Polling` for periodic reads. Its `poll` value controls one-shot, start, and stop
dispatches, plus `Poll.runNowAndRestart` for an immediate run that resets the
schedule. `createPollingAction()` creates a fresh tick action each time. Use
`pollingKeyParams()` to scope independent jobs, and use the same key when stopping.
The default schedule waits for the previous run to finish. Place connectivity and
execution controls on the tick action so they cannot prevent a stop command.

## Sequential work

Use `Sequential` when every action must run in dispatch order. All users of the
mixin in a store share a queue by default. Return a stable key from
`sequentialKeyParams()` for independent queues. Never await an action queued behind
the current action in the same queue. If you override `before`, await `super.before()`
first. Preserve `super.after()` even if cleanup fails. Override `discardQueueOnError`
only when pending actions depend on the failed action.

This example uses the state and base action from the setup skill.

```dart
class SaveCounter extends AppAction with Sequential<AppState> {
  SaveCounter(this.counterId, this.value, this.save);
  final String counterId;
  final int value;
  final Future<void> Function(String, int) save;

  @override
  Object sequentialKeyParams() => ('counter', counterId);

  @override
  Future<AppState?> reduce() async {
    await save(counterId, value);
    return null;
  }
}
```

## References

- [Control mixins](https://asyncredux.com/flutter/advanced-actions/control-mixins)
- [Action mixin compatibility](https://asyncredux.com/flutter/advanced-actions/action-mixins)
