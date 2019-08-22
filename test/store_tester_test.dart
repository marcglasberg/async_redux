import 'dart:async';

import 'package:async_redux/async_redux.dart';
import "package:test/test.dart";

class AppState {
  String text;

  AppState(this.text);

  AppState.add(AppState state, String text)
      : text = (state.text == null) ? text : state.text + "," + text;
}

class Action1 extends ReduxAction<AppState> {
  @override
  FutureOr<AppState> reduce() => AppState.add(state, "1");
}

class Action2 extends ReduxAction<AppState> {
  @override
  FutureOr<AppState> reduce() => AppState.add(state, "2");
}

class Action3 extends ReduxAction<AppState> {
  @override
  FutureOr<AppState> reduce() => AppState.add(state, "3");
}

class Action4 extends ReduxAction<AppState> {
  @override
  FutureOr<AppState> reduce() => AppState.add(state, "4");
}

class Action5 extends ReduxAction<AppState> {
  @override
  FutureOr<AppState> reduce() => AppState.add(state, "5");
}

class Action6 extends ReduxAction<AppState> {
  @override
  FutureOr<AppState> reduce() {
    dispatch(Action1());
    dispatch(Action2());
    dispatch(Action3());
    return AppState.add(state, "6");
  }
}

class Action7 extends ReduxAction<AppState> {
  @override
  FutureOr<AppState> reduce() async {
    dispatch(Action4());
    dispatch(Action6());
    dispatch(Action2());
    dispatch(Action5());
    return AppState.add(state, "7");
  }
}

class Action6b extends ReduxAction<AppState> {
  @override
  FutureOr<AppState> reduce() async {
    dispatch(Action1());
    await Future.delayed(Duration(milliseconds: 10));
    dispatch(Action2());
    dispatch(Action3());
    return AppState.add(state, "6b");
  }
}

class Action7b extends ReduxAction<AppState> {
  @override
  FutureOr<AppState> reduce() async {
    dispatch(Action4());
    dispatch(Action6b());
    dispatch(Action2());
    dispatch(Action5());
    return AppState.add(state, "7b");
  }
}

class Action8 extends ReduxAction<AppState> {
  @override
  FutureOr<AppState> reduce() async {
    await Future.delayed(Duration(milliseconds: 50));
    dispatch(Action2());
    return AppState.add(state, "8");
  }
}

class Action9 extends ReduxAction<AppState> {
  @override
  FutureOr<AppState> reduce() async {
    await Future.delayed(Duration(milliseconds: 100));
    return AppState.add(state, "9");
  }
}

