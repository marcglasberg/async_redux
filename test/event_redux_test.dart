import 'package:async_redux/async_redux.dart';
import "package:test/test.dart";

void main() {
  /////////////////////////////////////////////////////////////////////////////

  test('Boolean event equals.', () {
    // Spent events are always equal.
    expect(Event.spent(), Event.spent());

    // Not-spent events are always different.
    expect(Event(), isNot(Event()));

    // An event not-spent is always different from a spent event.
    expect(Event.spent(), isNot(Event()));
  });

  /////////////////////////////////////////////////////////////////////////////

  test('String event equals.', () {
    // Spent events are always equal.
    expect(Event<String>.spent(), Event<String>.spent());

    // Not-spent events are always different.
    expect(Event<String>('String'), isNot(Event<String>('String')));

    // An event not-spent is always different from a spent event.
    expect(Event<String>.spent(), isNot(Event<String>()));
  });

  /////////////////////////////////////////////////////////////////////////////

  test('Number event equals.', () {
    // Spent events are always equal.
    expect(Event<int>.spent(), Event<int>.spent());

    // Not-spent events are always different.
    expect(Event<int>(123), isNot(Event<int>(123)));

    // An event not-spent is always different from a spent event.
    expect(Event<int>.spent(), isNot(Event<int>()));
  });

  /////////////////////////////////////////////////////////////////////////////

  test('EventMultiple', () {
    Event<String> evt1 = Event<String>("Mary");
    Event<String> evt2 = Event<String>("Anna");
    EventMultiple<String> evt = EventMultiple(evt1, evt2);

    expect(evt.isSpent, false);
    expect(evt.isNotSpent, true);
    expect(evt.state, "Mary");
    expect(evt.state, "Mary");
    expect(evt.isSpent, false);
    expect(evt.isNotSpent, true);

    expect(evt.consume(), "Mary");
    expect(evt.state, "Anna");
    expect(evt.isSpent, false);
    expect(evt.isNotSpent, true);

    expect(evt.consume(), "Anna");
    expect(evt.state, null);
    expect(evt.isSpent, true);
    expect(evt.isNotSpent, false);

    expect(evt.consume(), null);
    expect(evt.isSpent, true);
    expect(evt.isNotSpent, false);
  });

  /////////////////////////////////////////////////////////////////////////////

  test('MappedEvent', () {
    List<String> users = ["Mary", "Anna", "Arnold", "Jake", "Frank", "Suzy"];
    String? Function(int?) mapFunction =
        (index) => index == null ? null : users[index];
    Event<String> userEvt1 = Event.map(Event<int>(3), mapFunction);
    Event<String> userEvt2 =
        MappedEvent<int, String>(Event<int>(2), mapFunction);

    // Consume the event.
    expect(userEvt1.consume(), "Jake");
    expect(userEvt1.consume(), null);
    expect(userEvt1.isSpent, true);
    expect(userEvt1.isNotSpent, false);

    // Don't consume the event.
    expect(userEvt2.state, "Arnold");
    expect(userEvt2.state, "Arnold");
    expect(userEvt2.isSpent, false);
    expect(userEvt2.isNotSpent, true);

    // A spent event is different from a not-spent one.
    expect(userEvt1 == userEvt2, isFalse);

    // Now consume the second event.
    expect(userEvt2.consume(), "Arnold");
    expect(userEvt2.isSpent, true);
    expect(userEvt2.isNotSpent, false);

    // A spent event is equal to a spent one.
    expect(userEvt1 == userEvt2, isTrue);
  });

  /////////////////////////////////////////////////////////////////////////////
}
