import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

import '../package_search.dart';
import '../rules/action_name_rules.dart';

/// Renames an action to follow the [style], in all files of the package.
///
/// Not offered when the new name is already used in the library, or when the
/// package can't be searched.
class RenameAction extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'async_redux_lints.fix.renameAction',
    DartFixKindPriority.standard,
    "Rename to '{0}'",
  );

  final ActionNameStyle style;

  String _newName = '';

  RenameAction(this.style, {required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  List<String> get fixArguments => [_newName];

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var element = _diagnosticClass();
    var oldName = element?.name;
    if (element == null || oldName == null) return;

    var newName = style.suggestedName(oldName);
    if (newName == null) return;
    if (libraryElement2.firstFragment.scope.lookup(newName).getter != null) return;

    var references = await searchReferences(unitResult.session, element);
    if (references == null) return;

    // The offsets of the class name, by file. The declarations are not references.
    var offsetsByPath = <String, Set<int>>{};
    void add(String? path, int? offset) {
      if (path != null && offset != null) {
        offsetsByPath.putIfAbsent(path, () => {}).add(offset);
      }
    }

    for (var fragment in element.fragments) {
      add(fragment.libraryFragment.source.fullName, fragment.nameOffset);
    }
    for (var constructor in element.constructors) {
      for (var fragment in constructor.fragments) {
        if (fragment.typeName != oldName) continue;
        add(fragment.libraryFragment.source.fullName, fragment.typeNameOffset);
      }
    }
    for (var reference in references) {
      if (reference.length == oldName.length) add(reference.path, reference.offset);
    }

    _newName = newName;
    for (var MapEntry(key: path, value: offsets) in offsetsByPath.entries) {
      await builder.addDartFileEdit(path, (builder) {
        for (var offset in offsets) {
          builder.addSimpleReplacement(SourceRange(offset, oldName.length), newName);
        }
      });
    }
  }

  /// Returns the class whose name is the diagnostic range.
  ClassElement? _diagnosticClass() {
    var offset = diagnosticOffset;
    var declaration = node.thisOrAncestorMatching(
      (node) =>
          (node is ClassDeclaration && node.namePart.typeName.offset == offset) ||
          (node is ClassTypeAlias && node.name.offset == offset),
    );
    return switch (declaration) {
      ClassDeclaration(:var declaredFragment) => declaredFragment?.element,
      ClassTypeAlias(:var declaredFragment) => declaredFragment?.element,
      _ => null,
    };
  }
}
