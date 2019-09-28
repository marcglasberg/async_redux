import 'package:async_redux/async_redux.dart'
    show NavigateAction, NavigateType, Store, StoreProvider;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Store<AppState> store;

final navigatorKey = GlobalKey<NavigatorState>();

final routes = {
  "/": (BuildContext context) => MyPage(Key("page1")),
  "/page2": (BuildContext context) => MyPage(Key("page2")),
  "/page3": (BuildContext context) => MyPage(Key("page3")),
};

class AppState {}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StoreProvider<AppState>(
      store: store,
      child: MaterialApp(
        initialRoute: "/",
        routes: routes,
        navigatorKey: navigatorKey,
      ),
    );
  }
}

class _NavAction extends StatelessWidget {
  final String route;
  final NavigateType navigateType;

  _NavAction(
    Key key, {
    this.route,
    @required this.navigateType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        NavigateAction<AppState> _action;

        switch (navigateType) {
          case NavigateType.pushNamedAndRemoveAll:
            {
              _action = NavigateAction.pushNamedAndRemoveAll(route);
            }
            break;
          case NavigateType.pushReplacementNamed:
            {
              _action = NavigateAction.pushReplacementNamed(route);
            }
            break;
          case NavigateType.pushNamed:
            {
              _action = NavigateAction.pushNamed(route);
            }
            break;

          case NavigateType.popUntil:
            {
              _action = NavigateAction.popUntil(route);
            }
            break;
          case NavigateType.pop:
            {
              _action = NavigateAction.pop();
            }
            break;
        }

        store.dispatch(_action);
      },
      child: SizedBox(height: 10, width: 10),
    );
  }
}

class MyPage extends StatelessWidget {
  MyPage(Key key) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          Text(
              "Current route: ${NavigateAction.getCurrentNavigatorRouteName(context)}"),
          //
          _NavAction(
            Key("pushNamedPage2"),
            route: "/page2",
            navigateType: NavigateType.pushNamed,
          ),
          _NavAction(
            Key("pushNamedPage3"),
            route: "/page3",
            navigateType: NavigateType.pushNamed,
          ),
          //
          _NavAction(
            Key("pushNamedAndRemoveAllPage1"),
            route: "/",
            navigateType: NavigateType.pushNamedAndRemoveAll,
          ),
          //
          _NavAction(
            Key("pushReplacementNamedPage2"),
            route: "/page2",
            navigateType: NavigateType.pushReplacementNamed,
          ),
          //
          _NavAction(
            Key("popUntilPage1"),
            route: "/",
            navigateType: NavigateType.popUntil,
          ),
          _NavAction(
            Key("pop"),
            navigateType: NavigateType.pop,
          ),
        ],
      ),
    );
  }
}

/////////////////////////////////////////////////////////////////////////////

