import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:flutter_test/flutter_test.dart';

// Developed by Marcelo Glasberg (Aug 2019).
// For more info, see: https://pub.dartlang.org/packages/async_redux

///////////////////////////////////////////////////////////////////////////////

/// This is meant to solve this issue:
/// - BEFORE() SWALLOWS REDUCER() ERRORS
///   https://github.com/marcglasberg/async_redux/issues/105
///
void main() {
  /////////////////////////////////////////////////////////////////////////////

  test('1).', () async {
    //
    Store<String> store = Store<String>(initialState: "");

    Object? error;

    try {
      await store.dispatch(ActionBeforeFutureOr());
    } catch (_error) {
      error = _error;
    }

    expect(store.state, "");
    expect(
        error,
        StoreException("Before should return `void` or `Future<void>`. "
            "Do not return `FutureOr`."));
  });

  /////////////////////////////////////////////////////////////////////////////

  test('1).', () async {
    //
    Store<String> store = Store<String>(initialState: "");

    Object? error;

    try {
      await store.dispatch(ActionSyncBeforeThrowsError());
    } catch (_error) {
      error = _error;
    }

    expect(store.state, "");
    expect(error, StoreException("ERROR 1"));
  });

  /////////////////////////////////////////////////////////////////////////////

  test('2).', () async {
    //
    Store<String> store = Store<String>(initialState: "");

    Object? error;

    try {
      await store.dispatch(ActionAsyncBeforeThrowsError());
    } catch (_error) {
      error = _error;
    }

    expect(store.state, "");
    expect(error, StoreException("ERROR 2"));
  });

  /////////////////////////////////////////////////////////////////////////////

  test('3).', () async {
    //
    Store<String> store = Store<String>(initialState: "");

    Object? error;

    try {
      await store.dispatch(ActionAsyncBeforeThrowsErrorAsync());
    } catch (_error) {
      error = _error;
    }

    expect(store.state, "");
    expect(error, StoreException("ERROR B"));
  });

  /////////////////////////////////////////////////////////////////////////////

  test('4).', () async {
    //
    Store<String> store = Store<String>(initialState: "");

    Object? error;

    try {
      await store.dispatch(ActionSyncBeforeThrowsErrorWithWrapError());
    } catch (_error) {
      error = _error;
    }

    expect(store.state, "");
    expect(error, WrappedError(StoreException("ERROR 4")));
  });

  /////////////////////////////////////////////////////////////////////////////

  test('5).', () async {
    //
    Store<String> store = Store<String>(initialState: "");

    Object? error;

    try {
      await store.dispatch(ActionAsyncBeforeThrowsErrorWithWrapError());
    } catch (_error) {
      error = _error;
    }

    expect(store.state, "");
    expect(error, WrappedError(StoreException("ERROR 5")));
  });

  /////////////////////////////////////////////////////////////////////////////

  test('6).', () async {
    //
    Store<String> store = Store<String>(initialState: "");

    Object? error;

    try {
      await store.dispatch(ActionAsyncBeforeThrowsErrorAsyncWithWrapError());
    } catch (_error) {
      error = _error;
    }

    expect(store.state, "");
    expect(error, WrappedError(StoreException("ERROR B")));
  });

  /////////////////////////////////////////////////////////////////////////////

  test('7).', () async {
    //
    Store<String> store = Store<String>(initialState: "");

    Object? error;

    try {
      await store.dispatch(ActionWithBeforeAndReducerThatThrowsErrorWithWrapError());
    } catch (_error) {
      error = _error;
    }

    expect(store.state, "C");
    expect(error, WrappedError(StoreException("ERROR 7")));
  });

  /////////////////////////////////////////////////////////////////////////////
}

// 0) ----------------------------------------------

class ActionBeforeFutureOr extends ReduxAction<String> {
  @override
  FutureOr<void> before() async {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  @override
  String reduce() {
    return state + '0';
  }
}

// 1) ----------------------------------------------

class ActionSyncBeforeThrowsError extends ReduxAction<String> {
  @override
  void before() {
    throw StoreException("ERROR 1");
  }

  @override
  String reduce() {
    return state + '1';
  }
}

// 2) ----------------------------------------------

class ActionAsyncBeforeThrowsError extends ReduxAction<String> {
  @override
  Future<void> before() async {
    await Future.delayed(const Duration(milliseconds: 50));
    throw StoreException("ERROR 2");
  }

  @override
  String reduce() {
    return state + '2';
  }
}

// 3) ----------------------------------------------

class ActionAsyncBeforeThrowsErrorAsync extends ReduxAction<String> {
  @override
  Future<void> before() async {
    await Future.delayed(const Duration(milliseconds: 50));
    dispatch(ActionB());
  }

  @override
  String reduce() {
    return state + '3';
  }
}

// ----------------------------------------------

class ActionB extends ReduxAction<String> {
  @override
  String reduce() {
    throw StoreException("ERROR B");
  }
}

// ----------------------------------------------

class ActionC extends ReduxAction<String> {
  @override
  String reduce() {
    return state + 'C';
  }
}

// 4) ----------------------------------------------

class ActionSyncBeforeThrowsErrorWithWrapError extends ReduxAction<String> {
  @override
  void before() {
    throw StoreException("ERROR 4");
  }

  @override
  String reduce() {
    return state + '4';
  }

  @override
  Object? wrapError(Object error, StackTrace stackTrace) {
    return WrappedError(error);
  }
}

// 5) ----------------------------------------------

class ActionAsyncBeforeThrowsErrorWithWrapError extends ReduxAction<String> {
  @override
  Future<void> before() async {
    await Future.delayed(const Duration(milliseconds: 50));
    throw StoreException("ERROR 5");
  }

  @override
  String reduce() {
    return state + '5';
  }

  @override
  Object? wrapError(Object error, StackTrace stackTrace) {
    return WrappedError(error);
  }
}

// 6) ----------------------------------------------

class ActionAsyncBeforeThrowsErrorAsyncWithWrapError extends ReduxAction<String> {
  @override
  Future<void> before() async {
    await Future.delayed(const Duration(milliseconds: 50));
    dispatch(ActionB());
  }

  @override
  String reduce() {
    return state + '6';
  }

  @override
  Object? wrapError(Object error, StackTrace stackTrace) => WrappedError(error);
}

// 7) ----------------------------------------------

class ActionWithBeforeAndReducerThatThrowsErrorWithWrapError extends ReduxAction<String> {
  @override
  void before() => dispatch(ActionC());

  @override
  Future<String> reduce() async {
    await Future.delayed(const Duration(milliseconds: 100));
    throw StoreException("ERROR 7");
  }

  @override
  Object? wrapError(Object error, StackTrace stackTrace) => WrappedError(error);
}

// ----------------------------------------------

class WrappedError {
  final Object? error;

  WrappedError(this.error);

  @override
  String toString() {
    return 'WrappedError{error: $error | ${error.runtimeType}}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WrappedError && runtimeType == other.runtimeType && error == other.error;

  @override
  int get hashCode => error.hashCode;
}
