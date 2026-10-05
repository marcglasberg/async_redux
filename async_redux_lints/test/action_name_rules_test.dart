import 'package:async_redux_lints/src/fixes/rename_action_fixes.dart';
import 'package:async_redux_lints/src/rules/action_name_rules.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'rule_test_base.dart';

void main() {
  group('ActionNameStyle.suggestedName', () {
    String? suggest(ActionNameStyle style, String name) => style.suggestedName(name);

    test('endsWithAction', () {
      var style = ActionNameStyle.endsWithAction;
      expect(suggest(style, 'LoadUser'), 'LoadUserAction');
      expect(suggest(style, 'LoadUser_Action'), 'LoadUserAction');
      expect(suggest(style, '_LoadUser'), '_LoadUserAction');
      expect(suggest(style, 'LoadUserAction'), isNull);
      expect(suggest(style, 'Action'), isNull);
    });

    test('endsWithUnderscoreAction', () {
      var style = ActionNameStyle.endsWithUnderscoreAction;
      expect(suggest(style, 'LoadUser'), 'LoadUser_Action');
      expect(suggest(style, 'LoadUserAction'), 'LoadUser_Action');
      expect(suggest(style, '_LoadUserAction'), '_LoadUser_Action');
      expect(suggest(style, 'LoadUser_Action'), isNull);
      expect(suggest(style, '_Action'), isNull);
    });

    test('withoutAction', () {
      var style = ActionNameStyle.withoutAction;
      expect(suggest(style, 'LoadUserAction'), 'LoadUser');
      expect(suggest(style, 'LoadUser_Action'), 'LoadUser');
      expect(suggest(style, 'Load_UserAction'), 'Load_User');
      expect(suggest(style, '_LoadUserAction'), '_LoadUser');
      expect(suggest(style, 'ActionLog'), isNull);
      expect(suggest(style, 'Action'), isNull);
      expect(suggest(style, 'Action2'), isNull);
    });

    test('withoutAction checks only the end of the name', () {
      var style = ActionNameStyle.withoutAction;
      expect(style.matches('LoadUser'), isTrue);
      expect(style.matches('ActionLog'), isTrue);
      expect(style.matches('LoadActionUser'), isTrue);
      expect(style.matches('LoadActions'), isTrue);
      expect(style.matches('LoadAction'), isFalse);
      expect(style.matches('LoadUser_Action'), isFalse);
    });
  });

  defineReflectiveSuite(() {
    defineReflectiveTests(ActionNameEndsWithActionTest);
    defineReflectiveTests(ActionNameEndsWithUnderscoreActionTest);
    defineReflectiveTests(ActionNameWithoutActionTest);
  });
}

