import '../async_redux.dart';

// Developed by Marcelo Glasberg (Apr 2020).
// For more info, see: https://pub.dartlang.org/packages/async_redux

/// For this to work your store state must have a `Wait` field named `wait`,
/// and then:
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
  static final WaitReducer _defaultReducer = (state, operation, flag, ref) {
    try {
      return _copyReducer(state, operation, flag, ref);
    } on NoSuchMethodError catch (_) {
      try {
        return _builtValueReducer(state, operation, flag, ref);
      } on NoSuchMethodError catch (_) {
        try {
          return _freezedReducer(state, operation, flag, ref);
        } on NoSuchMethodError catch (_) {
          throw AssertionError("The store state is not compatible with WaitAction.");
        }
      }
    }
  };

  /// For this to work, your state class must have a [copy] method.
  static final WaitReducer _copyReducer = (state, operation, flag, ref) {
    Wait wait = (state as dynamic).wait ?? Wait();
    return (state as dynamic).copy(wait: wait.process(operation, flag: flag, ref: ref));
  };

  /// For this to work, your state class must have a suitable [rebuild] method.
  /// This happens automatically when you use the BuiltValue package.
  static final WaitReducer _builtValueReducer = (state, operation, flag, ref) {
    Wait wait = (state as dynamic).wait ?? Wait();
    return (state as dynamic)
        .rebuild((state) => state..wait = wait.process(operation, flag: flag, ref: ref));
  };

  /// For this to work, your state class must have a [copyWith] method.
  /// This happens automatically when you use the Freezed package.
  static final WaitReducer _freezedReducer = (state, operation, flag, ref) {
    Wait wait = (state as dynamic).wait ?? Wait();
    return (state as dynamic).copyWith(wait: wait.process(operation, flag: flag, ref: ref));
  };

  final WaitOperation operation;

  final Object flag, ref;

  /// [flag] and [ref] must be immutable objects.
  WaitAction.add(
    this.flag, {
    this.ref,
  }) : operation = WaitOperation.add;

  WaitAction.remove(
    this.flag, {
    this.ref,
  }) : operation = WaitOperation.remove;

  WaitAction.clear([
    this.flag,
  ])  : operation = WaitOperation.clear,
        ref = null;

  @override
  St reduce() => reducer(state, operation, flag, ref);
}

typedef WaitReducer<St> = St Function(
  St state,
  WaitOperation operation,
  Object flag,
  Object ref,
);
