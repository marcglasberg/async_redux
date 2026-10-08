import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

import '../mixin_utils.dart';
import '../package_files.dart';
import '../redux_types.dart';

/// The mixins that only make sense for actions that do async work, like calling a
/// server, and why each one is pointless when the reducer is sync.
const asyncOnlyMixins = {
  'CheckInternet': 'a sync reducer does no network calls',
  'NoDialog': 'a sync reducer does no network calls',
  'AbortWhenNoInternet': 'a sync reducer does no network calls',
  'UnlimitedRetryCheckInternet': 'a sync reducer does no network calls',
  'NonReentrant': 'a sync action finishes before it can be dispatched again',
  'Retry': 'a sync reducer that fails will usually fail again in the same way',
  'UnlimitedRetries': 'a sync reducer that fails will usually fail again forever',
};

/// Reports a concrete action whose `reduce` is sync, but that uses a mixin that only
/// makes sense for async work, like `CheckInternet`, `NonReentrant` or `Retry`. These
/// mixins also make the action async, so it can't be dispatched with `dispatchSync`.
///
/// Not reported when `before` or `wrapReduce` are overridden outside of AsyncRedux,
/// since they may do the async work, or in tests, which often use sync actions to
/// test the mixins.
class AsyncMixinInSyncActionRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'async_mixin_in_sync_action',
    "The '{0}' mixin is pointless in the sync action '{1}', because {2}.",
    correctionMessage:
        "Try removing the mixin, or making the action async if it does async work.",
    severity: DiagnosticSeverity.WARNING,
  );

  AsyncMixinInSyncActionRule()
    : super(
        name: 'async_mixin_in_sync_action',
        description: "Don't use mixins meant for async work in sync actions.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    if (isTestLibrary(context)) return;
    var library = context.libraryElement;
    if (library == null) return;
    var visitor = _Visitor(this, library);
    registry.addClassDeclaration(this, visitor);
    registry.addClassTypeAlias(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final LibraryElement library;

  _Visitor(this.rule, this.library);

  @override
  void visitClassDeclaration(ClassDeclaration node) => _check(node);

  @override
  void visitClassTypeAlias(ClassTypeAlias node) => _check(node);

  void _check(AstNode node) {
    var declaration = ClassWithMixins.of(node);
    if (declaration == null) return;

    // The mixins are cached, so checking them first is the fastest.
    var found = declaration.mixins.where(asyncOnlyMixins.containsKey).toList();
    if (found.isEmpty) return;
    var element = declaration.element;
    if (!isConcreteAction(element)) return;
    if (!_hasSyncReduce(element)) return;
    if (_overridesOutsideAsyncRedux(element, 'before')) return;
    if (_overridesOutsideAsyncRedux(element, 'wrapReduce')) return;

    for (var mixin in found) {
      declaration.reportAtMixin(
        rule,
        mixin,
        arguments: [mixin, element.displayName, asyncOnlyMixins[mixin]!],
      );
    }
  }

  /// Returns true if the `reduce` of [element] is declared outside of AsyncRedux, and
  /// returns `St?` instead of a `Future` or `FutureOr`.
  bool _hasSyncReduce(ClassElement element) {
    var reduce = element.thisType.lookUpMethod('reduce', library);
    var declaring = reduce?.enclosingElement;
    if (reduce == null || declaring == null || isFromAsyncRedux(declaring)) {
      return false;
    }
    var returnType = reduce.returnType;
    return !returnType.isDartAsyncFuture &&
        !returnType.isDartAsyncFutureOr &&
        !returnType.isDartCoreObject &&
        returnType is! DynamicType;
  }

  /// Returns true if [element], or one of its superclasses or mixins of your own,
  /// overrides the method [name].
  bool _overridesOutsideAsyncRedux(ClassElement element, String name) {
    var method = element.thisType.lookUpMethod(name, library);
    var declaring = method?.enclosingElement;
    return declaring != null && !isFromAsyncRedux(declaring);
  }
}
