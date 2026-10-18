import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/workspace/workspace.dart';

import '../package_files.dart';
import '../redux_types.dart';
import '../state_class_utils.dart';
import '../state_contents.dart';
import 'state_class_must_be_immutable_rule.dart';
import 'state_contents_rules.dart';

/// Reports a class of the package that should be annotated with `@stateClass`, but
/// isn't. The rules that check state classes, like [StateClassMustBeImmutableRule],
/// only check the annotated classes, so these classes are not checked otherwise:
///
/// - The store's state class, like `AppState`. Reported at its declaration, when the
///   file sees an action that uses it, like `ReduxAction<AppState>`, and at the
///   creation of the store, like `Store<AppState>(...)`, when the class is declared
///   in another library.
///
/// - The classes held by the fields of a state class, like `User` in
///   `final IList<User> users`. Reported at the field. Since the rule checks the
///   fields of the annotated classes, annotating a class shows the classes that its
///   own fields hold, until the whole state is annotated.
///
/// Classes from the SDK and from other packages are not reported, since they can't be
/// annotated. Neither are enums, extension types, or classes that are not state, like
/// a `ChangeNotifier`, reported by [NonStateObjectInStateRule]. Not reported in
/// tests.
class MissingStateClassRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'missing_state_class',
    '{0}',
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.WARNING,
  );

  MissingStateClassRule()
    : super(
        name: 'missing_state_class',
        description:
            "The store's state class, and the classes that the fields of state "
            "classes hold, should be annotated with '@stateClass'.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    if (isTestLibrary(context)) return;
    var library = context.libraryElement;
    if (library == null) return;
    var visitor = _Visitor(this, library, context.package);
    registry.addCompilationUnit(this, visitor);
    registry.addInstanceCreationExpression(this, visitor);
  }
}

/// Returns true if [element] is declared in [package], or in [library] when there's
/// no package, and is not part of AsyncRedux.
bool isOwnClass(
  InterfaceElement element, {
  required LibraryElement library,
  required WorkspacePackage? package,
}) {
  if (isFromAsyncRedux(element)) return false;
  if (package == null) return element.library == library;
  return isInPackage(element.library, package);
}

/// Returns true if [element] is the state of a store, and should be annotated with
/// `@stateClass`, but isn't. [isOwn] says if a class is declared in the package.
bool isStoreStateMissingStateClass(
  InterfaceElement element,
  bool Function(InterfaceElement) isOwn,
) => element is ClassElement && isOwn(element) && !isStateClass(element);

/// Returns the `St` class of [type], if it's `Store<St>`. Otherwise, returns null.
InterfaceElement? storeStateClassOf(DartType? type) {
  if (!isAsyncReduxClass(type, 'Store')) return null;
  var stateType = (type as InterfaceType).typeArguments.firstOrNull;
  return (stateType is InterfaceType) ? stateType.element : null;
}

/// Returns the classes held by [field] that should be annotated with `@stateClass`,
/// but aren't, in the order they appear in its type. [isOwn] says if a class is
/// declared in the package.
List<InterfaceElement> classesMissingStateClassIn(
  FieldElement field,
  bool Function(InterfaceElement) isOwn,
) => {
  for (var type in interfaceTypesIn(field.type))
    if (_shouldBeStateClass(type, isOwn)) type.element,
}.toList();

bool _shouldBeStateClass(InterfaceType type, bool Function(InterfaceElement) isOwn) {
  var element = type.element;
  return (element is ClassElement || element is MixinElement) &&
      isOwn(element) &&
      !isStateClass(element) &&
      !NonStateObjectInStateRule.isNonStateType(type);
}

class _Visitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final LibraryElement library;
  final WorkspacePackage? package;

  _Visitor(this.rule, this.library, this.package);

  /// The state classes of the actions that this library sees. They are reported where
  /// they're declared.
  late final Set<InterfaceElement> _actionStates = {
    for (var type in visibleActionStateTypes(library, package)) type.element,
  };

  bool _isOwn(InterfaceElement element) =>
      isOwnClass(element, library: library, package: package);

  @override
  void visitCompilationUnit(CompilationUnit node) {
    for (var declaration in node.declarations) {
      var (element, members, name) = switch (declaration) {
        ClassDeclaration(:var declaredFragment, :var body, :var namePart) => (
          declaredFragment?.element,
          body.members,
          namePart.typeName,
        ),
        MixinDeclaration(:var declaredFragment, :var body, :var name) => (
          declaredFragment?.element,
          body.members,
          name,
        ),
        _ => (null, null, null),
      };
      if (element == null || members == null || name == null) continue;

      if (isStateClass(element)) {
        _checkFields(element, members);
      } else if (_actionStates.contains(element) &&
          isStoreStateMissingStateClass(element, _isOwn)) {
        rule.reportAtToken(name, arguments: _storeStateArguments(element));
      }
    }
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    var state = storeStateClassOf(node.staticType);
    if (state == null || !isStoreStateMissingStateClass(state, _isOwn)) return;
    // Already reported at the declaration of the class.
    if (state.library == library && _actionStates.contains(state)) return;
    rule.reportAtNode(node.constructorName, arguments: _storeStateArguments(state));
  }

  static List<String> _storeStateArguments(InterfaceElement state) {
    var name = state.displayName;
    return [
      "The store's state class '$name' isn't annotated with '@stateClass'.",
      "Try annotating '$name' with '@stateClass', so that it's checked as state.",
    ];
  }

  void _checkFields(InterfaceElement owner, List<ClassMember> members) {
    for (var member in members) {
      if (member is! FieldDeclaration || member.isStatic) continue;
      for (var variable in member.fields.variables) {
        var field = variable.declaredFragment?.element;
        if (field is! FieldElement) continue;
        var missing = classesMissingStateClassIn(field, _isOwn);
        if (missing.isEmpty) continue;
        var names = joinNames([for (var element in missing) element.displayName]);
        var isSingle = missing.length == 1;
        rule.reportAtToken(
          variable.name,
          arguments: [
            "The field '${variable.name.lexeme}' of the state class "
                "'${owner.displayName}' holds $names, which "
                "${isSingle ? "isn't" : "aren't"} annotated with '@stateClass'.",
            "Try annotating $names with '@stateClass', so that "
                "${isSingle ? "it's" : "they're"} checked as state.",
          ],
        );
      }
    }
  }
}
