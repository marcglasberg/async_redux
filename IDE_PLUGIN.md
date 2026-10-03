# AsyncRedux IntelliJ Plugin: Feature Ideas

Most of these features target mistakes that AsyncRedux today only reports at
runtime, or rules that are too large to keep in your head.

## Writing code

### 1. "New AsyncRedux Action" wizard

A dialog that asks for:

- the action name
- One of 2 options on how to name the action: like `SaveUser_Action.dart` or
  `SaveUserAction.dart`.
- sync or async
- which base action to extend (detected from the project)
- which mixins to add
- if add the class in the currently open file, or create a new file in the same dir
- One of 2 options on how to name the file: like `save_user_action.dart` or
  `ACTION_save_user.dart`.

Live templates `act` (sync action) and `actasync` (async action).

### 2. "Add mixin…" intention, plus a compatibility inspection

Alt+Enter on an action class opens a mixin picker. The compatibility matrix in
`mixin_compatibility.md` covers 16 mixins, and nobody remembers that `NonReentrant`
and `Throttle` can't be combined, or `Retry` and `Debounce`, or `Fresh` and
`NonReentrant`. The picker:

- greys out incompatible mixins and says why
- adds required mixins automatically (`NoDialog` needs `CheckInternet`,
  `UnlimitedRetries` needs `Retry`)
- stubs the methods each mixin needs, for example the ones `OptimisticSync` requires
- shows a warning for combinations with caveats, such as `Polling` with `Sequential`

The same data powers an inspection that flags bad combinations already in the code.

### 3. State class tooling

- Generates and updates `copy()`, `==` and `hashCode`, and `initialState()` when a
  field is added.
- An inspection warns when a field is missing from `copy()` or `copyWith()`.

## Catching runtime errors in the editor

### 4. Lifecycle signature inspections

These turn existing `StoreException`s into editor errors, each with a quick fix:

- `reduce()` declared as `FutureOr<St?>`, `Future<St>?` and similar
- `reduce()` returning a Future without `await` in all paths that don't return null.
- `before()` returning `FutureOr`
- `wrapReduce` returning `St` instead of `Future<St?>`
- `dispatchSync` called on an action that is async

### 5. Wait/fail API misuse

Checks the arguments passed to `isWaiting` and `isFailed` that can only accept:
A specific async ACTION, a specific async action TYPE, or a list with those. 

Checks the arguments passed to `exceptionFor` and `clearExceptionFor` that can only accept:
A specific async action TYPE, or a list with these.

### 6. Widget state access inspections

- Every `context.state`, which rebuilds the widget when any part of the state
  changes. In `build()`, the quick fix converts it to `context.select(...)`, one per
  field used. In callbacks such as `onPressed`, it converts it to `context.read()`.
- `context.state` in `initState`, which throws at runtime. The quick fix converts it
  to `context.read()`.
- `context.select` inside callbacks such as `onPressed`. The quick fix converts it
  to `context.read()`.
- A `Vm` field that is missing from `equals: [...]`, which leads to missed or
  extra rebuilds.

## Navigating and understanding the code

### 7. "Who writes this field?" on state fields

A gutter icon on each `AppState` field lists the actions whose `reduce()` changes
it, for example through `copy(field: ...)`. A related view shows which actions
dispatch which other actions. In large apps, "how did this state change?" is the
most common question.

## Runtime

### 8. Live "Redux Inspector" tool window

Connects to the running app through a VM service extension, fed by an action
observer and a state observer in debug mode. It shows:

- a timeline of dispatched actions, with their duration and errors
- a state diff for each action
- the actions currently running
- `UserException`s, and errors reported through `GlobalErrorObserver`
- persistence activity

Clicking an entry jumps to the action's source. Later it could add replay or
time-travel, using the undo/redo approach from the docs.

## Architecture

Don't put features 4–6 in the IntelliJ plugin. The Dart plugin's PSI has little
type information, because real type resolution comes from the Dart analysis server.
Build those inspections as a Dart analyzer plugin with `analysis_server_plugin`,
shipped next to `async_redux`. The inspections in features 2 and 3 can live there
too.

The analyzer plugin is a Dart package, not an IntelliJ plugin. Projects enable it in
`analysis_options.yaml`:

```yaml
plugins:
  async_redux_lints: ^1.0.0
```

The analysis server then loads it, and its diagnostics appear everywhere the
analysis server is used, from a single implementation:

