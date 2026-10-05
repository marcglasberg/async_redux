import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

import '../names.dart';
import '../redux_types.dart';

/// The ways to name actions. Each one has its own opt-in rule, since plugin rules
/// can't be configured.
enum ActionNameStyle {
  /// `LoadUserAction`.
  endsWithAction,

  /// `LoadUser_Action`.
  endsWithUnderscoreAction,

  /// `LoadUser`. Only the end of the name is checked, so `ActionLog` is fine.
  withoutAction;

  /// Returns true if the action [name] follows this style.
  bool matches(String name) => switch (this) {
    endsWithAction => name.endsWith('Action') && !name.endsWith('_Action'),
    endsWithUnderscoreAction => name.endsWith('_Action'),
    withoutAction => !name.endsWith('Action'),
  };

  /// Returns the name that the action [name] should have in this style, or null if
  /// there's none. For example, `LoadUser_Action` becomes `LoadUserAction`.
  String? suggestedName(String name) {
    // Keep the underscores that make a name private.
    var prefixLength = leadingUnderscores(name);
    var prefix = name.substring(0, prefixLength);

    // `LoadUser_Action` and `LoadUserAction` become `LoadUser`.
    var base = name.substring(prefixLength);
    if (base.endsWith('Action')) {
      base = base.substring(0, base.length - 'Action'.length);
    }
    base = withoutTrailingUnderscores(base);
    if (base.isEmpty || isDigit(base.codeUnitAt(0))) return null;

    var result = switch (this) {
      endsWithAction => '$prefix${base}Action',
      endsWithUnderscoreAction => '$prefix${base}_Action',
      withoutAction => '$prefix$base',
    };
    return (result == name) ? null : result;
  }
}

/// Opt-in rule for the `LoadUserAction` naming style.
class ActionNameEndsWithActionRule extends _ActionNameRule {
  static const LintCode code = LintCode(
    'action_name_ends_with_action',
    "The name of the action '{0}' should end with 'Action'.",
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.WARNING,
  );

  ActionNameEndsWithActionRule()
    : super(
        ActionNameStyle.endsWithAction,
        name: 'action_name_ends_with_action',
        description: "Action names should end with 'Action', like 'LoadUserAction'.",
      );

  @override
  LintCode get diagnosticCode => code;
}

/// Opt-in rule for the `LoadUser_Action` naming style.
class ActionNameEndsWithUnderscoreActionRule extends _ActionNameRule {
  static const LintCode code = LintCode(
    'action_name_ends_with_underscore_action',
    "The name of the action '{0}' should end with '_Action'.",
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.WARNING,
  );

  ActionNameEndsWithUnderscoreActionRule()
    : super(
        ActionNameStyle.endsWithUnderscoreAction,
        name: 'action_name_ends_with_underscore_action',
        description: "Action names should end with '_Action', like 'LoadUser_Action'.",
      );

  @override
  LintCode get diagnosticCode => code;
}

/// Opt-in rule for the `LoadUser` naming style.
class ActionNameWithoutActionRule extends _ActionNameRule {
  static const LintCode code = LintCode(
    'action_name_without_action',
    "The name of the action '{0}' shouldn't end with 'Action'.",
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.WARNING,
  );

  ActionNameWithoutActionRule()
    : super(
        ActionNameStyle.withoutAction,
        name: 'action_name_without_action',
        description: "Action names shouldn't end with 'Action', like 'LoadUser'.",
      );

  @override
  LintCode get diagnosticCode => code;
}

/// Reports a concrete action whose name doesn't follow the [style]. Abstract
/// classes, like the base action, are not checked, and neither are the actions of
/// AsyncRedux.
abstract class _ActionNameRule extends AnalysisRule {
  final ActionNameStyle style;

  _ActionNameRule(this.style, {required super.name, required super.description});

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    var visitor = _Visitor(this);
    registry.addClassDeclaration(this, visitor);
    registry.addClassTypeAlias(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final _ActionNameRule rule;

  _Visitor(this.rule);

  @override
  void visitClassDeclaration(ClassDeclaration node) =>
      _check(node.declaredFragment?.element, node.namePart.typeName);

  @override
  void visitClassTypeAlias(ClassTypeAlias node) =>
      _check(node.declaredFragment?.element, node.name);

  void _check(Element? element, Token name) {
    // Checking the name is faster than checking the supertypes.
    if (rule.style.matches(name.lexeme)) return;
    if (!isConcreteAction(element)) return;

    var suggestion = rule.style.suggestedName(name.lexeme);
    var correction = (suggestion == null)
        ? 'Try renaming the action.'
        : "Try renaming the action to '$suggestion'.";
    rule.reportAtToken(name, arguments: [name.lexeme, correction]);
  }
}
