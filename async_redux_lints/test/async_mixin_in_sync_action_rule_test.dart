import 'package:async_redux_lints/src/rules/async_mixin_in_sync_action_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AsyncMixinInSyncActionTest);
  });
}

@reflectiveTest
class AsyncMixinInSyncActionTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = AsyncMixinInSyncActionRule();
    super.setUp();
  }

  Future<void> test_checkInternet() async {
    var code = '''$header
class A extends ReduxAction<AppState> with CheckInternet {
  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'CheckInternet {',
        length: 13,
        messageContainsAll: [
          "The 'CheckInternet' mixin is pointless in the sync action 'A', because a "
              "sync reducer does no network calls.",
        ],
      ),
    ]);
  }

  Future<void> test_abortWhenNoInternet() async {
    var code = '''$header
class A extends ReduxAction<AppState> with AbortWhenNoInternet {
  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [lintAt(code, 'AbortWhenNoInternet {', length: 19)]);
  }

  Future<void> test_unlimitedRetryCheckInternet() async {
    var code = '''$header
class A extends ReduxAction<AppState> with UnlimitedRetryCheckInternet {
  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'UnlimitedRetryCheckInternet {', length: 27),
    ]);
  }

  Future<void> test_nonReentrant() async {
    var code = '''$header
class A extends ReduxAction<AppState> with NonReentrant {
  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [lintAt(code, 'NonReentrant {', length: 12)]);
  }

  Future<void> test_retry() async {
    var code = '''$header
class A extends ReduxAction<AppState> with Retry {
  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [lintAt(code, 'Retry {', length: 5)]);
  }

  Future<void> test_reportsEachMixin() async {
    var code = '''$header
class A extends ReduxAction<AppState> with CheckInternet, NoDialog {
  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'CheckInternet,', length: 13),
      lintAt(code, 'NoDialog {', length: 8),
    ]);
  }

  Future<void> test_retryAndUnlimitedRetries() async {
    var code = '''$header
class A extends ReduxAction<AppState> with Retry, UnlimitedRetries {
  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'Retry,', length: 5),
      lintAt(code, 'UnlimitedRetries {', length: 16),
    ]);
  }

  Future<void> test_mixinInBaseAction() async {
    var code = '''$header
abstract class AppAction extends ReduxAction<AppState> with NonReentrant {}

class A extends AppAction {
  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [lintAt(code, 'A extends', length: 1)]);
  }

  Future<void> test_testFiles() async {
    await assertNotReportedInTests('''$header
class A extends ReduxAction<AppState> with Retry {
  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_asyncReduce() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> with CheckInternet, Retry {
  @override
  Future<AppState?> reduce() async => null;
}
''');
  }

  Future<void> test_futureOrReduce() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> with NonReentrant {
  @override
  FutureOr<AppState?> reduce() => null;
}
''');
  }

  Future<void> test_overridesBefore() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> with CheckInternet {
  @override
  Future<void> before() async {
    await super.before();
  }

  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_overridesWrapReduce() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> with NonReentrant {
  @override
  Future<AppState?> wrapReduce(Reducer<AppState> reduce) async => reduce();

  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_abstractAction() async {
    await assertNoDiagnostics('''$header
abstract class AppAction extends ReduxAction<AppState> with NonReentrant {
  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_otherMixins() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> with Throttle {
  @override
  AppState? reduce() => null;
}

class B extends ReduxAction<AppState> with Fresh {
  @override
  AppState? reduce() => null;
}
''');
  }
}
