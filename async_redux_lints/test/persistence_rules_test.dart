import 'package:async_redux_lints/src/fixes/persistence_fixes.dart';
import 'package:async_redux_lints/src/rules/persistence_rules.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ImplementsPersistorTest);
    defineReflectiveTests(ThrowInReadStateTest);
    defineReflectiveTests(InitialStateNotSavedTest);
  });
}

/// The members of `Persistor`, for classes that implement it.
const _persistorMembers = r'''
  @override
  Future<AppState?> readState() async => null;
  @override
  Future<void> deleteState() async {}
  @override
  Future<void> persistDifference({
    required AppState? lastPersistedState,
    required AppState newState,
  }) async {}
  @override
  Future<void> saveInitialState(AppState state) async {}
  @override
  Duration? get throttle => null;
  @override
  Object? wrapError(Object error, StackTrace stackTrace) => error;
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  (Object, StackTrace)? getAndRemoveFirstError() => null;
''';

@reflectiveTest
class ImplementsPersistorTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = ImplementsPersistorRule();
    super.setUp();
  }

  Future<void> test_implements() async {
    var code =
        '''$header
class MyPersistor implements Persistor<AppState> {
$_persistorMembers}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'Persistor<AppState>', messageContainsAll: ["'Persistor'"]),
    ]);
  }

  Future<void> test_abstractClass() async {
    var code = '''$header
abstract class BasePersistor implements Persistor<AppState> {}
''';
    await assertDiagnostics(code, [lintAt(code, 'Persistor<AppState>')]);
  }

  Future<void> test_implementsSubclass() async {
    var code = '''$header
class MyPersistor extends Persistor<AppState> {}

abstract class OtherPersistor implements MyPersistor {}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'MyPersistor {}',
        length: 'MyPersistor'.length,
        messageContainsAll: ["'MyPersistor'"],
      ),
    ]);
  }

  Future<void> test_extends() async {
    await assertNoDiagnostics('''$header
class MyPersistor extends Persistor<AppState> {}
''');
  }

  Future<void> test_alreadyExtends() async {
    await assertNoDiagnostics('''$header
class MyPersistor extends Persistor<AppState> {}

class OtherPersistor extends MyPersistor implements Persistor<AppState> {}
''');
  }

  Future<void> test_otherInterface() async {
    await assertNoDiagnostics('''$header
abstract class Saver {}

abstract class MySaver implements Saver {}
''');
  }

  Future<void> test_fix() async {
    await assertFix(
      '''$header
class MyPersistor implements Persistor<AppState> {
$_persistorMembers}
''',
      ExtendPersistor.new,
      '''$header
class MyPersistor extends Persistor<AppState> {
$_persistorMembers}
''',
    );
  }

  Future<void> test_fixWithMixin() async {
    await assertFix(
      '''$header
mixin Logs {}

abstract class MyPersistor with Logs implements Persistor<AppState> {}
''',
      ExtendPersistor.new,
      '''$header
mixin Logs {}

abstract class MyPersistor extends Persistor<AppState> with Logs {}
''',
    );
  }

  Future<void> test_fixWithOtherInterfaces() async {
    await assertFix(
      '''$header
abstract class Saver {}

abstract class MyPersistor implements Saver, Persistor<AppState> {}
''',
      ExtendPersistor.new,
      '''$header
abstract class Saver {}

abstract class MyPersistor extends Persistor<AppState> implements Saver {}
''',
    );
  }

  Future<void> test_fixWithOtherInterfacesAndMixin() async {
    await assertFix(
      '''$header
mixin Logs {}
abstract class Saver {}

abstract class MyPersistor with Logs implements Persistor<AppState>, Saver {}
''',
      ExtendPersistor.new,
      '''$header
mixin Logs {}
abstract class Saver {}

abstract class MyPersistor extends Persistor<AppState> with Logs implements Saver {}
''',
    );
  }

  Future<void> test_noFixWhenExtendingAnotherClass() async {
    await assertFix(
      '''$header
abstract class Base {}

abstract class MyPersistor extends Base implements Persistor<AppState> {}
''',
      ExtendPersistor.new,
      null,
    );
  }

  Future<void> test_noFixWhenConstructorHasRequiredParameters() async {
    await assertFix(
      '''$header
class MyPersistor extends Persistor<AppState> {
  MyPersistor(String name);
}

abstract class OtherPersistor implements MyPersistor {}
''',
      ExtendPersistor.new,
      null,
    );
  }
}

