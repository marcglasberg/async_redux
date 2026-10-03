import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

import '../redux_types.dart';
import '../rules/reduce_without_await_rule.dart';

/// Adds `await microtask;` to the start of an async `reduce`. An expression body
/// (`=> expr`) becomes a block body.
class AddAwaitMicrotask extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'async_redux_lints.fix.addAwaitMicrotask',
    DartFixKindPriority.standard,
    "Add 'await microtask;' to the start of 'reduce'",
  );

  AddAwaitMicrotask({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var method = node.thisOrAncestorOfType<MethodDeclaration>();
    if (method == null || !isAsyncReduce(method)) return;

    var body = method.body;
    var eol = utils.endOfLine;

    if (body is BlockFunctionBody) {
      var statements = body.block.statements;
      if (statements.isEmpty) return;
      var first = statements.first;
      var indent = utils.getLinePrefix(first.offset);
      await builder.addDartFileEdit(file, (builder) {
        builder.addSimpleInsertion(first.offset, 'await microtask;$eol$indent');
      });
    } else if (body is ExpressionFunctionBody) {
      var indent = utils.getLinePrefix(method.firstTokenAfterCommentAndMetadata.offset);
      var innerIndent = indent + utils.oneIndent;
      var expression = utils.getNodeText(body.expression);
      await builder.addDartFileEdit(file, (builder) {
        builder.addSimpleReplacement(
          range.startEnd(body.functionDefinition, body),
          '{$eol'
          '${innerIndent}await microtask;$eol'
          '${innerIndent}return $expression;$eol'
          '$indent}',
        );
      });
    }
  }
}

/// Makes an async `reduce` sync: removes `async`, and changes the return type from
/// `Future<St?>` to `St?`. Only offered when `reduce` has no `await` at all, and
/// doesn't return a `Future`.
class MakeReduceSync extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'async_redux_lints.fix.makeReduceSync',
    DartFixKindPriority.standard - 1,
    "Make 'reduce' sync",
  );

  MakeReduceSync({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var method = node.thisOrAncestorOfType<MethodDeclaration>();
    if (method == null || !isAsyncReduce(method)) return;

    var returnType = method.returnType;
    var asyncKeyword = method.body.keyword;
    if (returnType == null || asyncKeyword == null) return;

    var valueType = futureValueType(returnType.type ?? typeProvider.dynamicType);
    if (valueType == null) return;

    var finder = _AwaitsAndReturnsFinder();
    method.body.accept(finder);
    if (finder.hasAwait || finder.returnsFuture) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addReplacement(range.node(returnType), (builder) {
        builder.writeType(valueType);
      });
      builder.addDeletion(range.startStart(asyncKeyword, asyncKeyword.next!));
    });
  }
}

/// Finds `await`s, and returns of a `Future`, in a method body, skipping closures.
class _AwaitsAndReturnsFinder extends RecursiveAstVisitor<void> {
  bool hasAwait = false;
  bool returnsFuture = false;

  @override
  void visitAwaitExpression(AwaitExpression node) {
    hasAwait = true;
  }

  @override
  void visitForStatement(ForStatement node) {
    if (node.awaitKeyword != null) hasAwait = true;
    super.visitForStatement(node);
  }

  @override
  void visitForElement(ForElement node) {
    if (node.awaitKeyword != null) hasAwait = true;
    super.visitForElement(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {}

  @override
  void visitFunctionDeclarationStatement(FunctionDeclarationStatement node) {}

  @override
  void visitReturnStatement(ReturnStatement node) {
    _checkReturned(node.expression);
    super.visitReturnStatement(node);
  }

  @override
  void visitExpressionFunctionBody(ExpressionFunctionBody node) {
    _checkReturned(node.expression);
    super.visitExpressionFunctionBody(node);
  }

  void _checkReturned(Expression? expression) {
    var type = expression?.staticType;
    if (type == null) return;
    if (type.isDartAsyncFuture || type.isDartAsyncFutureOr || type is DynamicType) {
      returnsFuture = true;
    }
  }
}
