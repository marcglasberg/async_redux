import 'package:async_redux_lints/src/fixes/state_access_fixes.dart';
import 'package:async_redux_lints/src/rules/avoid_context_state_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'widget_rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidContextStateTest);
    defineReflectiveTests(ContextStateInInitStateTest);
    defineReflectiveTests(ContextStateInInitStateActionStatusTest);
    defineReflectiveTests(ContextInDisposeTest);
    defineReflectiveTests(ContextInSelectorTest);
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

  /// The name is used elsewhere in the enclosing function, but not in the block
  /// that declares the variable, like in a test file where `main()` contains many
  /// tests.
  Future<void> test_variable_nameUsedOutsideBlock() async {
    var code = '''$widgetHeader
void use({String? name}) {}

Widget main() {
  var name = 'other';
  use(name: name);
  return Builder(builder: (context) {
    final state = context.state;
    return Text('Regular: \${state.name}');
  });
}
''';
    await assertDiagnostics(code, [lintAt(code, 'context.state')]);
    await assertFix(code, UseContextSelect.new, '''$widgetHeader
void use({String? name}) {}

Widget main() {
  var name = 'other';
  use(name: name);
  return Builder(builder: (context) {
    final name = context.select((st) => st.name);
    return Text('Regular: \${name}');
  });
}
''');
  }

  Future<void> test_variable_propertyAndNamedArgument_noConflict() async {
    var code = '''$widgetHeader
void use({String? name}) {}

class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    use(name: AppState().name);
    var state = context.state;
    return Text(state.name);
  }
}
''';
    await assertFix(code, UseContextSelect.new, '''$widgetHeader
void use({String? name}) {}

class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    use(name: AppState().name);
    var name = context.select((st) => st.name);
    return Text(name);
  }
}
''');
  }

  Future<void> test_variable_closureParameterInBlock_suffix() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var state = context.state;
    var names = ['a'].map((name) => name).toList();
    return Text(state.name + names.first);
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'context.state')]);
    await assertFix(code, UseContextSelect.new, '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var name2 = context.select((st) => st.name);
    var names = ['a'].map((name) => name).toList();
    return Text(name2 + names.first);
  }
}
''');
  }

  Future<void> test_variable_parameterOfEnclosingFunction_suffix() async {
    var code = '''$widgetHeader
Widget build(String name) => Builder(builder: (context) {
  var state = context.state;
  return Text(state.name + name);
});
''';
    await assertDiagnostics(code, [lintAt(code, 'context.state')]);
    await assertFix(code, UseContextSelect.new, '''$widgetHeader
Widget build(String name) => Builder(builder: (context) {
  var name2 = context.select((st) => st.name);
  return Text(name2 + name);
});
''');
  }

  Future<void> test_variable_fieldWithSameName_suffix() async {
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
    await assertFix(code, UseContextSelect.new, '''$widgetHeader
class W extends StatelessWidget {
  final String name = '';
  @override
  Widget build(BuildContext context) {
    var counter = context.select((st) => st.counter);
    var name2 = context.select((st) => st.name);
    return Text('\${counter}\${name2}' + name);
  }
}
''');
  }

  Future<void> test_variable_suffixAlsoUsed() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var userName = '';
    var userName2 = '';
    final state = context.state;
    return Text(state.user.name + userName + userName2);
  }
}
''';
    await assertFix(code, UseContextSelect.new, '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var userName = '';
    var userName2 = '';
    final userName3 = context.select((st) => st.user.name);
    return Text(userName3 + userName + userName2);
  }
}
''');
  }

  Future<void> test_variable_deepPath() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var user = '';
    final state = context.state;
    return Text('Name: \${state.user.name}' + user);
  }
}
''';
    await assertFix(code, UseContextSelect.new, '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var user = '';
    final userName = context.select((st) => st.user.name);
    return Text('Name: \${userName}' + user);
  }
}
''');
  }

  Future<void> test_variable_twoDeepPaths() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AppState state = context.state;
    return Text('\${state.user.name} \${state.user.age} \${state.user.name}');
  }
}
''';
    await assertFix(code, UseContextSelect.new, '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final String userName = context.select((st) => st.user.name);
    final int userAge = context.select((st) => st.user.age);
    return Text('\${userName} \${userAge} \${userName}');
  }
}
''');
  }

  Future<void> test_variable_pathIsPrefixOfAnother() async {
    var code = '''$widgetHeader
void use(User user) {}

class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var state = context.state;
    use(state.user);
    return Text(state.user.name);
  }
}
''';
    await assertFix(code, UseContextSelect.new, '''$widgetHeader
void use(User user) {}

