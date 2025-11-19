// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AsyncRedux context.event() functionality', () {
    testWidgets('Basic event consumption - value-less event (Event)',
        (WidgetTester tester) async {
      final initialState = AppState(
        clearTextEvt: Event.spent(),
        changeTextEvt: Event<String>.spent(),
        counter: 0,
      );

      final store = Store<AppState>(initialState: initialState);
      int buildCount = 0;
      bool? lastEventValue;

      await tester.pumpWidget(
        MaterialApp(
          home: StoreProvider<AppState>(
            store: store,
            child: Scaffold(
              body: Builder(builder: (context) {
                buildCount++;
                var clearText = context.event((state) => state.clearTextEvt);
                lastEventValue = clearText;
                return Text('Clear: $clearText', key: const Key('clearText'));
              }),
            ),
          ),
        ),
      );

      // Initial build - event is spent, should return false
      expect(buildCount, 1);
      expect(lastEventValue, false);
      expect(find.text('Clear: false'), findsOneWidget);

      // Dispatch event - should rebuild and return true
      store.dispatch(ClearTextAction());
      await tester.pump();
      await tester.pump();

      expect(buildCount, 2);
      expect(lastEventValue, true);
      expect(find.text('Clear: true'), findsOneWidget);

      // Event is now spent - dispatching unrelated action should NOT rebuild
      // because the selected event hasn't changed
      store.dispatch(IncrementCounterAction());
      await tester.pump();
      await tester.pump();

      expect(buildCount, 2); // No rebuild - event didn't change
      expect(find.text('Clear: true'), findsOneWidget); // Still shows last rendered value
    });

    testWidgets('Typed event consumption - Event<String>',
        (WidgetTester tester) async {
      final initialState = AppState(
        clearTextEvt: Event.spent(),
        changeTextEvt: Event<String>.spent(),
        counter: 0,
      );

      final store = Store<AppState>(initialState: initialState);
      int buildCount = 0;
      String? lastEventValue;

      await tester.pumpWidget(
        MaterialApp(
          home: StoreProvider<AppState>(
            store: store,
            child: Scaffold(
              body: Builder(builder: (context) {
                buildCount++;
                var newText = context.event((state) => state.changeTextEvt);
                lastEventValue = newText;
                return Text('Text: ${newText ?? "none"}',
                    key: const Key('changeText'));
              }),
            ),
          ),
        ),
      );

      // Initial build - event is spent, should return null
      expect(buildCount, 1);
      expect(lastEventValue, null);
      expect(find.text('Text: none'), findsOneWidget);

      // Dispatch event with value - should rebuild and return value
      store.dispatch(ChangeTextAction('Hello World'));
      await tester.pump();
      await tester.pump();

      expect(buildCount, 2);
      expect(lastEventValue, 'Hello World');
      expect(find.text('Text: Hello World'), findsOneWidget);

      // Event is now spent - dispatching unrelated action should NOT rebuild
      store.dispatch(IncrementCounterAction());
      await tester.pump();
      await tester.pump();

      expect(buildCount, 2); // No rebuild - event didn't change
      expect(find.text('Text: Hello World'), findsOneWidget); // Still shows last value
    });

    testWidgets('Event consumed only once per dispatch',
        (WidgetTester tester) async {
      final initialState = AppState(
        clearTextEvt: Event.spent(),
        changeTextEvt: Event<String>.spent(),
        counter: 0,
      );

      final store = Store<AppState>(initialState: initialState);
      List<String?> eventHistory = [];

      await tester.pumpWidget(
        MaterialApp(
          home: StoreProvider<AppState>(
            store: store,
            child: Scaffold(
              body: Builder(builder: (context) {
                var newText = context.event((state) => state.changeTextEvt);
                eventHistory.add(newText);
                return Text('Text: ${newText ?? "none"}');
              }),
            ),
          ),
        ),
      );

      expect(eventHistory, [null]); // Initial - spent

      // First event
      store.dispatch(ChangeTextAction('First'));
      await tester.pump();
      await tester.pump();
      expect(eventHistory, [null, 'First']);

      // Second event - overwrites the spent first event
      store.dispatch(ChangeTextAction('Second'));
      await tester.pump();
      await tester.pump();
      expect(eventHistory, [null, 'First', 'Second']);

      // Third event
      store.dispatch(ChangeTextAction('Third'));
      await tester.pump();
      await tester.pump();
      expect(eventHistory, [null, 'First', 'Second', 'Third']);
    });

    testWidgets('Multiple events in same widget', (WidgetTester tester) async {
      final initialState = AppState(
        clearTextEvt: Event.spent(),
        changeTextEvt: Event<String>.spent(),
        counter: 0,
      );

      final store = Store<AppState>(initialState: initialState);
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StoreProvider<AppState>(
            store: store,
            child: Scaffold(
              body: Builder(builder: (context) {
                buildCount++;
                var clear = context.event((state) => state.clearTextEvt);
                var change = context.event((state) => state.changeTextEvt);
                return Column(
                  children: [
                    Text('Clear: $clear'),
                    Text('Change: ${change ?? "none"}'),
                  ],
                );
              }),
            ),
          ),
        ),
      );

      expect(buildCount, 1);
      expect(find.text('Clear: false'), findsOneWidget);
      expect(find.text('Change: none'), findsOneWidget);

      // Dispatch clear event only
      store.dispatch(ClearTextAction());
      await tester.pump();
      await tester.pump();

      expect(buildCount, 2);
      expect(find.text('Clear: true'), findsOneWidget);
      expect(find.text('Change: none'), findsOneWidget);

      // Dispatch change event only
      store.dispatch(ChangeTextAction('New Text'));
      await tester.pump();
      await tester.pump();

      expect(buildCount, 3);
      expect(find.text('Clear: false'), findsOneWidget); // Clear was consumed
      expect(find.text('Change: New Text'), findsOneWidget);

      // Dispatch both events
      store.dispatch(ClearTextAction());
      store.dispatch(ChangeTextAction('Both Events'));
      await tester.pump();
      await tester.pump();

      expect(buildCount, 4);
      expect(find.text('Clear: true'), findsOneWidget);
      expect(find.text('Change: Both Events'), findsOneWidget);
    });

    testWidgets('Event triggers rebuild even with same value',
        (WidgetTester tester) async {
      final initialState = AppState(
        clearTextEvt: Event.spent(),
        changeTextEvt: Event<String>.spent(),
        counter: 0,
      );

      final store = Store<AppState>(initialState: initialState);
      int buildCount = 0;
      List<String?> values = [];

      await tester.pumpWidget(
        MaterialApp(
          home: StoreProvider<AppState>(
            store: store,
            child: Scaffold(
              body: Builder(builder: (context) {
                buildCount++;
                var newText = context.event((state) => state.changeTextEvt);
                values.add(newText);
                return Text('Text: ${newText ?? "none"}');
              }),
            ),
          ),
        ),
      );

      expect(buildCount, 1);

      // Dispatch event with value
      store.dispatch(ChangeTextAction('Same'));
      await tester.pump();
      await tester.pump();
      expect(buildCount, 2);
      expect(values.last, 'Same');

      // Dispatch same value again - should still trigger rebuild
      // because each Event instance is unique
      store.dispatch(ChangeTextAction('Same'));
      await tester.pump();
      await tester.pump();
      expect(buildCount, 3);
      expect(values.last, 'Same');

      // Dispatch same value a third time
      store.dispatch(ChangeTextAction('Same'));
      await tester.pump();
      await tester.pump();
      expect(buildCount, 4);
      expect(values.last, 'Same');
    });

    testWidgets('Event with null value vs spent event',
        (WidgetTester tester) async {
      final initialState = AppState(
        clearTextEvt: Event.spent(),
        changeTextEvt: Event<String>.spent(),
        counter: 0,
      );

      final store = Store<AppState>(initialState: initialState);
      List<String?> values = [];

      await tester.pumpWidget(
        MaterialApp(
          home: StoreProvider<AppState>(
            store: store,
            child: Scaffold(
              body: Builder(builder: (context) {
                var newText = context.event((state) => state.changeTextEvt);
                values.add(newText);
                return Text('Text: ${newText ?? "none"}');
              }),
            ),
          ),
        ),
      );

      expect(values, [null]); // Spent event returns null

      // Dispatch event with null value
      store.dispatch(ChangeTextAction(null));
      await tester.pump();
      await tester.pump();
      // Event with null value also returns null, but event was consumed
      expect(values, [null, null]);

      // Dispatch another event with actual value
      store.dispatch(ChangeTextAction('actual'));
      await tester.pump();
      await tester.pump();
      expect(values, [null, null, 'actual']);
    });

    testWidgets('Event with various types - int', (WidgetTester tester) async {
      final initialState = AppStateWithIntEvent(
        numberEvt: Event<int>.spent(),
        counter: 0,
      );

      final store = Store<AppStateWithIntEvent>(initialState: initialState);
      List<int?> values = [];

      await tester.pumpWidget(
        MaterialApp(
          home: StoreProvider<AppStateWithIntEvent>(
            store: store,
            child: Scaffold(
              body: Builder(builder: (context) {
                var number = context.getEvent<AppStateWithIntEvent, int>(
                    (state) => state.numberEvt);
                values.add(number);
                return Text('Number: ${number ?? "none"}');
              }),
            ),
          ),
        ),
      );

      expect(values, [null]);

      store.dispatch(SetNumberAction(42));
      await tester.pump();
      await tester.pump();
      expect(values, [null, 42]);

      store.dispatch(SetNumberAction(0));
      await tester.pump();
      await tester.pump();
      expect(values, [null, 42, 0]);
    });

    testWidgets('Event not consumed when widget disposed',
        (WidgetTester tester) async {
      final initialState = AppState(
        clearTextEvt: Event.spent(),
        changeTextEvt: Event<String>.spent(),
        counter: 0,
      );

      final store = Store<AppState>(initialState: initialState);
      bool showWidget = true;

      await tester.pumpWidget(
        MaterialApp(
          home: StoreProvider<AppState>(
            store: store,
            child: StatefulBuilder(
              builder: (context, setState) {
                return Scaffold(
                  body: Column(
                    children: [
                      if (showWidget)
                        Builder(builder: (context) {
                          var newText =
                              context.event((state) => state.changeTextEvt);
                          return Text('Text: ${newText ?? "none"}');
                        }),
                      ElevatedButton(
                        onPressed: () => setState(() => showWidget = false),
                        child: const Text('Hide'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Text: none'), findsOneWidget);

      // Dispatch event
      store.dispatch(ChangeTextAction('Hello'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Text: Hello'), findsOneWidget);

      // Hide widget
      await tester.tap(find.text('Hide'));
      await tester.pump();
      expect(find.text('Text: Hello'), findsNothing);

      // Dispatch another event while widget is hidden
      store.dispatch(ChangeTextAction('World'));
      await tester.pump();
      // Event is in state but not consumed (no widget to consume it)
      expect(store.state.changeTextEvt.isNotSpent, true);
    });

    testWidgets('Rapid event dispatching', (WidgetTester tester) async {
      final initialState = AppState(
        clearTextEvt: Event.spent(),
        changeTextEvt: Event<String>.spent(),
        counter: 0,
      );

      final store = Store<AppState>(initialState: initialState);
      List<String?> values = [];

      await tester.pumpWidget(
        MaterialApp(
          home: StoreProvider<AppState>(
            store: store,
            child: Scaffold(
              body: Builder(builder: (context) {
                var newText = context.event((state) => state.changeTextEvt);
                values.add(newText);
                return Text('Text: ${newText ?? "none"}');
              }),
            ),
          ),
        ),
      );

      expect(values, [null]);

      // Dispatch multiple events rapidly
      store.dispatch(ChangeTextAction('First'));
      store.dispatch(ChangeTextAction('Second'));
      store.dispatch(ChangeTextAction('Third'));
      await tester.pump();
      await tester.pump();

      // Only the last event should be consumed (events overwrite each other)
      expect(values.last, 'Third');
    });

    testWidgets('Event with complex type - List', (WidgetTester tester) async {
      final initialState = AppStateWithListEvent(
        itemsEvt: Event<List<String>>.spent(),
        counter: 0,
      );

      final store = Store<AppStateWithListEvent>(initialState: initialState);
      List<List<String>?> values = [];

      await tester.pumpWidget(
        MaterialApp(
          home: StoreProvider<AppStateWithListEvent>(
            store: store,
            child: Scaffold(
              body: Builder(builder: (context) {
                var items = context.getEvent<AppStateWithListEvent, List<String>>(
                    (state) => state.itemsEvt);
                values.add(items);
                return Text('Items: ${items?.join(", ") ?? "none"}');
              }),
            ),
          ),
        ),
      );

      expect(values, [null]);
      expect(find.text('Items: none'), findsOneWidget);

      store.dispatch(SetItemsAction(['apple', 'banana', 'cherry']));
      await tester.pump();
      await tester.pump();
      expect(values.last, ['apple', 'banana', 'cherry']);
      expect(find.text('Items: apple, banana, cherry'), findsOneWidget);
    });

    testWidgets('Event combined with select - independent rebuilds',
        (WidgetTester tester) async {
      final initialState = AppState(
        clearTextEvt: Event.spent(),
        changeTextEvt: Event<String>.spent(),
        counter: 0,
      );

      final store = Store<AppState>(initialState: initialState);
      int eventWidgetBuilds = 0;
      int selectWidgetBuilds = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StoreProvider<AppState>(
            store: store,
            child: Scaffold(
              body: Column(
                children: [
                  // Widget using event
                  Builder(builder: (context) {
                    eventWidgetBuilds++;
                    var newText = context.event((state) => state.changeTextEvt);
                    return Text('Event: ${newText ?? "none"}');
                  }),
                  // Widget using select
                  Builder(builder: (context) {
                    selectWidgetBuilds++;
                    var counter = context.select((st) => st.counter);
                    return Text('Counter: $counter');
                  }),
                ],
              ),
            ),
          ),
        ),
      );

      expect(eventWidgetBuilds, 1);
      expect(selectWidgetBuilds, 1);

      // Dispatch event - should rebuild event widget
      store.dispatch(ChangeTextAction('Hello'));
      await tester.pump();
      await tester.pump();
      expect(eventWidgetBuilds, 2);
      // Select widget may or may not rebuild depending on implementation

      // Increment counter - should rebuild select widget
      store.dispatch(IncrementCounterAction());
      await tester.pump();
      await tester.pump();
      expect(selectWidgetBuilds, greaterThan(1));
    });

    testWidgets('Event.from - consuming from multiple events',
        (WidgetTester tester) async {
      final initialState = AppStateWithTwoEvents(
        event1: Event<String>.spent(),
        event2: Event<String>.spent(),
        counter: 0,
      );

      final store = Store<AppStateWithTwoEvents>(initialState: initialState);
      List<String?> values = [];

      await tester.pumpWidget(
        MaterialApp(
          home: StoreProvider<AppStateWithTwoEvents>(
            store: store,
            child: Scaffold(
              body: Builder(builder: (context) {
                var combined = context.getEvent<AppStateWithTwoEvents, String>(
                    (state) => Event.from(state.event1, state.event2));
                values.add(combined);
                return Text('Combined: ${combined ?? "none"}');
              }),
            ),
          ),
        ),
      );

      expect(values, [null]);

      // Dispatch to first event
      store.dispatch(SetEvent1Action('From Event 1'));
      await tester.pump();
      await tester.pump();
      expect(values.last, 'From Event 1');

      // Dispatch to second event (first is now spent, so second is consumed)
      store.dispatch(SetEvent2Action('From Event 2'));
      await tester.pump();
      await tester.pump();
      expect(values.last, 'From Event 2');

      // Dispatch to first event again
      store.dispatch(SetEvent1Action('From Event 1 Again'));
      await tester.pump();
      await tester.pump();
      expect(values.last, 'From Event 1 Again');
    });

    testWidgets('MappedEvent - transforming event values',
        (WidgetTester tester) async {
      final initialState = AppStateWithMappedEvent(
        indexEvt: Event<int>.spent(),
        users: ['Alice', 'Bob', 'Charlie'],
        counter: 0,
      );

      final store = Store<AppStateWithMappedEvent>(initialState: initialState);
      List<String?> values = [];

      await tester.pumpWidget(
        MaterialApp(
          home: StoreProvider<AppStateWithMappedEvent>(
            store: store,
            child: Scaffold(
              body: Builder(builder: (context) {
                var user = context.getEvent<AppStateWithMappedEvent, String>(
                    (state) => Event.map(
                        state.indexEvt,
                        (int? index) =>
                            index == null ? null : state.users[index]));
                values.add(user);
                return Text('User: ${user ?? "none"}');
              }),
            ),
          ),
        ),
      );

      expect(values, [null]);

      // Dispatch index 1 -> should return "Bob"
      store.dispatch(SetIndexAction(1));
      await tester.pump();
      await tester.pump();
      expect(values.last, 'Bob');
      expect(find.text('User: Bob'), findsOneWidget);

      // Dispatch index 2 -> should return "Charlie"
      store.dispatch(SetIndexAction(2));
      await tester.pump();
      await tester.pump();
      expect(values.last, 'Charlie');
      expect(find.text('User: Charlie'), findsOneWidget);

      // Dispatch index 0 -> should return "Alice"
      store.dispatch(SetIndexAction(0));
      await tester.pump();
      await tester.pump();
      expect(values.last, 'Alice');
      expect(find.text('User: Alice'), findsOneWidget);
    });

    testWidgets('Event equality - spent events are equal',
        (WidgetTester tester) async {
      final evt1 = Event<String>.spent();
      final evt2 = Event<String>.spent();
      expect(evt1 == evt2, true);

      final evt3 = Event<String>('value');
      final evt4 = Event<String>('value');
      // Unspent events are never equal
      expect(evt3 == evt4, false);

      // Consume evt3
      evt3.consume();
      // Now evt3 is spent but evt4 is not
      expect(evt3 == evt4, false);

      // Consume evt4
      evt4.consume();
      // Both spent, should be equal
      expect(evt3 == evt4, true);
    });

    testWidgets('Event isSpent and isNotSpent properties',
        (WidgetTester tester) async {
      final evt = Event<String>('test');
      expect(evt.isSpent, false);
      expect(evt.isNotSpent, true);

      evt.consume();
      expect(evt.isSpent, true);
      expect(evt.isNotSpent, false);
    });
  });
}

// Extension for BuildContext
extension BuildContextExtension on BuildContext {
  AppState get state => getState<AppState>();
  AppState read() => getRead<AppState>();
  R select<R>(R Function(AppState state) selector) =>
      getSelect<AppState, R>(selector);
  R? event<R>(Evt<R> Function(AppState state) selector) =>
      getEvent<AppState, R>(selector);
}

// Test state classes
class AppState {
  final Event clearTextEvt;
  final Event<String> changeTextEvt;
  final int counter;

  AppState({
    required this.clearTextEvt,
    required this.changeTextEvt,
    required this.counter,
  });

  AppState copyWith({
    Event? clearTextEvt,
    Event<String>? changeTextEvt,
    int? counter,
  }) {
    return AppState(
      clearTextEvt: clearTextEvt ?? this.clearTextEvt,
      changeTextEvt: changeTextEvt ?? this.changeTextEvt,
      counter: counter ?? this.counter,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppState &&
        other.clearTextEvt == clearTextEvt &&
        other.changeTextEvt == changeTextEvt &&
        other.counter == counter;
  }

  @override
  int get hashCode => Object.hash(clearTextEvt, changeTextEvt, counter);
}

class AppStateWithIntEvent {
  final Event<int> numberEvt;
  final int counter;

  AppStateWithIntEvent({required this.numberEvt, required this.counter});

  AppStateWithIntEvent copyWith({Event<int>? numberEvt, int? counter}) {
    return AppStateWithIntEvent(
      numberEvt: numberEvt ?? this.numberEvt,
      counter: counter ?? this.counter,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppStateWithIntEvent &&
        other.numberEvt == numberEvt &&
        other.counter == counter;
  }

  @override
  int get hashCode => Object.hash(numberEvt, counter);
}

class AppStateWithListEvent {
  final Event<List<String>> itemsEvt;
  final int counter;

  AppStateWithListEvent({required this.itemsEvt, required this.counter});

  AppStateWithListEvent copyWith({Event<List<String>>? itemsEvt, int? counter}) {
    return AppStateWithListEvent(
      itemsEvt: itemsEvt ?? this.itemsEvt,
      counter: counter ?? this.counter,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppStateWithListEvent &&
        other.itemsEvt == itemsEvt &&
        other.counter == counter;
  }

  @override
  int get hashCode => Object.hash(itemsEvt, counter);
}

class AppStateWithTwoEvents {
  final Event<String> event1;
  final Event<String> event2;
  final int counter;

  AppStateWithTwoEvents({
    required this.event1,
    required this.event2,
    required this.counter,
  });

  AppStateWithTwoEvents copyWith({
    Event<String>? event1,
    Event<String>? event2,
    int? counter,
  }) {
    return AppStateWithTwoEvents(
      event1: event1 ?? this.event1,
      event2: event2 ?? this.event2,
      counter: counter ?? this.counter,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppStateWithTwoEvents &&
        other.event1 == event1 &&
        other.event2 == event2 &&
        other.counter == counter;
  }

  @override
  int get hashCode => Object.hash(event1, event2, counter);
}

class AppStateWithMappedEvent {
  final Event<int> indexEvt;
  final List<String> users;
  final int counter;

  AppStateWithMappedEvent({
    required this.indexEvt,
    required this.users,
    required this.counter,
  });

  AppStateWithMappedEvent copyWith({
    Event<int>? indexEvt,
    List<String>? users,
    int? counter,
  }) {
    return AppStateWithMappedEvent(
      indexEvt: indexEvt ?? this.indexEvt,
      users: users ?? this.users,
      counter: counter ?? this.counter,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppStateWithMappedEvent &&
        other.indexEvt == indexEvt &&
        other.counter == counter;
  }

  @override
  int get hashCode => Object.hash(indexEvt, counter);
}

// Test actions
class ClearTextAction extends ReduxAction<AppState> {
  @override
  AppState reduce() {
    return state.copyWith(clearTextEvt: Event());
  }
}

class ChangeTextAction extends ReduxAction<AppState> {
  final String? text;
  ChangeTextAction(this.text);

  @override
  AppState reduce() {
    return state.copyWith(changeTextEvt: Event<String>(text));
  }
}

class IncrementCounterAction extends ReduxAction<AppState> {
  @override
  AppState reduce() {
    return state.copyWith(counter: state.counter + 1);
  }
}

class SetNumberAction extends ReduxAction<AppStateWithIntEvent> {
  final int number;
  SetNumberAction(this.number);

  @override
  AppStateWithIntEvent reduce() {
    return state.copyWith(numberEvt: Event<int>(number));
  }
}

class SetItemsAction extends ReduxAction<AppStateWithListEvent> {
  final List<String> items;
  SetItemsAction(this.items);

  @override
  AppStateWithListEvent reduce() {
    return state.copyWith(itemsEvt: Event<List<String>>(items));
  }
}

class SetEvent1Action extends ReduxAction<AppStateWithTwoEvents> {
  final String value;
  SetEvent1Action(this.value);

  @override
  AppStateWithTwoEvents reduce() {
    return state.copyWith(event1: Event<String>(value));
  }
}

class SetEvent2Action extends ReduxAction<AppStateWithTwoEvents> {
  final String value;
  SetEvent2Action(this.value);

  @override
  AppStateWithTwoEvents reduce() {
    return state.copyWith(event2: Event<String>(value));
  }
}

class IncrementCounter2Action extends ReduxAction<AppStateWithTwoEvents> {
  @override
  AppStateWithTwoEvents reduce() {
    return state.copyWith(counter: state.counter + 1);
  }
}

class SetIndexAction extends ReduxAction<AppStateWithMappedEvent> {
  final int index;
  SetIndexAction(this.index);

  @override
  AppStateWithMappedEvent reduce() {
    return state.copyWith(indexEvt: Event<int>(index));
  }
}

class IncrementCounter3Action extends ReduxAction<AppStateWithMappedEvent> {
  @override
  AppStateWithMappedEvent reduce() {
    return state.copyWith(counter: state.counter + 1);
  }
}
