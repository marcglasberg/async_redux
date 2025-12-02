// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// Based upon packages redux by Brian Egan, and flutter_redux by Brian Egan and John Ryan.
// Uses code from package equatable by Felix Angelov.
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

import 'dart:async';
import 'dart:collection';

import 'package:async_redux/async_redux.dart';
import 'package:collection/collection.dart' show DeepCollectionEquality;
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';

/// Convert the entire [Store] into a [Model]. The [Model] will
/// be used to build a Widget using the [ViewModelBuilder].
typedef StoreConverter<St, Model> = Model Function(Store<St> store);

/// A function that will be run when the [StoreConnector] is initialized (using
/// the [State.initState] method). This can be useful for dispatching actions
/// that fetch data for your Widget when it is first displayed.
typedef OnInitCallback<St> = void Function(Store<St> store);

/// A function that will be run when the StoreConnector is removed from the Widget Tree.
/// It is run in the [State.dispose] method.
/// This can be useful for dispatching actions that remove stale data from your State tree.
typedef OnDisposeCallback<St> = void Function(Store<St> store);

/// A test of whether or not your `converter` or `vm` function should run in
/// response to a State change. For advanced use only.
/// Some changes to the State of your application will mean your `converter`
/// or `vm` function can't produce a useful Model. In these cases, such as when
/// performing exit animations on data that has been removed from your Store,
/// it can be best to ignore the State change while your animation completes.
/// To ignore a change, provide a function that returns true or false. If the
/// returned value is false, the change will be ignored.
/// If you ignore a change, and the framework needs to rebuild the Widget, the
/// `builder` function will be called with the latest Model produced
/// by your `converter` or `vm` functions.
typedef ShouldUpdateModel<St> = bool Function(St state);

/// A function that will be run on state change, before the build method.
/// This function is passed the `Model`, and if `distinct` is `true`,
/// it will only be called if the `Model` changes.
/// This is useful for making calls to other classes, such as a
/// `Navigator` or `TabController`, in response to state changes.
/// It can also be used to trigger an action based on the previous state.
typedef OnWillChangeCallback<St, Model> = void Function(
    BuildContext? context, Store<St> store, Model previousVm, Model newVm);

/// A function that will be run on State change, after the build method.
///
/// This function is passed the `Model`, and if `distinct` is `true`,
/// it will only be called if the `Model` changes.
/// This can be useful for running certain animations after the build is complete.
/// Note: Using a [BuildContext] inside this callback can cause problems if
/// the callback performs navigation. For navigation purposes, please use
/// an [OnWillChangeCallback].
typedef OnDidChangeCallback<St, Model> = void Function(
    BuildContext? context, Store<St> store, Model viewModel);

/// A function that will be run after the Widget is built the first time.
/// This function is passed the store and the initial `Model` created by the [vm]
/// or the [converter] function. This can be useful for starting certain animations,
/// such as showing Snackbars, after the Widget is built the first time.
typedef OnInitialBuildCallback<St, Model> = void Function(
    BuildContext? context, Store<St> store, Model viewModel);

/// Build a Widget using the [BuildContext] and [Model].
/// The [Model] is derived from the [Store] using a [StoreConverter].
typedef ViewModelBuilder<Model> = Widget Function(
  BuildContext context,
  Model vm,
);

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

abstract class StoreConnectorInterface<St, Model> {
  VmFactory<St, dynamic, dynamic> Function()? get vm;

  StoreConverter<St, Model>? get converter;

  bool? get distinct;

  OnInitCallback<St>? get onInit;

  OnDisposeCallback<St>? get onDispose;

  bool get rebuildOnChange;

  ShouldUpdateModel<St>? get shouldUpdateModel;

  OnWillChangeCallback<St, Model>? get onWillChange;

  OnDidChangeCallback<St, Model>? get onDidChange;

  OnInitialBuildCallback<St, Model>? get onInitialBuild;

  Object? get debug;
}

