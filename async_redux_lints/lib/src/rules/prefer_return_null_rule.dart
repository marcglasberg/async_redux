import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../redux_types.dart';

/// Reports a `reduce` method that returns `state` unchanged. The docs recommend
/// returning `null` when the state doesn't change.
class PreferReturnNullRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'prefer_return_null',
    "The reducer returns 'state' unchanged.",
    correctionMessage: "Try returning 'null', which means the state didn't change.",
    severity: DiagnosticSeverity.INFO,
  );

  PreferReturnNullRule()
    : super(
        name: 'prefer_return_null',
        description:
            "A reducer that doesn't change the state should return 'null', and not "
            "'state'.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addMethodDeclaration(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _Visitor(this.rule);

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.lexeme != 'reduce' || !isActionMethod(node)) return;

    var body = node.body;
    if (body is ExpressionFunctionBody) {
      _check(body.expression);
    } else {
      body.accept(_ReturnVisitor(_check));
    }
  }

  void _check(Expression? expression) {
    if (expression != null && readsActionGetter(expression, 'state')) {
      rule.reportAtNode(expression);
    }
  }
}

/// Visits the `return` statements of a method, skipping closures.
class _ReturnVisitor extends RecursiveAstVisitor<void> {
  final void Function(Expression? expression) onReturn;

  _ReturnVisitor(this.onReturn);

  @override
  void visitFunctionExpression(FunctionExpression node) {}

  @override
  void visitReturnStatement(ReturnStatement node) => onReturn(node.expression);
}
