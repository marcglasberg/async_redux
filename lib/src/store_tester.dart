import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Action;

import '../async_redux.dart';

// Developed by Marcelo Glasberg (Aug 2019).
// For more info, see: https://pub.dartlang.org/packages/async_redux

/// Predicate used in [StoreTester.waitCondition].
/// Return true to stop waiting, and get the last state.
typedef bool StateCondition<St>(TestInfo<St> info);

/// Helps testing the store, actions, and sync/async reducers.
///
/// For more info, see: https://pub.dartlang.org/packages/async_redux
///
class StoreTester<St> {
  //
  /// The global default timeout for the wait functions.
  static const defaultTimeout = 500;

  /// If the default debug info should be printed to the console or not.
  static bool printDefaultDebugInfo = true;

  static TestInfoPrinter defaultTestInfoPrinter = (TestInfo info) {
    if (printDefaultDebugInfo) print(info);
  };

  static VoidCallback defaultNewStorePrinter = () {
    if (printDefaultDebugInfo) print("New StoreTester.");
  };

  final Store<St> _store;
  final List<Type> _ignore;
  StreamSubscription _subscription;
  Completer<TestInfo<St>> _completer;
  Queue<Future<TestInfo<St>>> _futures;

  Store<St> get store => _store;

  St get state => _store.state;

  TestInfo<St> lastInfo;

  /// The [StoreTester] makes it easy to test both sync and async reducers.
  /// You may dispatch some action, wait for it to finish or wait until some
  /// arbitrary condition is met, and then check the resulting state.
  ///
  /// The [StoreTester] will, by default, print some default debug
  /// information to the console. You can disable these prints globally
  /// by making `StoreTester.printDefaultDebugInfo = false`.
  /// Note you can also provide your own custom [testInfoPrinter].
  ///
  /// If [shouldThrowUserExceptions] is true, all errors will be thrown,
  /// and not swallowed, including UserExceptions. Use this in all tests
  /// that should throw no errors. Pass [shouldThrowUserExceptions] as
  /// false when you are testing code that should throw UserExceptions.
  /// These exceptions will then silently go to the `errors` queue,
  /// where you can assert they exist with the right error messages.
  ///
  StoreTester({
    @required St initialState,
    TestInfoPrinter testInfoPrinter,
    List<Type> ignore,
    bool syncStream = false,
    ErrorObserver errorObserver,
    bool shouldThrowUserExceptions = false,
  }) : this.from(
            Store(
              initialState: initialState,
              syncStream: syncStream,
              errorObserver:
                  errorObserver ?? (shouldThrowUserExceptions ? TestErrorObserver() : null),
            ),
            testInfoPrinter: testInfoPrinter,
            ignore: ignore);

  StoreTester.from(
    Store<St> store, {
    TestInfoPrinter testInfoPrinter,
    List<Type> ignore,
  })  : assert(store != null),
        _ignore = ignore ?? const [],
        _store = store {
    _listen(testInfoPrinter);
    defaultNewStorePrinter();
  }

  void dispatch(ReduxAction<St> action) => store.dispatch(action);

  Future<void> dispatchFuture(ReduxAction<St> action) => store.dispatchFuture(action);

  void defineState(St state) => _store.defineState(state);

  /// Returns a mutable copy of the global ignore list.
  List<Type> get ignore => List.of(_ignore);

  /// Runs until the predicate function [condition] returns true.
  /// This function will receive each testInfo, from where it can
  /// access the state, action, errors etc.
  /// Only END states will be received, unless you pass [ignoreIni] as false.
  /// Returns the info after the condition is met.
  ///
  Future<TestInfo<St>> waitConditionGetLast(
    StateCondition<St> condition, {
    bool testImmediately = true,
    bool ignoreIni = true,
    int timeoutInSeconds = defaultTimeout,
  }) async {
    var infoList = await waitCondition(condition,
        testImmediately: testImmediately, ignoreIni: ignoreIni, timeoutInSeconds: timeoutInSeconds);

    return infoList.last;
  }

