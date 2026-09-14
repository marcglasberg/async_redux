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
| `Sequential`                  | Makes actions run one at a time, in dispatch order                        | `before`, `after`             |

## Compatibility Matrix

|                                 | CheckInternet | NoDialog | AbortWhenNoInternet | NonReentrant | Retry | UnlimitedRetries | UnlimitedRetryCheckInternet | Throttle | Debounce | Fresh | OptimisticCommand | OptimisticSync | OptimisticSyncWithPush | ServerPush | Polling | Sequential |
|---------------------------------|:-------------:|:--------:|:-------------------:|:------------:|:-----:|:----------------:|:---------------------------:|:--------:|:--------:|:-----:|:-----------------:|:--------------:|:----------------------:|:----------:|:-------:|:----------:|
| **CheckInternet**               |       —       |    ✅     |          ❌          |      ✅       |  ✅️   |        ✅️        |              ❌              |    ✅     |    ✅     |   ✅   |         ✅         |       ✅        |           ✅            |     ❌      |    ✅    | ✅ |
| **NoDialog**                    |      ➡️       |    —     |          ❌          |      ✅       |  ✅️   |        ✅️        |              ❌              |    ✅     |    ✅     |   ✅   |         ✅         |       ✅        |           ✅            |     ❌      |    ✅    | ✅ |
| **AbortWhenNoInternet**         |       ❌       |    ❌     |          —          |      ✅       |  ✅️   |        ✅️        |              ❌              |    ✅     |    ✅     |   ✅   |         ✅         |       ✅        |           ✅            |     ❌      |    ✅    | ✅ |
| **NonReentrant**                |       ✅       |    ✅     |          ✅          |      —       |   ✅   |        ✅         |              ❌              |    ❌     |    ✅     |   ❌   |         ❌         |       ❌        |           ❌            |     ❌      |    ✅    | ✅ |
| **Retry**                       |      ✅️       |    ✅️    |         ✅️          |      ✅       |   —   |        ✅         |              ❌              |    ✅     |    ❌     |   ✅   |         ✅         |       ❌        |           ❌            |     ❌      |    ❌    | ✅ |
| **UnlimitedRetries**            |      ✅️       |    ✅️    |         ✅️          |      ✅       |  ➡️   |        —         |              ❌              |    ✅     |    ❌     |   ✅   |         ❌         |       ❌        |           ❌            |     ❌      |    ❌    | ✅ |
| **UnlimitedRetryCheckInternet** |       ❌       |    ❌     |          ❌          |      ❌       |   ❌   |        ❌         |              —              |    ❌     |    ❌     |   ❌   |         ❌         |       ❌        |           ❌            |     ❌      |    ❌    | ❌ |
| **Throttle**                    |       ✅       |    ✅     |          ✅          |      ❌       |   ✅   |        ✅         |              ❌              |    —     |    ✅     |   ❌   |         ❌         |       ❌        |           ❌            |     ❌      |    ✅    | ✅ |
| **Debounce**                    |       ✅       |    ✅     |          ✅          |      ✅       |   ❌   |        ❌         |              ❌              |    ✅     |    —     |   ✅   |         ❌         |       ❌        |           ❌            |     ❌      |    ❌    | ❌ |
| **Fresh**                       |       ✅       |    ✅     |          ✅          |      ❌       |   ✅   |        ✅         |              ❌              |    ❌     |    ✅     |   —   |         ❌         |       ❌        |           ❌            |     ❌      |    ✅    | ✅ |
| **OptimisticCommand**           |       ✅       |    ✅     |          ✅          |      ❌       |   ✅   |        ❌         |              ❌              |    ❌     |    ❌     |   ❌   |         —         |       ❌        |           ❌            |     ❌      |    ❌    | ✅ |
| **OptimisticSync**              |       ✅       |    ✅     |          ✅          |      ❌       |   ❌   |        ❌         |              ❌              |    ❌     |    ❌     |   ❌   |         ❌         |       —        |           ❌            |     ❌      |    ❌    | ❌ |
| **OptimisticSyncWithPush**      |       ✅       |    ✅     |          ✅          |      ❌       |   ❌   |        ❌         |              ❌              |    ❌     |    ❌     |   ❌   |         ❌         |       ❌        |           —            |     ❌      |    ❌    | ❌ |
| **ServerPush**                  |       ❌       |    ❌     |          ❌          |      ❌       |   ❌   |        ❌         |              ❌              |    ❌     |    ❌     |   ❌   |         ❌         |       ❌        |           ❌            |     —      |    ❌    | ❌ |
| **Polling**                     |       ✅       |    ✅     |          ✅          |      ✅       |   ❌   |        ❌         |              ❌              |    ✅     |    ❌     |   ✅   |         ❌         |       ❌        |           ❌            |     ❌      |    —    | ⚠️ |
| **Sequential**                  |       ✅       |    ✅     |          ✅          |      ✅       |   ✅   |        ✅         |             ❌              |    ✅     |    ❌     |   ✅   |         ✅         |       ❌        |           ❌            |     ❌      |   ⚠️    |     —      |

