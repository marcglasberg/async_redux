import 'package:async_redux_lints/src/fixes/mixin_fixes.dart';
import 'package:async_redux_lints/src/rules/polling_action_restarts_polling_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(PollingActionRestartsPollingTest);
  });
}

@reflectiveTest
class PollingActionRestartsPollingTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = PollingActionRestartsPollingRule();
    super.setUp();
  }

  Future<void> test_sameAction() async {
    var code = '''$header
class Load extends ReduxAction<AppState> with Polling {
  @override
  final Poll poll;
  Load({this.poll = Poll.once});

  @override
  ReduxAction<AppState> createPollingAction() => Load(poll: Poll.start);

  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'Poll.start',
        messageContainsAll: [
          "The action returned by 'createPollingAction' must use 'Poll.once', not "
              "'Poll.start', so that each tick doesn't control the polling.",
        ],
      ),
    ]);
  }

  Future<void> test_positionalArgument_blockBody() async {
    var code = '''$header
class Tick extends ReduxAction<AppState> {
  final Poll poll;
  Tick(this.poll);

  @override
  AppState? reduce() => null;
}

class Load extends ReduxAction<AppState> with Polling {
  @override
  Poll get poll => Poll.start;

  @override
  ReduxAction<AppState> createPollingAction() {
    return Tick(Poll.runNowAndRestart);
  }

  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'Poll.runNowAndRestart',
        messageContainsAll: ["'Poll.runNowAndRestart'"],
      ),
    ]);
  }

  Future<void> test_fix() async {
    await assertFix(
      '''$header
class Load extends ReduxAction<AppState> with Polling {
  @override
  final Poll poll;
  Load({this.poll = Poll.once});

  @override
  ReduxAction<AppState> createPollingAction() => Load(poll: Poll.stop);

  @override
  AppState? reduce() => null;
}
''',
      UsePollOnce.new,
      '''$header
class Load extends ReduxAction<AppState> with Polling {
  @override
  final Poll poll;
  Load({this.poll = Poll.once});

  @override
  ReduxAction<AppState> createPollingAction() => Load(poll: Poll.once);

  @override
  AppState? reduce() => null;
}
''',
    );
  }

  // ---------------------------------------------------------------------------
  // Valid.

  Future<void> test_pollOnce_isValid() async {
    await assertNoDiagnostics('''$header
class Load extends ReduxAction<AppState> with Polling {
  @override
  final Poll poll;
  Load({this.poll = Poll.once});

  @override
  ReduxAction<AppState> createPollingAction() => Load(poll: Poll.once);

  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_defaultPoll_isValid() async {
    await assertNoDiagnostics('''$header
class Load extends ReduxAction<AppState> with Polling {
  @override
  final Poll poll;
  Load({this.poll = Poll.once});

  @override
  ReduxAction<AppState> createPollingAction() => Load();

  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_withoutPolling_isValid() async {
    await assertNoDiagnostics('''$header
class Load extends ReduxAction<AppState> {
  final Poll poll;
  Load(this.poll);

  ReduxAction<AppState> createPollingAction() => Load(Poll.start);

  @override
  AppState? reduce() => null;
}
''');
  }
}
