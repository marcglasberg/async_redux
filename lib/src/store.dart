import 'dart:async';
import 'dart:collection';

import 'package:async_redux/async_redux.dart';
import 'package:async_redux/src/process_persistence.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

// Developed by Marcelo Glasberg (Aug 2019).
// Based upon packages redux by Brian Egan, and flutter_redux by Brian Egan and John Ryan.
// Uses code from package equatable by Felix Angelov.
// For more info, see: https://pub.dartlang.org/packages/async_redux

// /////////////////////////////////////////////////////////////////////////////

typedef Dispatch<St> = void Function(ReduxAction<St> action);

typedef DispatchFuture<St> = Future<void> Function(ReduxAction<St> action);

typedef TestInfoPrinter = void Function(TestInfo);

class TestInfo<St> {
  final St state;
  final bool ini;
  final ReduxAction<St> action;
  final int dispatchCount;
  final int reduceCount;

  /// List of all UserException's waiting to be displayed in the error dialog.
  Queue<UserException> errors;

  /// The error thrown by the action, if any,
  /// before being processed by the action's wrapError() method.
  final Object error;

  /// The error thrown by the action,
  /// after being processed by the action's wrapError() method.
  final Object processedError;

  bool get isINI => ini;

  bool get isEND => !ini;

  Type get type => action.runtimeType;

  TestInfo(
    this.state,
    this.ini,
    this.action,
    this.error,
    this.processedError,
    this.dispatchCount,
    this.reduceCount,
    this.errors,
  )   : assert(state != null),
        assert(action != null),
        assert(ini != null);

  @override
  String toString() => 'D:$dispatchCount R:$reduceCount = $action ${ini ? "INI" : "END"}\n';
}

// /////////////////////////////////////////////////////////////////////////////

/// During development, use this error observer if you want all errors to be
/// shown to the user in a dialog, not only UserExceptions. In more detail:
/// This will wrap all errors into UserExceptions, and put them all into the
/// error queue. Note that errors which are NOT originally UserExceptions will
/// still be thrown, while UserExceptions will still be swallowed.
///
/// Passe it to the store like this:
///
/// `var store = Store(errorObserver:DevelopmentErrorObserver());`
///
class DevelopmentErrorObserver<St> implements ErrorObserver<St> {
  bool observe(Object error, ReduxAction<St> action, Store store) {
    if (error is UserException)
      return false;
    else {
      UserException errorAsUserException = UserException(error.toString(), cause: error);
      store._addError(errorAsUserException);
      store._changeController.add(store.state);
      return true;
    }
  }
}

/// Swallows all errors (not recommended). Passe it to the store like this:
///
/// `var store = Store(errorObserver:SwallowErrorObserver());`
///
class SwallowErrorObserver<St> implements ErrorObserver<St> {
  bool observe(Object error, ReduxAction<St> action, Store store) {
    return false;
  }
}

/// This model observer prints the StoreConnector's ViewModel to the console.
///
/// Passe it to the store like this:
///
/// `var store = Store(modelObserver:DefaultModelObserver());`
///
/// If you need to print the type of the `StoreConnector` to the console,
/// make sure to pass `debug:this` as a `StoreConnector` constructor parameter.
/// Then, optionally, you can also specify a list of `StoreConnector`s to be
/// observed:
///
/// `DefaultModelObserver([MyStoreConnector, SomeOtherStoreConnector]);`
///
/// You can also override your `ViewModels.toString()` to print out
/// any extra info you need.
///
class DefaultModelObserver<Model> implements ModelObserver<Model> {
  Model _previous;
  Model _current;

  Model get previous => _previous;

  Model get current => _current;

  final List<Type> _storeConnectorTypes;

  DefaultModelObserver([this._storeConnectorTypes = const <Type>[]]);

  @override
  void observe({
    Model modelPrevious,
    Model modelCurrent,
    bool isDistinct,
    StoreConnector storeConnector,
    int reduceCount,
    int dispatchCount,
  }) {
    _previous = modelPrevious;
    _current = modelCurrent;

    var shouldObserve = (_storeConnectorTypes == null || _storeConnectorTypes.isEmpty) ||
        _storeConnectorTypes.contains(storeConnector.debug?.runtimeType);

    if (shouldObserve)
      print("Model D:$dispatchCount R:$reduceCount = "
          "Rebuid:${isDistinct == null || isDistinct}, "
          "${storeConnector.debug == null ? "" : "Connector:${storeConnector.debug.runtimeType}"}, "
          "Model:$modelCurrent.");
  }
}

// /////////////////////////////////////////////////////////////////////////////

