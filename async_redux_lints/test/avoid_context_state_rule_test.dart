import 'package:async_redux_lints/src/fixes/state_access_fixes.dart';
import 'package:async_redux_lints/src/rules/avoid_context_state_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'widget_rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidContextStateTest);
    defineReflectiveTests(ContextStateInInitStateTest);
  });
}

const initStateCode = '''$widgetHeader
class W extends StatefulWidget {
  @override
  State<W> createState() => _WState();
}

class _WState extends State<W> {
  late AppState initial;

  @override
  void initState() {
    super.initState();
    initial = context.state;
  }

  @override
  Widget build(BuildContext context) => const Text('');
}
''';

@reflectiveTest
class AvoidContextStateTest extends AsyncReduxWidgetRuleTest {
  @override
  void setUp() {
    rule = AvoidContextStateRule();
    super.setUp();
  }

  Future<void> test_directField() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text('\${context.state.counter}');
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'context.state',
        messageContainsAll: [
          "'context.state' rebuilds the widget when any part of the state changes",
        ],
      ),
    ]);
    await assertFix(code, UseContextSelect.new, '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text('\${context.select((st) => st.counter)}');
  }
}
''');
    await assertFix(code, UseContextRead.new, null);
  }

  Future<void> test_twoDirectFields() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text('\${context.state.counter} \${context.state.name}');
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'context.state', occurrence: 1),
      lintAt(code, 'context.state', occurrence: 2),
    ]);
    await assertFix(code, UseContextSelect.new, '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text('\${context.select((st) => st.counter)} \${context.state.name}');
  }
}
''');
  }

  Future<void> test_variable() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var state = context.state;
    return Text('\${state.counter} \${state.counter + 1}');
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'context.state')]);
    await assertFix(code, UseContextSelect.new, '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var counter = context.select((st) => st.counter);
    return Text('\${counter} \${counter + 1}');
  }
}
''');
  }

  Future<void> test_variable_twoFields() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.state;
    return Text('\${state.name} \${state.counter} \${state.name}');
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'context.state')]);
    await assertFix(code, UseContextSelect.new, '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final name = context.select((st) => st.name);
    final counter = context.select((st) => st.counter);
    return Text('\${name} \${counter} \${name}');
  }
}
''');
  }

  Future<void> test_typedVariable() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AppState state = context.state;
    return Text(state.name);
  }
}
''';
    await assertFix(code, UseContextSelect.new, '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final String name = context.select((st) => st.name);
    return Text(name);
  }
}
''');
  }

  Future<void> test_typedVariable_twoFields() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    AppState state = context.state;
    return Text('\${state.counter}\${state.name}');
  }
}
''';
    await assertFix(code, UseContextSelect.new, '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    int counter = context.select((st) => st.counter);
    String name = context.select((st) => st.name);
    return Text('\${counter}\${name}');
  }
}
''');
  }

  Future<void> test_variable_nameConflict_noFix() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  final String name = '';
  @override
  Widget build(BuildContext context) {
    var state = context.state;
    return Text('\${state.counter}\${state.name}' + name);
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'context.state')]);
    await assertFix(code, UseContextSelect.new, null);
  }

  Future<void> test_getState() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(context.getState<AppState>().name);
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'context.getState<AppState>()',
        messageContainsAll: ["'context.getState' rebuilds the widget"],
      ),
    ]);
    await assertFix(code, UseContextSelect.new, '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(context.getSelect<AppState, String>((st) => st.name));
  }
}
''');
  }

  Future<void> test_stateOfStatefulWidget() async {
    var code = '''$widgetHeader
class W extends StatefulWidget {
  @override
  State<W> createState() => _WState();
}

class _WState extends State<W> {
  @override
  Widget build(BuildContext context) => Text(context.state.name);
}
''';
    await assertDiagnostics(code, [lintAt(code, 'context.state')]);
  }

  Future<void> test_builder() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Builder(builder: (context) => Text(context.state.name));
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'context.state')]);
    await assertFix(code, UseContextSelect.new, '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Builder(builder: (context) => Text(context.select((st) => st.name)));
  }
}
''');
  }

  Future<void> test_wholeState_noFix() async {
    var code = '''$widgetHeader
void use(AppState state) {}

class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    use(context.state);
    var state = context.state;
    use(state);
    return Text(state.name);
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'context.state', occurrence: 1),
      lintAt(code, 'context.state', occurrence: 2),
    ]);
    await assertFix(code, UseContextSelect.new, null);
    await assertFix(code, UseContextRead.new, null);
  }

  Future<void> test_methodCall_noFix() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text('\${context.state.sum()}');
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'context.state')]);
    await assertFix(code, UseContextSelect.new, null);
  }

  Future<void> test_callback() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: () => print(context.state.counter));
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'context.state')]);
    await assertFix(code, UseContextSelect.new, null);
    await assertFix(code, UseContextRead.new, '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: () => print(context.read().counter));
  }
}
''');
  }

  Future<void> test_callback_getState() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: () => print(context.getState<AppState>()));
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'context.getState<AppState>()')]);
    await assertFix(code, UseContextRead.new, '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: () => print(context.getRead<AppState>()));
  }
}
''');
  }

  Future<void> test_initState_isIgnored() async {
    await assertNoDiagnostics(initStateCode);
  }

  Future<void> test_dispose() async {
    var code = '''$widgetHeader
