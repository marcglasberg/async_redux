// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// Based upon packages redux by Brian Egan, and flutter_redux by Brian Egan and John Ryan.
// Uses code from package equatable by Felix Angelov.
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:collection/collection.dart' show DeepCollectionEquality;
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

/// The aspect function type for selectors.
/// Takes the new state value and returns true if the widget should rebuild.
typedef SelectorAspect<St> = bool Function(St? value);

/// Storage class for selector dependencies.
/// Stores all selector aspects for a single dependent widget.
class SelectorDependency<St> {
  /// Flag indicating selectors should be cleared on next registration
  bool shouldClearSelectors = false;

  /// Flag tracking if a microtask to clear is scheduled
  bool shouldClearMutationScheduled = false;

  /// List of all aspect functions registered by this widget
  final selectors = <SelectorAspect<St>>[];
}

/// Debug flag to prevent nested select calls.
bool _debugIsSelecting = false;

// Debug flag to enable logging for `select` mechanism (development only).
const bool _debugSelectLogging = false;

/// Provides a Redux [Store] to all descendants of this Widget.
/// This should generally be a root widget in your App.
///
/// Access the store with the extension methods on [BuildContext].
///
/// Subscribe to the values a widget renders with
/// [BuildContextExtensionForProvider.getSelect].
///
/// ```dart
/// var counter = context.select((st) => st.counter);
/// ```
///
/// Use `context.read()` in callbacks and `initState` to read the current state
/// without subscribing to changes.
///
/// You can dispatch actions using the [dispatch], [dispatchAll], [dispatchAndWait],
/// [dispatchAndWaitAll] and [dispatchSync] methods:
///
/// ```dart
/// context.dispatch(action);
/// context.dispatchAll([action1, action2]);
/// context.dispatchAndWait(action);
/// context.dispatchAndWaitAll([action1, action2]);
/// context.dispatchSync(action);
/// ```
///
/// You can also use `context.isWaiting`, `context.isFailed()`, `context.exceptionFor()`
/// and `context.clearExceptionFor()`.
///
/// IMPORTANT: You need to define this extension in your own code:
///
/// ```dart
/// extension BuildContextExtension on BuildContext {
///   R select<R>(R Function(AppState st) selector) => getSelect<AppState, R>(selector);
///   AppState read() => getRead<AppState>();
/// }
/// ```
class StoreProvider<St> extends InheritedWidget {
  final Store<St> _store;

  // Explanation
  // -----------
  //
  // The hierarchy is:
  // StoreProvider -> _InheritedUntypedDoesNotRebuild -> _WidgetListensOnChange -> _InheritedUntypedRebuilds
  //
  // Where:
  // * StoreProvider is a public, <St> TYPED inherited widget, from where we read
  //       the `state` of type `St`.
  //
  // * _InheritedUntypedDoesNotRebuild is an UNTYPED inherited widget used by `dispatch`,
  //       `dispatchAndWait` and `dispatchSync`. That's useful because they can dispatch without
  //       the knowing the St type, but it DOES NOT REBUILD.
  //
  // * _WidgetListensOnChange is a StatefulWidget that listens to the store (onChange) and
  //       rebuilds the whenever there is a new state available.
  //
  // * _InheritedUntypedRebuilds is an UNTYPED inherited widget that is used by `isWaiting`,
  //       `isFailed` and `exceptionFor`. That's useful because these methods can find it without
  //       the knowing the St type, but it REBUILDS. Note: `_InheritedUntypedRebuilds._isOn` is
  //       true only after `state`, `isWaiting`, `isFailed` and `exceptionFor` are used for the
  //       first time. This is to make it faster by avoiding `updateShouldNotify` before this
  //       inner provider is necessary.

  StoreProvider({
    Key? key,
    required Store<St> store,
    required Widget child,
  })  : _store = _init(store),
        super(
          key: key,
          child: _InheritedUntypedDoesNotRebuild(store: store, child: child),
        );

  /// Provides easy access to the AsyncRedux store state from a BuildContext.
  ///
  /// Use this in your widget's build method to read the current store state.
  /// Any widget that calls this WILL rebuild automatically when the state
  /// changes (unless you pass the [notify] parameter as `false`).
  ///
  /// For rendering, use [BuildContextExtensionForProvider.getSelect].
  /// For one-time reads, use [BuildContextExtensionForProvider.getRead].
  static St state<St>(BuildContext context,
      {bool notify = true, Object? debug}) {
    if (notify) {
      final _InheritedUntypedRebuilds? provider = context
          .dependOnInheritedWidgetOfExactType<_InheritedUntypedRebuilds>();

      if (provider == null)
        throw throw _exceptionForWrongStoreType(
            _typeOf<_InheritedUntypedRebuilds>(),
            debug: debug);

      St state;
      try {
        state = provider._store.state as St;
      } catch (error) {
        throw _exceptionForWrongStateType(provider._store.state, St);
      }

      // We only turn on rebuilds when this `state` method is used for the first time.
      // This is to make it faster when this method is not used, which is the
      // case if state is read without subscribing to the whole store.
      _InheritedUntypedRebuilds._isOn = true;

      return state;
    }
    // Get the state without rebuilding when the state later changes.
    else {
      return backdoorInheritedWidget<St>(context, debug: debug).state;
    }
  }

  /// This WILL create a dependency, and WILL potentially rebuild the state.
  /// You don't need `St` to call this method.
  static Store<St> _getStoreWithDependency_Untyped<St>(BuildContext context,
      {Object? debug}) {
    //
    final _InheritedUntypedRebuilds? provider =
        context.dependOnInheritedWidgetOfExactType<_InheritedUntypedRebuilds>();

    if (provider == null)
      throw _exceptionForWrongStoreType(_typeOf<_InheritedUntypedRebuilds>(),
          debug: debug);

    // We only turn on rebuilds when this `state` method is used for the first
    // time. This is to make it faster when this method is not used, which is
    // the case if state is read without subscribing to the whole store.
    _InheritedUntypedRebuilds._isOn = true;

    return provider._store as Store<St>;
  }

  /// This WILL NOT create a dependency, and may NOT rebuild the state.
  /// You don't need `St` to call this method.
  static Store<St> _getStoreNoDependency_Untyped<St>(BuildContext context,
      {Object? debug}) {
    //
    try {
      // Try to get the store from the dependency.
      final element = context.getElementForInheritedWidgetOfExactType<
          _InheritedUntypedDoesNotRebuild>();

      if (element == null)
        throw _exceptionForWrongStoreType(StoreException, debug: debug);

      final widget = element.widget as _InheritedUntypedDoesNotRebuild;
      return widget._store as Store<St>;
    }
    //
    // Try to get the store from the static global backdoor. Only works in
    // production, since in tests there may be more than one store-provider.
    catch (error) {
      try {
        return backdoorStaticGlobal<St>();
      } catch (e) {
        // Swallow.
      }

      // Rethrow the original error when getting the store from the dependency.
      rethrow;
    }
  }

  /// Workaround to capture generics.
  static Type _typeOf<T>() => T;

  /// Dispatch an action with [ReduxAction.dispatch]
  /// with a context extension. Example:
  ///
  /// ```dart
  /// StoreProvider.dispatch(context, MyAction());
  /// ```
  ///
  /// However, it's recommended that you use the built-in `BuildContext` extension instead:
  ///
  /// ```dart
  /// context.dispatch(action)`.
  /// ```
  static FutureOr<ActionStatus> dispatch<St>(
          BuildContext context, ReduxAction<St> action,
          {Object? debug, bool notify = true}) =>
      _getStoreNoDependency_Untyped(context, debug: debug)
          .dispatch(action, notify: notify);

  /// Dispatch an action with [ReduxAction.dispatchSync]
  /// with a context extension. Example:
  ///
  /// ```dart
  /// StoreProvider.dispatchSync(context, MyAction());
  /// ```
  ///
  /// However, it's recommended that you use the built-in `BuildContext` extension instead:
  ///
  /// ```dart
  /// context.dispatchSync(action)`.
  /// ```
  static ActionStatus dispatchSync<St>(
          BuildContext context, ReduxAction<St> action,
          {Object? debug, bool notify = true}) =>
      _getStoreNoDependency_Untyped(context, debug: debug)
          .dispatchSync(action, notify: notify);

  /// Dispatch an action with [ReduxAction.dispatchAndWait]
  /// with a context extension. Example:
  ///
  /// ```dart
  /// var status = await StoreProvider.dispatchAndWait(context, MyAction());
  /// ```
  ///
  /// However, it's recommended that you use the built-in `BuildContext` extension instead:
  ///
  /// ```dart
  /// var status = await context.dispatchAndWait(action)`.
  /// ```
  static Future<ActionStatus> dispatchAndWait<St>(
          BuildContext context, ReduxAction<St> action,
          {Object? debug, bool notify = true}) =>
      _getStoreNoDependency_Untyped(context, debug: debug)
          .dispatchAndWait(action, notify: notify);