/// Creates a Redux store that holds the app state.
///
/// The only way to change the state in the store is to dispatch a ReduxAction.
/// You may implement these methods:
///
/// 1) `AppState reduce()` ➜
///    To run synchronously, just return the state:
///         AppState reduce() { ... return state; }
///    To run asynchronously, return a future of the state:
///         Future<AppState> reduce() async { ... return state; }
///    Note that changing the state is optional. If you return null (or Future of null)
///    the state will not be changed. Just the same, if you return the same instance
///    of state (or its Future) the state will not be changed.
///
/// 2) `FutureOr<void> before()` ➜ Runs before the reduce method.
///    If it throws an error, then `reduce` will NOT run.
///    To run `before` synchronously, just return void:
///         void before() { ... }
///    To run asynchronously, return a future of void:
///         Future<void> before() async { ... }
///    Note: If this method runs asynchronously, then `reduce` will also be async,
///    since it must wait for this one to finish.
///
/// 3) `void after()` ➜ Runs after `reduce`, even if an error was thrown by
/// `before` or `reduce` (akin to a "finally" block). If the `after` method itself
/// throws an error, this error will be "swallowed" and ignored. Avoid `after`
/// methods which can throw errors.
///
/// 5) `Object wrapError(error)` ➜ If any error is thrown by `before` or `reduce`,
/// you have the chance to further process it by using `wrapError`. Usually this
/// is used to wrap the error inside of another that better describes the failed action.
/// For example, if some action converts a String into a number, then instead of
/// throwing a FormatException you could do:
/// `wrapError(error) => UserException("Please enter a valid number.", error: error)`
///
/// ---
///
/// • ActionObserver observes the dispatching of actions,
///   and may be used to print or log the dispatching of actions.
///
/// • StateObservers receive the action, stateIni (state right before the action),
///   stateEnd (state right after the action), and are used to log and save state.
///
/// • ErrorObservers may be used to observe or process errors thrown by actions.
///
/// For more info, see: https://pub.dartlang.org/packages/async_redux
///
class Store<St> {
  Store({
    St initialState,
    bool syncStream = false,
    TestInfoPrinter testInfoPrinter,
    bool ifRecordsTestInfo,
    List<ActionObserver> actionObservers,
    List<StateObserver> stateObservers,
    Persistor persistor,
    ModelObserver modelObserver,
    ErrorObserver errorObserver,
    WrapError wrapError,
    bool defaultDistinct = true,
  })  : _state = initialState,
        _changeController = StreamController.broadcast(sync: syncStream),
        _actionObservers = actionObservers,
        _stateObservers = stateObservers,
        _processPersistence = persistor == null ? null : ProcessPersistence(persistor),
        _modelObserver = modelObserver,
        _errorObserver = errorObserver,
        _wrapError = wrapError,
        _defaultDistinct = defaultDistinct,
        _errors = Queue<UserException>(),
        _dispatchCount = 0,
        _reduceCount = 0,
        _testInfoPrinter = testInfoPrinter,
        _testInfoController =
            (testInfoPrinter == null) ? null : StreamController.broadcast(sync: syncStream);

  St _state;

  /// The current state of the app.
  St get state => _state;

  int get dispatchCount => _dispatchCount;

  int get reduceCount => _reduceCount;

  final StreamController<St> _changeController;

  final List<ActionObserver> _actionObservers;

  final List<StateObserver> _stateObservers;

  final ProcessPersistence _processPersistence;

  final ModelObserver _modelObserver;

  final ErrorObserver _errorObserver;

  final WrapError _wrapError;

  final bool _defaultDistinct;

  final Queue<UserException> _errors;

  // For testing:
  int _dispatchCount;
  int _reduceCount;
  TestInfoPrinter _testInfoPrinter;
  StreamController<TestInfo<St>> _testInfoController;

  TestInfoPrinter get testInfoPrinter => _testInfoPrinter;

  /// Turns on testing capabilities, if not already.
  void initTestInfoController() {
    _testInfoController ??= StreamController.broadcast(sync: false);
  }

  /// Changes the testInfoPrinter.
  void initTestInfoPrinter(TestInfoPrinter testInfoPrinter) {
    _testInfoPrinter = testInfoPrinter;
    initTestInfoController();
  }

  /// A stream that emits the current state when it changes.
  ///
  /// # Example
  ///
  ///     // Create the Store;
  ///     final store = new Store<int>(initialState: 0);
  ///
  ///     // Listen to the Store's onChange stream, and print the latest
  ///     // state to the console whenever the reducer produces a new state.
  ///     // Store StreamSubscription as a variable, so you can stop listening later.
  ///     final subscription = store.onChange.listen(print);
  ///
  ///     // Dispatch some actions, which prints the state.
  ///     store.dispatch(IncrementAction());
  ///
  ///     // When you want to stop printing, cancel the subscription.
  ///     subscription.cancel();
  ///
  Stream<St> get onChange => _changeController.stream;

  /// Used by the storeTester.
  Stream<TestInfo<St>> get onReduce =>
      (_testInfoController != null) ? _testInfoController.stream : Stream<TestInfo<St>>.empty();

  /// Beware: Changes the state directly. Use only for TESTS.
  void defineState(St state) => _state = state;

  /// Adds an error at the end of the error queue.
  void _addError(UserException error) => _errors.addLast(error);

