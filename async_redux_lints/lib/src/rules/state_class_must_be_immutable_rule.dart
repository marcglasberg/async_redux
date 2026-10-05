// Adapted from `ImmutableVerifier` of package `analyzer`, which checks `@immutable`.
// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:collection';

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

/// Reports a class with non-final instance fields, when the class is annotated with
/// `@stateClass`, or inherits from a class or mixin annotated with `@stateClass`.
///
/// This is the same check the analyzer does for `@immutable`.
class StateClassMustBeImmutableRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'state_class_must_be_immutable',
    "This class (or a class that this class inherits from) is marked as "
        "'@stateClass', so it must be immutable and all its fields must be final: {0}",
    correctionMessage: "Try making all fields final.",
    severity: DiagnosticSeverity.WARNING,
  );

  StateClassMustBeImmutableRule()
    : super(
        name: 'state_class_must_be_immutable',
        description: "The instance fields of a '@stateClass' class must be final.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    var visitor = _Visitor(this);
    registry.addClassDeclaration(this, visitor);
    registry.addClassTypeAlias(this, visitor);
    registry.addMixinDeclaration(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _Visitor(this.rule);

  @override
  void visitClassDeclaration(ClassDeclaration node) =>
      _checkDeclaration(node, nameToken: node.namePart.typeName);

  @override
  void visitClassTypeAlias(ClassTypeAlias node) =>
      _checkDeclaration(node, nameToken: node.name);

  @override
  void visitMixinDeclaration(MixinDeclaration node) =>
      _checkDeclaration(node, nameToken: node.name);

  /// If [node] is marked with `@stateClass` or inherits from a class or mixin
  /// marked with `@stateClass`, searches the fields of [node] and its
  /// superclasses, reporting a warning if any non-final instance fields are found.
  void _checkDeclaration(CompilationUnitMember node, {required Token nameToken}) {
    var element = node.declaredFragment?.element;
    if (element is! InterfaceElement) return;
    if (!_isOrInheritsStateClass(element, HashSet<InterfaceElement>())) return;

    var nonFinalFieldNames = _declaredAndInheritedNonFinalInstanceFields(
      element,
      HashSet<InterfaceElement>(),
    );
    if (nonFinalFieldNames.isNotEmpty) {
      rule.reportAtToken(nameToken, arguments: [nonFinalFieldNames.join(', ')]);
    }
  }

  /// Returns all of the declared and inherited non-final instance fields of
  /// [element].
  ///
  /// [visited] is used to avoid visiting supertypes multiple times.
  static Iterable<String> _declaredAndInheritedNonFinalInstanceFields(
    InterfaceElement element,
    Set<InterfaceElement> visited,
  ) {
    if (!visited.add(element)) {
      // Already checked `element`.
      return const [];
    }
    return [
      ...element.nonFinalInstanceFieldNames,
      ...element.mixins.expand((mixin) => mixin.element.nonFinalInstanceFieldNames),
      if (element.supertype case var supertype?)
        ..._declaredAndInheritedNonFinalInstanceFields(supertype.element, visited),
    ];
  }

  /// Returns whether the given class [element] or any superclass of it is
  /// annotated with `@stateClass`.
  ///
  /// [visiting] is used to stop at cycles, which only happen in invalid code.
  ///
  /// The result is cached for each element, including the supertypes, so that the
  /// supertypes shared by many classes, like `StatelessWidget`, are only checked once.
  /// When a file changes, the analyzer creates new elements for its library, so the
  /// cached values of the old elements are not used anymore.
  static bool _isOrInheritsStateClass(
    InterfaceElement element,
    Set<InterfaceElement> visiting,
  ) {
    var cached = _isOrInheritsStateClassCache[element];
    if (cached != null) return cached;
    if (!visiting.add(element)) return false;

    var result =
        hasStateClassAnnotation(element) ||
        element.mixins.any(
          (InterfaceType mixin) => _isOrInheritsStateClass(mixin.element, visiting),
        ) ||
        element.interfaces.any(
          (InterfaceType interface) =>
              _isOrInheritsStateClass(interface.element, visiting),
        ) ||
        (element.supertype != null &&
            _isOrInheritsStateClass(element.supertype!.element, visiting));
    return _isOrInheritsStateClassCache[element] = result;
  }

  static final _isOrInheritsStateClassCache = Expando<bool>();
}

extension on InterfaceElement {
  List<String> get nonFinalInstanceFieldNames {
    var nonFinalFields = fields
        .where((f) => !f.isStatic && !f.isFinal && !f.isOriginGetterSetter)
        .toList();
    if (nonFinalFields.isEmpty) {
      return const [];
    }
    return List.generate(nonFinalFields.length, (i) {
      var field = nonFinalFields[i];
      return '$name.${field.name}';
    });
  }
}
