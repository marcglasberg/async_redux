import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../redux_types.dart';

/// Opt-in rule that reports every override of `abortDispatch` in an action. The docs
/// call it "a power feature that you may not need". Teams that turn this on
/// `// ignore` the uses they really need.
class AvoidAbortDispatchRule extends _PowerFeatureRule {
  static const LintCode code = LintCode(
    'avoid_abort_dispatch',
    "Avoid overriding 'abortDispatch'. It's a power feature that you may not need.",
    correctionMessage:
        "Try a mixin like 'NonReentrant', 'Throttle' or 'Fresh', or ignore this "
        "diagnostic if you really need it.",
    severity: DiagnosticSeverity.INFO,
  );

  AvoidAbortDispatchRule()
    : super(
        'abortDispatch',
        name: 'avoid_abort_dispatch',
        description: "Avoid overriding 'abortDispatch' in actions.",
      );

  @override
  LintCode get diagnosticCode => code;
}

/// Opt-in rule that reports every override of `wrapReduce` in an action. The docs
/// call it "a power feature that you may not need". Teams that turn this on
/// `// ignore` the uses they really need.
class AvoidWrapReduceRule extends _PowerFeatureRule {
  static const LintCode code = LintCode(
    'avoid_wrap_reduce',
    "Avoid overriding 'wrapReduce'. It's a power feature that you may not need.",
    correctionMessage:
        "Try a mixin like 'Retry' or 'Debounce', or ignore this diagnostic if you "
        "really need it.",
    severity: DiagnosticSeverity.INFO,
  );

  AvoidWrapReduceRule()
    : super(
        'wrapReduce',
        name: 'avoid_wrap_reduce',
        description: "Avoid overriding 'wrapReduce' in actions.",
      );

  @override
  LintCode get diagnosticCode => code;
}

/// Reports the overrides of [methodName] in actions, and in mixins on actions.
abstract class _PowerFeatureRule extends AnalysisRule {
  final String methodName;

  _PowerFeatureRule(this.methodName, {required super.name, required super.description});

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addMethodDeclaration(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final _PowerFeatureRule rule;

  _Visitor(this.rule);

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.lexeme == rule.methodName && isActionMethod(node)) {
      rule.reportAtToken(node.name);
    }
  }
}
