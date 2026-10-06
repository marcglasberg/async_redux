import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

import '../package_files.dart';
import '../source_text.dart';
import '../widget_types.dart';

/// Reports a `UserExceptionDialog` that is not below both the `StoreProvider` and the
/// `MaterialApp` (or `CupertinoApp`):
///
/// - Above the `StoreProvider`, it can't read the errors from the store.
/// - Above the `MaterialApp`, it can't show dialogs.
/// - In the `builder` of the `MaterialApp`, it's above the app's `Navigator`, so it
///   needs the `navigatorKey` of the `MaterialApp`, also set with
///   `NavigateAction.setNavigatorKey`, and can't use `useLocalContext: true`.
///
/// Only sees what's in the same file. A `UserExceptionDialog` in another widget, like
/// the home page, is not reported.
class UserExceptionDialogPlacementRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'user_exception_dialog_placement',
    "This 'UserExceptionDialog' is {0}.",
    correctionMessage: "{1}",
    severity: DiagnosticSeverity.ERROR,
  );

  UserExceptionDialogPlacementRule()
    : super(
        name: 'user_exception_dialog_placement',
        description:
            "A 'UserExceptionDialog' must be below both the 'StoreProvider' and the "
            "'MaterialApp'.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addCompilationUnit(this, _PlacementVisitor(this, context));
  }
}

class _PlacementVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _PlacementVisitor(this.rule, this.context);

  @override
  void visitCompilationUnit(CompilationUnit node) {
    // Finding the app setup visits the whole unit, which isn't needed in the files
    // that don't mention the dialog.
    if (!mayContainName(context, node, 'UserExceptionDialog')) return;
    var setup = AppSetup.of(node);
    for (var dialog in setup.dialogs) {
      _check(dialog, setup);
    }
  }

  void _check(InstanceCreationExpression dialog, AppSetup setup) {
    var at = dialog.constructorName;

    for (var provider in setup.storeProviders) {
      if (argumentNameIn(dialog, provider) == 'child') {
        rule.reportAtNode(
          at,
          arguments: [
            "above the 'StoreProvider', so it can't read the errors from the store",
            "Try moving it below the 'StoreProvider', to the 'home' of the "
                "'MaterialApp'.",
          ],
        );
        return;
      }
    }

    for (var app in setup.apps) {
      if (argumentNameIn(dialog, app) == 'child') {
        var name = appName(app);
        rule.reportAtNode(
          at,
          arguments: [
            "above the '$name', so it can't show dialogs",
            "Try moving it to the 'home' of the '$name'.",
          ],
        );
        return;
      }
    }

    var app = _enclosingApp(dialog);
    if (app == null || argumentNameIn(app, dialog) != 'builder') return;
    var name = appName(app);

    var useLocalContext = namedArgument(dialog, 'useLocalContext');
    if (useLocalContext case NamedArgument(
      argumentExpression: BooleanLiteral(value: true),
    )) {
      rule.reportAtNode(
        useLocalContext,
        arguments: [
          "in the 'builder' of the '$name', above its 'Navigator', so it can't use "
              "'useLocalContext: true'",
          "Try removing 'useLocalContext: true', or moving the 'UserExceptionDialog' "
              "to the 'home' of the '$name'.",
        ],
      );
      return;
    }

    // The `router` constructors don't have a `navigatorKey`. The key is set in the
    // router instead.
    if (!isRouterApp(app) && namedArgument(app, 'navigatorKey') == null) {
      rule.reportAtNode(
        at,
        arguments: [
          "in the 'builder' of the '$name', which doesn't have a 'navigatorKey'",
          "Try adding a 'navigatorKey' to the '$name', also set with "
              "'NavigateAction.setNavigatorKey', or moving the 'UserExceptionDialog' "
              "to the 'home'.",
        ],
      );
    }
  }

  /// Returns the closest `MaterialApp` or `CupertinoApp` that has [node] in one of its
  /// arguments.
  static InstanceCreationExpression? _enclosingApp(AstNode node) {
    for (var ancestor = node.parent; ancestor != null; ancestor = ancestor.parent) {
      if (ancestor is InstanceCreationExpression && isFlutterApp(ancestor)) {
        return ancestor;
      }
    }
    return null;
  }
}

/// Reports, in a file that calls `NavigateAction.setNavigatorKey(key)`, a
/// `MaterialApp` (or `CupertinoApp`) without `navigatorKey: key`. `NavigateAction`
/// needs the same key in both places.
///
/// Reported at the `MaterialApp` when it doesn't have a `navigatorKey`, and at its
/// `navigatorKey` when it's not the key passed to `setNavigatorKey`. Keys are only
/// compared when they are variables, getters, or new `GlobalKey`s.
class NavigatorKeyNotSetRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'navigator_key_not_set',
    "{0}",
    correctionMessage: "{1}",
    severity: DiagnosticSeverity.WARNING,
  );

  NavigatorKeyNotSetRule()
    : super(
        name: 'navigator_key_not_set',
        description:
            "The key passed to 'NavigateAction.setNavigatorKey' must also be the "
            "'navigatorKey' of the 'MaterialApp'.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addCompilationUnit(this, _NavigatorKeyVisitor(this, context));
  }
}

