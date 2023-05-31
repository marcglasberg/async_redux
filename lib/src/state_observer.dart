// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// Based upon packages redux by Brian Egan, and flutter_redux by Brian Egan and John Ryan.
// Uses code from package equatable by Felix Angelov.
// For more info, see: https://pub.dartlang.org/packages/async_redux

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
/// * stateIni = The state right before the new state returned by the reducer is applied. Note this
///              may be different from the state when the reducer was called.
///
/// * stateEnd = The state returned by the reducer. Note: If you need to know if the state was
///              changed or not by the reducer, you can compare both states:
///              `bool ifStateChanged = !identical(stateIni, stateEnd);`
///
/// * error = Is null if the reducer completed with no error and returned. Otherwise, will be the
///           error thrown by the reducer (before any wrapError is applied). Note that, in case of
///           error, both stateIni and stateEnd will be the current store state when the error is
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
///   void trackEvent(AppState stateIni, AppState stateEnd) { // Don't to anything }
/// }
///
/// class AppStateObserver implements StateObserver<AppState> {
///   @override
///   void observe(
///     ReduxAction<AppState> action,
///     AppState stateIni,
///     AppState stateEnd,
///     Object? error,
///     int dispatchCount,
///   ) {
///     if (action is AppAction) action.trackEvent(stateIni, stateEnd, error);
///   }
/// }
///
/// class MyAction extends AppAction {
///    @override
///    AppState? reduce() { // Do something }
///
///    @override
///    void trackEvent(AppState stateIni, AppState stateEnd, Object? error) =>
///       MyMetrics().track(this, stateEnd, error);
/// }
///
/// ```
///
abstract class StateObserver<St> {
  void observe(
    ReduxAction<St> action,
    St stateIni,
    St stateEnd,
    Object? error,
    int dispatchCount,
  );
}
