import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

import '../redux_types.dart';

/// Replaces an action with its type. For example, `exceptionFor(MyAction())` becomes
/// `exceptionFor(MyAction)`, and `exceptionFor(action)` becomes
/// `exceptionFor(action.runtimeType)`.
class UseActionType extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'async_redux_lints.fix.useActionType',
    DartFixKindPriority.standard,
    "Replace with '{0}'",
  );

  String _replacement = '';

  UseActionType({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  List<String> get fixArguments => [_replacement];

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var action = _diagnosticExpression();
    if (action == null || !isActionType(action.staticType)) return;

    if (action is InstanceCreationExpression) {
      _replacement = utils.getNodeText(action.constructorName.type);
    } else {
      var text = utils.getNodeText(action);
      var needsParentheses =
          !(action is Identifier ||
              action is PropertyAccess ||
              action is MethodInvocation ||
              action is ParenthesizedExpression);
      _replacement = needsParentheses ? '($text).runtimeType' : '$text.runtimeType';
    }

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(range.node(action), _replacement);
    });
  }

  /// Returns the outermost expression that covers exactly the diagnostic range.
  Expression? _diagnosticExpression() {
    var offset = diagnosticOffset;
    var length = diagnosticLength;
    if (offset == null || length == null) return null;

    Expression? result;
    for (AstNode? node = coveringNode; node != null; node = node.parent) {
      if (node.offset != offset || node.length != length) break;
      if (node is Expression) result = node;
    }
    return result;
  }
}
