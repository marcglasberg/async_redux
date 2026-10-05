import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

import '../rules/action_without_to_string_rule.dart';

/// Adds a `toString()` override to an action, with all its fields, like
/// `String toString() => '${super.toString()}(id: $id)';`.
class AddActionToString extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'async_redux_lints.fix.addActionToString',
    DartFixKindPriority.standard,
    "Override 'toString()'",
  );

  /// The maximum length of a line of the generated code.
  static const _pageWidth = 90;

  AddActionToString({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var declaration = node.thisOrAncestorOfType<ClassDeclaration>();
    var element = declaration?.declaredFragment?.element;
    var body = declaration?.body;
    if (element == null || body is! BlockClassBody) return;
    var fields = actionFieldsForToString(element);
    if (fields.isEmpty) return;

    var eol = utils.endOfLine;
    var members = body.members;
    var indent = members.isEmpty
        ? utils.getLinePrefix(declaration!.offset) + utils.oneIndent
        : utils.getLinePrefix(members.last.offset);
    var values = fields
        .map((field) => '${field.displayName}: \$${field.displayName}')
        .join(', ');
    var string = "'\${super.toString()}($values)';";
    var oneLine = '${indent}String toString() => $string';
    var method = (oneLine.length <= _pageWidth)
        ? oneLine
        : '${indent}String toString() =>$eol$indent${utils.oneIndent * 2}$string';
    var text = '$indent@override$eol$method';

    await builder.addDartFileEdit(file, (builder) {
      if (members.isEmpty) {
        builder.addSimpleInsertion(body.leftBracket.end, '$eol$text$eol');
      } else {
        builder.addSimpleInsertion(members.last.end, '$eol$eol$text');
      }
    });
  }
}
