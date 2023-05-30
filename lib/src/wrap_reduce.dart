// Developed by Marcelo Glasberg (Aug 2019).
// Based upon packages redux by Brian Egan, and flutter_redux by Brian Egan and John Ryan.
// Uses code from package equatable by Felix Angelov.
// For more info, see: https://pub.dartlang.org/packages/async_redux

import 'package:async_redux/async_redux.dart';

/// You may globally wrap the reducer to allow for some pre or post-processing.
/// Note: if the action also have a [ReduxAction.wrapReduce] method, this global
/// wrapper will be called AFTER (it will wrap the action's wrapper which wraps
/// the action's reducer).
///
/// If [ifShouldProcess] is overridden to return `false`, the wrapper will
/// be turned of.
///
/// The [process] method gets the old-state and the new-state, and returns
/// the end state that you want to send to the store. Note: In sync reducers,
/// the old-state is the state before the reducer is called. However, in
/// async reducers, the old-state is the state AFTER the reducer returns
/// but before the reducer's result is committed to the store.
///
/// For example, this wrapper checks if `newState.someInfo` is out of range,
/// and if that's the case it's logged and changed to some valid value:
///
/// ```
/// class MyWrapReduce extends WrapReduce<AppState> {
///   St process({required St oldState, required St newState}) {
///     if (identical(newState.someInfo, oldState.someInfo) || oldState.someInfo.isWithRange())
///     return newState;
///     else {
///       Logger.log('Invalid value: ${oldState.someInfo}');
///       return newState.copy(someInfo: newState.someInfo.copy(SomeInfo(validValue)));
///       }}}
/// ```
///
/// Note the [wrapReduce] method encapsulates the complexities of
/// differentiating sync and async reducers. However, you can override it
/// to provide your own implementation if necessary.
///
abstract class WrapReduce<St> {
  //
  bool ifShouldProcess() => true;

  St process({
    required St oldState,
    required St newState,
  });

  Reducer<St> wrapReduce(
    Reducer<St> reduce,
    Store<St> store,
  ) {
    //
    if (!ifShouldProcess())
      return reduce;
    //
    // 1) Sync reducer.
    else {
      if (reduce is St? Function()) {
        return () {
          //
          // The is the state right before calling the sync reducer.
          St oldState = store.state;

          // This is the state returned by the reducer.
          St? newState = reduce();

          // If the reducer returned null, or returned the same instance, don't do anything.
          if (newState == null || identical(store.state, newState)) return newState;

          return process(oldState: oldState, newState: newState);
        };
      }
      //
      // 2) Async reducer.
      else if (reduce is Future<St?> Function()) {
        return () async {
          //
          // The is the state returned by the reducer.
          St? newState = await reduce();

          // This is the state right after the reducer returns,
          // but before it's committed to the store.
          St oldState = store.state;

          // If the reducer returned null, or returned the same instance, don't do anything.
          if (newState == null || identical(store.state, newState)) return newState;

          return process(oldState: oldState, newState: newState);
        };
      }
      // Not defined.
      else {
        throw StoreException("Reducer should return `St?` or `Future<St?>`. "
            "Do not return `FutureOr<St?>`. "
            "Reduce is of type: '${reduce.runtimeType}'.");
      }
    }
  }
}
