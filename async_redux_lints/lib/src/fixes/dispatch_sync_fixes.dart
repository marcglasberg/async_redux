import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

import '../rules/dispatch_sync_async_action_rule.dart';

/// Replaces `dispatchSync` with `dispatch`.
class ReplaceWithDispatch extends _ReplaceDispatchSync {
  static const _kind = FixKind(
    'async_redux_lints.fix.replaceWithDispatch',
    DartFixKindPriority.standard,
    "Replace with 'dispatch'",
  );

  ReplaceWithDispatch({required super.context}) : super(replacement: 'dispatch');

  @override
  FixKind get fixKind => _kind;
}

/// Replaces `dispatchSync` with `dispatchAndWait`.
class ReplaceWithDispatchAndWait extends _ReplaceDispatchSync {
  static const _kind = FixKind(
    'async_redux_lints.fix.replaceWithDispatchAndWait',
    DartFixKindPriority.standard - 1,
    "Replace with 'dispatchAndWait'",
  );

  ReplaceWithDispatchAndWait({required super.context})
    : super(replacement: 'dispatchAndWait');

  @override
  FixKind get fixKind => _kind;
}

abstract class _ReplaceDispatchSync extends ResolvedCorrectionProducer {
  final String replacement;

  _ReplaceDispatchSync({required super.context, required this.replacement});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var invocation =
        node.thisOrAncestorMatching(
              (node) => node is InvocationExpression && dispatchSyncName(node) != null,
            )
            as InvocationExpression?;
    if (invocation == null) return;
    var name = dispatchSyncName(invocation)!;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(range.node(name), replacement);
    });
  }
}
