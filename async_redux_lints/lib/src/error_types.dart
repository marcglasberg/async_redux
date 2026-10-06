import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/type_system.dart';

import 'redux_types.dart';

/// Returns true if [element] is the `UserException` class, which is declared in
/// package `async_redux_core`, and exported by package `async_redux`.
bool isUserExceptionClass(Element? element) =>
    element is InterfaceElement &&
    element.name == 'UserException' &&
    _isAsyncReduxOrCore(element.library);

/// Returns true if [type] is `UserException`, or a subclass of it.
bool isUserExceptionType(DartType? type) =>
    type is InterfaceType &&
    (isUserExceptionClass(type.element) ||
        type.element.allSupertypes.any((type) => isUserExceptionClass(type.element)));

bool _isAsyncReduxOrCore(LibraryElement library) {
  var uri = library.uri.toString();
  return uri.startsWith('package:async_redux/') ||
      uri.startsWith('package:async_redux_core/');
}

/// Returns true if [element] extends the `GlobalErrorObserver` of AsyncRedux.
bool isGlobalErrorObserver(InterfaceElement element) =>
    _extendsAsyncReduxClass(element, 'GlobalErrorObserver');

/// Returns true if [element] extends the `Persistor` of AsyncRedux.
bool isPersistor(InterfaceElement element) =>
    _extendsAsyncReduxClass(element, 'Persistor');

/// Returns true if [element] is the `Store` class of AsyncRedux.
bool isStore(Element? element) =>
    element is InterfaceElement && element.name == 'Store' && isFromAsyncRedux(element);

bool _extendsAsyncReduxClass(InterfaceElement element, String name) => element
    .allSupertypes
    .any((type) => type.element.name == name && isFromAsyncRedux(type.element));

/// Returns the class or mixin that contains [node], or null if there's none.
InterfaceElement? enclosingInterface(AstNode node) {
  var declaration = node.thisOrAncestorMatching(
    (node) => node is ClassDeclaration || node is MixinDeclaration,
  );
  return switch (declaration) {
    ClassDeclaration() => declaration.declaredFragment?.element,
    MixinDeclaration() => declaration.declaredFragment?.element,
    _ => null,
  };
}

/// Returns the method that contains [node], without going through closures, or null
/// if there's none.
MethodDeclaration? enclosingMethodOutsideClosures(AstNode node) {
  for (var ancestor = node.parent; ancestor != null; ancestor = ancestor.parent) {
    switch (ancestor) {
      case MethodDeclaration():
        return ancestor;
      case FunctionExpression():
      case FunctionDeclaration():
      case ClassDeclaration():
      case MixinDeclaration():
      case CompilationUnit():
        return null;
    }
  }
  return null;
}

/// The names of the dispatch methods of AsyncRedux.
const dispatchNames = {
  'dispatch',
  'dispatchAndWait',
  'dispatchAll',
  'dispatchAndWaitAll',
  'dispatchSync',
};

/// Returns the identifier of the dispatch method of AsyncRedux that [node] calls, like
/// `dispatch` in `store.dispatch(action)`, or null if [node] doesn't dispatch.
/// Recognizes `dispatch`, `dispatchAndWait`, `dispatchAll`, `dispatchAndWaitAll` and
/// `dispatchSync`, as methods, or as getters of function type.
SimpleIdentifier? dispatchMethodName(InvocationExpression node) {
  var name = switch (node) {
    MethodInvocation() => node.methodName,
    FunctionExpressionInvocation(function: SimpleIdentifier function) => function,
    FunctionExpressionInvocation(function: PropertyAccess function) =>
      function.propertyName,
    FunctionExpressionInvocation(function: PrefixedIdentifier function) =>
      function.identifier,
    _ => null,
  };
  if (name == null || !dispatchNames.contains(name.name)) return null;
  var element = name.element?.baseElement;
  return (element != null && isFromAsyncRedux(element)) ? name : null;
}

/// Returns true if [node], which throws a value of static [type], is inside the `try`
/// block of a `try` statement with a `catch` that may catch it. Only looks inside the
/// function body that contains [node], since code in a closure runs when the closure is
/// called, and not where it's declared.
bool isCaughtLocally(AstNode node, DartType? type, TypeSystem typeSystem) {
  for (
    AstNode? child = node, parent = node.parent;
    parent != null && child is! FunctionBody;
    child = parent, parent = parent.parent
  ) {
    if (parent is TryStatement && parent.body == child) {
      if (parent.catchClauses.any((clause) => _catches(clause, type, typeSystem))) {
        return true;
      }
    }
  }
  return false;
}

/// Returns true if [clause] may catch a value of static [type]. When the types are
/// related, either way, the value may be caught.
bool _catches(CatchClause clause, DartType? type, TypeSystem typeSystem) {
  var caughtType = clause.exceptionType?.type;
  if (caughtType == null || type == null) return true;
  return typeSystem.isSubtypeOf(type, caughtType) ||
      typeSystem.isSubtypeOf(caughtType, type);
}

/// Returns true if [node] declares a local variable, parameter or local function
/// called [name].
///
/// A method can be asked about several names, like once for each dispatch in a large
/// `build` method, so the names that [node] declares are collected once, and cached.
bool declaresLocalName(AstNode node, String name) =>
    (_declaredNamesCache[node] ??= _declaredNames(node)).contains(name);

final _declaredNamesCache = Expando<Set<String>>();

Set<String> _declaredNames(AstNode node) {
  var collector = _DeclarationCollector();
  node.accept(collector);
  return collector.names;
}

/// Collects the names of the local variables, parameters and local functions.
class _DeclarationCollector extends RecursiveAstVisitor<void> {
  final names = <String>{};

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    names.add(node.name.lexeme);
    super.visitVariableDeclaration(node);
  }

  @override
  void visitFormalParameterList(FormalParameterList node) {
    for (var parameter in node.parameters) {
      if (parameter.name case var name?) names.add(name.lexeme);
    }
    super.visitFormalParameterList(node);
  }

  @override
  void visitCatchClauseParameter(CatchClauseParameter node) {
    names.add(node.name.lexeme);
    super.visitCatchClauseParameter(node);
  }

  @override
  void visitDeclaredIdentifier(DeclaredIdentifier node) {
    names.add(node.name.lexeme);
    super.visitDeclaredIdentifier(node);
  }

  @override
  void visitDeclaredVariablePattern(DeclaredVariablePattern node) {
    names.add(node.name.lexeme);
    super.visitDeclaredVariablePattern(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    names.add(node.name.lexeme);
    super.visitFunctionDeclaration(node);
  }
}

/// Returns true if [node] contains an identifier called [name].
bool usesName(AstNode node, String name) {
  var finder = _NameFinder(name);
  node.accept(finder);
  return finder.found;
}

class _NameFinder extends RecursiveAstVisitor<void> {
  final String name;
  bool found = false;

  _NameFinder(this.name);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name == name) found = true;
  }
}
