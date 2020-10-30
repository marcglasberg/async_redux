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
class NavigateAction<St> extends ReduxAction<St> {
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

  NavigateAction(this.navigatorCallback);

  final NavigatorCallback navigatorCallback;

  @override
  St reduce() {
    navigatorCallback.navigate();
    return null;
  }

  NavigateAction.push(
    Route route,
  ) : this(_NavigateAction_Push(route));

  NavigateAction.pop([Object result]) : this(_NavigateAction_Pop(result));

  NavigateAction.popAndPushNamed(
    String routeName, {
    Object result,
    Object arguments,
  }) : this(_NavigateAction_PopAndPushNamed(routeName, result: result, arguments: arguments));

  NavigateAction.pushNamed(
    String routeName, {
    Object arguments,
  }) : this(_NavigateAction_PushNamed(routeName, arguments: arguments));

  NavigateAction.pushReplacement(
    Route route, {
    Object result,
  }) : this(_NavigateAction_PushReplacement(route, result: result));

  NavigateAction.pushAndRemoveUntil(
    Route route,
    RoutePredicate predicate,
  ) : this(_NavigateAction_PushAndRemoveUntil(route, predicate));

  NavigateAction.replace({
    Route oldRoute,
    Route newRoute,
  }) : this(_NavigateAction_Replace(
          oldRoute: oldRoute,
          newRoute: newRoute,
        ));

  NavigateAction.replaceRouteBelow({
    Route anchorRoute,
    Route newRoute,
  }) : this(_NavigateAction_ReplaceRouteBelow(
          anchorRoute: anchorRoute,
          newRoute: newRoute,
        ));

  NavigateAction.pushReplacementNamed(
    String routeName, {
    Object arguments,
  }) : this(_NavigateAction_PushReplacementNamed(routeName, arguments: arguments));

  NavigateAction.pushNamedAndRemoveUntil(
    String newRouteName,
    RoutePredicate predicate, {
    Object arguments,
  }) : this(_NavigateAction_PushNamedAndRemoveUntil(newRouteName, predicate, arguments: arguments));

  NavigateAction.pushNamedAndRemoveAll(
    String newRouteName, {
    Object arguments,
  }) : this(_NavigateAction_PushNamedAndRemoveUntil(newRouteName, (_) => false,
            arguments: arguments));

  NavigateAction.popUntil(
    RoutePredicate predicate,
  ) : this(_NavigateAction_PopUntil(predicate));

  NavigateAction.removeRoute(
    Route route,
  ) : this(_NavigateAction_RemoveRoute(route));

  NavigateAction.removeRouteBelow(
    Route anchorRoute,
  ) : this(_NavigateAction_RemoveRouteBelow(anchorRoute));

  NavigateAction.popUntilRouteName(
    String routeName,
  ) : this(_NavigateAction_PopUntil(((route) => route.settings.name == routeName)));

  NavigateAction.popUntilRoute(
    Route route,
  ) : this(_NavigateAction_PopUntil(((_route) => _route == route)));

  /// This is useful for tests only.
  /// You can test that some dispatched NavigateAction was of a certain type.
  NavigateType get type => navigatorCallback.type;
}

// ////////////////////////////////////////////////////////////////////////////

class _NavigateAction_Push implements NavigatorCallback {
  final Route route;

  _NavigateAction_Push(this.route);

  @override
  void navigate() {
    NavigateAction._navigatorKey?.currentState?.push(route);
  }

  @override
  NavigateType get type => NavigateType.push;
}

// ////////////////////////////////////////////////////////////////////////////

class _NavigateAction_Pop implements NavigatorCallback {
  final Object result;

  _NavigateAction_Pop(this.result);

  @override
  void navigate() {
    NavigateAction._navigatorKey?.currentState?.pop(result);
  }

  @override
  NavigateType get type => NavigateType.pop;
}

// ////////////////////////////////////////////////////////////////////////////

class _NavigateAction_PopAndPushNamed implements NavigatorCallback {
  final String routeName;
  final Object result;
  final Object arguments;

  _NavigateAction_PopAndPushNamed(
    this.routeName, {
    this.result,
    this.arguments,
  });

  @override
  void navigate() {
    NavigateAction._navigatorKey?.currentState?.popAndPushNamed(
      routeName,
      result: result,
      arguments: arguments,
    );
  }

  @override
  NavigateType get type => NavigateType.popAndPushNamed;
}

// ////////////////////////////////////////////////////////////////////////////

class _NavigateAction_PushNamed implements NavigatorCallback {
  final String routeName;
  final Object arguments;

  _NavigateAction_PushNamed(
    this.routeName, {
    this.arguments,
  });

  @override
  void navigate() {
    NavigateAction._navigatorKey?.currentState?.pushNamed(routeName, arguments: arguments);
  }

  @override
  NavigateType get type => NavigateType.pushNamed;
}

// ////////////////////////////////////////////////////////////////////////////

