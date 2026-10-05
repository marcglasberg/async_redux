import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:analyzer/error/error.dart';

import '../redux_types.dart';

/// Reports a `throw` or `rethrow` in the `after` method of an action, outside a `try`
/// that catches it. The docs say `after` must not throw: the error is thrown
/// asynchronously, and only shows up in the console.
///
/// Throws inside closures are not reported, since they may run elsewhere, if at all.
class AfterThrowsRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'after_throws',
    "The 'after' method must not throw. The error is thrown asynchronously, and only "
        "shows up in the console.",
    correctionMessage:
        "Try catching the error, or moving the code that throws to 'before' or "
        "'reduce'.",
    severity: DiagnosticSeverity.WARNING,
  );

  AfterThrowsRule()
    : super(name: 'after_throws', description: "The 'after' method must not throw.");

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addMethodDeclaration(this, _Visitor(this, context));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _Visitor(this.rule, this.context);

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.lexeme != 'after' || !isActionMethod(node)) return;
    node.body.accept(_ThrowFinder(rule, context.typeSystem, node.body));
  }
}

class _ThrowFinder extends RecursiveAstVisitor<void> {
  final AnalysisRule rule;
  final TypeSystem typeSystem;
  final FunctionBody body;

  _ThrowFinder(this.rule, this.typeSystem, this.body);

  @override
  void visitFunctionExpression(FunctionExpression node) {}

  @override
  void visitThrowExpression(ThrowExpression node) {
    if (!_isCaught(node, node.expression.staticType)) rule.reportAtNode(node);
    super.visitThrowExpression(node);
  }

  @override
  void visitRethrowExpression(RethrowExpression node) {
    var catchClause = node.thisOrAncestorOfType<CatchClause>();
    var type = catchClause?.exceptionType?.type;
    if (!_isCaught(node, type)) rule.reportAtNode(node);
  }

  /// Returns true if [node], which throws a value of static [type], is inside the
  /// `try` block of a `try` statement with a `catch` that may catch it.
  bool _isCaught(AstNode node, DartType? type) {
    for (
      AstNode? child = node, parent = node.parent;
      parent != null && child != body;
      child = parent, parent = parent.parent
    ) {
      if (parent is TryStatement && parent.body == child) {
        if (parent.catchClauses.any((clause) => _catches(clause, type))) return true;
      }
    }
    return false;
  }

  /// Returns true if [clause] may catch a value of static [type]. When the types are
  /// related, either way, the value may be caught.
  bool _catches(CatchClause clause, DartType? type) {
    var caughtType = clause.exceptionType?.type;
    if (caughtType == null || type == null) return true;
    return typeSystem.isSubtypeOf(type, caughtType) ||
        typeSystem.isSubtypeOf(caughtType, type);
  }
}