void main() {
  StoreTester<AppState> createStoreTester() {
    var store = Store<AppState>(initialState: AppState("0"));
    return StoreTester.from(store);
  }

  ///////////////////////////////////////////////////////////////////////////////

  test(
      'Dispatch some actions and wait until some condition is met. '
      'Get the end state.', () async {
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");

    storeTester.dispatch(Action1());
    storeTester.dispatch(Action2());
    storeTester.dispatch(Action3());
    storeTester.dispatch(Action4());

    var condition = (TestInfo<AppState> info) => info.state.text == "0,1,2";
    TestInfo<AppState> info1 = await storeTester.waitConditionGetLast(condition);
    expect(info1.state.text, "0,1,2");
    expect(info1.ini, false);

    TestInfo<AppState> info2 =
        await storeTester.waitConditionGetLast((info) => info.state.text == "0,1,2,3,4");
    expect(info2.state.text, "0,1,2,3,4");
    expect(info1.ini, false);
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      'Dispatch some actions and wait until some condition is met. '
      'Get the end state.', () async {
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");

    storeTester.dispatch(Action1());
    storeTester.dispatch(Action2());
    storeTester.dispatch(Action3());
    storeTester.dispatch(Action4());

    var condition = (TestInfo<AppState> info) => info.state.text == "0,1,2" && info.ini;
    TestInfo<AppState> info1 = await storeTester.waitConditionGetLast(condition, ignoreIni: false);
    expect(info1.state.text, "0,1,2");
    expect(info1.ini, true);

    TestInfo<AppState> info2 = await storeTester.waitConditionGetLast(
        (info) => info.state.text == "0,1,2,3,4" && !info.ini,
        ignoreIni: false);
    expect(info2.state.text, "0,1,2,3,4");
    expect(info1.ini, true);
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      'Dispatch some actions and wait until some condition is met. '
      'Get all of the intermediary states (END only).', () async {
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");

    storeTester.dispatch(Action1());
    storeTester.dispatch(Action2());
    storeTester.dispatch(Action3());
    storeTester.dispatch(Action4());

    TestInfoList<AppState> infos =
        await storeTester.waitCondition((info) => info.state.text == "0,1,2");

    expect(infos.length, 2);
    expect(infos.getIndex(0).state.text, "0,1");
    expect(infos.getIndex(0).ini, false);
    expect(infos.getIndex(1).state.text, "0,1,2");
    expect(infos.getIndex(1).ini, false);

    infos = await storeTester.waitCondition((info) => info.state.text == "0,1,2,3,4");
    expect(infos.length, 2);
    expect(infos.getIndex(0).state.text, "0,1,2,3");
    expect(infos.getIndex(0).ini, false);
    expect(infos.getIndex(1).state.text, "0,1,2,3,4");
    expect(infos.getIndex(1).ini, false);
  });
  ///////////////////////////////////////////////////////////////////////////////

  test(
      'Dispatch some actions and wait until some condition is met. '
      'Get all of the intermediary states, '
      'including INI and END.', () async {
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");

    storeTester.dispatch(Action1());
    storeTester.dispatch(Action2());
    storeTester.dispatch(Action3());
    storeTester.dispatch(Action4());

    TestInfoList<AppState> infos =
        await storeTester.waitCondition((info) => info.state.text == "0,1,2", ignoreIni: false);
    expect(infos.length, 4);
    expect(infos.getIndex(0).state.text, "0");
    expect(infos.getIndex(0).ini, true);
    expect(infos.getIndex(1).state.text, "0,1");
    expect(infos.getIndex(1).ini, false);
    expect(infos.getIndex(2).state.text, "0,1");
    expect(infos.getIndex(2).ini, true);
    expect(infos.getIndex(3).state.text, "0,1,2");
    expect(infos.getIndex(3).ini, false);

    infos =
        await storeTester.waitCondition((info) => info.state.text == "0,1,2,3,4", ignoreIni: false);
    expect(infos.length, 4);
    expect(infos.getIndex(0).state.text, "0,1,2");
    expect(infos.getIndex(0).ini, true);
    expect(infos.getIndex(1).state.text, "0,1,2,3");
    expect(infos.getIndex(1).ini, false);
    expect(infos.getIndex(2).state.text, "0,1,2,3");
    expect(infos.getIndex(2).ini, true);
    expect(infos.getIndex(3).state.text, "0,1,2,3,4");
    expect(infos.getIndex(3).ini, false);
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      'Dispatch some action and wait for it. '
      'Get the end state.', () async {
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");

    storeTester.dispatch(Action1());
    TestInfo<AppState> info = await storeTester.wait(Action1);
    expect(info.state.text, "0,1");
    expect(info.errors, isEmpty);
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      'Dispatch some action and wait for a different one. '
      'Gets an error.', () async {
    var storeTester = createStoreTester();

    storeTester.dispatch(Action1());

    await storeTester.wait(Action2).then((_) => throw AssertionError(),
        onError: expectAsync1((Object error) {
      expect(error, TypeMatcher<StoreException>());
      expect(
          error.toString(),
          "Got this action: Action1 INI.\n"
          "Was expecting: Action2 INI.");
    }));
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      'Dispatch a few actions and wait for all of them, in order. '
      'Get the end state.', () async {
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");

    storeTester.dispatch(Action1());
    storeTester.dispatch(Action2());
    storeTester.dispatch(Action3());
    TestInfo<AppState> info = await storeTester.waitAllGetLast([Action1, Action2, Action3]);
    expect(info.state.text, "0,1,2,3");
    expect(info.errors, isEmpty);
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      'Dispatch a few actions and wait for all of them, in order. '
      'Get the end state.', () async {
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");

    // Action6 will dispatch actions 1, 2 and 3, and only then it will finish.
    storeTester.dispatch(Action6());

    TestInfo<AppState> info =
        await storeTester.waitAllGetLast([Action6, Action1, Action2, Action3]);
    expect(info.state.text, "0,1,2,3,6");
    expect(info.errors, isEmpty);
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      'Dispatch a few actions and wait for all of them, in order. '
      'Gets an error because they are not in order.', () async {
    var storeTester = createStoreTester();

    storeTester.dispatch(Action1());
    storeTester.dispatch(Action3());
    storeTester.dispatch(Action2());

    await storeTester.waitAllGetLast([Action1, Action2, Action3]).then(
        (_) => throw AssertionError(), onError: expectAsync1((Object error) {
      expect(error, TypeMatcher<StoreException>());
      expect(
          error.toString(),
          "Got this action: Action3 INI.\n"
          "Was expecting: Action2 INI.");
    }));
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      'Dispatch a few actions and wait for all of them, in order. '
      'Gets an error because a different one was dispacthed in the middle.', () async {
    var storeTester = createStoreTester();

    storeTester.dispatch(Action1());
    storeTester.dispatch(Action2());
    storeTester.dispatch(Action4());
    storeTester.dispatch(Action3());

    await storeTester.waitAllGetLast([Action1, Action2, Action3]).then(
        (_) => throw AssertionError(), onError: expectAsync1((Object error) {
      expect(error, TypeMatcher<StoreException>());
      expect(
          error.toString(),
          "Got this action: Action4 INI.\n"
          "Was expecting: Action3 INI.");
    }));
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      'Dispatch a few actions and wait until one of them is dispatched, '
      'ignoring the others.'
      'Get the end state after this action.', () async {
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");

    storeTester.dispatch(Action1());
    storeTester.dispatch(Action2());
    storeTester.dispatch(Action3());
    storeTester.dispatch(Action4());

    TestInfo<AppState> info = await storeTester.waitUntil(Action3);
    expect(info.state.text, "0,1,2,3");
    expect(info.errors, isEmpty);
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      'Wait until some action that is never dispatched.'
      'Should timeout.', () async {
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");

    storeTester.dispatch(Action1());
    storeTester.dispatch(Action2());
    storeTester.dispatch(Action4());

    await storeTester.waitUntil(Action3, timeoutInSeconds: 1).then((_) => throw AssertionError(),
        onError: expectAsync1((Object error) {
      expect(error, TypeMatcher<StoreException>());
      expect(error.toString(), "Timeout.");
    }));
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      'Dispatch a few actions and wait until one specific action instance is dispatched, '
      'ignoring the others.'
      'Get the end state after this action.', () async {
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");

    storeTester.dispatch(Action1());
    storeTester.dispatch(Action2());
    var action3 = Action3();
    storeTester.dispatch(action3);
    storeTester.dispatch(Action4());

    TestInfo<AppState> info = await storeTester.waitUntilAction(action3);
    expect(info.state.text, "0,1,2,3");
    expect(info.errors, isEmpty);
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      'Wait until some action that is never dispatched.'
      'Should timeout.', () async {
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");

    storeTester.dispatch(Action1());
    storeTester.dispatch(Action2());
    storeTester.dispatch(Action4());

    await storeTester
        .waitUntilAction(Action3(), timeoutInSeconds: 1)
        .then((_) => throw AssertionError(), onError: expectAsync1((Object error) {
      expect(error, TypeMatcher<StoreException>());
      expect(error.toString(), "Timeout.");
    }));
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      'Dispatch a few actions and wait for all of them, in ANY order. '
      'Get the end state.', () async {
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");

    storeTester.dispatch(Action1());
    storeTester.dispatch(Action2());
    storeTester.dispatch(Action3());
    TestInfo<AppState> info =
        await storeTester.waitAllUnorderedGetLast([Action3, Action1, Action2]);
    expect(info.state.text, "0,1,2,3");
    expect(info.errors, isEmpty);
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      'Dispatch a few actions and wait for all of them, in ANY order. '
      'Gets an error because there is a different one in the middle.', () async {
    var storeTester = createStoreTester();

    storeTester.dispatch(Action1());
    storeTester.dispatch(Action2());
    storeTester.dispatch(Action4());
    storeTester.dispatch(Action3());

    await storeTester.waitAllUnorderedGetLast([Action1, Action2, Action3]).then(
        (_) => throw AssertionError(), onError: expectAsync1((Object error) {
      expect(error, TypeMatcher<StoreException>());
      expect(error.toString(), "Unexpected action was dispatched: Action4 INI.");
    }));
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      'Dispatch a few actions and wait for all of them, in order. '
      'Get all of the intermediary states.', () async {
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");

    storeTester.dispatch(Action1());
    storeTester.dispatch(Action2());
    storeTester.dispatch(Action3());
    TestInfoList<AppState> infos = await storeTester.waitAll([Action1, Action2, Action3]);
    expect(infos.getIndex(0).state.text, "0,1");
    expect(infos.getIndex(1).state.text, "0,1,2");
    expect(infos.getIndex(2).state.text, "0,1,2,3");
    expect(infos.getIndex(0).errors, isEmpty);
    expect(infos.getIndex(1).errors, isEmpty);
    expect(infos.getIndex(2).errors, isEmpty);
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      'Dispatch a few actions and wait for all of them, in ANY order. '
      'Get all of the intermediary states.', () async {
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");

    storeTester.dispatch(Action1());
    storeTester.dispatch(Action2());
    storeTester.dispatch(Action2());
    storeTester.dispatch(Action3());
    TestInfoList<AppState> infos = await storeTester
        .waitAllUnordered([Action1, Action2, Action3, Action2], timeoutInSeconds: 1);

    // The states are indexed by order of dispatching
    // (doesn't matter the order we were expecting them).
    expect(infos.length, 4);
    expect(infos.getIndex(0).state.text, "0,1");
    expect(infos.getIndex(1).state.text, "0,1,2");
    expect(infos.getIndex(2).state.text, "0,1,2,2");
    expect(infos.getIndex(3).state.text, "0,1,2,2,3");
    expect(infos.getIndex(0).errors, isEmpty);
    expect(infos.getIndex(1).errors, isEmpty);
    expect(infos.getIndex(2).errors, isEmpty);
    expect(infos.getIndex(3).errors, isEmpty);

    // Can get first and last.
    expect(infos.first.state.text, "0,1");
    expect(infos.last.state.text, "0,1,2,2,3");

    // Number of infos.
    expect(infos.length, 4);
    expect(infos.isEmpty, false);
    expect(infos.isNotEmpty, true);

    // It's usually better to get them by type, not order.
    expect(infos[Action1].state.text, "0,1");
    expect(infos[Action2].state.text, "0,1,2");
    expect(infos[Action3].state.text, "0,1,2,2,3");

    // Operator [] is the same as get().
    expect(infos.get(Action1).state.text, "0,1");
    expect(infos.get(Action2).state.text, "0,1,2");
    expect(infos.get(Action3).state.text, "0,1,2,2,3");

    // But get is useful if some action is repeated, then you can get by type and repeating order.
    expect(infos.get(Action1, 1).state.text, "0,1");
    expect(infos.get(Action2, 1).state.text, "0,1,2");
    expect(infos.get(Action2, 2).state.text, "0,1,2,2");
    expect(infos.get(Action3, 1).state.text, "0,1,2,2,3");

    // If the action is not repeated to that order, return null;
    expect(infos.get(Action3, 2), isNull);
    expect(infos.get(Action3, 500), isNull);

    // Get repeated actions as list.
    List<TestInfo<AppState>> action2s = infos.getAll(Action2);
    expect(action2s.length, 2);
    expect(action2s[0].state.text, "0,1,2");
    expect(action2s[1].state.text, "0,1,2,2");
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      'Dispatch a few actions and wait for all of them, in ANY order. '
      'Ignore some actions. '
      'Get all of the intermediary states.', () async {
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");

    storeTester.dispatch(Action1());
    storeTester.dispatch(Action2());
    storeTester.dispatch(Action2());
    storeTester.dispatch(Action3());
    TestInfoList<AppState> infos = await storeTester.waitAllUnordered(
      [Action1, Action3],
      timeoutInSeconds: 1,
      ignore: [Action2],
    );

    // The states are indexed by order of dispatching
    // (doesn't matter the order we were expecting them).
    expect(infos.length, 2);
    expect(infos.getIndex(0).state.text, "0,1");
    expect(infos.getIndex(1).state.text, "0,1,2,2,3");
    expect(infos.getIndex(0).errors, isEmpty);
    expect(infos.getIndex(1).errors, isEmpty);
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      'Dispatch a few actions and wait for all of them, in order. '
      'Ignore some actions. '
      'Get the end state.', () async {
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");

    storeTester.dispatch(Action4());
    storeTester.dispatch(Action1());
    storeTester.dispatch(Action2());
    storeTester.dispatch(Action2());
    storeTester.dispatch(Action3());
    storeTester.dispatch(Action4());
    storeTester.dispatch(Action2());
    storeTester.dispatch(Action4());
    storeTester.dispatch(Action5());
    storeTester.dispatch(Action4());

    TestInfo<AppState> info = await storeTester.waitAllGetLast(
      [Action1, Action3, Action5],
      ignore: [Action2, Action4],
    );

    // All actions affect the state, even the ones ignored by the store-tester.
    // However, ignored action can run any number of times.
    expect(info.state.text, "0,4,1,2,2,3,4,2,4,5");
    expect(info.errors, isEmpty);
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      'Dispatch a few actions and wait for all of them, in order. '
      'Ignore some actions. '
      'Get all of the intermediary states.', () async {
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");

    storeTester.dispatch(Action4());
    storeTester.dispatch(Action1());
    storeTester.dispatch(Action2());
    storeTester.dispatch(Action2());
    storeTester.dispatch(Action3());
    storeTester.dispatch(Action4());
    storeTester.dispatch(Action2());
    storeTester.dispatch(Action4());
    storeTester.dispatch(Action5());
    storeTester.dispatch(Action4());

    TestInfoList<AppState> infos = await storeTester.waitAll(
      [Action1, Action3, Action5],
      ignore: [Action2, Action4],
    );

    // All actions affect the state, even the ones ignored by the store-tester.
    // However, ignored action can run any number of times.
    expect(infos.last.state.text, "0,4,1,2,2,3,4,2,4,5");
    expect(infos.last.errors, isEmpty);

    // Only 3 states were collected. The ignored action doesn't generate info.
    expect(infos.length, 3);
    expect(infos.getIndex(0).state.text, "0,4,1");
    expect(infos.getIndex(1).state.text, "0,4,1,2,2,3");
    expect(infos.getIndex(2).state.text, "0,4,1,2,2,3,4,2,4,5");
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      'Dispatch a few actions and wait for all of them, in order. '
      'Ignore some actions, including one which we are also waiting for it. '
      'Get all of the intermediary states.', () async {
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");

    storeTester.dispatch(Action1());

    // We are waiting for this Action2 (after Action1) which would otherwise be ignored.
    storeTester.dispatch(Action2());

    storeTester.dispatch(Action3());

    TestInfoList<AppState> infos = await storeTester.waitAll(
      [Action1, Action2, Action3],
      ignore: [Action2],
    );

    // All actions affect the state, even the ones ignored by the store-tester.
    // However, ignored action can run any number of times.
    expect(infos.last.state.text, "0,1,2,3");
    expect(infos.last.errors, isEmpty);

    // Only 3 states were collected. The ignored action doesn't generate info.
    expect(infos.length, 3);
    expect(infos.getIndex(0).state.text, "0,1");
    expect(infos.getIndex(1).state.text, "0,1,2");
    expect(infos.getIndex(2).state.text, "0,1,2,3");
  });

  ///////////////////////////////////////////////////////////////////////////////
  test(
      'Dispatch a few actions and wait for all of them, in order. '
      'Ignore some actions, including one which we are also waiting for it. '
      'Get all of the intermediary states.', () async {
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");

    storeTester.dispatch(Action4());
    storeTester.dispatch(Action1());
    storeTester.dispatch(Action2());
    storeTester.dispatch(Action2());
    storeTester.dispatch(Action3());

    // We are waiting for this Action4 (after Action3) which is otherwise ignored.
    storeTester.dispatch(Action4());

    storeTester.dispatch(Action2());
    storeTester.dispatch(Action4());
    storeTester.dispatch(Action5());
    storeTester.dispatch(Action4());

    TestInfoList<AppState> infos = await storeTester.waitAll(
      [Action1, Action3, Action4, Action5],
      ignore: [Action2, Action4],
    );

    // All actions affect the state, even the ones ignored by the store-tester.
    // However, ignored action can run any number of times.
    expect(infos.last.state.text, "0,4,1,2,2,3,4,2,4,5");
    expect(infos.last.errors, isEmpty);

    // Only 4 states were collected. The ignored action doesn't generate info.
    expect(infos.length, 4);
    expect(infos.getIndex(0).state.text, "0,4,1");
    expect(infos.getIndex(1).state.text, "0,4,1,2,2,3");
    expect(infos.getIndex(2).state.text, "0,4,1,2,2,3,4");
    expect(infos.getIndex(3).state.text, "0,4,1,2,2,3,4,2,4,5");
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      'Dispatch a few actions, some async that dispatch others, '
      'and wait for all of them, in order. '
      'Ignore some actions, including one which we are also waiting for it. '
      'Get all of the intermediary states.', () async {
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");

    // Action6 will dispatch actions 1, 2 and 3, and only then it will finish.
    storeTester.dispatch(Action6());

    TestInfoList<AppState> infos = await storeTester.waitAll(
      [Action6, Action1, Action2, Action3],
      ignore: [Action6],
    );

    // All actions affect the state, even the ones ignored by the store-tester.
    // However, ignored action can run any number of times.
    expect(infos.last.state.text, "0,1,2,3,6");
    expect(infos.last.errors, isEmpty);

    // Only 4 states were collected. The ignored action doesn't generate info.
    expect(infos.length, 4);
    expect(infos.getIndex(0).state.text, "0,1");
    expect(infos.getIndex(1).state.text, "0,1,2");
    expect(infos.getIndex(2).state.text, "0,1,2,3");
    expect(infos.getIndex(3).state.text, "0,1,2,3,6");
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      'Dispatch a more complex action sequence. '
      'Get all of the intermediary states.', () async {
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");

    // Action6 will dispatch actions 1, 2 and 3, and only then it will finish.
    storeTester.dispatch(Action7());

    TestInfoList<AppState> infos = await storeTester.waitAll(
      [Action7, Action4, Action6, Action1, Action2, Action3, Action5],
      ignore: [Action2],
    );

    // All actions affect the state, even the ones ignored by the store-tester.
    // However, ignored action can run any number of times.
    expect(infos.last.state.text, "0,4,1,2,3,6,2,5,7");
    expect(infos.last.errors, isEmpty);

    // Only 7 states were collected. The ignored action doesn't generate info.
    expect(infos.length, 7);
    expect(infos.getIndex(0).state.text, "0,4");
    expect(infos.getIndex(1).state.text, "0,4,1");
    expect(infos.getIndex(2).state.text, "0,4,1,2");
    expect(infos.getIndex(3).state.text, "0,4,1,2,3");
    expect(infos.getIndex(4).state.text, "0,4,1,2,3,6");
    expect(infos.getIndex(5).state.text, "0,4,1,2,3,6,2,5");
    expect(infos.getIndex(6).state.text, "0,4,1,2,3,6,2,5,7");
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      'Dispatch a more complex action sequence. '
      'One of the actions contains "await". '
      'Get all of the intermediary states.', () async {
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");

    // Action6b will dispatch actions 1, 2 and 3, and only then it will finish.
    storeTester.dispatch(Action7b());

    TestInfoList<AppState> infos = await storeTester.waitAll(
      [Action7b, Action4, Action6b, Action1, Action2, Action5, Action2, Action3],
    );

    // All actions affect the state, even the ones ignored by the store-tester.
    // However, ignored action can run any number of times.
    expect(infos.last.state.text, "0,4,1,2,5,7b,2,3,6b");
    expect(infos.last.errors, isEmpty);

    // All 8 states were collected.
    expect(infos.length, 8);
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      'Dispatch a more complex actions sequence. '
      'One of the actions contains "await". '
      'Ignore an action. '
      'Get all of the intermediary states.', () async {
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");

    // Action6b will dispatch actions 1, 2 and 3, and only then it will finish.
    storeTester.dispatch(Action7b());

    TestInfoList<AppState> infos = await storeTester.waitAll(
      [Action7b, Action4, Action6b, Action1, Action5, Action3],
      ignore: [Action2],
    );

    // All actions affect the state, even the ones ignored by the store-tester.
    // However, ignored action can run any number of times.
    expect(infos.last.state.text, "0,4,1,2,5,7b,2,3,6b");
    expect(infos.last.errors, isEmpty);

    // Only 6 states were collected. The ignored action doesn't generate info.
    expect(infos.length, 6);
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      'Dispatch a more complex actions sequence. '
      'An ignored action will finish after all others have started. '
      'Get all of the intermediary states.', () async {
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");

    // Action9 will dispatch Action2 after some delay.
    storeTester.dispatch(Action8());

    storeTester.dispatch(Action9());

    TestInfoList<AppState> infos = await storeTester.waitAll(
      [
        Action9,
        Action2,
      ],
      ignore: [Action8],
    );

    // All actions affect the state, even the ones ignored by the store-tester.
    // However, ignored action can run any number of times.
    expect(infos.last.state.text, "0,2,8,9");
    expect(infos.last.errors, isEmpty);

    // Only 2 states were collected. The ignored action doesn't generate info.
    expect(infos.length, 2);
    expect(infos.getIndex(0).state.text, "0,2");
    expect(infos.getIndex(1).state.text, "0,2,8,9");
  });

///////////////////////////////////////////////////////////////////////////////
}
