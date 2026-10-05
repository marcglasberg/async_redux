import 'package:async_redux_lints/src/fixes/mixin_fixes.dart';
import 'package:async_redux_lints/src/rules/sequential_rules.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(SequentialDeadlockTest);
    defineReflectiveTests(SequentialBeforeSuperNotFirstTest);
    defineReflectiveTests(SequentialAfterSuperNotInFinallyTest);
  });
}

@reflectiveTest
class SequentialDeadlockTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = SequentialDeadlockRule();
    super.setUp();
  }

  static const _child = '''
class Child extends ReduxAction<AppState> with Sequential {
  @override
  AppState? reduce() => null;
}
''';

  Future<void> test_dispatchAndWait() async {
    var code = '''$header$_child
class Parent extends ReduxAction<AppState> with Sequential {
  @override
  Future<AppState?> reduce() async {
    await dispatchAndWait(Child());
    return null;
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'Child()',
        messageContainsAll: [
          "'Parent' and 'Child' use the same 'Sequential' queue, so waiting for "
              "'Child' with 'dispatchAndWait' deadlocks: 'Child' only runs after "
              "'Parent' finishes.",
        ],
        correctionContains: "Try using 'dispatch' instead",
      ),
    ]);
  }

  Future<void> test_storeDispatchAndWait() async {
    var code = '''$header$_child
class Parent extends ReduxAction<AppState> with Sequential {
  @override
  Future<AppState?> reduce() async {
    await store.dispatchAndWait(Child());
    return null;
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'Child()')]);
  }

  Future<void> test_dispatchAndWaitAll() async {
    var code = '''$header$_child
class Other extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;
}

class Parent extends ReduxAction<AppState> with Sequential {
  @override
  Future<AppState?> reduce() async {
    await dispatchAndWaitAll([Other(), Child()]);
    return null;
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'Child()', correctionContains: "'dispatchAll'"),
    ]);
  }

  Future<void> test_waitActionType() async {
    var code = '''$header$_child
class Parent extends ReduxAction<AppState> with Sequential {
  @override
  Future<AppState?> reduce() async {
    await waitActionType(Child);
    return null;
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'Child);',
        length: 5,
        messageContainsAll: ["'waitActionType'"],
        correctionContains: "Try not waiting for 'Child'",
      ),
    ]);
  }

  Future<void> test_waitAllActionTypes() async {
    var code = '''$header$_child
class Parent extends ReduxAction<AppState> with Sequential {
  @override
  Future<AppState?> reduce() async {
    await waitAllActionTypes([Child]);
    return null;
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'Child]', length: 5)]);
  }

  Future<void> test_waitAllActions() async {
    var code = '''$header$_child
class Parent extends ReduxAction<AppState> with Sequential {
  @override
  Future<AppState?> reduce() async {
    var child = Child();
    dispatch(child);
    await waitAllActions([child]);
    return null;
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'child]', length: 5)]);
  }

  Future<void> test_returned() async {
    var code = '''$header$_child
class Parent extends ReduxAction<AppState> with Sequential {
  @override
  Future<void> before() => dispatchAndWait(Child());

  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [lintAt(code, 'Child()')]);
  }

  Future<void> test_sameConstantKey() async {
    var code = '''$header
const queue = 'items';

class Child extends ReduxAction<AppState> with Sequential {
  @override
  Object? sequentialKeyParams() => queue;

  @override
  AppState? reduce() => null;
}

class Parent extends ReduxAction<AppState> with Sequential {
  @override
  Object? sequentialKeyParams() => 'items';

  @override
  Future<AppState?> reduce() async {
    await dispatchAndWait(Child());
    return null;
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'Child()')]);
  }

  Future<void> test_runtimeTypeKey_sameType() async {
    var code = '''$header
class Parent extends ReduxAction<AppState> with Sequential {
  final bool isFirst;
  Parent(this.isFirst);

  @override
  Object? sequentialKeyParams() => runtimeType;

  @override
  Future<AppState?> reduce() async {
    if (isFirst) await dispatchAndWait(Parent(false));
    return null;
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'Parent(false)')]);
  }

  Future<void> test_keyFromBaseAction() async {
    var code = '''$header
abstract class AppAction extends ReduxAction<AppState> with Sequential {
  @override
  Object? sequentialKeyParams() => 'app';
}

class Child extends AppAction {
  @override
  AppState? reduce() => null;
}

class Parent extends AppAction {
  @override
  Future<AppState?> reduce() async {
    await dispatchAndWait(Child());
    return null;
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'Child()')]);
  }

  Future<void> test_fix_useDispatch() async {
    await assertFix(
      '''$header$_child
class Parent extends ReduxAction<AppState> with Sequential {
  @override
  Future<AppState?> reduce() async {
    await dispatchAndWait(Child());
    return null;
  }
}
''',
      UseDispatchWithoutWaiting.new,
      '''$header$_child
class Parent extends ReduxAction<AppState> with Sequential {
  @override
  Future<AppState?> reduce() async {
    dispatch(Child());
    return null;
  }
}
''',
    );
  }

  Future<void> test_fix_useDispatchAll() async {
    await assertFix(
      '''$header$_child
class Parent extends ReduxAction<AppState> with Sequential {
  @override
  Future<AppState?> reduce() async {
    await store.dispatchAndWaitAll([Child()]);
    return null;
  }
}
''',
      UseDispatchWithoutWaiting.new,
      '''$header$_child
class Parent extends ReduxAction<AppState> with Sequential {
  @override
  Future<AppState?> reduce() async {
    store.dispatchAll([Child()]);
    return null;
  }
}
''',
    );
  }

  Future<void> test_fix_resultIsUsed_notOffered() async {
    await assertFix(
      '''$header$_child
class Parent extends ReduxAction<AppState> with Sequential {
  @override
  Future<AppState?> reduce() async {
    var status = await dispatchAndWait(Child());
    print(status);
    return null;
  }
}
''',
      UseDispatchWithoutWaiting.new,
      null,
    );
  }

  // ---------------------------------------------------------------------------
  // Valid.

  Future<void> test_dispatchWithoutWaiting_isValid() async {
    await assertNoDiagnostics('''$header$_child
class Parent extends ReduxAction<AppState> with Sequential {
  @override
  AppState? reduce() {
    dispatch(Child());
    return null;
  }
}
''');
  }

  Future<void> test_notAwaited_isValid() async {
    await assertNoDiagnostics('''$header$_child
class Parent extends ReduxAction<AppState> with Sequential {
  @override
  AppState? reduce() {
    dispatchAndWait(Child()).then((_) {});
    return null;
  }
}
''');
  }

  Future<void> test_parentWithoutSequential_isValid() async {
    await assertNoDiagnostics('''$header$_child
class Parent extends ReduxAction<AppState> {
  @override
  Future<AppState?> reduce() async {
    await dispatchAndWait(Child());
    return null;
  }
}
''');
  }

  Future<void> test_childWithoutSequential_isValid() async {
    await assertNoDiagnostics('''$header
class Child extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;
}

class Parent extends ReduxAction<AppState> with Sequential {
  @override
  Future<AppState?> reduce() async {
    await dispatchAndWait(Child());
    return null;
  }
}
''');
  }

  Future<void> test_differentKeys_isValid() async {
    await assertNoDiagnostics('''$header
class Child extends ReduxAction<AppState> with Sequential {
  @override
  Object? sequentialKeyParams() => 'child';

  @override
  AppState? reduce() => null;
}

class Parent extends ReduxAction<AppState> with Sequential {
  @override
  Future<AppState?> reduce() async {
    await dispatchAndWait(Child());
    return null;
  }
}
''');
  }

  Future<void> test_runtimeTypeKey_differentTypes_isValid() async {
    await assertNoDiagnostics('''$header
abstract class AppAction extends ReduxAction<AppState> with Sequential {
  @override
  Object? sequentialKeyParams() => runtimeType;
}

class Child extends AppAction {
  @override
  AppState? reduce() => null;
}

class Parent extends AppAction {
  @override
  Future<AppState?> reduce() async {
    await dispatchAndWait(Child());
    return null;
  }
}
''');
  }

  Future<void> test_unknownKey_isValid() async {
    await assertNoDiagnostics('''$header
class Child extends ReduxAction<AppState> with Sequential {
  final String id;
  Child(this.id);

  @override
  Object? sequentialKeyParams() => id;

  @override
  AppState? reduce() => null;
}

class Parent extends ReduxAction<AppState> with Sequential {
  @override
  Object? sequentialKeyParams() => 'parent';

  @override
  Future<AppState?> reduce() async {
    await dispatchAndWait(Child('parent'));
    return null;
  }
}
''');
  }

  Future<void> test_inClosure_isValid() async {
    await assertNoDiagnostics('''$header$_child
class Parent extends ReduxAction<AppState> with Sequential {
  @override
  AppState? reduce() {
    Future<void> later() async => await dispatchAndWait(Child());
    print(later);
    return null;
  }
}
''');
  }

  Future<void> test_waitForOwnType_isValid() async {
    // Throws a StoreException instead of hanging, which is not this rule's job.
    await assertNoDiagnostics('''$header
class Parent extends ReduxAction<AppState> with Sequential {
  @override
  Future<AppState?> reduce() async {
    await waitActionType(Parent);
    return null;
  }
}
''');
  }
}