@reflectiveTest
class ActionNameEndsWithActionTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = ActionNameEndsWithActionRule();
    super.setUp();
  }

  Future<void> test_endsWithAction() async {
    await assertNoDiagnostics('''$header
class LoadUserAction extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_withoutAction() async {
    var code = '''$header
class LoadUser extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'LoadUser',
        messageContainsAll: [
          "The name of the action 'LoadUser' should end with 'Action'.",
        ],
        correctionContains: "Try renaming the action to 'LoadUserAction'.",
      ),
    ]);
  }

  Future<void> test_endsWithUnderscoreAction() async {
    var code = '''$header
class LoadUser_Action extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'LoadUser_Action',
        correctionContains: "Try renaming the action to 'LoadUserAction'.",
      ),
    ]);
  }

  Future<void> test_subclassOfBaseAction() async {
    var code = '''$header
abstract class AppAction extends ReduxAction<AppState> {}

class LoadUser extends AppAction {
  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [lintAt(code, 'LoadUser')]);
  }

  Future<void> test_classTypeAlias() async {
    var code = '''$header
abstract class Base extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;
}

class LoadUser = Base with NonReentrant<AppState>;
''';
    await assertDiagnostics(code, [lintAt(code, 'LoadUser =', length: 8)]);
  }

  Future<void> test_notChecked() async {
    await assertNoDiagnostics('''$header
abstract class AppBase extends ReduxAction<AppState> {}

sealed class Sealed extends ReduxAction<AppState> {}

mixin MyMixin on ReduxAction<AppState> {}

class User {}
''');
  }

  Future<void> test_fix_renamesInAllFiles() async {
    var other = newFile('$testPackageLibPath/other.dart', '''
import 'package:test/test.dart';

/// Dispatches [LoadUser].
void f(LoadUser action) {
  print(LoadUser());
  print(LoadUser.named());
  print(LoadUser.new);
  print(<LoadUser>[]);
}
''');
    var code = '''$header
class LoadUser extends ReduxAction<AppState> {
  LoadUser();
  LoadUser.named();

  factory LoadUser.create() = LoadUser;

  @override
  AppState? reduce() => null;
}

class Other extends LoadUser {}
''';
    await assertFixInFiles(
      code,
      ({required context}) =>
          RenameAction(ActionNameStyle.endsWithAction, context: context),
      {
        testFile.path: code.replaceAll('LoadUser', 'LoadUserAction'),
        other.path: other.readAsStringSync().replaceAll('LoadUser', 'LoadUserAction'),
      },
    );
  }

  Future<void> test_fix_notOfferedWhenTheNameIsTaken() async {
    await assertFix(
      '''$header
class LoadUserAction {}

class LoadUser extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;
}
''',
      ({required context}) =>
          RenameAction(ActionNameStyle.endsWithAction, context: context),
      null,
    );
  }
}

@reflectiveTest
class ActionNameEndsWithUnderscoreActionTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = ActionNameEndsWithUnderscoreActionRule();
    super.setUp();
  }

  Future<void> test_endsWithUnderscoreAction() async {
    await assertNoDiagnostics('''$header
class LoadUser_Action extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_endsWithAction() async {
    var code = '''$header
class LoadUserAction extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'LoadUserAction',
        messageContainsAll: [
          "The name of the action 'LoadUserAction' should end with '_Action'.",
        ],
        correctionContains: "Try renaming the action to 'LoadUser_Action'.",
      ),
    ]);
  }

  Future<void> test_fix() async {
    var code = '''$header
class LoadUser extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;
}

void f() => LoadUser();
''';
    await assertFix(
      code,
      ({required context}) =>
          RenameAction(ActionNameStyle.endsWithUnderscoreAction, context: context),
      code.replaceAll('LoadUser', 'LoadUser_Action'),
    );
  }
}

@reflectiveTest
class ActionNameWithoutActionTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = ActionNameWithoutActionRule();
    super.setUp();
  }

  Future<void> test_withoutAction() async {
    await assertNoDiagnostics('''$header
class LoadUser extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;
}

class SaveTransaction extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;
}

class ActionLog extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_withAction() async {
    var code = '''$header
class LoadUserAction extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;
}

class LoadUser_Action extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'LoadUserAction',
        messageContainsAll: [
          "The name of the action 'LoadUserAction' shouldn't end with 'Action'.",
        ],
        correctionContains: "Try renaming the action to 'LoadUser'.",
      ),
      lintAt(
        code,
        'LoadUser_Action',
        correctionContains: "Try renaming the action to 'LoadUser'.",
      ),
    ]);
  }

  Future<void> test_noSuggestion() async {
    var code = '''$header
class Action extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'Action extends',
        length: 6,
        correctionContains: "Try renaming the action.",
      ),
    ]);
  }

  Future<void> test_fix() async {
    var code = '''$header
class LoadUserAction extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;
}

void f() => LoadUserAction();
''';
    await assertFix(
      code,
      ({required context}) =>
          RenameAction(ActionNameStyle.withoutAction, context: context),
      code.replaceAll('LoadUserAction', 'LoadUser'),
    );
  }
}
