import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

import '../mixin_utils.dart';
import '../redux_types.dart';

/// Reports a concrete action with fields, and with a mixin that keeps state by key,
/// like `NonReentrant`, that doesn't override the method that creates the key, like
/// `nonReentrantKeyParams`. By default, the key doesn't depend on the fields, so all
/// instances share it. For example, `LoadUserCart('A')` then blocks
/// `LoadUserCart('B')`.
///
/// This is often intended, so the rule is opt-in. Fields that override a getter of a
/// supertype, like the `poll` field of `Polling`, don't count.
class MissingKeyParamsRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'missing_key_params',
    "The action '{0}' has fields, but doesn't override '{1}', so all its instances "
        "share the same '{2}' key.",
    correctionMessage:
        "Try overriding '{1}' to return the fields that identify the action, like "
        "'{3}'.",
    severity: DiagnosticSeverity.INFO,
  );

  /// For each mixin, the methods that create its key. Overriding any of them counts.
  static const _keyMethods = {
    'NonReentrant': ['nonReentrantKeyParams', 'computeNonReentrantKey'],
    'OptimisticCommand': ['nonReentrantKeyParams', 'computeNonReentrantKey'],
    'Fresh': ['freshKeyParams', 'computeFreshKey'],
    'Throttle': ['lockBuilder'],
    'Debounce': ['lockBuilder'],
    'Polling': ['pollingKeyParams', 'computePollingKey'],
    'Sequential': ['sequentialKeyParams'],
    'OptimisticSync': ['optimisticSyncKeyParams', 'computeOptimisticSyncKey'],
    'OptimisticSyncWithPush': ['optimisticSyncKeyParams', 'computeOptimisticSyncKey'],
  };

  MissingKeyParamsRule()
    : super(
        name: 'missing_key_params',
        description:
            "An action with fields should override the key method of its mixins, "
            "like 'nonReentrantKeyParams'.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addClassDeclaration(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _Visitor(this.rule);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    var declaration = ClassWithMixins.of(node);
    if (declaration == null) return;
    // The mixins are cached, so checking them first is the fastest.
    var keyMixins = [
      for (var entry in MissingKeyParamsRule._keyMethods.entries)
        if (declaration.mixins.contains(entry.key)) entry,
    ];
    if (keyMixins.isEmpty) return;

    var element = declaration.element;
    if (!isConcreteAction(element)) return;

    var fields = _ownFields(node, element);
    if (fields.isEmpty) return;

    for (var MapEntry(key: mixin, value: methods) in keyMixins) {
      if (methods.any((method) => _isOverridden(element, method))) continue;

      var method = methods.first;
      var example = (method == 'lockBuilder')
          ? 'Object? lockBuilder() => (runtimeType, ${fields.first});'
          : 'Object? $method() => ${fields.first};';
      declaration.reportAtMixin(
        rule,
        mixin,
        arguments: [element.displayName, method, mixin, example],
      );
    }
  }

  /// Returns the names of the instance fields declared in [node], except the ones
  /// that override a getter of a supertype.
  static List<String> _ownFields(ClassDeclaration node, ClassElement element) => [
    for (var member in node.body.members)
      if (member is FieldDeclaration && !member.isStatic)
        for (var variable in member.fields.variables)
          if (!_isInherited(element, variable.name.lexeme)) variable.name.lexeme,
  ];

  /// Uses the elements of the supertypes, and not the types, which would create a new
  /// getter with the type arguments of the supertype.
  static bool _isInherited(ClassElement element, String name) =>
      element.allSupertypes.any((type) => type.element.getGetter(name) != null);

  /// Returns true if [element], or one of its superclasses or mixins of your own,
  /// overrides the AsyncRedux method called [name].
  static bool _isOverridden(ClassElement element, String name) {
    var method = element.thisType.lookUpMethod(name, element.library);
    var declaring = method?.enclosingElement;
    return declaring != null && !isFromAsyncRedux(declaring);
  }
}
