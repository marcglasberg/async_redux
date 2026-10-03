import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

/// The pairs of AsyncRedux mixins that can't be combined. This is the same as
/// the `_incompatible` checks in `action_mixins.dart`, which throw an assertion
/// error at runtime, in debug mode. A test checks that they match.
///
/// `NoDialog` and `UnlimitedRetries` are missing from most pairs, because they
/// require `CheckInternet` and `Retry`, which are already in those pairs.
const incompatibleMixinPairs = {
  ('AbortWhenNoInternet', 'CheckInternet'),
  ('AbortWhenNoInternet', 'ServerPush'),
  ('AbortWhenNoInternet', 'UnlimitedRetryCheckInternet'),
  ('CheckInternet', 'ServerPush'),
  ('CheckInternet', 'UnlimitedRetryCheckInternet'),
  ('Debounce', 'OptimisticCommand'),
  ('Debounce', 'OptimisticSync'),
  ('Debounce', 'OptimisticSyncWithPush'),
  ('Debounce', 'Polling'),
  ('Debounce', 'Retry'),
  ('Debounce', 'Sequential'),
  ('Debounce', 'ServerPush'),
  ('Debounce', 'UnlimitedRetries'),
  ('Debounce', 'UnlimitedRetryCheckInternet'),
  ('Fresh', 'NonReentrant'),
  ('Fresh', 'OptimisticCommand'),
  ('Fresh', 'OptimisticSync'),
  ('Fresh', 'OptimisticSyncWithPush'),
  ('Fresh', 'ServerPush'),
  ('Fresh', 'Throttle'),
  ('Fresh', 'UnlimitedRetryCheckInternet'),
  ('NonReentrant', 'OptimisticCommand'),
  ('NonReentrant', 'OptimisticSync'),
  ('NonReentrant', 'OptimisticSyncWithPush'),
  ('NonReentrant', 'ServerPush'),
  ('NonReentrant', 'Throttle'),
  ('NonReentrant', 'UnlimitedRetryCheckInternet'),
  ('OptimisticCommand', 'OptimisticSync'),
  ('OptimisticCommand', 'OptimisticSyncWithPush'),
  ('OptimisticCommand', 'Polling'),
  ('OptimisticCommand', 'ServerPush'),
  ('OptimisticCommand', 'Throttle'),
  ('OptimisticCommand', 'UnlimitedRetries'),
  ('OptimisticCommand', 'UnlimitedRetryCheckInternet'),
  ('OptimisticSync', 'OptimisticSyncWithPush'),
  ('OptimisticSync', 'Polling'),
  ('OptimisticSync', 'Retry'),
  ('OptimisticSync', 'Sequential'),
  ('OptimisticSync', 'ServerPush'),
  ('OptimisticSync', 'Throttle'),
  ('OptimisticSync', 'UnlimitedRetries'),
  ('OptimisticSync', 'UnlimitedRetryCheckInternet'),
  ('OptimisticSyncWithPush', 'Polling'),
  ('OptimisticSyncWithPush', 'Retry'),
  ('OptimisticSyncWithPush', 'Sequential'),
  ('OptimisticSyncWithPush', 'ServerPush'),
  ('OptimisticSyncWithPush', 'Throttle'),
  ('OptimisticSyncWithPush', 'UnlimitedRetries'),
  ('OptimisticSyncWithPush', 'UnlimitedRetryCheckInternet'),
  ('Polling', 'Retry'),
  ('Polling', 'ServerPush'),
  ('Polling', 'UnlimitedRetries'),
  ('Polling', 'UnlimitedRetryCheckInternet'),
  ('Retry', 'ServerPush'),
  ('Retry', 'UnlimitedRetryCheckInternet'),
  ('Sequential', 'ServerPush'),
  ('Sequential', 'UnlimitedRetryCheckInternet'),
  ('ServerPush', 'Throttle'),
  ('ServerPush', 'UnlimitedRetries'),
  ('ServerPush', 'UnlimitedRetryCheckInternet'),
  ('Throttle', 'UnlimitedRetryCheckInternet'),
};

