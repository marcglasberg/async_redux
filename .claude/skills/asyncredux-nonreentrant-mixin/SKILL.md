---
name: asyncredux-nonreentrant-mixin
description: Use AsyncRedux NonReentrant to drop duplicate in-flight dispatches, with shared or per-entity keys.
---

# Prevent duplicate in-flight actions

Use `NonReentrant<AppState>` when a duplicate should be silently aborted while an
earlier action with the same key is in progress. The default key is the action type.
Override `nonReentrantKeyParams()` with immutable constructor values to allow
different entities to run independently. Override `computeNonReentrantKey()` to
share a key across action types.

Use `Sequential` when every request must run in dispatch order. Pair a per-entity
non-reentrant key with `statusKey` when the UI also tracks status per entity. These
keys serve separate purposes, so set both when needed.

This action uses `AppAction` from the setup skill.

```dart
class SaveItem extends AppAction with NonReentrant<AppState> {
  SaveItem(this.itemId, this.save);
  final String itemId;
  final Future<void> Function(String) save;

  @override
  Object nonReentrantKeyParams() => itemId;

  @override
  Object get statusKey => itemId;

  @override
  Future<AppState?> reduce() async {
    await save(itemId);
    return null;
  }
}
```

## References

- [Control mixins](https://asyncredux.com/flutter/advanced-actions/control-mixins)
- [Action mixin compatibility](https://asyncredux.com/flutter/advanced-actions/action-mixins)
