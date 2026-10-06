import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

import '../package_files.dart';
import '../names.dart';
import '../redux_types.dart';
import '../state_contents.dart';

/// Reports a field of a state class whose type is `List`, `Set` or `Map`. The docs
/// recommend `IList`, `ISet` and `IMap` of package `fast_immutable_collections`, which
/// can't be changed after they are created.
///
/// See [stateClassesIn] for the classes that are checked.
class PreferImmutableCollectionsRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'prefer_immutable_collections',
    "The field '{0}' of the state class '{1}' is a mutable '{2}'.",
    correctionMessage: "Try using '{3}' of package 'fast_immutable_collections'.",
    severity: DiagnosticSeverity.INFO,
  );

  /// The immutable collection to use instead of each mutable one.
  static const immutableCollections = {'List': 'IList', 'Set': 'ISet', 'Map': 'IMap'};

  PreferImmutableCollectionsRule()
    : super(
        name: 'prefer_immutable_collections',
        description:
            "Prefer 'IList', 'ISet' and 'IMap' to 'List', 'Set' and 'Map' in the "
            'state.',
      );

  @override
  LintCode get diagnosticCode => code;

  /// Returns the name of the mutable collection that [type] is, like `List`, or null
  /// if it's not one of `List`, `Set` or `Map` of `dart:core`.
  static String? mutableCollectionName(DartType? type) {
    if (type == null) return null;
    if (type.isDartCoreList) return 'List';
    if (type.isDartCoreSet) return 'Set';
    if (type.isDartCoreMap) return 'Map';
    return null;
  }

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    if (isTestLibrary(context)) return;
    registry.addCompilationUnit(
      this,
      _StateFieldVisitor(context, (field) {
        var collection = mutableCollectionName(field.element.type);
        if (collection == null) return;
        reportAtToken(
          field.declaration.name,
          arguments: [
            field.name,
            field.owner.displayName,
            collection,
            immutableCollections[collection]!,
          ],
        );
      }),
    );
  }
}

/// Reports a field of a state class that holds an object that is not state, like a
/// `Timer`, a `StreamSubscription` or a `TextEditingController`. The docs say streams
/// and timers go in the store props, and controllers are handled with events.
///
/// See [stateClassesIn] for the classes that are checked.
class NonStateObjectInStateRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'non_state_object_in_state',
    "The field '{0}' of the state class '{1}' holds a '{2}', which is not state.",
    correctionMessage: '{3}',
    severity: DiagnosticSeverity.WARNING,
  );

  static const _asyncTypes = {
    'Future',
    'Stream',
    'StreamController',
    'StreamSubscription',
    'Timer',
  };

  static const _widgetTypes = {'BuildContext', 'GlobalKey'};

  static const _controllerTypes = {'ChangeNotifier', 'AnimationController'};

  static const _asyncCorrection =
      "Try keeping it in the store props, with 'setProp' and 'prop', and disposing "
      "it with 'disposeProps'.";

  static const _widgetCorrection = 'Try keeping it out of the state, like in a widget.';

  static const _controllerCorrection =
      "Try keeping it in the widget, and adding an 'Event' to the state to control "
      'it.';

  NonStateObjectInStateRule()
    : super(
        name: 'non_state_object_in_state',
        description:
            'The state should not hold streams, timers, futures, a BuildContext, '
            'global keys or Flutter controllers.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addCompilationUnit(
      this,
      _StateFieldVisitor(context, (field) {
        for (var type in interfaceTypesIn(field.element.type)) {
          var correction = _correctionFor(type);
          if (correction == null) continue;
          reportAtToken(
            field.declaration.name,
            arguments: [
              field.name,
              field.owner.displayName,
              type.element.displayName,
              correction,
            ],
          );
          return;
        }
      }),
    );
  }

  /// Returns the correction message for a field that holds a [type], or null if
  /// [type] is state.
  static String? _correctionFor(InterfaceType type) {
    for (var element in [type.element, for (var t in type.allSupertypes) t.element]) {
      var uri = element.library.uri.toString();
      if (uri == 'dart:async' && _asyncTypes.contains(element.name)) {
        return _asyncCorrection;
      }
      if (uri.startsWith('package:flutter/')) {
        if (_widgetTypes.contains(element.name)) return _widgetCorrection;
        if (_controllerTypes.contains(element.name)) return _controllerCorrection;
      }
    }
    return null;
  }
}

