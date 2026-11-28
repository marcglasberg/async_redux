import 'package:async_redux_lints/src/rules/select_collection_literal_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'widget_rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(SelectCollectionLiteralTest);
  });
}

@reflectiveTest
class SelectCollectionLiteralTest extends AsyncReduxWidgetRuleTest {
  @override
  void setUp() {
    rule = SelectCollectionLiteralRule();
    super.setUp();
  }

  Future<void> _warning(String selector, String literal, {bool getSelect = false}) async {
    var method = getSelect ? 'getSelect<AppState, Object>' : 'select';
    var code =
        '''$widgetHeader
void f(BuildContext context) {
  context.$method($selector);
}
''';
    await assertDiagnostics(code, [lintAt(code, literal)]);
  }

  Future<void> _ok(String selector) async {
    await assertNoDiagnostics('''$widgetHeader
void f(BuildContext context) {
  context.select($selector);
}
''');
  }

  Future<void> test_list() =>
      _warning('(st) => [st.name, st.counter]', '[st.name, st.counter]');

  Future<void> test_set() =>
      _warning('(st) => {st.name, st.counter}', '{st.name, st.counter}');

  Future<void> test_map() => _warning("(st) => {'name': st.name}", "{'name': st.name}");

  Future<void> test_emptyTypedList() => _warning('(st) => <int>[]', '<int>[]');

  Future<void> test_emptyMap() => _warning('(st) => {}', '{}');

  Future<void> test_getSelect() =>
      _warning('(st) => [st.counter]', '[st.counter]', getSelect: true);

  Future<void> test_blockBody() =>
      _warning('(st) { return [st.counter]; }', '[st.counter]');

  Future<void> test_parenthesized() =>
      _warning('(st) => (([st.counter]))', '[st.counter]');

  Future<void> test_conditional() =>
      _warning('(st) => st.counter > 0 ? [st.name] : const []', '[st.name]');

  Future<void> test_switch() => _warning(
    '(st) => switch (st.counter) { 0 => [st.name], _ => const [] }',
    '[st.name]',
  );

  Future<void> test_cast() => _warning('(st) => [st.counter] as Object', '[st.counter]');

  Future<void> test_nullableFallback() =>
      _warning('(st) => st.maybeUser?.name ?? [st.counter]', '[st.counter]');

  Future<void> test_spread() =>
      _warning('(st) => [...[st.counter]]', '[...[st.counter]]');

  Future<void> test_record() => _ok('(st) => (st.name, st.counter)');

  Future<void> test_constCollections() async {
    await _ok('(st) => const [1, 2]');
    await _ok('(st) => const {1, 2}');
    await _ok("(st) => const {'a': 1}");
  }

  Future<void> test_existingValue() => _ok('(st) => st.user');

  Future<void> test_literalUsedInComputation() => _ok('(st) => [st.name].length');

  Future<void> test_nestedCallbackReturn() => _ok('''(st) {
    Object helper() => [st.counter];
    helper();
    return st.name;
  }''');

  Future<void> test_unrelatedSelect() async {
    await assertNoDiagnostics('''$widgetHeader
class Other {
  Object select(Object Function(AppState) selector) => selector(AppState());
}
void f(Other other) {
  other.select((st) => [st.name, st.counter]);
}
''');
  }
}
