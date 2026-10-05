import 'package:async_redux_lints/src/fixes/event_fixes.dart';
import 'package:async_redux_lints/src/rules/event_rules.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'rule_test_base.dart';
import 'widget_rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(EventNameSuffixTest);
    defineReflectiveTests(EventNotSpentInitiallyTest);
    defineReflectiveTests(EventPersistedTest);
    defineReflectiveTests(EventConsumedTwiceTest);
  });
  group('suggestedEventName', () {
    test('adds the suffix', () {
      expect(suggestedEventName('clearText'), 'clearTextEvt');
      expect(suggestedEventName('_clearText'), '_clearTextEvt');
      expect(suggestedEventName('clearTextEvent'), 'clearTextEvt');
      expect(suggestedEventName('event'), 'evt');
      expect(suggestedEventName('_event'), '_evt');
    });
  });
}

/// A stub of the events of package `async_redux`.
const eventsStub = r'''
typedef Evt<T> = Event<T>;

class Event<T> {
  Event([T? evtInfo]);
  Event.spent();
  bool get isSpent => throw 0;
  T? consume() => throw 0;
  static Event<T> map<T, V>(Event<V> evt, T? Function(V?) mapFunction) => throw 0;
}

class MappedEvent<V, T> extends Event<T> {
  MappedEvent(Event<V>? evt, T? Function(V?) mapFunction);
}
''';

/// The start of every event test file.
const eventHeader = r'''
import 'package:async_redux/async_redux.dart';
import 'package:async_redux/events.dart';

// Avoid unused import warnings in tests that don't use these imports.
typedef UsesAsyncRedux = ReduxAction<int>;
typedef UsesEvents = Evt<int>;
''';

abstract class AsyncReduxEventRuleTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    newPackage('async_redux').addFile('lib/events.dart', eventsStub);
    super.setUp();
  }
}

@reflectiveTest
class EventNameSuffixTest extends AsyncReduxEventRuleTest {
  @override
  void setUp() {
    rule = EventNameSuffixRule();
    super.setUp();
  }

  Future<void> test_goodNames() async {
    await assertNoDiagnostics('''$eventHeader
class AppState {
  final Evt clearTextEvt;
  final Event<int> _scrollEvt;
  final Evt<String>? changeTextEvt;
  final Evt evt;
  final String clearText;
  static final Evt global = Evt.spent();
  AppState(this.clearTextEvt, this._scrollEvt, this.changeTextEvt, this.evt, this.clearText);
}
''');
  }

