// ignore_for_file: always_declare_return_types, async_redux_lints/reduce_return_type
// ignore_for_file: async_redux_lints/before_return_type
// ignore_for_file: async_redux_lints/wrap_reduce_return_type
// ignore_for_file: async_redux_lints/reduce_without_await
// ignore_for_file: async_redux_lints/dispatch_sync_async_action
// ignore_for_file: async_redux_lints/incompatible_mixins
// ignore_for_file: async_redux_lints/polling_with_caveat_mixin
// ignore_for_file: async_redux_lints/wait_fail_invalid_argument
// ignore_for_file: async_redux_lints/wait_fail_never_matches
// ignore_for_file: async_redux_lints/avoid_context_state
// ignore_for_file: async_redux_lints/context_state_in_init_state
// ignore_for_file: async_redux_lints/context_in_dispose
// ignore_for_file: async_redux_lints/context_in_selector
// ignore_for_file: async_redux_lints/select_outside_build
// ignore_for_file: async_redux_lints/vm_field_not_in_equals
// ignore_for_file: async_redux_lints/copy_missing_field
// ignore_for_file: async_redux_lints/state_class_must_be_immutable
// ignore_for_file: async_redux_lints/state_class_missing_equality
// ignore_for_file: async_redux_lints/equality_missing_field
// ignore_for_file: async_redux_lints/equality_missing_inherited_field
// ignore_for_file: async_redux_lints/equatable_props_missing_field
// ignore_for_file: async_redux_lints/extend_base_action
// ignore_for_file: async_redux_lints/dependencies_cast_in_action
// ignore_for_file: async_redux_lints/prefer_return_null
// ignore_for_file: async_redux_lints/stale_state_after_await
// ignore_for_file: async_redux_lints/after_throws
// ignore_for_file: async_redux_lints/missing_super_in_mixin_override
// ignore_for_file: async_redux_lints/user_exception_outside_action
// ignore_for_file: async_redux_lints/user_exception_without_cause
// ignore_for_file: async_redux_lints/dispatch_in_global_error_observer
// ignore_for_file: async_redux_lints/throw_in_global_error_observer
// ignore_for_file: async_redux_lints/retry_without_non_reentrant
// ignore_for_file: async_redux_lints/dispatch_and_wait_unlimited_retries
// ignore_for_file: async_redux_lints/sequential_deadlock
// ignore_for_file: async_redux_lints/sequential_before_super_not_first
// ignore_for_file: async_redux_lints/sequential_after_super_not_in_finally
// ignore_for_file: async_redux_lints/polling_action_restarts_polling
// ignore_for_file: async_redux_lints/server_push_associated_action
// ignore_for_file: async_redux_lints/internet_simulation_in_production
// ignore_for_file: async_redux_lints/prefer_immutable_collections
// ignore_for_file: async_redux_lints/non_state_object_in_state
// ignore_for_file: async_redux_lints/missing_initial_state
// ignore_for_file: async_redux_lints/event_name_suffix
// ignore_for_file: async_redux_lints/event_not_spent_initially
// ignore_for_file: async_redux_lints/event_persisted
// ignore_for_file: async_redux_lints/dispatch_in_build
// ignore_for_file: async_redux_lints/prefer_dispatch_without_context
// ignore_for_file: async_redux_lints/context_read_in_build
// ignore_for_file: async_redux_lints/refresh_indicator_without_wait
// ignore_for_file: async_redux_lints/then_on_dispatch_and_wait
// ignore_for_file: async_redux_lints/stream_or_timer_in_widget
// ignore_for_file: async_redux_lints/user_exception_dialog_placement
// ignore_for_file: async_redux_lints/navigator_key_not_set
// ignore_for_file: async_redux_lints/debug_observer_in_release
// ignore_for_file: async_redux_lints/implements_persistor
// ignore_for_file: async_redux_lints/throw_in_read_state
// ignore_for_file: async_redux_lints/initial_state_not_saved
// ignore_for_file: async_redux_lints/timer_or_stream_not_in_props
// ignore_for_file: async_redux_lints/expect_without_waiting
// ignore_for_file: async_redux_lints/vm_create_from_reused_factory
// ignore_for_file: async_redux_lints/action_status_details_in_production
// ignore_for_file: async_redux_lints/action_name_ends_with_action
// ignore_for_file: async_redux_lints/action_name_ends_with_underscore_action
// ignore_for_file: async_redux_lints/action_name_without_action
// ignore_for_file: async_redux_lints/action_file_name_ends_with_action
// ignore_for_file: async_redux_lints/action_file_name_starts_with_action
// ignore_for_file: async_redux_lints/prefer_dispatch_with_context
// ignore_for_file: async_redux_lints/avoid_abort_dispatch
// ignore_for_file: async_redux_lints/avoid_wrap_reduce
// ignore_for_file: async_redux_lints/global_error_observer_without_env
// ignore_for_file: async_redux_lints/missing_key_params
// ignore_for_file: async_redux_lints/route_in_state
// ignore_for_file: async_redux_lints/action_without_to_string

// Demonstrates the diagnostics of the `async_redux_lints` analyzer plugin. Each
// diagnostic is marked with a comment right above the line it underlines: the rule
// name, then what the problem is (in parentheses, when needed), then a `Fix:` line
// that says what the quick fix changes. Each variant of a rule is shown separately.
//
// This file is not meant to run. Open it in the IDE to see the diagnostics, and
// press Alt+Enter on them to see the quick fixes. See async_redux_lints/README.md.
//
// Note: the example's `analysis_options.yaml` also enables some standard lints, like
// `always_declare_return_types`. A few of the mistakes below trigger those too.
import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

void main() => runApp(
      const MaterialApp(home: Text('Open this file in the IDE to see the lints.')),
    );

@stateClass
class User {
  final String name;
  final int age;

  User({required this.name, required this.age});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          age == other.age;

  @override
  int get hashCode => Object.hash(name, age);
}

@stateClass
class AppState {
  final int counter;
  final String name;
  final User user;
  final User? maybeUser;
  final Evt<int> evt;

  AppState({
    required this.counter,
    required this.name,
    required this.user,
    this.maybeUser,
    required this.evt,
  });

