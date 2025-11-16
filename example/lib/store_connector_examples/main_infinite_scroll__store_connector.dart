import 'dart:async';
import 'dart:convert';

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';

// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

late Store<AppState> store;

/// This example shows a List of Star Wars characters.
/// Scrolling to the bottom of the list will async load the next 20 characters.
/// Scrolling past the top of the list (pull to refresh) will use
/// `dispatchAndWait` to dispatch an action and get a future that tells the
/// `RefreshIndicator` when the action completes.
///
/// `isWaiting(LoadMoreAction)` prevents the user from loading more while the
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
          home: MyHomePageConnector(),
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

class MyHomePageConnector extends StatelessWidget {
  MyHomePageConnector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, ViewModel>(
      debug: this,
      vm: () => Factory(this),
      onInit: (st) => st.dispatch(RefreshAction()),
      builder: (BuildContext context, ViewModel vm) => MyHomePage(
        numTrivia: vm.numTrivia,
        isLoading: vm.isLoading,
        loadMore: vm.loadMore,
        onRefresh: vm.onRefresh,
      ),
    );
  }
}

/// Factory that creates a view-model for the StoreConnector.
class Factory extends VmFactory<AppState, MyHomePageConnector, ViewModel> {
  Factory(connector) : super(connector);

  @override
  ViewModel fromStore() {
    return ViewModel(
      numTrivia: state.numTrivia,
      isLoading: isWaiting(LoadMoreAction),
      loadMore: () => dispatch(LoadMoreAction()),
      onRefresh: () => dispatchAndWait(RefreshAction()),
    );
  }
}

/// The view-model holds the part of the Store state the dumb-widget needs.
class ViewModel extends Vm {
  final List<String> numTrivia;
  final bool isLoading;
  final VoidCallback loadMore;
  final Future<void> Function() onRefresh;

  ViewModel({
    required this.numTrivia,
    required this.isLoading,
    required this.loadMore,
    required this.onRefresh,
  }) : super(equals: [
          numTrivia,
          isLoading,
        ]);
}

class MyHomePage extends StatefulWidget {
  final List<String> numTrivia;
  final bool isLoading;
  final VoidCallback loadMore;
  final Future<void> Function() onRefresh;

  MyHomePage({
    Key? key,
    required this.numTrivia,
    required this.isLoading,
    required this.loadMore,
    required this.onRefresh,
  }) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late ScrollController _controller;

  @override
  void initState() {
    _controller = ScrollController()
      ..addListener(() {
        if (!widget.isLoading &&
            _controller.position.maxScrollExtent ==
                _controller.position.pixels) {
          widget.loadMore();
        }
      });
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Infinite Scroll Example (StoreConnector)')),
      body: (widget.numTrivia.isEmpty)
          ? Container()
          : RefreshIndicator(
              onRefresh: widget.onRefresh,
              child: ListView.builder(
                controller: _controller,
                itemCount: widget.numTrivia.length + (widget.isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  // Show loading spinner at the end
                  if (index == widget.numTrivia.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  } else
                    return ListTile(
                      leading: CircleAvatar(child: Text(index.toString())),
                      title: Text(widget.numTrivia[index]),
                    );
                },
              ),
            ),
    );
  }
}