  Future<void> test_badNames() async {
    var code = '''$eventHeader
class AppState {
  final Evt clearText;
  final Event<int> scrollEvent;
  final Evt<String>? _changeText;
  final MappedEvent<int, String> mapped;
  AppState(this.clearText, this.scrollEvent, this._changeText, this.mapped);
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'clearText;',
        length: 'clearText'.length,
        messageContainsAll: ["'clearText'"],
        correctionContains: "'clearTextEvt'",
      ),
      lintAt(
        code,
        'scrollEvent;',
        length: 'scrollEvent'.length,
        correctionContains: "'scrollEvt'",
      ),
      lintAt(
        code,
        '_changeText;',
        length: '_changeText'.length,
        correctionContains: "'_changeTextEvt'",
      ),
      lintAt(code, 'mapped;', length: 'mapped'.length),
    ]);
  }

  Future<void> test_eventFromOtherPackage() async {
    await assertNoDiagnostics('''$eventHeader
class Event {}

class AppState {
  final Event clearText = Event();
}
''');
  }

  Future<void> test_override() async {
    var code = '''$eventHeader
abstract class Base {
  Evt get clearText;
}

class AppState implements Base {
  @override
  final Evt clearText;
  AppState(this.clearText);
}
''';
    // Reported only where the name is declared first.
    await assertNoDiagnostics(code);
  }

  Future<void> test_fix_renamesFieldAndParameters() async {
    var code = '''$eventHeader
class AppState {
  final Evt clearText;
  final int counter;

  AppState({required this.clearText, required this.counter});

  AppState copy({Evt? clearText, int? counter}) => AppState(
    clearText: clearText ?? this.clearText,
    counter: counter ?? this.counter,
  );

  static AppState initialState() => AppState(clearText: Evt.spent(), counter: 0);
}

class ClearTextAction extends ReduxAction<AppState> {
  @override
  AppState reduce() => state.copy(clearText: Evt());
}

bool consume(AppState state) => state.clearText.isSpent;
''';
    await assertFix(code, RenameEvent.new, code.replaceAll('clearText', 'clearTextEvt'));
  }

  Future<void> test_fix_renamesInAllFiles() async {
    var other = newFile('$testPackageLibPath/other.dart', '''
import 'package:async_redux/events.dart';
import 'test.dart';

AppState create() => AppState(Evt.spent(), clearTextEvent: Evt.spent());

bool consume(AppState state) => state.clearTextEvent.isSpent;
''');
    var code = '''$eventHeader
class AppState {
  final Evt clearTextEvent;
  final Evt otherEvt;
  AppState(this.otherEvt, {required this.clearTextEvent});
}
''';
    await assertFixInFiles(code, RenameEvent.new, {
      testFile.path: code.replaceAll('clearTextEvent', 'clearTextEvt'),
      other.path: other.readAsStringSync().replaceAll('clearTextEvent', 'clearTextEvt'),
    });
  }

  Future<void> test_fix_notOfferedWhenTheNameIsTaken() async {
    await assertFix(
      '''$eventHeader
class AppState {
  final Evt clearText;
  final Evt clearTextEvt;
  AppState(this.clearText, this.clearTextEvt);
}
''',
      RenameEvent.new,
      null,
    );
  }
}

@reflectiveTest
class EventNotSpentInitiallyTest extends AsyncReduxEventRuleTest {
  @override
  void setUp() {
    rule = EventNotSpentInitiallyRule();
    super.setUp();
  }

  Future<void> test_spent() async {
    await assertNoDiagnostics('''$eventHeader
class AppState {
  final Evt clearTextEvt;
  final Evt<int> scrollEvt;
  final Evt<String> changeTextEvt = Evt<String>.spent();

  AppState({required this.clearTextEvt, Evt<int>? scrollEvt})
    : scrollEvt = scrollEvt ?? Evt<int>.spent();

  AppState copy({Evt? clearTextEvt}) =>
      AppState(clearTextEvt: clearTextEvt ?? this.clearTextEvt);

  static AppState initialState() => AppState(clearTextEvt: Evt.spent());
}

class ClearTextAction extends ReduxAction<AppState> {
  @override
  AppState reduce() => state.copy(clearTextEvt: Evt());
}
''');
  }

  Future<void> test_initialStateMethod() async {
    var code = '''$eventHeader
class AppState {
  final Evt clearTextEvt;
  final Evt<int> scrollEvt;
  AppState({required this.clearTextEvt, required this.scrollEvt});

  static AppState initialState() {
    return AppState(clearTextEvt: Evt(), scrollEvt: Event<int>(42));
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'Evt()', messageContainsAll: ["created in 'initialState'"]),
      lintAt(code, 'Event<int>(42)'),
    ]);
  }

  Future<void> test_initialStateFunctionAndConstructor() async {
    var code = '''$eventHeader
class AppState {
  final Evt clearTextEvt;
  AppState({required this.clearTextEvt});
  factory AppState.initialState() => AppState(clearTextEvt: Evt());
}

AppState initialState() => AppState(clearTextEvt: Evt());
''';
    await assertDiagnostics(code, [
      lintAt(code, 'Evt()', messageContainsAll: ["in 'initialState'"]),
      lintAt(code, 'Evt()', occurrence: 2, messageContainsAll: ["in 'initialState'"]),
    ]);
  }

  Future<void> test_initialStateArgument() async {
    var code = '''$eventHeader
class AppState {
  final Evt clearTextEvt;
  AppState({required this.clearTextEvt});
}

var store = Store<AppState>(initialState: AppState(clearTextEvt: Evt()));
''';
    await assertDiagnostics(code, [
      lintAt(code, 'Evt()', messageContainsAll: ["'initialState' argument"]),
    ]);
  }

  Future<void> test_constructorAndField() async {
    var code = '''$eventHeader
class AppState {
  final Evt clearTextEvt;
  final Evt<String> changeTextEvt = Evt('a');
  AppState({Evt? clearTextEvt}) : clearTextEvt = clearTextEvt ?? Evt();
}
''';
    await assertDiagnostics(code, [
      lintAt(code, "Evt('a')", messageContainsAll: ['in a field initializer']),
      lintAt(code, 'Evt();', length: 5, messageContainsAll: ['in a constructor']),
    ]);
  }

  Future<void> test_notInitial() async {
    await assertNoDiagnostics('''$eventHeader
class AppState {
  final Evt clearTextEvt;
  AppState({required this.clearTextEvt});
  static final global = Evt();
  static AppState initialState() => AppState(clearTextEvt: Evt.spent());
  AppState withEvent() => AppState(clearTextEvt: Evt());
}

AppState create() => AppState(clearTextEvt: Evt());

void f() {
  AppState initialState() => AppState(clearTextEvt: Evt.spent());
  Store<AppState>(initialState: initialState());
  Store<AppState>(initialState: AppState.initialState()).dispatch(Action());
}

class Action extends ReduxAction<AppState> {
  @override
  AppState reduce() => AppState(clearTextEvt: Evt());
}
''');
  }

  Future<void> test_closureInInitialState() async {
    await assertNoDiagnostics('''$eventHeader
class AppState {
  final Evt Function() createEvt;
  AppState({required this.createEvt});
  static AppState initialState() => AppState(createEvt: () => Evt());
}
''');
  }

  Future<void> test_testFile() async {
    var file = newFile('$testPackageRootPath/test/state_test.dart', '''$eventHeader
class AppState {
  final Evt clearTextEvt;
  AppState({required this.clearTextEvt});
}

var store = Store<AppState>(initialState: AppState(clearTextEvt: Evt()));
''');
    await assertNoDiagnosticsInFile(file.path);
  }

  Future<void> test_fix() async {
    var code = '''$eventHeader
class AppState {
  final Evt clearTextEvt;
  AppState({required this.clearTextEvt});
  static AppState initialState() => AppState(clearTextEvt: Evt());
}
''';
    await assertFix(code, UseSpentEvent.new, code.replaceAll('Evt()', 'Evt.spent()'));
  }

  Future<void> test_fix_explicitTypeArgument() async {
    var code = '''$eventHeader
class AppState {
  final Evt<int> scrollEvt;
  AppState({required this.scrollEvt});
  static AppState initialState() => AppState(scrollEvt: Event<int>(42));
}
''';
    await assertFix(
      code,
      UseSpentEvent.new,
      code.replaceAll('Event<int>(42)', 'Event<int>.spent()'),
    );
  }

  Future<void> test_fix_inferredTypeArgument() async {
    var code = '''$eventHeader
class AppState {
  final Evt<int> scrollEvt;
  AppState({required this.scrollEvt});
  static AppState initialState() => AppState(scrollEvt: Evt(42));
}
''';
    await assertFix(
      code,
      UseSpentEvent.new,
      code.replaceAll('Evt(42)', 'Evt<int>.spent()'),
    );
  }
}

