import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

import '../mixin_utils.dart';
import '../redux_types.dart';

/// Reports a `createPollingAction()`, in an action with the `Polling` mixin, that
/// creates the action with `Poll.start`, `Poll.stop` or `Poll.runNowAndRestart`. The
/// action created on each tick must use `Poll.once`, so that the ticks don't start,
/// stop or restart the timer.
class PollingActionRestartsPollingRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'polling_action_restarts_polling',
    "The action returned by 'createPollingAction' must use 'Poll.once', not "
        "'Poll.{0}', so that each tick doesn't control the polling.",
    correctionMessage: "Try using 'Poll.once' instead.",
    severity: DiagnosticSeverity.WARNING,
  );

  PollingActionRestartsPollingRule()
    : super(
        name: 'polling_action_restarts_polling',
        description: "The action returned by 'createPollingAction' must use 'Poll.once'.",
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
    if (node.name.lexeme != 'createPollingAction' || !isActionMethod(node)) return;
    var enclosing = enclosingInterface(node);
    if (enclosing == null || !asyncReduxMixinsOf(enclosing).contains('Polling')) return;

    for (var returned in returnedExpressions(node.body)) {
      var creation = returned.unParenthesized;
      if (creation is! InstanceCreationExpression) continue;
      for (var argument in creation.argumentList.arguments) {
        var value = argument.argumentExpression;
        var name = pollValueName(value);
        if (name != null && name != 'once') rule.reportAtNode(value, arguments: [name]);
      }
    }
  }
}

/// Returns the name of the `Poll` value of [expression], like `start` for
/// `Poll.start`, or null if [expression] is not a value of `Poll`.
String? pollValueName(Expression expression) {
  var identifier = switch (expression.unParenthesized) {
    PrefixedIdentifier(:var identifier) => identifier,
    PropertyAccess(:var propertyName) => propertyName,
    _ => null,
  };
  var enclosing = identifier?.element?.enclosingElement;
  if (enclosing is! EnumElement || enclosing.name != 'Poll') return null;
  if (!isFromAsyncRedux(enclosing)) return null;
  return identifier!.name;
}
