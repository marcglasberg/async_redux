import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

import '../error_types.dart';

/// Removes the `context.` of `context.dispatch(action)`.
class RemoveContextFromDispatch extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'async_redux_lints.fix.removeContextFromDispatch',
    DartFixKindPriority.standard,
    "Remove 'context.'",
  );

  RemoveContextFromDispatch({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.automatically;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var invocation = _dispatchInvocation(node);
    var target = invocation?.target;
    var operator = invocation?.operator;
    if (target == null || operator == null) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addDeletion(range.startEnd(target, operator));
    });
  }
}

/// Adds `context.` to `dispatch(action)`, or replaces the `this.` of
/// `this.dispatch(action)` with it.
class AddContextToDispatch extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'async_redux_lints.fix.addContextToDispatch',
    DartFixKindPriority.standard,
    "Add 'context.'",
  );

  AddContextToDispatch({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.automatically;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var invocation = _dispatchInvocation(node);
    if (invocation == null) return;
    var target = invocation.target;
    var operator = invocation.operator;

    await builder.addDartFileEdit(file, (builder) {
      if (target is ThisExpression && operator != null) {
        builder.addSimpleReplacement(range.startEnd(target, operator), 'context.');
      } else if (target == null) {
        builder.addSimpleInsertion(invocation.methodName.offset, 'context.');
      }
    });
  }
}

/// Returns the call of a dispatch method that contains [node], like
/// `context.dispatch(action)`.
MethodInvocation? _dispatchInvocation(AstNode node) =>
    node.thisOrAncestorMatching(
          (node) =>
              node is MethodInvocation && dispatchNames.contains(node.methodName.name),
        )
        as MethodInvocation?;
