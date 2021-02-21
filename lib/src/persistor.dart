import 'dart:async';
import 'package:async_redux/async_redux.dart';

// Developed by Marcelo Glasberg (Aug 2019).
// Based upon packages redux by Brian Egan, and flutter_redux by Brian Egan and John Ryan.
// Uses code from package equatable by Felix Angelov.
// For more info, see: https://pub.dartlang.org/packages/async_redux

// /////////////////////////////////////////////////////////////////////////////

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
abstract class Persistor<St> {
  Future<St> readState();

  Future<void> deleteState();

  Future<void> persistDifference({
    required St? lastPersistedState,
    required St newState,
  });

  Future<void> saveInitialState(St state) =>
      persistDifference(lastPersistedState: null, newState: state);

  /// The default throttle is 2 seconds. Pass null to turn off throttle.
  Duration? get throttle => const Duration(seconds: 2);
}

// /////////////////////////////////////////////////////////////////////////////

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
  Future<St> readState() async {
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
    return _persistor.persistDifference(lastPersistedState: lastPersistedState, newState: newState);
  }

  @override
  Future<void> saveInitialState(St state) async {
    print("Persistor: save initial state.");
    return _persistor.saveInitialState(state);
  }

  @override
  Duration? get throttle => _persistor.throttle;
}

// /////////////////////////////////////////////////////////////////////////////

/// A dummy persistor.
///
class PersistorDummy<T> extends Persistor<T?> {
  @override
  Future<T?> readState() async => null;

  @override
  Future<void> deleteState() async => null;

  @override
  Future<void> persistDifference({lastPersistedState, newState}) async => null;

  @override
  Future<void> saveInitialState(state) async => null;

  @override
  Duration? get throttle => null;
}

// /////////////////////////////////////////////////////////////////////////////

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

// /////////////////////////////////////////////////////////////////////////////

class PersistAction<St> extends ReduxAction<St> {
  @override
  St? reduce() => null;
}

// /////////////////////////////////////////////////////////////////////////////