class _NavigateAction_PushReplacementNamed implements NavigatorCallback {
  final String routeName;
  final Object arguments;

  _NavigateAction_PushReplacementNamed(
    this.routeName, {
    this.arguments,
  });

  @override
  void navigate() {
    NavigateAction._navigatorKey?.currentState
        ?.pushReplacementNamed(routeName, arguments: arguments);
  }

  @override
  NavigateType get type => NavigateType.pushReplacementNamed;
}

// ////////////////////////////////////////////////////////////////////////////

class _NavigateAction_PushNamedAndRemoveUntil implements NavigatorCallback {
  final String newRouteName;
  final Object arguments;
  final RoutePredicate predicate;

  _NavigateAction_PushNamedAndRemoveUntil(
    this.newRouteName,
    this.predicate, {
    this.arguments,
  });

  @override
  void navigate() {
    NavigateAction._navigatorKey?.currentState
        ?.pushNamedAndRemoveUntil(newRouteName, predicate, arguments: arguments);
  }

  @override
  NavigateType get type => NavigateType.pushNamedAndRemoveUntil;
}

// ////////////////////////////////////////////////////////////////////////////

class _NavigateAction_PushReplacement implements NavigatorCallback {
  final Route route;
  final Object result;

  _NavigateAction_PushReplacement(
    this.route, {
    this.result,
  });

  @override
  void navigate() {
    NavigateAction._navigatorKey?.currentState?.pushReplacement(route, result: result);
  }

  @override
  NavigateType get type => NavigateType.pushReplacement;
}

// ////////////////////////////////////////////////////////////////////////////

class _NavigateAction_PushAndRemoveUntil implements NavigatorCallback {
  final Route route;
  final RoutePredicate predicate;

  _NavigateAction_PushAndRemoveUntil(
    this.route,
    this.predicate,
  );

  @override
  void navigate() {
    NavigateAction._navigatorKey?.currentState?.pushAndRemoveUntil(route, predicate);
  }

  @override
  NavigateType get type => NavigateType.pushAndRemoveUntil;
}

// ////////////////////////////////////////////////////////////////////////////

class _NavigateAction_Replace implements NavigatorCallback {
  final Route oldRoute;
  final Route newRoute;

  _NavigateAction_Replace({
    @required this.oldRoute,
    @required this.newRoute,
  });

  @override
  void navigate() {
    NavigateAction._navigatorKey?.currentState?.replace(
      oldRoute: oldRoute,
      newRoute: newRoute,
    );
  }

  @override
  NavigateType get type => NavigateType.replace;
}

// ////////////////////////////////////////////////////////////////////////////

class _NavigateAction_ReplaceRouteBelow implements NavigatorCallback {
  final Route anchorRoute;
  final Route newRoute;

  _NavigateAction_ReplaceRouteBelow({
    @required this.anchorRoute,
    @required this.newRoute,
  });

  @override
  void navigate() {
    NavigateAction._navigatorKey?.currentState?.replaceRouteBelow(
      anchorRoute: anchorRoute,
      newRoute: newRoute,
    );
  }

  @override
  NavigateType get type => NavigateType.replaceRouteBelow;
}

// ////////////////////////////////////////////////////////////////////////////

class _NavigateAction_PopUntil implements NavigatorCallback {
  final RoutePredicate predicate;

  _NavigateAction_PopUntil(this.predicate);

  @override
  void navigate() {
    NavigateAction._navigatorKey?.currentState?.popUntil(predicate);
  }

  @override
  NavigateType get type => NavigateType.popUntil;
}

// ////////////////////////////////////////////////////////////////////////////

class _NavigateAction_RemoveRoute implements NavigatorCallback {
  final Route route;

  _NavigateAction_RemoveRoute(this.route);

  @override
  void navigate() {
    NavigateAction._navigatorKey?.currentState?.removeRoute(route);
  }

  @override
  NavigateType get type => NavigateType.removeRoute;
}

// ////////////////////////////////////////////////////////////////////////////

class _NavigateAction_RemoveRouteBelow implements NavigatorCallback {
  final Route anchorRoute;

  _NavigateAction_RemoveRouteBelow(this.anchorRoute);

  @override
  void navigate() {
    NavigateAction._navigatorKey?.currentState?.removeRouteBelow(anchorRoute);
  }

  @override
  NavigateType get type => NavigateType.removeRouteBelow;
}

// ////////////////////////////////////////////////////////////////////////////

abstract class NavigatorCallback {
  void navigate();

  NavigateType get type;
}

// ////////////////////////////////////////////////////////////////////////////

enum NavigateType {
  push,
  pop,
  popAndPushNamed,
  pushNamed,
  pushReplacement,
  pushAndRemoveUntil,
  replace,
  replaceRouteBelow,
  pushReplacementNamed,
  pushNamedAndRemoveUntil,
  pushNamedAndRemoveAll,
  popUntil,
  removeRoute,
  removeRouteBelow,
  popUntilRouteName,
  popUntilRoute,
}
