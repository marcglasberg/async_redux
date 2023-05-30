import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

@immutable
class AppState {
  final int count;

  AppState({this.count = 0});

  AppState copy({int? count}) => AppState(count: count ?? this.count);
}

class _SyncAction extends ReduxAction<AppState> {
  static int count = 0;

  @override
  AppState reduce() {
    count++;
    return state.copy(count: state.count + 1);
  }
}

class _AsyncAction extends ReduxAction<AppState> {
  static int count = 0;

  @override
  Future<AppState> reduce() async {
    await microtask;
    count++;
    return state.copy(count: state.count + 1);
  }
}

class _TestWrapReduce extends WrapReduce<AppState> {
  @override
  AppState process({required oldState, required newState}) => newState;
}

void main() {
  late Store<AppState> store;

  setUp(() async {
    store = Store<AppState>(initialState: AppState(), wrapReduce: _TestWrapReduce());
  });

  group(WrapReduce, () {
    test("Only reduces sync reducer once.", () async {
      expect(store.state.count, 0);
      await store.dispatch(_SyncAction());
      expect(_SyncAction.count, 1);
      expect(store.state.count, 1);
    });
    test("Only reduces async reducer once.", () async {
      expect(store.state.count, 0);
      await store.dispatch(_AsyncAction());
      expect(_AsyncAction.count, 1);
      expect(store.state.count, 1);
    });
  });
}
