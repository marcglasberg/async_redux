import 'dart:io';

import 'package:async_redux_lints/src/rules/mixin_combination_rules.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'rule_test_base.dart';

void main() {
  test('The incompatible pairs match the checks in action_mixins.dart', () {
    var source = File('../lib/src/action_mixins.dart').readAsStringSync();
    var pairs = {
      for (var match in RegExp(r'_incompatible<(\w+), (\w+)>\(this\)').allMatches(source))
        _sorted(match[1]!, match[2]!),
    };
    expect(pairs, isNotEmpty);
    expect({for (var (a, b) in incompatibleMixinPairs) _sorted(a, b)}, pairs);
  });

  defineReflectiveSuite(() {
    defineReflectiveTests(IncompatibleMixinsTest);
    defineReflectiveTests(PollingWithCaveatMixinTest);
  });
}

(String, String) _sorted(String a, String b) => (a.compareTo(b) < 0) ? (a, b) : (b, a);

@reflectiveTest
class IncompatibleMixinsTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = IncompatibleMixinsRule();
    super.setUp();
  }

  Future<void> test_compatibleMixins() async {
    await assertNoDiagnostics('''$header
class MyAction extends ReduxAction<AppState>
    with CheckInternet<AppState>, NoDialog<AppState>, Retry<AppState>,
        UnlimitedRetries<AppState>, NonReentrant<AppState>, Sequential<AppState> {
  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_incompatibleMixins() async {
    var code = '''$header
class MyAction extends ReduxAction<AppState> with NonReentrant<AppState>, Throttle<AppState> {
  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'Throttle<AppState>',
        messageContainsAll: [
          "The 'Throttle' mixin can't be combined with the 'NonReentrant' mixin.",
        ],
      ),
    ]);
  }

  Future<void> test_reportsOnTheLastMixin() async {
    var code = '''$header
class MyAction extends ReduxAction<AppState> with Throttle<AppState>, NonReentrant<AppState> {
  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'NonReentrant<AppState>',
        messageContainsAll: [
          "The 'NonReentrant' mixin can't be combined with the 'Throttle' mixin.",
        ],
      ),
    ]);
  }

  Future<void> test_severalIncompatiblePairs() async {
    var code = '''$header
abstract class MyAction extends ReduxAction<AppState>
    with Fresh<AppState>, Throttle<AppState>, NonReentrant<AppState> {}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'Throttle<AppState>', messageContainsAll: ["'Throttle'", "'Fresh'"]),
      lintAt(
        code,
        'NonReentrant<AppState>',
        messageContainsAll: ["'NonReentrant'", "'Fresh'"],
      ),
      lintAt(
        code,
        'NonReentrant<AppState>',
        messageContainsAll: ["'NonReentrant'", "'Throttle'"],
      ),
    ]);
  }

  Future<void> test_mixinFromSuperclass() async {
    var code = '''$header
abstract class AppAction extends ReduxAction<AppState> with CheckInternet<AppState> {}

class MyAction extends AppAction with ServerPush<AppState> {
  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'ServerPush<AppState>',
        messageContainsAll: [
          "The 'ServerPush' mixin can't be combined with the 'CheckInternet' mixin "
              "(from 'AppAction').",
        ],
      ),
    ]);
  }

  Future<void> test_pairInSuperclassIsReportedOnlyThere() async {
    var code = '''$header
abstract class AppAction extends ReduxAction<AppState>
    with Debounce<AppState>, Retry<AppState> {}

class MyAction extends AppAction {
  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'Retry<AppState>', messageContainsAll: ["'Retry'", "'Debounce'"]),
    ]);
  }

  Future<void> test_noDialogCountsAsCheckInternet() async {
    var code = '''$header
abstract class MyAction extends ReduxAction<AppState>
    with CheckInternet<AppState>, NoDialog<AppState>, AbortWhenNoInternet<AppState> {}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'AbortWhenNoInternet<AppState>',
        messageContainsAll: [
          "The 'AbortWhenNoInternet' mixin can't be combined with the 'CheckInternet' mixin.",
        ],
      ),
    ]);
  }

  Future<void> test_unlimitedRetriesIsReportedAsRetry() async {
    var code = '''$header
abstract class MyAction extends ReduxAction<AppState>
    with Retry<AppState>, UnlimitedRetries<AppState>, Polling<AppState> {}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'Polling<AppState>',
        messageContainsAll: [
          "The 'Polling' mixin can't be combined with the 'Retry' mixin.",
        ],
      ),
    ]);
  }

  Future<void> test_unlimitedRetriesIncompatibleWhenRetryIsNot() async {
    var code = '''$header
abstract class MyAction extends ReduxAction<AppState>
    with Retry<AppState>, UnlimitedRetries<AppState>, OptimisticCommand<AppState> {}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'OptimisticCommand<AppState>',
        messageContainsAll: [
          "The 'OptimisticCommand' mixin can't be combined with the 'UnlimitedRetries' mixin.",
        ],
      ),
    ]);
  }

  Future<void> test_mixinWithTwoTypeParameters() async {
    var code = '''$header
abstract class MyAction extends ReduxAction<AppState>
    with OptimisticSync<AppState, bool>, Sequential<AppState> {}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'Sequential<AppState>',
        messageContainsAll: [
          "The 'Sequential' mixin can't be combined with the 'OptimisticSync' mixin.",
        ],
      ),
    ]);
  }

  Future<void> test_classTypeAlias() async {
    var code = '''$header
abstract class MyAction = ReduxAction<AppState> with Debounce<AppState>, Sequential<AppState>;
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'Sequential<AppState>',
        messageContainsAll: ["'Sequential'", "'Debounce'"],
      ),
    ]);
  }

  Future<void> test_pollingWithSequentialIsNotIncompatible() async {
    await assertNoDiagnostics('''$header
abstract class MyAction extends ReduxAction<AppState>
    with Polling<AppState>, Sequential<AppState> {}
''');
  }
}

@reflectiveTest
class PollingWithCaveatMixinTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = PollingWithCaveatMixinRule();
    super.setUp();
  }

  Future<void> test_pollingAlone() async {
    await assertNoDiagnostics('''$header
abstract class PollAction extends ReduxAction<AppState> with Polling<AppState> {}

// The mixins belong to the tick action.
abstract class TickAction extends ReduxAction<AppState>
    with CheckInternet<AppState>, NonReentrant<AppState>, Sequential<AppState> {}
''');
  }

  Future<void> test_pollingWithSequential() async {
    var code = '''$header
abstract class PollAction extends ReduxAction<AppState>
    with Polling<AppState>, Sequential<AppState> {}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'Sequential<AppState>',
        messageContainsAll: [
          "Don't combine the 'Sequential' mixin with the 'Polling' mixin, because a "
              "'Poll.stop' has to wait for its turn in the queue",
        ],
      ),
    ]);
  }

  Future<void> test_pollingLast() async {
    var code = '''$header
abstract class PollAction extends ReduxAction<AppState>
    with Throttle<AppState>, Polling<AppState> {}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'Polling<AppState>',
        messageContainsAll: [
          "Don't combine the 'Throttle' mixin with the 'Polling' mixin, because a "
              "'Poll.stop' dispatched inside the throttle period is ignored",
        ],
      ),
    ]);
  }

  Future<void> test_eachCaveatMixin() async {
    var code = '''$header
abstract class PollAction extends ReduxAction<AppState>
    with Polling<AppState>, CheckInternet<AppState>, NoDialog<AppState>,
        NonReentrant<AppState>, Fresh<AppState> {}

abstract class PollAction2 extends ReduxAction<AppState>
    with Polling<AppState>, AbortWhenNoInternet<AppState> {}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'CheckInternet<AppState>', messageContainsAll: ["'CheckInternet'"]),
      lintAt(code, 'NonReentrant<AppState>', messageContainsAll: ["'NonReentrant'"]),
      lintAt(code, 'Fresh<AppState>', messageContainsAll: ["'Fresh'"]),
      lintAt(
        code,
        'AbortWhenNoInternet<AppState>',
        messageContainsAll: ["'AbortWhenNoInternet'"],
      ),
    ]);
  }

  Future<void> test_caveatMixinFromSuperclass() async {
    var code = '''$header
abstract class AppAction extends ReduxAction<AppState> with CheckInternet<AppState> {}

abstract class PollAction extends AppAction with Polling<AppState> {}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'Polling<AppState>',
        messageContainsAll: [
          "Don't combine the 'CheckInternet' mixin (from 'AppAction') with the 'Polling' mixin",
        ],
      ),
    ]);
  }

  Future<void> test_pollingFromSuperclass() async {
    var code = '''$header
abstract class PollBase extends ReduxAction<AppState> with Polling<AppState> {}

abstract class PollAction extends PollBase with Sequential<AppState> {}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'Sequential<AppState>',
        messageContainsAll: [
          "Don't combine the 'Sequential' mixin with the 'Polling' mixin (from 'PollBase')",
        ],
      ),
    ]);
  }

  Future<void> test_incompatibleMixinIsNotReported() async {
    await assertNoDiagnostics('''$header
abstract class PollAction extends ReduxAction<AppState>
    with Polling<AppState>, Retry<AppState> {}
''');
  }
}