  /// Runs until the predicate function [condition] returns true.
  /// This function will receive each testInfo, from where it can
  /// access the state, action, errors etc.
  /// Only END states will be received, unless you pass [ignoreIni] as false.
  /// Returns a list with all info until the condition is met.
  ///
  Future<TestInfoList<St>> waitCondition(
    StateCondition<St> condition, {
    bool testImmediately = true,
    bool ignoreIni = true,
    int timeoutInSeconds = defaultTimeout,
  }) async {
    assert(condition != null);

    TestInfoList<St> infoList = TestInfoList<St>();

    if (testImmediately) {
      var testInfo = TestInfo<St>(
          state, null, null, null, null, store.dispatchCount, store.reduceCount, store.errors);
      if (condition(testInfo)) {
        infoList._add(testInfo);
        return infoList;
      }
    }

    TestInfo<St> testInfo = await _next(timeoutInSeconds: timeoutInSeconds);

    while (true) {
      if (ignoreIni)
        while (testInfo.ini) testInfo = await _next(timeoutInSeconds: timeoutInSeconds);

      infoList._add(testInfo);

      if (condition(testInfo))
        break;
      else
        testInfo = await _next(timeoutInSeconds: timeoutInSeconds);
    }

    lastInfo = infoList.last;

    return infoList;
  }

  /// If [error] is a Type, runs until after an action throws an error of this exact type.
  /// If [error] is NOT a Type, runs until after an action throws this [error] (using equals).
  ///
  /// You can also, instead, define [processedError], which is the error after wrapped by the
  /// action's wrapError() method. Note, if you define both [error] and [processedError],
  /// both need to match.
  ///
  /// Returns the info after the error condition is met.
  ///
  Future<TestInfo<St>> waitUntilErrorGetLast({
    Object error,
    Object processedError,
    int timeoutInSeconds = defaultTimeout,
  }) async {
    var infoList = await waitUntilError(
        error: error, processedError: processedError, timeoutInSeconds: timeoutInSeconds);

    return infoList.last;
  }

  /// If [error] is a Type, runs until after an action throws an error of this exact type.
  /// If [error] is NOT a Type, runs until after an action throws this [error] (using equals).
  ///
  /// You can also, instead, define [processedError], which is the error after wrapped by the
  /// action's wrapError() method. Note, if you define both [error] and [processedError],
  /// both need to match.
  ///
  /// Returns a list with all info until the error condition is met.
  ///
  Future<TestInfoList<St>> waitUntilError({
    Object error,
    Object processedError,
    int timeoutInSeconds = defaultTimeout,
  }) async {
    assert(error != null || processedError != null);

    var condition = (TestInfo<St> info) =>
        (error == null ||
            (error is Type && info.error.runtimeType == error) ||
            (error is! Type && info.error == error)) &&
        (processedError == null ||
            (processedError is Type && info.processedError.runtimeType == processedError) ||
            (processedError is! Type && info.processedError == processedError));

    var infoList =
        await waitCondition(condition, ignoreIni: true, timeoutInSeconds: timeoutInSeconds);

    lastInfo = infoList.last;

    return infoList;
  }

  /// Expects **one action** of the given type to be dispatched, and waits until it finishes.
  /// Returns the info after the action finishes.
  /// Will fail with an exception if an unexpected action is seen.
  Future<TestInfo> wait(Type actionType) async => waitAllGetLast([actionType]);

  /// Runs until an action of the given type is dispatched, and then waits until it finishes.
  /// Returns the info after the action finishes. **Ignores other** actions types.
  ///
  Future<TestInfo> waitUntil(
    Type actionType, {
    int timeoutInSeconds = defaultTimeout,
  }) async {
    assert(actionType != null);

    TestInfo<St> testInfo;

    while (testInfo == null || testInfo.type != actionType || testInfo.isINI) {
      testInfo = await _next(timeoutInSeconds: timeoutInSeconds);
    }

    lastInfo = testInfo;

    return testInfo;
  }

  /// Runs until the exact given action is dispatched, and then waits until it finishes.
  /// Returns the info after the action finishes. **Ignores other** actions.
  ///
  /// Example use:
  ///
  ///   var action = MyAction();
  ///   storeTester.dispatch(action);
  ///   await storeTester.waitUntilAction(action);
  ///
  Future<TestInfo> waitUntilAction(
    ReduxAction<St> action, {
    int timeoutInSeconds = defaultTimeout,
  }) async {
    assert(action != null);

    TestInfo<St> testInfo;

    while (testInfo == null || testInfo.action != action || testInfo.isINI) {
      testInfo = await _next(timeoutInSeconds: timeoutInSeconds);
    }

    lastInfo = testInfo;

    return testInfo;
  }

