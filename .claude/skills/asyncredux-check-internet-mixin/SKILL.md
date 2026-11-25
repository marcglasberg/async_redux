---
name: asyncredux-check-internet-mixin
description: Choose AsyncRedux connectivity mixins for offline feedback, a silent skip, or retrying until connectivity returns.
---

# Handle offline actions

- `CheckInternet` checks connectivity in `before` and reports a `UserException` if
  offline. Override `connectionException` to customize the error.
- Add `NoDialog` after `CheckInternet` to suppress its dialog and use the failure
  helpers for inline feedback.
- Use `AbortWhenNoInternet` when offline work should be skipped silently.
- Use `UnlimitedRetryCheckInternet` when work should keep trying. It includes a
  connectivity check before each attempt and prevents duplicate in-flight dispatches.
  Use `shouldRetry` to stop on permanent failures. Awaiting this action may wait indefinitely.

These checks report connectivity and HTTP or server errors still need handling.
With `CheckInternet`, an offline failure happens in `before`, outside a plain `Retry`
mixin's retry loop. Check the mixin compatibility matrix when combining behaviors.
In tests set `store.forceInternetOnOffSimulation = () => false` for offline, `true` for
online, or have the callback return `null` to use actual connectivity.

## References

- [Internet mixins](https://asyncredux.com/flutter/advanced-actions/internet-mixins)
- [Action mixin compatibility](https://asyncredux.com/flutter/advanced-actions/action-mixins)
