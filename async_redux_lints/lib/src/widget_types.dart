import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import 'names.dart';

/// How a widget uses the store, through its `BuildContext`.
enum StateAccess {
  /// `context.state`, or `context.getState<St>()`. Rebuilds on any state change.
  state,

  /// `context.select(...)`, or `context.getSelect<St, R>(...)`.
  select,

  /// `context.event(...)`, or `context.getEvent<St, R>(...)`.
  event,

  /// `context.read()`, or `context.getRead<St>()`.
  read,

  /// `context.isWaiting`, `isFailed`, `exceptionFor` and `clearExceptionFor`. Like
  /// `context.state`, they rebuild on any state change.
  actionStatus,

  /// `context.getEnvironment<St>()` and `context.getConfiguration<St>()`.
  environment,

  /// `context.dispatch`, `dispatchAndWait`, `dispatchAll`, `dispatchAndWaitAll` and
  /// `dispatchSync`.
  dispatch,
}

/// Returns how [element] uses the store, or null if it's not one of the
/// `BuildContext` methods of AsyncRedux.
///
/// AsyncRedux declares `getState`, `getSelect`, `getEvent`, `getRead` and others in an
/// extension on `BuildContext`. The docs recommend that apps declare their own
/// extension with `state`, `select`, `event` and `read`, which call those. These are
/// recognized by their names, when declared in an extension on `BuildContext`, in a
/// library that imports `async_redux`. The library must import `async_redux`, so that
/// the `select` and `read` extension methods of other packages, like `provider`, are
/// not recognized.
StateAccess? stateAccessOf(Element? element) {
  element = element?.baseElement;
  if (element is! ExecutableElement) return null;
  var extension = element.enclosingElement;
  if (extension is! ExtensionElement || !isBuildContext(extension.extendedType)) {
    return null;
  }

  if (isAsyncReduxLibrary(extension.library)) {
    return switch (element.name) {
      'getState' => StateAccess.state,
      'getSelect' => StateAccess.select,
      'getEvent' => StateAccess.event,
      'getRead' => StateAccess.read,
      'isWaiting' ||
      'isFailed' ||
      'exceptionFor' ||
      'clearExceptionFor' => StateAccess.actionStatus,
      'getEnvironment' || 'getConfiguration' => StateAccess.environment,
      'dispatch' ||
      'dispatchAndWait' ||
      'dispatchAll' ||
      'dispatchAndWaitAll' ||
      'dispatchSync' => StateAccess.dispatch,
      _ => null,
    };
  }

  if (!_importsAsyncRedux(extension.library)) return null;
  return switch (element) {
    GetterElement(name: 'state') => StateAccess.state,
    MethodElement(name: 'select') => StateAccess.select,
    MethodElement(name: 'event') => StateAccess.event,
    MethodElement(name: 'read') => StateAccess.read,
    _ => null,
  };
}

/// Returns how [node] uses the store, or null if it doesn't. For example,
/// [StateAccess.state] for `context.state` and [StateAccess.select] for
/// `context.select((st) => st.counter)`.
StateAccess? stateAccessOfNode(AstNode node) => switch (node) {
  PrefixedIdentifier() => stateAccessOf(node.identifier.element),
  PropertyAccess() => stateAccessOf(node.propertyName.element),
  MethodInvocation() => stateAccessOf(node.methodName.element),
  _ => null,
};

/// Returns the name of the getter or method of a state access, like `state` for
/// `context.state`.
String stateAccessName(Expression node) => switch (node) {
  PrefixedIdentifier() => node.identifier.name,
  PropertyAccess() => node.propertyName.name,
  MethodInvocation() => node.methodName.name,
  _ => '',
};

/// Returns the `context` of a state access like `context.state` or
/// `context.select(...)`, or null if it's implicit.
Expression? stateAccessTarget(Expression node) => switch (node) {
  PrefixedIdentifier() => node.prefix,
  PropertyAccess() => node.target,
  MethodInvocation() => node.target,
  _ => null,
};

bool isAsyncReduxLibrary(LibraryElement library) =>
    library.uri.toString().startsWith('package:async_redux/');

final _importsAsyncReduxCache = Expando<bool>();

bool _importsAsyncRedux(LibraryElement library) =>
    _importsAsyncReduxCache[library] ??= library.fragments.any(
      (fragment) => fragment.libraryImports.any((import) {
        var imported = import.importedLibrary;
        if (imported == null) return false;
        // A library of the app may export async_redux.
        return isAsyncReduxLibrary(imported) ||
            import.namespace.definedNames2.values.any(
              (element) =>
                  element.library != null && isAsyncReduxLibrary(element.library!),
            );
      }),
    );

