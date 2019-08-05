import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Action;

import '../async_redux.dart';

/// Developed by Marcelo Glasberg (Aug 2019).
/// For more info, see: https://pub.dartlang.org/packages/async_redux

/// Helps testing the store, actions, and sync/async reducers.
///
/// For more info, see: https://pub.dartlang.org/packages/async_redux
///
class StoreListener<St> {
  static const _defaultTimout = 30;
  static final TestInfoPrinter _defaultTestInfoPrinter = (TestInfo info) => print(info);
  static final VoidCallback _defaultNewStorePrinter = () => print("New StoreListener.");

  Store<St> _store;
  StreamSubscription _subscription;
  Completer<TestInfo<St>> _completer;
  Queue<Future<TestInfo<St>>> _futures;

  Store<St> get store => _store;

  St get state => _store.state;

  StoreListener({
    @required St initialState,
    TestInfoPrinter testInfoPrinter,
    bool syncStream = false,
  }) : this.from(
            store: Store(initialState: initialState, syncStream: syncStream),
            testInfoPrinter: testInfoPrinter);

  StoreListener.from({
    @required Store<St> store,
    TestInfoPrinter testInfoPrinter,
  }) : assert(store != null) {
    _store = store;
    _listen(testInfoPrinter);
    _defaultNewStorePrinter();
  }

  void dispatch(ReduxAction<St> action) => store.dispatch(action);

  void defineState(St state) => _store.defineState(state);

  /// Expects **one action** of the given type to be dispatched, and waits until it finishes.
  /// Returns the info after the action finishes.
  /// Will fail with an exception if an unexpected action is seen.
  Future<TestInfo> wait(Type actionType) async => waitAllGetLast([actionType]);

  /// Runs until an action of the given type is dispatched, and then waits until it finishes.
  /// Returns the info after the action finishes. **Ignores other** actions types.
  Future<TestInfo> waitUntil(
    Type actionType, {
    int timeoutInSeconds = _defaultTimout,
  }) async {
    assert(actionType != null);

    TestInfo<St> testInfo;

    while (testInfo == null || testInfo.action.runtimeType != actionType || testInfo.ini == true) {
      testInfo = await _next(timeoutInSeconds: timeoutInSeconds);
    }

    return testInfo;
  }

  /// Runs until the exact given action is dispatched, and then waits until it finishes.
  /// Returns the info after the action finishes. **Ignores other** actions.
  ///
  /// Example use:
  ///
  ///   var action = MyAction();
  ///   storeListener.dispatch(action);
  ///   await storeListener.waitUntilAction(action);
  ///
  Future<TestInfo> waitUntilAction(
    ReduxAction<St> action, {
    int timeoutInSeconds = _defaultTimout,
  }) async {
    assert(action != null);

    TestInfo<St> testInfo;

    while (testInfo == null || testInfo.action != action || testInfo.ini == true) {
      testInfo = await _next(timeoutInSeconds: timeoutInSeconds);
    }

    return testInfo;
  }

  /// Runs until **all** given actions types are dispatched, **in order**.
  /// Waits until all of them are finished.
  /// Returns the info after all actions finish.
  /// Will fail with an exception if an unexpected action is seen,
  /// or if any of the expected actions are dispatched in the wrong order.
  Future<TestInfo> waitAllGetLast(List<Type> actionTypes) async {
    assert(actionTypes != null);

    var infoList = await waitAll(actionTypes);
    return infoList.last;
  }

  /// Runs until **all** given actions types are dispatched, in **any order**.
  /// Waits until all of them are finished. Returns the info after all actions finish.
  /// Will fail with an exception if an unexpected action is seen.
  Future<TestInfo> waitAllUnorderedGetLast(
    List<Type> actionTypes, {
    int timeoutInSeconds = _defaultTimout,
  }) async =>
      (await waitAllUnordered(actionTypes, timeoutInSeconds: timeoutInSeconds)).last;

  /// The same as `waitAllGetLast`, but instead of returning just the last info,
  /// it returns a list with the end info for each action.
  Future<TestInfoList<St>> waitAll(List<Type> actionTypes) async {
    assert(actionTypes != null);

    TestInfoList<St> results = TestInfoList<St>();

    // Waits the end of all actions, in any order.
    List<TestInfo<St>> endStates = [];

    TestInfo<St> testInfoState;

    for (Type actionType in actionTypes) {
      testInfoState =
          await _getNextActionIniWhileSavingActionsEnd(actionType, testInfoState, endStates);
    }

    for (TestInfo<St> testInfoFinal in endStates) {
      results._add(testInfoFinal);
    }

    TestInfoList<St> testInfoStateAposFinais =
        await _waitActionsEndUnordered(actionTypes, endStates);

    results._addAll(testInfoStateAposFinais);

    return results;
  }

  /// The same as `waitAllUnorderedGetLast`, but instead of returning just the last info,
  /// it returns a list with the end info for each action.
  Future<TestInfoList<St>> waitAllUnordered(
    List<Type> actionTypes, {
    int timeoutInSeconds = _defaultTimout,
  }) async {
    assert(actionTypes != null);

    TestInfoList<St> testInfoList = TestInfoList<St>();
    List<Type> actionsIni = List.from(actionTypes);
    List<Type> actionsEnd = List.from(actionTypes);

    TestInfo<St> testInfo;

    while (actionsIni.isNotEmpty || actionsEnd.isNotEmpty) {
      try {
        testInfo = await _next(timeoutInSeconds: timeoutInSeconds);
      } catch (error) {
        print("These actions were not dispatched: $actionsIni INI.");
        print("These actions haven't finished: $actionsEnd END.");
        rethrow;
      }

      var action = testInfo.action.runtimeType;

      if (testInfo.ini) {
        if (!actionsIni.remove(action))
          throw StoreException("Unexpected action was dispatched: $action INI.");
      } else {
        if (!actionsEnd.remove(action))
          throw StoreException("Unexpected action was dispatched: $action END.");

        // Only save the END states.
        testInfoList._add(testInfo);
      }
    }

    return testInfoList;
  }

