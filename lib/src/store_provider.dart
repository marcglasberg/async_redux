// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// Based upon packages redux by Brian Egan, and flutter_redux by Brian Egan and John Ryan.
// Uses code from package equatable by Felix Angelov.
// For more info, see: https://pub.dartlang.org/packages/async_redux

import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';

/// Provides a Redux [Store] to all ancestors of this Widget.
/// This should generally be a root widget in your App.
/// Connect to the Store provided by this Widget using a [StoreConnector].
class StoreProvider<St> extends InheritedWidget {
  final Store<St> _store;

  const StoreProvider({
    Key? key,
    required Store<St> store,
    required Widget child,
  })  : _store = store,
        super(key: key, child: child);

  static Store<St> of<St>(BuildContext context, Object? debug) {
    final StoreProvider<St>? provider =
        context.dependOnInheritedWidgetOfExactType<StoreProvider<St>>();

    if (provider == null)
      throw StoreConnectorError(
        _typeOf<StoreProvider<St>>(),
        debug,
      );

    return provider._store;
  }

  /// Dispatch an action without a StoreConnector,
  /// and get a `Future<void>` which completes when the action is done.
  static FutureOr<ActionStatus> dispatch<St>(
    BuildContext context,
    ReduxAction<St> action, {
    Object? debug,
  }) =>
      of<St>(context, debug).dispatch(action);

  /// Get the state, without a StoreConnector.
  static St? state<St>(BuildContext context, {Object? debug}) => //
      of<St>(context, debug).state;

  /// Workaround to capture generics.
  static Type _typeOf<T>() => T;

  @override
  bool updateShouldNotify(StoreProvider<St> oldWidget) => //
      _store != oldWidget._store;
}

class StoreConnectorError extends Error {
  final Type type;
  final Object? debug;

  StoreConnectorError(this.type, this.debug);

  @override
  String toString() {
    return '''Error: No $type found. (debug info: ${debug.runtimeType})    
    
    To fix, please try:
          
  * Dart 2 (required) 
  * Wrapping your MaterialApp with the StoreProvider<St>, rather than an individual Route
  * Providing full type information to your Store<St>, StoreProvider<St> and StoreConnector<St, Model>
  * Ensure you are using consistent and complete imports. E.g. always use `import 'package:my_app/app_state.dart';
      ''';
  }
}

/// To access the state inside of widgets, you can use `StoreProvider.of`. For example:
///
/// ```
/// // Read state
/// var myInfo = StoreProvider.of<AppState>(context, this).state.myInfo;
///
/// // Dispatch action
/// StoreProvider.of<AppState>(context, this).dispatch(MyAction());
/// ```
///
/// However, this extension allows you to write the above code like this:
///
/// ```
/// // Read state
/// var myInfo = context.ofState<AppState>().myInfo;
///
/// // Dispatch action
/// context.dispatch(MyAction());
/// ```
///
/// Optionally, to further improve this, you'll need to define your own typed extension method.
/// Supposing your state class is `AppState`, define your extension like this:
///
/// ```
/// extension BuildContextExtension on BuildContext {
///   AppState get state => StoreProvider.of<AppState>(this, null).state;
/// }
/// ```
///
/// Once you do that, you can use it like this:
///
/// ```
/// // Read state
/// var myInfo = context.state.myInfo;
///
/// // Dispatch action
/// context.dispatch(MyAction());
/// ```
extension BuildContextAsyncReduxExtension<St> on BuildContext {
  //

  /// You can access the store state from inside your widgets, using the context:
  /// ```
  /// context.ofState<AppState>().myInfo;
  /// ```
  ///
  /// Note: Optionally, to further improve this, you'll need to define your own typed extension
  /// method. Supposing your state class is `AppState`, define your extension like this:
  /// ```
  /// extension BuildContextExtension on BuildContext {
  ///    AppState get state => StoreProvider.of<AppState>(this, null).state;
  /// }
  ///  ```
  ///  Once you do that, you can use it like this:
  ///  ```
  ///  context.state.myInfo;
  ///  ```
  St ofState<St>() => StoreProvider.of<St>(this, null).state;

  /// Runs the action, applying its reducer, and possibly changing the store state.
  /// The action may be sync or async. Note: [dispatch] is of type [Dispatch].
  ///
  /// Use it like this:
  /// ```
  /// context.dispatch(MyAction());
  /// ```
  FutureOr<ActionStatus> dispatch(ReduxAction<St> action, {bool notify = true}) =>
      StoreProvider.of<St>(this, null).dispatch(action, notify: notify);

  /// Runs the action, applying its reducer, and possibly changing the store state.
  /// Note: [dispatchAsync] is of type [DispatchAsync]. It returns `Future<ActionStatus>`,
  /// which means you can `await` it.
  ///
  /// Use it like this:
  /// ```
  /// context.dispatchAsync(MyAction());
  /// ```
  Future<ActionStatus> dispatchAsync(ReduxAction<St> action, {bool notify = true}) =>
      StoreProvider.of<St>(this, null).dispatchAsync(action, notify: notify);

  /// Runs the action, applying its reducer, and possibly changing the store state.
  /// Note: [dispatchSync] is of type [DispatchSync].
  /// If the action is async, it will throw a [StoreException].
  ///
  /// Use it like this:
  /// ```
  /// context.dispatchSync(MySyncAction());
  /// ```
  ActionStatus dispatchSync(ReduxAction<St> action, {bool notify = true}) =>
      StoreProvider.of<St>(this, null).dispatchSync(action, notify: notify);
}