  AppState copy(
          {int? counter, String? name, User? user, User? maybeUser, Evt<int>? evt}) =>
      AppState(
        counter: counter ?? this.counter,
        name: name ?? this.name,
        user: user ?? this.user,
        maybeUser: maybeUser ?? this.maybeUser,
        evt: evt ?? this.evt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppState &&
          runtimeType == other.runtimeType &&
          counter == other.counter &&
          name == other.name &&
          user == other.user &&
          maybeUser == other.maybeUser &&
          evt == other.evt;

  @override
  int get hashCode => Object.hash(counter, name, user, maybeUser, evt);
}

extension BuildContextExtension on BuildContext {
  AppState get state => getState<AppState>();

  AppState read() => getRead<AppState>();

  R select<R>(R Function(AppState state) selector) => getSelect<AppState, R>(selector);

  R? event<R>(Evt<R> Function(AppState state) selector) =>
      getEvent<AppState, R>(selector);
}

/// The app's dependencies, which the store keeps in 'store.dependencies'.
class Dependencies {
  String get apiUrl => 'https://example.com';
}

/// The base action that all actions extend.
abstract class AppAction extends ReduxAction<AppState> {
  Dependencies get dependencies => store.dependencies as Dependencies;
}

/// A sync action.
class Increment extends AppAction {
  @override
  AppState reduce() => state.copy(counter: state.counter + 1);
}

/// An async action.
class LoadUser extends AppAction {
  @override
  Future<AppState?> reduce() async {
    var name = await fetchName();
    return state.copy(name: name);
  }
}

Future<String> fetchName() async => 'Mary';

Future<AppState?> fetchState() async => null;

void describe(Object? value) => print(value);

class ReduceReturnsFutureOr extends AppAction {
  @override
  // reduce_return_type
  // ('reduce' can't return 'FutureOr')
  // Fix: Will change the return type from 'FutureOr<AppState?>' to 'AppState?'.
  // Fix: Will change the return type from 'FutureOr<AppState?>' to 'Future<AppState?>',
  // and add 'async'.
  FutureOr<AppState?> reduce() => null;
}

class ReduceReturnsNullableFuture extends AppAction {
  @override
  // reduce_return_type
  // ('reduce' can't return a nullable Future)
  // Fix: Will change the return type from 'Future<AppState?>?' to 'AppState?'.
  // Fix: Will change the return type from 'Future<AppState?>?' to 'Future<AppState?>',
  // and add 'async'.
  Future<AppState?>? reduce() => null;
}

class ReduceWithoutReturnType extends AppAction {
  @override
  // reduce_return_type
  // (No return type, which Dart infers as FutureOr)
  // Fix: Will add the return type 'Future<AppState?>'.
  //
  // always_declare_return_types
  // ('reduce' has no return type)
  // Fix: Will add the return type 'Future<Null>'.
  reduce() async => null;
}

class BeforeReturnsFutureOr extends AppAction {
  @override
  // before_return_type
  // ('before' can't return 'FutureOr')
  // Fix: Will change the return type from 'FutureOr<void>' to 'Future<void>'.
  FutureOr<void> before() async {}

  @override
  AppState? reduce() => null;
}

class BeforeWithoutReturnType extends AppAction {
  @override
  // before_return_type
  // (No return type, which Dart infers as FutureOr)
  // Fix: Will add the return type 'Future<void>'.
  //
  // always_declare_return_types
  // ('before' has no return type)
  // Fix: Will add the return type 'Future<void>'.
  before() async {}

  @override
  AppState? reduce() => null;
}

class WrapReduceReturnsState extends AppAction {
  @override
  // wrap_reduce_return_type
  // ('wrapReduce' must return a Future, or AsyncRedux throws at runtime)
  // Fix: Will change the return type from 'AppState?' to 'Future<AppState?>', and add
  // 'async'.
  AppState? wrapReduce(Reducer<AppState> reduce) => null;

  @override
  AppState? reduce() => null;
}

class WrapReduceReturnsFutureOr extends AppAction {
  @override
  // wrap_reduce_return_type
  // ('wrapReduce' can't return 'FutureOr', or AsyncRedux never calls it)
  // Fix: Will change the return type from 'FutureOr<AppState?>' to 'Future<AppState?>',
  // and add 'async'.
  FutureOr<AppState?> wrapReduce(Reducer<AppState> reduce) => null;

  @override
  AppState? reduce() => null;
}

class ReturnsBeforeAwait extends AppAction {
  @override
  Future<AppState?> reduce() async {
    if (state.counter == 0) return null; // OK: returns null.
    // reduce_without_await
    // (Returns before passing through an 'await', so state changes may be lost)
    // Fix: Will add 'await microtask;' to the start of 'reduce'.
    if (state.counter > 10) return state.copy(counter: 0);
    var name = await fetchName();
    return state.copy(name: name); // OK: after an await.
  }
}

class ReturnsFutureWithoutAwait extends AppAction {
  @override
  Future<AppState?> reduce() async {
    // reduce_without_await
    // (Returns a Future without awaiting it)
    // Fix: Will add 'await microtask;' to the start of 'reduce'.
    return fetchState();
  }
}

class AwaitOnlyInLoop extends AppAction {
  @override
  Future<AppState?> reduce() async {
    var name = '';
    for (var i = 0; i < state.counter; i++) {
      name = await fetchName();
    }
    // reduce_without_await
    // (The loop may not run, so it may return without an 'await')
    // Fix: Will add 'await microtask;' to the start of 'reduce'.
    return state.copy(name: name);
  }
}

class AwaitInOneBranch extends AppAction {
  @override
  Future<AppState?> reduce() async {
    var name = state.name;
    if (name.isEmpty) name = await fetchName();
    // reduce_without_await
    // (The 'await' only runs in one branch)
    // Fix: Will add 'await microtask;' to the start of 'reduce'.
    return state.copy(name: name);
  }
}

class AwaitAfterOr extends AppAction {
  @override
  Future<AppState?> reduce() async {
    var ok = state.counter > 0 || (await fetchName()).isNotEmpty;
    // reduce_without_await
    // (The '||' may skip the 'await')
    // Fix: Will add 'await microtask;' to the start of 'reduce'.
    return ok ? state.copy(counter: 0) : null;
  }
}

class AwaitInsideTry extends AppAction {
  @override
  Future<AppState?> reduce() async {
    var name = '';
    try {
      name = await fetchName();
    } catch (_) {}
    // reduce_without_await
    // (The catch may run before the await)
    // Fix: Will add 'await microtask;' to the start of 'reduce'.
    return state.copy(name: name);
  }
}

class LoadUserWithCheckInternet extends AppAction with CheckInternet<AppState> {
  @override
  AppState? reduce() => null;
}

class AsyncWrapReduce extends AppAction {
  @override
  Future<AppState?> wrapReduce(Reducer<AppState> reduce) async => reduce();

