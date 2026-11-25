---
name: asyncredux-wait-fail-succeed
description: Drive Flutter loading, inline errors, and refresh from AsyncRedux action status, with independent per-item tracking via statusKey.
---

# Render loading and failure states

Use `context.isWaiting(ActionType)` and `context.isFailed(ActionType)` in `build`
for reactive status. Use `context.exceptionFor(ActionType)` for a `UserException`
and provide fallback text for other errors. Use `context.select` for the actual data.
Use `dispatchAndWait` in a `RefreshIndicator.onRefresh` callback and await completion.

For per-item status, derive the action's `statusKey` from final constructor fields.
Pass that key to `isWaiting`, `isFailed`, `exceptionFor`, and `clearExceptionFor`.
A string ID or record of IDs works. Omitting the key checks the whole action type.
Redispatching the same type and key clears that failure. Clear a dismissed failure
explicitly, particularly when the set of possible keys is large.

When several steps form one operation, track a parent action that awaits them.
For progress that outlives a dispatch entirely, represent it in feature state.

This example uses `AppAction` from the setup skill. The callback represents a save
operation for the given row.

```dart
class SaveRow extends AppAction {
  SaveRow(this.rowId, this.save);
  final String rowId;
  final Future<void> Function(String) save;

  @override
  Object get statusKey => rowId;

  @override
  Future<AppState?> reduce() async {
    await save(rowId);
    return null;
  }
}

Widget buildSaveButton(
  BuildContext context,
  String rowId,
  Future<void> Function(String) save,
) {
  final waiting = context.isWaiting(SaveRow, statusKey: rowId);
  final failed = context.isFailed(SaveRow, statusKey: rowId);
  final message = context.exceptionFor(SaveRow, statusKey: rowId)?.message;

  return Column(
    children: [
      ElevatedButton(
        onPressed: waiting ? null : () => context.dispatch(SaveRow(rowId, save)),
        child: Text(waiting ? 'Saving...' : 'Save'),
      ),
      if (failed) Text(message ?? 'Could not save.'),
    ],
  );
}
```

## References

- [Wait, fail, succeed](https://asyncredux.com/flutter/basics/wait-fail-succeed)
- [Advanced waiting](https://asyncredux.com/flutter/miscellaneous/advanced-waiting)
- [Refresh indicators](https://asyncredux.com/flutter/miscellaneous/refresh-indicators)
