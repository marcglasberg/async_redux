// Developed by Marcelo Glasberg (Aug 2019).
// For more info, see: https://pub.dartlang.org/packages/async_redux

/// When the [Event] class was created, Flutter did not have any class named `Event`.
/// Now there is. For this reason, this typedef allows you to use Evt instead.
/// You can hide one of them, by importing AsyncRedux like this:
/// import 'package:async_redux/async_redux.dart' hide Event;
/// or
/// import 'package:async_redux/async_redux.dart' hide Evt;
typedef Evt<T> = Event<T>;

/// The `Event` class can be used as a Redux state with *flutter_redux* , usually to change the
/// internal state of a stateful widget. When creating the `ViewModel` with the `StoreConnector`,
/// the event is "consumed" only once, and is then automatically considered "spent".
///
/// Note that since the event is spent when consumed, it can be consumed by **one single** widget.
///
/// If the event **HAS NO VALUE AND NO GENERIC TYPE**,
/// then `Event.consume()` returns **true** if the event was dispatched,
/// or **false** otherwise.
///
/// ```
/// class AppState { final Event buttonEvt; }
///
/// AppState({Event buttonEvt}) : buttonEvt = buttonEvt ?? Event.spent();
///
/// Event buttonEvt_Reducer(Event buttonEvt, dynamic action) {
///    if (action is Increment_Action) {
///    buttonEvt = Event();
///    return buttonEvt; }
/// ```
///
/// If the event **HAS VALUE OR SOME GENERIC TYPE**,
/// then `Event.consume()` returns the **value** if the event was dispatched,
/// or **null** otherwise.
///
/// ```
/// class AppState { final Event<int> buttonEvt; }
///
/// AppState({Event<int> buttonEvt}) : buttonEvt = buttonEvt ?? Event.spent();
///
/// Event buttonEvt_Reducer(Event<int> buttonEvt, dynamic action) {
///    if (action is Increment_Action) {
///    buttonEvt = Event(action.howMuch);
///    return buttonEvt; }
/// ```
///
/// For more info, see: https://pub.dartlang.org/packages/async_redux
///

class Event<T> {
  bool _spent;
  final T? _evtInfo;

  Event([T? evtInfo])
      : _evtInfo = evtInfo,
        _spent = false;

  Event.spent()
      : _evtInfo = null,
        _spent = true;

  bool get isSpent => _spent;

  bool get isNotSpent => !isSpent;

  /// Returns the event state and consumes the event.
  T? consume() {
    T? saveState = state;
    _spent = true;
    return saveState;
  }

  /// Returns the event state.
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

  /// This is a convenience factory to create an event which is transformed by
  /// some function that, usually, needs the store state. You must provide the
  /// event and a map-function. The map-function must be able to deal with
  /// the spent state (null or false, accordingly).
  ///
  /// For example, if `state.indexEvt = Event<int>(5)` and you must get
  /// a user from it:
  ///
  /// ```
  /// var mapFunction = (int index) => index == null ? null : state.users[index];
  /// Event<User> userEvt = Event.map(state.indexEvt, mapFunction);
  /// ```
  static Event<T> map<T, V>(Event<V> evt, T? Function(V?) mapFunction) =>
      MappedEvent<V, T>(evt, mapFunction);

  /// This is a convenience method to create an event which consumes from more than one event.
  /// If the first event is not spent, it will be consumed, and the second will not.
  /// If the first event is spent, the second one will be consumed.
  /// So, if both events are NOT spent, the method will have to be called twice to consume both.
  /// If both are spent, returns null.
  ///
  /// For example:
  /// ```
  /// String getTypedMessageEvt() {
  ///    return Event.consumeFrom(setTypedMessageEvt, widget.setTypedMessageEvt);
  ///  }
  /// ```
  factory Event.from(Event<T> evt1, Event<T> evt2) => EventMultiple(evt1, evt2);

  /// This is a convenience method to consume from more than one event.
  /// If the first event is not spent, it will be consumed, and the second will not.
  /// If the first event is spent, the second one will be consumed.
  /// So, if both events are NOT spent, the method will have to be called twice to consume both.
  /// If both are spent, returns null.
  ///
  /// ```
  /// For example:
  /// String getTypedMessageEvt() {
  ///    return Event.consumeFrom(setTypedMessageEvt, widget.setTypedMessageEvt);
  ///  }
  /// ```
  static T? consumeFrom<T>(Event<T> evt1, Event<T> evt2) {
    T? evt = evt1.consume();
    evt ??= evt2.consume();
    return evt;
  }