@reflectiveTest
class EventPersistedTest extends AsyncReduxEventRuleTest {
  @override
  void setUp() {
    rule = EventPersistedRule();
    super.setUp();
  }

  Future<void> test_toJsonWithoutEvents() async {
    await assertNoDiagnostics('''$eventHeader
class AppState {
  final int counter;
  final Evt clearTextEvt;
  AppState(this.counter, this.clearTextEvt);

  Map<String, dynamic> toJson() => {'counter': counter};

  static AppState fromJson(Map<String, dynamic> json) =>
      AppState(json['counter'] as int, Evt.spent());

  String describe() => '\$counter \$clearTextEvt';
}
''');
  }

  Future<void> test_toJsonAndToMap() async {
    var code = '''$eventHeader
class AppState {
  final int counter;
  final Evt clearTextEvt;
  final Evt<int>? scrollEvt;
  AppState(this.counter, this.clearTextEvt, this.scrollEvt);

  Map<String, dynamic> toJson() => {
    'counter': counter,
    'clearTextEvt': clearTextEvt.isSpent,
  };

  Map<String, Object?> toMap() => {'scrollEvt': this.scrollEvt?.consume()};
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'clearTextEvt.isSpent',
        length: 'clearTextEvt'.length,
        messageContainsAll: ["'clearTextEvt' is used in 'toJson'"],
      ),
      lintAt(
        code,
        'scrollEvt?.consume',
        length: 'scrollEvt'.length,
        messageContainsAll: ["'toMap'"],
      ),
    ]);
  }

  Future<void> test_persistor() async {
    var code = '''$eventHeader
class AppState {
  final int counter;
  final Evt clearTextEvt;
  AppState(this.counter, this.clearTextEvt);
}

void save(Object? value) {}

class MyPersistor extends Persistor<AppState> {
  Future<void> persistDifference({
    AppState? lastPersistedState,
    required AppState newState,
  }) async {
    save(newState.counter);
    save(newState.clearTextEvt);
  }

  Future<void> saveInitialState(AppState state) async => save(state.clearTextEvt);
}

class NotAPersistor {
  void persistDifference(AppState state) => save(state.clearTextEvt);
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'clearTextEvt);',
        length: 'clearTextEvt'.length,
        occurrence: 2,
        messageContainsAll: ["'persistDifference'"],
      ),
      lintAt(
        code,
        'clearTextEvt);',
        length: 'clearTextEvt'.length,
        occurrence: 3,
        messageContainsAll: ["'saveInitialState'"],
      ),
    ]);
  }
}

