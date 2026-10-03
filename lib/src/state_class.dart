import 'package:meta/meta_meta.dart';

/// Annotation on a state class, like `AppState`, or on a class used inside the
/// state.
///
/// Indicates that the class, and all subtypes of it, must be immutable.
///
/// A class is immutable if all of the instance fields of the class, whether
/// defined directly or inherited, are `final`.
///
/// The `async_redux_lints` analyzer plugin reports a warning if a class that has
/// this annotation, or extends, implements or mixes in a class that has this
/// annotation, is not immutable.
///
/// See [stateClass].
@Target({TargetKind.classType, TargetKind.mixinType})
class StateClass {
  const StateClass();
}

/// Annotation on a state class, like `AppState`, or on a class used inside the
/// state:
///
/// ```dart
/// @stateClass
/// class AppState {
///   final int counter;
///   AppState({required this.counter});
/// }
/// ```
///
/// See [StateClass].
const StateClass stateClass = StateClass();
