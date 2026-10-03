import 'package:async_redux_lints/src/rules/reduce_without_await_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ReduceWithoutAwaitTest);
  });
}

/// Wraps [body] in an async `reduce` of an action, after some helpers.
String action(String body) =>
    '''$header
enum Color { red, green }

Future<int> load() async => 1;
bool get flag => true;
String? get maybe => null;
List<int> get items => [];
Stream<int> get stream => throw 0;

class A extends ReduxAction<AppState> {
  @override
  Future<AppState?> reduce() async {
$body
  }
}
''';

@reflectiveTest
class ReduceWithoutAwaitTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = ReduceWithoutAwaitRule();
    super.setUp();
  }

  // ---------------------------------------------------------------------------
  // Valid.

  Future<void> test_awaitBeforeReturn() async {
    await assertNoDiagnostics(
      action('''
    await load();
    return state;'''),
    );
  }

  Future<void> test_awaitMicrotask() async {
    await assertNoDiagnostics(
      action('''
    await Future.microtask(() {});
    return state;'''),
    );
  }

  Future<void> test_returnNull_withoutAwait() async {
    await assertNoDiagnostics(
      action('''
    if (flag) return null;
    await load();
    return state;'''),
    );
  }

  Future<void> test_returnAwait() async {
    await assertNoDiagnostics(
      action('''
    return await Future.value(state);'''),
    );
  }

  Future<void> test_awaitInBothBranches() async {
    await assertNoDiagnostics(
      action('''
    if (flag) {
      await load();
    } else {
      await load();
    }
    return state;'''),
    );
  }

  Future<void> test_awaitInBothConditionalBranches() async {
    await assertNoDiagnostics(
      action('''
    flag ? await load() : await load();
    return state;'''),
    );
  }

  Future<void> test_throwPath() async {
    await assertNoDiagnostics(
      action('''
    if (!flag) throw Exception();
    await load();
    return state;'''),
    );
  }

  Future<void> test_awaitInCondition() async {
    await assertNoDiagnostics(
      action('''
    if (await load() == 1) return state;
    return state;'''),
    );
  }

  Future<void> test_awaitFor() async {
    await assertNoDiagnostics(
      action('''
    await for (var _ in stream) {
      return state;
    }
    return state;'''),
    );
  }

  Future<void> test_doWhileBodyAwaits() async {
    await assertNoDiagnostics(
      action('''
    do {
      await load();
    } while (flag);
    return state;'''),
    );
  }

  Future<void> test_exhaustiveSwitch_allCasesAwait() async {
    await assertNoDiagnostics(
      action('''
    switch (Color.red) {
      case Color.red:
        await load();
      case Color.green:
        await load();
    }
    return state;'''),
    );
  }

  Future<void> test_tryAndCatchAwait() async {
    await assertNoDiagnostics(
      action('''
    try {
      await load();
    } catch (_) {
      await load();
    }
    return state;'''),
    );
  }

  Future<void> test_returnInClosure_isIgnored() async {
    await assertNoDiagnostics(
      action('''
    var f = () {
      return state;
    };
    f();
    await load();
    return state;'''),
    );
  }

  Future<void> test_syncReduce_isIgnored() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> {
  @override
  AppState? reduce() => state;
}
''');
  }

  Future<void> test_notAnAction_isIgnored() async {
    await assertNoDiagnostics('''$header
class NotAnAction {
  Future<int?> reduce() async => 1;
}
''');
  }

  // ---------------------------------------------------------------------------
  // Invalid.

  Future<void> test_noAwait() async {
    var code = action('''
    return state;''');
    await assertDiagnostics(code, [lintAt(code, 'return state;')]);
  }

  Future<void> test_expressionBody() async {
    var code = '''$header
class A extends ReduxAction<AppState> {
  @override
  Future<AppState?> reduce() async => state;
}
''';
    await assertDiagnostics(code, [lint(code.indexOf('=> state;') + 3, 5)]);
  }

  Future<void> test_earlyReturnBeforeAwait() async {
    var code = action('''
    if (flag) return state;
    await load();
    return state;''');
    await assertDiagnostics(code, [lintAt(code, 'return state;')]);
  }

  Future<void> test_returnFutureWithoutAwait() async {
    var code = action('''
    return Future.value(state);''');
    await assertDiagnostics(code, [lintAt(code, 'return Future.value(state);')]);
  }

  Future<void> test_awaitOnlyInOneBranch() async {
    var code = action('''
    if (flag) await load();
    return state;''');
    await assertDiagnostics(code, [lintAt(code, 'return state;')]);
  }

  Future<void> test_awaitInForLoop() async {
    var code = action('''
    for (var _ in items) {
      await load();
    }
    return state;''');
    await assertDiagnostics(code, [lintAt(code, 'return state;')]);
  }

  Future<void> test_awaitInWhileLoop() async {
    var code = action('''
    while (flag) {
      await load();
    }
    return state;''');
    await assertDiagnostics(code, [lintAt(code, 'return state;')]);
  }

  Future<void> test_awaitOnRightOfAnd() async {
    var code = action('''
    if (flag && await load() == 1) {}
    return state;''');
    await assertDiagnostics(code, [lintAt(code, 'return state;')]);
  }

  Future<void> test_awaitInNullAwareCallArgument() async {
    var code = action('''
    maybe?.substring(await load());
    return state;''');
    await assertDiagnostics(code, [lintAt(code, 'return state;')]);
  }

  Future<void> test_catchWithoutAwait() async {
    var code = action('''
    try {
      await load();
    } catch (_) {}
    return state;''');
    await assertDiagnostics(code, [lintAt(code, 'return state;')]);
  }

  Future<void> test_nonExhaustiveSwitch() async {
    var code = action('''
    switch (1) {
      case 1:
        await load();
      case 2:
        await load();
    }
    return state;''');
    await assertDiagnostics(code, [lintAt(code, 'return state;')]);
  }

  Future<void> test_continueBeforeAwaitInDoWhile() async {
    var code = action('''
    do {
      if (flag) continue;
      await load();
    } while (flag);
    return state;''');
    await assertDiagnostics(code, [lintAt(code, 'return state;')]);
  }

  Future<void> test_breakBeforeAwait() async {
    var code = action('''
    outer:
    {
      if (flag) break outer;
      await load();
    }
    return state;''');
    await assertDiagnostics(code, [lintAt(code, 'return state;')]);
  }

  Future<void> test_mixin() async {
    var code = '''$header
mixin M on ReduxAction<AppState> {
  @override
  Future<AppState?> reduce() async {
    return state;
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'return state;')]);
  }
}
