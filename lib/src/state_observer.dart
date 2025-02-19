// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// Based upon packages redux by Brian Egan, and flutter_redux by Brian Egan and John Ryan.
// Uses code from package equatable by Felix Angelov.
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

import 'package:async_redux/async_redux.dart';

/// One or more [StateObserver]s can be set during the [Store] creation. Those observers are
/// called for all dispatched actions, right after the reducer returns. That happens before the
/// `after()` method is called, and before the action's `wrapError()` and the global `wrapError()`
/// methods are called.
///
/// The parameters are:
///
/// * action = The action itself.
///
/// * prevState = The state right before the new state returned by the reducer is applied.
///               Note this may be different from the state when the reducer was called.
///
/// * newState = The state returned by the reducer. Note: If you need to know if the state was
///            changed or not by the reducer, you can compare both states:
///            `bool ifStateChanged = !identical(prevState, newState);`
///
/// * error = Is null if the reducer completed with no error and returned. Otherwise, will be the
///           error thrown by the reducer (before any wrapError is applied). Note that, in case of
///           error, both prevState and newState will be the current store state when the error was
///           thrown.
///
/// * dispatchCount = The sequential number of the dispatch.
///
/// <br>
///
/// Among other uses, the state-observer is a good place to add METRICS to your application.
/// For example:
///
/// ```
/// abstract class AppAction extends ReduxAction<AppState> {
///   void trackEvent(AppState prevState, AppState newState) { // Don't to anything }
/// }
///
/// class AppStateObserver implements StateObserver<AppState> {
///   @override
///   void observe(
///     ReduxAction<AppState> action,
///     AppState prevState,
///     AppState newState,
///     Object? error,
///     int dispatchCount,
///   ) {
///     if (action is AppAction) action.trackEvent(prevState, newState, error);
///   }
/// }
///
/// class MyAction extends AppAction {
///    @override
///    AppState? reduce() { // Do something }
///
///    @override
///    void trackEvent(AppState prevState, AppState newState, Object? error) =>
///       MyMetrics().track(this, newState, error);
/// }
///
/// ```
///
abstract class StateObserver<St> {
  /// * [action] = The action itself.
  ///
  /// * [prevState] = The state right before the new state returned by the reducer is applied.
  ///               Note this may be different from the state when the reducer was called.
  ///
  /// * [newState] = The state returned by the reducer. Note: If you need to know if the state was
  ///              changed or not by the reducer, you can compare both states:
  ///              `bool ifStateChanged = !identical(prevState, newState);`
  ///
  /// * [error] = Is null if the reducer completed with no error and returned. Otherwise, will be the
  ///           error thrown by the reducer (before any wrapError is applied). Note that, in case of
  ///           error, both prevState and newState will be the current store state when the error
  ///           was thrown.
  ///
  /// * [dispatchCount] = The sequential number of the dispatch.
  ///
  void observe(
    ReduxAction<St> action,
    St prevState,
    St newState,
    Object? error,
    int dispatchCount,
  );
}
