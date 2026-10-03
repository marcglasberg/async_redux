import 'package:async_redux_lints/src/fixes/vm_equals_fixes.dart';
import 'package:async_redux_lints/src/rules/vm_field_not_in_equals_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'widget_rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(VmFieldNotInEqualsTest);
  });
}

@reflectiveTest
class VmFieldNotInEqualsTest extends AsyncReduxWidgetRuleTest {
  @override
  void setUp() {
    rule = VmFieldNotInEqualsRule();
    super.setUp();
  }

  Future<void> test_allFieldsInEquals() async {
    await assertNoDiagnostics('''$widgetHeader
class Event {}

class ViewModel extends Vm {
  final int counter;
  final String? description;
  final Event? event;
  final VoidCallback onIncrement;
  final void Function(int) onSet;
  final int constant = 42;
  static int count = 0;

  ViewModel({
    required this.counter,
    this.description,
    this.event,
    required this.onIncrement,
    required this.onSet,
  }) : super(equals: [counter, description, event!]);
}
''');
  }

  Future<void> test_missingField() async {
    var code = '''$widgetHeader
class ViewModel extends Vm {
  final int counter;
  final String description;
  final VoidCallback onIncrement;

  ViewModel({
    required this.counter,
    required this.description,
    required this.onIncrement,
  }) : super(equals: [counter]);
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'description;',
        length: 'description'.length,
        messageContainsAll: ["The field 'description' is missing from 'equals'"],
      ),
    ]);
    await assertFix(code, AddFieldToVmEquals.new, '''$widgetHeader
class ViewModel extends Vm {
  final int counter;
  final String description;
  final VoidCallback onIncrement;

  ViewModel({
    required this.counter,
    required this.description,
    required this.onIncrement,
  }) : super(equals: [counter, description]);
}
''');
    await assertFix(code, AddAllFieldsToVmEquals.new, null);
  }

  Future<void> test_noEquals() async {
    var code = '''$widgetHeader
class ViewModel extends Vm {
  final int counter;
  final String description;

  ViewModel({required this.counter, required this.description});
}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'counter;', length: 'counter'.length),
      lintAt(code, 'description;', length: 'description'.length),
    ]);
    await assertFix(code, AddFieldToVmEquals.new, '''$widgetHeader
class ViewModel extends Vm {
  final int counter;
  final String description;

  ViewModel({required this.counter, required this.description}) : super(equals: [counter]);
}
''');
    await assertFix(code, AddAllFieldsToVmEquals.new, '''$widgetHeader
class ViewModel extends Vm {
  final int counter;
  final String description;

  ViewModel({required this.counter, required this.description}) : super(equals: [counter, description]);
}
''');
  }

  Future<void> test_superWithoutEquals() async {
    var code = '''$widgetHeader
class ViewModel extends Vm {
  final int counter;

  ViewModel(this.counter) : assert(counter >= 0), super();
}
''';
    await assertDiagnostics(code, [lintAt(code, 'counter;', length: 'counter'.length)]);
    await assertFix(code, AddFieldToVmEquals.new, '''$widgetHeader
class ViewModel extends Vm {
  final int counter;

  ViewModel(this.counter) : assert(counter >= 0), super(equals: [counter]);
}
''');
  }

  Future<void> test_multilineList() async {
    var code = '''$widgetHeader
class ViewModel extends Vm {
  final int counter;
  final String description;

  ViewModel({required this.counter, required this.description})
      : super(equals: [
          counter,
        ]);
}
''';
    await assertFix(code, AddFieldToVmEquals.new, '''$widgetHeader
class ViewModel extends Vm {
  final int counter;
  final String description;

  ViewModel({required this.counter, required this.description})
      : super(equals: [
          counter,
          description,
        ]);
}
''');
  }

  Future<void> test_constEmptyList() async {
    var code = '''$widgetHeader
class ViewModel extends Vm {
  final int counter;

  ViewModel(this.counter) : super(equals: const []);
}
''';
    await assertFix(code, AddFieldToVmEquals.new, '''$widgetHeader
class ViewModel extends Vm {
  final int counter;

  ViewModel(this.counter) : super(equals: [counter]);
}
''');
  }

  Future<void> test_fieldInitializer() async {
    var code = '''$widgetHeader
class ViewModel extends Vm {
  final int counter;
  final int doubled;
  final String label;

  ViewModel(this.counter, int value)
      : doubled = value * 2,
        label = 'fixed',
        super(equals: [counter]);
}
''';
    await assertDiagnostics(code, [lintAt(code, 'doubled;', length: 'doubled'.length)]);
    await assertFix(code, AddFieldToVmEquals.new, '''$widgetHeader
class ViewModel extends Vm {
  final int counter;
  final int doubled;
  final String label;

  ViewModel(this.counter, int value)
      : doubled = value * 2,
        label = 'fixed',
        super(equals: [counter, value]);
}
''');
  }

  Future<void> test_fieldInitializer_parameterInEquals() async {
    await assertNoDiagnostics('''$widgetHeader
class ViewModel extends Vm {
  final int doubled;

  ViewModel(int value)
      : doubled = value * 2,
        super(equals: [value]);
}
''');
  }

  Future<void> test_twoConstructors() async {
    var code = '''$widgetHeader
class ViewModel extends Vm {
  final int counter;

  ViewModel(this.counter) : super(equals: [counter]);

  ViewModel.other(this.counter) : super(equals: []);

  ViewModel.zero() : counter = 0, super(equals: []);
}
''';
    await assertDiagnostics(code, [lintAt(code, 'counter;', length: 'counter'.length)]);
    await assertFix(code, AddFieldToVmEquals.new, '''$widgetHeader
class ViewModel extends Vm {
  final int counter;

  ViewModel(this.counter) : super(equals: [counter]);

  ViewModel.other(this.counter) : super(equals: [counter]);

  ViewModel.zero() : counter = 0, super(equals: []);
}
''');
  }

  Future<void> test_indirectSubclass() async {
    var code = '''$widgetHeader
abstract class BaseVm extends Vm {
  BaseVm({required super.equals});
}

class ViewModel extends BaseVm {
  final int counter;
  final String name;

  ViewModel(this.counter, this.name) : super(equals: [counter]);
}

class OtherViewModel extends BaseVm {
  final int counter;

  OtherViewModel(this.counter) : super(equals: list());

  static List<Object?> list() => [];
}
''';
    await assertDiagnostics(code, [lintAt(code, 'name;', length: 'name'.length)]);
  }

  Future<void> test_superParameters_areIgnored() async {
    await assertNoDiagnostics('''$widgetHeader
class ViewModel extends Vm {
  final int counter;

  ViewModel(this.counter, {super.equals});
}
''');
  }

  Future<void> test_overridesEquals_isIgnored() async {
    await assertNoDiagnostics('''$widgetHeader
class ViewModel extends Vm {
  final bool rebuild;

  ViewModel({required this.rebuild});

  @override
  bool operator ==(Object other) => !rebuild;

  @override
  int get hashCode => rebuild.hashCode;
}

abstract class BaseVm extends Vm {
  @override
  bool operator ==(Object other) => false;

  @override
  int get hashCode => 0;
}

class OtherViewModel extends BaseVm {
  final int counter;

  OtherViewModel(this.counter);
}
''');
  }

  Future<void> test_notVm_isIgnored() async {
    await assertNoDiagnostics('''$widgetHeader
class NotVm {
  final int counter;

  NotVm(this.counter);
}
''');
  }
}
