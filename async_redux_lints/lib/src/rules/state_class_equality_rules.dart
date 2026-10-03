import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../state_class_utils.dart';

/// Reports a state class that declares instance fields, but doesn't override `==`
/// and `hashCode`. Each class handles its own fields, so this includes abstract
/// classes, and classes that inherit `==` and `hashCode` from a superclass.
///
/// Classes that use `Equatable` from package `equatable` are not reported, since
/// they list their fields in `props` instead.
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
        description: "State classes with fields must override '==' and 'hashCode'.",
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
    if (element == null || !isStateClass(element) || isEquatable(element)) return;
    if (declaredFields(node).isEmpty) return;

    var missing = [
      if (element.getMethod('==') == null) '==',
      if (element.getGetter('hashCode') == null) 'hashCode',
    ];
    if (missing.isEmpty) return;
    var name = node.namePart.typeName;
    rule.reportAtToken(name, arguments: [name.lexeme, joinNames(missing)]);
  }
}

/// Reports the `==` operator and the `hashCode` getter of a state class when some
/// fields declared in the class are missing from them. All instance fields declared
/// in the class must be used in both. Each member gets a single diagnostic, on its
/// name, listing all its missing fields.
///
/// Inherited fields are checked by [EqualityMissingInheritedFieldRule].
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
      rule.reportAtToken(
        member.method.name,
        arguments: [missingFieldsMessage(member.fieldNames, name), name],
      );
    }
  }
}

/// Reports the `==` operator and the `hashCode` getter of a state class when they
/// don't handle the fields the class inherits. Each class handles its own fields, so
/// `==` must call `super == other`, and `hashCode` must use `super.hashCode`, when a
/// superclass or mixin overrides them. Otherwise, they must use the inherited fields
/// themselves.
class EqualityMissingInheritedFieldRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'equality_missing_inherited_field',
    '{0}',
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.WARNING,
  );

  EqualityMissingInheritedFieldRule()
    : super(
        name: 'equality_missing_inherited_field',
        description:
            "The '==' and 'hashCode' of a state class must handle its inherited "
            'fields.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addClassDeclaration(this, _MissingInheritedFieldVisitor(this));
  }
}

class _MissingInheritedFieldVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _MissingInheritedFieldVisitor(this.rule);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    for (var member in missingInheritedEqualityFields(node)) {
      var name = member.method.name.lexeme;
      var isEquals = name == '==';
      var names = member.fieldNames;
      var message = names.length == 1
          ? "Inherited field ${joinNames(names)} is missing from '$name'."
          : "Inherited fields ${joinNames(names)} are missing from '$name'.";
      var correction = !member.superOverrides
          ? 'Try using ${names.length == 1 ? 'it' : 'them'}.'
          : isEquals
          ? "Try adding 'super == other'."
          : "Try adding 'super.hashCode'.";
      rule.reportAtToken(member.method.name, arguments: [message, correction]);
    }
  }
}

/// The `==` operator or `hashCode` getter of a state class, and the fields it
/// doesn't use.
class EqualityMemberFields {
  final MethodDeclaration method;
  final List<String> fieldNames;

  /// Whether a superclass or mixin overrides the member, so that the member can
  /// call it with `super`. Only used for inherited fields.
  final bool superOverrides;

  EqualityMemberFields(this.method, this.fieldNames, {this.superOverrides = false});

  bool get isEquals => method.name.lexeme == '==';
}

/// Returns the `==` operator and `hashCode` getter of [node] that don't use some
/// of the fields declared in [node]. Returns an empty list if [node] is not a state
/// class.
List<EqualityMemberFields> missingEqualityFields(ClassDeclaration node) {
  var element = node.declaredFragment?.element;
  if (element == null || !isStateClass(element)) return const [];
  var fields = declaredFields(node);
  if (fields.isEmpty) return const [];

  return [
    for (var method in _equalityMembers(node))
      if (unusedFields(method.body, fields, (field) => field.declaredFragment?.element)
          case var missing when missing.isNotEmpty)
        EqualityMemberFields(method, [for (var field in missing) field.name.lexeme]),
  ];
}

/// Returns the `==` operator and `hashCode` getter of [node] that don't handle
/// the fields [node] inherits. Returns an empty list if [node] is not a state class.
List<EqualityMemberFields> missingInheritedEqualityFields(ClassDeclaration node) {
  var element = node.declaredFragment?.element;
  if (element == null || !isStateClass(element)) return const [];
  var fields = inheritedFields(element);
  if (fields.isEmpty) return const [];

  var result = <EqualityMemberFields>[];
  for (var method in _equalityMembers(node)) {
    var isEquals = method.name.lexeme == '==';
    var superOverrides = isEquals
        ? inheritsEquals(element)
        : inheritsGetter(element, 'hashCode');
    var callsSuper = isEquals
        ? usesSuperEquals(method.body)
        : usesSuperGetter(method.body, 'hashCode');
    if (superOverrides && callsSuper) continue;

    var missing = unusedFields(method.body, fields, (field) => field);
    if (missing.isEmpty) continue;
    result.add(
      EqualityMemberFields(method, [
        for (var field in missing) field.name!,
      ], superOverrides: superOverrides),
    );
  }
  return result;
}

/// Returns the instance fields declared in [node].
List<VariableDeclaration> declaredFields(ClassDeclaration node) => [
  for (var member in node.body.members)
    if (member is FieldDeclaration && !member.isStatic) ...member.fields.variables,
];

/// Returns the `==` operator and `hashCode` getter declared in [node], if they have
/// a body.
Iterable<MethodDeclaration> _equalityMembers(ClassDeclaration node) =>
    node.body.members.whereType<MethodDeclaration>().where(
      (member) =>
          !member.isStatic &&
          ((member.isOperator && member.name.lexeme == '==') ||
              (member.isGetter && member.name.lexeme == 'hashCode')) &&
          (member.body is BlockFunctionBody || member.body is ExpressionFunctionBody),
    );
