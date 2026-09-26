// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// Based upon packages redux by Brian Egan, and flutter_redux by Brian Egan and John Ryan.
// Uses code from package equatable by Felix Angelov.
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

import 'dart:async';
import 'dart:collection';

import 'package:async_redux/async_redux.dart';
import 'package:meta/meta.dart';

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
  ///
  /// Since this method is usually called before the store is created, it can't show errors
  /// to the user by throwing them. Instead, use [addError] to let the user know something
  /// went wrong. For example:
  ///
  /// ```dart
  /// Future<AppState?> readState() async {
  ///   try {
  ///     return await _read();
  ///   } on FormatException catch (error) {
  ///     await deleteState();
  ///     addError(UserException('Could not read your data, so it was reset.').addCause(error));
  ///     return null;
  ///   }
  /// }
  /// ```
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
  ///
  /// If this method throws an error, it will first be processed by [wrapError], and then
  /// given to the [GlobalErrorObserver] (with a `null` action). If the resulting error is a
  /// [UserException], it will be added to the store's error queue, so that it can be shown
  /// to the user. Also, [newState] will not be considered persisted, so the next call will
  /// receive the same [lastPersistedState].
  Future<void> persistDifference({
    required St? lastPersistedState,
    required St newState,
  });

  /// Save an initial-state to the persistence.
  Future<void> saveInitialState(St state) =>
      persistDifference(lastPersistedState: null, newState: state);

  /// The default throttle is 2 seconds. Pass null to turn off throttle.
  Duration? get throttle => const Duration(seconds: 2);

  /// If any error is thrown by [persistDifference], you have the chance to further
  /// process it by using `wrapError`. Usually this is used to wrap the error inside
  /// of another that better describes the failure. For example, you could turn a
  /// `FileSystemException` into a [UserException], so that it's shown to the user:
  ///
  /// ```dart
  /// wrapError(error, _) => (error is FileSystemException)
  ///     ? UserException("Could not save your data.", cause: error)
  ///     : error;
  /// ```
  ///
  /// If you want to disable the error you can return `null`. For example, if you want
  /// to disable errors of type `MyException`:
  ///
  /// ```dart
  /// wrapError(error, _) => (error is MyException) ? null : error
  /// ```
  ///
  /// If you don't want to modify the error, just return it unaltered
  /// (or don't override this method).
  ///
  /// IMPORTANT: If instead of RETURNING an error you THROW an error inside the `wrapError`
  /// method, AsyncRedux will catch this error and use it instead of the original error.
  /// However, it is still recommended to return the error rather than throwing it.
  ///
  /// See also:
  /// - [GlobalErrorObserver], which is a global way to observe and wrap errors,
  ///   and is called after this method (unless this method returns `null`).
  ///
  Object? wrapError(Object error, StackTrace stackTrace) => error;

  /// Errors added by [addError], waiting to be processed by the store.
  final Queue<(Object, StackTrace)> _errors = Queue();

  /// Adds an error to be processed by the store, even if the store was not yet created.
  /// This is useful in methods like [readState], which are usually called before the store
  /// exists, and can't show errors to the user by throwing them.
  ///
  /// The store processes the errors added here (by calling [getAndRemoveFirstError])
  /// when it's created, and then again after each
  /// persistence operation (reading, deleting, or saving the state). Each error is given to
  /// the [GlobalErrorObserver] (with a `null` action), where it can be logged, changed or
  /// swallowed. Then, if the resulting error is a [UserException], it will be added to the
  /// store's error queue, so that it can be shown to the user (for example, by the
  /// `UserExceptionDialog`). Any other error will be thrown as an unhandled async error.
  ///
  /// Note: Errors added here are NOT processed by [wrapError], since you are adding them
  /// on purpose, already in the form you want.
  ///
  /// Example:
  ///
  /// ```dart
  /// addError(UserException('Could not read your data, so it was reset.'));
  /// ```
  @protected
  void addError(Object error, [StackTrace? stackTrace]) =>
      _errors.add((error, stackTrace ?? StackTrace.current));

  /// Gets the first error added by [addError] (with its stack trace), and removes it.
  /// Returns `null` if there are no errors.
  ///
  /// This is used by the store to process the errors added by the persistor,
  /// so you usually don't need to call it yourself.
  (Object, StackTrace)? getAndRemoveFirstError() =>
      _errors.isEmpty ? null : _errors.removeFirst();
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
        "newState = $newState");
    return _persistor.persistDifference(
        lastPersistedState: lastPersistedState, newState: newState);
  }

  @override
  Future<void> saveInitialState(St state) async {
    print("Persistor: save initial state.");
    return _persistor.saveInitialState(state);
  }

  @override
  Object? wrapError(Object error, StackTrace stackTrace) =>
      _persistor.wrapError(error, stackTrace);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _persistor.addError(error, stackTrace);

  @override
  (Object, StackTrace)? getAndRemoveFirstError() => _persistor.getAndRemoveFirstError();

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
