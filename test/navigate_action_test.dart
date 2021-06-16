import 'package:async_redux/async_redux.dart';
import 'package:async_redux/src/store_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

late Store<AppState, AppEnvironment> store;

final navigatorKey = GlobalKey<NavigatorState>();

final routes = {
  "/": (BuildContext context) => MyPage(const Key("page1")),
  "/page2": (BuildContext context) => MyPage(const Key("page2")),
  "/page3": (BuildContext context) => MyPage(const Key("page3")),
};

class AppState {}

class AppEnvironment {}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StoreProvider<AppState, AppEnvironment>(
      store: store,
      child: MaterialApp(
        initialRoute: "/",
        routes: routes,
        navigatorKey: navigatorKey,
      ),
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
          Text("Current route: ${NavigateAction.getCurrentNavigatorRouteName(context)}"),
          //
          RawMaterialButton(
              key: const Key("pushNamedPage2"),
              onPressed: () => store.dispatch(NavigateAction.pushNamed("/page2"))),
          //
          RawMaterialButton(
              key: const Key("pushNamedPage3"),
              onPressed: () => store.dispatch(NavigateAction.pushNamed("/page3"))),
          //
          RawMaterialButton(
              key: const Key("pushNamedAndRemoveAllPage1"),
              onPressed: () => store.dispatch(NavigateAction.pushNamedAndRemoveAll("/"))),
          //
          RawMaterialButton(
              key: const Key("pushReplacementNamedPage2"),
              onPressed: () => store.dispatch(NavigateAction.pushReplacementNamed("/page2"))),
          //
          RawMaterialButton(
              key: const Key("pushNamedAndRemoveUntilPage2"),
              onPressed: () => store.dispatch(
                      NavigateAction.pushNamedAndRemoveUntil("/page2", (Route<dynamic> route) {
                    return route.settings.name == "/";
                  }))),
          //
          RawMaterialButton(
              key: const Key("popUntilPage1"),
              onPressed: () => store.dispatch(NavigateAction.popUntilRouteName("/"))),
          //
          RawMaterialButton(
            key: const Key("pop"),
            onPressed: () => store.dispatch(NavigateAction.pop()),
          ),
          //
        ],
      ),
    );
  }
}

/////////////////////////////////////////////////////////////////////////////

void main() {
  setUp(() async {
    NavigateAction.setNavigatorKey(navigatorKey);
    store = Store<AppState, AppEnvironment>(
      initialState: AppState(),
      environment: AppEnvironment()
    );
  });

  final Finder page1Finder = find.byKey(const Key("page1"));
  final Finder page1IncludeIfOffstageFinder = find.byKey(const Key("page1"), skipOffstage: false);
  final Finder pushAndRemoveAllPage1Finder = find.byKey(const Key("pushNamedAndRemoveAllPage1"));
  final Finder popUntilPage1Finder = find.byKey(const Key("popUntilPage1"));

  final Finder page2Finder = find.byKey(const Key("page2"));
  final Finder page2IncludeIfOffstageFinder = find.byKey(const Key("page2"), skipOffstage: false);
  final Finder pushPage2Finder = find.byKey(const Key("pushNamedPage2"));
  final Finder pushReplacementPage2Finder = find.byKey(const Key("pushReplacementNamedPage2"));
  final Finder pushNamedAndRemoveUntilPage2Finder =
      find.byKey(const Key("pushNamedAndRemoveUntilPage2"));

  final Finder page3Finder = find.byKey(const Key("page3"));
  final Finder page3IncludeIfOffstageFinder = find.byKey(const Key("page3"), skipOffstage: false);
  final Finder pushPage3Finder = find.byKey(const Key("pushNamedPage3"));

  final Finder popFinder = find.byKey(const Key("pop"));

  /////////////////////////////////////////////////////////////////////////////

  testWidgets("pushNamed", (WidgetTester tester) async {
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

  testWidgets("pushNamedAndRemoveAll", (WidgetTester tester) async {
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

  testWidgets("pushReplacementNamed", (WidgetTester tester) async {
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

  testWidgets("pushNamedAndRemoveUntil", (WidgetTester tester) async {
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

    // the current stack should be:
    // page 3
    // page 2
    // page 1

    // if we push page 2 and replace until page 1,then the stack should be:
    // page 2 (pushed)
    // page 3 (removed)
    // page 2 (removed)
    // page 1

    // which would result in a stack of
    // page 2
    // page 1
    await tester.tap(pushNamedAndRemoveUntilPage2Finder);
    await tester.pumpAndSettle();
    expect(find.text("Current route: /page2"), findsOneWidget);
    expect(page1IncludeIfOffstageFinder, findsOneWidget);
    expect(page2IncludeIfOffstageFinder, findsOneWidget);
    expect(page3IncludeIfOffstageFinder, findsNothing);
  });

  /////////////////////////////////////////////////////////////////////////////

  testWidgets("pop", (WidgetTester tester) async {
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
  testWidgets("popUntil", (WidgetTester tester) async {
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
