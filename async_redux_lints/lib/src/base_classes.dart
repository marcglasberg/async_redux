import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/workspace/workspace.dart';

import 'redux_types.dart';

/// Returns true if [candidate] is a base class that a class extending [superType]
/// can extend instead. That's an abstract class of your own that extends the class of
/// [superType] directly, like `abstract class AppAction extends ReduxAction<AppState>`
/// for `ReduxAction<AppState>`.
bool isBaseClassFor(ClassElement candidate, InterfaceType superType) =>
    candidate.isAbstract &&
    !isFromAsyncRedux(candidate) &&
    candidate.supertype?.element == superType.element &&
    baseClassTypeArguments(candidate, superType) != null;

/// Returns the type arguments of [base] that make it a subtype of [superType], as
/// indexes into the type arguments of [superType]. Returns null if no type arguments
/// do, or if [base] doesn't extend the class of [superType] directly.
///
/// For example, for `abstract class AppAction extends ReduxAction<AppState>` and
/// `ReduxAction<AppState>`, returns `[]`. For `abstract class Base<St> extends
/// ReduxAction<St>` and `ReduxAction<AppState>`, returns `[0]`, since
/// `Base<AppState>` is that type.
List<int>? baseClassTypeArguments(ClassElement base, InterfaceType superType) {
  var baseSupertype = base.supertype;
  if (baseSupertype == null || baseSupertype.element != superType.element) return null;

  var typeParameters = base.typeParameters;
  var indexes = List<int?>.filled(typeParameters.length, null);
  var arguments = superType.typeArguments;
  for (var i = 0; i < arguments.length; i++) {
    var baseArgument = baseSupertype.typeArguments[i];
    var parameterIndex = (baseArgument is TypeParameterType)
        ? typeParameters.indexOf(baseArgument.element)
        : -1;
    if (parameterIndex == -1) {
      if (baseArgument != arguments[i]) return null;
    } else if (indexes[parameterIndex] == null) {
      indexes[parameterIndex] = i;
    } else if (arguments[indexes[parameterIndex]!] != arguments[i]) {
      return null;
    }
  }
  if (indexes.contains(null)) return null;
  return indexes.cast<int>();
}

/// Returns the classes declared in [library], and in the libraries of [package] that
/// it imports or exports, directly or indirectly. These are the classes a rule can see
/// without searching the whole package.
Iterable<ClassElement> visiblePackageClasses(
  LibraryElement library,
  WorkspacePackage? package,
) sync* {
  for (var visible in visiblePackageLibraries(library, package)) {
    yield* visible.classes;
  }
}

/// Returns [library], and the libraries of [package] that it imports or exports,
/// directly or indirectly. These are already resolved, so no files are read.
Iterable<LibraryElement> visiblePackageLibraries(
  LibraryElement library,
  WorkspacePackage? package,
) sync* {
  var visited = <LibraryElement>{library};
  var pending = [library];
  while (pending.isNotEmpty) {
    var current = pending.removeLast();
    yield current;
    if (package == null) continue;
    for (var fragment in current.fragments) {
      var libraries = [
        for (var import in fragment.libraryImports) import.importedLibrary,
        for (var export in fragment.libraryExports) export.exportedLibrary,
      ];
      for (var other in libraries) {
        if (other == null || !package.contains(other.firstFragment.source)) continue;
        if (visited.add(other)) pending.add(other);
      }
    }
  }
}