class _NavigatorKeyVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _NavigatorKeyVisitor(this.rule, this.context);

  @override
  void visitCompilationUnit(CompilationUnit node) {
    // Finding the app setup visits the whole unit, which isn't needed in the files
    // that don't call `setNavigatorKey`.
    if (!mayContainName(context, node, 'setNavigatorKey')) return;
    var setup = AppSetup.of(node);
    var setKeys = [
      for (var call in setup.setNavigatorKeyCalls)
        if (call.argumentList.arguments.firstOrNull?.argumentExpression case var key?)
          key,
    ];
    if (setKeys.isEmpty) return;

    for (var app in setup.apps) {
      // The `router` constructors don't have a `navigatorKey`.
      if (isRouterApp(app)) continue;
      var name = appName(app);
      var argument = namedArgument(app, 'navigatorKey');
      if (argument == null) {
        rule.reportAtNode(
          app.constructorName,
          arguments: [
            "This '$name' doesn't have a 'navigatorKey', but "
                "'NavigateAction.setNavigatorKey' is called.",
            "Try adding the key passed to 'NavigateAction.setNavigatorKey' as the "
                "'navigatorKey' of the '$name'.",
          ],
        );
      } else if (setKeys.every(
        (key) => sameKey(argument.argumentExpression, key) == false,
      )) {
        rule.reportAtNode(
          argument.argumentExpression,
          arguments: [
            "This 'navigatorKey' is not the key passed to "
                "'NavigateAction.setNavigatorKey'.",
            "Try using the same key in both places.",
          ],
        );
      }
    }
  }
}

/// Reports `ConsoleActionObserver`, `Log.printer` or `DefaultModelObserver` passed to
/// the `Store` outside of an `if` or a conditional expression, like
/// `kReleaseMode ? null : [ConsoleActionObserver()]`. They are for development only.
///
/// Any condition is accepted, since the app may check the environment in other ways.
/// Not reported in tests.
class DebugObserverInReleaseRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'debug_observer_in_release',
    "'{0}' is meant for development, but it's also used in release builds.",
    correctionMessage:
        "Try using it only in debug builds, like "
        "'kReleaseMode ? null : ...', or 'if (kDebugMode) ...' in a list.",
    severity: DiagnosticSeverity.INFO,
  );

  DebugObserverInReleaseRule()
    : super(
        name: 'debug_observer_in_release',
        description:
            "'ConsoleActionObserver', 'Log.printer' and 'DefaultModelObserver' are "
            "meant for development only.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    if (isLibraryInTestDirectory(context)) return;
    registry.addInstanceCreationExpression(this, _DebugObserverVisitor(this));
  }
}

class _DebugObserverVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _DebugObserverVisitor(this.rule);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    var name = _debugObserverName(node);
    if (name == null) return;

    var inStore = false;
    AstNode child = node;
    for (var parent = node.parent; parent != null; parent = parent.parent) {
      if (_isConditionalBranch(parent, child)) return;
      if (parent is InstanceCreationExpression && _isStore(parent)) inStore = true;
      if (parent is CompilationUnit) break;
      child = parent;
    }
    if (inStore) rule.reportAtNode(node.constructorName, arguments: [name]);
  }

  /// Returns the name of the observer created by [node], like `Log.printer`, or null
  /// if it's not one of the observers meant for development.
  static String? _debugObserverName(InstanceCreationExpression node) {
    var element = node.constructorName.element;
    var enclosing = element?.enclosingElement;
    if (element == null ||
        enclosing is! InterfaceElement ||
        !isAsyncReduxLibrary(enclosing.library)) {
      return null;
    }
    return switch ((enclosing.name, element.name)) {
      ('ConsoleActionObserver', _) => 'ConsoleActionObserver',
      ('DefaultModelObserver', _) => 'DefaultModelObserver',
      ('Log', 'printer') => 'Log.printer',
      _ => null,
    };
  }

  /// Returns true if [child] is one of the branches of [parent], an `if` or a
  /// conditional expression.
  static bool _isConditionalBranch(AstNode parent, AstNode child) => switch (parent) {
    IfStatement() => child != parent.expression,
    IfElement() => child != parent.expression,
    ConditionalExpression() => child != parent.condition,
    _ => false,
  };

  static bool _isStore(InstanceCreationExpression node) {
    var element = node.constructorName.type.element;
    return element is InterfaceElement &&
        [element.thisType, ...element.allSupertypes].any(
          (type) =>
              type.element.name == 'Store' && isAsyncReduxLibrary(type.element.library),
        );
  }
}

// -----------------------------------------------------------------------------
// Helpers shared by the rules and fixes of the store and app setup.