@reflectiveTest
class ThrowInReadStateTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = ThrowInReadStateRule();
    super.setUp();
  }

  Future<void> test_throw() async {
    var code = '''$header
class MyPersistor extends Persistor<AppState> {
  @override
  Future<AppState?> readState() async {
    throw UserException('Could not read');
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(code, "throw UserException('Could not read')"),
    ]);
  }

  Future<void> test_rethrow() async {
    var code = '''$header
class MyPersistor extends Persistor<AppState> {
  @override
  Future<AppState?> readState() async {
    try {
      return await _read();
    } on FormatException {
      await deleteState();
      rethrow;
    }
  }

  Future<AppState?> _read() async => null;
}
''';
    await assertDiagnostics(code, [lintAt(code, 'rethrow')]);
  }

  Future<void> test_expressionBody() async {
    var code = '''$header
class MyPersistor extends Persistor<AppState> {
  @override
  Future<AppState?> readState() => throw Exception('Oops');
}
''';
    await assertDiagnostics(code, [lintAt(code, "throw Exception('Oops')")]);
  }

  Future<void> test_inMixin() async {
    var code = '''$header
mixin Reads on Persistor<AppState> {
  @override
  Future<AppState?> readState() async {
    throw Exception('Oops');
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, "throw Exception('Oops')")]);
  }

  Future<void> test_caughtLocally() async {
    await assertNoDiagnostics('''$header
class MyPersistor extends Persistor<AppState> {
  @override
  Future<AppState?> readState() async {
    try {
      throw FormatException();
    } on FormatException catch (error) {
      addError(UserException('Could not read').addCause(error));
      return null;
    }
  }
}
''');
  }

  Future<void> test_inClosure() async {
    await assertNoDiagnostics('''$header
class MyPersistor extends Persistor<AppState> {
  @override
  Future<AppState?> readState() async {
    void fail() => throw Exception('Oops');
    var check = () => throw Exception('Oops');
    if (identical(fail, check)) return null;
    return null;
  }
}
''');
  }

  Future<void> test_otherMethod() async {
    await assertNoDiagnostics('''$header
class MyPersistor extends Persistor<AppState> {
  @override
  Future<void> persistDifference({
    required AppState? lastPersistedState,
    required AppState newState,
  }) async {
    throw UserException('Could not save');
  }
}
''');
  }

  Future<void> test_testFile() async {
    var file = newFile('$testPackageRootPath/test/persistor_test.dart', '''$header
class FailingPersistor extends Persistor<AppState> {
  @override
  Future<AppState?> readState() async {
    throw Exception('Oops');
  }
}
''');
    await assertNoDiagnosticsInFile(file.path);
  }

  Future<void> test_notAPersistor() async {
    await assertNoDiagnostics('''$header
class Reader {
  Future<AppState?> readState() async {
    throw Exception('Oops');
  }
}
''');
  }

  Future<void> test_fixThrow() async {
    await assertFix(
      '''$header
class MyPersistor extends Persistor<AppState> {
  @override
  Future<AppState?> readState() async {
    throw UserException('Could not read');
  }
}
''',
      AddErrorAndReturnNull.new,
      '''$header
class MyPersistor extends Persistor<AppState> {
  @override
  Future<AppState?> readState() async {
    addError(UserException('Could not read'));
    return null;
  }
}
''',
    );
  }

  Future<void> test_fixRethrow() async {
    await assertFix(
      '''$header
class MyPersistor extends Persistor<AppState> {
  @override
  Future<AppState?> readState() async {
    try {
      return await _read();
    } catch (error, stackTrace) {
      rethrow;
    }
  }

  Future<AppState?> _read() async => null;
}
''',
      AddErrorAndReturnNull.new,
      '''$header
class MyPersistor extends Persistor<AppState> {
  @override
  Future<AppState?> readState() async {
    try {
      return await _read();
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      return null;
    }
  }

  Future<AppState?> _read() async => null;
}
''',
    );
  }

  Future<void> test_noFixForRethrowWithoutCatchParameter() async {
    await assertFix(
      '''$header
class MyPersistor extends Persistor<AppState> {
  @override
  Future<AppState?> readState() async {
    try {
      return await _read();
    } on FormatException {
      rethrow;
    }
  }

  Future<AppState?> _read() async => null;
}
''',
      AddErrorAndReturnNull.new,
      null,
    );
  }

  Future<void> test_noFixWhenNotAsync() async {
    await assertFix(
      '''$header
class MyPersistor extends Persistor<AppState> {
  @override
  Future<AppState?> readState() {
    throw UserException('Could not read');
  }
}
''',
      AddErrorAndReturnNull.new,
      null,
    );
  }
}

