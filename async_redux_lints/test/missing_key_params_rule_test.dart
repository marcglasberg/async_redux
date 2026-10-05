import 'package:async_redux_lints/src/rules/missing_key_params_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(MissingKeyParamsTest);
  });
}

@reflectiveTest
class MissingKeyParamsTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = MissingKeyParamsRule();
    super.setUp();
  }

  Future<void> test_nonReentrant() async {
    var code = '''$header
class LoadUserCart extends ReduxAction<AppState> with NonReentrant {
  final String userId;
  LoadUserCart(this.userId);

  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'NonReentrant',
        messageContainsAll: [
          "The action 'LoadUserCart' has fields, but doesn't override "
              "'nonReentrantKeyParams', so all its instances share the same "
              "'NonReentrant' key.",
        ],
        correctionContains: "'Object? nonReentrantKeyParams() => userId;'",
      ),
    ]);
  }

  Future<void> test_throttle() async {
    var code = '''$header
class A extends ReduxAction<AppState> with Throttle {
  final String id;
  A(this.id);

  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'Throttle',
        correctionContains: "'Object? lockBuilder() => (runtimeType, id);'",
      ),
    ]);
  }

  Future<void> test_eachMixin() async {
    for (var (index, (mixin, method)) in [
      ('Fresh', 'freshKeyParams'),
      ('Debounce', 'lockBuilder'),
      ('Polling', 'pollingKeyParams'),
      ('Sequential', 'sequentialKeyParams'),
      ('OptimisticCommand', 'nonReentrantKeyParams'),
      ('OptimisticSync<AppState, bool>', 'optimisticSyncKeyParams'),
      ('OptimisticSyncWithPush<AppState, bool>', 'optimisticSyncKeyParams'),
    ].indexed) {
      var code =
          '''$header
class A extends ReduxAction<AppState> with $mixin {
  final String id;
  A(this.id);

  @override
  Future<AppState?> reduce() async => null;
}
''';
      // Each mixin in its own file, since the analysis results of a file are cached.
      var path = '$testPackageLibPath/a$index.dart';
      var content = newFile(path, code).readAsStringSync();
      await assertDiagnosticsInFile(path, [
        lintAt(content, mixin, messageContainsAll: ["'$method'"]),
      ]);
    }
  }

  Future<void> test_mixinInBaseAction() async {
    var code = '''$header
abstract class AppAction extends ReduxAction<AppState> with NonReentrant {}

class A extends AppAction {
  final String id;
  A(this.id);

  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [lintAt(code, 'A extends', length: 1)]);
  }

  // ---------------------------------------------------------------------------
  // Valid.

  Future<void> test_overridden_isValid() async {
    await assertNoDiagnostics('''$header
class LoadUserCart extends ReduxAction<AppState> with NonReentrant {
  final String userId;
  LoadUserCart(this.userId);

  @override
  Object? nonReentrantKeyParams() => userId;

  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_computeKeyOverridden_isValid() async {
    await assertNoDiagnostics('''$header
class LoadUserCart extends ReduxAction<AppState> with NonReentrant {
  final String userId;
  LoadUserCart(this.userId);

  @override
  Object computeNonReentrantKey() => userId;

  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_noFields_isValid() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> with NonReentrant {
  static const limit = 10;

  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_pollField_isValid() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> with Polling {
  @override
  final Poll poll;
  A(this.poll);

  @override
  Future<AppState?> reduce() async => null;
}
''');
  }

  Future<void> test_mixinWithoutKey_isValid() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> with Retry {
  final String id;
  A(this.id);

  @override
  AppState? reduce() => null;
}
''');
  }
}
