import 'package:async_redux_lints/src/fixes/state_access_fixes.dart';
import 'package:async_redux_lints/src/fixes/widget_fixes.dart';
import 'package:async_redux_lints/src/rules/widget_rules.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'rule_test_base.dart';
import 'widget_rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(DispatchInBuildTest);
    defineReflectiveTests(DispatchInBuildStoreTest);
    defineReflectiveTests(ContextReadInBuildTest);
    defineReflectiveTests(RefreshIndicatorWithoutWaitTest);
    defineReflectiveTests(ThenOnDispatchAndWaitTest);
    defineReflectiveTests(ThenOnDispatchAndWaitStoreTest);
  });
}

/// The dispatch methods of the `BuildContext` extension of AsyncRedux, other than
/// `dispatch`, which the widget stub already declares.
const _dispatchStub = r'''
import 'dart:async';
import 'package:flutter/widgets.dart';

class ActionStatus {}

extension BuildContextDispatchExtension on BuildContext {
  Future<ActionStatus> dispatchAndWait(Object action) => throw 0;
  Object? dispatchAll(List<Object> actions) => throw 0;
  Future<void> dispatchAndWaitAll(List<Object> actions) => throw 0;
  ActionStatus dispatchSync(Object action) => throw 0;
}

extension FutureActionStatusExtension on Future<ActionStatus> {
  Future<ActionStatus> thenIfCompletedOk(
    FutureOr<void> Function(ActionStatus status) callback,
  ) => throw 0;
}
''';

const _refreshIndicatorStub = r'''
import 'package:flutter/widgets.dart';

class RefreshIndicator extends StatelessWidget {
  RefreshIndicator({required Future<void> Function() onRefresh, required Widget child});
  @override
  Widget build(BuildContext context) => throw 0;
}
''';

const _header =
    '''
import 'dart:async';
import 'package:async_redux/dispatch.dart';
import 'package:flutter/src/widgets/refresh.dart';
$widgetHeader
class Load {}

typedef UsesAsync = FutureOr<int>;
typedef UsesDispatch = ActionStatus;
typedef UsesRefresh = RefreshIndicator;
''';

abstract class _WidgetRuleTest extends AsyncReduxWidgetRuleTest {
  @override
  void setUp() {
    newPackage('async_redux').addFile('lib/dispatch.dart', _dispatchStub);
    super.setUp();
    newFile('${addFlutter().path}/src/widgets/refresh.dart', _refreshIndicatorStub);
  }
}

const _storeHeader = '''$header
class MyAction extends ReduxAction<AppState> {
  @override
  AppState? reduce() => null;
}
''';

@reflectiveTest
class DispatchInBuildTest extends _WidgetRuleTest {
  @override
  void setUp() {
    rule = DispatchInBuildRule();
    super.setUp();
  }

  Future<void> test_build() async {
    var code = '''$_header
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    context.dispatch(Load());
    return const SizedBox();
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'context.dispatch(Load())')]);
  }

  Future<void> test_dispatchAndWaitInBuilder() async {
    var code = '''$_header
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Builder(builder: (ctx) {
      ctx.dispatchAndWait(Load());
      return const SizedBox();
    });
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'ctx.dispatchAndWait(Load())')]);
  }

  Future<void> test_stateBuild() async {
    var code = '''$_header
class W extends StatefulWidget {
  @override
  State<W> createState() => _WState();
}

class _WState extends State<W> {
  @override
  Widget build(BuildContext context) {
    context.dispatchAll([Load()]);
    return const SizedBox();
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'context.dispatchAll([Load()])')]);
  }

  Future<void> test_callback() async {
    await assertNoDiagnostics('''$_header
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: () => context.dispatch(Load()));
  }
}
''');
  }

  Future<void> test_postFrameCallback() async {
    await assertNoDiagnostics('''$_header
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => context.dispatch(Load()));
    return const SizedBox();
  }
}
''');
  }

  Future<void> test_otherClosure() async {
    await assertNoDiagnostics('''$_header
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    [1].forEach((_) => context.dispatch(Load()));
    return const SizedBox();
  }
}
''');
  }

  Future<void> test_initState() async {
    await assertNoDiagnostics('''$_header
class W extends StatefulWidget {
  @override
  State<W> createState() => _WState();
}

class _WState extends State<W> {
  @override
  void initState() {
    super.initState();
    context.dispatch(Load());
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
''');
  }
}

@reflectiveTest
class DispatchInBuildStoreTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = DispatchInBuildRule();
    super.setUp();
  }

  Future<void> test_buildMethodOfOtherClass() async {
    await assertNoDiagnostics('''$_storeHeader
class Builder {
  final Store<AppState> store = Store<AppState>();

  void build() {
    store.dispatch(MyAction());
  }
}
''');
  }
}

@reflectiveTest
class ContextReadInBuildTest extends _WidgetRuleTest {
  @override
  void setUp() {
    rule = ContextReadInBuildRule();
    super.setUp();
  }

  Future<void> test_build() async {
    var code = '''$_header
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(context.read().user.name);
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'context.read()',
        messageContainsAll: ["'context.read' doesn't rebuild the widget"],
      ),
    ]);
    await assertFix(code, UseContextSelect.new, '''$_header
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(context.select((st) => st.user.name));
  }
}
''');
  }

  Future<void> test_variable() async {
    await assertFix(
      '''$_header
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var state = context.read();
    return Text(state.name + state.user.name);
  }
}
''',
      UseContextSelect.new,
      '''$_header
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var name = context.select((st) => st.name);
    var userName = context.select((st) => st.user.name);
    return Text(name + userName);
  }
}
''',
    );
  }

  Future<void> test_getRead() async {
    var code = '''$_header
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(context.getRead<AppState>().name);
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'context.getRead<AppState>()')]);
    await assertFix(code, UseContextSelect.new, '''$_header
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(context.getSelect<AppState, String>((st) => st.name));
  }
}
''');
  }

  Future<void> test_itemBuilder() async {
    var code = '''$_header
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemBuilder: (context, index) => Text(context.read().name),
    );
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'context.read()', correctionContains: "in a 'Builder'"),
    ]);
    await assertFix(code, UseContextSelect.new, null);
  }

  Future<void> test_callbackAndInitState() async {
    await assertNoDiagnostics('''$_header
class W extends StatefulWidget {
  @override
  State<W> createState() => _WState();
}

class _WState extends State<W> {
  late String name;

  @override
  void initState() {
    super.initState();
    name = context.read().name;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: () => print(context.read().name));
  }
}
''');
  }
}

