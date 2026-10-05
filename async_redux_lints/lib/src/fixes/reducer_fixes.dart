import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

import '../redux_types.dart';

/// Replaces `return state;` in a reducer with `return null;`. If the declared return
/// type of `reduce` is not nullable, like `AppState` or `Future<AppState>`, also makes
/// it nullable.
class ReturnNull extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'async_redux_lints.fix.returnNull',
    DartFixKindPriority.standard,
    "Return 'null'",
  );

  ReturnNull({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var expression = node;
    if (expression is! Expression || !readsActionGetter(expression, 'state')) return;
    var method = expression.thisOrAncestorOfType<MethodDeclaration>();
    if (method == null) return;

    var nonNullableType = _nonNullableStateType(method.returnType);
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(range.node(expression), 'null');
      if (nonNullableType != null) builder.addSimpleInsertion(nonNullableType.end, '?');
    });
  }

  /// Returns the state type in [returnType], like `AppState` in `Future<AppState>`,
  /// if it's not nullable. Otherwise, returns null.
  static TypeAnnotation? _nonNullableStateType(TypeAnnotation? returnType) {
    if (returnType is! NamedType) return null;
    var stateType = returnType;
    var typeArguments = returnType.typeArguments?.arguments;
    if (returnType.type?.isDartAsyncFuture == true && typeArguments?.length == 1) {
      var argument = typeArguments!.single;
      if (argument is! NamedType) return null;
      stateType = argument;
    }
    var type = stateType.type;
    if (type == null ||
        type is DynamicType ||
        type is TypeParameterType ||
        type.nullabilitySuffix != NullabilitySuffix.none) {
      return null;
    }
    return stateType;
  }
}

/// Replaces a variable that holds the state from before an `await` with `state`.
class UseCurrentState extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'async_redux_lints.fix.useCurrentState',
    DartFixKindPriority.standard,
    "Use 'state' instead",
  );

  UseCurrentState({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var identifier = node;
    if (identifier is! SimpleIdentifier) return;
    var method = identifier.thisOrAncestorOfType<MethodDeclaration>();
    if (method == null) return;

    // A local variable or parameter named `state` hides the `state` getter.
    var finder = _StateDeclarationFinder();
    method.accept(finder);
    var replacement = finder.found ? 'this.state' : 'state';

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(range.node(identifier), replacement);
    });
  }
}

/// Finds a local variable, parameter or local function named `state`.
class _StateDeclarationFinder extends RecursiveAstVisitor<void> {
  bool found = false;

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    if (node.name.lexeme == 'state') found = true;
    super.visitVariableDeclaration(node);
  }

  @override
  void visitFormalParameterList(FormalParameterList node) {
    if (node.parameters.any((p) => p.name?.lexeme == 'state')) found = true;
    super.visitFormalParameterList(node);
  }

  @override
  void visitDeclaredIdentifier(DeclaredIdentifier node) {
    if (node.name.lexeme == 'state') found = true;
    super.visitDeclaredIdentifier(node);
  }

  @override
  void visitDeclaredVariablePattern(DeclaredVariablePattern node) {
    if (node.name.lexeme == 'state') found = true;
    super.visitDeclaredVariablePattern(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (node.name.lexeme == 'state') found = true;
    super.visitFunctionDeclaration(node);
  }
}