@reflectiveTest
class SequentialBeforeSuperNotFirstTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = SequentialBeforeSuperNotFirstRule();
    super.setUp();
  }

  Future<void> test_codeBeforeSuper() async {
    var code = '''$header
class A extends ReduxAction<AppState> with Sequential {
  @override
  Future<void> before() async {
    print('dispatched');
    await super.before();
  }

  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'before() async',
        length: 6,
        messageContainsAll: [
          "In an action with the 'Sequential' mixin, 'before' must call "
              "'await super.before()' as its first statement.",
        ],
      ),
    ]);
  }

  Future<void> test_superNotAwaited() async {
    var code = '''$header
class A extends ReduxAction<AppState> with Sequential {
  @override
  Future<void> before() async {
    super.before();
    print('turn');
  }

  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [lintAt(code, 'before() async', length: 6)]);
  }

  Future<void> test_sequentialInBaseAction() async {
    var code = '''$header
abstract class AppAction extends ReduxAction<AppState> with Sequential {}

class A extends AppAction {
  @override
  Future<void> before() async {
    await Future.delayed(Duration.zero);
    await super.before();
  }

  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [lintAt(code, 'before() async', length: 6)]);
  }

  // ---------------------------------------------------------------------------
  // Valid.

  Future<void> test_superFirst_isValid() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> with Sequential {
  @override
  Future<void> before() async {
    await super.before();
    print('turn');
  }

  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_expressionBody_isValid() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> with Sequential {
  @override
  Future<void> before() => super.before();

  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_noSuperCall_isValid() async {
    // Reported by the analyzer's `must_call_super`.
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> with Sequential {
  @override
  Future<void> before() async {
    print('turn');
  }

  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_withoutSequential_isValid() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> with CheckInternet {
  @override
  Future<void> before() async {
    print('dispatched');
    await super.before();
  }

  @override
  AppState? reduce() => null;
}
''');
  }
}

