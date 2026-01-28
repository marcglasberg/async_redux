// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// Based upon packages redux by Brian Egan, and flutter_redux by Brian Egan and John Ryan.
// Uses code from package equatable by Felix Angelov.
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

import 'dart:math';

import 'package:flutter/foundation.dart';

/// When the [Event] class was created, Flutter did not have any class named
/// `Event`. Now there is. For this reason, this typedef allows you to use Evt
/// instead. You can hide one of them, by importing AsyncRedux like this:
/// import 'package:async_redux/async_redux.dart' hide Event;
/// or
/// import 'package:async_redux/async_redux.dart' hide Evt;
typedef Evt<T> = Event<T>;

/// Events are one-time notifications stored in the Redux state, used to trigger
/// side effects in widgets such as showing dialogs, clearing text fields, or
/// navigating to new screens.
///
/// Unlike regular state values, events are automatically "consumed" (marked as
/// spent) after being read, ensuring they only trigger once.
///
/// ## Main Usage: The `event` Extension
///
/// The recommended way to use events is with the `context.event()` extension
/// method. First, define an extension in your code:
///
/// ```dart
/// extension BuildContextExtension on BuildContext {
///   R? event<R>(Evt<R> Function(AppState state) selector) => getEvent<AppState, R>(selector);
/// }
/// ```
///
/// **Example with a boolean (value-less) event:**
///
/// ```dart
/// // In your state
/// class AppState {
///   final Event clearTextEvt;
///   AppState({required this.clearTextEvt});
/// }
///
/// // In your action
/// class ClearTextAction extends ReduxAction<AppState> {
///   @override
///   AppState reduce() => state.copy(clearTextEvt: Event());
/// }
///
/// // In your widget
/// Widget build(BuildContext context) {
///   var clearText = context.event((state) => state.clearTextEvt);
///   if (clearText) controller.clear();
///   ...
/// }
/// ```
///
/// **Example with a typed event:**
///
/// ```dart
/// // In your state
/// class AppState {
///   final Event<String> changeTextEvt;
///   AppState({required this.changeTextEvt});
/// }
///
/// // In your action
/// class ChangeTextAction extends ReduxAction<AppState> {
///   @override
///   Future<AppState> reduce() async {
///     String newText = await fetchTextFromApi();
///     return state.copy(changeTextEvt: Event<String>(newText));
///   }
/// }
///
/// // In your widget
/// Widget build(BuildContext context) {
///   var newText = context.event((state) => state.changeTextEvt);
///   if (newText != null) controller.text = newText;
///   ...
/// }
/// ```
///
/// ## Return Values
///
/// - For events with **no generic type** (`Event`): `Event.consume()`
///   returns **true** if the event was dispatched, or **false** if it was
///   already spent.
///
/// - For events with **a value type** (`Event<T>`): `Event.consume()` returns
///   the **value** if the event was dispatched, or **null** if it was already
///   spent.
///
/// ## Alternative Usage: StoreConnector
///
/// Events can also be consumed when creating a `ViewModel` with the `StoreConnector`.
/// The event is "consumed" only once in the converter function, and is then
/// automatically considered "spent".
///
/// ## Important Notes
///
/// - Events are consumed only once. After consumption, they are marked as "spent".
/// - Each event can be consumed by **one single widget**.
/// - Always initialize events as spent: `Event.spent()` or `Event<T>.spent()`.
/// - The widget will rebuild when a new event is dispatched, even if it has the
///   same internal value as a previous event, because each event instance is
///   unique.
///
/// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux
///
/// Note: For `Event<bool>()` with no value provided, the value defaults to
/// `true` (not `null`), so that `consume()` returns `true` as expected.
///
class Event<T> {
  bool _spent;
  final T? _evtInfo;

  Event([T? evtInfo])
      : _evtInfo = (T == bool && evtInfo == null) ? (true as T) : evtInfo,
        _spent = false;

  Event.spent()
      : _evtInfo = null,
        _spent = true;

  bool get isSpent => _spent;

  bool get isNotSpent => !isSpent;

  /// Returns the event state and consumes the event.
  ///
  /// After consumption, the event is marked as spent and will not trigger again.
  ///
  /// - For events with no generic type (`Event`): Returns **true** if the event
  ///   was dispatched, or **false** if it was already spent.
  ///
  /// - For events with a value type (`Event<T>`): Returns the **value** if the
  ///   event was dispatched, or **null** if it was already spent.
  ///
  /// This method is called internally by `context.getEvent()`
  /// (or `context.event()`) so you usually will not use it directly.
  /// However, when using the dumb/smart widget pattern, you may use it inside
  /// a dumb widget (for example, when using a `StoreConnector`) when the event
  /// was passed as a constructor parameter by a smart widget.
  T? consume() {
    T? saveState = state;
    _spent = true;
    return saveState;
  }

