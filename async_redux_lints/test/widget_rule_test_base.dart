import 'rule_test_base.dart';

/// A stub of the widget parts of package `async_redux`.
const asyncReduxWidgetsStub = r'''
import 'package:flutter/widgets.dart';

extension BuildContextExtensionForProviderAndConnector<St> on BuildContext {
  St getState<St>() => throw 0;
  St getRead<St>() => throw 0;
  R getSelect<St, R>(R Function(St state) selector) => throw 0;
  R? getEvent<St, R>(Evt<R> Function(St state) selector) => throw 0;
  bool isWaiting(Object actionOrTypeOrList) => throw 0;
  bool isFailed(Object actionTypeOrList) => throw 0;
  Object? exceptionFor(Object actionTypeOrList) => throw 0;
  void clearExceptionFor(Object actionTypeOrList) {}
  Object? getEnvironment<St>() => throw 0;
  Object? getConfiguration<St>() => throw 0;
  Object? dispatch(Object action) => throw 0;
}

class Evt<T> {}

abstract class Vm {
  final List<Object?> equals;
  Vm({this.equals = const []});
}
''';

/// Flutter APIs that the mock Flutter package of `analyzer_testing` doesn't declare.
/// Added to the mock package, as `package:flutter/src/widgets/extras.dart`.
const flutterExtrasStub = r'''
import 'package:flutter/widgets.dart';

class ListView extends StatelessWidget {
  ListView.builder({required Widget? Function(BuildContext, int) itemBuilder});
  ListView.separated({
    required Widget? Function(BuildContext, int) itemBuilder,
    required Widget Function(BuildContext, int) separatorBuilder,
  });
  @override
  Widget build(BuildContext context) => throw 0;
}

class SliverChildBuilderDelegate extends SliverChildDelegate {
  SliverChildBuilderDelegate(Widget? Function(BuildContext, int) builder);
}

class WidgetsBinding {
  static WidgetsBinding get instance => throw 0;
  void addPostFrameCallback(void Function(Duration) callback) {}
}
''';

/// The start of every widget test file. Declares the `BuildContext` extension that
/// the AsyncRedux docs recommend.
///
/// Doesn't import `async_redux.dart`, since its stub declares its own `BuildContext`.
const widgetHeader = r'''
import 'package:async_redux/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/src/widgets/extras.dart';

class User {
  final String name = '';
  final int age = 0;
  String nickname = '';
}

class AppState {
  final int counter = 0;
  final String name = '';
  final User user = User();
  final User? maybeUser = null;
  final Evt<int> evt = Evt<int>();
  int sum() => 0;
}

extension BuildContextExtension on BuildContext {
  AppState get state => getState<AppState>();
  AppState read() => getRead<AppState>();
  R select<R>(R Function(AppState state) selector) => getSelect<AppState, R>(selector);
  R? event<R>(Evt<R> Function(AppState state) selector) =>
      getEvent<AppState, R>(selector);
}

// Avoid unused import warnings in tests that don't use these imports.
typedef UsesWidgets = Widget;
typedef UsesExtras = ListView;
''';

abstract class AsyncReduxWidgetRuleTest extends AsyncReduxRuleTest {
  @override
  bool get addFlutterPackageDep => true;

  @override
  void setUp() {
    newPackage('async_redux').addFile('lib/widgets.dart', asyncReduxWidgetsStub);
    super.setUp();
    newFile('${addFlutter().path}/src/widgets/extras.dart', flutterExtrasStub);
  }
}