  @override
  AppState? reduce() => null;
}

void dispatchSyncDemo(Store<AppState> store) {
  store.dispatchSync(Increment()); // OK: a sync action.

  // dispatch_sync_async_action
  // ('reduce' returns a Future)
  // Fix: Will replace 'dispatchSync' with 'dispatch'.
  // Fix: Will replace 'dispatchSync' with 'dispatchAndWait'.
  store.dispatchSync(LoadUser());

  // dispatch_sync_async_action
  // ('before' (from 'CheckInternet') returns a Future)
  // Fix: Will replace 'dispatchSync' with 'dispatch'.
  // Fix: Will replace 'dispatchSync' with 'dispatchAndWait'.
  store.dispatchSync(LoadUserWithCheckInternet());

  // dispatch_sync_async_action
  // ('wrapReduce' returns a Future)
  // Fix: Will replace 'dispatchSync' with 'dispatch'.
  // Fix: Will replace 'dispatchSync' with 'dispatchAndWait'.
  store.dispatchSync(AsyncWrapReduce());
}

class NonReentrantAndThrottle extends AppAction
    with
        NonReentrant<AppState>,
        // incompatible_mixins
        // ('Throttle' can't be combined with 'NonReentrant')
        // Fix: not available.
        // ignore: private_collision_in_mixin_application
        Throttle<AppState> {
  @override
  AppState? reduce() => null;
}

abstract class NonReentrantBase extends AppAction with NonReentrant<AppState> {}

class InheritedNonReentrantAndFresh extends NonReentrantBase
    with
        // incompatible_mixins
        // ('Fresh' can't be combined with 'NonReentrant', inherited from the base action)
        // Fix: not available.
        // ignore: private_collision_in_mixin_application
        Fresh<AppState> {
  @override
  AppState? reduce() => null;
}

class PollWithSequential extends AppAction
    with
        Polling<AppState>,
        // polling_with_caveat_mixin
        // ('Sequential' goes in the polling action)
        // Fix: not available.
        Sequential<AppState> {
  @override
  final Poll poll;

  PollWithSequential({this.poll = Poll.once});

  @override
  ReduxAction<AppState> createPollingAction() => LoadUser();

  @override
  AppState? reduce() => null;
}

class PollWithCheckInternet extends AppAction
    with
        Polling<AppState>,
        // polling_with_caveat_mixin
        // ('CheckInternet' goes in the polling action)
        // Fix: not available.
        CheckInternet<AppState> {
  @override
  final Poll poll;

  PollWithCheckInternet({this.poll = Poll.once});

  @override
  ReduxAction<AppState> createPollingAction() => LoadUser();

  @override
  AppState? reduce() => null;
}

void waitFailInvalidDemo(BuildContext context, Store<AppState> store) {
  var action = LoadUser();

  // wait_fail_invalid_argument
  // ('isWaiting' doesn't accept a String)
  // Fix: not available.
  context.isWaiting('LoadUser');

  // wait_fail_invalid_argument
  // ('isFailed' doesn't accept an action)
  // Fix: Will replace 'LoadUser()' with 'LoadUser'.
  context.isFailed(LoadUser());

  // wait_fail_invalid_argument
  // (An action in the list)
  // Fix: Will replace 'action' with 'action.runtimeType'.
  store.exceptionFor([Increment, action]);

  // wait_fail_invalid_argument
  // (On the store, with a variable)
  // Fix: Will replace 'action' with 'action.runtimeType'.
  store.clearExceptionFor(action);

  context.isWaiting(action); // OK: 'isWaiting' accepts actions.
  context.isFailed([LoadUser, Increment]); // OK: a list of action types.
}

void waitFailNeverMatchesDemo(BuildContext context) {
  // wait_fail_never_matches
  // (Not an action type)
  // Fix: not available.
  context.isWaiting(AppState);

  // wait_fail_never_matches
  // (An abstract action type)
  // Fix: not available.
  context.isFailed(AppAction);

  // wait_fail_never_matches
  // (A sync action type, in 'isWaiting')
  // Fix: not available.
  context.isWaiting(Increment);

  // wait_fail_never_matches
  // (A new action, never dispatched)
  // Fix: Will replace 'LoadUser()' with 'LoadUser'.
  context.isWaiting(LoadUser());

  context.isFailed(Increment); // OK: a sync action can fail.
}

class StateOneField extends StatelessWidget {
  const StateOneField({super.key});

  @override
  // avoid_context_state
  // (In 'build')
  // Fix: Will replace 'context.state.counter' with 'context.select((st) => st.counter)'.
  Widget build(BuildContext context) => Text('${context.state.counter}');
}

class StateDeepPaths extends StatelessWidget {
  const StateDeepPaths({super.key});

  @override
  Widget build(BuildContext context) {
    // avoid_context_state
    // (A variable used through getters)
    // Fix: Will replace 'state.user.name' with 'userName', and 'state.user.age' with
    // 'userAge', declared as 'final userName = context.select((st) => st.user.name);'
    // and 'final userAge = context.select((st) => st.user.age);'.
    final state = context.state;
    return Text('${state.user.name} ${state.user.age}');
  }
}

class StatePathPrefix extends StatelessWidget {
  const StatePathPrefix({super.key});

  @override
  Widget build(BuildContext context) {
    // avoid_context_state
    // ('state.user' is a prefix of 'state.user.name')
    // Fix: Will replace 'state.user' with 'user', declared as
    // 'final user = context.select((st) => st.user);'.
    final state = context.state;
    describe(state.user);
    return Text(state.user.name);
  }
}

class StateNameClash extends StatelessWidget {
  const StateNameClash({super.key});