@reflectiveTest
class EventConsumedTwiceTest extends AsyncReduxWidgetRuleTest {
  @override
  void setUp() {
    rule = EventConsumedTwiceRule();
    super.setUp();
  }

  Future<void> test_consumedOnce() async {
    await assertNoDiagnostics('''$widgetHeader
class Other {
  final Evt<int> evt = Evt<int>();
}

class Nested {
  final Other a = Other();
  final Other b = Other();
}

class W1 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    context.event((state) => state.evt);
    context.getEvent<Nested, int>((nested) => nested.a.evt);
    context.getEvent<Nested, int>((nested) => nested.b.evt);
    context.getEvent<Other, int>((other) => other.evt);
    return const SizedBox();
  }
}
''');
  }

  /// Each file of a library is checked on its own.
  Future<void> test_consumedOnceInEachFileOfLibrary() async {
    var partPath = '$testPackageLibPath/part.dart';
    newFile(partPath, '''
part of 'test.dart';

class W2 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var value = context.event((state) => state.evt);
    return Text('\$value');
  }
}
''');
    var header = widgetHeader.replaceFirst(
      "import 'package:flutter/src/widgets/extras.dart';",
      "import 'package:flutter/src/widgets/extras.dart';\n\npart 'part.dart';",
    );
    newFile(testFilePath, '''$header
class W1 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var value = context.event((state) => state.evt);
    return Text('\$value');
  }
}
''');
    await assertDiagnosticsInUnits([(testFilePath, []), (partPath, [])]);
  }

  Future<void> test_consumedTwice() async {
    var code = '''$widgetHeader
class W1 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var value = context.event((state) => state.evt);
    return Text('\$value');
  }
}

class W2 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var value = context.event((st) => (st.evt));
    var other = context.getEvent<AppState, int>((st) => st.evt);
    return Text('\$value \$other');
  }
}
''';
    var line = code.substring(0, code.indexOf('context.event')).split('\n').length;
    await assertDiagnostics(code, [
      lintAt(
        code,
        'context.event((st) => (st.evt))',
        messageContainsAll: ["The event 'evt' is also consumed in line $line."],
      ),
      lintAt(code, 'context.getEvent<AppState, int>((st) => st.evt)'),
    ]);
  }

  Future<void> test_nestedPath() async {
    var code = '''$widgetHeader
class Other {
  final Evt<int> evt = Evt<int>();
}

class Nested {
  final Other a = Other();
}

class W1 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    context.getEvent<Nested, int>((nested) => nested.a.evt);
    context.getEvent<Nested, int>((n) => n.a.evt);
    return const SizedBox();
  }
}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'context.getEvent<Nested, int>((n) => n.a.evt)'),
    ]);
  }

  Future<void> test_selectorNotComparable() async {
    await assertNoDiagnostics('''$widgetHeader
class W1 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    context.event((state) {
      return state.evt;
    });
    context.event((state) => state.evt);
    return const SizedBox();
  }
}
''');
  }
}
