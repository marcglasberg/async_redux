import 'package:async_redux_lints/src/rules/power_feature_rules.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidAbortDispatchTest);
    defineReflectiveTests(AvoidWrapReduceTest);
  });
}

const _code = '''$header
abstract class AppAction extends ReduxAction<AppState> {
  @override
  bool abortDispatch() => false;

  @override
  Future<AppState?> wrapReduce(Reducer<AppState> reduce) async => reduce();
}

mixin M on ReduxAction<AppState> {
  @override
  bool abortDispatch() => false;

  @override
  Future<AppState?> wrapReduce(Reducer<AppState> reduce) async => reduce();
}

class A extends AppAction {
  @override
  bool abortDispatch() => true;

  @override
  Future<AppState?> wrapReduce(Reducer<AppState> reduce) async => reduce();

  @override
  AppState? reduce() => null;
}

class NotAnAction {
  bool abortDispatch() => false;
  Future<AppState?> wrapReduce(Reducer<AppState> reduce) async => reduce();
}
''';

@reflectiveTest
class AvoidAbortDispatchTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = AvoidAbortDispatchRule();
    super.setUp();
  }

  Future<void> test_overrides() async {
    await assertDiagnostics(_code, [
      lintAt(
        _code,
        'abortDispatch',
        messageContainsAll: ["Avoid overriding 'abortDispatch'."],
      ),
      lintAt(_code, 'abortDispatch', occurrence: 2),
      lintAt(_code, 'abortDispatch', occurrence: 3),
    ]);
  }

  Future<void> test_testFiles() async {
    await assertNotReportedInTests(_code);
  }
}

@reflectiveTest
class AvoidWrapReduceTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = AvoidWrapReduceRule();
    super.setUp();
  }

  Future<void> test_overrides() async {
    await assertDiagnostics(_code, [
      lintAt(_code, 'wrapReduce', messageContainsAll: ["Avoid overriding 'wrapReduce'."]),
      lintAt(_code, 'wrapReduce', occurrence: 2),
      lintAt(_code, 'wrapReduce', occurrence: 3),
    ]);
  }

  Future<void> test_testFiles() async {
    await assertNotReportedInTests(_code);
  }
}
