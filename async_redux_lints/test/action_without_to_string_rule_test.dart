import 'package:async_redux_lints/src/fixes/to_string_fixes.dart';
import 'package:async_redux_lints/src/rules/action_without_to_string_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ActionWithoutToStringTest);
  });
}

@reflectiveTest
class ActionWithoutToStringTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = ActionWithoutToStringRule();
    super.setUp();
  }

  Future<void> test_actionWithFields() async {
    var code = '''$header
class LoadUser extends ReduxAction<AppState> {
  final int id;
  LoadUser(this.id);

  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'LoadUser extends',
        length: 8,
        messageContainsAll: [
          "The action 'LoadUser' has fields, but doesn't override 'toString()'.",
        ],
      ),
    ]);
  }

  Future<void> test_testFiles() async {
    await assertNotReportedInTests('''$header
class LoadUser extends ReduxAction<AppState> {
  final int id;
  LoadUser(this.id);

  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_inheritedFieldsFromBaseAction() async {
    var code = '''$header
abstract class LoadAction extends ReduxAction<AppState> {
  final int id;
  LoadAction(this.id);
}

class LoadUser extends LoadAction {
  LoadUser(super.id);

  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [lintAt(code, 'LoadUser extends', length: 8)]);
  }

  Future<void> test_withoutFields_isValid() async {
    await assertNoDiagnostics('''$header
class Increment extends ReduxAction<AppState> {
  static const step = 1;
  int get amount => step;

  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_overridesToString_isValid() async {
    await assertNoDiagnostics('''$header
class LoadUser extends ReduxAction<AppState> {
  final int id;
  LoadUser(this.id);

  @override
  AppState? reduce() => null;

  @override
  String toString() => '\${super.toString()}(\$id)';
}
''');
  }

  Future<void> test_baseActionOverridesToString_isValid() async {
    await assertNoDiagnostics('''$header
abstract class AppAction extends ReduxAction<AppState> {
  @override
  String toString() => runtimeType.toString();
}

class LoadUser extends AppAction {
  final int id;
  LoadUser(this.id);

  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_abstractAction_isValid() async {
    await assertNoDiagnostics('''$header
abstract class LoadAction extends ReduxAction<AppState> {
  final int id;
  LoadAction(this.id);
}
''');
  }

  Future<void> test_notAnAction_isValid() async {
    await assertNoDiagnostics('''$header
class User {
  final int id;
  User(this.id);
}
''');
  }

  Future<void> test_fix() async {
    await assertFix(
      '''$header
class LoadUser extends ReduxAction<AppState> {
  final int id;
  final String _name;
  LoadUser(this.id, this._name);

  @override
  AppState? reduce() => null;
}
''',
      AddActionToString.new,
      '''$header
class LoadUser extends ReduxAction<AppState> {
  final int id;
  final String _name;
  LoadUser(this.id, this._name);

  @override
  AppState? reduce() => null;

  @override
  String toString() => '\${super.toString()}(id: \$id, _name: \$_name)';
}
''',
    );
  }

  Future<void> test_fix_inheritedFieldsAndLongLine() async {
    await assertFix(
      '''$header
abstract class LoadAction extends ReduxAction<AppState> {
  final int id;
  LoadAction(this.id);
}

class LoadUserWithLongName extends LoadAction {
  final String firstName;
  final String lastName;
  LoadUserWithLongName(super.id, this.firstName, this.lastName);

  @override
  AppState? reduce() => null;
}
''',
      AddActionToString.new,
      '''$header
abstract class LoadAction extends ReduxAction<AppState> {
  final int id;
  LoadAction(this.id);
}

class LoadUserWithLongName extends LoadAction {
  final String firstName;
  final String lastName;
  LoadUserWithLongName(super.id, this.firstName, this.lastName);

  @override
  AppState? reduce() => null;

  @override
  String toString() =>
      '\${super.toString()}(id: \$id, firstName: \$firstName, lastName: \$lastName)';
}
''',
    );
  }
}
