import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

import '../names.dart';
import '../package_files.dart';
import '../redux_types.dart';

/// Returns true if [type] is the `Event` class of package `async_redux` (also
/// available as `Evt`), or a subclass of it.
///
/// Called for every field, so it uses the supertypes of the element, which the
/// analyzer caches, and not the ones of the type, which it creates on each call.
bool isEventType(DartType? type) =>
    type is InterfaceType &&
    (_isEventClass(type.element) ||
        type.element.allSupertypes.any((supertype) => _isEventClass(supertype.element)));

bool _isEventClass(InterfaceElement element) =>
    element.name == 'Event' && isFromAsyncRedux(element);

/// Returns true if [node] creates an event that is not spent, like `Evt()`,
/// `Evt('text')` or `Event<int>(42)`. Returns false for `Evt.spent()`.
bool isNotSpentEventCreation(InstanceCreationExpression node) {
  var constructor = node.constructorName.element?.baseElement;
  return constructor != null &&
      constructor.name == 'new' &&
      constructor.enclosingElement.name == 'Event' &&
      isFromAsyncRedux(constructor);
}

/// Returns true if [name], not counting leading underscores, follows the docs: it
/// ends with `Evt`, like `clearTextEvt`, or it's just `evt`.
bool hasEventName(String name) =>
    name.endsWith('Evt') ||
    (name.endsWith('evt') && name.length - leadingUnderscores(name) == 3);

/// Returns the name that the docs would give to an event field named [name]. For
/// example, `clearTextEvt` for `clearText` and for `clearTextEvent`.
String suggestedEventName(String name) {
  var underscores = name.substring(0, leadingUnderscores(name));
  var base = name.substring(underscores.length);
  if (base == 'event') return '${underscores}evt';
  if (base.endsWith('Event')) {
    return '$underscores${base.substring(0, base.length - 'Event'.length)}Evt';
  }
  return '$underscores${base}Evt';
}

/// Reports a field of type `Evt` or `Event` whose name doesn't end with `Evt`. The
/// docs name events like `clearTextEvt`.
///
/// Checks the fields of all classes, since events are also kept in view-models and
/// in widgets. A field that overrides an inherited member is not reported, since its
/// name comes from the supertype, where it's reported.
class EventNameSuffixRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'event_name_suffix',
    "The name of the event field '{0}' should end with 'Evt'.",
    correctionMessage: "Try renaming it to '{1}'.",
    severity: DiagnosticSeverity.INFO,
  );

  EventNameSuffixRule()
    : super(
        name: 'event_name_suffix',
        description: "The name of a field of type 'Evt' should end with 'Evt'.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addFieldDeclaration(this, _EventNameVisitor(this));
  }
}

class _EventNameVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _EventNameVisitor(this.rule);

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    if (node.isStatic) return;
    for (var variable in node.fields.variables) {
      var field = variable.declaredFragment?.element;
      if (field is! FieldElement || !isEventType(field.type)) continue;
      var name = variable.name.lexeme;
      if (hasEventName(name) || _overridesInheritedMember(field)) continue;
      rule.reportAtToken(variable.name, arguments: [name, suggestedEventName(name)]);
    }
  }

  static bool _overridesInheritedMember(FieldElement field) {
    var enclosing = field.enclosingElement;
    if (enclosing is! InterfaceElement) return false;
    var name = field.name;
    if (name == null) return false;
    return enclosing.allSupertypes.any(
      (type) => type.getGetter(name) != null || type.getSetter(name) != null,
    );
  }
}

/// Reports an event created with `Evt()` or `Evt(value)` for the initial state: in an
/// `initialState()` method, in the `initialState:` argument of a `Store`, in a
/// constructor (like `clearTextEvt = clearTextEvt ?? Evt()`), or in the initializer of
/// an instance field. Initial events must be spent, with `Evt.spent()`, or they fire as
/// soon as the app starts.
///
/// Not reported in tests, which may create a state with an event on purpose, to test
/// how the widgets react to it.
class EventNotSpentInitiallyRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'event_not_spent_initially',
    "This event is created {0}, but it's not spent. It will fire as soon as the app "
        "starts.",
    correctionMessage: "Try using 'Evt.spent()'.",
    severity: DiagnosticSeverity.WARNING,
  );

  EventNotSpentInitiallyRule()
    : super(
        name: 'event_not_spent_initially',
        description: "Events of the initial state must be created with 'Evt.spent()'.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addInstanceCreationExpression(this, _NotSpentVisitor(this, context));
  }
}

