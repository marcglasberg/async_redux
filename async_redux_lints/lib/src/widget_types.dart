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
