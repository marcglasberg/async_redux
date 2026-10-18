import 'package:async_redux_lints/src/fixes/state_class_fixes.dart';
import 'package:async_redux_lints/src/rules/missing_state_class_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(MissingStateClassTest);
    defineReflectiveTests(MissingStateClassWithFlutterTest);
  });
}

const _ficStub = r'''
class IList<T> {
  const IList.empty();
}
''';

const _ficImport =
    "import 'package:fast_immutable_collections/fast_immutable_collections.dart';";

@reflectiveTest
class MissingStateClassTest extends AsyncReduxRuleTest {
  @override
  bool get addMetaPackageDep => true;

  @override
  void setUp() {
    rule = MissingStateClassRule();
    newPackage(
      'fast_immutable_collections',
    ).addFile('lib/fast_immutable_collections.dart', _ficStub);
    newPackage('models').addFile('lib/models.dart', 'class User {}');
    super.setUp();
  }

  // The store's state class.

  Future<void> test_storeState_fromActionInTheSameFile() async {
    var code = '''$header
class MyState {}

class MyAction extends ReduxAction<MyState> {
  @override
  MyState? reduce() => null;
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'MyState {',
        length: 7,
        messageContainsAll: ["The store's state class 'MyState'"],
        correctionContains: "Try annotating 'MyState' with '@stateClass'",
      ),
    ]);
  }

  Future<void> test_storeState_annotated() async {
    await assertNoDiagnostics('''$header
@stateClass
class MyState {}

class MyAction extends ReduxAction<MyState> {
  @override
  MyState? reduce() => null;
}

var store = Store<MyState>(initialState: MyState());
''');
  }

  Future<void> test_storeState_inheritsAnnotation() async {
    await assertNoDiagnostics('''$header
@stateClass
abstract class BaseState {}

class MyState extends BaseState {}

class MyAction extends ReduxAction<MyState> {
  @override
  MyState? reduce() => null;
}
''');
  }

  Future<void> test_storeState_fromImportedAction() async {
    newFile('$testPackageLibPath/app_action.dart', '''
import 'package:async_redux/async_redux.dart';
import 'test.dart';

abstract class AppAction extends ReduxAction<MyState> {}
''');
    var code =
        '''import 'app_action.dart';
$header
class MyState {}

typedef UsesAppAction = AppAction;
''';
    await assertDiagnostics(code, [lintAt(code, 'MyState {', length: 7)]);
  }

  Future<void> test_storeState_fromStoreOfAnotherFile() async {
    newFile('$testPackageLibPath/my_state.dart', '''
class MyState {}
''');
    var code =
        '''import 'my_state.dart';
$header
var store = Store<MyState>(initialState: MyState());
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'Store<MyState>',
        messageContainsAll: ["The store's state class 'MyState'"],
      ),
    ]);
  }

  /// The type of the store is inferred from its initial state.
  Future<void> test_storeState_inferredStore() async {
    var code = '''$header
class MyState {}

var store = Store(initialState: MyState());
''';
    await assertDiagnostics(code, [lintAt(code, 'Store(', length: 5)]);
  }

  /// When an action of the same file uses the state, it's reported only once, at the
  /// declaration.
  Future<void> test_storeState_reportedOnce() async {
    var code = '''$header
class MyState {}

class MyAction extends ReduxAction<MyState> {
  @override
  MyState? reduce() => null;
}

var store = Store<MyState>(initialState: MyState());
''';
    await assertDiagnostics(code, [lintAt(code, 'MyState {', length: 7)]);
  }

  Future<void> test_storeState_notOwnClass() async {
    await assertNoDiagnostics('''$header
var store = Store<int>(initialState: 0);
var otherStore = Store<String>();

class MyAction extends ReduxAction<int> {
  @override
  int? reduce() => null;
}
''');
  }

  Future<void> test_storeState_notReportedInTests() async {
    await assertNotReportedInTests('''$header
class MyState {}

var store = Store<MyState>(initialState: MyState());
''');
  }

  /// Without actions or stores, a class is not known to be the store's state.
  Future<void> test_notStoreState() async {
    await assertNoDiagnostics('''$header
class MyState {}

var state = MyState();
''');
  }

  // The classes held by the fields of state classes.

  Future<void> test_fields() async {
    var code =
        '''$_ficImport
$header
@stateClass
class MyState {
  final IList<User> users;
  final (Address, int) record;
  final Wrapper? wrapper;
  final Annotated annotated;
  final InheritsAnnotation inherits;
  final Color color;
  final Id id;
  final int Function(Address) function;
  final Store<int>? store;
  final String text;
  final _Private _private;
  static Address defaultAddress = Address();
  Address get address => Address();
  MyState(
    this.users,
    this.record,
    this.wrapper,
    this.annotated,
    this.inherits,
    this.color,
    this.id,
    this.function,
    this.store,
    this.text,
    this._private,
  );
  bool get usesPrivate => _private == _Private();
}

class User {}
class Address {}
class Wrapper {}
class _Private {}

@stateClass
class Annotated {}

class InheritsAnnotation extends Annotated {}

enum Color { red }

extension type Id(int value) {}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'users;',
        length: 5,
        messageContainsAll: [
          "The field 'users' of the state class 'MyState' holds 'User', which isn't",
        ],
        correctionContains: "Try annotating 'User' with '@stateClass', so that it's",
      ),
      lintAt(code, 'record;', length: 6, messageContainsAll: ["'Address'"]),
      lintAt(code, 'wrapper;', length: 7, messageContainsAll: ["'Wrapper'"]),
      lintAt(code, '_private;', length: 8, messageContainsAll: ["'_Private'"]),
    ]);
  }

  Future<void> test_field_severalClasses() async {
    var code = '''$header
@stateClass
class MyState {
  final (User, Address, User) pair;
  MyState(this.pair);
}

class User {}
class Address {}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'pair;',
        length: 4,
        messageContainsAll: ["holds 'User' and 'Address', which aren't"],
        correctionContains:
            "Try annotating 'User' and 'Address' with '@stateClass', "
            "so that they're",
      ),
    ]);
  }

  Future<void> test_fields_ofSubclassAndMixin() async {
    var code = '''$header
@stateClass
class MyState {}

class SubState extends MyState {
  final User user;
  SubState(this.user);
}

@stateClass
mixin StateMixin {
  User? get user => mixinUser;
  final User? mixinUser = null;
}

class User {}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'user;', length: 4),
      lintAt(code, 'mixinUser =', length: 9),
    ]);
  }

  /// Only state classes are checked, so a class that is only the store's state,
  /// without the annotation, doesn't have its fields checked.
  Future<void> test_fields_ofClassThatIsNotAnnotated() async {
    await assertNoDiagnostics('''$header
class MyState {
  final User user;
  MyState(this.user);
}

class User {}
''');
  }

  Future<void> test_field_classOfAnotherFile() async {
    newFile('$testPackageLibPath/user.dart', '''
class User {}
''');
    var code =
        '''import 'user.dart';
$header
@stateClass
class MyState {
  final User user;
  MyState(this.user);
}
''';
    await assertDiagnostics(code, [lintAt(code, 'user;', length: 4)]);
  }

  Future<void> test_field_classOfAnotherPackage() async {
    await assertNoDiagnostics('''import 'package:models/models.dart';
$header
@stateClass
class MyState {
  final User user;
  MyState(this.user);
}
''');
  }

  Future<void> test_fields_notReportedInTests() async {
    await assertNotReportedInTests('''$header
@stateClass
class MyState {
  final User user;
  MyState(this.user);
}

class User {}
''');
  }

  // The fix.

  Future<void> test_fix_storeState() async {
    await assertFix(
      '''$header
/// The state.
class MyState {}

class MyAction extends ReduxAction<MyState> {
  @override
  MyState? reduce() => null;
}
''',
      AddStateClassAnnotation.new,
      '''$header
/// The state.
@stateClass
class MyState {}

class MyAction extends ReduxAction<MyState> {
  @override
  MyState? reduce() => null;
}
''',
    );
  }

  Future<void> test_fix_beforeOtherAnnotations() async {
    await assertFix(
      '''$header
@Deprecated('Old')
abstract class MyState {}

class MyAction extends ReduxAction<MyState> {
  @override
  MyState? reduce() => null;
}
''',
      AddStateClassAnnotation.new,
      '''$header
@stateClass
@Deprecated('Old')
abstract class MyState {}

class MyAction extends ReduxAction<MyState> {
  @override
  MyState? reduce() => null;
}
''',
    );
  }

  /// Replaces `@immutable`, and removes the import of `meta` that only it used.
  Future<void> test_fix_replacesImmutable() async {
    await assertFix(
      '''import 'package:meta/meta.dart';
$header
@immutable
class MyState {}

class MyAction extends ReduxAction<MyState> {
  @override
  MyState? reduce() => null;
}
''',
      AddStateClassAnnotation.new,
      '''$header
@stateClass
class MyState {}

class MyAction extends ReduxAction<MyState> {
  @override
  MyState? reduce() => null;
}
''',
    );
  }

  /// Keeps the import of `meta` when something else uses it.
  Future<void> test_fix_replacesImmutable_keepsUsedImport() async {
    await assertFix(
      '''import 'package:meta/meta.dart';
$header
@immutable
class MyState {
  @visibleForTesting
  static int count = 0;
}

class MyAction extends ReduxAction<MyState> {
  @override
  MyState? reduce() => null;
}
''',
      AddStateClassAnnotation.new,
      '''import 'package:meta/meta.dart';
$header
@stateClass
class MyState {
  @visibleForTesting
  static int count = 0;
}

class MyAction extends ReduxAction<MyState> {
  @override
  MyState? reduce() => null;
}
''',
    );
  }

  Future<void> test_fix_fieldClassesInOtherFiles() async {
    var user = newFile('$testPackageLibPath/user.dart', '''
import 'package:meta/meta.dart';

/// A user.
@immutable
class User {}

class Address {}
''');
    var code =
        '''import 'user.dart';
$header
@stateClass
class MyState {
  final (User, Address) pair;
  MyState(this.pair);
}
''';
    await assertFixInFiles(code, AddStateClassAnnotation.new, {
      user.path: '''
import 'package:async_redux/async_redux.dart';

/// A user.
@stateClass
class User {}

@stateClass
class Address {}
''',
    });
  }

  /// The import of `async_redux` is added before another import, and the import of
  /// `meta` is removed.
  Future<void> test_fix_addsImportAndRemovesMetaImport() async {
    var user = newFile('$testPackageLibPath/user.dart', '''
$_ficImport
import 'package:meta/meta.dart';

@immutable
class User {
  final IList<int> ids = const IList.empty();
}
''');
    var code =
        '''import 'user.dart';
$header
@stateClass
class MyState {
  final User user;
  MyState(this.user);
}
''';
    await assertFixInFiles(code, AddStateClassAnnotation.new, {
      user.path:
          '''
import 'package:async_redux/async_redux.dart';
$_ficImport

@stateClass
class User {
  final IList<int> ids = const IList.empty();
}
''',
    });
  }

  Future<void> test_fix_storeStateInAnotherFile() async {
    var state = newFile('$testPackageLibPath/my_state.dart', '''
import 'package:async_redux/async_redux.dart' as redux;

class MyState {}

typedef UsesRedux = redux.ReduxAction<int>;
''');
    var code =
        '''import 'my_state.dart';
$header
var store = Store<MyState>(initialState: MyState());
''';
    await assertFixInFiles(code, AddStateClassAnnotation.new, {
      state.path: '''
import 'package:async_redux/async_redux.dart' as redux;

@redux.stateClass
class MyState {}

typedef UsesRedux = redux.ReduxAction<int>;
''',
    });
  }
}

/// Flutter APIs that the mock Flutter package of `analyzer_testing` doesn't declare.
const _flutterStub = r'''
import 'package:flutter/widgets.dart';

mixin class ChangeNotifier implements Listenable {}
''';

@reflectiveTest
class MissingStateClassWithFlutterTest extends AsyncReduxRuleTest {
  @override
  bool get addFlutterPackageDep => true;

  @override
  void setUp() {
    rule = MissingStateClassRule();
    super.setUp();
    newFile('${addFlutter().path}/src/state_extras.dart', _flutterStub);
  }

  /// Classes that are not state are reported by `non_state_object_in_state`.
  Future<void> test_nonStateClass() async {
    await assertNoDiagnostics('''
import 'package:async_redux/async_redux.dart' hide BuildContext;
import 'package:flutter/src/state_extras.dart';

@stateClass
class MyState {
  final Counter counter;
  MyState(this.counter);
}

class Counter extends ChangeNotifier {}
''');
  }
}
