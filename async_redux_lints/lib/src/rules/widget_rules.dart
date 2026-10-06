import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

import '../error_types.dart';
import '../widget_types.dart';
import 'context_access_visitor.dart';

/// Reports a dispatch that runs while the widget builds: directly in a `build` method,
/// or in a builder like `Builder(builder: (context) => ...)`. It dispatches again on
/// every rebuild, and can loop forever when the action changes the state.
///
/// Dispatches in callbacks, like `onPressed: () => ...`, in closures that run later,
/// like `addPostFrameCallback`, and in other closures, like `items.map(...)`, are not
/// reported.
class DispatchInBuildRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'dispatch_in_build',
    "Don't dispatch actions while the widget builds. It dispatches again on every "
        "rebuild.",
    correctionMessage:
        "Try dispatching from a callback like 'onPressed', or from 'initState'.",
    severity: DiagnosticSeverity.WARNING,
  );

  DispatchInBuildRule()
    : super(
        name: 'dispatch_in_build',
        description: "Don't dispatch actions while the widget builds.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    var visitor = _DispatchInBuildVisitor(this);
    registry.addMethodInvocation(this, visitor);
    // Calling a getter of function type, like `VmFactory.dispatch`.
    registry.addFunctionExpressionInvocation(this, visitor);
  }
}

class _DispatchInBuildVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _DispatchInBuildVisitor(this.rule);

  @override
  void visitMethodInvocation(MethodInvocation node) => _check(node);

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) =>
      _check(node);

  void _check(InvocationExpression node) {
    if (dispatchMethodName(node) == null) return;
    if (enclosingSelector(node) != null) return; // Reported by context_in_selector.
    if (isInWidgetBuild(node)) rule.reportAtNode(node);
  }
}

/// Returns true if [node] runs while a widget builds: in a `build` method that gets
/// a `BuildContext`, or the `build` method of a `State`, or in a builder closure. Code
/// in callbacks and in other closures inside them is not considered.
bool isInWidgetBuild(AstNode node) {
  var function = enclosingBuildFunction(node);
  return function != null && (function.context != null || function.isStateBuild);
}

/// Reports `context.read()`, and `context.getRead<St>()`, while the widget builds. The
/// widget then doesn't rebuild when the state changes.
///
/// Not reported inside selectors, which `context_in_selector` reports.
class ContextReadInBuildRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'context_read_in_build',
    "'{0}' doesn't rebuild the widget when the state changes.",
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.WARNING,
  );

  ContextReadInBuildRule()
    : super(
        name: 'context_read_in_build',
        description: "Don't use 'context.read()' while the widget builds.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registerContextAccesses(this, registry, (node, access) {
      if (access != StateAccess.read || enclosingSelector(node) != null) return;
      if (!isInWidgetBuild(node)) return;
      var correction = canUseSelect(node, stateAccessTarget(node))
          ? "Try using 'context.select' instead."
          : "Try using 'context.select', in a 'Builder' or in a separate widget.";
      reportAtNode(node, arguments: ['context.${stateAccessName(node)}', correction]);
    });
  }
}

/// Reports a dispatch in the `onRefresh` callback of a `RefreshIndicator` (or any
/// Flutter widget with `onRefresh`), whose result the callback doesn't return or
/// `await`. The refresh indicator then hides its spinner before the action finishes.
/// `dispatchAll` is always reported, since its result can't be waited for.
///
/// The callback can be a closure, or a tear-off of a method or function declared in
/// the same file, like `onRefresh: _refresh`. Dispatches in nested closures are not
/// reported.
class RefreshIndicatorWithoutWaitRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'refresh_indicator_without_wait',
    "The 'onRefresh' callback doesn't wait for '{0}' to finish, so the spinner "
        "disappears before the data loads.",
    correctionMessage: "Try returning or awaiting '{1}(...)'.",
    severity: DiagnosticSeverity.WARNING,
  );

  RefreshIndicatorWithoutWaitRule()
    : super(
        name: 'refresh_indicator_without_wait',
        description: "The 'onRefresh' callback must wait for the actions it dispatches.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addNamedArgument(this, _RefreshVisitor(this));
  }
}

class _RefreshVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _RefreshVisitor(this.rule);

  @override
  void visitNamedArgument(NamedArgument node) {
    var body = onRefreshBody(node);
    if (body == null) return;
    for (var (invocation, name) in unwaitedDispatches(body)) {
      rule.reportAtNode(invocation, arguments: [name.name, waitingDispatchName(name)]);
    }
  }
}

