import 'package:async_redux_lints/src/rules/after_throws_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AfterThrowsTest);
  });
}

/// The header, with some exception classes.
const errorsHeader = '''$header
class BaseError {}
class MyError extends BaseError {}
class OtherError {}
''';

/// Wraps [body] in the `after` method of an action.
String action(String body) =>
    '''$errorsHeader
bool get flag => true;
void save() {}
void run(void Function() function) {}

class A extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;

  @override
  void after() {
$body
  }
}
''';

@reflectiveTest
class AfterThrowsTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = AfterThrowsRule();
    super.setUp();
  }

  Future<void> test_throw() async {
    var code = action('''
    if (flag) throw MyError();''');
    await assertDiagnostics(code, [
      lintAt(
        code,
        "throw MyError()",
        messageContainsAll: ["The 'after' method must not throw."],
      ),
    ]);
  }

  Future<void> test_expressionBody() async {
    var code = '''$errorsHeader
class A extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;

  @override
  void after() => throw MyError();
}
''';
    await assertDiagnostics(code, [lintAt(code, "throw MyError()")]);
  }

  Future<void> test_inMixin() async {
    var code = '''$errorsHeader
mixin M on ReduxAction<AppState> {
  @override
  void after() {
    throw MyError();
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, "throw MyError()")]);
  }

  Future<void> test_inCatch() async {
    var code = action('''
    try {
      save();
    } catch (e) {
      throw MyError();
    }''');
    await assertDiagnostics(code, [lintAt(code, "throw MyError()")]);
  }

  Future<void> test_rethrow() async {
    var code = action('''
    try {
      save();
    } catch (e) {
      rethrow;
    }''');
    await assertDiagnostics(code, [lintAt(code, 'rethrow')]);
  }

  Future<void> test_tryWithoutCatch() async {
    var code = action('''
    try {
      throw MyError();
    } finally {
      save();
    }''');
    await assertDiagnostics(code, [lintAt(code, "throw MyError()")]);
  }

  Future<void> test_catchOfUnrelatedType() async {
    var code = action('''
    try {
      throw MyError();
    } on OtherError {
      save();
    }''');
    await assertDiagnostics(code, [lintAt(code, "throw MyError()")]);
  }

  // ---------------------------------------------------------------------------
  // Valid.

  Future<void> test_caught_isValid() async {
    await assertNoDiagnostics(
      action('''
    try {
      throw MyError();
    } catch (e) {
      save();
    }'''),
    );
  }

  Future<void> test_caughtByType_isValid() async {
    await assertNoDiagnostics(
      action('''
    try {
      throw MyError();
    } on BaseError {
      save();
    }'''),
    );
  }

  Future<void> test_rethrowCaughtByOuterTry_isValid() async {
    await assertNoDiagnostics(
      action('''
    try {
      try {
        save();
      } catch (e) {
        rethrow;
      }
    } catch (e) {
      save();
    }'''),
    );
  }

  Future<void> test_inClosure_isValid() async {
    await assertNoDiagnostics(
      action('''
    run(() => throw MyError());'''),
    );
  }

  Future<void> test_inReduce_isValid() async {
    await assertNoDiagnostics('''$errorsHeader
class A extends ReduxAction<AppState> {
  @override
  AppState? reduce() => throw MyError();
}
''');
  }

  Future<void> test_notAnAction_isValid() async {
    await assertNoDiagnostics('''$errorsHeader
class A {
  void after() => throw MyError();
}
''');
  }
}
