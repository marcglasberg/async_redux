import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';

late Store<AppState> store;

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  NavigateAction.setNavigatorKey(navigatorKey);
  store = Store<AppState>(initialState: AppState());
  runApp(MyApp());
}

final routes = {
  '/': (BuildContext context) => Page1Connector(),
  "/myRoute": (BuildContext context) => Page2Connector(),
};

class AppState {}

///////////////////////////////////////////////////////////////////////////////

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StoreProvider<AppState>(
      store: store,
      child: MaterialApp(
        routes: routes,
        navigatorKey: navigatorKey,
      ),
    );
  }
}

///////////////////////////////////////////////////////////////////////////////

class Page extends StatelessWidget {
  final Color? color;
  final String? text;
  final VoidCallback onChangePage;

  Page({this.color, this.text, required this.onChangePage});

  @override
  Widget build(BuildContext context) => ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: color),
        child: Text(text!),
        onPressed: onChangePage,
      );
}

///////////////////////////////////////////////////////////////////////////////

class Page1Connector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, ViewModel1>(
      vm: () => Factory1(),
      builder: (BuildContext context, ViewModel1 vm) => Page(
        color: Colors.red,
        text: "Tap me to push a new route!",
        onChangePage: vm.onChangePage,
      ),
    );
  }
}

/// Factory that creates a view-model for the StoreConnector.
class Factory1 extends VmFactory<AppState, Page1Connector, ViewModel1> {
  @override
  ViewModel1 fromStore() =>
      ViewModel1(onChangePage: () => dispatch(NavigateAction.pushNamed("/myRoute")));
}

/// The view-model holds the part of the Store state the dumb-widget needs.
class ViewModel1 extends Vm {
  final VoidCallback onChangePage;

  ViewModel1({required this.onChangePage});
}

///////////////////////////////////////////////////////////////////////////////

class Page2Connector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, ViewModel2>(
      vm: () => Factory2(),
      builder: (BuildContext context, ViewModel2 vm) => Page(
        color: Colors.blue,
        text: "Tap me to pop this route!",
        onChangePage: vm.onChangePage,
      ),
    );
  }
}

/// Factory that creates a view-model for the StoreConnector.
class Factory2 extends VmFactory<AppState, Page1Connector, ViewModel2> {
  @override
  ViewModel2 fromStore() => ViewModel2(
        onChangePage: () => dispatch(NavigateAction.pop()),
      );
}

/// The view-model holds the part of the Store state the dumb-widget needs.
class ViewModel2 extends Vm {
  final VoidCallback onChangePage;

  ViewModel2({required this.onChangePage});
}

///////////////////////////////////////////////////////////////////////////////