class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var user = context.select((st) => st.user);
    use(user);
    return Text(user.name);
  }
}
''');
  }

  Future<void> test_variable_stopsAtMethodAndNullAware() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var state = context.state;
    return Text(state.user.name.trim() + (state.maybeUser?.name ?? ''));
  }
}
''';
    await assertFix(code, UseContextSelect.new, '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var userName = context.select((st) => st.user.name);
    var maybeUser = context.select((st) => st.maybeUser);
    return Text(userName.trim() + (maybeUser?.name ?? ''));
  }
}
''');
  }

  Future<void> test_direct_deepPath() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Text(context.state.user.name + (context.state.maybeUser?.name ?? ''));
}
''';
    await assertFix(code, UseContextSelect.new, '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Text(context.select((st) => st.user.name) + (context.state.maybeUser?.name ?? ''));
}
''');
  }

  Future<void> test_direct_nullAware() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Text(context.state.maybeUser?.name ?? '');
}
''';
    await assertFix(
      code,
      UseContextSelect.new,
      code.replaceFirst(
        'context.state.maybeUser',
        'context.select((st) => st.maybeUser)',
      ),
    );
  }

  Future<void> test_variable_assignedField_noFix() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var state = context.state;
    state.user.nickname = '';
    return Text(state.name);
  }
}
''';
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

  Future<void> test_didUpdateWidget() async {
    var code = '''$widgetHeader
class W extends StatefulWidget {
  @override
  State<W> createState() => _WState();
}

class _WState extends State<W> {
  // The mock 'State' doesn't declare it.
  void didUpdateWidget(W oldWidget) {
    print(context.state.name);
  }

  @override
  Widget build(BuildContext context) => const Text('');
}
''';
    await assertDiagnostics(code, [lintAt(code, 'context.state')]);
    await assertFix(code, UseContextSelect.new, null);
    await assertFix(
      code,
      UseContextRead.new,
      code.replaceFirst('context.state.name', 'context.read().name'),
    );
  }

  Future<void> test_didChangeDependencies() async {
    var code = '''$widgetHeader
class W extends StatefulWidget {
  @override
  State<W> createState() => _WState();
}

class _WState extends State<W> {
  // The mock 'State' doesn't declare it.
  void didChangeDependencies() {
    print(context.state.name);
  }

