import 'rule_test_base.dart';

/// A stub of the parts of package `async_redux` that set up the store and the app.
const asyncReduxSetupStub = r'''
import 'package:flutter/widgets.dart';

abstract class ActionObserver<St> {}

class ConsoleActionObserver<St> extends ActionObserver<St> {}

class Log<St> implements ActionObserver<St> {
  Log({Object? logger});
  factory Log.printer({Object? formatter}) => Log();
}

abstract class ModelObserver<Model> {}

class DefaultModelObserver<Model> implements ModelObserver<Model> {}

class Store<St> {
  Store({
    St? initialState,
    List<ActionObserver<St>>? actionObservers,
    ModelObserver? modelObserver,
  });
}

class StoreProvider<St> extends StatelessWidget {
  StoreProvider({required Store<St> store, required Widget child});
  @override
  Widget build(BuildContext context) => throw 0;
}

class UserExceptionDialog<St> extends StatelessWidget {
  UserExceptionDialog({
    required Widget child,
    Object? onShowUserExceptionDialog,
    bool useLocalContext = false,
  });
  @override
  Widget build(BuildContext context) => throw 0;
}

class NavigateAction<St> {
  static GlobalKey<NavigatorState>? get navigatorKey => throw 0;
  static void setNavigatorKey(GlobalKey<NavigatorState> navigatorKey) {}
}
''';

/// Flutter APIs that the mock Flutter package of `analyzer_testing` doesn't declare.
/// Added to the mock package, as `package:flutter/src/widgets/app_extras.dart`.
const flutterAppStub = r'''
import 'package:flutter/widgets.dart';

const bool kReleaseMode = false;

class GlobalKey<T extends State<StatefulWidget>> extends Key {
  GlobalKey() : super.empty();
}

class MaterialApp extends StatelessWidget {
  MaterialApp({
    GlobalKey<NavigatorState>? navigatorKey,
    Widget? home,
    Map<String, WidgetBuilder> routes = const {},
    Widget Function(BuildContext, Widget?)? builder,
  });
  MaterialApp.router({
    Object? routerConfig,
    Widget Function(BuildContext, Widget?)? builder,
  });
  @override
  Widget build(BuildContext context) => throw 0;
}

class CupertinoApp extends StatelessWidget {
  CupertinoApp({
    GlobalKey<NavigatorState>? navigatorKey,
    Widget? home,
    Widget Function(BuildContext, Widget?)? builder,
  });
  @override
  Widget build(BuildContext context) => throw 0;
}
''';

/// The start of every store setup test file.
const setupHeader = r'''
import 'package:async_redux/app_setup.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/src/widgets/app_extras.dart';

class AppState {}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => throw 0;
}

final store = Store<AppState>(initialState: AppState());

// Avoid unused import warnings in tests that don't use these imports.
typedef UsesSetup = StoreProvider<AppState>;
typedef UsesWidgets = Widget;
typedef UsesExtras = MaterialApp;
''';

abstract class AsyncReduxSetupRuleTest extends AsyncReduxRuleTest {
  @override
  bool get addFlutterPackageDep => true;

  @override
  void setUp() {
    newPackage('async_redux').addFile('lib/app_setup.dart', asyncReduxSetupStub);
    super.setUp();
    newFile('${addFlutter().path}/src/widgets/app_extras.dart', flutterAppStub);
  }
}
