import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

@immutable
class AppState {
  final String text;

  AppState(this.text);

  AppState.add(AppState state, String text) : text = state.text + "," + text;
}

class Action1 extends ReduxAction<AppState> {
  @override
  AppState reduce() => AppState.add(state, "1");
}

class Action2 extends ReduxAction<AppState> {
  @override
  AppState reduce() => AppState.add(state, "2");
}

class Action3 extends ReduxAction<AppState> {
  @override
  AppState reduce() => AppState.add(state, "3");
}

class Action3b extends ReduxAction<AppState> {
  @override
  AppState reduce() {
    dispatch(Action4());
    return AppState.add(state, "3b");
  }
}

class Action4 extends ReduxAction<AppState> {
  @override
  AppState reduce() => AppState.add(state, "4");
}

class Action5 extends ReduxAction<AppState> {
  @override
  AppState reduce() => AppState.add(state, "5");
}

class Action6 extends ReduxAction<AppState> {
  @override
  AppState reduce() {
    dispatch(Action1());
    dispatch(Action2());
    dispatch(Action3());
    return AppState.add(state, "6");
  }
}

class Action6b extends ReduxAction<AppState> {
  @override
  Future<AppState> reduce() async {
    dispatch(Action1());
    await Future.delayed(const Duration(milliseconds: 10));
    dispatch(Action2());
    dispatch(Action3());
    return AppState.add(state, "6b");
  }
}

class Action6c extends ReduxAction<AppState> {
  @override
  AppState reduce() {
    dispatch(Action1());
    dispatch(Action2());
    dispatch(Action3b());
    return AppState.add(state, "6c");
  }
}

class Action7 extends ReduxAction<AppState> {
  @override
  Future<AppState> reduce() async {
    dispatch(Action4());
    dispatch(Action6());
    dispatch(Action2());
    dispatch(Action5());
    return AppState.add(state, "7");
  }
}

class Action7b extends ReduxAction<AppState> {
  @override
  Future<AppState> reduce() async {
    dispatch(Action4());
    dispatch(Action6b());
    dispatch(Action2());
    dispatch(Action5());
    return AppState.add(state, "7b");
  }
}

class Action8 extends ReduxAction<AppState> {
  @override
  Future<AppState> reduce() async {
    await Future.delayed(const Duration(milliseconds: 50));
    dispatch(Action2());
    return AppState.add(state, "8");
  }
}

class Action9 extends ReduxAction<AppState> {
  @override
  Future<AppState> reduce() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return AppState.add(state, "9");
  }
}

class Action10a extends ReduxAction<AppState> {
  @override
  Future<AppState> reduce() async {
    dispatch(Action1());
    dispatch(Action2());
    dispatch(Action11a());
    dispatch(Action3());
    return AppState.add(state, "10");
  }
}

class Action10b extends ReduxAction<AppState> {
  @override
  Future<AppState> reduce() async {
    dispatch(Action1());
    dispatch(Action2());
    dispatch(Action11b());
    dispatch(Action3());
    return AppState.add(state, "10");
  }
}

class Action11a extends ReduxAction<AppState> {
  @override
  AppState reduce() {
    throw const UserException("Hello!");
  }
}

class Action11b extends ReduxAction<AppState> {
  @override
  Future<AppState> reduce() async {
    throw const UserException("Hello!");
  }
}

class Action12 extends ReduxAction<AppState> {
  @override
  AppState reduce() {
    dispatch(Action13());
    return AppState.add(state, "12");
  }
}

class Action13 extends ReduxAction<AppState> {
  @override
  Future<AppState> reduce() async {
    await Future.delayed(const Duration(milliseconds: 1));
    return AppState.add(state, "13");
  }
}

