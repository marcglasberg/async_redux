import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Developed by Marcelo Glasberg (Aug 2019).
// For more info, see: https://pub.dartlang.org/packages/async_redux

/// This tests show that both sync and async reducers work as they should.
/// Async reducers work as long as we return uncompleted futures.
/// https://www.woolha.com/articles/dart-event-loop-microtask-event-queue
/// https://steemit.com/utopian-io/@tensor/the-fundamentals-of-zones-microtasks-and-event-loops-in-the-dart-programming-language-dart-tutorial-part-3

///////////////////////////////////////////////////////////////////////////////

void main() {
  /////////////////////////////////////////////////////////////////////////////

  test(
      'This tests the mechanism of a SYNC Reducer: '
      'The reducer changes the state to A, and it will later be changed to B. '
      'It works if the reducer returns `AppState`.', () async {
    //
    var state = "";

    String reducer() {
      Future.microtask(() => state += "A");
      return "B";
    }

    /// There is no 'A' after calling the reducer, because it ran SYNC.
    state = reducer();
    expect(state, "B");

    /// After a microtask, 'A' appears.
    await Future.microtask(() {});
    expect(state, "BA");
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
      state += "A";
      Future.microtask(() => state += "B");
      state += "C";
      await Future.microtask(() {});
      state += "D";
      Future.microtask(() => state += "E");
      return "F";
    }

    /// There is no 'E' yet, because even if the reducer is async,
    /// the then() method ran SYNC after the value was returned.
    await reducer().then((newState) => state += newState);
    expect(state, "ACBDF");

    /// After a microtask, 'E' appears.
    await Future.microtask(() {});
    expect(state, "ACBDFE");
  });

  /////////////////////////////////////////////////////////////////////////////

  test(
      "Tests what happens when we do it wrong, and return COMPLETED Futures."
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
      Future.microtask(() => state += "B");
      return "A";
    }

    // The reducer returned 'A', but the microtask that adds 'B'
    // ran before the then() method had the chance to run.
    await reducer().then((newState) => state += newState);
    expect(state, "BA");

    // It's all finished by now, nothing yet to run.
    await Future.microtask(() {});
    expect(state, "BA");
  });

  /////////////////////////////////////////////////////////////////////////////

  test(
      '1) A sync reducer is called, '
      'and no actions are dispatched inside of the reducer. '
      'It acts as a pure function, just like a regular reducer of "vanilla" Redux.', () async {
    states = [];
    var storeTester = StoreTester<AppState>(initialState: AppState.initialState());
    expect(storeTester.state.text, 'A');
    storeTester.dispatch(Action1B());
    TestInfo<AppState?> info = await (storeTester.waitAllUnorderedGetLast([Action1B]));
    expect(states, [AppState('A')]);
    expect(info.state!.text, 'AB');
  });

  /////////////////////////////////////////////////////////////////////////////

  test(
      '2) A sync reducer is called, '
      'which dispatches another sync action. '
      'They are both executed synchronously.', () async {
    states = [];
    var storeTester = StoreTester<AppState>(initialState: AppState.initialState());
    expect(storeTester.state.text, 'A');
    storeTester.dispatch(Action2B());
    TestInfo<AppState?> info = await (storeTester.waitAllUnorderedGetLast([Action2B, Action2C]));
    expect(states, [AppState('A'), AppState('AC')]);
    expect(info.state!.text, 'ACB');
  });

  ///////////////////////////////////////////////////////////////////////////

  test(
      '3) A sync reducer is called, '
      'which dispatches an ASYNC action.', () async {
    states = [];
    var storeTester = StoreTester<AppState>(initialState: AppState.initialState());
    expect(storeTester.state.text, 'A');
    storeTester.dispatch(Action3B());
    TestInfo<AppState?> info = await (storeTester.waitAllUnorderedGetLast([Action3B, Action3C]));
    expect(states, [AppState('A'), AppState('A')]);
    expect(info.state!.text, 'ABC');
  });

  /////////////////////////////////////////////////////////////////////////////

  test(
      '4) An ASYNC reducer is called, '
      'which dispatches another ASYNC action. '
      'The second reducer finishes BEFORE the first.', () async {
    states = [];
    var storeTester = StoreTester<AppState>(initialState: AppState.initialState());
    expect(storeTester.state.text, 'A');
    storeTester.dispatch(Action4B());
    TestInfo<AppState?> info = await (storeTester.waitAllUnorderedGetLast([Action4B, Action4C]));
    expect(states, [AppState('A'), AppState('A'), AppState('A'), AppState('AC')]);
    expect(info.state!.text, 'ACB');
  });

  /////////////////////////////////////////////////////////////////////////////

  test(
      '5) An ASYNC reducer is called, '
      'which dispatches another ASYNC action. '
      'The second reducer finishes AFTER the first.', () async {
    states = [];
    var storeTester = StoreTester<AppState>(initialState: AppState.initialState());
    expect(storeTester.state.text, 'A');
    storeTester.dispatch(Action5B());
    TestInfo<AppState?> info = await (storeTester.waitAllUnorderedGetLast([Action5B, Action5C]));
    expect(states, [AppState('A'), AppState('A'), AppState('A'), AppState('A')]);
    expect(info.state!.text, 'ABC');
  });

  /////////////////////////////////////////////////////////////////////////////

  test(
      "This tests the mechanism of ASYNC Reducers: "
      "1) Completed then Completed = state gets swallowed. "
      "2) Completed then Uncompleted = wrong, but works because of order. "
      "3) Uncompleted then Completed = state gets swallowed. "
      "4) Uncompleted then Uncompleted = correct and works. "
      "Note: "
      "* An async reducer that returns a COMPLETED future's will:"
      "   - Apply the state in the very next microtask after it is dispatched."
      "   - Apply the state in the very next microtask after the reducer returned (which is bad)."
      "* An async reducer that returns an UNCOMPLETED future's will:"
      "   - Apply the state in the very next microtask after it is dispatched, or after that."
      "   - Apply the state in the SAME microtask when the reducer returned (which is good).",
      () async {
    //
    // 1) Completed then Completed = state gets swallowed.
    var storeTester = StoreTester<AppState>(initialState: AppState.initialState());
    expect(storeTester.state.text, 'A');
    storeTester.dispatch(Action6ACompleted());
    storeTester.dispatch(Action6BCompleted());
    var info = await (storeTester.waitAllUnordered([Action6ACompleted, Action6BCompleted]));
    expect(info.first.action.runtimeType, Action6ACompleted);
    expect(info.last.action.runtimeType, Action6BCompleted);
    expect(info.first.state.text, 'AX');
    expect(info.last.state.text, 'A'); // The X was swallowed.

    // 2) Completed then Uncompleted = wrong, but works because of order.
    storeTester = StoreTester<AppState>(initialState: AppState.initialState());
    expect(storeTester.state.text, 'A');
    storeTester.dispatch(Action6ACompleted());
    storeTester.dispatch(Action6BUncompleted());
    info = await storeTester.waitAllUnordered([Action6ACompleted, Action6BUncompleted]);
    expect(info.first.action.runtimeType, Action6ACompleted);
    expect(info.last.action.runtimeType, Action6BUncompleted);
    expect(info.first.state.text, 'AX');
    expect(info.last.state.text, 'AX');

    // 3) Uncompleted then Completed = state gets swallowed.
    storeTester = StoreTester<AppState>(initialState: AppState.initialState());
    expect(storeTester.state.text, 'A');
    storeTester.dispatch(Action6AUncompleted());
    storeTester.dispatch(Action6BCompleted());
    info = await storeTester.waitAllUnordered([Action6AUncompleted, Action6BCompleted]);
    expect(info.first.action.runtimeType, Action6AUncompleted);
    expect(info.last.action.runtimeType, Action6BCompleted);
    expect(info.first.state.text, 'AX');
    expect(info.last.state.text, 'A'); // The X was swallowed.

    // 4) Uncompleted then Uncompleted = correct and works.
    storeTester = StoreTester<AppState>(initialState: AppState.initialState());
    expect(storeTester.state.text, 'A');
    storeTester.dispatch(Action6AUncompleted());
    storeTester.dispatch(Action6BUncompleted());
    info = await storeTester.waitAllUnordered([Action6AUncompleted, Action6BUncompleted]);
    expect(info.first.action.runtimeType, Action6AUncompleted);
    expect(info.last.action.runtimeType, Action6BUncompleted);
    expect(info.first.state.text, 'AX');
    expect(info.last.state.text, 'AX');
  });

  /////////////////////////////////////////////////////////////////////////////

  test(
      "Test that if you add method assertUncompletedFuture() to the end of reducers, "
      "it's capable of detecting completed futures.", () async {
    //
    var storeTester = StoreTester<AppState>(initialState: AppState.initialState());

    // ---

    dynamic error1 = "";

    runZonedGuarded(() async {
      storeTester.dispatch(Action7Completed());
    }, (_error, stackTrace) {
      error1 = _error;
    });

    await Future.delayed(const Duration(milliseconds: 100));

    expect(error1.toString(), contains("This may result in state changes being lost"));

    // ---

    dynamic error2 = "";

    runZonedGuarded(() async {
      storeTester.dispatch(Action7Uncompleted());
    }, (_error, stackTrace) {
      error2 = _error;
    });

    await Future.delayed(const Duration(milliseconds: 100));

    expect(error2, "");
  });

  /////////////////////////////////////////////////////////////////////////////

  test(
      "Test that dispatching a sync action works just the same as calling a sync function, "
      "and dispatching an async action works just the same as calling an async function.",
      () async {
    //
    var storeTester = StoreTester<AppState>(initialState: AppState.initialState());

    // ---

    states = [];

    Future<void> asyncFunction() async {
      states.add(AppState('f1'));
      await Future.microtask(() {});
      states.add(AppState('f2'));
    }

    /// The below code will print: 1 3 5 2 4 6

    states.add(AppState('BEFORE'));
    storeTester.dispatch(MyAsyncAction());
    asyncFunction();
    states.add(AppState('AFTER'));

    await Future.delayed(const Duration(milliseconds: 100));

    expect(states, [
      AppState('BEFORE'),
      AppState('a1'),
      AppState('f1'),
      AppState('AFTER'),
      AppState('a2'),
      AppState('f2'),
    ]);
  });

  /////////////////////////////////////////////////////////////////////////////
}

