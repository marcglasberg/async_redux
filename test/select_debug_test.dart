// Exploratory test to debug the select() rebuild issue

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Recommended to create this extension.
extension BuildContextExtension on BuildContext {
  TestState get state => getState<TestState>();
  TestState read() => getRead<TestState>();
  R select<R>(R Function(TestState state) selector) => getSelect<TestState, R>(selector);
}

// Simple test state
class TestState {
  final int counter;
  final String text;
  final bool flag;

  TestState({
    required this.counter,
    required this.text,
    required this.flag,
  });

  TestState copyWith({
    int? counter,
    String? text,
    bool? flag,
  }) {
    return TestState(
      counter: counter ?? this.counter,
      text: text ?? this.text,
      flag: flag ?? this.flag,
    );
  }

  @override
  String toString() => 'TestState(counter: $counter, text: $text, flag: $flag)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TestState &&
        other.counter == counter &&
        other.text == text &&
        other.flag == flag;
  }

  @override
  int get hashCode => Object.hash(counter, text, flag);
}

// Test actions
class IncrementAction extends ReduxAction<TestState> {
  @override
  TestState reduce() => state.copyWith(counter: state.counter + 1);
}

class ChangeTextAction extends ReduxAction<TestState> {
  final String text;
  ChangeTextAction(this.text);

  @override
  TestState reduce() => state.copyWith(text: text);
}

class ToggleFlagAction extends ReduxAction<TestState> {
  @override
  TestState reduce() => state.copyWith(flag: !state.flag);
}

// Test widgets with tracking
class CounterSelectWidget extends StatelessWidget {
  final List<String> buildLog;

  const CounterSelectWidget({Key? key, required this.buildLog}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    buildLog.add('CounterSelectWidget.build()');
    print('\n=== CounterSelectWidget BUILD ===');

    final counter = context.select((st) {
      print('  [Selector executing] Selecting counter: ${st.counter}');
      return st.counter;
    });

    print('  Selected value: $counter');
    print('=== CounterSelectWidget BUILD END ===\n');

    return Text('Counter: $counter');
  }
}

class FlagSelectWidget extends StatelessWidget {
  final List<String> buildLog;

  const FlagSelectWidget({Key? key, required this.buildLog}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    buildLog.add('FlagSelectWidget.build()');
    print('\n=== FlagSelectWidget BUILD ===');

    final flag = context.select((st) {
      print('  [Selector executing] Selecting flag: ${st.flag}');
      return st.flag;
    });

    print('  Selected value: $flag');
    print('=== FlagSelectWidget BUILD END ===\n');

    return Text('Flag: $flag');
  }
}

class RegularStateWidget extends StatelessWidget {
  final List<String> buildLog;

  const RegularStateWidget({Key? key, required this.buildLog}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    buildLog.add('RegularStateWidget.build()');
    print('\n=== RegularStateWidget BUILD ===');

    final state = context.getState<TestState>();

    print('  Got state: $state');
    print('=== RegularStateWidget BUILD END ===\n');

    return Text('State: $state');
  }
}

