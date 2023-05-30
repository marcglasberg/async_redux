import 'dart:async';
import 'dart:convert';

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';

// Developed by Marcelo Glasberg (Aug 2019).
// For more info, see: https://pub.dartlang.org/packages/async_redux

late Store<AppState> store;

/// This example shows a List of number descriptions.
/// Scrolling to the bottom of the list will async load the next 20 elements.
/// Scrolling past the top of the list (pull to refresh) will use `dispatch`
/// to dispatch an action, and get a future that tells a `RefreshIndicator`
/// when the action completes.
///
/// `IsLoadingAction` prevents the user to load more while the async loading action is running.
///
/// Note: This example uses http. It was configured to work in Android, debug mode only.
/// If you use iOS, please see:
/// https://flutter.dev/docs/release/breaking-changes/network-policy-ios-android
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
  final List<String>? numTrivia;
  final bool? isLoading;

  AppState({this.numTrivia, this.isLoading});

  AppState copy({List<String>? numTrivia, bool? isLoading}) => AppState(
        numTrivia: numTrivia ?? this.numTrivia,
        isLoading: isLoading ?? this.isLoading,
      );

  static AppState initialState() => AppState(
        numTrivia: <String>[],
        isLoading: false,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppState &&
          runtimeType == other.runtimeType &&
          numTrivia == other.numTrivia &&
          isLoading == other.isLoading;

  @override
  int get hashCode => numTrivia.hashCode ^ isLoading.hashCode;
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => StoreProvider<AppState>(
        store: store,
        child: MaterialApp(
          home: MyHomePageConnector(),
        ),
      );
}

class LoadMoreAction extends ReduxAction<AppState> {
  @override
  Future<AppState> reduce() async {
    Response response = await get(Uri.http(
        'http://numbersapi.com/',
        '${state.numTrivia!.length}'
            '..'
            '${state.numTrivia!.length + 19}'));

    List<String>? list = state.numTrivia;
    Map<String, dynamic> map = jsonDecode(response.body);
    map.forEach((String v, e) => list!.add(e.toString()));
    return state.copy(numTrivia: list);
  }

  @override
  void before() => dispatch(IsLoadingAction(true));

  @override
  void after() => dispatch(IsLoadingAction(false));
}

class RefreshAction extends ReduxAction<AppState> {
  @override
  Future<AppState> reduce() async {
    Response response = await get(Uri.http('http://numbersapi.com/', '0..19'));
    List<String> list = [];
    Map<String, dynamic> map = jsonDecode(response.body);
    map.forEach((String v, e) => list.add(e.toString()));
    return state.copy(numTrivia: list);
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
      isLoading: state.isLoading,
      loadMore: () => dispatch(LoadMoreAction()),
      onRefresh: () => dispatchAsync(RefreshAction()),
    );
  }
}

/// The view-model holds the part of the Store state the dumb-widget needs.
class ViewModel extends Vm {
  final List<String>? numTrivia;
  final bool? isLoading;
  final VoidCallback loadMore;
  final Future<void> Function() onRefresh;

  ViewModel({
    required this.numTrivia,
    required this.isLoading,
    required this.loadMore,
    required this.onRefresh,
  }) : super(equals: [
          numTrivia!,
          isLoading!,
        ]);
}

class MyHomePage extends StatefulWidget {
  final List<String>? numTrivia;
  final bool? isLoading;
  final VoidCallback? loadMore;
  final Future<void> Function()? onRefresh;

  MyHomePage({
    Key? key,
    this.numTrivia,
    this.isLoading,
    this.loadMore,
    this.onRefresh,
  }) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  ScrollController? _controller;

  @override
  void initState() {
    _controller = ScrollController()
      ..addListener(() {
        if (!widget.isLoading! &&
            _controller!.position.maxScrollExtent == _controller!.position.pixels) {
          widget.loadMore!();
        }
      });
    super.initState();
  }

  @override
  void dispose() {
    _controller!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dispatch Future Example')),
      body: (widget.numTrivia == null || widget.numTrivia!.isEmpty)
          ? Container()
          : RefreshIndicator(
              onRefresh: widget.onRefresh!,
              child: ListView.builder(
                controller: _controller,
                itemCount: widget.numTrivia!.length,
                itemBuilder: (context, index) => ListTile(
                  leading: CircleAvatar(child: Text(index.toString())),
                  title: Text(widget.numTrivia![index]),
                ),
              ),
            ),
    );
  }
}