  /// Gets the first error from the error queue, and removes it from the queue.
  UserException getAndRemoveFirstError() {
    return (_errors.isEmpty) ? null : _errors.removeFirst();
  }

  /// Runs the action, applying its reducer, and possibly changing the store state.
  /// Note: store.dispatch is of type Dispatch.
  void dispatch(ReduxAction<St> action) {
    _dispatchCount++;

    if (_actionObservers != null)
      for (ActionObserver observer in _actionObservers) {
        observer.observe(action, dispatchCount, ini: true);
      }

    St stateIni = _state;
    _processAction(action);
    St stateEnd = _state;

    if (_stateObservers != null)
      for (StateObserver observer in _stateObservers) {
        observer.observe(action, stateIni, stateEnd, dispatchCount);
      }

    if (_processPersistence != null) _processPersistence.process(action, stateEnd);
  }

  Future<void> dispatchFuture(ReduxAction<St> action) async {
    _dispatchCount++;

    if (_actionObservers != null)
      for (ActionObserver observer in _actionObservers) {
        observer.observe(action, dispatchCount, ini: true);
      }

    St stateIni = _state;
    await _processAction(action);
    St stateEnd = _state;

    if (_stateObservers != null)
      for (StateObserver observer in _stateObservers) {
        observer.observe(action, stateIni, stateEnd, dispatchCount);
      }

    if (_processPersistence != null) _processPersistence.process(action, stateEnd);

    return null;
  }

  void createTestInfoSnapshot(
    St state,
    ReduxAction<St> action,
    dynamic error,
    dynamic processedError, {
    @required bool ini,
  }) {
    assert(state != null);
    assert(action != null);
    assert(ini != null);

    if (_testInfoController != null || testInfoPrinter != null) {
      var reduceInfo = TestInfo<St>(
          state, ini, action, error, processedError, dispatchCount, reduceCount, _errors);
      if (_testInfoController != null) _testInfoController.add(reduceInfo);
      if (testInfoPrinter != null) testInfoPrinter(reduceInfo);
    }
  }

  /// We check the return type of methods `before` and `reduce` to decide if the
  /// reducer is synchronous or asynchronous. It's important to run the reducer
  /// synchronously, if possible.
  Future<void> _processAction(ReduxAction<St> action) async {
    //
    // Creates the "INI" test snapshot.
    createTestInfoSnapshot(state, action, null, null, ini: true);

    // The action may access the store/state/dispatch as fields.
    action.setStore(this);

    var afterWasRun = _Flag<bool>(false);

    dynamic result;

    dynamic originalError;
    dynamic processedError;

    try {
      result = action.before();
      if (result is Future) await result;
      result = _applyReducer(action);
      if (result is Future) await result;
    } catch (error) {
      originalError = error;
      processedError = _processError(error, action, afterWasRun);
      // Error is meant to be "swallowed".
      if (processedError == null)
        return;
      // Error was not changed. Rethrows.
      else if (identical(processedError, error))
        rethrow;
      // Error was wrapped. Rethrows, but looses stacktrace due to Dart architecture.
      // See: https://groups.google.com/a/dartlang.org/forum/#!topic/misc/O1OKnYTUcoo
      // See: https://github.com/dart-lang/sdk/issues/10297
      // This should be fixed when this issue is solved: https://github.com/dart-lang/sdk/issues/30741
      else
        throw processedError;
    } finally {
      _finalize(result, action, originalError, processedError, afterWasRun);
    }
  }

  FutureOr<void> _applyReducer(ReduxAction<St> action) {
    _reduceCount++;

    var result = action.reduce();

    if (result is Future<St>) {
      return result.then((state) => _registerState(state, action));
    } else if (result is St) {
      St state = result;
      _registerState(state, action);
    } else if (result != null) {
      throw AssertionError();
    }
  }

  /// Adds the state to the changeController, but only if the `reduce` method
  /// did not returned null, and if it did not return the same identical state.
  /// Note: We compare the state using `identical` (which is fast).
  void _registerState(St state, ReduxAction<St> pureAction) {
    if (state != null && !identical(_state, state)) {
      _state = state;
      _changeController.add(state);
    }
  }

  /// Returns the processed error. Returns `null` if the error is meant to be "swallowed".
  dynamic _processError(error, ReduxAction<St> action, _Flag<bool> afterWasRun) {
    error = action.wrapError(error);

    if (_wrapError != null && error is! UserException) {
      error = _wrapError.wrap(error) ?? error;
    }

    afterWasRun.value = true;
    _after(action);

    // Memorizes errors of type UserException (in the error queue).
    // These errors are usually shown to the user in a modal dialog, and are not logged.
    if (error is UserException) {
      _addError(error);
      _changeController.add(state);
    }

    // If an errorObserver was NOT defined, return (to throw) errors which are not UserException.
    if (_errorObserver == null) {
      if (error is! UserException) return error;
    }
    // If an errorObserver was defined, observe the error.
    // Then, if the observer returns true, return the error to be thrown.
    else {
      if (_errorObserver.observe(error, action, this)) return error;
    }

    return null;
  }

