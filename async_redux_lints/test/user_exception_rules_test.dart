import 'package:async_redux_lints/src/fixes/error_fixes.dart';
import 'package:async_redux_lints/src/rules/user_exception_rules.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'rule_test_base.dart';
import 'widget_rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(UserExceptionOutsideActionTest);
    defineReflectiveTests(UserExceptionOutsideActionWidgetTest);
    defineReflectiveTests(UserExceptionWithoutCauseTest);
  });
}

@reflectiveTest
class UserExceptionOutsideActionTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = UserExceptionOutsideActionRule();
    super.setUp();
  }

  Future<void> test_beforeAndReduce() async {
    await assertNoDiagnostics('''$header
class MyAction extends ReduxAction<AppState> {
  @override
  void before() {
    throw UserException('Before');
  }

  @override
  AppState? reduce() => throw UserException('Reduce');
}
''');
  }

  Future<void> test_after() async {
    var code = '''$header
class MyAction extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;

  @override
  void after() {
    throw UserException('Oops');
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        "throw UserException('Oops')",
        messageContainsAll: ["thrown in the 'after' method of an action"],
      ),
    ]);
    await assertFix(code, DispatchUserExceptionAction.new, '''$header
class MyAction extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;

  @override
  void after() {
    dispatch(UserExceptionAction('Oops'));
  }
}
''');
  }

  Future<void> test_afterWithAddCause() async {
    var code = '''$header
class MyAction extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;

  @override
  void after() {
    throw UserException('Oops').addCause('Reason');
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(code, "throw UserException('Oops').addCause('Reason')"),
    ]);
    await assertFix(code, DispatchUserExceptionAction.new, '''$header
class MyAction extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;

  @override
  void after() {
    dispatch(UserExceptionAction.from(UserException('Oops').addCause('Reason')));
  }
}
''');
  }

  Future<void> test_afterCaught() async {
    await assertNoDiagnostics('''$header
class MyAction extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;

  @override
  void after() {
    try {
      throw UserException('Oops');
    } on UserException {
      print('Caught');
    }
  }
}
''');
  }

  Future<void> test_afterInClosure() async {
    await assertNoDiagnostics('''$header
class MyAction extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;

  @override
  void after() {
    var f = () => throw UserException('Oops');
    print(f);
  }
}
''');
  }

  Future<void> test_otherErrorInAfter() async {
    await assertNoDiagnostics('''$header
class MyAction extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;

  @override
  void after() {
    throw 'Oops';
  }
}
''');
  }

  Future<void> test_topLevelFunction() async {
    await assertNoDiagnostics('''$header
void validate(String text) {
  if (text.isEmpty) throw UserException('Empty');
}
''');
  }

  Future<void> test_fixNotOfferedWhenValueIsUsed() async {
    var code = '''$header
class MyAction extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;

  @override
  void after() {
    var value = state.hashCode > 0 ? 1 : throw UserException('Oops');
    print(value);
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, "throw UserException('Oops')")]);
    await assertFix(code, DispatchUserExceptionAction.new, null);
  }
}

/// A stub of the `VmFactory` of package `async_redux`.
const _vmFactoryStub = r'''
import 'package:flutter/widgets.dart';
import 'async_redux.dart' show ReduxAction;
import 'widgets.dart';

abstract class VmFactory<St, T extends Widget?, Model extends Vm> {
  Object? Function(ReduxAction<St> action) get dispatch => throw 0;
  Model? fromStore();
}
''';

const _widgetHeader =
    '''
import 'package:async_redux/async_redux.dart'
    hide BuildContext, BuildContextExtensionForProviderAndConnector;
import 'package:async_redux/vm_factory.dart';
$widgetHeader
typedef UsesVmFactory = VmFactory;
''';

@reflectiveTest
class UserExceptionOutsideActionWidgetTest extends AsyncReduxWidgetRuleTest {
  @override
  void setUp() {
    rule = UserExceptionOutsideActionRule();
    newPackage('async_redux').addFile('lib/vm_factory.dart', _vmFactoryStub);
    super.setUp();
  }

  Future<void> test_callbackInBuild() async {
    var code = '''$_widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: () => throw UserException('Oops'));
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        "throw UserException('Oops')",
        messageContainsAll: ["thrown in a widget is not shown"],
      ),
    ]);
    await assertFix(code, DispatchUserExceptionAction.new, '''$_widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: () => context.dispatch(UserExceptionAction('Oops')));
  }
}
''');
  }

  Future<void> test_builderContext() async {
    var code = '''$_widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (ctx) => GestureDetector(onTap: () => throw UserException('Oops')),
    );
  }
}
''';
    await assertFix(code, DispatchUserExceptionAction.new, '''$_widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (ctx) => GestureDetector(onTap: () => ctx.dispatch(UserExceptionAction('Oops'))),
    );
  }
}
''');
  }

  Future<void> test_widgetMethodWithoutContext() async {
    var code = '''$_widgetHeader
class W extends StatelessWidget {
  void save() {
    throw UserException('Oops');
  }

  @override
  Widget build(BuildContext context) => GestureDetector(onTap: save);
}
''';
    await assertDiagnostics(code, [lintAt(code, "throw UserException('Oops')")]);
    await assertFix(code, DispatchUserExceptionAction.new, null);
  }

  Future<void> test_stateMethod() async {
    var code = '''$_widgetHeader
class W extends StatefulWidget {
  @override
  State<W> createState() => _WState();
}

class _WState extends State<W> {
  void save() {
    throw UserException('Oops', reason: 'Some reason');
  }

  @override
  Widget build(BuildContext context) => GestureDetector(onTap: save);
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        "throw UserException('Oops', reason: 'Some reason')",
        messageContainsAll: ["thrown in a 'State' is not shown"],
      ),
    ]);
    await assertFix(code, DispatchUserExceptionAction.new, '''$_widgetHeader
class W extends StatefulWidget {
  @override
  State<W> createState() => _WState();
}

class _WState extends State<W> {
  void save() {
    context.dispatch(UserExceptionAction('Oops', reason: 'Some reason'));
  }

  @override
  Widget build(BuildContext context) => GestureDetector(onTap: save);
}
''');
  }

  Future<void> test_caughtInWidget() async {
    await assertNoDiagnostics('''$_widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    try {
      throw UserException('Oops');
    } catch (_) {
      return const SizedBox();
    }
  }
}
''');
  }

  Future<void> test_vmFactory() async {
    var code = '''$_widgetHeader