  /// Returns the event state without consuming it.
  ///
  /// Unlike [consume], this method does not mark the event as spent, so the
  /// event can be read multiple times.
  ///
  /// This is useful in rare cases where you need to check the event value
  /// without consuming it, but most use cases should use [consume] via
  /// `context.getEvent()` (or `context.event()`).
  T? get state {
    if (T == dynamic && _evtInfo == null) {
      if (_spent)
        return (false as T);
      else {
        return (true as T);
      }
    } else {
      if (_spent)
        return null;
      else {
        return _evtInfo;
      }
    }
  }

  @override
  String toString() => 'Event('
      '${state.toString()}'
      '${_spent == true ? ', spent' : ''}'
      ')';

  /// Creates an event which is transformed by a function that usually needs
  /// the store state.
  ///
  /// You must provide the event and a map-function. The map-function must be
  /// able to deal with the spent state (null or false, accordingly).
  ///
  /// This is useful when you need to derive a new event value from an existing
  /// event, typically by looking up additional data from the state.
  ///
  /// **Example:** If `state.indexEvt = Event<int>(5)` and you need to get a
  /// user from it:
  ///
  /// ```dart
  /// var mapFunction = (int? index) => index == null ? null : state.users[index];
  /// Event<User> userEvt = Event.map(state.indexEvt, mapFunction);
  /// ```
  static Event<T> map<T, V>(Event<V> evt, T? Function(V?) mapFunction) =>
      MappedEvent<V, T>(evt, mapFunction);

  /// Creates an event which consumes from more than one event.
  ///
  /// If the first event is not spent, it will be consumed, and the second
  /// will not. If the first event is spent, the second one will be consumed.
  ///
  /// This is useful when you have multiple sources for the same event and want
  /// to consume from whichever one is available.
  ///
  /// **Note:** If both events are NOT spent, the method will have to be called
  /// twice to consume both. If both are spent, returns `null`.
  ///
  /// **Example:**
  /// ```dart
  /// Event<String> combinedEvt = Event.from(localMessageEvt, remoteMessageEvt);
  /// ```
  factory Event.from(Event<T> evt1, Event<T> evt2) => EventMultiple(evt1, evt2);

  /// Consumes from more than one event, prioritizing the first event.
  ///
  /// If the first event is not spent, it will be consumed, and the second will
  /// not. If the first event is spent, the second one will be consumed.
  ///
  /// This is useful when you have multiple sources for the same event and want
  /// to consume from whichever one is available.
  ///
  /// **Note:** If both events are NOT spent, the method will have to be called
  /// twice to consume both. If both are spent, returns null.
  ///
  /// **Example:**
  /// ```dart
  /// String? message = Event.consumeFrom(localMessageEvt, remoteMessageEvt);
  /// ```
  static T? consumeFrom<T>(Event<T> evt1, Event<T> evt2) {
    T? evt = evt1.consume();
    evt ??= evt2.consume();
    return evt;
  }

  /// Special equality implementation for events to ensure correct rebuild
  /// behavior.
  ///
  /// Events use a custom equality check where:
  /// - **Unspent events** are never considered equal to any other event,
  ///   ensuring widgets always rebuild when a new event is dispatched.
  /// - **Spent events** are all considered equal to each other, since they are
  ///   "empty" and should not trigger rebuilds.
  ///
  /// This behavior is essential for both the `context.event()` extension and
  /// `StoreConnector` usage patterns.
  ///
  /// ## For StoreConnector Users
  ///
  /// When using a [StoreConnector], you must implement equals and hashcode for
  /// your `ViewModel`. Events included in the ViewModel must follow these rules:
  ///
  /// 1) If the **new** ViewModel has an event which is **not spent**, then the
  /// ViewModel **MUST** be considered distinct, no matter the state of the
  /// **old** ViewModel, since the new event should fire.
  ///
  /// 2) If both the old and new ViewModels have events which **are spent**,
  /// then these events **MUST NOT** be considered distinct, since spent events
  /// are considered "empty" and should never fire.
  ///
  /// 3) If the **new** ViewModel has an event which is **not spent**, and
  /// the **old** ViewModel has an event which **is spent**, then the new event
  /// should fire, and for that reason they **MUST** be considered distinct.
  ///
  /// 4) If the **new** ViewModel has an event which is **is spent**, and
  /// the **old** ViewModel has an event which **not spent**, then the new event
  /// should NOT fire, and for that reason they **SHOULD NOT** be considered
  /// distinct.
  ///
  /// **Note:** To differentiate cases 3 and 4 we would actually be breaking
  /// the equals contract (which says A==B should be the same as B==A). A safer
  /// alternative is to always consider events different if any of them is not
  /// spent. That will, however, fire some unnecessary rebuilds.
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Event &&
            runtimeType == other.runtimeType

