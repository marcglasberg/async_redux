import 'dart:math';

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';

// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

late Store<AppState> store;

/// This example demonstrates the [Polling] mixin with all [Poll] enum values:
///
/// - [Poll.start] — Starts polling and runs reduce immediately. If polling is
///   already active, does nothing.
///
/// - [Poll.stop] — Cancels the timer and skips reduce.
///
/// - [Poll.runNowAndRestart] — Runs reduce immediately and restarts the timer
///   from that moment. If polling is not active, behaves like [Poll.start].
///
/// - [Poll.once] — Runs reduce immediately without starting, stopping, or
///   restarting polling.
///
/// The app simulates polling a stock price every 3 seconds. Four buttons
/// demonstrate each [Poll] value, and the UI shows the current price,
/// how many times it has been fetched, and whether polling is active.
///
void main() {
  store = Store<AppState>(initialState: AppState.initialState());
  runApp(MyApp());
}

// =============================================================================
// State
// =============================================================================

@immutable
class AppState {
  final double price;
  final int fetchCount;
  final bool isPolling;

  AppState({
    required this.price,
    required this.fetchCount,
    required this.isPolling,
  });

  AppState copy({double? price, int? fetchCount, bool? isPolling}) => AppState(
        price: price ?? this.price,
        fetchCount: fetchCount ?? this.fetchCount,
        isPolling: isPolling ?? this.isPolling,
      );

  static AppState initialState() => AppState(
        price: 100.0,
        fetchCount: 0,
        isPolling: false,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppState &&
          runtimeType == other.runtimeType &&
          price == other.price &&
          fetchCount == other.fetchCount &&
          isPolling == other.isPolling;

  @override
  int get hashCode => price.hashCode ^ fetchCount.hashCode ^ isPolling.hashCode;
}

// =============================================================================
// App
// =============================================================================

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => StoreProvider<AppState>(
        store: store,
        child: MaterialApp(
          home: MyHomePage(),
        ),
      );
}

// =============================================================================
// Actions
// =============================================================================

/// A polling action that simulates fetching a stock price.
///
/// This uses "Option 1" (single action for everything): the same action class
/// both controls polling and does the work. The [createPollingAction] returns
/// the same action type with [Poll.once], so timer ticks run reduce without
/// restarting the timer.
class PollStockPriceAction extends ReduxAction<AppState> with Polling {
  @override
  final Poll poll;

  PollStockPriceAction({this.poll = Poll.once});

  @override
  Duration get pollInterval => const Duration(seconds: 3);

  @override
  ReduxAction<AppState> createPollingAction() => PollStockPriceAction(poll: Poll.once);

  /// Update the [isPolling] flag in state whenever the polling status changes.
  @override
  void before() {
    switch (poll) {
      case Poll.start:
      case Poll.runNowAndRestart:
        dispatch(SetPollingFlagAction(true));
      case Poll.stop:
        dispatch(SetPollingFlagAction(false));
      case Poll.once:
        break;
    }
  }

  @override
  AppState reduce() {
    // Simulate a price change: random walk around the current price.
    final random = Random();
    final change = (random.nextDouble() - 0.5) * 4; // -2.0 to +2.0
    final newPrice = (state.price + change).clamp(50.0, 200.0);

    return state.copy(
      price: double.parse(newPrice.toStringAsFixed(2)),
      fetchCount: state.fetchCount + 1,
    );
  }
}

/// Marks polling as active or inactive in the state (so the UI can reflect it).
class SetPollingFlagAction extends ReduxAction<AppState> {
  final bool isPolling;

  SetPollingFlagAction(this.isPolling);

  @override
  AppState reduce() => state.copy(isPolling: isPolling);
}

// =============================================================================
// Home page
// =============================================================================

class MyHomePage extends StatelessWidget {
  MyHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var price = context.select((AppState s) => s.price);
    var fetchCount = context.select((AppState s) => s.fetchCount);
    var isPolling = context.select((AppState s) => s.isPolling);

    return Scaffold(
      appBar: AppBar(title: const Text('Polling Mixin Example')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Price display
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text('Stock Price',
                        style: TextStyle(fontSize: 16, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text(
                      '\$${price.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('Fetched $fetchCount time${fetchCount == 1 ? '' : 's'}'),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isPolling ? Icons.sync : Icons.sync_disabled,
                          color: isPolling ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isPolling ? 'Polling active (every 3s)' : 'Polling inactive',
                          style: TextStyle(color: isPolling ? Colors.green : Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            const Text('Poll values:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // Poll.start
            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Poll.start'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () => dispatch(PollStockPriceAction(poll: Poll.start)),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 16, bottom: 12, top: 4),
              child: Text(
                'Starts polling and runs reduce immediately. '
                'If polling is already active, does nothing.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),

            // Poll.stop
            ElevatedButton.icon(
              icon: const Icon(Icons.stop),
              label: const Text('Poll.stop'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => dispatch(PollStockPriceAction(poll: Poll.stop)),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 16, bottom: 12, top: 4),
              child: Text(
                'Cancels the timer and skips reduce.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),

            // Poll.runNowAndRestart
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Poll.runNowAndRestart'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () =>
                  dispatch(PollStockPriceAction(poll: Poll.runNowAndRestart)),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 16, bottom: 12, top: 4),
              child: Text(
                'Runs reduce immediately and restarts the timer from now. '
                'If not active, behaves like Poll.start.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),

            // Poll.once
            ElevatedButton.icon(
              icon: const Icon(Icons.looks_one),
              label: const Text('Poll.once'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              onPressed: () => dispatch(PollStockPriceAction(poll: Poll.once)),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 16, bottom: 12, top: 4),
              child: Text(
                'Runs reduce immediately without starting, stopping, '
                'or restarting polling.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// BuildContext extension
// =============================================================================

extension BuildContextExtension on BuildContext {
  AppState get state => getState<AppState>();

  AppState read() => getRead<AppState>();

  R select<R>(R Function(AppState state) selector) => getSelect<AppState, R>(selector);
}
