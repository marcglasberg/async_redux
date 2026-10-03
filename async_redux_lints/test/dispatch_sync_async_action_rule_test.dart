import 'package:async_redux_lints/src/rules/dispatch_sync_async_action_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(DispatchSyncAsyncActionTest);
  });
}

const _actions = '''$header
class SyncAction extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;
}

class AsyncReduceAction extends ReduxAction<AppState> {
  @override
  Future<AppState?> reduce() async => null;
}

class CheckInternetAction extends ReduxAction<AppState> with CheckInternet<AppState> {
  @override
  AppState? reduce() => null;
}

class WrapReduceAction extends ReduxAction<AppState> {
  @override
  Future<AppState?> wrapReduce(Reducer<AppState> reduce) async => reduce();
  @override
  AppState? reduce() => null;
}

abstract class AppAction extends ReduxAction<AppState> {}
''';

@reflectiveTest
class DispatchSyncAsyncActionTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = DispatchSyncAsyncActionRule();
    super.setUp();
  }

  Future<void> test_syncAction() async {
    await assertNoDiagnostics('''$_actions
void f(Store<AppState> store) {
  store.dispatchSync(SyncAction());
}
''');
  }

  Future<void> test_asyncReduce() async {
    var code = '''$_actions
void f(Store<AppState> store) {
  store.dispatchSync(AsyncReduceAction());
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'AsyncReduceAction()',
        messageContainsAll: [
          "'AsyncReduceAction' is async because its 'reduce' method returns 'Future<AppState?>'",
        ],
      ),
    ]);
  }

  Future<void> test_asyncBeforeFromMixin() async {
    var code = '''$_actions
void f(Store<AppState> store) {
  store.dispatchSync(CheckInternetAction());
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'CheckInternetAction()',
        messageContainsAll: [
          "its 'before' method (from 'CheckInternet') returns 'Future<void>'",
        ],
      ),
    ]);
  }

  Future<void> test_asyncWrapReduce() async {
    var code = '''$_actions
void f(Store<AppState> store) {
  store.dispatchSync(WrapReduceAction());
}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'WrapReduceAction()', messageContainsAll: ["its 'wrapReduce' method"]),
    ]);
  }

  Future<void> test_dispatchSyncGetterInsideAction() async {
    var code = '''$_actions
class Caller extends ReduxAction<AppState> {
  @override
  AppState? reduce() {
    dispatchSync(AsyncReduceAction());
    return null;
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'AsyncReduceAction()')]);
  }

  Future<void> test_unknownActionType_isIgnored() async {
    await assertNoDiagnostics('''$_actions
void f(Store<AppState> store, ReduxAction<AppState> a1, AppAction a2) {
  store.dispatchSync(a1);
  store.dispatchSync(a2);
}
''');
  }
}
