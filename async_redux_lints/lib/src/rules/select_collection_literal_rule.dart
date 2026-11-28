import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../widget_types.dart';

/// Reports fresh collection literals returned by AsyncRedux selector closures.
class SelectCollectionLiteralRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'select_collection_literal',
    'This selector returns a new {0} literal, which compares by identity with '
        'CompareBy.byEquals and CompareBy.byIdentity.',
    correctionMessage:
        'Use a record to select multiple fields, or ignore this warning if '
        'StoreOptions.collectionEquality is intentionally CompareBy.byDeepEquals.',
    severity: DiagnosticSeverity.WARNING,
  );

  SelectCollectionLiteralRule()
    : super(
        name: 'select_collection_literal',
        description: 'Avoid fresh collection literals as selector results.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addMethodInvocation(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _Visitor(this.rule);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (stateAccessOfNode(node) != StateAccess.select) return;
    var selector =
        node.argumentList.arguments.firstOrNull?.argumentExpression.unParenthesized;
    if (selector is! FunctionExpression) return;
    var body = selector.body;
    if (body is ExpressionFunctionBody) {
      _check(body.expression);
    } else {
      body.accept(_ReturnVisitor(_check));
    }
  }

  void _check(Expression? expression) {
    expression = expression?.unParenthesized;
    if (expression is ListLiteral && expression.constKeyword == null) {
      rule.reportAtNode(expression, arguments: ['List']);
    } else if (expression is SetOrMapLiteral && expression.constKeyword == null) {
      rule.reportAtNode(expression, arguments: [expression.isMap ? 'Map' : 'Set']);
    } else if (expression is ConditionalExpression) {
      _check(expression.thenExpression);
      _check(expression.elseExpression);
    } else if (expression is SwitchExpression) {
      for (var arm in expression.cases) {
        _check(arm.expression);
      }
    } else if (expression is AsExpression) {
      _check(expression.expression);
    } else if (expression is BinaryExpression && expression.operator.lexeme == '??') {
      _check(expression.leftOperand);
      _check(expression.rightOperand);
    }
  }
}

/// Only visit returns belonging to the selector, not to nested functions.
class _ReturnVisitor extends RecursiveAstVisitor<void> {
  final void Function(Expression?) onReturn;

  _ReturnVisitor(this.onReturn);

  @override
  void visitFunctionExpression(FunctionExpression node) {}

  @override
  void visitReturnStatement(ReturnStatement node) => onReturn(node.expression);
}
