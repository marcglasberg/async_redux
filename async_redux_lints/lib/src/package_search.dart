// The analysis server plugin API doesn't offer a search. These use the search of the
// analysis driver, which is the one the IDE uses to find references, but is not a
// public API of package `analyzer`.
// ignore_for_file: implementation_imports

import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/dart/analysis/driver_based_analysis_context.dart';
import 'package:analyzer/src/dart/analysis/search.dart';

/// A reference to an element, in the file at [path].
typedef Reference = ({String path, int offset, int length});

/// Returns the references to [element] in all files analyzed together with the
/// current file, which usually means the whole package. Returns null if the search
/// is not available.
Future<List<Reference>?> searchReferences(
  AnalysisSession session,
  Element element,
) async {
  var search = _search(session);
  if (search == null) return null;
  return [
    for (var result in await search.references(element))
      if (result.enclosingFragment.libraryFragment?.source.fullName case var path?)
        (path: path, offset: result.offset, length: result.length),
  ];
}

/// Returns the classes that extend, implement or mix in [type] directly, in all files
/// analyzed together with the current file. Returns null if the search is not
/// available.
Future<List<ClassElement>?> searchDirectSubclasses(
  AnalysisSession session,
  InterfaceElement type,
) async {
  var search = _search(session);
  if (search == null) return null;
  return [
    for (var result in await search.directSubtypeReferences(type))
      if (result.enclosingFragment.element case ClassElement element) element,
  ];
}

Search? _search(AnalysisSession session) {
  var context = session.analysisContext;
  return (context is DriverBasedAnalysisContext) ? context.driver.search : null;
}