/// Returns true if [type] is Flutter's `BuildContext`.
bool isBuildContext(DartType? type) =>
    type is InterfaceType && _isFlutterElement(type.element, 'BuildContext');

/// Returns true if [element] extends Flutter's `State`.
bool isFlutterState(InterfaceElement element) =>
    element.allSupertypes.any((type) => _isFlutterElement(type.element, 'State'));

/// Returns true if [element] extends Flutter's `StatelessWidget`.
bool isFlutterStatelessWidget(InterfaceElement element) => element.allSupertypes.any(
  (type) => _isFlutterElement(type.element, 'StatelessWidget'),
);

/// Returns true if [element] extends Flutter's `Widget`.
bool isFlutterWidget(InterfaceElement element) =>
    element.allSupertypes.any((type) => _isFlutterElement(type.element, 'Widget'));

bool _isFlutterElement(Element element, String name) =>
    element.name == name && _isFlutterLibrary(element.library);

bool _isFlutterLibrary(LibraryElement? library) =>
    library?.uri.toString().startsWith('package:flutter/') ?? false;

/// Returns true if [element] is the `Vm` class of package `async_redux`.
bool isVm(Element? element) =>
    element is InterfaceElement &&
    element.name == 'Vm' &&
    isAsyncReduxLibrary(element.library);

/// Returns true if [element] is a subclass of `Vm`, but not `Vm` itself.
bool isVmSubclass(InterfaceElement element) =>
    !isVm(element) && element.allSupertypes.any((type) => isVm(type.element));

/// Returns true if [element] extends the `VmFactory` class of package `async_redux`.
bool isVmFactorySubclass(InterfaceElement element) => element.allSupertypes.any(
  (type) => type.element.name == 'VmFactory' && isAsyncReduxLibrary(type.element.library),
);

/// Returns true if [node] is a closure that gets a `BuildContext`, like the
/// `builder` of a `Builder` widget, but not a local function declaration.
bool isBuilder(FunctionExpression node) {
  if (node.parent is FunctionDeclaration) return false;
  var parameters = node.parameters?.parameters ?? const <FormalParameter>[];
  return parameters.any(
    (parameter) => isBuildContext(parameter.declaredFragment?.element.type),
  );
}

/// A `build` method, or a builder closure like `Builder(builder: (context) => ...)`.
class BuildFunction {
  /// The `BuildContext` parameter.
  final FormalParameterElement? context;

  /// True for the `build` method of a `State`, where the `context` getter of the
  /// `State` is the same as the [context] parameter.
  final bool isStateBuild;

  /// True for a builder of the items of a list, like the `itemBuilder` of
  /// `ListView.builder`. Its `BuildContext` is the list's, not the item's.
  final bool isItemBuilder;

  BuildFunction._(this.context, {this.isStateBuild = false, this.isItemBuilder = false});
}

/// Returns the `build` method or builder closure that runs [node] while the widget
/// builds, or null if there's none, or it's not known.
///
/// Other closures in between, like `items.map((item) => ...)`, make the result
/// unknown, unless [throughClosures] is true. Callbacks like `onPressed: () => ...`,
/// and closures passed to methods like `addPostFrameCallback`, always do. So do
/// closures that get a `BuildContext` but are callbacks, like
/// `onInit: (context) => ...`.
BuildFunction? enclosingBuildFunction(AstNode node, {bool throughClosures = false}) {
  for (var ancestor = node.parent; ancestor != null; ancestor = ancestor.parent) {
    switch (ancestor) {
      case FunctionExpression():
        if (ancestor.parent is FunctionDeclaration) return null;
        if (_callbackName(ancestor) != null || _deferringCallee(ancestor) != null) {
          return null;
        }
        if (isBuilder(ancestor)) {
          var context = ancestor.parameters?.parameters
              .map((parameter) => parameter.declaredFragment?.element)
              .firstWhere((element) => isBuildContext(element?.type), orElse: () => null);
          return BuildFunction._(context, isItemBuilder: _isItemBuilder(ancestor));
        }
        if (!throughClosures) return null;
      case MethodDeclaration():
        if (ancestor.name.lexeme != 'build') return null;
        var element = ancestor.declaredFragment?.element;
        var enclosing = element?.enclosingElement;
        return BuildFunction._(
          element?.formalParameters
              .where((parameter) => isBuildContext(parameter.type))
              .firstOrNull,
          isStateBuild: enclosing is InterfaceElement && isFlutterState(enclosing),
        );
      case FunctionDeclaration():
      case CompilationUnit():
        return null;
    }
  }
  return null;
}

