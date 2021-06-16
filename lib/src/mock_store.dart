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
class MockStore<St, Environment> extends Store<St, Environment> {
  MockStore({
    required St initialState,
    required Environment environment,
    bool syncStream = false,
    TestInfoPrinter? testInfoPrinter,
    List<ActionObserver>? actionObservers,
    List<StateObserver>? stateObservers,
    Persistor? persistor,
    ModelObserver? modelObserver,
    ErrorObserver? errorObserver,
    WrapError? wrapError,
    bool defaultDistinct = true,
    this.mocks,
  }) : super(
          initialState: initialState,
          environment: environment,
          syncStream: syncStream,
          testInfoPrinter: testInfoPrinter,
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
  /// 5) `St Function(ReduxAction<St>, St)` or
  /// `Future<St> Function(ReduxAction<St>, St)` to modify the state directly.
  ///
  Map<Type, dynamic>? mocks;

  MockStore<St, Environment> addMock(Type actionType, dynamic mock) {
    (mocks ??= {})[actionType] = mock;
    return this;
  }

  MockStore<St, Environment> addMocks(Map<Type, dynamic> mocks) {
    (this.mocks ??= {}).addAll(mocks);
    return this;
  }

  MockStore<St, Environment> clearMocks() {
    mocks = null;
    return this;
  }

  @override
  Future<ActionStatus> dispatch(
    ReduxAction<St, Environment> action, {
    bool notify = true,
  }) {
    ReduxAction<St, Environment>? _action = _getMockedAction(action);

    if (_action == null)
      return Future.value(ActionStatus());
    else
      return super.dispatch(_action, notify: notify);
  }

  ReduxAction<St, Environment>? _getMockedAction(ReduxAction<St, Environment> action) {
    if (mocks == null || !mocks!.containsKey(action.runtimeType))
      return action;
    else {
      var mock = mocks![action.runtimeType];

      // 1) `null` to disable dispatching the action of a certain type.
      if (mock == null)
        return null;
      //
      // 2) A `MockAction<St, Environment>` instance to dispatch that action instead,
      // and provide the original action as a getter to the mocked action.
      else if (mock is MockAction<St, Environment>) {
        mock._setAction(action);
        return mock;
      }
      //
      // 3) A `ReduxAction<St, Environment>` instance to dispatch that mocked action instead.
      else if (mock is ReduxAction) {
        return mock as ReduxAction<St, Environment>;
      }
      //
      // 4) `ReduxAction<St> Function(ReduxAction<St, Environment>)` to create a mock
      // from the original action.
      else if (mock is ReduxAction<St, Environment> Function(ReduxAction<St, Environment>)) {
        ReduxAction<St, Environment> mockAction = mock(action);
        return mockAction;
      }
      //
      // 5) `St Function(ReduxAction<St>, St)` or
      // `Future<St> Function(ReduxAction<St>, St)` to modify the state directly.
      else if (mock is St Function(ReduxAction<St, Environment>, St)) {
        MockAction<St, Environment> mockAction = _GeneralActionSync(mock);
        mockAction._setAction(action);
        return mockAction;
      } else if (mock is Future<St> Function(ReduxAction<St, Environment>, St, Environment)) {
        MockAction<St, Environment> mockAction = _GeneralActionAsync(mock);
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
            "`MockAction<St, Environment>`\n"
            "`ReduxAction<St, Environment>`\n"
            "`ReduxAction<St, Environment> Function(ReduxAction<St, Environment>)`\n"
            "`St Function(ReduxAction<St, Environment>, St)`\n");
    }
  }
}

// /////////////////////////////////////////////////////////////////////////////

abstract class MockAction<St, Environment> extends ReduxAction<St, Environment> {
  late ReduxAction<St, Environment> _action;

  ReduxAction<St, Environment> get action => _action;

  void _setAction(ReduxAction<St, Environment> action) {
    _action = action;
  }
}

// /////////////////////////////////////////////////////////////////////////////

class _GeneralActionSync<St, Environment> extends MockAction<St, Environment> {
  final St Function(ReduxAction<St, Environment> action, St state) _reducer;

  _GeneralActionSync(this._reducer);

  @override
  St reduce() => _reducer(action, state);
}

// /////////////////////////////////////////////////////////////////////////////

class _GeneralActionAsync<St, Environment> extends MockAction<St, Environment> {
  final Future<St> Function(ReduxAction<St, Environment> action, St state, Environment environment) _reducer;

  _GeneralActionAsync(this._reducer);

  @override
  Future<St> reduce() => _reducer(action, state, environment);
}

// /////////////////////////////////////////////////////////////////////////////