/// Returns the body of the `onRefresh` callback passed as [argument], or null if
/// [argument] is not the `onRefresh` of a Flutter widget, or the body is not known.
FunctionBody? onRefreshBody(NamedArgument argument) {
  if (argument.name.lexeme != 'onRefresh') return null;
  var arguments = argument.parent;
  var creation = arguments?.parent;
  if (arguments is! ArgumentList || creation is! InstanceCreationExpression) return null;
  var library = creation.constructorName.element?.library;
  if (library == null || !library.uri.toString().startsWith('package:flutter/')) {
    return null;
  }

  var callback = argument.argumentExpression.unParenthesized;
  if (callback is FunctionExpression) return callback.body;

  // onRefresh: _refresh
  var element = switch (callback) {
    SimpleIdentifier() => callback.element,
    PrefixedIdentifier() => callback.identifier.element,
    PropertyAccess() => callback.propertyName.element,
    _ => null,
  };
  if (element is! ExecutableElement) return null;
  var unit = argument.thisOrAncestorOfType<CompilationUnit>();
  if (unit == null) return null;
  var finder = _DeclarationFinder(element.baseElement);
  unit.accept(finder);
  return finder.body;
}

class _DeclarationFinder extends RecursiveAstVisitor<void> {
  final Element element;
  FunctionBody? body;

  _DeclarationFinder(this.element);

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.declaredFragment?.element == element) body = node.body;
    super.visitMethodDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (node.declaredFragment?.element == element) {
      body = node.functionExpression.body;
    }
    super.visitFunctionDeclaration(node);
  }
}

/// Returns the dispatches in [body] that it doesn't wait for, with the identifier of
/// their dispatch method. These are dispatches whose value is discarded, and all the
/// `dispatchAll` calls. Dispatches in nested closures are not included.
List<(InvocationExpression, SimpleIdentifier)> unwaitedDispatches(FunctionBody body) {
  var finder = _DispatchFinder();
  body.accept(finder);
  return [
    for (var (invocation, name) in finder.dispatches)
      if (name.name == 'dispatchAll' || _isDiscarded(invocation)) (invocation, name),
  ];
}

class _DispatchFinder extends RecursiveAstVisitor<void> {
  final dispatches = <(InvocationExpression, SimpleIdentifier)>[];

  @override
  void visitFunctionExpression(FunctionExpression node) {}

  @override
  void visitMethodInvocation(MethodInvocation node) {
    _add(node);
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    _add(node);
    super.visitFunctionExpressionInvocation(node);
  }

  void _add(InvocationExpression node) {
    var name = dispatchMethodName(node);
    // A sync action finishes before `dispatchSync` returns.
    if (name != null && name.name != 'dispatchSync') dispatches.add((node, name));
  }
}

/// Returns true if the value of [expression] is not used, like in
/// `dispatch(action);`.
bool _isDiscarded(Expression expression) {
  AstNode node = expression;
  while (node.parent is ParenthesizedExpression) {
    node = node.parent!;
  }
  return node.parent is ExpressionStatement;
}

/// Returns the dispatch method that waits, for the dispatch method [name]:
/// `dispatchAndWaitAll` for `dispatchAll`, and `dispatchAndWait` for the others.
String waitingDispatchName(SimpleIdentifier name) => switch (name.name) {
  'dispatchAll' || 'dispatchAndWaitAll' => 'dispatchAndWaitAll',
  _ => 'dispatchAndWait',
};

/// Reports `.then(...)` called on the future returned by `dispatchAndWait`. It runs
/// even when the action fails. The docs recommend `thenIfCompletedOk` and
/// `thenIfCompletedFailed`, or checking `status.isCompletedOk`.
class ThenOnDispatchAndWaitRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'then_on_dispatch_and_wait',
    "'then' runs even when the action fails.",
    correctionMessage:
        "Try using 'thenIfCompletedOk' or 'thenIfCompletedFailed', or checking "
        "'status.isCompletedOk'.",
    severity: DiagnosticSeverity.WARNING,
  );

  ThenOnDispatchAndWaitRule()
    : super(
        name: 'then_on_dispatch_and_wait',
        description: "Don't use 'then' on the future returned by 'dispatchAndWait'.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addMethodInvocation(this, _ThenVisitor(this));
  }
}

class _ThenVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _ThenVisitor(this.rule);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (isThenOnDispatchAndWait(node)) rule.reportAtNode(node.methodName);
  }
}

/// Returns true if [node] is like `dispatchAndWait(action).then(...)`.
bool isThenOnDispatchAndWait(MethodInvocation node) {
  if (node.methodName.name != 'then') return false;
  var target = node.realTarget?.unParenthesized;
  return target is InvocationExpression &&
      dispatchMethodName(target)?.name == 'dispatchAndWait';
}