            /// 1) Events not spent are never considered equal to any other,
            /// and they will always "fire", forcing the widget to rebuild.
            /// 2) Spent events are considered "empty", so they are all equal.
            &&
            (isSpent && other.isSpent);
  }

  /// 1) If two objects are equal according to the equals method, then hashcode
  /// of both must be the same. Since spent events are all equal, they should
  /// produce the same hashcode.
  /// 2) If two objects are NOT equal, hashcode may be the same or not, but it's
  /// better when they are not the same. However, events are mutable, and this
  /// could mean the hashcode of the state could be changed when an event is
  /// consumed. To avoid this, we make events always return the same hashCode.
  @override
  int get hashCode => 0;
}

/// An event that combines multiple sub-events, consuming them in priority order.
///
/// When consuming this event:
/// - If the first sub-event is not spent, it will be consumed, and the second
///   will not.
/// - If the first sub-event is spent, the second one will be consumed.
///
/// This is useful when you have multiple sources for the same event and want
/// to consume from whichever one is available.
///
/// **Note:** If both sub-events are NOT spent, the multiple-event will have to
/// be consumed twice to consume both sub-events. If both sub-events are spent,
/// returns null when consumed.
///
/// **Example:**
/// ```dart
/// Event<String> combinedEvt = EventMultiple(localMessageEvt, remoteMessageEvt);
/// ```
class EventMultiple<T> extends Event<T> {
  Event<T> evt1;
  Event<T> evt2;

  EventMultiple(Event? evt1, Event? evt2)
      : evt1 = evt1 as Event<T>? ?? Event<T>.spent(),
        evt2 = evt2 as Event<T>? ?? Event<T>.spent();

  // Is spent only if both are spent.
  @override
  bool get isSpent => evt1.isSpent && evt2.isSpent;

  /// Returns the event state and consumes the event.
  ///
  /// Consumes the first non-spent event. If the first event is not spent, it
  /// will be consumed and returned. Otherwise, the second event will be
  /// consumed and returned.
  @override
  T? consume() {
    return Event.consumeFrom(evt1, evt2);
  }

  /// Returns the event state without consuming it.
  ///
  /// Returns the state of the first non-spent event without consuming either event.
  @override
  T? get state {
    T? st = evt1.state;
    st ??= evt2.state;
    return st;
  }
}

/// An event whose value is transformed by a mapping function.
///
/// This is useful when your event value must be transformed by a function that
/// usually needs the store state. You must provide the event and a map-function.
/// The map-function must be able to deal with the spent state (null or false,
/// accordingly).
///
/// This is commonly used when you need to derive a new event value from an
/// existing event, typically by looking up additional data from the state.
///
/// **Example:** If `state.indexEvt = Event<int>(5)` and you need to get a user
/// from it:
///
/// ```dart
/// var mapFunction = (int? index) => index == null ? null : state.users[index];
/// Event<User> userEvt = MappedEvent<int, User>(state.indexEvt, mapFunction);
/// ```
class MappedEvent<V, T> extends Event<T> {
  Event<V> evt;
  T? Function(V?) mapFunction;

  MappedEvent(Event<V>? evt, this.mapFunction) : evt = evt ?? Event<V>.spent();

  @override
  bool get isSpent => evt.isSpent;

  /// Returns the transformed event state and consumes the underlying event.
  @override
  T? consume() => mapFunction(evt.consume());

  /// Returns the transformed event state without consuming it.
  @override
  T? get state => mapFunction(evt.state);
}

/// An event-like class that generates a "pulse" to trigger widget updates,
/// but is NEVER CONSUMED.
///
/// Unlike [Event] which is consumed after being read, [EvtState] can be used
/// with multiple widgets and will trigger rebuilds each time a new instance is
/// created.
///
/// Each [EvtState] instance is unique, even if created with the same value:
///
/// ```dart
/// print(EvtState() == EvtState()); // false
/// print(EvtState<String>('abc') == EvtState<String>('abc')); // false
/// ```
///
/// **Usage with stateful widgets:**
///
/// When a new [EvtState] is created in the state, it will trigger a widget
/// rebuild. Then, the `didUpdateWidget` method will be called. Since `evt`
/// is now different from `oldWidget.evt`, it will run your side effect:
///
/// ```dart
/// @override
/// void didUpdateWidget(MyWidget oldWidget) {
///   super.didUpdateWidget(oldWidget);
///
///   if (evt != oldWidget.evt) doSomethingWith(evt.value);
/// }
/// ```
///
/// **Key difference from Event:**
///
/// The [EvtState] class is never "consumed" (like the [Event] class is), which
/// means you can use it with more than one widget. Use [EvtState] when you need
/// multiple widgets to react to the same trigger. Use [Event] when you need
/// one-time consumption by a single widget.
///
/// Note: For `Evt<bool>()` with no value provided, the value defaults to
/// `true` (not `null`), so that `consume()` returns `true` as expected.
///
@immutable
class EvtState<T> {
  static final _random = Random.secure();

  final T? value;
  final int _rand;

  EvtState([this.value]) : _rand = _random.nextInt(1 << 32);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EvtState &&
          runtimeType == other.runtimeType &&
          value == other.value &&
          _rand == other._rand;

  @override
  int get hashCode => value.hashCode ^ _rand.hashCode;
}