  /// Runs until **all** given actions types are dispatched, **in order**.
  /// Waits until all of them are finished.
  /// Returns the info after all actions finish.
  /// Will fail with an exception if an unexpected action is seen,
  /// or if any of the expected actions are dispatched in the wrong order.
  ///
  /// If you pass action types to [ignore], they will be ignored (the test won't fail when
  /// encountering them, and won't collect testInfo for them). However, if an action type
  /// exists both in [actionTypes] and [ignore], it will be expected in that particular order,
  /// and the others of that type will be ignored. This method will remember all ignored actions
  /// and wait for them to finish, so that they don't "leak" to the next wait.
  ///
  /// If [ignore] is null, it will use the global ignore provided in the
  /// [StoreTester] constructor, if any. If [ignore] is an empty list, it
  /// will disable that global ignore.
  ///
  Future<TestInfo> waitAllGetLast(
    List<Type> actionTypes, {
    List<Type> ignore,
  }) async {
    assert(actionTypes != null && actionTypes.isNotEmpty);
    if (ignore == null) ignore = _ignore;

    var infoList = await waitAll(actionTypes, ignore: ignore);

    lastInfo = infoList.last;

    return infoList.last;
  }

  /// Runs until **all** given actions types are dispatched, in **any order**.
  /// Waits until all of them are finished. Returns the info after all actions finish.
  /// Will fail with an exception if an unexpected action is seen.
  ///
  /// If you pass action types to [ignore], they will be ignored (the test won't fail when
  /// encountering them, and won't collect testInfo for them). This method will remember all
  /// ignored actions and wait for them to finish, so that they don't "leak" to the next wait.
  /// An action type cannot exist in both [actionTypes] and [ignore] lists.
  ///
  Future<TestInfo> waitAllUnorderedGetLast(
    List<Type> actionTypes, {
    int timeoutInSeconds = defaultTimeout,
    List<Type> ignore,
  }) async =>
      (await waitAllUnordered(
        actionTypes,
        timeoutInSeconds: timeoutInSeconds,
        ignore: ignore,
      ))
          .last;

  /// The same as `waitAllGetLast`, but instead of returning just the last info,
  /// it returns a list with the end info for each action.
  ///
  /// If you pass action types to [ignore], they will be ignored (the test won't fail when
  /// encountering them, and won't collect testInfo for them). However, if an action type
  /// exists both in [actionTypes] and [ignore], it will be expected in that particular order,
  /// and the others of that type will be ignored. This method will remember all ignored actions
  /// and wait for them to finish, so that they don't "leak" to the next wait.
  ///
  /// If [ignore] is null, it will use the global ignore provided in the
  /// [StoreTester] constructor, if any. If [ignore] is an empty list, it
  /// will disable that global ignore.
  ///
  Future<TestInfoList<St>> waitAll(List<Type> actionTypes, {List<Type> ignore}) async {
    assert(actionTypes != null && actionTypes.isNotEmpty);
    if (ignore == null) ignore = _ignore;

    TestInfoList<St> infoList = TestInfoList<St>();

    // Waits the end of all actions, in any order.
    List<TestInfo<St>> endStates = [];

    // Saves obtained expected actions INI.
    // Note: This relies on Actions not overriding operator ==.
    List<ReduxAction> obtainedActions = [];

    // Saves ignored actions INI.
    // Note: This relies on Actions not overriding operator ==.
    List<ReduxAction> ignoredActions = [];

    TestInfo<St> testInfo;

    testInfo = await _next();

    for (int i = 0; i < actionTypes.length; i++) {
      var actionType = actionTypes[i];

      if (testInfo.isINI) {
        // Ignores actions.
        while (ignore.contains(testInfo.type) && (testInfo.type != actionType)) {
          if (testInfo.isINI)
            ignoredActions.add(testInfo.action);
          else
            ignoredActions.remove(testInfo.action);

          testInfo = await _next();
        }

        obtainedActions.add(testInfo.action);

        if (testInfo.type != actionType)
          throw StoreException(
              "Got this action: ${testInfo.type} ${testInfo.ini ? "INI" : "END"}.\n"
              "Was expecting: $actionType INI.");

        testInfo = await _next();
      }

      if (i < actionTypes.length - 1)
        while (testInfo.isEND) {
          var wasObtained = obtainedActions.remove(testInfo.action);
          var wasIgnored = ignoredActions.remove(testInfo.action);

          if (!wasObtained && !wasIgnored)
            throw StoreException("Got this unexpected action: ${testInfo.type} END.");

          if (wasObtained) endStates.add(testInfo);

          testInfo = await _next();
        }
    }

    while (obtainedActions.isNotEmpty || ignoredActions.isNotEmpty) {
      // Ignores actions.
      while (ignore.contains(testInfo.type) && (testInfo.isINI)) {
        ignoredActions.add(testInfo.action);
        testInfo = await _next();
      }

      var wasObtained = obtainedActions.remove(testInfo.action);
      var wasIgnored = ignoredActions.remove(testInfo.action);

      if (!testInfo.isEND || (!wasObtained && !wasIgnored))
        throw StoreException(
            "Got this unexpected action: ${testInfo.type} ${testInfo.ini ? "INI" : "END"}.\n\n"
            "obtainedIni:$obtainedActions\n"
            "ignoredIni:$ignoredActions\n"
            "");

      if (wasObtained) endStates.add(testInfo);

      if (obtainedActions.isNotEmpty || ignoredActions.isNotEmpty) testInfo = await _next();
    }

    for (TestInfo<St> testInfo in endStates) {
      infoList._add(testInfo);
    }

    lastInfo = infoList.last;

    return infoList;
  }

