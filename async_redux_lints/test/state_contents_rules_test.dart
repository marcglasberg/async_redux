import 'package:async_redux_lints/src/fixes/immutable_collection_fixes.dart';
import 'package:async_redux_lints/src/rules/state_contents_rules.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(PreferImmutableCollectionsTest);
    defineReflectiveTests(PreferImmutableCollectionsWithoutPackageTest);
    defineReflectiveTests(NonStateObjectInStateTest);
    defineReflectiveTests(RouteInStateTest);
    defineReflectiveTests(MissingInitialStateTest);
  });
}

/// A stub of package `fast_immutable_collections`.
const _ficStub = r'''
class IList<T> {}
class ISet<T> {}
class IMap<K, V> {}
''';

const _ficImport =
    "import 'package:fast_immutable_collections/fast_immutable_collections.dart';";

/// [header], with the import that the fix adds.
final _headerWithFicImport = header.replaceFirst(
  "import 'package:async_redux/async_redux.dart';",
  "import 'package:async_redux/async_redux.dart';\n$_ficImport",
);

/// Flutter APIs that the mock Flutter package of `analyzer_testing` doesn't declare.
/// Added to the mock package, as `package:flutter/src/state_extras.dart`.
const _flutterStub = r'''
import 'package:flutter/widgets.dart';

mixin class ChangeNotifier implements Listenable {}
class ValueNotifier<T> extends ChangeNotifier {}
class TextEditingController extends ValueNotifier<String> {}
class ScrollController extends ChangeNotifier {}
class FocusNode with ChangeNotifier {}
class GlobalKey<T extends State<StatefulWidget>> extends Key {
  const GlobalKey() : super.empty();
}
''';

/// The start of the tests that use Flutter. Hides the `BuildContext` of the
/// `async_redux` stub, to use Flutter's.
const _flutterHeader = r'''
import 'dart:async';
import 'package:async_redux/async_redux.dart' hide BuildContext;
import 'package:flutter/widgets.dart';
import 'package:flutter/src/state_extras.dart';

// Avoid unused import warnings in tests that don't use these imports.
typedef UsesFutureOr = FutureOr<int>;
typedef UsesAsyncRedux = ReduxAction<int>;
typedef UsesWidgets = Widget;
typedef UsesExtras = ChangeNotifier;
''';

