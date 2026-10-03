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

import '../widget_types.dart';

/// Replaces `context.state.field` with `context.select((st) => st.field)`.
///
/// For `var state = context.state;`, where the variable is only used as
/// `state.field`, declares one variable per field instead, like
/// `var field = context.select((st) => st.field);`, and replaces each `state.field`
/// with `field`. Not offered if one of these names is already used in the enclosing
/// method.
///
/// Only offered where the widget builds, since `context.select` throws in callbacks.
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
    var access = _stateAccess(node);
    if (access == null || !runsWhileBuilding(access)) return;
    if (!_isAsyncReduxGetState(access) && _extensionMethod(access, 'select') == null) {
      return;
    }

    var target = stateAccessTarget(access);
    var stateType = access.staticType;
    var usage = _fieldUsage(access);
    if (target == null || stateType == null || usage == null) return;

    var targetText = utils.getNodeText(target);
    void writeSelect(DartEditBuilder builder, String fieldName, DartType fieldType) {
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
      var fieldType = propertyAccess.staticType;
      if (fieldType == null) return;
      await builder.addDartFileEdit(file, (builder) {
        builder.addReplacement(
          range.node(propertyAccess),
          (builder) => writeSelect(builder, propertyAccess.propertyName.name, fieldType),
        );
      });
      return;
    }

    var statement = usage.statement!;
    var list = statement.variables;
    var variable = list.variables.single;

    // The type of each field, in the order of their first use.
    var fieldTypes = <String, DartType>{};
    for (var variableAccess in usage.variableAccesses) {
      var fieldType = variableAccess.staticType;
      if (fieldType == null) return;
      fieldTypes.putIfAbsent(variableAccess.identifier.name, () => fieldType);
    }
    for (var fieldName in fieldTypes.keys) {
      if (_isNameUsed(variable, fieldName, usage.variableAccesses)) return;
    }

    var keyword = list.keyword?.lexeme;
    var hasType = list.type != null;
    var separator = '${utils.endOfLine}${utils.getLinePrefix(statement.offset)}';

    await builder.addDartFileEdit(file, (builder) {
      builder.addReplacement(range.node(statement), (builder) {
        var isFirst = true;
        for (var MapEntry(key: fieldName, value: fieldType) in fieldTypes.entries) {
          if (!isFirst) builder.write(separator);
          isFirst = false;
          if (keyword != null) builder.write('$keyword ');
          if (hasType) {
            builder.writeType(fieldType);
            builder.write(' ');
          }
          builder.write('$fieldName = ');
          writeSelect(builder, fieldName, fieldType);
          builder.write(';');
        }
      });
      for (var variableAccess in usage.variableAccesses) {
        builder.addSimpleReplacement(
          range.node(variableAccess),
          variableAccess.identifier.name,
        );
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

/// Replaces `context.state` with `context.read()`, and `context.getState<St>()` with
/// `context.getRead<St>()`.
///
/// Only offered in code that doesn't run while the widget builds, like callbacks.
/// For `context.state`, not offered if the extension that declares `state` doesn't
/// declare `read`.
class UseContextRead extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'async_redux_lints.fix.useContextRead',
    DartFixKindPriority.standard,
    "Replace with '{0}'",
  );

  String _readName = 'read';

  UseContextRead({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  List<String> get fixArguments => ['context.$_readName()'];

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var access = _stateAccess(node);
    if (access == null || notBuildingDescription(access) == null) return;
    var target = stateAccessTarget(access);
    if (target == null) return;

    String replacement;
    if (access is MethodInvocation) {
      // context.getState<AppState>()
      var stateType = access.staticType;
      if (stateType == null || stateType is DynamicType) return;
      var typeArguments = access.typeArguments;
      var typeArgumentsText = typeArguments != null
          ? utils.getNodeText(typeArguments)
          : '<${stateType.getDisplayString()}>';
      _readName = 'getRead';
      replacement = '${utils.getNodeText(target)}.getRead$typeArgumentsText()';
    } else {
      var read = _extensionMethod(access, 'read');
      if (read == null || read.formalParameters.any((p) => p.isRequired)) return;
      _readName = 'read';
      replacement = '${utils.getNodeText(target)}.read()';
    }

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(range.node(access), replacement);
    });
  }
}