  /// The same as `waitAllUnorderedGetLast`, but instead of returning just the last info,
  /// it returns a list with the end info for each action.
  ///
  /// If you pass action types to [ignore], they will be ignored (the test won't fail when
  /// encountering them, and won't collect testInfo for them). This method will remember all
  /// ignored actions and wait for them to finish, so that they don't "leak" to the next wait.
  /// An action type cannot exist in both [actionTypes] and [ignore] lists.
  ///
  /// If [ignore] is null, it will use the global ignore provided in the
  /// [StoreTester] constructor, if any. If [ignore] is an empty list, it
  /// will disable that global ignore.
  ///
  Future<TestInfoList<St>> waitAllUnordered(
    List<Type> actionTypes, {
    int timeoutInSeconds = defaultTimeout,
    List<Type> ignore,
  }) async {
    assert(actionTypes != null && actionTypes.isNotEmpty);
    if (ignore == null) ignore = _ignore;

    // Actions which are expected can't also be ignored.
    var intersection = ignore.toSet().intersection(actionTypes.toSet());
    if (intersection.isNotEmpty)
      throw StoreException("Actions $intersection should not be expected and ignored.");

    TestInfoList<St> infoList = TestInfoList<St>();
    List<Type> actionsIni = List.from(actionTypes);
    List<Type> actionsEnd = List.from(actionTypes);

    TestInfo<St> testInfo;

    // Saves ignored actions INI.
    // Note: This relies on Actions not overriding operator ==.
    List<ReduxAction> ignoredActions = [];

    while (actionsIni.isNotEmpty || actionsEnd.isNotEmpty) {
      try {
        testInfo = await _next(timeoutInSeconds: timeoutInSeconds);

        while (ignore.contains(testInfo.type)) {
          //
          // Saves ignored actions.
          if (ignore.contains(testInfo.type)) {
            if (testInfo.isINI)
              ignoredActions.add(testInfo.action);
            else
              ignoredActions.remove(testInfo.action);
          }

          testInfo = await _next(timeoutInSeconds: timeoutInSeconds);
        }
      } on StoreExceptionTimeout catch (error) {
        error.addDetail("These actions were not dispatched: $actionsIni INI.");
        error.addDetail("These actions haven't finished: $actionsEnd END.");
        rethrow;
      }

      var action = testInfo.type;

      if (testInfo.isINI) {
        if (!actionsIni.remove(action))
          throw StoreException("Unexpected action was dispatched: $action INI.");
      } else {
        if (!actionsEnd.remove(action))
          throw StoreException("Unexpected action was dispatched: $action END.");

        // Only save the END states.
        infoList._add(testInfo);
      }
    }

    // Wait for all ignored actions to finish, so that they don't "leak" to the next wait.
    while (ignoredActions.isNotEmpty) {
      testInfo = await _next();

      var wasIgnored = ignoredActions.remove(testInfo.action);

      if (!wasIgnored && ignore.contains(testInfo.type)) {
        if (testInfo.isINI)
          ignoredActions.add(testInfo.action);
        else
          ignoredActions.remove(testInfo.action);
        continue;
      }

      if (!testInfo.isEND || !wasIgnored)
        throw StoreException(
            "Got this unexpected action: ${testInfo.type} ${testInfo.ini ? "INI" : "END"}.");
    }

    lastInfo = infoList.last;

    return infoList;
  }

