import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

import '../rules/state_class_equality_rules.dart';
import '../state_class_utils.dart';
import 'insertions.dart';

/// Adds the missing fields to `==` or `hashCode`. Only inserts code, and is only
/// offered when the member has one of these forms:
///
/// ```dart
/// bool operator ==(Object other) =>
///     identical(this, other) ||
///     other is AppState && runtimeType == other.runtimeType && a == other.a;
///
/// int get hashCode => Object.hash(a, b);
/// int get hashCode => Object.hashAll([a, b]);
/// int get hashCode => a.hashCode ^ b.hashCode;
/// ```
///
/// For `==`, the `&&` chain must contain `other is ...`, so that `other` can be
/// used as the class. `Object.hash` accepts at most 20 values, so the fix is not
/// offered if there would be more.
class AddMissingFieldsToEquality extends ResolvedCorrectionProducer with Insertions {
  static const _kind = FixKind(
    'async_redux_lints.fix.addMissingFieldsToEquality',
    DartFixKindPriority.standard,
    "Add {0} to '{1}'",
  );

  String _names = '';
  String _member = '';

  AddMissingFieldsToEquality({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  List<String> get fixArguments => [_names, _member];

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var method = node.thisOrAncestorOfType<MethodDeclaration>();
    var classDeclaration = node.thisOrAncestorOfType<ClassDeclaration>();
    if (method == null || classDeclaration == null) return;

    var fields = missingEqualityFields(
      classDeclaration,
    ).where((member) => member.method == method).firstOrNull?.missingFields;
    if (fields == null) return;
    var names = [for (var field in fields) field.name.lexeme];

    var expression = _returnedExpression(method.body);
    if (expression == null) return;
    var insertion = method.isOperator
        ? _addToEquals(method, expression, names)
        : _addToHashCode(expression, names);
    if (insertion == null) return;

    _names = joinNames(names);
    _member = method.name.lexeme;
    await insertAll(builder, [insertion]);
  }

  /// Adds `name == other.name` to the `&&` chain of `==`.
  Insertion? _addToEquals(
    MethodDeclaration method,
    Expression expression,
    List<String> names,
  ) {
    var parameter = method.parameters?.parameters.singleOrNull;
    var parameterElement = parameter?.declaredFragment?.element;
    if (parameter == null || parameterElement == null) return null;

    var chain = expression;
    if (chain is BinaryExpression && chain.operator.type == TokenType.BAR_BAR) {
      chain = chain.rightOperand;
    }
    if (chain is ParenthesizedExpression) chain = chain.expression;

    var operands = _andOperands(chain);
    var checksType = operands.any(
      (operand) =>
          operand is IsExpression &&
          operand.notOperator == null &&
          operand.expression is SimpleIdentifier &&
          (operand.expression as SimpleIdentifier).element == parameterElement,
    );
    if (!checksType) return null;

    var other = parameter.name!.lexeme;
    return addOperands(chain, operands.last, '&&', [
      for (var name in names) '$name == $other.$name',
    ]);
  }

  /// Adds the fields to `Object.hash(...)` or `Object.hashAll([...])`, or adds
  /// `name.hashCode` to a `^` chain.
  Insertion? _addToHashCode(Expression expression, List<String> names) {
    if (expression is MethodInvocation && _isObject(expression.target)) {
      var arguments = expression.argumentList.arguments;
      switch (expression.methodName.name) {
        case 'hash':
          if (arguments.length + names.length > 20) return null;
          return arguments.isEmpty
              ? Insertion(expression.argumentList.leftParenthesis.end, names.join(', '))
              : addAfterLast(
                  arguments.last,
                  expression.argumentList.leftParenthesis,
                  names,
                );
        case 'hashAll':
          var list = arguments.singleOrNull?.argumentExpression;
          if (list is! ListLiteral) return null;
          return list.elements.isEmpty
              ? Insertion(list.leftBracket.end, names.join(', '))
              : addAfterLast(list.elements.last, list.leftBracket, names);
      }
      return null;
    }

    var operands = _caretOperands(expression);
    if (operands.isEmpty) return null;
    return addOperands(expression, operands.last, '^', [
      for (var name in names) '$name.hashCode',
    ]);
  }

  /// Returns the operands of the `&&` chain [expression], or [expression] itself.
  static List<Expression> _andOperands(Expression expression) =>
      expression is BinaryExpression &&
          expression.operator.type == TokenType.AMPERSAND_AMPERSAND
      ? [..._andOperands(expression.leftOperand), expression.rightOperand]
      : [expression];

  /// Returns the operands of the `^` chain [expression], or `[expression]` if it's
  /// a single `x.hashCode`. Returns an empty list otherwise, since appending
  /// `^ name.hashCode` to other expressions may change their meaning.
  static List<Expression> _caretOperands(Expression expression) {
    if (expression is BinaryExpression && expression.operator.type == TokenType.CARET) {
      return [..._caretOperands(expression.leftOperand), expression.rightOperand];
    }
    var isHashCode = switch (expression) {
      PrefixedIdentifier(:var identifier) => identifier.name == 'hashCode',
      PropertyAccess(:var propertyName) => propertyName.name == 'hashCode',
      _ => false,
    };
    return isHashCode ? [expression] : const [];
  }

  static bool _isObject(Expression? target) =>
      target is SimpleIdentifier &&
      target.element is ClassElement &&
      (target.element as ClassElement).library.isDartCore &&
      target.name == 'Object';

  /// Returns the expression of `=> expression`, or of a body with a single
  /// `return expression;`.
  static Expression? _returnedExpression(FunctionBody body) => switch (body) {
    ExpressionFunctionBody() => body.expression,
    BlockFunctionBody(block: Block(statements: [ReturnStatement(:var expression)])) =>
      expression,
    _ => null,
  };
}
