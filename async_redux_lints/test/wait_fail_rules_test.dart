import 'package:async_redux_lints/src/rules/wait_fail_rules.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(WaitFailInvalidArgumentTest);
    defineReflectiveTests(WaitFailNeverMatchesTest);
  });
}

const _actions = '''$header
class SyncAction extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;
}

class AsyncAction extends ReduxAction<AppState> {
  @override
  Future<AppState?> reduce() async => null;
}

class CheckInternetAction extends ReduxAction<AppState> with CheckInternet<AppState> {
  @override
  AppState? reduce() => null;
}

abstract class AppAction extends ReduxAction<AppState> {}
''';

@reflectiveTest
class WaitFailInvalidArgumentTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = WaitFailInvalidArgumentRule();
    super.setUp();
  }

  Future<void> test_valid() async {
    await assertNoDiagnostics('''$_actions
void f(Store<AppState> store, AsyncAction action, List<Type> types, Object unknown,
    dynamic d, Type type) {
  store.isWaiting(AsyncAction);
  store.isWaiting(action);
  store.isWaiting([AsyncAction, action]);
  store.isWaiting({AsyncAction, action});
  store.isWaiting(types);
  store.isWaiting(unknown);
  store.isWaiting(d);
  store.isWaiting(type);
  store.isFailed(AsyncAction);
  store.isFailed([AsyncAction, SyncAction]);
  store.isFailed(types);
  store.exceptionFor(AsyncAction);
  store.exceptionFor([AsyncAction, type, unknown, ...types]);
  store.clearExceptionFor(AsyncAction);
  store.clearExceptionFor(action.runtimeType);
}
''');
  }

  Future<void> test_isWaiting_notActionOrType() async {
    var code = '''$_actions
void f(Store<AppState> store) {
  store.isWaiting('AsyncAction');
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        "'AsyncAction'",
        messageContainsAll: [
          "'isWaiting' accepts only an action, an action type, or a list of them, not 'String'",
        ],
      ),
    ]);
  }

  Future<void> test_actionPassedToIsFailed() async {
    var code = '''$_actions
void f(Store<AppState> store, AsyncAction action) {
  store.isFailed(action);
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'action)',
        occurrence: 2,
        length: 'action'.length,
        messageContainsAll: [
          "'isFailed' accepts only an action type, or a list of action types, not 'AsyncAction'",
        ],
      ),
    ]);
  }

  Future<void> test_actionPassedToExceptionForAndClearExceptionFor() async {
    var code = '''$_actions
void f(Store<AppState> store) {
  store.exceptionFor(AsyncAction());
  store.clearExceptionFor(SyncAction());
}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'AsyncAction()'),
      lintAt(code, 'SyncAction()'),
    ]);
  }

  Future<void> test_invalidListElements() async {
    var code = '''$_actions
void f(Store<AppState> store, AsyncAction action, bool b) {
  store.isWaiting([AsyncAction, 42]);
  store.exceptionFor([AsyncAction, action]);
  store.isFailed([if (b) action else AsyncAction]);
  store.isWaiting([[AsyncAction]]);
}
''';
    await assertDiagnostics(code, [
      lintAt(code, '42'),
      lintAt(code, 'action]', length: 'action'.length),
      lintAt(code, 'action else', length: 'action'.length),
      lintAt(code, '[AsyncAction]]', length: '[AsyncAction]'.length),
    ]);
  }

  Future<void> test_invalidIterableType() async {
    var code = '''$_actions
void f(Store<AppState> store, List<String> names, List<AsyncAction> actions) {
  store.isWaiting(names);
  store.isWaiting(actions);
  store.exceptionFor(actions);
  store.clearExceptionFor([...actions]);
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'names)',
        length: 'names'.length,
        messageContainsAll: ["not 'List<String>'"],
      ),
      lintAt(
        code,
        'actions)',
        occurrence: 3,
        length: 'actions'.length,
        messageContainsAll: ["not 'List<AsyncAction>'"],
      ),
      lintAt(code, 'actions]', length: 'actions'.length),
    ]);
  }

  Future<void> test_allCallForms() async {
    var code = '''$_actions
class Caller extends ReduxAction<AppState> {
  @override
  AppState? reduce() {
    exceptionFor(AsyncAction());
    return null;
  }
}

void f(BuildContext context) {
  context.isFailed(AsyncAction());
  StoreProvider.isWaiting(context, 'x');
}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'AsyncAction()', occurrence: 1),
      lintAt(code, 'AsyncAction()', occurrence: 2),
      lintAt(code, "'x'"),
    ]);
  }

  Future<void> test_otherIsWaiting_isIgnored() async {
    await assertNoDiagnostics('''$_actions
class Other {
  bool isWaiting(Object o) => false;
}

void f(Wait wait, Other other) {
  wait.isWaiting('flag');
  other.isWaiting('flag');
}
''');
  }
}

@reflectiveTest
class WaitFailNeverMatchesTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = WaitFailNeverMatchesRule();
    super.setUp();
  }

  Future<void> test_valid() async {
    await assertNoDiagnostics('''$_actions
void f(Store<AppState> store, AsyncAction action, SyncAction syncAction) {
  store.isWaiting(AsyncAction);
  store.isWaiting(CheckInternetAction);
  store.isWaiting(action);
  store.isWaiting(syncAction);
  store.isFailed(SyncAction);
  store.exceptionFor([SyncAction, AsyncAction]);
}
''');
  }

  Future<void> test_notAnActionType() async {
    var code = '''$_actions
void f(Store<AppState> store) {
  store.isWaiting(AppState);
  store.exceptionFor([AsyncAction, String]);
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'AppState)',
        length: 'AppState'.length,
        messageContainsAll: [
          "'isWaiting' never matches 'AppState', because 'AppState' is not an action type",
        ],
      ),
      lintAt(code, 'String'),
    ]);
  }

  Future<void> test_abstractActionTypeOrMixin() async {
    var code = '''$_actions
void f(Store<AppState> store) {
  store.isFailed(AppAction);
  store.isWaiting(CheckInternet);
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'AppAction)',
        length: 'AppAction'.length,
        messageContainsAll: [
          "'AppAction' is abstract, and AsyncRedux only matches actions of exactly this type",
        ],
      ),
      lintAt(
        code,
        'CheckInternet)',
        length: 'CheckInternet'.length,
        messageContainsAll: ["'CheckInternet' is a mixin"],
      ),
    ]);
  }

  Future<void> test_isWaiting_syncActionType() async {
    var code = '''$_actions
void f(Store<AppState> store) {
  store.isWaiting(SyncAction);
  store.isWaiting([AsyncAction, SyncAction]);
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'SyncAction)',
        length: 'SyncAction'.length,
        messageContainsAll: ["'SyncAction' is a sync action"],
      ),
      lintAt(code, 'SyncAction]', length: 'SyncAction'.length),
    ]);
  }

  Future<void> test_isWaiting_newAction() async {
    var code = '''$_actions
void f(Store<AppState> store) {
  store.isWaiting(AsyncAction());
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'AsyncAction()',
        messageContainsAll: [
          "'isWaiting' never matches 'AsyncAction', because this action is created here, "
              "so it was never dispatched",
        ],
      ),
    ]);
  }
}
