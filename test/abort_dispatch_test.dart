import 'package:async_redux/async_redux.dart';
import "package:test/test.dart";

// Developed by Marcelo Glasberg (Aug 2019).
// For more info, see: https://pub.dartlang.org/packages/async_redux

///////////////////////////////////////////////////////////////////////////////

List<String> info;

void main() {
  /////////////////////////////////////////////////////////////////////////////

  test('Test aborting an action.', () async {
    //
    info = [];
    Store<String> store = Store<String>(initialState: "");

    store.dispatch(ActionA(abort: false));
    expect(store.state, "X");
    expect(info, ['1', '2', '3']);

    store.dispatch(ActionA(abort: false));
    expect(store.state, "XX");
    expect(info, ['1', '2', '3', '1', '2', '3']);

    // Won't dispatch, because abortDispatch checks the abort flag.
    store.dispatch(ActionA(abort: true));
    expect(store.state, "XX");
    expect(info, ['1', '2', '3', '1', '2', '3']);
  });

  /////////////////////////////////////////////////////////////////////////////

  test('Test aborting an action, where the abortDispatch method accesses the state.', () async {
    //
    info = [];
    Store<String> store = Store<String>(initialState: "");

    store.dispatch(ActionB());
    expect(store.state, "X");
    expect(info, ['1', '2', '3']);

    store.dispatch(ActionB());
    expect(store.state, "XX");
    expect(info, ['1', '2', '3', '1', '2', '3']);

    // Won't dispatch, because abortDispatch checks that the state has length 2.
    store.dispatch(ActionB());
    expect(store.state, "XX");
    expect(info, ['1', '2', '3', '1', '2', '3']);
  });

  /////////////////////////////////////////////////////////////////////////////
}

// ----------------------------------------------

class ActionA extends ReduxAction<String> {
  bool abort;

  ActionA({this.abort});

  @override
  bool abortDispatch() => abort;

  @override
  void before() {
    info.add('1');
  }

  @override
  String reduce() {
    info.add('2');
    return state + 'X';
  }

  @override
  void after() {
    info.add('3');
  }
}

// ----------------------------------------------

class ActionB extends ReduxAction<String> {
  @override
  bool abortDispatch() => state.length >= 2;

  @override
  void before() {
    info.add('1');
  }

  @override
  String reduce() {
    info.add('2');
    return state + 'X';
  }

  @override
  void after() {
    info.add('3');
  }
}

// ----------------------------------------------
