import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

import '../error_types.dart';
import '../widget_types.dart';
import 'context_access_visitor.dart';

/// The extension of AsyncRedux that lets a `StatelessWidget` dispatch without the
/// `context`, like `dispatch(action)` instead of `context.dispatch(action)`.
const _statelessWidgetExtension = 'StatelessWidgetExtensionForProviderAndConnector';

/// The extension of AsyncRedux that lets a `State` dispatch without the `context`.
const _stateExtension = 'StatefulWidgetExtensionForProviderAndConnector';

/// Reports `context.dispatch(action)` in a `StatelessWidget` or a `State`, where
/// `dispatch(action)` also works. Also `dispatchAndWait`, `dispatchAll`,
/// `dispatchAndWaitAll` and `dispatchSync`.
///
/// Only reported when the `context` is a variable, and when removing it calls the
/// dispatch extension of the widget, and not some other `dispatch`, like one declared
/// in the class, in the library, or as a local variable.
///
/// The opposite of [PreferDispatchWithContextRule]. Use only one of them.
class PreferDispatchWithoutContextRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'prefer_dispatch_without_context',
    "The 'context.' isn't needed to call '{0}' in a widget.",
    correctionMessage: "Try removing 'context.'.",
    severity: DiagnosticSeverity.INFO,
  );

  PreferDispatchWithoutContextRule()
    : super(
        name: 'prefer_dispatch_without_context',
        description: "Dispatch from widgets with 'dispatch()', not 'context.dispatch()'.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registerContextAccesses(this, registry, (node, access) {
      if (access != StateAccess.dispatch || node is! MethodInvocation) return;
      var target = node.target;
      var operator = node.operator;
      // Removing `getContext().` would not call `getContext()`, and removing
      // `context?.` would not check for null.
      if (target is! SimpleIdentifier && target is! PrefixedIdentifier) return;
      if (operator == null || operator.type != TokenType.PERIOD) return;
      if (!_canDispatchWithoutContext(node)) return;
      reportAtOffset(
        target!.offset,
        operator.end - target.offset,
        arguments: [node.methodName.name],
      );
    });
  }
}

/// Reports `dispatch(action)` in a `StatelessWidget` or a `State`, which uses the
/// dispatch extension of the widget instead of `context.dispatch(action)`. Also
/// `dispatchAndWait`, `dispatchAll`, `dispatchAndWaitAll` and `dispatchSync`.
///
/// Only reported where `context` is a `BuildContext`: in a `State`, and in a
/// `StatelessWidget` in the `build` method, or in other methods and closures that
/// get a `BuildContext` called `context`.
///
/// The opposite of [PreferDispatchWithoutContextRule]. Use only one of them.
class PreferDispatchWithContextRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'prefer_dispatch_with_context',
    "Use 'context.{0}' to dispatch from a widget.",
    correctionMessage: "Try adding 'context.'.",
    severity: DiagnosticSeverity.INFO,
  );

  PreferDispatchWithContextRule()
    : super(
        name: 'prefer_dispatch_with_context',
        description: "Dispatch from widgets with 'context.dispatch()', not 'dispatch()'.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addMethodInvocation(this, _WithContextVisitor(this));
  }
}

class _WithContextVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _WithContextVisitor(this.rule);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    var target = node.target;
    if (node.isCascaded || (target != null && target is! ThisExpression)) return;
    var name = node.methodName;
    if (!dispatchNames.contains(name.name)) return;
    if (!_isWidgetDispatch(name.element)) return;
    if (!_hasContext(node)) return;
    var offset = (target ?? name).offset;
    rule.reportAtOffset(offset, name.end - offset, arguments: [name.name]);
  }
}

/// Returns true if [element] is a dispatch method of the extensions of AsyncRedux
/// that dispatch without the `context`.
bool _isWidgetDispatch(Element? element) {
  var extension = element?.baseElement.enclosingElement;
  return extension is ExtensionElement &&
      (extension.name == _statelessWidgetExtension ||
          extension.name == _stateExtension) &&
      isAsyncReduxLibrary(extension.library);
}

/// Returns true if [node], like `context.dispatch(action)`, would call the dispatch
/// extension of AsyncRedux without the `context`. That's the case in the instance
/// methods of a `StatelessWidget` or a `State`, when the extension is imported, and
/// no other declaration with the same name, like a method of the class, a top-level
/// function or a local variable, would be called instead.
bool _canDispatchWithoutContext(MethodInvocation node) {
  var method = node.thisOrAncestorOfType<MethodDeclaration>();
  if (method == null || method.isStatic) return false;
  var element = method.declaredFragment?.element.enclosingElement;
  if (element is! InterfaceElement) return false;

  String extensionName;
  if (isFlutterState(element)) {
    extensionName = _stateExtension;
  } else if (isFlutterStatelessWidget(element)) {
    extensionName = _statelessWidgetExtension;
  } else {
    return false;
  }

  var unit = node.thisOrAncestorOfType<CompilationUnit>()?.declaredFragment;
  if (unit == null) return false;
  var isImported = unit.accessibleExtensions.any(
    (extension) =>
        extension.name == extensionName && isAsyncReduxLibrary(extension.library),
  );
  if (!isImported) return false;

  var name = node.methodName.name;
  var library = element.library;
  return element.thisType.lookUpMethod(name, library) == null &&
      element.thisType.lookUpGetter(name, library) == null &&
      element.getMethod(name) == null &&
      element.getGetter(name) == null &&
      unit.scope.lookup(name).getter == null &&
      !declaresLocalName(method, name);
}

/// Returns true if `context` is a `BuildContext` where [node] is: a parameter or a
/// local variable called `context`, or the `context` of a `State`.
///
/// Loop variables, catch parameters and pattern variables called `context` are not
/// considered.
bool _hasContext(AstNode node) {
  AstNode child = node;
  for (var ancestor = node.parent; ancestor != null; ancestor = ancestor.parent) {
    if (ancestor is Block) {
      for (var statement in ancestor.statements) {
        if (statement == child) break;
        if (statement is VariableDeclarationStatement) {
          for (var variable in statement.variables.variables) {
            if (variable.name.lexeme == 'context') {
              return isBuildContext(variable.declaredFragment?.element.type);
            }
          }
        }
        if (statement is FunctionDeclarationStatement &&
            statement.functionDeclaration.name.lexeme == 'context') {
          return false;
        }
      }
    }

    var parameters = switch (ancestor) {
      FunctionExpression() => ancestor.parameters,
      MethodDeclaration() => ancestor.parameters,
      _ => null,
    };
    for (var parameter in parameters?.parameters ?? const <FormalParameter>[]) {
      if (parameter.name?.lexeme == 'context') {
        return isBuildContext(parameter.declaredFragment?.element.type);
      }
    }

    if (ancestor is MethodDeclaration) {
      if (ancestor.isStatic) return false;
      var element = ancestor.declaredFragment?.element.enclosingElement;
      return element is InterfaceElement && isFlutterState(element);
    }
    child = ancestor;
  }
  return false;
}
