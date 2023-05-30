// Developed by Marcelo Glasberg (Aug 2019).
// Based upon packages redux by Brian Egan, and flutter_redux by Brian Egan and John Ryan.
// Uses code from package equatable by Felix Angelov.
// For more info, see: https://pub.dartlang.org/packages/async_redux

import 'package:async_redux/async_redux.dart';

/// This wrapper will be given all errors (including of type UserException).
/// * If it returns something, it will be used instead of the
///   original exception.
/// * Otherwise, just return null, so that the original exception will
///   not be modified.
///
/// Note this wrapper is called AFTER [ReduxAction.wrapError],
/// and BEFORE the [ErrorObserver].
///
/// A common use case for this is to have a global place to convert some
/// exceptions into [UserException]s. For example, Firebase may throw some
/// PlatformExceptions in response to a bad connection to the server.
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
abstract class WrapError<St> {
  Object? wrap(
    Object error,
    StackTrace stackTrace,
    ReduxAction<St> action,
  );
}
