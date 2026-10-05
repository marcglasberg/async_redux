import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

import '../redux_types.dart';

/// Reports an action that overrides a method that one of its AsyncRedux mixins
/// implements, like `abortDispatch` with `NonReentrant`, without calling `super`. The
/// mixin then silently stops working.
///
/// Only checks `abortDispatch`, `wrapReduce` and `reduce`. The mixins' `before` and
/// `after` have `@mustCallSuper`, so the analyzer already reports them, and the other
/// methods of the mixins are meant to be overridden. The mixin may come from a
/// superclass, like a base action.
class MissingSuperInMixinOverrideRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'missing_super_in_mixin_override',
    "This '{0}' overrides the one of the '{1}' mixin without calling 'super.{0}', so "
        "the mixin doesn't work.",
    correctionMessage: '{2}',
    severity: DiagnosticSeverity.ERROR,
  );

  static const _corrections = {
    'abortDispatch':
        "Try adding 'if (super.abortDispatch()) return true;' to the start of "
        "'abortDispatch'.",
    'wrapReduce': "Try returning 'super.wrapReduce(reduce)', or removing the override.",
    'reduce': "Try removing the override.",
  };

  MissingSuperInMixinOverrideRule()
    : super(
        name: 'missing_super_in_mixin_override',
        description:
            "An action that overrides 'abortDispatch', 'wrapReduce' or 'reduce' of an "
            "AsyncRedux mixin must call 'super'.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addMethodDeclaration(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _Visitor(this.rule);

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    var name = node.name.lexeme;
    var correction = MissingSuperInMixinOverrideRule._corrections[name];
    if (correction == null || !isActionMethod(node)) return;

    var enclosing = node.declaredFragment!.element.enclosingElement as InterfaceElement;
    var mixin = enclosing.allSupertypes
        .map((type) => type.element)
        .where((element) => _implementsWithoutMustCallSuper(element, name))
        .firstOrNull;
    if (mixin == null) return;

    var finder = _SuperCallFinder(name);
    node.body.accept(finder);
    if (finder.found) return;

    rule.reportAtToken(node.name, arguments: [name, mixin.displayName, correction]);
  }

  /// Returns true if [element] is an AsyncRedux mixin that implements the method
  /// called [name], without `@mustCallSuper`.
  static bool _implementsWithoutMustCallSuper(InterfaceElement element, String name) {
    if (element is! MixinElement || !isFromAsyncRedux(element)) return false;
    var method = element.getMethod(name);
    return method != null && !method.isAbstract && !method.metadata.hasMustCallSuper;
  }
}

/// Finds `super.name`, called or torn off, anywhere in a method body.
class _SuperCallFinder extends RecursiveAstVisitor<void> {
  final String name;
  bool found = false;

  _SuperCallFinder(this.name);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target is SuperExpression && node.methodName.name == name) found = true;
    super.visitMethodInvocation(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (node.target is SuperExpression && node.propertyName.name == name) found = true;
    super.visitPropertyAccess(node);
  }
}
