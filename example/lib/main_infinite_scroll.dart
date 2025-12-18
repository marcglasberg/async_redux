import 'dart:async';
import 'dart:convert';

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';

// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

late Store<AppState> store;

/// This example shows a List of Star Wars characters.
///
/// - Scrolling to the bottom of the list will async load the next 20 characters.
///
/// - Scrolling past the top of the list (pull to refresh) will use
/// `dispatchAndWait` to dispatch an action and get a future that tells the
/// `RefreshIndicator` when the action completes.
///
/// - `isWaiting(LoadMoreAction)` prevents the user from loading more while the
/// async action is running.
///
void main() {
  var state = AppState.initialState();
  store = Store<AppState>(
    initialState: state,
    actionObservers: [Log<AppState>.printer()],
    modelObserver: DefaultModelObserver(),
  );
  runApp(MyApp());
}

@immutable
class AppState {
  final List<String> numTrivia;

  AppState({required this.numTrivia});

  AppState copy({List<String>? numTrivia}) =>
      AppState(numTrivia: numTrivia ?? this.numTrivia);

  static AppState initialState() => AppState(numTrivia: <String>[]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppState &&
          runtimeType == other.runtimeType &&
          numTrivia == other.numTrivia;

  @override
  int get hashCode => numTrivia.hashCode;
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => StoreProvider<AppState>(
        store: store,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: MyHomePage(),
        ),
      );
}

class LoadMoreAction extends ReduxAction<AppState> {
  @override
  Future<AppState> reduce() async {
    List<String> list = List.from(state.numTrivia);
    int start = state.numTrivia.length + 1;

    // Fetch 20 people concurrently.
    final responses = await Future.wait(
      List.generate(20,
          (i) => get(Uri.parse('https://swapi.dev/api/people/${start + i}/'))),
    );

    for (final response in responses) {
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        list.add(data['name'] ?? 'Unknown character');
      }
    }

    return state.copy(numTrivia: list);
  }
}

class RefreshAction extends ReduxAction<AppState> {
  @override
  Future<AppState> reduce() async {
    List<String> list = [];

    // Fetch the first 20 people concurrently.
    final responses = await Future.wait(
      List.generate(
          20, (i) => get(Uri.parse('https://swapi.dev/api/people/${i + 1}/'))),
    );

    for (final response in responses) {
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        list.add(data['name'] ?? 'Unknown character');
      }
    }

    return state.copy(numTrivia: list);
  }
}

/// This is a "smart-widget" that directly accesses the store to select state
/// and dispatch actions, using context.select(), dispatch(), etc.
class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late ScrollController _controller;

  @override
  void initState() {
    super.initState();

    // Dispatch the initial refresh action
    dispatch(RefreshAction());

    _controller = ScrollController()..addListener(_scrollListener);
  }

  void _scrollListener() {
    // Get the current loading state
    final isLoading = context.isWaiting(LoadMoreAction);

    // Load more when scrolled to the bottom
    if (!isLoading &&
        _controller.position.maxScrollExtent == _controller.position.pixels) {
      context.dispatch(LoadMoreAction());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Select only the numTrivia list from state. Rebuilds only when numTrivia changes.
    final numTrivia = context.select((state) => state.numTrivia);

    // Check if LoadMoreAction is currently running
    final isLoading = context.isWaiting(LoadMoreAction);

    return Scaffold(
      appBar: AppBar(title: const Text('Infinite Scroll Example')),
      body: numTrivia.isEmpty
          ? Container()
          : RefreshIndicator(
              onRefresh: () => context.dispatchAndWait(RefreshAction()),
              child: ListView.builder(
                controller: _controller,
                itemCount: numTrivia.length + 1,
                itemBuilder: (context, index) {
                  // Show loading spinner at the end
                  if (index == numTrivia.length) {
                    return Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Center(
                        child: isLoading
                            ? CircularProgressIndicator()
                            : SizedBox(height: 30),
                      ),
                    );
                  } else {
                    return ListTile(
                      leading: CircleAvatar(child: Text(index.toString())),
                      title: Text(numTrivia[index]),
                    );
                  }
                },
              ),
            ),
    );
  }
}

/// Recommended extension methods for accessing state and dispatching actions.
extension BuildContextExtension on BuildContext {
  AppState get state => getState<AppState>();

  AppState read() => getRead<AppState>();

  R select<R>(R Function(AppState state) selector) =>
      getSelect<AppState, R>(selector);

  R? event<R>(Evt<R> Function(AppState state) selector) =>
      getEvent<AppState, R>(selector);
}
