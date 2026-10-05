import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

import '../redux_types.dart';

/// Reports a `reduce` method whose return type is not `St?` or `Future<St?>`.
/// For example, `FutureOr<St?>` or `Future<St?>?`, or no return type at all,
/// which is inferred as `FutureOr<St?>`.
class ReduceReturnTypeRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'reduce_return_type',
    "The 'reduce' method must return '{1}' or 'Future<{1}>', not '{0}'.",
    correctionMessage: "Try changing the return type.",
    severity: DiagnosticSeverity.ERROR,
  );

  ReduceReturnTypeRule()
    : super(
        name: 'reduce_return_type',
        description:
            "The 'reduce' method of an action must return 'St?' or 'Future<St?>'.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addMethodDeclaration(
      this,
      _ReturnTypeVisitor(this, 'reduce', (returnType, actionType) {
        if (!mayBeFutureButIsNotFuture(
          returnType,
          context.typeProvider,
          context.typeSystem,
        )) {
          return null;
        }
        return [returnType.getDisplayString(), _nullableStateType(actionType)];
      }),
    );
  }
}

/// Reports a `before` method whose return type is not `void` or `Future<void>`.
/// For example, `FutureOr<void>` or `Future<void>?`, or no return type at all,
/// which is inferred as `FutureOr<void>`.
class BeforeReturnTypeRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'before_return_type',
    "The 'before' method must return 'void' or 'Future<void>', not '{0}'.",
    correctionMessage: "Try changing the return type.",
    severity: DiagnosticSeverity.ERROR,
  );

  BeforeReturnTypeRule()
    : super(
        name: 'before_return_type',
        description:
            "The 'before' method of an action must return 'void' or 'Future<void>'.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addMethodDeclaration(
      this,
      _ReturnTypeVisitor(this, 'before', (returnType, actionType) {
        if (!mayBeFutureButIsNotFuture(
          returnType,
          context.typeProvider,
          context.typeSystem,
        )) {
          return null;
        }
        return [returnType.getDisplayString()];
      }),
    );
  }
}

/// Reports a `wrapReduce` method whose return type is not `Future<St?>`.
/// If it returns `St?`, AsyncRedux throws at runtime. If it returns `FutureOr<St?>`
/// or `Future<St?>?`, AsyncRedux never calls it.
class WrapReduceReturnTypeRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'wrap_reduce_return_type',
    "The 'wrapReduce' method must return 'Future<{1}>', not '{0}'. {2}",
    correctionMessage: "Try changing the return type to 'Future<{1}>'.",
    severity: DiagnosticSeverity.ERROR,
  );

  WrapReduceReturnTypeRule()
    : super(
        name: 'wrap_reduce_return_type',
        description: "The 'wrapReduce' method of an action must return 'Future<St?>'.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addMethodDeclaration(
      this,
      _ReturnTypeVisitor(this, 'wrapReduce', (returnType, actionType) {
        if (isNonNullableFuture(returnType)) return null;
        var consequence =
            mayBeFutureButIsNotFuture(
              returnType,
              context.typeProvider,
              context.typeSystem,
            )
            ? "AsyncRedux never calls it."
            : "AsyncRedux throws a StoreException at runtime.";
        return [
          returnType.getDisplayString(),
          _nullableStateType(actionType),
          consequence,
        ];
      }),
    );
  }
}

/// Returns the display string of `St?`, for an action of type `ReduxAction<St>`.
String _nullableStateType(InterfaceType actionType) => actionType.typeArguments.isEmpty
    ? 'dynamic'
    : nullableDisplayString(actionType.typeArguments.first);

/// Checks the return type of the method called [methodName], when it's declared in
/// an action, or in a mixin on an action. The [check] returns the arguments of the
/// diagnostic, or null if the return type is valid.
class _ReturnTypeVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final String methodName;
  final List<Object>? Function(DartType returnType, InterfaceType actionType) check;

  _ReturnTypeVisitor(this.rule, this.methodName, this.check);

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.lexeme != methodName) return;
    if (node.isStatic || node.isGetter || node.isSetter || node.isOperator) return;

    // An abstract declaration doesn't run, so its return type doesn't matter.
    if (node.body is EmptyFunctionBody) return;

    var element = node.declaredFragment?.element;
    if (element == null) return;

    var enclosing = element.enclosingElement;
    if (enclosing is! InterfaceElement) return;

    var actionType = reduxActionSupertype(enclosing);
    if (actionType == null) return;

    var arguments = check(element.returnType, actionType);
    if (arguments == null) return;

    // Without a declared return type, the type is inferred, so we report at the name.
    var returnType = node.returnType;
    if (returnType != null) {
      rule.reportAtNode(returnType, arguments: arguments);
    } else {
      rule.reportAtToken(node.name, arguments: arguments);
    }
  }
}