@reflectiveTest
class SequentialAfterSuperNotInFinallyTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = SequentialAfterSuperNotInFinallyRule();
    super.setUp();
  }

  Future<void> test_superAfterLast() async {
    var code = '''$header
class A extends ReduxAction<AppState> with Sequential {
  @override
  void after() {
    print('done');
    super.after();
  }

  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'super.after()',
        messageContainsAll: [
          "In an action with the 'Sequential' mixin, call 'super.after()' in a "
              "'finally' block, so that the queue is released even if 'after' throws.",
        ],
      ),
    ]);
  }

  Future<void> test_superAfterInTry() async {
    var code = '''$header
class A extends ReduxAction<AppState> with Sequential {
  @override
  void after() {
    try {
      print('done');
      super.after();
    } catch (_) {}
  }

  @override
  AppState? reduce() => null;
}
''';
    await assertDiagnostics(code, [lintAt(code, 'super.after()')]);
  }

  // ---------------------------------------------------------------------------
  // Valid.

  Future<void> test_inFinally_isValid() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> with Sequential {
  @override
  void after() {
    try {
      print('done');
    } finally {
      super.after();
    }
  }

  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_firstStatement_isValid() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> with Sequential {
  @override
  void after() {
    super.after();
    print('done');
  }

  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_expressionBody_isValid() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> with Sequential {
  @override
  void after() => super.after();

  @override
  AppState? reduce() => null;
}
''');
  }

  Future<void> test_withoutSequential_isValid() async {
    await assertNoDiagnostics('''$header
class A extends ReduxAction<AppState> with NonReentrant {
  @override
  void after() {
    print('done');
    super.after();
  }

  @override
  AppState? reduce() => null;
}
''');
  }
}
