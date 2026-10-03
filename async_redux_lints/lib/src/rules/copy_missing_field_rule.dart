import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

import '../state_class_utils.dart';

/// Reports a `copy` or `copyWith` method of a state class that can't change some of
/// the class's fields. A state class is annotated with `@stateClass`, or extends,
/// implements or mixes in a class or mixin annotated with `@stateClass`. For example, when a field was added
/// to the class but not to `copy`.
///
/// A field is missing from the copy method if the method has no parameter with the
/// field's name, or has one but doesn't use it. Each method gets a single diagnostic,
/// on its name, listing all its missing fields.
///
/// Only public fields that a constructor sets from a parameter with the same name
/// are checked, like `this.counter`, or `counter = counter ?? 0`. Other fields, like
/// private fields, or fields computed from other parameters, are not checked.
/// Fields and copy methods inherited from a superclass are not checked either.
class CopyMissingFieldRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'copy_missing_field',
    '{0}',
    correctionMessage:
        "Try making '{1}' accept a parameter for each missing field, and use it.",
    severity: DiagnosticSeverity.WARNING,
  );

  CopyMissingFieldRule()
    : super(
        name: 'copy_missing_field',
        description:
            "The 'copy' and 'copyWith' methods of a '@stateClass' class must be "
            'able to change all its fields.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addClassDeclaration(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _Visitor(this.rule);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    for (var copy in missingCopyFields(node)) {
      var method = copy.method.name.lexeme;
      var names = [for (var field in copy.missingFields) field.declaration.name.lexeme];
      rule.reportAtToken(
        copy.method.name,
        arguments: [missingFieldsMessage(names, method), method],
      );
    }
  }
}

/// The names of the methods that are checked.
const copyMethodNames = {'copy', 'copyWith'};

/// A field that a copy method can't change.
class CopyField {
  final VariableDeclaration declaration;
  final FieldElement element;

  /// The parameter of the copy method with the field's name, which the method
  /// doesn't use. Null if the method has no such parameter.
  final FormalParameter? unusedParameter;

  CopyField(this.declaration, this.element, this.unusedParameter);
}

/// A copy method, and the fields it can't change.
class CopyMethodFields {
  final MethodDeclaration method;
  final List<CopyField> missingFields;

  CopyMethodFields(this.method, this.missingFields);
}

/// Returns the copy methods of [node] that can't change some of its fields. Returns
/// an empty list if [node] is not a state class.
List<CopyMethodFields> missingCopyFields(ClassDeclaration node) {
  var element = node.declaredFragment?.element;
  if (element == null || !isStateClass(element)) return const [];

  var copyMethods = [
    for (var member in node.body.members)
      if (member is MethodDeclaration &&
          !member.isStatic &&
          !member.isGetter &&
          !member.isSetter &&
          member.parameters != null &&
          copyMethodNames.contains(member.name.lexeme))
        member,
  ];
  if (copyMethods.isEmpty) return const [];

  var settable = _fieldsSetFromParameters(node);
  var fields = <(VariableDeclaration, FieldElement)>[];
  for (var member in node.body.members) {
    if (member is! FieldDeclaration || member.isStatic) continue;
    for (var variable in member.fields.variables) {
      var field = variable.declaredFragment?.element;
      if (field is! FieldElement || field.isPrivate) continue;
      if (settable.contains(field)) fields.add((variable, field));
    }
  }
  if (fields.isEmpty) return const [];

  var result = <CopyMethodFields>[];
  for (var method in copyMethods) {
    var parameters = {
      for (var parameter in method.parameters!.parameters)
        if (parameter.name != null) parameter.name!.lexeme: parameter,
    };

    var body = method.body;
    var hasBody = body is BlockFunctionBody || body is ExpressionFunctionBody;
    var used = hasBody ? referencedElements(body) : const <Element>{};

    var missing = <CopyField>[];
    for (var (declaration, field) in fields) {
      var parameter = parameters[field.name];
      if (parameter == null) {
        missing.add(CopyField(declaration, field, null));
      } else if (hasBody) {
        var parameterElement = parameter.declaredFragment?.element;
        if (parameterElement != null && !used.contains(parameterElement)) {
          missing.add(CopyField(declaration, field, parameter));
        }
      }
    }
    if (missing.isNotEmpty) result.add(CopyMethodFields(method, missing));
  }
  return result;
}

/// Returns the fields that a generative constructor of [node] sets from a parameter
/// with the same name. For example, `this.counter`, or `counter = counter ?? 0`.
Set<FieldElement> _fieldsSetFromParameters(ClassDeclaration node) {
  var result = <FieldElement>{};
  for (var member in node.body.members) {
    if (member is! ConstructorDeclaration) continue;
    if (member.factoryKeyword != null) continue;
    var constructor = member.declaredFragment?.element;
    if (constructor == null) continue;

    for (var parameter in constructor.formalParameters) {
      if (parameter is FieldFormalParameterElement) {
        var field = parameter.field;
        if (field != null) result.add(field);
      }
    }

    for (var initializer in member.initializers) {
      if (initializer is! ConstructorFieldInitializer) continue;
      var field = initializer.fieldName.element;
      if (field is! FieldElement) continue;
      var referenced = referencedElements(initializer.expression);
      if (referenced.any((e) => e is FormalParameterElement && e.name == field.name)) {
        result.add(field);
      }
    }
  }
  return result;
}
