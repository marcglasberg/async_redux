/// This example is meant to demonstrate the [OptimisticSync] mixin in action.
/// The screen is split into two halves: the top shows the UI state (Redux), and
/// the bottom shows the simulated database state (server).
///
/// ## Use cases to try:
///
/// ### 1. Optimistic update
/// Tap the heart icon. The UI updates instantly (top half), while the database
/// takes ~3.5 seconds to update (bottom half shows "Saving...").
///
/// ### 2. Coalescing (key feature)
/// Tap the heart rapidly multiple times while "Saving..." is displayed. Notice:
/// - The UI toggles instantly on each tap (always responsive).
/// - Only one request is in flight at a time ("Saving 1...").
/// - When the request completes, if the current UI state differs from what was
///   sent, a follow-up request is automatically sent ("Saving 2...").
/// - If you toggle an even number of times, no follow-up is needed because the
///   final state matches what was originally sent.
///
/// ### 3. Button always enabled
/// Unlike [OptimisticCommand], the button is never disabled. This allows rapid
/// interactions without waiting for server responses.
///
/// ### 4. Reload on error
/// Tap the heart to start saving. While "Saving..." is displayed, tap "Request
/// fails". The UI keeps its optimistic state, but [OptimisticSync.onFinish] is
/// called with the error. In this example, we show an error dialog,
/// immediately revert to the initial state before the action, and then,
/// just to be sure, reload the value from the database.
///
/// ### 5. External database changes (no push)
/// Use the "Liked" or "Not Liked" buttons at the bottom to change the database
/// directly. The UI may update only if a request is still in progress, because
/// the request response will overwrite the UI state when it completes.
/// But when there is no request in progress, the UI state won't update,
/// because [OptimisticSync] doesn't support push notifications. The UI only
/// syncs when you tap the heart again.
///
/// Note: If you use push, try mixin [OptimisticSyncWithPush] instead.
///
import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import "package:meta/meta.dart";

late Store<AppState> store;

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
  Future<bool> sendValueToServer(Object? value) =>
      server.saveLike(value as bool);

  // If there was an error:
  // 1. Show an error message to the user.
  // 2. Immediately revert to the initial state before the action.
  // 3. Then, to be sure, reload the value from the database.
  @override
  Future<AppState?> onFinish(Object? error) async {
    if (error == null) return null;

    // 1. Show an error message to the user.
    dispatch(
      UserExceptionAction('The server request failed',
          reason: 'The like status was rolled back and then reloaded.'),
    );

    // 2. Immediately rollback to the initial state before the action.
    dispatchState(state.copy(isLiked: getValueFromState(initialState)));

    // 3. Then, to be sure, reload the value from the database.
    bool isLiked = await server.reload();
    return state.copy(isLiked: isLiked);
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
        debugShowCheckedModeBanner: false,
        title: 'OptimisticSync Mixin Demo',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: UserExceptionDialog<AppState>(
          child: const MyHomePage(),
        ),
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
                      server.databaseLiked
                          ? Icons.favorite
                          : Icons.favorite_border,
                      size: 80,
                      color: server.databaseLiked ? Colors.red : Colors.grey,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      server.databaseLiked ? 'Liked' : 'Not Liked',
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          server.isRequestInProgress
                              ? 'Saving ${server.requestCount}...'
                              : 'Idle',
                          style: TextStyle(
                            fontSize: 16,
                            color: server.isRequestInProgress
                                ? Colors.orange
                                : Colors.grey,
                            fontWeight: server.isRequestInProgress
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (server.isRequestInProgress)
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
                      'Updates after server round-trip (${(server.delayBeforeWrite + server.delayAfterWrite) / 1000}s)',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Number of requests received: ${server.requestCount}',
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
                                onPressed: () =>
                                    server.simulateExternalChange(true),
                                icon: const Icon(Icons.favorite, size: 16),
                                label: const Text('Liked'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade100,
                                  foregroundColor: Colors.red.shade900,
                                ),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton.icon(
                                onPressed: () =>
                                    server.simulateExternalChange(false),
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
                            onPressed: server.isRequestInProgress
                                ? () {
                                    server.shouldFail = true;
                                  }
                                : null,
                            icon: const Icon(Icons.error_outline, size: 16),
                            label: const Text('Request fails'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade100,
                              foregroundColor: Colors.orange.shade900,
                            ),
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

// ////////////////////////////////////////////////////////////////////////////

/// Singleton instance of the simulated server.
final server = SimulatedServer();

/// Simulates a remote server with database and request handling.
/// All server-side state and behavior is encapsulated here to clearly separate
/// it from the local app state managed by Redux.
class SimulatedServer {
  // ---------------------------------------------------------------------------
  // Server State
  // ---------------------------------------------------------------------------

  /// The "database" value stored on the server.
  bool databaseLiked = false;

  /// Whether a request is currently being processed.
  bool isRequestInProgress = false;

  /// Total number of requests received by the server.
  int requestCount = 0;

  /// When true, the next request will fail (for testing error handling).
  bool shouldFail = false;

  /// Simulated network delay before writing to database (ms).
  int delayBeforeWrite = 1500;

  /// Simulated network delay after writing to database (ms).
  int delayAfterWrite = 2000;

  // ---------------------------------------------------------------------------
  // Server Methods
  // ---------------------------------------------------------------------------

  /// Simulates saving to the database.
  /// Returns the current database value after save completes.
  Future<bool> saveLike(bool flag) async {
    requestCount++;
    isRequestInProgress = true;
    await _interruptibleDelay(delayBeforeWrite);

    databaseLiked = flag;
    await _interruptibleDelay(delayAfterWrite);
    isRequestInProgress = false;

    // Return the current value in the database.
    // This may differ from the saved value, simulating server-side logic.
    return databaseLiked;
  }

  /// Simulates reloading the current value from the database.
  Future<bool> reload() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return databaseLiked;
  }

  /// Simulates an external change to the database (e.g., from another client).
  void simulateExternalChange(bool liked) {
    databaseLiked = liked;
  }

  /// Interruptible delay that checks [shouldFail] every 50ms.
  /// Allows simulating mid-flight request failures.
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
}
