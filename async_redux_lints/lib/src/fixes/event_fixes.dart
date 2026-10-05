import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

import '../package_search.dart';
import '../rules/event_rules.dart';

/// Replaces `Evt()` or `Evt(value)` with `Evt.spent()`.
///
/// When the type argument of the event is inferred from its value, like `int` in
/// `Evt(42)`, it's written explicitly, as in `Evt<int>.spent()`, since `Evt.spent()`
/// has no value to infer it from.
class UseSpentEvent extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'async_redux_lints.fix.useSpentEvent',
    DartFixKindPriority.standard,
    "Use 'Evt.spent()'",
  );

  UseSpentEvent({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.automatically;

  @override
  FixKind get fixKind => _kind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var creation = node.thisOrAncestorOfType<InstanceCreationExpression>();
    if (creation == null || !isNotSpentEventCreation(creation)) return;
    var namedType = creation.constructorName.type;
    var type = creation.staticType;
    var typeArguments = (namedType.typeArguments == null && type is InterfaceType)
        ? type.typeArguments.where((type) => type is! DynamicType).toList()
        : const <DartType>[];

    await builder.addDartFileEdit(file, (builder) {
      builder.addReplacement(range.endEnd(namedType, creation), (builder) {
        if (typeArguments.isNotEmpty) {
          builder.write('<');
          builder.writeTypes(typeArguments);
          builder.write('>');
        }
        builder.write('.spent()');
      });
    });
  }
}

/// Renames an event field to end with `Evt`, in all files of the package.
///
/// Also renames the named parameters of the same class that have the same name as the
/// field, like `this.clearText` in the constructor and `clearText` in `copy()`, so that
/// the named arguments keep matching the field.
///
/// Not offered when the class already has a member with the new name, or when the
/// package can't be searched.
class RenameEvent extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'async_redux_lints.fix.renameEvent',
    DartFixKindPriority.standard,
    "Rename to '{0}'",
  );

  String _newName = '';

  RenameEvent({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  List<String> get fixArguments => [_newName];

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var variable = node.thisOrAncestorOfType<VariableDeclaration>();
    var field = variable?.declaredFragment?.element;
    var classDeclaration = variable?.thisOrAncestorOfType<ClassDeclaration>();
    var enclosing = field?.enclosingElement;
    if (field is! FieldElement || classDeclaration == null) return;
    if (enclosing is! InterfaceElement) return;
    var oldName = variable!.name.lexeme;

    var newName = suggestedEventName(oldName);
    if (_hasMember(enclosing, newName)) return;

    // The field, and the named parameters of the class with the same name.
    var elements = <Element>[field, ..._namedParameters(classDeclaration, oldName)];

    // The offsets of the names to replace, by file.
    var offsetsByPath = <String, Set<int>>{};
    void add(String? path, int? offset) {
      if (path != null && offset != null) {
        offsetsByPath.putIfAbsent(path, () => {}).add(offset);
      }
    }

    for (var element in elements) {
      for (var fragment in element.fragments) {
        add(fragment.libraryFragment?.source.fullName, fragment.nameOffset);
      }
      var references = await searchReferences(unitResult.session, element);
      if (references == null) return;
      for (var reference in references) {
        if (reference.length == oldName.length) add(reference.path, reference.offset);
      }
    }

    // Uses of the parameters inside the class, which the search may not include.
    var parameters = elements.skip(1).toSet();
    classDeclaration.accept(_ReferenceFinder(parameters, (offset) => add(file, offset)));

    _newName = newName;
    for (var MapEntry(key: path, value: offsets) in offsetsByPath.entries) {
      await builder.addDartFileEdit(path, (builder) {
        for (var offset in offsets) {
          builder.addSimpleReplacement(SourceRange(offset, oldName.length), newName);
        }
      });
    }
  }

  static bool _hasMember(InterfaceElement element, String name) =>
      [element, for (var type in element.allSupertypes) type.element].any(
        (element) =>
            element.getGetter(name) != null ||
            element.getSetter(name) != null ||
            element.getMethod(name) != null,
      );

  /// Returns the named parameters called [name] of the constructors and methods
  /// declared in [declaration], and its positional field formal parameters that
  /// initialize the field [name].
  static List<FormalParameterElement> _namedParameters(
    ClassDeclaration declaration,
    String name,
  ) => [
    for (var member in declaration.body.members)
      if (switch (member) {
            ConstructorDeclaration(:var parameters) => parameters,
            MethodDeclaration(:var parameters) => parameters,
            _ => null,
          }
          case var parameters?)
        for (var parameter in parameters.parameters)
          if (parameter.declaredFragment?.element case var element?
              when element.name == name &&
                  (element.isNamed || element is FieldFormalParameterElement))
            element,
  ];
}

class _ReferenceFinder extends RecursiveAstVisitor<void> {
  final Set<Element> elements;
  final void Function(int offset) add;

  _ReferenceFinder(this.elements, this.add);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (elements.contains(node.element?.baseElement)) add(node.offset);
  }

  @override
  void visitNamedArgument(NamedArgument node) {
    if (elements.contains(node.correspondingParameter?.baseElement)) {
      add(node.name.offset);
    }
    super.visitNamedArgument(node);
  }
}
