# async_redux_lints

This is an analyzer plugin for [AsyncRedux](https://pub.dev/packages/async_redux)
([asyncredux.com](https://asyncredux.com)).
It checks for style issues and also mistakes that compile fine but fail at runtime.

* Meant primarily for **AI agents**, like **Codex** and **Claude Code**
* Shows lint errors as you type in the IDE: IntelliJ, Android Studio and VS Code.
* Lots of quick fixes (for example, ALT+Enter in IntelliJ)

## How to install

Ask your AI agent:

*"Install the async_redux_lints analyzer package from pub.dev,
following all the steps in its README."*

## AI agents and the command line

On the command line, only some commands show the errors:

| Command                                             | Shows the plugin's errors |
|-----------------------------------------------------|---------------------------|
| `dart analyze`, from the package root               | Yes                       |
| `dart analyze <file> ...`                           | Yes                       |
| `dart analyze <directory>`, like `dart analyze lib` | **No**                    |
| `flutter analyze`, with or without files            | **No**                    |

**In other words:** `flutter analyze` doesn't show the linter errors, and even prints
`No issues found!`. It's important to know that because AI agents usually check their
work with `flutter analyze`, which doesn't work here. They MUST, instead, use
`dart analyze`.

Add the following to the `AGENTS.md` file at the root of your project:

```markdown
## Analyzing code

Use the `async_redux_lints` analyzer plugin. To check for errors, run `dart analyze` from 
the package root, or `dart analyze <file> ...` for specific files. Don't use 
`flutter analyze` or `dart analyze <directory>`, as they print "No issues found!" even 
when there are errors.
```

Note Codex reads `AGENTS.md`. Claude Code reads it too, but only when the project has no
`CLAUDE.md`. So it's best to have only `AGENTS.md`. If your project has both
`AGENTS.md` and `CLAUDE.md`, add the above text to both.

## Install

Requires Dart 3.10 (Flutter 3.38) or later.

1. Analyzer plugins are not added to `pubspec.yaml`. Add a top-level `plugins` section
   to the `analysis_options.yaml` at the root of your package:

   ```yaml
   plugins:
     async_redux_lints: ^1.0.0
   ```

2. You may need to restart the Dart analysis server. In IntelliJ or Android Studio, open
   the **Dart Analysis** tool window and click **Restart Dart Analysis Server**. In VS
   Code, run **Dart: Restart Analysis Server** from the command palette. Do this again
   after any change to the `plugins` section.

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

## Turning rules on and off

Most rules are on by default. The opt-in rules, marked in the [list of rules](#rules)
below, are off until you turn them on. Set a rule to `true` in `analysis_options.yaml` to
turn it on, or to `false` to turn it off for the whole package:

```yaml
plugins:
  async_redux_lints:
    version: ^1.0.0
    diagnostics:
      action_name_ends_with_action: true
      dispatch_sync_async_action: false
```

Plugin rules can't be configured. So, when AsyncRedux offers more than one style, like
how to name actions, each style is a separate opt-in rule. Turn on only one of them.

To ignore a single diagnostic directly in the code, add a comment on the line before it:

```dart
// ignore: async_redux_lints/dispatch_sync_async_action
store.dispatchSync(LoadUser());
```

Use `// ignore_for_file: async_redux_lints/<rule>` for a whole file.

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

## Rules

Most rules are on by default. The ones marked opt-in are off until you
[turn them on](#turning-rules-on-and-off).

Some rules are not reported in tests, as noted in their descriptions. Tests are the
files in the `test`, `integration_test`, `test_driver` and `testing` directories of a
package, and the files whose names end with `_test.dart`.

- [`reduce_return_type`](#reduce_return_type) error
- [`before_return_type`](#before_return_type) error
- [`wrap_reduce_return_type`](#wrap_reduce_return_type) error
- [`reduce_without_await`](#reduce_without_await) error
- [`dispatch_sync_async_action`](#dispatch_sync_async_action) error
- [`incompatible_mixins`](#incompatible_mixins) error
- [`polling_with_caveat_mixin`](#polling_with_caveat_mixin) error
- [`wait_fail_invalid_argument`](#wait_fail_invalid_argument) error
- [`wait_fail_never_matches`](#wait_fail_never_matches) warning
- [`avoid_context_state`](#avoid_context_state) info
- [`context_state_in_init_state`](#context_state_in_init_state) error
- [`context_in_dispose`](#context_in_dispose) error
- [`context_in_selector`](#context_in_selector) error
- [`select_outside_build`](#select_outside_build) error
- [`vm_field_not_in_equals`](#vm_field_not_in_equals) warning
- [`copy_missing_field`](#copy_missing_field) warning
- [`state_class_must_be_immutable`](#state_class_must_be_immutable) warning
- [`state_class_missing_equality`](#state_class_missing_equality) warning
- [`equality_missing_field`](#equality_missing_field) warning
- [`equality_missing_inherited_field`](#equality_missing_inherited_field) warning
- [`equatable_props_missing_field`](#equatable_props_missing_field) warning
- [`extend_base_action`](#extend_base_action) info
- [`dependencies_cast_in_action`](#dependencies_cast_in_action) info
- [`prefer_return_null`](#prefer_return_null) info
- [`stale_state_after_await`](#stale_state_after_await) warning
- [`after_throws`](#after_throws) warning
- [`missing_super_in_mixin_override`](#missing_super_in_mixin_override) error
- [`user_exception_outside_action`](#user_exception_outside_action) warning
- [`user_exception_without_cause`](#user_exception_without_cause) info
- [`dispatch_in_global_error_observer`](#dispatch_in_global_error_observer) warning
- [`throw_in_global_error_observer`](#throw_in_global_error_observer) info
- [`retry_without_non_reentrant`](#retry_without_non_reentrant) info
- [`dispatch_and_wait_unlimited_retries`](#dispatch_and_wait_unlimited_retries) warning
- [`async_mixin_in_sync_action`](#async_mixin_in_sync_action) warning
- [`sequential_deadlock`](#sequential_deadlock) error
- [`sequential_before_super_not_first`](#sequential_before_super_not_first) error
- [`sequential_after_super_not_in_finally`](#sequential_after_super_not_in_finally) info
- [`polling_action_restarts_polling`](#polling_action_restarts_polling) warning
- [`server_push_associated_action`](#server_push_associated_action) error
- [`internet_simulation_in_production`](#internet_simulation_in_production) warning
- [`prefer_immutable_collections`](#prefer_immutable_collections) info
- [`non_state_object_in_state`](#non_state_object_in_state) warning
- [`missing_initial_state`](#missing_initial_state) info
- [`event_name_suffix`](#event_name_suffix) info
- [`event_not_spent_initially`](#event_not_spent_initially) warning
- [`event_persisted`](#event_persisted) warning
- [`dispatch_in_build`](#dispatch_in_build) warning
- [`prefer_dispatch_without_context`](#prefer_dispatch_without_context) info
- [`context_read_in_build`](#context_read_in_build) warning
- [`refresh_indicator_without_wait`](#refresh_indicator_without_wait) warning
- [`then_on_dispatch_and_wait`](#then_on_dispatch_and_wait) warning
- [`user_exception_dialog_placement`](#user_exception_dialog_placement) error
- [`navigator_key_not_set`](#navigator_key_not_set) warning
- [`debug_observer_in_release`](#debug_observer_in_release) info
- [`implements_persistor`](#implements_persistor) error
- [`throw_in_read_state`](#throw_in_read_state) warning
- [`initial_state_not_saved`](#initial_state_not_saved) info
- [`timer_or_stream_not_in_props`](#timer_or_stream_not_in_props) info
- [`expect_without_waiting`](#expect_without_waiting) warning
- [`vm_create_from_reused_factory`](#vm_create_from_reused_factory) error
- [`action_status_details_in_production`](#action_status_details_in_production) info
- [`action_name_ends_with_action`](#action_name_ends_with_action) warning, opt-in
- [`action_name_ends_with_underscore_action`](#action_name_ends_with_underscore_action)
  warning, opt-in
- [`action_name_without_action`](#action_name_without_action) warning, opt-in
- [`action_file_name_ends_with_action`](#action_file_name_ends_with_action) warning,
  opt-in
- [`action_file_name_starts_with_action`](#action_file_name_starts_with_action) warning,
  opt-in
- [`prefer_dispatch_with_context`](#prefer_dispatch_with_context) info, opt-in
- [`avoid_abort_dispatch`](#avoid_abort_dispatch) info, opt-in
- [`avoid_wrap_reduce`](#avoid_wrap_reduce) info, opt-in
- [`global_error_observer_without_env`](#global_error_observer_without_env) info, opt-in
- [`missing_key_params`](#missing_key_params) info, opt-in
- [`route_in_state`](#route_in_state) info, opt-in
- [`action_without_to_string`](#action_without_to_string) info, opt-in

---

### reduce_return_type

An error for a `reduce` method that doesn't return `St?` or `Future<St?>`. Other return
types throw at runtime, including `FutureOr<St?>`, `Future<St?>?`, and no return type at
all (which Dart infers as `FutureOr<St?>`):

```dart
FutureOr<AppState?> reduce() => null; // Error 
reduce() async => null;               // Error

Future<AppState?> reduce() => null;   // OK
AppState? reduce() => null;           // OK
```

Quick fixes: change the return type to `AppState?`, or to `Future<AppState?>`
(adding `async` if needed).
   
---

### before_return_type

An error for a `before` method that doesn't return `void` or `Future<void>`. Returning
`FutureOr<void>` or no return type at all (which Dart infers as `FutureOr<void>`) throws
at runtime:

```dart
FutureOr<void> before() async { ... } // Error

Future<void> before() async { ... }   // OK
void before() { ... }                 // OK
```

Quick fixes: change the return type to `void`, or to `Future<void>`.
   
---

### wrap_reduce_return_type

An error for a `wrapReduce` method that doesn't return `Future<St?>`. If it returns `St?`,
AsyncRedux throws at runtime. If it returns `FutureOr<St?>` or `Future<St?>?`, AsyncRedux
never calls it, and no error is shown:

```dart
AppState? wrapReduce(Reducer<AppState> reduce) => ...; // Error
```

Quick fix: change the return type to `Future<AppState?>`, adding `async` if needed.

---

### reduce_without_await

An error for an **async** `reduce` that can return a completed `Future`. If it does, state
changes may be lost. So every path that returns a non-null value must first pass through
an `await` in `reduce` itself. Returning `null` without an `await` is fine, because `null`
doesn't change the state:

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
                              
---

### dispatch_sync_async_action

An error for `dispatchSync` of an async action, since `dispatchSync` only accepts sync
actions. An action is async if its `before`, `reduce` or `wrapReduce` method returns a
`Future`. This includes methods that come from mixins, like `CheckInternet`, `Retry` and
`Sequential`:

```dart
class LoadUser extends ReduxAction<AppState> with CheckInternet<AppState> { ... }

store.dispatchSync(LoadUser()); // Error: 'before' (from 'CheckInternet') returns a Future.
```

Quick fixes: replace `dispatchSync` with `dispatch` or `dispatchAndWait`.

The rule only reports when the action's type is known. For example, it doesn't report
`dispatchSync(action)` when `action` is typed as `ReduxAction<AppState>`.

---

### incompatible_mixins

An error for an action that combines AsyncRedux mixins that can't be used together, and
fail an assertion at runtime, in debug mode. For example, `NonReentrant` with `Throttle`,
`Retry` with `Debounce`, or `Fresh` with `NonReentrant`:

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

See
the [mixin compatibility matrix](https://github.com/marcglasberg/async_redux/blob/master/mixin_compatibility.md)
for all combinations.

---

### polling_with_caveat_mixin

An error for an action with the `Polling` mixin that also uses `CheckInternet`,
`AbortWhenNoInternet`, `NonReentrant`, `Throttle`, `Fresh` or `Sequential`. These can be
combined with `Polling` only if you add them to the action returned by
`createPollingAction`, and not to the action with `Polling`. They can abort, fail or delay
a dispatch, and can't tell a `Poll.stop` apart from a regular tick. So on the action with
`Polling`, they may block the `Poll.stop` itself, and you'd be unable to stop the polling:

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

---

### wait_fail_invalid_argument

An error for a value that `isWaiting`, `isFailed`, `exceptionFor` and `clearExceptionFor`
don't accept. These methods take an `Object`, but only accept some kinds of values.
Anything else throws a `StoreException` at runtime:

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

---

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

---

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

Not reported in tests, where widgets often show the state to check it, and rebuilds
don't matter.

Quick fixes:

- In a `build` method, or a builder like `Builder(builder: (context) => ...)`: replace
  `context.state.user.name` with `context.select((st) => st.user.name)`. The fix
  selects the getters as deep as the code uses them, so the widget only rebuilds when
  what it shows changes. It stops at methods, like `trim()` in
  `context.state.name.trim()`, and at null-aware accesses, like `?.name` in
  `context.state.user?.name`.

  For `var state = context.state;`, where the variable is only used through getters,
  the fix declares one variable per path, named after the path:

  ```dart
  var state = context.state;
  return Text('${state.user.name} ${state.user.age}');

  // Becomes:
  var userName = context.select((st) => st.user.name);
  var userAge = context.select((st) => st.user.age);
  return Text('${userName} ${userAge}');
  ```

  When a path is a prefix of another, like `state.user` and `state.user.name`, only the
  shorter one is selected. When a name is already used, a number is added, starting
  at 2, like `userName2`.

  The fix is not offered when the state itself is used, like in `print(state)`, or
  where `context.select` can't be used: in the `itemBuilder` of a list, or with the
  `context` of another widget.
- In the `itemBuilder` of a list, whose `BuildContext` belongs to the list, not to the
  item: wrap the item in a `Builder`, which gives it its own `BuildContext`, and replace
  `context.state` with `context.select`, as above:

  ```dart
  itemBuilder: (context, index) => Text(context.state.name),

  // Becomes:
  itemBuilder: (context, index) =>
      Builder(builder: (context) => Text(context.select((st) => st.name))),
  ```

  When the item uses the `context` of the widget that builds the list, like in
  `itemBuilder: (_, index) => Text(context.state.name)`, the `Builder` is named after
  it: `Builder(builder: (context) => ...)`. The fix is not offered when the item may be
  null, since the `builder` of a `Builder` can't return null, or when a block body
  doesn't end with a `return`.
- In a builder that uses the `context` of another widget: use the builder's own
  `BuildContext`, and replace `context.state` with `context.select`, as above. If the
  builder's parameter is a wildcard, it's renamed:

  ```dart
  Builder(builder: (_) => Text(context.state.name)),

  // Becomes:
  Builder(builder: (context) => Text(context.select((st) => st.name))),
  ```
- In callbacks, like `onPressed`, in closures passed to methods like
  `addPostFrameCallback`, and in the `State` methods `didUpdateWidget`, `activate`,
  `deactivate` and `reassemble`: replace `context.state` with `context.read()`, and
  `context.getState<AppState>()` with `context.getRead<AppState>()`.
- In `didChangeDependencies`, where `context.state` also makes `didChangeDependencies`
  run again on any state change: replace it with `context.select`, so that it runs
  again only when the selected part changes, or with `context.read()`, so that it
  doesn't run again.
- Elsewhere, like in helper methods, or closures that are not callbacks or builders,
  no fix is offered.

In `initState`, `dispose` and selectors, `context.state` is an error, reported by
[context_state_in_init_state](#context_state_in_init_state),
[context_in_dispose](#context_in_dispose) and [context_in_selector](#context_in_selector)
instead.

`context.state` comes from the `BuildContext` extension recommended by AsyncRedux. It's
recognized by its name, when the extension's library imports `async_redux`.

---

### context_state_in_init_state

An error for `context.state`, `context.isWaiting`, `context.isFailed`,
`context.exceptionFor` and `context.clearExceptionFor` in the `initState` method of a
`State`. They throw there, because the widget can't depend on the store before `initState`
completes. Use `context.read()` instead, or move the code to `didChangeDependencies` or
`build`:

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

Quick fix, for `context.state`: replace it with `context.read()`, and
`context.getState<AppState>()` with `context.getRead<AppState>()`.

`context.state` comes from the `BuildContext` extension recommended by AsyncRedux. It's
recognized by its name, when the extension's library imports `async_redux`.

---

### context_in_dispose

An error for `context.state`, `context.read()`, `context.isWaiting`, `context.isFailed`,
`context.exceptionFor`, `context.clearExceptionFor`, `context.getEnvironment` and
`context.getConfiguration` in the `dispose` method of a `State`. When `dispose` runs, the
widget is no longer in the tree, so they throw. Read what you need in `deactivate`, or
earlier, and keep it in a field:

```dart
@override
void dispose() {
  print(context.read().counter); // Error
  context.dispatch(StopTimer()); // OK
  super.dispose();
}
```

This also applies to closures inside `dispose`. Dispatching actions works. For
`context.select` and `context.event`, see
[select_outside_build](#select_outside_build).

`context.state` and `context.read()` come from the `BuildContext` extension recommended by
AsyncRedux. They're recognized by their names, when the extension's library imports
`async_redux`. This way, the `read` of packages like `provider` is not reported. The
`getState` and `getRead` methods of AsyncRedux are also recognized.

---

### context_in_selector

An error for `context.state`, `context.read()`, `context.select`, `context.event`,
`context.isWaiting`, `context.isFailed`, `context.exceptionFor`,
`context.clearExceptionFor` and `context.dispatch` inside the selector of `context.select`
or `context.event`. The selector must only use its parameter. Using `context.state` there
rebuilds the widget on any state change, and a nested `context.select` throws:

```dart
var items = context.select((st) => context.state.items); // Error
var items = context.select((st) => st.items);            // OK
```

Quick fix, for `context.state` and `context.read()`: replace it with the parameter of
the selector.

`context.state`, `context.read()`, `context.select` and `context.event` come from the
`BuildContext` extension recommended by AsyncRedux. They're recognized by their names,
when the extension's library imports `async_redux`. This way, the `select` and `read` of
packages like `provider` are not reported. The `getState`, `getRead`, `getSelect` and
`getEvent` methods of AsyncRedux are also recognized.

---

### select_outside_build

An error for `context.select` and `context.event` where they can't be used. They work
while the widget builds, with the `BuildContext` of that widget, and in
`didChangeDependencies`, which runs again when the selected value changes. Elsewhere,
they throw a `FlutterError` in debug mode, like in callbacks, or don't work as expected,
like in `didUpdateWidget`, which doesn't run again when the selected value changes:

```dart
ElevatedButton(
  onPressed: () => print(context.select((st) => st.counter)), // Error
  ...
);
```

The rule reports them in:

- Closures passed as a named argument that starts with `on`, like `onPressed`, and
  closures passed to `addPostFrameCallback`, `scheduleMicrotask`, `Future`,
  `Future.microtask`, `Future.delayed`, `Timer`, `Timer.periodic`, `then`,
  `catchError`, `whenComplete`, `listen`, `addListener` and `setState`.
- The `State` methods `initState`, `didUpdateWidget`, `activate`, `deactivate`,
  `dispose` and `reassemble`.
- Builders that use the `BuildContext` of another widget. The builder runs after that
  widget builds:

  ```dart
  Widget build(BuildContext context) {
    return Builder(builder: (inner) => Text(context.select((st) => st.name))); // Error
  }
  ```

- The `itemBuilder` and `separatorBuilder` of lists, like `ListView.builder`, and the
  `builder` of `SliverChildBuilderDelegate`. Their `BuildContext` belongs to the list,
  not to the item. Wrap the item in a `Builder`, or use a separate widget.

Helper methods, like `Widget buildHeader(BuildContext context)`, may be called while
the widget builds, so they're not reported. Neither are closures like
`items.map((item) => ...)`.

Quick fixes:

- In callbacks, and in `State` methods other than `dispose`: replace
  `context.select((st) => st.counter)` with `context.read().counter`. For
  `context.getSelect`, it uses `context.getRead<AppState>()`. The fix is not offered
  when your `BuildContext` extension doesn't declare `read()`, or for `context.event`.
- In a builder that uses the `BuildContext` of another widget: use the builder's own
  `BuildContext`. If it's a wildcard, like in `Builder(builder: (_) => ...)`, it's
  renamed, like `Builder(builder: (context) => ...)`. Not offered in the `itemBuilder`
  of a list.
- In the `itemBuilder` of a list: wrap the item in a `Builder`, like
  `itemBuilder: (context, index) => Builder(builder: (context) => ...)`. This also
  works when the item uses the `context` of the widget that builds the list. Not
  offered when the item may be null, or when a block body doesn't end with a `return`.

`context.select` and `context.event` come from the `BuildContext` extension recommended by
AsyncRedux. They're recognized by their names, when the extension's library imports
`async_redux`. This way, the `select` of packages like `provider` is not reported. The
`getSelect` and `getEvent` methods of AsyncRedux are also recognized.

---

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

---

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

---

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

---

### state_class_missing_equality

A warning for a state class that declares instance fields, but doesn't override `==`
and `hashCode`. Without them, two states with the same values are not equal. A state
class is annotated with `@stateClass` from `package:async_redux`, or extends,
implements or mixes in a class or mixin annotated with `@stateClass`:

```dart
@stateClass
class AppState { // Warning: must override '==' and 'hashCode'.
  final int counter;
  AppState({required this.counter});
}
```

Each class handles its own fields. So this also applies to abstract classes, and to
classes that inherit `==` and `hashCode` from a superclass: the inherited ones don't
know about the fields the class declares. Classes that don't declare fields are not
reported.

Classes that use `Equatable` or `EquatableMixin` from package `equatable` are not
reported either, since they list their fields in `props`. See
[equatable_props_missing_field](#equatable_props_missing_field).

There's no quick fix. Your IDE can generate `==` and `hashCode`. In IntelliJ or
Android Studio, press **Alt+Insert** (**Cmd+N** on macOS) inside the class.

---

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
anywhere. Inherited fields are checked by
[equality_missing_inherited_field](#equality_missing_inherited_field).

Quick fix: add the missing fields. It never changes existing code, and is only
offered for these forms:

- In `==`, it adds `&& counter == other.counter` at the end of the `&&` chain. The
  chain must contain `other is AppState`, possibly after `identical(this, other) ||`.
- In `hashCode`, it adds the fields to `Object.hash(...)` or `Object.hashAll([...])`,
  or adds `^ counter.hashCode` after `a.hashCode ^ b.hashCode` or `a.hashCode`. It
  isn't offered if `Object.hash` would get more than 20 values, its limit.

---

### equality_missing_inherited_field

A warning for the `==` operator or the `hashCode` getter of a state class, when they
don't handle the fields the class inherits from its superclasses and mixins. When a
class overrides `==`, the `==` of its superclass doesn't run, so the inherited fields
are not compared, unless the class does it:

```dart
class Sub extends Base {
  final String name;

  ...

  @override
  bool operator ==(Object other) => // Warning: Inherited field 'counter' is missing.
      other is Sub && name == other.name;
}
```

If a superclass or mixin overrides `==`, call it with `super == other`. Otherwise,
compare the inherited fields yourself. The same applies to `hashCode`, with
`super.hashCode`:

```dart
@override
bool operator ==(Object other) =>
    other is Sub && super == other && name == other.name;

@override
int get hashCode => Object.hash(super.hashCode, name);
```

Quick fix: add `super == other` or `super.hashCode`, or the inherited fields when no
superclass overrides `==` or `hashCode`. It's offered for the same forms as the fix of
[equality_missing_field](#equality_missing_field).

---

### equatable_props_missing_field

A warning for the `props` getter of a state class that uses `Equatable` or
`EquatableMixin` from package `equatable`, when some fields of the class are missing
from it. Equatable compares `props` in `==` and `hashCode`, so a field missing from
`props` is ignored by them:

```dart
@stateClass
class AppState extends Equatable {
  final int counter;
  final String name;

  ...

  @override
  List<Object?> get props => [counter]; // Warning: Field 'name' is missing.
}
```

Neither `async_redux` nor this plugin depend on package `equatable`. Its classes are
recognized by name.

The inherited fields must be in `props` too. If a superclass or mixin implements
`props`, add `...super.props` instead. If a class declares fields but not `props`, so
that it inherits a `props` that doesn't have them, the warning is shown on the class
name. Abstract classes that don't declare `props` are not reported, since their
subclasses must list the inherited fields.

Quick fix: add the missing fields to `props`, and `...super.props` at the start of
the list for missing inherited fields, when a superclass implements `props`. It never
changes existing code, and is only offered when `props` returns a list literal that
is not `const`.

---

### extend_base_action

An info for an action that extends `ReduxAction<AppState>` directly. The AsyncRedux
docs recommend a base action, usually named `AppAction`, that all your actions extend.
It removes the repeated `ReduxAction<AppState>`, and is the place for the getters,
selectors, typed dependencies and `wrapError` logic that all actions share:

```dart
abstract class AppAction extends ReduxAction<AppState> {
  User get user => state.user;
}

class LoadUser extends ReduxAction<AppState> { ... } // Info
class LoadUser extends AppAction { ... }             // OK
```

Not reported for abstract classes, like the base action itself, or for actions with a
generic state, like `class MyAction<St> extends ReduxAction<St>`, which can't extend
an app's base action. Not reported in tests, which often declare small actions that
extend `ReduxAction` directly.

If your package doesn't have a base action, create one. Classes that extend
`ReduxAction` directly are also fine in a package with a small example. To turn off the
rule there, see [Turning rules on and off](#turning-rules-on-and-off).

Quick fix: extend the base action instead. The fix finds the abstract classes of your
package that extend `ReduxAction<AppState>` directly, and offers one fix for each, up
to 3, adding the import if needed.

---

### dependencies_cast_in_action

An info for a cast of `store.environment`, `store.dependencies` or
`store.configuration` inside an action. The docs recommend declaring a typed getter
for each one, once, in the base action:

```dart
abstract class AppAction extends ReduxAction<AppState> {
  Dependencies get dependencies => store.dependencies as Dependencies;
  Environment get environment => store.environment as Environment;
  Config get config => store.configuration as Config;
}

class LoadUser extends AppAction {
  Future<AppState?> reduce() async {
    var user = await (store.dependencies as Dependencies).api.loadUser(); // Info
    var user = await dependencies.api.loadUser();                         // OK
    ...
  }
}
```

Casts in abstract classes, like the base action, and in mixins, are not reported.
Neither are casts in tests, whose actions may not extend the base action.

---

### prefer_return_null

An info for a `reduce` that returns `state` unchanged. Return `null` instead, which
tells AsyncRedux that the state didn't change:

```dart
AppState? reduce() {
  if (state.user == null) return state; // Info
  if (state.user == null) return null;  // OK
  ...
}
```

Quick fix: return `null`. If `reduce` returns a non-nullable type, like `AppState`,
the fix also makes it nullable.

---

### stale_state_after_await

A warning for an async `reduce` that copies `state` (or `initialState`) to a local
variable before an `await`, and uses that variable after the `await` to build the
state it returns. The `state` getter always has the current state, but the variable
keeps the old one. If other actions change the state during the `await`, their
changes are lost:

```dart
Future<AppState?> reduce() async {
  var s = state;
  var user = await api.loadUser();
  return s.copy(user: user);     // Warning
  return state.copy(user: user); // OK
}
```

Uses that build the returned state are the ones in the `return`, and in other local
variables that end up in the `return`. Uses in a condition, like `if (s.user == null)`,
and inside an `await`, like `await api.load(s.id)`, are not reported. The order is the
source order, so an `await` inside an `if` counts for the code after the `if`, but not
for the `else` branch.

Quick fix: use `state` instead of the variable.

---

### after_throws

A warning for a `throw` or `rethrow` in the `after` method of an action, outside a
`try` that catches it. The `after` method must not throw. AsyncRedux throws its error
asynchronously, so it only shows up in the console, and can't be caught:

```dart
void after() {
  if (state.user == null) throw Exception('No user'); // Warning
}
```

A `catch` with an `on` type only counts when its type is related to the thrown type.
Throws inside closures are not reported.

---

### missing_super_in_mixin_override

An error for an action that uses an AsyncRedux mixin, and overrides a method that the
mixin implements without calling `super`. The mixin then silently stops working:

```dart
class LoadUser extends AppAction with NonReentrant {
  bool abortDispatch() => state.user != null; // Error: NonReentrant doesn't work

  bool abortDispatch() {                       // OK
    if (super.abortDispatch()) return true;
    return state.user != null;
  }
  ...
}
```

This checks `abortDispatch` (implemented by `NonReentrant`, `Throttle`, `Fresh`,
`OptimisticCommand` and `UnlimitedRetryCheckInternet`), `wrapReduce` (`Retry`,
`Debounce`, `Polling` and `UnlimitedRetryCheckInternet`), and `reduce`
(`OptimisticCommand`, `OptimisticSync`, `OptimisticSyncWithPush` and `ServerPush`).
The mixin can also come from a superclass, like the base action. The mixins' `before`
and `after` methods have `@mustCallSuper`, so the analyzer already reports them, as
`must_call_super`.

---

### user_exception_outside_action

A warning for a `UserException` thrown in a widget, in a `State`, in a `VmFactory`, in a
view-model, or in the `after` method of an action, where AsyncRedux can't catch it. A
`UserException` is only shown to the user when it's thrown from the `before` or `reduce`
methods of an action:

```dart
ElevatedButton(
  onPressed: () => throw UserException('Invalid'),                      // Warning
  onPressed: () => context.dispatch(UserExceptionAction('Invalid')),    // OK
)
```

Throws caught by a `try` in the same function, and throws inside closures in `after`,
are not reported.

Quick fix: dispatch a `UserExceptionAction` instead, with `context.dispatch` in
widgets, and `dispatch` in actions and factories. It's offered when the `throw` is a
statement, or the body of an arrow function. Note the code after it then keeps
running.

---

### user_exception_without_cause

An info for a `UserException` that replaces another error without keeping it, with
`addCause`. This checks `UserException`s created in a `catch` clause, in the
`wrapError` method of an action or persistor, and in `GlobalErrorObserver.observe`:

```dart
try {
  return state.copy(counter: int.parse(text));
} catch (error) {
  throw UserException('Please enter a valid number');                 // Info
  throw UserException('Please enter a valid number').addCause(error); // OK
}
```

Not reported when the `UserException` is created inside a closure, when it's itself
the cause of another one, or when the `catch` clause or method calls `addCause`
somewhere else, like on a variable. Not reported in tests, where fakes often replace
errors on purpose.

Quick fix: add `.addCause(error)`, using the name of the caught error. In
`on FormatException { ... }`, the fix also adds `catch (error)`.

---

### dispatch_in_global_error_observer

A warning for a dispatch inside a `GlobalErrorObserver`. The store is still processing
the action that failed, so the observer must not dispatch. To show the error to the
user, return a `UserException` instead:

```dart
class AppErrorObserver extends GlobalErrorObserver<AppState> {
  Object? observe() {
    store.dispatch(UserExceptionAction('Failed'));         // Warning
    return UserException('Failed').addCause(error);        // OK
  }
}
```

Dispatches inside closures that run later, like `Future.microtask(() => ...)`, are not
reported.

---

### throw_in_global_error_observer

An info for a `throw` in `GlobalErrorObserver.observe`. AsyncRedux uses the thrown
error just like a returned one, but the docs recommend returning it:

```dart
Object? observe() {
  throw UserException('Failed').addCause(error);  // Info
  return UserException('Failed').addCause(error); // OK
}
```

Throws inside closures, and throws caught by a `try` in `observe`, are not reported.

Quick fix: change `throw` to `return`.

---

### retry_without_non_reentrant

An info for an action with the `Retry` mixin, but not `NonReentrant`. The AsyncRedux
docs recommend adding `NonReentrant` to most actions that use `Retry`, so that a new
dispatch doesn't run while the previous one is still retrying:

```dart
class LoadText extends AppAction with Retry { ... }               // Info
class LoadText extends AppAction with Retry, NonReentrant { ... } // OK
```

Not reported when the action also has `Sequential`, or a mixin that can't be combined
with `NonReentrant` or `Retry`, like `Throttle`, `Fresh` or `Polling`, or when it
overrides `abortDispatch` itself. Not reported in tests, which often test `Retry`
alone.

Quick fix: add the `NonReentrant` mixin.

---

### dispatch_and_wait_unlimited_retries

A warning for `dispatchAndWait` or `dispatchAndWaitAll` with an action that uses the
`UnlimitedRetries` or `UnlimitedRetryCheckInternet` mixin. The action retries for as
long as it fails, so the future may never complete:

```dart
class LoadText extends AppAction with Retry, UnlimitedRetries { ... }

await dispatchAndWait(LoadText()); // Warning
dispatch(LoadText());              // OK
```

This also catches a `RefreshIndicator` whose spinner may never stop, with
`onRefresh: () => context.dispatchAndWait(LoadText())`.

Not reported in tests, where the action usually succeeds after a few retries, and a
test that never completes times out.

---

### async_mixin_in_sync_action

A warning for an action whose `reduce` is sync, but that uses a mixin meant for async
work: `CheckInternet`, `NoDialog`, `AbortWhenNoInternet`, `UnlimitedRetryCheckInternet`,
`NonReentrant`, `Retry` or `UnlimitedRetries`. A sync reducer does no network calls,
can't be dispatched again before it finishes, and usually fails again the same way
when retried. These mixins also make the action async, so it can't be dispatched with
`dispatchSync`:

```dart
// Warning on NonReentrant.
class Increment extends AppAction with NonReentrant {
  AppState? reduce() => state.copy(counter: state.counter + 1);
}

// OK.
class LoadText extends AppAction with NonReentrant {
  Future<AppState?> reduce() async { ... }
}
```

Not reported when the action overrides `before` or `wrapReduce` itself, since they may
do the async work, or in tests, which often use sync actions to test the mixins.

---

### sequential_deadlock

An error for an action with the `Sequential` mixin that waits for another action that uses
the same queue. An action with `Sequential` holds its queue until it finishes, so the
other action can only start after the first one finishes, and both wait for each other
forever:

```dart
class Parent extends AppAction with Sequential {
  Future<AppState?> reduce() async {
    await dispatchAndWait(Child()); // Error: Child also uses Sequential
    dispatch(Child());              // OK: Child runs after Parent finishes
    return null;
  }
}

class Child extends AppAction with Sequential { ... }
```

This checks waits with `dispatchAndWait`, `dispatchAndWaitAll`, `waitActionType`,
`waitAllActionTypes` and `waitAllActions`, that are awaited or returned, in the
action's own methods. Two actions use the same queue when neither overrides
`sequentialKeyParams`, when both return the same constant, or when both return
`runtimeType` and are of the same type. Keys that depend on fields are not checked.

Quick fix: use `dispatch` or `dispatchAll` instead, without waiting. It's only
offered when the result isn't used.

---

### sequential_before_super_not_first

An error for a `before` method, in an action with the `Sequential` mixin, whose first
statement is not `await super.before()`. Code before it runs as soon as the action is
dispatched, before the action gets its turn. An `await` before it can make the action lose
its position in the queue:

```dart
class SaveItem extends AppAction with Sequential {
  Future<void> before() async {
    showSpinner();          // Runs before the action's turn
    await super.before();   // Error: not the first statement
  }
}
```

Overrides that don't call `super.before()` at all are reported by the analyzer, as
`must_call_super`.

---

### sequential_after_super_not_in_finally

An info for an action with the `Sequential` mixin whose `after` method calls
`super.after()` outside a `finally` block. If the code before it throws, the queue is
never released, and the actions waiting in it never run:

```dart
void after() {
  hideSpinner();
  super.after(); // Info
}

void after() {
  try {
    hideSpinner();
  } finally {
    super.after(); // OK
  }
}
```

Not reported when `super.after()` is the first statement of `after`.

---

### polling_action_restarts_polling

A warning for a `createPollingAction` that creates the action with `Poll.start`,
`Poll.stop` or `Poll.runNowAndRestart`. The action dispatched on each tick must use
`Poll.once`, so that the ticks don't start, stop or restart the polling:

```dart
ReduxAction<AppState> createPollingAction() => LoadPrices(poll: Poll.start); // Warning
ReduxAction<AppState> createPollingAction() => LoadPrices(poll: Poll.once);  // OK
```

Quick fix: use `Poll.once`.

---

### server_push_associated_action

An error for an `associatedAction`, in a `ServerPush` action, that doesn't return the type
of an action with the `OptimisticSyncWithPush` mixin. It must return the type of the
action that the push updates. Otherwise, the key of the push never matches the key of that
action:

```dart
class PushLike extends AppAction with ServerPush {
  Type associatedAction() => PushLike;   // Error: doesn't use OptimisticSyncWithPush
  Type associatedAction() => ToggleLike; // OK
  ...
}
```

---

### internet_simulation_in_production

A warning for an override of `internetOnOffSimulation` that returns `true` or `false`,
in code under `lib`. It's meant for tests, and makes the action ignore the real
internet connection:

```dart
class LoadText extends AppAction with CheckInternet {
  bool? get internetOnOffSimulation => false; // Warning
  ...
}
```

To simulate the connection in tests, use `store.forceInternetOnOffSimulation`
instead. Files in the `test` directory are not checked.

---

### prefer_immutable_collections

An info for a field of type `List`, `Set` or `Map` in a class that holds state. The
AsyncRedux docs recommend `IList`, `ISet` and `IMap` of package
[fast_immutable_collections](https://pub.dev/packages/fast_immutable_collections),
which can't be changed after they're created:

```dart
@stateClass
class AppState {
  final List<User> users;  // Info
  final IList<User> users; // OK
  ...
}
```

Only the type of the field itself is checked, not its type arguments. Not reported in
tests.

The classes that hold state are:

- State classes, annotated with `@stateClass`, and the classes that extend, implement
  or mix them in.
- The store's state class, like `AppState`, when the file uses it as the state of an
  action or a store, like `ReduxAction<AppState>` or `Store<AppState>`, or imports a
  file of your package that does.
- The classes of your package that the classes above contain, like `User` in
  `final IList<User> users`, and the classes they extend or mix in.

Analyzer plugins see one file at a time. If `User` is declared in its own file, which
doesn't import `AppState`, the rule can't know that `User` is part of the state.
Annotate it with `@stateClass` to have it checked.

Quick fix: change the type, like `List<User>` to `IList<User>`, adding the import if
needed. It's only offered when your package depends on `fast_immutable_collections`,
and the field declares its type. It doesn't change the values assigned to the field,
like `[]`, which you then change to `const IList.empty()` or similar.

---

### non_state_object_in_state

A warning for a field, in a class that holds state, that holds an object that is not
state:

- A `Future`, `Stream`, `StreamController`, `StreamSubscription` or `Timer`. Keep
  these in the store props, with `setProp` and `prop`, and dispose of them with
  `disposeProps`.
- A `BuildContext` or a `GlobalKey`. Keep these out of the state, like in a widget.
- A Flutter `ChangeNotifier`, like `TextEditingController`, `ScrollController` or
  `FocusNode`, or an `AnimationController`. Keep these in the widget, and use an
  `Event` in the state to control them.

Subclasses and type arguments are checked too, like `List<Timer>`:

```dart
@stateClass
class AppState {
  final Timer? timer;                         // Warning
  final TextEditingController nameController; // Warning
  final List<StreamSubscription> listeners;   // Warning
  final void Function(Timer) onTick;          // OK, holds a function
  ...
}
```

The classes that hold state are:

- State classes, annotated with `@stateClass`, and the classes that extend, implement
  or mix them in.
- The store's state class, like `AppState`, when the file uses it as the state of an
  action or a store, like `ReduxAction<AppState>` or `Store<AppState>`, or imports a
  file of your package that does.
- The classes of your package that the classes above contain, like `User` in
  `final IList<User> users`, and the classes they extend or mix in.

Analyzer plugins see one file at a time. If `User` is declared in its own file, which
doesn't import `AppState`, the rule can't know that `User` is part of the state.
Annotate it with `@stateClass` to have it checked.

---

### missing_initial_state

An info for a `Store` whose initial state is not created with
`AppState.initialState()`, which is how the AsyncRedux docs create it. It's reported
when the state class doesn't have a static `initialState()` method, or when the store
calls a constructor of the state class directly:

```dart
class AppState {
  static AppState initialState() => AppState(user: null);
  ...
}

var store = Store<AppState>(initialState: AppState(user: null));    // Info
var store = Store<AppState>(initialState: AppState.initialState()); // OK
```

A constructor named `initialState`, like `factory AppState.initialState()`, works too.
Other expressions, like a function that loads the state, are fine when the class has
an `initialState()` method. Not reported for states that are not classes of your
package, like `Store<int>`, or in tests, which often create the store with a specific
state.

---

### event_name_suffix

An info for a field of type `Evt` or `Event` whose name doesn't end with `Evt`. The
docs name events like `clearTextEvt`, so that they are easy to tell apart from the
other fields of the state:

```dart
class AppState {
  final Evt clearText;    // Info
  final Evt clearTextEvt; // OK
  ...
}
```

This checks the fields of all classes, since events are also kept in view-models and
widgets. The name `evt` is accepted. A field that overrides an inherited member is not
reported, since its name comes from the supertype.

Quick fix: rename the field, in all files of the package. A name ending with `Event`
changes to end with `Evt`, like `clearTextEvent` to `clearTextEvt`. The named
parameters of the same class with the same name, like `this.clearText` in the
constructor and `clearText` in `copy()`, are renamed too, so that the named arguments
keep matching.

---

### event_not_spent_initially

A warning for an event created with `Evt()` or `Evt(value)` for the initial state.
Initial events must be spent, with `Evt.spent()`, or they fire as soon as the app
starts:

```dart
static AppState initialState() => AppState(
  clearTextEvt: Evt(),       // Warning
  clearTextEvt: Evt.spent(), // OK
);
```

This checks `initialState()` methods, functions and constructors, the `initialState:`
argument of a `Store`, constructors (like `clearTextEvt = clearTextEvt ?? Evt()`), and
the initializers of instance fields. Events created inside closures are not reported.
Not reported in tests, which may create a state with an event on purpose, to test how
the widgets react to it.

Quick fix: use `Evt.spent()`. When the type of the event is inferred from its value,
like in `Evt(42)`, the fix writes it explicitly, as in `Evt<int>.spent()`.

---

### event_persisted

A warning for an event field used in a `toJson` or `toMap` method, or in the
`persistDifference` or `saveInitialState` method of a `Persistor`. Events must not be
persisted:

```dart
Map<String, dynamic> toJson() => {
  'counter': counter,
  'clearTextEvt': clearTextEvt.isSpent, // Warning
};
```

When the state is read back, create its events with `Evt.spent()`.

---

### dispatch_in_build

A warning for a dispatch that runs while the widget builds. It dispatches again on
every rebuild, and can loop forever when the action changes the state. Dispatch from a
callback, from `initState`, or from `StoreConnector.onInit` instead:

```dart
Widget build(BuildContext context) {
  context.dispatch(LoadUser());                                      // Warning
  return ElevatedButton(onPressed: () => context.dispatch(LoadUser())); // OK
}
```

This checks `build` methods and builder closures, like
`Builder(builder: (context) => ...)`. Dispatches in callbacks, in closures that run
later, like `addPostFrameCallback`, and in other closures, like `items.forEach(...)`,
are not reported.

---

### prefer_dispatch_without_context

An info for `context.dispatch(...)` in a `StatelessWidget`, or in the `State` of a
`StatefulWidget`, where `dispatch(...)` also works. The same for `dispatchAndWait`,
`dispatchAll`, `dispatchAndWaitAll` and `dispatchSync`:

```dart
class MyWidget extends StatelessWidget {
  Widget build(BuildContext context) => ElevatedButton(
    onPressed: () => context.dispatch(Increment()), // Info
    onLongPress: () => dispatch(Increment()),       // OK
  );
}
```

Dispatching without the `context` needs a single `StoreProvider` in the app, which is
almost always the case. Not reported in other classes, in static methods, or when the
class, the library or the function declares its own `dispatch`. Not reported in tests
either, which may create more than one `StoreProvider`.

To dispatch with the `context` instead, turn this rule off and turn on the opt-in
[prefer_dispatch_with_context](#prefer_dispatch_with_context).

Quick fix: remove `context.`.

---

### context_read_in_build

A warning for `context.read()` while the widget builds. It reads the state once, and
the widget doesn't rebuild when the state changes. Use `context.select` instead, and
keep `context.read()` for callbacks and `initState`:

```dart
Widget build(BuildContext context) {
  var name = context.read().user.name;                 // Warning
  var name = context.select((st) => st.user.name);     // OK
  ...
}
```

Quick fix: convert to `context.select(...)`, like the quick fix of
[avoid_context_state](#avoid_context_state).

`context.read()` comes from the `BuildContext` extension recommended by AsyncRedux. It's
recognized by its name, when the extension's library imports `async_redux`. This way, the
`read` of packages like `provider` is not reported. The `getRead` method of AsyncRedux is
also recognized.

---

### refresh_indicator_without_wait

A warning for a dispatch in the `onRefresh` callback of a `RefreshIndicator` that the
callback doesn't wait for. The spinner then disappears before the data loads:

```dart
RefreshIndicator(
  onRefresh: () async { context.dispatch(LoadItems()); },       // Warning
  onRefresh: () => context.dispatchAndWait(LoadItems()),        // OK
  ...
)
```

This reports dispatches whose result is discarded, and every `dispatchAll`, whose
result can't be waited for. It also checks methods and functions declared in the same
file and passed as the callback, like `onRefresh: _refresh`.

Quick fix: use `dispatchAndWait` (or `dispatchAndWaitAll`), and `await` it, or
`return` it when it's the last statement of a callback that is not async.

---

### then_on_dispatch_and_wait

A warning for `.then(...)` on the future returned by `dispatchAndWait`. The future
completes even when the action fails, so the callback always runs:

```dart
dispatchAndWait(SaveUser()).then((_) => Navigator.pop(context));               // Warning
dispatchAndWait(SaveUser()).thenIfCompletedOk((_) => Navigator.pop(context));  // OK
```

Use `thenIfCompletedOk` and `thenIfCompletedFailed`, or check `status.isCompletedOk`.

Quick fix: replace `then` with `thenIfCompletedOk`. It's offered when the result of
`then` is not used, since `thenIfCompletedOk` returns the `ActionStatus`.

---

### user_exception_dialog_placement

An error for a `UserExceptionDialog` that is not below both the `StoreProvider` and the
`MaterialApp` (or `CupertinoApp`). Above the `StoreProvider`, it can't read the errors
from the store, and above the `MaterialApp`, it can't show dialogs:

```dart
StoreProvider<AppState>(
  store: store,
  child: UserExceptionDialog<AppState>(              // Error
    child: MaterialApp(home: HomePage()),
  ),
);

StoreProvider<AppState>(
  store: store,
  child: MaterialApp(
    home: UserExceptionDialog<AppState>(              // OK
      child: HomePage(),
    ),
  ),
);
```

In the `builder` of the `MaterialApp`, the dialog is above the app's `Navigator`. It
then needs the `navigatorKey` of the `MaterialApp`, also set with
`NavigateAction.setNavigatorKey`, and can't use `useLocalContext: true`:

```dart
MaterialApp(
  builder: (context, child) => UserExceptionDialog<AppState>(child: child!),  // Error
);

MaterialApp(
  navigatorKey: navigatorKey,
  builder: (context, child) => UserExceptionDialog<AppState>(child: child!),  // OK
);
```

Only checks what's in the same file. The `router` constructors, like
`MaterialApp.router`, are not checked for the `navigatorKey`, since the key is set in
the router.

---

### navigator_key_not_set

A warning, in a file that calls `NavigateAction.setNavigatorKey(key)`, for a
`MaterialApp` (or `CupertinoApp`) without `navigatorKey: key`. `NavigateAction` needs
the same key in both places:

```dart
final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  NavigateAction.setNavigatorKey(navigatorKey);
  ...
}

MaterialApp(home: HomePage());                                // Warning
MaterialApp(navigatorKey: otherKey, home: HomePage());        // Warning
MaterialApp(navigatorKey: navigatorKey, home: HomePage());    // OK
```

Keys are compared when they are variables, getters, or new `GlobalKey`s. Other keys,
like `keys[0]`, are not reported. `navigatorKey: NavigateAction.navigatorKey` is
always accepted. The `router` constructors, like `MaterialApp.router`, are not
checked, since they don't have a `navigatorKey`. Not reported in tests, where a file
often creates many apps, and only some of them navigate.

Quick fix: add `navigatorKey: key` to the `MaterialApp`. Only offered when the key
passed to `setNavigatorKey` is a variable or a getter.

---

### debug_observer_in_release

An info for `ConsoleActionObserver`, `Log.printer` or `DefaultModelObserver` passed to
the `Store` in release builds. They are meant for development only:

```dart
Store<AppState>(
  actionObservers: [ConsoleActionObserver()],                       // Info
  actionObservers: kReleaseMode ? null : [ConsoleActionObserver()], // OK
  actionObservers: [if (kDebugMode) ConsoleActionObserver()],       // OK
);
```

Not reported inside an `if` or a conditional expression, with any condition, since the
app may check the environment in other ways. Not reported in tests.

---

### implements_persistor

An error for a class that implements `Persistor`, instead of extending it. The store
relies on code inherited from `Persistor`, like the error queue behind `addError`:

```dart
class MyPersistor implements Persistor<AppState> { ... } // Error
class MyPersistor extends Persistor<AppState> { ... }    // OK
```

This also reports a class that implements another persistor, like
`implements MyPersistor`, unless it also extends one. Not reported in tests, where
mocks like `class MockPersistor extends Mock implements Persistor<AppState>` are common.

Quick fix: change `implements` to `extends`. It's not offered when the class already
extends another class.

---

### throw_in_read_state

A warning for a `throw` or `rethrow` in the `readState` method of a `Persistor`.
`readState` runs when the app starts, before the store exists, so the error can't be
shown to the user. Instead, call `addError` and return `null`. The store processes the
error when it's created, and shows it to the user if it's a `UserException`:

```dart
Future<AppState?> readState() async {
  try {
    return await _read();
  } on FormatException catch (error) {
    await deleteState();
    throw UserException('Could not read your data.');                 // Warning
    addError(UserException('Could not read your data.').addCause(error)); // OK
    return null;
  }
}
```

Throws inside closures, and throws caught by a `try` in `readState`, are not reported.
Not reported in tests, where a persistor may throw on purpose.

Quick fix: replace `throw error;` with `addError(error);` and `return null;`. For
`rethrow`, adds the error and stack trace of the `catch` clause. Only offered when
`readState` is `async`.

---

### initial_state_not_saved

An info for the initial state created when `persistor.readState()` returns `null`, when
it's not saved with `persistor.saveInitialState(...)`. The store considers its initial
state already persisted. So it's not saved until the state changes, and then
`persistDifference` receives it as the `lastPersistedState`:

```dart
var initialState = await persistor.readState();

if (initialState == null) {
  initialState = AppState.initialState();             // Info, without the next line
  await persistor.saveInitialState(initialState);
}

var store = Store<AppState>(initialState: initialState, persistor: persistor);
```

This recognizes the result of `await persistor.readState()` kept in a variable, and
then replaced in `if (initialState == null) { ... }`, with `initialState ??= ...`, or
used in `initialState ?? ...`. It's not reported when the same function calls
`saveInitialState` or `persistDifference`, or inside a `Persistor`, like a decorator
that reads the state of another persistor. Not reported in tests, which often create
the store and the persistor differently from the app.

Quick fix: add `await persistor.saveInitialState(initialState);` after the line that
creates the state, changing `initialState ??= ...` into an `if`. Only offered when the
state is kept in a local variable, and the persistor is a variable.

---

### timer_or_stream_not_in_props

An info for an action that creates a `Timer`, or listens to a `Stream`, without saving
the `Timer` or the `StreamSubscription` in the store props with `setProp`. It then
can't be cancelled with `disposeProp(key)`, or with `store.disposeProps()` when the app
shuts down or a test ends:

```dart
class StartPolling extends AppAction {
  AppState? reduce() {
    var timer = Timer.periodic(Duration(seconds: 5), (_) => dispatch(LoadPrices()));
    setProp('pricesTimer', timer); // Without this line: Info
    return null;
  }
}
```

A `Timer` or `StreamSubscription` kept in a variable or field is fine when the action
passes it to `setProp`, or cancels it, like `timer.cancel()` in `after()`. It's also
fine when it's returned, or passed to other code, which may keep it. `Timer.run(...)`
is not reported, since it doesn't return a `Timer`. This also checks mixins on
actions.

---

### expect_without_waiting

A warning, in files under `test/`, for `store.dispatch(...)` of an async action,
followed by an `expect` that reads `store.state`, without waiting in between. The
`expect` then checks the state before the action finishes:

```dart
store.dispatch(LoadUser());                 // Warning
await store.dispatchAndWait(LoadUser());    // OK
expect(store.state.user.name, 'Mary');
```

Any `await` counts as waiting, like `await store.waitActionType(LoadUser)`, and so do
the `elapse`, `flushMicrotasks` and `flushTimers` calls of `fakeAsync`. An `expect`
inside a closure is not checked, since it may run later. It's not reported when the
test later waits and checks `store.state` again, since the first `expect` then checks
the state while the action runs on purpose:

```dart
store.dispatch(LoadUser());
expect(store.state.user, isNull);           // OK: the state didn't change yet.
await store.waitActionType(LoadUser);
expect(store.state.user.name, 'Mary');
```

Quick fix: replace `store.dispatch(...)` with `await store.dispatchAndWait(...)`. If
the enclosing function is not `async`, like the body of a `test`, also makes it
`async`. Not offered when that function declares a return type other than `void`.

---

### vm_create_from_reused_factory

An error for `Vm.createFrom` called with a factory that was already passed to
`Vm.createFrom`. It can only be called once per factory instance, and then throws:

```dart
var factory = MyFactory();
var vm1 = Vm.createFrom(store, factory);
var vm2 = Vm.createFrom(store, factory);     // Error
var vm3 = Vm.createFrom(store, MyFactory()); // OK
```

Only factories kept in variables are checked. A variable that is never assigned holds
the same factory everywhere, so this also reports two tests that use the same factory.
A variable that is assigned, like in `setUp`, is only checked between two calls in the
same function, with no assignment between them. Calls in different branches of an
`if`, `?:` or `switch` are not reported.

---

### action_status_details_in_production

An info for `hasFinishedMethodBefore`, `hasFinishedMethodReduce` or
`hasFinishedMethodAfter` of an `ActionStatus`, in code under `lib/`. They are meant for
tests and debugging. In the app, use `isCompleted`, `isCompletedOk` or
`isCompletedFailed`:

```dart
var status = await dispatchAndWait(SaveUser());
if (status.hasFinishedMethodReduce) ... // Info
if (status.isCompletedOk) ...           // OK
```

Not reported in tests.

---

### action_name_ends_with_action

An [opt-in](#turning-rules-on-and-off) warning for an action whose name doesn't end with
`Action`, like `LoadUser` instead of `LoadUserAction`.

There are 3 ways to name actions, and one rule for each. Turn on only one of them:

| Rule                                      | Example           |
|-------------------------------------------|-------------------|
| `action_name_ends_with_action`            | `LoadUserAction`  |
| `action_name_ends_with_underscore_action` | `LoadUser_Action` |
| `action_name_without_action`              | `LoadUser`        |

Only classes that can be dispatched are checked. Abstract classes, like the base
action, and mixins are not.

Quick fix: rename the action, like `LoadUser` to `LoadUserAction`. The fix renames it in
all files of the package, like your IDE's rename refactoring does. It's not offered when
the new name is already used in the file. It doesn't rename the action in other packages
that use it, like an `example` directory with its own `pubspec.yaml`.

---

### action_name_ends_with_underscore_action

An [opt-in](#turning-rules-on-and-off) warning for an action whose name doesn't end with
`_Action`, like `LoadUser` instead of `LoadUser_Action`.

There are 3 ways to name actions, and one rule for each. Turn on only one of them:

| Rule                                      | Example           |
|-------------------------------------------|-------------------|
| `action_name_ends_with_action`            | `LoadUserAction`  |
| `action_name_ends_with_underscore_action` | `LoadUser_Action` |
| `action_name_without_action`              | `LoadUser`        |

Only classes that can be dispatched are checked. Abstract classes, like the base
action, and mixins are not.

Quick fix: rename the action, like `LoadUser` to `LoadUser_Action`. The fix renames it in
all files of the package, like your IDE's rename refactoring does. It's not offered when
the new name is already used in the file. It doesn't rename the action in other packages
that use it, like an `example` directory with its own `pubspec.yaml`.

---

### action_name_without_action

An [opt-in](#turning-rules-on-and-off) warning for an action whose name ends with
`Action`, like `LoadUserAction` instead of `LoadUser`.

There are 3 ways to name actions, and one rule for each. Turn on only one of them:

| Rule                                      | Example           |
|-------------------------------------------|-------------------|
| `action_name_ends_with_action`            | `LoadUserAction`  |
| `action_name_ends_with_underscore_action` | `LoadUser_Action` |
| `action_name_without_action`              | `LoadUser`        |

Names that only contain `Action` elsewhere, like `ActionLog`, are fine.

Only classes that can be dispatched are checked. Abstract classes, like the base
action, and mixins are not.

Quick fix: rename the action, like `LoadUserAction` to `LoadUser`. The fix renames it in
all files of the package, like your IDE's rename refactoring does. It's not offered when
the new name is already used in the file. It doesn't rename the action in other packages
that use it, like an `example` directory with its own `pubspec.yaml`.

---

### action_file_name_ends_with_action

An [opt-in](#turning-rules-on-and-off) warning for a file that declares actions, but whose
name doesn't end with `_action`, like `load_user.dart` instead of `load_user_action.dart`.

There are 2 ways to name the files that declare actions, and one rule for each. Turn on
only one of them:

| Rule                                  | Example                 |
|---------------------------------------|-------------------------|
| `action_file_name_ends_with_action`   | `load_user_action.dart` |
| `action_file_name_starts_with_action` | `ACTION_load_user.dart` |

A file with more than one action can have any name that follows the style, like
`user_action.dart`. The warning is shown on the first action of the file. Files without
actions, files in the `test` directory, and files whose names end with `_test` are not
checked.

There's no quick fix, because analyzer plugins can't rename files. The message
suggests a name, based on the action when the file has only one, like
`load_user_action.dart` for `LoadUser`. Rename the file with your IDE, which also updates
the imports.

---

### action_file_name_starts_with_action

An [opt-in](#turning-rules-on-and-off) warning for a file that declares actions, but whose
name doesn't start with `ACTION_`, like `load_user.dart` instead of
`ACTION_load_user.dart`.

There are 2 ways to name the files that declare actions, and one rule for each. Turn on
only one of them:

| Rule                                  | Example                 |
|---------------------------------------|-------------------------|
| `action_file_name_ends_with_action`   | `load_user_action.dart` |
| `action_file_name_starts_with_action` | `ACTION_load_user.dart` |

A file with more than one action can have any name that follows the style, like
`ACTION_user.dart`. The warning is shown on the first action of the file. Files without
actions, files in the `test` directory, and files whose names end with `_test` are not
checked.

There's no quick fix, because analyzer plugins can't rename files. The message
suggests a name, based on the action when the file has only one, like
`ACTION_load_user.dart` for `LoadUser`. Rename the file with your IDE, which also updates
the imports.

---

### prefer_dispatch_with_context

An [opt-in](#turning-rules-on-and-off) info for `dispatch(...)` in a widget, where
`context.dispatch(...)` also works. It's the opposite of
[prefer_dispatch_without_context](#prefer_dispatch_without_context).

Turn off `prefer_dispatch_without_context` when you turn it on:

```yaml
plugins:
  async_redux_lints:
    version: ^1.0.0
    diagnostics:
      prefer_dispatch_without_context: false
      prefer_dispatch_with_context: true
```

It's only reported where `context` is a `BuildContext`: anywhere in a `State`, and in a
`StatelessWidget` only in `build`, or in methods and closures with a
`BuildContext context` parameter.

Quick fix: add `context.`.

---

### avoid_abort_dispatch

An [opt-in](#turning-rules-on-and-off) info for every override of `abortDispatch`. The
AsyncRedux docs call it "a power feature that you may not need". Most actions should use a
mixin instead, like `NonReentrant`, `Throttle`, `Fresh`, `Retry` or `Debounce`.

Turn it on to make each override deliberate, and add an `// ignore` comment to the
overrides you really need. Not reported in tests.

---

### avoid_wrap_reduce

An [opt-in](#turning-rules-on-and-off) info for every override of `wrapReduce`. The
AsyncRedux docs call it "a power feature that you may not need". Most actions should use a
mixin instead, like `NonReentrant`, `Throttle`, `Fresh`, `Retry` or `Debounce`.

Turn it on to make each override deliberate, and add an `// ignore` comment to the
overrides you really need. Not reported in tests.

---

### global_error_observer_without_env

An [opt-in](#turning-rules-on-and-off) info for a `Store` created with a
`globalErrorObserver`, but no `environment`. The AsyncRedux docs suggest passing both, so
that the observer can handle errors differently in production, staging and tests:

```dart
var store = Store<AppState>(
  initialState: AppState.initialState(),
  globalErrorObserver: (store) => AppErrorObserver.newInstance(store),
  environment: Environment.production, // Without it: Info
);
```

Not reported in tests.

---

### missing_key_params

An [opt-in](#turning-rules-on-and-off) info for an action with fields that uses a mixin
with a key, but doesn't override the method that creates the key. By default, the key
doesn't depend on the fields, so all instances of the action share it. For example,
`LoadUserCart('A')` then blocks `LoadUserCart('B')`:

```dart
class LoadUserCart extends AppAction with NonReentrant {
  final String userId;
  LoadUserCart(this.userId);

  Object? nonReentrantKeyParams() => userId; // Without it: Info
  ...
}
```

| Mixin                                      | Key method                |
|--------------------------------------------|---------------------------|
| `NonReentrant`, `OptimisticCommand`        | `nonReentrantKeyParams`   |
| `Fresh`                                    | `freshKeyParams`          |
| `Throttle`, `Debounce`                     | `lockBuilder`             |
| `Polling`                                  | `pollingKeyParams`        |
| `Sequential`                               | `sequentialKeyParams`     |
| `OptimisticSync`, `OptimisticSyncWithPush` | `optimisticSyncKeyParams` |

Overriding the `compute...Key` method of the mixin also counts. Fields that override a
getter, like the `poll` field of `Polling`, don't count. It's opt-in, since sharing the
key is often intended.

---

### route_in_state

An [opt-in](#turning-rules-on-and-off) info for a field named `currentRoute`, `routeName`
or `currentRouteName`, in a class that holds state. The AsyncRedux docs recommend getting
the current route with `NavigateAction.getCurrentNavigatorRouteName(context)`, instead of
keeping it in the state. It's opt-in, since it only looks at the name.
Not reported in tests.

The classes that hold state are:

- State classes, annotated with `@stateClass`, and the classes that extend, implement
  or mix them in.
- The store's state class, like `AppState`, when the file uses it as the state of an
  action or a store, like `ReduxAction<AppState>` or `Store<AppState>`, or imports a
  file of your package that does.
- The classes of your package that the classes above contain, like `User` in
  `final IList<User> users`, and the classes they extend or mix in.

Analyzer plugins see one file at a time. If `User` is declared in its own file, which
doesn't import `AppState`, the rule can't know that `User` is part of the state.
Annotate it with `@stateClass` to have it checked.

---

### action_without_to_string

An [opt-in](#turning-rules-on-and-off) info for an action with fields that doesn't
override `toString()`. The logs from `ConsoleActionObserver` then only show the action
type, like `Action LoadUser`, and not which user it loads:

```dart
class LoadUser extends AppAction { // Info, without the toString() below
  final String userId;
  LoadUser(this.userId);

  @override
  String toString() => '${super.toString()}(userId: $userId)';
  ...
}
```

The fields inherited from your own classes and mixins count, and so does a `toString()`
inherited from them, like one in the base action. The fields and `toString()` of
AsyncRedux don't. It's opt-in, since not every app logs its actions.
Not reported in tests.

Quick fix: override `toString()` with all the fields, as in the example above.