/// Build a widget based on the state of the [Store].
///
/// Before the [builder] is run, the [converter] will convert the store into a
/// more specific `Model` tailored to the Widget being built.
///
/// Every time the store changes, the Widget will be rebuilt. As a performance
/// optimization, the Widget can be rebuilt only when the [Model] changes.
/// In order for this to work correctly, you must implement [==] and [hashCode] for
/// the [Model], and set the [distinct] option to true when creating your StoreConnector.
///
/// **IMPORTANT:**
///  With the release of [MockBuildContext], the [StoreConnector] is now
///  considered deprecated. It will not be marked as deprecated and will not be
///  removed, but you should avoid it for new code.
///  For new code, prefer [BuildContext] extensions with [MockBuildContext] for
///  testing.
///
///  The goal of [StoreConnector] was to separate dumb widgets from smart
///  widgets and let you test the view model without mounting it. Then you could
///  test the dumb widget with simple presentation tests.
///  `MockBuildContext` gives you the same benefits, because the dumb widget
///  itself, when built with a mock context, works as the view model you can
///  inspect and use to call callbacks.
///
///  This makes `StoreConnector` unnecessary. `MockBuildContext` is simpler to
///  use and avoids extra view model classes and factories.
///
class StoreConnector<St, Model> extends StatelessWidget
    implements StoreConnectorInterface<St, Model> {
  //
  /// Build a Widget using the [BuildContext] and [Model]. The [Model]
  /// is created by the [vm] or [converter] functions.
  final ViewModelBuilder<Model> builder;

  /// Convert the [Store] into a [Model]. The resulting [Model] will be
  /// passed to the [builder] function.
  @override
  final VmFactory<St, dynamic, dynamic> Function()? vm;

  /// Convert the [Store] into a [Model]. The resulting [Model] will be
  /// passed to the [builder] function.
  @override
  final StoreConverter<St, Model>? converter;

  /// When [distinct] is true (the default), the Widget is rebuilt only
  /// when the [Model] changes. In order for this to work correctly, you
  /// must implement [==] and [hashCode] for the [Model].
  @override
  final bool? distinct;

  /// A function that will be run when the StoreConnector is initially created.
  /// It is run in the [State.initState] method.
  /// This can be useful for dispatching actions that fetch data for your Widget
  /// when it is first displayed.
  @override
  final OnInitCallback<St>? onInit;

  /// A function that will be run when the StoreConnector is removed from the
  /// Widget Tree. It is run in the [State.dispose] method.
  /// This can be useful for dispatching actions that remove stale data from your State tree.
  @override
  final OnDisposeCallback<St>? onDispose;

  /// Determines whether the Widget should be rebuilt when the Store emits an onChange event.
  @override
  final bool rebuildOnChange;

  /// A test of whether or not your [vm] or [converter] function should run in
  /// response to a State change. For advanced use only.
  /// Some changes to the State of your application will mean your [vm] or
  /// [converter] function can't produce a useful Model. In these cases, such as
  /// when performing exit animations on data that has been removed from your Store,
  /// it can be best to ignore the State change while your animation completes.
  /// To ignore a change, provide a function that returns true or false.
  /// If the returned value is true, the change will be applied.
  /// If the returned value is false, the change will be ignored.
  /// If you ignore a change, and the framework needs to rebuild the Widget,
  /// the [builder] function will be called with the latest [Model] produced
  /// by your [vm] or [converter] function.
  @override
  final ShouldUpdateModel<St>? shouldUpdateModel;

  /// A function that will be run on State change, before the Widget is built.
  /// This function is passed the `Model`, and if `distinct` is `true`,
  /// it will only be called if the `Model` changes.
  /// This can be useful for imperative calls to things like Navigator, TabController, etc
  @override
  final OnWillChangeCallback<St, Model>? onWillChange;

  /// A function that will be run on State change, after the Widget is built.
  /// This function is passed the `Model`, and if `distinct` is `true`,
  /// it will only be called if the `Model` changes.
  /// This can be useful for running certain animations after the build is complete.
  /// Note: Using a [BuildContext] inside this callback can cause problems if
  /// the callback performs navigation. For navigation purposes, please use [onWillChange].
  @override
  final OnDidChangeCallback<St, Model>? onDidChange;

  /// A function that will be run after the Widget is built the first time.
  /// This function is passed the store and the initial `Model` created by
  /// the `vm` or the `converter` function. This can be useful for starting certain
  /// animations, such as showing snackbars, after the Widget is built the first time.
  @override
  final OnInitialBuildCallback<St, Model>? onInitialBuild;

  /// Pass the parameter `debug: this` to get a more detailed error message.
  @override
  final Object? debug;

  const StoreConnector({
    Key? key,
    required this.builder,
    this.distinct,
    this.vm, // Recommended.
    this.converter, // Can be used instead of `vm`.
    this.debug,
    this.onInit,
    this.onDispose,
    this.rebuildOnChange = true,
    this.shouldUpdateModel,
    this.onWillChange,
    this.onDidChange,
    this.onInitialBuild,
  })  : assert(converter == null || vm == null,
            "You can't provide both `converter` and `vm`."),
        assert(converter != null || vm != null,
            "You should provide the `converter` or the `vm` parameter."),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return _StoreStreamListener<St, Model>(
      store: StoreProvider.backdoorInheritedWidget<St>(context, debug: debug),
      debug: debug,
      storeConnector: this,
      builder: builder,
      converter: converter,
      vm: vm,
      distinct: distinct,
      onInit: onInit,
      onDispose: onDispose,
      rebuildOnChange: rebuildOnChange,
      shouldUpdateModel: shouldUpdateModel,
      onWillChange: onWillChange,
      onDidChange: onDidChange,
      onInitialBuild: onInitialBuild,
    );
  }

  /// This is not used directly by the store, but may be used in tests.
  /// If you have a store and a StoreConnector, and you want its associated
  /// ViewModel, you can do:
  /// `Model viewModel = storeConnector.getLatestModel(store);`
  ///
  /// And if you want to build the widget:
  /// `var widget = (storeConnector as dynamic).builder(context, viewModel);`
  ///
  Model getLatestModel(Store store) {
    //
    // The `vm` parameter is recommended.
    if (vm != null) {
      var factory = vm!();
      internalsVmFactoryInject(factory, store.state, store);
      return internalsVmFactoryFromStore(factory) as Model;
    }
    //
    // The `converter` parameter can be used instead of `vm`.
    else if (converter != null) {
      return converter!(store as Store<St>);
    }
    //
    else
      throw AssertionError("View-model can't be created. "
          "Please provide the vm or the converter parameter.");
  }
}