  void _finalize(Future result, ReduxAction<St> action, dynamic error, dynamic processedError,
      _Flag<bool> afterWasRun) {
    if (!afterWasRun.value) _after(action);

    createTestInfoSnapshot(state, action, error, processedError, ini: false);

    if (_actionObservers != null)
      for (ActionObserver observer in _actionObservers) {
        observer.observe(action, dispatchCount, ini: false);
      }
  }

  Future<void> _after(ReduxAction<St> action) async {
    try {
      action.after();
    } catch (error) {
      // Swallows error.
    }
  }

  /// Closes down the store so it will no longer be operational.
  /// Only use this if you want to destroy the Store while your app is running.
  /// Do not use this method as a way to stop listening to onChange state changes.
  /// For that purpose, view the onChange documentation.
  Future teardown() async {
    _state = null;
    return _changeController.close();
  }
}

// /////////////////////////////////////////////////////////////////////////////

/// Actions must extend this class.
///
/// Important: Do NOT override operator == and hashCode. Actions must retain
/// their default [Object] comparison by identity, or the StoreTester may not work.
///
abstract class ReduxAction<St> {
  Store<St> _store;

  void setStore(Store store) => _store = (store as Store<St>);

  Store<St> get store => _store;

  St get state => _store.state;

  Dispatch<St> get dispatch => _store.dispatch;

  DispatchFuture<St> get dispatchFuture => _store.dispatchFuture;

  /// This is an optional method that may be overridden to run during action
  /// dispatching, before `reduce`. If this method throws an error, the
  /// `reduce` method will NOT run, but the method `after` will.
  /// It may be synchronous (returning `void`) ou async (returning `Future<void>`).
  FutureOr<void> before() {}

  /// This is an optional method that may be overridden to run during action
  /// dispatching, after `reduce`. If this method throws an error, the
  /// error will be swallowed (will not throw). So you should only run code that
  /// can't throw errors. It may be synchronous only.
  /// Note this method will always be called,
  /// even if errors were thrown by `before` or `reduce`.
  void after() {}

  /// The `reduce` method is the action reducer. It may read the action state,
  /// the store state, and then return a new state (or `null` if no state
  /// change is necessary).
  ///
  /// It may be synchronous (returning `AppState` or `null`)
  /// or async (returning `Future<AppState>` or `Future<null>`).
  ///
  /// The `StoreConnector`s may rebuild only if the `reduce` method returns
  /// a state which is both not `null` and different from the previous one
  /// (comparing by `identical`, not `equals`).
  FutureOr<St> reduce();

  /// If any error is thrown by `reduce` or `before`, you have the chance
  /// to further process it by using `wrapError`. Usually this is used to wrap
  /// the error inside of another that better describes the failed action.
  /// For example, if some action converts a String into a number, then instead of
  /// throwing a FormatException you could do:
  /// `wrapError(error) => UserException("Please enter a valid number.", error: error)`
  Object wrapError(error) => error;

  /// Nest state reducers without dispatching another action.
  /// Example: return AddTaskAction(demoTask).reduceWithState(state);
  FutureOr<St> reduceWithState(St state) {
    _store.defineState(state);
    return reduce();
  }

  @override
  String toString() => 'Action ' + runtimeType.toString();
}

// /////////////////////////////////////////////////////////////////////////////

abstract class ActionObserver<St> {
  /// If `ini==true` this is right before the action is dispatched.
  /// If `ini==false` this is right after the action finishes.
  void observe(ReduxAction<St> action, int dispatchCount, {@required bool ini});
}

abstract class StateObserver<St> {
  void observe(ReduxAction<St> action, St stateIni, St stateEnd, int dispatchCount);
}

/// This will be given all errors, including those of type [UserException].
/// Return true to throw the error. False to swallow it.
///
/// Don't use the store to dispatch any actions, as this may have
/// unpredictable results.
///
abstract class ErrorObserver<St> {
  bool observe(
    Object error,
    ReduxAction<St> action,
    Store<St> store,
  );
}

/// This will be given all errors which are NOT of type UserException.
/// * If it returns a [UserException], it will be used instead of the
///   original exception.
/// * Otherwise, just return null, so that the original exception will
///   not be modified.
///
/// Note this wrapper is called AFTER [ReduxAction.wrapError],
/// and BEFORE the [ErrorObserver].
///
/// The use case for this is to have a global place to convert some exceptions
/// into [UserException]s. For example, Firebase my throw some
/// PlatformExceptions in response to a bad connection to the server.
/// In this case, you may want to show the user a dialog explaining that the
/// connection is bad, which you can do by converting it to a [UserException].
/// Note, this could also be done in the [ReduxAction.wrapError], but then
/// you'd have to add it to all actions that use Firebase.
///
abstract class WrapError<St> {
  UserException wrap(Object error);
}

