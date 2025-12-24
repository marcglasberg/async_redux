/// This example is meant to demonstrate the [OptimisticSyncWithPush] mixin in
/// action. The screen is split into two halves: the top shows the UI state
/// (Redux), and the bottom shows the simulated database state (server).
///
/// ## Use cases to try:
///
/// ### 1. Optimistic update
/// Tap the heart icon. The UI updates instantly (top half), while the database
/// takes ~3.5 seconds to update (bottom half shows "Saving...").
///
/// ### 2. Coalescing
/// Tap the heart rapidly multiple times while "Saving..." is displayed. Notice:
/// - The UI toggles instantly on each tap (always responsive).
/// - Only one request is in flight at a time ("Saving 1...").
/// - When the request completes, if the current UI state differs from what was
///   sent, a follow-up request is automatically sent ("Saving 2...").
///
/// ### 3. Push updates (key feature)
/// With "Push database changes" switch ON (default), tap "Liked" or "Not Liked"
/// buttons to simulate an external change from another device. The UI updates
/// immediately via the simulated WebSocket push. This is the key difference
/// from [OptimisticSync], which doesn't support push.
///
/// ### 4. Push disabled behavior
/// Turn OFF the "Push database changes" switch, then tap "Liked" or "Not Liked".
/// The database changes but the UI doesn't update (no push). The UI only syncs
/// when you tap the heart again.
///
/// ### 5. Push during in-flight request
/// With push ON, tap the heart to start saving. While "Saving..." is displayed,
/// tap "Liked" or "Not Liked" to simulate an external change. Notice how the
/// mixin handles the race condition using revision tracking, ensuring eventual
/// consistency.
///
/// ### 6. Reload on error
/// Tap the heart to start saving. While "Saving..." is displayed, tap "Request
/// fails". The UI keeps its optimistic state, but [OptimisticSyncWithPush.onFinish]
/// is called with the error. In this example, we reload from the database
/// to restore the correct state.
///
import 'dart:async';
import 'dart:convert';

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:shared_preferences/shared_preferences.dart';

late Store<AppState> store;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load persisted state
  final initialState = await loadAppState();

  // Initialize server revision counter from persisted state.
  // In production, this would come from the server on reconnect.
  server.revisionCounter = initialState.serverRevision;

  store = Store<AppState>(
    initialState: initialState,
    actionObservers: [ConsoleActionObserver()],
  );
  runApp(const MyApp());
}

class AppState {
  final bool liked;
  final int serverRevision;

  AppState({required this.liked, this.serverRevision = 0});

  @useResult
  AppState copy({bool? isLiked, int? serverRevision}) => AppState(
        liked: isLiked ?? this.liked,
        serverRevision: serverRevision ?? this.serverRevision,
      );

  Map<String, dynamic> toJson() => {
        'liked': liked,
        'serverRevision': serverRevision,
      };

  factory AppState.fromJson(Map<String, dynamic> json) => AppState(
        liked: json['liked'] as bool? ?? false,
        serverRevision: json['serverRevision'] as int? ?? 0,
      );

  @override
  String toString() =>
      'AppState(liked: $liked, serverRevision: $serverRevision)';
}

/// Saves AppState to shared_preferences.
Future<void> saveAppState(AppState state) async {
  final prefs = await SharedPreferences.getInstance();
  final json = jsonEncode(state.toJson());
  await prefs.setString('app_state', json);
}

/// Loads AppState from shared_preferences.
Future<AppState> loadAppState() async {
  final prefs = await SharedPreferences.getInstance();
  final jsonString = prefs.getString('app_state');
  if (jsonString == null) {
    return AppState(liked: false, serverRevision: 0);
  }
  try {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    print('Loaded AppState from prefs: $json');
    return AppState.fromJson(json);
  } catch (e) {
    return AppState(liked: false, serverRevision: 0);
  }
}

/// Represents the server's response including the revision number.
class ServerResponse {
  final bool liked;
  final int serverRevision;

  ServerResponse({required this.liked, required this.serverRevision});
}

/// ServerPush action for handling WebSocket push updates.
/// This action properly integrates with OptimisticSyncWithPush.
class PushLikeUpdate extends AppAction with ServerPush<AppState> {
  final bool liked;
  final int serverRev;

  PushLikeUpdate({required this.liked, required this.serverRev});

  /// Return the Type of the associated OptimisticSyncWithPush action.
  @override
  Type associatedAction() => ToggleLike;

  /// Return the revision number that came with the push.
  @override
  int serverRevision() => serverRev;

