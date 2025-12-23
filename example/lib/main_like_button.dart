import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import "package:meta/meta.dart";

late Store<AppState> store;

/// Simulated database value (not in the Redux store).
bool databaseLiked = false;

/// Whether a request is currently in progress.
bool isRequestInProgress = false;

/// Number of requests received by the server.
int requestCount = 0;

/// Whether the next request should fail.
bool shouldFail = false;

/// Whether websocket should push database changes.
bool websocketPushEnabled = false;

int delayBeforeWriteToDatabase = 1500;
int delayAfterWriteToDatabase = 2000;

/// Interruptible delay that checks shouldFail every 50ms.
Future<void> _interruptibleDelay(int milliseconds) async {
  const checkInterval = 50;
  int remaining = milliseconds;
  while (remaining > 0) {
    if (shouldFail) {
      shouldFail = false;
      isRequestInProgress = false;
      throw Exception('Simulated server error');
    }
    final wait = remaining < checkInterval ? remaining : checkInterval;
    await Future.delayed(Duration(milliseconds: wait));
    remaining -= checkInterval;
  }
}

/// Simulates saving to a database.
/// Waits 500ms, changes the value, then waits 2000ms before returning.
Future<bool> saveLike(bool flag) async {
  print('\nINI------------------------------------------------------------');
  requestCount++;
  isRequestInProgress = true;
  print('flag.a = ${flag}');
  await _interruptibleDelay(delayBeforeWriteToDatabase);

  databaseLiked = flag;
  print('flag.b = ${flag}');
  if (websocketPushEnabled) {
    push(isLiked: flag);
  }
  await _interruptibleDelay(delayAfterWriteToDatabase);
  isRequestInProgress = false;
  print('flag.c = ${flag}');
  print('\nEND------------------------------------------------------------');

  // When the save request is complete, return the current value in the database.
  // This is not necessarily the same as the value we tried to save, simulating
  // a situation where the server has the final say.
  return databaseLiked;
}

Future<bool> reload() async {
  // Simulate a quick reload from the database.
  await Future.delayed(const Duration(milliseconds: 300));
  return databaseLiked;
}

Future<void> push({required bool isLiked}) async {
  await Future.delayed(const Duration(milliseconds: 50));
  store.dispatch(SetLike(isLiked));
}

void main() {
  store = Store<AppState>(
    initialState: AppState(liked: false),
    actionObservers: [ConsoleActionObserver()],
  );
  runApp(const MyApp());
}

class AppState {
  final bool liked;

  AppState({required this.liked});

  @useResult
  AppState copy({bool? isLiked}) => AppState(liked: isLiked ?? this.liked);

  @override
  String toString() => 'AppState(liked: $liked)';
}

class SetLike extends AppAction {
  final bool isLiked;

  SetLike(this.isLiked);

  @override
  AppState reduce() => state.copy(isLiked: isLiked);

  @override
  String toString() => '${super.toString()}($isLiked)';
}

/// TODO: Marcelo: Test if it works with DEBOUNCE!!!!!!!!!!!!
class ToggleLike extends AppAction with OptimisticSync<AppState, bool> {
  @override
  bool valueToApply() => !state.liked;

  @override
  bool getValueFromState(AppState state) => state.liked;

  @override
  AppState applyOptimisticValueToState(
          AppState state, bool optimisticValueToApply) =>
      state.copy(isLiked: optimisticValueToApply);

  @override
  AppState applyServerResponseToState(AppState state, Object? serverResponse) {
    bool isLiked = serverResponse as bool;
    return state.copy(isLiked: isLiked);
  }

  @override
  Future<bool> sendValueToServer(Object? value) => saveLike(value as bool);

  // If there was an error, revert the state to the database value.
  @override
  Future<AppState?> onFinish(Object? error) async {
    //
    // If no error, do nothing.
    if (error == null)
      return null;
    //
    // If there was an error, reload the value from the database.
    else {
      bool isLiked = await reload();
      return state.copy(isLiked: isLiked);
    }
  }

  @override
  String toString() => '${super.toString()}(${!state.liked})';
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StoreProvider<AppState>(
      store: store,
      child: MaterialApp(
        title: 'OptimisticSync Mixin Demo',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const MyHomePage(),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    // Refresh the UI periodically to show the database state.
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OptimisticSync Mixin Demo')),
      body: Column(
        children: [
          // Top half: Like button (Redux state)
          Expanded(
            child: Container(
              color: Colors.blue.shade50,
              child: Center(
                child: StoreConnector<AppState, bool>(
                  converter: (store) => store.state.liked,
                  builder: (context, liked) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'UI State (Async Redux)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        IconButton(
                          iconSize: 80,
                          icon: Icon(
                            liked ? Icons.favorite : Icons.favorite_border,
                            color: liked ? Colors.red : Colors.grey,
                          ),
                          onPressed: () {
                            store.dispatch(ToggleLike());
                          },
                        ),
                        const SizedBox(height: 10),
                        Text(
                          liked ? 'Liked' : 'Not Liked',
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Tap rapidly to see coalescing in action!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          // Divider
          Container(
            height: 2,
            color: Colors.grey.shade400,
          ),
          // Bottom half: Database state
          Expanded(
            child: Container(
              color: Colors.green.shade50,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Database State (Simulated)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Icon(
                      databaseLiked ? Icons.favorite : Icons.favorite_border,
                      size: 80,
                      color: databaseLiked ? Colors.red : Colors.grey,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      databaseLiked ? 'Liked' : 'Not Liked',
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isRequestInProgress
                              ? 'Saving $requestCount...'
                              : 'Idle',
                          style: TextStyle(
                            fontSize: 16,
                            color: isRequestInProgress
                                ? Colors.orange
                                : Colors.grey,
                            fontWeight: isRequestInProgress
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (isRequestInProgress)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.orange,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Updates after server round-trip (${(delayBeforeWriteToDatabase + delayAfterWriteToDatabase) / 1000}s)',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Number of requests received: $requestCount',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Simulate external change to the database:',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () {
                                  databaseLiked = true;
                                  if (websocketPushEnabled) {
                                    push(isLiked: databaseLiked);
                                  }
                                },
                                icon: const Icon(Icons.favorite, size: 16),
                                label: const Text('Liked'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade100,
                                  foregroundColor: Colors.red.shade900,
                                ),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  databaseLiked = false;
                                  if (websocketPushEnabled) {
                                    push(isLiked: databaseLiked);
                                  }
                                },
                                icon:
                                    const Icon(Icons.favorite_border, size: 16),
                                label: const Text('Not Liked'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey.shade200,
                                  foregroundColor: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              shouldFail = true;
                            },
                            icon: const Icon(Icons.error_outline, size: 16),
                            label: const Text('Request fails'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade100,
                              foregroundColor: Colors.orange.shade900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Push database changes',
                                style: TextStyle(fontSize: 14),
                              ),
                              const SizedBox(width: 8),
                              Switch(
                                value: websocketPushEnabled,
                                onChanged: (value) {
                                  setState(() {
                                    websocketPushEnabled = value;
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

abstract class AppAction extends ReduxAction<AppState> {}
