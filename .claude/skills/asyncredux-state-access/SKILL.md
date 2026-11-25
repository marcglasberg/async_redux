---
name: asyncredux-state-access
description: Read store state in AsyncRedux widgets using context.select and context.read, including multiple fields, callbacks, and initState.
---

# Read store state in widgets

Reuse the app's typed `BuildContext` extension. If it is missing, define
`select<R>(R Function(AppState) selector)` using `getSelect<AppState, R>(selector)`
and `AppState read()` using `getRead<AppState>()`.

- Use `context.select` in `build` or `didChangeDependencies` to subscribe to the
  values that drive the UI. Select the smallest useful value. For several values,
  use separate selections or a Dart record.
- Use `context.read()` in callbacks and `initState` for a current snapshot without a
  subscription. When a callback needs fresh state, read it inside the callback.
- Keep selectors synchronous and pure. Use the supplied state and keep each
  `context.select` outside other selectors. Select list data in the widget's build
  and pass it to item builders.

This widget uses `AppState` and the extension from the setup skill.

```dart
class CounterSummary extends StatelessWidget {
  const CounterSummary({required this.onInspect, super.key});

  final ValueChanged<int> onInspect;

  @override
  Widget build(BuildContext context) {
    final (:counter, :caption) = context.select(
      (st) => (counter: st.counter, caption: st.caption),
    );

    return TextButton(
      onPressed: () => onInspect(context.read().counter),
      child: Text('$caption: $counter'),
    );
  }
}
```

## References

- [Using the store state](https://asyncredux.com/flutter/basics/using-the-store-state)
- [Widget selectors](https://asyncredux.com/flutter/miscellaneous/widget-selectors)
