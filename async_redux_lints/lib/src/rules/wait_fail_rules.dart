import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/type_provider.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:analyzer/error/error.dart';

import '../redux_types.dart';

/// Reports an argument of `isWaiting`, `isFailed`, `exceptionFor` or
/// `clearExceptionFor` that AsyncRedux rejects at runtime.
///
/// `isWaiting` accepts an action, an action type, or a list of them. The other
/// methods accept an action type, or a list of action types. Note that `isFailed`
/// doesn't accept actions, since it calls `exceptionFor`.
///
/// Only reports when the argument's static type can't be accepted. For example,
/// it doesn't report an argument typed as `Object`.
class WaitFailInvalidArgumentRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'wait_fail_invalid_argument',
    "'{0}' accepts only {1}, not '{2}'.",
    correctionMessage: "Try passing an action type instead.",
    severity: DiagnosticSeverity.ERROR,
  );

  WaitFailInvalidArgumentRule()
    : super(
        name: 'wait_fail_invalid_argument',
        description:
            "'isWaiting', 'isFailed', 'exceptionFor' and 'clearExceptionFor' "
            "accept only actions and action types, or lists of them.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    var checker = _sharedChecker(this, registry, context);
    checker?.onInvalid = (node, arguments) => reportAtNode(node, arguments: arguments);
  }
}

/// Reports an argument of `isWaiting`, `isFailed`, `exceptionFor` or
/// `clearExceptionFor` that AsyncRedux accepts, but that can never match an action.
/// For example:
///
/// - A type that is not an action type, like `isWaiting(AppState)`.
/// - An abstract action type, like `isWaiting(AppAction)`, since AsyncRedux compares
///   the exact type of the actions, and not their subtypes.
/// - `isWaiting` with a sync action type, since sync actions finish synchronously.
/// - `isWaiting` with an action created right there, like `isWaiting(MyAction())`,
///   since that action was never dispatched.
class WaitFailNeverMatchesRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'wait_fail_never_matches',
    "'{0}' never matches '{1}', because {2}.",
    correctionMessage: "Try passing the type of a concrete action instead.",
    severity: DiagnosticSeverity.WARNING,
  );

  WaitFailNeverMatchesRule()
    : super(
        name: 'wait_fail_never_matches',
        description:
            "The argument of 'isWaiting', 'isFailed', 'exceptionFor' and "
            "'clearExceptionFor' should be able to match an action.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    var checker = _sharedChecker(this, registry, context);
    checker?.onNeverMatches = (node, arguments) =>
        reportAtNode(node, arguments: arguments);
  }
}

/// Returns the checker shared by the rules of [registry], or null if there's no
/// library.
///
/// Both rules check the same arguments, so they share a single visitor and checker for
/// each registry, which checks each argument once, and then reports with the callback
/// of each rule. Errors thrown by the checker are attributed to the first rule.
_WaitFailChecker? _sharedChecker(
  AnalysisRule rule,
  RuleVisitorRegistry registry,
  RuleContext context,
) {
  var library = context.libraryElement;
  if (library == null) return null;
  var visitor = _visitors[registry];
  if (visitor == null) {
    visitor = _visitors[registry] = _Visitor(
      _WaitFailChecker(library, context.typeProvider, context.typeSystem),
    );
    registry.addMethodInvocation(rule, visitor);
  }
  return visitor.checker;
}

/// The shared visitor of each registry. The plugin creates a new registry for each
/// analysis of a library.
final _visitors = Expando<_Visitor>();

class _Visitor extends SimpleAstVisitor<void> {
  final _WaitFailChecker checker;

  _Visitor(this.checker);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    var call = waitFailArgument(node);
    if (call == null) return;
    checker.checkArgument(call.methodName, call.argument);
  }
}

/// The names of the parameters that receive the action, type or list.
const _parameterNames = {'actionOrTypeOrList', 'actionTypeOrList'};

const _methodNames = {'isWaiting', 'isFailed', 'exceptionFor', 'clearExceptionFor'};

/// If [node] calls `isWaiting`, `isFailed`, `exceptionFor` or `clearExceptionFor`
/// of package `async_redux`, returns the method name and the argument with the
/// actions or types. Otherwise, returns null.
///
/// This works for `store.isWaiting(...)`, `context.isWaiting(...)`, and
/// `isWaiting(...)` inside actions and view-model factories, as well as
/// `StoreProvider.isWaiting(context, ...)`.
({String methodName, Expression argument})? waitFailArgument(MethodInvocation node) {
  var methodName = node.methodName.name;
  if (!_methodNames.contains(methodName)) return null;

  var element = node.methodName.element;
  if (element is! ExecutableElement ||
      !element.library.uri.toString().startsWith('package:async_redux/')) {
    return null;
  }

  for (var argument in node.argumentList.arguments) {
    if (argument is! Expression) continue;
    if (_parameterNames.contains(argument.correspondingParameter?.name)) {
      return (methodName: methodName, argument: argument);
    }
  }
  return null;
}

