import 'dart:async';
import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Action;

import '../async_redux.dart';

// Developed by Marcelo Glasberg (Aug 2019).
// For more info, see: https://pub.dartlang.org/packages/async_redux

/// Predicate used in [StoreTester.waitCondition].
/// Return true to stop waiting, and get the last state.
typedef StateCondition<St, Environment> = bool Function(TestInfo<St, Environment> info);

/// Helps testing the store, actions, and sync/async reducers.
///
/// For more info, see: https://pub.dartlang.org/packages/async_redux
///
class StoreTester<St, Environment> {
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

  final Store<St, Environment> _store;
  final List<Type> _ignore;
  late StreamSubscription _subscription;
  late Completer<TestInfo<St, Environment>> _completer;
  late Queue<Future<TestInfo<St, Environment>>> _futures;

  Store<St, Environment> get store => _store;

  St get state => _store.state;

  Environment get environment => _store.environment;

  /// The last TestInfo read after some wait method.
  late TestInfo<St, Environment> lastInfo;

  /// The current TestInfo.
  TestInfo<St, Environment> get currentTestInfo => _currentTestInfo;
  late TestInfo<St, Environment> _currentTestInfo;

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
    required St initialState,
    required Environment environment,
    TestInfoPrinter? testInfoPrinter,
    List<Type>? ignore,
    bool syncStream = false,
    ErrorObserver? errorObserver,
    bool shouldThrowUserExceptions = false,
    Map<Type, dynamic>? mocks,
  }) : this.from(
            MockStore(
              initialState: initialState,
              environment: environment,
              syncStream: syncStream,
              errorObserver: errorObserver ?? //
                  (shouldThrowUserExceptions ? TestErrorObserver() : null),
              mocks: mocks,
            ),
            testInfoPrinter: testInfoPrinter,
            ignore: ignore);

  /// Create a StoreTester from a store that already exists.
  StoreTester.from(
    Store<St, Environment> store, {
    TestInfoPrinter? testInfoPrinter,
    List<Type>? ignore,
  })  : _ignore = ignore ?? const [],
        _store = store {
    if (testInfoPrinter != null)
      _store.initTestInfoPrinter(testInfoPrinter);
    else if (_store.testInfoPrinter == null) //
      _store.initTestInfoPrinter(defaultTestInfoPrinter);

    _listen();
    defaultNewStorePrinter();
  }

  /// Create a StoreTester from a store that already exists,
  /// but don't print anything to the console.
  StoreTester.simple(this._store) : _ignore = const [] {
    _listen();
  }

  Map<Type, dynamic>? get mocks => (store as MockStore).mocks;

  set mocks(Map<Type, dynamic>? _mocks) => (store as MockStore).mocks = _mocks;

  MockStore<St, Environment> addMock(Type actionType, dynamic mock) {
    (store as MockStore).addMock(actionType, mock);
    return store as MockStore<St, Environment>;
  }

  MockStore<St, Environment> addMocks(Map<Type, dynamic> mocks) {
    (store as MockStore).addMocks(mocks);
    return store as MockStore<St, Environment>;
  }

  MockStore<St, Environment> clearMocks() {
    (store as MockStore).clearMocks();
    return store as MockStore<St, Environment>;
  }

  FutureOr<ActionStatus> dispatch(ReduxAction<St, Environment> action, {bool notify = true}) =>
      store.dispatch(action, notify: notify);

  void defineState(St state) => _store.defineState(state);

  /// Dispatches an action that changes the current state to the one provided by you.
  /// Then, runs until that action is dispatched and finished (ignoring other actions).
  /// Returns the info after the action finishes, containing the given state.
  ///
  /// Example use:
  ///
  ///   var info = await storeTester.dispatchState(MyState(123));
  ///   expect(info.state, MyState(123));
  ///
  Future<TestInfo<St, Environment>> dispatchState(St state) async {
    var action = _NewStateAction<St, Environment>(state);
    dispatch(action);

    TestInfo<St, Environment>? testInfo;

    while (testInfo == null || !identical(testInfo.action, action) || testInfo.isINI) {
      testInfo = await _next();
    }

    lastInfo = testInfo;

    return testInfo;
  }

  /// Returns a mutable copy of the global ignore list.
  List<Type> get ignore => List.of(_ignore);

  /// Runs until the predicate function [condition] returns true.
  /// This function will receive each testInfo, from where it can
  /// access the state, action, errors etc.
  /// When [testImmediately] is true (the default), it will test the condition
  /// immediately when the method is called. If the condition is true, the
  /// method will return immediately, without waiting for any actions to be
  /// dispatched.
  /// When [testImmediately] is false, it will only test
  /// the condition once an action is dispatched.
  /// Only END states will be received, unless you pass [ignoreIni] as false.
  /// Returns the info after the condition is met.
  ///
  Future<TestInfo<St, Environment>> waitConditionGetLast(
    StateCondition<St, Environment> condition, {
    bool testImmediately = true,
    bool ignoreIni = true,
    int timeoutInSeconds = defaultTimeout,
  }) async {
    var infoList = await waitCondition(
      condition,
      testImmediately: testImmediately,
      ignoreIni: ignoreIni,
      timeoutInSeconds: timeoutInSeconds,
    );

    return infoList.last;
  }

  /// Runs until the predicate function [condition] returns true.
  /// This function will receive each testInfo, from where it can
  /// access the state, action, errors etc.
  /// When [testImmediately] is true (the default), it will test the condition
  /// immediately when the method is called. If the condition is true, the
  /// method will return immediately, without waiting for any actions to be
  /// dispatched.
  /// When [testImmediately] is false, it will only test
  /// the condition once an action is dispatched.
  /// Only END states will be received, unless you pass [ignoreIni] as false.
  /// Returns a list with all info until the condition is met.
  ///
  Future<TestInfoList<St, Environment>> waitCondition(
    StateCondition<St, Environment> condition, {
    bool testImmediately = true,
    bool ignoreIni = true,
    int? timeoutInSeconds = defaultTimeout,
  }) async {
    TestInfoList<St, Environment> infoList = TestInfoList<St, Environment>();

    if (testImmediately) {
      var currentTestInfoWithoutAction = TestInfo<St, Environment>(
        _currentTestInfo.state,
        _currentTestInfo.environment,
        false,
        null,
        null,
        null,
        _currentTestInfo.dispatchCount,
        _currentTestInfo.reduceCount,
        _currentTestInfo.errors,
      );
      if (condition(currentTestInfoWithoutAction)) {
        infoList._add(currentTestInfoWithoutAction);
        lastInfo = infoList.last;
        return infoList;
      }
    }

    TestInfo<St, Environment> testInfo = await _next(timeoutInSeconds: timeoutInSeconds);

    while (true) {
      if (ignoreIni)
        while (testInfo.ini)
          testInfo = await (_next(
            timeoutInSeconds: timeoutInSeconds,
          ));

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
  Future<TestInfo<St, Environment>> waitUntilErrorGetLast({
    Object? error,
    Object? processedError,
    int timeoutInSeconds = defaultTimeout,
  }) async {
    var infoList = await waitUntilError(
      error: error,
      processedError: processedError,
      timeoutInSeconds: timeoutInSeconds,
    );

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
  Future<TestInfoList<St, Environment>> waitUntilError({
    Object? error,
    Object? processedError,
    int timeoutInSeconds = defaultTimeout,
  }) async {
    assert(error != null || processedError != null);

    var condition = (TestInfo<St, Environment> info) =>
        (error == null ||
            (error is Type && info.error.runtimeType == error) ||
            (error is! Type && info.error == error)) &&
        (processedError == null ||
            (processedError is Type && //
                info.processedError.runtimeType == processedError) ||
            (processedError is! Type && //
                info.processedError == processedError));

    var infoList = await waitCondition(
      condition,
      ignoreIni: true,
      timeoutInSeconds: timeoutInSeconds,
    );

    lastInfo = infoList.last;

    return infoList;
  }

  /// Expects **one action** of the given type to be dispatched, and waits until it finishes.
  /// Returns the info after the action finishes.
  /// Will fail with an exception if an unexpected action is seen.
  Future<TestInfo<St, Environment>> wait(Type actionType) async => //
      waitAllGetLast([actionType]);

  /// Runs until an action of the given type is dispatched, and then waits until it finishes.
  /// Returns the info after the action finishes. **Ignores other** actions types.
  ///
  Future<TestInfo<St, Environment>> waitUntil(
    Type actionType, {
    int timeoutInSeconds = defaultTimeout,
  }) async {
    TestInfo<St, Environment>? testInfo;

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
  Future<TestInfo<St, Environment>> waitUntilAction(
    ReduxAction<St, Environment> action, {
    int timeoutInSeconds = defaultTimeout,
  }) async {
    TestInfo<St, Environment>? testInfo;

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
  Future<TestInfo<St, Environment>> waitAllGetLast(
    List<Type> actionTypes, {
    List<Type>? ignore,
  }) async {
    assert(actionTypes.isNotEmpty);
    ignore ??= _ignore;

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
  Future<TestInfo<St, Environment>> waitAllUnorderedGetLast(
    List<Type> actionTypes, {
    int timeoutInSeconds = defaultTimeout,
    List<Type>? ignore,
  }) async =>
      (await waitAllUnordered(
        actionTypes,
        timeoutInSeconds: timeoutInSeconds,
        ignore: ignore,
      ))
          .last;

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
  /// This method is the same as `waitAllGetLast`, but instead of returning
  /// just the last info, it returns a list with the end info for each action.
  ///
  Future<TestInfoList<St, Environment>> waitAll(
    List<Type> actionTypes, {
    List<Type>? ignore,
  }) async {
    assert(actionTypes.isNotEmpty);
    ignore ??= _ignore;

    TestInfoList<St, Environment> infoList = TestInfoList<St, Environment>();

    TestInfo<St, Environment>? testInfo;

    Queue<Type> expectedActionTypesINI = Queue.from(actionTypes);

    // These are for better error messages only.
    List<Type> obtainedIni = [];
    List<Type> ignoredIni = [];

    List<ReduxAction?> expectedActionsEND = [];
    List<ReduxAction?> expectedActionsENDIgnored = [];

    while (expectedActionTypesINI.isNotEmpty ||
        expectedActionsEND.isNotEmpty ||
        expectedActionsENDIgnored.isNotEmpty) {
      //
      testInfo = await _next();

      // Action INI must all exist, in order.
      if (testInfo.isINI) {
        //
        bool wasIgnored = ignore.contains(testInfo.type) &&
            (expectedActionTypesINI.isEmpty || //
                expectedActionTypesINI.first != testInfo.type);

        /// Record this action, so that later we can wait until it ends.
        if (wasIgnored) {
          expectedActionsENDIgnored.add(testInfo.action);
          ignoredIni.add(testInfo.type); // // For better error messages only.
        }
        //
        else {
          expectedActionsEND.add(testInfo.action);
          obtainedIni.add(testInfo.type); // For better error messages only.

          Type? expectedActionTypeINI = expectedActionTypesINI.isEmpty
              ? //
              null
              : expectedActionTypesINI.removeFirst();

          if (testInfo.type != expectedActionTypeINI)
            throw StoreException("Got this unexpected action: "
                "${testInfo.type} INI.\n"
                "Was expecting: $expectedActionTypeINI INI.\n"
                "obtainedIni: $obtainedIni\n"
                "ignoredIni: $ignoredIni");
        }
      }
      //
      // Action END must all exist, but the order doesn't matter.
      else {
        bool wasRemoved = expectedActionsEND.remove(testInfo.action);

        if (wasRemoved)
          infoList._add(testInfo);
        else
          wasRemoved = expectedActionsENDIgnored.remove(testInfo.action);

        if (!wasRemoved)
          throw StoreException("Got this unexpected action: "
              "${testInfo.type} END.\n"
              "obtainedIni: $obtainedIni\n"
              "ignoredIni: $ignoredIni");
      }
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
  Future<TestInfoList<St, Environment>> waitAllUnordered(
    List<Type> actionTypes, {
    int timeoutInSeconds = defaultTimeout,
    List<Type>? ignore,
  }) async {
    assert(actionTypes.isNotEmpty);
    ignore ??= _ignore;

    // Actions which are expected can't also be ignored.
    var intersection = ignore.toSet().intersection(actionTypes.toSet());
    if (intersection.isNotEmpty)
      throw StoreException("Actions $intersection "
          "should not be expected and ignored.");

    TestInfoList<St, Environment> infoList = TestInfoList<St, Environment>();
    List<Type> actionsIni = List.from(actionTypes);
    List<Type> actionsEnd = List.from(actionTypes);

    TestInfo<St, Environment>? testInfo;

    // Saves ignored actions INI.
    // Note: This relies on Actions not overriding operator ==.
    List<ReduxAction?> ignoredActions = [];

    while (actionsIni.isNotEmpty || actionsEnd.isNotEmpty) {
      try {
        testInfo = await _next(timeoutInSeconds: timeoutInSeconds);

        while (ignore.contains(testInfo!.type)) {
          //
          // Saves ignored actions.
          if (ignore.contains(testInfo.type)) {
            if (testInfo.isINI)
              ignoredActions.add(testInfo.action);
            else
              ignoredActions.remove(testInfo.action);
          }

          testInfo = await (_next(timeoutInSeconds: timeoutInSeconds));
        }
      } on StoreExceptionTimeout catch (error) {
        error.addDetail("These actions were not dispatched: "
            "$actionsIni INI.");
        error.addDetail("These actions haven't finished: "
            "$actionsEnd END.");
        rethrow;
      }

      var action = testInfo.type;

      if (testInfo.isINI) {
        if (!actionsIni.remove(action))
          throw StoreException("Unexpected action was dispatched: "
              "$action INI.");
      } else {
        if (!actionsEnd.remove(action))
          throw StoreException("Unexpected action was dispatched: "
              "$action END.");

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
        throw StoreException("Got this unexpected action: "
            "${testInfo.type} ${testInfo.ini ? "INI" : "END"}.");
    }

    lastInfo = infoList.last;

    return infoList;
  }

  void _listen() {
    _store.initTestInfoController();
    _subscription = _store.onReduce.listen(_completeFuture);
    _completer = Completer();
    _futures = Queue()..addLast(_completer.future);

    _currentTestInfo = TestInfo<St, Environment>(
      state,
      environment,
      false,
      null,
      null,
      null,
      store.dispatchCount,
      store.reduceCount,
      store.errors,
    );
  }

  Future<TestInfo<St, Environment>> _next({
    int? timeoutInSeconds = defaultTimeout,
  }) async {
    if (_futures.isEmpty) {
      _completer = Completer();
      _futures.addLast(_completer.future);
    }

    var result = _futures.removeFirst();

    _currentTestInfo = await ((timeoutInSeconds == null)
        ? result
        : result.timeout(
            Duration(seconds: timeoutInSeconds),
            onTimeout: (() => throw StoreExceptionTimeout()),
          ));

    return _currentTestInfo;
  }

  void _completeFuture(TestInfo<St, Environment> reduceInfo) {
    _completer.complete(reduceInfo);
    _completer = Completer();
    _futures.addLast(_completer.future);
  }

  Future cancel() async => await _subscription.cancel();
}

// /////////////////////////////////////////////////////////////////////////////

/// List of test information, before or after some actions are dispatched.
class TestInfoList<St, Environment> {
  final List<TestInfo<St, Environment>> _info = [];

  TestInfo<St, Environment> get last => _info.last;

  TestInfo<St, Environment> get first => _info.first;

  /// The number of dispatched actions.
  int get length => _info.length;

  /// Returns info corresponding to the end of the index-th dispatched action type.
  TestInfo<St, Environment> getIndex(int index) => _info[index];

  /// Returns the first info corresponding to the end of the given action type.
  TestInfo<St, Environment>? operator [](Type actionType) =>
      _info.firstWhereOrNull((info) => info.type == actionType);

  /// Returns the n-th info corresponding to the end of the given action type
  /// Note: N == 1 is the first one.
  TestInfo<St, Environment>? get(Type actionType, [int n = 1]) => _info.firstWhereOrNull((info) {
        var ifFound = (info.type == actionType);
        if (ifFound) n--;
        return ifFound && (n == 0);
      });

  /// Returns all info corresponding to the action type.
  List<TestInfo<St, Environment>> getAll(Type actionType) {
    return _info.where((info) => info.type == actionType).toList();
  }

  void forEach(void action(TestInfo<St, Environment> element)) => _info.forEach(action);

  TestInfo<St, Environment> firstWhere(
    bool test(TestInfo<St, Environment> element), {
    TestInfo<St, Environment> orElse()?,
  }) =>
      _info.firstWhere(test, orElse: orElse);

  TestInfo<St, Environment> lastWhere(
    bool test(TestInfo<St, Environment> element), {
    TestInfo<St, Environment> orElse()?,
  }) =>
      _info.lastWhere(test, orElse: orElse);

  TestInfo<St, Environment> singleWhere(
    bool test(TestInfo<St, Environment> element), {
    TestInfo<St, Environment> orElse()?,
  }) =>
      _info.singleWhere(test, orElse: orElse);

  Iterable<TestInfo<St, Environment>> where(
          bool test(
    TestInfo<St, Environment> element,
  )) =>
      _info.where(test);

  Iterable<T> map<T>(T f(TestInfo<St, Environment> element)) => _info.map(f);

  List<TestInfo<St, Environment>> toList({
    bool growable = true,
  }) =>
      _info.toList(growable: growable);

  Set<TestInfo<St, Environment>> toSet() => _info.toSet();

  bool get isEmpty => length == 0;

  bool get isNotEmpty => !isEmpty;

  void _add(TestInfo<St, Environment> info) => _info.add(info);
}

// /////////////////////////////////////////////////////////////////////////////

class StoreExceptionTimeout extends StoreException {
  StoreExceptionTimeout() : super("Timeout.");

  final List<String> _details = <String>[];

  List<String> get details => _details;

  void addDetail(String detail) => _details.add(detail);

  @override
  String toString() => (details.isEmpty)
      ? msg
      : //
      msg + "\nDetails:\n" + details.map((d) => "- $d").join("\n");

  @override
  bool operator ==(Object other) =>
      identical(this, other) || //
      other is StoreExceptionTimeout && runtimeType == other.runtimeType;

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
class TestErrorObserver<St, Environment> implements ErrorObserver<St, Environment> {
  @override
  bool observe(
    Object error,
    StackTrace stackTrace,
    ReduxAction<St, Environment> action,
    Store store,
  ) =>
      true;
}

// /////////////////////////////////////////////////////////////////////////////

class _NewStateAction<St, Environment> extends ReduxAction<St, Environment> {
  final St newState;

  _NewStateAction(this.newState);

  @override
  St reduce() => newState;
}

// /////////////////////////////////////////////////////////////////////////////