  @override
  Widget build(BuildContext context) {
    var userName = 'Guest';
    // avoid_context_state
    // (The name 'userName' is already used)
    // Fix: Will replace 'state.user.name' with 'userName2', declared as
    // 'final userName2 = context.select((st) => st.user.name);'.
    final state = context.state;
    return Text(state.user.name + userName);
  }
}

class StateMethodAndNullAware extends StatelessWidget {
  const StateMethodAndNullAware({super.key});

  @override
  Widget build(BuildContext context) {
    // avoid_context_state
    // (The paths stop at methods and at '?.')
    // Fix: Will replace 'state.name' with 'name', and 'state.maybeUser' with
    // 'maybeUser', declared as 'final name = context.select((st) => st.name);' and
    // 'final maybeUser = context.select((st) => st.maybeUser);'.
    final state = context.state;
    return Text(state.name.trim() + (state.maybeUser?.name ?? ''));
  }
}

class StateWholeState extends StatelessWidget {
  const StateWholeState({super.key});

  @override
  Widget build(BuildContext context) {
    // avoid_context_state
    // (The whole state is used)
    // Fix: not available.
    final state = context.state;
    describe(state);
    return Text(state.name);
  }
}

class StateInCallback extends StatelessWidget {
  const StateInCallback({super.key});

  @override
  Widget build(BuildContext context) => ElevatedButton(
        // avoid_context_state
        // (In a callback)
        // Fix: Will replace 'context.state' with 'context.read()'.
        onPressed: () => describe(context.state.counter),
        child: const Text('Print'),
      );
}

class StateInHelperMethod extends StatelessWidget {
  const StateInHelperMethod({super.key});

  // avoid_context_state
  // (In a helper method, which may or may not run while the widget builds)
  // Fix: not available.
  Widget buildHeader(BuildContext context) => Text(context.state.name);

  @override
  Widget build(BuildContext context) => buildHeader(context);
}

class StateInItemBuilder extends StatelessWidget {
  const StateInItemBuilder({super.key});

  @override
  Widget build(BuildContext context) => ListView.builder(
        // avoid_context_state
        // (In an 'itemBuilder', whose 'BuildContext' belongs to the list)
        // Fix: Will wrap the item in a 'Builder', and replace 'context.state.name' with
        // 'context.select((st) => st.name)'.
        itemBuilder: (context, index) => Text(context.state.name),
      );
}

class StateWithContextOfAnotherWidget extends StatelessWidget {
  const StateWithContextOfAnotherWidget({super.key});

  @override
  Widget build(BuildContext context) => Builder(
        // avoid_context_state
        // (The 'context' of 'build', inside a builder)
        // Fix: Will rename '_' to 'context', and replace 'context.state.name' with
        // 'context.select((st) => st.name)'.
        builder: (_) => Text(context.state.name),
      );
}

class LifecycleDemo extends StatefulWidget {
  const LifecycleDemo({super.key});

  @override
  State<LifecycleDemo> createState() => _LifecycleDemoState();
}

class _LifecycleDemoState extends State<LifecycleDemo> {
  @override
  void initState() {
    super.initState();

    // context_state_in_init_state
    // (The widget can't depend on the store before 'initState' completes)
    // Fix: Will replace 'context.state' with 'context.read()'.
    describe(context.state.counter);

    // context_state_in_init_state
    // ('isWaiting' also depends on the store)
    // Fix: not available.
    describe(context.isWaiting(LoadUser));

    // select_outside_build
    // ('initState' doesn't run while the widget builds)
    // Fix: Will replace 'context.select((st) => st.counter)' with
    // 'context.read().counter'.
    describe(context.select((st) => st.counter));

    describe(context.read().counter); // OK.
    dispatch(LoadUser()); // OK.

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // avoid_context_state
      // (In a closure that runs later)
      // Fix: Will replace 'context.state' with 'context.read()'.
      describe(context.state.counter);

      // select_outside_build
      // (In a closure passed to 'addPostFrameCallback')
      // Fix: Will replace 'context.select((st) => st.counter)' with
      // 'context.read().counter'.
      describe(context.select((st) => st.counter));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // OK: 'didChangeDependencies' runs again when the counter changes.
    describe(context.select((st) => st.counter));

    // avoid_context_state
    // (In 'didChangeDependencies', it runs again on any state change)
    // Fix: Will replace 'context.state.counter' with
    // 'context.select((st) => st.counter)'.
    // Fix: Will replace 'context.state' with 'context.read()'.
    describe(context.state.counter);
  }

  @override
  void didUpdateWidget(LifecycleDemo oldWidget) {
    super.didUpdateWidget(oldWidget);

    // select_outside_build
    // (In 'didUpdateWidget', which doesn't run while the widget builds)
    // Fix: Will replace the 'getSelect(...)' call with
    // 'context.getRead<AppState>().counter'.
    describe(context.getSelect<AppState, int>((st) => st.counter));

    // avoid_context_state
    // (In 'didUpdateWidget', which doesn't run while the widget builds)
    // Fix: Will replace 'context.state' with 'context.read()'.
    describe(context.state.counter);
  }

  void increment() {
    setState(() {
      // select_outside_build
      // (In a closure passed to 'setState')
      // Fix: Will replace 'context.select((st) => st.counter)' with
      // 'context.read().counter'.
      describe(context.select((st) => st.counter));
    });
  }

  @override
  void deactivate() {
    describe(context.read().counter); // OK: the widget is still in the tree.
    super.deactivate();
  }

  @override
  void dispose() {
    // context_in_dispose
    // (The widget is no longer in the tree)
    // Fix: not available.
    describe(context.read().counter);

    // context_in_dispose
    // ('context.state' doesn't work either)
    // Fix: not available.
    describe(context.state.counter);

    // context_in_dispose
    // ('context.isWaiting' doesn't work either)
    // Fix: not available.
    describe(context.isWaiting(LoadUser));

    // context_in_dispose
    // ('context.getEnvironment' doesn't work either)
    // Fix: not available.
    describe(context.getEnvironment<AppState>());

    // context_in_dispose
    // (Also in closures inside 'dispose')
    // Fix: not available.
    Future.microtask(() => describe(context.read()));

    // select_outside_build
    // ('context.read()' throws here too)
    // Fix: not available.
    describe(context.select((st) => st.counter));

    dispatch(Increment()); // OK: dispatching works in 'dispose'.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Text('Lifecycle');
}

class SelectInCallback extends StatelessWidget {
  const SelectInCallback({super.key});