/// Listens to the store and calls builder whenever the store changes.
class _StoreStreamListener<St, Model> extends StatefulWidget {
  final ViewModelBuilder<Model> builder;
  final StoreConverter<St, Model>? converter;
  final VmFactory<St, dynamic, dynamic> Function()? vm;
  final Store<St> store;
  final Object? debug;
  final StoreConnectorInterface storeConnector;
  final bool rebuildOnChange;
  final bool? distinct;
  final OnInitCallback<St>? onInit;
  final OnDisposeCallback<St>? onDispose;
  final ShouldUpdateModel<St>? shouldUpdateModel;
  final OnWillChangeCallback<St, Model>? onWillChange;
  final OnDidChangeCallback<St, Model>? onDidChange;
  final OnInitialBuildCallback<St, Model>? onInitialBuild;

  const _StoreStreamListener({
    Key? key,
    required this.builder,
    required this.store,
    required this.debug,
    required this.converter,
    required this.vm,
    required this.storeConnector,
    this.distinct,
    this.onInit,
    this.onDispose,
    this.rebuildOnChange = true,
    this.onWillChange,
    this.onDidChange,
    this.onInitialBuild,
    this.shouldUpdateModel,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _StoreStreamListenerState<St, Model>();
  }
}

/// If the StoreConnector throws an error.
class _ConverterError extends Error {
  final Object? debug;

  /// The error thrown while running the [StoreConnector.converter] function.
  final Object error;

  /// The stacktrace that accompanies the [error]
  @override
  final StackTrace stackTrace;

  /// Creates a ConverterError with the relevant error and stacktrace.
  _ConverterError(this.error, this.stackTrace, this.debug);

