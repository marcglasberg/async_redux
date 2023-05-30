// Developed by Marcelo Glasberg (Aug 2019).
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
