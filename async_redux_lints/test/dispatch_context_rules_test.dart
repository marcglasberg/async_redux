import 'package:async_redux_lints/src/fixes/dispatch_context_fixes.dart';
import 'package:async_redux_lints/src/rules/dispatch_context_rules.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'widget_rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(PreferDispatchWithoutContextTest);
    defineReflectiveTests(PreferDispatchWithContextTest);
  });
}

/// The dispatch methods of AsyncRedux, other than the `dispatch` of `BuildContext`,
/// which the widget stub already declares.
const _dispatchStub = r'''
import 'package:flutter/widgets.dart';

class ActionStatus {}

extension BuildContextDispatchExtension on BuildContext {
  Object? dispatchAndWait(Object action) => throw 0;
  Object? dispatchSync(Object action) => throw 0;
}

extension StatefulWidgetExtensionForProviderAndConnector<St> on State {
  Object? dispatch(Object action) => throw 0;
  Object? dispatchAndWait(Object action) => throw 0;
  Object? dispatchSync(Object action) => throw 0;
}

extension StatelessWidgetExtensionForProviderAndConnector<St> on StatelessWidget {
  Object? dispatch(Object action) => throw 0;
  Object? dispatchAndWait(Object action) => throw 0;
  Object? dispatchSync(Object action) => throw 0;
}
''';

const _header =
    '''
import 'package:async_redux/dispatch.dart';
$widgetHeader
class Load {}

typedef UsesDispatch = ActionStatus;
''';

abstract class _DispatchContextTest extends AsyncReduxWidgetRuleTest {
  @override
  void setUp() {
    newPackage('async_redux').addFile('lib/dispatch.dart', _dispatchStub);
    super.setUp();
  }
}

@reflectiveTest
class PreferDispatchWithoutContextTest extends _DispatchContextTest {
  @override
  void setUp() {
    rule = PreferDispatchWithoutContextRule();
    super.setUp();
  }

  Future<void> test_testFiles() async {
    await assertNotReportedInTests('''$_header
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: () => context.dispatch(Load()));
  }
}
''');
  }

  Future<void> test_statelessWidget() async {
    var code = '''$_header
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: () => context.dispatch(Load()));
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'context.dispatch', length: 8)]);
  }

  Future<void> test_builderContext() async {
    var code = '''$_header
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (ctx) => GestureDetector(onTap: () => ctx.dispatchSync(Load())),
    );
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'ctx.dispatchSync', length: 4)]);
  }

  Future<void> test_state() async {
    var code = '''$_header
class W extends StatefulWidget {
  @override
  State<W> createState() => _WState();
}

class _WState extends State<W> {
  @override
  void initState() {
    super.initState();
    context.dispatchAndWait(Load());
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
''';
    await assertDiagnostics(code, [lintAt(code, 'context.dispatchAndWait', length: 8)]);
  }

  Future<void> test_statefulWidget() async {
    await assertNoDiagnostics('''$_header
class W extends StatefulWidget {
  void load(BuildContext context) => context.dispatch(Load());

  @override
  State<W> createState() => throw 0;
}
''');
  }

  Future<void> test_topLevelFunction() async {
    await assertNoDiagnostics('''$_header
void load(BuildContext context) => context.dispatch(Load());
''');
  }

  Future<void> test_staticMethod() async {
    await assertNoDiagnostics('''$_header
class W extends StatelessWidget {
  static void load(BuildContext context) => context.dispatch(Load());

  @override
  Widget build(BuildContext context) => const SizedBox();
}
''');
  }

  Future<void> test_classDeclaresDispatch() async {
    await assertNoDiagnostics('''$_header
class W extends StatelessWidget {
  void dispatch(Object action) {}

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: () => context.dispatch(Load()));
  }
}
''');
  }

  Future<void> test_localDispatch() async {
    await assertNoDiagnostics('''$_header
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    void dispatch(Object action) {}
    dispatch(Load());
    return GestureDetector(onTap: () => context.dispatch(Load()));
  }
}
''');
  }

  Future<void> test_topLevelDispatch() async {
    await assertNoDiagnostics('''$_header
void dispatch(Object action) {}

class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: () => context.dispatch(Load()));
  }
}
''');
  }

  Future<void> test_extensionNotImported() async {
    await assertNoDiagnostics('''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: () => context.dispatch(Object()));
  }
}
''');
  }

  Future<void> test_fix() async {
    await assertFix(
      '''$_header
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: () => context.dispatch(Load()));
  }
}
''',
      RemoveContextFromDispatch.new,
      '''$_header
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: () => dispatch(Load()));
  }
}
''',
    );
  }
}