  @override
  String toString() {
    return "Error creating the view model"
        "${debug == null ? '' : ' (${debug.runtimeType})'}: "
        "$error\n\n"
        "$stackTrace\n\n";
  }
}

class _StoreStreamListenerState<St, Model> //
    extends State<_StoreStreamListener<St, Model>> {
  Stream<Model>? _stream;
  Model? _latestModel;
  _ConverterError? _latestError;

  // If `widget.distinct` was passed, use it. Otherwise, use the store default.
  bool get _distinct => widget.distinct ?? widget.store.defaultDistinct;

  /// if [StoreConnector.shouldUpdateModel] returns false, we need to know the
  /// most recent VALID state (it was valid when [StoreConnector.shouldUpdateModel]
  /// returned true). We save all valid states into [_mostRecentValidState], and
  /// when we need to use it we put it into [_forceLastValidStreamState].
  St? _mostRecentValidState, _forceLastValidStreamState;

  @override
  void initState() {
    if (widget.onInit != null) {
      widget.onInit!(widget.store);
    }

    _computeLatestModel();
    if (widget.shouldUpdateModel != null) {
      // The initial state has to be valid at this point.
      // This is needed so that the first stream event
      // can be compared against a baseline.
      _mostRecentValidState = widget.store.state;
    }

    if ((widget.onInitialBuild != null) && (_latestModel != null)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onInitialBuild!(
          mounted ? context : null,
          widget.store,
          _latestModel!,
        );
      });
    }

    _createStream();

