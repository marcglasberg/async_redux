import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../state_class_utils.dart';
import 'state_class_equality_rules.dart';

/// Reports the `props` getter of a state class that uses `Equatable` from package
/// `equatable`, when some fields of the class are missing from it. Equatable
/// compares `props` in `==` and `hashCode`, so a field missing from `props` is
/// ignored by them.
///
/// The fields declared in the class must be in `props`. The inherited fields must be
/// too, unless `props` contains `...super.props`, which is only possible when a
/// superclass or mixin implements `props`.
///
/// When the class declares fields but not `props`, the diagnostic is on the class
/// name. Abstract classes that don't declare `props` are not reported, since their
/// subclasses must list the inherited fields in their own `props`.
class EquatablePropsMissingFieldRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'equatable_props_missing_field',
    '{0}',
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.WARNING,
  );

  EquatablePropsMissingFieldRule()
    : super(
        name: 'equatable_props_missing_field',
        description: "All fields of an Equatable state class must be in its 'props'.",
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
    var missing = missingPropsFields(node);
    if (missing == null) return;

    var names = [...missing.declaredFields, ...missing.inheritedFields];
    var correction = missing.props == null
        ? "Try overriding 'props'."
        : missing.inheritedFields.isNotEmpty && missing.superImplementsProps
        ? "Try adding the missing fields, or '...super.props', to 'props'."
        : "Try adding the missing fields to 'props'.";
    rule.reportAtToken(
      missing.props?.name ?? node.namePart.typeName,
      arguments: [missingFieldsMessage(names, 'props'), correction],
    );
  }
}

/// The fields missing from the `props` of an Equatable state class.
class PropsFields {
  /// The `props` getter, or null if the class doesn't declare it.
  final MethodDeclaration? props;

  /// The missing fields declared in the class.
  final List<String> declaredFields;

  /// The missing inherited fields.
  final List<String> inheritedFields;

  /// Whether a superclass or mixin implements `props`, so that `props` can contain
  /// `...super.props`.
  final bool superImplementsProps;

  PropsFields(
    this.props,
    this.declaredFields,
    this.inheritedFields, {
    required this.superImplementsProps,
  });
}

/// Returns the fields missing from the `props` of [node], or null if none are
/// missing, or if [node] is not an Equatable state class.
PropsFields? missingPropsFields(ClassDeclaration node) {
  var element = node.declaredFragment?.element;
  if (element == null || !isStateClass(element) || !isEquatable(element)) return null;
  var declared = [for (var field in declaredFields(node)) field.name.lexeme];
  var superImplementsProps = inheritsGetter(element, 'props');

  var props = node.body.members
      .whereType<MethodDeclaration>()
      .where((member) => !member.isStatic && member.isGetter)
      .where((member) => member.name.lexeme == 'props')
      .firstOrNull;
  if (props == null) {
    if (declared.isEmpty || element.isAbstract) return null;
    return PropsFields(
      null,
      declared,
      const [],
      superImplementsProps: superImplementsProps,
    );
  }

  var body = props.body;
  if (body is! BlockFunctionBody && body is! ExpressionFunctionBody) return null;
  var declaredMissing = [
    for (var field in unusedFields(
      body,
      declaredFields(node),
      (field) => field.declaredFragment?.element,
    ))
      field.name.lexeme,
  ];
  var inheritedMissing = superImplementsProps && usesSuperGetter(body, 'props')
      ? const <String>[]
      : [
          for (var field in unusedFields(body, inheritedFields(element), (f) => f))
            field.name!,
        ];
  if (declaredMissing.isEmpty && inheritedMissing.isEmpty) return null;
  return PropsFields(
    props,
    declaredMissing,
    inheritedMissing,
    superImplementsProps: superImplementsProps,
  );
}

/// Returns the list literal returned by [props], like `[a, b]` in
/// `List<Object?> get props => [a, b];`, or null if it doesn't return a non-const
/// list literal.
ListLiteral? propsList(MethodDeclaration props) {
  var body = props.body;
  var expression = switch (body) {
    ExpressionFunctionBody() => body.expression,
    BlockFunctionBody(block: Block(statements: [ReturnStatement(:var expression)])) =>
      expression,
    _ => null,
  };
  if (expression is! ListLiteral || expression.constKeyword != null) return null;
  return expression;
}
