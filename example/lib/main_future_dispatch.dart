import 'dart:async';
import 'dart:convert';

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';

// Developed by Marcelo Glasberg (Aug 2019).
// For more info, see: https://pub.dartlang.org/packages/async_redux

Store<AppState> store;

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
    Response response = await get('http://numbersapi.com/${state.numTrivias.length}..${state.numTrivias.length + 20}');
    List<String> list = state.numTrivias;
    Map<String, dynamic> map = jsonDecode(response.body);
    map.forEach((String v, e) => list.add(e.toString()));
    return state.copy(numTrivias: list);
  }

  void before() => dispatch(LoadingAction(true));

  void after() => dispatch(LoadingAction(false));
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

  void before() => dispatch(LoadingAction(true));

  void after() => dispatch(LoadingAction(false));
}

class LoadingAction extends ReduxAction<AppState> {
  LoadingAction(this.val);

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
      model: ViewModel(),
      onInit: (st) => st.dispatch(RefreshAction()),
      builder: (BuildContext context, ViewModel vm) => MyHomePage(
        numTrivias: vm.numTrivias,
        isLoading: vm.isLoading,
        loadMore: vm.loadMore,
      ),
      debug: this,
    );
  }
}

/// Helper class to the connector widget. Holds the part of the State the widget needs,
/// and may perform conversions to the type of data the widget can conveniently work with.
class ViewModel extends BaseModel<AppState> {
  ViewModel();

  List<String> numTrivias;
  bool isLoading;
  VoidCallback loadMore;

  //VoidCallback onIncrement;

  ViewModel.build({
    @required this.numTrivias,
    @required this.isLoading,
    @required this.loadMore,
  }) : super(equals: [numTrivias, isLoading]);

  @override
  ViewModel fromStore() => ViewModel.build(
        numTrivias: state.numTrivias,
        isLoading: state.isLoading,
        loadMore: () => dispatch(LoadMoreAction()),
      );
}

///////////////////////////////////////////////////////////////////////////////

class MyHomePage extends StatefulWidget {
  final List<String> numTrivias;
  final bool isLoading;
  final VoidCallback loadMore;

  MyHomePage({
    Key key,
    this.numTrivias,
    this.isLoading,
    this.loadMore,
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
        if (!widget.isLoading && _controller.position.maxScrollExtent == _controller.position.pixels) {
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
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: Text('Future Dispatch Example')),
          body: (widget.numTrivias == null || widget.numTrivias.isEmpty)
              ? Container()
              : RefreshIndicator(
                  onRefresh: () => StoreProvider.of<AppState>(context, 'refresh').dispatchFuture(RefreshAction()),
                  child: ListView.builder(
                    controller: _controller,
                    itemCount: widget.numTrivias.length,
                    itemBuilder: (context, index) => ListTile(
                      leading: Text(index.toString()),
                      title: Text(widget.numTrivias[index]),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