    super.initState();
  }

  @override
  void dispose() {
    if (widget.onDispose != null) {
      widget.onDispose!(widget.store);
    }

    super.dispose();
  }

  @override
  void didUpdateWidget(_StoreStreamListener<St, Model> oldWidget) {
    _computeLatestModel();

    if (widget.store != oldWidget.store) {
      _createStream();
    }

    super.didUpdateWidget(oldWidget);
  }

  void _computeLatestModel() {
    try {
      _latestError = null;
      _latestModel =
          getLatestModel(_forceLastValidStreamState ?? widget.store.state);
    } catch (error, stacktrace) {
      _latestModel = null;
      _latestError = _ConverterError(error, stacktrace, widget.debug);
    }
  }

  void _createStream() => _stream = widget.store.onChange
      // This prevents unnecessary calculations of the view-model.
      .where(_stateChanged)
      // Discards invalid states.
      .where(_shouldUpdateModel)
      // Calculates the view-model using the `vm` or `converter` functions.
      .map(_calculateModel)
      // Don't use `Stream.distinct` because it cannot capture the initial
      // ViewModel produced by the `converter`.
      .where(_whereDistinct)
      // Updates the latest-model with the calculated vm.
      // Important: This must be done after all other optional
      // transformations, such as shouldUpdateModel.
      .transform(StreamTransformer.fromHandlers(
        handleData: _handleData as void Function(Model?, EventSink<Model>)?,
        handleError: _handleError,
      ));

  // This prevents unnecessary calculations of the view-model.
  bool _stateChanged(St state) {
    return !identical(_mostRecentValidState, widget.store.state) ||
        _actionsInProgressHaveChanged();
  }

  /// Used by [_actionsInProgressHaveChanged].
  Set<ReduxAction<St>> _lastActionsInProgress =
      HashSet<ReduxAction<St>>.identity();

  /// Returns true if the actions in progress have changed since the last time we checked.
  bool _actionsInProgressHaveChanged() {
    if (widget.store.actionsInProgressEqualTo(_lastActionsInProgress))
      return false;
    else {
      _lastActionsInProgress = widget.store.copyActionsInProgress();
      return true;
    }
  }

  // If `shouldUpdateModel` is provided, it will calculate if the STORE state contains
  // a valid state which may be used to calculate the view-model. If this is not the
  // case, we revert to the last known valid state, which may be a STORE state or a
  // STREAM state. Note the view-model is always calculated from the STORE state,
  // which is always the same or more recent than the STREAM state. We could greatly
  // simplify all of this if the view-model used the STREAM state. However, this would
  // mean some small delay in the UI, and there is also the problem that the converter
  // parameter uses the STORE.
  bool _shouldUpdateModel(St state) {
    if (widget.shouldUpdateModel == null)
      return true;
    else {
      _forceLastValidStreamState = null;
      bool ifStoreHasValidModel = widget.shouldUpdateModel!(widget.store.state);
      if (ifStoreHasValidModel) {
        _mostRecentValidState = widget.store.state;
        return true;
      }
      //
      else {
        //
        bool ifStreamHasValidModel = widget.shouldUpdateModel!(state);
        if (ifStreamHasValidModel) {
          _mostRecentValidState = state;
          return false;
        } else {
          if (identical(state, widget.store.state)) {
            _forceLastValidStreamState = _mostRecentValidState;
          }
        }
      }

      return (_forceLastValidStreamState != null);
    }
  }

  Model? _calculateModel(St state) =>
      getLatestModel(_forceLastValidStreamState ?? widget.store.state);

  // Don't use `Stream.distinct` since it can't capture the initial vm.
  bool _whereDistinct(Model? vm) {
    if (_distinct) {
      bool isDistinct = _isDistinct(vm);

      _observeWithTheModelObserver(
        modelPrevious: _latestModel,
        modelCurrent: vm,
        isDistinct: isDistinct,
      );

      return isDistinct;
    } else
      return true;
  }

  bool _isDistinct(Model? vm) {
    if ((vm is ImmutableCollection) &&
        (_latestModel is ImmutableCollection) &&
        widget.store.immutableCollectionEquality != null) {
      if (widget.store.immutableCollectionEquality == CompareBy.byIdentity)
        return areSameImmutableCollection(
            vm, _latestModel as ImmutableCollection?);
      if (widget.store.immutableCollectionEquality == CompareBy.byDeepEquals) {
        return areImmutableCollectionsWithEqualItems(
            vm, _latestModel as ImmutableCollection?);
      } else
        throw AssertionError(widget.store.immutableCollectionEquality);
    } else
      return vm != _latestModel;
  }

  void _handleData(Model vm, EventSink<Model> sink) {
    //
    if (!_distinct)
      _observeWithTheModelObserver(
        modelPrevious: _latestModel,
        modelCurrent: vm,
        isDistinct: _distinct,
      );

    _latestError = null;

    if ((widget.onWillChange != null) && (_latestModel != null)) {
      widget.onWillChange!(
        mounted ? context : null,
        widget.store,
        _latestModel!,
        vm,
      );
    }

    _latestModel = vm;

    if ((widget.onDidChange != null) && (_latestModel != null)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onDidChange!(
          mounted ? context : null,
          widget.store,
          _latestModel!,
        );
      });
    }

    sink.add(vm);
  }

  // If the view-model construction failed.
  void _handleError(
    Object error,
    StackTrace stackTrace,
    EventSink<Model> sink,
  ) {
    _latestModel = null;
    _latestError = _ConverterError(error, stackTrace, widget.debug);
    sink.addError(error, stackTrace);
  }

  // If there is a ModelObserver, observe.
  // Note: This observer is only useful for tests.
  void _observeWithTheModelObserver<Model>({
    required Model? modelPrevious,
    required Model? modelCurrent,
    required bool isDistinct,
  }) {
    try {
      widget.store.modelObserver?.observe(
        modelPrevious: modelPrevious,
        modelCurrent: modelCurrent,
        isDistinct: isDistinct,
        storeConnector: widget.storeConnector,
        reduceCount: widget.store.reduceCount,
        dispatchCount: widget.store.dispatchCount,
      );
    } catch (error, stackTrace) {
      // The errorObserver should never throw. However, if it does, print the error.
      _throws("Method 'ModelObserver.observe()' has thrown an error", error,
          stackTrace);
    }
  }

  /// Throws the error after an asynchronous gap.
  void _throws(errorMsg, Object? error, StackTrace stackTrace) {
    Future(() {
      Error.throwWithStackTrace(
        (error == null) ? errorMsg : "$errorMsg:\n  $error",
        stackTrace,
      );
    });
  }

  /// The StoreConnector needs the converter or vm parameter (only one of them):
  /// 1) Converter gets the `store`.
  /// 2) Vm gets `state` and `dispatch`, so it's easier to use.
  ///
  Model getLatestModel(St state) {
    //
    // The `vm` parameter is recommended.
    if (widget.vm != null) {
      var factory = widget.vm!();
      internalsVmFactoryInject(factory, state, widget.store);
      return internalsVmFactoryFromStore(factory) as Model;
    }
    //
    // The `converter` parameter can be used instead of `vm`.
    else if (widget.converter != null) {
      return widget.converter!(widget.store);
    }
    //
    else
      throw AssertionError("View-model can't be created. "
          "Please provide vm or converter parameter.");
  }

  @override
  Widget build(BuildContext context) {
    return widget.rebuildOnChange
        ? StreamBuilder<Model>(
            stream: _stream,
            builder: (context, snapshot) => (_latestError != null)
                ? throw _latestError!
                : widget.builder(context, _latestModel as Model),
          )
        : _latestError != null
            ? throw _latestError!
            : widget.builder(context, _latestModel as Model);
  }
}