void main() {
  group('Select Debug Investigation', () {
    testWidgets('Track dependency lifecycle and rebuild behavior', (WidgetTester tester) async {
      // 
      print('\n' + '='*80);
      print('STARTING SELECT DEBUG TEST');
      print('='*80 + '\n');

      // Create initial state
      final initialState = TestState(counter: 0, text: 'hello', flag: false);
      final store = Store<TestState>(initialState: initialState);

      // Track builds
      final counterBuilds = <String>[];
      final flagBuilds = <String>[];
      final regularBuilds = <String>[];

      print('>>> INITIAL WIDGET TREE BUILD\n');

      // Build the widget tree
      await tester.pumpWidget(
        MaterialApp(
          home: StoreProvider<TestState>(
            store: store,
            child: Scaffold(
              body: Column(
                children: [
                  CounterSelectWidget(buildLog: counterBuilds),
                  FlagSelectWidget(buildLog: flagBuilds),
                  RegularStateWidget(buildLog: regularBuilds),
                ],
              ),
            ),
          ),
        ),
      );

      print('\n>>> INITIAL BUILD COMPLETE');
      print('Counter builds: ${counterBuilds.length}');
      print('Flag builds: ${flagBuilds.length}');
      print('Regular builds: ${regularBuilds.length}');

      // Clear build logs for next phase
      counterBuilds.clear();
      flagBuilds.clear();
      regularBuilds.clear();

      print('\n' + '-'*80);
      print('>>> ACTION 1: INCREMENT COUNTER');
      print('-'*80 + '\n');

      // Dispatch increment action
      store.dispatch(IncrementAction());
      await tester.pump();

      print('\n>>> AFTER INCREMENT:');
      print('Counter rebuilds: ${counterBuilds.length} ${counterBuilds.isNotEmpty ? "✓" : "✗"}');
      print('Flag rebuilds: ${flagBuilds.length} ${flagBuilds.isEmpty ? "✓" : "✗ UNEXPECTED!"}');
      print('Regular rebuilds: ${regularBuilds.length} ${regularBuilds.isNotEmpty ? "✓" : "✗"}');

      // Clear for next action
      counterBuilds.clear();
      flagBuilds.clear();
      regularBuilds.clear();

      print('\n' + '-'*80);
      print('>>> ACTION 2: TOGGLE FLAG');
      print('-'*80 + '\n');

      // Dispatch toggle action
      store.dispatch(ToggleFlagAction());
      await tester.pump();

      print('\n>>> AFTER TOGGLE:');
      print('Counter rebuilds: ${counterBuilds.length} ${counterBuilds.isEmpty ? "✓" : "✗ UNEXPECTED!"}');
      print('Flag rebuilds: ${flagBuilds.length} ${flagBuilds.isNotEmpty ? "✓" : "✗"}');
      print('Regular rebuilds: ${regularBuilds.length} ${regularBuilds.isNotEmpty ? "✓" : "✗"}');

      // Clear for next action
      counterBuilds.clear();
      flagBuilds.clear();
      regularBuilds.clear();

      print('\n' + '-'*80);
      print('>>> ACTION 3: INCREMENT AGAIN');
      print('-'*80 + '\n');

      // Dispatch another increment
      store.dispatch(IncrementAction());
      await tester.pump();

      print('\n>>> AFTER SECOND INCREMENT:');
      print('Counter rebuilds: ${counterBuilds.length} ${counterBuilds.isNotEmpty ? "✓" : "✗"}');
      print('Flag rebuilds: ${flagBuilds.length} ${flagBuilds.isEmpty ? "✓" : "✗ UNEXPECTED!"}');
      print('Regular rebuilds: ${regularBuilds.length} ${regularBuilds.isNotEmpty ? "✓" : "✗"}');

      print('\n' + '='*80);
      print('TEST COMPLETE');
      print('='*80 + '\n');

      // Assertions to verify expected behavior
      expect(counterBuilds.isNotEmpty, true, reason: 'Counter widget should rebuild on increment');
      expect(flagBuilds.isEmpty, true, reason: 'Flag widget should NOT rebuild on increment');
    });

    testWidgets('Test with different widget creation patterns', (WidgetTester tester) async {
      // Enable debug logging
      print('\n' + '='*80);
      print('TESTING DIFFERENT WIDGET PATTERNS');
      print('='*80 + '\n');

      final initialState = TestState(counter: 0, text: 'hello', flag: false);
      final store = Store<TestState>(initialState: initialState);

      // Test with Builder widgets
      await tester.pumpWidget(
        MaterialApp(
          home: StoreProvider<TestState>(
            store: store,
            child: Scaffold(
              body: Column(
                children: [
                  // Pattern 1: Direct widget
                  Builder(
                    builder: (context) {
                      print('[BUILDER 1] Building counter selector');
                      final counter = context.select((s) => s.counter);
                      return Text('Direct: $counter');
                    },
                  ),
                  // Pattern 2: Wrapped in another Builder
                  Builder(
                    builder: (context) => Builder(
                      builder: (context) {
                        print('[BUILDER 2] Building flag selector');
                        final flag = context.select((s) => s.flag);
                        return Text('Nested: $flag');
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      print('\n>>> DISPATCHING INCREMENT IN BUILDER TEST');
      store.dispatch(IncrementAction());
      await tester.pump();

      print('\n>>> DISPATCHING TOGGLE IN BUILDER TEST');
      store.dispatch(ToggleFlagAction());
      await tester.pump();

      print('\n' + '='*80);
      print('BUILDER TEST COMPLETE');
      print('='*80 + '\n');
    });
  });
}

// Additional test to examine timing
void exploratoryTimingTest() {
  test('Examine microtask timing', () async {
    print('\nMicrotask timing test:');

    int step = 1;
    print('Step $step: Start');
    step++;

    Future.microtask(() {
      print('Step $step: Microtask 1');
      step++;
    });

    print('Step $step: After scheduling microtask');
    step++;

    await Future.delayed(Duration.zero);

    print('Step $step: After Future.delayed(zero)');
    step++;

    Future.microtask(() {
      print('Step $step: Microtask 2');
      step++;
    });

    await Future.microtask(() {
      print('Step $step: Awaited microtask');
      step++;
    });

    print('Step $step: End');
  });
}