- **IntelliJ and VS Code:** squiggly underlines and quick fixes, through the existing
  Dart support. No IntelliJ plugin is needed for this.
- **Command line, CI and AI agents:** the same diagnostics appear in `dart analyze`.

Tested with Dart 3.13.4 and Flutter 3.47.5, the command line has limits:

- `dart analyze <files>` reports the plugin's diagnostics, but `dart analyze` on a
  directory may finish before the plugin reports, and miss them. Passing the files
  explicitly works: `dart analyze $(git ls-files '*.dart')`.
- `flutter analyze` doesn't report them.
- `dart fix` doesn't apply plugin quick fixes. They are only available in the IDE.

So AI agents and CI need that `dart analyze` command, not `flutter analyze`.

Prefer `analysis_server_plugin` over `custom_lint`. With `custom_lint`, the IDE still
shows the diagnostics, but the command line needs a separate `dart run custom_lint`
step that CI and AI agents must remember to run.

The IntelliJ plugin can offer to add the analyzer plugin to `analysis_options.yaml`
when it detects an AsyncRedux project without it.

The IntelliJ plugin can focus on what only an IDE can do: the wizards (1–3), the
gutter icons (7) and the tool window (8).

Feature 8 could also be built as a Flutter DevTools extension. Both IntelliJ and
VS Code can show those inside the editor, so it would be written once.

## Where the code lives

**Analyzer plugin (features 4–6, and the inspections in 2 and 3):** a separate
package named `async_redux_lints`, in the `async_redux_lints/` directory of the
`async_redux` repo, published to pub.dev on its own.

- **Same repo:** the rules check `async_redux`'s API. Keeping them next to the
  library means a change to the API and the matching change to the rules can go in
  the same commit.
- **Separate package:** a plugin depends on `analyzer` and `analysis_server_plugin`.
  If `async_redux` itself were the plugin, every app using it would get those
  dependencies too. That causes version conflicts with packages that pin `analyzer`,
  such as `build_runner`, `freezed` and `json_serializable`. Also, analyzer plugins
  need Dart 3.10 or later, while `async_redux` supports Dart 3.5.
- **Publishing:** when `async_redux` is published, the `async_redux_lints/` folder
  is included in its archive (about 9 KB). Excluding it with a `.pubignore` doesn't
  work: pub also applies the parent's `.pubignore` when publishing
  `async_redux_lints`, which then hides all of its files.

The `async_redux` package and its `example/` directory both enable the plugin in their
`analysis_options.yaml`, with a relative `path`.

**IntelliJ plugin (features 1–3, 7 and 8):** the
`C:\Users\Marcelo\Documents\GitHub\marcelosdartplugin` repo.

Feature 4 is built entirely in the analyzer plugin. It needs no IntelliJ plugin code.
It is implemented in `async_redux_lints`, as the rules `reduce_return_type`,
`before_return_type`, `wrap_reduce_return_type`, `reduce_without_await` and
`dispatch_sync_async_action`.

Feature 5 is also built entirely in the analyzer plugin, as the rules
`wait_fail_invalid_argument` (arguments that throw at runtime) and
`wait_fail_never_matches` (arguments that are accepted, but never match an action).

Feature 6 is also built entirely in the analyzer plugin, as the rules
`avoid_context_state` (an info), `context_state_in_init_state` (an error),
`select_in_callback` (an error) and `vm_field_not_in_equals` (a warning).

The inspection of feature 2 is built in the analyzer plugin, as the rules
`incompatible_mixins` (combinations that fail an assertion at runtime) and
`polling_with_caveat_mixin` (`Polling` with `CheckInternet`, `AbortWhenNoInternet`,
`NonReentrant`, `Throttle`, `Fresh` or `Sequential` in the same action). Both are
errors. The mixin picker stays in the IntelliJ plugin.

The inspections of feature 3 are built in the analyzer plugin, as the rules
`copy_missing_field`, `state_class_missing_equality` and `equality_missing_field` (all
warnings). They check classes annotated with `@stateClass`, and their subclasses: the
`copy` and `copyWith` methods must handle all fields, and the class must override
`==` and `hashCode`, using all fields. Generating `copy()`, `==`, `hashCode` and
`initialState()` stays in the IntelliJ plugin.

## Suggested first release

Ship **2, 4 and 8** first. Each solves a problem that is hard to solve without
tooling: the mixin compatibility matrix, mistakes that only fail at runtime, and
seeing what happens at runtime.
