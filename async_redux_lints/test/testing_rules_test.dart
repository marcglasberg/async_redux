import 'package:async_redux_lints/src/fixes/testing_fixes.dart';
import 'package:async_redux_lints/src/rules/testing_rules.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ExpectWithoutWaitingTest);
    defineReflectiveTests(VmCreateFromReusedFactoryTest);
    defineReflectiveTests(ActionStatusDetailsInProductionTest);
  });
}

/// The start of every test file of `expect_without_waiting`.
const _testHeader = '''$header
class SyncAction extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;
}

class AsyncAction extends ReduxAction<AppState> {
  @override
  Future<AppState?> reduce() async => null;
}

class AsyncBefore extends ReduxAction<AppState> with CheckInternet {
  @override
  AppState? reduce() => null;
}

// Members of the real `Store` that the main stub doesn't declare.
extension StoreStub on Store<AppState> {
  AppState get state => throw 0;
  Future<AppState?> waitActionType(Type actionType) => throw 0;
}

void expect(Object? actual, Object? matcher) {}
void test(String description, void Function() body) {}
''';

@reflectiveTest
class ExpectWithoutWaitingTest extends AsyncReduxRuleTest {
  @override
  String get testFilePath => '$testPackageTestPath/a_test.dart';

  @override
  void setUp() {
    rule = ExpectWithoutWaitingRule();
    super.setUp();
  }

