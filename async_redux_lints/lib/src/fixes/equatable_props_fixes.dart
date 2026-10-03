import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

import '../rules/equatable_props_missing_field_rule.dart';
import '../state_class_utils.dart';
import 'insertions.dart';

/// Adds the missing fields to `props`. For missing inherited fields, adds
/// `...super.props` at the start of the list when a superclass or mixin implements
/// `props`, and adds the fields themselves otherwise.
///
/// Only inserts code, and is only offered when `props` returns a list literal that
/// is not `const`. Not offered when the class doesn't declare `props`.
class AddMissingFieldsToProps extends ResolvedCorrectionProducer with Insertions {
  static const _kind = FixKind(
    'async_redux_lints.fix.addMissingFieldsToProps',
    DartFixKindPriority.standard,
    "Add {0} to 'props'",
  );

  String _names = '';

  AddMissingFieldsToProps({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  List<String> get fixArguments => [_names];

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var classDeclaration = node.thisOrAncestorOfType<ClassDeclaration>();
    if (classDeclaration == null) return;
    var missing = missingPropsFields(classDeclaration);
    var props = missing?.props;
    if (missing == null || props == null) return;
    var list = propsList(props);
    if (list == null) return;

    var addSuperProps =
        missing.inheritedFields.isNotEmpty && missing.superImplementsProps;
    var names = [
      ...missing.declaredFields,
      if (!addSuperProps) ...missing.inheritedFields,
    ];

    var insertions = <Insertion>[];
    var elements = list.elements;
    if (elements.isEmpty) {
      insertions.add(
        Insertion(
          list.leftBracket.end,
          [if (addSuperProps) '...super.props', ...names].join(', '),
        ),
      );
    } else {
      if (addSuperProps) insertions.add(_addFirst(list, '...super.props'));
      if (names.isNotEmpty) {
        insertions.add(addAfterLast(elements.last, list.leftBracket, names));
      }
    }

    _names = joinNames([if (addSuperProps) '...super.props', ...names]);
    await insertAll(builder, insertions);
  }

  /// Adds [item] before the first element of [list]. If the first element is in its
  /// own line, adds [item] in its own line too.
  Insertion _addFirst(ListLiteral list, String item) {
    var first = list.elements.first;
    if (line(first.offset) != line(list.leftBracket.offset)) {
      return Insertion(
        first.offset,
        '$item,${utils.endOfLine}${utils.getLinePrefix(first.offset)}',
      );
    }
    return Insertion(first.offset, '$item, ');
  }
}
