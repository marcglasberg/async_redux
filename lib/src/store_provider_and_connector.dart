// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// Based upon packages redux by Brian Egan, and flutter_redux by Brian Egan and John Ryan.
// Uses code from package equatable by Felix Angelov.
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

import 'dart:async';
import 'dart:collection';

import 'package:async_redux/async_redux.dart';
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
  final StoreConnector storeConnector;
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
  static Store _getStoreWithDependency_Untyped(BuildContext context,
      {Object? debug}) {
    //
    final _InheritedUntypedRebuilds? provider =
        context.dependOnInheritedWidgetOfExactType<_InheritedUntypedRebuilds>();

    if (provider == null)
      throw _exceptionForWrongStoreType(_typeOf<_InheritedUntypedRebuilds>(),
          debug: debug);

    // We only turn on rebuilds when this `state` method is used for the first time.
    // This is to make it faster when this method is not used, which is the
    // case if the state is only accessed via StoreConnector.
    _InheritedUntypedRebuilds._isOn = true;

    return provider._store;
  }

  /// This WILL NOT create a dependency, and may NOT rebuild the state.
  /// You don't need `St` to call this method.
  static Store _getStoreNoDependency_Untyped(BuildContext context,
      {Object? debug}) {
    final _InheritedUntypedDoesNotRebuild? provider = context
        .dependOnInheritedWidgetOfExactType<_InheritedUntypedDoesNotRebuild>();

    if (provider == null)
      throw _exceptionForWrongStoreType(
          _typeOf<_InheritedUntypedDoesNotRebuild>(),
          debug: debug);

    return provider._store;
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
  static void dispatchAll<St>(
    BuildContext context,
    List<ReduxAction<St>> actions, {
    Object? debug,
    bool notify = true,
  }) =>
      _getStoreNoDependency_Untyped(context, debug: debug)
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
  static Future<void> dispatchAndWaitAll<St>(
    BuildContext context,
    List<ReduxAction<St>> actions, {
    Object? debug,
    bool notify = true,
  }) =>
      _getStoreNoDependency_Untyped(context, debug: debug)
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
    final StoreProvider<St>? provider =
        context.dependOnInheritedWidgetOfExactType<StoreProvider<St>>();

    if (provider == null)
      throw _exceptionForWrongStoreType(_typeOf<StoreProvider<St>>(),
          debug: debug);

    return provider._store;
  }

  /// Avoid using if you don't have a good reason to do so.
  ///
  /// The [backdoorStaticGlobal] gives you direct access to the store for advanced use-cases.
  /// It does NOT need the context, as it gets the store from the static
  /// field [_staticStoreBackdoor]. Note this field is set when the [StoreProvider] is created,
  /// which assumes the [StoreProvider] is used only once in your app. This is usually a
  /// reasonable assumption, but can break in tests. It does NOT create a dependency
  /// like [_getStoreWithDependency_Untyped] does, and it does NOT rebuild the state when the state changes,
  /// when you access it like this: `var state = StoreProvider.backdoorStaticGlobal<AppState>().state;`.
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