  @override
  Widget build(BuildContext context) => ElevatedButton(
        // select_outside_build
        // (The 'onPressed' callback doesn't run while the widget builds)
        // Fix: Will replace 'context.select((st) => st.counter)' with
        // 'context.read().counter'.
        onPressed: () => describe(context.select((st) => st.counter)),
        child: const Text('Print'),
      );
}

class EventInCallback extends StatelessWidget {
  const EventInCallback({super.key});

  @override
  Widget build(BuildContext context) => ElevatedButton(
        // select_outside_build
        // (Events must be consumed in 'build')
        // Fix: not available.
        onPressed: () => describe(context.event((st) => st.evt)),
        child: const Text('Print'),
      );
}

class SelectWithContextOfAnotherWidget extends StatelessWidget {
  const SelectWithContextOfAnotherWidget({super.key});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Builder(
            // select_outside_build
            // (The 'context' of 'build', in a builder)
            // Fix: Will replace 'context' with the builder's 'inner'.
            builder: (inner) => Text(context.select((st) => st.name)),
          ),
          Builder(
            // select_outside_build
            // (The 'context' of 'build', in a builder whose 'BuildContext' is '_')
            // Fix: Will rename '_' to 'context'.
            builder: (_) => Text(context.select((st) => st.name)),
          ),
          Builder(
            // OK: the builder's own 'BuildContext'.
            builder: (context) => Text(context.select((st) => st.name)),
          ),
        ],
      );
}

class SelectWithContextOfState extends StatefulWidget {
  const SelectWithContextOfState({super.key});

  @override
  State<SelectWithContextOfState> createState() => _SelectWithContextOfStateState();
}

class _SelectWithContextOfStateState extends State<SelectWithContextOfState> {
  @override
  Widget build(BuildContext buildContext) => Builder(
        // select_outside_build
        // (The 'context' of the State, in a builder)
        // Fix: Will replace 'context' with the builder's 'inner'.
        builder: (inner) => Text(context.select((st) => st.name)),
      );
}

class SelectInItemBuilder extends StatelessWidget {
  const SelectInItemBuilder({super.key});

  @override
  Widget build(BuildContext context) => ListView.builder(
        // select_outside_build
        // (The 'BuildContext' of an 'itemBuilder' belongs to the list)
        // Fix: Will wrap the item in a 'Builder'.
        itemBuilder: (context, index) => Text(context.select((st) => st.name)),
      );
}

class SelectInItemBuilderWithBuilder extends StatelessWidget {
  const SelectInItemBuilderWithBuilder({super.key});

  @override
  Widget build(BuildContext context) => ListView.builder(
        // OK: the 'Builder' has its own 'BuildContext'.
        itemBuilder: (_, index) =>
            Builder(builder: (context) => Text(context.select((st) => st.name))),
      );
}

class ContextInSelector extends StatelessWidget {
  const ContextInSelector({super.key});

  @override
  Widget build(BuildContext context) {
    // context_in_selector
    // (The selector must only use its parameter)
    // Fix: Will replace 'context.state' with 'st'.
    var name = context.select((st) => context.state.name);

    // context_in_selector
    // (The selector must only use its parameter)
    // Fix: Will replace 'context.read()' with 'st'.
    var counter = context.select((st) => context.read().counter);

    var user = context.select((st) {
      // context_in_selector
      // (A nested 'select' throws)
      // Fix: not available.
      return context.select((s) => s.user);
    });

    var value = context.event((st) {
      // context_in_selector
      // (In the selector of 'context.event')
      // Fix: not available.
      if (context.isWaiting(LoadUser)) describe('waiting');
      return st.evt;
    });

    return Text('$name $counter ${user.name} $value');
  }
}

class CounterVm extends Vm {
  final int counter;

  // vm_field_not_in_equals
  // ('description' is missing from 'equals', so changing it doesn't rebuild)
  // Fix: Will add 'description' to 'equals'.
  final String description;

  final VoidCallback onIncrement; // OK: functions can't be in 'equals'.

  CounterVm({
    required this.counter,
    required this.description,
    required this.onIncrement,
  }) : super(equals: [counter]);
}

class NoEqualsVm extends Vm {
  // vm_field_not_in_equals
  // (Without 'equals', all fields are missing)
  // Fix: Will add ': super(equals: [counter])' to the constructor.
  final int counter;

  NoEqualsVm({required this.counter});
}

@stateClass
class CopyMissingField {
  final int counter;
  final String name;
  final bool waiting;

  CopyMissingField({required this.counter, this.name = '', this.waiting = false});

  // copy_missing_field
  // ('name' has no parameter, and 'waiting' has one but doesn't use it)
  // Fix: Will add the parameter 'String? name' to 'copy', and pass
  // 'name: name ?? this.name' to the constructor. It doesn't change 'waiting'.
  CopyMissingField copy({int? counter, bool? waiting}) =>
      CopyMissingField(counter: counter ?? this.counter, waiting: false);

  @override
  bool operator ==(Object other) =>
      other is CopyMissingField &&
      counter == other.counter &&
      name == other.name &&
      waiting == other.waiting;

  @override
  int get hashCode => Object.hash(counter, name, waiting);
}

@stateClass
// state_class_must_be_immutable
// ('counter' isn't final)
// Fix: not available.
class MutableState {
  int counter;

  MutableState({required this.counter});

  @override
  bool operator ==(Object other) => other is MutableState && counter == other.counter;

  @override
  int get hashCode => counter.hashCode;
}

@stateClass
abstract class ImmutableBase {
  final int counter;

  ImmutableBase({required this.counter});

  @override
  bool operator ==(Object other) => other is ImmutableBase && counter == other.counter;

  @override
  int get hashCode => counter.hashCode;
}

// state_class_must_be_immutable
// (Subclasses of a '@stateClass' are checked)
// Fix: not available.
class MutableSubclass extends ImmutableBase {
  String name;

  MutableSubclass({required super.counter, required this.name});

  @override
  bool operator ==(Object other) =>
      other is MutableSubclass && counter == other.counter && name == other.name;

  @override
  int get hashCode => Object.hash(counter, name);
}