class MyVm extends Vm {
  final VoidCallback onSave;
  MyVm({required this.onSave});
}

class Factory extends VmFactory<AppState, Widget, MyVm> {
  @override
  MyVm fromStore() => MyVm(onSave: () => throw UserException('Oops'));
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        "throw UserException('Oops')",
        messageContainsAll: ["thrown in a 'VmFactory' is not shown"],
      ),
    ]);
    await assertFix(code, DispatchUserExceptionAction.new, '''$_widgetHeader
class MyVm extends Vm {
  final VoidCallback onSave;
  MyVm({required this.onSave});
}

class Factory extends VmFactory<AppState, Widget, MyVm> {
  @override
  MyVm fromStore() => MyVm(onSave: () => dispatch(UserExceptionAction('Oops')));
}
''');
  }

  Future<void> test_vm() async {
    var code = '''$_widgetHeader
class MyVm extends Vm {
  void save() => throw UserException('Oops');
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        "throw UserException('Oops')",
        messageContainsAll: ['thrown in a view-model is not shown'],
      ),
    ]);
    await assertFix(code, DispatchUserExceptionAction.new, null);
  }
}

@reflectiveTest
class UserExceptionWithoutCauseTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = UserExceptionWithoutCauseRule();
    super.setUp();
  }

  Future<void> test_catch() async {
    var code = '''$header
class MyAction extends ReduxAction<AppState> {
  final String text = '';

  @override
  AppState? reduce() {
    try {
      int.parse(text);
    } catch (error) {
      throw UserException('Please enter a valid number');
    }
    return null;
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        "UserException('Please enter a valid number')",
        correctionContains: "'.addCause(error)'",
      ),
    ]);
    await assertFix(code, AddCause.new, '''$header
class MyAction extends ReduxAction<AppState> {
  final String text = '';

  @override
  AppState? reduce() {
    try {
      int.parse(text);
    } catch (error) {
      throw UserException('Please enter a valid number').addCause(error);
    }
    return null;
  }
}
''');
  }

  Future<void> test_catchWithAddCause() async {
    await assertNoDiagnostics('''$header
void f(String text) {
  try {
    int.parse(text);
  } catch (e) {
    throw UserException('Invalid').addProps({}).addCause(e);
  }
}
''');
  }

  Future<void> test_addCauseOnVariable() async {
    await assertNoDiagnostics('''$header
void f(String text) {
  try {
    int.parse(text);
  } catch (e) {
    var exception = UserException('Invalid');
    throw exception.addCause(e);
  }
}
''');
  }

  Future<void> test_causeIsAnotherUserException() async {
    await assertNoDiagnostics('''$header
void f(String text) {
  try {
    int.parse(text);
  } catch (e) {
    throw UserException('Invalid').addCause(UserException('Not a number'));
  }
}
''');
  }

  Future<void> test_onWithoutCatch() async {
    var code = '''$header
void f(String text) {
  try {
    int.parse(text);
  } on FormatException {
    throw UserException('Invalid');
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, "UserException('Invalid')")]);
    await assertFix(code, AddCause.new, '''$header
void f(String text) {
  try {
    int.parse(text);
  } on FormatException catch (error) {
    throw UserException('Invalid').addCause(error);
  }
}
''');
  }

  Future<void> test_onWithoutCatchErrorNameUsed() async {
    await assertFix(
      '''$header
void f(String text, Object error) {
  try {
    int.parse(text);
  } on FormatException {
    print(error);
    throw UserException('Invalid');
  }
}
''',
      AddCause.new,
      '''$header
void f(String text, Object error) {
  try {
    int.parse(text);
  } on FormatException catch (e) {
    print(error);
    throw UserException('Invalid').addCause(e);
  }
}
''',
    );
  }

  Future<void> test_inClosureInsideCatch() async {
    await assertNoDiagnostics('''$header
void f(String text) {
  try {
    int.parse(text);
  } catch (e) {
    var create = () => UserException('Invalid');
    print(create);
  }
}
''');
  }

  Future<void> test_inTryBlock() async {
    await assertNoDiagnostics('''$header
void f(String text) {
  try {
    throw UserException('Invalid');
  } catch (e) {
    print(e);
  }
}
''');
  }

  Future<void> test_notInCatch() async {
    await assertNoDiagnostics('''$header
class MyAction extends ReduxAction<AppState> {
  @override
  AppState? reduce() => throw UserException('Oops');
}
''');
  }

  Future<void> test_wrapError() async {
    var code = '''$header
class MyAction extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;

  @override
  Object? wrapError(Object e, StackTrace stackTrace) => UserException('Oops');
}
''';
    await assertDiagnostics(code, [
      lintAt(code, "UserException('Oops')", correctionContains: "'.addCause(e)'"),
    ]);
    await assertFix(code, AddCause.new, '''$header