@reflectiveTest
class PreferImmutableCollectionsTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = PreferImmutableCollectionsRule();
    newPackage(
      'fast_immutable_collections',
    ).addFile('lib/fast_immutable_collections.dart', _ficStub);
    super.setUp();
  }

  Future<void> test_mutableCollections() async {
    var code = '''$header
@stateClass
class MyState {
  final List<int> list;
  final Set<String>? set;
  final Map<String, int> map;
  final items = <int>[];
  MyState(this.list, this.set, this.map);
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'list;',
        length: 4,
        messageContainsAll: ["'list'", "'MyState'", "'List'"],
        correctionContains: "'IList'",
      ),
      lintAt(code, 'set;', length: 3, correctionContains: "'ISet'"),
      lintAt(code, 'map;', length: 3, correctionContains: "'IMap'"),
      lintAt(code, 'items', correctionContains: "'IList'"),
    ]);
  }

  Future<void> test_testFiles() async {
    await assertNotReportedInTests('''$header
@stateClass
class MyState {
  final List<int> list;
  MyState(this.list);
}
''');
  }

  Future<void> test_immutableCollectionsAndOtherTypes() async {
    await assertNoDiagnostics('''$_ficImport
$header
@stateClass
class MyState {
  static List<int> cache = [];
  final IList<int> list;
  final ISet<int> set;
  final IMap<String, int> map;
  final Iterable<int> iterable;
  final int counter;
  List<int> get asList => [];
  MyState(this.list, this.set, this.map, this.iterable, this.counter);
}
''');
  }

  Future<void> test_notState() async {
    await assertNoDiagnostics('''$header
class Foo {
  final List<int> list = [];
}
''');
  }

  Future<void> test_subclassOfStateClass() async {
    var code = '''$header
@stateClass
abstract class Base {}

class MyState extends Base {
  final List<int> list = [];
}
''';
    await assertDiagnostics(code, [lintAt(code, 'list =', length: 4)]);
  }

  Future<void> test_stateClassMixin() async {
    var code = '''$header
@stateClass
mixin M {
  final List<int> list = [];
}
''';
    await assertDiagnostics(code, [lintAt(code, 'list =', length: 4)]);
  }

  Future<void> test_storeState_fromAction() async {
    var code = '''$header
class MyState {
  final List<int> list = [];
}

abstract class AppAction extends ReduxAction<MyState> {}
''';
    await assertDiagnostics(code, [lintAt(code, 'list =', length: 4)]);
  }

  Future<void> test_storeState_fromStore() async {
    var code = '''$header
class MyState {
  final List<int> list = [];
}

var store = Store(initialState: MyState());
''';
    await assertDiagnostics(code, [lintAt(code, 'list =', length: 4)]);
  }

  /// The file doesn't use the name `Store`, so the store is only found through the
  /// type alias that it imports.
  Future<void> test_storeState_fromStoreTypeAlias() async {
    newFile('$testPackageLibPath/app_store.dart', '''
import 'package:async_redux/async_redux.dart';
import 'test.dart';

typedef AppStateStore = Store<MyState>;
''');
    var code =
        '''import 'app_store.dart';
$header
class MyState {
  final List<int> list = [];
}

var store = AppStateStore(initialState: MyState());
''';
    await assertDiagnostics(code, [lintAt(code, 'list =', length: 4)]);
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
class MyState {
  final List<int> list = [];
}

typedef UsesAppAction = AppAction;
''';
    await assertDiagnostics(code, [lintAt(code, 'list =', length: 4)]);
  }

  Future<void> test_containedClasses() async {
    var code =
        '''$_ficImport
$header
@stateClass
class MyState {
  final IList<User> users;
  final (Address, int) record;
  final Wrapper? wrapper;
  MyState(this.users, this.record, this.wrapper);
}

class User {
  final List<String> tags = [];
}

class Address {
  final Set<String> lines = {};
}

class Wrapper extends Base {}

class Base {
  final Map<String, int> map = {};
}

class Unrelated {
  final List<int> list = [];
}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'tags', messageContainsAll: ["'User'"]),
      lintAt(code, 'lines'),
      lintAt(code, 'map =', length: 3, messageContainsAll: ["'Base'"]),
    ]);
  }

  Future<void> test_fix() async {
    await assertFix(
      '''$header
@stateClass
class MyState {
  final List<int>? list;
  final Map<String, List<int>> map = {};
  MyState(this.list);
}
''',
      UseImmutableCollection.new,
      '''$_headerWithFicImport
@stateClass
class MyState {
  final IList<int>? list;
  final Map<String, List<int>> map = {};
  MyState(this.list);
}
''',
    );
  }

  Future<void> test_fix_existingImport() async {
    await assertFix(
      '''import 'package:fast_immutable_collections/fast_immutable_collections.dart' as fic;
$header
@stateClass
class MyState {
  final fic.IList<int> list1;
  final Set<int> set;
  MyState(this.list1, this.set);
}
''',
      UseImmutableCollection.new,
      '''import 'package:fast_immutable_collections/fast_immutable_collections.dart' as fic;
$header
@stateClass
class MyState {
  final fic.IList<int> list1;
  final fic.ISet<int> set;
  MyState(this.list1, this.set);
}
''',
    );
  }

  Future<void> test_fix_inferredType() async {
    await assertFix(
      '''$header
@stateClass
class MyState {
  final list = <int>[];
}
''',
      UseImmutableCollection.new,
      null,
    );
  }
}

@reflectiveTest
class PreferImmutableCollectionsWithoutPackageTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = PreferImmutableCollectionsRule();
    super.setUp();
  }

  Future<void> test_fix_notOffered() async {
    await assertFix(
      '''$header
@stateClass
class MyState {
  final List<int> list = [];
}
''',
      UseImmutableCollection.new,
      null,
    );
  }
}

@reflectiveTest
class NonStateObjectInStateTest extends AsyncReduxRuleTest {
  @override
  bool get addFlutterPackageDep => true;

  @override
  void setUp() {
    rule = NonStateObjectInStateRule();
    super.setUp();
    newFile('${addFlutter().path}/src/state_extras.dart', _flutterStub);
  }

  Future<void> test_asyncObjects() async {
    var code = '''$_flutterHeader
@stateClass
class MyState {
  final Timer timer;
  final StreamSubscription<int>? subscription;
  final Stream<int> stream;
  final Future<int> future;
  final List<Timer> timers;
  MyState(
    this.timer,
    this.subscription,
    this.stream,
    this.future,
    this.timers,
  );
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'timer;',
        length: 5,
        messageContainsAll: ["'timer'", "'MyState'", "'Timer'"],
        correctionContains: "'setProp'",
      ),
      lintAt(
        code,
        'subscription;',
        length: 12,
        messageContainsAll: ["'StreamSubscription'"],
      ),
      lintAt(code, 'stream;', length: 6),
      lintAt(code, 'future;', length: 6),
      lintAt(code, 'timers;', length: 6, messageContainsAll: ["'Timer'"]),
    ]);
  }

  Future<void> test_flutterObjects() async {
    var code = '''$_flutterHeader
@stateClass
class MyState {
  final BuildContext context;
  final GlobalKey key;
  final TextEditingController textController;
  final ScrollController scrollController;
  final AnimationController animationController;
  final FocusNode focusNode;
  MyState(
    this.context,
    this.key,
    this.textController,
    this.scrollController,
    this.animationController,
    this.focusNode,
  );
}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'context;', length: 7, correctionContains: 'out of the state'),
      lintAt(code, 'key;', length: 3, messageContainsAll: ["'GlobalKey'"]),
      lintAt(
        code,
        'textController;',
        length: 14,
        messageContainsAll: ["'TextEditingController'"],
        correctionContains: "'Event'",
      ),
      lintAt(code, 'scrollController;', length: 16),
      lintAt(code, 'animationController;', length: 19),
      lintAt(code, 'focusNode;', length: 9),
    ]);
  }

  Future<void> test_stateObjects() async {
    await assertNoDiagnostics('''$_flutterHeader
@stateClass
class MyState {
  final int counter;
  final String? name;
  final List<Duration> durations;
  final void Function(Timer timer) onTick;
  final Future<int> Function() load;
  MyState(this.counter, this.name, this.durations, this.onTick, this.load);
}
''');
  }

  Future<void> test_notState() async {
    await assertNoDiagnostics('''$_flutterHeader
class Foo {
  final Timer? timer = null;
}
''');
  }
}

@reflectiveTest
class RouteInStateTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = RouteInStateRule();
    super.setUp();
  }

  Future<void> test_routeFields() async {
    var code = '''$header
@stateClass
class MyState {
  final String currentRoute;
  final String? routeName;
  final String _currentRouteName;
  final String route;
  final String userName;
  MyState(this.currentRoute, this.routeName, this._currentRouteName, this.route,
      this.userName);
  String get name => _currentRouteName;
}
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'currentRoute;',
        length: 12,
        messageContainsAll: ["'currentRoute'", "'MyState'"],
        correctionContains: 'getCurrentNavigatorRouteName',
      ),
      lintAt(code, 'routeName;', length: 9),
      lintAt(code, '_currentRouteName;', length: 17),
    ]);
  }

  Future<void> test_testFiles() async {
    await assertNotReportedInTests('''$header
@stateClass
class MyState {
  final String currentRoute;
  MyState(this.currentRoute);
}
''');
  }

  Future<void> test_notState() async {
    await assertNoDiagnostics('''$header
class Foo {
  final String currentRoute = '';
}
''');
  }
}

