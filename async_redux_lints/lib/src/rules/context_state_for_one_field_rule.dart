import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

import '../widget_types.dart';

/// Reports `context.state` in a `build` method, or in a builder like
/// `Builder(builder: (context) => ...)`, when only one field of the state is used.
/// `context.state` rebuilds the widget when any part of the state changes, while
/// `context.select((st) => st.field)` only rebuilds it when that field changes.
///
/// Recognizes `context.state.field`, and `var state = context.state;` when the
/// variable is only used as `state.field`. Accesses inside callbacks like
/// `onPressed: () => context.state` are ignored.
class ContextStateForOneFieldRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'context_state_for_one_field',
    "Only the '{0}' field of the state is used, but 'context.state' rebuilds "
        "the widget when any part of the state changes.",
    correctionMessage: "Try using 'context.select((st) => st.{0})' instead.",
    severity: DiagnosticSeverity.INFO,
  );

  ContextStateForOneFieldRule()
    : super(
        name: 'context_state_for_one_field',
        description:
            "Use 'context.select' when the widget uses only one field of the state.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    var visitor = _Visitor(this);
    registry.addMethodDeclaration(this, visitor);
    registry.addFunctionExpression(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _Visitor(this.rule);

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.lexeme == 'build') _check(node.body);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    if (isBuilder(node)) _check(node.body);
  }

  void _check(FunctionBody body) {
    var collector = _StateAccessCollector();
    body.accept(collector);
    if (collector.accesses.isEmpty) return;

    String? fieldName;
    for (var access in collector.accesses) {
      var usage = singleFieldUsage(access);
      if (usage == null) return;
      if (fieldName != null && fieldName != usage.fieldName) return;
      fieldName = usage.fieldName;
    }

    for (var access in collector.accesses) {
      rule.reportAtNode(access, arguments: [fieldName!]);
    }
  }
}

/// Returns true if [node] is a closure that gets a `BuildContext`, like the
/// `builder` of a `Builder` widget, but not a local function declaration.
bool isBuilder(FunctionExpression node) {
  if (node.parent is FunctionDeclaration) return false;
  var parameters = node.parameters?.parameters ?? const <FormalParameter>[];
  return parameters.any(
    (parameter) => isBuildContext(parameter.declaredFragment?.element.type),
  );
}

/// Collects `context.state` accesses, skipping closures.
class _StateAccessCollector extends RecursiveAstVisitor<void> {
  final accesses = <Expression>[];

  @override
  void visitFunctionExpression(FunctionExpression node) {}

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    _add(node);
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    _add(node);
    super.visitPropertyAccess(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    _add(node);
    super.visitMethodInvocation(node);
  }

  void _add(Expression node) {
    if (stateAccessOfNode(node) == StateAccess.state) accesses.add(node);
  }
}

/// How a `context.state` access uses a single field of the state.
class SingleFieldUsage {
  /// The name of the field, or getter, of the state.
  final String fieldName;

  /// The access of the field: `context.state.field`.
  /// Null if the state is assigned to a variable.
  final PropertyAccess? propertyAccess;

  /// The variable that holds the state: `var state = context.state;`.
  /// Null if the field is accessed directly.
  final VariableDeclaration? variable;

  /// The accesses of the field through the [variable]: `state.field`.
  final List<PrefixedIdentifier> variableAccesses;

  SingleFieldUsage.direct(this.fieldName, PropertyAccess this.propertyAccess)
    : variable = null,
      variableAccesses = const [];

  SingleFieldUsage.variable(
    this.fieldName,
    VariableDeclaration this.variable,
    this.variableAccesses,
  ) : propertyAccess = null;
}

/// Returns how the `context.state` [access] uses a single field of the state,
/// or null if it uses more than one field, or the state itself.
SingleFieldUsage? singleFieldUsage(Expression access) {
  var parent = access.parent;

  // context.state.field
  if (parent is PropertyAccess && parent.target == access) {
    if (parent.operator.type != TokenType.PERIOD) return null;
    if (parent.propertyName.element?.baseElement is! GetterElement) return null;
    if (_isAssigned(parent)) return null;
    return SingleFieldUsage.direct(parent.propertyName.name, parent);
  }

  // var state = context.state;
  if (parent is VariableDeclaration && parent.initializer == access) {
    var variable = parent.declaredFragment?.element;
    if (variable is! LocalVariableElement || variable.isLate) return null;
    var function = parent.thisOrAncestorOfType<FunctionBody>();
    if (function == null) return null;

    var finder = _ReferenceFinder(variable);
    function.accept(finder);
    if (finder.references.isEmpty) return null;

    String? fieldName;
    var variableAccesses = <PrefixedIdentifier>[];
    for (var reference in finder.references) {
      var referenceParent = reference.parent;
      if (referenceParent is! PrefixedIdentifier || referenceParent.prefix != reference) {
        return null;
      }
      if (referenceParent.identifier.element?.baseElement is! GetterElement) return null;
      if (_isAssigned(referenceParent)) return null;
      var name = referenceParent.identifier.name;
      if (fieldName != null && fieldName != name) return null;
      fieldName = name;
      variableAccesses.add(referenceParent);
    }
    return SingleFieldUsage.variable(fieldName!, parent, variableAccesses);
  }

  return null;
}

bool _isAssigned(Expression node) {
  var parent = node.parent;
  return (parent is AssignmentExpression && parent.leftHandSide == node) ||
      (parent is PrefixExpression && parent.operator.type.isIncrementOperator) ||
      (parent is PostfixExpression && parent.operator.type.isIncrementOperator);
}

class _ReferenceFinder extends RecursiveAstVisitor<void> {
  final LocalVariableElement variable;
  final references = <SimpleIdentifier>[];

  _ReferenceFinder(this.variable);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.element == variable) references.add(node);
  }
}
