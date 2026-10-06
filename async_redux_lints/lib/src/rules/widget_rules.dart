import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

import '../error_types.dart';
import '../widget_types.dart';
import 'context_access_visitor.dart';

/// Reports a dispatch that runs while the widget builds: directly in a `build` method,
/// or in a builder like `Builder(builder: (context) => ...)`. It dispatches again on
/// every rebuild, and can loop forever when the action changes the state.
///
/// Dispatches in callbacks, like `onPressed: () => ...`, in closures that run later,
/// like `addPostFrameCallback`, and in other closures, like `items.map(...)`, are not
/// reported.
class DispatchInBuildRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'dispatch_in_build',
    "Don't dispatch actions while the widget builds. It dispatches again on every "
        "rebuild.",
    correctionMessage:
        "Try dispatching from a callback like 'onPressed', or from 'initState'.",
    severity: DiagnosticSeverity.WARNING,
  );

  DispatchInBuildRule()
    : super(
        name: 'dispatch_in_build',
        description: "Don't dispatch actions while the widget builds.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    var visitor = _DispatchInBuildVisitor(this);
    registry.addMethodInvocation(this, visitor);
    // Calling a getter of function type, like `VmFactory.dispatch`.
    registry.addFunctionExpressionInvocation(this, visitor);
  }
}

class _DispatchInBuildVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _DispatchInBuildVisitor(this.rule);

  @override
  void visitMethodInvocation(MethodInvocation node) => _check(node);

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) =>
      _check(node);

  void _check(InvocationExpression node) {
    if (dispatchMethodName(node) == null) return;
    if (enclosingSelector(node) != null) return; // Reported by context_in_selector.
    if (isInWidgetBuild(node)) rule.reportAtNode(node);
  }
}

/// Returns true if [node] runs while a widget builds: in a `build` method that gets
/// a `BuildContext`, or the `build` method of a `State`, or in a builder closure. Code
/// in callbacks and in other closures inside them is not considered.
bool isInWidgetBuild(AstNode node) {
  var function = enclosingBuildFunction(node);
  return function != null && (function.context != null || function.isStateBuild);
}

/// Reports `context.read()`, and `context.getRead<St>()`, while the widget builds. The
/// widget then doesn't rebuild when the state changes.
///
/// Not reported inside selectors, which `context_in_selector` reports.
class ContextReadInBuildRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'context_read_in_build',
    "'{0}' doesn't rebuild the widget when the state changes.",
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.WARNING,
  );

  ContextReadInBuildRule()
    : super(
        name: 'context_read_in_build',
        description: "Don't use 'context.read()' while the widget builds.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registerContextAccesses(this, registry, (node, access) {
      if (access != StateAccess.read || enclosingSelector(node) != null) return;
      if (!isInWidgetBuild(node)) return;
      var correction = canUseSelect(node, stateAccessTarget(node))
          ? "Try using 'context.select' instead."
          : "Try using 'context.select', in a 'Builder' or in a separate widget.";
      reportAtNode(node, arguments: ['context.${stateAccessName(node)}', correction]);
    });
  }
}

/// Reports a dispatch in the `onRefresh` callback of a `RefreshIndicator` (or any
/// Flutter widget with `onRefresh`), whose result the callback doesn't return or
/// `await`. The refresh indicator then hides its spinner before the action finishes.
/// `dispatchAll` is always reported, since its result can't be waited for.
///
/// The callback can be a closure, or a tear-off of a method or function declared in
/// the same file, like `onRefresh: _refresh`. Dispatches in nested closures are not
/// reported.
class RefreshIndicatorWithoutWaitRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'refresh_indicator_without_wait',
    "The 'onRefresh' callback doesn't wait for '{0}' to finish, so the spinner "
        "disappears before the data loads.",
    correctionMessage: "Try returning or awaiting '{1}(...)'.",
    severity: DiagnosticSeverity.WARNING,
  );

  RefreshIndicatorWithoutWaitRule()
    : super(
        name: 'refresh_indicator_without_wait',
        description: "The 'onRefresh' callback must wait for the actions it dispatches.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addNamedArgument(this, _RefreshVisitor(this));
  }
}

class _RefreshVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _RefreshVisitor(this.rule);

  @override
  void visitNamedArgument(NamedArgument node) {
    var body = onRefreshBody(node);
    if (body == null) return;
    for (var (invocation, name) in unwaitedDispatches(body)) {
      rule.reportAtNode(invocation, arguments: [name.name, waitingDispatchName(name)]);
    }
  }
}

