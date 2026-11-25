---
name: asyncredux-setup
description: Set up AsyncRedux in Flutter with immutable AppState, a typed Store, StoreProvider, and typed widget state access.
---

# Set up AsyncRedux

Run `flutter pub add async_redux material_ui` for the example below. Enable the
[AsyncRedux analyzer plugin](https://pub.dev/packages/async_redux_lints#install) to
catch reducer and selector mistakes. Reuse the existing store, base action, and context
extension in an established app.

Create the store at startup. Place `StoreProvider<AppState>` above the widgets that
use it. Define the typed context extension alongside the state and import it in widgets
that select state. The app's base action keeps the state type in one place.

```dart
import 'package:async_redux/async_redux.dart';
import 'package:material_ui/material_ui.dart';

@immutable
class AppState {
  const AppState({this.counter = 0, this.caption = 'Total'});
  final int counter;
  final String caption;

  AppState copy({int? counter, String? caption}) => AppState(
    counter: counter ?? this.counter,
    caption: caption ?? this.caption,
  );
}

extension AppStateContext on BuildContext {
  R select<R>(R Function(AppState st) selector) => getSelect<AppState, R>(selector);
  AppState read() => getRead<AppState>();
}

abstract class AppAction extends ReduxAction<AppState> {}

class Increment extends AppAction {
  @override
  AppState reduce() => state.copy(counter: state.counter + 1);
}

void main() {
  final store = Store<AppState>(initialState: const AppState());
  runApp(
    StoreProvider<AppState>(
      store: store,
      child: const MaterialApp(home: Scaffold(body: CounterButton())),
    ),
  );
}

class CounterButton extends StatelessWidget {
  const CounterButton({super.key});

  @override
  Widget build(BuildContext context) {
    final count = context.select((st) => st.counter);
    return ElevatedButton(
      onPressed: () => context.dispatch(Increment()),
      child: Text('Count: $count'),
    );
  }
}
```

Add `UserExceptionDialog<AppState>` within the app's UI if it should display queued
user exceptions. Add a typed event method to the context extension when the app uses
one-time events.

## References

- [Store](https://asyncredux.com/flutter/basics/store)
- [Using the store state](https://asyncredux.com/flutter/basics/using-the-store-state)
- [Action simplification](https://asyncredux.com/flutter/basics/action-simplification)
- [Failed actions](https://asyncredux.com/flutter/basics/failed-actions)
