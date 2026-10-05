import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

import '../mixin_utils.dart';
import '../redux_types.dart';

/// Reports an `associatedAction()`, in an action with the `ServerPush` mixin, that
/// returns the type of an action without the `OptimisticSyncWithPush` mixin. The key
/// of the push then never matches the key of the action it should update.
class ServerPushAssociatedActionRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'server_push_associated_action',
    "The '{0}' returned by 'associatedAction' doesn't use the "
        "'OptimisticSyncWithPush' mixin.",
    correctionMessage:
        "Try returning the type of the action with 'OptimisticSyncWithPush' that "
        "this push updates.",
    severity: DiagnosticSeverity.ERROR,
  );

  ServerPushAssociatedActionRule()
    : super(
        name: 'server_push_associated_action',
        description:
            "The 'associatedAction' of a 'ServerPush' action must return an action "
            "type with 'OptimisticSyncWithPush'.",
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
    if (node.name.lexeme != 'associatedAction' || !isActionMethod(node)) return;
    var enclosing = enclosingInterface(node);
    if (enclosing == null || !asyncReduxMixinsOf(enclosing).contains('ServerPush')) {
      return;
    }

    for (var returned in returnedExpressions(node.body)) {
      var literal = returned.unParenthesized;
      if (literal is! TypeLiteral) continue;
      var type = literal.type.type;
      if (type is! InterfaceType) continue;
      if (asyncReduxMixinsOfType(type).contains('OptimisticSyncWithPush')) continue;
      rule.reportAtNode(literal, arguments: [type.element.displayName]);
    }
  }
}
