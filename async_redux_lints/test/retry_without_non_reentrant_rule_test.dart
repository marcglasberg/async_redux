import 'package:async_redux_lints/src/fixes/mixin_fixes.dart';
import 'package:async_redux_lints/src/rules/retry_without_non_reentrant_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(RetryWithoutNonReentrantTest);
  });
}

@reflectiveTest
class RetryWithoutNonReentrantTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = RetryWithoutNonReentrantRule();
    super.setUp();
  }

  Future<void> test_retry() async {
    var code = '''$header
class A extends ReduxAction<AppState> with Retry {
  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'Retry {',
        length: 5,
        messageContainsAll: [
          "The action 'A' uses the 'Retry' mixin without the 'NonReentrant' mixin.",
        ],
      ),
    ]);
  }

  Future<void> test_unlimitedRetries() async {
    var code = '''$header
class A extends ReduxAction<AppState> with Retry, UnlimitedRetries {
  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [lintAt(code, 'Retry,', length: 5)]);
  }

  Future<void> test_retryInBaseAction() async {
    var code = '''$header
abstract class AppAction extends ReduxAction<AppState> with Retry {}

class A extends AppAction {
  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [lintAt(code, 'A extends', length: 1)]);
  }

  Future<void> test_fix_addsToWithClause() async {
    await assertFix(
      '''$header
class A extends ReduxAction<AppState> with Retry {
  @override
  AppState? reduce() => null;
}
''',
      AddNonReentrant.new,
      '''$header
class A extends ReduxAction<AppState> with Retry, NonReentrant {
  @override
  AppState? reduce() => null;
}
''',
    );
  }

  Future<void> test_fix_addsWithClause() async {
    await assertFix(
      '''$header
abstract class AppAction extends ReduxAction<AppState> with Retry {}

class A extends AppAction {
  @override
  AppState? reduce() => null;
}
''',
      AddNonReentrant.new,
      '''$header
abstract class AppAction extends ReduxAction<AppState> with Retry {}

class A extends AppAction with NonReentrant {
  @override
  AppState? reduce() => null;
}
''',
    );
  }

  // ---------------------------------------------------------------------------
  // Valid.

  Future<void> test_withNonReentrant_isValid() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> with Retry, NonReentrant {
  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_nonReentrantInBaseAction_isValid() async {
    await assertNoDiagnostics('''$header
abstract class AppAction extends ReduxAction<AppState> with NonReentrant {}

class A extends AppAction with Retry {
  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_withSequential_isValid() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> with Retry, Sequential {
  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_withThrottle_isValid() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> with Retry, Throttle {
  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_incompatibleWithRetry_isValid() async {
    // Reported by `incompatible_mixins`.
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> with Retry, Polling {
  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_overridesAbortDispatch_isValid() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> with Retry {
  @override
  bool abortDispatch() => isWaiting(A);

  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_abstractAction_isValid() async {
    await assertNoDiagnostics('''$header
abstract class AppAction extends ReduxAction<AppState> with Retry {}
''');
  }
}
