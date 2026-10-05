import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

import '../error_types.dart';
import '../rules/widget_rules.dart';

/// In the `onRefresh` callback of a refresh indicator, replaces `dispatch(action);`
/// with `await dispatchAndWait(action);` in an async callback, or with
/// `return dispatchAndWait(action);` when it's the last statement of a callback that
/// is not async. Also replaces `dispatchAll` with `dispatchAndWaitAll`.
class WaitForDispatch extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'async_redux_lints.fix.waitForDispatch',
    DartFixKindPriority.standard,
    "Wait for '{0}'",
  );

  String _name = 'dispatchAndWait';

  WaitForDispatch({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  List<String> get fixArguments => [_name];

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var invocation =
        node.thisOrAncestorMatching(
              (node) => node is InvocationExpression && dispatchMethodName(node) != null,
            )
            as InvocationExpression?;
    if (invocation == null) return;
    var name = dispatchMethodName(invocation)!;
    var body = invocation.thisOrAncestorOfType<FunctionBody>();
    if (body == null) return;

    AstNode expression = invocation;
    while (expression.parent is ParenthesizedExpression) {
      expression = expression.parent!;
    }
    var statement = expression.parent;

    String? prefix;
    if (statement is ExpressionStatement) {
      if (body.isAsynchronous) {
        prefix = 'await ';
      } else if (body is BlockFunctionBody &&
          body.block.statements.lastOrNull == statement) {
        prefix = 'return ';
      } else {
        return;
      }
    }

    var newName = waitingDispatchName(name);
    if (prefix == null && newName == name.name) return;
    _name = newName;

    await builder.addDartFileEdit(file, (builder) {
      if (prefix != null) builder.addSimpleInsertion(expression.offset, prefix);
      if (newName != name.name) {
        builder.addSimpleReplacement(range.node(name), newName);
      }
    });
  }
}

/// Replaces `dispatchAndWait(action).then(...)` with
/// `dispatchAndWait(action).thenIfCompletedOk(...)`.
///
/// Only offered when `then` gets a single callback, without `onError` or type
/// arguments, and its result is not used, since `thenIfCompletedOk` returns the
/// `ActionStatus`, and not the value of the callback.
class UseThenIfCompletedOk extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'async_redux_lints.fix.useThenIfCompletedOk',
    DartFixKindPriority.standard,
    "Replace with 'thenIfCompletedOk'",
  );

  UseThenIfCompletedOk({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var invocation = node.thisOrAncestorOfType<MethodInvocation>();
    if (invocation == null || !isThenOnDispatchAndWait(invocation)) return;
    var arguments = invocation.argumentList.arguments;
    if (invocation.typeArguments != null ||
        arguments.length != 1 ||
        arguments.single is NamedArgument) {
      return;
    }

    AstNode value = invocation;
    while (value.parent is ParenthesizedExpression || value.parent is AwaitExpression) {
      value = value.parent!;
    }
    if (value.parent is! ExpressionStatement) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        range.node(invocation.methodName),
        'thenIfCompletedOk',
      );
    });
  }
}
