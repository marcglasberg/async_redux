import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

import '../redux_types.dart';

/// Reports a `return` in an async `reduce` method that can be reached without passing
/// through an `await` in `reduce` itself. Such a reducer may return a completed Future,
/// and then state changes may be lost. Returning `null` is fine, because it doesn't
/// change the state.
///
/// The analysis is conservative: an `await` only counts if it provably runs before the
/// `return`. For example, an `await` inside a `for` loop doesn't count, because the
/// loop may run zero times.
class ReduceWithoutAwaitRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'reduce_without_await',
    "This async 'reduce' can return without first passing through an 'await'. "
        "Returning a completed Future may result in state changes being lost.",
    correctionMessage:
        "Try adding 'await microtask;' to the start of 'reduce', "
        "or make 'reduce' sync if it doesn't need to await.",
    severity: DiagnosticSeverity.ERROR,
  );

  ReduceWithoutAwaitRule()
    : super(
        name: 'reduce_without_await',
        description:
            "All code paths of an async 'reduce' method must pass through at "
            "least one 'await', unless they return null.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addMethodDeclaration(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _Visitor(this.rule);

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (!isAsyncReduce(node)) return;

    var body = node.body;
    if (body is ExpressionFunctionBody) {
      if (!expressionAwaits(body.expression) && !_returnsNull(body.expression)) {
        rule.reportAtNode(body.expression);
      }
    } else if (body is BlockFunctionBody) {
      _AwaitFlow(rule).statement(body.block, false);
    }
  }
}

/// Returns true if [node] is an `async` `reduce` method of an action, returning a
/// `Future`. Other return types are reported by `reduce_return_type`.
bool isAsyncReduce(MethodDeclaration node) {
  if (node.name.lexeme != 'reduce') return false;
  if (node.isStatic || node.isGetter || node.isSetter) return false;

  var body = node.body;
  if (!body.isAsynchronous || body.isGenerator) return false;

  var element = node.declaredFragment?.element;
  if (element == null || !isNonNullableFuture(element.returnType)) return false;

  var enclosing = element.enclosingElement;
  return enclosing is InterfaceElement && reduxActionSupertype(enclosing) != null;
}

bool _returnsNull(Expression expression) =>
    expression is NullLiteral || (expression.staticType?.isDartCoreNull ?? false);

/// Tracks, statement by statement, whether an `await` has provably run, and reports
/// each `return` reached when it hasn't.
///
/// The state is a bool: true if an `await` has run on every path reaching this point.
/// A point that can't be reached (after a `return`, `throw`, `break` or `continue`)
/// is also true, so it doesn't weaken the state where paths join.
class _AwaitFlow {
  final AnalysisRule rule;

  /// For each statement targeted by a `break`, the state at the breaks so far.
  final _breakStates = <AstNode, bool>{};

  /// For each loop targeted by a `continue`, the state at the continues so far.
  final _continueStates = <AstNode, bool>{};

  _AwaitFlow(this.rule);

  /// Analyzes [node], starting with state [awaited], and returns the state after it
  /// completes normally, or after a `break` out of it.
  bool statement(Statement node, bool awaited) {
    var result = _statement(node, awaited);
    var breakState = _breakStates.remove(node);
    return (breakState == null) ? result : result && breakState;
  }

  bool _statements(Iterable<Statement> statements, bool awaited) {
    for (var statement in statements) {
      awaited = this.statement(statement, awaited);
    }
    return awaited;
  }

  bool _statement(Statement node, bool awaited) {
    switch (node) {
      case Block():
        return _statements(node.statements, awaited);

      case ExpressionStatement():
        return awaited || expressionAwaits(node.expression);

      case VariableDeclarationStatement():
        return awaited ||
            node.variables.variables.any((v) => expressionAwaits(v.initializer));

      case PatternVariableDeclarationStatement():
        return awaited || expressionAwaits(node.declaration.expression);

      case ReturnStatement():
        var expression = node.expression;
        if (expression != null &&
            !awaited &&
            !expressionAwaits(expression) &&
            !_returnsNull(expression)) {
          rule.reportAtNode(node);
        }
        return true;

      case IfStatement():
        // A `case` guard only runs if the pattern matches, so it doesn't count.
        var condition = awaited || expressionAwaits(node.expression);
        var thenState = statement(node.thenStatement, condition);
        var elseStatement = node.elseStatement;
        var elseState = (elseStatement == null)
            ? condition
            : statement(elseStatement, condition);
        return thenState && elseState;

      case WhileStatement():
        // The body may run zero times, so its awaits don't count after the loop.
        var condition = awaited || expressionAwaits(node.condition);
        statement(node.body, condition);
        _continueStates.remove(node);
        return condition;

      case DoStatement():
        // The body runs at least once. The condition runs after the body completes
        // normally, or after a `continue`.
        var bodyState = statement(node.body, awaited);
        var continueState = _continueStates.remove(node);
        if (continueState != null) bodyState = bodyState && continueState;
        return bodyState || expressionAwaits(node.condition);

      case ForStatement():
        return _forStatement(node, awaited);

      case SwitchStatement():
        return _switchStatement(node, awaited);

      case TryStatement():
        // A `catch` may run before any statement of the `try` block.
        var tryState = statement(node.body, awaited);
        var catchStates = [
          for (var clause in node.catchClauses) statement(clause.body, awaited),
        ];
        var state = tryState && catchStates.every((s) => s);
        var finallyBlock = node.finallyBlock;
        if (finallyBlock == null) return state;
        // The `finally` block may also run after an exception, from any point.
        return statement(finallyBlock, awaited) || state;

      case BreakStatement():
        var target = node.target;
        if (target != null)
          _breakStates[target] = (_breakStates[target] ?? true) && awaited;
        return true;

      case ContinueStatement():
        var target = node.target;
        if (target != null) {
          _continueStates[target] = (_continueStates[target] ?? true) && awaited;
        }
        return true;

      case LabeledStatement():
        return statement(node.statement, awaited);

      // Asserts may be disabled, so their awaits don't count.
      // Local functions run later, if at all.
      case AssertStatement():
      case FunctionDeclarationStatement():
      case EmptyStatement():
      default:
        return awaited;
    }
  }