  /// Dispatch a list of actions with [ReduxAction.dispatchAll]
  /// with a context extension. Example:
  ///
  /// ```dart
  /// StoreProvider.dispatchAll(context, [Action1(), Action2()]);
  /// ```
  ///
  /// However, it's recommended that you use the built-in `BuildContext` extension instead:
  ///
  /// ```dart
  /// context.dispatchAll([Action1(), Action2()])`.
  /// ```
  static List<ReduxAction<St>> dispatchAll<St>(
    BuildContext context,
    List<ReduxAction<St>> actions, {
    Object? debug,
    bool notify = true,
  }) =>
      _getStoreNoDependency_Untyped<St>(context, debug: debug)
          .dispatchAll(actions, notify: notify);

  /// Dispatch a list of actions with [ReduxAction.dispatchAndWaitAll]
  /// with a context extension. Example:
  ///
  /// ```dart
  /// var status = await StoreProvider.dispatchAndWaitAll(context, [Action1(), Action2()]);
  /// ```
  ///
  /// However, it's recommended that you use the built-in `BuildContext` extension instead:
  ///
  /// ```dart
  /// var status = await context.dispatchAndWaitAll([Action1(), Action2()])`.
  /// ```
  static Future<List<ReduxAction<St>>> dispatchAndWaitAll<St>(
    BuildContext context,
    List<ReduxAction<St>> actions, {
    Object? debug,
    bool notify = true,
  }) =>
      _getStoreNoDependency_Untyped<St>(context, debug: debug)
          .dispatchAndWaitAll(actions, notify: notify);

  /// Returns a future which will complete when the given state [condition] is true.
  /// If the condition is already true when the method is called, the future completes immediately.
  ///
  /// You may also provide a [timeoutMillis], which by default is 10 minutes.
  /// To disable the timeout, make it -1.
  /// If you want, you can modify [Store.defaultTimeoutMillis] to change the default timeout.
  ///
  /// ```dart
  /// var action = await store.waitCondition((state) => state.name == "Bill");
  /// expect(action, isA<ChangeNameAction>());
  /// ```
  static Future<ReduxAction<St>?> waitCondition<St>(
    BuildContext context,
    bool Function(St) condition, {
    int? timeoutMillis,
  }) =>
      backdoorInheritedWidget<St>(context)
          .waitCondition(condition, timeoutMillis: timeoutMillis);

  /// Returns a future that completes when ALL given [actions] finished dispatching.
  ///
  /// Example:
  ///
  /// ```ts
  /// // Dispatching two actions in PARALLEL and waiting for both to finish.
  /// var action1 = ChangeNameAction('Bill');
  /// var action2 = ChangeAgeAction(42);
  /// await waitAllActions([action1, action2]);
  ///
  /// // Compare this to dispatching the actions in SERIES:
  /// await dispatchAndWait(action1);
  /// await dispatchAndWait(action2);
  /// ```
  static Future<void> waitAllActions<St>(
      BuildContext context, List<ReduxAction<St>> actions) {
    if (actions.isEmpty)
      throw StoreException('You have to provide a non-empty list of actions.');
    return backdoorInheritedWidget<St>(context).waitAllActions(actions);
  }

  /// You can use [isWaiting] and pass it [actionOrTypeOrList] to check if:
  /// * A specific async ACTION is currently being processed.
  /// * An async action of a specific TYPE is currently being processed.
  /// * If any of a few given async actions or action types is currently being processed.
  ///
  /// If you wait for an action TYPE, then it returns false when:
  /// - The ASYNC action of the type is NOT currently being processed.
  /// - If the type is not really a type that extends [ReduxAction].
  /// - The action of the type is a SYNC action (since those finish immediately).
  ///
  /// If you wait for an ACTION, then it returns false when:
  /// - The ASYNC action is NOT currently being processed.
  /// - If the action is a SYNC action (since those finish immediately).
  ///
  /// Trying to wait for any other type of object will return null and throw
  /// a [StoreException] after the async gap.
  ///
  /// Widgets that use this method WILL rebuild whenever the state changes
  /// (unless you pass the [notify] parameter as `false`).
  ///
  /// Pass [statusKey] to consider only the actions with that [ReduxAction.statusKey]:
  /// `isWaiting(LoadUser, statusKey: userId)`.
  ///
  static bool isWaiting(
    BuildContext context,
    Object actionOrTypeOrList, {
    Object? statusKey,
    bool notify = true,
  }) =>
      (notify
              ? _getStoreWithDependency_Untyped
              : _getStoreNoDependency_Untyped)(context)
          .isWaiting(actionOrTypeOrList, statusKey: statusKey);

  /// Returns true if an action of the given type failed, with any error, not only with a
  /// [UserException]. Use [exceptionFor] to get the error, if it was a [UserException].
  /// An error swallowed by `wrapError` or the `GlobalErrorObserver` (they returned null),
  /// and an [AbortDispatchException], don't count as failures.
  ///
  /// [actionTypeOrList] can be an action [Type], or an Iterable of action types, in
  /// which case it returns true if any of them failed. Note it does NOT accept an
  /// action, only its type. Any other object, including an action, will return false
  /// and throw a [StoreException] after the async gap.
  ///
  /// It's recommended that you use the BuildContext extension instead:
  ///
  /// ```dart
  /// if (context.isFailed(MyAction)) { // Show an error message. }
  /// ```
  ///
  /// Widgets that use this method WILL rebuild whenever the state changes
  /// (unless you pass the [notify] parameter as `false`).
  ///
  /// Pass [statusKey] to consider only the failures with that [ReduxAction.statusKey]:
  /// `isFailed(LoadUser, statusKey: userId)`.
  ///
  static bool isFailed(
    BuildContext context,
    Object actionTypeOrList, {
    Object? statusKey,
    bool notify = true,
  }) =>
      (notify
              ? _getStoreWithDependency_Untyped
              : _getStoreNoDependency_Untyped)(context)
          .isFailed(actionTypeOrList, statusKey: statusKey);

  /// Returns the [UserException] of the [actionTypeOrList] that failed. Returns null if
  /// it didn't fail, or if it failed with an error that is not a [UserException] (in
  /// that case, [isFailed] is still true).
  ///
  /// The [actionTypeOrList] can be a [Type], or an Iterable of types. Any other type
  /// of object will return null and throw a [StoreException] after the async gap.
  ///
  /// It's recommended that you use the BuildContext extension instead:
  ///
  /// ```dart
  /// if (context.isFailed(SaveUserAction)) Text(context.exceptionFor(SaveUserAction)!.reason ?? '');
  /// ```
  ///
  /// Widgets that use this method WILL rebuild whenever the state changes
  /// (unless you pass the [notify] parameter as `false`).
  ///
  /// Pass [statusKey] to get the exception of the failure with that
  /// [ReduxAction.statusKey]: `exceptionFor(LoadUser, statusKey: userId)`.
  ///
  static UserException? exceptionFor(
    BuildContext context,
    Object actionTypeOrList, {
    Object? statusKey,
    bool notify = true,
  }) =>
      (notify
              ? _getStoreWithDependency_Untyped
              : _getStoreNoDependency_Untyped)(context)
          .exceptionFor(actionTypeOrList, statusKey: statusKey);

  /// Removes the given [actionTypeOrList] from the list of action types that failed.
  ///
  /// Note that dispatching an action already removes that action type from the exceptions list.
  /// This removal happens as soon as the action is dispatched, not when it finishes.
  ///
  /// [actionTypeOrList] can be a [Type], or an Iterable of types. Any other type
  /// of object will return null and throw a [StoreException] after the async gap.
  ///
  /// Widgets that use this method WILL rebuild whenever the state changes
  /// (unless you pass the [notify] parameter as `false`).
  ///
  /// Pass [statusKey] to clear only the failure with that [ReduxAction.statusKey]:
  /// `clearExceptionFor(LoadUser, statusKey: userId)`. Without it, all the failures of
  /// the type are cleared, whatever their keys.
  ///
  static void clearExceptionFor(
    BuildContext context,
    Object actionTypeOrList, {
    Object? statusKey,
    bool notify = true,
  }) =>
      (notify
              ? _getStoreWithDependency_Untyped
              : _getStoreNoDependency_Untyped)(context)
          .clearExceptionFor(actionTypeOrList, statusKey: statusKey);

