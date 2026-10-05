import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/type_provider.dart';
import 'package:analyzer/dart/element/type_system.dart';

/// Returns true if [element] is the `ReduxAction` class of package `async_redux`.
bool isReduxAction(Element? element) =>
    element is InterfaceElement &&
    element.name == 'ReduxAction' &&
    element.library.uri.toString().startsWith('package:async_redux/');

/// Returns true if [element] is annotated with `@stateClass` or `@StateClass()`
/// of package `async_redux`.
///
/// The rules check the supertypes of every class, which are mostly the same classes,
/// so the result is cached. When a file changes, the analyzer creates new elements for
/// its library, so the cached values of the old elements are not used anymore.
bool hasStateClassAnnotation(Element element) => _stateClassAnnotationCache[element] ??=
    element.metadata.annotations.any((annotation) {
      var annotationElement = annotation.element;
      var isStateClass = switch (annotationElement) {
        GetterElement(:var name) => name == 'stateClass',
        ConstructorElement(:var enclosingElement) =>
          enclosingElement.name == 'StateClass',
        _ => false,
      };
      return isStateClass &&
          annotationElement!.library!.uri.toString().startsWith('package:async_redux/');
    });

final _stateClassAnnotationCache = Expando<bool>();

/// Returns the `ReduxAction<St>` supertype of [element], or null if [element]
/// is not an action (or mixin on an action). Returns null for `ReduxAction` itself.
InterfaceType? reduxActionSupertype(InterfaceElement element) {
  if (isReduxAction(element)) return null;
  for (var type in element.allSupertypes) {
    if (isReduxAction(type.element)) return type;
  }
  return null;
}

/// Returns true if [type] is `Future<T>`, but not `Future<T>?`.
bool isNonNullableFuture(DartType type) =>
    type.isDartAsyncFuture && type.nullabilitySuffix == NullabilitySuffix.none;

/// Returns true if a value of [type] may be a `Future`, without [type] being a
/// non-nullable `Future`. For example: `FutureOr<T>`, `Future<T>?`, `Object?`
/// and `dynamic`. Returns false for `void`.
///
/// AsyncRedux checks the declared return type of the action methods at runtime,
/// and these types fail the check.
bool mayBeFutureButIsNotFuture(
  DartType type,
  TypeProvider typeProvider,
  TypeSystem typeSystem,
) {
  if (type is VoidType || isNonNullableFuture(type)) return false;
  var futureOfNever = typeProvider.futureType(typeProvider.neverType);
  return typeSystem.isSubtypeOf(futureOfNever, type);
}

/// Returns the type `T` of `Future<T>`, `Future<T>?` or `FutureOr<T>`,
/// or null if [type] is none of those.
DartType? futureValueType(DartType type) {
  if ((type.isDartAsyncFuture || type.isDartAsyncFutureOr) && type is InterfaceType) {
    return type.typeArguments.first;
  }
  return null;
}

/// Returns the display string of [type] made nullable. For example, `AppState?`.
String nullableDisplayString(DartType type) {
  var display = type.getDisplayString();
  return (type.nullabilitySuffix == NullabilitySuffix.question ||
          type is DynamicType ||
          type is VoidType)
      ? display
      : '$display?';
}

/// Returns true if [type] is an action type, like `ReduxAction<St>`, a subclass of
/// it, or a mixin on it.
bool isActionType(DartType? type) =>
    type is InterfaceType &&
    (isReduxAction(type.element) || reduxActionSupertype(type.element) != null);

/// Returns why the action of type [actionType] is async, or null if it's not known
/// to be async. An action is async if its `before`, `reduce` or `wrapReduce` methods
/// return a `Future`, including methods inherited from mixins like `CheckInternet`.
String? actionAsyncReason(InterfaceType actionType, LibraryElement library) {
  // Same order as `ReduxAction.isSync()`.
  return _methodAsyncReason(actionType, library, 'before', isNonNullableFuture) ??
      _methodAsyncReason(
        actionType,
        library,
        'reduce',
        (type) => type.isDartAsyncFuture || type.isDartAsyncFutureOr,
      ) ??
      _methodAsyncReason(actionType, library, 'wrapReduce', isNonNullableFuture);
}

String? _methodAsyncReason(
  InterfaceType actionType,
  LibraryElement library,
  String methodName,
  bool Function(DartType returnType) isAsync,
) {
  var method = actionType.lookUpMethod(methodName, library);
  if (method == null) return null;

  // The declaration in ReduxAction itself says nothing about the actual action.
  var declaringElement = method.enclosingElement;
  if (isReduxAction(declaringElement)) return null;

  var returnType = method.returnType;
  if (!isAsync(returnType)) return null;

  var from = (declaringElement == null || declaringElement == actionType.element)
      ? ''
      : " (from '${declaringElement.displayName}')";

  return "its '$methodName' method$from returns '${returnType.getDisplayString()}'";
}

/// Returns true if the action of exactly type [actionType] (not a subtype) is
/// known to be sync. That's the case when its `reduce` returns `St?`, and neither
/// `before` nor `wrapReduce` return a `Future`.
bool isKnownSyncAction(
  InterfaceType actionType,
  LibraryElement library,
  TypeSystem typeSystem,
) {
  if (actionAsyncReason(actionType, library) != null) return false;

  var reduxAction = actionType.allSupertypes.where((type) => isReduxAction(type.element));
  if (reduxAction.isEmpty) return false;
  var stateType = reduxAction.first.typeArguments.first;

  var reduce = actionType.lookUpMethod('reduce', library);
  if (reduce == null || isReduxAction(reduce.enclosingElement)) return false;

  // Same as `reduce is St? Function()` in `ReduxAction.isSync()`.
  // A type is a subtype of `St?` if its non-nullable version is a subtype of `St`.
  return typeSystem.isSubtypeOf(
    typeSystem.promoteToNonNull(reduce.returnType),
    stateType,
  );
}

/// Returns true if [element] is declared in package `async_redux`.
bool isFromAsyncRedux(Element element) =>
    element.library?.uri.toString().startsWith('package:async_redux/') ?? false;

/// Returns true if [element] is a non-abstract action class that is not part of
/// AsyncRedux, like `class LoadUser extends AppAction`.
bool isConcreteAction(Element? element) =>
    element is ClassElement &&
    !element.isAbstract &&
    !element.isSealed &&
    !isFromAsyncRedux(element) &&
    reduxActionSupertype(element) != null;

/// Returns true if [node] is an instance method with a body, declared in an action or
/// in a mixin on an action.
bool isActionMethod(MethodDeclaration node) {
  if (node.isStatic || node.isGetter || node.isSetter || node.isOperator) return false;
  if (node.body is EmptyFunctionBody) return false;
  var enclosing = node.declaredFragment?.element.enclosingElement;
  return enclosing is InterfaceElement && reduxActionSupertype(enclosing) != null;
}

/// Returns true if [expression] reads the getter called [name] of `ReduxAction`, like
/// `state` or `this.state`.
bool readsActionGetter(Expression expression, String name) {
  var identifier = switch (expression.unParenthesized) {
    SimpleIdentifier identifier => identifier,
    PropertyAccess(target: ThisExpression(), :var propertyName) => propertyName,
    _ => null,
  };
  if (identifier == null || identifier.name != name) return false;
  var element = identifier.element;
  return element is GetterElement && isReduxAction(element.enclosingElement);
}
