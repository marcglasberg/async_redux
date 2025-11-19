// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

import 'package:async_redux/async_redux.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AsyncRedux select() functionality', () {
    testWidgets('Basic selection - widget only rebuilds when selected value changes',
        (WidgetTester tester) async {
      // Create initial state
      final initialState = AppState(
        user: User(name: 'Alice', age: 25, email: 'alice@example.com'),
        counter: 0,
        items: IList<String>(['item1']),
        settings: Settings(darkMode: false, language: 'en'),
      );

      final store = Store<AppState>(initialState: initialState);

      // Track build counts for each widget
      Map<String, int> buildCounts = {
        'userName': 0,
        'userAge': 0,
        'counter': 0,
        'itemsCount': 0,
        'darkMode': 0,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: StoreProvider<AppState>(
            store: store,
            child: Scaffold(
              body: Column(
                children: [
                  Builder(builder: (context) {
                    buildCounts['userName'] = buildCounts['userName']! + 1;
                    final userName = context.select((st) => st.user.name);
                    return Text('Name: $userName', key: const Key('userName'));
                  }),
                  Builder(builder: (context) {
                    buildCounts['userAge'] = buildCounts['userAge']! + 1;
                    final userAge = context.select((st) => st.user.age);
                    return Text('Age: $userAge', key: const Key('userAge'));
                  }),
                  Builder(builder: (context) {
                    buildCounts['counter'] = buildCounts['counter']! + 1;
                    final counter = context.select((st) => st.counter);
                    return Text('Counter: $counter', key: const Key('counter'));
                  }),
                ],
              ),
            ),
          ),
        ),
      );

      // Initial build
      expect(buildCounts['userName'], 1);
      expect(buildCounts['userAge'], 1);
      expect(buildCounts['counter'], 1);
      expect(find.text('Name: Alice'), findsOneWidget);
      expect(find.text('Age: 25'), findsOneWidget);
      expect(find.text('Counter: 0'), findsOneWidget);

      // Update user name - only userName widget should rebuild
      store.dispatch(UpdateUserNameAction('Bob'));
      await tester.pump();
      await tester.pump();

      expect(buildCounts['userName'], 2); // Rebuilt
      expect(buildCounts['userAge'], 1); // Not rebuilt
      expect(buildCounts['counter'], 1); // Not rebuilt
      expect(find.text('Name: Bob'), findsOneWidget);

      // Update user age - only userAge widget should rebuild
      store.dispatch(UpdateUserAgeAction(30));
      await tester.pump();
      await tester.pump();

      expect(buildCounts['userName'], 2); // Not rebuilt
      expect(buildCounts['userAge'], 2); // Rebuilt
      expect(buildCounts['counter'], 1); // Not rebuilt
      expect(find.text('Age: 30'), findsOneWidget);

      // Update counter - only counter widget should rebuild
      store.dispatch(IncrementCounterAction());
      await tester.pump();
      await tester.pump();

      expect(buildCounts['userName'], 2); // Not rebuilt
      expect(buildCounts['userAge'], 2); // Not rebuilt
      expect(buildCounts['counter'], 2); // Rebuilt
      expect(find.text('Counter: 1'), findsOneWidget);
    });

    testWidgets('Deep equality checking for collections', (WidgetTester tester) async {
      final initialState = AppState(
        user: User(name: 'Alice', age: 25, email: 'alice@example.com'),
        counter: 0,
        items: IList<String>(['apple', 'banana']),
        settings: Settings(darkMode: false, language: 'en'),
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
                // Select filtered list
                final filteredItems = context.select(
                  (state) => state.items.where((item) => item.startsWith('a')).toList(),
                );
                return Text('Items: ${filteredItems.join(', ')}');
              }),
            ),
          ),
        ),
      );

      expect(buildCount, 1);
      expect(find.text('Items: apple'), findsOneWidget);

      // Add item that doesn't match filter - should NOT rebuild
      store.dispatch(AddItemAction('cherry'));
      await tester.pump();
      await tester.pump();
      expect(buildCount, 1); // No rebuild

      // Add item that matches filter - should rebuild
      store.dispatch(AddItemAction('apricot'));
      await tester.pump();
      await tester.pump();
      expect(buildCount, 2); // Rebuilt
      expect(find.text('Items: apple, apricot'), findsOneWidget);
    });

    testWidgets('Multiple selects in one widget', (WidgetTester tester) async {
      final initialState = AppState(
        user: User(name: 'Alice', age: 25, email: 'alice@example.com'),
        counter: 0,
        items: IList<String>(),
        settings: Settings(darkMode: false, language: 'en'),
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
                // Multiple selects in one build
                final userName = context.select((st) => st.user.name);
                final userAge = context.select((st) => st.user.age);
                final isDarkMode = context.select((st) => st.settings.darkMode);

                return Column(
                  children: [
                    Text('User: $userName, $userAge'),
                    Text('Dark Mode: $isDarkMode'),
                  ],
                );
              }),
            ),
          ),
        ),
      );

      expect(buildCount, 1);

      // Change only counter (not selected) - should NOT rebuild
      store.dispatch(IncrementCounterAction());
      await tester.pump();
      await tester.pump();
      expect(buildCount, 1);

      // Change any selected value - should rebuild
      store.dispatch(UpdateUserNameAction('Bob'));
      await tester.pump();
      await tester.pump();
      expect(buildCount, 2);

      // Change another selected value - should rebuild
      store.dispatch(ToggleDarkModeAction());
      await tester.pump();
      await tester.pump();
      expect(buildCount, 3);
    });

    testWidgets('Complex computed values', (WidgetTester tester) async {
      final initialState = AppState(
        user: User(name: 'Alice', age: 17, email: 'alice@example.com'),
        counter: 5,
        items: IList<String>(['a', 'b', 'c']),
        settings: Settings(darkMode: false, language: 'en'),
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
                // Select computed summary.
                final summary = context.select((st) => {
                  'isAdult': st.user.age >= 18,
                  'hasMany': st.items.length > 5,
                  'score': st.counter * st.items.length,
                });

                return Text('Adult: ${summary['isAdult']}, Many: ${summary['hasMany']}, Score: ${summary['score']}');
              }),
            ),
          ),
        ),
      );

      expect(buildCount, 1);
      expect(find.text('Adult: false, Many: false, Score: 15'), findsOneWidget);

      // Change age but still minor - computed value same, should NOT rebuild
      store.dispatch(UpdateUserAgeAction(16));
      await tester.pump();
      await tester.pump();
      expect(buildCount, 1);

      // Change age to adult - computed value changes, should rebuild
      store.dispatch(UpdateUserAgeAction(18));
      await tester.pump();
      await tester.pump();
      expect(buildCount, 2);
      expect(find.text('Adult: true, Many: false, Score: 15'), findsOneWidget);

      // Add items to change score
      store.dispatch(AddItemAction('d'));
      await tester.pump();
      await tester.pump();
      expect(buildCount, 3);
      expect(find.text('Adult: true, Many: false, Score: 20'), findsOneWidget);
    });

    testWidgets('Selector clearing between builds', (WidgetTester tester) async {
      final initialState = AppState(
        user: User(name: 'Alice', age: 25, email: 'alice@example.com'),
        counter: 0,
        items: IList<String>(),
        settings: Settings(darkMode: false, language: 'en'),
      );

      final store = Store<AppState>(initialState: initialState);
      bool showAge = true;

      await tester.pumpWidget(
        MaterialApp(
          home: StoreProvider<AppState>(
            store: store,
            child: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    children: [
                      if (showAge)
                        Builder(builder: (context) {
                          final userAge = context.select((st) => st.user.age);
                          return Text('Age: $userAge');
                        })
                      else
                        Builder(builder: (context) {
                          final userName = context.select((st) => st.user.name);
                          return Text('Name: $userName');
                        }),
                      ElevatedButton(
                        onPressed: () => setState(() => showAge = !showAge),
                        child: const Text('Toggle'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Age: 25'), findsOneWidget);
      expect(find.text('Name: Alice'), findsNothing);

      // Toggle to show name
      await tester.tap(find.text('Toggle'));
      await tester.pump();
      await tester.pump(); // Extra pump for microtask

      expect(find.text('Age: 25'), findsNothing);
      expect(find.text('Name: Alice'), findsOneWidget);

      // Change age (should not trigger rebuild since we're now selecting name)
      store.dispatch(UpdateUserAgeAction(30));
      await tester.pump();
      expect(find.text('Name: Alice'), findsOneWidget); // Still showing name

      // Change name (should trigger rebuild)
      store.dispatch(UpdateUserNameAction('Bob'));
      await tester.pump();
      expect(find.text('Name: Bob'), findsOneWidget);
    });

    testWidgets('Comparing to regular state access', (WidgetTester tester) async {
      final initialState = AppState(
        user: User(name: 'Alice', age: 25, email: 'alice@example.com'),
        counter: 0,
        items: IList<String>(),
        settings: Settings(darkMode: false, language: 'en'),
      );

      final store = Store<AppState>(initialState: initialState);
      int regularBuildCount = 0;
      int selectBuildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: StoreProvider<AppState>(
            store: store,
            child: Scaffold(
              body: Column(
                children: [
                  // Widget using regular state access
                  Builder(builder: (context) {
                    regularBuildCount++;
                    final state = context.state;
                    return Text('Regular: ${state.user.name}');
                  }),
                  // Widget using select.
                  Builder(builder: (context) {
                    selectBuildCount++;
                    final userName = context.select((st) => st.user.name);
                    return Text('Select: $userName');
                  }),
                ],
              ),
            ),
          ),
        ),
      );

      expect(regularBuildCount, 1);
      expect(selectBuildCount, 1);

      // Change unrelated state - regular rebuilds, select doesn't
      store.dispatch(IncrementCounterAction());
      await tester.pump();
      expect(regularBuildCount, 2); // Rebuilt
      expect(selectBuildCount, 1); // Not rebuilt

      // Change selected state - both rebuild
      store.dispatch(UpdateUserNameAction('Bob'));
      await tester.pump();
      await tester.pump();
      expect(regularBuildCount, 3); // Rebuilt
      expect(selectBuildCount, 2); // Rebuilt
    });
  });

  group('Error handling and edge cases', () {
    testWidgets('Using select outside build method throws error', (WidgetTester tester) async {
      final initialState = AppState(
        user: User(name: 'Alice', age: 25, email: 'alice@example.com'),
        counter: 0,
        items: IList<String>(),
        settings: Settings(darkMode: false, language: 'en'),
      );

      final store = Store<AppState>(initialState: initialState);

      await tester.pumpWidget(
        MaterialApp(
          home: StoreProvider<AppState>(
            store: store,
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      // This should throw an error.
                      expect(
                        () => context.select((st) => st.user.name),
                        throwsA(isA<FlutterError>()),
                      );
                    },
                    child: const Text('Click me'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Click me'));
    });

    testWidgets('Nested select calls throw error', (WidgetTester tester) async {
      final initialState = AppState(
        user: User(name: 'Alice', age: 25, email: 'alice@example.com'),
        counter: 0,
        items: IList<String>(),
        settings: Settings(darkMode: false, language: 'en'),
      );

      final store = Store<AppState>(initialState: initialState);
      bool errorThrown = false;

      await tester.pumpWidget(
        MaterialApp(
          home: StoreProvider<AppState>(
            store: store,
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  try {
                    context.select((st) {
                      // Nested select - should throw.
                      context.select((s) => s.counter);
                      return st.user.name;
                    });
                  } catch (e) {
                    errorThrown = true;
                    return const Text('Error caught');
                  }
                  return const Text('No error');
                },
              ),
            ),
          ),
        ),
      );

      expect(errorThrown, true);
      expect(find.text('Error caught'), findsOneWidget);
    });
  });
}

// Recommended to create this extension.
extension BuildContextExtension on BuildContext {
  AppState get state => getState<AppState>();
  AppState read() => getRead<AppState>();
  R select<R>(R Function(AppState state) selector) => getSelect<AppState, R>(selector);
  R? event<R>(Evt<R> Function(AppState state) selector) => getEvent<AppState, R>(selector);
}

// Test state classes
class AppState {
  final User user;
  final int counter;
  final IList<String> items;
  final Settings settings;

  AppState({
    required this.user,
    required this.counter,
    required this.items,
    required this.settings,
  });

  AppState copyWith({
    User? user,
    int? counter,
    IList<String>? items,
    Settings? settings,
  }) {
    return AppState(
      user: user ?? this.user,
      counter: counter ?? this.counter,
      items: items ?? this.items,
      settings: settings ?? this.settings,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppState &&
        other.user == user &&
        other.counter == counter &&
        other.items == items &&
        other.settings == settings;
  }

  @override
  int get hashCode => Object.hash(user, counter, items, settings);
}

class User {
  final String name;
  final int age;
  final String email;

  User({required this.name, required this.age, required this.email});

  User copyWith({String? name, int? age, String? email}) {
    return User(
      name: name ?? this.name,
      age: age ?? this.age,
      email: email ?? this.email,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        other.name == name &&
        other.age == age &&
        other.email == email;
  }

  @override
  int get hashCode => Object.hash(name, age, email);
}

class Settings {
  final bool darkMode;
  final String language;

  Settings({required this.darkMode, required this.language});

  Settings copyWith({bool? darkMode, String? language}) {
    return Settings(
      darkMode: darkMode ?? this.darkMode,
      language: language ?? this.language,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Settings &&
        other.darkMode == darkMode &&
        other.language == language;
  }

  @override
  int get hashCode => Object.hash(darkMode, language);
}

// Test actions
class UpdateUserNameAction extends ReduxAction<AppState> {
  final String name;
  UpdateUserNameAction(this.name);

  @override
  AppState reduce() {
    return state.copyWith(user: state.user.copyWith(name: name));
  }
}

class UpdateUserAgeAction extends ReduxAction<AppState> {
  final int age;
  UpdateUserAgeAction(this.age);

  @override
  AppState reduce() {
    return state.copyWith(user: state.user.copyWith(age: age));
  }
}

class IncrementCounterAction extends ReduxAction<AppState> {
  @override
  AppState reduce() {
    return state.copyWith(counter: state.counter + 1);
  }
}

class AddItemAction extends ReduxAction<AppState> {
  final String item;
  AddItemAction(this.item);

  @override
  AppState reduce() {
    return state.copyWith(items: state.items.add(item));
  }
}

class ToggleDarkModeAction extends ReduxAction<AppState> {
  @override
  AppState reduce() {
    return state.copyWith(
      settings: state.settings.copyWith(darkMode: !state.settings.darkMode),
    );
  }
}

// Test widgets
class SelectTestWidget extends StatefulWidget {
  final Store<AppState> store;
  final int Function()? onBuildCounter;

  const SelectTestWidget({
    Key? key,
    required this.store,
    this.onBuildCounter,
  }) : super(key: key);

  @override
  State<SelectTestWidget> createState() => _SelectTestWidgetState();
}

class _SelectTestWidgetState extends State<SelectTestWidget> {
  int buildCount = 0;

  @override
  Widget build(BuildContext context) {
    buildCount++;
    widget.onBuildCounter?.call();

    return StoreProvider<AppState>(
      store: widget.store,
      child: Builder(
        builder: (context) {
          return Column(
            children: [
              UserNameWidget(
                key: const Key('userName'),
                onBuild: widget.onBuildCounter,
              ),
              UserAgeWidget(
                key: const Key('userAge'),
                onBuild: widget.onBuildCounter,
              ),
              CounterWidget(
                key: const Key('counter'),
                onBuild: widget.onBuildCounter,
              ),
              ItemsCountWidget(
                key: const Key('itemsCount'),
                onBuild: widget.onBuildCounter,
              ),
              DarkModeWidget(
                key: const Key('darkMode'),
                onBuild: widget.onBuildCounter,
              ),
            ],
          );
        },
      ),
    );
  }
}

class UserNameWidget extends StatelessWidget {
  final Function()? onBuild;

  const UserNameWidget({Key? key, this.onBuild}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    onBuild?.call();
    final userName = context.select((st) => st.user.name);
    return Text('Name: $userName');
  }
}

class UserAgeWidget extends StatelessWidget {
  final Function()? onBuild;

  const UserAgeWidget({Key? key, this.onBuild}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    onBuild?.call();
    final userAge = context.select((st) => st.user.age);
    return Text('Age: $userAge');
  }
}

class CounterWidget extends StatelessWidget {
  final Function()? onBuild;

  const CounterWidget({Key? key, this.onBuild}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    onBuild?.call();
    final counter = context.select((st) => st.counter);
    return Text('Counter: $counter');
  }
}

class ItemsCountWidget extends StatelessWidget {
  final Function()? onBuild;

  const ItemsCountWidget({Key? key, this.onBuild}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    onBuild?.call();
    final itemCount = context.select((st) => st.items.length);
    return Text('Items: $itemCount');
  }
}

class DarkModeWidget extends StatelessWidget {
  final Function()? onBuild;

  const DarkModeWidget({Key? key, this.onBuild}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    onBuild?.call();
    final isDarkMode = context.select((st) => st.settings.darkMode);
    return Text('Dark Mode: $isDarkMode');
  }
}

// Widget that uses multiple selects
class MultiSelectWidget extends StatelessWidget {
  final Function()? onBuild;

  const MultiSelectWidget({Key? key, this.onBuild}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    onBuild?.call();

    // Multiple selects in one build
    final userName = context.select((st) => st.user.name);
    final userAge = context.select((st) => st.user.age);
    final isDarkMode = context.select((st) => st.settings.darkMode);

    return Column(
      children: [
        Text('User: $userName, $userAge'),
        Text('Dark Mode: $isDarkMode'),
      ],
    );
  }
}

// Widget that selects complex computed values
class ComputedSelectWidget extends StatelessWidget {
  final Function()? onBuild;

  const ComputedSelectWidget({Key? key, this.onBuild}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    onBuild?.call();

    // Select computed/derived values
    final summary = context.select((st) => {
      'userName': st.user.name,
      'itemCount': st.items.length,
      'isAdult': st.user.age >= 18,
    });

    return Text('Summary: $summary');
  }
}

// Widget that selects lists
class ListSelectWidget extends StatelessWidget {
  final Function()? onBuild;

  const ListSelectWidget({Key? key, this.onBuild}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    onBuild?.call();

    // Select filtered list
    final longItems = context.select(
          (state) => state.items.where((item) => item.length > 5).toList(),
    );

    return Text('Long items: ${longItems.join(', ')}');
  }
}
