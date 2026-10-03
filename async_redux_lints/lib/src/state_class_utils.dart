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

class _ElementCollector extends RecursiveAstVisitor<void> {
  final Set<Element> elements;

  _ElementCollector(this.elements);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    var element = node.element;
    if (element != null) elements.add(element);
  }
}
