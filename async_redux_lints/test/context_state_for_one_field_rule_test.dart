import 'package:async_redux_lints/src/fixes/state_access_fixes.dart';
import 'package:async_redux_lints/src/rules/context_state_for_one_field_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'widget_rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ContextStateForOneFieldTest);
  });
}

@reflectiveTest
class ContextStateForOneFieldTest extends AsyncReduxWidgetRuleTest {
  @override
  void setUp() {
    rule = ContextStateForOneFieldRule();
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
        messageContainsAll: ["Only the 'counter' field of the state is used"],
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
  }

  Future<void> test_sameFieldTwice() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var a = context.state.counter;
    var b = context.state.counter;
    return Text('\$a\$b');
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'context.state', occurrence: 1),
      lintAt(code, 'context.state', occurrence: 2),
    ]);
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

  Future<void> test_variable_nameConflict_noFix() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  final String name = '';
  @override
  Widget build(BuildContext context) {
    var state = context.state;
    return Text(state.name + name);
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
    await assertDiagnostics(code, [lintAt(code, 'context.getState<AppState>()')]);
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
  }

  Future<void> test_twoFields_isIgnored() async {
    await assertNoDiagnostics('''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var state = context.state;
    return Text('\${context.state.counter} \${state.name}');
  }
}
''');
  }

  Future<void> test_wholeState_isIgnored() async {
    await assertNoDiagnostics('''$widgetHeader
void use(AppState state) {}

class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    use(context.state);
    var state = context.state;
    use(state);
    return Text(context.state.name);
  }
}
''');
  }

  Future<void> test_methodCall_isIgnored() async {
    await assertNoDiagnostics('''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text('\${context.state.sum()}');
  }
}
''');
  }

  Future<void> test_callback_isIgnored() async {
    await assertNoDiagnostics('''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: () => print(context.state.counter));
  }
}
''');
  }

  Future<void> test_notBuild_isIgnored() async {
    await assertNoDiagnostics('''$widgetHeader
class W extends StatelessWidget {
  Widget buildHeader(BuildContext context) => Text(context.state.name);

  @override
  Widget build(BuildContext context) => buildHeader(context);
}
''');
  }
}
