---
name: asyncredux-smart-and-presentational-widgets
description: Split selection and dispatch from reusable Flutter presentation, and test AsyncRedux widget wiring with StoreProvider.
---

# Smart and presentational widgets

Use a single widget when selection, dispatch, and presentation are simple. Extract a smart
widget when presentation should be reused or tested independently. The smart widget
selects values, handles missing data, and passes values and callbacks to the
presentational widget through its constructor.

This example uses the state, increment action, and context extension from the setup skill.

```dart
class CounterConnector extends StatelessWidget {
  const CounterConnector({super.key});

  @override
  Widget build(BuildContext context) {
    final summary = context.select((st) => (count: st.counter, caption: st.caption));
    return CounterView(
      count: summary.count,
      caption: summary.caption,
      onIncrement: () => context.dispatch(Increment()),
    );
  }
}

class CounterView extends StatelessWidget {
  const CounterView({
    required this.count,
    required this.caption,
    required this.onIncrement,
    super.key,
  });

  final int count;
  final String caption;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$caption: $count'),
        ElevatedButton(onPressed: onIncrement, child: const Text('Increment')),
      ],
    );
  }
}
```

Test presentation by pumping `CounterView` with fixed inputs and a recording callback.
Test the wiring by pumping `CounterConnector` under a typed `StoreProvider` and
`MaterialApp`. Tap **Increment**, pump, and assert both `store.state.counter` and the
rendered count. Test action behavior with a store test and start/stop callbacks with
a widget lifecycle test.

## References

- [Smart and presentational widgets](https://asyncredux.com/flutter/basics/smart-and-presentational-widgets)
- [Test files](https://asyncredux.com/flutter/testing/test-files)
- [Testing widget lifecycle](https://asyncredux.com/flutter/testing/testing-oninit-ondispose)