void main() {
  StoreTester<AppState> createStoreTester() {
    var store = Store<AppState>(initialState: AppState("0"));
    return StoreTester.from(store);
  }

  /////////////////////////////////////////////////////////////////////////////

  test('Dispatch multiple actions but only issue a single change event.', () async {
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");

    int invocations = 0;

    storeTester.store.onChange.listen((event) {
      invocations += 1;
    });

    await storeTester.dispatch(Action1());
    await storeTester.dispatch(Action2());
    await storeTester.dispatch(Action3());
    await storeTester.dispatch(Action4());

    expect(invocations, 4);
    expect(storeTester.state.text, "0,1,2,3,4");

    storeTester = createStoreTester();
    expect(storeTester.state.text, "0");

    invocations = 0;

    storeTester.store.onChange.listen((event) {
      invocations += 1;
    });

    await storeTester.dispatch(Action1(), notify: false);
    await storeTester.dispatch(Action2(), notify: false);
    await storeTester.dispatch(Action3(), notify: false);
    await storeTester.dispatch(Action4(), notify: true);

    expect(invocations, 1);
    expect(storeTester.state.text, "0,1,2,3,4");
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

    var condition = (TestInfo<AppState?>? info) => info!.state!.text == "0,1,2";
    TestInfo<AppState?> info1 = await (storeTester.waitConditionGetLast(condition));
    expect(info1.state!.text, "0,1,2");
    expect(info1.ini, false);

    TestInfo<AppState?> info2 =
        await (storeTester.waitConditionGetLast((info) => info.state.text == "0,1,2,3,4"));
    expect(info2.state!.text, "0,1,2,3,4");
    expect(info2.ini, false);
  });

  /////////////////////////////////////////////////////////////////////////////

  test(
      'Dispatch some actions and wait until some condition is met. '
      'Get the end state.', () async {
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");

    storeTester.dispatch(Action1());
    storeTester.dispatch(Action2());
    storeTester.dispatch(Action3());
    storeTester.dispatch(Action4());

    var condition = (TestInfo<AppState?>? info) => info!.state!.text == "0,1,2" && info.ini;
    TestInfo<AppState?> info1 =
        await (storeTester.waitConditionGetLast(condition, ignoreIni: false));
    expect(info1.state!.text, "0,1,2");
    expect(info1.ini, true);

    TestInfo<AppState?> info2 = await (storeTester.waitConditionGetLast(
        (info) => info.state.text == "0,1,2,3,4" && !info.ini,
        ignoreIni: false));
    expect(info2.state!.text, "0,1,2,3,4");
    expect(info2.ini, false);
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

    TestInfoList<AppState?> infos =
        await storeTester.waitCondition((info) => info.state.text == "0,1,2");

    expect(infos.length, 2);
    expect(infos.getIndex(0).state!.text, "0,1");
    expect(infos.getIndex(0).ini, false);
    expect(infos.getIndex(1).state!.text, "0,1,2");
    expect(infos.getIndex(1).ini, false);

    infos = await storeTester.waitCondition((info) => info.state.text == "0,1,2,3,4");
    expect(infos.length, 2);
    expect(infos.getIndex(0).state!.text, "0,1,2,3");
    expect(infos.getIndex(0).ini, false);
    expect(infos.getIndex(1).state!.text, "0,1,2,3,4");
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

    TestInfoList<AppState?> infos =
        await storeTester.waitCondition((info) => info.state.text == "0,1,2", ignoreIni: false);
    expect(infos.length, 4);
    expect(infos.getIndex(0).state!.text, "0");
    expect(infos.getIndex(0).ini, true);
    expect(infos.getIndex(1).state!.text, "0,1");
    expect(infos.getIndex(1).ini, false);
    expect(infos.getIndex(2).state!.text, "0,1");
    expect(infos.getIndex(2).ini, true);
    expect(infos.getIndex(3).state!.text, "0,1,2");
    expect(infos.getIndex(3).ini, false);

    infos =
        await storeTester.waitCondition((info) => info.state.text == "0,1,2,3,4", ignoreIni: false);
    expect(infos.length, 4);
    expect(infos.getIndex(0).state!.text, "0,1,2");
    expect(infos.getIndex(0).ini, true);
    expect(infos.getIndex(1).state!.text, "0,1,2,3");
    expect(infos.getIndex(1).ini, false);
    expect(infos.getIndex(2).state!.text, "0,1,2,3");
    expect(infos.getIndex(2).ini, true);
    expect(infos.getIndex(3).state!.text, "0,1,2,3,4");
    expect(infos.getIndex(3).ini, false);
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      'Dispatch some action and wait for it. '
      'Get the end state.', () async {
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");

    storeTester.dispatch(Action1());
    TestInfo<AppState?> info = await (storeTester.wait(Action1));
    expect(info.state!.text, "0,1");
    expect(info.errors, isEmpty);
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      'Dispatch some action and wait for a different one. '
      'Gets an error.', () async {
    var storeTester = createStoreTester();

    storeTester.dispatch(Action1());

    // await storeTester.wait(Action2);

    await storeTester.wait(Action2).then(
      (_) {
        throw AssertionError();
        return null; // ignore: dead_code
      },
      onError: expectAsync1(
        (Object error) {
          expect(error, const TypeMatcher<StoreException>());
          expect(
              error.toString(),
              'Got this unexpected action: Action1 INI.\n'
              'Was expecting: Action2 INI.\n'
              'obtainedIni: [Action1]\n'
              'ignoredIni: []');
        },
      ),
    );
  });

  /////////////////////////////////////////////////////////////////////////////

  test(
      'Dispatch a few actions and wait for all of them, in order. '
      'Get the end state.', () async {
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");

    storeTester.dispatch(Action1());
    storeTester.dispatch(Action2());
    storeTester.dispatch(Action3());
    TestInfo<AppState?> info = await (storeTester.waitAllGetLast([Action1, Action2, Action3]));
    expect(info.state!.text, "0,1,2,3");
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

    TestInfo<AppState?> info =
        await (storeTester.waitAllGetLast([Action6, Action1, Action2, Action3]));
    expect(info.state!.text, "0,1,2,3,6");
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

    await storeTester.waitAllGetLast([Action1, Action2, Action3]).then((_) {
      throw AssertionError();
      return null; // ignore: dead_code
    }, onError: expectAsync1((Object error) {
      expect(error, const TypeMatcher<StoreException>());
      expect(
          error.toString(),
          'Got this unexpected action: Action3 INI.\n'
          'Was expecting: Action2 INI.\n'
          'obtainedIni: [Action1, Action3]\n'
          'ignoredIni: []');
    }));
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      'Dispatch a few actions and wait for all of them, in order. '
      'Gets an error because a different one was dispatched in the middle.', () async {
    var storeTester = createStoreTester();

    storeTester.dispatch(Action1());
    storeTester.dispatch(Action2());
    storeTester.dispatch(Action4());
    storeTester.dispatch(Action3());

    await storeTester.waitAllGetLast([Action1, Action2, Action3]).then((_) {
      throw AssertionError();
      return null; // ignore: dead_code
    }, onError: expectAsync1((Object error) {
      expect(error, const TypeMatcher<StoreException>());
      expect(
          error.toString(),
          'Got this unexpected action: Action4 INI.\n'
          'Was expecting: Action3 INI.\n'
          'obtainedIni: [Action1, Action2, Action4]\n'
          'ignoredIni: []');
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

    TestInfo<AppState?> info = await storeTester.waitUntil(Action3);
    expect(info.state!.text, "0,1,2,3");
    expect(info.errors, isEmpty);
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      'Dispatch a few actions and wait until all of them finish, '
      'ignoring the others.'
      'Get the end state after all actions finish.', () async {
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");

    storeTester.dispatch(Action1());
    storeTester.dispatch(Action2());
    storeTester.dispatch(Action1());
    storeTester.dispatch(Action3());
    storeTester.dispatch(Action4());

    TestInfo<AppState?> info = await storeTester.waitUntilAllGetLast([Action3, Action2]);
    expect(info.state!.text, "0,1,2,1,3");
    expect(info.errors, isEmpty);
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      'Dispatch a few actions and wait until all of them finish, '
      'ignoring the others.'
      'Get all states until all actions finish.', () async {
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");

    storeTester.dispatch(Action1());
    storeTester.dispatch(Action2());
    storeTester.dispatch(Action1());
    storeTester.dispatch(Action3());
    storeTester.dispatch(Action4());

    TestInfoList<AppState?> infos = await storeTester.waitUntilAll([Action3, Action2]);

    expect(infos.length, 4);
    expect(infos.getIndex(0).state!.text, "0,1");
    expect(infos.getIndex(1).state!.text, "0,1,2");
    expect(infos.getIndex(2).state!.text, "0,1,2,1");
    expect(infos.getIndex(3).state!.text, "0,1,2,1,3");
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

    await storeTester.waitUntil(Action3, timeoutInSeconds: 1).then((_) {
      throw AssertionError();
      return null; // ignore: dead_code
    }, onError: expectAsync1((Object error) {
      expect(error, const TypeMatcher<StoreException>());
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

    TestInfo<AppState?> info = await storeTester.waitUntilAction(action3);
    expect(info.state!.text, "0,1,2,3");
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

    await storeTester.waitUntilAction(Action3(), timeoutInSeconds: 1).then((_) {
      throw AssertionError();
      return null; // ignore: dead_code
    }, onError: expectAsync1((Object error) {
      expect(error, const TypeMatcher<StoreException>());
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
    TestInfo<AppState?> info =
        await (storeTester.waitAllUnorderedGetLast([Action3, Action1, Action2]));
    expect(info.state!.text, "0,1,2,3");
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

    await storeTester.waitAllUnorderedGetLast([Action1, Action2, Action3]).then((_) {
      throw AssertionError();
      return null; // ignore: dead_code
    }, onError: expectAsync1((Object error) {
      expect(error, const TypeMatcher<StoreException>());
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
    TestInfoList<AppState?> infos = await storeTester.waitAll([Action1, Action2, Action3]);
    expect(infos.getIndex(0).state!.text, "0,1");
    expect(infos.getIndex(1).state!.text, "0,1,2");
    expect(infos.getIndex(2).state!.text, "0,1,2,3");
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
    TestInfoList<AppState?> infos = await storeTester
        .waitAllUnordered([Action1, Action2, Action3, Action2], timeoutInSeconds: 1);

    // The states are indexed by order of dispatching
    // (doesn't matter the order we were expecting them).
    expect(infos.length, 4);
    expect(infos.getIndex(0).state!.text, "0,1");
    expect(infos.getIndex(1).state!.text, "0,1,2");
    expect(infos.getIndex(2).state!.text, "0,1,2,2");
    expect(infos.getIndex(3).state!.text, "0,1,2,2,3");
    expect(infos.getIndex(0).errors, isEmpty);
    expect(infos.getIndex(1).errors, isEmpty);
    expect(infos.getIndex(2).errors, isEmpty);
    expect(infos.getIndex(3).errors, isEmpty);

    // Can get first and last.
    expect(infos.first.state!.text, "0,1");
    expect(infos.last.state!.text, "0,1,2,2,3");

    // Number of infos.
    expect(infos.length, 4);
    expect(infos.isEmpty, false);
    expect(infos.isNotEmpty, true);

    // It's usually better to get them by type, not order.
    expect(infos[Action1]!.state!.text, "0,1");
    expect(infos[Action2]!.state!.text, "0,1,2");
    expect(infos[Action3]!.state!.text, "0,1,2,2,3");

    // Operator [] is the same as get().
    expect(infos.get(Action1)!.state!.text, "0,1");
    expect(infos.get(Action2)!.state!.text, "0,1,2");
    expect(infos.get(Action3)!.state!.text, "0,1,2,2,3");

    // But get is useful if some action is repeated, then you can get by type and repeating order.
    expect(infos.get(Action1, 1)!.state!.text, "0,1");
    expect(infos.get(Action2, 1)!.state!.text, "0,1,2");
    expect(infos.get(Action2, 2)!.state!.text, "0,1,2,2");
    expect(infos.get(Action3, 1)!.state!.text, "0,1,2,2,3");

    // If the action is not repeated to that order, return null;
    expect(infos.get(Action3, 2), isNull);
    expect(infos.get(Action3, 500), isNull);

    // Get repeated actions as list.
    List<TestInfo<AppState?>?> action2s = infos.getAll(Action2);
    expect(action2s.length, 2);
    expect(action2s[0]!.state!.text, "0,1,2");
    expect(action2s[1]!.state!.text, "0,1,2,2");
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
    TestInfoList<AppState?> infos = await storeTester.waitAllUnordered(
      [Action1, Action3],
      timeoutInSeconds: 1,
      ignore: [Action2],
    );

    // The states are indexed by order of dispatching
    // (doesn't matter the order we were expecting them).
    expect(infos.length, 2);
    expect(infos.getIndex(0).state!.text, "0,1");
    expect(infos.getIndex(1).state!.text, "0,1,2,2,3");
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

    TestInfo<AppState?> info = await (storeTester.waitAllGetLast(
      [Action1, Action3, Action5],
      ignore: [Action2, Action4],
    ));

    // All actions affect the state, even the ones ignored by the store-tester.
    // However, ignored action can run any number of times.
    expect(info.state!.text, "0,4,1,2,2,3,4,2,4,5");
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

    TestInfoList<AppState?> infos = await storeTester.waitAll(
      [Action1, Action3, Action5],
      ignore: [Action2, Action4],
    );

    // All actions affect the state, even the ones ignored by the store-tester.
    // However, ignored action can run any number of times.
    expect(infos.last.state!.text, "0,4,1,2,2,3,4,2,4,5");
    expect(infos.last.errors, isEmpty);

    // Only 3 states were collected. The ignored action doesn't generate info.
    expect(infos.length, 3);
    expect(infos.getIndex(0).state!.text, "0,4,1");
    expect(infos.getIndex(1).state!.text, "0,4,1,2,2,3");
    expect(infos.getIndex(2).state!.text, "0,4,1,2,2,3,4,2,4,5");
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

    TestInfoList<AppState?> infos = await storeTester.waitAll(
      [Action1, Action2, Action3],
      ignore: [Action2],
    );

    // All actions affect the state, even the ones ignored by the store-tester.
    // However, ignored action can run any number of times.
    expect(infos.last.state!.text, "0,1,2,3");
    expect(infos.last.errors, isEmpty);

    // Only 3 states were collected. The ignored action doesn't generate info.
    expect(infos.length, 3);
    expect(infos.getIndex(0).state!.text, "0,1");
    expect(infos.getIndex(1).state!.text, "0,1,2");
    expect(infos.getIndex(2).state!.text, "0,1,2,3");
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

    TestInfoList<AppState?> infos = await storeTester.waitAll(
      [Action1, Action3, Action4, Action5],
      ignore: [Action2, Action4],
    );

    // All actions affect the state, even the ones ignored by the store-tester.
    // However, ignored action can run any number of times.
    expect(infos.last.state!.text, "0,4,1,2,2,3,4,2,4,5");
    expect(infos.last.errors, isEmpty);

    // Only 4 states were collected. The ignored action doesn't generate info.
    expect(infos.length, 4);
    expect(infos.getIndex(0).state!.text, "0,4,1");
    expect(infos.getIndex(1).state!.text, "0,4,1,2,2,3");
    expect(infos.getIndex(2).state!.text, "0,4,1,2,2,3,4");
    expect(infos.getIndex(3).state!.text, "0,4,1,2,2,3,4,2,4,5");
  });

  /////////////////////////////////////////////////////////////////////////////

  test(
      'Dispatch a few actions, some async that dispatch others, '
      'and wait for all of them, in order. '
      'Ignore some actions, including one which we are also waiting for it. '
      'Get all of the intermediary states.', () async {
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");

    // Action6 will dispatch actions 1, 2 and 3, and only then it will finish.
    storeTester.dispatch(Action6());

    TestInfoList<AppState?> infos = await storeTester.waitAll(
      [Action6, Action1, Action2, Action3],
      ignore: [Action6],
    );

    // All actions affect the state, even the ones ignored by the store-tester.
    // However, ignored action can run any number of times.
    expect(infos.last.state!.text, "0,1,2,3,6");
    expect(infos.last.errors, isEmpty);

    // Only 4 states were collected. The ignored action doesn't generate info.
    expect(infos.length, 4);
    expect(infos.getIndex(0).state!.text, "0,1");
    expect(infos.getIndex(1).state!.text, "0,1,2");
    expect(infos.getIndex(2).state!.text, "0,1,2,3");
    expect(infos.getIndex(3).state!.text, "0,1,2,3,6");
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      'Dispatch a more complex action sequence. '
      'Get all of the intermediary states.', () async {
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");

    // Action6 will dispatch actions 1, 2 and 3, and only then it will finish.
    storeTester.dispatch(Action7());

    TestInfoList<AppState?> infos = await storeTester.waitAll(
      [Action7, Action4, Action6, Action1, Action2, Action3, Action5],
      ignore: [Action2],
    );

    // All actions affect the state, even the ones ignored by the store-tester.
    // However, ignored action can run any number of times.
    expect(infos.last.state!.text, "0,4,1,2,3,6,2,5,7");
    expect(infos.last.errors, isEmpty);

    // Only 7 states were collected. The ignored action doesn't generate info.
    expect(infos.length, 7);
    expect(infos.getIndex(0).state!.text, "0,4");
    expect(infos.getIndex(1).state!.text, "0,4,1");
    expect(infos.getIndex(2).state!.text, "0,4,1,2");
    expect(infos.getIndex(3).state!.text, "0,4,1,2,3");
    expect(infos.getIndex(4).state!.text, "0,4,1,2,3,6");
    expect(infos.getIndex(5).state!.text, "0,4,1,2,3,6,2,5");
    expect(infos.getIndex(6).state!.text, "0,4,1,2,3,6,2,5,7");
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

    TestInfoList<AppState?> infos = await storeTester.waitAll(
      [Action7b, Action4, Action6b, Action2, Action5, Action1, Action2, Action3],
    );

    // All actions affect the state, even the ones ignored by the store-tester.
    // However, ignored action can run any number of times.
    expect(infos.last.state!.text, "0,4,2,5,7b,2,3,6b");
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

    TestInfoList<AppState?> infos = await storeTester.waitAll(
      [Action7b, Action4, Action6b, Action2, Action5, Action1, Action3],
      ignore: [Action2],
    );

    // All actions affect the state, even the ones ignored by the store-tester.
    // However, ignored action can run any number of times.
    expect(infos.last.state!.text, "0,4,2,5,7b,2,3,6b");
    expect(infos.last.errors, isEmpty);

    // Only 7 states were collected. The ignored action doesn't generate info.
    expect(infos.length, 7);
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

    TestInfoList<AppState?> infos = await storeTester.waitAll(
      [
        Action9,
        Action2,
      ],
      ignore: [Action8],
    );

    // All actions affect the state, even the ones ignored by the store-tester.
    // However, ignored action can run any number of times.
    expect(infos.last.state!.text, "0,2,8,9");
    expect(infos.last.errors, isEmpty);

    // Only 2 states were collected. The ignored action doesn't generate info.
    expect(infos.length, 2);
    expect(infos.getIndex(0).state!.text, "0,2");
    expect(infos.getIndex(1).state!.text, "0,2,8,9");
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      'An ignored action starts after the last expected actions starts, '
      'but before this last expected action finishes.', () async {
    //
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");
    storeTester.dispatch(Action9());
    storeTester.dispatch(Action1());
    storeTester.dispatch(Action9());
    storeTester.dispatch(Action1());

    TestInfoList<AppState?> infos = await storeTester.waitAll(
      [
        Action9,
        Action9,
      ],
      ignore: [Action1],
    );

    expect(infos.last.state!.text, "0,1,1,9,9");
    expect(infos.last.errors, isEmpty);
    expect(infos.length, 2);
    expect(infos.getIndex(0).state!.text, "0,1,1,9");
    expect(infos.getIndex(1).state!.text, "0,1,1,9,9");
  });

  ///////////////////////////////////////////////////////////////////////////////

  // TODO: THIS ONE IS FAILING. FIX!!!
  test("Wait for a sync action that dispatches an async action which is ignored.", () async {
    var storeTester = createStoreTester();

    storeTester.dispatch(Action12());
    storeTester.dispatch(Action12());

    var infos = await storeTester.waitAll(
      [
        Action12,
        Action12,
      ],
      ignore: [Action13],
    );

    expect(infos.getIndex(0).state.text, "0,12");
    expect(infos.getIndex(1).state.text, "0,12,12");
  });

  ///////////////////////////////////////////////////////////////////////////////

  test('Makes sure we wait until the END of all ignored actions.', () async {
    //
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");
    storeTester.dispatch(Action6());

    expect(() async => await storeTester.waitAllGetLast([Action1, Action2], ignore: [Action6]),
        throwsA(anything));
  });

  ///////////////////////////////////////////////////////////////////////////

  test('Makes sure we wait until the END of all ignored actions.', () async {
    //
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");
    storeTester.dispatch(Action6());
    TestInfo<AppState?> info = await (storeTester.waitAllGetLast(
      [
        Action1,
        Action2,
        Action3,
      ],
      ignore: [Action6],
    ));
    expect(info.state!.text, "0,1,2,3");
    expect(info.errors, isEmpty);

    storeTester.dispatch(Action6());
    info = await (storeTester.waitAllGetLast([
      Action6,
      Action1,
      Action2,
      Action3,
    ]));

    expect(info.state!.text, "0,1,2,3,6,1,2,3,6");
  });

  ///////////////////////////////////////////////////////////////////////////////

  test('Makes sure we wait until the END of all ignored actions.', () async {
    //
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");
    storeTester.dispatch(Action6());
    TestInfo<AppState?> info = await (storeTester.waitAllUnorderedGetLast(
      [
        Action1,
        Action2,
        Action3,
      ],
      ignore: [Action6],
    ));
    expect(info.state!.text, "0,1,2,3");
    expect(info.errors, isEmpty);

    storeTester.dispatch(Action6());
    info = await (storeTester.waitAllGetLast([
      Action6,
      Action1,
      Action2,
      Action3,
    ]));
    expect(info.state!.text, "0,1,2,3,6,1,2,3,6");
  });

  /////////////////////////////////////////////////////////////////////////////

  test('Makes sure we wait until the END of all ignored actions.', () async {
    //
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");
    storeTester.dispatch(Action6());
    TestInfo<AppState?> info = await (storeTester.waitAllUnorderedGetLast(
      [
        Action1,
        Action2,
      ],
      ignore: [Action3, Action6],
    ));
    expect(info.state!.text, "0,1,2");
    expect(info.errors, isEmpty);

    // Now waits Action4 just to make sure Action3 hasn't leaked.
    storeTester.dispatch(Action4());
    info = await (storeTester.waitAllGetLast(
      [Action4],
    ));
    expect(info.state!.text, "0,1,2,3,6,4");
    expect(info.errors, isEmpty);
  });

  ///////////////////////////////////////////////////////////////////////////////

  test('Makes sure we wait until the END of all ignored actions.', () async {
    //
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");
    storeTester.dispatch(Action6c());

    expect(
        () async => await storeTester
            .waitAllUnorderedGetLast([Action1, Action2], ignore: [Action3b, Action6c]),
        throwsA(StoreException("Got this unexpected action: Action4 INI.")));
  });

  /////////////////////////////////////////////////////////////////////////////

  test('Error message when time is out.', () async {
    //
    var storeTester = createStoreTester();
    await storeTester.waitAllUnordered([Action1], timeoutInSeconds: 1).then((_) {
      fail('There was no timeout.');
      return null; // ignore: dead_code
    }, onError: expectAsync1((dynamic error) {
      expect(error, StoreExceptionTimeout());
    }));
  });

  // ///////////////////////////////////////////////////////////////////////////////

  test(
      'An action dispatches other actions, and one of them throws an error. '
      'Wait until that action finishes, '
      'and check the error.', () async {
    var storeTester = createStoreTester();

    runZonedGuarded(() {
      storeTester.dispatch(Action10a());
    }, (error, stackTrace) {
      expect(error, const UserException("Hello!"));
    });

    TestInfo<AppState?> info = await storeTester.waitUntil(Action11a);
    expect(info.error, const UserException("Hello!"));
    expect(info.processedError, null);
    expect(info.state!.text, "0,1,2");
    expect(info.ini, false);
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      'An action dispatches other actions, and one of them throws an error. '
      'Wait until that action finishes, '
      'and check the error.', () async {
    var storeTester = createStoreTester();

    runZonedGuarded(() {
      storeTester.dispatch(Action10b());
    }, (error, stackTrace) {
      expect(error, const UserException("Hello!"));
    });

    TestInfo<AppState?> info = await storeTester.waitUntil(Action11b);
    expect(info.error, const UserException("Hello!"));
    expect(info.processedError, null);
    expect(info.state!.text, "0,1,2,3,10");
    expect(info.ini, false);
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      'An action dispatches other actions, and one of them '
      '(a sync one) throws an error. '
      'Wait until the error TYPE is thrown, '
      'and check the error.', () async {
    var storeTester = createStoreTester();

    runZonedGuarded(() {
      storeTester.dispatch(Action10a());
    }, (error, stackTrace) {});

    TestInfo<AppState?> info = await (storeTester.waitUntilErrorGetLast(
      error: UserException,
      timeoutInSeconds: 1,
    ));

    expect(info.error, const UserException("Hello!"));
    expect(info.processedError, null);
    expect(info.state!.text, "0,1,2");
    expect(info.ini, false);
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      'An action dispatches other actions, and one of them '
      '(an async one) throws an error. '
      'Wait until the error (compare using equals) is thrown, '
      'and check the error.', () async {
    var storeTester = createStoreTester();

    runZonedGuarded(() {
      storeTester.dispatch(Action10a());
    }, (error, stackTrace) {});

    TestInfo<AppState?> info = await (storeTester.waitUntilErrorGetLast(
      error: const UserException("Hello!"),
      timeoutInSeconds: 1,
    ));

    expect(info.error, const UserException("Hello!"));
    expect(info.processedError, null);
    expect(info.state!.text, "0,1,2");
    expect(info.ini, false);
  });

  ///////////////////////////////////////////////////////////////////////////////

  test('The lastInfo can be accessed through StoreTester.lastInfo.', () async {
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");

    storeTester.dispatch(Action1());
    storeTester.dispatch(Action2());
    storeTester.dispatch(Action3());
    storeTester.dispatch(Action4());

    var condition = (TestInfo<AppState?>? info) => info!.state!.text == "0,1,2";
    await storeTester.waitConditionGetLast(condition);

    // Same as expect(info1.state.text, "0,1,2");
    expect(storeTester.lastInfo.state.text, "0,1,2");

    // Same as expect(info1.ini, false);
    expect(storeTester.lastInfo.ini, false);

    await storeTester.waitConditionGetLast((info) => info.state.text == "0,1,2,3,4");

    // Same as expect(info2.state.text, "0,1,2,3,4");
    expect(storeTester.lastInfo.state.text, "0,1,2,3,4");

    // Same as expect(info1.ini, false);
    expect(storeTester.lastInfo.ini, false);
  });

  ///////////////////////////////////////////////////////////////////////////////

  test('Wait condition with testImmediately true/false.', () async {
    // ---

    // 1) If testImmediately=false, it should timeout, because it will wait until an Action
    // is dispatched, and after that it's not "0" anymore.
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");
    storeTester.dispatch(Action1());
    storeTester.dispatch(Action2());
    storeTester.dispatch(Action3());
    storeTester.dispatch(Action4());

    await storeTester
        .waitConditionGetLast((info) => info.state.text == "0",
            testImmediately: false, timeoutInSeconds: 1)
        .then((_) {
      throw AssertionError();
      return null; // ignore: dead_code
    }, onError: expectAsync1((Object error) {
      expect(error, const TypeMatcher<StoreException>());
      expect(error.toString(), "Timeout.");
    }));

    expect(storeTester.state.text, "0,1,2,3,4");

    // ---

    // 2) If testImmediately=true, it should work, because it will test before any Action
    // is dispatched, and that's already "0".
    storeTester = createStoreTester();
    expect(storeTester.state.text, "0");
    storeTester.dispatch(Action1());
    storeTester.dispatch(Action2());
    storeTester.dispatch(Action3());
    storeTester.dispatch(Action4());

    TestInfo<AppState?> info = await (storeTester
        .waitConditionGetLast((info) => info.state.text == "0", timeoutInSeconds: 1));

    expect(info.state!.text, "0");
    expect(storeTester.state.text, "0,1,2,3,4");

    // ---

    // 3) Let's see if the current testInfo is kept.
    info = await (storeTester.waitConditionGetLast((info) => info.state.text == "0,1,2,3,4",
        timeoutInSeconds: 1));

    expect(info.state!.text, "0,1,2,3,4");
    expect(storeTester.state.text, "0,1,2,3,4");

    // ---

    // 4) Let's see if the current testInfo is kept.
    storeTester.dispatch(Action5());

    info = await (storeTester.waitConditionGetLast((info) => info.state.text == "0,1,2,3,4",
        timeoutInSeconds: 1));

    expect(info.state!.text, "0,1,2,3,4");
    expect(storeTester.state.text, "0,1,2,3,4,5");
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      "Wait condition with testImmediately true "
      "should not see the action of previous test-infos.", () async {
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");

    storeTester.dispatch(Action1());

    TestInfoList<AppState?> infos = await storeTester.waitCondition(
      (info) => info.state.text == "0,1",
      testImmediately: true,
    );

    expect(infos[Action1]!.action, isA<Action1>());
    expect(storeTester.currentTestInfo.action, isA<Action1>());

    infos = await storeTester.waitCondition(
      (info) {
        if (info.action is Action1) throw AssertionError();
        return true;
      },
      testImmediately: true,
    );
  });

  ///////////////////////////////////////////////////////////////////////////////

  test(
      "Wait condition with testImmediately true "
      "should not see the action of previous test-infos (a more realistic test).", () async {
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");

    storeTester.dispatch(Action1());

    TestInfoList<AppState?> infos = await storeTester.waitCondition(
      (info) => info.state.text == "0,1",
      testImmediately: true,
    );

    expect(infos, hasLength(1));
    expect(infos[Action1]!.state!.text, "0,1");
    expect(storeTester.currentTestInfo.action, isA<Action1>());
    expect(storeTester.currentTestInfo.state.text, "0,1");

    storeTester.dispatch(Action2());
    storeTester.dispatch(Action1());

    bool hasDispatchedAction1 = false;

    infos = await storeTester.waitCondition(
      (info) {
        if (info.action is Action1) hasDispatchedAction1 = true;
        return hasDispatchedAction1 && info.state.text.contains(",2");
      },
      testImmediately: true,
    );

    expect(infos, hasLength(2));
    expect(infos[Action2]!.state!.text, "0,1,2");
    expect(infos[Action1]!.state!.text, "0,1,2,1");
  });

  ///////////////////////////////////////////////////////////////////////////////

  test('Two simultaneous store testers will receive the same state changes.', () async {
    var storeTester1 = createStoreTester();
    var storeTester2 = StoreTester.from(storeTester1.store);

    expect(storeTester1.state.text, "0");
    expect(storeTester2.state.text, "0");

    storeTester1.dispatch(Action1());
    storeTester1.dispatch(Action2());
    storeTester1.dispatch(Action3());
    storeTester1.dispatch(Action4());

    TestInfo<AppState?> info1 = await (storeTester1
        .waitConditionGetLast((info) => info.state.text == "0,1,2,3", timeoutInSeconds: 1));

    TestInfo<AppState?> info2 = await (storeTester2
        .waitConditionGetLast((info) => info.state.text == "0,1", timeoutInSeconds: 1));

    expect(info1.state!.text, "0,1,2,3");
    expect(info2.state!.text, "0,1");
    expect(storeTester1.state.text, "0,1,2,3,4");
    expect(storeTester2.state.text, "0,1,2,3,4");
  });

  ///////////////////////////////////////////////////////////////////////////////

  test('StoreTester.dispatchState.', () async {
    var storeTester = createStoreTester();
    expect(storeTester.state.text, "0");

    storeTester.dispatch(Action1());
    storeTester.dispatch(Action2());

    // Remove state "1" from the stream, but not state "2".
    await storeTester.waitUntil(Action1);
    expect(storeTester.lastInfo.state.text, "0,1");
    expect(storeTester.state.text, "0,1,2");

    // When we dispatchState, it empties the stream.
    // This means state "2" will be removed.
    await storeTester.dispatchState(AppState("my state"));
    expect(storeTester.lastInfo.state.text, "my state");
    expect(storeTester.state.text, "my state");
    storeTester.dispatch(Action3());
    expect(storeTester.state.text, "my state,3");
    expect(storeTester.lastInfo.state.text, "my state");

    await storeTester.waitUntil(Action3);
    expect(storeTester.lastInfo.state.text, "my state,3");
    expect(storeTester.state.text, "my state,3");
  });

  ///////////////////////////////////////////////////////////////////////////////
}