@reflectiveTest
class RefreshIndicatorWithoutWaitTest extends _WidgetRuleTest {
  @override
  void setUp() {
    rule = RefreshIndicatorWithoutWaitRule();
    super.setUp();
  }

  Future<void> test_asyncBlock() async {
    var code = '''$_header
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        context.dispatch(Load());
      },
      child: const SizedBox(),
    );
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'context.dispatch(Load())',
        messageContainsAll: ["doesn't wait for 'dispatch' to finish"],
        correctionContains: "'dispatchAndWait(...)'",
      ),
    ]);
    await assertFix(code, WaitForDispatch.new, '''$_header
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await context.dispatchAndWait(Load());
      },
      child: const SizedBox(),
    );
  }
}
''');
  }

  Future<void> test_dispatchAndWaitNotAwaited() async {
    var code = '''$_header
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        context.dispatchAndWait(Load());
      },
      child: const SizedBox(),
    );
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'context.dispatchAndWait(Load())')]);
    await assertFix(code, WaitForDispatch.new, '''$_header
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await context.dispatchAndWait(Load());
      },
      child: const SizedBox(),
    );
  }
}
''');
  }

  Future<void> test_dispatchAllReturned() async {
    var code = '''$_header
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => context.dispatchAll([Load()]),
      child: const SizedBox(),
    );
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'context.dispatchAll([Load()])',
        correctionContains: "'dispatchAndWaitAll(...)'",
      ),
    ]);
    await assertFix(code, WaitForDispatch.new, '''$_header
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => context.dispatchAndWaitAll([Load()]),
      child: const SizedBox(),
    );
  }
}
''');
  }

  Future<void> test_notLastStatementOfSyncBody() async {
    var code = '''$_header
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () {
        context.dispatch(Load());
        return Future.value();
      },
      child: const SizedBox(),
    );
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'context.dispatch(Load())')]);
    await assertFix(code, WaitForDispatch.new, null);
  }

  Future<void> test_tearOff() async {
    var code = '''$_header
class W extends StatefulWidget {
  @override
  State<W> createState() => _WState();
}

class _WState extends State<W> {
  Future<void> _refresh() async {
    context.dispatch(Load());
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(onRefresh: _refresh, child: const SizedBox());
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'context.dispatch(Load())')]);
  }

  Future<void> test_waits() async {
    await assertNoDiagnostics('''$_header
class W extends StatelessWidget {
  Future<void> refresh(BuildContext context) => context.dispatchAndWait(Load());

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RefreshIndicator(
          onRefresh: () => context.dispatchAndWait(Load()),
          child: const SizedBox(),
        ),
        RefreshIndicator(
          onRefresh: () async {
            context.dispatchSync(Load());
            await context.dispatchAndWaitAll([Load()]);
          },
          child: const SizedBox(),
        ),
        RefreshIndicator(
          onRefresh: () async => context.dispatch(Load()),
          child: const SizedBox(),
        ),
      ],
    );
  }
}
''');
  }
}

@reflectiveTest
class ThenOnDispatchAndWaitTest extends _WidgetRuleTest {
  @override
  void setUp() {
    rule = ThenOnDispatchAndWaitRule();
    super.setUp();
  }

  Future<void> test_then() async {
    var code = '''$_header
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.dispatchAndWait(Load()).then((_) => print('Done'));
      },
    );
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'then((_)', length: 4)]);
    await assertFix(code, UseThenIfCompletedOk.new, '''$_header
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.dispatchAndWait(Load()).thenIfCompletedOk((_) => print('Done'));
      },
    );
  }
}
''');
  }

  Future<void> test_resultUsed() async {
    var code = '''$_header
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        var value = await context.dispatchAndWait(Load()).then((_) => 1);
        print(value);
      },
    );
  }
}
''';
    await assertDiagnostics(code, [lintAt(code, 'then((_)', length: 4)]);
    await assertFix(code, UseThenIfCompletedOk.new, null);
  }

  Future<void> test_notDispatchAndWait() async {
    await assertNoDiagnostics('''$_header
class W extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Future.value(1).then((_) => print('Done'));
        context.dispatchAndWait(Load()).thenIfCompletedOk((_) => print('Done'));
      },
    );
  }
}
''');
  }
}

@reflectiveTest
class ThenOnDispatchAndWaitStoreTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = ThenOnDispatchAndWaitRule();
    super.setUp();
  }

  Future<void> test_storeAndAction() async {
    var code = '''$_storeHeader
void f(Store<AppState> store) {
  store.dispatchAndWait(MyAction()).then((_) => print('Done'));
}

class OtherAction extends ReduxAction<AppState> {
  @override
  AppState? reduce() {
    dispatchAndWait(MyAction()).then((_) => print('Done'));
    return null;
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'then((_)', length: 4),
      lintAt(code, 'then((_)', occurrence: 2, length: 4),
    ]);
  }
}
