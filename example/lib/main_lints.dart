// Demonstrates the diagnostics of the `async_redux_lints` analyzer plugin. Each
// diagnostic is marked with a comment on the line before it, like
// `// Error: rule_name`, and each variant of a rule is shown separately.
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

// =====================================================================================
// The app's state, actions and BuildContext extension. These have no diagnostics.
// =====================================================================================

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

/// A sync action.
class Increment extends ReduxAction<AppState> {
  @override
  AppState reduce() => state.copy(counter: state.counter + 1);
}

/// An async action.
class LoadUser extends ReduxAction<AppState> {
  @override
  Future<AppState?> reduce() async {
    var name = await fetchName();
    return state.copy(name: name);
  }
}

/// An abstract base action.
abstract class AppAction extends ReduxAction<AppState> {}

Future<String> fetchName() async => 'Mary';

Future<AppState?> fetchState() async => null;

void describe(Object? value) => print(value);

// =====================================================================================
// reduce_return_type (error)
// =====================================================================================

class ReduceReturnsFutureOr extends ReduxAction<AppState> {
  // Error: reduce_return_type. FutureOr<AppState?>.
  // Quick fixes: change to 'AppState?', or to 'Future<AppState?>'.
  @override
  FutureOr<AppState?> reduce() => null;
}

class ReduceReturnsNullableFuture extends ReduxAction<AppState> {
  // Error: reduce_return_type. Future<AppState?>?.
  @override
  Future<AppState?>? reduce() => null;
}

class ReduceWithoutReturnType extends ReduxAction<AppState> {
  // Error: reduce_return_type. No return type, which Dart infers as FutureOr.
  @override
  reduce() async => null;
}

// =====================================================================================
// before_return_type (error)
// =====================================================================================

class BeforeReturnsFutureOr extends ReduxAction<AppState> {
  // Error: before_return_type. FutureOr<void>.
  // Quick fixes: change to 'void', or to 'Future<void>'.
  @override
  FutureOr<void> before() async {}

  @override
  AppState? reduce() => null;
}

class BeforeWithoutReturnType extends ReduxAction<AppState> {
  // Error: before_return_type. No return type.
  @override
  before() async {}

  @override
  AppState? reduce() => null;
}

// =====================================================================================
// wrap_reduce_return_type (error)
// =====================================================================================

class WrapReduceReturnsState extends ReduxAction<AppState> {
  // Error: wrap_reduce_return_type. Returns 'AppState?', which throws at runtime.
  // Quick fix: change to 'Future<AppState?>'.
  @override
  AppState? wrapReduce(Reducer<AppState> reduce) => null;

  @override
  AppState? reduce() => null;
}

class WrapReduceReturnsFutureOr extends ReduxAction<AppState> {
  // Error: wrap_reduce_return_type. Returns 'FutureOr<AppState?>', so AsyncRedux never
  // calls it.
  @override
  FutureOr<AppState?> wrapReduce(Reducer<AppState> reduce) => null;

  @override
  AppState? reduce() => null;
}

// =====================================================================================
// reduce_without_await (error)
// Quick fixes: add 'await microtask;' to the start of 'reduce', or make 'reduce' sync
// (only when it has no 'await' at all).
// =====================================================================================

class ReturnsBeforeAwait extends ReduxAction<AppState> {
  @override
  Future<AppState?> reduce() async {
    if (state.counter == 0) return null; // OK: returns null.
    // Error: reduce_without_await. A non-null value, before any await.
    if (state.counter > 10) return state;
    var name = await fetchName();
    return state.copy(name: name); // OK: after an await.
  }
}

class ReturnsFutureWithoutAwait extends ReduxAction<AppState> {
  @override
  Future<AppState?> reduce() async {
    // Error: reduce_without_await. Returns a Future without awaiting it.
    return fetchState();
  }
}

class AwaitOnlyInLoop extends ReduxAction<AppState> {
  @override
  Future<AppState?> reduce() async {
    var name = '';
    for (var i = 0; i < state.counter; i++) {
      name = await fetchName();
    }
    // Error: reduce_without_await. The loop may run zero times.
    return state.copy(name: name);
  }
}

class AwaitInOneBranch extends ReduxAction<AppState> {
  @override
  Future<AppState?> reduce() async {
    var name = state.name;
    if (name.isEmpty) name = await fetchName();
    // Error: reduce_without_await. The await only runs in one branch.
    return state.copy(name: name);
  }
}