/// Provides a Redux [Store] to all ancestors of this Widget.
/// This should generally be a root widget in your App.
///
/// Then, you have two alternatives to access the store:
///
/// 1) Connect to the provided store by using a [StoreConnector], and
/// the [StoreConnector.vm] parameter:
///
/// ```dart
/// StoreConnector(
///    vm: () => Factory(this),
///    builder: (context, vm) => MyHomePage(user: vm.user)
/// );
/// ```
///
/// See the documentation for more information on how to create the view-model using the `vm`
/// parameter and a `VmFactory` class.
///
/// 2) Connect to the provided store by using a [StoreConnector], and
/// the [StoreConnector.converter] parameter:
///
/// ```dart
/// StoreConnector(
///    converter: (Store<AppState> store) => store.state.counter,
///    builder: (context, value) => Text('$value', style: const TextStyle(fontSize: 30)),
/// );
/// ```
/// See the documentation for more information on how to use the `converter` parameter.
///
/// 3) Use the extension methods on [BuildContext], like explained below:
///
/// You can read the state of the store using the `context.state` method:
///
/// ```dart
/// var state = context.state;
/// ```
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
///   AppState get state => getState<AppState>();
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
  /// For convenience, it's recommended that you define this extension in your
  /// own code:
  /// ```dart
  /// extension BuildContextExtension on BuildContext {
  ///   AppState get state => getState<AppState>();
  /// }
  /// ```
  ///
  /// And then use it like this:
  ///
  /// ```dart
  /// var state = context.state;
  /// ```
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
      // case if the state is only accessed via StoreConnector.
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
    // the case if the state is only accessed via StoreConnector.
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
  /// without needing a `StoreConnector`. Example:
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
  /// without needing a `StoreConnector`. Example:
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
  /// without needing a `StoreConnector`. Example:
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
  /// without needing a `StoreConnector`. Example:
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
  /// without needing a `StoreConnector`. Example:
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

  /// You can use [isWaiting] and pass it [actionOrActionTypeOrList] to check if:
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
  static bool isWaiting(
    BuildContext context,
    Object actionOrTypeOrList, {
    bool notify = true,
  }) =>
      (notify
              ? _getStoreWithDependency_Untyped
              : _getStoreNoDependency_Untyped)(context)
          .isWaiting(actionOrTypeOrList);

  /// Returns true if an [actionOrTypeOrList] failed with an [UserException].
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
  static bool isFailed(
    BuildContext context,
    Object actionOrTypeOrList, {
    bool notify = true,
  }) =>
      (notify
              ? _getStoreWithDependency_Untyped
              : _getStoreNoDependency_Untyped)(context)
          .isFailed(actionOrTypeOrList);

  /// Returns the [UserException] of the [actionTypeOrList] that failed.
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
  static UserException? exceptionFor(
    BuildContext context,
    Object actionOrTypeOrList, {
    bool notify = true,
  }) =>
      (notify
              ? _getStoreWithDependency_Untyped
              : _getStoreNoDependency_Untyped)(context)
          .exceptionFor(actionOrTypeOrList);

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
  static void clearExceptionFor(
    BuildContext context,
    Object actionOrTypeOrList, {
    bool notify = true,
  }) =>
      (notify
              ? _getStoreWithDependency_Untyped
              : _getStoreNoDependency_Untyped)(context)
          .clearExceptionFor(actionOrTypeOrList);

  /// Avoid using if you don't have a good reason to do so.
  ///
  /// The [backdoorInheritedWidget] gives you direct access to the store for advanced
  /// use-cases. It does NOT create a dependency like [_getStoreWithDependency_Untyped] does,
  /// and it does NOT rebuild the state when the state changes, when you access it like this:
  /// `var state = StoreProvider.backdoorInheritedWidget(context, this).state;`.
  ///
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

  /// Avoid using this if you don't have a good reason to do so.
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
  @override
  void initState() {
    super.initState();
    widget.store.onChange.listen((state) {
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
    required Store store,
    required Widget child,
  })  : _store = store,
        super(key: key, child: child);

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
      // No aspect = listen to everything (context.state behavior).
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
  * Providing full type information to your Store<St>, StoreProvider<St> and StoreConnector<St, Model>
  * Ensure you are using consistent and complete imports. E.g. always use `import 'package:my_app/app_state.dart';
      ''');
}

StoreException _exceptionForWrongStateType(Object? state, Type wrongType) {
  return StoreException(
      'Error: State is of type ${state.runtimeType} but you typed it as $wrongType.');
}

extension BuildContextExtensionForProviderAndConnector<St> on BuildContext {
  //
  /// Provides easy access to the AsyncRedux store state from a BuildContext.
  ///
  /// Use this in your widget's build method to watch the current store state.
  /// Any widget that calls this will rebuild automatically when the state
  /// changes in any way (even if the part of the state we are actually using
  /// did not change).
  ///
  /// You cannot use [getState] in your `initState` method. If you do, it will
  /// throw an exception. See [getRead] for an alternative that can be used in
  /// `initState`.
  ///
  /// For convenience, it's recommended that you define this extension in your
  /// own code:
  ///
  /// ```dart
  /// extension BuildContextExtension on BuildContext {
  ///   AppState get state => getState<AppState>();
  ///   AppState read() => getRead<AppState>();
  ///   R select<R>(R Function(AppState state) selector) => getSelect<AppState, R>(selector);
  ///   R? event<R>(Evt<R> Function(AppState state) selector) => getEvent<AppState, R>(selector);
  /// }
  /// ```
  ///
  /// Then use it like this:
  ///
  /// ```dart
  /// var state = context.state;
  /// ```
  ///
  /// See also:
  ///
  /// - [getRead] if you don't want the widget to rebuild automatically when
  ///   the state changes (use it with `context.read()`). This is useful when
  ///   you want to read the state once, for example inside an event handler,
  ///   or in your `initState` method.
  ///
  /// - [getSelect] to select a specific part of the state and only rebuild
  ///   when that part changes (use it with `context.select()`).
  ///
  St getState<St>() => _isMock //
      ? (_store.state as St) //
      : StoreProvider.state<St>(this);

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
  ///   AppState get state => getState<AppState>();
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
  /// - [getState] if you want the widget to rebuild automatically on any state
  ///   change (use it with `context.state`).
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
  ///   AppState get state => getState<AppState>();
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
  /// - [getState] to access the state and rebuild on any state change.
  /// - [getRead] to read the state without triggering rebuilds.
  /// - [getSelect] to select specific parts of the state and rebuild only when those parts change.
  /// - [Event] class documentation for more details on event behavior and lifecycle.
  ///
  R? getEvent<St, R>(Evt<R> Function(St state) selector, {bool debug = true}) {
    _assertEvent(debug);

    var evt = getSelect<St, Evt<R>>(selector, debug: debug);
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
  ///   AppState get state => getState<AppState>();
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
  /// - [getState] if you want the widget to rebuild automatically on any state
  ///   change (use it with `context.state`).
  ///
  /// - [getRead] if you don't want the widget to rebuild automatically when
  ///   the state changes (use it with `context.read()`).
  ///
  /// The [debug] parameter, when true (the default), will throw an error if you
  /// try to use `context.select` outside the widget's `build` method. Set it to
  /// false to also allow usage in `didChangeDependencies`. Use this with care:
  /// once the debug check is off, invalid usage in methods like `initState` will
  /// no longer be detected.
  ///
  R getSelect<St, R>(R Function(St state) selector, {bool debug = true}) {
    if (_isMock) return selector(_store.state as St);
    _assertSelect(debug);

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

  void _assertSelect(bool debug) {
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

      // Check we're in a build method.
      if (debug &&
          !debugDoingBuild &&
          widget is! LayoutBuilder &&
          widget is! SliverLayoutBuilder) {
        throw FlutterError(
            'Tried to use `context.select` (or `context.getSelect`) '
            'outside the widget `build` method.'
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

  void _assertEvent(bool debug) {
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

      // Check we're in a build method.
      if (debug &&
          !debugDoingBuild &&
          widget is! LayoutBuilder &&
          widget is! SliverLayoutBuilder) {
        throw FlutterError(
            'Tried to use `context.event` (or `context.getEvent`) '
            'outside the widget `build` method.'
            '\n\n'
            'Note: If you also want to allow the usage in '
            '`didChangeDependencies`, set `debug` to false in `context.getEvent`. '
            'Use with care, as invalid usage in methods like `initState` will '
            'no longer be detected once the debug check is off.\n');
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
  /// store.dispatch(MyAction());
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
  /// await store.dispatchAndWaitAll([BuyAction('IBM'), SellAction('TSLA')]);
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
  /// var status = store.dispatchSync(MyAction());
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

  /// You can use [isWaiting] and pass it [actionOrActionTypeOrList] to check if:
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
  bool isWaiting(Object actionOrTypeOrList) => _isMock
      ? _store.isWaiting(actionOrTypeOrList)
      : StoreProvider.isWaiting(this, actionOrTypeOrList);

  /// Returns true if an [actionOrTypeOrList] failed with an [UserException].
  ///
  /// Example:
  ///
  /// ```dart
  /// if (context.isFailed(MyAction)) { // Show an error message. }
  /// ```
  bool isFailed(Object actionOrTypeOrList) => _isMock
      ? _store.isFailed(actionOrTypeOrList)
      : StoreProvider.isFailed(this, actionOrTypeOrList);

  /// Returns the [UserException] of the [actionTypeOrList] that failed.
  ///
  /// The [actionTypeOrList] can be a [Type], or an Iterable of types. Any other type
  /// of object will return null and throw a [StoreException] after the async gap.
  ///
  /// Example:
  ///
  /// ```dart
  /// if (context.isFailed(SaveUserAction)) Text(context.exceptionFor(SaveUserAction)!.reason ?? '');
  /// ```
  UserException? exceptionFor(Object actionOrTypeOrList) => _isMock
      ? _store.exceptionFor(actionOrTypeOrList)
      : StoreProvider.exceptionFor(this, actionOrTypeOrList);

  /// Removes the given [actionTypeOrList] from the list of action types that failed.
  ///
  /// Note that dispatching an action already removes that action type from the
  /// exceptions list. This removal happens as soon as the action is dispatched,
  /// not when it finishes.
  ///
  /// [actionTypeOrList] can be a [Type], or an Iterable of types. Any other type
  /// of object will return null and throw a [StoreException] after the async gap.
  ///
  void clearExceptionFor(Object actionOrTypeOrList) => _isMock
      ? _store.clearExceptionFor(actionOrTypeOrList)
      : StoreProvider.clearExceptionFor(this, actionOrTypeOrList);

  /// Given the BuildContext, provides easy access to the optional AsyncRedux
  /// store "environment" that you may have defined.
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
  /// var state = context.env;
  /// ```
  Object? getEnvironment<St>() {
    if (_isMock) return _store.env;

    Store<St> store = StoreProvider.backdoorInheritedWidget<St>(this);
    return store.env;
  }

  /// Allows [MockBuildContext] to be used for testing.
  bool get _isMock => this is MockBuildContext;

  /// Only use this after checking [_isMock].
  Store get _store => (this as MockBuildContext).store;
}