@stateClass
// state_class_missing_equality
// (Has fields, but no '==' and 'hashCode')
// Fix: not available.
class NoEquality {
  final int counter;

  NoEquality({required this.counter});
}

@stateClass
class EqualityBase {
  final int counter;

  EqualityBase({required this.counter});

  @override
  bool operator ==(Object other) => other is EqualityBase && counter == other.counter;

  @override
  int get hashCode => counter.hashCode;
}

// state_class_missing_equality
// (The inherited '==' doesn't know 'name')
// Fix: not available.
class InheritsEquality extends EqualityBase {
  final String name;

  InheritsEquality({required super.counter, required this.name});
}

@stateClass
class EqualityMissingField {
  final int counter;
  final bool waiting;
  final bool loading;

  EqualityMissingField({
    required this.counter,
    required this.waiting,
    required this.loading,
  });

  @override
  // equality_missing_field
  // ('counter' is missing from '==')
  // Fix: Will add '&& counter == other.counter' to '=='.
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EqualityMissingField &&
          runtimeType == other.runtimeType &&
          waiting == other.waiting &&
          loading == other.loading;

  @override
  // equality_missing_field
  // ('waiting' is missing from 'hashCode')
  // Fix: Will add 'waiting' to 'Object.hash(...)'.
  int get hashCode => Object.hash(counter, loading);
}

@stateClass
class InheritedFieldBase {
  final int counter;

  InheritedFieldBase({required this.counter});

  @override
  bool operator ==(Object other) =>
      other is InheritedFieldBase && counter == other.counter;

  @override
  int get hashCode => counter.hashCode;
}

class InheritedFieldSub extends InheritedFieldBase {
  final String name;

  InheritedFieldSub({required super.counter, required this.name});

  @override
  // equality_missing_inherited_field
  // (Doesn't call 'super == other')
  // Fix: Will add '&& super == other' to '=='.
  bool operator ==(Object other) => other is InheritedFieldSub && name == other.name;

  @override
  // equality_missing_inherited_field
  // (Doesn't use 'super.hashCode')
  // Fix: Will add '^ super.hashCode' to 'hashCode'.
  int get hashCode => name.hashCode;
}

@stateClass
class EquatableState extends Equatable {
  final int counter;
  final String name;

  const EquatableState({required this.counter, required this.name});

  @override
  // equatable_props_missing_field
  // ('name' is missing from 'props')
  // Fix: Will add 'name' to 'props'.
  List<Object?> get props => [counter];
}

class EquatableSub extends EquatableState {
  final bool waiting;

  const EquatableSub(
      {required super.counter, required super.name, required this.waiting});

  @override
  // equatable_props_missing_field
  // (The inherited 'props' are missing)
  // Fix: Will add '...super.props' to the start of 'props'.
  List<Object?> get props => [waiting];
}

// equatable_props_missing_field
// (Declares a field, but not 'props', so the inherited 'props' doesn't have it)
// Fix: not available.
class EquatableWithoutProps extends EquatableState {
  final bool loading;

  const EquatableWithoutProps({
    required super.counter,
    required super.name,
    required this.loading,
  });
}

// extend_base_action
// (Extends 'ReduxAction<AppState>' directly, instead of the base action)
// Fix: Will replace 'ReduxAction<AppState>' with 'AppAction'.
class ExtendsReduxAction extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;
}

// OK: an action with a generic state can't extend the app's base action.
class GenericAction<St> extends ReduxAction<St> {
  @override
  St? reduce() => null;
}

class CastsDependencies extends AppAction {
  @override
  AppState? reduce() {
    // dependencies_cast_in_action
    // (Use the 'dependencies' getter of 'AppAction')
    // Fix: not available.
    var deps = store.dependencies as Dependencies;
    describe(deps.apiUrl);

    describe(dependencies.apiUrl); // OK
    return null;
  }
}

class ReturnsUnchangedState extends AppAction {
  @override
  AppState? reduce() {
    // prefer_return_null
    // (Returning 'null' means the state didn't change)
    // Fix: Will replace 'state' with 'null'.
    if (state.counter == 0) return state;
    return state.copy(counter: 0);
  }
}

class UsesStaleState extends AppAction {
  @override
  Future<AppState?> reduce() async {
    var oldState = state;
    var name = await fetchName();
    // stale_state_after_await
    // (Other actions may have changed the state during the 'await', and these changes
    // would be lost)
    // Fix: Will replace 'oldState' with 'state'.
    return oldState.copy(name: name);
  }
}

class ReadsStateAgain extends AppAction {
  @override
  Future<AppState?> reduce() async {
    var name = await fetchName();
    var newState = state; // OK: read after the 'await'.
    return newState.copy(name: name);
  }
}

class ThrowsInAfter extends AppAction {
  @override
  AppState? reduce() => null;

  @override
  void after() {
    // after_throws
    // (The error would only show up in the console)
    // Fix: not available.
    if (state.counter < 0) throw Exception('Negative counter');

    try {
      throw Exception('Caught'); // OK: caught below.
    } catch (error) {
      describe(error);
    }
  }
}

class OverridesNonReentrant extends AppAction with NonReentrant<AppState> {
  @override
  // missing_super_in_mixin_override
  // ('NonReentrant' doesn't work without 'super.abortDispatch()')
  // Fix: not available.
  bool abortDispatch() => state.counter > 10;

  @override
  AppState? reduce() => null;
}

class CallsSuperAbortDispatch extends AppAction with NonReentrant<AppState> {
  @override
  bool abortDispatch() {
    if (super.abortDispatch()) return true; // OK: calls super.
    return state.counter > 10;
  }

  @override
  AppState? reduce() => null;
}

// retry_without_non_reentrant
// (A new dispatch could run while this one retries)
// Fix: Will change 'with Retry<AppState>' to 'with Retry<AppState>, NonReentrant'.
class RetryWithoutNonReentrant extends AppAction with Retry<AppState> {
  @override
  Future<AppState?> reduce() async => state.copy(name: await fetchName());
}

class RetryWithNonReentrant extends AppAction
    with Retry<AppState>, NonReentrant<AppState> {
  @override
  Future<AppState?> reduce() async => state.copy(name: await fetchName()); // OK
}

