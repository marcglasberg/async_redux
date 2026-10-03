import 'package:async_redux_lints/src/fixes/state_access_fixes.dart';
import 'package:async_redux_lints/src/rules/select_outside_build_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'widget_rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(SelectOutsideBuildTest);
  });
}

@reflectiveTest
class SelectOutsideBuildTest extends AsyncReduxWidgetRuleTest {
  @override
  void setUp() {
    rule = SelectOutsideBuildRule();
    super.setUp();
  }

  Future<void> test_onTap() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: () => print(context.select((st) => st.counter)));
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'context.select((st) => st.counter)',
        messageContainsAll: ["'select' can't be used in the 'onTap' callback"],
      ),
    ]);
    await assertFix(code, ReplaceSelectWithRead.new, '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: () => print(context.read().counter));
  }
}
''');
  }

  Future<void> test_nestedClosureInCallback() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: () {
      [1].forEach((_) {
        var s = context.select((st) => '\$st' + st.name);
        print(s);
      });
    });
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(code, "context.select((st) => '\$st' + st.name)"),
    ]);
    await assertFix(code, ReplaceSelectWithRead.new, '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: () {
      [1].forEach((_) {
        var s = '\${context.read()}' + context.read().name;
        print(s);
      });
    });
  }
}
''');
  }

  Future<void> test_parenthesesWhenNeeded() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => print(context.select((st) => st.counter + 1).isEven),
    );
  }
}
''';
    await assertFix(code, ReplaceSelectWithRead.new, '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => print((context.read().counter + 1).isEven),
    );
  }
}
''');
  }

  Future<void> test_tearOffSelector() async {
    var code = '''$widgetHeader
int selectCounter(AppState state) => state.counter;

class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: () => print(context.select(selectCounter)));
  }
}
''';
    await assertFix(code, ReplaceSelectWithRead.new, '''$widgetHeader
int selectCounter(AppState state) => state.counter;

class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: () => print(selectCounter(context.read())));
  }
}
''');
  }

  Future<void> test_getSelect() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => print(context.getSelect<AppState, int>((st) => st.counter)),
    );
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'context.getSelect<AppState, int>((st) => st.counter)',
        messageContainsAll: ["'getSelect' can't be used"],
      ),
    ]);
    await assertFix(code, ReplaceSelectWithRead.new, '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => print(context.getRead<AppState>().counter),
    );
  }
}
''');
  }

  Future<void> test_initState() async {
    var code = '''$widgetHeader
class W extends StatefulWidget {
  @override
  State<W> createState() => _WState();
}

class _WState extends State<W> {
  @override
  void initState() {
    super.initState();
    print(context.select((st) => st.counter));
  }

  @override
  Widget build(BuildContext context) => Text('');
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'context.select((st) => st.counter)',
        messageContainsAll: ["'select' can't be used in 'initState'"],
      ),
    ]);
  }

  Future<void> test_readMissing_noFix() async {
    var code = r'''
import 'package:async_redux/widgets.dart';
import 'package:flutter/widgets.dart';

class AppState {
  final int counter = 0;
}

extension BuildContextExtension on BuildContext {
  R select<R>(R Function(AppState state) selector) => getSelect<AppState, R>(selector);
}

class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: () => print(context.select((st) => st.counter)));
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'context.select((st) => st.counter)')]);
    await assertFix(code, ReplaceSelectWithRead.new, null);
  }

  Future<void> test_build_isIgnored() async {
    await assertNoDiagnostics('''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var counter = context.select((st) => st.counter);
    var names = [1].map((_) => context.select((st) => st.name)).toList();
    return Text('\$counter \$names');
  }
}
''');
  }

  Future<void> test_builderInsideCallback_isIgnored() async {
    await assertNoDiagnostics('''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Builder(builder: (context) => Text(context.select((st) => st.name))),
    );
  }
}
''');
  }

  Future<void> test_helperMethod_isIgnored() async {
    await assertNoDiagnostics('''$widgetHeader
