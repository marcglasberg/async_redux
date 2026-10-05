import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

import '../mixin_utils.dart';
import '../redux_types.dart';

/// Reports an action with the `Sequential` mixin that waits for another action of the
/// same queue, with `dispatchAndWait`, `dispatchAndWaitAll`, `waitActionType`,
/// `waitAllActionTypes` or `waitAllActions`. The other action can only run after this
/// one finishes, so both wait for each other forever.
///
/// Two actions use the same queue when neither overrides `sequentialKeyParams`, or
/// when both return the same constant key, or both return `runtimeType` and are of the
/// same type. Keys that can't be known from the code are not reported.
///
/// Only checks waits in the action's own methods, not in closures, and only when the
/// result is awaited or returned.
class SequentialDeadlockRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'sequential_deadlock',
    "'{0}' and '{1}' use the same 'Sequential' queue, so waiting for '{1}' with '{2}' "
        "deadlocks: '{1}' only runs after '{0}' finishes.",
    correctionMessage: '{3}',
    severity: DiagnosticSeverity.ERROR,
  );

  static const _dispatchMethods = {'dispatchAndWait', 'dispatchAndWaitAll'};
  static const _typeMethods = {'waitActionType', 'waitAllActionTypes'};
  static const _actionMethods = {..._dispatchMethods, 'waitAllActions'};

  SequentialDeadlockRule()
    : super(
        name: 'sequential_deadlock',
        description:
            "An action with 'Sequential' must not wait for another action of the same "
            "queue.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    var library = context.libraryElement;
    if (library == null) return;
    var visitor = _DeadlockVisitor(this, context, library);
    registry.addMethodInvocation(this, visitor);
    // Calling a getter of function type, like `ReduxAction.dispatchAndWait`.
    registry.addFunctionExpressionInvocation(this, visitor);
  }
}

class _DeadlockVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;
  final LibraryElement library;

  _DeadlockVisitor(this.rule, this.context, this.library);

  @override
  void visitMethodInvocation(MethodInvocation node) => _check(node);

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) =>
      _check(node);

  void _check(InvocationExpression node) {
    var name = invokedName(node);
    if (name == null) return;
    var waitsForTypes = SequentialDeadlockRule._typeMethods.contains(name);
    if (!waitsForTypes && !SequentialDeadlockRule._actionMethods.contains(name)) return;
    if (!_isWaited(node)) return;

    // Only the action's own methods, not closures.
    var body = node.thisOrAncestorOfType<FunctionBody>();
    var method = body?.parent;
    if (method is! MethodDeclaration) return;
    var current = enclosingInterface(method);
    if (current == null || !asyncReduxMixinsOf(current).contains('Sequential')) return;

    var currentKey = _queueKey(current.thisType);
    if (currentKey == null) return;

    for (var argument in firstArgumentExpressions(node)) {
      var target = waitsForTypes ? _typeOfLiteral(argument) : argument.staticType;
      if (target is! InterfaceType || !isActionType(target)) continue;
      if (!asyncReduxMixinsOfType(target).contains('Sequential')) continue;

      // Waiting for its own type throws a StoreException instead of hanging.
      if (waitsForTypes && target.element == current) continue;

      if (_queueKey(target) != currentKey) continue;

      var correction = SequentialDeadlockRule._dispatchMethods.contains(name)
          ? "Try using '${name == 'dispatchAndWait' ? 'dispatch' : 'dispatchAll'}' "
                "instead, without waiting, or giving the actions different keys in "
                "'sequentialKeyParams'."
          : "Try not waiting for '${target.element.displayName}', or giving the "
                "actions different keys in 'sequentialKeyParams'.";

      rule.reportAtNode(
        argument,
        arguments: [current.displayName, target.element.displayName, name, correction],
      );
    }
  }

  /// Returns true if the future returned by [node] is awaited, or returned.
  static bool _isWaited(InvocationExpression node) {
    AstNode child = node;
    var parent = node.parent;
    while (parent is ParenthesizedExpression) {
      child = parent;
      parent = parent.parent;
    }
    return parent is AwaitExpression ||
        parent is ReturnStatement ||
        (parent is ExpressionFunctionBody && parent.expression == child);
  }

  static DartType? _typeOfLiteral(Expression expression) =>
      (expression is TypeLiteral) ? expression.type.type : null;

  /// Returns the key of the `Sequential` queue of the actions of [type], or null if
  /// it can't be known. Keys are compared with `==`.
  Object? _queueKey(InterfaceType type) {
    var method = type.lookUpMethod('sequentialKeyParams', library);
    if (method == null) return null;
    if (isFromAsyncRedux(method)) return const _NullKey();

    var declaration = _declarationOf(method);
    if (declaration == null) return null;
    var returned = returnedExpressions(declaration.body);
    if (returned.length != 1) return null;
    var expression = returned.single.unParenthesized;

    // `runtimeType` is the type of the action, which is only known for a concrete type.
    if (expression is SimpleIdentifier && expression.name == 'runtimeType') {
      var element = type.element;
      return (element is ClassElement && !element.isAbstract) ? element : null;
    }

    var value = expression.computeConstantValue()?.value;
    if (value == null) return null;
    return value.isNull ? const _NullKey() : value;
  }

  /// Returns the declaration of [method], if it's in the library being analyzed.
  MethodDeclaration? _declarationOf(MethodElement method) {
    var baseElement = method.baseElement;
    for (var unit in context.allUnits) {
      for (var declaration in unit.unit.declarations) {
        var members = switch (declaration) {
          ClassDeclaration(:var body) => body.members,
          MixinDeclaration(:var body) => body.members,
          _ => const <ClassMember>[],
        };
        for (var member in members) {
          if (member is MethodDeclaration &&
              member.declaredFragment?.element == baseElement) {
            return member;
          }
        }
      }
    }
    return null;
  }
}

