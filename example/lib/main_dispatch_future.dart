import 'dart:async';
import 'dart:convert';

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';

// Developed by Marcelo Glasberg (Aug 2019).
// For more info, see: https://pub.dartlang.org/packages/async_redux

Store<AppState> store;

/// This example shows a List of number descriptions.
/// Scrolling to the bottom of the list will async load the next 20 elements.
/// Scrolling past the top of the list (pull to refresh) will use `dispatchFuture`
/// to dispatch an action, and get a `Future<void>` that tells a `RefreshIndicator`
/// when the action completes.
///
/// `IsLoadingAction` prevents the user to load more while the async loading action is running.
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

///////////////////////////////////////////////////////////////////////////////

class AppState {
  final List<String> numTrivias;
  final bool isLoading;

  AppState({this.numTrivias, this.isLoading});

  AppState copy({List<String> numTrivias, bool isLoading}) => AppState(
        numTrivias: numTrivias ?? this.numTrivias,
        isLoading: isLoading ?? this.isLoading,
      );

  static AppState initialState() => AppState(numTrivias: <String>[], isLoading: false);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppState &&
          runtimeType == other.runtimeType &&
          numTrivias == other.numTrivias &&
          isLoading == other.isLoading;

  @override
  int get hashCode => numTrivias.hashCode ^ isLoading.hashCode;
}

///////////////////////////////////////////////////////////////////////////////

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => StoreProvider<AppState>(
        store: store,
        child: MaterialApp(
          home: MyHomePageConnector(),
        ),
      );
}

///////////////////////////////////////////////////////////////////////////////

class LoadMoreAction extends ReduxAction<AppState> {
  @override
  Future<AppState> reduce() async {
    Response response = await get(
        'http://numbersapi.com/${state.numTrivias.length}..${state.numTrivias.length + 19}');
    List<String> list = state.numTrivias;
    Map<String, dynamic> map = jsonDecode(response.body);
    map.forEach((String v, e) => list.add(e.toString()));
    return state.copy(numTrivias: list);
  }

  @override
  void before() => dispatch(IsLoadingAction(true));

  @override
  void after() => dispatch(IsLoadingAction(false));
}

class RefreshAction extends ReduxAction<AppState> {
  @override
  Future<AppState> reduce() async {
    Response response = await get('http://numbersapi.com/0..19');
    List<String> list = [];
    Map<String, dynamic> map = jsonDecode(response.body);
    map.forEach((String v, e) => list.add(e.toString()));
    return state.copy(numTrivias: list);
  }

  @override
  void before() => dispatch(IsLoadingAction(true));

  @override
  void after() => dispatch(IsLoadingAction(false));
}

class IsLoadingAction extends ReduxAction<AppState> {
  IsLoadingAction(this.val);

  final bool val;

  @override
  AppState reduce() => state.copy(isLoading: val);
}

///////////////////////////////////////////////////////////////////////////////

class MyHomePageConnector extends StatelessWidget {
  MyHomePageConnector({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, ViewModel>(
      debug: this,
      model: ViewModel(),
      onInit: (st) => st.dispatch(RefreshAction()),
      builder: (BuildContext context, ViewModel vm) => MyHomePage(
        numTrivias: vm.numTrivias,
        isLoading: vm.isLoading,
        loadMore: vm.loadMore,
        onRefresh: vm.onRefresh,
      ),
    );
  }
}

class ViewModel extends BaseModel<AppState> {
  ViewModel();

  List<String> numTrivias;
  bool isLoading;
  VoidCallback loadMore;
  Future<void> Function() onRefresh;

  ViewModel.build({
    @required this.numTrivias,
    @required this.isLoading,
    @required this.loadMore,
    @required this.onRefresh,
  }) : super(equals: [
          numTrivias,
          isLoading,
        ]);

  @override
  ViewModel fromStore() => ViewModel.build(
        numTrivias: state.numTrivias,
        isLoading: state.isLoading,
        loadMore: () => dispatch(LoadMoreAction()),
        onRefresh: () => dispatchFuture(RefreshAction()),
      );
}

///////////////////////////////////////////////////////////////////////////////

class MyHomePage extends StatefulWidget {
  final List<String> numTrivias;
  final bool isLoading;
  final VoidCallback loadMore;
  final Future<void> Function() onRefresh;

  MyHomePage({
    Key key,
    this.numTrivias,
    this.isLoading,
    this.loadMore,
    this.onRefresh,
  }) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  ScrollController _controller;

  @override
  void initState() {
    _controller = ScrollController()
      ..addListener(() {
        if (!widget.isLoading &&
            _controller.position.maxScrollExtent == _controller.position.pixels) {
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
      appBar: AppBar(title: const Text('Dispatch Future Example')),
      body: (widget.numTrivias == null || widget.numTrivias.isEmpty)
          ? Container()
          : RefreshIndicator(
              onRefresh: widget.onRefresh,
              child: ListView.builder(
                controller: _controller,
                itemCount: widget.numTrivias.length,
                itemBuilder: (context, index) => ListTile(
                  leading: CircleAvatar(child: Text(index.toString())),
                  title: Text(widget.numTrivias[index]),
                ),
              ),
            ),
    );
  }
}

///////////////////////////////////////////////////////////////////////////////
