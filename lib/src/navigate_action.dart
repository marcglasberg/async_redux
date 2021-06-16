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
class NavigateAction<St, Environment> extends ReduxAction<St, Environment> {
  static GlobalKey<NavigatorState>? _navigatorKey;

  static GlobalKey<NavigatorState>? get navigatorKey => _navigatorKey;

  static void setNavigatorKey(GlobalKey<NavigatorState> navigatorKey) =>
      _navigatorKey = navigatorKey;

  /// Trick explained here: https://github.com/flutter/flutter/issues/20451
  /// Note 'ModalRoute.of(context).settings.name' doesn't always work.
  static String? getCurrentNavigatorRouteName(BuildContext context) {
    late Route currentRoute;
    Navigator.popUntil(context, (route) {
      currentRoute = route;
      return true;
    });
    return currentRoute.settings.name;
  }

  NavigateAction._(this.details);

  final NavigatorDetails details;

  /// This is useful for tests only.
  /// You can test that some dispatched NavigateAction was of a certain type.
  NavigateType get type => details.type;

  @override
  St? reduce({required Environment environment}) {
    details.navigate();
    return null;
  }

  NavigateAction.push(
    Route route,
  ) : this._(NavigatorDetails_Push(route));

  NavigateAction.pop([Object? result]) : this._(NavigatorDetails_Pop(result));

  NavigateAction.popAndPushNamed(
    String routeName, {
    Object? result,
    Object? arguments,
  }) : this._(NavigatorDetails_PopAndPushNamed(routeName, result: result, arguments: arguments));

  NavigateAction.pushNamed(
    String routeName, {
    Object? arguments,
  }) : this._(NavigatorDetails_PushNamed(routeName, arguments: arguments));

  NavigateAction.pushReplacement(
    Route route, {
    Object? result,
  }) : this._(NavigatorDetails_PushReplacement(route, result: result));

  NavigateAction.pushAndRemoveUntil(
    Route route,
    RoutePredicate predicate,
  ) : this._(NavigatorDetails_PushAndRemoveUntil(route, predicate));

  NavigateAction.replace({
    Route? oldRoute,
    Route? newRoute,
  }) : this._(NavigatorDetails_Replace(
          oldRoute: oldRoute,
          newRoute: newRoute,
        ));

  NavigateAction.replaceRouteBelow({
    Route? anchorRoute,
    Route? newRoute,
  }) : this._(NavigatorDetails_ReplaceRouteBelow(
          anchorRoute: anchorRoute,
          newRoute: newRoute,
        ));

  NavigateAction.pushReplacementNamed(
    String routeName, {
    Object? arguments,
  }) : this._(NavigatorDetails_PushReplacementNamed(routeName, arguments: arguments));

  NavigateAction.pushNamedAndRemoveUntil(
    String newRouteName,
    RoutePredicate predicate, {
    Object? arguments,
  }) : this._(NavigatorDetails_PushNamedAndRemoveUntil(newRouteName, predicate,
            arguments: arguments));

  NavigateAction.pushNamedAndRemoveAll(
    String newRouteName, {
    Object? arguments,
  }) : this._(NavigatorDetails_PushNamedAndRemoveUntil(newRouteName, (_) => false,
            arguments: arguments));

  NavigateAction.popUntil(
    RoutePredicate predicate,
  ) : this._(NavigatorDetails_PopUntil(predicate));

  NavigateAction.removeRoute(
    Route route,
  ) : this._(NavigatorDetails_RemoveRoute(route));

  NavigateAction.removeRouteBelow(
    Route anchorRoute,
  ) : this._(NavigatorDetails_RemoveRouteBelow(anchorRoute));

  NavigateAction.popUntilRouteName(
    String routeName,
  ) : this._(NavigatorDetails_PopUntil(((route) => route.settings.name == routeName)));

  NavigateAction.popUntilRoute(
    Route route,
  ) : this._(NavigatorDetails_PopUntil(((_route) => _route == route)));
}

// ////////////////////////////////////////////////////////////////////////////

class NavigatorDetails_Push implements NavigatorDetails {
  final Route route;

  NavigatorDetails_Push(this.route);