/// The key `null`, which all actions with `Sequential` use by default.
class _NullKey {
  const _NullKey();
}

/// Reports a `before()` override, in an action with the `Sequential` mixin, that
/// doesn't call `await super.before()` as its first statement. Code before it runs
/// as soon as the action is dispatched, before the action gets its turn, and an
/// `await` before it can make the action lose its position in the queue.
///
/// Overrides that don't call `super.before()` at all are not reported, since the
/// analyzer already reports them with `must_call_super`.
class SequentialBeforeSuperNotFirstRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'sequential_before_super_not_first',
    "In an action with the 'Sequential' mixin, 'before' must call "
        "'await super.before()' as its first statement.",
    correctionMessage:
        "Try moving 'await super.before();' to the start of 'before', so that the "
        "code after it runs when the action gets its turn.",
    severity: DiagnosticSeverity.ERROR,
  );

  SequentialBeforeSuperNotFirstRule()
    : super(
        name: 'sequential_before_super_not_first',
        description:
            "In an action with 'Sequential', 'before' must start with "
            "'await super.before()'.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addMethodDeclaration(this, _BeforeVisitor(this));
  }
}

class _BeforeVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _BeforeVisitor(this.rule);

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.lexeme != 'before' || !_isInSequentialAction(node)) return;

    var finder = _SuperCallFinder('before');
    node.body.accept(finder);
    if (finder.calls.isEmpty) return;

    if (!_startsWithSuperBefore(node.body)) rule.reportAtToken(node.name);
  }

  static bool _startsWithSuperBefore(FunctionBody body) {
    if (body is ExpressionFunctionBody) return _isSuperBefore(body.expression);
    if (body is! BlockFunctionBody) return false;
    var first = body.block.statements.firstOrNull;
    return switch (first) {
      ExpressionStatement(expression: AwaitExpression(:var expression)) => _isSuperBefore(
        expression,
      ),
      ReturnStatement(:var expression?) => _isSuperBefore(expression),
      _ => false,
    };
  }

  /// Returns true if [expression] is `super.before()` or `await super.before()`.
  static bool _isSuperBefore(Expression expression) {
    var unwrapped = expression.unParenthesized;
    if (unwrapped is AwaitExpression) unwrapped = unwrapped.expression.unParenthesized;
    return isSuperCall(unwrapped, 'before');
  }
}

/// Reports a `super.after()` call, in an action with the `Sequential` mixin, that is
/// not in a `finally` block. If the code before it throws, `super.after()` is never
/// called, and the actions waiting in the queue never run.
///
/// Not reported when `super.after()` is the first statement of `after()`, since then
/// no code of the override runs before it.
class SequentialAfterSuperNotInFinallyRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'sequential_after_super_not_in_finally',
    "In an action with the 'Sequential' mixin, call 'super.after()' in a 'finally' "
        "block, so that the queue is released even if 'after' throws.",
    correctionMessage:
        "Try wrapping the code of 'after' in a 'try' block, and calling "
        "'super.after()' in its 'finally' block.",
    severity: DiagnosticSeverity.INFO,
  );

  SequentialAfterSuperNotInFinallyRule()
    : super(
        name: 'sequential_after_super_not_in_finally',
        description:
            "In an action with 'Sequential', 'after' should call 'super.after()' in a "
            "'finally' block.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addMethodDeclaration(this, _AfterVisitor(this));
  }
}

class _AfterVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _AfterVisitor(this.rule);

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.lexeme != 'after' || !_isInSequentialAction(node)) return;

    var finder = _SuperCallFinder('after');
    node.body.accept(finder);

    for (var call in finder.calls) {
      if (_isFirst(call, node.body) || _isInFinally(call, node.body)) continue;
      rule.reportAtNode(call);
    }
  }

  /// Returns true if [call] is the expression body, or the first statement of [body].
  static bool _isFirst(Expression call, FunctionBody body) {
    var statement = call.parent;
    return (body is ExpressionFunctionBody && body.expression == call) ||
        (body is BlockFunctionBody &&
            statement is ExpressionStatement &&
            body.block.statements.firstOrNull == statement);
  }

  static bool _isInFinally(AstNode call, FunctionBody body) {
    for (AstNode? node = call; node != null && node != body; node = node.parent) {
      var parent = node.parent;
      if (parent is TryStatement && parent.finallyBlock == node) return true;
    }
    return false;
  }
}

/// Returns true if [node] is an instance method of an action, or of a mixin on an
/// action, that has the `Sequential` mixin as a supertype.
bool _isInSequentialAction(MethodDeclaration node) {
  if (!isActionMethod(node)) return false;
  var enclosing = enclosingInterface(node);
  return enclosing != null && asyncReduxMixinsOf(enclosing).contains('Sequential');
}

/// Finds the `super.name()` calls and `super.name` tear-offs in a method body,
/// skipping closures.
class _SuperCallFinder extends RecursiveAstVisitorSkippingFunctions {
  final String name;
  final calls = <Expression>[];

  _SuperCallFinder(this.name);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (isSuperCall(node, name)) calls.add(node);
    super.visitMethodInvocation(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (isSuperCall(node, name)) calls.add(node);
    super.visitPropertyAccess(node);
  }
}