  /// Avoid using if you don't have a good reason to do so. This is marked as [internal],
  /// so you will have to silence the linter to use it. Use it at your own risk.
  ///
  /// The [backdoorInheritedWidget] gives you direct access to the store for advanced
  /// use-cases. It does NOT create a dependency like [_getStoreWithDependency_Untyped] does,
  /// and it does NOT rebuild the state when the state changes, when you access it like this:
  /// `var state = StoreProvider.backdoorInheritedWidget(context, this).state;`.
  @internal
  static Store<St> backdoorInheritedWidget<St>(BuildContext context,
      {Object? debug}) {
    //
    final element =
        context.getElementForInheritedWidgetOfExactType<StoreProvider<St>>();
    final StoreProvider<St>? provider = element?.widget as StoreProvider<St>?;

    if (provider == null)
      throw _exceptionForWrongStoreType(_typeOf<StoreProvider<St>>(),
          debug: debug);

    return provider._store;
  }

  /// Avoid using if you don't have a good reason to do so. This is marked as [internal],
  /// so you will have to silence the linter to use it. Use it at your own risk.
  ///
  /// The [backdoorStaticGlobal] gives you direct access to the store for
  /// advanced use-cases. It does NOT need the context, as it gets the store
  /// from the static field [_staticStoreBackdoor].
  ///
  /// Note this field is set when the [StoreProvider] is created, which assumes
  /// the [StoreProvider] is used only once in your app. This is usually a
  /// reasonable assumption in production, but can break in tests.
  ///
  /// It is similar to [_getStoreNoDependency_Untyped] in that is does not
  /// create a dependency, but it does not need the context, which means
  /// you can use it anywhere, even outside of the widget tree.
  ///
  /// Use it like this:
  ///
  /// ```dart
  /// var state = StoreProvider.backdoorStaticGlobal<AppState>().state;`.
  /// ```
  ///
  @internal
  static Store<St> backdoorStaticGlobal<St>() {
    if (_staticStoreBackdoor == null)
      throw StoreException('Error: No Redux store found. '
          'Did you forget to use the StoreProvider?');

    if (_staticStoreBackdoor is! Store<St>) {
      var type = _typeOf<Store<St>>;
      throw StoreException(
          'Error: Store is of type ${_staticStoreBackdoor.runtimeType} '
          'and not of type $type. Please provide the correct type.');
    }

    return _staticStoreBackdoor as Store<St>;
  }

  /// Avoid using if you don't have a good reason to do so. This is marked as [internal],
  /// so you will have to silence the linter to use it. Use it at your own risk.
  ///
  @internal
  static Store backdoorStaticGlobalUntyped() {
    if (_staticStoreBackdoor == null)
      throw StoreException('Error: No Redux store found. '
          'Did you forget to use the StoreProvider?');

    return _staticStoreBackdoor!;
  }

  /// See [backdoorStaticGlobal].
  static Store? _staticStoreBackdoor;

  static Store<St> _init<St>(Store<St> store) {
    _staticStoreBackdoor = store;
    return store;
  }

  @override
  bool updateShouldNotify(StoreProvider<St> oldWidget) {
    // Only notify dependents if the store instance changes,
    // not on every state change within the store.
    return _store != oldWidget._store;
  }
}

/// An UNTYPED inherited widget used by `dispatch`, `dispatchAndWait` and
/// `dispatchSync`. That's useful because they can dispatch without the knowing
/// the St type, but it DOES NOT REBUILD.
class _InheritedUntypedDoesNotRebuild extends InheritedWidget {
  final Store _store;

  _InheritedUntypedDoesNotRebuild({
    Key? key,
    required Store store,
    required Widget child,
  })  : _store = store,
        super(
          key: key,
          child: _WidgetListensOnChange(store: store, child: child),
        );

  @override
  bool updateShouldNotify(_InheritedUntypedDoesNotRebuild oldWidget) {
    // Only notify dependents if the store instance changes,
    // not on every state change within the store.
    return _store != oldWidget._store;
  }
}

/// A StatefulWidget that listens to the store (onChange) and
/// rebuilds the whenever there is a new state available.
class _WidgetListensOnChange extends StatefulWidget {
  final Widget child;
  final Store store;

  _WidgetListensOnChange({required this.store, required this.child});

  @override
  _WidgetListensOnChangeState createState() => _WidgetListensOnChangeState();
}

