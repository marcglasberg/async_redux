import 'package:async_redux_lints/src/rules/internet_simulation_in_production_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(InternetSimulationInProductionTest);
  });
}

@reflectiveTest
class InternetSimulationInProductionTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = InternetSimulationInProductionRule();
    super.setUp();
  }

  Future<void> test_false() async {
    var code = '''$header
class A extends ReduxAction<AppState> with CheckInternet {
  @override
  bool? get internetOnOffSimulation => false;

  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'false;',
        length: 5,
        messageContainsAll: [
          "This 'internetOnOffSimulation' returns 'false', so the action ignores the "
              "real internet connection.",
        ],
      ),
    ]);
  }

  Future<void> test_blockBody() async {
    var code = '''$header
class A extends ReduxAction<AppState> with AbortWhenNoInternet {
  @override
  bool? get internetOnOffSimulation {
    return true;
  }

  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [lintAt(code, 'true;', length: 4)]);
  }

  Future<void> test_mixinInBaseAction() async {
    var code = '''$header
abstract class AppAction extends ReduxAction<AppState> with UnlimitedRetryCheckInternet {}

class A extends AppAction {
  @override
  bool? get internetOnOffSimulation => true;

  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [lintAt(code, 'true;', length: 4)]);
  }

  // ---------------------------------------------------------------------------
  // Valid.

  Future<void> test_null_isValid() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> with CheckInternet {
  @override
  bool? get internetOnOffSimulation => null;

  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_notLiteral_isValid() async {
    await assertNoDiagnostics('''$header
bool? simulation;

class A extends ReduxAction<AppState> with CheckInternet {
  @override
  bool? get internetOnOffSimulation => simulation;

  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_withoutInternetMixin_isValid() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> {
  bool? get internetOnOffSimulation => false;

  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_inTestDirectory_isValid() async {
    var path = '$testPackageTestPath/a_test.dart';
    newFile(path, '''$header
class A extends ReduxAction<AppState> with CheckInternet {
  @override
  bool? get internetOnOffSimulation => false;

  @override
  AppState? reduce() => null;
}
''');
    await assertNoDiagnosticsInFile(path);
  }
}