/// The mixins that should be added to the action returned by
/// `createPollingAction`, and not to the action with the `Polling` mixin.
/// Each one says why it may prevent a `Poll.stop` from stopping the polling.
const _pollingCaveats = {
  'CheckInternet': "a 'Poll.stop' dispatched with no internet fails",
  'AbortWhenNoInternet': "a 'Poll.stop' dispatched with no internet is aborted",
  'NonReentrant': "a 'Poll.stop' dispatched while a run is in progress is ignored",
  'Throttle': "a 'Poll.stop' dispatched inside the throttle period is ignored",
  'Fresh': "a 'Poll.stop' dispatched while the data is fresh is ignored",
  'Sequential': "a 'Poll.stop' has to wait for its turn in the queue",
};

bool _isIncompatible(String mixin1, String mixin2) =>
    incompatibleMixinPairs.contains((mixin1, mixin2)) ||
    incompatibleMixinPairs.contains((mixin2, mixin1));

/// Reports an action that uses two AsyncRedux mixins that can't be combined, like
/// `NonReentrant` and `Throttle`. AsyncRedux throws an assertion error at runtime,
/// in debug mode. Mixins inherited from a superclass, like a base action, count too.
class IncompatibleMixinsRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'incompatible_mixins',
    "The '{0}' mixin{2} can't be combined with the '{1}' mixin{3}. "
        "AsyncRedux throws an assertion error at runtime.",
    correctionMessage: "Try removing one of the mixins.",
    severity: DiagnosticSeverity.ERROR,
  );

  IncompatibleMixinsRule()
    : super(
        name: 'incompatible_mixins',
        description: "Some AsyncRedux mixins can't be combined in the same action.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    var visitor = _MixinCombinationVisitor(this, reportedFirst: true, (mixins) sync* {
      var names = mixins.toList();
      for (var i = 0; i < names.length; i++) {
        for (var j = i + 1; j < names.length; j++) {
          var (mixin1, mixin2) = (names[i], names[j]);
          if (!_isIncompatible(mixin1, mixin2)) continue;

          // `UnlimitedRetries` requires `Retry`. Report only the pair with `Retry`,
          // when both pairs are incompatible.
          if ((mixin1 == 'UnlimitedRetries' && _isIncompatible('Retry', mixin2)) ||
              (mixin2 == 'UnlimitedRetries' && _isIncompatible('Retry', mixin1))) {
            continue;
          }
          yield (mixin1, mixin2);
        }
      }
    });
    registry.addClassDeclaration(this, visitor);
    registry.addClassTypeAlias(this, visitor);
  }
}

/// Reports an action with the `Polling` mixin that also uses `CheckInternet`,
/// `AbortWhenNoInternet`, `NonReentrant`, `Throttle`, `Fresh` or `Sequential`.
/// Those mixins can abort, fail or delay a `Poll.stop`, so you may be unable to
/// stop the polling. They should be added to the action returned by
/// `createPollingAction` instead.
class PollingWithCaveatMixinRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'polling_with_caveat_mixin',
    "Don't combine the '{0}' mixin{2} with the '{1}' mixin{3}, "
        "because {4}, so you may be unable to stop the polling.",
    correctionMessage:
        "Try adding the '{0}' mixin to the action returned by "
        "'createPollingAction' instead.",
    severity: DiagnosticSeverity.ERROR,
  );

  PollingWithCaveatMixinRule()
    : super(
        name: 'polling_with_caveat_mixin',
        description:
            "Mixins that can abort or delay a dispatch should be added to the "
            "action returned by 'createPollingAction', not to the action with 'Polling'.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    var visitor = _MixinCombinationVisitor(
      this,
      (mixins) => mixins.contains('Polling')
          ? mixins.where(_pollingCaveats.containsKey).map((mixin) => (mixin, 'Polling'))
          : const [],
      reasonFor: (mixin, _) => _pollingCaveats[mixin]!,
    );
    registry.addClassDeclaration(this, visitor);
    registry.addClassTypeAlias(this, visitor);
  }
}

