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
///
/// Prefixed identifiers, property accesses and method invocations are some of the
/// most common nodes, so the rules that call this share a single visitor for each
/// registry, which finds the use of the store once, and then calls the [check] of
/// each rule. Errors thrown by any [check] are attributed to the first rule.
void registerContextAccesses(
  AnalysisRule rule,
  RuleVisitorRegistry registry,
  void Function(Expression node, StateAccess access) check,
) {
  var visitor = _visitors[registry];
  if (visitor == null) {
    visitor = _visitors[registry] = _Visitor();
    registry.addPrefixedIdentifier(rule, visitor);
    registry.addPropertyAccess(rule, visitor);
    registry.addMethodInvocation(rule, visitor);
  }
  visitor.checks.add(check);
}

/// The shared visitor of each registry. The plugin creates a new registry for each
/// analysis of a library.
final _visitors = Expando<_Visitor>();

class _Visitor extends SimpleAstVisitor<void> {
  final checks = <void Function(Expression node, StateAccess access)>[];

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
    for (var check in checks) {
      check(node, access);
    }
  }
}
