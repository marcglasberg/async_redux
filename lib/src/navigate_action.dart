import 'package:flutter/material.dart';

import '../async_redux.dart';

// Developed by Marcelo Glasberg (Aug 2019).
// For more info, see: https://pub.dartlang.org/packages/async_redux

/// Available constructors:
/// `NavigateAction.push()`,
/// `NavigateAction.pop()`,
/// `NavigateAction.popAndPushNamed()`,
/// `NavigateAction.pushNamed()`,
/// `NavigateAction.pushReplacement()`,
/// `NavigateAction.pushAndRemoveUntil()`,
/// `NavigateAction.replace()`,
/// `NavigateAction.replaceRouteBelow()`,
/// `NavigateAction.pushReplacementNamed()`,
/// `NavigateAction.pushNamedAndRemoveUntil()`,
/// `NavigateAction.pushNamedAndRemoveAll()`,
/// `NavigateAction.popUntil()`,
/// `NavigateAction.removeRoute()`,
/// `NavigateAction.removeRouteBelow()`,
/// `NavigateAction.popUntilRouteName()`,
/// `NavigateAction.popUntilRoute()`,
///
abstract class NavigateAction<St> extends ReduxAction<St> {
  static GlobalKey<NavigatorState> _navigatorKey;

  static GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  static void setNavigatorKey(GlobalKey<NavigatorState> navigatorKey) =>
      _navigatorKey = navigatorKey;

  /// Trick explained here: https://github.com/flutter/flutter/issues/20451
  /// Note 'ModalRoute.of(context).settings.name' doesn't always work.
  static String getCurrentNavigatorRouteName(BuildContext context) {
    Route currentRoute;
    Navigator.popUntil(context, (route) {
      currentRoute = route;
      return true;
    });
    return currentRoute.settings.name;
  }

  NavigateAction();

  factory NavigateAction.push(
    Route route,
  ) =>
      _NavigateAction_Push(route);

  factory NavigateAction.pop([Object result]) => _NavigateAction_Pop(result);

  factory NavigateAction.popAndPushNamed(
    String routeName, {
    Object result,
    Object arguments,
  }) =>
      _NavigateAction_PopAndPushNamed(routeName, result: result, arguments: arguments);

  factory NavigateAction.pushNamed(
    String routeName, {
    Object arguments,
  }) =>
      _NavigateAction_PushNamed(routeName, arguments: arguments);

  factory NavigateAction.pushReplacement(
    Route route, {
    Object result,
  }) =>
      _NavigateAction_PushReplacement(route, result: result);

  factory NavigateAction.pushAndRemoveUntil(
    Route route,
    RoutePredicate predicate,
  ) =>
      _NavigateAction_PushAndRemoveUntil(route, predicate);

  factory NavigateAction.replace(
    Route oldRoute,
    Route newRoute,
  ) =>
      _NavigateAction_Replace(
        oldRoute: oldRoute,
        newRoute: newRoute,
      );

  factory NavigateAction.replaceRouteBelow(
    Route anchorRoute,
    Route newRoute,
  ) =>
      _NavigateAction_ReplaceRouteBelow(
        anchorRoute: anchorRoute,
        newRoute: newRoute,
      );

  factory NavigateAction.pushReplacementNamed(
    String routeName, {
    Object arguments,
  }) =>
      _NavigateAction_PushReplacementNamed(routeName, arguments: arguments);

  factory NavigateAction.pushNamedAndRemoveUntil(
    String newRouteName,
    RoutePredicate predicate, {
    Object arguments,
  }) =>
      _NavigateAction_PushNamedAndRemoveUntil(newRouteName, predicate, arguments: arguments);

  factory NavigateAction.pushNamedAndRemoveAll(
    String newRouteName, {
    Object arguments,
  }) =>
      _NavigateAction_PushNamedAndRemoveUntil(newRouteName, (_) => false, arguments: arguments);

  factory NavigateAction.popUntil(
    RoutePredicate predicate,
  ) =>
      _NavigateAction_PopUntil(predicate);

  factory NavigateAction.removeRoute(
    Route route,
  ) =>
      _NavigateAction_RemoveRoute(route);

  factory NavigateAction.removeRouteBelow(
    Route anchorRoute,
  ) =>
      _NavigateAction_RemoveRouteBelow(anchorRoute);

  factory NavigateAction.popUntilRouteName(
    String routeName,
  ) =>
      _NavigateAction_PopUntil(((route) => route.settings.name == routeName));

  factory NavigateAction.popUntilRoute(
    Route route,
  ) =>
      _NavigateAction_PopUntil(((_route) => _route == route));
}

// ////////////////////////////////////////////////////////////////////////////

class _NavigateAction_Push<St> extends NavigateAction<St> {
  final Route route;

  _NavigateAction_Push(this.route);

  @override
  St reduce() {
    NavigateAction._navigatorKey?.currentState?.push(route);
    return null;
  }
}

// ////////////////////////////////////////////////////////////////////////////

class _NavigateAction_Pop<St> extends NavigateAction<St> {
  final Object result;

  _NavigateAction_Pop(this.result);

