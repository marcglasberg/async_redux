// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// For more info, see: https://pub.dartlang.org/packages/async_redux

import 'package:flutter/cupertino.dart';

import '../async_redux.dart';

/// [WaitAction] and [Wait] work together to help you create boolean flags that
/// indicate some process is currently running. For this to work your store state
/// must have a `Wait` field named `wait`, and then:
///
/// 1) The state must have a `copy` or `copyWith` method that copies this
/// field as a named parameter. For example:
///
/// ```
/// class AppState {
///   final Wait wait;
///   AppState({this.wait});
///   AppState copy({Wait wait}) => AppState(wait: wait);
///   }
/// ```
///
/// OR:
///
/// 2) You must use the BuiltValue package https://pub.dev/packages/built_value,
/// which automatically creates a `rebuild` method.
///
/// OR:
///
/// 3) You must use the Freezed package https://pub.dev/packages/freezed,
/// which automatically creates the `copyWith` method.
///
/// OR:
///
/// 4) Inject your own [WaitReducer] implementation into [WaitAction]
/// by replacing the static variable [WaitAction.reducer] with a callback
/// that changes the wait object as you see fit.
///
/// OR:
///
/// 5) Don't use the [WaitAction], but instead create your own `MyWaitAction`
/// that uses the [Wait] object in whatever way you want.
///
class WaitAction<St> extends ReduxAction<St> {
  //

  /// Works out-of-the-box for most use cases, but you can inject your
  /// own reducer here during your app's initialization, if necessary.
  static WaitReducer reducer = _defaultReducer;

  /// The default is to choose a reducer that is compatible with your AppState class.
  static final WaitReducer _defaultReducer = (
    state,
    operation,
    flag,
    ref,
  ) {
    try {
      return _copyReducer(state, operation, flag, ref);
    } on NoSuchMethodError catch (_) {
      try {
        return _builtValueReducer(state, operation, flag, ref);
      } on NoSuchMethodError catch (_) {
        try {
          return _freezedReducer(state, operation, flag, ref);
        } on NoSuchMethodError catch (_) {
          throw AssertionError("The store state "
              "is not compatible with WaitAction.");
        }
      }
    }
  };

  /// For this to work, your state class must have a [copy] method.
  static final WaitReducer _copyReducer = (state, operation, flag, ref) {
    Wait wait = (state as dynamic).wait ?? Wait();
    return (state as dynamic).copy(
        wait: wait.process(
      operation,
      flag: flag,
      ref: ref,
    ));
  };

  /// For this to work, your state class must have a suitable [rebuild] method.
  /// This happens automatically when you use the BuiltValue package.
  static final WaitReducer _builtValueReducer = (state, operation, flag, ref) {
    Wait wait = (state as dynamic).wait ?? Wait();
    return (state as dynamic).rebuild((state) => state
      ..wait = wait.process(
        operation,
        flag: flag,
        ref: ref,
      ));
  };

  /// For this to work, your state class must have a [copyWith] method.
  /// This happens automatically when you use the Freezed package.
  static final WaitReducer _freezedReducer = (state, operation, flag, ref) {
    Wait wait = (state as dynamic).wait ?? Wait();
    return (state as dynamic).copyWith(
        wait: wait.process(
      operation,
      flag: flag,
      ref: ref,
    ));
  };

  final WaitOperation operation;

  final Object? flag, ref;
  final Duration? delay;

  /// Adds a [flag] that indicates some process is currently running.
  /// Optionally, you can also have a flag-reference called [ref].
  ///
  /// Note: [flag] and [ref] must be immutable objects.
  ///
  /// ```
  /// // Add a wait state, using this as the flag.
  /// dispatch(WaitAction.add(this));
  ///
  /// // Add a wait state, using this as the flag, and 123 as a reference.
  /// dispatch(WaitAction.add(this, ref: 123));
  /// ```
  /// Note: When the process finishes running, you will have to remove
  /// the [flag] by using the [remove] or [clear] methods.
  ///
  /// If you pass a [delay], the flag will be added only after that
  /// duration has passed, after the [add] method is called.
  ///
  WaitAction.add(
    this.flag, {
    this.ref,
    this.delay,
  }) : operation = WaitOperation.add;

  /// Removes a [flag] previously added with the [add] method.
  /// Removing the flag indicating some process finished running.
  ///
  /// If you added the flag with a reference [ref], you must also pass the
  /// same reference here to remove it. Alternatively, if you want to
  /// remove all references to that flag, use the [clear] method instead.
  ///
  /// ```
  /// // Add and remove a wait state, using this as the flag.
  /// dispatch(WaitAction.add(this));
  /// dispatch(WaitAction.remove(this));
  ///
  /// // Adds and remove a wait state, using this as the flag, and 123 as a reference.
  /// dispatch(WaitAction.add(this, ref: 123));
  /// dispatch(WaitAction.remove(this, ref: 123));
  /// ```
  ///
  /// If you pass a [delay], the flag will be removed only after that
  /// duration has passed, after the [add] method is called. Example:
  ///
  /// ```
  /// // Add a wait state that will be automatically removed after 3 seconds.
  /// dispatch(WaitAction.add(this));
  /// dispatch(WaitAction.remove(this, delay: Duration(seconds: 3)));
  /// ```
  ///
  WaitAction.remove(
    this.flag, {
    this.ref,
    this.delay,
  }) : operation = WaitOperation.remove;

  /// Clears (removes) the [flag], with all its references.
  /// Removing the flag indicating some process finished running.
  ///
  /// ```
  /// dispatch(WaitAction.add(this, flag: 123));
  /// dispatch(WaitAction.add(this, flag: "xyz"));
  /// dispatch(WaitAction.clear(this);
  /// ```
  WaitAction.clear([
    this.flag,
  ])  : operation = WaitOperation.clear,
        delay = null,
        ref = null;

  @override
  St? reduce() {
    if (delay == null)
      return reducer(state, operation, flag, ref);
    else {
      Future.delayed(delay!, () {
        reducer(state, operation, flag, ref);
      });
      return null;
    }
  }

  @override
  String toString() => 'WaitAction.${operation.name}('
      'flag: ${flag.toStringLimited()}, '
      'ref: ${ref.toStringLimited()})';
}

typedef WaitReducer<St> = St? Function(
  St? state,
  WaitOperation operation,
  Object? flag,
  Object? ref,
);

extension _StringExtension on Object? {
  /// If the object can be represented with up to 50 chars, we print it.
  /// Otherwise, we cut the text (using the Characters lib) and add an ellipsis.
  String toStringLimited() {
    String text = toString();
    return (text.length <= 50) ? text : "${Characters(text).take(49)}…";
  }
}
