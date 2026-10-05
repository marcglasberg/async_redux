import 'package:async_redux_lints/src/rules/missing_super_in_mixin_override_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(MissingSuperInMixinOverrideTest);
  });
}

@reflectiveTest
class MissingSuperInMixinOverrideTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = MissingSuperInMixinOverrideRule();
    super.setUp();
  }

  Future<void> test_abortDispatch() async {
    var code = '''$header
class A extends ReduxAction<AppState> with NonReentrant {
  @override
  bool abortDispatch() => isWaiting(A);

  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'abortDispatch',
        messageContainsAll: [
          "This 'abortDispatch' overrides the one of the 'NonReentrant' mixin without "
              "calling 'super.abortDispatch', so the mixin doesn't work.",
        ],
        correctionContains: "if (super.abortDispatch()) return true;",
      ),
    ]);
  }

  Future<void> test_wrapReduce() async {
    var code = '''$header
class A extends ReduxAction<AppState> with Retry {
  @override
  Future<AppState?> wrapReduce(Reducer<AppState> reduce) async => reduce();

  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'wrapReduce', messageContainsAll: ["'Retry' mixin"]),
    ]);
  }

  Future<void> test_reduce() async {
    var code = '''$header
class A extends ReduxAction<AppState> with OptimisticCommand {
  @override
  Future<AppState?> reduce() async => null;
}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'reduce()', length: 6, messageContainsAll: ["'OptimisticCommand'"]),
    ]);
  }

  Future<void> test_mixinInBaseAction() async {
    var code = '''$header
abstract class AppAction extends ReduxAction<AppState> with NonReentrant {}

class A extends AppAction {
  @override
  bool abortDispatch() => false;

  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [lintAt(code, 'abortDispatch')]);
  }

  Future<void> test_userMixinOnAsyncReduxMixin() async {
    var code = '''$header
mixin M on NonReentrant<AppState> {
  @override
  bool abortDispatch() => false;
}
''';
    await assertDiagnostics(code, [lintAt(code, 'abortDispatch')]);
  }

  // ---------------------------------------------------------------------------
  // Valid.

  Future<void> test_callsSuper_isValid() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> with NonReentrant {
  @override
  bool abortDispatch() => super.abortDispatch() || isWaiting(A);

  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_wrapReduceCallsSuper_isValid() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> with Retry {
  @override
  Future<AppState?> wrapReduce(Reducer<AppState> reduce) =>
      super.wrapReduce(() => reduce());

  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_withoutMixin_isValid() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> {
  @override
  bool abortDispatch() => false;

  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_mixinDoesNotImplementMethod_isValid() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> with Retry {
  @override
  bool abortDispatch() => false;

  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_userMixin_isValid() async {
    await assertNoDiagnostics('''$header
mixin M on ReduxAction<AppState> {
  @override
  bool abortDispatch() => false;
}

class A extends ReduxAction<AppState> with M {
  @override
  bool abortDispatch() => true;

  @override
  AppState? reduce() => null;
}
''');
  }
}
