import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:analyzer/error/error.dart';

import '../error_types.dart';
import '../widget_types.dart';

/// Reports a dispatch inside a `GlobalErrorObserver` subclass. The docs say not to
/// dispatch from it, because the store is still processing the failed action.
///
/// Not reported inside closures that run later, like `Future.microtask(() => ...)`,
/// since the action is done by then.
class DispatchInGlobalErrorObserverRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'dispatch_in_global_error_observer',
    "Don't dispatch actions from a 'GlobalErrorObserver'. The store is still "
        "processing the action that failed.",
    correctionMessage:
        "Try returning the error instead. To show it to the user, return a "
        "'UserException'.",
    severity: DiagnosticSeverity.WARNING,
  );

  DispatchInGlobalErrorObserverRule()
    : super(
        name: 'dispatch_in_global_error_observer',
        description: "Don't dispatch actions from a 'GlobalErrorObserver'.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    var visitor = _DispatchVisitor(this);
    registry.addMethodInvocation(this, visitor);
    // Calling a getter of function type, like `ReduxAction.dispatch`.
    registry.addFunctionExpressionInvocation(this, visitor);
  }
}

class _DispatchVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _DispatchVisitor(this.rule);

  @override
  void visitMethodInvocation(MethodInvocation node) => _check(node);

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) =>
      _check(node);

  void _check(InvocationExpression node) {
    if (dispatchMethodName(node) == null) return;
    var interface = enclosingInterface(node);
    if (interface == null || !isGlobalErrorObserver(interface)) return;
    if (_isInClosureThatRunsLater(node)) return;
    rule.reportAtNode(node);
  }

  static bool _isInClosureThatRunsLater(AstNode node) {
    for (var ancestor = node.parent; ancestor != null; ancestor = ancestor.parent) {
      if (ancestor is FunctionExpression && runsLater(ancestor)) return true;
      if (ancestor is ClassMember) return false;
    }
    return false;
  }
}

/// Reports a `throw` in `GlobalErrorObserver.observe`. It works, but the docs
/// recommend returning the error instead.
///
/// Throws inside closures, and throws caught by a `try` in `observe`, are not
/// reported.
class ThrowInGlobalErrorObserverRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'throw_in_global_error_observer',
    "Prefer returning the error from 'observe', instead of throwing it.",
    correctionMessage: "Try changing 'throw' to 'return'.",
    severity: DiagnosticSeverity.INFO,
  );

  ThrowInGlobalErrorObserverRule()
    : super(
        name: 'throw_in_global_error_observer',
        description:
            "The 'observe' method of a 'GlobalErrorObserver' should return the error, "
            "and not throw it.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addMethodDeclaration(this, _ObserveVisitor(this, context.typeSystem));
  }
}

class _ObserveVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final TypeSystem typeSystem;

  _ObserveVisitor(this.rule, this.typeSystem);

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.lexeme != 'observe' || node.isStatic) return;
    var enclosing = node.declaredFragment?.element.enclosingElement;
    if (enclosing is! InterfaceElement || !isGlobalErrorObserver(enclosing)) return;
    node.body.accept(_ThrowFinder(rule, typeSystem));
  }
}

class _ThrowFinder extends RecursiveAstVisitor<void> {
  final AnalysisRule rule;
  final TypeSystem typeSystem;

  _ThrowFinder(this.rule, this.typeSystem);

  @override
  void visitFunctionExpression(FunctionExpression node) {}

  @override
  void visitThrowExpression(ThrowExpression node) {
    if (!isCaughtLocally(node, node.expression.staticType, typeSystem)) {
      rule.reportAtNode(node);
    }
    super.visitThrowExpression(node);
  }
}

/// Opt-in rule that reports a `Store` created with a `globalErrorObserver`, but no
/// `environment`. The docs suggest passing both, so that production, staging and tests
/// can handle errors differently.
class GlobalErrorObserverWithoutEnvironmentRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'global_error_observer_without_env',
    "The store has a 'globalErrorObserver', but no 'environment'.",
    correctionMessage:
        "Try passing an 'environment' too, so that the observer can handle errors "
        "differently in production, staging and tests.",
    severity: DiagnosticSeverity.INFO,
  );

  GlobalErrorObserverWithoutEnvironmentRule()
    : super(
        name: 'global_error_observer_without_env',
        description:
            "A store with a 'globalErrorObserver' should also have an 'environment'.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addInstanceCreationExpression(this, _StoreVisitor(this));
  }
}

class _StoreVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _StoreVisitor(this.rule);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!isStore(node.constructorName.element?.enclosingElement)) return;
    var names = node.argumentList.arguments
        .whereType<NamedArgument>()
        .map((argument) => argument.name.lexeme)
        .toSet();
    if (names.contains('globalErrorObserver') && !names.contains('environment')) {
      rule.reportAtNode(node.constructorName);
    }
  }
}