/// This will be given all errors, including those of type UserException.
/// Return true to throw the error. False to swallow it.
/// Note:
/// * When isDistinct==true, it means the widget rebuilt because the model changed.
/// * When isDistinct==false, it means the widget didn't rebuilt because the model hasn't changed.
/// * When isDistinct==null, it means the widget rebuilds everytime, and the model is not relevant.
abstract class ModelObserver<Model> {
  void observe({
    Model modelPrevious,
    Model modelCurrent,
    bool isDistinct,
    StoreConnector storeConnector,
    int reduceCount,
    int dispatchCount,
  });
}

// /////////////////////////////////////////////////////////////////////////////

/// This should only be used for IMMUTABLE classes.
/// Lets you implement equals/hashcode without having to override these methods.
abstract class BaseModel<St> {
  /// The List of properties which will be used to determine whether two BaseModels are equal.
  final List<Object> equals;

  /// You can pass the connector widget, in case the view-model needs any info from it.
  final Widget widget;

  /// The constructor takes an optional List of fields which will be used
  /// to determine whether two [BaseModel] are equal.
  BaseModel({this.equals = const [], this.widget})
      : assert(_onlyContainFieldsOfAllowedTypes(equals));

  /// Fields should not contain functions.
  static bool _onlyContainFieldsOfAllowedTypes(List equals) {
    equals.forEach((Object field) {
      if (field is Function)
        throw StoreException("ViewModel equals has an invalid field of type ${field.runtimeType}.");
    });

    return true;
  }

  void _setStore(Store store) => _store = store;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BaseModel && runtimeType == other.runtimeType && listEquals(equals, other.equals);

  @override
  int get hashCode => runtimeType.hashCode ^ _propsHashCode;

  int get _propsHashCode {
    int hashCode = 0;
    equals.forEach((Object prop) => hashCode = hashCode ^ prop.hashCode);
    return hashCode;
  }

  Store<St> _store;

  Store<St> get store => _store;

  BaseModel fromStore();

  St get state => _store.state;

  Dispatch<St> get dispatch => _store.dispatch;

  DispatchFuture<St> get dispatchFuture => _store.dispatchFuture;

  @override
  String toString() => '$runtimeType{${equals.join(', ')}}';
}

// /////////////////////////////////////////////////////////////////////////////

/// Provides a Redux [Store] to all ancestors of this Widget.
/// This should generally be a root widget in your App.
/// Connect to the Store provided by this Widget using a [StoreConnector].
class StoreProvider<St> extends InheritedWidget {
  final Store<St> _store;

  const StoreProvider({
    Key key,
    @required Store<St> store,
    @required Widget child,
  })  : assert(store != null),
        assert(child != null),
        _store = store,
        super(key: key, child: child);

  static Store<St> of<St>(BuildContext context, Object debug) {
    final type = _typeOf<StoreProvider<St>>();
    final StoreProvider<St> provider = context.inheritFromWidgetOfExactType(type);

    if (provider == null) throw StoreConnectorError(type, debug);

    return provider._store;
  }

  /// Dispatch an action without a StoreConnector.
  static void dispatch<St>(BuildContext context, ReduxAction<St> action, {Object debug}) {
    of<St>(context, debug).dispatch(action);
  }

  /// Dispatch an action without a StoreConnector,
  /// and get a `Future<void>` which completes when the action is done.
  static Future<void> dispatchFuture<St>(BuildContext context, ReduxAction<St> action,
          {Object debug}) async =>
      of<St>(context, debug).dispatchFuture(action);

  /// Get the state, without a StoreConnector.
  static St state<St>(BuildContext context, {Object debug}) => of<St>(context, debug).state;

  /// Workaround to capture generics.
  static Type _typeOf<T>() => T;

  @override
  bool updateShouldNotify(StoreProvider<St> oldWidget) => _store != oldWidget._store;
}

// /////////////////////////////////////////////////////////////////////////////

/// Build a Widget using the [BuildContext] and [Model].
/// The [Model] is derived from the [Store] using a [StoreConverter].
typedef ViewModelBuilder<Model> = Widget Function(BuildContext context, Model vm);

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

/// A test of whether or not your `converter` function should run in response
/// to a State change. For advanced use only.
/// Some changes to the State of your application will mean your `converter`
/// function can't produce a useful Model. In these cases, such as when
/// performing exit animations on data that has been removed from your Store,
/// it can be best to ignore the State change while your animation completes.
/// To ignore a change, provide a function that returns true or false. If the
/// returned value is false, the change will be ignored.
/// If you ignore a change, and the framework needs to rebuild the Widget, the
/// `builder` function will be called with the latest Model produced
/// by your `converter` or `model` functions.
typedef ShouldUpdateModel<St> = bool Function(St state);

/// A function that will be run on state change, before the build method.
/// This function is passed the `Model`, and if `distinct` is `true`,
/// it will only be called if the `Model` changes.
/// This can be useful for imperative calls to things like Navigator, TabController, etc
typedef OnWillChangeCallback<Model> = void Function(Model viewModel);

