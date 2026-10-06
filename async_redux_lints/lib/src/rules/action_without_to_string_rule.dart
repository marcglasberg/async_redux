import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

import '../package_files.dart';
import '../redux_types.dart';
import '../state_class_utils.dart';

/// Reports a concrete action with fields that doesn't override `toString()`. The logs
/// from `ConsoleActionObserver` then only show the action type, like
/// `Action LoadUser`, and not its fields.
///
/// The fields and `toString()` of the action's own superclasses and mixins count, but
/// not the ones of AsyncRedux.
class ActionWithoutToStringRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'action_without_to_string',
    "The action '{0}' has fields, but doesn't override 'toString()'.",
    correctionMessage:
        "Try overriding 'toString()' to include the fields, so that they appear in the "
        "logs.",
    severity: DiagnosticSeverity.INFO,
  );

  ActionWithoutToStringRule()
    : super(
        name: 'action_without_to_string',
        description:
            "Actions with fields should override 'toString()', so that the logs show "
            "the fields.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    if (isTestLibrary(context)) return;
    registry.addClassDeclaration(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _Visitor(this.rule);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    var element = node.declaredFragment?.element;
    if (element == null || !isConcreteAction(element)) return;
    var ownClasses = _ownClasses(element);
    if (_fieldsOf(ownClasses).isEmpty) return;
    if (ownClasses.any((c) => c.getMethod('toString')?.isAbstract == false)) return;
    var name = node.namePart.typeName;
    rule.reportAtToken(name, arguments: [name.lexeme]);
  }
}

/// Returns the instance fields of the action [element], and of the superclasses and
/// mixins it inherits from, other than the ones of AsyncRedux. Inherited fields come
/// first.
List<FieldElement> actionFieldsForToString(InterfaceElement element) =>
    _fieldsOf(_ownClasses(element));

/// Returns the instance fields of [classes], from the last class to the first.
List<FieldElement> _fieldsOf(List<InterfaceElement> classes) => [
  for (var c in classes.reversed)
    for (var field in c.fields)
      if (!field.isStatic && !field.isOriginGetterSetter) field,
];

/// Returns [element], and the classes and mixins it inherits from, other than the
/// ones of AsyncRedux and of the SDK.
List<InterfaceElement> _ownClasses(InterfaceElement element) => [
  for (var c in [element, ...inheritedClasses(element)])
    if (!isFromAsyncRedux(c) && !c.library.isInSdk) c,
];
