import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

import '../widget_types.dart';

/// Reports a field of a `Vm` subclass that is missing from the `equals` list passed
/// to the `Vm` constructor. Two view-models with the same `equals` are considered
/// equal, so the widget doesn't rebuild when only that field changes.
///
/// Fields that are functions are not reported, since they can't be in `equals`.
/// View-models that override `==` are not checked.
/// Fields that a constructor doesn't set from its parameters are not reported for
/// that constructor, since they have the same value in all its view-models.
///
/// The `equals` list must be a list literal, passed as `super(equals: [...])`.
/// Constructors that pass it in some other way are not checked. Constructors that
/// call the `Vm` constructor without `equals` are checked, since `equals` is then
/// empty.
class VmFieldNotInEqualsRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'vm_field_not_in_equals',
    "The field '{0}' is missing from 'equals', so the widget doesn't rebuild "
        "when only '{0}' changes.",
    correctionMessage: "Try adding '{0}' to 'equals'.",
    severity: DiagnosticSeverity.WARNING,
  );

  VmFieldNotInEqualsRule()
    : super(
        name: 'vm_field_not_in_equals',
        description: "The fields of a 'Vm' must be in its 'equals' list.",
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
    var missing = missingVmEquals(node);
    var reported = <String>{};
    for (var constructor in missing) {
      for (var field in constructor.missingFields.keys) {
        if (reported.add(field.name.lexeme)) {
          rule.reportAtToken(field.name, arguments: [field.name.lexeme]);
        }
      }
    }
  }
}

/// A constructor of a `Vm` subclass whose `equals` list misses some fields.
class VmConstructorEquals {
  final ConstructorDeclaration constructor;

  /// The `equals: [...]` list, or null if the constructor doesn't pass one to the
  /// `Vm` constructor.
  final ListLiteral? equalsList;

  /// The `super(...)` call, or null if the constructor doesn't have one.
  final SuperConstructorInvocation? superInvocation;

  /// The missing fields, and for each one the names of the parameters to add to
  /// `equals`. For example, `[counter]` for `this.counter`.
  final Map<VariableDeclaration, List<String>> missingFields;

  VmConstructorEquals(
    this.constructor,
    this.equalsList,
    this.superInvocation,
    this.missingFields,
  );
}

/// Returns the constructors of the `Vm` subclass [node] whose `equals` list misses
/// some fields. Returns an empty list if [node] is not a `Vm` subclass.
List<VmConstructorEquals> missingVmEquals(ClassDeclaration node) {
  var element = node.declaredFragment?.element;
  if (element == null || !isVmSubclass(element)) return const [];
  if (_overridesEquals(element)) return const [];
  var extendsVmDirectly = isVm(element.supertype?.element);

  var fields = <String, VariableDeclaration>{};
  for (var member in node.body.members) {
    if (member is! FieldDeclaration || member.isStatic) continue;
    for (var variable in member.fields.variables) {
      if (variable.initializer != null) continue;
      var type = variable.declaredFragment?.element.type;
      if (type == null || type is DynamicType || _isFunction(type)) continue;
      fields[variable.name.lexeme] = variable;
    }
  }
  if (fields.isEmpty) return const [];

  var result = <VmConstructorEquals>[];
  for (var member in node.body.members) {
    if (member is! ConstructorDeclaration) continue;
    if (member.factoryKeyword != null || member.externalKeyword != null) continue;
    if (member.initializers.any((i) => i is RedirectingConstructorInvocation)) continue;

    // Super parameters may include `super.equals`, which can't be checked.
    if (member.parameters.parameters.any((p) => p is SuperFormalParameter)) continue;

    var superInvocation = member.initializers
        .whereType<SuperConstructorInvocation>()
        .firstOrNull;
    var equalsArgument = superInvocation?.argumentList.arguments
        .whereType<NamedArgument>()
        .where((argument) => argument.name.lexeme == 'equals')
        .firstOrNull;

    ListLiteral? equalsList;
    if (equalsArgument != null) {
      var expression = equalsArgument.argumentExpression;
      if (expression is! ListLiteral) continue;
      equalsList = expression;
    } else if (!extendsVmDirectly) {
      // An intermediate class may pass its own `equals` to `Vm`.
      continue;
    }

    var referenced = <Element>{};
    equalsList?.accept(_ElementCollector(referenced));

    var missing = <VariableDeclaration, List<String>>{};
    for (var MapEntry(key: name, value: field) in _initializedFields(member).entries) {
      var declaration = fields[name];
      if (declaration == null) continue;
      if (field.any(referenced.contains)) continue;
      missing[declaration] = [for (var parameter in field) parameter.displayName];
    }

    if (missing.isNotEmpty) {
      result.add(VmConstructorEquals(member, equalsList, superInvocation, missing));
    }
  }
  return result;
}

/// Returns the fields that [constructor] sets from its parameters, and for each
/// one, the parameters it's set from.
Map<String, List<FormalParameterElement>> _initializedFields(
  ConstructorDeclaration constructor,
) {
  var result = <String, List<FormalParameterElement>>{};

  for (var parameter in constructor.parameters.parameters) {
    if (parameter is FieldFormalParameter) {
      var element = parameter.declaredFragment?.element;
      if (element != null) result[parameter.name.lexeme] = [element];
    }
  }

  for (var initializer in constructor.initializers) {
    if (initializer is! ConstructorFieldInitializer) continue;
    var referenced = <Element>{};
    initializer.expression.accept(_ElementCollector(referenced));
    var parameters = referenced.whereType<FormalParameterElement>().toList();
    if (parameters.isNotEmpty) result[initializer.fieldName.name] = parameters;
  }

  return result;
}

/// Returns true if the `Vm` subclass [element], or a superclass below `Vm`,
/// overrides `==`. Then `equals` may not be used at all.
bool _overridesEquals(InterfaceElement element) => [
  element,
  for (var type in element.allSupertypes) type.element,
].any((element) => isVmSubclass(element) && element.getMethod('==') != null);

bool _isFunction(DartType type) => type is FunctionType || type.isDartCoreFunction;

class _ElementCollector extends RecursiveAstVisitor<void> {
  final Set<Element> elements;

  _ElementCollector(this.elements);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    var element = node.element;
    if (element != null) elements.add(element);
  }
}
