import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:analyzer/error/error.dart';

import '../error_types.dart';
import '../package_files.dart';
import '../redux_types.dart';
import '../widget_types.dart';

/// Reports `throw UserException(...)` where AsyncRedux can't catch it to show it to
/// the user: in a widget, in a `State`, in a `VmFactory`, in a view-model, or in the
/// `after` method of an action. A `UserException` only shows a dialog when thrown
/// from `before` or `reduce`.
class UserExceptionOutsideActionRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'user_exception_outside_action',
    "A 'UserException' thrown in {0} is not shown to the user. It's only shown when "
        "thrown from the 'before' or 'reduce' methods of an action.",
    correctionMessage: "Try dispatching a 'UserExceptionAction' instead.",
    severity: DiagnosticSeverity.WARNING,
  );

  UserExceptionOutsideActionRule()
    : super(
        name: 'user_exception_outside_action',
        description:
            "Throw a 'UserException' only from the 'before' and 'reduce' methods of an "
            "action.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addThrowExpression(this, _OutsideActionVisitor(this, context.typeSystem));
  }
}

/// Where a `UserException` is thrown, outside of `before` and `reduce`.
enum UserExceptionPlace {
  widget('a widget'),
  state("a 'State'"),
  vmFactory("a 'VmFactory'"),
  vm('a view-model'),
  after("the 'after' method of an action");

  final String description;

  const UserExceptionPlace(this.description);
}

/// Returns where [node], which throws a `UserException`, is, or null if it may be
/// thrown from the `before` or `reduce` methods of an action.
UserExceptionPlace? userExceptionPlace(ThrowExpression node) {
  var interface = enclosingInterface(node);
  if (interface == null) return null;
  if (reduxActionSupertype(interface) != null) {
    // Throws inside closures are not reported, since they may run elsewhere, if at all.
    var method = enclosingMethodOutsideClosures(node);
    return (method != null && method.name.lexeme == 'after')
        ? UserExceptionPlace.after
        : null;
  }
  if (isFlutterState(interface)) return UserExceptionPlace.state;
  if (isFlutterWidget(interface)) return UserExceptionPlace.widget;
  if (isVmFactorySubclass(interface)) return UserExceptionPlace.vmFactory;
  if (isVmSubclass(interface)) return UserExceptionPlace.vm;
  return null;
}

class _OutsideActionVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final TypeSystem typeSystem;

  _OutsideActionVisitor(this.rule, this.typeSystem);

  @override
  void visitThrowExpression(ThrowExpression node) {
    var type = node.expression.staticType;
    if (!isUserExceptionType(type)) return;
    var place = userExceptionPlace(node);
    if (place == null || isCaughtLocally(node, type, typeSystem)) return;
    rule.reportAtNode(node, arguments: [place.description]);
  }
}

/// Reports a `UserException` created inside a `catch` clause, or in `wrapError` or
/// `GlobalErrorObserver.observe`, that doesn't keep the original error with
/// `.addCause(error)`. The docs always add the cause, so that no information is lost.
///
/// Not reported when the `UserException` is created inside a closure, or when the
/// `catch` clause or method calls `addCause` somewhere else, like
/// `var exception = UserException('...'); throw exception.addCause(error);`.
class UserExceptionWithoutCauseRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'user_exception_without_cause',
    "This 'UserException' doesn't keep the original error.",
    correctionMessage: "Try adding the original error with '.addCause({0})'.",
    severity: DiagnosticSeverity.INFO,
  );

  UserExceptionWithoutCauseRule()
    : super(
        name: 'user_exception_without_cause',
        description:
            "A 'UserException' that replaces another error should keep it, with "
            "'.addCause(error)'.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    if (isTestLibrary(context)) return;
    registry.addInstanceCreationExpression(this, _WithoutCauseVisitor(this));
  }
}

/// The code that replaces an error, and the original error.
class ErrorReplacement {
  /// The `catch` clause, `wrapError` or `observe` method.
  final AstNode node;

  /// The `catch` clause, if [node] is one.
  final CatchClause? catchClause;

  /// The expression to pass to `addCause`, like `error`, or null if the error is not
  /// available, like in `on FormatException { ... }`, or in `wrapError(_, __)`.
  final String? cause;

