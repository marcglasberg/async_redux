import 'dart:async';

import 'package:async_redux/async_redux.dart';
import "package:test/test.dart";

// Developed by Marcelo Glasberg (Aug 2019).
// For more info, see: https://pub.dartlang.org/packages/async_redux

/// This tests show that both sync and async reducers work as they should,
/// and that no state is lost. This works no matter if an async reducer returns
/// a completed or uncompleted future.

///////////////////////////////////////////////////////////////////////////////

/// The app state, which in this case is just a text.
class AppState {
  final String text;

  AppState(this.text);

  AppState copy(String? text) => AppState(text ?? this.text);

  static AppState initialState() => AppState('A');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppState && runtimeType == other.runtimeType && text == other.text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => text.toString();
}

class AppEnvironment {}

late List<AppState?> states;

void main() {
  /////////////////////////////////////////////////////////////////////////////

  test(
      'This tests the mechanism of a SYNC Reducer: '
      'The reducer changes the state to A, and it will later be changed to B. '
      'It works if the reducer returns `AppState`.', () async {
    //
    var state = "";

    String reducer() {
      Future.microtask(() {
        state = "B";
      });
      return "A";
    }

    state = reducer();
    expect(state, "A");

    await Future.delayed(const Duration(milliseconds: 0));
    expect(state, "B");
  });

  /////////////////////////////////////////////////////////////////////////////

  test(
      'This tests the mechanism of a ASYNC Reducer: '
      'The reducer changes the state to A, and it will later be changed to B. '
      'It works if the reducer returns a `Future<AppState>` and contains the `await` keyword. '
      'This works because the `then` is called synchronously after the `return`.', () async {
    //
    var state = "";

    Future<String> reducer() async {
      await Future.value(null);
      Future.microtask(() {
        state = "B";
      });
      return "A";
    }

    await reducer().then((newState) {
      state = newState;
    });
    expect(state, "A");

    await Future.delayed(const Duration(milliseconds: 0));
    expect(state, "B");
  });

  /////////////////////////////////////////////////////////////////////////////

  test(
      "Tests what would happen if we allowed AsyncRedux to process COMPLETED Futures:"
      "The reducer changes the state to A, and it should later be changed to B."
      "It fails if the reducer returns a Future<AppState> and it does NOT contain the await keyword."
      "If the reducer does NOT contain the `await` keyword, it means it was created as a completed Future."
      "In this case, Dart schedules the `then` for the next microtask"
      "(see why here: https://github.com/dart-lang/sdk/issues/14323)."
      "In other words, in this case `then` is called asynchronously, one microtask after the `return`."
      "If some other process changes the state in that exact microtask the state change may be lost."
      "We don't allow this to happen because we check the reducer signature, and if it returns"
      "a Future we force it to wait for the next microtask. "
      "In other words, we make sure the future is uncompleted.", () async {
    //
    var state = "";

    Future<String> reducer() async {
      Future.microtask(() {
        state = "B";
      });
      return "A";
    }

    await reducer().then((newState) {
      state = newState;
    });
    expect(state, "A");

    // State 'B' is lost.
    await Future.delayed(const Duration(milliseconds: 0));
    expect(state, "A");
  });

  /////////////////////////////////////////////////////////////////////////////

  test(
      '1) A sync reducer is called, '
      'and no actions are dispatched inside of the reducer. '
      'It acts as a pure function, just like a regular reducer of "vanilla" Redux.', () async {
    states = [];
    var storeTester = StoreTester<AppState, AppEnvironment>(
      initialState: AppState.initialState(),
      environment: AppEnvironment(),
    );
    expect(storeTester.state.text, 'A');
    storeTester.dispatch(Action1B());
    TestInfo<AppState?, AppEnvironment> info = await (storeTester.waitAllUnorderedGetLast([Action1B]));
    expect(states, [AppState('A')]);
    expect(info.state!.text, 'AB');
  });

  /////////////////////////////////////////////////////////////////////////////

  test(
      '2) A sync reducer is called, '
      'which dispatches another sync action. '
      'They are both executed synchronously.', () async {
    states = [];
    var storeTester = StoreTester<AppState, AppEnvironment>(
      initialState: AppState.initialState(),
      environment: AppEnvironment(),
    );
    expect(storeTester.state.text, 'A');
    storeTester.dispatch(Action2B());
    TestInfo<AppState?, AppEnvironment> info = await (storeTester.waitAllUnorderedGetLast([Action2B, Action2C]));
    expect(states, [AppState('A'), AppState('AC')]);
    expect(info.state!.text, 'ACB');
  });

  /////////////////////////////////////////////////////////////////////////////

  test(
      '3) A sync reducer is called, '
      'which dispatches an ASYNC action.', () async {
    states = [];
    var storeTester = StoreTester<AppState, AppEnvironment>(
      initialState: AppState.initialState(),
      environment: AppEnvironment(),
    );
    expect(storeTester.state.text, 'A');
    storeTester.dispatch(Action3B());
    TestInfo<AppState?, AppEnvironment> info = await (storeTester.waitAllUnorderedGetLast([Action3B, Action3C]));
    expect(states, [AppState('A'), AppState('A')]);
    expect(info.state!.text, 'ABC');
  });

  /////////////////////////////////////////////////////////////////////////////

  test(
      '4) An ASYNC reducer is called, '
      'which dispatches another ASYNC action. '
      'The second reducer finishes BEFORE the first.', () async {
    states = [];
    var storeTester = StoreTester<AppState, AppEnvironment>(
      initialState: AppState.initialState(),
      environment: AppEnvironment(),
    );
    expect(storeTester.state.text, 'A');
    storeTester.dispatch(Action4B());
    TestInfo<AppState?, AppEnvironment> info = await (storeTester.waitAllUnorderedGetLast([Action4B, Action4C]));
    expect(states, [AppState('A'), AppState('A'), AppState('A'), AppState('AC')]);
    expect(info.state!.text, 'ACB');
  });

  /////////////////////////////////////////////////////////////////////////////

  test(
      '5) An ASYNC reducer is called, '
      'which dispatches another ASYNC action. '
      'The second reducer finishes AFTER the first.', () async {
    states = [];
    var storeTester = StoreTester<AppState, AppEnvironment>(
      initialState: AppState.initialState(),
      environment: AppEnvironment(),
    );
    expect(storeTester.state.text, 'A');
    storeTester.dispatch(Action5B());
    TestInfo<AppState?, AppEnvironment> info = await (storeTester.waitAllUnorderedGetLast([Action5B, Action5C]));
    expect(states, [AppState('A'), AppState('A'), AppState('A'), AppState('A')]);
    expect(info.state!.text, 'ABC');
  });

  /////////////////////////////////////////////////////////////////////////////

  test(
      '6) Tests what happens if the developer returns a COMPLETED Future: '
      'AsyncRedux adds await `Future.microtask(() {});` '
      'to convert it into an uncompleted future. '
      'In other words, it will run the reducer later, '
      'when it can actually apply the new state right away.', () async {
    states = [];
    var storeTester = StoreTester<AppState, AppEnvironment>(
      initialState: AppState.initialState(),
      environment: AppEnvironment(),
    );
    expect(storeTester.state.text, 'A');
    storeTester.dispatch(Action6B());

    TestInfo<AppState?, AppEnvironment> info = await (storeTester.waitAllUnorderedGetLast([Action6B, Action6C]));
    expect(states, [AppState('A'), AppState('A'), AppState('AB')]);

    // State 'C' is lost.
    expect(info.state!.text, 'ABC');
    print('info.state.text = ${info.state!.text}');
  });

  ///////////////////////////////////////////////////////////////////////////

  test(
      '7) Test 6 is fixed if the reducer executes an await '
      '(here we try putting it in the beginning).', () async {
    states = [];
    var storeTester = StoreTester<AppState, AppEnvironment>(
      initialState: AppState.initialState(),
      environment: AppEnvironment(),
    );
    expect(storeTester.state.text, 'A');
    storeTester.dispatch(Action7B());
    TestInfo<AppState?, AppEnvironment> info = await (storeTester.waitAllUnorderedGetLast([Action7B, Action7C]));
    expect(states, [AppState('A'), AppState('A'), AppState('AB'), AppState('AB')]);
    expect(info.state!.text, 'ABC');
  });

  /////////////////////////////////////////////////////////////////////////////

  test(
      '8) Test 6 is fixed if the reducer executes an await '
      '(here we try putting it in the end).', () async {
    states = [];
    var storeTester = StoreTester<AppState, AppEnvironment>(
      initialState: AppState.initialState(),
      environment: AppEnvironment(),
    );
    expect(storeTester.state.text, 'A');
    storeTester.dispatch(Action8B());
    TestInfo<AppState?, AppEnvironment> info = await (storeTester.waitAllUnorderedGetLast([Action8B, Action8C]));
    expect(states, [AppState('A'), AppState('A'), AppState('A'), AppState('AB')]);
    expect(info.state!.text, 'ABC');
  });

  /////////////////////////////////////////////////////////////////////////////

  test(
      '9) Test 6 is fixed if the reducer executes an await '
      '(here we try putting one in the beginning and one in the end).', () async {
    states = [];
    var storeTester = StoreTester<AppState, AppEnvironment>(
      initialState: AppState.initialState(),
      environment: AppEnvironment(),
    );
    expect(storeTester.state.text, 'A');
    storeTester.dispatch(Action9B());
    TestInfo<AppState?, AppEnvironment> info = await (storeTester.waitAllUnorderedGetLast([Action9B, Action9C]));
    expect(states, [AppState('A'), AppState('A'), AppState('A'), AppState('A'), AppState('AB')]);
    expect(info.state!.text, 'ABC');
  });

  /////////////////////////////////////////////////////////////////////////////
}

