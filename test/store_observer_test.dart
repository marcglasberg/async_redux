import 'dart:async';

import 'package:async_redux/async_redux.dart';
import "package:test/test.dart";

class _MyAction extends ReduxAction<num, int> {
  final num number;

  _MyAction(this.number);

  @override
  num reduce() => number;
}

class _MyAsyncAction extends ReduxAction<num, int> {
  final num number;

  _MyAsyncAction(this.number);

  @override
  Future<num> reduce() async {
    await Future.sync(() {});
    return number;
  }
}

class _MyStateObserver extends StateObserver<num?, int> {
  num? iniValue;
  num? endValue;

  @override
  void observe(ReduxAction<num?, int> action, num? stateIni, num? stateEnd, int dispatchCount) {
    iniValue = stateIni;
    endValue = stateEnd;
  }
}

void main() {
  var observer = _MyStateObserver();
  StoreTester<num, int> createStoreTester() {
    var store = Store<num, int>(
      initialState: 0, 
      environment: 0,
      stateObservers: [observer]
    );
    return StoreTester.from(store);
  }

  ///////////////////////////////////////////////////////////////////////////////

  test('Dispatch a sync action, see what the StateObserver picks up. ', () async {
    var storeTester = createStoreTester();
    expect(storeTester.state, 0);

    storeTester.dispatch(_MyAction(1));
    var condition = (TestInfo<num?, int>? info) => info!.state == 1;
    await storeTester.waitConditionGetLast(condition);
    expect(observer.iniValue, 0);
    expect(observer.endValue, 1);
  });

  ///////////////////////////////////////////////////////////////////////////////

  test('Dispatch an async action, see what the StateObserver picks up.', () async {
    var storeTester = createStoreTester();
    expect(storeTester.state, 0);

    storeTester.dispatch(_MyAsyncAction(1));
    var condition = (TestInfo<num?, int>? info) => info!.state == 1;
    await storeTester.waitConditionGetLast(condition);
    expect(observer.iniValue, 0);
    expect(observer.endValue, 1);
  });

  ///////////////////////////////////////////////////////////////////////////////
}
