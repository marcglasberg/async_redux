import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

import '../widget_types.dart';
import 'context_state_for_one_field_rule.dart';

/// Reports `context.select` in code that doesn't run while the widget builds, which
/// throws a `FlutterError` in debug mode. These are:
///
/// - Closures passed as a named argument that starts with `on`, like `onPressed`.
/// - The `State` methods `initState`, `didChangeDependencies`, `didUpdateWidget`,
///   `activate`, `deactivate`, `dispose` and `reassemble`.
///
/// Other code that calls `select`, like a helper method called by `build`, may run
/// while the widget builds, so it's not reported.
class SelectInCallbackRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'select_in_callback',
    "'{0}' can't be used in {1}, because it doesn't run while the widget builds. "
        "This throws an error at runtime.",
    correctionMessage: "Try using 'context.read()' instead.",
    severity: DiagnosticSeverity.ERROR,
  );

  SelectInCallbackRule()
    : super(
        name: 'select_in_callback',
        description: "Don't use 'context.select' in callbacks like 'onPressed'.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addMethodInvocation(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _Visitor(this.rule);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (stateAccessOfNode(node) != StateAccess.select) return;
    var where = _notBuildingDescription(node);
    if (where == null) return;
    rule.reportAtNode(node, arguments: [node.methodName.name, where]);
  }
}

const _stateLifecycleMethods = {
  'initState',
  'didChangeDependencies',
  'didUpdateWidget',
  'activate',
  'deactivate',
  'dispose',
  'reassemble',
};

final _callbackName = RegExp(r'^on[A-Z]');

/// Returns a description of the code around [node] that doesn't run while the
/// widget builds, like "the 'onPressed' callback". Returns null if that code may
/// run while the widget builds.
String? _notBuildingDescription(AstNode node) {
  for (var ancestor = node.parent; ancestor != null; ancestor = ancestor.parent) {
    switch (ancestor) {
      case FunctionExpression():
        if (isBuilder(ancestor)) return null;
        var parent = ancestor.parent;
        if (parent is NamedArgument && _callbackName.hasMatch(parent.name.lexeme)) {
          return "the '${parent.name.lexeme}' callback";
        }
      case MethodDeclaration():
        var name = ancestor.name.lexeme;
        var enclosing = ancestor.declaredFragment?.element.enclosingElement;
        if (_stateLifecycleMethods.contains(name) &&
            enclosing is InterfaceElement &&
            isFlutterState(enclosing)) {
          return "'$name'";
        }
        return null;
      case FunctionDeclaration():
      case ClassDeclaration():
      case CompilationUnit():
        return null;
    }
  }
  return null;
}
