import 'package:async_redux_lints/src/fixes/store_setup_fixes.dart';
import 'package:async_redux_lints/src/rules/store_setup_rules.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'store_setup_rule_test_base.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(UserExceptionDialogPlacementTest);
    defineReflectiveTests(NavigatorKeyNotSetTest);
    defineReflectiveTests(DebugObserverInReleaseTest);
  });
}

@reflectiveTest
class UserExceptionDialogPlacementTest extends AsyncReduxSetupRuleTest {
  @override
  void setUp() {
    rule = UserExceptionDialogPlacementRule();
    super.setUp();
  }

  Future<void> test_aboveStoreProvider() async {
    var code = '''$setupHeader
Widget app() => UserExceptionDialog<AppState>(
  child: StoreProvider<AppState>(
    store: store,
    child: MaterialApp(home: HomePage()),
  ),
);
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'UserExceptionDialog<AppState>',
        messageContainsAll: [
          "This 'UserExceptionDialog' is above the 'StoreProvider', so it can't read "
              "the errors from the store.",
        ],
      ),
    ]);
  }

  Future<void> test_aboveMaterialApp() async {
    var code = '''$setupHeader
Widget app() => StoreProvider<AppState>(
  store: store,
  child: UserExceptionDialog<AppState>(
    child: MaterialApp(home: HomePage()),
  ),
);
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'UserExceptionDialog<AppState>',
        messageContainsAll: [
          "This 'UserExceptionDialog' is above the 'MaterialApp', so it can't show "
              "dialogs.",
        ],
      ),
    ]);
  }

  Future<void> test_aboveCupertinoApp() async {
    var code = '''$setupHeader
Widget app() => StoreProvider<AppState>(
  store: store,
  child: UserExceptionDialog<AppState>(child: CupertinoApp(home: HomePage())),
);
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'UserExceptionDialog<AppState>',
        messageContainsAll: ["above the 'CupertinoApp'"],
      ),
    ]);
  }

  Future<void> test_builderWithoutNavigatorKey() async {
    var code = '''$setupHeader
Widget app() => StoreProvider<AppState>(
  store: store,
  child: MaterialApp(
    home: HomePage(),
    builder: (context, child) => UserExceptionDialog<AppState>(child: child!),
  ),
);
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'UserExceptionDialog<AppState>',
        messageContainsAll: [
          "This 'UserExceptionDialog' is in the 'builder' of the 'MaterialApp', which "
              "doesn't have a 'navigatorKey'.",
        ],
      ),
    ]);
  }

  Future<void> test_builderWithUseLocalContext() async {
    var code = '''$setupHeader
final navigatorKey = GlobalKey<NavigatorState>();

Widget app() => StoreProvider<AppState>(
  store: store,
  child: MaterialApp(
    navigatorKey: navigatorKey,
    builder: (context, child) =>
        UserExceptionDialog<AppState>(useLocalContext: true, child: child!),
  ),
);
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'useLocalContext: true',
        messageContainsAll: ["so it can't use 'useLocalContext: true'"],
      ),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Valid.

  Future<void> test_inHome_isValid() async {
    await assertNoDiagnostics('''$setupHeader
Widget app() => StoreProvider<AppState>(
  store: store,
  child: MaterialApp(home: UserExceptionDialog<AppState>(child: HomePage())),
);
''');
  }

  Future<void> test_inRoutes_isValid() async {
    await assertNoDiagnostics('''$setupHeader
Widget app() => StoreProvider<AppState>(
  store: store,
  child: MaterialApp(
    routes: {'/': (context) => UserExceptionDialog<AppState>(child: HomePage())},
  ),
);
''');
  }

  Future<void> test_storeProviderBelowMaterialApp_isValid() async {
    await assertNoDiagnostics('''$setupHeader
Widget app() => MaterialApp(
  home: StoreProvider<AppState>(
    store: store,
    child: UserExceptionDialog<AppState>(child: HomePage()),
  ),
);
''');
  }

  Future<void> test_builderWithNavigatorKey_isValid() async {
    await assertNoDiagnostics('''$setupHeader
final navigatorKey = GlobalKey<NavigatorState>();

Widget app() => StoreProvider<AppState>(
  store: store,
  child: MaterialApp(
    navigatorKey: navigatorKey,
    builder: (context, child) => UserExceptionDialog<AppState>(child: child!),
  ),
);
''');
  }

  Future<void> test_builderOfRouterApp_isValid() async {
    await assertNoDiagnostics('''$setupHeader
Widget app() => StoreProvider<AppState>(
  store: store,
  child: MaterialApp.router(
    builder: (context, child) => UserExceptionDialog<AppState>(child: child!),
  ),
);
''');
  }

  Future<void> test_inAnotherWidget_isValid() async {
    await assertNoDiagnostics('''$setupHeader
Widget app() => StoreProvider<AppState>(
  store: store,
  child: MaterialApp(home: MyHomePage()),
);

class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => UserExceptionDialog<AppState>(child: HomePage());
}
''');
  }
}

@reflectiveTest
class NavigatorKeyNotSetTest extends AsyncReduxSetupRuleTest {
  @override
  void setUp() {
    rule = NavigatorKeyNotSetRule();
    super.setUp();
  }

  Future<void> test_appWithoutNavigatorKey() async {
    var code = '''$setupHeader
