# async_redux_lints

An analyzer plugin for [AsyncRedux](https://pub.dev/packages/async_redux).

Some AsyncRedux mistakes compile fine but fail at runtime with a `StoreException`.
This plugin reports them as errors while you type: in IntelliJ, Android Studio and
VS Code, and in `dart analyze`. Most errors come with a quick fix.

> **Important:** `flutter analyze` doesn't show this plugin's errors, and still prints
> `No issues found!`. AI coding agents, like Claude Code and Codex, usually check their
> work with `flutter analyze`, so they'll miss every error unless you tell them to use
> `dart analyze`. See [AI agents and the command line](#ai-agents-and-the-command-line).

> **Tip:** The easiest way to install the plugin is to ask your AI agent:
> *"Install the async_redux_lints analyzer plugin, following all the steps in its
> README."* This way, it also sets up its own instructions.

## AI agents and the command line

In the IDE, the plugin's errors show up as you type. On the command line, only some
commands show them:

| Command                                             | Shows the plugin's errors |
|-----------------------------------------------------|---------------------------|
| `dart analyze`, from the package root               | Yes                       |
| `dart analyze <file> ...`                           | Yes                       |
| `dart analyze <directory>`, like `dart analyze lib` | **No**                    |
| `flutter analyze`, with or without files            | **No**                    |

The commands that don't show them still print `No issues found!`, so an AI agent that
uses them thinks the code is fine. To prevent this, add the following to the
`AGENTS.md` file at the root of your project:

```markdown
## Analyzing code

This project uses the `async_redux_lints` analyzer plugin. To check for errors, run
`dart analyze` from the package root, or `dart analyze <file> ...` for specific files.
Don't use `flutter analyze` or `dart analyze <directory>`. They skip the plugin and
print "No issues found!" even when there are errors.
```

Codex reads `AGENTS.md`. Claude Code reads it too, but only when the project has no
`CLAUDE.md`. So it's best to have only `AGENTS.md`. If your project has both
`AGENTS.md` and `CLAUDE.md`, add the text to both.

## Install

Requires Dart 3.10 (Flutter 3.38) or later.

1. Analyzer plugins are not added to `pubspec.yaml`. Add a top-level `plugins` section
   to the `analysis_options.yaml` at the root of your package:

   ```yaml
   plugins:
     async_redux_lints: ^0.1.0
   ```

2. Restart the Dart analysis server. In IntelliJ or Android Studio, open the
   **Dart Analysis** tool window and click **Restart Dart Analysis Server**. In VS
   Code, run **Dart: Restart Analysis Server** from the command palette. Do this again
   after any change to the `plugins` section.

3. Tell your AI agents to use `dart analyze`, by adding the text in
   [AI agents and the command line](#ai-agents-and-the-command-line) to the
   `AGENTS.md` at the root of your project, creating it if needed. If your project
   also has a `CLAUDE.md`, add the text there too.

The plugin is enabled only for the package whose `analysis_options.yaml` lists it.
A Flutter app and its `example` directory are separate packages, so each needs its own
`plugins` section.

To use a local copy of the plugin, give its path instead of a version. A relative path
is resolved from the directory of the `analysis_options.yaml` file:

```yaml
plugins:
  async_redux_lints:
    path: ../async_redux_lints
```

## Rules

All rules are enabled by default. They are reported as errors, except
`wait_fail_never_matches`, `vm_field_not_in_equals`, `copy_missing_field`,
`state_class_must_be_immutable`, `state_class_missing_equality` and
`equality_missing_field`, which are warnings, and `avoid_context_state`, which is an
info.

### reduce_return_type

The `reduce` method must return `St?` or `Future<St?>`. Other return types throw at
runtime, including `FutureOr<St?>`, `Future<St?>?`, and no return type at all (which
Dart infers as `FutureOr<St?>`):

```dart
FutureOr<AppState?> reduce() => null; // Error
reduce() async => null;               // Error
```

Quick fixes: change the return type to `AppState?`, or to `Future<AppState?>`
(adding `async` if needed).

### before_return_type

The `before` method must return `void` or `Future<void>`. With `FutureOr<void>`, or no
return type, AsyncRedux throws at runtime when `before` returns a `Future`:

```dart
FutureOr<void> before() async { ... } // Error
```

Quick fixes: change the return type to `void`, or to `Future<void>`.

### wrap_reduce_return_type

The `wrapReduce` method must return `Future<St?>`. If it returns `St?`, AsyncRedux
throws at runtime. If it returns `FutureOr<St?>` or `Future<St?>?`, AsyncRedux never
calls it, and no error is shown:

```dart
AppState? wrapReduce(Reducer<AppState> reduce) => ...; // Error
```

Quick fix: change the return type to `Future<AppState?>`, adding `async` if needed.

### reduce_without_await

An async `reduce` must not return a completed `Future`, or state changes may be lost.
So every path that returns a non-null value must first pass through an `await` in
`reduce` itself. Returning `null` without an `await` is fine, because `null` doesn't
change the state:

```dart
Future<AppState?> reduce() async {
  if (state.user == null) return null;       // OK: returns null
  if (state.isCached) return state;          // Error: no await before this return
  var data = await api.load();
  return state.copy(data: data);             // OK: after an await
}
```

`return someFuture();` without `await` is also an error. Code that does the `await`
somewhere else, for example in a helper method, doesn't count.

The `await` must provably run before the `return`, so these don't count:

- An `await` inside a `for` or `while` loop, because the loop may run zero times.
- An `await` in only some branches of an `if`, `switch` or `? :`.
- An `await` on the right side of `&&`, `||` or `??`, or in the arguments of a
  null-aware call like `a?.b(await c)`.
- For a `return` after a `try`/`catch`, an `await` inside the `try`, because the
  `catch` may run before it.

In these cases, add `await microtask;` to the start of `reduce`.

Quick fixes: add `await microtask;` to the start of `reduce`, or make `reduce` sync.
Making it sync is only offered when `reduce` has no `await` at all.

### dispatch_sync_async_action

`dispatchSync` only accepts sync actions. An action is async if its `before`, `reduce`
or `wrapReduce` method returns a `Future`. This includes methods that come from mixins,
like `CheckInternet`, `Retry` and `Sequential`:

```dart
class LoadUser extends ReduxAction<AppState> with CheckInternet<AppState> { ... }

store.dispatchSync(LoadUser()); // Error: 'before' (from 'CheckInternet') returns a Future.
```

Quick fixes: replace `dispatchSync` with `dispatch` or `dispatchAndWait`.

The rule only reports when the action's type is known. For example, it doesn't report
`dispatchSync(action)` when `action` is typed as `ReduxAction<AppState>`.

### incompatible_mixins

Some AsyncRedux mixins can't be combined in the same action, and fail an assertion at
runtime, in debug mode. For example, `NonReentrant` with `Throttle`, `Retry` with
`Debounce`, or `Fresh` with `NonReentrant`:

```dart
class LoadUser extends ReduxAction<AppState>
    with NonReentrant<AppState>, Throttle<AppState> { ... } // Error
```

Mixins inherited from a superclass, like a base action, count too. The error is shown
on the mixin that comes last in the `with` clause:

```dart
abstract class AppAction extends ReduxAction<AppState> with CheckInternet<AppState> {}

// Error: 'ServerPush' can't be combined with 'CheckInternet' (from 'AppAction').
class PushUser extends AppAction with ServerPush<AppState> { ... }
```

See the [mixin compatibility matrix](https://github.com/marcglasberg/async_redux/blob/master/mixin_compatibility.md)
for all combinations.

### polling_with_caveat_mixin

The `Polling` mixin can be combined with `CheckInternet`, `AbortWhenNoInternet`,
`NonReentrant`, `Throttle`, `Fresh` and `Sequential`, but only if you add those to the
action returned by `createPollingAction`, and not to the action with `Polling`. They
can abort, fail or delay a dispatch, and can't tell a `Poll.stop` apart from a regular
tick. So on the action with `Polling`, they may block the `Poll.stop` itself, and you'd
be unable to stop the polling:

```dart
class PollBalance extends ReduxAction<AppState>
    with Polling<AppState>, Sequential<AppState> { ... } // Error
```

Instead, add them to the tick action:

```dart
class PollBalance extends ReduxAction<AppState> with Polling<AppState> {
  @override
  ReduxAction<AppState> createPollingAction() => LoadBalance();
  ...
}

class LoadBalance extends ReduxAction<AppState> with Sequential<AppState> { ... }
```

### wait_fail_invalid_argument

The `isWaiting`, `isFailed`, `exceptionFor` and `clearExceptionFor` methods take an
`Object`, but only accept some kinds of values. Anything else throws a
`StoreException` at runtime:

- `isWaiting` accepts an action, an action type, or a list of actions and action types.
- `isFailed`, `exceptionFor` and `clearExceptionFor` accept an action type, or a list
  of action types. They don't accept actions.

```dart
context.isWaiting('LoadUser');            // Error: a String
context.isFailed(action);                 // Error: an action
context.exceptionFor([LoadUser, action]); // Error: an action in the list
```

This applies to the methods of the store, of `BuildContext`, of actions, of
view-model factories, and of `StoreProvider`.

Quick fix: replace the action with its type. For example, `LoadUser()` becomes
`LoadUser`, and `action` becomes `action.runtimeType`.

The rule only reports when the argument's type is known. For example, it doesn't
report an argument typed as `Object`, or a `List<Object>`.

### wait_fail_never_matches

A warning for an argument of `isWaiting`, `isFailed`, `exceptionFor` or
`clearExceptionFor` that is accepted, but never matches any action. So `isWaiting`
and `isFailed` always return `false`, and `exceptionFor` always returns `null`:

```dart
context.isWaiting(AppState);   // Not an action type.
context.isFailed(AppAction);   // An abstract action type.
context.isWaiting(Increment);  // A sync action type.
context.isWaiting(LoadUser()); // An action that was never dispatched.
```

- AsyncRedux compares the exact type of each action, not its subtypes. So an
  abstract action type, like a base action, or a mixin, never matches.
- Sync actions finish before they can be waited on. This only applies to `isWaiting`.
  A sync action can still fail, so `isFailed(Increment)` is fine.
- `isWaiting(LoadUser())` checks a new action, which is never the one that was
  dispatched. Use the type `LoadUser`, or keep a reference to the dispatched action.

Quick fix, for a new action: replace it with its type.

### avoid_context_state

An info for every `context.state`, and `context.getState<AppState>()`. They rebuild the
widget when any part of the state changes. While the widget builds, `context.select`
only rebuilds it when the selected parts change. In callbacks, `context.read()` reads
the state without rebuilding the widget:

```dart
Widget build(BuildContext context) {
  var state = context.state;                        // Info
  return ElevatedButton(
    onPressed: () => print(context.state.counter), // Info
    child: Text('${state.counter} ${state.name}'),
  );
}

Widget build(BuildContext context) {
  var counter = context.select((st) => st.counter); // OK
  var name = context.select((st) => st.name);       // OK
  return ElevatedButton(
    onPressed: () => print(context.read().counter), // OK
    child: Text('$counter $name'),
  );
}
```

The rule is reported even when no quick fix is offered. When the widget really needs
the whole state, for example when the state is an `int` that the widget shows, add
`// ignore: async_redux_lints/avoid_context_state`.

Quick fixes:

- In a `build` method, or a builder like `Builder(builder: (context) => ...)`: replace
  `context.state.field` with `context.select((st) => st.field)`. For
  `var state = context.state;`, where the variable is only used as `state.field`, the
  fix declares one variable per field, like
  `var field = context.select((st) => st.field);`. It's not offered when one of these
  names is already used in the method, or when the state itself is used, like in
  `print(state)`.
- In callbacks, like `onPressed`, and in the `State` methods `didChangeDependencies`,
  `didUpdateWidget`, `activate`, `deactivate`, `dispose` and `reassemble`: replace `context.state` with `context.read()`, and
  `context.getState<AppState>()` with `context.getRead<AppState>()`.
- Elsewhere, like in helper methods, or closures that are not callbacks or builders,
  no fix is offered, since it's not known whether the code runs while the widget
  builds.

In `initState`, `context.state` is reported by `context_state_in_init_state` instead.

### context_state_in_init_state

`context.state` throws in the `initState` method of a `State`, because the widget
can't depend on the store before `initState` completes. Use `context.read()` instead:

```dart
@override
void initState() {
  super.initState();
  var counter = context.state.counter;  // Error
  var counter = context.read().counter; // OK
}
```

This also applies to `context.getState<AppState>()`. Closures inside `initState`, like
`addPostFrameCallback((_) => ...)`, run later, so they're not reported.

Quick fix: replace `context.state` with `context.read()`, and
`context.getState<AppState>()` with `context.getRead<AppState>()`.

### select_in_callback

`context.select` only works while the widget builds. In a callback, like `onPressed`,
it throws a `FlutterError` in debug mode. Use `context.read()` instead:

```dart
ElevatedButton(
  onPressed: () => print(context.select((st) => st.counter)), // Error
  ...
);
```

The rule checks closures passed as a named argument that starts with `on`, like
`onPressed` or `onChanged`, and the `State` methods `initState`,
`didChangeDependencies`, `didUpdateWidget`, `activate`, `deactivate`, `dispose` and
`reassemble`. It doesn't check helper methods, since `build` may call them. It also
applies to `context.getSelect`.

Quick fix: replace `context.select((st) => st.counter)` with `context.read().counter`.
For `context.getSelect`, it uses `context.getRead<AppState>()`. The fix is not offered
when your `BuildContext` extension doesn't declare `read()`.

The `state`, `select` and `read` of the `BuildContext` extension recommended by
AsyncRedux are recognized by their names, when the extension's library imports
`async_redux`. This way, the `select` and `read` of packages like `provider` are not
reported.

### vm_field_not_in_equals

A warning for a field of a `Vm` subclass that is missing from the `equals` list passed
to the `Vm` constructor. View-models with the same `equals` are considered equal, so
the widget doesn't rebuild when only that field changes:

```dart
class ViewModel extends Vm {
  final int counter;
  final String description; // Warning
  final VoidCallback onIncrement;

  ViewModel({
    required this.counter,
    required this.description,
    required this.onIncrement,
  }) : super(equals: [counter]);
}
```

Calling the `Vm` constructor without `equals` is the same as an empty list, so all
fields are reported.

Not reported:

- Fields that are functions, like `onIncrement`, since they can't be in `equals`.
- Fields that a constructor doesn't set from its parameters, like `final int x = 0`,
  since they are the same in all view-models.
- View-models that override `==`.
- Constructors that don't pass `equals` as a list literal, like `super.equals` or
  `super(equals: list)`.

Quick fixes: add the field to `equals`, or add all missing fields to `equals`.

### copy_missing_field

A warning for a `copy` or `copyWith` method that can't change some fields of its
class, when the class is a state class. A state class is annotated with `@stateClass`
from `package:async_redux`, or extends, implements or mixes in a class or mixin
annotated with `@stateClass`.

This usually happens when a field is added to the class, but not to `copy`. If the
constructor parameter for the field is optional, `copy` then also resets the field to
its default value:

```dart
@stateClass
class AppState {
  final int counter;
  final String name;
  final bool waiting;

  AppState({required this.counter, this.name = '', this.waiting = false});

  // Warning: Fields 'name' and 'waiting' are missing from 'copy'.
  AppState copy({int? counter, bool? waiting}) =>
      AppState(counter: counter ?? this.counter, waiting: false);
  // Quick fix: Add 'name' to 'copy'.
}
```

A field is missing from the copy method if the method has no parameter with the
field's name, like `name` above, or has one but doesn't use it, like `waiting` above.
Each copy method gets a single warning, on its name, listing all its missing fields.

Not reported:

- Classes that are not state classes. Classes that are only annotated with
  `@immutable` are not checked.
- Private fields.
- Fields that no constructor sets from a parameter with the same name, like
  `final int x = 0`, or `doubled = counter * 2`. Fields set with `this.name`, or
  with `name = name ?? ''`, are checked.
- Fields and copy methods inherited from a superclass.

Quick fix: add the missing fields to the copy method, all at once. For each field,
the fix adds a nullable parameter if needed, like `String? name`, and passes
`name: name ?? this.name` to the constructor.

The fix never changes existing code. It skips a field when the constructor call
already has an argument for it, like `waiting: false` above, or `name: this.name`.
It also skips a field when the constructor's parameter for it is positional, or when
the copy method needs a new parameter for it but has optional positional parameters.
Fix the skipped fields by hand, or ignore the warning. The fix is only offered when it
can add at least one field.

### state_class_must_be_immutable

A warning for a class with non-final instance fields, when the class is annotated with
`@stateClass` from `package:async_redux`. Annotate your state classes, like `AppState`,
and the classes used inside the state:

```dart
@stateClass
class AppState { // Warning: 'AppState.counter' isn't final.
  int counter;
  final String name;

  AppState({required this.counter, required this.name});
}
```

This is the same check the analyzer does for `@immutable`. Classes that extend,
implement or mix in a `@stateClass` class or mixin are checked too, and so are the
fields they inherit.

### state_class_missing_equality

A warning for a state class that doesn't override `==` and `hashCode`. Without them,
two states with the same values are not equal. A state class is annotated with
`@stateClass` from `package:async_redux`, or extends, implements or mixes in a class
or mixin annotated with `@stateClass`:

```dart
@stateClass
class AppState { // Warning: must override '==' and 'hashCode'.
  final int counter;
  AppState({required this.counter});
}
```

Not reported:

- Abstract classes.
- Classes that inherit `==` or `hashCode` from a superclass or mixin other than
  `Object`, like `Equatable`.

There's no quick fix. Your IDE can generate `==` and `hashCode`. In IntelliJ or
Android Studio, press **Alt+Insert** (**Cmd+N** on macOS) inside the class.

### equality_missing_field

A warning for the `==` operator or the `hashCode` getter of a state class, when they
don't use all fields of the class. Each one gets a single warning, on its name,
listing all its missing fields:

```dart
@stateClass
class AppState {
  final int counter;
  final bool waiting;
  final bool loading;

  ...

  @override
  bool operator ==(Object other) => // Warning: Field 'counter' is missing from '=='.
      identical(this, other) ||
      other is AppState &&
          runtimeType == other.runtimeType &&
          waiting == other.waiting &&
          loading == other.loading;

  @override
  int get hashCode => // Warning: Field 'waiting' is missing from 'hashCode'.
      Object.hash(counter, loading);
}
```

All instance fields declared in the class are checked, including private fields, and
fields with initializers. A field counts as used if `==` or `hashCode` mentions it
anywhere. Fields declared in a superclass are not checked.

Quick fix: add the missing fields. It never changes existing code, and is only
offered for these forms:

- In `==`, it adds `&& counter == other.counter` at the end of the `&&` chain. The
  chain must contain `other is AppState`, possibly after `identical(this, other) ||`.
- In `hashCode`, it adds the fields to `Object.hash(...)` or `Object.hashAll([...])`,
  or adds `^ counter.hashCode` after `a.hashCode ^ b.hashCode` or `a.hashCode`. It
  isn't offered if `Object.hash` would get more than 20 values, its limit.

## Turning off rules

To ignore a single diagnostic, add a comment on the line before it:

```dart
// ignore: async_redux_lints/dispatch_sync_async_action
store.dispatchSync(LoadUser());
```

Use `// ignore_for_file: async_redux_lints/<rule>` for a whole file.

To turn off a rule for the whole package, set it to `false` in `analysis_options.yaml`:

```yaml
plugins:
  async_redux_lints:
    version: ^0.1.0
    diagnostics:
      dispatch_sync_async_action: false
```

## Command line and CI

Tested with Dart 3.13.4 and Flutter 3.47.5:

- `dart analyze` from the package root, and `dart analyze <file> ...`, report the
  plugin's diagnostics. See the table in
  [AI agents and the command line](#ai-agents-and-the-command-line).
- `dart analyze <directory>` and `flutter analyze` don't report them.
- `dart fix` doesn't apply the plugin's quick fixes. They are only available in the IDE.

If a package inside your package also enables the plugin, for example an `example`
directory with its own `pubspec.yaml` and `analysis_options.yaml`, then `dart analyze`
from the outer package may miss diagnostics in both packages. In that case, run
`dart analyze` inside the inner package, and pass the outer package's files explicitly:

```shell
cd example && dart analyze && cd ..
dart analyze $(git ls-files 'lib/*.dart' 'test/*.dart')
```