  @override
  void navigate() {
    NavigateAction._navigatorKey?.currentState?.push(route);
  }

  @override
  NavigateType get type => NavigateType.push;
}

// ////////////////////////////////////////////////////////////////////////////

class NavigatorDetails_Pop implements NavigatorDetails {
  final Object? result;

  NavigatorDetails_Pop(this.result);

  @override
  void navigate() {
    NavigateAction._navigatorKey?.currentState?.pop(result);
  }

  @override
  NavigateType get type => NavigateType.pop;
}

// ////////////////////////////////////////////////////////////////////////////

class NavigatorDetails_PopAndPushNamed implements NavigatorDetails {
  final String routeName;
  final Object? result;
  final Object? arguments;

  NavigatorDetails_PopAndPushNamed(
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

class NavigatorDetails_PushNamed implements NavigatorDetails {
  final String routeName;
  final Object? arguments;

  NavigatorDetails_PushNamed(
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

class NavigatorDetails_PushReplacementNamed implements NavigatorDetails {
  final String routeName;
  final Object? arguments;

  NavigatorDetails_PushReplacementNamed(
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

class NavigatorDetails_PushNamedAndRemoveUntil implements NavigatorDetails {
  final String newRouteName;
  final Object? arguments;
  final RoutePredicate predicate;

  NavigatorDetails_PushNamedAndRemoveUntil(
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

class NavigatorDetails_PushReplacement implements NavigatorDetails {
  final Route route;
  final Object? result;

  NavigatorDetails_PushReplacement(
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

class NavigatorDetails_PushAndRemoveUntil implements NavigatorDetails {
  final Route route;
  final RoutePredicate predicate;

  NavigatorDetails_PushAndRemoveUntil(
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

class NavigatorDetails_Replace implements NavigatorDetails {
  final Route? oldRoute;
  final Route? newRoute;

  NavigatorDetails_Replace({
    required this.oldRoute,
    required this.newRoute,
  });

  @override
  void navigate() {
    NavigateAction._navigatorKey?.currentState?.replace(
      oldRoute: oldRoute!,
      newRoute: newRoute!,
    );
  }

  @override
  NavigateType get type => NavigateType.replace;
}

// ////////////////////////////////////////////////////////////////////////////

class NavigatorDetails_ReplaceRouteBelow implements NavigatorDetails {
  final Route? anchorRoute;
  final Route? newRoute;

  NavigatorDetails_ReplaceRouteBelow({
    required this.anchorRoute,
    required this.newRoute,
  });

  @override
  void navigate() {
    NavigateAction._navigatorKey?.currentState?.replaceRouteBelow(
      anchorRoute: anchorRoute!,
      newRoute: newRoute!,
    );
  }

  @override
  NavigateType get type => NavigateType.replaceRouteBelow;
}

// ////////////////////////////////////////////////////////////////////////////

class NavigatorDetails_PopUntil implements NavigatorDetails {
  final RoutePredicate predicate;

  NavigatorDetails_PopUntil(this.predicate);

  @override
  void navigate() {
    NavigateAction._navigatorKey?.currentState?.popUntil(predicate);
  }

  @override
  NavigateType get type => NavigateType.popUntil;
}

// ////////////////////////////////////////////////////////////////////////////

class NavigatorDetails_RemoveRoute implements NavigatorDetails {
  final Route route;

  NavigatorDetails_RemoveRoute(this.route);

  @override
  void navigate() {
    NavigateAction._navigatorKey?.currentState?.removeRoute(route);
  }

  @override
  NavigateType get type => NavigateType.removeRoute;
}

// ////////////////////////////////////////////////////////////////////////////

class NavigatorDetails_RemoveRouteBelow implements NavigatorDetails {
  final Route anchorRoute;

  NavigatorDetails_RemoveRouteBelow(this.anchorRoute);

  @override
  void navigate() {
    NavigateAction._navigatorKey?.currentState?.removeRouteBelow(anchorRoute);
  }

  @override
  NavigateType get type => NavigateType.removeRouteBelow;
}

// ////////////////////////////////////////////////////////////////////////////

abstract class NavigatorDetails {
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
