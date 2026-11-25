---
name: asyncredux-selectors
description: Write pure AsyncRedux selectors, share them between actions and widgets, and memoize expensive derived data.
---

# Write and cache selectors

Keep selectors pure and read from the state argument. Call shared selectors with
current `state` in actions and inside the widget's top-level `context.select`. If
a widget-specific selector helper calls `context.select` itself, invoke that helper
directly from `build`. Avoid nesting subscriptions.

Memoize expensive derived results by keying on the smallest immutable inputs.
Choose a `cache...` helper for the number of state inputs and parameters. Hoist the
cache outside the selector invocation and return immutable results.

```dart
import 'package:async_redux/async_redux.dart';

final _filterNames = cache1state_1param(
  (List<String> names) => (String prefix) =>
      List<String>.unmodifiable(names.where((name) => name.startsWith(prefix))),
);

List<String> namesStartingWith(List<String> names, String prefix) =>
    _filterNames(names)(prefix);
```

Pass an immutable list that retains its identity while unchanged. For a widget that
renders the result, call the selector inside `context.select` with the list from the
state argument.

## References

- [Widget selectors](https://asyncredux.com/flutter/miscellaneous/widget-selectors)
- [Action selectors](https://asyncredux.com/flutter/advanced-actions/action-selectors)
- [Cached selectors](https://asyncredux.com/flutter/miscellaneous/cached-selectors)