/// Checks the AsyncRedux mixins of each class. The [findPairs] function returns the
/// pairs of mixins to report, from the names of all the AsyncRedux mixins of a class.
///
/// A pair already present in the superclass is not reported, since it's reported
/// where the superclass is declared. Otherwise, the diagnostic is reported on the
/// last mixin of the pair in the `with` clause, or on the class name if neither
/// is there.
///
/// The arguments of the diagnostic are the two mixins, then " (from 'MySuperclass')"
/// or an empty string for each of them, then the result of [reasonFor], if given.
/// If [reportedFirst] is true, the mixin where the diagnostic is reported comes
/// first. Otherwise, the order is the one returned by [findPairs].
class _MixinCombinationVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final Iterable<(String, String)> Function(Set<String> mixins) findPairs;
  final String Function(String mixin1, String mixin2)? reasonFor;
  final bool reportedFirst;

  _MixinCombinationVisitor(
    this.rule,
    this.findPairs, {
    this.reasonFor,
    this.reportedFirst = false,
  });

  @override
  void visitClassDeclaration(ClassDeclaration node) =>
      _check(node.declaredFragment?.element, node.withClause, node.namePart.typeName);

  @override
  void visitClassTypeAlias(ClassTypeAlias node) =>
      _check(node.declaredFragment?.element, node.withClause, node.name);

  void _check(ClassElement? element, WithClause? withClause, Token className) {
    if (element == null) return;

    var mixins = _asyncReduxMixins(element.allSupertypes);
    if (mixins.length < 2) return;

    var superclass = element.supertype;
    var inherited = (superclass == null)
        ? const <String>{}
        : _asyncReduxMixins([superclass, ...superclass.element.allSupertypes]);

    var mixinTypes = withClause?.mixinTypes ?? const <NamedType>[];

    for (var (mixin1, mixin2) in findPairs(mixins)) {
      if (inherited.contains(mixin1) && inherited.contains(mixin2)) continue;

      // Report on the mixin that comes last in the `with` clause.
      var index1 = _indexInWithClause(mixin1, mixinTypes);
      var index2 = _indexInWithClause(mixin2, mixinTypes);
      var index = (index1 > index2) ? index1 : index2;
      if (reportedFirst && index2 > index1) (mixin1, mixin2) = (mixin2, mixin1);

      String from(String mixin) => (inherited.contains(mixin) && superclass != null)
          ? " (from '${superclass.element.displayName}')"
          : '';

      var arguments = [
        mixin1,
        mixin2,
        from(mixin1),
        from(mixin2),
        if (reasonFor != null) reasonFor!(mixin1, mixin2),
      ];

      if (index == -1) {
        rule.reportAtToken(className, arguments: arguments);
      } else {
        rule.reportAtNode(mixinTypes[index], arguments: arguments);
      }
    }
  }
}

/// Returns the names of the AsyncRedux mixins among [types].
Set<String> _asyncReduxMixins(Iterable<InterfaceType> types) => {
  for (var type in types)
    if (_isAsyncReduxMixin(type.element)) type.element.name!,
};

bool _isAsyncReduxMixin(InterfaceElement element) =>
    element is MixinElement &&
    element.library.uri.toString().startsWith('package:async_redux/');

/// Returns the index of the type in [mixinTypes] that adds the AsyncRedux [mixin],
/// or -1 if none does. That's the [mixin] itself or, if missing, another mixin
/// that has [mixin] as a supertype, like a mixin of your own.
int _indexInWithClause(String mixin, List<NamedType> mixinTypes) {
  var index = mixinTypes.indexWhere((type) {
    var element = type.element;
    return element is InterfaceElement &&
        _isAsyncReduxMixin(element) &&
        element.name == mixin;
  });
  if (index != -1) return index;

  return mixinTypes.indexWhere((type) {
    var element = type.element;
    return element is InterfaceElement &&
        _asyncReduxMixins(element.allSupertypes).contains(mixin);
  });
}
