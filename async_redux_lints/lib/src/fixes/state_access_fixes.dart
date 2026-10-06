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

import '../rules/select_outside_build_rule.dart';
import '../widget_types.dart';

/// Replaces `context.state.user.name` with `context.select((st) => st.user.name)`.
/// Also replaces `context.read()` the same way, and `context.getState<St>()` and
/// `context.getRead<St>()` with `context.getSelect<St, R>(...)`.
///
/// Selects the getters that follow `context.state`, as deep as the code uses them.
/// It stops at methods, like `trim()` in `context.state.name.trim()`, and at
/// null-aware accesses, like `?.name` in `context.state.user?.name`.
///
/// For `var state = context.state;`, where the variable is only used through
/// getters, like `state.user.name`, declares one variable per path instead, like
/// `var userName = context.select((st) => st.user.name);`, and replaces each
/// `state.user.name` with `userName`. When a path is a prefix of another, like
/// `state.user` and `state.user.name`, only the shorter one is selected. Each
/// variable is named after its path. If that name is already used, a number is
/// added, starting at 2, like `userName2`.
///
/// Only offered where the widget builds, and in `didChangeDependencies`, since
/// `context.select` throws in callbacks.
class UseContextSelect extends ResolvedCorrectionProducer with _SelectReplacement {
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
    var access = _stateOrReadAccess(node);
    if (access == null) return;
    var target = stateAccessTarget(access);
    if (!canUseSelect(access, target) && !isInDidChangeDependencies(access, target)) {
      return;
    }
    var edits = selectEdits(access);
    if (edits == null) return;
    await builder.addDartFileEdit(file, edits);
  }
}

/// Replaces a `context.state` or `context.read()` access with `context.select`, as
/// described in [UseContextSelect].
mixin _SelectReplacement on ResolvedCorrectionProducer {
  /// Returns a function that adds the edits that replace [access] with
  /// `context.select`, or null if it can't be replaced.
  ///
  /// The `context` of `context.select` is [targetText], or the `context` of [access]
  /// if it's null.
  void Function(DartFileEditBuilder)? selectEdits(
    Expression access, {
    String? targetText,
  }) {
    var isAsyncReduxMethod = _isAsyncReduxMethod(access);
    if (!isAsyncReduxMethod && _extensionMethod(access, 'select') == null) return null;

    var target = stateAccessTarget(access);
    var stateType = access.staticType;
    var usage = _stateUsage(access);
    if (target == null || stateType == null || usage == null) return null;

    targetText ??= utils.getNodeText(target);
    void writeSelect(DartEditBuilder builder, _GetterPath path) {
      builder.write('$targetText.');
      if (isAsyncReduxMethod) {
        // context.getState<AppState>() or context.getRead<AppState>()
        builder.write('getSelect<');
        builder.writeType(stateType);
        builder.write(', ');
        builder.writeType(path.type);
        builder.write('>');
      } else {
        builder.write('select');
      }
      builder.write('((st) => st.${path.names.join('.')})');
    }

    // context.state.user.name
    var statement = usage.statement;
    if (statement == null) {
      var path = usage.paths.single;
      if (path.type == null) return null;
      return (builder) {
        builder.addReplacement(range.node(path.nodes.last), (b) => writeSelect(b, path));
      };
    }

    // var state = context.state;
    var list = statement.variables;
    var variable = list.variables.single;

    // The paths to select, in the order of their first use. A path that has another
    // path as a prefix uses the variable of the shorter one.
    var selected = <_GetterPath>[];
    for (var path in usage.paths) {
      if (path.type == null) return null;
      var hasShorterPrefix = usage.paths.any(
        (other) => other.names.length < path.names.length && other.isPrefixOf(path),
      );
      var isSelected = selected.any((other) => other.isSameAs(path));
      if (!hasShorterPrefix && !isSelected) selected.add(path);
    }

    var names = <_GetterPath, String>{};
    for (var path in selected) {
      var base = path.variableName;
      var name = base;
      for (var i = 2; names.containsValue(name) || _isNameUsed(variable, name); i++) {
        name = '$base$i';
      }
      names[path] = name;
    }

    var keyword = list.keyword?.lexeme;
    var hasType = list.type != null;
    var separator = '${utils.endOfLine}${utils.getLinePrefix(statement.offset)}';

    return (builder) {
      builder.addReplacement(range.node(statement), (builder) {
        var isFirst = true;
        for (var path in selected) {
          if (!isFirst) builder.write(separator);
          isFirst = false;
          if (keyword != null) builder.write('$keyword ');
          if (hasType) {
            builder.writeType(path.type);
            builder.write(' ');
          }
          builder.write('${names[path]} = ');
          writeSelect(builder, path);
          builder.write(';');
        }
      });
      for (var path in usage.paths) {
        var prefix = selected.firstWhere((other) => other.isPrefixOf(path));
        builder.addSimpleReplacement(
          range.node(path.nodes[prefix.names.length - 1]),
          names[prefix]!,
        );
      }
    };
  }

  /// Returns true if a new local variable named [name], declared instead of
  /// [variable], would conflict with another use of [name]. That's when the block
  /// that declares [variable], which is the scope of the new variable, references
  /// something else named [name], or declares something named [name]. So do the
  /// parameters of the function, if the block is its body.
  ///
  /// Property names, like `st.name`, and named arguments, like `name: ...`, are not
  /// conflicts.
  bool _isNameUsed(VariableDeclaration variable, String name) {
    if (variable.name.lexeme == name) return false;
    var block = variable.thisOrAncestorOfType<VariableDeclarationStatement>()?.parent;
    if (block is! Block) return true;

    var function = block.parent?.parent;
    var parameters = switch (function) {
      FunctionExpression() => function.parameters,
      MethodDeclaration() => function.parameters,
      ConstructorDeclaration() => function.parameters,
      _ => null,
    };
    if (block.parent is BlockFunctionBody &&
        (parameters?.parameters.any((p) => p.name?.lexeme == name) ?? false)) {
      return true;
    }

    var finder = _NameUseFinder(name, variable);
    block.accept(finder);
    return finder.isUsed;
  }
}