class W extends StatelessWidget {
  Widget buildHeader(BuildContext context) => Text(context.select((st) => st.name));

  @override
  Widget build(BuildContext context) => buildHeader(context);
}
''');
  }

  Future<void> test_otherSelect_isIgnored() async {
    await assertNoDiagnostics('''$widgetHeader
extension ProviderLike on BuildContext {
  R choose<R>(R Function(AppState state) selector) => throw 0;
}

class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: () => print(context.choose((st) => st.name)));
  }
}
''');
  }

  /// A `State` with [body] in the method [method]. The mock `State` doesn't
  /// declare most lifecycle methods, so they don't use `@override`.
  String stateWith(String method, String body, {String header = widgetHeader}) =>
      '''$header
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

  /// The [widgetHeader], with `debug: false` in `select` and `event`.
  static final debugOffHeader = widgetHeader
      .replaceFirst(
        'getSelect<AppState, R>(selector)',
        'getSelect<AppState, R>(selector, debug: false)',
      )
      .replaceFirst(
        'getEvent<AppState, R>(selector)',
        'getEvent<AppState, R>(selector, debug: false)',
      );

  Future<void> test_event_onTap() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: () => print(context.event((st) => st.evt)));
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'context.event((st) => st.evt)',
        messageContainsAll: ["'event' can't be used in the 'onTap' callback"],
      ),
    ]);
    await assertFix(code, ReplaceSelectWithRead.new, null);
  }

  Future<void> test_event_build_isIgnored() async {
    await assertNoDiagnostics('''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Text('\${context.event((st) => st.evt)}');
}
''');
  }

  Future<void> test_didChangeDependencies_debugOn() async {
    var code = stateWith(
      'didChangeDependencies()',
      'print(context.select((st) => st.counter)); print(context.event((st) => st.evt));',
    );
    await assertDiagnostics(code, [
      lintAt(
        code,
        'context.select((st) => st.counter)',
        messageContainsAll: ["'select' can't be used in 'didChangeDependencies'"],
      ),
      lintAt(code, 'context.event((st) => st.evt)'),
    ]);
    await assertFix(code, ReplaceSelectWithRead.new, null);
  }

  Future<void> test_didChangeDependencies_debugOff_isIgnored() async {
    await assertNoDiagnostics(
      stateWith(
        'didChangeDependencies()',
        'print(context.select((st) => st.counter)); '
            'print(context.event((st) => st.evt));',
        header: debugOffHeader,
      ),
    );
  }

  Future<void> test_didChangeDependencies_getSelect() async {
    var code = stateWith(
      'didChangeDependencies()',
      'print(context.getSelect<AppState, int>((st) => st.counter, debug: false)); '
          'print(context.getSelect<AppState, int>((st) => st.counter, debug: true));',
    );
    await assertDiagnostics(code, [
      lintAt(code, 'context.getSelect<AppState, int>((st) => st.counter, debug: true)'),
    ]);
  }

  Future<void> test_didChangeDependencies_debugParameter() async {
    var header = widgetHeader.replaceFirst(
      'R select<R>(R Function(AppState state) selector) => '
          'getSelect<AppState, R>(selector);',
      'R select<R>(R Function(AppState state) selector, {bool debug = true}) =>\n'
          '      getSelect<AppState, R>(selector, debug: debug);',
    );
    var code = stateWith(
      'didChangeDependencies()',
      'print(context.select((st) => st.counter, debug: false)); '
          'print(context.select((st) => st.name));',
      header: header,
    );
    await assertDiagnostics(code, [lintAt(code, 'context.select((st) => st.name)')]);
  }

  Future<void> test_didUpdateWidget_debugOff() async {
    var code = stateWith(
      'didUpdateWidget(W oldWidget)',
      'print(context.select((st) => st.counter));',
      header: debugOffHeader,
    );
    await assertDiagnostics(code, [
      lintAt(
        code,
        'context.select((st) => st.counter)',
        messageContainsAll: ["'select' can't be used in 'didUpdateWidget'"],
      ),
    ]);
    await assertFix(
      code,
      ReplaceSelectWithRead.new,
      code.replaceFirst('context.select((st) => st.counter)', 'context.read().counter'),
    );
  }

  Future<void> test_dispose_noFix() async {
    var code = stateWith(
      'dispose()',
      'print(context.select((st) => st.counter)); super.dispose();',
    );
    await assertDiagnostics(code, [
      lintAt(
        code,
        'context.select((st) => st.counter)',
        messageContainsAll: ["'select' can't be used in 'dispose'"],
      ),
    ]);
    await assertFix(code, ReplaceSelectWithRead.new, null);
  }

  Future<void> test_postFrameCallback() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => print(context.select((st) => st.counter)),
    );
    return const Text('');
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'context.select((st) => st.counter)',
        messageContainsAll: [
          "'select' can't be used in a closure passed to 'addPostFrameCallback'",
        ],
      ),
    ]);
    await assertFix(
      code,
      ReplaceSelectWithRead.new,
      code.replaceFirst('context.select((st) => st.counter)', 'context.read().counter'),
    );
  }

  Future<void> test_setState() async {
    var code = stateWith(
      'increment()',
      'setState(() => print(context.select((st) => st.counter)));',
    );
    await assertDiagnostics(code, [
      lintAt(
        code,
        'context.select((st) => st.counter)',
        messageContainsAll: ["in a closure passed to 'setState'"],
      ),
    ]);
  }

  Future<void> test_contextOfAnotherWidget() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Builder(builder: (inner) => Text(context.select((st) => st.name)));
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'context.select((st) => st.name)',
        messageContainsAll: ["'select' can't be used with the 'BuildContext' of another"],
      ),
    ]);
    await assertFix(code, ReplaceSelectWithRead.new, null);
    await assertFix(
      code,
      UseBuilderContext.new,
      code.replaceFirst('Text(context.select', 'Text(inner.select'),
    );
  }

  Future<void> test_contextOfAnotherWidget_wildcard_noFix() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Builder(builder: (_) => Text('\${context.event((st) => st.evt)}'));
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'context.event((st) => st.evt)')]);
    await assertFix(code, UseBuilderContext.new, null);
  }

  Future<void> test_contextOfState_inBuilder() async {
    var code = '''$widgetHeader
class W extends StatefulWidget {
  @override
  State<W> createState() => _WState();
}

class _WState extends State<W> {
  @override
  Widget build(BuildContext buildContext) {
    var name = context.select((st) => st.name);
    return Builder(builder: (inner) => Text(name + context.select((st) => st.name)));
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'context.select((st) => st.name)', occurrence: 2),
    ]);
  }

  Future<void> test_itemBuilder() async {
    var code = '''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemBuilder: (context, index) => Text(context.select((st) => st.name)),
      separatorBuilder: (context, index) => Text('\${context.event((st) => st.evt)}'),
    );
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'context.select((st) => st.name)',
        messageContainsAll: [
          "'select' can't be used with the 'BuildContext' of an 'itemBuilder'",
        ],
      ),
      lintAt(code, 'context.event((st) => st.evt)'),
    ]);
    await assertFix(code, ReplaceSelectWithRead.new, null);
  }

  Future<void> test_sliverChildBuilderDelegate() async {
    var code = '''$widgetHeader
Object delegate() => SliverChildBuilderDelegate(
  (context, index) => Text(context.select((st) => st.name)),
);
''';
    await assertDiagnostics(code, [lintAt(code, 'context.select((st) => st.name)')]);
  }

  Future<void> test_builderInItemBuilder_isIgnored() async {
    await assertNoDiagnostics('''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemBuilder: (_, index) =>
          Builder(builder: (context) => Text(context.select((st) => st.name))),
    );
  }
}
''');
  }

  Future<void> test_selectorInSelector_isIgnored() async {
    await assertNoDiagnostics('''$widgetHeader
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Text(context.select((st) => context.select((s) => s.name)));
}
''');
  }
}
