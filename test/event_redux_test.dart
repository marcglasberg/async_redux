import 'package:easy_redux/async_redux.dart';
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
}