class MyAction extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;

  @override
  Object? wrapError(Object e, StackTrace stackTrace) => UserException('Oops').addCause(e);
}
''');
  }

  Future<void> test_wrapErrorWithWildcard() async {
    var code = '''$header
class MyAction extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;

  @override
  Object? wrapError(_, __) => UserException('Oops');
}
''';
    await assertDiagnostics(code, [lintAt(code, "UserException('Oops')")]);
    await assertFix(code, AddCause.new, null);
  }

  Future<void> test_wrapErrorInMixin() async {
    var code = '''$header
mixin ShowUserException on ReduxAction<AppState> {
  @override
  Object? wrapError(error, stackTrace) => UserException('Oops');
}
''';
    await assertDiagnostics(code, [lintAt(code, "UserException('Oops')")]);
  }

  Future<void> test_wrapErrorOfPersistor() async {
    var code = '''$header
class MyPersistor extends Persistor<AppState> {
  @override
  Object? wrapError(Object error, StackTrace stackTrace) =>
      UserException('Could not save');
}
''';
    await assertDiagnostics(code, [lintAt(code, "UserException('Could not save')")]);
  }

  Future<void> test_wrapErrorOfOtherClass() async {
    await assertNoDiagnostics('''$header
class Other {
  Object? wrapError(Object error, StackTrace stackTrace) => UserException('Oops');
}
''');
  }

  Future<void> test_observe() async {
    var code = '''$header
class MyObserver extends GlobalErrorObserver<AppState> {
  @override
  Object? observe() {
    if (error is UserException) return error;
    return UserException('Something went wrong');
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(code, "UserException('Something went wrong')"),
    ]);
    await assertFix(code, AddCause.new, '''$header
class MyObserver extends GlobalErrorObserver<AppState> {
  @override
  Object? observe() {
    if (error is UserException) return error;
    return UserException('Something went wrong').addCause(error);
  }
}
''');
  }

  Future<void> test_observeWithLocalError() async {
    await assertFix(
      '''$header
class MyObserver extends GlobalErrorObserver<AppState> {
  @override
  Object? observe() {
    var error = 'Something went wrong';
    return UserException(error);
  }
}
''',
      AddCause.new,
      '''$header
class MyObserver extends GlobalErrorObserver<AppState> {
  @override
  Object? observe() {
    var error = 'Something went wrong';
    return UserException(error).addCause(this.error);
  }
}
''',
    );
  }
}
