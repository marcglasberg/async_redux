import 'package:async_redux/async_redux.dart';

// Developed by Marcelo Glasberg (Aug 2019).
// Based upon packages redux by Brian Egan, and flutter_redux by Brian Egan and John Ryan.
// Uses code from package equatable by Felix Angelov.
// For more info, see: https://pub.dartlang.org/packages/async_redux

/// You may globally wrap the reducer to allow for some pre or post-processing.
/// Note, if the action also have a wrapReduce method, this global wrapper
/// will be called AFTER (it will wrap the action's wrapper which wraps the
/// action's reducer).
abstract class WrapReduce<St> {
  Reducer<St?> wrapReduce(Reducer<St> reduce);
}
