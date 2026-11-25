---
name: asyncredux-persistence
description: Restore and persist AsyncRedux store state with Persistor, including startup fallback, write failures, and lifecycle handling.
---

# Persist store state

Extend `Persistor<AppState>`. Implement `readState`, `deleteState`, and
`persistDifference` with your storage backend. Persist only the durable data and
recreate transient state on load. The persistor serializes saves and coalesces
changes within its throttle window. Override `throttle` when you need a different
duration or return `null` to disable throttling.

This startup helper uses `AppState` from the setup skill and accepts the app's
persistor implementation.

```dart
Future<Store<AppState>> restoreStore(Persistor<AppState> persistor) async {
  final savedState = await persistor.readState();
  final initialState = savedState ?? const AppState();

  if (savedState == null) {
    await persistor.saveInitialState(initialState);
  }

  return Store<AppState>(initialState: initialState, persistor: persistor);
}
```

Use `WidgetsFlutterBinding.ensureInitialized()` before startup I/O when the persistor
uses Flutter plugins. Distinguish missing data from read errors. If recovery calls
for resetting data, use `addError` to queue an explanation for processing after the
store is created. During writes, use `wrapError` for known storage failures and the
store's `globalErrorObserver` for reporting. The next save still compares against
the last successfully persisted state.

`PersistAction<AppState>` requests a flush that bypasses throttling. For lifecycle
handling use `persistAndPausePersistor` and `resumePersistor`. Await
`deleteStateFromPersistence()` when clearing persisted data on logout.

## References

- [Persistence](https://asyncredux.com/flutter/miscellaneous/persistence)
- [Error monitoring](https://asyncredux.com/flutter/miscellaneous/error-monitoring)
