import 'dart:async';
import 'package:async_redux/async_redux.dart';

// Developed by Marcelo Glasberg (Aug 2019).
// For more info, see: https://pub.dartlang.org/packages/async_redux

// /////////////////////////////////////////////////////////////////////////////

/// Creates a Redux store that lets you mock actions/reducers.
///
/// The MockStore lets you define mock actions/reducers for specific actions.
///
/// For more info, see: https://pub.dartlang.org/packages/async_redux
///
class MockStore<St> extends Store<St> {
  MockStore({
    St initialState,
    bool syncStream = false,
    TestInfoPrinter testInfoPrinter,
    bool ifRecordsTestInfo,
    List<ActionObserver> actionObservers,
    List<StateObserver> stateObservers,
    Persistor persistor,
    ModelObserver modelObserver,
    ErrorObserver errorObserver,
    WrapError wrapError,
    bool defaultDistinct = true,
    this.mocks,
  }) : super(
          initialState: initialState,
          syncStream: syncStream,
          testInfoPrinter: testInfoPrinter,
          ifRecordsTestInfo: ifRecordsTestInfo,
          actionObservers: actionObservers,
          stateObservers: stateObservers,
          persistor: persistor,
          modelObserver: modelObserver,
          errorObserver: errorObserver,
          wrapError: wrapError,
          defaultDistinct: defaultDistinct,
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
  /// 5) `St Function(ReduxAction<St>, St)` to modify the state directly.
  ///
  Map<Type, dynamic> mocks;

  MockStore<St> addMock(Type actionType, dynamic mock) {
    mocks ??= {};
    mocks[actionType] = mock;
    return this;
  }

  MockStore<St> addMocks(Map<Type, dynamic> mocks) {
    this.mocks ??= {};
    this.mocks.addAll(mocks);
    return this;
  }

  MockStore<St> clearMocks() {
    mocks = null;
    return this;
  }

  @override
  void dispatch(ReduxAction<St> action, {bool notify = true}) {
    assert(action != null);
    action = _getMockedAction(action);
    if (action != null) super.dispatch(action, notify: notify);
  }

  @override
  Future<void> dispatchFuture(
    ReduxAction<St> action, {
    bool notify = true,
  }) async {
    assert(action != null);
    action = _getMockedAction(action);
    if (action != null) return super.dispatchFuture(action, notify: notify);
  }

  ReduxAction<St> _getMockedAction(ReduxAction<St> action) {
    if (mocks == null || !mocks.containsKey(action.runtimeType))
      return action;
    else {
      var mock = mocks[action.runtimeType];

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
        return mock;
      }
      //
      // 4) `ReduxAction<St> Function(ReduxAction<St>)` to create a mock
      // from the original action.
      else if (mock is ReduxAction<St> Function(ReduxAction<St>)) {
        ReduxAction<St> mockAction = mock(action);
        return mockAction;
      }
      //
      // 5) `St Function(ReduxAction<St>, St)` to modify the state directly.
      else if (mock is St Function(ReduxAction<St>, St)) {
        MockAction<St> mockAction = _GeneralAction(mock);
        mockAction._setAction(action);
        return mockAction;
      }
      //
      else
        throw StoreException("Action of type `${action.runtimeType}` "
            "can't be mocked by a mock of type "
            "`${(mock as Object).runtimeType}`.\n"
            "Valid mock types are:\n"
            "`null`\n"
            "`MockAction<St>`\n"
            "`ReduxAction<St>`\n"
            "`ReduxAction<St> Function(ReduxAction<St>)`\n"
            "`St Function(ReduxAction<St>, St)`\n");
    }
  }
}

// /////////////////////////////////////////////////////////////////////////////

abstract class MockAction<St> extends ReduxAction<St> {
  ReduxAction _action;

  ReduxAction get action => _action;

  void _setAction(ReduxAction action) {
    _action = action;
  }
}

// /////////////////////////////////////////////////////////////////////////////

class _GeneralAction<St> extends MockAction<St> {
  final St Function(ReduxAction<St> action, St state) _reducer;

  _GeneralAction(this._reducer);

  @override
  FutureOr<St> reduce() => _reducer(action, state);
}

// /////////////////////////////////////////////////////////////////////////////
