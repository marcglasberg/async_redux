import 'package:async_redux_lints/src/rules/dispatch_and_wait_unlimited_retries_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(DispatchAndWaitUnlimitedRetriesTest);
  });
}

@reflectiveTest
class DispatchAndWaitUnlimitedRetriesTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = DispatchAndWaitUnlimitedRetriesRule();
    super.setUp();
  }

  static const _actions = '''
class Load extends ReduxAction<AppState> with Retry, UnlimitedRetries {
  @override
  AppState? reduce() => null;
}

class LoadWhenOnline extends ReduxAction<AppState> with UnlimitedRetryCheckInternet {
  @override
  AppState? reduce() => null;
}

class Other extends ReduxAction<AppState> with Retry {
  @override
  AppState? reduce() => null;
}
''';

  Future<void> test_storeDispatchAndWait() async {
    var code = '''$header$_actions
Future<void> f(Store<AppState> store) async {
  await store.dispatchAndWait(Load());
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'Load()',
        messageContainsAll: [
          "The action 'Load' uses the 'UnlimitedRetries' mixin, so the future returned "
              "by 'dispatchAndWait' may never complete.",
        ],
      ),
    ]);
  }

  Future<void> test_testFiles() async {
    await assertNotReportedInTests('''$header$_actions
Future<void> f(Store<AppState> store) async {
  await store.dispatchAndWait(Load());
}
''');
  }

  Future<void> test_unlimitedRetryCheckInternet() async {
    var code = '''$header$_actions
Future<void> f(Store<AppState> store) => store.dispatchAndWait(LoadWhenOnline());
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'LoadWhenOnline()',
        messageContainsAll: ["'UnlimitedRetryCheckInternet'"],
      ),
    ]);
  }

  Future<void> test_dispatchAndWaitAll() async {
    var code = '''$header$_actions
Future<void> f(Store<AppState> store) async {
  await store.dispatchAndWaitAll([Other(), Load()]);
}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'Load()', messageContainsAll: ["'dispatchAndWaitAll'"]),
    ]);
  }

  Future<void> test_inAction() async {
    var code = '''$header$_actions
class A extends ReduxAction<AppState> {
  @override
  Future<AppState?> reduce() async {
    await dispatchAndWait(Load());
    return null;
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'Load()', occurrence: 1)]);
  }

  Future<void> test_variable() async {
    var code = '''$header$_actions
Future<void> f(Store<AppState> store, Load action) async {
  await store.dispatchAndWait(action);
}
''';
    await assertDiagnostics(code, [lintAt(code, 'action);', length: 6)]);
  }

  // ---------------------------------------------------------------------------
  // Valid.

  Future<void> test_dispatch_isValid() async {
    await assertNoDiagnostics('''$header$_actions
void f(Store<AppState> store) {
  store.dispatch(Load());
}
''');
  }

  Future<void> test_limitedRetries_isValid() async {
    await assertNoDiagnostics('''$header$_actions
Future<void> f(Store<AppState> store) async {
  await store.dispatchAndWait(Other());
}
''');
  }
}
