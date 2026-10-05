import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:analyzer/error/error.dart';

import '../error_types.dart';
import '../redux_types.dart';

/// Returns true if [element] is the `Persistor` of AsyncRedux, or a class that
/// extends or implements it.
bool isPersistorOrSubtype(Element? element) =>
    element is InterfaceElement &&
    ((element.name == 'Persistor' && isFromAsyncRedux(element)) || isPersistor(element));

/// Returns true if [element] inherits the code of the `Persistor` of AsyncRedux,
/// because `Persistor` is one of its superclasses.
bool _extendsPersistor(InterfaceElement element) {
  for (var type = element.supertype; type != null; type = type.element.supertype) {
    if (type.element.name == 'Persistor' && isFromAsyncRedux(type.element)) return true;
  }
  return false;
}

/// Reports a class that implements `Persistor`, or a class that extends it, without
/// extending it. The docs say to always extend `Persistor`, because the store relies
/// on the code inherited from it, like the error queue behind `addError`.
class ImplementsPersistorRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'implements_persistor',
    "Persistors must extend '{0}', not implement it. The store relies on the code "
        "inherited from 'Persistor'.",
    correctionMessage: "Try changing 'implements' to 'extends'.",
    severity: DiagnosticSeverity.ERROR,
  );

  ImplementsPersistorRule()
    : super(
        name: 'implements_persistor',
        description: "Persistors must extend 'Persistor', not implement it.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addClassDeclaration(this, _ImplementsVisitor(this));
  }
}

class _ImplementsVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _ImplementsVisitor(this.rule);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    // Most classes don't implement anything, so the `implements` clause is checked
    // before the superclasses.
    var implemented = implementedPersistor(node);
    if (implemented == null) return;
    var element = node.declaredFragment?.element;
    if (element == null || _extendsPersistor(element)) return;
    rule.reportAtNode(implemented, arguments: [implemented.name.lexeme]);
  }
}

/// Returns the type in the `implements` clause of [node] that is `Persistor`, or a
/// class that extends or implements it, or null if there's none.
NamedType? implementedPersistor(ClassDeclaration node) => node
    .implementsClause
    ?.interfaces
    .where((type) => isPersistorOrSubtype(type.element))
    .firstOrNull;

/// Reports a `throw` or `rethrow` in the `readState` method of a `Persistor`, outside
/// a `try` that catches it. `readState` runs before the store exists, so the error
/// can't be shown to the user. The docs recommend `addError(...)` and returning null.
///
/// Throws inside closures are not reported, since they may run elsewhere, if at all.
/// Not reported in tests, where a persistor may throw on purpose.
class ThrowInReadStateRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'throw_in_read_state',
    "Don't throw from 'readState'. It runs before the store exists, so the error "
        "can't be shown to the user.",
    correctionMessage:
        "Try calling 'addError(...)' and returning null, or fixing the persisted "
        "state.",
    severity: DiagnosticSeverity.WARNING,
  );

  ThrowInReadStateRule()
    : super(
        name: 'throw_in_read_state',
        description: "The 'readState' method of a 'Persistor' should not throw.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addMethodDeclaration(this, _ReadStateVisitor(this, context));
  }
}

class _ReadStateVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _ReadStateVisitor(this.rule, this.context);

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.lexeme != 'readState' || node.isStatic) return;
    var enclosing = node.declaredFragment?.element.enclosingElement;
    if (enclosing is! InterfaceElement || !isPersistor(enclosing)) return;
    if (_isTestFile()) return;
    node.body.accept(_ThrowFinder(rule, context.typeSystem));
  }

  bool _isTestFile() {
    var file = context.currentUnit?.file;
    if (file == null) return false;
    return (context.package?.isInTestDirectory(file) ?? false) ||
        file.shortName.endsWith('_test.dart');
  }
}

class _ThrowFinder extends RecursiveAstVisitor<void> {
  final AnalysisRule rule;
  final TypeSystem typeSystem;

  _ThrowFinder(this.rule, this.typeSystem);

  @override
  void visitFunctionExpression(FunctionExpression node) {}

  @override
  void visitThrowExpression(ThrowExpression node) {
    if (!isCaughtLocally(node, node.expression.staticType, typeSystem)) {
      rule.reportAtNode(node);
    }
    super.visitThrowExpression(node);
  }

  @override
  void visitRethrowExpression(RethrowExpression node) {
    var type = node.thisOrAncestorOfType<CatchClause>()?.exceptionType?.type;
    if (!isCaughtLocally(node, type, typeSystem)) rule.reportAtNode(node);
  }
}

/// Reports the initial state created when `persistor.readState()` returns null, when
/// the same function doesn't save it with `persistor.saveInitialState(...)`. The store
/// considers its initial state already persisted, so it's never saved until the state
/// changes.
///
/// Recognizes the result of `await persistor.readState()` kept in a variable, and then
/// replaced in `if (state == null) { state = ...; }`, with `state ??= ...`, or used in
/// `state ?? ...`. Also recognizes `await persistor.readState() ?? ...`.
class InitialStateNotSavedRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'initial_state_not_saved',
    "The initial state created when 'readState' returns null is not saved.",
    correctionMessage:
        "Try saving it with 'await {0}.saveInitialState(...)', before creating the "
        "store.",
    severity: DiagnosticSeverity.INFO,
  );

  InitialStateNotSavedRule()
    : super(
        name: 'initial_state_not_saved',
        description:
            "The initial state created when 'readState' returns null should be saved "
            "with 'saveInitialState'.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addMethodInvocation(this, _ReadStateCallVisitor(this));
  }
}