/// Finds references to [name], and declarations of [name], other than [variable].
class _NameUseFinder extends GeneralizingAstVisitor<void> {
  final String name;
  final VariableDeclaration variable;
  bool isUsed = false;

  _NameUseFinder(this.name, this.variable);

  @override
  void visitNode(AstNode node) {
    if (isUsed) return;
    var declaredName = switch (node) {
      VariableDeclaration() when node != variable => node.name,
      FormalParameter() => node.name,
      FunctionDeclaration() => node.name,
      DeclaredIdentifier() => node.name,
      DeclaredVariablePattern() => node.name,
      CatchClauseParameter() => node.name,
      _ => null,
    };
    if (declaredName?.lexeme == name) {
      isUsed = true;
      return;
    }
    super.visitNode(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name == name && !_isPropertyName(node)) {
      isUsed = true;
    }
  }

  /// Returns true if [node] is the name of a property or method of an object, like
  /// `name` in `st.name`, `st?.name` or `st.name()`.
  bool _isPropertyName(SimpleIdentifier node) => switch (node.parent) {
    PrefixedIdentifier(:var identifier) => identifier == node,
    PropertyAccess(:var propertyName) => propertyName == node,
    MethodInvocation(:var methodName, :var target) =>
      methodName == node && target != null,
    _ => false,
  };
}

/// Replaces `context.state` with `context.read()`, and `context.getState<St>()` with
/// `context.getRead<St>()`.
///
/// Only offered in code that doesn't run while the widget builds, like callbacks and
/// `didChangeDependencies`, but not in `dispose`, where `context.read()` throws too.
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
    if (access == null || enclosingSelector(access) != null) return;
    var notBuildingCode = notBuilding(access);
    if (notBuildingCode == null || notBuildingCode.stateMethod == 'dispose') return;
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

/// Returns the `context.state` or `context.read()` access that contains [node], or
/// null.
Expression? _stateOrReadAccess(AstNode node) =>
    node.thisOrAncestorMatching((node) {
          var access = stateAccessOfNode(node);
          return node is Expression &&
              (access == StateAccess.state || access == StateAccess.read);
        })
        as Expression?;

/// Returns true if [access] is the `context.getState<St>()` or
/// `context.getRead<St>()` of AsyncRedux.
bool _isAsyncReduxMethod(Expression access) {
  if (access is! MethodInvocation) return false;
  var extension = _extensionOf(access.methodName.element);
  return extension != null && isAsyncReduxLibrary(extension.library);
}