/// The widgets and calls of a file that set up the store and the app.
class AppSetup {
  final List<InstanceCreationExpression> storeProviders = [];

  /// `MaterialApp` and `CupertinoApp`, created with any of their constructors.
  final List<InstanceCreationExpression> apps = [];

  final List<InstanceCreationExpression> dialogs = [];

  /// `NavigateAction.setNavigatorKey(...)`.
  final List<MethodInvocation> setNavigatorKeyCalls = [];

  static final _cache = Expando<AppSetup>();

  static AppSetup of(CompilationUnit unit) => _cache[unit] ??= _find(unit);

  static AppSetup _find(CompilationUnit unit) {
    var setup = AppSetup();
    unit.accept(_AppSetupFinder(setup));
    return setup;
  }
}

class _AppSetupFinder extends RecursiveAstVisitor<void> {
  final AppSetup setup;

  _AppSetupFinder(this.setup);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (isFlutterApp(node)) {
      setup.apps.add(node);
    } else if (_isAsyncReduxClass(node, 'StoreProvider')) {
      setup.storeProviders.add(node);
    } else if (_isAsyncReduxClass(node, 'UserExceptionDialog')) {
      setup.dialogs.add(node);
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    var element = node.methodName.element;
    if (element is MethodElement &&
        element.isStatic &&
        element.name == 'setNavigatorKey' &&
        _isNavigateAction(element.enclosingElement)) {
      setup.setNavigatorKeyCalls.add(node);
    }
    super.visitMethodInvocation(node);
  }

  static bool _isAsyncReduxClass(InstanceCreationExpression node, String name) {
    var element = node.constructorName.type.element;
    return element is InterfaceElement &&
        element.name == name &&
        isAsyncReduxLibrary(element.library);
  }
}

bool _isNavigateAction(Element? element) =>
    element is InterfaceElement &&
    element.name == 'NavigateAction' &&
    isAsyncReduxLibrary(element.library);

/// Returns true if [node] creates Flutter's `MaterialApp` or `CupertinoApp`.
bool isFlutterApp(InstanceCreationExpression node) {
  var element = node.constructorName.type.element;
  return element is InterfaceElement &&
      (element.name == 'MaterialApp' || element.name == 'CupertinoApp') &&
      element.library.uri.toString().startsWith('package:flutter/');
}

/// Returns true if [app] is created with `MaterialApp.router` or `CupertinoApp.router`.
bool isRouterApp(InstanceCreationExpression app) =>
    app.constructorName.name?.name == 'router';

/// Returns `MaterialApp` or `CupertinoApp`.
String appName(InstanceCreationExpression app) =>
    app.constructorName.type.element?.name ?? 'MaterialApp';

/// Returns the argument named [name] of [creation], or null if there's none.
NamedArgument? namedArgument(InstanceCreationExpression creation, String name) => creation
    .argumentList
    .arguments
    .whereType<NamedArgument>()
    .where((argument) => argument.name.lexeme == name)
    .firstOrNull;

/// Returns the name of the argument of [creation] that contains [node], or null if
/// [node] is not in a named argument of [creation].
String? argumentNameIn(InstanceCreationExpression creation, AstNode node) {
  for (AstNode? child = node; child != null; child = child.parent) {
    if (child.parent == creation.argumentList) {
      return (child is NamedArgument) ? child.name.lexeme : null;
    }
  }
  return null;
}

/// Returns true if [a] and [b] are the same `navigatorKey`, false if they are
/// different, or null if that's not known.
bool? sameKey(Expression a, Expression b) {
  var keyA = _keyIdentity(a);
  var keyB = _keyIdentity(b);
  if (keyA == null || keyB == null) return null;
  // `NavigateAction.navigatorKey` is the key passed to `setNavigatorKey`.
  if (keyA == _KeyIdentity.navigateActionKey || keyB == _KeyIdentity.navigateActionKey) {
    return true;
  }
  // Each `GlobalKey()` is a different key.
  if (keyA == _KeyIdentity.newKey || keyB == _KeyIdentity.newKey) return false;
  return keyA == keyB;
}

enum _KeyIdentity { navigateActionKey, newKey }

/// Returns the variable or getter that holds the key [expression], or a
/// [_KeyIdentity], or null if it's not known.
Object? _keyIdentity(Expression expression) {
  expression = expression.unParenthesized;
  if (expression is InstanceCreationExpression) return _KeyIdentity.newKey;
  var element = switch (expression) {
    SimpleIdentifier() => expression.element,
    PrefixedIdentifier() => expression.identifier.element,
    PropertyAccess() => expression.propertyName.element,
    _ => null,
  };
  if (element is PropertyAccessorElement) {
    if (element.name == 'navigatorKey' && _isNavigateAction(element.enclosingElement)) {
      return _KeyIdentity.navigateActionKey;
    }
    return element.variable.baseElement;
  }
  if (element is VariableElement) return element.baseElement;
  return null;
}
