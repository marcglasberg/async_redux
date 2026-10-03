import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';

/// Text to insert at an offset. Fixes that only use insertions never change
/// existing code.
class Insertion {
  final int offset;
  final String text;

  Insertion(this.offset, this.text);
}

/// Helpers for fixes that only insert code.
mixin Insertions on ResolvedCorrectionProducer {
  /// Adds [insertions] to the file.
  Future<void> insertAll(ChangeBuilder builder, List<Insertion> insertions) =>
      builder.addDartFileEdit(file, (builder) {
        for (var insertion in insertions) {
          builder.addSimpleInsertion(insertion.offset, insertion.text);
        }
      });

  /// Adds [items] after [last], the last item of a list that starts at [open].
  /// If the list has a trailing comma and is split into lines, adds each item in
  /// its own line.
  Insertion addAfterLast(AstNode last, Token open, List<String> items) {
    var comma = last.endToken.next!;
    if (comma.type != TokenType.COMMA) {
      return Insertion(last.end, ', ${items.join(', ')}');
    }
    if (line(last.offset) != line(open.offset)) {
      var prefix = '${utils.endOfLine}${utils.getLinePrefix(last.offset)}';
      return Insertion(comma.end, items.map((i) => '$prefix$i,').join());
    }
    return Insertion(comma.end, items.map((i) => ' $i,').join());
  }

  /// Adds [operands] after [expression], joined with the binary [operator], like
  /// `a && b`. [last] is the last operand of [expression]. If [expression] is split
  /// into lines, adds each operand in its own line, with the same indentation as
  /// [last], and the operator at the end of the previous line.
  Insertion addOperands(
    Expression expression,
    AstNode last,
    String operator,
    List<String> operands,
  ) {
    if (line(expression.offset) != line(expression.end)) {
      var prefix = '${utils.endOfLine}${utils.getLinePrefix(last.offset)}';
      return Insertion(
        expression.end,
        operands.map((operand) => ' $operator$prefix$operand').join(),
      );
    }
    return Insertion(
      expression.end,
      operands.map((operand) => ' $operator $operand').join(),
    );
  }

  /// Returns the 1-based line of [offset].
  int line(int offset) => unitResult.lineInfo.getLocation(offset).lineNumber;
}
