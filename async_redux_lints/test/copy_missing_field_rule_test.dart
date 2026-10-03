import 'package:async_redux_lints/src/fixes/copy_fixes.dart';
import 'package:async_redux_lints/src/rules/copy_missing_field_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(CopyMissingFieldTest);
  });
}

const _header = r'''
import 'package:async_redux/async_redux.dart';

// Avoid unused import warnings in tests that don't use this import.
const usesAsyncRedux = stateClass;
''';

@reflectiveTest
class CopyMissingFieldTest extends AsyncReduxRuleTest {
  @override
  bool get addMetaPackageDep => true;

  @override
  void setUp() {
    rule = CopyMissingFieldRule();
    super.setUp();
  }

  Future<void> test_allFieldsInCopy() async {
    await assertNoDiagnostics('''$_header
@stateClass
class AppState {
  static int count = 0;
  final int counter;
  final String? name;
  final int doubled;
  final int constant = 42;
  final int _secret;

  AppState({required this.counter, this.name, int secret = 0})
    : doubled = counter * 2,
      _secret = secret;

  AppState copy({int? counter, String? name}) =>
      AppState(counter: counter ?? this.counter, name: name ?? this.name, secret: _secret);
}
''');
  }

  Future<void> test_missingField() async {
    var code = '''$_header
@stateClass
class AppState {
  final int counter;
  final String name;

  AppState({required this.counter, this.name = ''});

  AppState copy({int? counter}) => AppState(counter: counter ?? this.counter);
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'copy(',
        length: 'copy'.length,
        messageContainsAll: ["Field 'name' is missing from 'copy'."],
      ),
    ]);
    await assertFix(code, AddMissingFieldsToCopy.new, '''$_header
@stateClass
class AppState {
  final int counter;
  final String name;

  AppState({required this.counter, this.name = ''});

  AppState copy({int? counter, String? name}) => AppState(counter: counter ?? this.counter, name: name ?? this.name);
}
''');
  }

  Future<void> test_copyWith() async {
    var code = '''$_header
@stateClass
class AppState {
  final int counter;
  final String name;

  AppState({this.counter = 0, this.name = ''});

  AppState copyWith({String? name}) => AppState(name: name ?? this.name);
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'copyWith(',
        length: 'copyWith'.length,
        messageContainsAll: ["Field 'counter' is missing from 'copyWith'."],
      ),
    ]);
    await assertFix(code, AddMissingFieldsToCopy.new, '''$_header
@stateClass
class AppState {
  final int counter;
  final String name;

  AppState({this.counter = 0, this.name = ''});

  AppState copyWith({String? name, int? counter}) => AppState(name: name ?? this.name, counter: counter ?? this.counter);
}
''');
  }

  Future<void> test_unusedParameter() async {
    var code = '''$_header
@stateClass
class AppState {
  final int counter;
  final bool waiting;

  AppState({
    required this.counter,
    required this.waiting,
  });

  AppState copy({
    int? counter,
    bool? waiting,
  }) =>
      AppState(
        counter: 0,
        waiting: waiting ?? this.waiting,
      );
}
''';
    // Reported on the method, not on the parameter.
    await assertDiagnostics(code, [
      lintAt(
        code,
        'copy(',
        length: 'copy'.length,
        messageContainsAll: ["Field 'counter' is missing from 'copy'."],
      ),
    ]);
    // Never changes the existing argument `counter: 0`.
    await assertFix(code, AddMissingFieldsToCopy.new, null);
  }

  Future<void> test_unusedParameter_noArgument() async {
    var code = '''$_header
@stateClass
class AppState {
  final int counter;
  final bool waiting;

  AppState({this.counter = 0, this.waiting = false});

  AppState copy({int? counter, bool? waiting}) => AppState(waiting: waiting ?? this.waiting);
}
''';
    await assertDiagnostics(code, [lintAt(code, 'copy(', length: 'copy'.length)]);
    await assertFix(code, AddMissingFieldsToCopy.new, '''$_header
@stateClass
class AppState {
  final int counter;
  final bool waiting;

  AppState({this.counter = 0, this.waiting = false});

  AppState copy({int? counter, bool? waiting}) => AppState(waiting: waiting ?? this.waiting, counter: counter ?? this.counter);
}
''');
  }

  Future<void> test_argumentWithoutParameter_fixNotOffered() async {
    var code = '''$_header
@stateClass
class AppState {
  final int counter;
  final String name;

  AppState({required this.counter, required this.name});

  AppState copy({int? counter}) => AppState(counter: counter ?? this.counter, name: this.name);
}
''';
    await assertDiagnostics(code, [lintAt(code, 'copy(', length: 'copy'.length)]);
    // Never changes the existing argument `name: this.name`.
    await assertFix(code, AddMissingFieldsToCopy.new, null);
  }

  Future<void> test_severalFields() async {
    var code = '''$_header
@stateClass
class AppState {
  final int counter;
  final String? name;
  final List<int> items;
  final bool waiting;

  AppState({
    required this.counter,
    this.name,
    this.items = const [],
    required this.waiting,
  });

  AppState copy({
    int? counter,
  }) {
    return AppState(
      counter: counter ?? this.counter,
      waiting: this.waiting,
    );
  }
}
''';
    // A single diagnostic for the method.
    await assertDiagnostics(code, [
      lintAt(
        code,
        'copy(',
        length: 'copy'.length,
        messageContainsAll: [
          "Fields 'name', 'items' and 'waiting' are missing from 'copy'.",
        ],
      ),
    ]);
    // A single fix for the fields that can be added. 'waiting' already has an
    // argument, so it's left as it is.
    await assertFix(code, AddMissingFieldsToCopy.new, '''$_header
@stateClass
class AppState {
  final int counter;
  final String? name;
  final List<int> items;
  final bool waiting;

  AppState({
    required this.counter,
    this.name,
    this.items = const [],
    required this.waiting,
  });

  AppState copy({
    int? counter,
    String? name,
    List<int>? items,
  }) {
    return AppState(
      counter: counter ?? this.counter,
      waiting: this.waiting,
      name: name ?? this.name,
      items: items ?? this.items,
    );
  }
}
''');
  }

  Future<void> test_twoFields() async {
    var code = '''$_header
@stateClass
class AppState {
  final int counter;
  final bool waiting;

  AppState({this.counter = 0, this.waiting = false});

  AppState copy() => AppState();
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'copy(',
        length: 'copy'.length,
        messageContainsAll: ["Fields 'counter' and 'waiting' are missing from 'copy'."],
      ),
    ]);
    await assertFix(code, AddMissingFieldsToCopy.new, '''$_header
@stateClass
class AppState {
  final int counter;
  final bool waiting;

  AppState({this.counter = 0, this.waiting = false});

  AppState copy({int? counter, bool? waiting}) => AppState(counter: counter ?? this.counter, waiting: waiting ?? this.waiting);
}
''');
  }

  Future<void> test_positionalNotPassed_fixNotOffered() async {
    var code = '''$_header
@stateClass
class AppState {
  final int counter;

  AppState([this.counter = 0]);

  AppState copy() => AppState();
}
''';
    await assertDiagnostics(code, [lintAt(code, 'copy(', length: 'copy'.length)]);
    // The constructor's parameter is positional and not passed.
    await assertFix(code, AddMissingFieldsToCopy.new, null);
  }

  Future<void> test_positionalArgument_fixNotOffered() async {
    var code = '''$_header
@stateClass
class AppState {
  final int counter;
  final String name;

  AppState(this.counter, this.name);

  AppState copy(String name) => AppState(this.counter, name);
}
''';
    await assertDiagnostics(code, [lintAt(code, 'copy(', length: 'copy'.length)]);
    // Never changes the existing argument `this.counter`.
    await assertFix(code, AddMissingFieldsToCopy.new, null);
  }

  Future<void> test_fieldInitializer() async {
    var code = '''$_header
@stateClass
class AppState {
  final int counter;

  AppState({int? counter}) : counter = counter ?? 0;

  AppState copy() => AppState();
}
''';
    await assertDiagnostics(code, [lintAt(code, 'copy(', length: 'copy'.length)]);
    await assertFix(code, AddMissingFieldsToCopy.new, '''$_header
@stateClass
class AppState {
  final int counter;

  AppState({int? counter}) : counter = counter ?? 0;

  AppState copy({int? counter}) => AppState(counter: counter ?? this.counter);
}
''');
  }

  Future<void> test_copyAndCopyWith() async {
    var code = '''$_header
@stateClass
class AppState {
  final int counter;
  final String name;

  AppState({required this.counter, this.name = ''});

  AppState copy({int? counter}) => AppState(counter: counter ?? this.counter);

  AppState copyWith({int? counter}) => AppState(counter: counter ?? this.counter);
}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'copy(', length: 'copy'.length, messageContainsAll: ["'copy'"]),
      lintAt(
        code,
        'copyWith(',
        length: 'copyWith'.length,
        messageContainsAll: ["'copyWith'"],
      ),
    ]);
    // The fix only changes the method it's reported on.
    await assertFix(code, AddMissingFieldsToCopy.new, '''$_header
@stateClass
class AppState {
  final int counter;
  final String name;

  AppState({required this.counter, this.name = ''});

  AppState copy({int? counter, String? name}) => AppState(counter: counter ?? this.counter, name: name ?? this.name);

  AppState copyWith({int? counter}) => AppState(counter: counter ?? this.counter);
}
''');
  }

  Future<void> test_abstractCopy() async {
    var code = '''$_header
@stateClass
abstract class Base {
  final int counter;

  Base(this.counter);

  Base copy();
}
''';
    await assertDiagnostics(code, [lintAt(code, 'copy(', length: 'copy'.length)]);
    await assertFix(code, AddMissingFieldsToCopy.new, '''$_header
@stateClass
abstract class Base {
  final int counter;

  Base(this.counter);

  Base copy({int? counter});
}
''');
  }

  Future<void> test_subclasses() async {
    var code = '''$_header
@stateClass
abstract class Base {}

@stateClass
mixin Mixin {}

class Extends extends Base {
  final int counter;
  Extends({this.counter = 0});
  Extends copy() => Extends();
}

class Implements implements Base {
  final int counter;
  Implements({this.counter = 0});
  Implements copy() => Implements();
}

class Mixes with Mixin {
  final int counter;
  Mixes({this.counter = 0});
  Mixes copy() => Mixes();
}

class Indirect extends Extends {
  final String name;
  Indirect({this.name = ''});
  @override
  Indirect copy() => Indirect();
}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'copy(', occurrence: 1, length: 'copy'.length),
      lintAt(code, 'copy(', occurrence: 2, length: 'copy'.length),
      lintAt(code, 'copy(', occurrence: 3, length: 'copy'.length),
      lintAt(
        code,
        'copy(',
        occurrence: 4,
        length: 'copy'.length,
        messageContainsAll: ["Field 'name' is missing"],
      ),
    ]);
  }

  Future<void> test_immutable_isIgnored() async {
    await assertNoDiagnostics('''
import 'package:meta/meta.dart';

@immutable
class AppState {
  final int counter;
  final String name;

  AppState({required this.counter, this.name = ''});

  AppState copy({int? counter}) => AppState(counter: counter ?? this.counter);
}
''');
  }

  Future<void> test_notAnnotated_isIgnored() async {
    await assertNoDiagnostics('''$_header
class AppState {
  final int counter;
  final String name;

  AppState({required this.counter, this.name = ''});

  AppState copy({int? counter}) => AppState(counter: counter ?? this.counter);
}
''');
  }

  Future<void> test_otherMethods_areIgnored() async {
    await assertNoDiagnostics('''$_header
@stateClass
class AppState {
  final int counter;

  AppState({required this.counter});

  AppState clone() => AppState(counter: counter);

  static AppState copy(AppState state) => AppState(counter: state.counter);
}
''');
  }
}