class AwaitAfterOr extends ReduxAction<AppState> {
  @override
  Future<AppState?> reduce() async {
    var ok = state.counter > 0 || (await fetchName()).isNotEmpty;
    // Error: reduce_without_await. The await after '||' may not run.
    return ok ? state.copy(counter: 0) : null;
  }
}

class AwaitInsideTry extends ReduxAction<AppState> {
  @override
  Future<AppState?> reduce() async {
    var name = '';
    try {
      name = await fetchName();
    } catch (_) {}
    // Error: reduce_without_await. The catch may run before the await.
    return state.copy(name: name);
  }
}

// =====================================================================================
// dispatch_sync_async_action (error)
// Quick fixes: replace with 'dispatch', or with 'dispatchAndWait'.
// =====================================================================================

class LoadUserWithCheckInternet extends ReduxAction<AppState>
    with CheckInternet<AppState> {
  @override
  AppState? reduce() => null;
}

class AsyncWrapReduce extends ReduxAction<AppState> {
  @override
  Future<AppState?> wrapReduce(Reducer<AppState> reduce) async => reduce();

  @override
  AppState? reduce() => null;
}

void dispatchSyncDemo(Store<AppState> store) {
  store.dispatchSync(Increment()); // OK: a sync action.

  // Error: dispatch_sync_async_action. 'reduce' returns a Future.
  store.dispatchSync(LoadUser());

  // Error: dispatch_sync_async_action. 'before' (from 'CheckInternet') returns a
  // Future.
  store.dispatchSync(LoadUserWithCheckInternet());

  // Error: dispatch_sync_async_action. 'wrapReduce' returns a Future.
  store.dispatchSync(AsyncWrapReduce());
}

// =====================================================================================
// incompatible_mixins (error). See mixin_compatibility.md for all combinations.
// The analyzer also reports these as 'private_collision_in_mixin_application', with a
// message that names a private '_cannot_combine_mixins_...' method. The lint explains
// which mixins conflict.
// =====================================================================================

// Error: incompatible_mixins. On 'Throttle': can't be combined with 'NonReentrant'.
class NonReentrantAndThrottle extends ReduxAction<AppState>
    with NonReentrant<AppState>, Throttle<AppState> {
  @override
  AppState? reduce() => null;
}

abstract class NonReentrantBase extends ReduxAction<AppState>
    with NonReentrant<AppState> {}

// Error: incompatible_mixins. A mixin inherited from the base action counts too.
class InheritedNonReentrantAndFresh extends NonReentrantBase with Fresh<AppState> {
  @override
  AppState? reduce() => null;
}

// =====================================================================================
// polling_with_caveat_mixin (error)
// =====================================================================================

class PollWithSequential extends ReduxAction<AppState>
    // Error: polling_with_caveat_mixin. 'Sequential' goes in the polling action.
    with
        Polling<AppState>,
        Sequential<AppState> {
  @override
  final Poll poll;

  PollWithSequential({this.poll = Poll.once});

  @override
  ReduxAction<AppState> createPollingAction() => LoadUser();

  @override
  AppState? reduce() => null;
}

class PollWithCheckInternet extends ReduxAction<AppState>
    // Error: polling_with_caveat_mixin. 'CheckInternet' goes in the polling action.
    with
        Polling<AppState>,
        CheckInternet<AppState> {
  @override
  final Poll poll;

  PollWithCheckInternet({this.poll = Poll.once});

  @override
  ReduxAction<AppState> createPollingAction() => LoadUser();

  @override
  AppState? reduce() => null;
}

// =====================================================================================
// wait_fail_invalid_argument (error)
// Quick fix: replace the action with its type.
// =====================================================================================

void waitFailInvalidDemo(BuildContext context, Store<AppState> store) {
  var action = LoadUser();

  // Error: wait_fail_invalid_argument. 'isWaiting' doesn't accept a String.
  context.isWaiting('LoadUser');

  // Error: wait_fail_invalid_argument. 'isFailed' doesn't accept an action.
  context.isFailed(LoadUser());

  // Error: wait_fail_invalid_argument. An action in the list.
  store.exceptionFor([Increment, action]);

  // Error: wait_fail_invalid_argument. On the store, with a variable.
  store.clearExceptionFor(action);

  context.isWaiting(action); // OK: 'isWaiting' accepts actions.
  context.isFailed([LoadUser, Increment]); // OK: a list of action types.
}

