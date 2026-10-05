import 'package:async_redux_lints/src/rules/action_file_name_rules.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'rule_test_base.dart';

void main() {
  group('ActionFileNameStyle.suggestedName', () {
    test('endsWithAction', () {
      var style = ActionFileNameStyle.endsWithAction;
      expect(style.suggestedName('user', 'LoadUser'), 'load_user_action.dart');
      expect(style.suggestedName('user', 'LoadUserAction'), 'load_user_action.dart');
      expect(style.suggestedName('user', 'LoadUser_Action'), 'load_user_action.dart');
      expect(style.suggestedName('user', 'HTTPRequest'), 'http_request_action.dart');
      expect(style.suggestedName('user', 'ABCdEFg'), 'ab_cd_e_fg_action.dart');
      expect(style.suggestedName('user', 'Load2Users'), 'load2_users_action.dart');
      expect(style.suggestedName('user', 'Load__User_'), 'load_user_action.dart');
      expect(style.suggestedName('user', '_LoadUser'), 'load_user_action.dart');
      expect(style.suggestedName('user', 'Action'), 'user_action.dart');
      expect(style.suggestedName('user_actions', null), 'user_action.dart');
      expect(style.suggestedName('ACTION_load_user', null), 'load_user_action.dart');
    });

    test('startsWithAction', () {
      var style = ActionFileNameStyle.startsWithAction;
      expect(style.suggestedName('user', 'LoadUserAction'), 'ACTION_load_user.dart');
      expect(style.suggestedName('user_actions', null), 'ACTION_user.dart');
      expect(style.suggestedName('load_user_action', null), 'ACTION_load_user.dart');
    });
  });

  defineReflectiveSuite(() {
    defineReflectiveTests(ActionFileNameEndsWithActionTest);
    defineReflectiveTests(ActionFileNameStartsWithActionTest);
  });
}

const _twoActions = '''$header
class AppStateHelper {}

abstract class AppAction extends ReduxAction<AppState> {}

class LoadUser extends AppAction {
  @override
  AppState? reduce() => null;
}

class SaveUser extends AppAction {
  @override
  AppState? reduce() => null;
}
''';

@reflectiveTest
class ActionFileNameEndsWithActionTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = ActionFileNameEndsWithActionRule();
    super.setUp();
  }

  Future<void> test_endsWithAction() async {
    var path = '$testPackageLibPath/user_action.dart';
    newFile(path, _twoActions);
    await assertNoDiagnosticsInFile(path);
  }

  Future<void> test_otherName() async {
    var path = '$testPackageLibPath/ACTION_user.dart';
    var content = newFile(path, _twoActions).readAsStringSync();
    await assertDiagnosticsInFile(path, [
      lintAt(
        content,
        'LoadUser',
        messageContainsAll: [
          "The file 'ACTION_user.dart' declares actions, so its name should end with "
              "'_action'.",
        ],
        correctionContains: "Try renaming the file to 'user_action.dart'.",
      ),
    ]);
  }

  Future<void> test_singleAction_suggestsTheActionName() async {
    var code = '''$header
class LoadUserAction extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;
}
''';
    var path = '$testPackageLibPath/user.dart';
    var content = newFile(path, code).readAsStringSync();
    await assertDiagnosticsInFile(path, [
      lintAt(
        content,
        'LoadUserAction',
        correctionContains: "Try renaming the file to 'load_user_action.dart'.",
      ),
    ]);
  }

  Future<void> test_noConcreteActions() async {
    var path = '$testPackageLibPath/app_base.dart';
    newFile(path, '''$header
abstract class AppAction extends ReduxAction<AppState> {}

mixin MyMixin on ReduxAction<AppState> {}
''');
    await assertNoDiagnosticsInFile(path);
  }

  Future<void> test_testFiles_areNotChecked() async {
    var inTestDirectory = '$testPackageTestPath/helpers.dart';
    newFile(inTestDirectory, _twoActions);
    await assertNoDiagnosticsInFile(inTestDirectory);

    var testFile = '$testPackageLibPath/user_test.dart';
    newFile(testFile, _twoActions);
    await assertNoDiagnosticsInFile(testFile);
  }
}

@reflectiveTest
class ActionFileNameStartsWithActionTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = ActionFileNameStartsWithActionRule();
    super.setUp();
  }

  Future<void> test_startsWithAction() async {
    var path = '$testPackageLibPath/ACTION_user.dart';
    newFile(path, _twoActions);
    await assertNoDiagnosticsInFile(path);
  }

  Future<void> test_otherName() async {
    var path = '$testPackageLibPath/user_action.dart';
    var content = newFile(path, _twoActions).readAsStringSync();
    await assertDiagnosticsInFile(path, [
      lintAt(
        content,
        'LoadUser',
        messageContainsAll: [
          "The file 'user_action.dart' declares actions, so its name should start "
              "with 'ACTION_'.",
        ],
        correctionContains: "Try renaming the file to 'ACTION_user.dart'.",
      ),
    ]);
  }
}
