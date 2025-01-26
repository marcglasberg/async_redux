// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// Based upon packages redux by Brian Egan, and flutter_redux by Brian Egan and John Ryan.
// Uses code from package equatable by Felix Angelov.
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

import 'package:async_redux/async_redux.dart';

abstract class ActionObserver<St> {
  /// If `ini==true` this is right before the action is dispatched.
  /// If `ini==false` this is right after the action finishes.
  void observe(
    ReduxAction<St> action,
    int dispatchCount, {
    required bool ini,
  });
}

/// This action-observer will print all actions to the console, with color,
/// like so:
///
/// ```
/// I/flutter (15304): | Action MyAction
/// ```
///
/// This helps with development, so you probably don't want to use it in
/// release mode:
///
/// ```
/// store = Store<AppState>(
///    ...
///    actionObservers: kReleaseMode ? null : [ConsoleActionObserver()],
/// );
/// ```
///
/// If you implement the action's [toString], you can display more information.
/// For example, suppose a LoginAction which has a username field:
///
/// ```
/// class LoginAction extends ReduxAction {
///   final String username;
///   ...
///   String toString() => super.toString() + '(username)';
/// }
/// ```
///
/// The above code will print something like this:
///
/// ```
/// I/flutter (15304): | Action LoginAction(user32)
/// ```
///
class ConsoleActionObserver<St> extends ActionObserver<St> {
  @override
  void observe(ReduxAction<St> action, int dispatchCount, {required bool ini}) {
    if (ini) print('${color(action)}|$italic $action$reset');
  }

  /// Callback that chooses the color to print in the console.
  static String Function(ReduxAction action) color = //
      (ReduxAction action) => //
          (action is WaitAction || action is NavigateAction) //
              ? green
              : yellow;

  // See ANSI Colors here: https://pub.dev/packages/ansicolor
  static const white = "\x1B[38;5;255m";
  static const reversed = "\u001b[7m";
  static const red = "\x1B[38;5;9m";
  static const blue = "\x1B[38;5;45m";
  static const yellow = "\x1B[38;5;226m";
  static const green = "\x1B[38;5;118m";
  static const grey = "\x1B[38;5;246m";
  static const dark = "\x1B[38;5;238m";
  static const bold = "\u001b[1m";
  static const italic = "\u001b[3m";
  static const boldItalic = bold + italic;
  static const boldItalicOff = boldOff + italicOff;
  static const boldOff = "\u001b[22m";
  static const italicOff = "\u001b[23m";
  static const reset = "\u001b[0m";
}
