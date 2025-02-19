// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// Based upon packages redux by Brian Egan, and flutter_redux by Brian Egan and John Ryan.
// Uses code from package equatable by Felix Angelov.
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

import 'dart:async';

import 'package:async_redux/async_redux.dart';

/// Creates a Redux store that lets you mock actions/reducers.
///
/// The MockStore lets you define mock actions/reducers for specific actions.
///
/// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux
///
class MockStore<St> extends Store<St> {
  MockStore({
    required St initialState,
    Object? environment,
    Map<Object?, Object?> props = const {},
    bool syncStream = false,
    TestInfoPrinter? testInfoPrinter,
    List<ActionObserver<St>>? actionObservers,
    List<StateObserver<St>>? stateObservers,
    Persistor<St>? persistor,
    Persistor<St>? cloudSync,
    ModelObserver? modelObserver,
    ErrorObserver<St>? errorObserver,
    WrapReduce<St>? wrapReduce,
    @Deprecated("Use `globalWrapError` instead. This will be removed.")
    WrapError<St>? wrapError,
    GlobalWrapError<St>? globalWrapError,
    bool? defaultDistinct,
    CompareBy? immutableCollectionEquality,
    int? maxErrorsQueued,
    this.mocks,
  }) : super(
          initialState: initialState,
          environment: environment,
          props: props,
          syncStream: syncStream,
          testInfoPrinter: testInfoPrinter,
          actionObservers: actionObservers,
          stateObservers: stateObservers,
          persistor: persistor,
          cloudSync: cloudSync,
          modelObserver: modelObserver,
          errorObserver: errorObserver,
          wrapReduce: wrapReduce,
          wrapError: wrapError,
          globalWrapError: globalWrapError,
          defaultDistinct: defaultDistinct,
          immutableCollectionEquality: immutableCollectionEquality,
          maxErrorsQueued: maxErrorsQueued,
        );

  /// 1) `null` to disable dispatching the action of a certain type.
  ///
  /// 2) A `MockAction<St>` instance to dispatch that action instead,
  /// and provide the original action as a getter to the mocked action.
  ///
  /// 3) A `ReduxAction<St>` instance to dispatch that mocked action instead.
  ///
  /// 4) `ReduxAction<St> Function(ReduxAction<St>)` to create a mock
  /// from the original action.
  ///
  /// 5) `St Function(ReduxAction<St>, St)` or
  /// `Future<St> Function(ReduxAction<St>, St)` to modify the state directly.
  ///
  Map<Type, dynamic>? mocks;

  MockStore<St> addMock(Type actionType, dynamic mock) {
    (mocks ??= {})[actionType] = mock;
    return this;
  }

  MockStore<St> addMocks(Map<Type, dynamic> mocks) {
    (this.mocks ??= {}).addAll(mocks);
    return this;
  }

  MockStore<St> clearMocks() {
    mocks = null;
    return this;
  }

  /// Dispatches the action, applying its reducer, and possibly changing the store state.
  /// The action may be sync or async.
  ///
  /// ```dart
  /// store.dispatch(MyAction());
  /// ```
  ///
  /// Method [dispatch] is of type [Dispatch].
  ///
  /// See also:
  /// - [dispatchSync] which dispatches sync actions, and throws if the action is async.
  /// - [dispatchAndWait] which dispatches both sync and async actions, and returns a Future.
  @override
  FutureOr<ActionStatus> dispatch(
    ReduxAction<St> action, {
    bool notify = true,
  }) {
    ReduxAction<St>? _action = _getMockedAction(action);

    return (_action == null) //
        ? Future.value(ActionStatus())
        : super.dispatch(_action, notify: notify);
  }

  @Deprecated("Use `dispatchAndWait` instead. This will be removed.")
  @override
  Future<ActionStatus> dispatchAsync(ReduxAction<St> action,
      {bool notify = true}) {
    return dispatchAndWait(action, notify: notify);
  }

