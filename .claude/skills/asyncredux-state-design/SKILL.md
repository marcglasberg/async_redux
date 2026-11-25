---
name: asyncredux-state-design
description: Design immutable AsyncRedux app state, including nested state, collection updates, and domain methods.
---

# Design immutable state

- Represent shared app state with one root `AppState` composed of immutable feature
  state objects. Give it a named initial state when initialization warrants it.
- Use final fields and immutable values throughout the object graph. The docs
  recommend `IList`, `IMap`, and `ISet` from `fast_immutable_collections`. With
  standard Dart collections, store immutable copies so callers cannot mutate state.
- Put pure domain operations in state classes. Reducers can orchestrate I/O and call
  those operations. Keep services, streams, and timers in dependencies or store props.
- When a nullable field can be cleared, use a dedicated method or a sentinel to
  distinguish clearing from an omitted argument. Preserve unchanged substate instances
  when copying so widgets can select them efficiently.

```dart
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

class Todo {
  const Todo(this.title);
  final String title;
}

class TodoState {
  const TodoState({this.todos = const IList<Todo>.empty()});
  final IList<Todo> todos;

  TodoState add(Todo todo) => TodoState(todos: todos.add(todo));
}
```

## References

- [State](https://asyncredux.com/flutter/basics/state)
- [Business logic](https://asyncredux.com/flutter/miscellaneous/business-logic)
