import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

import '../rules/state_contents_rules.dart';

/// Changes the type of a state class field from `List`, `Set` or `Map` to `IList`,
/// `ISet` or `IMap` of package `fast_immutable_collections`, adding the import if
/// needed. Keeps the type arguments, like `List<User>` to `IList<User>`.
///
/// Only offered when the package can import `fast_immutable_collections`, and the
/// field has a declared type. The values assigned to the field, like `[]`, are not
/// changed.
class UseImmutableCollection extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'async_redux_lints.fix.useImmutableCollection',
    DartFixKindPriority.standard,
    "Change the type to '{0}'",
  );

  static const _libraryUri =
      'package:fast_immutable_collections/fast_immutable_collections.dart';

  String _immutableName = '';

  UseImmutableCollection({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  List<String> get fixArguments => [_immutableName];

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var variables = node.thisOrAncestorOfType<VariableDeclarationList>();
    var type = variables?.type;
    if (type is! NamedType || type.importPrefix != null) return;
    var collection = PreferImmutableCollectionsRule.mutableCollectionName(type.type);
    if (collection == null) return;
    var immutable = PreferImmutableCollectionsRule.immutableCollections[collection]!;

    var library = await unitResult.session.getLibraryByUri(_libraryUri);
    if (library is! LibraryElementResult) return;

    _immutableName = immutable;
    await builder.addDartFileEdit(file, (builder) {
      var prefix = builder.importLibraryElement(Uri.parse(_libraryUri)).prefix;
      var name = (prefix == null) ? immutable : '$prefix.$immutable';
      builder.addSimpleReplacement(range.token(type.name), name);
    });
  }
}
