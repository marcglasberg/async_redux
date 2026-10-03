import 'package:async_redux_lints/src/rules/return_type_rules.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ReduceReturnTypeTest);
    defineReflectiveTests(BeforeReturnTypeTest);
    defineReflectiveTests(WrapReduceReturnTypeTest);
  });
}

@reflectiveTest
class ReduceReturnTypeTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = ReduceReturnTypeRule();
    super.setUp();
  }

  Future<void> test_valid_types() async {
    await assertNoDiagnostics('''$header
class A1 extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;
}

class A2 extends ReduxAction<AppState> {
  @override
  AppState reduce() => state;
}

class A3 extends ReduxAction<AppState> {
  @override
  Future<AppState?> reduce() async => null;
}

class A4 extends ReduxAction<AppState> {
  @override
  Future<AppState> reduce() async => state;
}

mixin M<St> on ReduxAction<St> {
  @override
  Future<St?> reduce() async => null;
}
''');
  }

  Future<void> test_futureOr() async {
    var code = '''$header
class A extends ReduxAction<AppState> {
  @override
  FutureOr<AppState?> reduce() => null;
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'FutureOr<AppState?>',
        messageContainsAll: [
          "must return 'AppState?' or 'Future<AppState?>', not 'FutureOr<AppState?>'",
        ],
      ),
    ]);
  }

  Future<void> test_nullableFuture() async {
    var code = '''$header
class A extends ReduxAction<AppState> {
  @override
  Future<AppState?>? reduce() async => null;
}
''';
    await assertDiagnostics(code, [lintAt(code, 'Future<AppState?>?')]);
  }

  Future<void> test_missingReturnType_isInferredAsFutureOr() async {
    var code = '''$header
class A extends ReduxAction<AppState> {
  @override
  reduce() async => null;
}
''';
    await assertDiagnostics(code, [lintAt(code, 'reduce', occurrence: 1)]);
  }

  Future<void> test_indirectSubclass() async {
    var code = '''$header
abstract class AppAction extends ReduxAction<AppState> {}

class A extends AppAction {
  @override
  FutureOr<AppState?> reduce() => null;
}
''';
    await assertDiagnostics(code, [lintAt(code, 'FutureOr<AppState?>')]);
  }

  Future<void> test_mixinOnReduxAction() async {
    var code = '''$header
mixin M<St> on ReduxAction<St> {
  @override
  FutureOr<St?> reduce() => null;
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'FutureOr<St?>',
        messageContainsAll: ["must return 'St?' or 'Future<St?>'"],
      ),
    ]);
  }

  Future<void> test_abstractDeclaration_isIgnored() async {
    await assertNoDiagnostics('''$header
abstract class AppAction extends ReduxAction<AppState> {
  @override
  FutureOr<AppState?> reduce();
}
''');
  }

  Future<void> test_notAnAction_isIgnored() async {
    await assertNoDiagnostics('''$header
class NotAnAction {
  FutureOr<AppState?> reduce() => null;
}
''');
  }
}

@reflectiveTest
class BeforeReturnTypeTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = BeforeReturnTypeRule();
    super.setUp();
  }

  Future<void> test_valid_types() async {
    await assertNoDiagnostics('''$header
class A1 extends ReduxAction<AppState> {
  @override
  void before() {}
  @override
  AppState? reduce() => null;
}

class A2 extends ReduxAction<AppState> {
  @override
  Future<void> before() async {}
  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_futureOr() async {
    var code = '''$header
class A extends ReduxAction<AppState> {
  @override
  FutureOr<void> before() {}
  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'FutureOr<void>',
        messageContainsAll: [
          "must return 'void' or 'Future<void>', not 'FutureOr<void>'",
        ],
      ),
    ]);
  }

  Future<void> test_missingReturnType_isInferredAsFutureOr() async {
    var code = '''$header
class A extends ReduxAction<AppState> {
  @override
  before() async {}
  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [lintAt(code, 'before')]);
  }
}

@reflectiveTest
class WrapReduceReturnTypeTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = WrapReduceReturnTypeRule();
    super.setUp();
  }

  Future<void> test_valid_type() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> {
  @override
  Future<AppState?> wrapReduce(Reducer<AppState> reduce) async => reduce();
  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_sync_throws() async {
    var code = '''$header
class A extends ReduxAction<AppState> {
  @override
  AppState? wrapReduce(Reducer<AppState> reduce) => null;
  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'AppState?',
        messageContainsAll: [
          "must return 'Future<AppState?>', not 'AppState?'",
          'throws a StoreException',
        ],
      ),
    ]);
  }

  Future<void> test_futureOr_isNeverCalled() async {
    var code = '''$header
class A extends ReduxAction<AppState> {
  @override
  FutureOr<AppState?> wrapReduce(Reducer<AppState> reduce) => reduce();
  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'FutureOr<AppState?>', messageContainsAll: ['never calls it']),
    ]);
  }
}