  void _listen(TestInfoPrinter testInfoPrinter) {
    if (testInfoPrinter != null)
      _store.initTestInfoPrinter(testInfoPrinter);
    else if (_store.testInfoPrinter == null)
      _store.initTestInfoPrinter(testInfoPrinter ?? defaultTestInfoPrinter);

    _store.initTestInfoController();
    _subscription = _store.onReduce.listen(_completeFuture);
    _completer = Completer();
    _futures = Queue()..addLast(_completer.future);
  }

  Future<TestInfo<St>> _next({
    int timeoutInSeconds = defaultTimeout,
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
            onTimeout: () => throw StoreExceptionTimeout(),
          );
  }

  void _completeFuture(TestInfo<St> reduceInfo) {
    _completer.complete(reduceInfo);
    _completer = Completer();
    _futures.addLast(_completer.future);
  }

  Future cancel() async => await _subscription.cancel();
}

// /////////////////////////////////////////////////////////////////////////////

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
    return _info.firstWhere((info) => info.type == actionType, orElse: () => null);
  }

  /// Returns the n-th info corresponding to the end of the given action type
  /// Note: N == 1 is the first one.
  TestInfo<St> get(Type actionType, [int n = 1]) {
    assert(n != null);
    return _info.firstWhere((info) {
      var ifFound = (info.type == actionType);
      if (ifFound) n--;
      return ifFound && (n == 0);
    }, orElse: () => null);
  }

  /// Returns all info corresponding to the action type.
  List<TestInfo<St>> getAll(Type actionType) {
    return _info.where((info) => info.type == actionType).toList();
  }

  void forEach(void action(TestInfo<St> element)) => _info.forEach(action);

  TestInfo<St> firstWhere(bool test(TestInfo<St> element), {TestInfo<St> orElse()}) =>
      _info.firstWhere(test, orElse: orElse);

  TestInfo<St> lastWhere(bool test(TestInfo<St> element), {TestInfo<St> orElse()}) =>
      _info.lastWhere(test, orElse: orElse);

  TestInfo<St> singleWhere(bool test(TestInfo<St> element), {TestInfo<St> orElse()}) =>
      _info.singleWhere(test, orElse: orElse);

  Iterable<TestInfo<St>> where(bool test(TestInfo<St> element)) => _info.where(test);

  Iterable<T> map<T>(T f(TestInfo<St> element)) => _info.map(f);

  List<TestInfo<St>> toList({bool growable = true}) => _info.toList(growable: growable);

  Set<TestInfo<St>> toSet() => _info.toSet();

  bool get isEmpty => length == 0;

  bool get isNotEmpty => !isEmpty;

  void _add(TestInfo<St> info) => _info.add(info);
}

// /////////////////////////////////////////////////////////////////////////////

class StoreExceptionTimeout extends StoreException {
  StoreExceptionTimeout() : super("Timeout.");

  List<String> _details = <String>[];

  List<String> get details => _details;

  void addDetail(String detail) => _details.add(detail);

  @override
  String toString() =>
      (details.isEmpty) ? msg : msg + "\nDetails:\n" + details.map((d) => "- $d").join("\n");

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is StoreExceptionTimeout && runtimeType == other.runtimeType;

  @override
  int get hashCode => 0;
}

// /////////////////////////////////////////////////////////////////////////////

/// During tests, use this error observer if you want all errors to be thrown,
/// and not swallowed, including UserExceptions. You should probably use this
/// in all tests that you don't expect to throw any errors, including
/// UserExceptions.
///
/// On the contrary, when you are actually testing that some code throws
/// specific UserExceptions, you should NOT use this error observer, but
/// should instead let the UserExceptions go silently to the error queue
/// (the `errors` field in the store), and then assert that the queue
/// actually contains those errors.
///
class TestErrorObserver<St> implements ErrorObserver<St> {
  bool observe(Object error, ReduxAction<St> action, Store store) => true;
}

// /////////////////////////////////////////////////////////////////////////////