/// Note:
///
/// These wait for microtasks:
///   await Future.value(null);
///   await Future.sync((){});
///   await Future.microtask((){});
///
/// These wait for tasks (run only after all pending microtasks):
///   await Future((){});
///   await Future.delayed(Duration(seconds: 1));
///
/// More info:
/// https://www.woolha.com/articles/dart-event-loop-microtask-event-queue
/// https://steemit.com/utopian-io/@tensor/the-fundamentals-of-zones-microtasks-and-event-loops-in-the-dart-programming-language-dart-tutorial-part-3

// ----------------------------------------------

class Action1B extends ReduxAction<AppState, AppEnvironment> {
  @override
  AppState reduce() {
    states.add(state);
    return state.copy(state.text + 'B');
  }
}

// ----------------------------------------------

class Action2B extends ReduxAction<AppState, AppEnvironment> {
  @override
  AppState reduce() {
    states.add(state);
    dispatch(Action2C());
    states.add(state);
    return state.copy(state.text + 'B');
  }
}

class Action2C extends ReduxAction<AppState, AppEnvironment> {
  @override
  AppState reduce() {
    return state.copy(state.text + 'C');
  }
}

// ----------------------------------------------

class Action3B extends ReduxAction<AppState, AppEnvironment> {
  @override
  AppState reduce() {
    states.add(state);
    dispatch(Action3C());
    states.add(state);
    return state.copy(state.text + 'B');
  }
}