/// Reports a field of a state class named like the current route, like
/// `currentRoute`. The docs recommend getting the current route with
/// `NavigateAction.getCurrentNavigatorRouteName(context)` instead. Opt-in, since it's
/// based on the name of the field.
///
/// See [stateClassesIn] for the classes that are checked.
class RouteInStateRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'route_in_state',
    "The field '{0}' of the state class '{1}' seems to hold the current route.",
    correctionMessage:
        "Try using 'NavigateAction.getCurrentNavigatorRouteName(context)' instead.",
    severity: DiagnosticSeverity.INFO,
  );

  static const _routeFieldNames = {'currentRoute', 'routeName', 'currentRouteName'};

  RouteInStateRule()
    : super(
        name: 'route_in_state',
        description:
            "Don't keep the current route in the state. Use "
            "'NavigateAction.getCurrentNavigatorRouteName(context)' instead.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    if (isTestLibrary(context)) return;
    registry.addCompilationUnit(
      this,
      _StateFieldVisitor(context, (field) {
        var name = withoutLeadingUnderscores(field.name);
        if (!_routeFieldNames.contains(name)) return;
        reportAtToken(
          field.declaration.name,
          arguments: [field.name, field.owner.displayName],
        );
      }),
    );
  }
}

/// Calls [check] for each field of a state class in the unit.
class _StateFieldVisitor extends SimpleAstVisitor<void> {
  final RuleContext context;
  final void Function(StateField field) check;

  _StateFieldVisitor(this.context, this.check);

  @override
  void visitCompilationUnit(CompilationUnit node) {
    for (var field in stateFieldsIn(node, context)) {
      check(field);
    }
  }
}

/// Reports the `initialState` of a `Store`, when the store's state class doesn't have
/// a static `initialState()` method, or when the initial state is created with a
/// constructor of the state class. The docs create the initial state with
/// `AppState.initialState()`.
///
/// A constructor named `initialState`, like `factory AppState.initialState()`, is also
/// accepted. Not reported in tests, which often create the store with a specific
/// state.
class MissingInitialStateRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'missing_initial_state',
    '{0}',
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.INFO,
  );

  MissingInitialStateRule()
    : super(
        name: 'missing_initial_state',
        description:
            "The store's state class should have a static 'initialState()' method, "
            "and the store should use it, like 'Store(initialState: "
            "AppState.initialState())'.",
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    if (isTestLibrary(context)) return;
    registry.addInstanceCreationExpression(this, _InitialStateVisitor(this, context));
  }
}

class _InitialStateVisitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _InitialStateVisitor(this.rule, this.context);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    var storeType = node.staticType;
    if (!isAsyncReduxClass(storeType, 'Store')) return;
    var stateType = (storeType as InterfaceType).typeArguments.firstOrNull;
    if (stateType is! InterfaceType) return;
    var state = stateType.element;
    if (state is! ClassElement || !_isOwnClass(state)) return;

    var argument = node.argumentList.arguments
        .whereType<NamedArgument>()
        .where((argument) => argument.name.lexeme == 'initialState')
        .firstOrNull
        ?.argumentExpression;
    if (argument == null) return;

    var name = state.displayName;
    var hasInitialState =
        state.getMethod('initialState')?.isStatic == true ||
        state.getNamedConstructor('initialState') != null;
    if (!hasInitialState) {
      rule.reportAtNode(
        argument,
        arguments: [
          "The state class '$name' doesn't have a static 'initialState()' method.",
          "Try adding 'static $name initialState() => $name(...);' to '$name', and "
              "using 'initialState: $name.initialState()'.",
        ],
      );
      return;
    }

    var expression = argument.unParenthesized;
    if (expression is InstanceCreationExpression) {
      var constructor = expression.constructorName.element;
      if (constructor != null &&
          constructor.enclosingElement == state &&
          constructor.name != 'initialState') {
        rule.reportAtNode(
          argument,
          arguments: [
            "The initial state is created with a constructor of '$name', instead of "
                "with '$name.initialState()'.",
            "Try using 'initialState: $name.initialState()'.",
          ],
        );
      }
    }
  }

  /// Returns true if [element] is declared in the current package, and not in the SDK
  /// or in another package, like `int` in `Store<int>`.
  bool _isOwnClass(InterfaceElement element) {
    if (isFromAsyncRedux(element)) return false;
    var package = context.package;
    if (package == null) return element.library == context.libraryElement;
    return isInPackage(element.library, package);
  }
}
