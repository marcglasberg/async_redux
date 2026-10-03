import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';

import 'redux_types.dart';

/// Returns true if [element] is a state class: it's annotated with `@stateClass`, or
/// extends, implements or mixes in a class or mixin annotated with `@stateClass`.
bool isStateClass(InterfaceElement element) => [
  element,
  for (var type in element.allSupertypes) type.element,
].any(hasStateClassAnnotation);

/// Returns true if [element] extends `Equatable`, or mixes in `EquatableMixin`, of
/// package `equatable`. The package is recognized by name, so neither `async_redux`
/// nor this plugin depend on it.
bool isEquatable(InterfaceElement element) => element.allSupertypes.any((type) {
  var name = type.element.name;
  return (name == 'Equatable' || name == 'EquatableMixin') &&
      type.element.library.uri.toString().startsWith('package:equatable/');
});

/// Returns the classes and mixins that [element] inherits members from: its
/// superclasses other than `Object`, and the mixins of [element] and of its
/// superclasses.
List<InterfaceElement> inheritedClasses(InterfaceElement element) => [
  for (
    InterfaceElement? e = element;
    e != null && e.supertype != null;
    e = e.supertype?.element
  ) ...[if (e != element) e, for (var mixin in e.mixins) mixin.element],
];

/// Returns the instance fields that [element] inherits. See [inheritedClasses].
List<FieldElement> inheritedFields(InterfaceElement element) => [
  for (var inherited in inheritedClasses(element))
    for (var field in inherited.fields)
      if (!field.isStatic &&
          (field.isOriginDeclaration || field.isOriginDeclaringFormalParameter))
        field,
];

/// Returns true if [element] inherits a concrete `==` operator, other than the one
/// of `Object`.
bool inheritsEquals(InterfaceElement element) => inheritedClasses(
  element,
).any((inherited) => inherited.getMethod('==')?.isAbstract == false);

/// Returns true if [element] inherits a concrete getter named [name], other than
/// the ones of `Object`.
bool inheritsGetter(InterfaceElement element, String name) => inheritedClasses(
  element,
).any((inherited) => inherited.getGetter(name)?.isAbstract == false);

/// Returns the fields of [fields] that the identifiers in [node] don't refer to.
List<T> unusedFields<T>(AstNode node, List<T> fields, Element? Function(T) element) {
  var used = {
    for (var element in referencedElements(node))
      if (element is GetterElement) element.variable.baseElement else element,
  };
  return [
    for (var field in fields)
      if (!used.contains(element(field))) field,
  ];
}

/// Returns true if [node] contains `super.[name]`.
bool usesSuperGetter(AstNode node, String name) => _contains(
  node,
  (node) =>
      node is PropertyAccess &&
      node.target is SuperExpression &&
      node.propertyName.name == name,
);

/// Returns true if [node] contains `super == ...`.
bool usesSuperEquals(AstNode node) => _contains(
  node,
  (node) =>
      node is BinaryExpression &&
      node.operator.lexeme == '==' &&
      node.leftOperand is SuperExpression,
);

/// Returns true if [node], or a node inside it, passes [test].
bool _contains(AstNode node, bool Function(AstNode) test) {
  var finder = _NodeFinder(test);
  node.accept(finder);
  return finder.found;
}

/// Returns `'a'`, `'a' and 'b'`, or `'a', 'b' and 'c'`.
String joinNames(List<String> names) {
  var quoted = [for (var name in names) "'$name'"];
  if (quoted.length == 1) return quoted.single;
  return '${quoted.sublist(0, quoted.length - 1).join(', ')} and ${quoted.last}';
}

/// Returns `Field 'a' is missing from '[member]'.`, or
/// `Fields 'a' and 'b' are missing from '[member]'.`
String missingFieldsMessage(List<String> names, String member) => names.length == 1
    ? "Field ${joinNames(names)} is missing from '$member'."
    : "Fields ${joinNames(names)} are missing from '$member'.";

/// Returns the elements that the identifiers in [node] refer to.
Set<Element> referencedElements(AstNode node) {
  var elements = <Element>{};
  node.accept(_ElementCollector(elements));
  return elements;
}

class _NodeFinder extends GeneralizingAstVisitor<void> {
  final bool Function(AstNode) test;
  bool found = false;

  _NodeFinder(this.test);

  @override
  void visitNode(AstNode node) {
    if (found) return;
    if (test(node)) {
      found = true;
    } else {
      super.visitNode(node);
    }
  }
}

class _ElementCollector extends RecursiveAstVisitor<void> {
  final Set<Element> elements;

  _ElementCollector(this.elements);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    var element = node.element;
    if (element != null) elements.add(element);
  }
}
