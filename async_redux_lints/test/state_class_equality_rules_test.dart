import 'package:async_redux_lints/src/fixes/equality_fixes.dart';
import 'package:async_redux_lints/src/rules/state_class_equality_rules.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'equatable_stub.dart';
import 'rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(StateClassMissingEqualityTest);
    defineReflectiveTests(EqualityMissingFieldTest);
    defineReflectiveTests(EqualityMissingInheritedFieldTest);
  });
}

const _header = r'''
import 'package:async_redux/async_redux.dart';

// Avoid unused import warnings in tests that don't use this import.
const usesAsyncRedux = stateClass;
''';

@reflectiveTest
class StateClassMissingEqualityTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = StateClassMissingEqualityRule();
    addEquatablePackage(this);
    super.setUp();
  }

  Future<void> test_overridesBoth() async {
    await assertNoDiagnostics('''$_header
@stateClass
class AppState {
  final int counter;
  AppState(this.counter);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AppState && counter == other.counter;

  @override
  int get hashCode => counter.hashCode;
}
''');
  }

  Future<void> test_missingBoth() async {
    var code = '''$_header
@stateClass
class AppState {
  final int counter;
  AppState(this.counter);
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'AppState {',
        length: 'AppState'.length,
        messageContainsAll: [
          "The state class 'AppState' must override '==' and 'hashCode'.",
        ],
      ),
    ]);
  }

  Future<void> test_missingHashCode() async {
    var code = '''$_header
@stateClass
class AppState {
  final int counter;
  AppState(this.counter);

  @override
  bool operator ==(Object other) => other is AppState && counter == other.counter;
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'AppState {',
        length: 'AppState'.length,
        messageContainsAll: ["must override 'hashCode'."],
      ),
    ]);
  }

  Future<void> test_subclass() async {
    var code = '''$_header
@stateClass
abstract class Base {}

class AppState extends Base {
  final int counter;
  AppState(this.counter);
}
''';
    // The abstract class has no fields, so it's not reported. Its subclass is.
    await assertDiagnostics(code, [
      lintAt(code, 'AppState extends', length: 'AppState'.length),
    ]);
  }

  Future<void> test_abstractClassWithFields() async {
    var code = '''$_header
@stateClass
abstract class Base {
  final int counter;
  Base(this.counter);
}
''';
    await assertDiagnostics(code, [lintAt(code, 'Base {', length: 'Base'.length)]);
  }

  Future<void> test_inheritsEquality_declaresFields() async {
    var code = '''$_header
@stateClass
class Base {
  final int counter;
  Base(this.counter);

  @override
  bool operator ==(Object other) => other is Base && counter == other.counter;

  @override
  int get hashCode => counter.hashCode;
}

class Sub extends Base {
  final String name;
  Sub(super.counter, this.name);
}

class NoFields extends Base {
  NoFields(super.counter);
}
''';
    // 'Sub' declares a field, so it must override '==' and 'hashCode', even though
    // it inherits them. 'NoFields' declares no fields.
    await assertDiagnostics(code, [lintAt(code, 'Sub extends', length: 'Sub'.length)]);
  }

  Future<void> test_equatable_isIgnored() async {
    await assertNoDiagnostics('''
import 'package:async_redux/async_redux.dart';
import 'package:equatable/equatable.dart';

@stateClass
class AppState extends Equatable {
  final int counter;
  const AppState(this.counter);

  @override
  List<Object?> get props => [counter];
}

@stateClass
class Other with EquatableMixin {
  final int counter;
  Other(this.counter);

  @override
  List<Object?> get props => [counter];
}
''');
  }

  Future<void> test_noFields_isIgnored() async {
    await assertNoDiagnostics('''$_header
@stateClass
class AppState {
  static int count = 0;
  int get counter => 0;
}
''');
  }

  Future<void> test_notStateClass_isIgnored() async {
    await assertNoDiagnostics('''$_header
class AppState {
  final int counter;
  AppState(this.counter);
}
''');
  }
}

