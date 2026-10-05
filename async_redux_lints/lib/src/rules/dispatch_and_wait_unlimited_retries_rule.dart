import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

import '../mixin_utils.dart';
import '../redux_types.dart';

/// Reports `dispatchAndWait` or `dispatchAndWaitAll` with an action that uses the
/// `UnlimitedRetries` or `UnlimitedRetryCheckInternet` mixin. These actions retry
/// for as long as they fail, so the returned future may never complete. This covers
/// the `onRefresh` of a `RefreshIndicator`, which usually returns `dispatchAndWait`.
class DispatchAndWaitUnlimitedRetriesRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'dispatch_and_wait_unlimited_retries',
    "The action '{0}' uses the '{1}' mixin, so the future returned by '{2}' may never "
        "complete.",
    correctionMessage:
        "Try using 'dispatch' instead, or removing the '{1}' mixin from the action.",
    severity: DiagnosticSeverity.WARNING,
  );

  static const _waitingMethods = {'dispatchAndWait', 'dispatchAndWaitAll'};
  static const _unlimitedMixins = ['UnlimitedRetries', 'UnlimitedRetryCheckInternet'];

  DispatchAndWaitUnlimitedRetriesRule()
    : super(
        name: 'dispatch_and_wait_unlimited_retries',
        description:
            "Waiting for an action with 'UnlimitedRetries' or "
            "'UnlimitedRetryCheckInternet' may never complete.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    var visitor = _Visitor(this);
    registry.addMethodInvocation(this, visitor);
    // Calling a getter of function type, like `ReduxAction.dispatchAndWait`.
    registry.addFunctionExpressionInvocation(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _Visitor(this.rule);

  @override
  void visitMethodInvocation(MethodInvocation node) => _check(node);

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) =>
      _check(node);

  void _check(InvocationExpression node) {
    var name = invokedName(node);
    if (!DispatchAndWaitUnlimitedRetriesRule._waitingMethods.contains(name)) return;

    for (var action in firstArgumentExpressions(node)) {
      var type = action.staticType;
      if (type is! InterfaceType || !isActionType(type)) continue;

      var mixins = asyncReduxMixinsOfType(type);
      var mixin = DispatchAndWaitUnlimitedRetriesRule._unlimitedMixins
          .where(mixins.contains)
          .firstOrNull;
      if (mixin == null) continue;

      rule.reportAtNode(action, arguments: [type.element.displayName, mixin, name!]);
    }
  }
}
