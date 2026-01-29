// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// Based upon packages redux by Brian Egan, and flutter_redux by Brian Egan and John Ryan.
// Uses code from package equatable by Felix Angelov.
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

import 'dart:async';

import 'package:async_redux/async_redux.dart';

/// Use it like this:
///
/// ```dart
/// var persistor = MyPersistor();
///
/// var initialState = await persistor.readState();
///
/// if (initialState == null) {
/// initialState = AppState.initialState();
/// await persistor.saveInitialState(initialState);
/// }
///
/// var store = Store<AppState>(
///   initialState: initialState,
///   persistor: persistor,
/// );
/// ```
///
/// IMPORTANT: When the store is created with a Persistor, the store considers that the
/// provided initial-state was already persisted. You have to make sure this is the case.
///
abstract class Persistor<St> {
  //

  /// Read the saved state from the persistence. Should return null if the state is not yet
  /// persisted. This method should be called only once, when the app starts, before the store
  /// is created. The state it returns may become the store's initial-state. If some error
  /// occurs while loading the info, we have to deal with it by fixing the problem. In the worse
  /// case, if we think the state is corrupted and cannot be fixed, one alternative is deleting
  /// all persisted files and returning null.
  Future<St?> readState();

  /// Delete the saved state from the persistence.
  Future<void> deleteState();

  /// Save the new state to the persistence.
  /// [lastPersistedState] is the last state that was persisted since the app started,
  /// while [newState] is the new state to be persisted.
  ///
  /// Note you have to make sure that [newState] is persisted after this method is called.
  /// For simpler apps where your state is small, you can just ignore [lastPersistedState]
  /// and persist the whole [newState] every time. But for larger apps, you should compare
  /// [lastPersistedState] and [newState], to persist only the difference between them.
  Future<void> persistDifference({
    required St? lastPersistedState,
    required St newState,
  });

  /// Save an initial-state to the persistence.
  Future<void> saveInitialState(St state) =>
      persistDifference(lastPersistedState: null, newState: state);

  /// The default throttle is 2 seconds. Pass null to turn off throttle.
  Duration? get throttle => const Duration(seconds: 2);
}

/// A decorator to print persistor information to the console.
/// Use it like this:
///
/// ```dart
/// var store = Store<AppState>(...,  persistor: PersistorPrinterDecorator(persistor));
/// ```
///
class PersistorPrinterDecorator<St> extends Persistor<St> {
  final Persistor<St> _persistor;

  PersistorPrinterDecorator(this._persistor);

  @override
  Future<St?> readState() async {
    print("Persistor: read state.");
    return _persistor.readState();
  }

  @override
  Future<void> deleteState() async {
    print("Persistor: delete state.");
    return _persistor.deleteState();
  }

  @override
  Future<void> persistDifference({
    required St? lastPersistedState,
    required St newState,
  }) async {
    print("Persistor: persist difference:\n"
        "lastPersistedState = $lastPersistedState\n"
        "newState = newState");
    return _persistor.persistDifference(
        lastPersistedState: lastPersistedState, newState: newState);
  }

  @override
  Future<void> saveInitialState(St state) async {
    print("Persistor: save initial state.");
    return _persistor.saveInitialState(state);
  }

  @override
  Duration? get throttle => _persistor.throttle;
}

/// A dummy persistor.
///
class PersistorDummy<T> extends Persistor<T> {
  @override
  Future<T?> readState() async => null;

  @override
  Future<void> deleteState() async => null;

  @override
  Future<void> persistDifference(
      {required lastPersistedState, required newState}) async {}

  @override
  Future<void> saveInitialState(T state) async {}

  @override
  Duration? get throttle => null;
}

class PersistException implements Exception {
  final Object error;

  PersistException(this.error);

  @override
  String toString() => error.toString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PersistException //
          &&
          runtimeType == other.runtimeType //
          &&
          error == other.error;

  @override
  int get hashCode => error.hashCode;
}

class PersistAction<St> extends ReduxAction<St> {
  @override
  St? reduce() => null;
}
