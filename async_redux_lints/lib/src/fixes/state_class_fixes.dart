import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

import '../rules/missing_state_class_rule.dart';
import '../state_class_utils.dart';

/// Annotates with `@stateClass` the classes reported by [MissingStateClassRule], in
/// the files that declare them, adding the import of `async_redux` if needed.
///
/// An `@immutable` annotation of package `meta` is replaced, since `@stateClass` does
/// the same check. Then the import of `package:meta/meta.dart` is removed, if nothing
/// else in the file uses package `meta`. Other imports, like
/// `package:flutter/foundation.dart`, are kept.
class AddStateClassAnnotation extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'async_redux_lints.fix.addStateClassAnnotation',
    DartFixKindPriority.standard,
    "Annotate {0} with '@stateClass'",
  );

  static const _asyncReduxUri = 'package:async_redux/async_redux.dart';

  String _names = '';

  AddStateClassAnnotation({required super.context});

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  List<String> get fixArguments => [_names];

  @override
  Future<void> compute(ChangeBuilder builder) async {
    var classes = _classesToAnnotate();
    if (classes.isEmpty) return;
    var asyncRedux = await unitResult.session.getLibraryByUri(_asyncReduxUri);
    if (asyncRedux is! LibraryElementResult) return;

    // The declarations to annotate, by the file that declares them.
    var declarationsByPath = <String, List<_Declaration>>{};
    var units = <String, ResolvedUnitResult>{};
    for (var element in classes) {
      var path = element.firstFragment.libraryFragment.source.fullName;
      var unit = units[path];
      if (unit == null) {
        var result = await unitResult.session.getResolvedUnit(path);
        if (result is! ResolvedUnitResult) return;
        units[path] = unit = result;
      }
      var declaration = _Declaration.find(unit.unit, element);
      if (declaration == null) return;
      declarationsByPath.putIfAbsent(path, () => []).add(declaration);
    }

    _names = joinNames([for (var element in classes) element.displayName]);
    for (var MapEntry(key: path, value: declarations) in declarationsByPath.entries) {
      var unit = units[path]!;
      var replaced = [
        for (var declaration in declarations)
          if (declaration.immutable case var immutable?) immutable,
      ];
      var metaImport = (replaced.isEmpty) ? null : _unusedMetaImport(unit, replaced);

      // When the import of `async_redux` would be added where the removed import of
      // `meta` is, it replaces that import, since the edits can't overlap.
      var isMetaImportReplaced =
          metaImport != null && _importPositionOfAsyncRedux(unit) == metaImport;

      await builder.addDartFileEdit(path, (builder) {
        String? prefix;
        if (isMetaImportReplaced) {
          builder.addSimpleReplacement(
            range.node(metaImport),
            "import '$_asyncReduxUri';",
          );
        } else {
          prefix = builder.importLibraryElement(Uri.parse(_asyncReduxUri)).prefix;
        }
        var annotation = (prefix == null) ? '@stateClass' : '@$prefix.stateClass';
        for (var declaration in declarations) {
          if (declaration.immutable case var immutable?) {
            builder.addSimpleReplacement(range.node(immutable), annotation);
          } else {
            builder.addSimpleInsertion(
              declaration.offset,
              '$annotation${_endOfLine(unit.content)}',
            );
          }
        }
        if (metaImport != null && !isMetaImportReplaced) {
          builder.addDeletion(_lineRange(unit.content, metaImport));
        }
      });
    }
  }

  /// Returns the classes that the diagnostic reports.
  List<InterfaceElement> _classesToAnnotate() {
    var package = unitResult.session.analysisContext.contextRoot.workspace.findPackageFor(
      file,
    );
    bool isOwn(InterfaceElement element) =>
        isOwnClass(element, library: unitResult.libraryElement, package: package);

    var variable = node.thisOrAncestorOfType<VariableDeclaration>();
    if (variable?.declaredFragment?.element case FieldElement field) {
      return classesMissingStateClassIn(field, isOwn);
    }

    var creation = node.thisOrAncestorOfType<InstanceCreationExpression>();
    var state = (creation != null)
        ? storeStateClassOf(creation.staticType)
        : node.thisOrAncestorOfType<ClassDeclaration>()?.declaredFragment?.element;
    return (state != null && isStoreStateMissingStateClass(state, isOwn))
        ? [state]
        : const [];
  }

  /// Returns the import of `package:meta/meta.dart` in [unit], if nothing in [unit]
  /// other than the annotations [replaced] uses an element of package `meta`.
  /// Otherwise, returns null.
  static ImportDirective? _unusedMetaImport(
    ResolvedUnitResult unit,
    List<Annotation> replaced,
  ) {
    var imports = [
      for (var directive in unit.unit.directives)
        if (directive is ImportDirective &&
            directive.uri.stringValue == 'package:meta/meta.dart')
          directive,
    ];
    if (imports.length != 1) return null;
    var finder = _MetaUseFinder(replaced.toSet());
    unit.unit.accept(finder);
    return finder.isFound ? null : imports.single;
  }

  /// Returns the import before which the change builder would add the import of
  /// `async_redux` to [unit]: the first import that is relative, or that is a package
  /// import that sorts after it. Returns null if [unit] already imports `async_redux`,
  /// or if the import would be added after the existing ones.
  static ImportDirective? _importPositionOfAsyncRedux(ResolvedUnitResult unit) {
    var imports = unit.unit.directives.whereType<ImportDirective>();
    if (imports.any((directive) => directive.uri.stringValue == _asyncReduxUri)) {
      return null;
    }
    for (var directive in imports) {
      var uri = directive.uri.stringValue ?? '';
      if (uri.startsWith('dart:')) continue;
      if (!uri.contains(':') || uri.compareTo(_asyncReduxUri) > 0) return directive;
    }
    return null;
  }

  /// Returns the range of [node], with the end of its line.
  static SourceRange _lineRange(String content, AstNode node) {
    var end = node.end;
    if (content.startsWith('\r\n', end)) {
      end += 2;
    } else if (content.startsWith('\n', end)) {
      end += 1;
    }
    return SourceRange(node.offset, end - node.offset);
  }

  static String _endOfLine(String content) => content.contains('\r\n') ? '\r\n' : '\n';
}

