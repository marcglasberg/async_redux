import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:test/test.dart';

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

  String _unixLineEndings(String text) => text.replaceAll('\r\n', '\n');
}