/// A function that will be run on State change, after the build method.
///
/// This function is passed the `Model`, and if `distinct` is `true`,
/// it will only be called if the `Model` changes.
/// This can be useful for running certain animations after the build is complete.
/// Note: Using a [BuildContext] inside this callback can cause problems if
/// the callback performs navigation. For navigation purposes, please use
/// an [OnWillChangeCallback].
typedef OnDidChangeCallback<Model> = void Function(Model viewModel);

/// A function that will be run after the Widget is built the first time.
/// This function is passed the initial `Model` created by the [converter] function.
/// This can be useful for starting certain animations, such as showing
/// Snackbars, after the Widget is built the first time.
typedef OnInitialBuildCallback<Model> = void Function(Model viewModel);

// /////////////////////////////////////////////////////////////////////////////

/// Build a widget based on the state of the [Store].
///
/// Before the [builder] is run, the [converter] will convert the store into a
/// more specific `Model` tailored to the Widget being built.
///
/// Every time the store changes, the Widget will be rebuilt. As a performance
/// optimization, the Widget can be rebuilt only when the [Model] changes.
/// In order for this to work correctly, you must implement [==] and [hashCode] for
/// the [Model], and set the [distinct] option to true when creating your StoreConnector.
class StoreConnector<St, Model> extends StatelessWidget {
  //
  /// Build a Widget using the [BuildContext] and [Model]. The [Model]
  /// is created by the [converter] or [model] functions.
  final ViewModelBuilder<Model> builder;

  /// Convert the [Store] into a [Model]. The resulting [Model] will be
  /// passed to the [builder] function.
  final StoreConverter<St, Model> converter;

  final BaseModel model;

  /// As a performance optimization, the Widget can be rebuilt only when the
  /// [Model] changes. In order for this to work correctly, you must
  /// implement [==] and [hashCode] for the [Model], and set the [distinct]
  /// option to true when creating your StoreConnector.
  final bool distinct;

  /// A function that will be run when the StoreConnector is initially created.
  /// It is run in the [State.initState] method.
  /// This can be useful for dispatching actions that fetch data for your Widget
  /// when it is first displayed.
  final OnInitCallback<St> onInit;

  /// A function that will be run when the StoreConnector is removed from the
  /// Widget Tree. It is run in the [State.dispose] method.
  /// This can be useful for dispatching actions that remove stale data from your State tree.
  final OnDisposeCallback<St> onDispose;

  /// Determines whether the Widget should be rebuilt when the Store emits an onChange event.
  final bool rebuildOnChange;

  /// A test of whether or not your [converter] function should run in response
  /// to a State change. For advanced use only.
  /// Some changes to the State of your application will mean your [converter]
  /// function can't produce a useful Model. In these cases, such as when
  /// performing exit animations on data that has been removed from your Store,
  /// it can be best to ignore the State change while your animation completes.
  /// To ignore a change, provide a function that returns true or false. If the
  /// returned value is false, the change will be ignored.
  /// If you ignore a change, and the framework needs to rebuild the Widget, the
  /// [builder] function will be called with the latest [Model] produced
  /// by your [converter] or [model] functions.
  final ShouldUpdateModel<St> shouldUpdateModel;

  /// A function that will be run on State change, before the Widget is built.
  /// This function is passed the `Model`, and if `distinct` is `true`,
  /// it will only be called if the `Model` changes.
  /// This can be useful for imperative calls to things like Navigator, TabController, etc
  final OnWillChangeCallback<Model> onWillChange;

  /// A function that will be run on State change, after the Widget is built.
  /// This function is passed the `Model`, and if `distinct` is `true`,
  /// it will only be called if the `Model` changes.
  /// This can be useful for running certain animations after the build is complete.
  /// Note: Using a [BuildContext] inside this callback can cause problems if
  /// the callback performs navigation. For navigation purposes, please use
  /// [onWillChange].
  final OnDidChangeCallback<Model> onDidChange;

  /// A function that will be run after the Widget is built the first time.
  /// This function is passed the initial `Model` created by the [converter] function.
  /// This can be useful for starting certain animations, such as showing
  /// Snackbars, after the Widget is built the first time.
  final OnInitialBuildCallback<Model> onInitialBuild;

  /// Pass the parameter `debug: this` to get a more detailed error message.
  final Object debug;

