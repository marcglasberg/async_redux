import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

import '../package_files.dart';
import '../redux_types.dart';
import '../source_text.dart';
import 'dispatch_sync_async_action_rule.dart';

/// Reports, in code under `test/`, a `store.dispatch(action);` statement of an async
/// action, followed by an `expect` that reads `store.state`, without waiting in
/// between. The `expect` then checks the state before the action finishes.
///
/// Any `await` counts as waiting, since it can't tell what's being waited for. So do
/// the `elapse`, `flushMicrotasks` and `flushTimers` calls of `fakeAsync`. An `expect`
/// inside a closure is ignored, since it may run later.
///
/// Not reported when the test later waits, and checks `store.state` again. The first
/// `expect` then checks the state while the action runs, on purpose. For example, to
/// check that the state didn't change yet.
class ExpectWithoutWaitingRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'expect_without_waiting',
    "'{0}' is async, but '{1}.state' is checked below without waiting for the action "
        "to finish.",
    correctionMessage:
        "Try using 'await {1}.dispatchAndWait(...)' instead, or waiting for the action "
        "before the 'expect'.",
    severity: DiagnosticSeverity.WARNING,
  );

  ExpectWithoutWaitingRule()
    : super(
        name: 'expect_without_waiting',
        description:
            "In tests, wait for an async action to finish before checking the state.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    if (!isLibraryInTestDirectory(context)) return;
    var library = context.libraryElement;
    if (library == null) return;
    registry.addMethodInvocation(this, _ExpectWithoutWaitingVisitor(this, library));
  }
}

class _ExpectWithoutWaitingVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final LibraryElement library;

  _ExpectWithoutWaitingVisitor(this.rule, this.library);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    var statement = unwaitedStoreDispatchStatement(node);
    if (statement == null) return;

    var action = actionArgument(node.argumentList);
    if (action == null) return;
    var actionType = action.staticType as InterfaceType;
    if (actionAsyncReason(actionType, library) == null) return;

    var store = node.realTarget!.toSource();
    if (!_checksStateWithoutWaiting(statement, store)) return;

    rule.reportAtNode(node, arguments: [actionType.element.displayName, store]);
  }

  /// Returns true if the first event after [statement] is an `expect` that reads
  /// `[store].state`, and the test doesn't later wait, and check the state again,
  /// which means the first check is on purpose.
  ///
  /// The events are the waits, and the `expect` calls that read `[store].state`, in
  /// the statements that follow [statement] in its block, and then in the statements
  /// that follow each enclosing statement, up to the function body. The search stops
  /// as soon as the result is known.
  static bool _checksStateWithoutWaiting(Statement statement, String store) {
    var collector = _EventCollector(store);
    AstNode current = statement;
    while (!collector.isDone) {
      var parent = current.parent;
      if (parent is Block) {
        var statements = parent.statements;
        var index = statements.indexOf(current as Statement);
        for (var following in statements.skip(index + 1)) {
          following.accept(collector);
          if (collector.isDone) break;
        }
      }
      if (parent is! Statement) break;
      current = parent;
    }
    return collector.checksStateWithoutWaiting;
  }
}

/// Returns the statement of [node] if [node] is `store.dispatch(...)`, with a `Store`
/// of AsyncRedux, used as a statement on its own, without `await`. Otherwise, returns
/// null.
ExpressionStatement? unwaitedStoreDispatchStatement(MethodInvocation node) {
  if (node.methodName.name != 'dispatch') return null;
  var targetType = node.realTarget?.staticType;
  if (targetType is! InterfaceType || !_isStore(targetType.element)) return null;

  AstNode expression = node;
  while (expression.parent is ParenthesizedExpression) {
    expression = expression.parent!;
  }
  var statement = expression.parent;
  return (statement is ExpressionStatement && statement.parent is Block)
      ? statement
      : null;
}

bool _isStore(Element element) =>
    element is InterfaceElement && element.name == 'Store' && isFromAsyncRedux(element);

/// What the events seen so far by an [_EventCollector] mean.
enum _Events {
  /// No events yet.
  none,

  /// The first event is an `expect`, and there was no wait after it yet.
  expectFirst,

  /// The first event is an `expect`, and there was a wait after it.
  waitAfterExpect,

  /// Not reported, whatever comes next. Either the first event is a wait, or the test
  /// waits after the first `expect`, and checks the state again.
  notReported,
}

/// Visits, in the order they run, the waits, and the `expect` calls that read
/// `[store].state`. Doesn't look inside closures. Stops visiting when [isDone].
class _EventCollector extends GeneralizingAstVisitor<void> {
  /// The methods of `FakeAsync` that let time pass.
  static const _fakeAsyncWaits = {'elapse', 'flushMicrotasks', 'flushTimers'};

