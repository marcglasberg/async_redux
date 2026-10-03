import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

import '../redux_types.dart';

/// Changes the return type of `reduce` or `before` to a sync type: `St?` or `void`.
/// Not offered when the method body is `async`.
class ChangeToSyncReturnType extends _ChangeReturnType {
  static const _kind = FixKind(
    'async_redux_lints.fix.changeToSyncReturnType',
    DartFixKindPriority.standard,
    "Change the return type to '{0}'",
  );

  ChangeToSyncReturnType({required super.context}) : super(async: false);

  @override
  FixKind get fixKind => _kind;
}

/// Changes the return type of `reduce`, `before` or `wrapReduce` to a `Future`,
/// adding `async` to the method body if needed.
class ChangeToAsyncReturnType extends _ChangeReturnType {
  static const _kind = FixKind(
    'async_redux_lints.fix.changeToAsyncReturnType',
    DartFixKindPriority.standard,
    "Change the return type to '{0}'",
  );

  ChangeToAsyncReturnType({required super.context}) : super(async: true);

  @override
  FixKind get fixKind => _kind;
}

abstract class _ChangeReturnType extends ResolvedCorrectionProducer {
  final bool async;

  String _typeDisplay = '';

  _ChangeReturnType({required super.context, required this.async});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  List<String> get fixArguments => [_typeDisplay];

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var method = node.thisOrAncestorOfType<MethodDeclaration>();
    if (method == null) return;

    var body = method.body;
    var bodyIsAsync = body.isAsynchronous;
    if (body.isGenerator) return;
    if (!async && bodyIsAsync) return;

    var newType = _newReturnType(method);
    if (newType == null) return;
    _typeDisplay = newType.getDisplayString();

    await builder.addDartFileEdit(file, (builder) {
      var returnType = method.returnType;
      if (returnType != null) {
        builder.addReplacement(range.node(returnType), (builder) {
          builder.writeType(newType);
        });
      } else {
        builder.addInsertion(method.name.offset, (builder) {
          builder.writeType(newType);
          builder.write(' ');
        });
      }
      if (async && !bodyIsAsync) {
        builder.addSimpleInsertion(body.offset, 'async ');
      }
    });
  }

  /// Returns the new return type, or null if this fix doesn't apply.
  DartType? _newReturnType(MethodDeclaration method) {
    var element = method.declaredFragment?.element;
    if (element == null) return null;

    DartType valueType;
    switch (method.name.lexeme) {
      case 'before':
        valueType = typeProvider.voidType;
      case 'reduce':
        valueType = futureValueType(element.returnType) ?? _nullableStateType(element);
      case 'wrapReduce':
        if (!async) return null;
        valueType = futureValueType(element.returnType) ?? _nullableStateType(element);
      default:
        return null;
    }

    return async ? typeProvider.futureType(valueType) : valueType;
  }

  /// Returns `St?`, for a method of an action of type `ReduxAction<St>`.
  /// It's the value type of `FutureOr<St?>`, the return type of `ReduxAction.reduce`.
  DartType _nullableStateType(ExecutableElement element) {
    var enclosing = element.enclosingElement;
    var actionType = (enclosing is InterfaceElement)
        ? reduxActionSupertype(enclosing)
        : null;
    var reduceType = actionType?.getMethod('reduce')?.returnType;
    return (reduceType == null ? null : futureValueType(reduceType)) ??
        typeProvider.dynamicType;
  }
}
