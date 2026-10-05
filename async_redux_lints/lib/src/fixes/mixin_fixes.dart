import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

import '../mixin_utils.dart';
import '../rules/polling_action_restarts_polling_rule.dart';

final _asyncReduxUri = Uri.parse('package:async_redux/async_redux.dart');

/// Adds the `NonReentrant` mixin to the action, at the end of its `with` clause, or
/// in a new `with` clause. Imports AsyncRedux if needed.
class AddNonReentrant extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'async_redux_lints.fix.addNonReentrant',
    DartFixKindPriority.standard,
    "Add the 'NonReentrant' mixin",
  );

  AddNonReentrant({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var declaration = node.thisOrAncestorMatching(
      (node) => node is ClassDeclaration || node is ClassTypeAlias,
    );
    var (withClause, extendsEnd) = switch (declaration) {
      ClassDeclaration(:var withClause, :var extendsClause) => (
        withClause,
        extendsClause?.end,
      ),
      ClassTypeAlias(:var withClause) => (withClause, null),
      _ => (null, null),
    };

    int offset;
    String prefix;
    if (withClause != null) {
      (offset, prefix) = (withClause.mixinTypes.last.end, ', ');
    } else if (extendsEnd != null) {
      (offset, prefix) = (extendsEnd, ' with ');
    } else {
      return;
    }

    await builder.addDartFileEdit(file, (builder) {
      builder.addInsertion(offset, (builder) {
        builder.write(prefix);
        builder.writeImportedName([_asyncReduxUri], 'NonReentrant');
      });
    });
  }
}

/// Replaces `await dispatchAndWait(action);` with `dispatch(action);`, and
/// `await dispatchAndWaitAll(actions);` with `dispatchAll(actions);`. Only offered
/// when the result is not used.
class UseDispatchWithoutWaiting extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'async_redux_lints.fix.useDispatchWithoutWaiting',
    DartFixKindPriority.standard,
    "Use '{0}' without waiting",
  );

  static const _replacements = {
    'dispatchAndWait': 'dispatch',
    'dispatchAndWaitAll': 'dispatchAll',
  };

  String _replacement = '';

  UseDispatchWithoutWaiting({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  List<String> get fixArguments => [_replacement];

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var invocation = node.thisOrAncestorMatching(
      (node) =>
          node is InvocationExpression && _replacements.containsKey(invokedName(node)),
    );
    if (invocation is! InvocationExpression) return;
    var replacement = _replacements[invokedName(invocation)];
    var name = _nameNode(invocation);
    if (replacement == null || name == null) return;

    var awaitExpression = invocation.parent;
    if (awaitExpression is! AwaitExpression ||
        awaitExpression.parent is! ExpressionStatement) {
      return;
    }

    _replacement = replacement;
    await builder.addDartFileEdit(file, (builder) {
      builder.addDeletion(range.startStart(awaitExpression, invocation));
      builder.addSimpleReplacement(range.node(name), replacement);
    });
  }

  static SimpleIdentifier? _nameNode(InvocationExpression node) => switch (node) {
    MethodInvocation(:var methodName) => methodName,
    FunctionExpressionInvocation(function: SimpleIdentifier function) => function,
    FunctionExpressionInvocation(function: PropertyAccess function) =>
      function.propertyName,
    FunctionExpressionInvocation(function: PrefixedIdentifier function) =>
      function.identifier,
    _ => null,
  };
}

/// Replaces `Poll.start`, `Poll.stop` or `Poll.runNowAndRestart` with `Poll.once`.
class UsePollOnce extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'async_redux_lints.fix.usePollOnce',
    DartFixKindPriority.standard,
    "Use 'Poll.once'",
  );

  UsePollOnce({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var value = node.thisOrAncestorMatching(
      (node) => node is PrefixedIdentifier || node is PropertyAccess,
    );
    if (value is! Expression || pollValueName(value) == null) return;
    var name = switch (value) {
      PrefixedIdentifier(:var identifier) => identifier,
      PropertyAccess(:var propertyName) => propertyName,
      _ => null,
    };
    if (name == null) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(range.node(name), 'once');
    });
  }
}