/// Returns the body of the `onRefresh` callback passed as [argument], or null if
/// [argument] is not the `onRefresh` of a Flutter widget, or the body is not known.
FunctionBody? onRefreshBody(NamedArgument argument) {
  if (argument.name.lexeme != 'onRefresh') return null;
  var arguments = argument.parent;
  var creation = arguments?.parent;
  if (arguments is! ArgumentList || creation is! InstanceCreationExpression) return null;
  var library = creation.constructorName.element?.library;
  if (library == null || !library.uri.toString().startsWith('package:flutter/')) {
    return null;
  }

  var callback = argument.argumentExpression.unParenthesized;
  if (callback is FunctionExpression) return callback.body;

  // onRefresh: _refresh
  var element = switch (callback) {
    SimpleIdentifier() => callback.element,
    PrefixedIdentifier() => callback.identifier.element,
    PropertyAccess() => callback.propertyName.element,
    _ => null,
  };
  if (element is! ExecutableElement) return null;
  var unit = argument.thisOrAncestorOfType<CompilationUnit>();
  if (unit == null) return null;
  var finder = _DeclarationFinder(element.baseElement);
  unit.accept(finder);
  return finder.body;
}

class _DeclarationFinder extends RecursiveAstVisitor<void> {
  final Element element;
  FunctionBody? body;

  _DeclarationFinder(this.element);

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.declaredFragment?.element == element) body = node.body;
    super.visitMethodDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (node.declaredFragment?.element == element) {
      body = node.functionExpression.body;
    }
    super.visitFunctionDeclaration(node);
  }
}

/// Returns the dispatches in [body] that it doesn't wait for, with the identifier of
/// their dispatch method. These are dispatches whose value is discarded, and all the
/// `dispatchAll` calls. Dispatches in nested closures are not included.
List<(InvocationExpression, SimpleIdentifier)> unwaitedDispatches(FunctionBody body) {
  var finder = _DispatchFinder();
  body.accept(finder);
  return [
    for (var (invocation, name) in finder.dispatches)
      if (name.name == 'dispatchAll' || _isDiscarded(invocation)) (invocation, name),
  ];
}

class _DispatchFinder extends RecursiveAstVisitor<void> {
  final dispatches = <(InvocationExpression, SimpleIdentifier)>[];

  @override
  void visitFunctionExpression(FunctionExpression node) {}

  @override
  void visitMethodInvocation(MethodInvocation node) {
    _add(node);
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    _add(node);
    super.visitFunctionExpressionInvocation(node);
  }

  void _add(InvocationExpression node) {
    var name = dispatchMethodName(node);
    // A sync action finishes before `dispatchSync` returns.
    if (name != null && name.name != 'dispatchSync') dispatches.add((node, name));
  }
}

/// Returns true if the value of [expression] is not used, like in
/// `dispatch(action);`.
bool _isDiscarded(Expression expression) {
  AstNode node = expression;
  while (node.parent is ParenthesizedExpression) {
    node = node.parent!;
  }
  return node.parent is ExpressionStatement;
}

/// Returns the dispatch method that waits, for the dispatch method [name]:
/// `dispatchAndWaitAll` for `dispatchAll`, and `dispatchAndWait` for the others.
String waitingDispatchName(SimpleIdentifier name) => switch (name.name) {
  'dispatchAll' || 'dispatchAndWaitAll' => 'dispatchAndWaitAll',
  _ => 'dispatchAndWait',
};

/// Reports `.then(...)` called on the future returned by `dispatchAndWait`. It runs
/// even when the action fails. The docs recommend `thenIfCompletedOk` and
/// `thenIfCompletedFailed`, or checking `status.isCompletedOk`.
class ThenOnDispatchAndWaitRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'then_on_dispatch_and_wait',
    "'then' runs even when the action fails.",
    correctionMessage:
        "Try using 'thenIfCompletedOk' or 'thenIfCompletedFailed', or checking "
        "'status.isCompletedOk'.",
    severity: DiagnosticSeverity.WARNING,
  );

  ThenOnDispatchAndWaitRule()
    : super(
        name: 'then_on_dispatch_and_wait',
        description: "Don't use 'then' on the future returned by 'dispatchAndWait'.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addMethodInvocation(this, _ThenVisitor(this));
  }
}

