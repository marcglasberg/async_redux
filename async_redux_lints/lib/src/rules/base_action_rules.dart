import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

import '../redux_types.dart';

/// Reports a concrete action that extends `ReduxAction<St>` directly, instead of the
/// app's base action, like `AppAction`. The docs recommend a base action that holds
/// the shared getters, selectors, typed dependencies and `wrapError` logic.
///
/// Not reported for actions with a generic state, like `ReduxAction<St>`, which can't
/// extend an app's base action, or for the actions of AsyncRedux.
class ExtendBaseActionRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'extend_base_action',
    "The action '{0}' extends '{1}' directly, instead of a base action.",
    correctionMessage:
        "Try extending your base action, or creating one, like 'abstract class "
        "AppAction extends {1} {}'.",
    severity: DiagnosticSeverity.INFO,
  );

  ExtendBaseActionRule()
    : super(
        name: 'extend_base_action',
        description:
            "Actions should extend a base action, like 'AppAction', and not "
            "'ReduxAction' directly.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    var visitor = _ExtendBaseActionVisitor(this);
    registry.addClassDeclaration(this, visitor);
    registry.addClassTypeAlias(this, visitor);
  }
}

class _ExtendBaseActionVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _ExtendBaseActionVisitor(this.rule);

  @override
  void visitClassDeclaration(ClassDeclaration node) => _check(
    node.declaredFragment?.element,
    node.extendsClause?.superclass,
    node.namePart.typeName.lexeme,
  );

  @override
  void visitClassTypeAlias(ClassTypeAlias node) =>
      _check(node.declaredFragment?.element, node.superclass, node.name.lexeme);

  void _check(ClassElement? element, NamedType? superclass, String name) {
    // Checking the superclass is faster than checking all the supertypes.
    var superType = superclass?.type;
    if (superType is! InterfaceType || !isReduxAction(superType.element)) return;
    if (!isConcreteAction(element)) return;
    var typeArguments = superType.typeArguments;
    if (typeArguments.isEmpty || typeArguments.first is TypeParameterType) return;

    rule.reportAtNode(superclass!, arguments: [name, superType.getDisplayString()]);
  }
}

/// Reports a cast of `store.environment`, `store.dependencies` or
/// `store.configuration` inside a concrete action. The docs recommend declaring a
/// typed getter once, in the base action, like
/// `Dependencies get dependencies => store.dependencies as Dependencies;`.
class DependenciesCastInActionRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'dependencies_cast_in_action',
    "Avoid casting 'store.{0}' in the action '{1}'.",
    correctionMessage:
        "Try declaring '{2} get {3} => store.{0} as {2};' in your base action, and "
        "using '{3}' instead.",
    severity: DiagnosticSeverity.INFO,
  );

  /// The getter name the docs use for each `Store` getter.
  static const _typedGetterNames = {
    'environment': 'environment',
    'dependencies': 'dependencies',
    'configuration': 'config',
  };

  DependenciesCastInActionRule()
    : super(
        name: 'dependencies_cast_in_action',
        description:
            "Declare typed getters for 'store.environment', 'store.dependencies' and "
            "'store.configuration' in the base action, instead of casting them in "
            "each action.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addAsExpression(this, _CastVisitor(this));
  }
}

class _CastVisitor extends SimpleAstVisitor<void> {
  final DependenciesCastInActionRule rule;

  _CastVisitor(this.rule);

  @override
  void visitAsExpression(AsExpression node) {
    var expression = node.expression.unParenthesized;
    if (expression is PostfixExpression) expression = expression.operand.unParenthesized;

    var getter = switch (expression) {
      PropertyAccess(:var propertyName) => propertyName,
      PrefixedIdentifier(:var identifier) => identifier,
      _ => null,
    };
    var getterName = getter?.name;
    var typedGetterName = DependenciesCastInActionRule._typedGetterNames[getterName];
    if (typedGetterName == null) return;

    var getterElement = getter!.element;
    if (getterElement is! GetterElement) return;
    var store = getterElement.enclosingElement;
    if (store is! ClassElement || store.name != 'Store' || !isFromAsyncRedux(store)) {
      return;
    }

    var action = node.thisOrAncestorOfType<ClassDeclaration>();
    var actionElement = action?.declaredFragment?.element;
    if (!isConcreteAction(actionElement)) return;

    rule.reportAtNode(
      node,
      arguments: [
        getterName!,
        actionElement!.displayName,
        node.type.toSource(),
        typedGetterName,
      ],
    );
  }
}
