import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../widget_types.dart';

/// Reports `context.select` and `context.event` where they can't be used. They only
/// work while the widget builds, with the `BuildContext` of that widget. Otherwise,
/// they throw a `FlutterError` in debug mode. These are reported:
///
/// - Closures passed as a named argument that starts with `on`, like `onPressed`,
///   and closures passed to methods like `addPostFrameCallback`, `Timer` or
///   `setState`.
/// - The `State` methods `initState`, `didUpdateWidget`, `activate`, `deactivate`,
///   `dispose` and `reassemble`. Even with `debug: false`, which turns off the
///   runtime check, they're not valid there.
/// - The `State` method `didChangeDependencies`, unless `debug: false` is passed to
///   `getSelect` or `getEvent`. AsyncRedux allows them there with `debug: false`.
/// - Builders that use the `BuildContext` of another widget, like
///   `Builder(builder: (_) => Text(context.select(...)))`, where `context` is the
///   parameter of the enclosing `build` method.
/// - The `itemBuilder` of a list, like `ListView.builder`, whose `BuildContext`
///   belongs to the list, not to the item.
///
/// Other code that calls `select`, like a helper method called by `build`, may run
/// while the widget builds, so it's not reported.
class SelectOutsideBuildRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'select_outside_build',
    "'{0}' can't be used {1}.",
    correctionMessage: '{2}',
    severity: DiagnosticSeverity.ERROR,
  );

  SelectOutsideBuildRule()
    : super(
        name: 'select_outside_build',
        description:
            "Use 'context.select' and 'context.event' only while the widget builds.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addMethodInvocation(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _Visitor(this.rule);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    var problem = selectProblem(node);
    if (problem == null) return;
    rule.reportAtNode(
      node,
      arguments: [node.methodName.name, problem.where, problem.correction],
    );
  }
}

/// Why `context.select` or `context.event` can't be used somewhere.
enum SelectProblemKind {
  /// A callback, like `onPressed`, or a closure passed to a method like `Timer`.
  callback,

  /// A `State` method, like `initState`, but not `dispose` or
  /// `didChangeDependencies`.
  stateMethod,

  /// The `dispose` method of a `State`. The state can't be read there.
  dispose,

  /// The `didChangeDependencies` method of a `State`, with the debug check on.
  didChangeDependencies,

  /// A builder, using the `BuildContext` of another widget.
  otherContext,

  /// The `itemBuilder` of a list.
  itemBuilder,
}

typedef SelectProblem = ({SelectProblemKind kind, String where, String correction});

/// Returns why [node], a `context.select` or `context.event`, can't be used where
/// it is, or null if it can, or if it's not known.
SelectProblem? selectProblem(MethodInvocation node) {
  var access = stateAccessOfNode(node);
  if (access != StateAccess.select && access != StateAccess.event) return null;
  var isEvent = access == StateAccess.event;
  var getSelect = isEvent ? 'getEvent' : 'getSelect';
  const whileBuilding = "which doesn't run while the widget builds";

  var notBuildingCode = notBuilding(node);
  if (notBuildingCode != null) {
    var where = 'in ${notBuildingCode.description}, $whileBuilding';
    switch (notBuildingCode.stateMethod) {
      case 'didChangeDependencies':
        if (isDebugCheckOn(node) != true) return null;
        return (
          kind: SelectProblemKind.didChangeDependencies,
          where: "in 'didChangeDependencies' while the debug check is on",
          correction: "Try passing 'debug: false' to '$getSelect'.",
        );
      case 'dispose':
        return (
          kind: SelectProblemKind.dispose,
          where: where,
          correction:
              "Try reading what you need in 'deactivate', or earlier, and keeping it "
              "in a field.",
        );
    }
    return (
      kind: notBuildingCode.stateMethod == null
          ? SelectProblemKind.callback
          : SelectProblemKind.stateMethod,
      where: where,
      correction: isEvent
          ? "Try consuming the event in 'build'."
          : "Try using 'context.read()' instead.",
    );
  }

  var function = enclosingBuildFunction(node, throughClosures: true);
  if (function == null) return null;
  var isOwnContext = isContextOf(node.target, function);
  if (isOwnContext == false) {
    return (
      kind: SelectProblemKind.otherContext,
      where:
          "with the 'BuildContext' of another widget, because this builder doesn't "
          "run while that widget builds",
      correction: "Try using the 'BuildContext' parameter of the builder.",
    );
  }
  if (isOwnContext == true && function.isItemBuilder) {
    return (
      kind: SelectProblemKind.itemBuilder,
      where:
          "with the 'BuildContext' of an 'itemBuilder', which belongs to the list, "
          "not to the item",
      correction: "Try wrapping the item in a 'Builder', or using a separate widget.",
    );
  }
  return null;
}
