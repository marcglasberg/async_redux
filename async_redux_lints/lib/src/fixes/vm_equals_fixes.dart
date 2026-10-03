import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

import '../rules/vm_field_not_in_equals_rule.dart';

/// Adds the reported field to the `equals` list of each constructor that misses it.
/// If a constructor doesn't pass `equals` to `Vm`, adds `equals: [...]`.
class AddFieldToVmEquals extends _AddToVmEquals {
  static const _kind = FixKind(
    'async_redux_lints.fix.addFieldToVmEquals',
    DartFixKindPriority.standard,
    "Add '{0}' to 'equals'",
  );

  AddFieldToVmEquals({required super.context}) : super(allFields: false);

  @override
  FixKind get fixKind => _kind;
}

/// Adds all missing fields to the `equals` list of each constructor. Only offered
/// when more than one field is missing.
class AddAllFieldsToVmEquals extends _AddToVmEquals {
  static const _kind = FixKind(
    'async_redux_lints.fix.addAllFieldsToVmEquals',
    DartFixKindPriority.standard - 1,
    "Add all missing fields to 'equals'",
  );

  AddAllFieldsToVmEquals({required super.context}) : super(allFields: true);

  @override
  FixKind get fixKind => _kind;
}

abstract class _AddToVmEquals extends ResolvedCorrectionProducer {
  final bool allFields;

  String _fieldName = '';

  _AddToVmEquals({required super.context, required this.allFields});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  List<String> get fixArguments => [_fieldName];

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var field = node.thisOrAncestorOfType<VariableDeclaration>();
    var classDeclaration = node.thisOrAncestorOfType<ClassDeclaration>();
    if (field == null || classDeclaration == null) return;
    _fieldName = field.name.lexeme;

    var constructors = missingVmEquals(classDeclaration);
    if (allFields) {
      var missingFields = {
        for (var constructor in constructors)
          for (var missingField in constructor.missingFields.keys)
            missingField.name.lexeme,
      };
      if (missingFields.length < 2) return;
    }

    var changes = <(VmConstructorEquals, List<String>)>[];
    for (var constructor in constructors) {
      var names = <String>{};
      for (var MapEntry(key: missingField, value: parameters)
          in constructor.missingFields.entries) {
        if (allFields || missingField.name.lexeme == _fieldName) names.addAll(parameters);
      }
      if (names.isNotEmpty) changes.add((constructor, names.toList()));
    }
    if (changes.isEmpty) return;

    await builder.addDartFileEdit(file, (builder) {
      for (var (constructor, names) in changes) {
        _addToEquals(builder, constructor, names);
      }
    });
  }

  void _addToEquals(
    DartFileEditBuilder builder,
    VmConstructorEquals constructor,
    List<String> names,
  ) {
    var joined = names.join(', ');

    var list = constructor.equalsList;
    if (list != null) {
      // A const list can't contain parameters.
      var constKeyword = list.constKeyword;
      if (constKeyword != null) {
        builder.addDeletion(range.startStart(constKeyword, constKeyword.next!));
      }

      var elements = list.elements;
      if (elements.isEmpty) {
        builder.addSimpleInsertion(list.leftBracket.end, joined);
        return;
      }

      var last = elements.last;
      var comma = last.endToken.next!;
      if (comma.type != TokenType.COMMA) {
        builder.addSimpleInsertion(last.end, ', $joined');
      } else if (_line(last.offset) != _line(list.leftBracket.offset)) {
        var prefix = '${utils.endOfLine}${utils.getLinePrefix(last.offset)}';
        builder.addSimpleInsertion(
          comma.end,
          names.map((name) => '$prefix$name,').join(),
        );
      } else {
        builder.addSimpleInsertion(comma.end, names.map((name) => ' $name,').join());
      }
      return;
    }

    var superInvocation = constructor.superInvocation;
    if (superInvocation != null) {
      var arguments = superInvocation.argumentList.arguments;
      if (arguments.isEmpty) {
        builder.addSimpleInsertion(
          superInvocation.argumentList.leftParenthesis.end,
          'equals: [$joined]',
        );
      } else {
        builder.addSimpleInsertion(arguments.last.end, ', equals: [$joined]');
      }
      return;
    }

    var initializers = constructor.constructor.initializers;
    if (initializers.isEmpty) {
      builder.addSimpleInsertion(
        constructor.constructor.parameters.end,
        ' : super(equals: [$joined])',
      );
    } else {
      builder.addSimpleInsertion(initializers.last.end, ', super(equals: [$joined])');
    }
  }

  int _line(int offset) => unitResult.lineInfo.getLocation(offset).lineNumber;
}
