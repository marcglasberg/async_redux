import 'package:async_redux_lints/src/rules/server_push_associated_action_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ServerPushAssociatedActionTest);
  });
}

@reflectiveTest
class ServerPushAssociatedActionTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = ServerPushAssociatedActionRule();
    super.setUp();
  }

  static const _actions = '''
class ToggleLike extends ReduxAction<AppState> with OptimisticSyncWithPush<AppState, bool> {
  @override
  AppState? reduce() => null;
}

class SaveLike extends ReduxAction<AppState> with OptimisticSync<AppState, bool> {
  @override
  AppState? reduce() => null;
}
''';

  Future<void> test_actionWithoutOptimisticSyncWithPush() async {
    var code = '''$header$_actions
class PushLike extends ReduxAction<AppState> with ServerPush {
  @override
  AppState? reduce() => null;

  @override
  Type associatedAction() => SaveLike;
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'SaveLike;',
        length: 8,
        messageContainsAll: [
          "The 'SaveLike' returned by 'associatedAction' doesn't use the "
              "'OptimisticSyncWithPush' mixin.",
        ],
      ),
    ]);
  }

  Future<void> test_blockBody() async {
    var code = '''$header$_actions
class PushLike extends ReduxAction<AppState> with ServerPush {
  @override
  AppState? reduce() => null;

  @override
  Type associatedAction() {
    return PushLike;
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'PushLike;', length: 8)]);
  }

  // ---------------------------------------------------------------------------
  // Valid.

  Future<void> test_optimisticSyncWithPush_isValid() async {
    await assertNoDiagnostics('''$header$_actions
class PushLike extends ReduxAction<AppState> with ServerPush {
  @override
  AppState? reduce() => null;

  @override
  Type associatedAction() => ToggleLike;
}
''');
  }

  Future<void> test_optimisticSyncWithPushInBaseAction_isValid() async {
    await assertNoDiagnostics('''$header
abstract class LikeAction extends ReduxAction<AppState>
    with OptimisticSyncWithPush<AppState, bool> {}

class ToggleLike extends LikeAction {
  @override
  AppState? reduce() => null;
}

class PushLike extends ReduxAction<AppState> with ServerPush {
  @override
  AppState? reduce() => null;

  @override
  Type associatedAction() => ToggleLike;
}
''');
  }

  Future<void> test_withoutServerPush_isValid() async {
    await assertNoDiagnostics('''$header$_actions
class A extends ReduxAction<AppState> {
  Type associatedAction() => SaveLike;

  @override
  AppState? reduce() => null;
}
''');
  }
}
