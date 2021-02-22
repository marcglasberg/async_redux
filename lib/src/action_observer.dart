import 'package:async_redux/async_redux.dart';

// Developed by Marcelo Glasberg (Aug 2019).
// Based upon packages redux by Brian Egan, and flutter_redux by Brian Egan and John Ryan.
// Uses code from package equatable by Felix Angelov.
// For more info, see: https://pub.dartlang.org/packages/async_redux

abstract class ActionObserver<St> {
  /// If `ini==true` this is right before the action is dispatched.
  /// If `ini==false` this is right after the action finishes.
  void observe(
    ReduxAction<St> action,
    int dispatchCount, {
    required bool ini,
  });
}