/// Returns true if [node] runs while the widget builds: directly in a `build`
/// method, or in a builder like `Builder(builder: (context) => ...)`. Code in other
/// closures inside them, like `onPressed: () => ...`, is not considered.
bool runsWhileBuilding(AstNode node) => enclosingBuildFunction(node) != null;

/// Returns true if [target], the `context` of a state access, is the `BuildContext`
/// of [function]. Returns false if it's the `BuildContext` of another widget: the
/// parameter of another `build` method or builder, or the `context` of a `State`
/// used in a builder. Returns null if it's not known.
bool? isContextOf(Expression? target, BuildFunction function) {
  if (target is! SimpleIdentifier) return null;
  var element = target.element?.baseElement;
  if (element is FormalParameterElement) {
    if (!isBuildContext(element.type)) return null;
    return element == function.context?.baseElement;
  }
  if (element is GetterElement && element.name == 'context') {
    var enclosing = element.enclosingElement;
    if (enclosing is InterfaceElement &&
        (_isFlutterElement(enclosing, 'State') || isFlutterState(enclosing))) {
      return function.isStateBuild;
    }
  }
  return null;
}

/// Returns true if [node] can use `context.select` with [target] as its `context`:
/// it runs while the widget builds, [target] is the `BuildContext` of that widget,
/// and it's not in the `itemBuilder` of a list.
bool canUseSelect(AstNode node, Expression? target) {
  var function = enclosingBuildFunction(node);
  return function != null &&
      !function.isItemBuilder &&
      isContextOf(target, function) == true;
}

/// Returns true if [node] is in the `didChangeDependencies` method of a `State`, and
/// [target], the `context` of a state access, is the `context` of that `State`.
/// `context.select` and `context.event` work there, and make `didChangeDependencies`
/// run again when the selected value changes.
bool isInDidChangeDependencies(AstNode node, Expression? target) =>
    notBuilding(node)?.stateMethod == 'didChangeDependencies' &&
    isContextOf(target, BuildFunction._(null, isStateBuild: true)) == true;

/// Returns true if [closure] builds the items of a list, like the `itemBuilder` of
/// `ListView.builder`, or the `builder` of a `SliverChildBuilderDelegate`. Its
/// `BuildContext` is the list's.
bool _isItemBuilder(FunctionExpression closure) {
  var parameters = closure.parameters?.parameters;
  if (parameters == null || parameters.length < 2) return false;
  var index = parameters[1].declaredFragment?.element.type;
  if (index == null || !index.isDartCoreInt) return false;

  var parent = closure.parent;
  var name = parent is NamedArgument ? parent.name.lexeme : null;
  var arguments = parent is NamedArgument ? parent.parent : parent;
  if (arguments is! ArgumentList) return false;
  var invocation = arguments.parent;
  if (invocation is InstanceCreationExpression) {
    if (!_isFlutterLibrary(invocation.constructorName.element?.library)) return false;
    if (name == null) {
      return invocation.constructorName.type.element?.name ==
          'SliverChildBuilderDelegate';
    }
  } else if (invocation is MethodInvocation) {
    if (!_isFlutterLibrary(invocation.methodName.element?.library)) return false;
  } else {
    return false;
  }
  return name == 'itemBuilder' || name == 'separatorBuilder';
}

/// Returns the name of the callback, like `onPressed`, if [closure] is passed as a
/// named argument that starts with `on`.
String? _callbackName(FunctionExpression closure) {
  var parent = closure.parent;
  return parent is NamedArgument && _isCallbackName(parent.name.lexeme)
      ? parent.name.lexeme
      : null;
}

/// Returns true if [name] is `on` followed by an uppercase letter, like `onPressed`.
bool _isCallbackName(String name) =>
    name.length > 2 &&
    name.codeUnitAt(0) == 0x6F && // o
    name.codeUnitAt(1) == 0x6E && // n
    isUppercase(name.codeUnitAt(2));

/// Methods and constructors of the Dart and Flutter SDKs, whose closures don't run
/// immediately, or don't run while the widget builds.
const _deferringCallees = {
  'addPostFrameCallback',
  'addPersistentFrameCallback',
  'scheduleFrameCallback',
  'scheduleMicrotask',
  'then',
  'catchError',
  'whenComplete',
  'listen',
  'addListener',
  'setState',
  'Future',
  'Future.microtask',
  'Future.delayed',
  'Timer',
  'Timer.periodic',
  'Timer.run',
};

/// Returns true if [closure] is passed to a method or constructor of the Dart and
/// Flutter SDKs that runs it later, like `Future.microtask` or `addPostFrameCallback`.
bool runsLater(FunctionExpression closure) => _deferringCallee(closure) != null;