/// Returns the method named [name] of the extension that declares the `state` of
/// the `context.state` [access], or the `read` of the `context.read()` [access], or
/// null.
MethodElement? _extensionMethod(Expression access, String name) {
  var element = switch (access) {
    PrefixedIdentifier() => access.identifier.element,
    PropertyAccess() => access.propertyName.element,
    MethodInvocation() => access.methodName.element,
    _ => null,
  };
  return _extensionOf(element)?.getMethod(name);
}

ExtensionElement? _extensionOf(Element? element) {
  var extension = element?.baseElement.enclosingElement;
  return extension is ExtensionElement ? extension : null;
}

/// How a `context.state` access uses the state.
class _StateUsage {
  /// The declaration of the variable that holds the state:
  /// `var state = context.state;`. Null if the state is used directly, like in
  /// `context.state.user.name`.
  final VariableDeclarationStatement? statement;

  /// The getters used after each use of the state, in the order of the uses.
  final List<_GetterPath> paths;

  _StateUsage(this.statement, this.paths);
}

/// The getters used after a use of the state, like `user` and `name` in
/// `state.user.name`.
class _GetterPath {
  /// The names of the getters, like `['user', 'name']`.
  final List<String> names;

  /// The access of each getter, like `state.user` and `state.user.name`.
  final List<Expression> nodes;

  _GetterPath(this.names, this.nodes);

  /// The type of the value of the last getter.
  DartType? get type => nodes.last.staticType;

  /// The name of a variable that holds the value of the last getter, like
  /// `userName` for `state.user.name`.
  String get variableName {
    var words = names
        .map((name) => name.replaceFirst(RegExp(r'^_+'), ''))
        .where((name) => name.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'value';
    return words.first +
        words.skip(1).map((word) => word[0].toUpperCase() + word.substring(1)).join();
  }

  /// Returns true if this path is a prefix of [other], or the same as [other].
  bool isPrefixOf(_GetterPath other) {
    if (names.length > other.names.length) return false;
    for (var i = 0; i < names.length; i++) {
      if (names[i] != other.names[i]) return false;
    }
    return true;
  }

  bool isSameAs(_GetterPath other) =>
      names.length == other.names.length && isPrefixOf(other);
}

/// Returns how the `context.state` [access] uses the state, or null if it uses the
/// state itself, like in `print(state)`, or assigns to a field of the state.
_StateUsage? _stateUsage(Expression access) {
  var parent = access.parent;

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

    var paths = <_GetterPath>[];
    for (var reference in finder.references) {
      var path = _getterPath(reference);
      if (path == null) return null;
      paths.add(path);
    }
    return _StateUsage(statement, paths);
  }

  // context.state.user.name
  var path = _getterPath(access);
  return path == null ? null : _StateUsage(null, [path]);
}