@reflectiveTest
class PreferDispatchWithContextTest extends _DispatchContextTest {
  @override
  void setUp() {
    rule = PreferDispatchWithContextRule();
    super.setUp();
  }

  Future<void> test_statelessWidget() async {
    var code = '''$_header
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: () => dispatch(Load()));
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'dispatch(', length: 8)]);
  }

  Future<void> test_statelessWidgetMethodWithContext() async {
    var code = '''$_header
class W extends StatelessWidget {
  void load(BuildContext context) => dispatchSync(Load());

  @override
  Widget build(BuildContext context) => const SizedBox();
}
''';
    await assertDiagnostics(code, [lintAt(code, 'dispatchSync')]);
  }

  Future<void> test_statelessWidgetMethodWithoutContext() async {
    await assertNoDiagnostics('''$_header
class W extends StatelessWidget {
  void load() => dispatch(Load());

  @override
  Widget build(BuildContext context) => const SizedBox();
}
''');
  }

  Future<void> test_contextIsNotBuildContext() async {
    await assertNoDiagnostics('''$_header
class W extends StatelessWidget {
  void load(Object context) => dispatch(Load());

  @override
  Widget build(BuildContext context) => const SizedBox();
}
''');
  }

  Future<void> test_state() async {
    var code = '''$_header
class W extends StatefulWidget {
  @override
  State<W> createState() => _WState();
}

class _WState extends State<W> {
  @override
  void initState() {
    super.initState();
    dispatchAndWait(Load());
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
''';
    await assertDiagnostics(code, [lintAt(code, 'dispatchAndWait')]);
  }

  Future<void> test_this() async {
    var code = '''$_header
class W extends StatefulWidget {
  @override
  State<W> createState() => _WState();
}

class _WState extends State<W> {
  void load() => this.dispatch(Load());

  @override
  Widget build(BuildContext context) => const SizedBox();
}
''';
    await assertDiagnostics(code, [lintAt(code, 'this.dispatch')]);
  }

  Future<void> test_withContext() async {
    await assertNoDiagnostics('''$_header
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: () => context.dispatch(Load()));
  }
}
''');
  }

  Future<void> test_otherDispatch() async {
    await assertNoDiagnostics('''$_header
class W extends StatelessWidget {
  void dispatch(Object action) {}

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: () => dispatch(Load()));
  }
}
''');
  }

  Future<void> test_fix() async {
    await assertFix(
      '''$_header
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: () => dispatch(Load()));
  }
}
''',
      AddContextToDispatch.new,
      '''$_header
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: () => context.dispatch(Load()));
  }
}
''',
    );
  }

  Future<void> test_fixThis() async {
    await assertFix(
      '''$_header
class W extends StatefulWidget {
  @override
  State<W> createState() => _WState();
}

class _WState extends State<W> {
  void load() => this.dispatch(Load());

  @override
  Widget build(BuildContext context) => const SizedBox();
}
''',
      AddContextToDispatch.new,
      '''$_header
class W extends StatefulWidget {
  @override
  State<W> createState() => _WState();
}

class _WState extends State<W> {
  void load() => context.dispatch(Load());

  @override
  Widget build(BuildContext context) => const SizedBox();
}
''',
    );
  }
}
