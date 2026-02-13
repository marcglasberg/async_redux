# Mixin Compatibility Matrix

This document describes the compatibility between AsyncRedux action mixins.

## Mixins Overview

| Mixin                         | Purpose                                                                   | Overrides                     |
|-------------------------------|---------------------------------------------------------------------------|-------------------------------|
| `CheckInternet`               | Checks internet before action; shows dialog if no connection              | `before`                      |
| `NoDialog`                    | Modifier for `CheckInternet` to suppress dialog                           | (requires `CheckInternet`)    |
| `AbortWhenNoInternet`         | Checks internet before action; aborts silently if no connection           | `before`                      |
| `NonReentrant`                | Aborts if the same action is already running                              | `abortDispatch`               |
| `Retry`                       | Retries the action on error with exponential backoff                      | `wrapReduce`                  |
| `UnlimitedRetries`            | Modifier for `Retry` to retry indefinitely                                | (requires `Retry`)            |
| `OptimisticCommand`           | Applies state changes optimistically, rolls back on error                 | `reduce`                      |
| `OptimisticSync`              | Optimistic updates with coalescing; merges rapid dispatches into one sync | `reduce`                      |
| `OptimisticSyncWithPush`      | Like `OptimisticSync` but with revision tracking for server pushes        | `reduce`                      |
| `ServerPush`                  | Handles server-pushed updates for `OptimisticSyncWithPush`                | `reduce`                      |
| `Throttle`                    | Limits action execution to at most once per throttle period               | `abortDispatch`, `after`      |
| `Debounce`                    | Delays execution until after a period of inactivity                       | `wrapReduce`                  |
| `UnlimitedRetryCheckInternet` | Combines internet check + unlimited retry + non-reentrant                 | `abortDispatch`, `wrapReduce` |
| `Fresh`                       | Skips action if data is still fresh (not stale)                           | `abortDispatch`, `after`      |
| `Polling`                     | Adds periodic polling to any action                                       | `wrapReduce`                  |

## Compatibility Matrix

|                                 | CheckInternet | NoDialog | AbortWhenNoInternet | NonReentrant | Retry | UnlimitedRetries | UnlimitedRetryCheckInternet | Throttle | Debounce | Fresh | OptimisticCommand | OptimisticSync | OptimisticSyncWithPush | ServerPush | Polling |
|---------------------------------|:-------------:|:--------:|:-------------------:|:------------:|:-----:|:----------------:|:---------------------------:|:--------:|:--------:|:-----:|:-----------------:|:--------------:|:----------------------:|:----------:|:-------:|
| **CheckInternet**               |       —       |    ✅     |          ❌          |      ✅       |  ✅️   |        ✅️        |              ❌              |    ✅     |    ✅     |   ✅   |         ✅         |       ✅        |           ✅            |     ❌      |    ✅    |
| **NoDialog**                    |      ➡️       |    —     |          ❌          |      ✅       |  ✅️   |        ✅️        |              ❌              |    ✅     |    ✅     |   ✅   |         ✅         |       ✅        |           ✅            |     ❌      |    ✅    |
| **AbortWhenNoInternet**         |       ❌       |    ❌     |          —          |      ✅       |  ✅️   |        ✅️        |              ❌              |    ✅     |    ✅     |   ✅   |         ✅         |       ✅        |           ✅            |     ❌      |    ✅    |
| **NonReentrant**                |       ✅       |    ✅     |          ✅          |      —       |   ✅   |        ✅         |              ❌              |    ❌     |    ✅     |   ❌   |         ❌         |       ❌        |           ❌            |     ❌      |    ✅    |
| **Retry**                       |      ✅️       |    ✅️    |         ✅️          |      ✅       |   —   |        ✅         |              ❌              |    ✅     |    ❌     |   ✅   |         ✅         |       ❌        |           ❌            |     ❌      |    ❌    |
| **UnlimitedRetries**            |      ✅️       |    ✅️    |         ✅️          |      ✅       |  ➡️   |        —         |              ❌              |    ✅     |    ❌     |   ✅   |         ❌         |       ❌        |           ❌            |     ❌      |    ❌    |
| **UnlimitedRetryCheckInternet** |       ❌       |    ❌     |          ❌          |      ❌       |   ❌   |        ❌         |              —              |    ❌     |    ❌     |   ❌   |         ❌         |       ❌        |           ❌            |     ❌      |    ❌    |
| **Throttle**                    |       ✅       |    ✅     |          ✅          |      ❌       |   ✅   |        ✅         |              ❌              |    —     |    ✅     |   ❌   |         ❌         |       ❌        |           ❌            |     ❌      |    ✅    |
| **Debounce**                    |       ✅       |    ✅     |          ✅          |      ✅       |   ❌   |        ❌         |              ❌              |    ✅     |    —     |   ✅   |         ❌         |       ❌        |           ❌            |     ❌      |    ❌    |
| **Fresh**                       |       ✅       |    ✅     |          ✅          |      ❌       |   ✅   |        ✅         |              ❌              |    ❌     |    ✅     |   —   |         ❌         |       ❌        |           ❌            |     ❌      |    ✅    |
| **OptimisticCommand**           |       ✅       |    ✅     |          ✅          |      ❌       |   ✅   |        ❌         |              ❌              |    ❌     |    ❌     |   ❌   |         —         |       ❌        |           ❌            |     ❌      |    ❌    |
| **OptimisticSync**              |       ✅       |    ✅     |          ✅          |      ❌       |   ❌   |        ❌         |              ❌              |    ❌     |    ❌     |   ❌   |         ❌         |       —        |           ❌            |     ❌      |    ❌    |
| **OptimisticSyncWithPush**      |       ✅       |    ✅     |          ✅          |      ❌       |   ❌   |        ❌         |              ❌              |    ❌     |    ❌     |   ❌   |         ❌         |       ❌        |           —            |     ❌      |    ❌    |
| **ServerPush**                  |       ❌       |    ❌     |          ❌          |      ❌       |   ❌   |        ❌         |              ❌              |    ❌     |    ❌     |   ❌   |         ❌         |       ❌        |           ❌            |     —      |    ❌    |
| **Polling**                     |       ✅       |    ✅     |          ✅          |      ✅       |   ❌   |        ❌         |              ❌              |    ✅     |    ❌     |   ✅   |         ❌         |       ❌        |           ❌            |     ❌      |    —    |