- ✅ = Compatible (can be combined)
- ❌ = Incompatible (cannot be combined)
- ⚠️ = Allowed, but with caveats (see the notes below)
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

### Group 5: Sequential

`Sequential` holds the action until its turn in the queue. It cannot be
combined with:

- `Debounce`, `OptimisticSync`, `OptimisticSyncWithPush` and `ServerPush`,
  which all need the action (or its optimistic state change) to happen as soon
  as it is dispatched, and not when it gets its turn.
- `UnlimitedRetryCheckInternet`, which drops a dispatch while another action of
  the same type is in progress. Since a queued action does count as being in
  progress, actions of the same type would be silently dropped instead of being
  ordered.

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

### Sequential

`Sequential` makes actions run one at a time, in the exact order they were
dispatched. It only overrides `before` and `after`, so it composes with most
other mixins, in any mixin order.

Safe combinations:

- `Sequential` + `CheckInternet` / `NoDialog` / `AbortWhenNoInternet`: the
  internet check happens when the action gets its turn in the queue.
- `Sequential` + `Retry` / `UnlimitedRetries`: the retries happen while the
  action holds the queue, which delays the actions waiting behind it.
- `Sequential` + `NonReentrant`: duplicates are dropped while the original
  action is queued or running, and the ones that get through still run one at
  a time.
- `Sequential` + `Throttle` / `Fresh`: note that both the throttle period and
  the fresh period start when the action finishes, so they start counting
  after the action's turn in the queue, and not from the dispatch.
- `Sequential` + `OptimisticCommand`: note the optimistic value is applied
  when the action gets its turn, and not as soon as it is dispatched.

Combinations with caveats:

- `Polling` + `CheckInternet` / `AbortWhenNoInternet` / `NonReentrant` /
  `Throttle` / `Fresh` / `Sequential`: add these to the action returned by
  `createPollingAction`, and NOT to the action that starts and stops the
  polling. All of them can abort or fail a dispatch, and they can't tell a
  `Poll.stop` apart from a regular tick. So, on the polling controller, they may
  block the `Poll.stop` itself, and you'd be unable to stop the polling:

  - `Throttle`: a `Poll.stop` inside the throttle period is silently ignored.
  - `NonReentrant`: a `Poll.stop` while a run is in progress is silently ignored.
  - `Fresh`: a `Poll.stop` while the data is fresh is silently ignored.
  - `CheckInternet`: a `Poll.stop` with no internet fails in `before`.
  - `AbortWhenNoInternet`: a `Poll.stop` with no internet is silently aborted.
  - `Sequential`: a `Poll.stop` has to wait for its turn in the queue.

  Note that with the default `pollWaitsForRun` of `true` ticks can't pile up,
  since a tick is only scheduled after the previous one finishes. Adding
  `NonReentrant`, `Throttle` or `Sequential` to the tick action only matters
  when `pollWaitsForRun` is `false`.

Incompatible combinations (they throw an assertion error in debug mode):

- `Sequential` + `Debounce`: the debounce period would only start when the
  action got its turn in the queue, which defeats the purpose of debouncing.
- `Sequential` + `UnlimitedRetryCheckInternet`: that mixin aborts the dispatch
  while another action of the same type is in progress, and an action waiting
  in the queue does count as being in progress. This means two actions of the
  SAME type never queue behind each other: the later ones are silently dropped
  instead of being ordered, which is the opposite of what `Sequential` is for.
  On top of that, it retries forever while holding the queue, so a single
  action can block every action behind it for as long as the internet is down.
  To keep the ordering and still retry, use `Retry` with a limited number of
  attempts, possibly with `Sequential.discardQueueOnError`.
- `Sequential` + `OptimisticSync` / `OptimisticSyncWithPush`: those mixins need
  dispatches to overlap. They apply the optimistic value as soon as the action
  is dispatched, and coalesce the dispatches that happen while a request is in
  flight into a single follow-up request. Under `Sequential` the UI would stop
  giving immediate feedback, and nothing would ever be coalesced: each dispatch
  would send its own request. Note those mixins already guarantee a single
  in-flight request per key, so `Sequential` is not needed to serialize them.
- `Sequential` + `ServerPush`: pushed values must be applied to the state as
  soon as they arrive, and `Sequential` would delay them behind unrelated
  queued actions. Worse, a push is what tells an in-flight
  `OptimisticSyncWithPush` request that no follow-up is needed, and that signal
  would arrive too late.

Also note that an action holding the queue must never wait for another action
in the same queue (`dispatchAndWait`, `waitActionType`, `waitAllActions`, or a
`waitCondition` that only becomes true after the other action runs), or both
will wait for each other forever.

### Recommended Combinations

- `Retry` + `NonReentrant`: Recommended to avoid multiple instances running
  simultaneously.
- `CheckInternet` + `NonReentrant`: Safe combination for internet-dependent actions.
- `CheckInternet` + `Throttle`: Safe combination (but not with `NonReentrant` at the same
  time)
- `AbortWhenNoInternet` + `NonReentrant`: Safe combination.
- `AbortWhenNoInternet` + `Throttle`: Safe combination (but not with `NonReentrant` at the
  same time)
