import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

import '../redux_types.dart';
import 'reduce_without_await_rule.dart';

/// Reports, in an async `reduce`, a local variable set to `state` (or `initialState`)
/// before an `await`, and used after the `await` to build the returned state. The
/// `state` getter can change after every `await`, so the returned state silently
/// discards the changes made by other actions in the meantime.
///
/// A use builds the returned state when it's in a `return`, or in the value of a
/// local variable that ends up in a `return`. Uses inside an `await`, like
/// `await api.load(s.id)`, don't build the state, so they are not reported.
///
/// The analysis follows the source order, so an `await` in an `if` branch counts for
/// the code after the `if`, but not for the `else` branch.
class StaleStateAfterAwaitRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'stale_state_after_await',
    "The variable '{0}' was set to '{1}' before an 'await', so it may not have the "
        "current state.",
    correctionMessage:
        "Try using 'state' instead, so that the changes made by other actions during "
        "the 'await' are kept.",
    severity: DiagnosticSeverity.WARNING,
  );

  StaleStateAfterAwaitRule()
    : super(
        name: 'stale_state_after_await',
        description:
            "An async reducer shouldn't build the state it returns from a copy of "
            "'state' read before an 'await'.",
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
    var collector = _Collector();
    body.accept(collector);
    if (body is ExpressionFunctionBody) collector.returns.add(body.expression);

    var candidates = {
      for (var MapEntry(key: variable, value: declaration)
          in collector.stateCopies.entries)
        if (!collector.assigned.contains(variable)) variable: declaration,
    };
    if (candidates.isEmpty || collector.awaits.isEmpty) return;

    // The expressions whose value ends up in a `return`: the returned expressions,
    // and the values of the local variables they use, recursively.
    // The references of each sink are kept, so that each sink is visited only once.
    var sinks = [...collector.returns];
    var sinkReferences = <(AstNode, List<SimpleIdentifier>)>[];
    var flowVariables = <LocalVariableElement>{};
    for (var i = 0; i < sinks.length; i++) {
      var references = _localReferences(sinks[i]);
      sinkReferences.add((sinks[i], references));
      for (var identifier in references) {
        var variable = identifier.element as LocalVariableElement;
        if (flowVariables.add(variable)) {
          sinks.addAll(collector.values[variable] ?? const []);
        }
      }
    }

    var reported = <SimpleIdentifier>{};
    for (var (sink, references) in sinkReferences) {
      for (var identifier in references) {
        var declaration = candidates[identifier.element];
        if (declaration == null || _isInsideAwait(identifier, sink)) continue;
        if (!collector.awaits.any((a) => _runsBetween(a, declaration, identifier))) {
          continue;
        }
        if (!reported.add(identifier)) continue;
        var initializer = declaration.initializer!;
        rule.reportAtNode(
          identifier,
          arguments: [
            identifier.name,
            readsActionGetter(initializer, 'state') ? 'state' : 'initialState',
          ],
        );
      }
    }
  }

  /// Returns the references to local variables inside [node].
  static List<SimpleIdentifier> _localReferences(AstNode node) {
    var finder = _LocalReferenceFinder();
    node.accept(finder);
    return finder.identifiers;
  }

  /// Returns true if [identifier] is inside an `await`, below [root].
  static bool _isInsideAwait(SimpleIdentifier identifier, AstNode root) {
    for (AstNode? node = identifier.parent; node != null && node != root;) {
      if (node is AwaitExpression) return true;
      node = node.parent;
    }
    return false;
  }

  /// Returns true if the [awaitNode] runs after the [declaration], and before the
  /// [reference] is evaluated.
  static bool _runsBetween(
    AstNode awaitNode,
    VariableDeclaration declaration,
    SimpleIdentifier reference,
  ) {
    // After an `await for` starts, its body and the code after it run after an await.
    var awaitEnd = switch (awaitNode) {
      ForStatement(:var forLoopParts) => forLoopParts.end,
      ForElement(:var forLoopParts) => forLoopParts.end,
      _ => awaitNode.end,
    };
    if (awaitNode.offset < declaration.end || awaitEnd > reference.offset) return false;

    // When the `await` and the reference are in different branches, the `await`
    // doesn't run before the reference. It only does when it's in the condition.
    var condition = switch (_commonAncestor(awaitNode, reference)) {
      IfStatement(:var expression) => expression,
      IfElement(:var expression) => expression,
      ConditionalExpression(:var condition) => condition,
      SwitchStatement(:var expression) => expression,
      SwitchExpression(:var expression) => expression,
      _ => null,
    };
    if (condition == null) return true;
    return awaitNode.offset >= condition.offset && awaitNode.end <= condition.end;
  }

  static AstNode? _commonAncestor(AstNode a, AstNode b) {
    var ancestors = <AstNode>{};
    for (AstNode? node = a; node != null; node = node.parent) {
      ancestors.add(node);
    }
    for (AstNode? node = b; node != null; node = node.parent) {
      if (ancestors.contains(node)) return node;
    }
    return null;
  }
}

/// Collects, in the body of a `reduce`, the local variables set to `state` or
/// `initialState`, the values assigned to local variables, the returned expressions,
/// and the `await`s. Returns and awaits inside closures are skipped.
class _Collector extends RecursiveAstVisitor<void> {
  final stateCopies = <LocalVariableElement, VariableDeclaration>{};
  final values = <LocalVariableElement, List<Expression>>{};
  final assigned = <LocalVariableElement>{};
  final returns = <Expression>[];
  final awaits = <AstNode>[];

  int _closureDepth = 0;

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    var element = node.declaredFragment?.element;
    var initializer = node.initializer;
    if (element is LocalVariableElement && initializer != null) {
      (values[element] ??= []).add(initializer);
      if (readsActionGetter(initializer, 'state') ||
          readsActionGetter(initializer, 'initialState')) {
        stateCopies[element] = node;
      }
    }
    super.visitVariableDeclaration(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    var element = node.writeElement;
    if (element is LocalVariableElement) {
      assigned.add(element);
      (values[element] ??= []).add(node.rightHandSide);
    }
    super.visitAssignmentExpression(node);
  }

  @override
  void visitPrefixExpression(PrefixExpression node) {
    var element = node.writeElement;
    if (element is LocalVariableElement) assigned.add(element);
    super.visitPrefixExpression(node);
  }

  @override
  void visitPostfixExpression(PostfixExpression node) {
    var element = node.writeElement;
    if (element is LocalVariableElement) assigned.add(element);
    super.visitPostfixExpression(node);
  }

  @override
  void visitReturnStatement(ReturnStatement node) {
    var expression = node.expression;
    if (_closureDepth == 0 && expression != null) returns.add(expression);
    super.visitReturnStatement(node);
  }

  @override
  void visitAwaitExpression(AwaitExpression node) {
    if (_closureDepth == 0) awaits.add(node);
    super.visitAwaitExpression(node);
  }

  @override
  void visitForStatement(ForStatement node) {
    if (_closureDepth == 0 && node.awaitKeyword != null) awaits.add(node);
    super.visitForStatement(node);
  }

  @override
  void visitForElement(ForElement node) {
    if (_closureDepth == 0 && node.awaitKeyword != null) awaits.add(node);
    super.visitForElement(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    _closureDepth++;
    super.visitFunctionExpression(node);
    _closureDepth--;
  }
}

class _LocalReferenceFinder extends RecursiveAstVisitor<void> {
  final identifiers = <SimpleIdentifier>[];

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.element is LocalVariableElement && !node.inSetterContext()) {
      identifiers.add(node);
    }
  }
}