class RetryForever extends AppAction
    with Retry<AppState>, UnlimitedRetries<AppState>, NonReentrant<AppState> {
  @override
  Future<AppState?> reduce() async => state.copy(name: await fetchName());
}

Future<void> waitsForRetryForever(Store<AppState> store) async {
  // dispatch_and_wait_unlimited_retries
  // (It may never complete)
  // Fix: not available.
  await store.dispatchAndWait(RetryForever());

  store.dispatch(RetryForever()); // OK: doesn't wait.
}

class SequentialChild extends AppAction with Sequential<AppState> {
  @override
  AppState? reduce() => null;
}

class SequentialParent extends AppAction with Sequential<AppState> {
  @override
  Future<AppState?> reduce() async {
    // sequential_deadlock
    // ('SequentialChild' only runs after this action ends)
    // Fix: Will change 'await dispatchAndWait(...)' to 'dispatch(...)'.
    await dispatchAndWait(SequentialChild());

    dispatch(SequentialChild()); // OK: runs after this action ends.
    return null;
  }
}

class SequentialWithBeforeAndAfter extends AppAction with Sequential<AppState> {
  @override
  // sequential_before_super_not_first
  // ('describe' runs before the action's turn)
  // Fix: not available.
  Future<void> before() async {
    describe('dispatched');
    await super.before();
  }

  @override
  void after() {
    describe('finished');
    // sequential_after_super_not_in_finally
    // (Not called if 'describe' throws)
    // Fix: not available.
    super.after();
  }

  @override
  AppState? reduce() => null;
}

class SequentialWithBeforeAndAfterOk extends AppAction with Sequential<AppState> {
  @override
  Future<void> before() async {
    await super.before(); // OK: the first statement.
    describe('my turn');
  }

  @override
  void after() {
    try {
      describe('finished');
    } finally {
      super.after(); // OK: in a 'finally' block.
    }
  }

  @override
  AppState? reduce() => null;
}

class PollPrices extends AppAction with Polling<AppState> {
  @override
  final Poll poll;

  PollPrices({this.poll = Poll.once});

  @override
  // polling_action_restarts_polling
  // (Each tick would restart the timer)
  // Fix: Will replace 'Poll.runNowAndRestart' with 'Poll.once'.
  ReduxAction<AppState> createPollingAction() => PollPrices(poll: Poll.runNowAndRestart);

  @override
  AppState? reduce() => null;
}

class PushName extends AppAction with ServerPush<AppState> {
  @override
  // server_push_associated_action
  // ('LoadUser' doesn't use 'OptimisticSyncWithPush')
  // Fix: not available.
  Type associatedAction() => LoadUser;

  @override
  PushMetadata pushMetadata() => (serverRevision: 1, localRevision: 0, deviceId: 0);

  @override
  int getServerRevisionFromState(Object? key) => 0;

  @override
  AppState? applyServerPushToState(AppState state, Object? key, int serverRevision) =>
      null;
}

class LoadWhenOnline extends AppAction with CheckInternet<AppState> {
  @override
  // internet_simulation_in_production
  // (Ignores the real connection)
  // Fix: not available.
  bool? get internetOnOffSimulation => false;

  @override
  AppState? reduce() => null;
}

class DispatchDemo extends StatelessWidget {
  const DispatchDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ElevatedButton(
        // prefer_dispatch_without_context
        // (The 'context.' isn't needed to call 'dispatch' in a widget)
        // Fix: Will replace 'context.dispatch' with 'dispatch'.
        onPressed: () => context.dispatch(Increment()),
        child: const Text('Increment'),
      ),
      ElevatedButton(
        onPressed: () => dispatch(Increment()), // OK.
        child: const Text('Increment'),
      ),
      ElevatedButton(
        onPressed: () {
          // then_on_dispatch_and_wait
          // (The callback also runs when the action fails)
          // Fix: Will replace 'then' with 'thenIfCompletedOk'.
          dispatchAndWait(LoadUser()).then((_) => Navigator.pop(context));
        },
        child: const Text('Load user'),
      ),
      ElevatedButton(
        onPressed: () {
          dispatchAndWait(LoadUser())
              .thenIfCompletedOk((_) => Navigator.pop(context)); // OK.
        },
        child: const Text('Load user'),
      ),
    ]);
  }
}

class DispatchInBuildDemo extends StatelessWidget {
  const DispatchInBuildDemo({super.key});

  @override
  Widget build(BuildContext context) {
    // dispatch_in_build
    // (It dispatches again on every rebuild)
    dispatch(LoadUser());

    return Column(children: [
      Builder(builder: (context) {
        // dispatch_in_build
        // (Builder closures also run while the widget builds)
        dispatch(LoadUser());
        return const Text('Builder');
      }),
      ElevatedButton(
        onPressed: () => dispatch(LoadUser()), // OK: dispatching in a callback.
        child: const Text('Load user'),
      ),
    ]);
  }
}

class ContextReadInBuildDemo extends StatelessWidget {
  const ContextReadInBuildDemo({super.key});

  @override
  Widget build(BuildContext context) {
    // context_read_in_build
    // (The widget doesn't rebuild when the name changes)
    // Fix: Will replace 'context.read().user.name' with
    // 'context.select((st) => st.user.name)'.
    var name = context.read().user.name;

    var age = context.select((st) => st.user.age); // OK.

    return ListView.builder(
      itemCount: 3,
      itemBuilder: (context, index) {
        // context_read_in_build
        // ('context.select' can't be used in an 'itemBuilder', so the message suggests
        // a 'Builder' or a separate widget)
        var counter = context.read().counter;
        return Text('$name $age $counter $index');
      },
    );
  }
}

class RefreshDemo extends StatelessWidget {
  const RefreshDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      RefreshIndicator(
        onRefresh: () async {
          // refresh_indicator_without_wait
          // (The spinner disappears before the user loads)
          // Fix: Will replace 'dispatch(...)' with 'await dispatchAndWait(...)'.
          dispatch(LoadUser());
        },
        child: ListView(),
      ),
      RefreshIndicator(
        onRefresh: () async {
          // refresh_indicator_without_wait
          // ('dispatchAll' can't be waited for)
          // Fix: Will replace 'dispatchAll(...)' with 'await dispatchAndWaitAll(...)'.
          dispatchAll([LoadUser(), Increment()]);
        },
        child: ListView(),
      ),
      RefreshIndicator(
        onRefresh: _refresh, // The method below is checked too.
        child: ListView(),
      ),
      RefreshIndicator(
        onRefresh: () => dispatchAndWait(LoadUser()), // OK.
        child: ListView(),
      ),
    ]);
  }

  Future<void> _refresh() async {
    // refresh_indicator_without_wait
    // (The dispatch is in a method passed as 'onRefresh')
    // Fix: Will replace 'dispatch(...)' with 'await dispatchAndWait(...)'.
    dispatch(LoadUser());
  }
}

