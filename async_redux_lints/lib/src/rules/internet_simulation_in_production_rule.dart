import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

import '../mixin_utils.dart';
import '../package_files.dart';

/// Reports an override of `internetOnOffSimulation`, in code under `lib/`, that
/// returns `true` or `false`. It's meant for tests, and makes the action ignore the
/// real connectivity. Overrides that return `null`, or a value that is not a literal,
/// are not reported.
class InternetSimulationInProductionRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'internet_simulation_in_production',
    "This 'internetOnOffSimulation' returns '{0}', so the action ignores the real "
        "internet connection.",
    correctionMessage:
        "Try removing the override, or simulating the connection in your tests with "
        "'store.forceInternetOnOffSimulation'.",
    severity: DiagnosticSeverity.WARNING,
  );

  InternetSimulationInProductionRule()
    : super(
        name: 'internet_simulation_in_production',
        description:
            "Overriding 'internetOnOffSimulation' to return 'true' or 'false' is "
            "meant for tests.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    if (!isLibraryInLibDir(context)) return;
    registry.addMethodDeclaration(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _Visitor(this.rule);

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (!node.isGetter || node.isStatic) return;
    if (node.name.lexeme != 'internetOnOffSimulation') return;
    var enclosing = enclosingInterface(node);
    if (enclosing == null || !_overridesAsyncRedux(enclosing)) return;

    for (var returned in returnedExpressions(node.body)) {
      var literal = returned.unParenthesized;
      if (literal is BooleanLiteral) {
        rule.reportAtNode(literal, arguments: [literal.value.toString()]);
      }
    }
  }

  /// Returns true if [element] inherits `internetOnOffSimulation` from an AsyncRedux
  /// mixin, like `CheckInternet`.
  static bool _overridesAsyncRedux(InterfaceElement element) => element.allSupertypes.any(
    (type) =>
        isAsyncReduxMixin(type.element) &&
        type.element.getGetter('internetOnOffSimulation') != null,
  );
}