void main() {
  setUp(() async {
    NavigateAction.setNavigatorKey(navigatorKey);
    store = Store<AppState>(initialState: AppState());
  });

  final Finder page1Finder = find.byKey(Key("page1"));
  final Finder page1IncludeIfOffstageFinder =
      find.byKey(Key("page1"), skipOffstage: false);
  final Finder pushAndRemoveAllPage1Finder =
      find.byKey(Key("pushNamedAndRemoveAllPage1"));
  final Finder popUntilPage1Finder = find.byKey(Key("popUntilPage1"));

  final Finder page2Finder = find.byKey(Key("page2"));
  final Finder page2IncludeIfOffstageFinder =
      find.byKey(Key("page2"), skipOffstage: false);
  final Finder pushPage2Finder = find.byKey(Key("pushNamedPage2"));
  final Finder pushReplacementPage2Finder =
      find.byKey(Key("pushReplacementNamedPage2"));

  final Finder page3Finder = find.byKey(Key("page3"));
  final Finder page3IncludeIfOffstageFinder =
      find.byKey(Key("page3"), skipOffstage: false);
  final Finder pushPage3Finder = find.byKey(Key("pushNamedPage3"));

  final Finder popFinder = find.byKey(Key("pop"));

  /////////////////////////////////////////////////////////////////////////////

  testWidgets(NavigateType.pushNamed.toString(), (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());
    await tester.pumpAndSettle();

    // check if initial page corresponds to initialRoute
    expect(find.text("Current route: /"), findsOneWidget);
    expect(page1Finder, findsOneWidget);
    expect(page2Finder, findsNothing);
    expect(page3Finder, findsNothing);

    // pushNamed to page 2
    await tester.tap(pushPage2Finder);
    await tester.pumpAndSettle();
    expect(find.text("Current route: /page2"), findsOneWidget);
    expect(page1Finder, findsNothing);
    expect(page2Finder, findsOneWidget);
    expect(page3Finder, findsNothing);

    // pushNamed to page 3
    await tester.tap(pushPage3Finder);
    await tester.pumpAndSettle();
    expect(find.text("Current route: /page3"), findsOneWidget);
    expect(page1Finder, findsNothing);
    expect(page2Finder, findsNothing);
    expect(page3Finder, findsOneWidget);
  });

  /////////////////////////////////////////////////////////////////////////////

  testWidgets(NavigateType.pushNamedAndRemoveAll.toString(),
      (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());
    await tester.pumpAndSettle();

    // initial route
    expect(find.text("Current route: /"), findsOneWidget);
    expect(page1IncludeIfOffstageFinder, findsOneWidget);
    expect(page2IncludeIfOffstageFinder, findsNothing);
    expect(page3IncludeIfOffstageFinder, findsNothing);

    // push page 2
    await tester.tap(pushPage2Finder);
    await tester.pumpAndSettle();
    expect(find.text("Current route: /page2"), findsOneWidget);
    expect(page1IncludeIfOffstageFinder, findsOneWidget);
    expect(page2IncludeIfOffstageFinder, findsOneWidget);
    expect(page3IncludeIfOffstageFinder, findsNothing);

    // push page 3
    await tester.tap(pushPage3Finder);
    await tester.pumpAndSettle();
    expect(find.text("Current route: /page3"), findsOneWidget);
    expect(page1IncludeIfOffstageFinder, findsOneWidget);
    expect(page2IncludeIfOffstageFinder, findsOneWidget);
    expect(page3IncludeIfOffstageFinder, findsOneWidget);

    // for fun, push page 3 again
    await tester.tap(pushPage3Finder);
    await tester.pumpAndSettle();
    expect(find.text("Current route: /page3"), findsOneWidget);
    expect(page1IncludeIfOffstageFinder, findsOneWidget);
    expect(page2IncludeIfOffstageFinder, findsOneWidget);
    expect(page3IncludeIfOffstageFinder, findsNWidgets(2));

    // pushNamedAndRemoveAll back to page 1
    await tester.tap(pushAndRemoveAllPage1Finder);
    await tester.pumpAndSettle();
    expect(find.text("Current route: /"), findsOneWidget);
    expect(page1IncludeIfOffstageFinder, findsOneWidget);
    expect(page2IncludeIfOffstageFinder, findsNothing);
    expect(page3IncludeIfOffstageFinder, findsNothing);
  });

  /////////////////////////////////////////////////////////////////////////////

  testWidgets(NavigateType.pushReplacementNamed.toString(),
      (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());
    await tester.pumpAndSettle();

    // initial route
    expect(find.text("Current route: /"), findsOneWidget);
    expect(page1IncludeIfOffstageFinder, findsOneWidget);
    expect(page2IncludeIfOffstageFinder, findsNothing);
    expect(page3IncludeIfOffstageFinder, findsNothing);

    // push page 2
    await tester.tap(pushPage2Finder);
    await tester.pumpAndSettle();
    expect(find.text("Current route: /page2"), findsOneWidget);
    expect(page1IncludeIfOffstageFinder, findsOneWidget);
    expect(page2IncludeIfOffstageFinder, findsOneWidget);
    expect(page3IncludeIfOffstageFinder, findsNothing);

    // push page 3
    await tester.tap(pushPage3Finder);
    await tester.pumpAndSettle();
    expect(find.text("Current route: /page3"), findsOneWidget);
    expect(page1IncludeIfOffstageFinder, findsOneWidget);
    expect(page2IncludeIfOffstageFinder, findsOneWidget);
    expect(page3IncludeIfOffstageFinder, findsOneWidget);

    // push page 2 and replace page 3
    await tester.tap(pushReplacementPage2Finder);
    await tester.pumpAndSettle();
    expect(find.text("Current route: /page2"), findsOneWidget);
    expect(page1IncludeIfOffstageFinder, findsOneWidget);
    expect(page2IncludeIfOffstageFinder, findsNWidgets(2));
    expect(page3IncludeIfOffstageFinder, findsNothing);
  });

  /////////////////////////////////////////////////////////////////////////////

  testWidgets(NavigateType.pop.toString(), (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());
    await tester.pumpAndSettle();

    // initial route
    expect(find.text("Current route: /"), findsOneWidget);
    expect(page1IncludeIfOffstageFinder, findsOneWidget);
    expect(page2IncludeIfOffstageFinder, findsNothing);
    expect(page3IncludeIfOffstageFinder, findsNothing);

    // push page 2
    await tester.tap(pushPage2Finder);
    await tester.pumpAndSettle();
    expect(find.text("Current route: /page2"), findsOneWidget);
    expect(page1IncludeIfOffstageFinder, findsOneWidget);
    expect(page2IncludeIfOffstageFinder, findsOneWidget);
    expect(page3IncludeIfOffstageFinder, findsNothing);

    // push page 3
    await tester.tap(pushPage3Finder);
    await tester.pumpAndSettle();
    expect(find.text("Current route: /page3"), findsOneWidget);
    expect(page1IncludeIfOffstageFinder, findsOneWidget);
    expect(page2IncludeIfOffstageFinder, findsOneWidget);
    expect(page3IncludeIfOffstageFinder, findsOneWidget);

    // pop page 3
    await tester.tap(popFinder);
    await tester.pumpAndSettle();
    expect(find.text("Current route: /page2"), findsOneWidget);
    expect(page1IncludeIfOffstageFinder, findsOneWidget);
    expect(page2IncludeIfOffstageFinder, findsOneWidget);
    expect(page3IncludeIfOffstageFinder, findsNothing);

    // pop page 2
    await tester.tap(popFinder);
    await tester.pumpAndSettle();
    expect(find.text("Current route: /"), findsOneWidget);
    expect(page1IncludeIfOffstageFinder, findsOneWidget);
    expect(page2IncludeIfOffstageFinder, findsNothing);
    expect(page3IncludeIfOffstageFinder, findsNothing);
  });
  //
  testWidgets(NavigateType.popUntil.toString(), (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());
    await tester.pumpAndSettle();

    // initial route
    expect(find.text("Current route: /"), findsOneWidget);
    expect(page1IncludeIfOffstageFinder, findsOneWidget);
    expect(page2IncludeIfOffstageFinder, findsNothing);
    expect(page3IncludeIfOffstageFinder, findsNothing);

    // push page 2
    await tester.tap(pushPage2Finder);
    await tester.pumpAndSettle();
    expect(find.text("Current route: /page2"), findsOneWidget);
    expect(page1IncludeIfOffstageFinder, findsOneWidget);
    expect(page2IncludeIfOffstageFinder, findsOneWidget);
    expect(page3IncludeIfOffstageFinder, findsNothing);

    // push page 3
    await tester.tap(pushPage3Finder);
    await tester.pumpAndSettle();
    expect(find.text("Current route: /page3"), findsOneWidget);
    expect(page1IncludeIfOffstageFinder, findsOneWidget);
    expect(page2IncludeIfOffstageFinder, findsOneWidget);
    expect(page3IncludeIfOffstageFinder, findsOneWidget);

    // pop until page 1
    await tester.tap(popUntilPage1Finder);
    await tester.pumpAndSettle();
    expect(find.text("Current route: /"), findsOneWidget);
    expect(page1IncludeIfOffstageFinder, findsOneWidget);
    expect(page2IncludeIfOffstageFinder, findsNothing);
    expect(page3IncludeIfOffstageFinder, findsNothing);
  });
}