  @override
  St reduce() {
    NavigateAction._navigatorKey?.currentState?.pop(result);
    return null;
  }
}

// ////////////////////////////////////////////////////////////////////////////

class _NavigateAction_PopAndPushNamed<St> extends NavigateAction<St> {
  final String routeName;
  final Object result;
  final Object arguments;

  _NavigateAction_PopAndPushNamed(
    this.routeName, {
    this.result,
    this.arguments,
  });

  @override
  St reduce() {
    NavigateAction._navigatorKey?.currentState?.popAndPushNamed(
      routeName,
      result: result,
      arguments: arguments,
    );
    return null;
  }
}

// ////////////////////////////////////////////////////////////////////////////

class _NavigateAction_PushNamed<St> extends NavigateAction<St> {
  final String routeName;
  final Object arguments;

  _NavigateAction_PushNamed(
    this.routeName, {
    this.arguments,
  });

  @override
  St reduce() {
    NavigateAction._navigatorKey?.currentState?.pushNamed(routeName, arguments: arguments);
    return null;
  }
}

// ////////////////////////////////////////////////////////////////////////////

class _NavigateAction_PushReplacementNamed<St> extends NavigateAction<St> {
  final String routeName;
  final Object arguments;

  _NavigateAction_PushReplacementNamed(
    this.routeName, {
    this.arguments,
  });

  @override
  St reduce() {
    NavigateAction._navigatorKey?.currentState
        ?.pushReplacementNamed(routeName, arguments: arguments);
    return null;
  }
}

// ////////////////////////////////////////////////////////////////////////////

class _NavigateAction_PushNamedAndRemoveUntil<St> extends NavigateAction<St> {
  final String newRouteName;
  final Object arguments;
  final RoutePredicate predicate;

  _NavigateAction_PushNamedAndRemoveUntil(
    this.newRouteName,
    this.predicate, {
    this.arguments,
  });

  @override
  St reduce() {
    NavigateAction._navigatorKey?.currentState
        ?.pushNamedAndRemoveUntil(newRouteName, predicate, arguments: arguments);
    return null;
  }
}

// ////////////////////////////////////////////////////////////////////////////

class _NavigateAction_PushReplacement<St> extends NavigateAction<St> {
  final Route route;
  final Object result;

  _NavigateAction_PushReplacement(
    this.route, {
    this.result,
  });

  @override
  St reduce() {
    NavigateAction._navigatorKey?.currentState?.pushReplacement(route, result: result);
    return null;
  }
}

// ////////////////////////////////////////////////////////////////////////////

class _NavigateAction_PushAndRemoveUntil<St> extends NavigateAction<St> {
  final Route route;
  final RoutePredicate predicate;

  _NavigateAction_PushAndRemoveUntil(
    this.route,
    this.predicate,
  );

  @override
  St reduce() {
    NavigateAction._navigatorKey?.currentState?.pushAndRemoveUntil(route, predicate);
    return null;
  }
}

// ////////////////////////////////////////////////////////////////////////////

class _NavigateAction_Replace<St> extends NavigateAction<St> {
  final Route oldRoute;
  final Route newRoute;

  _NavigateAction_Replace({
    @required this.oldRoute,
    @required this.newRoute,
  });

  @override
  St reduce() {
    NavigateAction._navigatorKey?.currentState?.replace(
      oldRoute: oldRoute,
      newRoute: newRoute,
    );
    return null;
  }
}

// ////////////////////////////////////////////////////////////////////////////

class _NavigateAction_ReplaceRouteBelow<St> extends NavigateAction<St> {
  final Route anchorRoute;
  final Route newRoute;

  _NavigateAction_ReplaceRouteBelow({
    @required this.anchorRoute,
    @required this.newRoute,
  });

  @override
  St reduce() {
    NavigateAction._navigatorKey?.currentState?.replaceRouteBelow(
      anchorRoute: anchorRoute,
      newRoute: newRoute,
    );
    return null;
  }
}

// ////////////////////////////////////////////////////////////////////////////

class _NavigateAction_PopUntil<St> extends NavigateAction<St> {
  final RoutePredicate predicate;

  _NavigateAction_PopUntil(this.predicate);

  @override
  St reduce() {
    NavigateAction._navigatorKey?.currentState?.popUntil(predicate);
    return null;
  }
}

// ////////////////////////////////////////////////////////////////////////////

class _NavigateAction_RemoveRoute<St> extends NavigateAction<St> {
  final Route route;

  _NavigateAction_RemoveRoute(this.route);

  @override
  St reduce() {
    NavigateAction._navigatorKey?.currentState?.removeRoute(route);
    return null;
  }
}

// ////////////////////////////////////////////////////////////////////////////

class _NavigateAction_RemoveRouteBelow<St> extends NavigateAction<St> {
  final Route anchorRoute;

  _NavigateAction_RemoveRouteBelow(this.anchorRoute);

  @override
  St reduce() {
    NavigateAction._navigatorKey?.currentState?.removeRouteBelow(anchorRoute);
    return null;
  }
}

// ////////////////////////////////////////////////////////////////////////////