  /// The [StoreConnector] has a `distinct` parameter which may be set to `true`.
  /// As a performance optimization, `distinct:true` allows the widget to be rebuilt only when the
  /// ViewModel changes. If this is not done, then every time any state in the store changes the
  /// widget will be rebuilt.
  ///
  /// And then, of course, you must implement equals and hashcode for the `ViewModel`.
  /// This can be done by typing **`ALT`+`INSERT`** in IntelliJ IDEA or Android Studio and
  /// choosing **`==() and hashcode`**, but you can't forget to update this whenever new
  /// parameters are added to the model.
  /// The present events must also be part of that equals/hashcode, like so:
  ///
  /// 1) If the **new** ViewModel has an event which is **not spent**, then the ViewModel
  /// **MUST** be considered distinct, no matter the state of the **old** ViewModel, since the
  /// new event should fire.
  ///
  /// 2) If both the old and new ViewModels have events which **are spent**, then these events
  /// **MUST NOT** be considered distinct, since spent events are considered "empty" and
  /// should never fire.
  ///
  /// 3) If the **new** ViewModel has an event which is **not spent**,
  /// and the **old** ViewModel has an event which **is spent**,
  /// then the new event should fire, and for that reason they **MUST** be considered distinct.
  ///
  /// 4) If the **new** ViewModel has an event which is **is spent**,
  /// and the **old** ViewModel has an event which **not spent**, then the new event
  /// should NOT fire, and for that reason they **SHOULD NOT** be considered distinct.
  ///
  /// Note: To differentiate 3 and 4 we would actually be breaking the equals contract (which says
  /// A==B should be the same as B==A). Besides, we would need to know if AsyncRedux is
  /// comparing newVm==oldViewModel or oldViewModel==newVm (and stays like this).
  /// A safer alternative is discard 4, and always consider events different if any of them is not
  /// spent. That will, however, fire some unnecessary rebuilds.
  ///
  /// In the near future, we may decide to break the equals contract (which is probably fine since
  /// the usage of [Event] is so specialized), and create unit tests to check it continues to work
  /// and detect breaks if new versions of AsyncRedux change the order of the comparison.
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

  /// 1) If two objects are equal according to the equals method, then hashcode of both must
  /// be the same. Since spent events are all equal, they should produce the same hashcode.
  /// 2) If two objects are NOT equal, hashcode may be the same or not, but it's better
  /// when they are not the same. However, events are mutable, and this could mean the hashcode
  /// of the state could be changed when an event is consumed. To avoid this, we make events
  /// always return the same hashCode.
  @override
  int get hashCode => 0;
}

// /////////////////////////////////////////////////////////////////////////////

/// An Event from multiple sub-events.
/// When consuming this event, if the first sub-event is not spent, it will be consumed,
/// and the second will not. If the first sub-event is spent, the second one will be consumed.
///
/// So, if both sub-events are NOT spent, the multiple-event will have to be consumed twice to
/// consume both sub-events.
///
/// If both sub-events are spent, the multiple-event returns null when consumed.
///
/// ```
/// For example:
/// Event getTypedMessageEvt() {
///    return EventMultiple(setTypedMessageEvt, widget.setTypedMessageEvt);
///  }
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
  @override
  T? consume() {
    return Event.consumeFrom(evt1, evt2);
  }

  /// Returns the event state.
  @override
  T? get state {
    T? st = evt1.state;
    st ??= evt2.state;
    return st;
  }
}

// /////////////////////////////////////////////////////////////////////////////

/// A MappedEvent is useful when your event value must be transformed by
/// some function that, usually, needs the store state. You must provide the
/// event and a map-function. The map-function must be able to deal with
/// the spent state (null or false, accordingly).
///
/// For example, if `state.indexEvt = Event<int>(5)` and you must get
/// a user from it:
///
/// ```
/// var mapFunction = (index) => index == null ? null : state.users[index];
/// Event<User> userEvt = MappedEvent<int, User>(state.indexEvt, mapFunction);
/// ```
class MappedEvent<V, T> extends Event<T> {
  Event<V> evt;
  T? Function(V?) mapFunction;

  MappedEvent(Event<V>? evt, this.mapFunction) : evt = evt ?? Event<V>.spent();

  @override
  bool get isSpent => evt.isSpent;

  /// Returns the event state and consumes the event.
  @override
  T? consume() => mapFunction(evt.consume());

  /// Returns the event state.
  @override
  T? get state => mapFunction(evt.state);
}

// /////////////////////////////////////////////////////////////////////////////