  void _listen(TestInfoPrinter testInfoPrinter) {
    if (testInfoPrinter != null)
      _store.initTestInfoPrinter(testInfoPrinter);
    else if (_store.testInfoPrinter == null)
      _store.initTestInfoPrinter(testInfoPrinter ?? _defaultTestInfoPrinter);

    _store.initTestInfoController();
    _subscription = _store.onReduce.listen(_completeFuture);
    _completer = Completer();
    _futures = Queue()..addLast(_completer.future);
  }

  /// Waits for all actions that are still running to finish.
  /// Then returns a list with all [TestInfo]s.
  /// If any action is unexpected, throws.
  /// If any INI state is found, throws.
  Future<TestInfoList<St>> _waitActionsEndUnordered(
    List<Type> listOfExpectedActions,
    List<TestInfo<St>> alreadyDispatchedEnd,
  ) async {
    //
    List<Type> alreadyDispatchedActions =
        alreadyDispatchedEnd.map((state) => state.action.runtimeType).toList();

    listOfExpectedActions.removeWhere(
        (actionType) => actionType == null || alreadyDispatchedActions.remove(actionType));

    TestInfo<St> testInfo;

    TestInfoList<St> results = TestInfoList<St>();

    while (listOfExpectedActions.isNotEmpty) {
      testInfo = await _next();

      if (testInfo.ini)
        throw StoreException("Foi disparada uma action de INI: ${testInfo.action}.");

      results._add(testInfo);

      // If the action is found in the action list, removes it.
      if (!listOfExpectedActions.remove(testInfo.action.runtimeType))
        throw StoreException("Foi disparada uma action não listada: ${testInfo.action}.");
    }

    return results;
  }

  Future<TestInfo<St>> _getNextActionIniWhileSavingActionsEnd(
    Type action,
    TestInfo<St> testInfoState,
    List<TestInfo<St>> endStates,
  ) async {
    if (action != null) {
      testInfoState = await _next();

      while (testInfoState.ini == false) {
        endStates.add(testInfoState);
        testInfoState = await _next();
      }

      if (action != null && (testInfoState.action.runtimeType != action))
        throw StoreException(
            "Wrong action: ${testInfoState.action.runtimeType} ${testInfoState.ini}.");
    }

    return testInfoState;
  }

  Future<TestInfo<St>> _next({
    int timeoutInSeconds = _defaultTimout,
  }) async {
    if (_futures.isEmpty) {
      _completer = Completer();
      _futures.addLast(_completer.future);
    }

    var result = _futures.removeFirst();

    return (timeoutInSeconds == null)
        ? result
        : result.timeout(
            Duration(seconds: timeoutInSeconds),
            onTimeout: () => throw StoreException("Timeout."),
          );
  }

  void _completeFuture(TestInfo<St> reduceInfo) {
    _completer.complete(reduceInfo);
    _completer = Completer();
    _futures.addLast(_completer.future);
  }

  Future cancel() async => await _subscription.cancel();
}

///////////////////////////////////////////////////////////////////////////////

/// List of test information, before or after some actions are dispatched.
class TestInfoList<St> {
  final List<TestInfo<St>> _info = [];

  TestInfo<St> get last => _info.last;

  TestInfo<St> get first => _info.first;

  /// The number of dispatched actions.
  int get length => _info.length;

  /// Returns info corresponding to the end of the index-th dispatched action type.
  TestInfo<St> getIndex(int index) => _info[index];

  /// Returns the first info corresponding to the end of the given action type.
  TestInfo<St> operator [](Type actionType) {
    return _info.firstWhere((info) => info.action.runtimeType == actionType, orElse: null);
  }

  /// Returns the n-th info corresponding to the end of the given action type
  /// Note: N == 1 is the first one.
  TestInfo<St> get(Type actionType, [int n]) {
    return _info.firstWhere((info) {
      var ifFound = (info.action.runtimeType == actionType);
      if (ifFound) n--;
      return ifFound && (n == 0);
    }, orElse: null);
  }

  /// Returns all info corresponding to the action type.
  List<TestInfo<St>> getAll(Type actionType) {
    return _info.where((info) => info.action.runtimeType == actionType).toList();
  }

  void forEach(void action(TestInfo<St> element)) => _info.forEach(action);

  TestInfo<St> firstWhere(bool test(TestInfo<St> element), {TestInfo<St> orElse()}) =>
      _info.firstWhere(test);

  TestInfo<St> lastWhere(bool test(TestInfo<St> element), {TestInfo<St> orElse()}) =>
      _info.lastWhere(test);

  TestInfo<St> singleWhere(bool test(TestInfo<St> element), {TestInfo<St> orElse()}) =>
      _info.singleWhere(test);

  Iterable<TestInfo<St>> where(bool test(TestInfo<St> element)) => _info.where(test);

  Iterable<T> map<T>(T f(TestInfo<St> element)) => _info.map(f);

  List<TestInfo<St>> toList({bool growable = true}) => _info.toList(growable: growable);

  Set<TestInfo<St>> toSet() => _info.toSet();

  bool get isEmpty => length == 0;

  bool get isNotEmpty => !isEmpty;

  void _add(TestInfo<St> info) => _info.add(info);

  void _addAll(TestInfoList<St> infoList) => _info.addAll(infoList._info);
}
