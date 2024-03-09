// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// Based upon packages redux by Brian Egan, and flutter_redux by Brian Egan and John Ryan.
// Uses code from package equatable by Felix Angelov.
// For more info, see: https://pub.dartlang.org/packages/async_redux

import 'dart:async';

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

  BaseModel? get model;

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

  /// Don't use, this is deprecated. Please, use the recommended
  /// `vm` parameter (of type [VmFactory]) or `converter`.
  @Deprecated("Please, use `vm` parameter. "
      "See classes `VmFactory` and `Vm`.")
  @override
  final BaseModel? model;

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
    this.model, // Deprecated.
    this.debug,
    this.onInit,
    this.onDispose,
    this.rebuildOnChange = true,
    this.shouldUpdateModel,
    this.onWillChange,
    this.onDidChange,
    this.onInitialBuild,
  })  : assert(converter != null || vm != null || model != null,
            "You should provide the `converter` or the `vm` parameter."),
        assert(converter == null || vm == null,
            "You can't provide both the `converter` and the `vm` parameters."),
        assert(converter == null || model == null,
            "You can't provide both the `converter` and the `model` parameters."),
        assert(vm == null || model == null,
            "You can't provide both the `vm` and the `model` parameters."),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return _StoreStreamListener<St, Model>(
      store: StoreProvider._getStore<St>(context, debug: debug),
      debug: debug,
      storeConnector: this,
      builder: builder,
      converter: converter,
      vm: vm,
      // ignore: deprecated_member_use_from_same_package
      model: model,
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
    // The `model` parameter is deprecated.
    // ignore: deprecated_member_use_from_same_package
    else if (model != null) {
      // ignore: deprecated_member_use_from_same_package
      internalsBaseModelInject(model!, store.state, store);
      // ignore: deprecated_member_use_from_same_package
      return model!.fromStore() as Model;
    }
    //
    else
      throw AssertionError("View-model can't be created. "
          "Please provide vm or converter parameter.");
  }
}

