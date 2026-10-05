import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

import '../mixin_utils.dart';
import '../redux_types.dart';
import 'mixin_combination_rules.dart';

/// Reports a concrete action with the `Retry` mixin, but not `NonReentrant`. The docs
/// recommend adding `NonReentrant` to most actions that use `Retry`, so that a new
/// dispatch doesn't run while the previous one is still retrying.
///
/// Not reported when the action also has a mixin that can't be combined with
/// `NonReentrant` or `Retry`, since `incompatible_mixins` reports it, or that already
/// keeps the action from running twice at the same time (`Sequential`), or when the
/// action overrides `abortDispatch` itself.
class RetryWithoutNonReentrantRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'retry_without_non_reentrant',
    "The action '{0}' uses the 'Retry' mixin without the 'NonReentrant' mixin.",
    correctionMessage:
        "Try adding 'NonReentrant', so that the action doesn't run again while it's "
        "retrying.",
    severity: DiagnosticSeverity.INFO,
  );

  RetryWithoutNonReentrantRule()
    : super(
        name: 'retry_without_non_reentrant',
        description: "Most actions that use 'Retry' should also use 'NonReentrant'.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    var visitor = _Visitor(this);
    registry.addClassDeclaration(this, visitor);
    registry.addClassTypeAlias(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _Visitor(this.rule);

  @override
  void visitClassDeclaration(ClassDeclaration node) => _check(node);

  @override
  void visitClassTypeAlias(ClassTypeAlias node) => _check(node);

  void _check(AstNode node) {
    var declaration = ClassWithMixins.of(node);
    if (declaration == null) return;

    // The mixins are cached, so checking them first is the fastest.
    var mixins = declaration.mixins;
    if (!mixins.contains('Retry') || mixins.contains('NonReentrant')) return;
    if (mixins.any(_excludes)) return;
    if (!isConcreteAction(declaration.element)) return;
    if (_overridesAbortDispatch(declaration.element)) return;

    declaration.reportAtMixin(
      rule,
      'Retry',
      arguments: [declaration.element.displayName],
    );
  }

  /// Returns true if [mixin] can't be combined with `NonReentrant` or `Retry`, or
  /// already keeps the action from running twice at the same time.
  static bool _excludes(String mixin) =>
      mixin == 'Sequential' ||
      _isIncompatible(mixin, 'NonReentrant') ||
      _isIncompatible(mixin, 'Retry');

  static bool _isIncompatible(String mixin1, String mixin2) =>
      incompatibleMixinPairs.contains((mixin1, mixin2)) ||
      incompatibleMixinPairs.contains((mixin2, mixin1));

  /// Returns true if [element], or one of its superclasses or mixins of your own,
  /// overrides `abortDispatch`.
  static bool _overridesAbortDispatch(ClassElement element) {
    var method = element.thisType.lookUpMethod('abortDispatch', element.library);
    var declaring = method?.enclosingElement;
    return declaring != null && !isFromAsyncRedux(declaring);
  }
}