@reflectiveTest
class InitialStateNotSavedTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = InitialStateNotSavedRule();
    super.setUp();
  }

  static const _persistor = '''
class MyPersistor extends Persistor<AppState> {}
''';

  Future<void> test_ifNull() async {
    var code = '''$header$_persistor
Future<Store<AppState>> start() async {
  var persistor = MyPersistor();
  var initialState = await persistor.readState();
  if (initialState == null) {
    initialState = AppState();
  }
  return Store<AppState>(initialState: initialState);
}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'AppState()', correctionContains: 'persistor.saveInitialState'),
    ]);
  }

  Future<void> test_ifNullWithSave() async {
    await assertNoDiagnostics('''$header$_persistor
Future<Store<AppState>> start() async {
  var persistor = MyPersistor();
  var initialState = await persistor.readState();
  if (initialState == null) {
    initialState = AppState();
    await persistor.saveInitialState(initialState);
  }
  return Store<AppState>(initialState: initialState);
}
''');
  }

  Future<void> test_ifNullWithPersistDifference() async {
    await assertNoDiagnostics('''$header$_persistor
Future<Store<AppState>> start() async {
  var persistor = MyPersistor();
  var initialState = await persistor.readState();
  if (initialState == null) {
    initialState = AppState();
    await persistor.persistDifference(lastPersistedState: null, newState: initialState);
  }
  return Store<AppState>(initialState: initialState);
}
''');
  }

  Future<void> test_ifNullBlockless() async {
    var code = '''$header$_persistor
Future<Store<AppState>> start() async {
  var persistor = MyPersistor();
  var initialState = await persistor.readState();
  if (null == initialState) initialState = AppState();
  return Store<AppState>(initialState: initialState);
}
''';
    await assertDiagnostics(code, [lintAt(code, 'AppState()')]);
  }

  Future<void> test_assignedLater() async {
    var code = '''$header$_persistor
late MyPersistor persistor;

Future<Store<AppState>> start() async {
  persistor = MyPersistor();
  AppState? initialState;
  initialState = await persistor.readState();
  if (initialState == null) {
    initialState = AppState();
  }
  return Store<AppState>(initialState: initialState);
}
''';
    await assertDiagnostics(code, [lintAt(code, 'AppState()')]);
  }

  Future<void> test_ifNotNullAssignment() async {
    await assertNoDiagnostics('''$header$_persistor
Future<Store<AppState>> start() async {
  var persistor = MyPersistor();
  var initialState = await persistor.readState();
  if (initialState != null) {
    initialState = AppState();
  }
  return Store<AppState>(initialState: initialState);
}
''');
  }

  Future<void> test_ifNullAssignment() async {
    var code = '''$header$_persistor
Future<Store<AppState>> start() async {
  var persistor = MyPersistor();
  var initialState = await persistor.readState();
  initialState ??= AppState();
  return Store<AppState>(initialState: initialState);
}
''';
    await assertDiagnostics(code, [lintAt(code, 'AppState()')]);
  }

  Future<void> test_ifNullOperatorOnVariable() async {
    var code = '''$header$_persistor
Future<Store<AppState>> start() async {
  var persistor = MyPersistor();
  var initialState = await persistor.readState();
  return Store<AppState>(initialState: initialState ?? AppState());
}
''';
    await assertDiagnostics(code, [lintAt(code, 'AppState()')]);
  }

  Future<void> test_ifNullOperatorOnReadState() async {
    var code = '''$header$_persistor
Future<Store<AppState>> start() async {
  var persistor = MyPersistor();
  var initialState = (await persistor.readState()) ?? AppState();
  return Store<AppState>(initialState: initialState);
}
''';
    await assertDiagnostics(code, [lintAt(code, 'AppState()')]);
  }

  Future<void> test_noDefaultState() async {
    await assertNoDiagnostics('''$header$_persistor
Future<Store<AppState>?> start() async {
  var persistor = MyPersistor();
  var initialState = await persistor.readState();
  if (initialState == null) return null;
  return Store<AppState>(initialState: initialState);
}
''');
  }

  Future<void> test_insidePersistor() async {
    await assertNoDiagnostics('''$header$_persistor
class LoggingPersistor extends Persistor<AppState> {
  final MyPersistor persistor;
  LoggingPersistor(this.persistor);

  @override
  Future<AppState?> readState() async {
    var state = await persistor.readState();
    return state ?? AppState();
  }
}
''');
  }

  Future<void> test_notAwaited() async {
    await assertNoDiagnostics('''$header$_persistor
Future<AppState?> start() {
  var persistor = MyPersistor();
  return persistor.readState().then((state) => state ?? AppState());
}
''');
  }

  Future<void> test_fixAssignment() async {
    await assertFix(
      '''$header$_persistor
Future<Store<AppState>> start() async {
  var persistor = MyPersistor();
  var initialState = await persistor.readState();
  if (initialState == null) {
    initialState = AppState();
  }
  return Store<AppState>(initialState: initialState);
}
''',
      AddSaveInitialState.new,
      '''$header$_persistor
Future<Store<AppState>> start() async {
  var persistor = MyPersistor();
  var initialState = await persistor.readState();
  if (initialState == null) {
    initialState = AppState();
    await persistor.saveInitialState(initialState);
  }
  return Store<AppState>(initialState: initialState);
}
''',
    );
  }

  Future<void> test_fixIfNullAssignment() async {
    await assertFix(
      '''$header$_persistor
Future<Store<AppState>> start() async {
  var persistor = MyPersistor();
  var initialState = await persistor.readState();
  initialState ??= AppState();
  return Store<AppState>(initialState: initialState);
}
''',
      AddSaveInitialState.new,
      '''$header$_persistor
Future<Store<AppState>> start() async {
  var persistor = MyPersistor();
  var initialState = await persistor.readState();
  if (initialState == null) {
    initialState = AppState();
    await persistor.saveInitialState(initialState);
  }
  return Store<AppState>(initialState: initialState);
}
''',
    );
  }

  Future<void> test_noFixForIfNullOperator() async {
    await assertFix(
      '''$header$_persistor
Future<Store<AppState>> start() async {
  var persistor = MyPersistor();
  var initialState = await persistor.readState();
  return Store<AppState>(initialState: initialState ?? AppState());
}
''',
      AddSaveInitialState.new,
      null,
    );
  }

  Future<void> test_noFixWhenPersistorIsNotAVariable() async {
    await assertFix(
      '''$header$_persistor
Future<Store<AppState>> start() async {
  var initialState = await MyPersistor().readState();
  initialState ??= AppState();
  return Store<AppState>(initialState: initialState);
}
''',
      AddSaveInitialState.new,
      null,
    );
  }
}
