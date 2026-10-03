import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

import '../state_class_utils.dart';

/// Reports a state class that doesn't override `==` or `hashCode`. Without them,
/// two states with the same values are not equal.
///
/// Abstract classes are not reported. Neither are classes that inherit `==` or
/// `hashCode` from a superclass or mixin other than `Object`, like `Equatable`.
class StateClassMissingEqualityRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'state_class_missing_equality',
    "The state class '{0}' must override {1}.",
    correctionMessage: 'Try generating {1} with your IDE.',
    severity: DiagnosticSeverity.WARNING,
  );

  StateClassMissingEqualityRule()
    : super(
        name: 'state_class_missing_equality',
        description: "State classes must override '==' and 'hashCode'.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addClassDeclaration(this, _MissingEqualityVisitor(this));
  }
}

class _MissingEqualityVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _MissingEqualityVisitor(this.rule);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    var element = node.declaredFragment?.element;
    if (element == null || element.isAbstract || !isStateClass(element)) return;

    var missing = [
      if (!_declaresOrInherits(element, (e) => e.getMethod('==') != null)) '==',
      if (!_declaresOrInherits(element, (e) => e.getGetter('hashCode') != null))
        'hashCode',
    ];
    if (missing.isEmpty) return;
    var name = node.namePart.typeName;
    rule.reportAtToken(name, arguments: [name.lexeme, joinNames(missing)]);
  }

  /// Returns true if [element], or a superclass or mixin other than `Object`,
  /// declares the member checked by [declares].
  static bool _declaresOrInherits(
    InterfaceElement element,
    bool Function(InterfaceElement) declares,
  ) {
    for (
      InterfaceElement? e = element;
      e != null && e.supertype != null;
      e = e.supertype?.element
    ) {
      if (declares(e) || e.mixins.any((mixin) => declares(mixin.element))) {
        return true;
      }
    }
    return false;
  }
}

/// Reports the `==` operator and the `hashCode` getter of a state class when some
/// fields of the class are missing from them. All instance fields declared in the
/// class must be used in both. Each member gets a single diagnostic, on its name,
/// listing all its missing fields.
///
/// Fields declared in a superclass are not checked.
class EqualityMissingFieldRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'equality_missing_field',
    '{0}',
    correctionMessage: "Try adding the missing fields to '{1}'.",
    severity: DiagnosticSeverity.WARNING,
  );

  EqualityMissingFieldRule()
    : super(
        name: 'equality_missing_field',
        description:
            "All fields of a state class must be used in its '==' and 'hashCode'.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addClassDeclaration(this, _MissingFieldVisitor(this));
  }
}

class _MissingFieldVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _MissingFieldVisitor(this.rule);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    for (var member in missingEqualityFields(node)) {
      var name = member.method.name.lexeme;
      var fields = [for (var field in member.missingFields) field.name.lexeme];
      rule.reportAtToken(
        member.method.name,
        arguments: [missingFieldsMessage(fields, name), name],
      );
    }
  }
}

/// The `==` operator or `hashCode` getter of a state class, and the fields it
/// doesn't use.
class EqualityMemberFields {
  final MethodDeclaration method;
  final List<VariableDeclaration> missingFields;

  EqualityMemberFields(this.method, this.missingFields);
}

/// Returns the `==` operator and `hashCode` getter of [node] that don't use some
/// of its fields. Returns an empty list if [node] is not a state class.
List<EqualityMemberFields> missingEqualityFields(ClassDeclaration node) {
  var element = node.declaredFragment?.element;
  if (element == null || !isStateClass(element)) return const [];

  var fields = [
    for (var member in node.body.members)
      if (member is FieldDeclaration && !member.isStatic) ...member.fields.variables,
  ];
  if (fields.isEmpty) return const [];

  var result = <EqualityMemberFields>[];
  for (var member in node.body.members) {
    if (member is! MethodDeclaration || member.isStatic) continue;
    var isEquals = member.isOperator && member.name.lexeme == '==';
    var isHashCode = member.isGetter && member.name.lexeme == 'hashCode';
    if (!isEquals && !isHashCode) continue;
    var body = member.body;
    if (body is! BlockFunctionBody && body is! ExpressionFunctionBody) continue;

    var used = {
      for (var element in referencedElements(body))
        if (element is GetterElement) element.variable.baseElement else element,
    };
    var missing = [
      for (var field in fields)
        if (!used.contains(field.declaredFragment?.element)) field,
    ];
    if (missing.isNotEmpty) result.add(EqualityMemberFields(member, missing));
  }
  return result;
}