  const StoreConnector({
    Key key,
    @required this.builder,
    this.distinct,
    this.converter,
    this.model,
    this.debug,
    this.onInit,
    this.onDispose,
    this.rebuildOnChange = true,
    this.shouldUpdateModel,
    this.onWillChange,
    this.onDidChange,
    this.onInitialBuild,
  })  : assert(builder != null),
        assert(converter != null || model != null),
        assert(converter == null || model == null),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return _StoreStreamListener<St, Model>(
      store: StoreProvider.of<St>(context, debug),
      storeConnector: this,
      builder: builder,
      converter: converter,
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
  ///
  /// `BaseModel viewModel = storeConnector.getLatestValue(store);`
  ///
  /// And if you want to build the widget:
  ///
  /// `var widget = (storeConnector as dynamic).builder(context, viewModel);`
  Model getLatestValue(Store store) {
    if (converter != null)
      return converter(store);
    else if (model != null) {
      model._setStore(store);
      return model.fromStore() as Model;
    } else
      throw AssertionError();
  }
}

// /////////////////////////////////////////////////////////////////////////////

/// Listens to the store and calls builder whenever the store changes.
class _StoreStreamListener<St, Model> extends StatefulWidget {
  final ViewModelBuilder<Model> builder;
  final StoreConverter<St, Model> converter;
  final BaseModel model;
  final Store<St> store;
  final StoreConnector storeConnector;
  final bool rebuildOnChange;
  final bool distinct;
  final OnInitCallback<St> onInit;
  final OnDisposeCallback<St> onDispose;
  final ShouldUpdateModel<St> shouldUpdateModel;
  final OnWillChangeCallback<Model> onWillChange;
  final OnDidChangeCallback<Model> onDidChange;
  final OnInitialBuildCallback<Model> onInitialBuild;

  const _StoreStreamListener({
    Key key,
    @required this.builder,
    @required this.store,
    @required this.converter,
    @required this.model,
    @required this.storeConnector,
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

// /////////////////////////////////////////////////////////////////////////////

class _StoreStreamListenerState<St, Model> extends State<_StoreStreamListener<St, Model>> {
  Stream<Model> stream;
  Model modelPrevious;

  @override
  void initState() {
    _init();

    super.initState();
  }

  @override
  void dispose() {
    if (widget.onDispose != null) {
      widget.onDispose(widget.store);
    }

    super.dispose();
  }

  @override
  void didUpdateWidget(_StoreStreamListener<St, Model> oldWidget) {
    if (widget.store != oldWidget.store) {
      _init();
    }

    super.didUpdateWidget(oldWidget);
  }

  void _init() {
    if (widget.onInit != null) {
      widget.onInit(widget.store);
    }

    modelPrevious = getLatestValue();

    if (widget.onInitialBuild != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onInitialBuild(modelPrevious);
      });
    }

    Stream<St> _stream = widget.store.onChange;

    if (widget.shouldUpdateModel != null) {
      _stream = _stream.where((state) => !widget.shouldUpdateModel(state));
    }

    stream = _stream.map((_) => getLatestValue());

    // If `widget.distinct` was passed, use it.
    // Otherwise, use the store default `store._distinct`.
    bool distinct = (widget.distinct != null) ? widget.distinct : widget.store._defaultDistinct;

    // Don't use `Stream.distinct` since it can't capture the initial vm produced by the `converter`.
    if (distinct == true) {
      stream = stream.where((modelCurrent) {
        bool isDistinct = modelCurrent != modelPrevious;

        _observeWithTheModelObserver(
          modelPrevious: modelPrevious,
          modelCurrent: modelCurrent,
          isDistinct: isDistinct,
        );

        return isDistinct;
      });
    }

    // After each Model is emitted from the Stream, we update the
    // latestValue. Important: This must be done after all other optional
    // transformations, such as shouldUpdateModel.
    stream = stream.transform(StreamTransformer.fromHandlers(handleData: (modelCurrent, sink) {
      //
      if (distinct == false)
        _observeWithTheModelObserver(
          modelPrevious: modelPrevious,
          modelCurrent: modelCurrent,
          isDistinct: null,
        );

      modelPrevious = modelCurrent;

      if (widget.onWillChange != null) {
        widget.onWillChange(modelPrevious);
      }

      if (widget.onDidChange != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onDidChange(modelPrevious);
        });
      }

      sink.add(modelCurrent);
    }));
  }

  // If there is a ModelObserver, observe.
  // Note: This observer is only useful for tests.
  void _observeWithTheModelObserver({
    @required modelPrevious,
    @required modelCurrent,
    @required bool isDistinct,
  }) {
    ModelObserver modelObserver = widget.store._modelObserver;
    if (modelObserver != null) {
      try {
        modelObserver.observe(
          modelPrevious: modelPrevious,
          modelCurrent: modelCurrent,
          isDistinct: isDistinct,
          storeConnector: widget.storeConnector,
          reduceCount: widget.store.reduceCount,
          dispatchCount: widget.store.dispatchCount,
        );
      } catch (error) {
        // Swallows any errors thrown by the model observer.
        print("Model observer has thrown an error: '$error'.");
      }
    }
  }

  /// The StoreConnector needs the converter or model parameter (only one of them):
  /// 1) Converter gets a store.
  /// 2) Model gets state and dispatch, so it's easier to use.
  Model getLatestValue() {
    if (widget.converter != null)
      return widget.converter(widget.store);
    else if (widget.model != null) {
      widget.model._setStore(widget.store);
      return widget.model.fromStore() as Model;
    } else
      throw AssertionError();
  }

  @override
  Widget build(BuildContext context) {
    return widget.rebuildOnChange
        ? StreamBuilder<Model>(
            stream: stream,
            builder: (context, snapshot) => widget.builder(
              context,
              snapshot.hasData ? snapshot.data : modelPrevious,
            ),
          )
        : widget.builder(context, modelPrevious);
  }
}

