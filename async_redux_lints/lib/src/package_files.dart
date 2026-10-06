import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/workspace/workspace.dart';

// The analyzer answers these questions by comparing paths, which is slow, and the
// rules ask them again for the same files and libraries, so the answers are cached.
// They only depend on the path of the file and on the package, and the analyzer keeps
// the same package objects while the package doesn't change.

/// Returns true if [library] is in [package].
///
/// When a file changes, the analyzer creates new elements for its library, so the
/// cached values of the old elements are not used anymore.
bool isInPackage(LibraryElement library, WorkspacePackage package) {
  var cached = _isInPackageCache[library];
  if (cached != null && identical(cached.package, package)) return cached.isIn;
  var isIn = package.contains(library.firstFragment.source);
  _isInPackageCache[library] = (package: package, isIn: isIn);
  return isIn;
}

final _isInPackageCache = Expando<({WorkspacePackage package, bool isIn})>();

/// Returns true if [file] is in a test directory of [package], like `test/`. Same as
/// `package?.isInTestDirectory(file) ?? false`.
bool isInTestDirectory(WorkspacePackage? package, File file) {
  if (package == null) return false;
  var cache = _isInTestDirectoryCache[package] ??= {};
  return cache[file.path] ??= package.isInTestDirectory(file);
}

final _isInTestDirectoryCache = Expando<Map<String, bool>>();

/// Returns true if the library being analyzed is in a test directory of its package.
/// Same as `context.isInTestDirectory`.
bool isLibraryInTestDirectory(RuleContext context) =>
    isInTestDirectory(context.package, context.definingUnit.file);

/// Returns true if the library being analyzed is in the `lib` directory of its
/// package. Same as `context.isInLibDir`.
bool isLibraryInLibDir(RuleContext context) {
  var package = context.package;
  if (package == null) return false;
  var cache = _isInLibDirCache[package] ??= {};
  return cache[context.definingUnit.file.path] ??= context.isInLibDir;
}

final _isInLibDirCache = Expando<Map<String, bool>>();