  /// Apply the pushed data to state and save the revision.
  @override
  AppState? applyServerPushToState(
      AppState state, Object? key, int serverRevision) {
    final newState = state.copy(isLiked: liked, serverRevision: serverRevision);
    // Persist the state asynchronously (fire and forget is OK for persistence).
    saveAppState(newState);
    return newState;
  }

  /// Return the current server revision from state for this key.
  @override
  int? getServerRevisionFromState(Object? key) {
    return state.serverRevision;
  }

  @override
  String toString() =>
      '${super.toString()}(liked: $liked, serverRev: $serverRev)';
}

class ToggleLike extends AppAction with OptimisticSyncWithPush<AppState, bool> {
  // Store the server revision from the response.
  int _serverRevFromResponse = 0;

  @override
  bool valueToApply() => !state.liked;

  @override
  bool getValueFromState(AppState state) => state.liked;

  @override
  AppState applyOptimisticValueToState(
          AppState state, bool optimisticValueToApply) =>
      state.copy(isLiked: optimisticValueToApply);

  @override
  AppState? applyServerResponseToState(AppState state, Object? serverResponse) {
    // Apply both the liked value and the server revision.
    final newState = state.copy(
      isLiked: serverResponse as bool,
      serverRevision: _serverRevFromResponse,
    );
    // Persist the state.
    saveAppState(newState);
    return newState;
  }

  @override
  Future<bool> sendValueToServer(Object? value) async {
    // CRITICAL: Call localRevision() BEFORE any await!
    // This captures the revision number before any async operations.
    int localRev = localRevision();

    // Send to server and get response with revision.
    final response = await server.saveLike(value as bool, localRev);

    // Store the server revision for use in applyServerResponseToState.
    _serverRevFromResponse = response.serverRevision;

    // Inform the mixin about the server revision.
    informServerRevision(response.serverRevision);

    return response.liked;
  }

  /// Return the current server revision from state.
  @override
  int? getServerRevisionFromState(Object? key) {
    return state.serverRevision;
  }

  // If there was an error, revert the state to the database value.
  @override
  Future<AppState?> onFinish(Object? error) async {
    if (error == null) return null;

    // If there was an error, reload the value from the database.
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
        title: 'OptimisticSyncWithPush Mixin Demo',
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
                                value: server.websocketPushEnabled,
                                onChanged: (value) {
                                  setState(() {
                                    server.websocketPushEnabled = value;
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

// ////////////////////////////////////////////////////////////////////////////

/// Singleton instance of the simulated server.
final server = SimulatedServer();

/// Simulates a remote server with database, WebSocket push, and request handling.
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

  /// Whether the server should push changes via "WebSocket" after writes.
  bool websocketPushEnabled = true;

  /// Server-side revision counter. Incremented on each successful write.
  /// In production, this would be managed by the actual server/database.
  int revisionCounter = 0;

  /// Simulated network delay before writing to database (ms).
  int delayBeforeWrite = 1500;

  /// Simulated network delay after writing to database (ms).
  int delayAfterWrite = 2000;

  // ---------------------------------------------------------------------------
  // Server Methods
  // ---------------------------------------------------------------------------

  /// Simulates saving to the database.
  /// Returns a [ServerResponse] with the current liked value and server revision.
  Future<ServerResponse> saveLike(bool flag, int clientLocalRev) async {
    print('Save started');
    requestCount++;
    isRequestInProgress = true;
    print('flag = $flag, clientLocalRev = $clientLocalRev');
    await _interruptibleDelay(delayBeforeWrite);

    // Save flag and increment server revision (simulate server-side versioning).
    databaseLiked = flag;
    revisionCounter++;
    final currentServerRev = revisionCounter;

    print('flag = $flag, serverRev = $currentServerRev');
    if (websocketPushEnabled) push(isLiked: flag, serverRev: currentServerRev);

    await _interruptibleDelay(delayAfterWrite);
    isRequestInProgress = false;
    print('flag = $flag, serverRev = $currentServerRev');
    print('Save ended');

    return ServerResponse(
      liked: databaseLiked,
      serverRevision: currentServerRev,
    );
  }

  /// Simulates reloading the current value from the database.
  Future<bool> reload() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return databaseLiked;
  }

  /// Simulates a WebSocket push from the server to the client.
  Future<void> push({required bool isLiked, required int serverRev}) async {
    await Future.delayed(const Duration(milliseconds: 50));
    store.dispatch(PushLikeUpdate(liked: isLiked, serverRev: serverRev));
  }

  /// Simulates an external change to the database (e.g., from another client).
  void simulateExternalChange(bool liked) {
    databaseLiked = liked;
    if (websocketPushEnabled) {
      revisionCounter++;
      push(isLiked: databaseLiked, serverRev: revisionCounter);
    }
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
