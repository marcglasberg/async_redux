import 'package:async_redux_lints/src/fixes/equatable_props_fixes.dart';
import 'package:async_redux_lints/src/rules/equatable_props_missing_field_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'equatable_stub.dart';
import 'rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(EquatablePropsMissingFieldTest);
  });
}

const _header = r'''
import 'package:async_redux/async_redux.dart';
import 'package:equatable/equatable.dart';

// Avoid unused import warnings in tests that don't use these imports.
const usesAsyncRedux = stateClass;
typedef UsesEquatable = Equatable;
''';

const _base = r'''
@stateClass
class Base extends Equatable {
  final int counter;
  const Base(this.counter);

  @override
  List<Object?> get props => [counter];
}
''';

@reflectiveTest
class EquatablePropsMissingFieldTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = EquatablePropsMissingFieldRule();
    addEquatablePackage(this);
    super.setUp();
  }

  Future<void> test_allFields() async {
    await assertNoDiagnostics('''$_header
$_base
class Sub extends Base {
  final String name;
  const Sub(super.counter, this.name);

  @override
  List<Object?> get props => [...super.props, name];
}

class Explicit extends Base {
  final String name;
  const Explicit(super.counter, this.name);

  @override
  List<Object?> get props => [counter, name];
}
''');
  }

  Future<void> test_missingField() async {
    var code = '''$_header
@stateClass
class AppState extends Equatable {
  final int counter;
  final String name;
  const AppState(this.counter, this.name);

  @override
  List<Object?> get props => [counter];
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'props =>',
        length: 'props'.length,
        messageContainsAll: ["Field 'name' is missing from 'props'."],
      ),
    ]);
    await assertFix(code, AddMissingFieldsToProps.new, '''$_header
@stateClass
class AppState extends Equatable {
  final int counter;
  final String name;
  const AppState(this.counter, this.name);

  @override
  List<Object?> get props => [counter, name];
}
''');
  }

  Future<void> test_equatableMixin() async {
    var code = '''$_header
@stateClass
class AppState with EquatableMixin {
  final int counter;
  AppState(this.counter);

  @override
  List<Object?> get props => [];
}
''';
    await assertDiagnostics(code, [lintAt(code, 'props =>', length: 'props'.length)]);
    await assertFix(code, AddMissingFieldsToProps.new, '''$_header
@stateClass
class AppState with EquatableMixin {
  final int counter;
  AppState(this.counter);

  @override
  List<Object?> get props => [counter];
}
''');
  }

  Future<void> test_missingSuperProps() async {
    var code =
        '''$_header
$_base
class Sub extends Base {
  final String name;
  final bool flag;
  const Sub(super.counter, this.name, this.flag);

  @override
  List<Object?> get props => [name];
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'props => [name]',
        length: 'props'.length,
        messageContainsAll: ["Fields 'flag' and 'counter' are missing from 'props'."],
      ),
    ]);
    await assertFix(code, AddMissingFieldsToProps.new, '''$_header
$_base
class Sub extends Base {
  final String name;
  final bool flag;
  const Sub(super.counter, this.name, this.flag);

  @override
  List<Object?> get props => [...super.props, name, flag];
}
''');
  }

  Future<void> test_missingSuperProps_multiline() async {
    var code =
        '''$_header
$_base
class Sub extends Base {
  final String name;
  final bool flag;
  const Sub(super.counter, this.name, this.flag);

  @override
  List<Object?> get props => [
        name,
      ];
}
''';
    await assertFix(code, AddMissingFieldsToProps.new, '''$_header
$_base
class Sub extends Base {
  final String name;
  final bool flag;
  const Sub(super.counter, this.name, this.flag);

  @override
  List<Object?> get props => [
        ...super.props,
        name,
        flag,
      ];
}
''');
  }

  Future<void> test_abstractSuperWithoutProps_addsFields() async {
    var code = '''$_header
@stateClass
abstract class Base extends Equatable {
  final int counter;
  const Base(this.counter);
}

class Sub extends Base {
  final String name;
  const Sub(super.counter, this.name);

  @override
  List<Object?> get props => [name];
}
''';
    // The abstract class without 'props' is not reported, but its subclass must
    // list the inherited field, since there's no 'super.props' to call.
    await assertDiagnostics(code, [
      lintAt(
        code,
        'props =>',
        length: 'props'.length,
        messageContainsAll: ["Field 'counter' is missing from 'props'."],
      ),
    ]);
    await assertFix(code, AddMissingFieldsToProps.new, '''$_header
@stateClass
abstract class Base extends Equatable {
  final int counter;
  const Base(this.counter);
}

class Sub extends Base {
  final String name;
  const Sub(super.counter, this.name);

  @override
  List<Object?> get props => [name, counter];
}
''');
  }

  Future<void> test_noProps() async {
    var code =
        '''$_header
$_base
class Sub extends Base {
  final String name;
  const Sub(super.counter, this.name);
}
''';
    // 'Sub' inherits 'props', which doesn't have 'name'.
    await assertDiagnostics(code, [
      lintAt(
        code,
        'Sub extends',
        length: 'Sub'.length,
        messageContainsAll: ["Field 'name' is missing from 'props'."],
      ),
    ]);
    await assertFix(code, AddMissingFieldsToProps.new, null);
  }

  Future<void> test_constList_fixNotOffered() async {
    var code = '''$_header
@stateClass
class AppState extends Equatable {
  final int counter;
  const AppState(this.counter);

  @override
  List<Object?> get props => const [];
}
''';
    await assertDiagnostics(code, [lintAt(code, 'props =>', length: 'props'.length)]);
    await assertFix(code, AddMissingFieldsToProps.new, null);
  }

  Future<void> test_notStateClass_isIgnored() async {
    await assertNoDiagnostics('''$_header
class AppState extends Equatable {
  final int counter;
  final String name;
  const AppState(this.counter, this.name);

  @override
  List<Object?> get props => [counter];
}
''');
  }
}