  bool _forStatement(ForStatement node, bool awaited) {
    var parts = node.forLoopParts;

    // `await for` waits for the stream, so it always awaits before the body runs.
    if (node.awaitKeyword != null) {
      statement(node.body, true);
      _continueStates.remove(node);
      return true;
    }

    // The initializer and the first check of the condition always run.
    // The updaters and the body may not run.
    var before =
        awaited ||
        switch (parts) {
          ForEachParts() => expressionAwaits(parts.iterable),
          ForPartsWithDeclarations() =>
            parts.variables.variables.any((v) => expressionAwaits(v.initializer)) ||
                expressionAwaits(parts.condition),
          ForPartsWithExpression() =>
            expressionAwaits(parts.initialization) || expressionAwaits(parts.condition),
          ForPartsWithPattern() =>
            expressionAwaits(parts.variables.expression) ||
                expressionAwaits(parts.condition),
        };

    statement(node.body, before);
    _continueStates.remove(node);
    return before;
  }

  bool _switchStatement(SwitchStatement node, bool awaited) {
    var subject = awaited || expressionAwaits(node.expression);

    // Each case starts after the subject. Cases with no statements share the body of
    // the next case. A guard only runs if its pattern matches, so it doesn't count.
    var result = true;
    for (var member in node.members) {
      if (member.statements.isEmpty) continue;
      result = _statements(member.statements, subject) && result;
    }

    // If no case matches, the switch completes right after the subject.
    if (!_isExhaustive(node)) result = result && subject;
    return result;
  }

  /// Returns true if some case of [node] always runs. A switch on an enum, `bool` or
  /// sealed type must be exhaustive, so the compiler guarantees it.
  bool _isExhaustive(SwitchStatement node) {
    for (var member in node.members) {
      if (member is SwitchDefault) return true;
      if (member is SwitchPatternCase &&
          member.guardedPattern.whenClause == null &&
          member.guardedPattern.pattern is WildcardPattern) {
        return true;
      }
    }
    var type = node.expression.staticType;
    if (type is! InterfaceType) return false;
    var element = type.element;
    return element is EnumElement ||
        type.isDartCoreBool ||
        (element is ClassElement && element.isSealed);
  }
}

/// Returns true if evaluating [node] provably runs an `await`. Parts that may not be
/// evaluated don't count: the right side of `&&`, `||` and `??`, the arguments of a
/// null-aware call, closures, and so on.
bool expressionAwaits(AstNode? node) {
  switch (node) {
    case null:
      return false;

    case AwaitExpression():
      return true;

    // Code after an expression of type `Never` (like `throw`) can't be reached.
    case Expression(staticType: NeverType()):
      return true;

    // A closure runs later, if at all.
    case FunctionExpression():
      return false;

    case ConditionalExpression():
      return expressionAwaits(node.condition) ||
          (expressionAwaits(node.thenExpression) &&
              expressionAwaits(node.elseExpression));

    case BinaryExpression():
      var operator = node.operator.type;
      if (operator == TokenType.AMPERSAND_AMPERSAND ||
          operator == TokenType.BAR_BAR ||
          operator == TokenType.QUESTION_QUESTION) {
        return expressionAwaits(node.leftOperand);
      }
      return expressionAwaits(node.leftOperand) || expressionAwaits(node.rightOperand);

    case AssignmentExpression():
      if (node.operator.type == TokenType.QUESTION_QUESTION_EQ) {
        return expressionAwaits(node.leftHandSide);
      }
      return expressionAwaits(node.leftHandSide) || expressionAwaits(node.rightHandSide);

    case MethodInvocation(isNullAware: true):
      return expressionAwaits(node.target);

    case PropertyAccess(isNullAware: true):
      return expressionAwaits(node.target);

    case IndexExpression(isNullAware: true):
      return expressionAwaits(node.target);

    case CascadeExpression(isNullAware: true):
      return expressionAwaits(node.target);

    case SwitchExpression():
      return expressionAwaits(node.expression) ||
          node.cases.every((c) => expressionAwaits(c.expression));

    case IfElement():
      var elseElement = node.elseElement;
      return expressionAwaits(node.expression) ||
          (expressionAwaits(node.thenElement) &&
              elseElement != null &&
              expressionAwaits(elseElement));

    // The body of a collection `for` may run zero times.
    case ForElement():
      return node.awaitKeyword != null;

    default:
      for (var child in node.childEntities) {
        if (child is AstNode && expressionAwaits(child)) return true;
      }
      return false;
  }
}