class _WidgetListensOnChangeState extends State<_WidgetListensOnChange> {
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(_WidgetListensOnChange oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.store != oldWidget.store) {
      _subscription?.cancel();
      _listen();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _listen() {
    _subscription = widget.store.onChange.listen((state) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // The Inner InheritedWidget is rebuilt whenever the store's state changes,
    // triggering rebuilds for widgets that depend on the specific parts of the state.
    return _InheritedUntypedRebuilds(
      store: widget.store,
      child: widget.child,
    );
  }
}

/// An UNTYPED inherited widget that is used by `isWaiting`, `isFailed` and `exceptionFor`.
/// That's useful because these methods can find it without the knowing the St type, but
/// it REBUILDS. Note: `_InheritedUntypedRebuilds._isOn` is true only after `state`, `isWaiting`,
/// `isFailed` and `exceptionFor` are used for the first time. This is to make it faster by
/// avoiding `updateShouldNotify` before this inner provider is necessary.
/// This class now also supports selector-based rebuilds for fine-grained state subscriptions.
class _InheritedUntypedRebuilds extends InheritedWidget {
  static var _isOn = false;
  final Store _store;

  _InheritedUntypedRebuilds({
    Key? key,
    required this._store,
    required Widget child,
  })  : super(key: key, child: child);

  @override
  _InheritedUntypedRebuildsElement createElement() {
    return _InheritedUntypedRebuildsElement(this);
  }

  @override
  bool updateShouldNotify(_InheritedUntypedRebuilds oldWidget) {
    return _isOn;
  }
}

/// Custom InheritedElement that supports selector-based rebuilds.
class _InheritedUntypedRebuildsElement extends InheritedElement {
  _InheritedUntypedRebuildsElement(_InheritedUntypedRebuilds widget)
      : super(widget);

  @override
  _InheritedUntypedRebuilds get widget =>
      super.widget as _InheritedUntypedRebuilds;

  @override
  void updateDependencies(Element dependent, Object? aspect) {
    // We need the state type, but this is untyped. We'll handle dynamic selectors.
    final dependencies = getDependencies(dependent);

    // DEBUG: Log dependency registration
    if (_debugSelectLogging) {
      print('[UPDATE_DEPS] Widget: ${dependent.widget.runtimeType}, '
          'Has existing deps: ${dependencies != null}, '
          'Deps type: ${dependencies?.runtimeType}, '
          'Aspect type: ${aspect?.runtimeType}');
    }

    // Already listening to everything - don't override with selector.
    if (dependencies != null && dependencies is! SelectorDependency) {
      if (_debugSelectLogging) {
        print('[UPDATE_DEPS] Already listening to everything, returning');
      }
      return;
    }

    if (aspect is SelectorAspect) {
      // Get or create the dependency object.
      final selectorDependency =
          (dependencies ?? SelectorDependency()) as SelectorDependency;

      if (_debugSelectLogging) {
        print('[UPDATE_DEPS] Selector aspect detected. '
            'Creating new dependency: ${dependencies == null}, '
            'Current selector count: ${selectorDependency.selectors.length}');
      }

      // Clear selectors if flagged (from previous build).
      if (selectorDependency.shouldClearSelectors) {
        if (_debugSelectLogging) {
          print(
              '[UPDATE_DEPS] Clearing ${selectorDependency.selectors.length} old selectors');
        }
        selectorDependency.shouldClearSelectors = false;
        selectorDependency.selectors.clear();
      }

      // Schedule selector clearing for next tick.
      if (selectorDependency.shouldClearMutationScheduled == false) {
        selectorDependency.shouldClearMutationScheduled = true;
        if (_debugSelectLogging) {
          print('[UPDATE_DEPS] Scheduling selector clear for next microtask');
        }
        Future.microtask(() {
          if (_debugSelectLogging) {
            print(
                '[UPDATE_DEPS] Microtask executed - marking selectors for clearing');
          }
          selectorDependency
            ..shouldClearMutationScheduled = false
            ..shouldClearSelectors = true;
        });
      }

      // Add the new selector.
      selectorDependency.selectors.add(aspect);
      setDependencies(dependent, selectorDependency);

      if (_debugSelectLogging) {
        print(
            '[UPDATE_DEPS] Added selector. New count: ${selectorDependency.selectors.length}');
      }
    } else {
      // A dependency without a selector listens to the whole store.
      setDependencies(dependent, const Object());
      if (_debugSelectLogging) {
        print('[UPDATE_DEPS] No aspect - listening to everything');
      }
    }
  }

  @override
  void notifyDependent(InheritedWidget oldWidget, Element dependent) {
    final dependencies = getDependencies(dependent);

    if (_debugSelectLogging) {
      print('[NOTIFY] Widget: ${dependent.widget.runtimeType}, '
          'Has deps: ${dependencies != null}, '
          'Deps type: ${dependencies?.runtimeType}, '
          'Is dirty: ${dependent.dirty}');
    }

    var shouldNotify = false;
    if (dependencies != null) {
      if (dependencies is SelectorDependency) {
        // OPTIMIZATION: Skip if widget is already being rebuilt.
        if (dependent.dirty) {
          if (_debugSelectLogging) {
            print('[NOTIFY] Widget already dirty, skipping');
          }
          return;
        }

        if (_debugSelectLogging) {
          print('[NOTIFY] Checking ${dependencies.selectors.length} selectors');
        }

        // Check each selector.
        int selectorIndex = 0;
        for (final updateShouldNotify in dependencies.selectors) {
          try {
            assert(() {
              _debugIsSelecting = true;
              return true;
            }());

            // Call the aspect function with new value.
            shouldNotify = updateShouldNotify(widget._store.state);

            if (_debugSelectLogging) {
              print('[NOTIFY] Selector $selectorIndex returned: $shouldNotify');
            }
          } finally {
            assert(() {
              _debugIsSelecting = false;
              return true;
            }());
          }

          // OPTIMIZATION: Short-circuit on first true.
          if (shouldNotify) {
            if (_debugSelectLogging) {
              print('[NOTIFY] Selector triggered rebuild, stopping check');
            }
            break;
          }
          selectorIndex++;
        }
      } else {
        // No selectors = watch everything.
        shouldNotify = true;
        if (_debugSelectLogging) {
          print('[NOTIFY] No selectors - watching everything');
        }
      }
    } else {
      // If no dependencies registered yet, notify by default.
      shouldNotify = true;
      if (_debugSelectLogging) {
        print(
            '[NOTIFY] WARNING: No dependencies registered! Notifying by default');
      }
    }

    if (shouldNotify) {
      if (_debugSelectLogging) {
        print('[NOTIFY] >>> REBUILDING ${dependent.widget.runtimeType}');
      }
      dependent.didChangeDependencies();
    } else {
      if (_debugSelectLogging) {
        print('[NOTIFY] Not rebuilding ${dependent.widget.runtimeType}');
      }
    }
  }
}

StoreException _exceptionForWrongStoreType(Type type, {Object? debug}) {
  return StoreException(
      '''Error: No $type found. (debug info: ${debug.runtimeType})

    To fix, please try:
  
  * Wrapping your MaterialApp with the StoreProvider<St>, rather than an individual Route
  * Providing full type information to your Store<St> and StoreProvider<St>
  * Ensure you are using consistent and complete imports. E.g. always use `import 'package:my_app/app_state.dart';
      ''');
}

StoreException _exceptionForWrongStateType(Object? state, Type wrongType) {
  return StoreException(
      'Error: State is of type ${state.runtimeType} but you typed it as $wrongType.');
}

extension BuildContextExtensionForProvider<St> on BuildContext {
  /// Provides easy access to the AsyncRedux store state from a BuildContext.
  ///
  /// This is useful when you want to read the state once, for example
  /// inside an event handler, or in your `initState` method.
  /// Widgets using this will NOT rebuild automatically when the state changes.
  ///
  /// For convenience, it's recommended that you define this extension in your
  /// own code:
  ///
  /// ```dart
  /// extension BuildContextExtension on BuildContext {
  ///   AppState read() => getRead<AppState>();
  ///   R select<R>(R Function(AppState state) selector) => getSelect<AppState, R>(selector);
  ///   R? event<R>(Evt<R> Function(AppState state) selector) => getEvent<AppState, R>(selector);
  /// }
  /// ```
  ///
  /// Then use it like this:
  ///
  /// ```dart
  /// var state = context.read();
  /// ```
  ///
  /// See also:
  ///
  /// - [getSelect] to select a specific part of the state and only rebuild
  ///   when that part changes (use it with `context.select()`).
  ///
  St getRead<St>() => _isMock
      ? (_store.state as St)
      : StoreProvider.state<St>(this, notify: false);

  /// Consume an event from the state, and rebuild the widget when the event is
  /// dispatched.
  ///
  /// Events are one-time notifications that can be used to trigger side effects
  /// in widgets, such as showing a dialog, clearing a text field, or navigating
  /// to a new screen. Unlike regular state values, events are automatically
  /// "consumed" (marked as spent) after being read, ensuring they only trigger
  /// once.
  ///
  /// This method selects an event from the state using the provided [selector]
  /// function, consumes it, and returns its value. The widget will rebuild
  /// whenever a new (unspent) event is dispatched to the store.
  ///
  /// **Return value:**
  /// - For events with no generic type (`Evt`): Returns `true` if the event
  ///   was dispatched, or `false` if it was already spent.
  /// - For events with a value type (`Evt<R>`): Returns the event's value if
  ///   it was dispatched, or `null` if it was already spent.
  ///
  /// For convenience, it's recommended that you define this extension in your
  /// own code:
  ///
  /// ```dart
  /// extension BuildContextExtension on BuildContext {
  ///   AppState read() => getRead<AppState>();
  ///   R select<R>(R Function(AppState state) selector) => getSelect<AppState, R>(selector);
  ///   R? event<R>(Evt<R> Function(AppState state) selector) => getEvent<AppState, R>(selector);
  /// }
  /// ```
  ///
  /// **Example with a boolean (value-less) event (clear text field):**
  ///
  /// In your state:
  /// ```dart
  /// class AppState {
  ///   final Event clearTextEvt;
  ///   AppState({required this.clearTextEvt});
  /// }
  /// ```
  ///
  /// In your action:
  /// ```dart
  /// class ClearTextAction extends ReduxAction<AppState> {
  ///   AppState reduce() => state.copy(clearTextEvt: Event());
  /// }
  /// ```
  ///
  /// In your widget:
  /// ```dart
  /// Widget build(BuildContext context) {
  ///   var clearText = context.event((state) => state.clearTextEvt);
  ///   if (clearText) controller.clear();
  ///   ...
  /// }
  /// ```
  ///
  /// **Example with a typed event (display text in text field):**
  ///
  /// In your state:
  /// ```dart
  /// class AppState {
  ///   final Event<String> changeTextEvt;
  ///   AppState({required this.changeTextEvt});
  /// }
  /// ```
  ///
  /// In your action:
  /// ```dart
  /// class ChangeTextAction extends ReduxAction<AppState> {
  ///   Future<AppState> reduce() async {
  ///     String newText = await fetchTextFromApi();
  ///     return state.copy(changeTextEvt: Event<String>(newText));
  ///   }
  /// }
  /// ```
  ///
  /// In your widget:
  /// ```dart
  /// Widget build(BuildContext context) {
  ///   var newText = context.event((state) => state.changeTextEvt);
  ///   if (newText != null) controller.text = newText;
  ///   ...
  /// }
  /// ```
  ///
  /// **Important notes:**
  /// - Events are consumed only once. After consumption, they are marked as
  ///   "spent" and won't trigger again until a new event is dispatched.
  /// - Each event can be consumed by **only one widget**. If you need multiple
  ///   widgets to react to the same trigger, use separate events in the state
  ///   or consider using [EvtState] instead (which is not consumed).
  /// - Initialize events in the state as spent: `Event.spent()` or
  ///   `Event<T>.spent()`.
  /// - The widget will rebuild when a new event is dispatched, even if it has
  ///   the same internal value as a previous event, because each event instance
  ///   is unique.
  /// - The [selector] function must be pure and not cause side effects.
  ///
  /// See also:
  ///
  /// - [getRead] to read the state without triggering rebuilds.
  /// - [getSelect] to select specific parts of the state and rebuild only when those parts change.
  /// - [Event] class documentation for more details on event behavior and lifecycle.
  ///
  R? getEvent<St, R>(Evt<R> Function(St state) selector) {
    _assertEvent();

    var evt = getSelect<St, Evt<R>>(selector);
    return evt.consume();
  }

  /// Select a specific part of the state and only rebuild when that part changes.
  ///
  /// This method allows fine-grained subscriptions to the state, rebuilding the widget
  /// only when the selected value actually changes, not on every state update.
  ///
  /// For convenience, it's recommended that you define this extension in your
  /// own code:
  ///
  /// ```dart
  /// extension BuildContextExtension on BuildContext {
  ///   AppState read() => getRead<AppState>();
  ///   R select<R>(R Function(AppState state) selector) => getSelect<AppState, R>(selector);
  ///   R? event<R>(Evt<R> Function(AppState state) selector) => getEvent<AppState, R>(selector);
  /// }
  /// ```
  ///
  /// Then use it like this:
  /// ```dart
  /// final userName = context.select((state) => state.user.name);
  /// ```
  ///
  /// The widget will only rebuild when `state.user.name` changes, not when other
  /// parts of the state change.
  ///
  /// The comparison uses deep equality checking, so it works correctly with:
  /// - Primitive values (int, String, bool, etc.)
  /// - Lists (element-by-element comparison)
  /// - Maps (key-value pair comparison)
  /// - Sets (membership comparison)
  /// - Custom classes with proper `==` operator
  /// - IList, ISet, IMap from fast_immutable_collections
  ///
  /// IMPORTANT: The selector function must be pure and not cause side effects.
  /// Do not call other provider methods or dispatch actions inside the selector.
  ///
  /// See also:
  ///
  /// - [getRead] if you don't want the widget to rebuild automatically when
  ///   the state changes (use it with `context.read()`).
  ///
  /// Use it in the widget's `build` method, or in the `didChangeDependencies` method
  /// of a `State`. In debug mode, using it elsewhere, like in callbacks such as
  /// `onPressed`, throws an error.
  ///
  R getSelect<St, R>(R Function(St state) selector) {
    if (_isMock) return selector(_store.state as St);
    _assertSelect();

    // Get the InheritedElement WITHOUT creating a dependency yet.
    final inheritedElement =
        getElementForInheritedWidgetOfExactType<_InheritedUntypedRebuilds>();

    if (inheritedElement == null) {
      throw _exceptionForWrongStoreType(_typeOf<_InheritedUntypedRebuilds>());
    }

    final provider = inheritedElement.widget as _InheritedUntypedRebuilds;

    St state;
    try {
      state = provider._store.state as St;
    } catch (error) {
      throw _exceptionForWrongStateType(provider._store.state, St);
    }

    // We only turn on rebuilds when select is used for the first time
    // (similar to how state() method works).
    _InheritedUntypedRebuilds._isOn = true;

    // Execute selector with debug tracking
    assert(() {
      _debugIsSelecting = true;
      return true;
    }());

    final selected = selector(state);

    assert(() {
      _debugIsSelecting = false;
      return true;
    }());

    if (_debugSelectLogging) {
      print('[SELECT] ${widget.runtimeType} selected value: $selected');
    }

    // Register the dependency with an aspect function.
    dependOnInheritedElement(
      inheritedElement as _InheritedUntypedRebuildsElement,
      aspect: (dynamic newValue) {
        if (newValue == null) {
          return false;
        }

        // Re-run selector with new value and compare.
        assert(() {
          _debugIsSelecting = true;
          return true;
        }());

        St newState;
        try {
          newState = newValue as St;
        } catch (_) {
          return false;
        }

        final newSelected = selector(newState);

        assert(() {
          _debugIsSelecting = false;
          return true;
        }());

        // Use deep equality to compare selected values.
        return !const DeepCollectionEquality().equals(newSelected, selected);
      },
    );

    return selected;
  }

  /// Returns true if this context is building, or if the widgets are being built,
  /// which includes `didChangeDependencies`, and the builders of `LayoutBuilder` and
  /// of lists. Callbacks like `onPressed`, timers and post-frame callbacks run later.
  bool get _debugIsBuilding => debugDoingBuild || (owner?.debugBuilding ?? false);

  void _assertSelect() {
    assert(() {
      final widget = this.widget;

      // Check for unsupported contexts.
      if (widget is SliverWithKeepAliveWidget ||
          widget is AutomaticKeepAliveClientMixin) {
        throw FlutterError(
            'Tried to use `context.select` (or `context.getSelect`) '
            'inside a SliverList/SliderGridView.'
            '\n\n'
            'This is likely a mistake, as instead of rebuilding only the item that cares '
            'about the selected value, this would rebuild the entire list/grid.'
            '\n\n'
            'To fix, add a `Builder` or extract the content of `itemBuilder` in a separate widget:'
            '\n\n'
            'ListView.builder(\n'
            '  itemBuilder: (context, index) {\n'
            '    return Builder(builder: (context) {\n'
            '      final todo = context.select((st) => st.list[index]);\n'
            '      return Text(todo.name);\n'
            '    });\n'
            '  },\n'
            ');\n');
      }

      // Check we're in a build method, or in didChangeDependencies.
      if (!_debugIsBuilding) {
        throw FlutterError(
            'Tried to use `context.select` (or `context.getSelect`) '
            'outside the widget `build` method and `didChangeDependencies`.'
            '\n\n'
            'See also: `context.read()` which you can use in `initState` and events handlers, '
            'because it will not rebuild widgets automatically when the state changes.\n');
      }

      // Check for nested select calls.
      if (_debugIsSelecting) {
        throw FlutterError(
            'Cannot call `context.select` inside the selector of another `context.select`.'
            '\n\n'
            'The selector function must return a value immediately, without calling other selectors.\n');
      }

      return true;
    }());
  }

  void _assertEvent() {
    assert(() {
      final widget = this.widget;

      // Check for unsupported contexts.
      if (widget is SliverWithKeepAliveWidget ||
          widget is AutomaticKeepAliveClientMixin) {
        throw FlutterError(
            'Tried to use `context.event` (or `context.getEvent`) '
            'inside a SliverList/SliderGridView.'
            '\n\n'
            'This is likely a mistake, as instead of rebuilding only the item that cares '
            'about the selected value, this would rebuild the entire list/grid.'
            '\n\n'
            'To fix, add a `Builder` or extract the content of `itemBuilder` in a separate widget:'
            '\n\n'
            'ListView.builder(\n'
            '  itemBuilder: (context, index) {\n'
            '    return Builder(builder: (context) {\n'
            '      var clearText = context.event((state) => state.clearTextEvt);\n'
            '      if (clearText) controller.clear();\n'
            '      return TextField(controller: controller);\n'
            '    });\n'
            '  },\n'
            ');\n');
      }

      // Check we're in a build method, or in didChangeDependencies.
      if (!_debugIsBuilding) {
        throw FlutterError(
            'Tried to use `context.event` (or `context.getEvent`) '
            'outside the widget `build` method and `didChangeDependencies`.\n');
      }

      // Check for nested select calls.
      if (_debugIsSelecting) {
        throw FlutterError(
            'Cannot call `context.event` inside the selector of another `context.event`.'
            '\n\n'
            'The selector function must return a value immediately, without calling other selectors.\n');
      }

      return true;
    }());
  }

  /// Workaround to capture generics (used internally).
  static Type _typeOf<T>() => T;

  /// Dispatches the action, applying its reducer, and possibly changing the store state.
  /// The action may be sync or async.
  ///
  /// ```dart
  /// context.dispatch(MyAction());
  /// ```
  /// If you pass the [notify] parameter as `false`, widgets will not necessarily rebuild because
  /// of this action, even if it changes the state.
  ///
  /// Method [dispatch] is of type [Dispatch].
  ///
  /// See also:
  /// - [dispatchSync] which dispatches sync actions, and throws if the action is async.
  /// - [dispatchAndWait] which dispatches both sync and async actions, and returns a Future.
  ///
  FutureOr<ActionStatus> dispatch(ReduxAction<St> action,
          {bool notify = true}) =>
      _isMock
          ? _store.dispatch(action, notify: notify)
          : StoreProvider.dispatch(this, action, notify: notify);

  /// Dispatches the action, applying its reducer, and possibly changing the store state.
  /// The action may be sync or async. In both cases, it returns a [Future] that resolves when
  /// the action finishes.
  ///
  /// ```dart
  /// await context.dispatchAndWait(DoThisFirstAction());
  /// context.dispatch(DoThisSecondAction());
  /// ```
  ///
  /// If you pass the [notify] parameter as `false`, widgets will not necessarily rebuild because
  /// of this action, even if it changes the state.
  ///
  /// Note: While the state change from the action's reducer will have been applied when the
  /// Future resolves, other independent processes that the action may have started may still
  /// be in progress.
  ///
  /// Method [dispatchAndWait] is of type [DispatchAndWait]. It returns `Future<ActionStatus>`,
  /// which means you can also get the final status of the action after you `await` it:
  ///
  /// ```dart
  /// var status = await context.dispatchAndWait(MyAction());
  /// ```
  ///
  /// See also:
  /// - [dispatch] which dispatches both sync and async actions.
  /// - [dispatchSync] which dispatches sync actions, and throws if the action is async.
  ///
  Future<ActionStatus> dispatchAndWait(ReduxAction<St> action,
          {bool notify = true}) =>
      _isMock
          ? _store.dispatchAndWait(action, notify: notify)
          : StoreProvider.dispatchAndWait(this, action, notify: notify);

  /// Dispatches all given [actions] in parallel, applying their reducer, and
  /// possibly changing the store state.
  ///
  /// ```dart
  /// dispatchAll([BuyAction('IBM'), SellAction('TSLA')]);
  /// ```
  ///
  /// If you pass the [notify] parameter as `false`, widgets will not
  /// necessarily rebuild because of these actions, even if it changes the state.
  ///
  /// See also:
  /// - [dispatch] which dispatches both sync and async actions.
  /// - [dispatchAndWait] which dispatches both sync and async actions, and returns a Future.
  /// - [dispatchAndWaitAll] which dispatches all given actions, and returns a Future.
  /// - [dispatchSync] which dispatches sync actions, and throws if the action is async.
  ///
  List<ReduxAction<St>> dispatchAll<St>(List<ReduxAction<St>> actions,
      {bool notify = true}) {
    return _isMock
        ? _store.dispatchAll(actions, notify: notify) as List<ReduxAction<St>>
        : StoreProvider.dispatchAll<St>(this, actions, notify: notify);
  }

  /// Dispatches all given [actions] in parallel, applying their reducers, and
  /// possibly changing the store state. The actions may be sync or async.
  /// It returns a [Future] that resolves when ALL actions finish.
  ///
  /// ```dart
  /// await context.dispatchAndWaitAll([BuyAction('IBM'), SellAction('TSLA')]);
  /// ```
  ///
  /// If you pass the [notify] parameter as `false`, widgets will not necessarily
  /// rebuild because of these actions, even if they change the state.
  ///
  /// Note: While the state change from the action's reducers will have been
  /// applied when the Future resolves, other independent processes that the
  /// action may have started may still be in progress.
  ///
  /// See also:
  /// - [dispatch] which dispatches both sync and async actions.
  /// - [dispatchAndWait] which dispatches both sync and async actions, and returns a Future.
  /// - [dispatchSync] which dispatches sync actions, and throws if the action is async.
  /// - [dispatchAll] which dispatches all given actions in parallel.
  ///
  Future<List<ReduxAction<St>>> dispatchAndWaitAll<St>(
    List<ReduxAction<St>> actions, {
    bool notify = true,
  }) =>
      _isMock
          ? _store.dispatchAndWaitAll(actions, notify: notify)
              as Future<List<ReduxAction<St>>>
          : StoreProvider.dispatchAndWaitAll(this, actions, notify: notify);

  /// Dispatches the action, applying its reducer, and possibly changing the store state.
  /// However, if the action is ASYNC, it will throw a [StoreException].
  ///
  /// If you pass the [notify] parameter as `false`, widgets will not necessarily
  /// rebuild because of this action, even if it changes the state.
  ///
  /// Method [dispatchSync] is of type [DispatchSync]. It returns `ActionStatus`,
  /// which means you can also get the final status of the action:
  ///
  /// ```dart
  /// var status = context.dispatchSync(MyAction());
  /// ```
  ///
  /// See also:
  /// - [dispatch] which dispatches both sync and async actions.
  /// - [dispatchAndWait] which dispatches both sync and async actions, and returns a Future.
  ///
  ActionStatus dispatchSync(ReduxAction<St> action, {bool notify = true}) =>
      _isMock
          ? _store.dispatchSync(action, notify: notify)
          : StoreProvider.dispatchSync(this, action, notify: notify);

  /// You can use [isWaiting] and pass it [actionOrTypeOrList] to check if:
  /// * A specific async ACTION is currently being processed.
  /// * An async action of a specific TYPE is currently being processed.
  /// * If any of a few given async actions or action types is currently being
  ///   processed.
  ///
  /// If you wait for an action TYPE, then it returns false when:
  /// - The ASYNC action of the type is NOT currently being processed.
  /// - If the type is not really a type that extends [ReduxAction].
  /// - The action of the type is a SYNC action (since those finish immediately).
  ///
  /// If you wait for an ACTION, then it returns false when:
  /// - The ASYNC action is NOT currently being processed.
  /// - If the action is a SYNC action (since those finish immediately).
  ///
  /// Trying to wait for any other type of object will return null and throw
  /// a [StoreException] after the async gap.
  ///
  /// Examples:
  ///
  /// ```dart
  /// // Waiting for an action TYPE:
  /// dispatch(MyAction());
  /// if (context.isWaiting(MyAction)) { // Show a spinner }
  ///
  /// // Waiting for an ACTION:
  /// var action = MyAction();
  /// dispatch(action);
  /// if (context.isWaiting(action)) { // Show a spinner }
  ///
  /// // Waiting for any of the given action TYPES:
  /// dispatch(BuyAction());
  /// if (context.isWaiting([BuyAction, SellAction])) { // Show a spinner }
  /// ```
  ///
  /// Pass [statusKey] to consider only the actions with that [ReduxAction.statusKey]:
  /// `context.isWaiting(LoadUser, statusKey: userId)`. See [ReduxAction.statusKey].
  bool isWaiting(Object actionOrTypeOrList, {Object? statusKey}) => _isMock
      ? _store.isWaiting(actionOrTypeOrList, statusKey: statusKey)
      : StoreProvider.isWaiting(this, actionOrTypeOrList, statusKey: statusKey);

  /// Returns true if an action of the given type failed, with any error, not only with a
  /// [UserException]. Use [exceptionFor] to get the error, if it was a [UserException].
  /// An error swallowed by `wrapError` or the `GlobalErrorObserver` (they returned null),
  /// and an [AbortDispatchException], don't count as failures.
  ///
  /// [actionTypeOrList] can be an action [Type], or an Iterable of action types, in
  /// which case it returns true if any of them failed. Note it does NOT accept an
  /// action, only its type. Any other object, including an action, will return false
  /// and throw a [StoreException] after the async gap.
  ///
  /// Example:
  ///
  /// ```dart
  /// if (context.isFailed(MyAction)) { // Show an error message. }
  /// ```
  ///
  /// Pass [statusKey] to consider only the failures with that [ReduxAction.statusKey]:
  /// `context.isFailed(LoadUser, statusKey: userId)`. See [ReduxAction.statusKey].
  bool isFailed(Object actionTypeOrList, {Object? statusKey}) => _isMock
      ? _store.isFailed(actionTypeOrList, statusKey: statusKey)
      : StoreProvider.isFailed(this, actionTypeOrList, statusKey: statusKey);

  /// Returns the [UserException] of the [actionTypeOrList] that failed. Returns null if
  /// it didn't fail, or if it failed with an error that is not a [UserException] (in
  /// that case, [isFailed] is still true).
  ///
  /// The [actionTypeOrList] can be a [Type], or an Iterable of types. Any other type
  /// of object will return null and throw a [StoreException] after the async gap.
  ///
  /// Example:
  ///
  /// ```dart
  /// if (context.isFailed(SaveUserAction)) Text(context.exceptionFor(SaveUserAction)!.reason ?? '');
  /// ```
  ///
  /// Pass [statusKey] to get the exception of the failure with that
  /// [ReduxAction.statusKey]: `context.exceptionFor(LoadUser, statusKey: userId)`. See
  /// [ReduxAction.statusKey].
  UserException? exceptionFor(Object actionTypeOrList, {Object? statusKey}) => _isMock
      ? _store.exceptionFor(actionTypeOrList, statusKey: statusKey)
      : StoreProvider.exceptionFor(this, actionTypeOrList, statusKey: statusKey);

  /// Removes the given [actionTypeOrList] from the list of action types that failed.
  ///
  /// Note that dispatching an action already removes that action type from the
  /// exceptions list. This removal happens as soon as the action is dispatched,
  /// not when it finishes.
  ///
  /// [actionTypeOrList] can be a [Type], or an Iterable of types. Any other type
  /// of object will return null and throw a [StoreException] after the async gap.
  ///
  /// Pass [statusKey] to clear only the failure with that [ReduxAction.statusKey]:
  /// `context.clearExceptionFor(LoadUser, statusKey: userId)`. Without it, all the
  /// failures of the type are cleared, whatever their keys.
  void clearExceptionFor(Object actionTypeOrList, {Object? statusKey}) => _isMock
      ? _store.clearExceptionFor(actionTypeOrList, statusKey: statusKey)
      : StoreProvider.clearExceptionFor(this, actionTypeOrList, statusKey: statusKey);

  /// Given the BuildContext, provides easy access to the optional AsyncRedux
  /// store "environment" that you may have defined. The environment is considered
  /// immutable and should not change during the app's lifecycle.
  ///
  /// This allows you to show different UI based on the environment (if the app is running
  /// in production, staging, development, testing), for example showing a debug banner
  /// in development environment but not in production.
  ///
  /// Note that accessing the environment does not trigger any widget rebuilds.
  ///
  /// For convenience, given that you will have your own `Environment` class,
  /// it's recommended that you define this extension in your own code:
  ///
  /// ```dart
  /// extension BuildContextExtension on BuildContext {
  ///   Environment get env => getEnvironment<AppState>() as Environment;
  /// }
  /// ```
  ///
  /// Then use it like this:
  ///
  /// ```dart
  /// var environment = context.env;
  /// ```
  ///
  /// Or else you can directly create a boolean getter:
  ///
  /// ```dart
  /// extension BuildContextExtension on BuildContext {
  ///   Environment get _env => getEnvironment<AppState>() as Environment;
  ///   bool get isProduction => _env.isProduction;
  ///   bool get isStaging => _env.isStaging;
  ///   bool get isDevelopment => _env.isDevelopment
  ///   bool get isTesting => _env.isTesting;
  /// }
  /// ```
  ///
  /// Then use it like this:
  ///
  /// ```dart
  /// if (context.isProduction) return Text('Welcome to the app!');
  /// else return Text('Welcome to the development version of the app!');
  /// ```
  Object? getEnvironment<St>() {
    if (_isMock) return _store.environment;

    Store<St> store = StoreProvider.backdoorInheritedWidget<St>(this);
    return store.environment;
  }

  /// Given the BuildContext, provides easy access to the optional AsyncRedux
  /// store "configuration" that you may have defined.
  ///
  /// This allows you to show different UI based on the configuration (if the app should
  /// show certain features, or use certain API endpoints, etc.). The configuration is
  /// considered immutable and should not change during the app's lifecycle.
  ///
  /// Note that accessing the configuration does not trigger any widget rebuilds.
  ///
  /// For convenience, given that you will have your own `Configuration` class,
  /// it's recommended that you define this extension in your own code:
  ///
  /// ```dart
  /// extension BuildContextExtension on BuildContext {
  ///   Configuration get config => getConfiguration<AppState>() as Configuration;
  /// }
  /// ```
  ///
  /// Then use it like this:
  ///
  /// ```dart
  /// var configuration = context.config;
  /// ```
  ///
  /// Or else you can directly create a boolean getter:
  ///
  /// ```dart
  /// extension BuildContextExtension on BuildContext {
  ///   Configuration get _config => getConfiguration<AppState>() as Configuration;
  ///   bool get isA => _config.abTesting.a;
  ///   bool get isB => _config.abTesting.b;
  ///   bool get showAdminFeatures => _config.showAdminFeatures;
  /// }
  /// ```
  ///
  /// Then use it like this:
  ///
  /// ```dart
  /// if (context.isA) return Text('Welcome', style: TextStyle(color: Colors.blue));
  /// else return Text('Welcome', style: TextStyle(color: Colors.red));
  /// ```
  Object? getConfiguration<St>() {
    if (_isMock) return _store.configuration;

    Store<St> store = StoreProvider.backdoorInheritedWidget<St>(this);
    return store.configuration;
  }

  /// Allows [MockBuildContext] to be used for testing.
  bool get _isMock => this is MockBuildContext;

  /// Only use this after checking [_isMock].
  Store get _store => (this as MockBuildContext).store;
}

/// This extension allows you to write `dispatch()` instead of
/// `context.dispatch()` inside the [State] of a [StatefulWidget]. It
/// also works for `dispatchAndWait()`, `dispatchAll()`, `dispatchAndWaitAll()`
/// and `dispatchSync()`.
///
/// - Other methods, like `isWaiting()`, `isFailed()`, `exceptionFor()` and
/// `clearExceptionFor()`, still need the `context`, so that the widget rebuilds
/// when the state changes.
///
/// - It is compatible with testing with [MockBuildContext].
///
/// - If your app has multiple [StoreProvider] widgets, you should continue
/// using `context.dispatch()`.
///
extension StatefulWidgetExtensionForProvider<St> on State {
  //
  /// Dispatches the action, applying its reducer, and possibly changing the
  /// store state. The action may be sync or async.
  ///
  /// ```dart
  /// dispatch(MyAction());
  /// ```
  /// If you pass the [notify] parameter as `false`, widgets will not
  /// necessarily rebuild because of this action, even if it changes the state.
  ///
  /// Method [dispatch] is of type [Dispatch].
  ///
  /// IMPORTANT: You can use `dispatch()` only when your app has a single
  /// [StoreProvider], which is almost always true. Otherwise, you need to use
  /// `context.dispatch()` instead.
  ///
  /// See also:
  /// - [dispatchSync] which dispatches sync actions, and throws if the action is async.
  /// - [dispatchAndWait] which dispatches both sync and async actions, and returns a Future.
  ///
  FutureOr<ActionStatus> dispatch(ReduxAction<St> action,
          {bool notify = true}) =>
      StoreProvider.backdoorStaticGlobal().dispatch(action, notify: notify);

  /// Dispatches the action, applying its reducer, and possibly changing the
  /// store state. The action may be sync or async. In both cases, it returns a
  /// [Future] that resolves when the action finishes.
  ///
  /// ```dart
  /// await dispatchAndWait(DoThisFirstAction());
  /// dispatch(DoThisSecondAction());
  /// ```
  ///
  /// If you pass the [notify] parameter as `false`, widgets will not
  /// necessarily rebuild because of this action, even if it changes the state.
  ///
  /// Note: While the state change from the action's reducer will have been
  /// applied when the Future resolves, other independent processes that the
  /// action may have started may still be in progress.
  ///
  /// Method [dispatchAndWait] is of type [DispatchAndWait]. It returns
  /// `Future<ActionStatus>`, which means you can also get the final status of
  /// the action after you `await` it:
  ///
  /// ```dart
  /// var status = await dispatchAndWait(MyAction());
  /// ```
  ///
  /// IMPORTANT: You can use `dispatchAndWait()` only when your app has a single
  /// [StoreProvider], which is almost always true. Otherwise, you need to use
  /// `context.dispatchAndWait()` instead.
  ///
  /// See also:
  /// - [dispatch] which dispatches both sync and async actions.
  /// - [dispatchSync] which dispatches sync actions, and throws if the action is async.
  ///
  Future<ActionStatus> dispatchAndWait(ReduxAction<St> action,
          {bool notify = true}) =>
      StoreProvider.backdoorStaticGlobal()
          .dispatchAndWait(action, notify: notify);

  /// Dispatches all given [actions] in parallel, applying their reducer, and
  /// possibly changing the store state.
  ///
  /// ```dart
  /// dispatchAll([BuyAction('IBM'), SellAction('TSLA')]);
  /// ```
  ///
  /// If you pass the [notify] parameter as `false`, widgets will not
  /// necessarily rebuild because of these actions, even if it changes the state.
  ///
  /// IMPORTANT: You can use `dispatchAll()` only when your app has a single
  /// [StoreProvider], which is almost always true. Otherwise, you need to use
  /// `context.dispatchAll()` instead.
  ///
  /// See also:
  /// - [dispatch] which dispatches both sync and async actions.
  /// - [dispatchAndWait] which dispatches both sync and async actions, and returns a Future.
  /// - [dispatchAndWaitAll] which dispatches all given actions, and returns a Future.
  /// - [dispatchSync] which dispatches sync actions, and throws if the action is async.
  ///
  List<ReduxAction<St>> dispatchAll<St>(List<ReduxAction<St>> actions,
          {bool notify = true}) =>
      StoreProvider.backdoorStaticGlobal().dispatchAll(actions, notify: notify)
          as List<ReduxAction<St>>;

  /// Dispatches all given [actions] in parallel, applying their reducers, and
  /// possibly changing the store state. The actions may be sync or async.
  /// It returns a [Future] that resolves when ALL actions finish.
  ///
  /// ```dart
  /// await dispatchAndWaitAll([BuyAction('IBM'), SellAction('TSLA')]);
  /// ```
  ///
  /// If you pass the [notify] parameter as `false`, widgets will not
  /// necessarily rebuild because of these actions, even if they change the state.
  ///
  /// Note: While the state change from the action's reducers will have been
  /// applied when the Future resolves, other independent processes that the
  /// action may have started may still be in progress.
  ///
  /// IMPORTANT: You can use `dispatchAndWaitAll()` only when your app has a single
  /// [StoreProvider], which is almost always true. Otherwise, you need to use
  /// `context.dispatchAndWaitAll()` instead.
  ///
  /// See also:
  /// - [dispatch] which dispatches both sync and async actions.
  /// - [dispatchAndWait] which dispatches both sync and async actions, and returns a Future.
  /// - [dispatchSync] which dispatches sync actions, and throws if the action is async.
  /// - [dispatchAll] which dispatches all given actions in parallel.
  ///
  Future<List<ReduxAction<St>>> dispatchAndWaitAll<St>(
    List<ReduxAction<St>> actions, {
    bool notify = true,
  }) =>
      StoreProvider.backdoorStaticGlobal().dispatchAndWaitAll(actions,
          notify: notify) as Future<List<ReduxAction<St>>>;

  /// Dispatches the action, applying its reducer, and possibly changing the store
  /// state. However, if the action is ASYNC, it will throw a [StoreException].
  ///
  /// If you pass the [notify] parameter as `false`, widgets will not
  /// necessarily rebuild because of this action, even if it changes the state.
  ///
  /// Method [dispatchSync] is of type [DispatchSync]. It returns `ActionStatus`,
  /// which means you can also get the final status of the action:
  ///
  /// ```dart
  /// var status = dispatchSync(MyAction());
  /// ```
  ///
  /// IMPORTANT: You can use `dispatchSync()` only when your app has a single
  /// [StoreProvider], which is almost always true. Otherwise, you need to use
  /// `context.dispatchSync()` instead.
  ///
  /// See also:
  /// - [dispatch] which dispatches both sync and async actions.
  /// - [dispatchAndWait] which dispatches both sync and async actions, and returns a Future.
  ///
  ActionStatus dispatchSync(ReduxAction<St> action, {bool notify = true}) =>
      StoreProvider.backdoorStaticGlobal().dispatchSync(action, notify: notify);
}

/// This extension allows you to write `dispatch()` instead of
/// `context.dispatch()` inside a [StatelessWidget]. It also works for
/// `dispatchAndWait()`, `dispatchAll()`, `dispatchAndWaitAll()` and
/// `dispatchSync()`.
///
/// - Other methods, like `isWaiting()`, `isFailed()`, `exceptionFor()` and
/// `clearExceptionFor()`, still need the `context`, so that the widget rebuilds
/// when the state changes.
///
/// - It is compatible with testing with [MockBuildContext].
///
/// - If your app has multiple [StoreProvider] widgets, you should continue
/// using `context.dispatch()`.
///
extension StatelessWidgetExtensionForProvider<St>
    on StatelessWidget {
  //
  /// Dispatches the action, applying its reducer, and possibly changing the
  /// store state. The action may be sync or async.
  ///
  /// ```dart
  /// dispatch(MyAction());
  /// ```
  /// If you pass the [notify] parameter as `false`, widgets will not
  /// necessarily rebuild because of this action, even if it changes the state.
  ///
  /// Method [dispatch] is of type [Dispatch].
  ///
  /// IMPORTANT: You can use `dispatch()` only when your app has a single
  /// [StoreProvider], which is almost always true. Otherwise, you need to use
  /// `context.dispatch()` instead.
  ///
  /// See also:
  /// - [dispatchSync] which dispatches sync actions, and throws if the action is async.
  /// - [dispatchAndWait] which dispatches both sync and async actions, and returns a Future.
  ///
  FutureOr<ActionStatus> dispatch(ReduxAction<St> action,
          {bool notify = true}) =>
      StoreProvider.backdoorStaticGlobal().dispatch(action, notify: notify);

  /// Dispatches the action, applying its reducer, and possibly changing the
  /// store state. The action may be sync or async. In both cases, it returns a
  /// [Future] that resolves when the action finishes.
  ///
  /// ```dart
  /// await dispatchAndWait(DoThisFirstAction());
  /// dispatch(DoThisSecondAction());
  /// ```
  ///
  /// If you pass the [notify] parameter as `false`, widgets will not
  /// necessarily rebuild because of this action, even if it changes the state.
  ///
  /// Note: While the state change from the action's reducer will have been
  /// applied when the Future resolves, other independent processes that the
  /// action may have started may still be in progress.
  ///
  /// Method [dispatchAndWait] is of type [DispatchAndWait]. It returns
  /// `Future<ActionStatus>`, which means you can also get the final status of
  /// the action after you `await` it:
  ///
  /// ```dart
  /// var status = await dispatchAndWait(MyAction());
  /// ```
  ///
  /// IMPORTANT: You can use `dispatchAndWait()` only when your app has a single
  /// [StoreProvider], which is almost always true. Otherwise, you need to use
  /// `context.dispatchAndWait()` instead.
  ///
  /// See also:
  /// - [dispatch] which dispatches both sync and async actions.
  /// - [dispatchSync] which dispatches sync actions, and throws if the action is async.
  ///
  Future<ActionStatus> dispatchAndWait(ReduxAction<St> action,
          {bool notify = true}) =>
      StoreProvider.backdoorStaticGlobal()
          .dispatchAndWait(action, notify: notify);

  /// Dispatches all given [actions] in parallel, applying their reducer, and
  /// possibly changing the store state.
  ///
  /// ```dart
  /// dispatchAll([BuyAction('IBM'), SellAction('TSLA')]);
  /// ```
  ///
  /// If you pass the [notify] parameter as `false`, widgets will not
  /// necessarily rebuild because of these actions, even if it changes the state.
  ///
  /// IMPORTANT: You can use `dispatchAll()` only when your app has a single
  /// [StoreProvider], which is almost always true. Otherwise, you need to use
  /// `context.dispatchAll()` instead.
  ///
  /// See also:
  /// - [dispatch] which dispatches both sync and async actions.
  /// - [dispatchAndWait] which dispatches both sync and async actions, and returns a Future.
  /// - [dispatchAndWaitAll] which dispatches all given actions, and returns a Future.
  /// - [dispatchSync] which dispatches sync actions, and throws if the action is async.
  ///
  List<ReduxAction<St>> dispatchAll<St>(List<ReduxAction<St>> actions,
          {bool notify = true}) =>
      StoreProvider.backdoorStaticGlobal().dispatchAll(actions, notify: notify)
          as List<ReduxAction<St>>;

  /// Dispatches all given [actions] in parallel, applying their reducers, and
  /// possibly changing the store state. The actions may be sync or async.
  /// It returns a [Future] that resolves when ALL actions finish.
  ///
  /// ```dart
  /// await dispatchAndWaitAll([BuyAction('IBM'), SellAction('TSLA')]);
  /// ```
  ///
  /// If you pass the [notify] parameter as `false`, widgets will not
  /// necessarily rebuild because of these actions, even if they change the state.
  ///
  /// Note: While the state change from the action's reducers will have been
  /// applied when the Future resolves, other independent processes that the
  /// action may have started may still be in progress.
  ///
  /// IMPORTANT: You can use `dispatchAndWaitAll()` only when your app has a single
  /// [StoreProvider], which is almost always true. Otherwise, you need to use
  /// `context.dispatchAndWaitAll()` instead.
  ///
  /// See also:
  /// - [dispatch] which dispatches both sync and async actions.
  /// - [dispatchAndWait] which dispatches both sync and async actions, and returns a Future.
  /// - [dispatchSync] which dispatches sync actions, and throws if the action is async.
  /// - [dispatchAll] which dispatches all given actions in parallel.
  ///
  Future<List<ReduxAction<St>>> dispatchAndWaitAll<St>(
    List<ReduxAction<St>> actions, {
    bool notify = true,
  }) =>
      StoreProvider.backdoorStaticGlobal().dispatchAndWaitAll(actions,
          notify: notify) as Future<List<ReduxAction<St>>>;

  /// Dispatches the action, applying its reducer, and possibly changing the store
  /// state. However, if the action is ASYNC, it will throw a [StoreException].
  ///
  /// If you pass the [notify] parameter as `false`, widgets will not
  /// necessarily rebuild because of this action, even if it changes the state.
  ///
  /// Method [dispatchSync] is of type [DispatchSync]. It returns `ActionStatus`,
  /// which means you can also get the final status of the action:
  ///
  /// ```dart
  /// var status = dispatchSync(MyAction());
  /// ```
  ///
  /// IMPORTANT: You can use `dispatchSync()` only when your app has a single
  /// [StoreProvider], which is almost always true. Otherwise, you need to use
  /// `context.dispatchSync()` instead.
  ///
  /// See also:
  /// - [dispatch] which dispatches both sync and async actions.
  /// - [dispatchAndWait] which dispatches both sync and async actions, and returns a Future.
  ///
  ActionStatus dispatchSync(ReduxAction<St> action, {bool notify = true}) =>
      StoreProvider.backdoorStaticGlobal().dispatchSync(action, notify: notify);
}
