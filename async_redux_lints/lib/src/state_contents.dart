import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/workspace/workspace.dart';

import 'base_classes.dart';
import 'redux_types.dart';
import 'source_text.dart';
import 'state_class_utils.dart';

/// A field of a class that holds state, as seen by the state contents rules.
class StateField {
  /// The class or mixin that declares the field.
  final InterfaceElement owner;

  final VariableDeclaration declaration;
  final FieldElement element;

  /// The declared type of the field, or null if it's inferred.
  final TypeAnnotation? typeAnnotation;

  StateField(this.owner, this.declaration, this.element, this.typeAnnotation);

  String get name => declaration.name.lexeme;
}

final _stateFieldsCache = Expando<List<StateField>>();

/// Returns the instance fields declared in [unit] by classes and mixins that hold
/// state. See [stateClassesIn]. Computed once for each unit, and shared by the rules.
List<StateField> stateFieldsIn(CompilationUnit unit, RuleContext context) =>
    _stateFieldsCache[unit] ??= _computeStateFields(unit, context);

List<StateField> _computeStateFields(CompilationUnit unit, RuleContext context) {
  // Most files don't declare fields, so this avoids looking for the state classes.
  var declarations = [
    for (var declaration in unit.declarations)
      if (_withInstanceFields(declaration) case var found?) found,
  ];
  if (declarations.isEmpty) return const [];
  var stateClasses = stateClassesIn(unit, context, {
    for (var (element, _) in declarations) element,
  });
  if (stateClasses.isEmpty) return const [];

  var result = <StateField>[];
  for (var (element, members) in declarations) {
    if (!stateClasses.contains(element)) continue;
    for (var member in members) {
      if (member is! FieldDeclaration || member.isStatic) continue;
      for (var variable in member.fields.variables) {
        var field = variable.declaredFragment?.element;
        if (field is! FieldElement) continue;
        result.add(StateField(element, variable, field, member.fields.type));
      }
    }
  }
  return result;
}

/// Returns the element and the members of [declaration], if it's a class or mixin
/// that declares instance fields. Otherwise, returns null.
(InterfaceElement, List<ClassMember>)? _withInstanceFields(
  CompilationUnitMember declaration,
) {
  var (element, members) = switch (declaration) {
    ClassDeclaration(:var declaredFragment, :var body) => (
      declaredFragment?.element,
      body.members,
    ),
    MixinDeclaration(:var declaredFragment, :var body) => (
      declaredFragment?.element,
      body.members,
    ),
    _ => (null, null),
  };
  if (element == null || members == null) return null;
  if (!members.any((member) => member is FieldDeclaration && !member.isStatic)) {
    return null;
  }
  return (element, members);
}

/// Returns the classes and mixins that hold state, as far as they can be seen from
/// [unit]. These are:
///
/// - State classes, annotated with `@stateClass`, and the classes that inherit from
///   them. See [isStateClass].
///
/// - The store's state class, when [unit], or a library of the package it imports,
///   uses it as the `St` of an action, like `ReduxAction<AppState>`, or of a `Store`.
///
/// - The classes of the package that the classes above contain, directly or
///   indirectly, as the type of a field, or a type argument of it, like `User` in
///   `IList<User> users`. Also the classes of the package they inherit from.
///
/// Rules see one file at a time, so a class like `User` is only known to hold state
/// when its file also declares, or imports, the class that contains it.
///
/// Only the classes of [declared], which are declared in [unit], matter to the
/// caller. Finding the `Store` types of [unit] means visiting the whole unit, so they
/// are only searched when they can change the result for [declared]: when some of
/// [declared] don't hold state otherwise, and [unit] may refer to `Store`.
Set<InterfaceElement> stateClassesIn(
  CompilationUnit unit,
  RuleContext context,
  Set<InterfaceElement> declared,
) {
  var library = context.libraryElement;
  if (library == null) return const {};
  var package = context.package;

  var isOwnLibrary = <LibraryElement, bool>{};
  bool isOwnClass(InterfaceElement element) {
    if (isFromAsyncRedux(element)) return false;
    if (package == null) return element.library == library;
    return isOwnLibrary[element.library] ??= package.contains(
      element.library.firstFragment.source,
    );
  }

  var result = <InterfaceElement>{};

  /// Adds [roots] to the result, and the classes they contain or inherit from.
  void addWithContents(List<InterfaceElement> roots) {
    var pending = roots;
    while (pending.isNotEmpty) {
      var element = pending.removeLast();
      if (!result.add(element)) continue;
      for (var inherited in inheritedClasses(element)) {
        if (isOwnClass(inherited)) pending.add(inherited);
      }
      for (var field in element.fields) {
        if (field.isStatic || field.isOriginGetterSetter) continue;
        for (var type in interfaceTypesIn(field.type)) {
          if (isOwnClass(type.element)) pending.add(type.element);
        }
      }
    }
  }

  addWithContents([
    for (var declaration in unit.declarations)
      if (declaration case ClassDeclaration(
        :var declaredFragment,
      ) when declaredFragment != null && isStateClass(declaredFragment.element))
        declaredFragment.element
      else if (declaration case MixinDeclaration(
        :var declaredFragment,
      ) when declaredFragment != null && isStateClass(declaredFragment.element))
        declaredFragment.element,
    for (var type in _visibleActionStateTypes(library, package))
      if (isOwnClass(type.element)) type.element,
  ]);

  // More roots can only add classes, and the ones already in the result already have
  // their contents in it.
  if (!declared.every(result.contains) && _mayReferToStore(unit, context, library)) {
    addWithContents([
      for (var type in _storeStateTypesIn(unit))
        if (isOwnClass(type.element)) type.element,
    ]);
  }
  return result;
}

