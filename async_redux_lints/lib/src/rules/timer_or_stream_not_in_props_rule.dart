import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

import '../error_types.dart';
import '../redux_types.dart';

/// Reports an action that creates a `Timer`, or listens to a `Stream`, without
/// storing the `Timer` or the `StreamSubscription` with `setProp(...)`. It then can't
/// be cancelled with `disposeProp` or `store.disposeProps()`.
///
/// Only reported when the created object is discarded, or kept in a variable or field
/// that is never passed to `setProp`, never cancelled, and never passed on to other
/// code. Objects that are returned, or passed to a function, may be stored elsewhere.
class TimerOrStreamNotInPropsRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'timer_or_stream_not_in_props',
    "The '{0}' isn't stored in the store props.",
    correctionMessage:
        "Try saving it with 'setProp(key, value)', so that it can be cancelled with "
        "'disposeProp(key)' or 'store.disposeProps()'.",
    severity: DiagnosticSeverity.INFO,
  );

  TimerOrStreamNotInPropsRule()
    : super(
        name: 'timer_or_stream_not_in_props',
        description:
            "Actions should save the timers and stream subscriptions they create with "
            "'setProp', so that they can be cancelled.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    var visitor = _Visitor(this);
    registry.addInstanceCreationExpression(this, visitor);
    registry.addMethodInvocation(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _Visitor(this.rule);

  /// `Timer(...)` and `Timer.periodic(...)`. `Timer.run(...)` returns `void`, so
  /// it can't be stored.
  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (_isAsyncClass(node.constructorName.type.element, 'Timer')) {
      _check(node, 'Timer');
    }
  }

  /// `stream.listen(...)`.
  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'listen' && _isStream(node.realTarget?.staticType)) {
      _check(node, 'StreamSubscription');
    }
  }

  void _check(Expression node, String typeName) {
    var interface = enclosingInterface(node);
    if (interface == null || reduxActionSupertype(interface) == null) return;
    if (!_isKept(node)) rule.reportAtNode(node, arguments: [typeName]);
  }
}

/// Returns true if the value of [expression] is stored with `setProp`, cancelled, or
/// may be kept by other code. Returns false if it's discarded, or kept in a variable or
/// field that is only read by code that doesn't keep it.
bool _isKept(Expression expression) {
  var child = _outermost(expression);
  var parent = child.parent;
  switch (parent) {
    case ExpressionStatement():
      return false;
    case VariableDeclaration(:var initializer) when initializer == child:
      return _isVariableKept(parent.declaredFragment?.element, parent);
    case AssignmentExpression(:var rightHandSide) when rightHandSide == child:
      return _isVariableKept(parent.writeElement, parent);
    default:
      // Passed to `setProp` or to another function, returned, or used in another way.
      return true;
  }
}

/// Returns the outermost expression whose value is the value of [expression], going
/// up through parentheses, `!`, conditional expressions and cascades.
Expression _outermost(Expression expression) {
  var child = expression;
  while (true) {
    var parent = child.parent;
    if (parent is ParenthesizedExpression ||
        (parent is PostfixExpression && parent.operator.lexeme == '!') ||
        (parent is ConditionalExpression && parent.condition != child) ||
        (parent is CascadeExpression && parent.target == child)) {
      child = parent as Expression;
    } else {
      return child;
    }
  }
}

/// Returns true if the variable or field [element] is passed to `setProp`, cancelled,
/// or read by code that may keep it, anywhere in the file of [node].
bool _isVariableKept(Element? element, AstNode node) {
  var variable = _variableOf(element);
  if (variable == null) return true;
  // A local variable can only be used inside the method or function that declares it.
  var scope = (variable is LocalVariableElement)
      ? node.thisOrAncestorMatching(
          (node) => node is ClassMember || node is CompilationUnitMember,
        )
      : null;
  return _keptVariablesIn(scope ?? node.root).contains(variable);
}

/// Returns the variables and fields that have a read in [scope] that stores, cancels
/// or passes on their value.
///
/// A file, or a method, may create several timers and subscriptions, so each scope is
/// only visited once, for all of them, and the result is cached.
Set<Element> _keptVariablesIn(AstNode scope) =>
    _keptVariablesCache[scope] ??= (_KeptReferenceFinder()..visit(scope)).kept;

final _keptVariablesCache = Expando<Set<Element>>();

/// Returns the variable of [element], which is a variable, or the getter or setter
/// of a field or top-level variable.
Element? _variableOf(Element? element) => switch (element) {
  PropertyAccessorElement() => element.variable.baseElement,
  VariableElement() => element.baseElement,
  _ => null,
};

/// Finds the variables that have a read that stores, cancels or passes on their value.
class _KeptReferenceFinder extends RecursiveAstVisitor<void> {
  final kept = <Element>{};

  void visit(AstNode scope) => scope.accept(this);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.inDeclarationContext()) return;
    var variable = _variableOf(node.element);
    if (variable == null || kept.contains(variable)) return;

    // `x`, `this.x` or `Class.x`.
    Expression reference = node;
    var parent = node.parent;
    if ((parent is PropertyAccess && parent.propertyName == node) ||
        (parent is PrefixedIdentifier && parent.identifier == node)) {
      reference = parent as Expression;
    }
    reference = _outermost(reference);

    var referenceParent = reference.parent;
    var keeps = switch (referenceParent) {
      // `x.cancel()` or `x?.cancel()`.
      MethodInvocation(:var target, :var methodName) =>
        target == reference && methodName.name == 'cancel',
      // Other uses, like `x.isActive`, don't keep the value.
      PropertyAccess() || PrefixedIdentifier() || ExpressionStatement() => false,
      // A write to the variable, like `x = Timer(...)`.
      AssignmentExpression(:var leftHandSide) when leftHandSide == reference => false,
      // Null checks, like `if (x != null)`, and string interpolation don't keep it.
      BinaryExpression() || IsExpression() || InterpolationExpression() => false,
      // Passed to `setProp` or to another function, returned, assigned to another
      // variable, or added to a collection.
      _ => true,
    };
    if (keeps) kept.add(variable);
  }
}

/// Returns true if [type] is a `Stream`, or a subtype of it.
bool _isStream(DartType? type) =>
    type is InterfaceType &&
    (_isAsyncClass(type.element, 'Stream') ||
        type.element.allSupertypes.any(
          (candidate) => _isAsyncClass(candidate.element, 'Stream'),
        ));

bool _isAsyncClass(Element? element, String name) =>
    element is InterfaceElement && element.name == name && element.library.isDartAsync;
