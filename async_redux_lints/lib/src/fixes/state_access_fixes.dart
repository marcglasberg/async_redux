import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/precedence.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_dart.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

import '../rules/context_state_for_one_field_rule.dart';
import '../widget_types.dart';

/// Replaces `context.state.field` with `context.select((st) => st.field)`.
///
/// For `var state = context.state;`, where the variable is only used as
/// `state.field`, replaces it with `var field = context.select((st) => st.field);`,
/// and each `state.field` with `field`. Not offered if the name `field` is already
/// used in the enclosing method.
class UseContextSelect extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'async_redux_lints.fix.useContextSelect',
    DartFixKindPriority.standard,
    "Replace with 'context.select'",
  );

  UseContextSelect({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var access =
        node.thisOrAncestorMatching(
              (node) =>
                  node is Expression && stateAccessOfNode(node) == StateAccess.state,
            )
            as Expression?;
    if (access == null) return;

    var target = stateAccessTarget(access);
    var stateType = access.staticType;
    var usage = singleFieldUsage(access);
    if (target == null || stateType == null || usage == null) return;

    var fieldName = usage.fieldName;
    var fieldAccess = usage.propertyAccess ?? usage.variableAccesses.first;
    var fieldType = fieldAccess.staticType;
    if (fieldType == null) return;

    var targetText = utils.getNodeText(target);
    void writeSelect(DartEditBuilder builder) {
      builder.write('$targetText.');
      if (access is MethodInvocation) {
        // context.getState<AppState>()
        builder.write('getSelect<');
        builder.writeType(stateType);
        builder.write(', ');
        builder.writeType(fieldType);
        builder.write('>');
      } else {
        builder.write('select');
      }
      builder.write('((st) => st.$fieldName)');
    }

    var propertyAccess = usage.propertyAccess;
    if (propertyAccess != null) {
      await builder.addDartFileEdit(file, (builder) {
        builder.addReplacement(range.node(propertyAccess), writeSelect);
      });
      return;
    }

    var variable = usage.variable!;
    var list = variable.parent;
    if (list is! VariableDeclarationList || list.variables.length != 1) return;
    if (_isNameUsed(variable, fieldName, usage.variableAccesses)) return;

    await builder.addDartFileEdit(file, (builder) {
      var type = list.type;
      if (type != null) {
        builder.addReplacement(
          range.node(type),
          (builder) => builder.writeType(fieldType),
        );
      }
      if (variable.name.lexeme != fieldName) {
        builder.addSimpleReplacement(range.token(variable.name), fieldName);
      }
      builder.addReplacement(range.node(access), writeSelect);
      for (var variableAccess in usage.variableAccesses) {
        builder.addSimpleReplacement(range.node(variableAccess), fieldName);
      }
    });
  }

  /// Returns true if [name] is used in the method or function that declares
  /// [variable], other than as the field name of the [variableAccesses].
  bool _isNameUsed(
    VariableDeclaration variable,
    String name,
    List<PrefixedIdentifier> variableAccesses,
  ) {
    if (variable.name.lexeme == name) return false;
    AstNode scope =
        variable.thisOrAncestorOfType<ClassMember>() ??
        variable.thisOrAncestorOfType<CompilationUnitMember>() ??
        variable.root;
    var replaced = {for (var access in variableAccesses) access.identifier.token};
    var end = scope.endToken.next;
    for (
      Token? token = scope.beginToken;
      token != null && token != end;
      token = token.next
    ) {
      if (token.lexeme == name && !replaced.contains(token)) return true;
    }
    return false;
  }
}

/// Replaces `context.select((st) => st.field)` with `context.read().field`, and
/// `context.select(selector)` with `selector(context.read())`.
///
/// For `context.getSelect(...)`, uses `context.getRead<St>()`. For `context.select`,
/// not offered if the extension that declares `select` doesn't declare `read`.
class ReplaceSelectWithRead extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'async_redux_lints.fix.replaceSelectWithRead',
    DartFixKindPriority.standard,
    "Replace with '{0}'",
  );

  String _readName = 'read';

  ReplaceSelectWithRead({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  List<String> get fixArguments => ['context.$_readName()'];

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var invocation =
        node.thisOrAncestorMatching(
              (node) =>
                  node is MethodInvocation &&
                  stateAccessOfNode(node) == StateAccess.select,
            )
            as MethodInvocation?;
    if (invocation == null) return;

    var target = invocation.target;
    var element = invocation.methodName.element?.baseElement;
    var extension = element?.enclosingElement;
    if (target == null || extension is! ExtensionElement) return;

    String readCall;
    if (isAsyncReduxLibrary(extension.library)) {
      // context.getSelect<AppState, int>((st) => st.counter)
      var stateType = invocation.typeArgumentTypes?.firstOrNull;
      if (stateType == null || stateType is DynamicType) return;
      var typeArguments = invocation.typeArguments?.arguments;
      var stateTypeText = (typeArguments != null && typeArguments.isNotEmpty)
          ? utils.getNodeText(typeArguments.first)
          : stateType.getDisplayString();
      _readName = 'getRead';
      readCall = '${utils.getNodeText(target)}.getRead<$stateTypeText>()';
    } else {
      var read = extension.getMethod('read');
      if (read == null || read.formalParameters.any((p) => p.isRequired)) return;
      _readName = 'read';
      readCall = '${utils.getNodeText(target)}.read()';
    }

    var selector = invocation.argumentList.arguments.firstOrNull;
    String replacement;
    if (selector is FunctionExpression) {
      var body = selector.body;
      var parameters = selector.parameters?.parameters;
      if (body is! ExpressionFunctionBody ||
          selector.typeParameters != null ||
          parameters == null ||
          parameters.length != 1) {
        return;
      }
      var parameter = parameters.first.declaredFragment?.element;
      if (parameter == null) return;

      replacement = _replaceReferences(body.expression, parameter, readCall);
      if (body.expression.precedence < Precedence.postfix &&
          _needsParentheses(invocation)) {
        replacement = '($replacement)';
      }
    } else if (selector is Identifier || selector is PropertyAccess) {
      replacement = '${utils.getNodeText(selector!)}($readCall)';
    } else {
      return;
    }

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(range.node(invocation), replacement);
    });
  }

  /// Returns the text of [expression], with each reference to [parameter] replaced
  /// with [readCall].
  String _replaceReferences(
    Expression expression,
    FormalParameterElement parameter,
    String readCall,
  ) {
    var finder = _ParameterReferenceFinder(parameter);
    expression.accept(finder);

    var text = utils.getNodeText(expression);
    for (var reference in finder.references.reversed) {
      // '$st' must become '${context.read()}'.
      var parent = reference.parent;
      var (
        AstNode replaced,
        String replacement,
      ) = (parent is InterpolationExpression && parent.rightBracket == null)
          ? (parent, '\${$readCall}')
          : (reference, readCall);
      var start = replaced.offset - expression.offset;
      text = text.replaceRange(start, start + replaced.length, replacement);
    }
    return text;
  }

  bool _needsParentheses(MethodInvocation invocation) {
    var parent = invocation.parent;
    return parent is Expression &&
        parent is! ParenthesizedExpression &&
        !(parent is AssignmentExpression && parent.rightHandSide == invocation);
  }
}

class _ParameterReferenceFinder extends RecursiveAstVisitor<void> {
  final FormalParameterElement parameter;
  final references = <SimpleIdentifier>[];

  _ParameterReferenceFinder(this.parameter);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.element == parameter) references.add(node);
  }
}
