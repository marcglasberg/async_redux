import 'package:async_redux_lints/src/fixes/state_access_fixes.dart';
import 'package:async_redux_lints/src/rules/select_in_callback_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'widget_rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(SelectInCallbackTest);
  });
}

@reflectiveTest
class SelectInCallbackTest extends AsyncReduxWidgetRuleTest {
  @override
  void setUp() {
    rule = SelectInCallbackRule();
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
}