  final String store;
  var _events = _Events.none;

  _EventCollector(this.store);

  /// True if more events can't change [checksStateWithoutWaiting].
  bool get isDone => _events == _Events.notReported;

  /// True if the first event is an `expect`, and no `expect` follows a wait after it.
  bool get checksStateWithoutWaiting =>
      _events == _Events.expectFirst || _events == _Events.waitAfterExpect;

  void _wait() {
    _events = switch (_events) {
      _Events.none => _Events.notReported,
      _Events.expectFirst => _Events.waitAfterExpect,
      var events => events,
    };
  }

  void _expect() {
    _events = switch (_events) {
      _Events.none => _Events.expectFirst,
      _Events.waitAfterExpect => _Events.notReported,
      var events => events,
    };
  }

  @override
  void visitNode(AstNode node) {
    if (!isDone) super.visitNode(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {}

  @override
  void visitFunctionDeclarationStatement(FunctionDeclarationStatement node) {}

  @override
  void visitAwaitExpression(AwaitExpression node) {
    super.visitAwaitExpression(node);
    _wait();
  }

  @override
  void visitForStatement(ForStatement node) {
    if (node.awaitKeyword != null) _wait();
    super.visitForStatement(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);
    if (isDone) return;
    var name = node.methodName.name;
    if (node.target != null && _fakeAsyncWaits.contains(name)) {
      _wait();
    } else if (node.target == null && name == 'expect') {
      var finder = _StateReadFinder(store);
      node.argumentList.accept(finder);
      if (finder.readsState) _expect();
    }
  }
}

/// Finds reads of `[store].state`.
class _StateReadFinder extends RecursiveAstVisitor<void> {
  final String store;
  bool readsState = false;

  _StateReadFinder(this.store);

  @override
  void visitFunctionExpression(FunctionExpression node) {}

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.identifier.name == 'state' && node.prefix.toSource() == store) {
      readsState = true;
    }
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (node.propertyName.name == 'state' && node.realTarget.toSource() == store) {
      readsState = true;
    }
    super.visitPropertyAccess(node);
  }
}

/// Reports `Vm.createFrom(store, factory)` when the same factory instance was already
/// passed to `Vm.createFrom`. A factory can only be used once, so the second call
/// throws.
///
/// Only checks factories in variables. A variable that is never assigned holds the
/// same factory everywhere it's used. A variable that is assigned, like in `setUp`, is
/// only checked between two calls in the same function, with no assignment between
/// them. Calls in different branches of an `if`, `?:` or `switch` are not reported.
class VmCreateFromReusedFactoryRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'vm_create_from_reused_factory',
    "The factory '{0}' was already used by 'Vm.createFrom', but each factory instance "
        "can only be used once.",
    correctionMessage: "Try creating a new factory for each 'Vm.createFrom' call.",
    severity: DiagnosticSeverity.ERROR,
  );

  VmCreateFromReusedFactoryRule()
    : super(
        name: 'vm_create_from_reused_factory',
        description: "'Vm.createFrom' can only be called once per factory instance.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addCompilationUnit(this, _VmCreateFromVisitor(this, context));
  }
}

class _VmCreateFromVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _VmCreateFromVisitor(this.rule, this.context);

  @override
  void visitCompilationUnit(CompilationUnit node) {
    // The collector visits the whole unit, which isn't needed in the files that don't
    // call `createFrom`.
    if (!mayContainName(context, node, 'createFrom')) return;
    var collector = _CreateFromCollector();
    node.accept(collector);

    for (var MapEntry(key: variable, value: factories) in collector.factories.entries) {
      var assignments = collector.assignments[variable] ?? const <int>[];
      for (var i = 1; i < factories.length; i++) {
        var factory = factories[i];
        var isReused = factories
            .take(i)
            .any(
              (previous) =>
                  !_inExclusiveBranches(previous, factory) &&
                  (assignments.isEmpty ||
                      _sameFunctionWithoutAssignment(previous, factory, assignments)),
            );
        if (isReused) rule.reportAtNode(factory, arguments: [factory.name]);
      }
    }
  }

  /// Returns true if [a] and [b] are in the same function body, and no offset in
  /// [assignments] is between them.
  static bool _sameFunctionWithoutAssignment(
    AstNode a,
    AstNode b,
    List<int> assignments,
  ) =>
      a.thisOrAncestorOfType<FunctionBody>() == b.thisOrAncestorOfType<FunctionBody>() &&
      !assignments.any((offset) => offset > a.offset && offset < b.offset);

  /// Returns true if [a] and [b] are in different branches of the same `if`, `?:`,
  /// or `switch`, so they can't both run.
  static bool _inExclusiveBranches(AstNode a, AstNode b) {
    var ancestorsOfA = <AstNode, AstNode>{}; // Ancestor -> its child containing [a].
    for (AstNode? child = a, parent = a.parent; parent != null; parent = parent.parent) {
      ancestorsOfA[parent] = child!;
      child = parent;
    }
    AstNode? childOfB = b;
    var common = b.parent;
    while (common != null && !ancestorsOfA.containsKey(common)) {
      childOfB = common;
      common = common.parent;
    }
    if (common == null) return false;
    var childOfA = ancestorsOfA[common];

    bool areBranches(AstNode? first, AstNode? second) =>
        (childOfA == first && childOfB == second) ||
        (childOfA == second && childOfB == first);

    return switch (common) {
      IfStatement() => areBranches(common.thenStatement, common.elseStatement),
      IfElement() => areBranches(common.thenElement, common.elseElement),
      ConditionalExpression() => areBranches(
        common.thenExpression,
        common.elseExpression,
      ),
      SwitchStatement() || SwitchExpression() =>
        childOfA != childOfB &&
            (childOfA is SwitchMember || childOfA is SwitchExpressionCase) &&
            (childOfB is SwitchMember || childOfB is SwitchExpressionCase),
      _ => false,
    };
  }
}

