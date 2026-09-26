import 'package:async_redux/async_redux.dart';
import 'package:flutter_test/flutter_test.dart';

class _MyAction extends ReduxAction<num> {
  final num number;

  _MyAction(this.number);

  @override
  num reduce() => number;
}

class _MyAsyncAction extends ReduxAction<num> {
  final num number;

  _MyAsyncAction(this.number);

  @override
  Future<num> reduce() async {
    await Future.sync(() {});
    return number;
  }
}

class _MyStateObserver extends StateObserver<num> {
  num? iniValue;
  num? endValue;

  @override
  void observe(
    ReduxAction<num?> action,
    num? stateIni,
    num? stateEnd,
    Object? error,
    int dispatchCount,
  ) {
    iniValue = stateIni;
    endValue = stateEnd;
  }
}

void main() {
  var observer = _MyStateObserver();
  Store<num> createStore() => Store<num>(initialState: 0, stateObservers: [observer]);

  test('Dispatch a sync action, see what the StateObserver picks up. ', () async {
    var store = createStore();
    expect(store.state, 0);

    store.dispatch(_MyAction(1));
    await store.waitCondition((state) => state == 1);
    expect(observer.iniValue, 0);
    expect(observer.endValue, 1);
  });

  test('Dispatch an async action, see what the StateObserver picks up.', () async {
    var store = createStore();
    expect(store.state, 0);

    store.dispatch(_MyAsyncAction(1));
    await store.waitCondition((state) => state == 1);
    expect(observer.iniValue, 0);
    expect(observer.endValue, 1);
  });
}
