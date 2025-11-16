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
  '/': (BuildContext context) => Page1(),
  "/myRoute": (BuildContext context) => Page2(),
};

class AppState {}

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

class Page1 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Page(
      color: Colors.red,
      text: "Tap me to push a new route!",
      onChangePage: () => context.dispatch(NavigateAction.pushNamed("/myRoute")),
    );
  }
}

class Page2 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Page(
      color: Colors.blue,
      text: "Tap me to pop this route!",
      onChangePage: () => context.dispatch(NavigateAction.pop()),
    );
  }
}
