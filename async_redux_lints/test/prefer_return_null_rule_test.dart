import 'package:async_redux_lints/src/fixes/reducer_fixes.dart';
import 'package:async_redux_lints/src/rules/prefer_return_null_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(PreferReturnNullTest);
  });
}

@reflectiveTest
class PreferReturnNullTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = PreferReturnNullRule();
    super.setUp();
  }

  Future<void> test_syncReturnState() async {
    var code = '''$header
class A extends ReduxAction<AppState> {
  bool get flag => true;

  @override
  AppState? reduce() {
    if (flag) return state;
    return AppState();
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'state;',
        length: 5,
        messageContainsAll: ["The reducer returns 'state' unchanged."],
      ),
    ]);
  }

  Future<void> test_expressionBody() async {
    var code = '''$header
class A extends ReduxAction<AppState> {
  @override
  AppState? reduce() => state;
}
''';
    await assertDiagnostics(code, [lintAt(code, 'state;', length: 5)]);
  }

  Future<void> test_thisState() async {
    var code = '''$header
class A extends ReduxAction<AppState> {
  @override
  AppState? reduce() => this.state;
}
''';
    await assertDiagnostics(code, [lintAt(code, 'this.state')]);
  }

  Future<void> test_asyncReturnStateAfterAwait() async {
    var code = '''$header
class A extends ReduxAction<AppState> {
  @override
  Future<AppState?> reduce() async {
    await Future.value(1);
    return state;
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'state;', length: 5)]);
  }

  Future<void> test_inMixin() async {
    var code = '''$header
mixin M on ReduxAction<AppState> {
  @override
  AppState? reduce() => state;
}
''';
    await assertDiagnostics(code, [lintAt(code, 'state;', length: 5)]);
  }

  Future<void> test_returnNull_isValid() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_returnNewState_isValid() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> {
  bool get flag => true;

  @override
  AppState? reduce() => flag ? state : AppState();
}
''');
  }

  Future<void> test_returnInClosure_isValid() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> {
  @override
  AppState? reduce() {
    AppState f() {
      return state;
    }
    return f() == state ? null : AppState();
  }
}
''');
  }

  Future<void> test_otherMethod_isValid() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> {
  AppState current() => state;

  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_notAnAction_isValid() async {
    await assertNoDiagnostics('''$header
class A {
  AppState get state => AppState();
  AppState? reduce() => state;
}
''');
  }

  // ---------------------------------------------------------------------------
  // Fix.

  Future<void> test_fix_returnNull() async {
    await assertFix(
      '''$header
class A extends ReduxAction<AppState> {
  @override
  AppState? reduce() {
    return state;
  }
}
''',
      ReturnNull.new,
      '''$header
class A extends ReduxAction<AppState> {
  @override
  AppState? reduce() {
    return null;
  }
}
''',
    );
  }

  Future<void> test_fix_makesReturnTypeNullable() async {
    await assertFix(
      '''$header
class A extends ReduxAction<AppState> {
  @override
  AppState reduce() => state;
}
''',
      ReturnNull.new,
      '''$header
class A extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;
}
''',
    );
  }

  Future<void> test_fix_makesFutureTypeArgumentNullable() async {
    await assertFix(
      '''$header
class A extends ReduxAction<AppState> {
  @override
  Future<AppState> reduce() async {
    await Future.value(1);
    return this.state;
  }
}
''',
      ReturnNull.new,
      '''$header
class A extends ReduxAction<AppState> {
  @override
  Future<AppState?> reduce() async {
    await Future.value(1);
    return null;
  }
}
''',
    );
  }
}