/// Collects the factory arguments of `Vm.createFrom` calls that are variables, and
/// the offsets of the assignments to those variables.
class _CreateFromCollector extends RecursiveAstVisitor<void> {
  final factories = <Element, List<SimpleIdentifier>>{};
  final assignments = <Element, List<int>>{};

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (isVmCreateFrom(node)) {
      var arguments = node.argumentList.arguments.whereType<Expression>().toList();
      var factory = (arguments.length >= 2) ? arguments[1].unParenthesized : null;
      if (factory is SimpleIdentifier) {
        var variable = _variable(factory.element);
        if (variable != null) (factories[variable] ??= []).add(factory);
      }
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    var variable = _variable(node.writeElement);
    if (variable != null) (assignments[variable] ??= []).add(node.offset);
    super.visitAssignmentExpression(node);
  }

  /// Returns the variable of [element], or null if [element] is not a variable, or
  /// is a getter declared explicitly, which may return a new factory each time.
  static Element? _variable(Element? element) => switch (element) {
    PropertyAccessorElement(isOriginVariable: true) => element.variable.baseElement,
    LocalVariableElement() || FormalParameterElement() => element!.baseElement,
    _ => null,
  };
}

/// Returns true if [node] calls `Vm.createFrom` of AsyncRedux.
bool isVmCreateFrom(MethodInvocation node) {
  if (node.methodName.name != 'createFrom') return false;
  var element = node.methodName.element;
  if (element is! MethodElement || !element.isStatic) return false;
  var enclosing = element.enclosingElement;
  return enclosing is InterfaceElement &&
      enclosing.name == 'Vm' &&
      isFromAsyncRedux(enclosing);
}

/// Reports, in code under `lib/`, the use of `hasFinishedMethodBefore`,
/// `hasFinishedMethodReduce` or `hasFinishedMethodAfter` of `ActionStatus`. The docs
/// say these are meant for tests and debugging.
class ActionStatusDetailsInProductionRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'action_status_details_in_production',
    "'{0}' is meant for tests and debugging.",
    correctionMessage:
        "Try using 'isCompleted', 'isCompletedOk' or 'isCompletedFailed' instead.",
    severity: DiagnosticSeverity.INFO,
  );

  static const _names = {
    'hasFinishedMethodBefore',
    'hasFinishedMethodReduce',
    'hasFinishedMethodAfter',
  };

  ActionStatusDetailsInProductionRule()
    : super(
        name: 'action_status_details_in_production',
        description:
            "The 'hasFinishedMethod...' getters of 'ActionStatus' are meant for tests "
            "and debugging.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    if (!isLibraryInLibDir(context)) return;
    // AsyncRedux itself sets and reads them.
    var library = context.libraryElement;
    if (library == null || isFromAsyncRedux(library)) return;
    registry.addSimpleIdentifier(this, _ActionStatusDetailsVisitor(this));
  }
}

class _ActionStatusDetailsVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _ActionStatusDetailsVisitor(this.rule);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (!ActionStatusDetailsInProductionRule._names.contains(node.name)) return;
    var element = node.element;
    if (element is! GetterElement) return;
    var enclosing = element.enclosingElement;
    if (enclosing is! InterfaceElement ||
        enclosing.name != 'ActionStatus' ||
        !isFromAsyncRedux(enclosing)) {
      return;
    }
    rule.reportAtNode(node, arguments: [node.name]);
  }
}
