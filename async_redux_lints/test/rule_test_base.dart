import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:analyzer_testing/src/analysis_rule/pub_package_resolution.dart'
    show ExpectedDiagnostic;

/// A stub of the parts of package `async_redux` that the rules look at.
const asyncReduxStub = r'''
import 'dart:async';

typedef Reducer<St> = FutureOr<St?> Function();

class ActionStatus {}

class UserException {}

class BuildContext {}

class Store<St> {
  ActionStatus dispatchSync(ReduxAction<St> action, {bool notify = true}) => throw 0;
  FutureOr<ActionStatus> dispatch(ReduxAction<St> action, {bool notify = true}) => throw 0;
  bool isWaiting(Object actionOrTypeOrList) => throw 0;
  bool isFailed(Object actionOrTypeOrList) => throw 0;
  UserException? exceptionFor(Object actionTypeOrList) => throw 0;
  void clearExceptionFor(Object actionTypeOrList) {}
}

class StoreProvider<St> {
  static bool isWaiting(BuildContext context, Object actionOrTypeOrList, {bool notify = true}) =>
      throw 0;
}

extension BuildContextExtensionForProviderAndConnector<St> on BuildContext {
  bool isWaiting(Object actionOrTypeOrList) => throw 0;
  bool isFailed(Object actionOrTypeOrList) => throw 0;
  UserException? exceptionFor(Object actionOrTypeOrList) => throw 0;
  void clearExceptionFor(Object actionOrTypeOrList) {}
}

class Wait {
  bool isWaiting(Object? flag, {Object? ref}) => throw 0;
}

abstract class ReduxAction<St> {
  St get state => throw 0;
  ActionStatus Function(ReduxAction<St> action, {bool notify}) get dispatchSync => throw 0;
  bool isWaiting(Object actionOrTypeOrList) => throw 0;
  bool isFailed(Object actionOrTypeOrList) => throw 0;
  UserException? exceptionFor(Object actionTypeOrList) => throw 0;
  void clearExceptionFor(Object actionTypeOrList) {}
  FutureOr<void> before() {}
  void after() {}
  FutureOr<St?> reduce();
  FutureOr<St?> wrapReduce(Reducer<St> reduce) => null;
}

mixin CheckInternet<St> on ReduxAction<St> {
  @override
  Future<void> before() async {}
}

// The other mixins only need to exist, for the mixin combination rules.
mixin NoDialog<St> on CheckInternet<St> {}
mixin AbortWhenNoInternet<St> on ReduxAction<St> {}
mixin NonReentrant<St> on ReduxAction<St> {}
mixin Retry<St> on ReduxAction<St> {}
mixin UnlimitedRetries<St> on Retry<St> {}
mixin OptimisticCommand<St> on ReduxAction<St> {}
mixin Throttle<St> on ReduxAction<St> {}
mixin Debounce<St> on ReduxAction<St> {}
mixin UnlimitedRetryCheckInternet<St> on ReduxAction<St> {}
mixin Fresh<St> on ReduxAction<St> {}
mixin OptimisticSync<St, T> on ReduxAction<St> {}
mixin OptimisticSyncWithPush<St, T> on ReduxAction<St> {}
mixin ServerPush<St> on ReduxAction<St> {}
mixin Polling<St> on ReduxAction<St> {}
mixin Sequential<St> on ReduxAction<St> {}
''';

/// The start of every test file.
const header = r'''
import 'dart:async';
import 'package:async_redux/async_redux.dart';

class AppState {}

// Avoid unused import warnings in tests that don't use these imports.
typedef UsesFutureOr = FutureOr<int>;
typedef UsesAsyncRedux = ReduxAction<int>;
''';

abstract class AsyncReduxRuleTest extends AnalysisRuleTest {
  @override
  void setUp() {
    newPackage('async_redux').addFile('lib/async_redux.dart', asyncReduxStub);
    super.setUp();
  }

  /// Expects a lint at the [occurrence] (1-based) of [snippet] in [code].
  /// The lint covers the whole [snippet], or only its first [length] characters.
  ExpectedDiagnostic lintAt(
    String code,
    String snippet, {
    int occurrence = 1,
    int? length,
    List<Pattern> messageContainsAll = const [],
  }) {
    var offset = -1;
    for (var i = 0; i < occurrence; i++) {
      offset = code.indexOf(snippet, offset + 1);
      if (offset == -1) throw ArgumentError('Snippet not found: $snippet');
    }
    return lint(offset, length ?? snippet.length, messageContainsAll: messageContainsAll);
  }
}
