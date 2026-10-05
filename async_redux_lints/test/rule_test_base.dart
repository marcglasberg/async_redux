import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:analyzer_testing/src/analysis_rule/pub_package_resolution.dart'
    show ExpectedDiagnostic;
import 'package:test/test.dart';

/// A stub of the parts of package `async_redux` that the rules look at.
const asyncReduxStub = r'''
import 'dart:async';

typedef Reducer<St> = FutureOr<St?> Function();

class ActionStatus {}

class UserException implements Exception {
  const UserException(String? message, {int? code, String? reason});
  UserException mergedWith(UserException? anotherUserException) => this;
  UserException get noDialog => this;
}

extension UserExceptionAdvancedExtension on UserException {
  UserException addCause(Object? cause) => this;
  UserException addProps(Map<String, dynamic>? moreProps) => this;
}

class BuildContext {}

class Store<St> {
  Store({
    St? initialState,
    Object? environment,
    GlobalErrorObserver<St> Function(Store<St>)? globalErrorObserver,
  });
  Object? get environment => throw 0;
  Object? get dependencies => throw 0;
  Object? get configuration => throw 0;
  V prop<V>(Object? key) => throw 0;
  void setProp(Object? key, Object? value) {}
  void disposeProp(Object? keyToDispose) {}
  ActionStatus dispatchSync(ReduxAction<St> action, {bool notify = true}) => throw 0;
  FutureOr<ActionStatus> dispatch(ReduxAction<St> action, {bool notify = true}) => throw 0;
  bool isWaiting(Object actionOrTypeOrList) => throw 0;
  bool isFailed(Object actionOrTypeOrList) => throw 0;
  UserException? exceptionFor(Object actionTypeOrList) => throw 0;
  void clearExceptionFor(Object actionTypeOrList) {}
  Future<ActionStatus> dispatchAndWait(ReduxAction<St> action, {bool notify = true}) =>
      throw 0;
  Future<List<ReduxAction<St>>> dispatchAndWaitAll(
    List<ReduxAction<St>> actions, {
    bool notify = true,
  }) => throw 0;
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
  Store<St> get store => throw 0;
  St get state => throw 0;
  St get initialState => throw 0;
  ActionStatus Function(ReduxAction<St> action, {bool notify}) get dispatchSync => throw 0;
  FutureOr<ActionStatus> Function(ReduxAction<St> action, {bool notify}) get dispatch =>
      throw 0;
  Future<ActionStatus> Function(ReduxAction<St> action, {bool notify})
      get dispatchAndWait => throw 0;
  Future<List<ReduxAction<St>>> Function(List<ReduxAction<St>> actions, {bool notify})
      get dispatchAndWaitAll => throw 0;
  List<ReduxAction<St>> Function(List<ReduxAction<St>> actions, {bool notify})
      get dispatchAll => throw 0;
  Future<void> waitAllActions(List<ReduxAction<St>> actions) => throw 0;
  Future<ReduxAction<St>?> waitActionType(Type actionType) => throw 0;
  Future<void> waitAllActionTypes(List<Type> actionTypes) => throw 0;
  bool isWaiting(Object actionOrTypeOrList) => throw 0;
  bool isFailed(Object actionOrTypeOrList) => throw 0;
  UserException? exceptionFor(Object actionTypeOrList) => throw 0;
  void clearExceptionFor(Object actionTypeOrList) {}
  Object? wrapError(Object error, StackTrace stackTrace) => error;
  bool abortDispatch() => false;
  FutureOr<void> before() {}
  void after() {}
  FutureOr<St?> reduce();
  FutureOr<St?> wrapReduce(Reducer<St> reduce) => null;
  V prop<V>(Object? key) => throw 0;
  void setProp(Object? key, Object? value) {}
  void disposeProp(Object? keyToDispose) {}
  @override
  String toString() => 'Action';
}

mixin CheckInternet<St> on ReduxAction<St> {
  bool? get internetOnOffSimulation => null;
  @override
  Future<void> before() async {}
}

mixin NonReentrant<St> on ReduxAction<St> {
  Object? nonReentrantKeyParams() => null;
  Object computeNonReentrantKey() => (runtimeType, nonReentrantKeyParams());
  @override
  bool abortDispatch() => false;
}

mixin Retry<St> on ReduxAction<St> {
  @override
  Future<St?> wrapReduce(Reducer<St> reduce) async => null;
}

mixin OptimisticCommand<St> on ReduxAction<St> {
  Object? nonReentrantKeyParams() => null;
  @override
  Future<St?> reduce() async => null;
}

// The other mixins, with only the members that the rules look at.
mixin NoDialog<St> on CheckInternet<St> {}
mixin UnlimitedRetries<St> on Retry<St> {}

mixin AbortWhenNoInternet<St> on ReduxAction<St> {
  bool? get internetOnOffSimulation => null;
}

mixin UnlimitedRetryCheckInternet<St> on ReduxAction<St> {
  bool? get internetOnOffSimulation => null;
}

mixin Throttle<St> on ReduxAction<St> {
  Object? lockBuilder() => runtimeType;
}

mixin Debounce<St> on ReduxAction<St> {
  Object? lockBuilder() => runtimeType;
}

mixin Fresh<St> on ReduxAction<St> {
  Object? freshKeyParams() => null;
}

mixin OptimisticSync<St, T> on ReduxAction<St> {
  Object? optimisticSyncKeyParams() => null;
}

mixin OptimisticSyncWithPush<St, T> on ReduxAction<St> {
  Object? optimisticSyncKeyParams() => null;
}

mixin ServerPush<St> on ReduxAction<St> {
  Type associatedAction() => throw 0;
}

enum Poll { start, stop, runNowAndRestart, once }

mixin Polling<St> on ReduxAction<St> {
  Poll get poll => Poll.once;
  ReduxAction<St> createPollingAction() => throw 0;
  Object? pollingKeyParams() => null;
}

mixin Sequential<St> on ReduxAction<St> {
  Object? sequentialKeyParams() => null;
  @override
  Future<void> before() async {}
  @override
  void after() {}
}

class UserExceptionAction<St> extends ReduxAction<St> {
  UserExceptionAction(String? message, {int? code, String? reason, Object? cause});
  UserExceptionAction.from(UserException exception);
  @override
  Future<St> reduce() async => throw 0;
}

abstract class GlobalErrorObserver<St> {
  Object get error => throw 0;
  Object get originalError => throw 0;
  ReduxAction<St>? get action => throw 0;
  Store<St> get store => throw 0;
  Object? observe();
}

// The methods have bodies, so that tests don't need to implement them.
abstract class Persistor<St> {
  Future<St?> readState() async => null;
  Future<void> deleteState() async {}
  Future<void> persistDifference({
    required St? lastPersistedState,
    required St newState,
  }) async {}
  Future<void> saveInitialState(St state) async {}
  Duration? get throttle => null;
  Object? wrapError(Object error, StackTrace stackTrace) => error;
  void addError(Object error, [StackTrace? stackTrace]) {}
  (Object, StackTrace)? getAndRemoveFirstError() => null;
}

class StateClass {
  const StateClass();
}

const StateClass stateClass = StateClass();
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
    Pattern? correctionContains,
  }) {
    var offset = -1;
    for (var i = 0; i < occurrence; i++) {
      offset = code.indexOf(snippet, offset + 1);
      if (offset == -1) throw ArgumentError('Snippet not found: $snippet');
    }
    return lint(
      offset,
      length ?? snippet.length,
      messageContainsAll: messageContainsAll,
      correctionContains: correctionContains,
    );
  }

  /// Applies the fix created by [producer] to the first diagnostic of the rule in
  /// [code], and expects the result to be [expected]. If [expected] is null,
  /// expects the fix not to be offered.
  Future<void> assertFix(
    String code,
    CorrectionProducer Function({required CorrectionProducerContext context}) producer,
    String? expected,
  ) async {
    newFile(testFile.path, code);
    var unitResult = await resolveFile(testFile.path);
    var libraryResult =
        await unitResult.session.getResolvedLibrary(testFile.path)
            as ResolvedLibraryResult;
    var diagnostic = unitResult.diagnostics.firstWhere(
      (diagnostic) => diagnostic.diagnosticCode.lowerCaseName == rule.name,
    );

    var context = CorrectionProducerContext.createResolved(
      libraryResult: libraryResult,
      unitResult: unitResult,
      diagnostic: diagnostic,
      selectionOffset: diagnostic.offset,
      selectionLength: diagnostic.length,
    );
    var builder = ChangeBuilder(session: unitResult.session);
    await producer(context: context).compute(builder);

    var edits = builder.sourceChange.edits;
    if (expected == null) {
      expect(edits, isEmpty);
      return;
    }
    expect(edits, hasLength(1));
    // On Windows, the analyzed content may have different line endings.
    var result = SourceEdit.applySequence(unitResult.content, edits.single.edits);
    expect(_unixLineEndings(result), _unixLineEndings(expected));
  }

  /// Applies the fix created by [producer] to the first diagnostic of the rule in
  /// [code], and expects the content of each file to be the one in [expected], by
  /// path, like `testFile.path`. The fix must not change other files.
  Future<void> assertFixInFiles(
    String code,
    CorrectionProducer Function({required CorrectionProducerContext context}) producer,
    Map<String, String> expected,
  ) async {
    newFile(testFile.path, code);
    var unitResult = await resolveFile(testFile.path);
    var libraryResult =
        await unitResult.session.getResolvedLibrary(testFile.path)
            as ResolvedLibraryResult;
    var diagnostic = unitResult.diagnostics.firstWhere(
      (diagnostic) => diagnostic.diagnosticCode.lowerCaseName == rule.name,
    );

    var context = CorrectionProducerContext.createResolved(
      libraryResult: libraryResult,
      unitResult: unitResult,
      diagnostic: diagnostic,
      selectionOffset: diagnostic.offset,
      selectionLength: diagnostic.length,
    );
    var builder = ChangeBuilder(session: unitResult.session);
    await producer(context: context).compute(builder);

    var edits = {for (var edit in builder.sourceChange.edits) edit.file: edit.edits};
    expect(edits.keys, unorderedEquals(expected.keys));
    for (var MapEntry(key: path, value: content) in expected.entries) {
      var original = getFile(path).readAsStringSync();
      var result = SourceEdit.applySequence(original, edits[path]!);
      expect(_unixLineEndings(result), _unixLineEndings(content), reason: path);
    }
  }

  String _unixLineEndings(String text) => text.replaceAll('\r\n', '\n');
}
