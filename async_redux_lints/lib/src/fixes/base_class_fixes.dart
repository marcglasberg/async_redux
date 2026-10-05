import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

import '../base_classes.dart';
import '../package_search.dart';

/// Replaces the superclass of an action, like `ReduxAction<AppState>`, with a base
/// action of the package, like `AppAction`.
///
/// The base classes are searched in the whole package, and sorted by name. Each fix
/// offers the one at its [index], so that up to [maxFixes] base classes are offered.
class UseBaseClass extends ResolvedCorrectionProducer {
  static const maxFixes = 3;

  static const _kinds = [
    FixKind(
      'async_redux_lints.fix.useBaseClass',
      DartFixKindPriority.standard,
      "Extend '{0}'",
    ),
    FixKind(
      'async_redux_lints.fix.useBaseClass2',
      DartFixKindPriority.standard - 1,
      "Extend '{0}'",
    ),
    FixKind(
      'async_redux_lints.fix.useBaseClass3',
      DartFixKindPriority.standard - 2,
      "Extend '{0}'",
    ),
  ];

  final int index;

  String _baseName = '';

  UseBaseClass(this.index, {required super.context}) : assert(index < maxFixes);

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kinds[index];

  @override
  List<String> get fixArguments => [_baseName];

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var superclass = _diagnosticSuperclass();
    var superType = superclass?.type;
    if (superclass == null || superType is! InterfaceType) return;

    var bases = await _baseClasses(superType);
    if (index >= bases.length) return;
    var base = bases[index];
    var indexes = baseClassTypeArguments(base, superType)!;

    var arguments = superclass.typeArguments?.arguments;
    var typeArguments = [
      for (var i in indexes)
        (arguments == null)
            ? superType.typeArguments[i].getDisplayString()
            : utils.getNodeText(arguments[i]),
    ];

    _baseName = base.displayName;
    await builder.addDartFileEdit(file, (builder) {
      builder.addReplacement(range.node(superclass), (builder) {
        builder.writeReference(base);
        if (typeArguments.isNotEmpty) builder.write('<${typeArguments.join(', ')}>');
      });
    });
  }

  /// Returns the base classes for [superType] that the current library can use,
  /// sorted by name. The classes of the library itself are found even when the
  /// package can't be searched.
  Future<List<ClassElement>> _baseClasses(InterfaceType superType) async {
    var library = libraryElement2;
    var candidates = <ClassElement>{
      ...visiblePackageClasses(library, null),
      ...?await searchDirectSubclasses(unitResult.session, superType.element),
    };
    var isPackageLibrary = library.uri.isScheme('package');
    return candidates.where((candidate) {
      if (!isBaseClassFor(candidate, superType)) return false;
      if (candidate.library == library) return true;
      // A private class can't be used, and a library under `lib` can't import one
      // that is not.
      if (candidate.isPrivate) return false;
      return !isPackageLibrary || candidate.library.uri.isScheme('package');
    }).toList()..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  /// Returns the superclass whose range is the diagnostic range.
  NamedType? _diagnosticSuperclass() {
    var offset = diagnosticOffset;
    var length = diagnosticLength;
    for (AstNode? node = coveringNode; node != null; node = node.parent) {
      if (node is NamedType && node.offset == offset && node.length == length) {
        return node;
      }
    }
    return null;
  }
}