@reflectiveTest
class MissingInitialStateTest extends AsyncReduxRuleTest {
  @override
  void setUp() {
    rule = MissingInitialStateRule();
    super.setUp();
  }

  Future<void> test_noInitialStateMethod() async {
    var code = '''$header
class MyState {}

var store = Store<MyState>(initialState: MyState());
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'MyState());',
        length: 9,
        messageContainsAll: [
          "The state class 'MyState' doesn't have a static 'initialState()' method.",
        ],
        correctionContains: 'static MyState initialState()',
      ),
    ]);
  }

  Future<void> test_constructorInsteadOfInitialState() async {
    var code = '''$header
class MyState {
  MyState();
  MyState.empty();
  static MyState initialState() => MyState();
}

var store1 = Store<MyState>(initialState: MyState());
var store2 = Store(initialState: MyState.empty());
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'MyState());',
        length: 9,
        messageContainsAll: ['created with a constructor'],
        correctionContains: 'MyState.initialState()',
      ),
      lintAt(code, 'MyState.empty());', length: 15),
    ]);
  }

  Future<void> test_usesInitialState() async {
    await assertNoDiagnostics('''$header
class MyState {
  static MyState initialState() => MyState();
}

class OtherState {
  factory OtherState.initialState() => OtherState._();
  OtherState._();
}

MyState load() => MyState.initialState();

var store1 = Store<MyState>(initialState: MyState.initialState());
var store2 = Store<OtherState>(initialState: OtherState.initialState());
var store3 = Store<MyState>(initialState: load());
''');
  }

  Future<void> test_stateFromOtherLibraries() async {
    await assertNoDiagnostics('''$header
var store1 = Store<int>(initialState: 0);
var store2 = Store<Duration>(initialState: Duration());
''');
  }

  Future<void> test_testFiles() async {
    var code = '''$header
class MyState {}

var store = Store<MyState>(initialState: MyState());
''';
    var inTestDirectory = '$testPackageTestPath/helpers.dart';
    newFile(inTestDirectory, code);
    await assertNoDiagnosticsInFile(inTestDirectory);

    var testFile = '$testPackageLibPath/store_test.dart';
    newFile(testFile, code);
    await assertNoDiagnosticsInFile(testFile);
  }
}