class _ReadStateCallVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _ReadStateCallVisitor(this.rule);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    var unsaved = unsavedInitialStates(node);
    if (unsaved == null) return;
    var target = node.target;
    var name = target is Identifier ? target.name : 'persistor';
    for (var creation in unsaved) {
      rule.reportAtNode(creation, arguments: [name]);
    }
  }
}

/// If [node] is a call to `persistor.readState()`, outside a `Persistor`, returns the
/// expressions that create the initial state when it returns null, provided the
/// function that calls it doesn't also call `saveInitialState` or
/// `persistDifference`. Otherwise, returns null.
List<Expression>? unsavedInitialStates(MethodInvocation node) {
  if (node.methodName.name != 'readState' || node.argumentList.arguments.isNotEmpty) {
    return null;
  }
  var target = node.target;
  if (target == null || !_isPersistorType(target.staticType)) return null;
  var enclosing = enclosingInterface(node);
  if (enclosing != null && isPersistorOrSubtype(enclosing)) return null;

  var body = node.thisOrAncestorOfType<FunctionBody>();
  if (body == null) return null;

  var read = _outerParentheses(node);
  var await_ = read.parent;
  if (await_ is! AwaitExpression) return null;
  read = _outerParentheses(await_);
  var parent = read.parent;

  var creations = <Expression>[];
  if (parent is BinaryExpression &&
      parent.operator.type == TokenType.QUESTION_QUESTION &&
      parent.leftOperand == read) {
    creations.add(parent.rightOperand);
  } else {
    var variable = switch (parent) {
      VariableDeclaration(:var initializer) when initializer == read =>
        parent.declaredFragment?.element,
      AssignmentExpression(:var rightHandSide)
          when rightHandSide == read && parent.operator.type == TokenType.EQ =>
        _variable(parent.writeElement),
      _ => null,
    };
    if (variable == null) return null;
    var finder = _CreationFinder(variable, node.end);
    body.accept(finder);
    creations.addAll(finder.creations);
  }
  if (creations.isEmpty) return null;

  var saveFinder = _SaveFinder();
  body.accept(saveFinder);
  return saveFinder.found ? null : creations;
}

bool _isPersistorType(DartType? type) =>
    type is InterfaceType && isPersistorOrSubtype(type.element);

/// Returns the outermost parenthesized expression that contains only [node], or
/// [node] if it's not inside parentheses.
Expression _outerParentheses(Expression node) {
  var result = node;
  for (
    var parent = node.parent;
    parent is ParenthesizedExpression;
    parent = parent.parent
  ) {
    result = parent;
  }
  return result;
}

/// Returns the variable of [element], which may be the getter or setter of a field or
/// top-level variable.
Element? _variable(Element? element) =>
    element is PropertyAccessorElement ? element.variable : element;

/// Returns true if [expression] reads [variable].
bool _reads(Expression expression, Element variable) {
  var unParenthesized = expression.unParenthesized;
  return unParenthesized is Identifier && _variable(unParenthesized.element) == variable;
}

/// Finds the expressions, after [offset], that create the state kept in [variable]
/// when it's null: `variable ?? creation`, `variable ??= creation`, and
/// `variable = creation` inside `if (variable == null)`.
class _CreationFinder extends RecursiveAstVisitor<void> {
  final Element variable;
  final int offset;
  final creations = <Expression>[];

  _CreationFinder(this.variable, this.offset);

  @override
  void visitBinaryExpression(BinaryExpression node) {
    if (node.offset > offset &&
        node.operator.type == TokenType.QUESTION_QUESTION &&
        _reads(node.leftOperand, variable)) {
      creations.add(node.rightOperand);
    }
    super.visitBinaryExpression(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    if (node.offset > offset && _variable(node.writeElement) == variable) {
      var operator = node.operator.type;
      if (operator == TokenType.QUESTION_QUESTION_EQ ||
          (operator == TokenType.EQ && _isInsideNullCheck(node))) {
        creations.add(node.rightHandSide);
      }
    }
    super.visitAssignmentExpression(node);
  }

  /// Returns true if [node] is in the `then` branch of `if (variable == null)`.
  bool _isInsideNullCheck(AstNode node) {
    for (
      AstNode? child = node, parent = node.parent;
      parent != null && parent is! FunctionBody;
      child = parent, parent = parent.parent
    ) {
      if (parent is IfStatement &&
          parent.thenStatement == child &&
          _isNullCheck(parent.expression)) {
        return true;
      }
    }
    return false;
  }

  bool _isNullCheck(Expression condition) {
    var expression = condition.unParenthesized;
    if (expression is! BinaryExpression || expression.operator.type != TokenType.EQ_EQ) {
      return false;
    }
    var left = expression.leftOperand;
    var right = expression.rightOperand;
    return (right is NullLiteral && _reads(left, variable)) ||
        (left is NullLiteral && _reads(right, variable));
  }
}

/// Finds a call to `saveInitialState` or `persistDifference` of a `Persistor`.
class _SaveFinder extends RecursiveAstVisitor<void> {
  static const _saveMethods = {'saveInitialState', 'persistDifference'};

  bool found = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_saveMethods.contains(node.methodName.name) &&
        _isPersistorType(node.realTarget?.staticType)) {
      found = true;
    }
    super.visitMethodInvocation(node);
  }
}
