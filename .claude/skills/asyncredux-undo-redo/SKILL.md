---
name: asyncredux-undo-redo
description: Implement AsyncRedux undo/redo using bounded history and actions for restoring immutable state.
---

# Implement undo and redo

Track bounded history with a store-scoped `StateObserver` or an immutable feature
history in state. Record only successful changes to the slice the user can undo.
Capture the original slice so the first change can be undone. Skip undo/redo
actions when recording observer history, drop the redo branch after a new edit,
and enforce a history limit.

Have synchronous undo and redo actions restore the chosen slice on current state.
Preserve unrelated changes. Expose availability through state the UI can select so
buttons update when history changes. If restoring a value also needs to update a
server, coordinate that write explicitly.

Test the first undo, redo, the history limit, and editing after undo. Test that
unrelated store fields keep their current values.

## References

- [Undo and redo](https://asyncredux.com/flutter/miscellaneous/undo-and-redo)
- [State observers](https://asyncredux.com/flutter/miscellaneous/logging)