class W extends StatefulWidget {
  @override
  State<W> createState() => _WState();
}

class _WState extends State<W> {
  @override
  void dispose() {
    print(context.state.name);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Text('');
}
''';
    await assertDiagnostics(code, [lintAt(code, 'context.state')]);
    await assertFix(code, UseContextSelect.new, null);
    await assertFix(code, UseContextRead.new, '''$widgetHeader
class W extends StatefulWidget {
  @override
  State<W> createState() => _WState();
}

class _WState extends State<W> {
  @override
  void dispose() {
    print(context.read().name);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Text('');
}
''');
  }

  Future<void> test_helperMethod_noFix() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  Widget buildHeader(BuildContext context) => Text(context.state.name);

  @override
  Widget build(BuildContext context) => buildHeader(context);
}
''';
    await assertDiagnostics(code, [lintAt(code, 'context.state')]);
    await assertFix(code, UseContextSelect.new, null);
    await assertFix(code, UseContextRead.new, null);
  }

  Future<void> test_closureInBuild_noFix() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(children: [1, 2].map((i) => Text(context.state.name)).toList());
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'context.state')]);
    await assertFix(code, UseContextSelect.new, null);
    await assertFix(code, UseContextRead.new, null);
  }

  Future<void> test_callbackWithContext_noFix() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  final void Function(BuildContext context)? onInit;
  const W({this.onInit});

  @override
  Widget build(BuildContext context) =>
      W(onInit: (context) => print(context.state.name));
}
''';
    await assertDiagnostics(code, [lintAt(code, 'context.state')]);
    await assertFix(code, UseContextSelect.new, null);
    await assertFix(code, UseContextRead.new, null);
  }

  Future<void> test_extensionDeclaringState_isIgnored() async {
    await assertNoDiagnostics('''$widgetHeader
extension OtherExtension on BuildContext {
  AppState get otherState => this.getState<AppState>();
}
''');
  }
}

@reflectiveTest
class ContextStateInInitStateTest extends AsyncReduxWidgetRuleTest {
  @override
  void setUp() {
    rule = ContextStateInInitStateRule();
    super.setUp();
  }

  Future<void> test_initState() async {
    var code = initStateCode;
    await assertDiagnostics(code, [
      lintAt(
        code,
        'context.state',
        messageContainsAll: ["'context.state' can't be used in 'initState'"],
      ),
    ]);
    await assertFix(
      code,
      UseContextRead.new,
      code.replaceFirst('initial = context.state;', 'initial = context.read();'),
    );
  }

  Future<void> test_getState() async {
    var code = '''$widgetHeader
class W extends StatefulWidget {
  @override
  State<W> createState() => _WState();
}

class _WState extends State<W> {
  @override
  void initState() {
    super.initState();
    print(context.getState<AppState>().name);
  }

  @override
  Widget build(BuildContext context) => const Text('');
}
''';
    await assertDiagnostics(code, [lintAt(code, 'context.getState<AppState>()')]);
    await assertFix(
      code,
      UseContextRead.new,
      code.replaceFirst('context.getState<AppState>()', 'context.getRead<AppState>()'),
    );
  }

  Future<void> test_closureInInitState_isIgnored() async {
    await assertNoDiagnostics('''$widgetHeader
class W extends StatefulWidget {
  @override
  State<W> createState() => _WState();
}

class _WState extends State<W> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => print(context.state.name));
  }

  @override
  Widget build(BuildContext context) => const Text('');
}
''');
  }

  Future<void> test_initStateNotInState_isIgnored() async {
    await assertNoDiagnostics('''$widgetHeader
class W {
  void initState(BuildContext context) => print(context.state.name);
}
''');
  }

  Future<void> test_otherMethods_isIgnored() async {
    await assertNoDiagnostics('''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Text(context.state.name);
}
''');
  }
}