class Action3C extends ReduxAction<AppState, AppEnvironment> {
  @override
  Future<AppState> reduce() async {
    await Future.sync(() {});
    return state.copy(state.text + 'C');
  }
}

// ----------------------------------------------

class Action4B extends ReduxAction<AppState, AppEnvironment> {
  @override
  Future<AppState> reduce() async {
    states.add(state);
    await Future.delayed(const Duration(milliseconds: 100));
    states.add(state);
    dispatch(Action4C());
    states.add(state);
    await Future.delayed(const Duration(milliseconds: 200));
    states.add(state);
    return state.copy(state.text + 'B');
  }
}

class Action4C extends ReduxAction<AppState, AppEnvironment> {
  @override
  Future<AppState> reduce() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return state.copy(state.text + 'C');
  }
}

// ----------------------------------------------

class Action5B extends ReduxAction<AppState, AppEnvironment> {
  @override
  Future<AppState> reduce() async {
    states.add(state);
    await Future.delayed(const Duration(milliseconds: 100));
    states.add(state);
    dispatch(Action5C());
    states.add(state);
    await Future.delayed(const Duration(milliseconds: 50));
    states.add(state);
    return state.copy(state.text + 'B');
  }
}

class Action5C extends ReduxAction<AppState, AppEnvironment> {
  @override
  Future<AppState> reduce() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return state.copy(state.text + 'C');
  }
}

// ----------------------------------------------

/// Returns a COMPLETED Future.
class Action6B extends ReduxAction<AppState, AppEnvironment> {
  @override
  Future<AppState> reduce() async {
    print('33333333333');
    states.add(state);
    dispatch(Action6C());
    states.add(state);
    return state.copy(state.text + 'B');
  }
}

/// Returns an UNCOMPLETED Future.
class Action6C extends ReduxAction<AppState, AppEnvironment> {
  @override
  Future<AppState> reduce() async {
    await Future.value(null);
    states.add(state);
    print('Action6C.reduce');
    return state.copy(state.text + 'C');
  }
}

// ----------------------------------------------

class Action7B extends ReduxAction<AppState, AppEnvironment> {
  @override
  Future<AppState> reduce() async {
    await Future.value(null);
    states.add(state);
    dispatch(Action7C());
    states.add(state);
    return state.copy(state.text + 'B');
  }
}

class Action7C extends ReduxAction<AppState, AppEnvironment> {
  @override
  Future<AppState> reduce() async {
    states.add(state);
    await Future.value(null);
    states.add(state);
    return state.copy(state.text + 'C');
  }
}

// ----------------------------------------------

class Action8B extends ReduxAction<AppState, AppEnvironment> {
  @override
  Future<AppState> reduce() async {
    states.add(state);
    dispatch(Action8C());
    states.add(state);
    await Future.value(null);
    states.add(state);
    return state.copy(state.text + 'B');
  }
}

class Action8C extends ReduxAction<AppState, AppEnvironment> {
  @override
  Future<AppState> reduce() async {
    await Future.value(null);
    states.add(state);
    return state.copy(state.text + 'C');
  }
}

// ----------------------------------------------

class Action9B extends ReduxAction<AppState, AppEnvironment> {
  @override
  Future<AppState> reduce() async {
    states.add(state);
    await Future.value(null);
    states.add(state);
    dispatch(Action9C());
    states.add(state);
    await Future.value(null);
    states.add(state);
    return state.copy(state.text + 'B');
  }
}

class Action9C extends ReduxAction<AppState, AppEnvironment> {
  @override
  Future<AppState> reduce() async {
    await Future.value(null);
    states.add(state);
    return state.copy(state.text + 'C');
  }
}

// ----------------------------------------------
