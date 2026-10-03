import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

/// How a widget accesses the store state.
enum StateAccess {
  /// `context.state`, or `context.getState<St>()`. Rebuilds on any state change.
  state,

  /// `context.select(...)`, or `context.getSelect<St, R>(...)`.
  select,

  /// `context.read()`, or `context.getRead<St>()`.
  read,
}

/// Returns how [element] accesses the store state, or null if it's not one of the
/// state access methods.
///
/// AsyncRedux declares `getState`, `getSelect` and `getRead` in an extension on
/// `BuildContext`. The docs recommend that apps declare their own extension with
/// `state`, `select` and `read`, which call those. These are recognized by their
/// names, when declared in an extension on `BuildContext`, in a library that imports
/// `async_redux`. The library must import `async_redux`, so that the `select` and
/// `read` extension methods of other packages, like `provider`, are not recognized.
StateAccess? stateAccessOf(Element? element) {
  element = element?.baseElement;
  if (element is! ExecutableElement) return null;
  var extension = element.enclosingElement;
  if (extension is! ExtensionElement) return null;

  if (isAsyncReduxLibrary(extension.library)) {
    return switch (element.name) {
      'getState' => StateAccess.state,
      'getSelect' => StateAccess.select,
      'getRead' => StateAccess.read,
      _ => null,
    };
  }

  if (!isBuildContext(extension.extendedType) || !_importsAsyncRedux(extension.library)) {
    return null;
  }
  return switch (element) {
    GetterElement(name: 'state') => StateAccess.state,
    MethodElement(name: 'select') => StateAccess.select,
    MethodElement(name: 'read') => StateAccess.read,
    _ => null,
  };
}

/// Returns how [node] accesses the store state, or null if it doesn't. For example,
/// [StateAccess.state] for `context.state` and [StateAccess.select] for
/// `context.select((st) => st.counter)`.
StateAccess? stateAccessOfNode(AstNode node) => switch (node) {
  PrefixedIdentifier() => stateAccessOf(node.identifier.element),
  PropertyAccess() => stateAccessOf(node.propertyName.element),
  MethodInvocation() => stateAccessOf(node.methodName.element),
  _ => null,
};

/// Returns the `context` of a state access like `context.state` or
/// `context.select(...)`, or null if it's implicit.
Expression? stateAccessTarget(Expression node) => switch (node) {
  PrefixedIdentifier() => node.prefix,
  PropertyAccess() => node.target,
  MethodInvocation() => node.target,
  _ => null,
};

bool isAsyncReduxLibrary(LibraryElement library) =>
    library.uri.toString().startsWith('package:async_redux/');

final _importsAsyncReduxCache = Expando<bool>();

bool _importsAsyncRedux(LibraryElement library) =>
    _importsAsyncReduxCache[library] ??= library.fragments.any(
      (fragment) => fragment.libraryImports.any((import) {
        var imported = import.importedLibrary;
        if (imported == null) return false;
        // A library of the app may export async_redux.
        return isAsyncReduxLibrary(imported) ||
            import.namespace.definedNames2.values.any(
              (element) =>
                  element.library != null && isAsyncReduxLibrary(element.library!),
            );
      }),
    );

/// Returns true if [type] is Flutter's `BuildContext`.
bool isBuildContext(DartType? type) =>
    type is InterfaceType && _isFlutterElement(type.element, 'BuildContext');

/// Returns true if [element] extends Flutter's `State`.
bool isFlutterState(InterfaceElement element) =>
    element.allSupertypes.any((type) => _isFlutterElement(type.element, 'State'));

bool _isFlutterElement(Element element, String name) =>
    element.name == name &&
    (element.library?.uri.toString().startsWith('package:flutter/') ?? false);

/// Returns true if [element] is the `Vm` class of package `async_redux`.
bool isVm(Element? element) =>
    element is InterfaceElement &&
    element.name == 'Vm' &&
    isAsyncReduxLibrary(element.library);

/// Returns true if [element] is a subclass of `Vm`, but not `Vm` itself.
bool isVmSubclass(InterfaceElement element) =>
    !isVm(element) && element.allSupertypes.any((type) => isVm(type.element));

/// Returns true if [node] is a closure that gets a `BuildContext`, like the
/// `builder` of a `Builder` widget, but not a local function declaration.
bool isBuilder(FunctionExpression node) {
  if (node.parent is FunctionDeclaration) return false;
  var parameters = node.parameters?.parameters ?? const <FormalParameter>[];
  return parameters.any(
    (parameter) => isBuildContext(parameter.declaredFragment?.element.type),
  );
}

/// Returns true if [node] runs while the widget builds: directly in a `build`
/// method, or in a builder like `Builder(builder: (context) => ...)`. Code in other
/// closures inside them, like `onPressed: () => ...`, is not considered. Neither is
/// a closure that gets a `BuildContext` but is passed as a callback, like
/// `onInit: (context) => ...`, since it may run when the widget is not building.
bool runsWhileBuilding(AstNode node) {
  for (var ancestor = node.parent; ancestor != null; ancestor = ancestor.parent) {
    switch (ancestor) {
      case FunctionExpression():
        var parent = ancestor.parent;
        return isBuilder(ancestor) &&
            !(parent is NamedArgument && _callbackName.hasMatch(parent.name.lexeme));
      case MethodDeclaration():
        return ancestor.name.lexeme == 'build';
      case FunctionDeclaration():
      case CompilationUnit():
        return false;
    }
  }
  return false;
}

/// Returns true if [node] is directly in the `initState` method of a `State`, and
/// not in a closure inside it, like `addPostFrameCallback((_) => ...)`.
bool isInInitState(AstNode node) {
  for (var ancestor = node.parent; ancestor != null; ancestor = ancestor.parent) {
    switch (ancestor) {
      case FunctionExpression():
      case FunctionDeclaration():
      case CompilationUnit():
        return false;
      case MethodDeclaration():
        var enclosing = ancestor.declaredFragment?.element.enclosingElement;
        return ancestor.name.lexeme == 'initState' &&
            enclosing is InterfaceElement &&
            isFlutterState(enclosing);
    }
  }
  return false;
}

const _stateLifecycleMethods = {
  'initState',
  'didChangeDependencies',
  'didUpdateWidget',
  'activate',
  'deactivate',
  'dispose',
  'reassemble',
};

final _callbackName = RegExp(r'^on[A-Z]');

/// Returns a description of the code around [node] that doesn't run while the
/// widget builds, like "the 'onPressed' callback". Returns null if that code may
/// run while the widget builds.
///
/// These are closures passed as a named argument that starts with `on`, like
/// `onPressed`, and the `State` methods `initState`, `didChangeDependencies`,
/// `didUpdateWidget`, `activate`, `deactivate`, `dispose` and `reassemble`.
String? notBuildingDescription(AstNode node) {
  for (var ancestor = node.parent; ancestor != null; ancestor = ancestor.parent) {
    switch (ancestor) {
      case FunctionExpression():
        if (isBuilder(ancestor)) return null;
        var parent = ancestor.parent;
        if (parent is NamedArgument && _callbackName.hasMatch(parent.name.lexeme)) {
          return "the '${parent.name.lexeme}' callback";
        }
      case MethodDeclaration():
        var name = ancestor.name.lexeme;
        var enclosing = ancestor.declaredFragment?.element.enclosingElement;
        if (_stateLifecycleMethods.contains(name) &&
            enclosing is InterfaceElement &&
            isFlutterState(enclosing)) {
          return "'$name'";
        }
        return null;
      case FunctionDeclaration():
      case ClassDeclaration():
      case CompilationUnit():
        return null;
    }
  }
  return null;
}
