import 'rule_test_base.dart';

/// A stub of the widget parts of package `async_redux`.
const asyncReduxWidgetsStub = r'''
import 'package:flutter/widgets.dart';

extension BuildContextExtensionForProviderAndConnector<St> on BuildContext {
  St getState<St>() => throw 0;
  St getRead<St>() => throw 0;
  R getSelect<St, R>(R Function(St state) selector, {bool debug = true}) => throw 0;
}

abstract class Vm {
  final List<Object?> equals;
  Vm({this.equals = const []});
}
''';

/// The start of every widget test file. Declares the `BuildContext` extension that
/// the AsyncRedux docs recommend.
///
/// Doesn't import `async_redux.dart`, since its stub declares its own `BuildContext`.
const widgetHeader = r'''
import 'package:async_redux/widgets.dart';
import 'package:flutter/widgets.dart';

class AppState {
  final int counter = 0;
  final String name = '';
  int sum() => 0;
}

extension BuildContextExtension on BuildContext {
  AppState get state => getState<AppState>();
  AppState read() => getRead<AppState>();
  R select<R>(R Function(AppState state) selector) => getSelect<AppState, R>(selector);
}

// Avoid unused import warnings in tests that don't use these imports.
typedef UsesWidgets = Widget;
''';

abstract class AsyncReduxWidgetRuleTest extends AsyncReduxRuleTest {
  @override
  bool get addFlutterPackageDep => true;

  @override
  void setUp() {
    newPackage('async_redux').addFile('lib/widgets.dart', asyncReduxWidgetsStub);
    super.setUp();
  }
}
