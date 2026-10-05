import 'dart:collection';

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import 'redux_types.dart';

/// Returns true if [element] is a mixin of package `async_redux`, like `Retry`.
bool isAsyncReduxMixin(InterfaceElement element) =>
    element is MixinElement && isFromAsyncRedux(element);

/// Returns the names of the AsyncRedux mixins among [types].
Set<String> asyncReduxMixins(Iterable<InterfaceType> types) => {
  for (var type in types)
    if (isAsyncReduxMixin(type.element)) type.element.name!,
};

/// Returns the names of the AsyncRedux mixins of [element], including the ones it
/// inherits from its superclasses and from mixins of your own.
///
/// Many rules check the mixins of every class, so the result is cached, and can't be
/// modified. When a file changes, the analyzer creates new elements for its library,
/// so the cached values of the old elements are not used anymore.
Set<String> asyncReduxMixinsOf(InterfaceElement element) =>
    _asyncReduxMixinsCache[element] ??= switch (asyncReduxMixins(element.allSupertypes)) {
      var mixins when mixins.isEmpty => const <String>{},
      var mixins => UnmodifiableSetView(mixins),
    };

final _asyncReduxMixinsCache = Expando<Set<String>>();

/// Returns the names of the AsyncRedux mixins of [type], including [type] itself
/// when it's one of them.
Set<String> asyncReduxMixinsOfType(InterfaceType type) {
  var element = type.element;
  var inherited = asyncReduxMixinsOf(element);
  return isAsyncReduxMixin(element) ? {element.name!, ...inherited} : inherited;
}

/// Returns the index of the type in [mixinTypes] that adds the AsyncRedux [mixin],
/// or -1 if none does. That's the [mixin] itself or, if missing, another mixin
/// that has [mixin] as a supertype, like a mixin of your own.
int indexInWithClause(String mixin, List<NamedType> mixinTypes) {
  var index = mixinTypes.indexWhere((type) {
    var element = type.element;
    return element is InterfaceElement &&
        isAsyncReduxMixin(element) &&
        element.name == mixin;
  });
  if (index != -1) return index;

  return mixinTypes.indexWhere((type) {
    var element = type.element;
    return element is InterfaceElement && asyncReduxMixinsOf(element).contains(mixin);
  });
}

/// A class declaration or class type alias, with what the mixin rules need from it.
class ClassWithMixins {
  final ClassElement element;
  final WithClause? withClause;
  final Token name;

  ClassWithMixins(this.element, this.withClause, this.name);

  /// Returns the class declared by [node], a class declaration or class type alias,
  /// or null if [node] is something else.
  static ClassWithMixins? of(AstNode node) => switch (node) {
    ClassDeclaration(:var declaredFragment?, :var withClause, :var namePart) =>
      ClassWithMixins(declaredFragment.element, withClause, namePart.typeName),
    ClassTypeAlias(:var declaredFragment?, :var withClause, :var name) => ClassWithMixins(
      declaredFragment.element,
      withClause,
      name,
    ),
    _ => null,
  };

  /// The names of the AsyncRedux mixins of the class, including inherited ones.
  late final Set<String> mixins = asyncReduxMixinsOf(element);

  /// Reports a diagnostic of [rule] about [mixin]: on the type in the `with` clause
  /// that adds [mixin], or on the class name if [mixin] is inherited from a
  /// superclass.
  void reportAtMixin(
    AnalysisRule rule,
    String mixin, {
    List<Object> arguments = const [],
  }) {
    var mixinTypes = withClause?.mixinTypes ?? const <NamedType>[];
    var index = indexInWithClause(mixin, mixinTypes);
    if (index == -1) {
      rule.reportAtToken(name, arguments: arguments);
    } else {
      rule.reportAtNode(mixinTypes[index], arguments: arguments);
    }
  }
}

/// Returns the interface element that declares [method], if it's an instance method
/// of a class or mixin. Returns null otherwise.
InterfaceElement? enclosingInterface(MethodDeclaration method) {
  if (method.isStatic) return null;
  var enclosing = method.declaredFragment?.element.enclosingElement;
  return enclosing is InterfaceElement ? enclosing : null;
}

/// Returns the name of the method or function getter called by [node], like
/// `dispatchAndWait` in `dispatchAndWait(action)`, `store.dispatchAndWait(action)`
/// and `context.dispatchAndWait(action)`. Returns null if the name isn't known.
String? invokedName(InvocationExpression node) => switch (node) {
  MethodInvocation(:var methodName) => methodName.name,
  FunctionExpressionInvocation(function: SimpleIdentifier function) => function.name,
  FunctionExpressionInvocation(function: PropertyAccess function) =>
    function.propertyName.name,
  FunctionExpressionInvocation(function: PrefixedIdentifier function) =>
    function.identifier.name,
  _ => null,
};

/// Returns the expressions of the first argument of [node]: the argument itself or,
/// if it's a list literal, its elements. Spreads and other collection elements are
/// skipped.
List<Expression> firstArgumentExpressions(InvocationExpression node) {
  var arguments = node.argumentList.arguments;
  if (arguments.isEmpty || arguments.first is NamedArgument) return const [];
  var first = arguments.first.argumentExpression.unParenthesized;
  if (first is ListLiteral) return [...first.elements.whereType<Expression>()];
  return [first];
}

/// Returns true if [node] calls `super.name()`, or tears off `super.name`.
bool isSuperCall(AstNode? node, String name) => switch (node) {
  MethodInvocation(target: SuperExpression(), :var methodName) => methodName.name == name,
  PropertyAccess(target: SuperExpression(), :var propertyName) =>
    propertyName.name == name,
  _ => false,
};

/// Returns the expressions returned by [body]: the expression of an expression body,
/// or the expressions of the `return` statements of a block body. Returns in nested
/// functions are skipped.
List<Expression> returnedExpressions(FunctionBody body) {
  if (body is ExpressionFunctionBody) return [body.expression];
  if (body is! BlockFunctionBody) return const [];
  var collector = _ReturnCollector();
  body.block.accept(collector);
  return collector.expressions;
}

class _ReturnCollector extends RecursiveAstVisitorSkippingFunctions {
  final expressions = <Expression>[];

  @override
  void visitReturnStatement(ReturnStatement node) {
    var expression = node.expression;
    if (expression != null) expressions.add(expression);
  }
}

/// A recursive visitor that doesn't visit nested functions, like closures and
/// local functions.
class RecursiveAstVisitorSkippingFunctions extends RecursiveAstVisitor<void> {
  @override
  void visitFunctionExpression(FunctionExpression node) {}

  @override
  void visitFunctionDeclarationStatement(FunctionDeclarationStatement node) {}
}
