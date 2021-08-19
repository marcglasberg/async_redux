import 'package:async_redux/async_redux.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import "package:test/test.dart";

// Developed by Marcelo Glasberg (Aug 2019).
// For more info, see: https://pub.dartlang.org/packages/async_redux

void main() {
  /////////////////////////////////////////////////////////////////////////////

  test('NavigateAction toString() and type.', () async {
    //
    var route1 = MaterialPageRoute(builder: (BuildContext ctx) => Container());
    var route2 = CupertinoPageRoute(builder: (BuildContext ctx) => Container());

    // ---

    var action = NavigateAction.push(route1);
    expect(action.toString(), 'Action NavigateAction.push(MaterialPageRoute)');
    expect(action.type, NavigateType.push);

    // ---

    action = NavigateAction.pop();
    expect(action.toString(), 'Action NavigateAction.pop()');
    expect(action.type, NavigateType.pop);

    action = NavigateAction.pop(true);
    expect(action.toString(), 'Action NavigateAction.pop(true)');
    expect(action.type, NavigateType.pop);

    // ---

    action = NavigateAction.popAndPushNamed("routeName");
    expect(action.toString(), 'Action NavigateAction.popAndPushNamed(routeName)');
    expect(action.type, NavigateType.popAndPushNamed);

    action = NavigateAction.popAndPushNamed("routeName", result: true);
    expect(action.toString(), 'Action NavigateAction.popAndPushNamed(routeName, result: true)');
    expect(action.type, NavigateType.popAndPushNamed);

    // ---

    action = NavigateAction.pushNamed("routeName");
    expect(action.toString(), 'Action NavigateAction.pushNamed(routeName)');
    expect(action.type, NavigateType.pushNamed);

    // ---

    action = NavigateAction.pushReplacement(route1);
    expect(action.toString(), 'Action NavigateAction.pushReplacement(MaterialPageRoute)');
    expect(action.type, NavigateType.pushReplacement);

    action = NavigateAction.pushReplacement(route1, result: true);
    expect(action.toString(),
        'Action NavigateAction.pushReplacement(MaterialPageRoute, result: true)');
    expect(action.type, NavigateType.pushReplacement);

    // ---

    action = NavigateAction.pushAndRemoveUntil(route1, (_) => true);
    expect(action.toString(),
        'Action NavigateAction.pushAndRemoveUntil(MaterialPageRoute, predicate)');
    expect(action.type, NavigateType.pushAndRemoveUntil);

    // ---

    action = NavigateAction.replace(oldRoute: route1, newRoute: route2);
    expect(action.toString(),
        'Action NavigateAction.replace(oldRoute: MaterialPageRoute, newRoute: CupertinoPageRoute)');
    expect(action.type, NavigateType.replace);

    action = NavigateAction.replace(oldRoute: null, newRoute: null);
    expect(action.toString(), 'Action NavigateAction.replace(oldRoute: null, newRoute: null)');
    expect(action.type, NavigateType.replace);

    // ---

    action = NavigateAction.replaceRouteBelow(anchorRoute: route1, newRoute: route2);
    expect(action.toString(),
        'Action NavigateAction.replaceRouteBelow(anchorRoute: MaterialPageRoute, newRoute: CupertinoPageRoute)');
    expect(action.type, NavigateType.replaceRouteBelow);

    action = NavigateAction.replaceRouteBelow(anchorRoute: null, newRoute: null);
    expect(action.toString(),
        'Action NavigateAction.replaceRouteBelow(anchorRoute: null, newRoute: null)');
    expect(action.type, NavigateType.replaceRouteBelow);

    // ---

    action = NavigateAction.pushReplacementNamed("routeName");
    expect(action.toString(), 'Action NavigateAction.pushReplacementNamed(routeName)');
    expect(action.type, NavigateType.pushReplacementNamed);

    // ---

    action = NavigateAction.pushNamedAndRemoveUntil("routeName", (_) => true);
    expect(
        action.toString(), 'Action NavigateAction.pushNamedAndRemoveUntil(routeName, predicate)');
    expect(action.type, NavigateType.pushNamedAndRemoveUntil);

    // ---

    action = NavigateAction.pushNamedAndRemoveAll("routeName");
    expect(action.toString(), 'Action NavigateAction.pushNamedAndRemoveAll(routeName)');
    expect(action.type, NavigateType.pushNamedAndRemoveAll);

    // ---

    action = NavigateAction.popUntil((_) => true);
    expect(action.toString(), 'Action NavigateAction.popUntil(predicate)');
    expect(action.type, NavigateType.popUntil);

    // ---

    action = NavigateAction.removeRoute(route1);
    expect(action.toString(), 'Action NavigateAction.removeRoute(MaterialPageRoute)');
    expect(action.type, NavigateType.removeRoute);

    // ---

    action = NavigateAction.removeRouteBelow(route1);
    expect(action.toString(), 'Action NavigateAction.removeRouteBelow(MaterialPageRoute)');
    expect(action.type, NavigateType.removeRouteBelow);

    // ---

    action = NavigateAction.popUntilRouteName("routeName");
    expect(action.toString(), 'Action NavigateAction.popUntilRouteName(routeName)');
    expect(action.type, NavigateType.popUntilRouteName);

    // ---

    action = NavigateAction.popUntilRoute(route1);
    expect(action.toString(), 'Action NavigateAction.popUntilRoute(MaterialPageRoute)');
    expect(action.type, NavigateType.popUntilRoute);
  });

  /////////////////////////////////////////////////////////////////////////////
}