final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  NavigateAction.setNavigatorKey(navigatorKey);
}

Widget app() => StoreProvider<AppState>(
  store: store,
  child: MaterialApp(home: HomePage()),
);
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'MaterialApp(home',
        length: 'MaterialApp'.length,
        messageContainsAll: [
          "This 'MaterialApp' doesn't have a 'navigatorKey', but "
              "'NavigateAction.setNavigatorKey' is called.",
        ],
      ),
    ]);
  }

  Future<void> test_differentKey() async {
    var code = '''$setupHeader
final navigatorKey = GlobalKey<NavigatorState>();
final otherKey = GlobalKey<NavigatorState>();

void main() {
  NavigateAction.setNavigatorKey(navigatorKey);
}

Widget app() => MaterialApp(navigatorKey: otherKey, home: HomePage());
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'otherKey,',
        length: 'otherKey'.length,
        messageContainsAll: [
          "This 'navigatorKey' is not the key passed to "
              "'NavigateAction.setNavigatorKey'.",
        ],
      ),
    ]);
  }

  Future<void> test_newKeyInSetNavigatorKey() async {
    var code = '''$setupHeader
final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  NavigateAction.setNavigatorKey(GlobalKey<NavigatorState>());
}

Widget app() => MaterialApp(navigatorKey: navigatorKey, home: HomePage());
''';
    await assertDiagnostics(code, [
      lintAt(code, 'navigatorKey, home', length: 'navigatorKey'.length),
    ]);
  }

  Future<void> test_fix() async {
    await assertFix(
      '''$setupHeader
final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  NavigateAction.setNavigatorKey(navigatorKey);
}

Widget app() => MaterialApp(home: HomePage());
''',
      AddNavigatorKey.new,
      '''$setupHeader
final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  NavigateAction.setNavigatorKey(navigatorKey);
}

Widget app() => MaterialApp(navigatorKey: navigatorKey, home: HomePage());
''',
    );
  }

  Future<void> test_fixWithArgumentsInLines() async {
    await assertFix(
      '''$setupHeader
final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  NavigateAction.setNavigatorKey(navigatorKey);
}

Widget app() => MaterialApp(
  home: HomePage(),
);
''',
      AddNavigatorKey.new,
      '''$setupHeader
final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  NavigateAction.setNavigatorKey(navigatorKey);
}

Widget app() => MaterialApp(
  navigatorKey: navigatorKey,
  home: HomePage(),
);
''',
    );
  }

  Future<void> test_fixWithoutArguments() async {
    await assertFix(
      '''$setupHeader
final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  NavigateAction.setNavigatorKey(navigatorKey);
}

Widget app() => MaterialApp();
''',
      AddNavigatorKey.new,
      '''$setupHeader
final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  NavigateAction.setNavigatorKey(navigatorKey);
}

Widget app() => MaterialApp(navigatorKey: navigatorKey);
''',
    );
  }

  // ---------------------------------------------------------------------------
  // Valid.

  Future<void> test_sameKey_isValid() async {
    await assertNoDiagnostics('''$setupHeader
final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  NavigateAction.setNavigatorKey(navigatorKey);
}

Widget app() => MaterialApp(navigatorKey: navigatorKey, home: HomePage());
''');
  }

  Future<void> test_navigateActionKey_isValid() async {
    await assertNoDiagnostics('''$setupHeader
void main() {
  NavigateAction.setNavigatorKey(GlobalKey<NavigatorState>());
}

