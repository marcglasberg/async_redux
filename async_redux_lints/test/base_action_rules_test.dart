import 'package:async_redux_lints/src/fixes/base_class_fixes.dart';
import 'package:async_redux_lints/src/rules/base_action_rules.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ExtendBaseActionTest);
    defineReflectiveTests(DependenciesCastInActionTest);
  });
}

@reflectiveTest
class ExtendBaseActionTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = ExtendBaseActionRule();
    super.setUp();
  }

  Future<void> test_testFiles() async {
    await assertNotReportedInTests('''$header
class LoadUser extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_extendsReduxAction() async {
    var code = '''$header
class LoadUser extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'ReduxAction<AppState> {',
        length: 21,
        messageContainsAll: [
          "The action 'LoadUser' extends 'ReduxAction<AppState>' directly, instead of "
              "a base action.",
        ],
        correctionContains:
            "Try extending your base action, or creating one, like 'abstract class "
            "AppAction extends ReduxAction<AppState> {}'.",
      ),
    ]);
  }

  Future<void> test_baseActionInTheLibrary() async {
    var code = '''$header
abstract class AppAction extends ReduxAction<AppState> {}

class LoadUser extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'ReduxAction<AppState> {', occurrence: 2, length: 21),
    ]);
  }

  Future<void> test_notReported() async {
    await assertNoDiagnostics('''$header
abstract class AppAction extends ReduxAction<AppState> {}

class LoadUser extends AppAction {
  @override
  AppState? reduce() => null;
}

class Generic<St> extends ReduxAction<St> {
  @override
  St? reduce() => null;
}

mixin MyMixin on ReduxAction<AppState> {}
''');
  }

  Future<void> test_classTypeAlias() async {
    var code = '''$header
mixin Reduce on ReduxAction<AppState> {
  @override
  AppState? reduce() => null;
}

class LoadUser = ReduxAction<AppState> with Reduce;
''';
    await assertDiagnostics(code, [
      lintAt(code, 'ReduxAction<AppState> with', length: 21),
    ]);
  }

  Future<void> test_fix_baseActionInTheLibrary() async {
    var code = '''$header
abstract class AppAction extends ReduxAction<AppState> {}

class LoadUser extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;
}
''';
    await assertFix(
      code,
      ({required context}) => UseBaseClass(0, context: context),
      code.replaceFirst(
        'LoadUser extends ReduxAction<AppState>',
        'LoadUser extends AppAction',
      ),
    );
  }

  Future<void> test_fix_baseActionNotImported() async {
    newFile('$testPackageLibPath/app_action.dart', '''
import 'package:async_redux/async_redux.dart';
import 'package:test/test.dart';
abstract class AppAction extends ReduxAction<AppState> {}
''');
    var code = '''$header
class LoadUser extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;
}
''';
    await assertFix(
      code,
      ({required context}) => UseBaseClass(0, context: context),
      code
          .replaceFirst(
            "import 'package:async_redux/async_redux.dart';",
            "import 'package:async_redux/async_redux.dart';\n"
                "import 'package:test/app_action.dart';",
          )
          .replaceFirst(
            'LoadUser extends ReduxAction<AppState>',
            'LoadUser extends AppAction',
          ),
    );
  }

  Future<void> test_fix_oneFixForEachBaseAction() async {
    var code = '''$header
abstract class AppAction extends ReduxAction<AppState> {}

abstract class LoadingAction extends ReduxAction<AppState> {}

abstract class OtherState extends ReduxAction<int> {}

abstract class _Private extends ReduxAction<AppState> {}

class LoadUser extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;
}
''';
    String extending(String base) => code.replaceFirst(
      'LoadUser extends ReduxAction<AppState>',
      'LoadUser extends $base',
    );
    var producers = [
      for (var i = 0; i < UseBaseClass.maxFixes; i++)
        ({required context}) => UseBaseClass(i, context: context),
    ];
    // The private class is in the same library, so it can be used.
    await assertFix(code, producers[0], extending('AppAction'));
    await assertFix(code, producers[1], extending('LoadingAction'));
    await assertFix(code, producers[2], extending('_Private'));
  }

  Future<void> test_fix_noBaseAction() async {
    await assertFix(
      '''$header
abstract class Generic<T> extends ReduxAction<AppState> {}

class LoadUser extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;
}
''',
      ({required context}) => UseBaseClass(0, context: context),
      null,
    );
  }
}

@reflectiveTest
class DependenciesCastInActionTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = DependenciesCastInActionRule();
    super.setUp();
  }

  static const _types = '''
class Dependencies {}
class Environment {}
class Config {}
''';

  Future<void> test_testFiles() async {
    await assertNotReportedInTests('''$header$_types
class LoadUser extends ReduxAction<AppState> {
  @override
  AppState? reduce() {
    print(store.dependencies as Dependencies);
    return null;
  }
}
''');
  }

  Future<void> test_castInAction() async {
    var code = '''$header$_types
class LoadUser extends ReduxAction<AppState> {
  @override
  AppState? reduce() {
    var dependencies = store.dependencies as Dependencies;
    var environment = (store.environment as Environment?)!;
    var config = this.store.configuration as Config;
    return null;
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'store.dependencies as Dependencies',
        messageContainsAll: [
          "Avoid casting 'store.dependencies' in the action 'LoadUser'.",
        ],
        correctionContains:
            "Try declaring 'Dependencies get dependencies => store.dependencies as "
            "Dependencies;' in your base action, and using 'dependencies' instead.",
      ),
      lintAt(code, 'store.environment as Environment?'),
      lintAt(
        code,
        'this.store.configuration as Config',
        correctionContains: "'Config get config => store.configuration as Config;'",
      ),
    ]);
  }

  Future<void> test_castInBaseAction_isNotReported() async {
    await assertNoDiagnostics('''$header$_types
abstract class AppAction extends ReduxAction<AppState> {
  Dependencies get dependencies => store.dependencies as Dependencies;
}

mixin MyMixin on ReduxAction<AppState> {
  Environment get environment => store.environment as Environment;
}

class Other {
  Object? get dependencies => null;
  Dependencies get typed => dependencies as Dependencies;
}

void f(Store<AppState> store) {
  print(store.configuration as Config);
}
''');
  }
}