/// Returns the `context.state` access that contains [node], or null.
Expression? _stateAccess(AstNode node) =>
    node.thisOrAncestorMatching(
          (node) => node is Expression && stateAccessOfNode(node) == StateAccess.state,
        )
        as Expression?;

/// Returns true if [access] is the `context.getState<St>()` of AsyncRedux.
bool _isAsyncReduxGetState(Expression access) {
  if (access is! MethodInvocation) return false;
  var extension = _extensionOf(access.methodName.element);
  return extension != null && isAsyncReduxLibrary(extension.library);
}

/// Returns the method named [name] of the extension that declares the `state` of
/// the `context.state` [access], or null.
MethodElement? _extensionMethod(Expression access, String name) {
  var element = switch (access) {
    PrefixedIdentifier() => access.identifier.element,
    PropertyAccess() => access.propertyName.element,
    _ => null,
  };
  return _extensionOf(element)?.getMethod(name);
}

ExtensionElement? _extensionOf(Element? element) {
  var extension = element?.baseElement.enclosingElement;
  return extension is ExtensionElement ? extension : null;
}

/// How a `context.state` access uses the fields of the state.
class _FieldUsage {
  /// The access of a field: `context.state.field`.
  /// Null if the state is assigned to a variable.
  final PropertyAccess? propertyAccess;

  /// The declaration of the variable that holds the state:
  /// `var state = context.state;`. Null if a field is accessed directly.
  final VariableDeclarationStatement? statement;

  /// The accesses of the fields through the variable: `state.field`.
  final List<PrefixedIdentifier> variableAccesses;

  _FieldUsage.direct(PropertyAccess this.propertyAccess)
    : statement = null,
      variableAccesses = const [];

  _FieldUsage.variable(VariableDeclarationStatement this.statement, this.variableAccesses)
    : propertyAccess = null;
}

/// Returns how the `context.state` [access] uses the fields of the state, or null
/// if it uses the state itself, or assigns to its fields.
_FieldUsage? _fieldUsage(Expression access) {
  var parent = access.parent;

  // context.state.field
  if (parent is PropertyAccess && parent.target == access) {
    if (parent.operator.type != TokenType.PERIOD) return null;
    if (parent.propertyName.element?.baseElement is! GetterElement) return null;
    if (_isAssigned(parent)) return null;
    return _FieldUsage.direct(parent);
  }

  // var state = context.state;
  if (parent is VariableDeclaration && parent.initializer == access) {
    var list = parent.parent;
    var statement = list?.parent;
    if (list is! VariableDeclarationList ||
        list.variables.length != 1 ||
        list.isLate ||
        statement is! VariableDeclarationStatement) {
      return null;
    }
    var variable = parent.declaredFragment?.element;
    if (variable is! LocalVariableElement) return null;
    var function = parent.thisOrAncestorOfType<FunctionBody>();
    if (function == null) return null;

    var finder = _ReferenceFinder(variable);
    function.accept(finder);
    if (finder.references.isEmpty) return null;

    var variableAccesses = <PrefixedIdentifier>[];
    for (var reference in finder.references) {
      var referenceParent = reference.parent;
      if (referenceParent is! PrefixedIdentifier || referenceParent.prefix != reference) {
        return null;
      }
      if (referenceParent.identifier.element?.baseElement is! GetterElement) return null;
      if (_isAssigned(referenceParent)) return null;
      variableAccesses.add(referenceParent);
    }
    return _FieldUsage.variable(statement, variableAccesses);
  }

  return null;
}

bool _isAssigned(Expression node) {
  var parent = node.parent;
  return (parent is AssignmentExpression && parent.leftHandSide == node) ||
      (parent is PrefixExpression && parent.operator.type.isIncrementOperator) ||
      (parent is PostfixExpression && parent.operator.type.isIncrementOperator);
}

class _ReferenceFinder extends RecursiveAstVisitor<void> {
  final LocalVariableElement variable;
  final references = <SimpleIdentifier>[];

  _ReferenceFinder(this.variable);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.element == variable) references.add(node);
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