Widget app() => MaterialApp(navigatorKey: NavigateAction.navigatorKey, home: HomePage());
''');
  }

  Future<void> test_localVariable_isValid() async {
    await assertNoDiagnostics('''$setupHeader
Widget app() {
  var key = GlobalKey<NavigatorState>();
  NavigateAction.setNavigatorKey(key);
  return MaterialApp(navigatorKey: key, home: HomePage());
}
''');
  }

  Future<void> test_unknownKey_isValid() async {
    await assertNoDiagnostics('''$setupHeader
final keys = [GlobalKey<NavigatorState>()];

void main() {
  NavigateAction.setNavigatorKey(keys[0]);
}

Widget app() => MaterialApp(navigatorKey: keys[0], home: HomePage());
''');
  }

  Future<void> test_withoutSetNavigatorKey_isValid() async {
    await assertNoDiagnostics('''$setupHeader
Widget app() => MaterialApp(home: HomePage());
''');
  }

  Future<void> test_routerApp_isValid() async {
    await assertNoDiagnostics('''$setupHeader
final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  NavigateAction.setNavigatorKey(navigatorKey);
}

Widget app() => MaterialApp.router(routerConfig: null);
''');
  }
}

@reflectiveTest
class DebugObserverInReleaseTest extends AsyncReduxSetupRuleTest {
  @override
  void setUp() {
    rule = DebugObserverInReleaseRule();
    super.setUp();
  }

  Future<void> test_consoleActionObserver() async {
    var code = '''$setupHeader
final store2 = Store<AppState>(actionObservers: [ConsoleActionObserver()]);
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'ConsoleActionObserver()',
        length: 'ConsoleActionObserver'.length,
        messageContainsAll: [
          "'ConsoleActionObserver' is meant for development, but it's also used in "
              "release builds.",
        ],
      ),
    ]);
  }

  Future<void> test_logPrinter() async {
    var code = '''$setupHeader
final store2 = Store<AppState>(actionObservers: [Log.printer()]);
''';
    await assertDiagnostics(code, [
      lintAt(
        code,
        'Log.printer',
        messageContainsAll: ["'Log.printer' is meant for development"],
      ),
    ]);
  }

  Future<void> test_defaultModelObserver() async {
    var code = '''$setupHeader
final store2 = Store<AppState>(modelObserver: DefaultModelObserver());
''';
    await assertDiagnostics(code, [
      lintAt(code, 'DefaultModelObserver()', length: 'DefaultModelObserver'.length),
    ]);
  }

  Future<void> test_insideFunction() async {
    var code = '''$setupHeader
Store<AppState> createStore() {
  return Store<AppState>(
    initialState: AppState(),
    actionObservers: [ConsoleActionObserver()],
  );
}
''';
    await assertDiagnostics(code, [
      lintAt(code, 'ConsoleActionObserver()', length: 'ConsoleActionObserver'.length),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Valid.

  Future<void> test_conditionalExpression_isValid() async {
    await assertNoDiagnostics('''$setupHeader
final store2 = Store<AppState>(
  actionObservers: kReleaseMode ? null : [ConsoleActionObserver()],
  modelObserver: kDebugMode ? DefaultModelObserver() : null,
);
''');
  }

  Future<void> test_collectionIf_isValid() async {
    await assertNoDiagnostics('''$setupHeader
final store2 = Store<AppState>(actionObservers: [if (kDebugMode) Log.printer()]);
''');
  }

  Future<void> test_ifStatement_isValid() async {
    await assertNoDiagnostics('''$setupHeader
Store<AppState> createStore() {
  if (kReleaseMode) {
    return Store<AppState>();
  } else {
    return Store<AppState>(actionObservers: [ConsoleActionObserver()]);
  }
}
''');
  }

  Future<void> test_logWithLogger_isValid() async {
    await assertNoDiagnostics('''$setupHeader
final store2 = Store<AppState>(actionObservers: [Log()]);
''');
  }

  Future<void> test_notPassedToStore_isValid() async {
    await assertNoDiagnostics('''$setupHeader
final observer = ConsoleActionObserver<AppState>();
''');
  }

  Future<void> test_inTestDirectory_isValid() async {
    var path = '$testPackageTestPath/a_test.dart';
    newFile(path, '''$setupHeader
final store2 = Store<AppState>(actionObservers: [ConsoleActionObserver()]);
''');
    await assertNoDiagnosticsInFile(path);
  }
}
