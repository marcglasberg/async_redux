---
name: asyncredux-events
description: Send one-time effects from AsyncRedux actions to Flutter widgets using Event, Evt, and context.event.
---

# Deliver one-time widget events

Use an event for a one-time UI effect such as clearing a field, dismissing the keyboard,
or opening a dialog. Use ordinary immutable state and `context.select` for values the
UI must keep rendering.

- Add a final `Evt<T>` field to state and initialize it with `Evt<T>.spent()`.
  An action replaces it with a fresh `Evt<T>(payload)`. Preserve the same event
  instance on copies for unrelated changes.
- Add `R? event<R>(Evt<R> Function(AppState st) selector)` to the app's typed context
  extension and delegate to `getEvent<AppState, R>(selector)`. Read it in `build`
  or `didChangeDependencies`. It returns the payload once, then returns `null`.
- Give each effect one consumer. If several widgets need independent one-time
  notifications, give them separate events. For controller updates, dialogs, and
  navigation, schedule the effect after the frame and check `mounted` before using the widget's controller or context.
- Omit event fields from persistence and restore them spent. Keep controllers and
  focus nodes in the widget.

For a trigger without a data payload, use a typed `Evt<bool>` with a `true` payload.
Then handle it with an explicit `== true` check. This example shows a screen-specific
state type. In an app, add the field and helper to the existing app state and extension.

```dart
import 'package:async_redux/async_redux.dart' hide Event;
import 'package:material_ui/material_ui.dart';

class EditorState {
  EditorState({required this.clearTextEvt});
  EditorState.initial() : clearTextEvt = Evt<bool>.spent();

  final Evt<bool> clearTextEvt;
}

extension EditorStateContext on BuildContext {
  R? event<R>(Evt<R> Function(EditorState st) selector) =>
      getEvent<EditorState, R>(selector);
}

class ClearEditor extends ReduxAction<EditorState> {
  @override
  EditorState reduce() => EditorState(clearTextEvt: Evt<bool>(true));
}

class Editor extends StatefulWidget {
  const Editor({super.key});

  @override
  State<Editor> createState() => _EditorState();
}

class _EditorState extends State<Editor> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    if (context.event((st) => st.clearTextEvt) == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.clear();
      });
    }
    return Column(
      children: [
        TextField(controller: _controller),
        TextButton(
          onPressed: () => context.dispatch(ClearEditor()),
          child: const Text('Clear'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

## References

- [Events](https://asyncredux.com/flutter/basics/events)
- [Advanced events](https://asyncredux.com/flutter/miscellaneous/advanced-events)