// =====================================================================================
// wait_fail_never_matches (warning)
// =====================================================================================

void waitFailNeverMatchesDemo(BuildContext context) {
  // Warning: wait_fail_never_matches. Not an action type.
  context.isWaiting(AppState);

  // Warning: wait_fail_never_matches. An abstract action type.
  context.isFailed(AppAction);

  // Warning: wait_fail_never_matches. A sync action type, in 'isWaiting'.
  context.isWaiting(Increment);

  // Warning: wait_fail_never_matches. A new action, never dispatched.
  // Quick fix: replace it with its type.
  context.isWaiting(LoadUser());

  context.isFailed(Increment); // OK: a sync action can fail.
}

// =====================================================================================
// avoid_context_state (info)
// =====================================================================================

class StateOneField extends StatelessWidget {
  const StateOneField({super.key});

  // Info: avoid_context_state. In 'build'.
  // Quick fix: 'context.select((st) => st.counter)'.
  @override
  Widget build(BuildContext context) => Text('${context.state.counter}');
}

class StateDeepPaths extends StatelessWidget {
  const StateDeepPaths({super.key});

  @override
  Widget build(BuildContext context) {
    // Info: avoid_context_state. A variable used through getters.
    // Quick fix: one select per path, 'userName' and 'userAge'.
    final state = context.state;
    return Text('${state.user.name} ${state.user.age}');
  }
}

class StatePathPrefix extends StatelessWidget {
  const StatePathPrefix({super.key});

  @override
  Widget build(BuildContext context) {
    // Info: avoid_context_state. 'state.user' is a prefix of 'state.user.name'.
    // Quick fix: a single 'user' select, and 'user.name'.
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
    // Info: avoid_context_state. The name 'userName' is already used.
    // Quick fix: 'userName2'.
    final state = context.state;
    return Text(state.user.name + userName);
  }
}

class StateMethodAndNullAware extends StatelessWidget {
  const StateMethodAndNullAware({super.key});

  @override
  Widget build(BuildContext context) {
    // Info: avoid_context_state. The paths stop at methods and at '?.'.
    // Quick fix: 'name' (then 'name.trim()') and 'maybeUser' (then 'maybeUser?.name').
    final state = context.state;
    return Text(state.name.trim() + (state.maybeUser?.name ?? ''));
  }
}

class StateWholeState extends StatelessWidget {
  const StateWholeState({super.key});

  @override
  Widget build(BuildContext context) {
    // Info: avoid_context_state. The whole state is used. No quick fix.
    final state = context.state;
    describe(state);
    return Text(state.name);
  }
}

class StateInCallback extends StatelessWidget {
  const StateInCallback({super.key});

  @override
  Widget build(BuildContext context) => ElevatedButton(
        // Info: avoid_context_state. In a callback.
        // Quick fix: 'context.read()'.
        onPressed: () => describe(context.state.counter),
        child: const Text('Print'),
      );
}

class StateInHelperMethod extends StatelessWidget {
  const StateInHelperMethod({super.key});

  // Info: avoid_context_state. In a helper method, which may or may not run while the
  // widget builds. No quick fix.
  Widget buildHeader(BuildContext context) => Text(context.state.name);

  @override
  Widget build(BuildContext context) => buildHeader(context);
}

class StateInItemBuilder extends StatelessWidget {
  const StateInItemBuilder({super.key});

  @override
  Widget build(BuildContext context) => ListView.builder(
        // Info: avoid_context_state. In an 'itemBuilder', where 'context.select' can't be
        // used. No quick fix. Use 'context.select' in a 'Builder', or a separate widget.
        itemBuilder: (context, index) => Text(context.state.name),
      );
}

class StateWithContextOfAnotherWidget extends StatelessWidget {
  const StateWithContextOfAnotherWidget({super.key});

  @override
  Widget build(BuildContext context) => Builder(
        // Info: avoid_context_state. The 'context' of 'build', inside a builder. No fix.
        builder: (_) => Text(context.state.name),
      );
}

// =====================================================================================
// State methods: context_state_in_init_state (error), context_in_dispose (error),
// select_outside_build (error), and avoid_context_state (info).
// =====================================================================================

class LifecycleDemo extends StatefulWidget {
  const LifecycleDemo({super.key});

