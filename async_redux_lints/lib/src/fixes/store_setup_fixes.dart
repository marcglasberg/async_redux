import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

import '../rules/store_setup_rules.dart';

/// Adds `navigatorKey: key` to a `MaterialApp` without one, where `key` is the key
/// passed to `NavigateAction.setNavigatorKey` in the same file.
///
/// Only offered when there's a single key, which is a variable or a getter.
class AddNavigatorKey extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'async_redux_lints.fix.addNavigatorKey',
    DartFixKindPriority.standard,
    "Add 'navigatorKey: {0}'",
  );

  AddNavigatorKey({required super.context});

  String _key = 'navigatorKey';

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  List<String> get fixArguments => [_key];

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var app = node.thisOrAncestorOfType<InstanceCreationExpression>();
    if (app == null || !isFlutterApp(app) || namedArgument(app, 'navigatorKey') != null) {
      return;
    }

    var keys = {
      for (var call in AppSetup.of(unit).setNavigatorKeyCalls)
        if (call.argumentList.arguments.firstOrNull?.argumentExpression.unParenthesized
            case Identifier(:var name))
          name,
    };
    if (keys.length != 1) return;
    _key = keys.single;

    var argumentList = app.argumentList;
    var first = argumentList.arguments.firstOrNull;
    await builder.addDartFileEdit(file, (builder) {
      if (first == null) {
        builder.addSimpleInsertion(
          argumentList.leftParenthesis.end,
          'navigatorKey: $_key',
        );
      } else if (line(first.offset) != line(argumentList.leftParenthesis.offset)) {
        // Each argument is in its own line.
        builder.addSimpleInsertion(
          first.offset,
          'navigatorKey: $_key,${utils.endOfLine}${utils.getLinePrefix(first.offset)}',
        );
      } else {
        builder.addSimpleInsertion(first.offset, 'navigatorKey: $_key, ');
      }
    });
  }

  int line(int offset) => unitResult.lineInfo.getLocation(offset).lineNumber;
}
