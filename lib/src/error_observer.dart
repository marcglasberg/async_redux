import 'package:async_redux/async_redux.dart';

// Developed by Marcelo Glasberg (Aug 2019).
// Based upon packages redux by Brian Egan, and flutter_redux by Brian Egan and John Ryan.
// Uses code from package equatable by Felix Angelov.
// For more info, see: https://pub.dartlang.org/packages/async_redux

// /////////////////////////////////////////////////////////////////////////////

/// This will be given all errors, including those of type [UserException].
/// Return true to throw the error. False to swallow it.
///
/// Don't use the store to dispatch any actions, as this may have
/// unpredictable results.
///
abstract class ErrorObserver<St> {
  bool observe(
    Object error,
    StackTrace stackTrace,
    ReduxAction<St> action,
    Store<St> store,
  );
}

// /////////////////////////////////////////////////////////////////////////////

/// During development, use this error observer if you want all errors to be
/// shown to the user in a dialog, not only [UserException]s. In more detail:
/// This will wrap all errors into [UserException]s, and put them all into the
/// error queue. Note that errors which are NOT originally [UserException]s will
/// still be thrown, while [UserException]s will still be swallowed.
///
/// Passe it to the store like this:
///
/// `var store = Store(errorObserver:DevelopmentErrorObserver());`
///
class DevelopmentErrorObserver<St> implements ErrorObserver<St> {
  @override
  bool observe(
    Object error,
    StackTrace stackTrace,
    ReduxAction<St> action,
    Store store,
  ) {
    if (error is UserException)
      return false;
    else {
      // We have to dispatch another action, since we cannot do:
      // store._addError(errorAsUserException);
      // store._changeController.add(store.state);
      Future.microtask(() => store.dispatch(
            UserExceptionAction(error.toString(), cause: error),
          ));
      return true;
    }
  }
}

// /////////////////////////////////////////////////////////////////////////////

/// Swallows all errors (not recommended). Passe it to the store like this:
///
/// `var store = Store(errorObserver:SwallowErrorObserver());`
///
class SwallowErrorObserver<St> implements ErrorObserver<St> {
  @override
  bool observe(
    Object error,
    StackTrace stackTrace,
    ReduxAction<St> action,
    Store store,
  ) {
    return false;
  }
}

// /////////////////////////////////////////////////////////////////////////////