@reflectiveTest
class EqualityMissingFieldTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = EqualityMissingFieldRule();
    super.setUp();
  }

  Future<void> test_allFields() async {
    await assertNoDiagnostics('''$_header
@stateClass
class AppState {
  static int count = 0;
  final int counter;
  final bool waiting;
  final int _secret = 42;

  AppState({required this.counter, required this.waiting});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppState &&
          runtimeType == other.runtimeType &&
          counter == other.counter &&
          waiting == other.waiting &&
          _secret == other._secret;

  @override
  int get hashCode => Object.hash(counter, waiting, _secret);
}
''');
  }

  Future<void> test_missingFields() async {
    var code = '''$_header
@stateClass
class AppState {
  final int counter;
  final bool waiting;
  final bool loading;

  AppState({required this.counter, required this.waiting, required this.loading});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppState &&
          runtimeType == other.runtimeType &&
          waiting == other.waiting &&
          loading == other.loading;

  @override
  int get hashCode => Object.hash(counter, loading);
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        '==(',
        length: '=='.length,
        messageContainsAll: ["Field 'counter' is missing from '=='."],
      ),
      lintAt(
        code,
        'hashCode =>',
        length: 'hashCode'.length,
        messageContainsAll: ["Field 'waiting' is missing from 'hashCode'."],
      ),
    ]);
    await assertFix(code, AddMissingFieldsToEquality.new, '''$_header
@stateClass
class AppState {
  final int counter;
  final bool waiting;
  final bool loading;

  AppState({required this.counter, required this.waiting, required this.loading});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppState &&
          runtimeType == other.runtimeType &&
          waiting == other.waiting &&
          loading == other.loading &&
          counter == other.counter;

  @override
  int get hashCode => Object.hash(counter, loading);
}
''');
  }

  Future<void> test_equals_singleLine() async {
    var code = '''$_header
@stateClass
class AppState {
  final int counter;
  final bool waiting;
  final bool loading;

  AppState(this.counter, this.waiting, this.loading);

  @override
  bool operator ==(Object other) => other is AppState && counter == other.counter;

  @override
  int get hashCode => Object.hash(counter, waiting, loading);
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        '==(',
        length: '=='.length,
        messageContainsAll: ["Fields 'waiting' and 'loading' are missing from '=='."],
      ),
    ]);
    await assertFix(code, AddMissingFieldsToEquality.new, '''$_header
@stateClass
class AppState {
  final int counter;
  final bool waiting;
  final bool loading;

  AppState(this.counter, this.waiting, this.loading);

  @override
  bool operator ==(Object other) => other is AppState && counter == other.counter && waiting == other.waiting && loading == other.loading;

  @override
  int get hashCode => Object.hash(counter, waiting, loading);
}
''');
  }

  Future<void> test_equals_blockBody() async {
    var code = '''$_header
@stateClass
class AppState {
  final int counter;
  final bool waiting;

  AppState(this.counter, this.waiting);

  @override
  bool operator ==(Object o) {
    return identical(this, o) || o is AppState && counter == o.counter;
  }

  @override
  int get hashCode => Object.hash(counter, waiting);
}
''';
    await assertFix(code, AddMissingFieldsToEquality.new, '''$_header
@stateClass
class AppState {
  final int counter;
  final bool waiting;

  AppState(this.counter, this.waiting);

  @override
  bool operator ==(Object o) {
    return identical(this, o) || o is AppState && counter == o.counter && waiting == o.waiting;
  }

  @override
  int get hashCode => Object.hash(counter, waiting);
}
''');
  }

  Future<void> test_equals_noTypeCheck_fixNotOffered() async {
    var code = '''$_header
@stateClass
class AppState {
  final int counter;

  AppState(this.counter);

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => Object.hash(counter, 0);
}
''';
    await assertDiagnostics(code, [lintAt(code, '==(', length: '=='.length)]);
    // `other.counter` wouldn't compile without `other is AppState`.
    await assertFix(code, AddMissingFieldsToEquality.new, null);
  }

  Future<void> test_hashCode_objectHash_multiline() async {
    var code = '''$_header
@stateClass
class AppState {
  final int counter;
  final bool waiting;
  final bool loading;

  AppState(this.counter, this.waiting, this.loading);

  @override
  bool operator ==(Object other) =>
      other is AppState &&
      counter == other.counter &&
      waiting == other.waiting &&
      loading == other.loading;

  @override
  int get hashCode => Object.hash(
        counter,
        waiting,
      );
}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'hashCode =>', length: 'hashCode'.length),
    ]);
    await assertFix(code, AddMissingFieldsToEquality.new, '''$_header
@stateClass
class AppState {
  final int counter;
  final bool waiting;
  final bool loading;

  AppState(this.counter, this.waiting, this.loading);

  @override
  bool operator ==(Object other) =>
      other is AppState &&
      counter == other.counter &&
      waiting == other.waiting &&
      loading == other.loading;

  @override
  int get hashCode => Object.hash(
        counter,
        waiting,
        loading,
      );
}
''');
  }

  Future<void> test_hashCode_hashAll() async {
    var code = '''$_header
@stateClass
class AppState {
  final int counter;
  final bool waiting;

  AppState(this.counter, this.waiting);

  @override
  bool operator ==(Object other) =>
      other is AppState && counter == other.counter && waiting == other.waiting;

  @override
  int get hashCode => Object.hashAll([counter]);
}
''';
    await assertFix(code, AddMissingFieldsToEquality.new, '''$_header
@stateClass
class AppState {
  final int counter;
  final bool waiting;

  AppState(this.counter, this.waiting);

  @override
  bool operator ==(Object other) =>
      other is AppState && counter == other.counter && waiting == other.waiting;

  @override
  int get hashCode => Object.hashAll([counter, waiting]);
}
''');
  }

  Future<void> test_hashCode_caret() async {
    var code = '''$_header
@stateClass
class AppState {
  final int counter;
  final bool waiting;
  final bool loading;

  AppState(this.counter, this.waiting, this.loading);

  @override
  bool operator ==(Object other) =>
      other is AppState &&
      counter == other.counter &&
      waiting == other.waiting &&
      loading == other.loading;

  @override
  int get hashCode =>
      counter.hashCode ^
      waiting.hashCode;
}
''';
    await assertFix(code, AddMissingFieldsToEquality.new, '''$_header
@stateClass
class AppState {
  final int counter;
  final bool waiting;
  final bool loading;

  AppState(this.counter, this.waiting, this.loading);

  @override
  bool operator ==(Object other) =>
      other is AppState &&
      counter == other.counter &&
      waiting == other.waiting &&
      loading == other.loading;

  @override
  int get hashCode =>
      counter.hashCode ^
      waiting.hashCode ^
      loading.hashCode;
}
''');
  }

  Future<void> test_hashCode_singleField() async {
    var code = '''$_header
@stateClass
class AppState {
  final int counter;
  final bool waiting;

  AppState(this.counter, this.waiting);

  @override
  bool operator ==(Object other) =>
      other is AppState && counter == other.counter && waiting == other.waiting;

  @override
  int get hashCode => counter.hashCode;
}
''';
    await assertFix(code, AddMissingFieldsToEquality.new, '''$_header
@stateClass
class AppState {
  final int counter;
  final bool waiting;

  AppState(this.counter, this.waiting);

  @override
  bool operator ==(Object other) =>
      other is AppState && counter == other.counter && waiting == other.waiting;

  @override
  int get hashCode => counter.hashCode ^ waiting.hashCode;
}
''');
  }

  Future<void> test_hashCode_otherForm_fixNotOffered() async {
    var code = '''$_header
@stateClass
class AppState {
  final int counter;
  final bool waiting;

  AppState(this.counter, this.waiting);

  @override
  bool operator ==(Object other) =>
      other is AppState && counter == other.counter && waiting == other.waiting;

  @override
  int get hashCode => waiting ? 1 : 0;
}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'hashCode =>', length: 'hashCode'.length),
    ]);
    // Appending `^ counter.hashCode` would change the meaning of `? :`.
    await assertFix(code, AddMissingFieldsToEquality.new, null);
  }

  Future<void> test_hashCode_tooManyValues_fixNotOffered() async {
    var names = [for (var i = 1; i <= 21; i++) 'f$i'];
    var present = names.sublist(0, 19);
    var code =
        '''$_header
@stateClass
class AppState {
${names.map((name) => '  final int $name = 0;').join('\n')}

  @override
  bool operator ==(Object other) =>
      other is AppState && ${names.map((name) => '$name == other.$name').join(' && ')};

  @override
  int get hashCode => Object.hash(${present.join(', ')});
}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'hashCode =>', length: 'hashCode'.length),
    ]);
    // `Object.hash` accepts at most 20 values.
    await assertFix(code, AddMissingFieldsToEquality.new, null);
  }

  Future<void> test_subclass() async {
    var code = '''$_header
@stateClass
abstract class Base {}

class AppState extends Base {
  final int counter;
  final bool waiting;

  AppState(this.counter, this.waiting);

  @override
  bool operator ==(Object other) => other is AppState && counter == other.counter;

  @override
  int get hashCode => Object.hash(counter, waiting);
}
''';
    await assertDiagnostics(code, [lintAt(code, '==(', length: '=='.length)]);
  }

  Future<void> test_notStateClass_isIgnored() async {
    await assertNoDiagnostics('''$_header
class AppState {
  final int counter;
  final bool waiting;

  AppState(this.counter, this.waiting);

  @override
  bool operator ==(Object other) => other is AppState && counter == other.counter;

  @override
  int get hashCode => counter.hashCode;
}
''');
  }
}

@reflectiveTest
class EqualityMissingInheritedFieldTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = EqualityMissingInheritedFieldRule();
    super.setUp();
  }

  static const _base = '''
@stateClass
class Base {
  final int counter;
  Base(this.counter);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Base && runtimeType == other.runtimeType && counter == other.counter;

  @override
  int get hashCode => counter.hashCode;
}
''';

  Future<void> test_callsSuper() async {
    await assertNoDiagnostics('''$_header
$_base
class Sub extends Base {
  final String name;
  Sub(super.counter, this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Sub && super == other && name == other.name;

  @override
  int get hashCode => Object.hash(super.hashCode, name);
}
''');
  }

  Future<void> test_usesInheritedFields() async {
    await assertNoDiagnostics('''$_header
$_base
class Sub extends Base {
  final String name;
  Sub(super.counter, this.name);

  @override
  bool operator ==(Object other) =>
      other is Sub && counter == other.counter && name == other.name;

  @override
  int get hashCode => Object.hash(counter, name);
}
''');
  }

  Future<void> test_missingSuper() async {
    var code =
        '''$_header
$_base
class Sub extends Base {
  final String name;
  Sub(super.counter, this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Sub &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => Object.hash(name, 0);
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        '==(',
        occurrence: 2,
        length: '=='.length,
        messageContainsAll: ["Inherited field 'counter' is missing from '=='."],
      ),
      lintAt(
        code,
        'hashCode => Object',
        length: 'hashCode'.length,
        messageContainsAll: ["Inherited field 'counter' is missing from 'hashCode'."],
      ),
    ]);
    await assertFix(code, AddInheritedFieldsToEquality.new, '''$_header
$_base
class Sub extends Base {
  final String name;
  Sub(super.counter, this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Sub &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          super == other;

  @override
  int get hashCode => Object.hash(name, 0);
}
''');
  }

  Future<void> test_missingSuperHashCode() async {
    var code =
        '''$_header
$_base
class Sub extends Base {
  final String name;
  Sub(super.counter, this.name);

  @override
  bool operator ==(Object other) => other is Sub && super == other && name == other.name;

  @override
  int get hashCode => Object.hash(name, 0);
}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'hashCode => Object', length: 'hashCode'.length),
    ]);
    await assertFix(code, AddInheritedFieldsToEquality.new, '''$_header
$_base
class Sub extends Base {
  final String name;
  Sub(super.counter, this.name);

  @override
  bool operator ==(Object other) => other is Sub && super == other && name == other.name;

  @override
  int get hashCode => Object.hash(name, 0, super.hashCode);
}
''');
  }

  Future<void> test_superWithoutEquality_addsFields() async {
    var code = '''$_header
@stateClass
abstract class Base {
  final int counter;
  Base(this.counter);
}

class Sub extends Base {
  final String name;
  Sub(super.counter, this.name);

  @override
  bool operator ==(Object other) => other is Sub && name == other.name;

  @override
  int get hashCode => Object.hash(counter, name);
}
''';
    // 'super == other' would be the identity of 'Object', so the fields are needed.
    await assertDiagnostics(code, [
      lintAt(
        code,
        '==(',
        length: '=='.length,
        messageContainsAll: ["Inherited field 'counter' is missing from '=='."],
      ),
    ]);
    await assertFix(code, AddInheritedFieldsToEquality.new, '''$_header
@stateClass
abstract class Base {
  final int counter;
  Base(this.counter);
}

class Sub extends Base {
  final String name;
  Sub(super.counter, this.name);

  @override
  bool operator ==(Object other) => other is Sub && name == other.name && counter == other.counter;

  @override
  int get hashCode => Object.hash(counter, name);
}
''');
  }

  Future<void> test_mixinFields() async {
    var code = '''$_header
mixin Named {
  final String name = '';
}

@stateClass
class AppState with Named {
  final int counter;
  AppState(this.counter);

  @override
  bool operator ==(Object other) =>
      other is AppState && counter == other.counter && name == other.name;

  @override
  int get hashCode => Object.hash(counter, 0);
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'hashCode =>',
        length: 'hashCode'.length,
        messageContainsAll: ["Inherited field 'name' is missing from 'hashCode'."],
      ),
    ]);
  }
}
