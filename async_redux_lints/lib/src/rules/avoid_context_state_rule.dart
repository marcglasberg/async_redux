import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../widget_types.dart';

/// Reports every `context.state`, and `context.getState<St>()`. They make the widget
/// rebuild when any part of the state changes.
///
/// While the widget builds, `context.select((st) => st.field)` only rebuilds it when
/// that field changes. In callbacks like `onPressed`, and in `State` methods like
/// `dispose`, `context.read()` reads the state without rebuilding the widget.
///
/// The `BuildContext` extension that declares `state`, by calling `getState` on
/// itself, is not reported. Neither is `context.state` in `initState`, which
/// [ContextStateInInitStateRule] reports.
class AvoidContextStateRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'avoid_context_state',
    "'{0}' rebuilds the widget when any part of the state changes.",
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.INFO,
  );

  static const _useSelect =
      "Try using 'context.select' to select only the parts of the state that the "
      "widget uses.";

  static const _useRead = "Try using 'context.read()', which doesn't rebuild the widget.";

  static const _useSelectOrRead =
      "Try using 'context.select' if this runs while the widget builds, or "
      "'context.read()' if it doesn't.";

  AvoidContextStateRule()
    : super(
        name: 'avoid_context_state',
        description:
            "Use 'context.select' or 'context.read()' instead of 'context.state'.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    _register(this, registry, (node, name) {
      if (isInInitState(node)) return;
      var correction = runsWhileBuilding(node)
          ? _useSelect
          : notBuildingDescription(node) != null
          ? _useRead
          : _useSelectOrRead;
      reportAtNode(node, arguments: ['context.$name', correction]);
    });
  }
}

/// Reports `context.state`, and `context.getState<St>()`, in the `initState` method
/// of a `State`. They throw at runtime, because the widget can't depend on the
/// store before `initState` completes. `context.read()` works there.
///
/// Closures inside `initState`, like `addPostFrameCallback((_) => ...)`, run later,
/// so they're not reported.
class ContextStateInInitStateRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'context_state_in_init_state',
    "'{0}' can't be used in 'initState'. This throws an error at runtime.",
    correctionMessage: "Try using 'context.read()' instead.",
    severity: DiagnosticSeverity.ERROR,
  );

  ContextStateInInitStateRule()
    : super(
        name: 'context_state_in_init_state',
        description: "Don't use 'context.state' in 'initState'.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    _register(this, registry, (node, name) {
      if (isInInitState(node)) reportAtNode(node, arguments: ['context.$name']);
    });
  }
}

/// Calls [check] for each `context.state` and `context.getState<St>()`, with the
/// name of the getter or method.
void _register(
  AnalysisRule rule,
  RuleVisitorRegistry registry,
  void Function(Expression node, String name) check,
) {
  var visitor = _Visitor(check);
  registry.addPrefixedIdentifier(rule, visitor);
  registry.addPropertyAccess(rule, visitor);
  registry.addMethodInvocation(rule, visitor);
}

class _Visitor extends SimpleAstVisitor<void> {
  final void Function(Expression node, String name) check;

  _Visitor(this.check);

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) =>
      _check(node, node.identifier.name);

  @override
  void visitPropertyAccess(PropertyAccess node) => _check(node, node.propertyName.name);

  @override
  void visitMethodInvocation(MethodInvocation node) => _check(node, node.methodName.name);

  void _check(Expression node, String name) {
    if (stateAccessOfNode(node) != StateAccess.state) return;

    // The extension that declares `AppState get state => getState<AppState>();`.
    var target = stateAccessTarget(node);
    if (target == null || target is ThisExpression) return;

    check(node, name);
  }
}