// ----------------------------------------------

/// The app state, which in this case is just a text.
@immutable
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

late List<AppState?> states;

// ----------------------------------------------

class Action1B extends ReduxAction<AppState> {
  @override
  AppState reduce() {
    states.add(state);
    return state.copy(state.text + 'B');
  }
}

// ----------------------------------------------

class Action2B extends ReduxAction<AppState> {
  @override
  AppState reduce() {
    states.add(state);
    dispatch(Action2C());
    states.add(state);
    return state.copy(state.text + 'B');
  }
}

class Action2C extends ReduxAction<AppState> {
  @override
  AppState reduce() {
    return state.copy(state.text + 'C');
  }
}

// ----------------------------------------------

class Action3B extends ReduxAction<AppState> {
  @override
  AppState reduce() {
    states.add(state);
    dispatch(Action3C());
    states.add(state);
    return state.copy(state.text + 'B');
  }
}

class Action3C extends ReduxAction<AppState> {
  @override
  Future<AppState> reduce() async {
    await Future.microtask(() {});
    return state.copy(state.text + 'C');
  }
}

// ----------------------------------------------

class Action4B extends ReduxAction<AppState> {
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

class Action4C extends ReduxAction<AppState> {
  @override
  Future<AppState> reduce() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return state.copy(state.text + 'C');
  }
}

