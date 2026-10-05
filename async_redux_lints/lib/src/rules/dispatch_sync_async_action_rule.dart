import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

import '../redux_types.dart';

/// Reports `dispatchSync` called with an async action, which AsyncRedux rejects at
/// runtime. An action is async if its `reduce`, `before` or `wrapReduce` methods
/// return a `Future`, including methods inherited from mixins like `CheckInternet`.
///
/// Only reports when the action's static type is known to be async. Since an override
/// can't change a `Future` return type into a sync one, subclasses are async too.
class DispatchSyncAsyncActionRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'dispatch_sync_async_action',
    "'{0}' is async because {1}. Dispatching it with 'dispatchSync' "
        "throws a StoreException.",
    correctionMessage:
        "Try using 'dispatch' or 'dispatchAndWait' instead, or making the action sync.",
    severity: DiagnosticSeverity.ERROR,
  );

  DispatchSyncAsyncActionRule()
    : super(
        name: 'dispatch_sync_async_action',
        description: "Only sync actions can be dispatched with 'dispatchSync'.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    var library = context.libraryElement;
    if (library == null) return;
    var visitor = _Visitor(this, library);
    registry.addMethodInvocation(this, visitor);
    // Calling a getter of function type, like `ReduxAction.dispatchSync`.
    registry.addFunctionExpressionInvocation(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final LibraryElement library;

  _Visitor(this.rule, this.library);

  @override
  void visitMethodInvocation(MethodInvocation node) => _check(node);

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) =>
      _check(node);

  void _check(InvocationExpression node) {
    if (dispatchSyncName(node) == null) return;

    var action = actionArgument(node.argumentList);
    if (action == null) return;

    var actionType = action.staticType as InterfaceType;
    var reason = actionAsyncReason(actionType, library);
    if (reason == null) return;

    rule.reportAtNode(action, arguments: [actionType.element.displayName, reason]);
  }
}

/// Returns the `dispatchSync` identifier of [node], or null if [node] doesn't call
/// `dispatchSync`. For example, `store.dispatchSync(action)` or `dispatchSync(action)`.
SimpleIdentifier? dispatchSyncName(InvocationExpression node) {
  var name = switch (node) {
    MethodInvocation() => node.methodName,
    FunctionExpressionInvocation(function: SimpleIdentifier function) => function,
    FunctionExpressionInvocation(function: PropertyAccess function) =>
      function.propertyName,
    FunctionExpressionInvocation(function: PrefixedIdentifier function) =>
      function.identifier,
    _ => null,
  };
  return (name?.name == 'dispatchSync') ? name : null;
}

/// Returns the first positional argument whose static type is an action,
/// or null if there is none.
Expression? actionArgument(ArgumentList argumentList) {
  for (var argument in argumentList.arguments) {
    if (argument is! Expression) continue;
    if (isActionType(argument.staticType)) return argument;
  }
  return null;
}