  @override
  State<LifecycleDemo> createState() => _LifecycleDemoState();
}

class _LifecycleDemoState extends State<LifecycleDemo> {
  @override
  void initState() {
    super.initState();

    // Error: context_state_in_init_state. Quick fix: 'context.read()'.
    describe(context.state.counter);

    // Error: context_state_in_init_state. No quick fix.
    describe(context.isWaiting(LoadUser));

    // Error: select_outside_build. Quick fix: 'context.read().counter'.
    describe(context.select((st) => st.counter));

    describe(context.read().counter); // OK.
    context.dispatch(LoadUser()); // OK.

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Info: avoid_context_state. In a closure that runs later.
      // Quick fix: 'context.read()'.
      describe(context.state.counter);

      // Error: select_outside_build. In a closure passed to 'addPostFrameCallback'.
      describe(context.select((st) => st.counter));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Error: select_outside_build. Only allowed here with 'debug: false', which the
    // 'select' of BuildContextExtension doesn't pass.
    describe(context.select((st) => st.counter));

    // OK: 'debug: false' allows it in 'didChangeDependencies'.
    describe(context.getSelect<AppState, int>((st) => st.counter, debug: false));

    // Info: avoid_context_state. No quick fix here.
    describe(context.state.counter);
  }

  @override
  void didUpdateWidget(LifecycleDemo oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Error: select_outside_build. Even with 'debug: false', which only turns off
    // the runtime check. Quick fix: 'context.getRead<AppState>().counter'.
    describe(context.getSelect<AppState, int>((st) => st.counter, debug: false));

    // Info: avoid_context_state. Quick fix: 'context.read()'.
    describe(context.state.counter);
  }

