import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../widget_types.dart';

/// Calls [check] for each use of the store through a `BuildContext`, like
/// `context.state` or `context.select(...)`.
///
/// The `BuildContext` extension that declares them, like
/// `AppState get state => getState<AppState>();`, is skipped.
void registerContextAccesses(
  AnalysisRule rule,
  RuleVisitorRegistry registry,
  void Function(Expression node, StateAccess access) check,
) {
  var visitor = _Visitor(check);
  registry.addPrefixedIdentifier(rule, visitor);
  registry.addPropertyAccess(rule, visitor);
  registry.addMethodInvocation(rule, visitor);
}

class _Visitor extends SimpleAstVisitor<void> {
  final void Function(Expression node, StateAccess access) check;

  _Visitor(this.check);

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) => _check(node);

  @override
  void visitPropertyAccess(PropertyAccess node) => _check(node);

  @override
  void visitMethodInvocation(MethodInvocation node) => _check(node);

  void _check(Expression node) {
    var access = stateAccessOfNode(node);
    if (access == null) return;
    var target = stateAccessTarget(node);
    if (target == null || target is ThisExpression) return;
    check(node, access);
  }
}