/// Returns the name of the method or constructor, like `addPostFrameCallback`, if
/// [closure] is passed to one that runs it later, or outside of `build`.
String? _deferringCallee(FunctionExpression closure) {
  var arguments = closure.parent;
  if (arguments is NamedArgument) arguments = arguments.parent;
  if (arguments is! ArgumentList) return null;
  var invocation = arguments.parent;

  String name;
  Element? element;
  switch (invocation) {
    case MethodInvocation():
      name = invocation.methodName.name;
      element = invocation.methodName.element;
    case InstanceCreationExpression():
      var constructor = invocation.constructorName;
      var className = constructor.type.name.lexeme;
      name = constructor.name == null
          ? className
          : '$className.${constructor.name!.name}';
      element = constructor.element;
    default:
      return null;
  }
  if (!_deferringCallees.contains(name)) return null;
  var library = element?.library;
  if (library == null || !(library.isInSdk || _isFlutterLibrary(library))) return null;
  return name;
}

/// Code that doesn't run while the widget builds.
typedef NotBuilding = ({
  /// A description of the code, like "the 'onPressed' callback".
  String description,

  /// The `State` method that contains the code, like `initState`, or null if the
  /// code is a callback.
  String? stateMethod,
});

const _stateLifecycleMethods = {
  'initState',
  'didChangeDependencies',
  'didUpdateWidget',
  'activate',
  'deactivate',
  'dispose',
  'reassemble',
};

/// Returns the code around [node] that doesn't run while the widget builds, or null
/// if that code may run while the widget builds.
///
/// These are closures passed as a named argument that starts with `on`, like
/// `onPressed`, closures passed to methods like `addPostFrameCallback`, `Timer` or
/// `setState`, and the `State` methods `initState`, `didChangeDependencies`,
/// `didUpdateWidget`, `activate`, `deactivate`, `dispose` and `reassemble`.
NotBuilding? notBuilding(AstNode node) {
  for (var ancestor = node.parent; ancestor != null; ancestor = ancestor.parent) {
    switch (ancestor) {
      case FunctionExpression():
        if (isBuilder(ancestor)) return null;
        var callback = _callbackName(ancestor);
        if (callback != null) {
          return (description: "the '$callback' callback", stateMethod: null);
        }
        var callee = _deferringCallee(ancestor);
        if (callee != null) {
          return (description: "a closure passed to '$callee'", stateMethod: null);
        }
      case MethodDeclaration():
        var name = ancestor.name.lexeme;
        var enclosing = ancestor.declaredFragment?.element.enclosingElement;
        if (_stateLifecycleMethods.contains(name) &&
            enclosing is InterfaceElement &&
            isFlutterState(enclosing)) {
          return (description: "'$name'", stateMethod: name);
        }
        return null;
      case FunctionDeclaration():
      case ClassDeclaration():
      case CompilationUnit():
        return null;
    }
  }
  return null;
}

/// Returns true if [node] is directly in the `initState` method of a `State`, and
/// not in a closure inside it, like `addPostFrameCallback((_) => ...)`.
bool isInInitState(AstNode node) {
  for (var ancestor = node.parent; ancestor != null; ancestor = ancestor.parent) {
    switch (ancestor) {
      case FunctionExpression():
      case FunctionDeclaration():
      case CompilationUnit():
        return false;
      case MethodDeclaration():
        return ancestor.name.lexeme == 'initState' && _isStateMethod(ancestor);
    }
  }
  return false;
}

/// Returns true if [node] is in the `dispose` method of a `State`, including in
/// closures inside it. When `dispose` runs, or later, the widget is no longer in the
/// tree.
bool isInDispose(AstNode node) {
  var method = node.thisOrAncestorOfType<MethodDeclaration>();
  return method != null && method.name.lexeme == 'dispose' && _isStateMethod(method);
}

bool _isStateMethod(MethodDeclaration method) {
  var enclosing = method.declaredFragment?.element.enclosingElement;
  return enclosing is InterfaceElement && isFlutterState(enclosing);
}

/// Returns the selector of the `context.select` or `context.event` that contains
/// [node], like `(st) => st.counter`, or null if there's none.
FunctionExpression? enclosingSelector(AstNode node) {
  for (var ancestor = node.parent; ancestor != null; ancestor = ancestor.parent) {
    if (ancestor is! FunctionExpression) continue;
    var arguments = ancestor.parent;
    if (arguments is! ArgumentList || arguments.arguments.firstOrNull != ancestor) {
      continue;
    }
    var invocation = arguments.parent;
    if (invocation is! MethodInvocation) continue;
    var access = stateAccessOfNode(invocation);
    if (access == StateAccess.select || access == StateAccess.event) return ancestor;
  }
  return null;
}