/// The [_visibleActionStateTypes] of each library, shared by its units.
final _visibleActionStateTypesCache = Expando<List<InterfaceType>>();

/// Returns the `St` types of the actions declared in [library], or in the libraries of
/// [package] that it imports.
List<InterfaceType> _visibleActionStateTypes(
  LibraryElement library,
  WorkspacePackage? package,
) => _visibleActionStateTypesCache[library] ??= [
  for (var visible in visiblePackageLibraries(library, package))
    ..._actionStateTypes(visible),
];

/// Returns the `St` types of the `Store` types and `Store` creations in [unit].
List<InterfaceType> _storeStateTypesIn(CompilationUnit unit) {
  var collector = _StoreTypeCollector();
  unit.accept(collector);
  return collector.stateTypes;
}

/// Returns true if [unit] may refer to the `Store` class of AsyncRedux: its text uses
/// the name `Store`, or [library], or a library it imports, declares a type alias of
/// `Store`, which has another name.
bool _mayReferToStore(
  CompilationUnit unit,
  RuleContext context,
  LibraryElement library,
) =>
    mayContainName(context, unit, 'Store') ||
    library.typeAliases.any(_aliasesStore) ||
    library.fragments.any(
      (fragment) => fragment.libraryImports.any((import) {
        var imported = import.importedLibrary;
        return imported != null && _exportsStoreAlias(imported);
      }),
    );

/// Whether each library exports a type alias of `Store`. The libraries imported by the
/// file being analyzed usually don't change, so each one is only checked once.
final _exportsStoreAliasCache = Expando<bool>();

bool _exportsStoreAlias(LibraryElement library) =>
    _exportsStoreAliasCache[library] ??= library.exportNamespace.definedNames2.values.any(
      (element) => element is TypeAliasElement && _aliasesStore(element),
    );

bool _aliasesStore(TypeAliasElement alias) =>
    isAsyncReduxClass(alias.aliasedType, 'Store');

/// The [_actionStateTypes] of each library. The libraries imported by the file being
/// analyzed usually don't change, and keep their elements between analyses, so their
/// actions are only checked once. When a file changes, the analyzer creates new
/// elements for its library, so the cached values of the old elements are not used
/// anymore.
final _actionStateTypesCache = Expando<List<InterfaceType>>();

/// Returns the `St` types of the actions declared in [library].
List<InterfaceType> _actionStateTypes(LibraryElement library) =>
    _actionStateTypesCache[library] ??= [
      for (var element in library.classes)
        if (reduxActionSupertype(element)?.typeArguments.firstOrNull
            case InterfaceType stateType)
          stateType,
    ];

/// Returns [type], and the types it contains as type arguments or record fields, that
/// are interface types. Function types are not searched, since a function that takes
/// or returns a value doesn't hold it.
Iterable<InterfaceType> interfaceTypesIn(DartType type) sync* {
  switch (type) {
    case InterfaceType():
      yield type;
      for (var argument in type.typeArguments) {
        yield* interfaceTypesIn(argument);
      }
    case RecordType():
      for (var field in type.positionalFields) {
        yield* interfaceTypesIn(field.type);
      }
      for (var field in type.namedFields) {
        yield* interfaceTypesIn(field.type);
      }
    default:
      break;
  }
}

/// Returns true if [type] is the class [name] of package `async_redux`.
bool isAsyncReduxClass(DartType? type, String name) =>
    type is InterfaceType && type.element.name == name && isFromAsyncRedux(type.element);

/// Collects the `St` of the `Store<St>` types and `Store` creations in a unit.
class _StoreTypeCollector extends RecursiveAstVisitor<void> {
  final stateTypes = <InterfaceType>[];

  @override
  void visitNamedType(NamedType node) {
    _add(node.type);
    super.visitNamedType(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _add(node.staticType);
    super.visitInstanceCreationExpression(node);
  }

  void _add(DartType? type) {
    if (!isAsyncReduxClass(type, 'Store')) return;
    var stateType = (type as InterfaceType).typeArguments.firstOrNull;
    if (stateType is InterfaceType) stateTypes.add(stateType);
  }
}
