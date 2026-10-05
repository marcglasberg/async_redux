import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

import '../error_types.dart';
import '../rules/user_exception_rules.dart';
import '../widget_types.dart';

/// Replaces `throw UserException(...)` with `dispatch(UserExceptionAction(...))`, or
/// with `context.dispatch(UserExceptionAction(...))` in widgets.
///
/// Only offered when the `throw` is a statement, or the body of an arrow function,
/// where its value is not used.
class DispatchUserExceptionAction extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'async_redux_lints.fix.dispatchUserExceptionAction',
    DartFixKindPriority.standard,
    "Dispatch a 'UserExceptionAction' instead",
  );

  DispatchUserExceptionAction({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var throwExpression = node.thisOrAncestorOfType<ThrowExpression>();
    if (throwExpression == null) return;
    var parent = throwExpression.parent;
    if (parent is! ExpressionStatement && parent is! ExpressionFunctionBody) return;

    var place = userExceptionPlace(throwExpression);
    var dispatch = switch (place) {
      UserExceptionPlace.after || UserExceptionPlace.vmFactory => 'dispatch',
      UserExceptionPlace.widget || UserExceptionPlace.state => _contextDispatch(
        throwExpression,
        isState: place == UserExceptionPlace.state,
      ),
      _ => null,
    };
    if (dispatch == null) return;

    var exception = throwExpression.expression;
    var action =
        (exception is InstanceCreationExpression &&
            isUserExceptionClass(exception.constructorName.type.element))
        // UserExceptionAction has the same parameters as UserException.
        ? 'UserExceptionAction${utils.getNodeText(exception.argumentList)}'
        : 'UserExceptionAction.from(${utils.getNodeText(exception)})';

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(range.node(throwExpression), '$dispatch($action)');
    });
  }

  /// Returns `context.dispatch`, using the `BuildContext` available where [node] is,
  /// or null if there's none.
  static String? _contextDispatch(AstNode node, {required bool isState}) {
    for (var ancestor = node.parent; ancestor != null; ancestor = ancestor.parent) {
      var parameters = switch (ancestor) {
        FunctionExpression() => ancestor.parameters,
        MethodDeclaration() => ancestor.parameters,
        _ => null,
      };
      var context = parameters?.parameters
          .where((parameter) => isBuildContext(parameter.declaredFragment?.element.type))
          .map((parameter) => parameter.name?.lexeme)
          .where((name) => name != null && name != '_')
          .firstOrNull;
      if (context != null) return '$context.dispatch';
      if (ancestor is MethodDeclaration) break;
    }
    // The `State` has a `context` getter.
    return isState ? 'context.dispatch' : null;
  }
}

/// Adds `.addCause(error)` to a `UserException` that replaces another error. In a
/// `catch` clause without an exception parameter, like `on FormatException { ... }`,
/// also adds one.
class AddCause extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'async_redux_lints.fix.addCause',
    DartFixKindPriority.standard,
    "Add '.addCause({0})'",
  );

  AddCause({required super.context});

  String _cause = 'error';

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  List<String> get fixArguments => [_cause];

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var creation = node.thisOrAncestorOfType<InstanceCreationExpression>();
    if (creation == null) return;
    var replacement = userExceptionWithoutCause(creation);
    if (replacement == null) return;

    var cause = replacement.cause;
    var catchClause = replacement.catchClause;
    var addCatchParameter = false;
    if (cause == null) {
      // Adds `catch (error)` to `on FormatException { ... }`.
      if (catchClause == null || catchClause.exceptionType == null) return;
      cause = [
        'error',
        'e',
        'cause',
      ].firstWhere((name) => !usesName(catchClause.body, name), orElse: () => '');
      if (cause.isEmpty) return;
      addCatchParameter = true;
    }
    _cause = cause;

    await builder.addDartFileEdit(file, (builder) {
      if (addCatchParameter) {
        builder.addSimpleInsertion(catchClause!.exceptionType!.end, ' catch ($cause)');
      }
      builder.addSimpleInsertion(creation.end, '.addCause($cause)');
    });
  }
}

/// Changes `throw error;` to `return error;`, and `=> throw error` to `=> error`.
class ReturnInsteadOfThrow extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'async_redux_lints.fix.returnInsteadOfThrow',
    DartFixKindPriority.standard,
    "Change 'throw' to 'return'",
  );

  ReturnInsteadOfThrow({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var throwExpression = node.thisOrAncestorOfType<ThrowExpression>();
    if (throwExpression == null) return;
    var parent = throwExpression.parent;
    var replacement = switch (parent) {
      ExpressionStatement() => 'return ',
      ExpressionFunctionBody() => '',
      _ => null,
    };
    if (replacement == null) return;

    var throwKeyword = SourceRange(
      throwExpression.offset,
      throwExpression.expression.offset - throwExpression.offset,
    );
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(throwKeyword, replacement);
    });
  }
}