  ErrorReplacement._(this.node, this.cause, {this.catchClause});
}

/// Returns the code that replaces an error, if [creation] creates a `UserException`
/// inside it, without keeping that error. Otherwise, returns null.
ErrorReplacement? userExceptionWithoutCause(InstanceCreationExpression creation) {
  if (!isUserExceptionClass(creation.constructorName.type.element)) return null;
  var replacement = _errorReplacement(creation);
  if (replacement == null) return null;
  if (_isCauseOfAnotherException(creation) || _addsCause(creation)) return null;
  if (_callsAddCause(replacement.node)) return null;
  return replacement;
}

ErrorReplacement? _errorReplacement(AstNode node) {
  for (
    AstNode? child = node, ancestor = node.parent;
    ancestor != null;
    child = ancestor, ancestor = ancestor.parent
  ) {
    switch (ancestor) {
      case CatchClause():
        if (ancestor.body != child) return null;
        return ErrorReplacement._(
          ancestor,
          ancestor.exceptionParameter?.name.lexeme,
          catchClause: ancestor,
        );
      case MethodDeclaration():
        return _methodReplacement(ancestor);
      case FunctionExpression():
      case FunctionDeclaration():
      case CompilationUnit():
        return null;
    }
  }
  return null;
}

/// Returns the [ErrorReplacement] of [method], if it's the `wrapError` method of an
/// action or persistor, or the `observe` method of a `GlobalErrorObserver`.
ErrorReplacement? _methodReplacement(MethodDeclaration method) {
  if (method.isStatic) return null;
  var enclosing = method.declaredFragment?.element.enclosingElement;
  if (enclosing is! InterfaceElement) return null;

  var name = method.name.lexeme;
  if (name == 'wrapError' &&
      (reduxActionSupertype(enclosing) != null || isPersistor(enclosing))) {
    var error = method.parameters?.parameters.firstOrNull?.name?.lexeme;
    return ErrorReplacement._(method, (error == null || error == '_') ? null : error);
  }
  if (name == 'observe' && isGlobalErrorObserver(enclosing)) {
    var cause = declaresLocalName(method, 'error') ? 'this.error' : 'error';
    return ErrorReplacement._(method, cause);
  }
  return null;
}

/// Returns true if [creation] is passed to `addCause` or `mergedWith`, like
/// `UserException('a').addCause(UserException('b'))`.
bool _isCauseOfAnotherException(InstanceCreationExpression creation) {
  AstNode node = creation;
  while (node.parent is ParenthesizedExpression) {
    node = node.parent!;
  }
  var arguments = node.parent;
  if (arguments is! ArgumentList) return false;
  var invocation = arguments.parent;
  return invocation is MethodInvocation &&
      (invocation.methodName.name == 'addCause' ||
          invocation.methodName.name == 'mergedWith');
}

/// Returns true if `addCause` is called on [creation], directly or after other
/// methods, like `UserException('...').addProps(props).addCause(error)`.
bool _addsCause(InstanceCreationExpression creation) {
  AstNode node = creation;
  while (true) {
    var parent = node.parent;
    if (parent is ParenthesizedExpression) {
      node = parent;
    } else if (parent is MethodInvocation && parent.target == node) {
      if (parent.methodName.name == 'addCause') return true;
      node = parent;
    } else if (parent is PropertyAccess && parent.target == node) {
      node = parent;
    } else {
      return false;
    }
  }
}

/// Returns true if [node] calls `addCause`, outside of closures.
bool _callsAddCause(AstNode node) {
  var finder = _AddCauseFinder();
  node.accept(finder);
  return finder.found;
}

class _AddCauseFinder extends RecursiveAstVisitor<void> {
  bool found = false;

  @override
  void visitFunctionExpression(FunctionExpression node) {}

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'addCause') found = true;
    super.visitMethodInvocation(node);
  }
}

class _WithoutCauseVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _WithoutCauseVisitor(this.rule);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    var replacement = userExceptionWithoutCause(node);
    if (replacement == null) return;
    rule.reportAtNode(node, arguments: [replacement.cause ?? 'error']);
  }
}