  Future<void> test_asyncReduce() async {
    var code = '''$_testHeader
void main() {
  test('a', () {
    var store = Store<AppState>();
    store.dispatch(AsyncAction());
    expect(store.state, 1);
  });
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'store.dispatch(AsyncAction())',
        messageContainsAll: [
          "'AsyncAction' is async, but 'store.state' is checked below without "
              "waiting for the action to finish.",
        ],
        correctionContains: "'await store.dispatchAndWait(...)'",
      ),
    ]);
  }

  Future<void> test_asyncBeforeFromMixin() async {
    var code = '''$_testHeader
void main() {
  test('a', () async {
    var store = Store<AppState>();
    store.dispatch(AsyncBefore());
    var x = 1;
    expect(store.state.hashCode, x);
  });
}
''';
    await assertDiagnostics(code, [lintAt(code, 'store.dispatch(AsyncBefore())')]);
  }

  Future<void> test_storeInField() async {
    var code = '''$_testHeader
class Setup {
  final store = Store<AppState>();
}

void check(Setup setup) {
  setup.store.dispatch(AsyncAction());
  expect(setup.store.state, 1);
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'setup.store.dispatch(AsyncAction())',
        messageContainsAll: ["'setup.store.state'"],
      ),
    ]);
  }

  Future<void> test_expectAfterEnclosingStatement() async {
    var code = '''$_testHeader
void check(Store<AppState> store, bool flag) {
  if (flag) {
    store.dispatch(AsyncAction());
  }
  expect(store.state, 1);
}
''';
    await assertDiagnostics(code, [lintAt(code, 'store.dispatch(AsyncAction())')]);
  }

  Future<void> test_expectInNestedStatement() async {
    var code = '''$_testHeader
void check(Store<AppState> store, bool flag) {
  store.dispatch(AsyncAction());
  if (flag) {
    expect(store.state, 1);
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'store.dispatch(AsyncAction())')]);
  }

  Future<void> test_waitsAfterwardsWithoutCheckingAgain() async {
    var code = '''$_testHeader
Future<void> check(Store<AppState> store) async {
  store.dispatch(AsyncAction());
  expect(store.state, 1);
  await store.waitActionType(AsyncAction);
}
''';
    await assertDiagnostics(code, [lintAt(code, 'store.dispatch(AsyncAction())')]);
  }

  // ---------------------------------------------------------------------------
  // Valid.

  Future<void> test_checksAgainAfterWaiting_isValid() async {
    await assertNoDiagnostics('''$_testHeader
Future<void> check(Store<AppState> store) async {
  store.dispatch(AsyncAction());
  // The state didn't change yet.
  expect(store.state, 1);
  await Future.delayed(const Duration(milliseconds: 50));
  expect(store.state, 2);
}
''');
  }

  Future<void> test_fakeAsyncElapse_isValid() async {
    await assertNoDiagnostics('''$_testHeader
class FakeAsync {
  void elapse(Duration duration) {}
  void flushMicrotasks() {}
}

void check(Store<AppState> store, FakeAsync fake) {
  store.dispatch(AsyncAction());
  fake.elapse(Duration.zero);
  expect(store.state, 1);
  store.dispatch(AsyncAction());
  fake.flushMicrotasks();
  expect(store.state, 2);
}
''');
  }

  Future<void> test_dispatchAndWait_isValid() async {
    await assertNoDiagnostics('''$_testHeader
Future<void> check(Store<AppState> store) async {
  await store.dispatchAndWait(AsyncAction());
  expect(store.state, 1);
}
''');
  }

  Future<void> test_awaitedDispatch_isValid() async {
    await assertNoDiagnostics('''$_testHeader
Future<void> check(Store<AppState> store) async {
  await store.dispatch(AsyncAction());
  expect(store.state, 1);
}
''');
  }

  Future<void> test_awaitInBetween_isValid() async {
    await assertNoDiagnostics('''$_testHeader
Future<void> check(Store<AppState> store) async {
  store.dispatch(AsyncAction());
  await store.waitActionType(AsyncAction);
  expect(store.state, 1);
}
''');
  }

  Future<void> test_awaitInExpect_isValid() async {
    await assertNoDiagnostics('''$_testHeader
Future<void> check(Store<AppState> store) async {
  store.dispatch(AsyncAction());
  expect(await store.waitActionType(AsyncAction), store.state);
}
''');
  }

  Future<void> test_syncAction_isValid() async {
    await assertNoDiagnostics('''$_testHeader
void check(Store<AppState> store) {
  store.dispatch(SyncAction());
  expect(store.state, 1);
}
''');
  }

  Future<void> test_expectWithoutState_isValid() async {
    await assertNoDiagnostics('''$_testHeader
void check(Store<AppState> store) {
  store.dispatch(AsyncAction());
  expect(store.isWaiting(AsyncAction), true);
}
''');
  }

  Future<void> test_otherStore_isValid() async {
    await assertNoDiagnostics('''$_testHeader
void check(Store<AppState> store, Store<AppState> other) {
  store.dispatch(AsyncAction());
  expect(other.state, 1);
}
''');
  }

  Future<void> test_expectBeforeDispatch_isValid() async {
    await assertNoDiagnostics('''$_testHeader
void check(Store<AppState> store) {
  expect(store.state, 1);
  store.dispatch(AsyncAction());
}
''');
  }

  Future<void> test_expectInClosure_isValid() async {
    await assertNoDiagnostics('''$_testHeader
void check(Store<AppState> store) {
  store.dispatch(AsyncAction());
  test('a', () => expect(store.state, 1));
}
''');
  }

  Future<void> test_inLibDirectory_isValid() async {
    var path = '$testPackageLibPath/a.dart';
    newFile(path, '''$_testHeader
void check(Store<AppState> store) {
  store.dispatch(AsyncAction());
  expect(store.state, 1);
}
''');
    await assertNoDiagnosticsInFile(path);
  }

  // ---------------------------------------------------------------------------
  // Fix.

  Future<void> test_fix_inAsyncFunction() async {
    await assertFix(
      '''$_testHeader
Future<void> check(Store<AppState> store) async {
  store.dispatch(AsyncAction(), notify: false);
  expect(store.state, 1);
}
''',
      UseAwaitDispatchAndWait.new,
      '''$_testHeader
Future<void> check(Store<AppState> store) async {
  await store.dispatchAndWait(AsyncAction(), notify: false);
  expect(store.state, 1);
}
''',
    );
  }

  Future<void> test_fix_makesClosureAsync() async {
    await assertFix(
      '''$_testHeader
void main() {
  test('a', () {
    var store = Store<AppState>();
    (store.dispatch(AsyncAction()));
    expect(store.state, 1);
  });
}
''',
      UseAwaitDispatchAndWait.new,
      '''$_testHeader
void main() {
  test('a', () async {
    var store = Store<AppState>();
    await (store.dispatchAndWait(AsyncAction()));
    expect(store.state, 1);
  });
}
''',
    );
  }

  Future<void> test_fix_makesVoidFunctionAsync() async {
    await assertFix(
      '''$_testHeader
void check(Store<AppState> store) {
  store.dispatch(AsyncAction());
  expect(store.state, 1);
}
''',
      UseAwaitDispatchAndWait.new,
      '''$_testHeader
void check(Store<AppState> store) async {
  await store.dispatchAndWait(AsyncAction());
  expect(store.state, 1);
}
''',
    );
  }

  Future<void> test_fix_notOfferedWhenReturnTypeIsNotVoid() async {
    await assertFix(
      '''$_testHeader
int check(Store<AppState> store) {
  store.dispatch(AsyncAction());
  expect(store.state, 1);
  return 0;
}
''',
      UseAwaitDispatchAndWait.new,
      null,
    );
  }
}

/// A stub of `Vm` and `VmFactory` of package `async_redux`.
const _vmStub = r'''
import 'package:async_redux/async_redux.dart';

abstract class Vm {
  static Model createFrom<St, T, Model extends Vm>(
    Store<St> store,
    VmFactory<St, T, Model> factory,
  ) => throw 0;
}

abstract class VmFactory<St, T, Model extends Vm> {
  Model? fromStore();
}
''';

const _vmHeader =
    '''import 'package:async_redux/view_model.dart';
$header
class ViewModel extends Vm {}

class Factory extends VmFactory<AppState, Object, ViewModel> {
  @override
  ViewModel? fromStore() => ViewModel();
}

void test(String description, void Function() body) {}
void setUp(void Function() body) {}
''';

@reflectiveTest
class VmCreateFromReusedFactoryTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    newPackage('async_redux').addFile('lib/view_model.dart', _vmStub);
    rule = VmCreateFromReusedFactoryRule();
    super.setUp();
  }

  Future<void> test_sameFunction() async {
    var code = '''$_vmHeader
void check(Store<AppState> store) {
  var factory = Factory();
  Vm.createFrom(store, factory);
  Vm.createFrom(store, factory);
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'factory);',
        occurrence: 2,
        length: 7,
        messageContainsAll: [
          "The factory 'factory' was already used by 'Vm.createFrom', but each "
              "factory instance can only be used once.",
        ],
      ),
    ]);
  }

  Future<void> test_threeCalls() async {
    var code = '''$_vmHeader
void check(Store<AppState> store, Factory factory) {
  Vm.createFrom(store, factory);
  Vm.createFrom(store, factory);
  Vm.createFrom(store, (factory));
}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'factory);', occurrence: 2, length: 7),
      lintAt(code, 'factory));', length: 7),
    ]);
  }

  Future<void> test_differentTests() async {
    var code = '''$_vmHeader
void main() {
  final factory = Factory();
  test('a', () => Vm.createFrom(Store<AppState>(), factory));
  test('b', () => Vm.createFrom(Store<AppState>(), factory));
}
''';
    await assertDiagnostics(code, [lintAt(code, 'factory));', occurrence: 2, length: 7)]);
  }

  Future<void> test_topLevelVariable() async {
    var code = '''$_vmHeader
final factory = Factory();

void a(Store<AppState> store) => Vm.createFrom(store, factory);
void b(Store<AppState> store) => Vm.createFrom(store, factory);
''';
    await assertDiagnostics(code, [lintAt(code, 'factory);', occurrence: 2, length: 7)]);
  }

  Future<void> test_assignedButNotInBetween() async {
    var code = '''$_vmHeader
void check(Store<AppState> store) {
  var factory = Factory();
  Vm.createFrom(store, factory);
  Vm.createFrom(store, factory);
  factory = Factory();
}
''';
    await assertDiagnostics(code, [lintAt(code, 'factory);', occurrence: 2, length: 7)]);
  }

  // ---------------------------------------------------------------------------
  // Valid.

  Future<void> test_newFactoryEachTime_isValid() async {
    await assertNoDiagnostics('''$_vmHeader
void check(Store<AppState> store) {
  Vm.createFrom(store, Factory());
  Vm.createFrom(store, Factory());
}
''');
  }

  Future<void> test_differentFactories_isValid() async {
    await assertNoDiagnostics('''$_vmHeader
void check(Store<AppState> store) {
  var factory1 = Factory();
  var factory2 = Factory();
  Vm.createFrom(store, factory1);
  Vm.createFrom(store, factory2);
}
''');
  }

  Future<void> test_reassignedInBetween_isValid() async {
    await assertNoDiagnostics('''$_vmHeader
void check(Store<AppState> store) {
  var factory = Factory();
  Vm.createFrom(store, factory);
  factory = Factory();
  Vm.createFrom(store, factory);
}
''');
  }

  Future<void> test_assignedInSetUp_isValid() async {
    await assertNoDiagnostics('''$_vmHeader
void main() {
  late Factory factory;
  setUp(() {
    factory = Factory();
  });
  test('a', () => Vm.createFrom(Store<AppState>(), factory));
  test('b', () => Vm.createFrom(Store<AppState>(), factory));
}
''');
  }

  Future<void> test_explicitGetter_isValid() async {
    await assertNoDiagnostics('''$_vmHeader
Factory get factory => Factory();

void check(Store<AppState> store) {
  Vm.createFrom(store, factory);
  Vm.createFrom(store, factory);
}
''');
  }

  Future<void> test_exclusiveBranches_isValid() async {
    await assertNoDiagnostics('''$_vmHeader
void a(Store<AppState> store, Factory factory, bool flag) {
  if (flag) {
    Vm.createFrom(store, factory);
  } else {
    Vm.createFrom(store, factory);
  }
}

void b(Store<AppState> store, Factory factory, bool flag) {
  flag ? Vm.createFrom(store, factory) : Vm.createFrom(store, factory);
}

void c(Store<AppState> store, Factory factory, int value) {
  switch (value) {
    case 1:
      Vm.createFrom(store, factory);
    case 2:
      Vm.createFrom(store, factory);
  }
}
''');
  }
}

/// A stub of `ActionStatus` of package `async_redux`, with its `hasFinishedMethod...`
/// getters. It's in its own library, since the `ActionStatus` of the main stub
/// doesn't have them.
const _actionStatusStub = r'''
class ActionStatus {
  final bool hasFinishedMethodBefore = false;
  final bool hasFinishedMethodReduce = false;
  final bool hasFinishedMethodAfter = false;
  bool get isCompletedOk => true;
}
''';

const _actionStatusHeader = r'''
import 'package:async_redux/action_status.dart';

class MyStatus {
  bool get hasFinishedMethodAfter => true;
}
''';

@reflectiveTest
class ActionStatusDetailsInProductionTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    newPackage('async_redux').addFile('lib/action_status.dart', _actionStatusStub);
    rule = ActionStatusDetailsInProductionRule();
    super.setUp();
  }

  Future<void> test_allGetters() async {
    var code = '''$_actionStatusHeader
void check(ActionStatus status) {
  print(status.hasFinishedMethodBefore);
  print(status.hasFinishedMethodReduce);
  if (status.hasFinishedMethodAfter) print('done');
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'hasFinishedMethodBefore',
        occurrence: 1,
        messageContainsAll: [
          "'hasFinishedMethodBefore' is meant for tests and debugging.",
        ],
        correctionContains: "'isCompletedOk'",
      ),
      lintAt(code, 'hasFinishedMethodReduce'),
      lintAt(code, 'hasFinishedMethodAfter', occurrence: 2),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Valid.

  Future<void> test_otherGetters_isValid() async {
    await assertNoDiagnostics('''$_actionStatusHeader
void check(ActionStatus status, MyStatus other) {
  print(status.isCompletedOk);
  print(other.hasFinishedMethodAfter);
}
''');
  }

  Future<void> test_inTestDirectory_isValid() async {
    var path = '$testPackageTestPath/a_test.dart';
    newFile(path, '''$_actionStatusHeader
void check(ActionStatus status) {
  print(status.hasFinishedMethodAfter);
}
''');
    await assertNoDiagnosticsInFile(path);
  }
}