/// An UNTYPED inherited widget used by `dispatch`, `dispatchAndWait` and `dispatchSync`.
/// That's useful because they can dispatch without the knowing the St type, but it DOES NOT
/// REBUILD.
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
  // TODO: DONT REMOVE
  // Object? _recentState;

  @override
  void initState() {
    super.initState();
    widget.store.onChange.where(_stateChanged).listen((state) {
      if (mounted) {
        // TODO: DONT REMOVE
        // _recentState = state;
        setState(() {});
      }
    });
  }

  // Make sure we're not rebuilding if the state didn't change.
  // Note: This is not necessary because the store only sends the new state if it changed:
  // `if (((state != null) && !identical(_state, state)) ...`
  // I'm leaving it here because in the future I want to improve this by only rebuilding
  // when the part of the state that the widgets depend on changes.
  // To implement that in the future I have to create some special InheritedWidget that
  // only notifies dependents when the part of the state they depend on changes.
  // For the moment, if you use the [StoreProvider.state] method, it will rebuild the widget
  // whenever the state changes, even if the part of the state that the widget depends on
  // didn't change. Currently, the only way to avoid this is to use the [StoreConnector].
  // TODO: DONT REMOVE:  bool _stateChanged(state) => !identical(_recentState, widget.store.state);
  bool _stateChanged(state) => true;

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
  bool updateShouldNotify(_InheritedUntypedRebuilds oldWidget) {
    return _isOn;
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
  /// Use this in your widget's build method to read the current store state.
  /// Any widget that calls this will rebuild automatically when the state changes.
  ///
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
  St getState<St>() => StoreProvider.state<St>(this);

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
  FutureOr<ActionStatus> dispatch(ReduxAction action, {bool notify = true}) =>
      StoreProvider.dispatch(this, action, notify: notify);

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
  Future<ActionStatus> dispatchAndWait(ReduxAction action,
          {bool notify = true}) =>
      StoreProvider.dispatchAndWait(this, action, notify: notify);

  /// Dispatches all given [actions] in parallel, applying their reducer, and possibly changing
  /// the store state.
  ///
  /// ```dart
  /// dispatchAll([BuyAction('IBM'), SellAction('TSLA')]);
  /// ```
  ///
  /// If you pass the [notify] parameter as `false`, widgets will not necessarily rebuild because
  /// of these actions, even if it changes the state.
  ///
  /// See also:
  /// - [dispatch] which dispatches both sync and async actions.
  /// - [dispatchAndWait] which dispatches both sync and async actions, and returns a Future.
  /// - [dispatchAndWaitAll] which dispatches all given actions, and returns a Future.
  /// - [dispatchSync] which dispatches sync actions, and throws if the action is async.
  ///
  void dispatchAll(List<ReduxAction<St>> actions, {bool notify = true}) =>
      StoreProvider.dispatchAll(this, actions, notify: notify);

  /// Dispatches all given [actions] in parallel, applying their reducers, and possibly changing
  /// the store state. The actions may be sync or async. It returns a [Future] that resolves when
  /// ALL actions finish.
  ///
  /// ```dart
  /// await store.dispatchAndWaitAll([BuyAction('IBM'), SellAction('TSLA')]);
  /// ```
  ///
  /// If you pass the [notify] parameter as `false`, widgets will not necessarily rebuild because
  /// of these actions, even if they change the state.
  ///
  /// Note: While the state change from the action's reducers will have been applied when the
  /// Future resolves, other independent processes that the action may have started may still
  /// be in progress.
  ///
  /// See also:
  /// - [dispatch] which dispatches both sync and async actions.
  /// - [dispatchAndWait] which dispatches both sync and async actions, and returns a Future.
  /// - [dispatchSync] which dispatches sync actions, and throws if the action is async.
  /// - [dispatchAll] which dispatches all given actions in parallel.
  ///
  Future<void> dispatchAndWaitAll(
    List<ReduxAction<St>> actions, {
    bool notify = true,
  }) =>
      StoreProvider.dispatchAndWaitAll(this, actions, notify: notify);

  /// Dispatches the action, applying its reducer, and possibly changing the store state.
  /// However, if the action is ASYNC, it will throw a [StoreException].
  ///
  /// If you pass the [notify] parameter as `false`, widgets will not necessarily rebuild because
  /// of this action, even if it changes the state.
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
  ActionStatus dispatchSync(ReduxAction action, {bool notify = true}) =>
      StoreProvider.dispatchSync(this, action, notify: notify);

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
  bool isWaiting(Object actionOrTypeOrList) =>
      StoreProvider.isWaiting(this, actionOrTypeOrList);

  /// Returns true if an [actionOrTypeOrList] failed with an [UserException].
  ///
  /// Example:
  ///
  /// ```dart
  /// if (context.isFailed(MyAction)) { // Show an error message. }
  /// ```
  bool isFailed(Object actionOrTypeOrList) =>
      StoreProvider.isFailed(this, actionOrTypeOrList);

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
  UserException? exceptionFor(Object actionOrTypeOrList) =>
      StoreProvider.exceptionFor(this, actionOrTypeOrList);

  /// Removes the given [actionTypeOrList] from the list of action types that failed.
  ///
  /// Note that dispatching an action already removes that action type from the exceptions list.
  /// This removal happens as soon as the action is dispatched, not when it finishes.
  ///
  /// [actionTypeOrList] can be a [Type], or an Iterable of types. Any other type
  /// of object will return null and throw a [StoreException] after the async gap.
  ///
  void clearExceptionFor(Object actionOrTypeOrList) =>
      StoreProvider.clearExceptionFor(this, actionOrTypeOrList);
}
