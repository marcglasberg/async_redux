import 'package:async_redux_lints/src/fixes/error_fixes.dart';
import 'package:async_redux_lints/src/rules/global_error_observer_rules.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(DispatchInGlobalErrorObserverTest);
    defineReflectiveTests(ThrowInGlobalErrorObserverTest);
    defineReflectiveTests(GlobalErrorObserverWithoutEnvironmentTest);
  });
}

@reflectiveTest
class DispatchInGlobalErrorObserverTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = DispatchInGlobalErrorObserverRule();
    super.setUp();
  }

  Future<void> test_storeDispatch() async {
    var code = '''$header
class MyObserver extends GlobalErrorObserver<AppState> {
  @override
  Object? observe() {
    store.dispatch(UserExceptionAction('Oops'));
    return error;
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(code, "store.dispatch(UserExceptionAction('Oops'))"),
    ]);
  }

  Future<void> test_storeDispatchSyncInHelperMethod() async {
    var code = '''$header
class MyObserver extends GlobalErrorObserver<AppState> {
  @override
  Object? observe() {
    _show();
    return error;
  }

  void _show() => store.dispatchSync(UserExceptionAction('Oops'));
}
''';
    await assertDiagnostics(code, [
      lintAt(code, "store.dispatchSync(UserExceptionAction('Oops'))"),
    ]);
  }

  Future<void> test_actionDispatch() async {
    var code = '''$header
class MyObserver extends GlobalErrorObserver<AppState> {
  @override
  Object? observe() {
    action!.dispatch(UserExceptionAction('Oops'));
    return error;
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(code, "action!.dispatch(UserExceptionAction('Oops'))"),
    ]);
  }

  Future<void> test_microtask() async {
    await assertNoDiagnostics('''$header
class MyObserver extends GlobalErrorObserver<AppState> {
  @override
  Object? observe() {
    Future.microtask(() => store.dispatch(UserExceptionAction('Oops')));
    return error;
  }
}
''');
  }

  Future<void> test_notAnObserver() async {
    await assertNoDiagnostics('''$header
class Other {
  final Store<AppState> store = Store<AppState>();

  Object? observe() {
    store.dispatch(UserExceptionAction('Oops'));
    return null;
  }
}
''');
  }

  Future<void> test_otherDispatchMethod() async {
    await assertNoDiagnostics('''$header
class MyObserver extends GlobalErrorObserver<AppState> {
  void dispatch(Object action) {}

  @override
  Object? observe() {
    dispatch(error);
    return error;
  }
}
''');
  }
}

@reflectiveTest
class ThrowInGlobalErrorObserverTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = ThrowInGlobalErrorObserverRule();
    super.setUp();
  }

  Future<void> test_throwStatement() async {
    var code = '''$header
class MyObserver extends GlobalErrorObserver<AppState> {
  @override
  Object? observe() {
    if (error is UserException) return error;
    throw UserException('Something went wrong').addCause(error);
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(code, "throw UserException('Something went wrong').addCause(error)"),
    ]);
    await assertFix(code, ReturnInsteadOfThrow.new, '''$header
class MyObserver extends GlobalErrorObserver<AppState> {
  @override
  Object? observe() {
    if (error is UserException) return error;
    return UserException('Something went wrong').addCause(error);
  }
}
''');
  }

  Future<void> test_arrowBody() async {
    var code = '''$header
class MyObserver extends GlobalErrorObserver<AppState> {
  @override
  Object? observe() => throw error;
}
''';
    await assertDiagnostics(code, [lintAt(code, 'throw error')]);
    await assertFix(code, ReturnInsteadOfThrow.new, '''$header
class MyObserver extends GlobalErrorObserver<AppState> {
  @override
  Object? observe() => error;
}
''');
  }

  Future<void> test_fixNotOfferedInConditional() async {
    var code = '''$header
class MyObserver extends GlobalErrorObserver<AppState> {
  @override
  Object? observe() => error is UserException ? error : throw error;
}
''';
    await assertDiagnostics(code, [lintAt(code, 'throw error')]);
    await assertFix(code, ReturnInsteadOfThrow.new, null);
  }

  Future<void> test_caught() async {
    await assertNoDiagnostics('''$header
class MyObserver extends GlobalErrorObserver<AppState> {
  @override
  Object? observe() {
    try {
      throw 'Oops';
    } catch (e) {
      return e;
    }
  }
}
''');
  }

  Future<void> test_inClosure() async {
    await assertNoDiagnostics('''$header
class MyObserver extends GlobalErrorObserver<AppState> {
  @override
  Object? observe() {
    var f = () => throw 'Oops';
    print(f);
    return error;
  }
}
''');
  }

  Future<void> test_otherMethod() async {
    await assertNoDiagnostics('''$header
class MyObserver extends GlobalErrorObserver<AppState> {
  @override
  Object? observe() => error;

  void other() => throw 'Oops';
}
''');
  }

  Future<void> test_notAnObserver() async {
    await assertNoDiagnostics('''$header
class Other {
  Object? observe() => throw 'Oops';
}
''');
  }
}

@reflectiveTest
class GlobalErrorObserverWithoutEnvironmentTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = GlobalErrorObserverWithoutEnvironmentRule();
    super.setUp();
  }

  static const _observer = '''$header
class MyObserver extends GlobalErrorObserver<AppState> {
  @override
  Object? observe() => error;
}
''';

  Future<void> test_withoutEnvironment() async {
    var code = '''$_observer
var store = Store<AppState>(
  initialState: AppState(),
  globalErrorObserver: (store) => MyObserver(),
);
''';
    await assertDiagnostics(code, [lintAt(code, 'Store<AppState>')]);
  }

  Future<void> test_withEnvironment() async {
    await assertNoDiagnostics('''$_observer
var store = Store<AppState>(
  initialState: AppState(),
  globalErrorObserver: (store) => MyObserver(),
  environment: 'production',
);
''');
  }

  Future<void> test_withoutObserver() async {
    await assertNoDiagnostics('''$_observer
var store = Store<AppState>(initialState: AppState());
''');
  }
}
