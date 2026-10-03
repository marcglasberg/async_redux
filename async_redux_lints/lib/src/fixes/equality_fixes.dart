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

/// Adds the fields declared in the class that are missing from `==` or `hashCode`.
/// See [_AddToEquality] for when it's offered.
class AddMissingFieldsToEquality extends _AddToEquality {
  static const _kind = FixKind(
    'async_redux_lints.fix.addMissingFieldsToEquality',
    DartFixKindPriority.standard,
    '{0}',
  );

  AddMissingFieldsToEquality({required super.context});

  @override
  FixKind get fixKind => _kind;

  @override
  List<EqualityMemberFields> missingMembers(ClassDeclaration node) =>
      missingEqualityFields(node);
}

/// Adds `super == other` to `==`, or `super.hashCode` to `hashCode`, when a
/// superclass or mixin overrides them. Otherwise, adds the inherited fields that
/// are missing. See [_AddToEquality] for when it's offered.
class AddInheritedFieldsToEquality extends _AddToEquality {
  static const _kind = FixKind(
    'async_redux_lints.fix.addInheritedFieldsToEquality',
    DartFixKindPriority.standard,
    '{0}',
  );

  AddInheritedFieldsToEquality({required super.context});

  @override
  FixKind get fixKind => _kind;

  @override
  List<EqualityMemberFields> missingMembers(ClassDeclaration node) =>
      missingInheritedEqualityFields(node);
}

/// Adds values to `==` or `hashCode`. Only inserts code, and is only offered when
/// the member has one of these forms:
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
/// To add fields to `==`, the `&&` chain must contain `other is ...`, so that
/// `other` can be used as the class. `Object.hash` accepts at most 20 values, so the
/// fix is not offered if there would be more.
abstract class _AddToEquality extends ResolvedCorrectionProducer with Insertions {
  String _message = '';

  _AddToEquality({required super.context});

  /// Returns the members of [node] that miss some values, as reported by the rule.
  List<EqualityMemberFields> missingMembers(ClassDeclaration node);

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  List<String> get fixArguments => [_message];

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var method = node.thisOrAncestorOfType<MethodDeclaration>();
    var classDeclaration = node.thisOrAncestorOfType<ClassDeclaration>();
    if (method == null || classDeclaration == null) return;

    var member = missingMembers(
      classDeclaration,
    ).where((member) => member.method == method).firstOrNull;
    if (member == null) return;

    // A null name stands for `super`.
    var names = member.superOverrides ? <String?>[null] : member.fieldNames;
    var expression = _returnedExpression(method.body);
    if (expression == null) return;
    var insertion = member.isEquals
        ? _addToEquals(method, expression, names)
        : _addToHashCode(expression, names);
    if (insertion == null) return;

    var memberName = method.name.lexeme;
    _message = member.superOverrides
        ? (member.isEquals
              ? "Add 'super == other' to '=='"
              : "Add 'super.hashCode' to 'hashCode'")
        : "Add ${joinNames(member.fieldNames)} to '$memberName'";
    await insertAll(builder, [insertion]);
  }

  /// Adds `name == other.name`, or `super == other` for a null name, to the `&&`
  /// chain of `==`.
  Insertion? _addToEquals(
    MethodDeclaration method,
    Expression expression,
    List<String?> names,
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
    // `super == other` doesn't need the type check, but a single operand that isn't
    // a type check, like `identical(this, other)`, is not a chain to add to.
    if (!checksType && (names.any((name) => name != null) || operands.length == 1)) {
      return null;
    }

    var other = parameter.name!.lexeme;
    return addOperands(chain, operands.last, '&&', [
      for (var name in names) name == null ? 'super == $other' : '$name == $other.$name',
    ]);
  }

  /// Adds the values to `Object.hash(...)` or `Object.hashAll([...])`, or adds
  /// `name.hashCode` to a `^` chain. A null name stands for `super.hashCode`.
  Insertion? _addToHashCode(Expression expression, List<String?> names) {
    var values = [for (var name in names) name ?? 'super.hashCode'];
    if (expression is MethodInvocation && _isObject(expression.target)) {
      var arguments = expression.argumentList.arguments;
      switch (expression.methodName.name) {
        case 'hash':
          if (arguments.length + values.length > 20) return null;
          return arguments.isEmpty
              ? Insertion(expression.argumentList.leftParenthesis.end, values.join(', '))
              : addAfterLast(
                  arguments.last,
                  expression.argumentList.leftParenthesis,
                  values,
                );
        case 'hashAll':
          var list = arguments.singleOrNull?.argumentExpression;
          if (list is! ListLiteral) return null;
          return list.elements.isEmpty
              ? Insertion(list.leftBracket.end, values.join(', '))
              : addAfterLast(list.elements.last, list.leftBracket, values);
      }
      return null;
    }

    var operands = _caretOperands(expression);
    if (operands.isEmpty) return null;
    return addOperands(expression, operands.last, '^', [
      for (var name in names) name == null ? 'super.hashCode' : '$name.hashCode',
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