  @override
  Widget build(BuildContext context) => const Text('');
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'context.state',
        correctionContains:
            "In 'didChangeDependencies', it also makes 'didChangeDependencies' run "
            "again. Try using 'context.select'",
      ),
    ]);
    await assertFix(
      code,
      UseContextSelect.new,
      code.replaceFirst('context.state.name', 'context.select((st) => st.name)'),
    );
    await assertFix(
      code,
      UseContextRead.new,
      code.replaceFirst('context.state.name', 'context.read().name'),
    );
  }

  Future<void> test_didChangeDependencies_otherContext() async {
    var code = '''$widgetHeader
class W extends StatefulWidget {
  @override
  State<W> createState() => _WState();
}

class _WState extends State<W> {
  BuildContext get other => throw 0;

  // The mock 'State' doesn't declare it.
  void didChangeDependencies() {
    print(other.state.name);
  }

  @override
  Widget build(BuildContext context) => const Text('');
}
''';
    await assertDiagnostics(code, [lintAt(code, 'other.state')]);
    await assertFix(code, UseContextSelect.new, null);
  }

  Future<void> test_postFrameCallback() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => print(context.state.name));
    return const Text('');
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'context.state')]);
    await assertFix(code, UseContextSelect.new, null);
    await assertFix(
      code,
      UseContextRead.new,
      code.replaceFirst('context.state.name', 'context.read().name'),
    );
  }

  Future<void> test_itemBuilder() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemBuilder: (context, index) => Text(context.state.name),
    );
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'context.state',
        correctionContains: "Try wrapping the item in a 'Builder'",
      ),
    ]);
    await assertFix(code, UseContextSelect.new, null);
    await assertFix(code, UseContextRead.new, null);
    await assertFix(code, UseBuilderContext.new, null);
    await assertFix(
      code,
      WrapItemInBuilder.new,
      code.replaceFirst(
        '(context, index) => Text(context.state.name)',
        '(context, index) => Builder(builder: (context) => '
            'Text(context.select((st) => st.name)))',
      ),
    );
  }

  Future<void> test_itemBuilder_blockBody() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemBuilder: (ctx, index) {
        var state = ctx.state;
        return Text(state.name + state.user.name);
      },
    );
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'ctx.state')]);
    await assertFix(code, WrapItemInBuilder.new, '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemBuilder: (ctx, index) => Builder(builder: (ctx) {
        var name = ctx.select((st) => st.name);
        var userName = ctx.select((st) => st.user.name);
        return Text(name + userName);
      }),
    );
  }
}
''');
  }

  Future<void> test_itemBuilder_wholeItem() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemBuilder: (context, index) => context.state.user.name.isEmpty
          ? const Text('')
          : Text(context.state.name),
    );
  }
}
''';
    await assertFix(code, WrapItemInBuilder.new, '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemBuilder: (context, index) => Builder(builder: (context) => context.select((st) => st.user.name.isEmpty)
          ? const Text('')
          : Text(context.state.name)),
    );
  }
}
''');
  }

  Future<void> test_itemBuilder_nullableItem_noFix() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemBuilder: (context, index) => index < 3 ? Text(context.state.name) : null,
    );
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'context.state')]);
    await assertFix(code, WrapItemInBuilder.new, null);
  }

  Future<void> test_itemBuilder_blockBodyReturnsNull_noFix() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemBuilder: (context, index) {
        if (index > 3) return null;
        return Text(context.state.name);
      },
    );
  }
}
''';
    await assertFix(code, WrapItemInBuilder.new, null);
  }

  Future<void> test_itemBuilder_blockBodyWithoutFinalReturn_noFix() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemBuilder: (context, index) {
        if (index < 3) return Text(context.state.name);
      },
    );
  }
}
''';
    await assertFix(code, WrapItemInBuilder.new, null);
  }

  Future<void> test_itemBuilder_stateItself_noFix() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemBuilder: (context, index) => Text('\${context.state}'),
    );
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'context.state')]);
    await assertFix(code, WrapItemInBuilder.new, null);
  }

  Future<void> test_itemBuilder_contextOfBuild() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemBuilder: (_, index) => Text(context.state.name),
    );
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'context.state',
        correctionContains:
            "This 'context' belongs to the enclosing widget, not to the item",
      ),
    ]);
    await assertFix(code, UseBuilderContext.new, null);
    await assertFix(
      code,
      WrapItemInBuilder.new,
      code.replaceFirst(
        '(_, index) => Text(context.state.name)',
        '(_, index) => Builder(builder: (context) => '
            'Text(context.select((st) => st.name)))',
      ),
    );
  }

  Future<void> test_contextOfAnotherWidget() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Builder(builder: (inner) => Text(context.state.name));
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'context.state',
        correctionContains: "This 'context' belongs to the enclosing widget",
      ),
    ]);
    await assertFix(code, UseContextSelect.new, null);
    await assertFix(code, WrapItemInBuilder.new, null);
    await assertFix(
      code,
      UseBuilderContext.new,
      code.replaceFirst('context.state.name', 'inner.select((st) => st.name)'),
    );
  }

  Future<void> test_contextOfAnotherWidget_wildcard() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Builder(builder: (_) => Text(context.state.name));
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'context.state')]);
    await assertFix(
      code,
      UseBuilderContext.new,
      code.replaceFirst(
        '(_) => Text(context.state.name)',
        '(context) => Text(context.select((st) => st.name))',
      ),
    );
  }

  Future<void> test_contextOfAnotherWidget_variable() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext ctx) {
    return Builder(
      builder: (_) {
        var state = ctx.state;
        return Text(state.name);
      },
    );
  }
}
''';
    await assertFix(
      code,
      UseBuilderContext.new,
      code
          .replaceFirst('(_) {', '(ctx) {')
          .replaceFirst(
            'var state = ctx.state;',
            'var name = ctx.select((st) => st.name);',
          )
          .replaceFirst('Text(state.name)', 'Text(name)'),
    );
  }

  Future<void> test_contextOfAnotherWidget_stateItself_noFix() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Builder(builder: (_) => Text('\${context.state}'));
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'context.state')]);
    await assertFix(code, UseBuilderContext.new, null);
  }

  Future<void> test_dispose_isIgnored() async {
    await assertNoDiagnostics('''$widgetHeader
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
''');
  }

  Future<void> test_selector_isIgnored() async {
    await assertNoDiagnostics('''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Text(context.select((st) => context.state.name));
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

/// A `State` with [body] in the method [method]. The mock `State` doesn't declare
/// most lifecycle methods, so they don't use `@override`.
String _stateWith(String method, String body) =>
    '''$widgetHeader
class W extends StatefulWidget {
  @override
  State<W> createState() => _WState();
}

class _WState extends State<W> {
  void $method {
    $body
  }

  @override
  Widget build(BuildContext context) => const Text('');
}
''';

@reflectiveTest
class ContextStateInInitStateActionStatusTest extends AsyncReduxWidgetRuleTest {
  @override
  void setUp() {
    rule = ContextStateInInitStateRule();
    super.setUp();
  }

  Future<void> test_actionStatus() async {
    var code = _stateWith(
      'initState()',
      'super.initState(); '
          'print(context.isWaiting(int)); print(context.isFailed(int)); '
          'print(context.exceptionFor(int)); context.clearExceptionFor(int);',
    );
    await assertDiagnostics(code, [
      lintAt(
        code,
        'context.isWaiting(int)',
        messageContainsAll: ["'context.isWaiting' can't be used in 'initState'"],
      ),
      lintAt(code, 'context.isFailed(int)'),
      lintAt(code, 'context.exceptionFor(int)'),
      lintAt(code, 'context.clearExceptionFor(int)'),
    ]);
    await assertFix(code, UseContextRead.new, null);
  }

  Future<void> test_readDispatchAndEnvironment_isIgnored() async {
    await assertNoDiagnostics(
      _stateWith(
        'initState()',
        'super.initState(); print(context.read()); context.dispatch(1); '
            'print(context.getEnvironment<AppState>());',
      ),
    );
  }

  Future<void> test_didChangeDependencies_isIgnored() async {
    await assertNoDiagnostics(
      _stateWith(
        'didChangeDependencies()',
        'print(context.state); print(context.isWaiting(int));',
      ),
    );
  }
}

@reflectiveTest
class ContextInDisposeTest extends AsyncReduxWidgetRuleTest {
  @override
  void setUp() {
    rule = ContextInDisposeRule();
    super.setUp();
  }

  Future<void> test_dispose() async {
    var code = _stateWith(
      'dispose()',
      'print(context.state); print(context.read()); print(context.isWaiting(int)); '
          'print(context.getConfiguration<AppState>()); super.dispose();',
    );
    await assertDiagnostics(code, [
      lintAt(
        code,
        'context.state',
        messageContainsAll: ["'context.state' can't be used in 'dispose'"],
      ),
      lintAt(code, 'context.read()'),
      lintAt(code, 'context.isWaiting(int)'),
      lintAt(code, 'context.getConfiguration<AppState>()'),
    ]);
    await assertFix(code, UseContextRead.new, null);
  }

  Future<void> test_closureInDispose() async {
    var code = _stateWith(
      'dispose()',
      'Future.microtask(() => print(context.read())); super.dispose();',
    );
    await assertDiagnostics(code, [lintAt(code, 'context.read()')]);
  }

  Future<void> test_dispatchAndSelect_isIgnored() async {
    // 'select' in 'dispose' is reported by 'select_outside_build'.
    await assertNoDiagnostics(
      _stateWith(
        'dispose()',
        'context.dispatch(1); print(context.select((st) => st.name)); super.dispose();',
      ),
    );
  }

  Future<void> test_deactivate_isIgnored() async {
    await assertNoDiagnostics(
      _stateWith('deactivate()', 'print(context.read()); print(context.state);'),
    );
  }
}

@reflectiveTest
class ContextInSelectorTest extends AsyncReduxWidgetRuleTest {
  @override
  void setUp() {
    rule = ContextInSelectorRule();
    super.setUp();
  }

  Future<void> test_state() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Text(context.select((st) => context.state.name));
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'context.state',
        messageContainsAll: [
          "'context.state' can't be used inside the selector of 'context.select'",
        ],
      ),
    ]);
    await assertFix(
      code,
      UseSelectorParameter.new,
      code.replaceFirst('context.state.name', 'st.name'),
    );
  }

  Future<void> test_read() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Text(context.select((st) => [1].map((_) => context.read().name).first));
}
''';
    await assertDiagnostics(code, [lintAt(code, 'context.read()')]);
    await assertFix(
      code,
      UseSelectorParameter.new,
      code.replaceFirst('context.read().name', 'st.name'),
    );
  }

  Future<void> test_nestedSelectAndDispatch() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Text(
    context.select((st) {
      context.dispatch(1);
      return context.select((s) => s.name);
    }),
  );
}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'context.dispatch(1)'),
      lintAt(code, 'context.select((s) => s.name)'),
    ]);
    await assertFix(code, UseSelectorParameter.new, null);
  }

  Future<void> test_event() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Text('\${context.event((st) => context.isWaiting(int) ? st.evt : st.evt)}');
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'context.isWaiting(int)',
        messageContainsAll: ["inside the selector of 'context.event'"],
      ),
    ]);
  }

  Future<void> test_wildcardParameter_noFix() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Text(context.select((_) => context.state.name));
}
''';
    await assertDiagnostics(code, [lintAt(code, 'context.state')]);
    await assertFix(code, UseSelectorParameter.new, null);
  }

  Future<void> test_selectorParameter_isIgnored() async {
    await assertNoDiagnostics('''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var name = context.select((st) => st.name);
    return Text(name + context.state.name);
  }
}
''');
  }
}