class Clock extends StatefulWidget {
  // stream_or_timer_in_widget
  // (A field of type 'Stream')
  final Stream<int> ticks;

  const Clock({
    super.key,
    required this.ticks,
    // stream_or_timer_in_widget
    // (A constructor parameter of type 'Stream')
    Stream<String>? messages,
  });

  @override
  State<Clock> createState() => _ClockState();
}

class _ClockState extends State<Clock> {
  // stream_or_timer_in_widget
  // (A field of type 'Timer')
  Timer? timer;

  @override
  void initState() {
    super.initState();

    // stream_or_timer_in_widget
    // (Creating a 'Timer')
    timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

    // stream_or_timer_in_widget
    // (Listening to a 'Stream')
    widget.ticks.listen((_) => setState(() {}));

    dispatch(Increment()); // OK: start the clock with an action instead.
  }

  @override
  Widget build(BuildContext context) => const Text('Clock');
}

class UserExceptionDemo extends StatelessWidget {
  const UserExceptionDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ElevatedButton(
        // user_exception_outside_action
        // (In a widget, AsyncRedux can't catch it to show the dialog)
        // Fix: Will replace 'throw UserException(...)' with
        // 'context.dispatch(UserExceptionAction(...))'.
        onPressed: () => throw const UserException('Invalid'),
        child: const Text('Save'),
      ),
      ElevatedButton(
        onPressed: () => dispatch(UserExceptionAction('Invalid')), // OK.
        child: const Text('Save'),
      ),
      ElevatedButton(
        onPressed: () {
          try {
            throw const UserException('Invalid'); // OK: caught below.
          } catch (error) {
            describe(error);
          }
        },
        child: const Text('Save'),
      ),
    ]);
  }
}

class UserExceptionInState extends StatefulWidget {
  const UserExceptionInState({super.key});

  @override
  State<UserExceptionInState> createState() => _UserExceptionInStateState();
}

class _UserExceptionInStateState extends State<UserExceptionInState> {
  void _save() {
    // user_exception_outside_action
    // (In a 'State')
    // Fix: Will replace 'throw UserException(...)' with
    // 'context.dispatch(UserExceptionAction(...))'.
    throw const UserException('Invalid');
  }

  @override
  Widget build(BuildContext context) =>
      ElevatedButton(onPressed: _save, child: const Text('Save'));
}

class CounterFactory extends VmFactory<AppState, UserExceptionDemo, CounterVm> {
  @override
  CounterVm fromStore() {
    // user_exception_outside_action
    // (In a 'VmFactory')
    // Fix: Will replace 'throw UserException(...)' with
    // 'dispatch(UserExceptionAction(...))'.
    if (state.counter < 0) throw const UserException('Negative counter');

    return CounterVm(
      counter: state.counter,
      description: 'Counter',
      onIncrement: () => dispatch(Increment()),
    );
  }
}

class ValidatingVm extends Vm {
  final int counter;

  ValidatingVm({required this.counter}) : super(equals: [counter]);

  void validate() {
    // user_exception_outside_action
    // (In a view-model)
    // Fix: not available.
    if (counter < 0) throw const UserException('Negative counter');
  }
}

class UserExceptionInAfter extends AppAction {
  @override
  AppState? reduce() {
    if (state.counter < 0) throw const UserException('Negative counter'); // OK.
    return null;
  }

  @override
  void after() {
    // user_exception_outside_action
    // (In 'after', which AsyncRedux doesn't catch to show the dialog)
    // Fix: Will replace 'throw UserException(...)' with
    // 'dispatch(UserExceptionAction(...))'.
    if (state.counter > 100) throw const UserException('Counter too large');
  }
}

// =====================================================================================
// Opt-in rules. They are off in this example, so these diagnostics don't show. To see
// them, turn them on in the example's analysis_options.yaml.
// =====================================================================================

// Action names. Turn on one of these:
//
// - action_name_ends_with_action: a warning on 'LoadUser', which should be
//   'LoadUserAction'.
// - action_name_ends_with_underscore_action: a warning on 'LoadUser', which should be
//   'LoadUser_Action'.
// - action_name_without_action: a warning on 'ExtendsReduxAction', which shouldn't
//   end with 'Action'.
//
// Quick fix: rename the action, in all files of the package.

// Dispatching with the context. Turn on prefer_dispatch_with_context, and turn off
// prefer_dispatch_without_context, for an info on each 'dispatch(...)' in a widget,
// like the second button of 'DispatchDemo'. Quick fix: add 'context.'.

// Action file names. Turn on one of these:
//
// - action_file_name_ends_with_action: a warning on 'Increment', the first action of
//   this file, since 'main_lints.dart' doesn't end with '_action'.
// - action_file_name_starts_with_action: the same, since 'main_lints.dart' doesn't
//   start with 'ACTION_'.
//
// No quick fix. Rename the file with the IDE, which also updates the imports.

// Power features. Turn on these to make each use deliberate, with an '// ignore':
//
// - avoid_abort_dispatch: an info on 'abortDispatch' in 'OverridesNonReentrant' and
//   'CallsSuperAbortDispatch'.
// - avoid_wrap_reduce: an info on 'wrapReduce' in the wrap_reduce_return_type and
//   dispatch_sync_async_action examples.

// Mixin keys. Turn on missing_key_params for an info on 'NonReentrant' in
// 'LoadUserCart', which has a field but doesn't override 'nonReentrantKeyParams'. So
// 'LoadUserCart('A')' blocks 'LoadUserCart('B')'.

class LoadUserCart extends AppAction with NonReentrant<AppState> {
  final String userId;

  LoadUserCart(this.userId);

  @override
  AppState? reduce() => null;
}
