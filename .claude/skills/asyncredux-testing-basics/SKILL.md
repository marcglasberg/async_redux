---
name: asyncredux-testing-basics
description: Test AsyncRedux reducers, actions, and Flutter widget wiring with isolated stores and controlled dependencies.
---

# Test AsyncRedux behavior

Use a fresh `Store<AppState>` with known initial state and fake services for action
tests. Dispatch the real action, await completion when needed, and assert the state
or failure. Use `MockStore` when you specifically need to suppress or replace part
of the action graph. Map an action type to `null` to suppress it or use a factory
with a `ReduxAction<AppState>` parameter to construct a fresh replacement each time.

Test presentation by injecting fixed values and callbacks. Test widget wiring by
mounting the widget under `StoreProvider<AppState>`, performing an interaction,
pumping, and asserting both the state and what rendered. The example uses the
`AppState` and `Increment` definitions from the setup skill and `CounterConnector`
from the smart and presentational widgets skill.

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('increments store state', () async {
    final store = Store<AppState>(initialState: const AppState());
    addTearDown(store.shutdown);

    final status = await store.dispatchAndWait(Increment());

    expect(status.isCompletedOk, isTrue);
    expect(store.state.counter, 1);
  });

  testWidgets('counter dispatches and renders the new value', (tester) async {
    final store = Store<AppState>(initialState: const AppState());
    addTearDown(store.shutdown);

    await tester.pumpWidget(
      StoreProvider<AppState>(
        store: store,
        child: const MaterialApp(home: Scaffold(body: CounterConnector())),
      ),
    );

    expect(find.text('Total: 0'), findsOneWidget);
    await tester.tap(find.text('Increment'));
    await tester.pump();

    expect(store.state.counter, 1);
    expect(find.text('Total: 1'), findsOneWidget);
  });
}
```

## References

- [Test files](https://asyncredux.com/flutter/testing/test-files)
- [Dispatch, wait and expect](https://asyncredux.com/flutter/testing/dispatch-wait-and-expect)
- [Mocking actions and reducers](https://asyncredux.com/flutter/testing/mocking)
