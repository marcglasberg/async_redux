// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// Based upon packages redux by Brian Egan, and flutter_redux by Brian Egan and John Ryan.
// Uses code from package equatable by Felix Angelov.
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

import 'package:async_redux/async_redux.dart';

/// This wrapper will be given all errors thrown in your actions (including those of type
/// `UserException`). Then:
/// * If it returns the same [error] unaltered, this original error will be used.
/// * If it returns something else, that it will be used instead of the original [error].
/// * If it returns `null`, the original error will be disabled (swallowed).
///
/// IMPORTANT: If instead of RETURNING an error you THROW an error inside the `wrap` function,
/// AsyncRedux will catch this error and use it instead the original error. In other
/// words, returning an error or throwing an error has the same effect. However, it is still
/// recommended to return the error rather than throwing it.
///
/// Note this wrapper is called AFTER the action's [ReduxAction.wrapError],
/// and BEFORE the [ErrorObserver].
///
/// A common use case for this is to have a global place to convert some
/// exceptions into [UserException]s. For example, Firebase may throw some
/// `PlatformException`s in response to a bad connection to the server.
/// In this case, you may want to show the user a dialog explaining that the
/// connection is bad, which you can do by converting it to a [UserException].
/// Note, this could also be done in the [ReduxAction.wrapError], but then
/// you'd have to add it to all actions that use Firebase.
///
/// Another use case is when you want to throw the [UserException.cause]
/// which is not itself an [UserException], and you still want to show
/// the original [UserException] in a dialog to the user:
/// ```
/// Object wrap(Object error, [StackTrace stackTrace, ReduxAction<St> action]) {
///   if (error is UserException) {
///     var hardCause = error.hardCause();
///     if (hardCause != null) {
///       Future.microtask(() =>
///         Business.store.dispatch(UserExceptionAction.from(error.withoutHardCause())));
///       return hardCause;
///     }}
///   return null; }
/// ```
///
/// You should not use [GlobalWrapError] to log errors, as the preferred place for
/// doing that is in the [ErrorObserver].
///
abstract class GlobalWrapError<St> {
  Object? wrap(
    Object error,
    StackTrace stackTrace,
    ReduxAction<St> action,
  );
}

/// [WrapError] is deprecated in favor of [GlobalWrapError].
///
/// The reason for this deprecation is that the [GlobalWrapError] works in the
/// same way as the action's [ReduxAction.wrapError], while [WrapError] does not.
///
/// The difference is that when [WrapError] returns `null`, the original error is
/// not modified, while with [GlobalWrapError] returning `null` will disable the
/// error (just like [ReduxAction.wrapError] does).
///
/// In other words, where your old [WrapError] returned null, your new [GlobalWrapError]
/// should return the original error:
///
/// ```
/// // WrapError (deprecated):
/// Object? wrap(error, stackTrace, action) {
///    if (error is MyException) return null; // Keep the error unaltered.
///    else return processError(error); // May change the error, but not disable it.
/// }
///
/// // GlobalWrapError:
/// Object? wrap(error, stackTrace, action) {
///    if (error is MyException) return error; // Keep the error unaltered.
///    else return processError(error); // May change or disable the error.
/// }
/// ```
///
@Deprecated('Use GlobalWrapError instead. '
    'However, where WrapError returned `null`, GlobalWrapError should return the original error. '
    'Check the documentation for more details.')
abstract class WrapError<St> {
  //

  /// This method is deprecated in favor of [GlobalWrapError.wrap].
  ///
  /// The reason for this deprecation is that the [GlobalWrapError] works in the
  /// same way as the action's [ReduxAction.wrapError], while [WrapError] does not.
  ///
  /// The difference is that when [WrapError] returns `null`, the original error is
  /// not modified, while with [GlobalWrapError] returning `null` will instead
  /// disable the error.
  ///
  /// In other words, where your old [WrapError] returned `null`, your new [GlobalWrapError]
  /// should return the original `error`:
  ///
  /// ```
  /// // WrapError (deprecated):
  /// Object? wrap(error, stackTrace, action) {
  ///    if (error is MyException) return null; // Keep the error unaltered.
  ///    else return processError(error);
  /// }
  ///
  /// // GlobalWrapError:
  /// Object? wrap(error, stackTrace, action) {
  ///    if (error is MyException) return error; // Keep the error unaltered.
  ///    else return processError(error);
  /// }
  /// ```
  /// Also note, [GlobalWrapError] is more powerful because it can disable the error,
  /// whereas [WrapError] cannot.
  ///
  Object? wrap(
    Object error,
    StackTrace stackTrace,
    ReduxAction<St> action,
  );
}