- ✅ = Compatible (can be combined)
- ❌ = Incompatible (cannot be combined)
- ➡️ = Requires (must be used together)

## Incompatibility Groups

### Group 1: Internet Checking Mixins

These mixins all check internet connectivity and cannot be combined with each
other:

- `CheckInternet`
- `AbortWhenNoInternet`
- `UnlimitedRetryCheckInternet`

### Group 2: abortDispatch Mixins

These mixins override `abortDispatch` and cannot be combined with each other:

- `NonReentrant`
- `Throttle`
- `UnlimitedRetryCheckInternet`
- `Fresh`

### Group 3: wrapReduce Mixins

These mixins override `wrapReduce` and cannot be combined with each other:

- `Retry` / `UnlimitedRetries`
- `Debounce`
- `UnlimitedRetryCheckInternet`
- `Polling`

### Group 4: Optimistic Update Mixins

These mixins handle optimistic state updates and cannot be combined with each
other:

- `OptimisticCommand`
- `OptimisticSync`
- `OptimisticSyncWithPush`
- `ServerPush` (used alongside `OptimisticSyncWithPush`, but not combined with it in the
  same action)

## Notes

### CheckInternet / AbortWhenNoInternet + Retry

Combining `Retry` with `CheckInternet` or `AbortWhenNoInternet`
will not retry when there is no internet. It will only retry if there **is**
internet but the action fails for some other reason. To retry indefinitely until
internet is available, use `UnlimitedRetryCheckInternet` instead.

### NoDialog

`NoDialog` is a modifier mixin that **requires** `CheckInternet`. It cannot be
used alone:

```dart
class MyAction extends ReduxAction<AppState> with CheckInternet, NoDialog { ... }
```

### UnlimitedRetries

`UnlimitedRetries` is a modifier mixin that **requires** `Retry`. It cannot be
used alone:

```dart
class MyAction extends ReduxAction<AppState> with Retry, UnlimitedRetries { ... }
```

### Recommended Combinations

- `Retry` + `NonReentrant`: Recommended to avoid multiple instances running
  simultaneously.
- `CheckInternet` + `NonReentrant`: Safe combination for internet-dependent actions.
- `CheckInternet` + `Throttle`: Safe combination (but not with `NonReentrant` at the same
  time)
- `AbortWhenNoInternet` + `NonReentrant`: Safe combination.
- `AbortWhenNoInternet` + `Throttle`: Safe combination (but not with `NonReentrant` at the
  same time)
