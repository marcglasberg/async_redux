import 'package:async_redux_lints/src/rules/state_class_must_be_immutable_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(StateClassMustBeImmutableTest);
  });
}

@reflectiveTest
class StateClassMustBeImmutableTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = StateClassMustBeImmutableRule();
    super.setUp();
  }

  Future<void> test_allFieldsFinal() async {
    await assertNoDiagnostics('''$header
@stateClass
class A {
  static int count = 0;
  final int x;
  final int y = 0;
  int get z => x;
  set z(int value) {}
  A(this.x);
}
''');
  }

  Future<void> test_notAnnotated() async {
    await assertNoDiagnostics('''$header
class A {
  int x = 0;
}
''');
  }

  Future<void> test_nonFinalField() async {
    var code = '''$header
@stateClass
class A {
  int x = 0;
  final int y = 0;
  late String z;
}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'A {', length: 1, messageContainsAll: ['A.x, A.z']),
    ]);
  }

  Future<void> test_constructorAnnotation() async {
    var code = '''$header
@StateClass()
class A {
  int x = 0;
}
''';
    await assertDiagnostics(code, [lintAt(code, 'A {', length: 1)]);
  }

  Future<void> test_annotationFromOtherPackage() async {
    await assertNoDiagnostics('''$header
class StateClass {
  const StateClass();
}

@StateClass()
class A {
  int x = 0;
}
''');
  }

  Future<void> test_subclass() async {
    var code = '''$header
@stateClass
class A {
  final int x = 0;
}

class B extends A {
  int y = 0;
}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'B extends', length: 1, messageContainsAll: ['B.y']),
    ]);
  }

  Future<void> test_inheritedNonFinalField() async {
    var code = '''$header
class A {
  int x = 0;
}

@stateClass
class B extends A {
  final int y = 0;
}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'B extends', length: 1, messageContainsAll: ['A.x']),
    ]);
  }

  Future<void> test_implementsStateClass() async {
    var code = '''$header
@stateClass
abstract class A {}

class B implements A {
  int x = 0;
}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'B implements', length: 1, messageContainsAll: ['B.x']),
    ]);
  }

  Future<void> test_mixin() async {
    var code = '''$header
@stateClass
mixin M {
  int x = 0;
}

class A with M {}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'M {', length: 1, messageContainsAll: ['M.x']),
      lintAt(code, 'A with', length: 1, messageContainsAll: ['M.x']),
    ]);
  }

  Future<void> test_mixinNonFinalFieldOnStateClass() async {
    var code = '''$header
mixin M {
  int x = 0;
}

@stateClass
class A with M {}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'A with', length: 1, messageContainsAll: ['M.x']),
    ]);
  }

  Future<void> test_classTypeAlias() async {
    var code = '''$header
@stateClass
class A {}

mixin M {
  int x = 0;
}

class B = A with M;
''';
    await assertDiagnostics(code, [
      lintAt(code, 'B =', length: 1, messageContainsAll: ['M.x']),
    ]);
  }
}
