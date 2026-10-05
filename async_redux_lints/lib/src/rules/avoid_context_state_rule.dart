import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart';

import '../widget_types.dart';
import 'context_access_visitor.dart';

/// Reports every `context.state`, and `context.getState<St>()`. They make the widget
/// rebuild when any part of the state changes.
///
/// While the widget builds, `context.select((st) => st.field)` only rebuilds it when
/// that field changes. In callbacks like `onPressed`, and in `State` methods like
/// `didUpdateWidget`, `context.read()` reads the state without rebuilding the widget.
///
/// Not reported where `context.state` is an error, which other rules report: in
/// `initState`, in `dispose`, and in selectors.
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

  static const _useSelectInBuilder =
      "Try using 'context.select', in a 'Builder' or in a separate widget.";

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
    registerContextAccesses(this, registry, (node, access) {
      if (access != StateAccess.state) return;
      if (isInInitState(node) || isInDispose(node) || enclosingSelector(node) != null) {
        return;
      }
      var notBuildingCode = notBuilding(node);
      String correction;
      if (canUseSelect(node, stateAccessTarget(node))) {
        correction = _useSelect;
      } else if (enclosingBuildFunction(node) != null) {
        // The itemBuilder of a list, or the context of another widget.
        correction = _useSelectInBuilder;
      } else if (notBuildingCode != null &&
          notBuildingCode.stateMethod != 'didChangeDependencies') {
        correction = _useRead;
      } else {
        correction = _useSelectOrRead;
      }
      reportAtNode(node, arguments: ['context.${stateAccessName(node)}', correction]);
    });
  }
}

/// Reports `context.state`, `context.isWaiting`, `context.isFailed`,
/// `context.exceptionFor` and `context.clearExceptionFor` in the `initState` method of
/// a `State`. They throw at runtime, because the widget can't depend on the store
/// before `initState` completes. `context.read()` works there.
///
/// Closures inside `initState`, like `addPostFrameCallback((_) => ...)`, run later,
/// so they're not reported. For `context.select` and `context.event`, see
/// `select_outside_build`.
class ContextStateInInitStateRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'context_state_in_init_state',
    "'{0}' can't be used in 'initState', because the widget can't depend on the store "
        "before 'initState' completes.",
    correctionMessage: '{1}',
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
    registerContextAccesses(this, registry, (node, access) {
      if (access != StateAccess.state && access != StateAccess.actionStatus) return;
      if (!isInInitState(node)) return;
      reportAtNode(
        node,
        arguments: [
          'context.${stateAccessName(node)}',
          access == StateAccess.state
              ? "Try using 'context.read()' instead."
              : "Try using it in 'didChangeDependencies' or in 'build' instead.",
        ],
      );
    });
  }
}

/// Reports `context.state`, `context.read()`, `context.isWaiting`,
/// `context.isFailed`, `context.exceptionFor`, `context.clearExceptionFor`,
/// `context.getEnvironment` and `context.getConfiguration` in the `dispose` method of
/// a `State`, including in closures inside it. When `dispose` runs, the widget is no
/// longer in the tree, so they throw at runtime. Dispatching actions works.
///
/// For `context.select` and `context.event`, see `select_outside_build`.
class ContextInDisposeRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'context_in_dispose',
    "'{0}' can't be used in 'dispose', because the widget is no longer in the tree.",
    correctionMessage:
        "Try reading what you need in 'deactivate', or earlier, and keeping it in a field.",
    severity: DiagnosticSeverity.ERROR,
  );

  ContextInDisposeRule()
    : super(
        name: 'context_in_dispose',
        description: "Don't use the store through the 'context' in 'dispose'.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registerContextAccesses(this, registry, (node, access) {
      if (access == StateAccess.select ||
          access == StateAccess.event ||
          access == StateAccess.dispatch) {
        return;
      }
      if (isInDispose(node)) {
        reportAtNode(node, arguments: ['context.${stateAccessName(node)}']);
      }
    });
  }
}

/// Reports the use of the store through the `context` inside the selector of
/// `context.select` or `context.event`. The selector must only use its parameter:
/// `context.state` there rebuilds the widget on any state change, a nested
/// `context.select` throws, and dispatching actions is a side effect.
class ContextInSelectorRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'context_in_selector',
    "'{0}' can't be used inside the selector of '{1}'. The selector must only use "
        "its parameter.",
    correctionMessage: '{2}',
    severity: DiagnosticSeverity.ERROR,
  );

  ContextInSelectorRule()
    : super(
        name: 'context_in_selector',
        description: "Don't use the 'context' inside the selector of 'context.select'.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registerContextAccesses(this, registry, (node, access) {
      if (access == StateAccess.environment) return;
      var selector = enclosingSelector(node);
      if (selector == null) return;
      var invocation = selector.parent!.parent as MethodInvocation;
      var parameter = selector.parameters?.parameters.firstOrNull?.name?.lexeme;

      String correction;
      if (access == StateAccess.state || access == StateAccess.read) {
        correction = parameter == null
            ? "Try using the parameter of the selector instead."
            : "Try using '$parameter' instead.";
      } else {
        correction = "Try calling it outside of the selector.";
      }
      reportAtNode(
        node,
        arguments: [
          'context.${stateAccessName(node)}',
          'context.${invocation.methodName.name}',
          correction,
        ],
      );
    });
  }
}