typedef _Report = void Function(AstNode node, List<Object> arguments);

class _WaitFailChecker {
  final LibraryElement library;
  final TypeProvider typeProvider;
  final TypeSystem typeSystem;

  /// Reports for `wait_fail_invalid_argument`, or null if that rule is off.
  _Report? onInvalid;

  /// Reports for `wait_fail_never_matches`, or null if that rule is off.
  _Report? onNeverMatches;

  _WaitFailChecker(this.library, this.typeProvider, this.typeSystem);

  void checkArgument(String methodName, Expression argument) {
    var check = _Check(this, methodName);

    if (argument is ListLiteral) {
      argument.elements.forEach(check.collectionElement);
    } else if (argument is SetOrMapLiteral && argument.isSet) {
      argument.elements.forEach(check.collectionElement);
    } else if (_iterableElementType(argument.staticType) case var elementType?) {
      // For example, a `List<String>` variable.
      if (check.isInvalid(elementType))
        check.reportInvalid(argument, argument.staticType!);
    } else {
      check.item(argument);
    }
  }

  /// Returns the type `T` if [type] is an `Iterable<T>`, or null otherwise.
  DartType? _iterableElementType(DartType? type) {
    if (type is! InterfaceType) return null;
    return type.asInstanceOf(typeProvider.iterableElement)?.typeArguments.first;
  }
}

/// Checks the argument of a single call.
class _Check {
  final _WaitFailChecker checker;
  final String methodName;

  _Check(this.checker, this.methodName);

  /// Only `isWaiting` accepts actions. The others accept only action types.
  bool get acceptsActions => methodName == 'isWaiting';

  String get _accepted => acceptsActions
      ? 'an action, an action type, or a list of them'
      : 'an action type, or a list of action types';

  void collectionElement(CollectionElement element) {
    switch (element) {
      case Expression():
        item(element);
      case IfElement():
        collectionElement(element.thenElement);
        if (element.elseElement case var elseElement?) collectionElement(elseElement);
      case ForElement():
        collectionElement(element.body);
      case SpreadElement():
        var elementType = checker._iterableElementType(element.expression.staticType);
        if (elementType != null && isInvalid(elementType)) {
          reportInvalid(element.expression, element.expression.staticType!);
        }
      default:
        break;
    }
  }

  /// Checks a single action or type, passed directly or inside a list.
  void item(Expression expression) {
    var type = expression.staticType;
    if (type == null) return;

    if (isInvalid(type)) {
      reportInvalid(expression, type);
    } else if (checker.onNeverMatches == null) {
      return;
    } else if (expression is TypeLiteral) {
      _typeLiteral(expression);
    } else if (acceptsActions &&
        expression is InstanceCreationExpression &&
        isActionType(type)) {
      // Actions are compared by identity, and actions can't be const.
      _reportNeverMatches(
        expression,
        expression.constructorName.type.name.lexeme,
        'this action is created here, so it was never dispatched',
      );
    }
  }

  void _typeLiteral(TypeLiteral literal) {
    var type = literal.type.type;
    if (type is! InterfaceType) return;
    var element = type.element;
    var name = element.displayName;

    if (!isActionType(type)) {
      _reportNeverMatches(literal, name, "'$name' is not an action type");
    } else if (element is! ClassElement || element.isAbstract) {
      var kind = switch (element) {
        ClassElement() => 'abstract',
        MixinElement() => 'a mixin',
        _ => 'not a class',
      };
      _reportNeverMatches(
        literal,
        name,
        "'$name' is $kind, and AsyncRedux only matches actions of exactly this type, "
        "not of its subtypes",
      );
    } else if (acceptsActions &&
        isKnownSyncAction(type, checker.library, checker.typeSystem)) {
      _reportNeverMatches(
        literal,
        name,
        "'$name' is a sync action, and sync actions finish before they can be waited on",
      );
    }
  }

  /// Returns true if AsyncRedux throws for an action or type of [type], passed
  /// directly or inside a list. Returns false when [type] is unknown, like `Object`.
  bool isInvalid(DartType type) {
    if (type is DynamicType || type is InvalidType) return false;
    var typeType = checker.typeProvider.typeType;
    var typeSystem = checker.typeSystem;
    if (typeSystem.isSubtypeOf(type, typeType) ||
        typeSystem.isSubtypeOf(typeType, type)) {
      return false;
    }
    if (acceptsActions && isActionType(type)) return false;
    // A type parameter may be an action or a type.
    if (type is TypeParameterType) return isInvalid(type.bound);
    return true;
  }

  void reportInvalid(AstNode node, DartType type) =>
      checker.onInvalid?.call(node, [methodName, _accepted, type.getDisplayString()]);

  void _reportNeverMatches(AstNode node, String name, String reason) =>
      checker.onNeverMatches?.call(node, [methodName, name, reason]);
}