class _NotSpentVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _NotSpentVisitor(this.rule, this.context);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!isNotSpentEventCreation(node)) return;
    var where = _initialPlace(node);
    if (where != null && !_isTestFile()) rule.reportAtNode(node, arguments: [where]);
  }

  bool _isTestFile() {
    var file = context.currentUnit?.file;
    if (file == null) return false;
    return isInTestDirectory(context.package, file) ||
        file.shortName.endsWith('_test.dart');
  }

  /// Returns where [node] creates an initial event, like `in 'initialState'`, or null
  /// if it doesn't. Closures are not followed, since they run later.
  static String? _initialPlace(AstNode node) {
    for (AstNode? ancestor = node.parent; ancestor != null; ancestor = ancestor.parent) {
      switch (ancestor) {
        case FunctionExpression() when ancestor.parent is! FunctionDeclaration:
          return null;
        case NamedArgument(name: Token(lexeme: 'initialState'))
            when ancestor.parent is ArgumentList:
          return "for the 'initialState' argument";
        case MethodDeclaration(name: var name) || FunctionDeclaration(name: var name):
          return name.lexeme == 'initialState' ? "in 'initialState'" : null;
        case ConstructorDeclaration(:var name):
          return name?.lexeme == 'initialState'
              ? "in 'initialState'"
              : 'in a constructor';
        case VariableDeclaration(parent: VariableDeclarationList(:var parent))
            when parent is FieldDeclaration:
          return parent.isStatic ? null : 'in a field initializer';
        case ClassMember() || CompilationUnitMember():
          return null;
      }
    }
    return null;
  }
}

/// Reports an event field used in a `toJson` or `toMap` method, or in the
/// `persistDifference` or `saveInitialState` method of a `Persistor`. The docs say
/// events must not be persisted.
class EventPersistedRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'event_persisted',
    "The event '{0}' is used in '{1}'. Events must not be persisted.",
    correctionMessage:
        "Try removing it. When the state is read back, create the event with "
        "'Evt.spent()'.",
    severity: DiagnosticSeverity.WARNING,
  );

  EventPersistedRule()
    : super(name: 'event_persisted', description: "Events must not be persisted.");

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addMethodDeclaration(this, _PersistedVisitor(this));
  }
}

class _PersistedVisitor extends SimpleAstVisitor<void> {
  static const _serializationMethods = {'toJson', 'toMap'};
  static const _persistorMethods = {'persistDifference', 'saveInitialState'};

  final AnalysisRule rule;

  _PersistedVisitor(this.rule);

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.isStatic) return;
    var name = node.name.lexeme;
    if (!_serializationMethods.contains(name)) {
      if (!_persistorMethods.contains(name)) return;
      var enclosing = node.declaredFragment?.element.enclosingElement;
      if (enclosing is! InterfaceElement || !_isPersistor(enclosing)) return;
    }
    node.body.accept(_EventFieldFinder(rule, name));
  }

  static bool _isPersistor(InterfaceElement element) => element.allSupertypes.any(
    (type) => type.element.name == 'Persistor' && isFromAsyncRedux(type.element),
  );
}

class _EventFieldFinder extends RecursiveAstVisitor<void> {
  final AnalysisRule rule;
  final String methodName;

  _EventFieldFinder(this.rule, this.methodName);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    var element = node.element?.baseElement;
    if (element is GetterElement &&
        !element.isStatic &&
        element.enclosingElement is InterfaceElement &&
        isEventType(element.returnType)) {
      rule.reportAtNode(node, arguments: [node.name, methodName]);
    }
  }
}
