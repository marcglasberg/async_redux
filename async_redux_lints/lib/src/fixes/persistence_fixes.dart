import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

import '../rules/persistence_rules.dart';

/// Changes `implements Persistor<St>` to `extends Persistor<St>`. Only offered when
/// the class doesn't extend another class, and the implemented class has an unnamed
/// constructor without required parameters.
class ExtendPersistor extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'async_redux_lints.fix.extendPersistor',
    DartFixKindPriority.standard,
    "Change 'implements' to 'extends'",
  );

  ExtendPersistor({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var declaration = node.thisOrAncestorOfType<ClassDeclaration>();
    if (declaration == null || declaration.extendsClause != null) return;
    var implemented = implementedPersistor(declaration);
    var implementsClause = declaration.implementsClause;
    if (implemented == null || implementsClause == null) return;
    if (!_hasDefaultConstructor(implemented.element)) return;

    var interfaces = implementsClause.interfaces;
    var withClause = declaration.withClause;
    var extendsText = 'extends ${utils.getNodeText(implemented)}';

    await builder.addDartFileEdit(file, (builder) {
      if (interfaces.length == 1 && withClause == null) {
        builder.addSimpleReplacement(
          range.token(implementsClause.implementsKeyword),
          'extends',
        );
      } else if (interfaces.length == 1) {
        builder.addSimpleInsertion(withClause!.offset, '$extendsText ');
        builder.addDeletion(range.endEnd(withClause, implementsClause));
      } else {
        var offset = (withClause ?? implementsClause).offset;
        builder.addSimpleInsertion(offset, '$extendsText ');
        builder.addDeletion(range.nodeInList(interfaces, implemented));
      }
    });
  }

  static bool _hasDefaultConstructor(Element? element) {
    if (element is! ClassElement) return false;
    var constructor = element.unnamedConstructor;
    return constructor != null &&
        !constructor.formalParameters.any((parameter) => parameter.isRequired);
  }
}

/// Replaces `throw error;` in `Persistor.readState` with `addError(error);` and
/// `return null;`. For `rethrow`, adds the error and stack trace of the `catch`
/// clause. Only offered when the `throw` is a statement in a block, in an `async`
/// `readState`.
class AddErrorAndReturnNull extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'async_redux_lints.fix.addErrorAndReturnNull',
    DartFixKindPriority.standard,
    "Replace with 'addError(...)' and 'return null'",
  );

  AddErrorAndReturnNull({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var throwNode = node.thisOrAncestorMatching(
      (node) => node is ThrowExpression || node is RethrowExpression,
    );
    var statement = throwNode?.parent;
    if (statement is! ExpressionStatement || statement.parent is! Block) return;

    var method = statement.thisOrAncestorOfType<MethodDeclaration>();
    var body = method?.body;
    if (body == null || !body.isAsynchronous || body.isGenerator) return;
    if (statement.thisOrAncestorOfType<FunctionBody>() != body) return;

    String arguments;
    if (throwNode is ThrowExpression) {
      arguments = utils.getNodeText(throwNode.expression);
    } else {
      var catchClause = throwNode!.thisOrAncestorOfType<CatchClause>();
      var error = catchClause?.exceptionParameter?.name.lexeme;
      if (error == null || error == '_') return;
      var stackTrace = catchClause!.stackTraceParameter?.name.lexeme;
      arguments = (stackTrace == null || stackTrace == '_')
          ? error
          : '$error, $stackTrace';
    }

    var indent = utils.getLinePrefix(statement.offset);
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        range.node(statement),
        'addError($arguments);${utils.endOfLine}${indent}return null;',
      );
    });
  }
}

/// Adds `await persistor.saveInitialState(state);` after the statement that creates
/// the initial state, when `persistor.readState()` returns null. Changes
/// `state ??= ...;` into an `if (state == null)` block. Only offered when the state
/// is kept in a local variable, and the persistor is a variable.
class AddSaveInitialState extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'async_redux_lints.fix.addSaveInitialState',
    DartFixKindPriority.standard,
    "Add 'await {0}.saveInitialState({1})'",
  );

  AddSaveInitialState({required super.context});

  String _persistor = 'persistor';
  String _state = 'state';

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  List<String> get fixArguments => [_persistor, _state];

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var creation = node;
    if (creation is! Expression) return;
    var assignment = creation.parent;
    if (assignment is! AssignmentExpression || assignment.rightHandSide != creation) {
      return;
    }
    var variable = assignment.leftHandSide;
    if (variable is! SimpleIdentifier || variable.element is! LocalVariableElement) {
      return;
    }
    var statement = assignment.parent;
    if (statement is! ExpressionStatement || statement.parent is! Block) return;
    var body = statement.thisOrAncestorOfType<FunctionBody>();
    if (body == null || !body.isAsynchronous) return;

    var persistor = _persistorOf(creation);
    if (persistor == null) return;
    _persistor = persistor;
    _state = variable.name;

    var eol = utils.endOfLine;
    var indent = utils.getLinePrefix(statement.offset);
    var save = 'await $_persistor.saveInitialState($_state);';

    await builder.addDartFileEdit(file, (builder) {
      if (assignment.operator.type == TokenType.EQ) {
        builder.addSimpleInsertion(statement.end, '$eol$indent$save');
      } else {
        var innerIndent = indent + utils.oneIndent;
        builder.addSimpleReplacement(
          range.node(statement),
          'if ($_state == null) {$eol'
          '$innerIndent$_state = ${utils.getNodeText(creation)};$eol'
          '$innerIndent$save$eol'
          '$indent}',
        );
      }
    });
  }

  /// Returns the name of the persistor whose `readState()` returned the state that
  /// [creation] replaces, or null if it's not a variable.
  static String? _persistorOf(Expression creation) {
    for (
      var body = creation.thisOrAncestorOfType<FunctionBody>();
      body != null;
      body = body.parent?.thisOrAncestorOfType<FunctionBody>()
    ) {
      var finder = _ReadStateFinder(creation);
      body.accept(finder);
      var target = finder.call?.target;
      if (finder.call != null) return target is Identifier ? target.name : null;
    }
    return null;
  }
}

/// Finds the call to `readState()` whose unsaved initial states include [creation].
class _ReadStateFinder extends RecursiveAstVisitor<void> {
  final Expression creation;
  MethodInvocation? call;

  _ReadStateFinder(this.creation);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (call == null && (unsavedInitialStates(node)?.contains(creation) ?? false)) {
      call = node;
    }
    super.visitMethodInvocation(node);
  }
}
