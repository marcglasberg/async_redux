import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

import '../rules/testing_rules.dart';

/// Replaces `store.dispatch(action);` with `await store.dispatchAndWait(action);`.
/// If the enclosing function is not async, also makes it async, unless it declares a
/// return type other than `void`.
class UseAwaitDispatchAndWait extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'async_redux_lints.fix.useAwaitDispatchAndWait',
    DartFixKindPriority.standard,
    "Replace with 'await dispatchAndWait'",
  );

  UseAwaitDispatchAndWait({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var invocation = node.thisOrAncestorOfType<MethodInvocation>();
    if (invocation == null) return;
    var statement = unwaitedStoreDispatchStatement(invocation);
    if (statement == null) return;

    var body = statement.thisOrAncestorOfType<FunctionBody>();
    if (body is! BlockFunctionBody || body.isGenerator) return;
    var makeAsync = !body.isAsynchronous;
    if (makeAsync && !_canBeAsync(body)) return;

    await builder.addDartFileEdit(file, (builder) {
      if (makeAsync) builder.addSimpleInsertion(body.block.offset, 'async ');
      builder.addSimpleInsertion(statement.expression.offset, 'await ');
      builder.addSimpleReplacement(range.node(invocation.methodName), 'dispatchAndWait');
    });
  }

  /// Returns true if [body] belongs to a function or method that can be made async
  /// without changing its declared return type.
  static bool _canBeAsync(FunctionBody body) {
    var function = body.parent;
    TypeAnnotation? returnType;
    if (function is FunctionExpression) {
      var declaration = function.parent;
      if (declaration is FunctionDeclaration) returnType = declaration.returnType;
    } else if (function is MethodDeclaration) {
      returnType = function.returnType;
    } else {
      // Constructors can't be async.
      return false;
    }
    return returnType == null || returnType.type is VoidType;
  }
}