/// Returns the getters used after [state], which is a use of the state, like
/// `user` and `name` in `state.user.name`. They stop at methods, like `trim()` in
/// `state.name.trim()`, and at null-aware accesses, like `?.name` in
/// `state.user?.name`. Returns null if there are none, or if the last one is
/// assigned to, like in `state.user.name = ''`.
_GetterPath? _getterPath(Expression state) {
  var names = <String>[];
  var nodes = <Expression>[];
  var current = state;
  while (true) {
    var parent = current.parent;
    SimpleIdentifier property;
    if (parent is PrefixedIdentifier && parent.prefix == current) {
      property = parent.identifier;
    } else if (parent is PropertyAccess &&
        parent.target == current &&
        parent.operator.type == TokenType.PERIOD) {
      property = parent.propertyName;
    } else {
      break;
    }
    if (property.element?.baseElement is! GetterElement) break;
    names.add(property.name);
    nodes.add(parent as Expression);
    current = parent;
  }
  if (names.isEmpty || _isAssigned(current)) return null;

  // state.user.name = '', where `name` is a setter.
  var next = current.parent;
  if ((next is PrefixedIdentifier || next is PropertyAccess) &&
      _isAssigned(next as Expression)) {
    return null;
  }
  return _GetterPath(names, nodes);
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
///
/// Only offered in callbacks, and in `State` methods other than `dispose`, where
/// `context.read()` throws too.
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
    var kind = selectProblem(invocation)?.kind;
    if (kind != SelectProblemKind.callback && kind != SelectProblemKind.stateMethod) {
      return;
    }

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

/// Fixes a `context.select`, `context.event` or `context.state` in a builder, like
/// `Builder(builder: (inner) => ...)`, whose `context` is the `BuildContext` of
/// another widget, by using the `BuildContext` parameter of the builder instead.
/// Replaces `context.select(...)` with `inner.select(...)`, and `context.state.name`
/// with `inner.select((st) => st.name)`, like [UseContextSelect].
///
/// If that parameter is a wildcard, like in `Builder(builder: (_) => ...)`, renames it
/// to the name of the `context`, like `Builder(builder: (context) => ...)`. Then all
/// the uses of `context` in the builder refer to the builder's `BuildContext`.
///
/// Not offered in the `itemBuilder` of a list, whose `BuildContext` belongs to the
/// list. See [WrapItemInBuilder].
class UseBuilderContext extends ResolvedCorrectionProducer with _SelectReplacement {
  static const _kind = FixKind(
    'async_redux_lints.fix.useBuilderContext',
    DartFixKindPriority.standard,
    '{0}',
  );

  String _message = '';

  UseBuilderContext({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  List<String> get fixArguments => [_message];

  @override
  Future<void> compute(ChangeBuilder builder) async {
    // context.state
    Expression? access = _stateAccess(node);
    var isState = access != null;
    BuildFunction? function;
    if (access != null) {
      function = enclosingBuildFunction(access);
      if (function == null || isContextOf(stateAccessTarget(access), function) != false) {
        return;
      }
    } else {
      // context.select(...) or context.event(...)
      var invocation = node.thisOrAncestorOfType<MethodInvocation>();
      while (invocation != null && selectProblem(invocation) == null) {
        invocation = invocation.parent?.thisOrAncestorOfType<MethodInvocation>();
      }
      if (invocation == null) return;
      if (selectProblem(invocation)?.kind != SelectProblemKind.otherContext) return;
      access = invocation;
      function = enclosingBuildFunction(invocation, throughClosures: true);
    }
    if (function == null || function.isItemBuilder) return;

    var target = stateAccessTarget(access);
    if (target is! SimpleIdentifier) return;
    var closure =
        access.thisOrAncestorMatching(
              (node) => node is FunctionExpression && isBuilder(node),
            )
            as FunctionExpression?;
    var parameter = closure?.parameters?.parameters
        .where((p) => p.declaredFragment?.element == function!.context)
        .firstOrNull;
    var parameterName = parameter?.name;
    if (parameterName == null) return;

    // (_) => ..., becomes (context) => ...
    var isWildcard = RegExp(r'^_+$').hasMatch(parameterName.lexeme);
    var name = isWildcard ? target.name : parameterName.lexeme;

    void Function(DartFileEditBuilder)? selectEdit;
    if (isState) {
      selectEdit = selectEdits(access, targetText: name);
      if (selectEdit == null) return;
    }

    var wildcard = parameterName.lexeme;
    _message = switch ((isWildcard, isState)) {
      (true, true) =>
        "Rename the builder's '$wildcard' to '$name', and use 'context.select'",
      (true, false) => "Rename the builder's '$wildcard' to '$name'",
      (false, true) => "Use 'context.select' with the builder's '$name'",
      (false, false) => "Use the builder's '$name'",
    };

    await builder.addDartFileEdit(file, (builder) {
      if (isWildcard) builder.addSimpleReplacement(range.token(parameterName), name);
      if (selectEdit != null) {
        selectEdit(builder);
      } else if (!isWildcard) {
        builder.addSimpleReplacement(range.node(target), name);
      }
    });
  }
}

/// Wraps the item built by the `itemBuilder` of a list in a `Builder`, so that the
/// `context` of a `context.state`, `context.select` or `context.event` in the item
/// is the item's `BuildContext`, not the list's:
/// `itemBuilder: (context, index) => Builder(builder: (context) => Text(...))`.
/// The `Builder` names its `BuildContext` like the `context` used in the item. For
/// `context.state`, also replaces it with `context.select`, like [UseContextSelect].
///
/// Also offered when the item uses the `context` of the widget that builds the list,
/// like `itemBuilder: (_, index) => Text(context.state.name)`. Then the `Builder`
/// is named after that `context`, so all its uses in the item refer to the
/// `Builder`'s `BuildContext`:
/// `itemBuilder: (_, index) => Builder(builder: (context) => Text(...))`.
///
/// Not offered if the item may be null, like in `index < 3 ? Text('') : null`,
/// since the `builder` of a `Builder` can't return null, if the `itemBuilder` is
/// async, or if its block body doesn't end with a `return`.
class WrapItemInBuilder extends ResolvedCorrectionProducer with _SelectReplacement {
  static const _wrapKind = FixKind(
    'async_redux_lints.fix.wrapItemInBuilder',
    DartFixKindPriority.standard,
    "Wrap the item in a 'Builder'",
  );

  static const _wrapAndSelectKind = FixKind(
    'async_redux_lints.fix.wrapItemInBuilderAndUseSelect',
    DartFixKindPriority.standard,
    "Wrap the item in a 'Builder', and use 'context.select'",
  );

  FixKind _kind = _wrapKind;

  WrapItemInBuilder({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    // context.state
    Expression? access = _stateAccess(node);
    void Function(DartFileEditBuilder)? edits;
    if (access != null) {
      var function = enclosingBuildFunction(access);
      if (function == null ||
          !function.isItemBuilder ||
          isContextOf(stateAccessTarget(access), function) == null) {
        return;
      }
      edits = selectEdits(access);
      if (edits == null) return;
      _kind = _wrapAndSelectKind;
    } else {
      // context.select(...) or context.event(...)
      access =
          node.thisOrAncestorMatching((node) {
                if (node is! MethodInvocation) return false;
                var kind = selectProblem(node)?.kind;
                return kind == SelectProblemKind.itemBuilder ||
                    (kind == SelectProblemKind.otherContext &&
                        enclosingBuildFunction(
                          node,
                          throughClosures: true,
                        )!.isItemBuilder);
              })
              as Expression?;
      if (access == null) return;
      _kind = _wrapKind;
    }

    var itemBuilder =
        access.thisOrAncestorMatching(
              (node) => node is FunctionExpression && isBuilder(node),
            )
            as FunctionExpression?;
    var target = stateAccessTarget(access);
    var contextName = target is SimpleIdentifier ? target.name : null;
    var body = itemBuilder?.body;
    if (contextName == null || body == null || !body.isSynchronous || body.isGenerator) {
      return;
    }

    // (context, index) => Text(...)
    // becomes: (context, index) => Builder(builder: (context) => Text(...))
    // (context, index) { ... }
    // becomes: (context, index) => Builder(builder: (context) { ... })
    int start, end;
    if (body is ExpressionFunctionBody) {
      if (!_isNonNullable(body.expression)) return;
      start = body.functionDefinition.offset;
      end = body.expression.end;
    } else if (body is BlockFunctionBody) {
      var statements = body.block.statements;
      if (statements.lastOrNull is! ReturnStatement) return;
      var finder = _ReturnFinder();
      body.block.accept(finder);
      if (!finder.returns.every((r) => _isNonNullable(r.expression))) return;
      start = body.block.offset;
      end = body.block.end;
    } else {
      return;
    }

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleInsertion(start, '=> Builder(builder: ($contextName) ');
      edits?.call(builder);
      builder.addSimpleInsertion(end, ')');
    });
  }

  bool _isNonNullable(Expression? expression) {
    var type = expression?.staticType;
    return type != null && typeSystem.isNonNullable(type);
  }
}

/// Finds the `return` statements of a function body, but not of the functions
/// declared in it.
class _ReturnFinder extends RecursiveAstVisitor<void> {
  final returns = <ReturnStatement>[];

  @override
  void visitFunctionExpression(FunctionExpression node) {}

  @override
  void visitReturnStatement(ReturnStatement node) {
    returns.add(node);
    super.visitReturnStatement(node);
  }
}

/// Replaces `context.state` and `context.read()` inside a selector, like
/// `context.select((st) => context.state.counter)`, with the parameter of the
/// selector: `context.select((st) => st.counter)`. Not offered if that parameter is
/// a wildcard, like `_`.
class UseSelectorParameter extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'async_redux_lints.fix.useSelectorParameter',
    DartFixKindPriority.standard,
    "Replace with '{0}'",
  );

  String _name = '';

  UseSelectorParameter({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  List<String> get fixArguments => [_name];

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var access =
        node.thisOrAncestorMatching((node) {
              var access = stateAccessOfNode(node);
              return node is Expression &&
                  (access == StateAccess.state || access == StateAccess.read);
            })
            as Expression?;
    if (access == null) return;
    var selector = enclosingSelector(access);
    var name = selector?.parameters?.parameters.firstOrNull?.name?.lexeme;
    if (name == null || name.startsWith('_')) return;

    _name = name;
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(range.node(access), name);
    });
  }
}
