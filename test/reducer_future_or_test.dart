import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import "package:test/test.dart";

// Developed by Marcelo Glasberg (Aug 2019).
// For more info, see: https://pub.dartlang.org/packages/async_redux

/// These test makes sure that reducers can return:
///    Null reduce()
///    AppState reduce()
///    AppState? reduce()
///    Future<AppState> reduce()
///    Future<AppState?> reduce()
///
/// But CANNOT return:
///    Future<AppState>? reduce()
///    Future<AppState?>? reduce()
///
void main() {
  /////////////////////////////////////////////////////////////////////////////

  test('Test all accepted and rejected reducer return types', () async {
    //
    // The initial state is "0".
    Store<AppState> store = Store<AppState>(initialState: AppState.initialState());
    await Future.delayed(const Duration(milliseconds: 50));
    expect(store.state.text, "0");

    // Null reduce()
    // Doesn't change anything and the state is still "0".
    store.dispatch(ActionNull());
    await Future.delayed(const Duration(milliseconds: 50));
    expect(store.state.text, "0");

    // AppState reduce()
    // Adds an "A" to the state.
    store.dispatch(ActionA());
    await Future.delayed(const Duration(milliseconds: 50));
    expect(store.state.text, "0A");

    // AppState? reduce()
    // Adds a "B" to the state.
    store.dispatch(ActionB());
    await Future.delayed(const Duration(milliseconds: 50));
    expect(store.state.text, "0AB");

    // Future<AppState> reduce()
    // Adds a "C" to the state.
    store.dispatch(ActionC());
    await Future.delayed(const Duration(milliseconds: 50));
    expect(store.state.text, "0ABC");

    // Future<AppState?> reduce()
    // Adds a "D" to the state.
    store.dispatch(ActionD());
    await Future.delayed(const Duration(milliseconds: 50));
    expect(store.state.text, "0ABCD");

    // ------------

    dynamic error1;

    try {
      // Future<AppState>? reduce()
      await store.dispatch(ActionE());
    } catch (error) {
      error1 = error;
    }

    expect(
        error1,
        StoreException("Reducer should return `St?` or `Future<St?>`. "
            "Do not return `Future<St>?`."));

    // ------------

    dynamic error2;

    try {
      // Future<AppState?>? reduce()
      await store.dispatch(ActionF());
    } catch (error) {
      error2 = error;
    }

    expect(
        error2,
        StoreException("Reducer should return `St?` or `Future<St?>`. "
            "Do not return `Future<St?>?`."));

    // ------------

    dynamic error3;

    try {
      // FutureOr<AppState> reduce()
      await store.dispatch(ActionG());
    } catch (error) {
      error3 = error;
    }

    expect(
        error3,
        StoreException("Reducer should return `St?` or `Future<St?>`. "
            "Do not return `FutureOr`."));

    // ------------

    dynamic error4;

    try {
      // FutureOr<AppState?> reduce()
      await store.dispatch(ActionH());
    } catch (error) {
      error4 = error;
    }

    expect(
        error4,
        StoreException("Reducer should return `St?` or `Future<St?>`. "
            "Do not return `FutureOr`."));

    // ------------

    dynamic error5;

    try {
      // FutureOr<AppState>? reduce()
      await store.dispatch(ActionI());
    } catch (error) {
      error5 = error;
    }

    expect(
        error5,
        StoreException("Reducer should return `St?` or `Future<St?>`. "
            "Do not return `FutureOr`."));

    // ------------

    dynamic error6;

    try {
      // FutureOr<AppState?>? reduce()
      await store.dispatch(ActionJ());
    } catch (error) {
      error6 = error;
    }

    expect(
        error6,
        StoreException("Reducer should return `St?` or `Future<St?>`. "
            "Do not return `FutureOr`."));

    // ------------
  });

  /////////////////////////////////////////////////////////////////////////////
}

// ----------------------------------------------

/// Null reduce()
class ActionNull extends ReduxAction<AppState> {
  @override
  Null reduce() {
    return null;
  }
}

// ----------------------------------------------

/// AppState reduce()
class ActionA extends ReduxAction<AppState> {
  @override
  AppState reduce() {
    return state.copy(state.text + 'A');
  }
}

// ----------------------------------------------

/// AppState? reduce()
class ActionB extends ReduxAction<AppState> {
  @override
  AppState? reduce() {
    return state.copy(state.text + 'B');
  }
}

// ----------------------------------------------

/// Future<AppState> reduce()
class ActionC extends ReduxAction<AppState> {
  @override
  Future<AppState> reduce() async {
    return state.copy(state.text + 'C');
  }
}

// ----------------------------------------------

/// Future<AppState?> reduce()
class ActionD extends ReduxAction<AppState> {
  @override
  Future<AppState?> reduce() async {
    return state.copy(state.text + 'D');
  }
}

// ----------------------------------------------

/// Future<AppState>? reduce()
class ActionE extends ReduxAction<AppState> {
  @override
  Future<AppState>? reduce() async {
    return state.copy(state.text + 'E');
  }
}

// ----------------------------------------------

/// Future<AppState?>? reduce()
class ActionF extends ReduxAction<AppState> {
  @override
  Future<AppState?>? reduce() async {
    return state.copy(state.text + 'F');
  }
}

// ----------------------------------------------

/// FutureOr<AppState> reduce()
class ActionG extends ReduxAction<AppState> {
  @override
  FutureOr<AppState> reduce() async {
    return state.copy(state.text + 'G');
  }
}

// ----------------------------------------------

/// FutureOr<AppState?> reduce()
class ActionH extends ReduxAction<AppState> {
  @override
  FutureOr<AppState?> reduce() async {
    return state.copy(state.text + 'H');
  }
}

// ----------------------------------------------

/// FutureOr<AppState>? reduce()
class ActionI extends ReduxAction<AppState> {
  @override
  FutureOr<AppState>? reduce() async {
    return state.copy(state.text + 'I');
  }
}

// ----------------------------------------------

/// FutureOr<AppState?>? reduce()
class ActionJ extends ReduxAction<AppState> {
  @override
  FutureOr<AppState?>? reduce() async {
    return state.copy(state.text + 'J');
  }
}

///////////////////////////////////////////////////////////////////////////////

@immutable
class AppState {
  final String text;

  AppState(this.text);

  AppState copy(String? text) => AppState(text ?? this.text);

  static AppState initialState() => AppState('0');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is AppState && runtimeType == other.runtimeType && text == other.text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => text.toString();
}

///////////////////////////////////////////////////////////////////////////////