class _ThenVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _ThenVisitor(this.rule);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (isThenOnDispatchAndWait(node)) rule.reportAtNode(node.methodName);
  }
}

/// Returns true if [node] is like `dispatchAndWait(action).then(...)`.
bool isThenOnDispatchAndWait(MethodInvocation node) {
  if (node.methodName.name != 'then') return false;
  var target = node.realTarget?.unParenthesized;
  return target is InvocationExpression &&
      dispatchMethodName(target)?.name == 'dispatchAndWait';
}

/// Reports a widget or `State` that creates a `Timer`, listens to a `Stream`, or has a
/// field or constructor parameter of type `Stream`, `StreamSubscription` or `Timer`.
/// The docs say to start and stop streams and timers with actions, and keep them in
/// the store props.
class StreamOrTimerInWidgetRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'stream_or_timer_in_widget',
    "Avoid {0} in widgets.",
    correctionMessage:
        "Try starting and stopping streams and timers with actions, and keeping them "
        "in the store props.",
    severity: DiagnosticSeverity.INFO,
  );

  StreamOrTimerInWidgetRule()
    : super(
        name: 'stream_or_timer_in_widget',
        description: "Widgets shouldn't create, hold or listen to streams and timers.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    var visitor = _StreamOrTimerVisitor(this);
    registry.addInstanceCreationExpression(this, visitor);
    registry.addMethodInvocation(this, visitor);
    registry.addFieldDeclaration(this, visitor);
    registry.addConstructorDeclaration(this, visitor);
  }
}

class _StreamOrTimerVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _StreamOrTimerVisitor(this.rule);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!_isAsyncClass(node.constructorName.type.element, 'Timer')) return;
    if (_isInWidget(node)) rule.reportAtNode(node, arguments: ["creating a 'Timer'"]);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    var name = node.methodName.name;
    var target = node.realTarget;
    String? description;
    if (name == 'listen' && _streamTypeName(target?.staticType) == 'Stream') {
      description = "listening to a 'Stream'";
    } else if (name == 'run' &&
        target is Identifier &&
        _isAsyncClass(target.element, 'Timer')) {
      description = "creating a 'Timer'";
    }
    if (description != null && _isInWidget(node)) {
      rule.reportAtNode(node, arguments: [description]);
    }
  }

  // Fields and constructors are checked for the types first, since few of them are
  // streams or timers, and that's faster than checking if they're in a widget.

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    if (node.isStatic) return;
    bool? isInWidget;
    for (var variable in node.fields.variables) {
      var type = variable.declaredFragment?.element.type;
      var name = _streamTypeName(type);
      if (name != null && (isInWidget ??= _isInWidget(node))) {
        rule.reportAtToken(variable.name, arguments: ["a field of type '$name'"]);
      }
    }
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    bool? isInWidget;
    // Field formal parameters, like `this.stream`, are reported with the field.
    for (var parameter
        in node.parameters.parameters.whereType<RegularFormalParameter>()) {
      var name = _streamTypeName(parameter.declaredFragment?.element.type);
      if (name != null && (isInWidget ??= _isInWidget(node))) {
        rule.reportAtNode(
          parameter,
          arguments: ["a constructor parameter of type '$name'"],
        );
      }
    }
  }

  static bool _isInWidget(AstNode node) {
    var interface = enclosingInterface(node);
    return interface != null && (isFlutterWidget(interface) || isFlutterState(interface));
  }
}

/// Returns `Stream`, `StreamSubscription` or `Timer`, if [type] is one of them or a
/// subtype, or null otherwise.
///
/// Called for every field and constructor parameter, so it doesn't create a list of
/// the supertypes.
String? _streamTypeName(DartType? type) {
  if (type is! InterfaceType) return null;
  var element = type.element;
  var name = _streamClassName(element);
  if (name != null) return name;
  for (var supertype in element.allSupertypes) {
    name = _streamClassName(supertype.element);
    if (name != null) return name;
  }
  return null;
}

/// Returns `Stream`, `StreamSubscription` or `Timer`, if [element] is one of them.
String? _streamClassName(InterfaceElement element) => switch (element.name) {
  var name? && ('Stream' || 'StreamSubscription' || 'Timer')
      when element.library.isDartAsync =>
    name,
  _ => null,
};

bool _isAsyncClass(Element? element, String name) =>
    element is InterfaceElement && element.name == name && element.library.isDartAsync;