/// A class or mixin declaration to annotate.
class _Declaration {
  /// Where to insert the annotation: before the other annotations, after the
  /// documentation comment.
  final int offset;

  /// The `@immutable` annotation of package `meta`, to replace, if any.
  final Annotation? immutable;

  _Declaration(this.offset, this.immutable);

  /// Returns the declaration of [element] in [unit], or null if it's not found.
  static _Declaration? find(CompilationUnit unit, InterfaceElement element) {
    for (var declaration in unit.declarations) {
      if (declaration is! ClassDeclaration && declaration is! MixinDeclaration) continue;
      if (declaration.declaredFragment?.element.name != element.name) continue;
      var metadata = declaration.metadata;
      return _Declaration(
        metadata.firstOrNull?.offset ??
            declaration.firstTokenAfterCommentAndMetadata.offset,
        metadata.where(_isImmutable).firstOrNull,
      );
    }
    return null;
  }

  /// Returns true if [annotation] is `@immutable` or `@Immutable()` of package
  /// `meta`, also when it's exported by another library, like
  /// `package:flutter/foundation.dart`.
  static bool _isImmutable(Annotation annotation) {
    var element = annotation.element;
    var isImmutable = switch (element) {
      GetterElement(:var name) => name == 'immutable',
      ConstructorElement(:var enclosingElement) => enclosingElement.name == 'Immutable',
      _ => false,
    };
    return isImmutable && _isFromMeta(element);
  }
}

bool _isFromMeta(Element? element) =>
    element?.library?.uri.toString().startsWith('package:meta/') ?? false;

/// Finds a use of an element of package `meta`, outside of the [ignored] annotations.
class _MetaUseFinder extends RecursiveAstVisitor<void> {
  final Set<Annotation> ignored;
  bool isFound = false;

  _MetaUseFinder(this.ignored);

  @override
  void visitAnnotation(Annotation node) {
    if (!ignored.contains(node)) super.visitAnnotation(node);
  }

  @override
  void visitImportDirective(ImportDirective node) {}

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (_isFromMeta(node.element)) isFound = true;
  }

  @override
  void visitNamedType(NamedType node) {
    if (_isFromMeta(node.element)) isFound = true;
    super.visitNamedType(node);
  }
}
