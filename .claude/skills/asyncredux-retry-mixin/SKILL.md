---
name: asyncredux-retry-mixin
description: Retry transient AsyncRedux reducer failures with backoff, a retry limit, and shouldRetry.
---

# Retry transient reducer failures

`Retry` retries `reduce()` with backoff. It does not retry `before()` and makes the
action asynchronous. The defaults are `maxRetries = 3` after the first try,
`initialDelay = 350` ms, `multiplier = 2`, and `maxDelay = 5000` ms. Read `attempts`
when you need to log attempt counts. `AbortDispatchException` always stops retrying.

Override `shouldRetry(Object error, int attempt)` to retry only transient errors.
Retry writes only when retries are safe, for example when the operation is
idempotent or uses an idempotency key. Combine with `NonReentrant` when duplicate
in-flight calls should be dropped. `UnlimitedRetries` is an explicit opt-in that may
keep an awaited dispatch pending indefinitely.

For this example, `loadAmount` throws `TimeoutException` for retryable timeouts.
`AppState` and `AppAction` come from the setup skill.

```dart
import 'dart:async';

class RetryLoadAmount extends AppAction with Retry<AppState>, NonReentrant<AppState> {
  RetryLoadAmount(this.loadAmount);
  final Future<int> Function() loadAmount;

  @override
  bool shouldRetry(Object error, int attempt) => error is TimeoutException;

  @override
  Future<AppState> reduce() async {
    final amount = await loadAmount();
    return state.copy(counter: state.counter + amount);
  }
}
```

## References

- [Control mixins](https://asyncredux.com/flutter/advanced-actions/control-mixins)
- [Action mixin compatibility](https://asyncredux.com/flutter/advanced-actions/action-mixins)