  void increment() {
    setState(() {
      // Error: select_outside_build. In a closure passed to 'setState'.
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
    // Error: context_in_dispose.
    describe(context.read().counter);

    // Error: context_in_dispose.
    describe(context.state.counter);

    // Error: context_in_dispose.
    describe(context.isWaiting(LoadUser));

    // Error: context_in_dispose.
    describe(context.getEnvironment<AppState>());

    // Error: context_in_dispose. Also in closures inside 'dispose'.
    Future.microtask(() => describe(context.read()));

    // Error: select_outside_build. No quick fix, since 'context.read()' throws too.
    describe(context.select((st) => st.counter));

    context.dispatch(Increment()); // OK: dispatching works in 'dispose'.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Text('Lifecycle');
}

// =====================================================================================
// select_outside_build (error), outside of State methods
// =====================================================================================

class SelectInCallback extends StatelessWidget {
  const SelectInCallback({super.key});

  @override
  Widget build(BuildContext context) => ElevatedButton(
        // Error: select_outside_build. Quick fix: 'context.read().counter'.
        onPressed: () => describe(context.select((st) => st.counter)),
        child: const Text('Print'),
      );
}

class EventInCallback extends StatelessWidget {
  const EventInCallback({super.key});

  @override
  Widget build(BuildContext context) => ElevatedButton(
        // Error: select_outside_build. Events must be consumed in 'build'. No quick fix.
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
            // Error: select_outside_build. The 'context' of 'build', in a builder.
            // Quick fix: use the builder's 'inner'.
            builder: (inner) => Text(context.select((st) => st.name)),
          ),
          Builder(
            // Error: select_outside_build. No quick fix, since the builder's
            // 'BuildContext' is '_'.
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
        // Error: select_outside_build. The 'context' of the State, in a builder.
        builder: (inner) => Text(context.select((st) => st.name)),
      );
}

class SelectInItemBuilder extends StatelessWidget {
  const SelectInItemBuilder({super.key});

  @override
  Widget build(BuildContext context) => ListView.builder(
        // Error: select_outside_build. The 'BuildContext' of an 'itemBuilder' belongs to
        // the list.
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

// =====================================================================================
// context_in_selector (error)
// =====================================================================================

class ContextInSelector extends StatelessWidget {
  const ContextInSelector({super.key});

  @override
  Widget build(BuildContext context) {
    // Error: context_in_selector. Quick fix: replace it with 'st'.
    var name = context.select((st) => context.state.name);

    // Error: context_in_selector. Quick fix: replace it with 'st'.
    var counter = context.select((st) => context.read().counter);

    var user = context.select((st) {
      // Error: context_in_selector. A nested 'select' throws.
      return context.select((s) => s.user);
    });

    var value = context.event((st) {
      // Error: context_in_selector. In the selector of 'context.event'.
      if (context.isWaiting(LoadUser)) describe('waiting');
      return st.evt;
    });

    return Text('$name $counter ${user.name} $value');
  }
}

// =====================================================================================
// vm_field_not_in_equals (warning)
// Quick fixes: add the field to 'equals', or add all missing fields.
// =====================================================================================

class CounterVm extends Vm {
  final int counter;

  // Warning: vm_field_not_in_equals.
  final String description;

  final VoidCallback onIncrement; // OK: functions can't be in 'equals'.

  CounterVm({
    required this.counter,
    required this.description,
    required this.onIncrement,
  }) : super(equals: [counter]);
}

class NoEqualsVm extends Vm {
  // Warning: vm_field_not_in_equals. Without 'equals', all fields are missing.
  final int counter;

  NoEqualsVm({required this.counter});
}

// =====================================================================================
// copy_missing_field (warning)
// Quick fix: add the missing fields to the copy method.
// =====================================================================================

@stateClass
class CopyMissingField {
  final int counter;
  final String name;
  final bool waiting;

  CopyMissingField({required this.counter, this.name = '', this.waiting = false});

  // Warning: copy_missing_field. 'name' has no parameter, and 'waiting' has one but
  // doesn't use it.
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

// =====================================================================================
// state_class_must_be_immutable (warning)
// =====================================================================================

// Warning: state_class_must_be_immutable. 'counter' isn't final.
@stateClass
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

// Warning: state_class_must_be_immutable. Subclasses of a '@stateClass' are checked.
class MutableSubclass extends ImmutableBase {
  String name;

  MutableSubclass({required super.counter, required this.name});

  @override
  bool operator ==(Object other) =>
      other is MutableSubclass && counter == other.counter && name == other.name;

  @override
  int get hashCode => Object.hash(counter, name);
}

// =====================================================================================
// state_class_missing_equality (warning). No quick fix.
// =====================================================================================

// Warning: state_class_missing_equality. Has fields, but no '==' and 'hashCode'.
@stateClass
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

// Warning: state_class_missing_equality. The inherited '==' doesn't know 'name'.
class InheritsEquality extends EqualityBase {
  final String name;

  InheritsEquality({required super.counter, required this.name});
}

// =====================================================================================
// equality_missing_field (warning)
// Quick fix: add the missing fields.
// =====================================================================================

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

  // Warning: equality_missing_field. 'counter' is missing from '=='.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EqualityMissingField &&
          runtimeType == other.runtimeType &&
          waiting == other.waiting &&
          loading == other.loading;

  // Warning: equality_missing_field. 'waiting' is missing from 'hashCode'.
  @override
  int get hashCode => Object.hash(counter, loading);
}

// =====================================================================================
// equality_missing_inherited_field (warning)
// Quick fix: add 'super == other' and 'super.hashCode', or the inherited fields.
// =====================================================================================

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

  // Warning: equality_missing_inherited_field. Doesn't call 'super == other'.
  @override
  bool operator ==(Object other) => other is InheritedFieldSub && name == other.name;

  // Warning: equality_missing_inherited_field. Doesn't use 'super.hashCode'.
  @override
  int get hashCode => name.hashCode;
}

// =====================================================================================
// equatable_props_missing_field (warning)
// Quick fix: add the missing fields to 'props', and '...super.props'.
// =====================================================================================

@stateClass
class EquatableState extends Equatable {
  final int counter;
  final String name;

  const EquatableState({required this.counter, required this.name});

  // Warning: equatable_props_missing_field. 'name' is missing.
  @override
  List<Object?> get props => [counter];
}

class EquatableSub extends EquatableState {
  final bool waiting;

  const EquatableSub(
      {required super.counter, required super.name, required this.waiting});

  // Warning: equatable_props_missing_field. The inherited 'props' are missing. Add
  // '...super.props'.
  @override
  List<Object?> get props => [waiting];
}

// Warning: equatable_props_missing_field. Declares a field, but not 'props', so the
// inherited 'props' doesn't have it.
class EquatableWithoutProps extends EquatableState {
  final bool loading;

  const EquatableWithoutProps({
    required super.counter,
    required super.name,
    required this.loading,
  });
}