/// Listens to the store and calls builder whenever the store changes.
class _StoreStreamListener<St, Model> extends StatefulWidget {
  final ViewModelBuilder<Model> builder;
  final StoreConverter<St, Model>? converter;
  final VmFactory<St, dynamic, dynamic> Function()? vm;
  final BaseModel? model; // Deprecated.
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
    required this.model, // Deprecated.
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
      _latestModel = getLatestModel(_forceLastValidStreamState ?? widget.store.state);
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
    return !identical(_mostRecentValidState, widget.store.state);
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
        return areSameImmutableCollection(vm, _latestModel as ImmutableCollection?);
      if (widget.store.immutableCollectionEquality == CompareBy.byDeepEquals) {
        return areImmutableCollectionsWithEqualItems(vm, _latestModel as ImmutableCollection?);
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
    ModelObserver? modelObserver = widget.store.modelObserver;
    if (modelObserver != null) {
      modelObserver.observe(
        modelPrevious: modelPrevious,
        modelCurrent: modelCurrent,
        isDistinct: isDistinct,
        storeConnector: widget.storeConnector,
        reduceCount: widget.store.reduceCount,
        dispatchCount: widget.store.dispatchCount,
      );
    }
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
    // The `model` parameter is deprecated.
    else if (widget.model != null) {
      internalsBaseModelInject(widget.model!, state, widget.store);
      return widget.model!.fromStore() as Model;
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
///    builder: (context, vm) => return MyHomePage(user: vm.user)
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
/// 3) Use the static methods of [StoreProvider], like explained below:
///
/// You can read the state of the store using the [state] method:
///
/// ```dart
/// var state = StoreProvider.state<AppState>(context);
/// ```
///
/// You can dispatch actions using the [dispatch], [dispatchAndWait] and [dispatchSync] method:
///
/// ```dart
/// StoreProvider.dispatch(context, action);
/// StoreProvider.dispatchAndWait(context, action);
/// StoreProvider.dispatchSync(context, action);
/// ```
///
/// IMPORTANT: It's recommended that you define this extension in your own code:
///
/// ```dart
/// extension BuildContextExtension on BuildContext {
///
///   AppState get state => StoreProvider.state<AppState>(this);
///
///   FutureOr<ActionStatus> dispatch(ReduxAction<AppState> action, {bool notify = true}) =>
///       StoreProvider.dispatch(this, action, notify: notify);
///
///   Future<ActionStatus> dispatchAndWait(ReduxAction<AppState> action, {bool notify = true}) =>
///       StoreProvider.dispatchAndWait(this, action, notify: notify);
///
///   ActionStatus dispatchSync(ReduxAction<AppState> action, {bool notify = true}) =>
///       StoreProvider.dispatchSync(this, action, notify: notify);
/// }
/// ```
///
/// This will allow you to write:
///
/// ```dart
/// var state = context.state;
/// context.dispatch(action);
/// context.dispatchAndWait(action);
/// context.dispatchSync(action);
/// ```

class StoreProvider<St> extends InheritedWidget {
  final Store<St> _store;

  StoreProvider({
    Key? key,
    required Store<St> store,
    required Widget child,
  })  : _store = store,
        super(
          key: key,
          child: _StatefulWrapper(store: store, child: child),
        );

  /// Get the state, without a StoreConnector.
  /// Note: Widgets that use this method will rebuild whenever the state changes.
  static St state<St>(BuildContext context, {Object? debug}) {
    final _InnerStoreProvider<St>? provider =
        context.dependOnInheritedWidgetOfExactType<_InnerStoreProvider<St>>();

    if (provider == null) throw StoreConnectorError(_typeOf<StoreProvider<St>>(), debug);

    // We only turn on rebuilds when this `state` method is used for the first time.
    // This is to make it faster when this method is not used, which is the
    // case if the state is only accessed via StoreConnector.
    _InnerStoreProvider._isOn = true;

    return provider._store.state;
  }

  /// This WILL create a dependency, and WILL potentially rebuild the state.
  static Store<St> _getStoreWithDependency<St>(BuildContext context, {Object? debug}) {
    final _InnerStoreProvider<St>? provider =
        context.dependOnInheritedWidgetOfExactType<_InnerStoreProvider<St>>();

    if (provider == null) throw StoreConnectorError(_typeOf<StoreProvider<St>>(), debug);

    // We only turn on rebuilds when this `state` method is used for the first time.
    // This is to make it faster when this method is not used, which is the
    // case if the state is only accessed via StoreConnector.
    _InnerStoreProvider._isOn = true;

    return provider._store;
  }

  static Store<St> _of<St>(BuildContext context, [Object? debug]) {
    final StoreProvider<St>? provider =
        context.dependOnInheritedWidgetOfExactType<StoreProvider<St>>();

    if (provider == null) throw StoreConnectorError(_typeOf<StoreProvider<St>>(), debug);

    return provider._store;
  }

  /// Workaround to capture generics.
  static Type _typeOf<T>() => T;

  /// Dispatch an action without a StoreConnector.
  /// Note: It's efficient to use this, as Widgets that using this will NOT necessarily rebuild
  /// whenever the state changes.
  static FutureOr<ActionStatus> dispatch<St>(BuildContext context, ReduxAction<St> action,
          {Object? debug, bool notify = true}) =>
      _of<St>(context, debug).dispatch(action, notify: notify);

  /// Dispatch an action without a StoreConnector.
  /// Note: It's efficient to use this, as Widgets that using this will NOT necessarily rebuild
  /// whenever the state changes.
  static Future<ActionStatus> dispatchAndWait<St>(BuildContext context, ReduxAction<St> action,
          {Object? debug, bool notify = true}) =>
      _of<St>(context, debug).dispatchAndWait(action, notify: notify);

  /// Dispatch an action without a StoreConnector.
  /// Note: It's efficient to use this, as Widgets that using this will NOT necessarily rebuild
  /// whenever the state changes.
  static ActionStatus dispatchSync<St>(BuildContext context, ReduxAction<St> action,
          {Object? debug, bool notify = true}) =>
      _of<St>(context, debug).dispatchSync(action, notify: notify);

  /// Get the state, without a StoreConnector.
  /// This will NOT create a dependency, and will NOT rebuild the state.
  static Store<St> _getStore<St>(BuildContext context, {Object? debug}) => //
      _of<St>(context, debug);

  /// If an ASYNC action of the exact given [actionType] is currently being processed, returns true.
  /// Returns false when:
  /// - The ASYNC action of type [actionType] is NOT currently being processed.
  /// - If [actionType] is not really a type that extends [ReduxAction].
  /// - The action of type [actionType] is a SYNC action.
  ///
  /// Example:
  ///
  /// ```dart
  /// if (store.isWaitingForType(MyAction)) { // Show a spinner. }
  /// ```
  static bool isWaitingForType<St>(BuildContext context, Type actionType) =>
      _getStoreWithDependency<St>(context).isWaitingForType(actionType);

  /// If the given ASYNC [action] is currently being processed, returns true.
  /// Returns false when:
  /// - The ASYNC [action] is NOT currently being processed.
  /// - If [action] is a SYNC action (since those finish immediately).
  ///
  /// Example:
  ///
  /// ```dart
  /// var action = MyAction();
  /// dispatch(action);
  /// if (store.isWaitingForAction(action)) { // Show a spinner. }
  /// ```
  static bool isWaitingForAction<St>(BuildContext context, ReduxAction<St> action) =>
      _getStoreWithDependency<St>(context).isWaitingForAction(action);

  // static Store<St> _getStore<St>(BuildContext context, {Object? debug}) => //
  // _of<St>(context, debug);

  @override
  bool updateShouldNotify(StoreProvider<St> oldWidget) {
    // Only notify dependents if the store instance changes,
    // not on every state change within the store.
    return _store != oldWidget._store;
  }
}

class _StatefulWrapper<St> extends StatefulWidget {
  final Widget child;
  final Store<St> store;

  _StatefulWrapper({required this.store, required this.child});

  @override
  _StatefulWrapperState<St> createState() => _StatefulWrapperState<St>();
}

class _StatefulWrapperState<St> extends State<_StatefulWrapper<St>> {
  // TODO: DONT REMOVE
  // St? _recentState;

  @override
  void initState() {
    super.initState();
    widget.store.onChange.where(_stateChanged).listen((St state) {
      if (mounted) {
        // TODO: DONT REMOVE
        // _recentState = state;
        setState(() {});
      }
    });
  }

  // Make sure we're not rebuilding if the state didn't change.
  // Note: This is not necessary because the store only sends the new state if it changed:
  // `if (state != null && !identical(_state, state)) { ... }`
  // I'm leaving it here because in the future I want to improve this by only rebuilding
  // when the part of the state that the widgets depend on changes.
  // To implement that in the future I have to create some special InheritedWidget that
  // only notifies dependents when the part of the state they depend on changes.
  // For the moment, if you use the [StoreProvider.state] method, it will rebuild the widget
  // whenever the state changes, even if the part of the state that the widget depends on
  // didn't change. Currently, the only way to avoid this is to use the [StoreConnector].
  // TODO: DONT REMOVE:  bool _stateChanged(St state) => !identical(_recentState, widget.store.state);
  bool _stateChanged(St state) => true;

  @override
  Widget build(BuildContext context) {
    // The Inner InheritedWidget is rebuilt whenever the store's state changes,
    // triggering rebuilds for widgets that depend on the specific parts of the state.
    return _InnerStoreProvider<St>(
      store: widget.store,
      child: widget.child,
    );
  }
}

class _InnerStoreProvider<St> extends InheritedWidget {
  static var _isOn = false;
  final Store<St> _store;

  _InnerStoreProvider({
    Key? key,
    required Store<St> store,
    required Widget child,
  })  : _store = store,
        super(key: key, child: child);

  @override
  bool updateShouldNotify(_InnerStoreProvider<St> oldWidget) {
    return _isOn;
  }
}

class StoreConnectorError extends Error {
  final Type type;
  final Object? debug;

  StoreConnectorError(this.type, [this.debug]);

  @override
  String toString() {
    return '''Error: No $type found. (debug info: ${debug.runtimeType})

    To fix, please try:
  
  * Wrapping your MaterialApp with the StoreProvider<St>, rather than an individual Route
  * Providing full type information to your Store<St>, StoreProvider<St> and StoreConnector<St, Model>
  * Ensure you are using consistent and complete imports. E.g. always use `import 'package:my_app/app_state.dart';
      ''';
  }
}
