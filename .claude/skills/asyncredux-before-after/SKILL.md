---
name: asyncredux-before-after
description: Use before and after for AsyncRedux action preconditions and cleanup, including safe lifecycle overrides with mixins.
---

# Use action lifecycle hooks

`before` runs before `reduce`. Give it a `void` return type for synchronous work or
`Future<void>` for asynchronous work. An async `before` makes the action asynchronous
even with a sync reducer. An exception in `before` skips `reduce`.

`after` is synchronous. It runs after `before` or `reduce` throws, so it is suitable
for cleanup. A dispatch rejected by `abortDispatch()` never enters these hooks. Make
cleanup safe after partial setup, and handle cleanup errors inside `after`.

If an inherited hook performs work, preserve it. For `Sequential` specifically,
`await super.before()` first and ensure `super.after()` runs, preferably in `finally`.
Use `context.isWaiting` for a busy indicator or modal barrier driven by an async action.
Use `wrapReduce` when you need to wrap the reducer itself, and consult mixin
compatibility before adding a wrapper.

## References

- [Before and after the reducer](https://asyncredux.com/flutter/advanced-actions/before-and-after-the-reducer)
- [Wrapping the reducer](https://asyncredux.com/flutter/advanced-actions/wrapping-the-reducer)
- [Control mixins](https://asyncredux.com/flutter/advanced-actions/control-mixins)
