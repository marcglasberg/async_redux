// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// Based upon packages redux by Brian Egan, and flutter_redux by Brian Egan and John Ryan.
// Uses code from package equatable by Felix Angelov.
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

import 'package:async_redux/async_redux.dart';

/// This is DEPRECATED. Use [GlobalErrorObserver] instead.
///
/// This will be given all errors thrown in your actions (including those of type
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
/// Another use case is when you want to throw the [AdvancedUserException.hardCause]
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
@Deprecated('Use GlobalErrorObserver instead. Check the documentation for more details.')
abstract class GlobalWrapError<St> {
  Object? wrap(
    Object error,
    StackTrace stackTrace,
    ReduxAction<St> action,
  );
}

/// A dummy global wrap error that does nothing.
@Deprecated('Use GlobalErrorObserver instead. This will be removed.')
class GlobalWrapErrorDummy<St> implements GlobalWrapError<St> {
  @override
  Object? wrap(error, stackTrace, action) => error;
}