// ----------------------------------------------

class Action5B extends ReduxAction<AppState> {
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

class Action5C extends ReduxAction<AppState> {
  @override
  Future<AppState> reduce() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return state.copy(state.text + 'C');
  }
}

// ----------------------------------------------

class Action6ACompleted extends ReduxAction<AppState> {
  @override
  Future<AppState?> reduce() async => state.copy(state.text + 'X');
}

class Action6BCompleted extends ReduxAction<AppState> {
  @override
  Future<AppState?> reduce() async => state;
}

class Action6AUncompleted extends ReduxAction<AppState> {
  @override
  Future<AppState?> reduce() async {
    await microtask;
    return state.copy(state.text + 'X');
  }
}

class Action6BUncompleted extends ReduxAction<AppState> {
  @override
  Future<AppState?> reduce() async {
    await microtask;
    return state;
  }
}

// ----------------------------------------------

class Action7Completed extends ReduxAction<AppState> {
  @override
  Future<AppState?> reduce() async {
    assertUncompletedFuture();
    return state;
  }
}

class Action7Uncompleted extends ReduxAction<AppState> {
  @override
  Future<AppState?> reduce() async {
    await microtask;
    assertUncompletedFuture();
    return state;
  }
}

// ----------------------------------------------

class MyAsyncAction extends ReduxAction<AppState> {
  @override
  Future<AppState?> reduce() async {
    states.add(AppState('a1'));
    await microtask;
    states.add(AppState('a2'));
    return state;
  }
}

// ----------------------------------------------