// /////////////////////////////////////////////////////////////////////////////

/// A function that formats the message that will be logged:
///
///   final log = Log(formatter: onlyLogActionFormatter);
///   var store = new Store(initialState: 0, actionObservers:[log], stateObservers: [...]);
///
typedef MessageFormatter<St> = String Function(
  St state,
  ReduxAction<St> action,
  bool ini,
  int dispatchCount,
  DateTime timestamp,
);

/// Connects a [Logger] to the Redux Store.
/// Every action that is dispatched will be logged to the Logger, along with the new State
/// that was created as a result of the action reaching your Store's reducer.
///
/// By default, this class does not print anything to your console or to a web
/// service, such as Fabric or Sentry. It simply logs entries to a Logger instance.
/// You can then listen to the [Logger.onRecord] Stream, and print to the
/// console or send these actions to a web service.
///
/// Example: To print actions to the console as they are dispatched:
///
///     var store = Store(
///       initialValue: 0,
///       actionObservers: [Log.printer()]);
///
/// Example: If you only want to log actions to a Logger, use the default constructor.
///
///     // Create your own Logger and pass it to the Observer.
///     final logger = new Logger("Redux Logger");
///     final stateObserver = Log(logger: logger);
///
///     final store = new Store<int>(
///       initialState: 0,
///       stateObserver: [stateObserver]);
///
///     // Note: One quirk about listening to a logger instance is that you're
///     // actually listening to the Singleton instance of *all* loggers.
///     logger.onRecord
///       // Filter down to [LogRecord]s sent to your logger instance
///       .where((record) => record.loggerName == logger.name)
///       // Print them out (or do something more interesting!)
///       .listen((LogRecord) => print(LogRecord));
///
class Log<St> implements ActionObserver<St> {
  //
  final Logger logger;

  /// The log Level at which the actions will be recorded
  final Level level;

  /// A function that formats the String for printing
  final MessageFormatter<St> formatter;

  /// Logs actions to the given Logger, and does not print anything to the console.
  Log({
    Logger logger,
    this.level = Level.INFO,
    this.formatter = singleLineFormatter,
  }) : logger = logger ?? Logger("Log");

  /// Logs actions to the console.
  factory Log.printer({
    Logger logger,
    Level level = Level.INFO,
    MessageFormatter<St> formatter = singleLineFormatter,
  }) {
    final log = Log(logger: logger, level: level, formatter: formatter);
    log.logger.onRecord.where((record) => record.loggerName == log.logger.name).listen(print);
    return log;
  }

  /// A very simple formatter that writes only the action.
  static String verySimpleFormatter(
    dynamic state,
    ReduxAction action,
    bool ini,
    int dispatchCount,
    DateTime timestamp,
  ) =>
      "$action ${ini ? 'INI' : 'END'}";

  /// A simple formatter that puts all data on one line.
  static String singleLineFormatter(
    dynamic state,
    ReduxAction action,
    bool ini,
    int dispatchCount,
    DateTime timestamp,
  ) {
    return "{$action, St: $state, ts: ${new DateTime.now()}}";
  }

  /// A formatter that puts each attribute on it's own line.
  static String multiLineFormatter(
    dynamic state,
    ReduxAction action,
    bool ini,
    int dispatchCount,
    DateTime timestamp,
  ) {
    return "{\n"
        "  $dispatchCount) $action,\n"
        "  St: $state,\n"
        "  Timestamp: ${new DateTime.now()}\n"
        "}";
  }

  @override
  void observe(ReduxAction<St> action, int dispatchCount, {bool ini}) {
    logger.log(level, formatter(null, action, ini, dispatchCount, new DateTime.now()));
  }
}

// /////////////////////////////////////////////////////////////////////////////

class _Flag<T> {
  T value;

  _Flag(this.value);

  @override
  bool operator ==(Object other) => true;

  @override
  int get hashCode => 0;
}

// /////////////////////////////////////////////////////////////////////////////

class StoreConnectorError extends Error {
  final Type type;
  final Object debug;

  StoreConnectorError(this.type, this.debug);

  @override
  String toString() {
    return '''Error: No $type found. (debug info: ${debug.runtimeType.toString()})    
    
    To fix, please try:
          
  * Dart 2 (required) 
  * Wrapping your MaterialApp with the StoreProvider<St>, rather than an individual Route
  * Providing full type information to your Store<St>, StoreProvider<St> and StoreConnector<St, Model>
  * Ensure you are using consistent and complete imports. E.g. always use `import 'package:my_app/app_state.dart';
      ''';
  }
}

// /////////////////////////////////////////////////////////////////////////////

class StoreException implements Exception {
  final String msg;

  StoreException(this.msg);

  @override
  String toString() => msg;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoreException && runtimeType == other.runtimeType && msg == other.msg;

  @override
  int get hashCode => msg.hashCode;
}

// /////////////////////////////////////////////////////////////////////////////
