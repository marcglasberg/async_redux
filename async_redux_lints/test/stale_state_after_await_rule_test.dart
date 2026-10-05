import 'package:async_redux_lints/src/fixes/reducer_fixes.dart';
import 'package:async_redux_lints/src/rules/stale_state_after_await_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(StaleStateAfterAwaitTest);
  });
}

/// Wraps [body] in an async `reduce` of an action, after some helpers.
String action(String body) =>
    '''$header
class AppState {
  final int count;
  AppState(this.count);
  AppState copy({int? count}) => AppState(count ?? this.count);
}

Future<int> load([int? id]) async => 1;
bool get flag => true;
Stream<int> get stream => throw 0;

class A extends ReduxAction<AppState> {
  @override
  Future<AppState?> reduce() async {
$body
  }
}
'''
        .replaceFirst('class AppState {}\n', '');

@reflectiveTest
class StaleStateAfterAwaitTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = StaleStateAfterAwaitRule();
    super.setUp();
  }

  Future<void> test_returnAfterAwait() async {
    var code = action('''
    var s = state;
    var count = await load();
    return s.copy(count: count);''');
    await assertDiagnostics(code, [
      lintAt(
        code,
        's.copy',
        length: 1,
        messageContainsAll: [
          "The variable 's' was set to 'state' before an 'await', so it may not have "
              "the current state.",
        ],
      ),
    ]);
  }

  Future<void> test_initialState() async {
    var code = action('''
    final s = initialState;
    await load();
    return s.copy(count: 1);''');
    await assertDiagnostics(code, [
      lintAt(code, 's.copy', length: 1, messageContainsAll: ["set to 'initialState'"]),
    ]);
  }

  Future<void> test_thisState() async {
    var code = action('''
    var s = this.state;
    await load();
    return s.copy(count: 1);''');
    await assertDiagnostics(code, [lintAt(code, 's.copy', length: 1)]);
  }

  Future<void> test_usedInArgument() async {
    var code = action('''
    var s = state;
    await load();
    return state.copy(count: s.count + 1);''');
    await assertDiagnostics(code, [lintAt(code, 's.count + 1', length: 1)]);
  }

  Future<void> test_throughAnotherVariable() async {
    var code = action('''
    var s = state;
    await load();
    var newState = s.copy(count: 1);
    return newState;''');
    await assertDiagnostics(code, [lintAt(code, 's.copy', length: 1)]);
  }

  Future<void> test_awaitInIfBeforeReturn() async {
    var code = action('''
    var s = state;
    if (flag) await load();
    return s.copy(count: 1);''');
    await assertDiagnostics(code, [lintAt(code, 's.copy', length: 1)]);
  }

  Future<void> test_awaitInCondition() async {
    var code = action('''
    var s = state;
    if (await load() == 1) return s.copy(count: 1);
    return null;''');
    await assertDiagnostics(code, [lintAt(code, 's.copy', length: 1)]);
  }

  Future<void> test_awaitFor() async {
    var code = action('''
    var s = state;
    await for (var count in stream) {
      return s.copy(count: count);
    }
    return null;''');
    await assertDiagnostics(code, [lintAt(code, 's.copy', length: 1)]);
  }

  Future<void> test_twoUses() async {
    var code = action('''
    var s = state;
    await load();
    return s.copy(count: s.count + 1);''');
    await assertDiagnostics(code, [
      lintAt(code, 's.copy', length: 1),
      lintAt(code, 's.count + 1', length: 1),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Valid.

  Future<void> test_stateReadAgainAfterAwait_isValid() async {
    await assertNoDiagnostics(
      action('''
    await load();
    var s = state;
    return s.copy(count: 1);'''),
    );
  }

  Future<void> test_useBeforeAwait_isValid() async {
    await assertNoDiagnostics(
      action('''
    var s = state;
    if (s.count == 0) return s.copy(count: 1);
    await load();
    return state.copy(count: 2);'''),
    );
  }

  Future<void> test_usedOnlyInCondition_isValid() async {
    await assertNoDiagnostics(
      action('''
    var s = state;
    await load();
    if (s.count == state.count) return null;
    return state.copy(count: 1);'''),
    );
  }

  Future<void> test_usedInsideAwait_isValid() async {
    await assertNoDiagnostics(
      action('''
    var s = state;
    await load();
    return state.copy(count: await load(s.count));'''),
    );
  }

  Future<void> test_evaluatedBeforeAwait_isValid() async {
    // `s` is evaluated before the `await`, like `state` would be.
    await assertNoDiagnostics(
      action('''
    var s = state;
    return s.copy(count: await load());'''),
    );
  }

  Future<void> test_awaitInOtherBranch_isValid() async {
    await assertNoDiagnostics(
      action('''
    var s = state;
    if (flag) {
      await load();
      return null;
    } else {
      return s.copy(count: 1);
    }'''),
    );
  }

  Future<void> test_reassigned_isValid() async {
    await assertNoDiagnostics(
      action('''
    var s = state;
    await load();
    s = state;
    return s.copy(count: 1);'''),
    );
  }

  Future<void> test_awaitInClosure_isValid() async {
    await assertNoDiagnostics(
      action('''
    var s = state;
    Future<void> f() async => await load();
    f();
    return s.copy(count: 1);'''),
    );
  }

  Future<void> test_partOfState_isValid() async {
    await assertNoDiagnostics(
      action('''
    var count = state.count;
    await load();
    return state.copy(count: count + 1);'''),
    );
  }

  Future<void> test_syncReduce_isValid() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> {
  @override
  AppState? reduce() {
    var s = state;
    return s;
  }
}
''');
  }

  // ---------------------------------------------------------------------------
  // Fix.

  Future<void> test_fix_useState() async {
    await assertFix(
      action('''
    var s = state;
    await load();
    return s.copy(count: s.count);'''),
      UseCurrentState.new,
      action('''
    var s = state;
    await load();
    return state.copy(count: s.count);'''),
    );
  }

  Future<void> test_fix_stateIsHidden() async {
    await assertFix(
      action('''
    var s = this.state;
    await load();
    var state = s.copy(count: 1);
    return state;'''),
      UseCurrentState.new,
      action('''
    var s = this.state;
    await load();
    var state = this.state.copy(count: 1);
    return state;'''),
    );
  }
}
