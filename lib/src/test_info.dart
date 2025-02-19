import 'dart:collection';

import 'package:async_redux/async_redux.dart';

typedef TestInfoPrinter = void Function(TestInfo);

class TestInfo<St> {
  final St state;
  final bool ini;
  final ReduxAction<St>? action;
  final int dispatchCount;
  final int reduceCount;

  /// List of all UserException's waiting to be displayed in the error dialog.
  Queue<UserException> errors;

  /// The error thrown by the action, if any,
  /// before being processed by the action's wrapError() method.
  final Object? error;

  /// The error thrown by the action,
  /// after being processed by the action's wrapError() method.
  final Object? processedError;

  bool get isINI => ini;

  bool get isEND => !ini;

  Type get type {
    // Removes the generic type from UserExceptionAction, WaitAction,
    // NavigateAction and PersistAction.
    // For example UserExceptionAction<AppState> becomes UserExceptionAction<dynamic>.
    if (action is UserExceptionAction) {
      if (action.runtimeType.toString().split('<')[0] ==
          'UserExceptionAction') //
        return UserExceptionAction;
    } else if (action is WaitAction) {
      if (action.runtimeType.toString().split('<')[0] == 'WaitAction') //
        return WaitAction;
    } else if (action is NavigateAction) {
      if (action.runtimeType.toString().split('<')[0] == 'NavigateAction') //
        return NavigateAction;
    } else if (action is PersistAction) {
      if (action.runtimeType.toString().split('<')[0] == 'PersistAction') //
        return PersistAction;
    }

    return action.runtimeType;
  }

  TestInfo(
    this.state,
    this.ini,
    this.action,
    this.error,
    this.processedError,
    this.dispatchCount,
    this.reduceCount,
    this.errors,
  ) : assert(state != null);

  @override
  String toString() => 'D:$dispatchCount '
      'R:$reduceCount '
      '= $action ${ini ? "INI" : "END"}\n';
}
