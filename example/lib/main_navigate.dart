import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

Store<AppState> store;

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
  final Color color;
  final String text;
  final VoidCallback onChangePage;

  Page({this.color, this.text, @required this.onChangePage}) : assert(onChangePage != null);

  @override
  Widget build(BuildContext context) => RaisedButton(
        color: color,
        child: Text(text),
        onPressed: onChangePage,
      );
}

///////////////////////////////////////////////////////////////////////////////

class Page1Connector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, ViewModel1>(
      model: ViewModel1(),
      builder: (BuildContext context, ViewModel1 vm) => Page(
        color: Colors.red,
        text: "Tap me to push a new route!",
        onChangePage: vm.onChangePage,
      ),
    );
  }
}

class ViewModel1 extends BaseModel<AppState> {
  ViewModel1();

  VoidCallback onChangePage;

  ViewModel1.build({@required this.onChangePage});

  @override
  ViewModel1 fromStore() => ViewModel1.build(
        onChangePage: () => dispatch(NavigateAction.pushNamed("/myRoute")),
      );
}

///////////////////////////////////////////////////////////////////////////////

class Page2Connector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, ViewModel2>(
      model: ViewModel2(),
      builder: (BuildContext context, ViewModel2 vm) => Page(
        color: Colors.blue,
        text: "Tap me to pop this route!",
        onChangePage: vm.onChangePage,
      ),
    );
  }
}

class ViewModel2 extends BaseModel<AppState> {
  ViewModel2();

  VoidCallback onChangePage;

  ViewModel2.build({@required this.onChangePage});

  @override
  ViewModel2 fromStore() => ViewModel2.build(
        onChangePage: () => dispatch(NavigateAction.pop()),
      );
}

///////////////////////////////////////////////////////////////////////////////