  /// Dispatches the action, applying its reducer, and possibly changing the store state.
  /// The action may be sync or async. In both cases, it returns a [Future] that resolves when
  /// the action finishes.
  ///
  /// ```dart
  /// await store.dispatchAndWait(DoThisFirstAction());
  /// store.dispatch(DoThisSecondAction());
  /// ```
  ///
  /// Note: While the state change from the action's reducer will have been applied when the
  /// Future resolves, other independent processes that the action may have started may still
  /// be in progress.
  ///
  /// Method [dispatchAndWait] is of type [DispatchAndWait]. It returns `Future<ActionStatus>`,
  /// which means you can also get the final status of the action after you `await` it:
  ///
  /// ```dart
  /// var status = await store.dispatchAndWait(MyAction());
  /// ```
  ///
  /// See also:
  /// - [dispatch] which dispatches both sync and async actions.
  /// - [dispatchSync] which dispatches sync actions, and throws if the action is async.
  @override
  Future<ActionStatus> dispatchAndWait(ReduxAction<St> action,
      {bool notify = true}) {
    ReduxAction<St>? _action = _getMockedAction(action);

    return (_action == null) //
        ? Future.value(ActionStatus())
        : super.dispatchAndWait(_action, notify: notify);
  }

  /// Dispatches the action, applying its reducer, and possibly changing the store state.
  /// However, if the action is ASYNC, it will throw a [StoreException].
  ///
  /// Method [dispatchSync] is of type [DispatchSync].
  ///
  /// See also:
  /// - [dispatch] which dispatches both sync and async actions.
  /// - [dispatchAndWait] which dispatches both sync and async actions, and returns a Future.
  @override
  ActionStatus dispatchSync(ReduxAction<St> action, {bool notify = true}) {
    ReduxAction<St>? _action = _getMockedAction(action);

    return (_action == null) //
        ? ActionStatus()
        : super.dispatchSync(_action, notify: notify);
  }

  ReduxAction<St>? _getMockedAction(ReduxAction<St> action) {
    if (mocks == null || !mocks!.containsKey(action.runtimeType))
      return action;
    else {
      var mock = mocks![action.runtimeType];

      // 1) `null` to disable dispatching the action of a certain type.
      if (mock == null)
        return null;
      //
      // 2) A `MockAction<St>` instance to dispatch that action instead,
      // and provide the original action as a getter to the mocked action.
      else if (mock is MockAction<St>) {
        mock._setAction(action);
        return mock;
      }
      //
      // 3) A `ReduxAction<St>` instance to dispatch that mocked action instead.
      else if (mock is ReduxAction) {
        return mock as ReduxAction<St>;
      }
      //
      // 4) `ReduxAction<St> Function(ReduxAction<St>)` to create a mock
      // from the original action.
      else if (mock is ReduxAction<St> Function(ReduxAction<St>)) {
        ReduxAction<St> mockAction = mock(action);
        return mockAction;
      }
      //
      // 5) `St Function(ReduxAction<St>, St)` or
      // `Future<St> Function(ReduxAction<St>, St)` to modify the state directly.
      else if (mock is St Function(ReduxAction<St>, St)) {
        MockAction<St> mockAction = _GeneralActionSync(mock);
        mockAction._setAction(action);
        return mockAction;
      } else if (mock is Future<St> Function(ReduxAction<St>, St)) {
        MockAction<St> mockAction = _GeneralActionAsync(mock);
        mockAction._setAction(action);
        return mockAction;
      }
      //
      else
        throw StoreException("Action of type `${action.runtimeType}` "
            "can't be mocked by a mock of type "
            "`${mock.runtimeType}`.\n"
            "Valid mock types are:\n"
            "`null`\n"
            "`MockAction<St>`\n"
            "`ReduxAction<St>`\n"
            "`ReduxAction<St> Function(ReduxAction<St>)`\n"
            "`St Function(ReduxAction<St>, St)`\n");
    }
  }
}

abstract class MockAction<St> extends ReduxAction<St> {
  late ReduxAction<St> _action;

  ReduxAction<St> get action => _action;

  void _setAction(ReduxAction<St> action) {
    _action = action;
  }
}

class _GeneralActionSync<St> extends MockAction<St> {
  final St Function(ReduxAction<St> action, St state) _reducer;

  _GeneralActionSync(this._reducer);

  @override
  St reduce() => _reducer(action, state);
}

class _GeneralActionAsync<St> extends MockAction<St> {
  final Future<St> Function(ReduxAction<St> action, St state) _reducer;

  _GeneralActionAsync(this._reducer);

  @override
  Future<St> reduce() => _reducer(action, state);
}
