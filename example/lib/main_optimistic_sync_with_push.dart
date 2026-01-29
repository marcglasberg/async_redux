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
/// ### 7. Persistence
/// Close and restart the app. The last known state is persisted using
/// shared_preferences (see class [MyPersistor] below) and restored on startup.
/// When using PUSH, we must persist the server revision as well to ensure
/// correct operation across app restarts.
///
/// Note: If you DO NOT use push, try mixins [OptimisticSync] or
/// [OptimisticCommand] instead. They are much easier to implement since they
/// don't require revision tracking.
///
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:async_redux/async_redux.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:shared_preferences/shared_preferences.dart';

late Store<AppState> store;
late MyPersistor persistor;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Create the persistor.
  persistor = MyPersistor();

  // Load persisted state.
  var initialState = await persistor.readState();

  // If no persisted state exists, create the default initial state and save it.
  if (initialState == null) {
    initialState = AppState(liked: false);
    await persistor.saveInitialState(initialState);
  }

  // Initialize the server SIMULATION, by setting the like and revision counter.
  // In production, this would be the real server, using a database.
  // The key is (ToggleLike, null) as computed by computeOptimisticSyncKey().
  server.revisionCounter = initialState.getServerRevision((ToggleLike, null));
  server.databaseLiked = initialState.liked;

  store = Store<AppState>(
    initialState: initialState,
    actionObservers: [ConsoleActionObserver()],
    persistor: persistor,
  );
  runApp(const MyApp());
}

class AppState {
  final bool liked;

  /// Stores the last known server revision for each [OptimisticSyncWithPush]
  /// action. Keys are stringified versions of action keys (e.g.,
  /// "(ToggleLike, null)"). It's persisted with [MyPersistor] to maintain
  /// correct operation across app restarts. The mixin uses these revisions to
  /// detect stale push updates and ensure eventual consistency.
  final IMap<String, int> serverRevisionMap;

  AppState({required this.liked, IMap<String, int>? serverRevisionMap})
      : serverRevisionMap = serverRevisionMap ?? const IMapConst({});

  @useResult
  AppState copy({bool? isLiked, IMap<String, int>? serverRevisionMap}) =>
      AppState(
        liked: isLiked ?? this.liked,
        serverRevisionMap: serverRevisionMap ?? this.serverRevisionMap,
      );

  /// Returns a copy of the state with the server revision updated for the given key.
  @useResult
  AppState withServerRevision(Object? key, int revision) => copy(
        serverRevisionMap: serverRevisionMap.add(
          _keyToString(key),
          revision,
        ),
      );

  /// Returns the server revision for the given key, or -1 if not found.
  int getServerRevision(Object? key) =>
      serverRevisionMap.get(_keyToString(key)) ?? -1;

  Map<String, dynamic> toJson() => {
        'liked': liked,
        'serverRevisionMap': serverRevisionMap.unlock,
      };

  factory AppState.fromJson(Map<String, dynamic> json) => AppState(
        liked: json['liked'] as bool? ?? false,
        serverRevisionMap: IMap<String, int>.fromEntries(
          (json['serverRevisionMap'] as Map<String, dynamic>? ?? {})
              .entries
              .map((e) => MapEntry(e.key, e.value as int)),
        ),
      );

  @override
  String toString() =>
      'AppState(liked: $liked, serverRevisionMap: $serverRevisionMap)';
}

/// Converts an action key to a String for persistence.
/// The key is typically the runtimeType of the action, or a custom identifier for keyed actions.
String _keyToString(Object? key) => key?.toString() ?? '_default_';

/// Persistor that saves AppState to shared_preferences.
class MyPersistor extends Persistor<AppState> {
  static const _key = 'app_state';

  @override
  Future<AppState?> readState() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null) return null;
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      print('Loaded AppState from prefs: $json');
      return AppState.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> deleteState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  @override
  Future<void> persistDifference({
    required AppState? lastPersistedState,
    required AppState newState,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(newState.toJson());
    await prefs.setString(_key, json);
  }

  /// Short throttle for this demo to save changes quickly.
  @override
  Duration? get throttle => const Duration(milliseconds: 300);
}

/// Represents the server's response including the revision number.
class ServerResponse {
  final bool liked;
  final int serverRevision;
  final int localRevision;
  final int deviceId;

  ServerResponse({
    required this.liked,
    required this.serverRevision,
    required this.localRevision,
    required this.deviceId,
  });
}

/// ServerPush action for handling WebSocket push updates.
/// This action properly integrates with [OptimisticSyncWithPush].
class PushLikeUpdate extends AppAction with ServerPush {
  final bool liked;
  final int serverRev;
  final int localRev;
  final int deviceId;

  PushLikeUpdate({
    required this.liked,
    required this.serverRev,
    required this.localRev,
    required this.deviceId,
  });

  /// Return the Type of the associated OptimisticSyncWithPush action.
  @override
  Type associatedAction() => ToggleLike;

  @override
  PushMetadata pushMetadata() {
    print('Incoming metadata: ${(
      serverRevision: serverRev,
      localRevision: localRev,
      deviceId: deviceId,
    )}');

    return (
      serverRevision: serverRev,
      localRevision: localRev,
      deviceId: deviceId,
    );
  }

  /// Apply the pushed data to state and save the revision.
  @override
  AppState? applyServerPushToState(
    AppState state,
    Object? key,
    int serverRevision,
  ) =>
      state.copy(isLiked: liked).withServerRevision(key, serverRevision);

  /// Return the current server revision from state for this key.
  @override
  int getServerRevisionFromState(Object? key) => state.getServerRevision(key);

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
    AppState state,
    bool optimisticValueToApply,
  ) =>
      state.copy(isLiked: optimisticValueToApply);

  @override
  AppState? applyServerResponseToState(AppState state, Object? serverResponse) {
    // Apply both the liked value and the server revision.
    // Use computeOptimisticSyncKey() to get the same key used by the mixin.
    return state
        .copy(isLiked: serverResponse as bool)
        .withServerRevision(computeOptimisticSyncKey(), _serverRevFromResponse);
  }

  @override
  Future<bool> sendValueToServer(
    Object? optimisticValue,
    int localRevision,
    int deviceId,
  ) async {
    print('Sending to server: $optimisticValue');
    // Send to server and get response with revision.
    final response = await server.saveLike(
      optimisticValue as bool,
      localRevision,
      deviceId,
    );

    // Store the server revision for use in applyServerResponseToState.
    print('Server response: $response');

    // Inform the mixin about the server revision.
    informServerRevision(response.serverRevision);

    return response.liked;
  }

  /// Return the current server revision from state.
  @override
  int getServerRevisionFromState(Object? key) => state.getServerRevision(key);

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

/// Resets all state: deletes persisted state and resets server simulation.
class ResetAllState extends AppAction {
  @override
  Future<AppState?> reduce() async {
    // Delete persisted state.
    await persistor.deleteState();

    // Reset server simulation.
    server.reset();

    // Return fresh initial state.
    return AppState(liked: false);
  }
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
      appBar: AppBar(
        title: const Text('OptimisticSyncWithPush Mixin Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: 'Reset all state',
            onPressed: () => store.dispatch(ResetAllState()),
          ),
        ],
      ),
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
                          'UI State (AsyncRedux)',
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
  Future<ServerResponse> saveLike(
    bool flag,
    int localRevision,
    int deviceId,
  ) async {
    print('Save started');
    requestCount++;
    isRequestInProgress = true;
    print('flag = $flag, localRev = $localRevision, deviceId = $deviceId');
    await _interruptibleDelay(delayBeforeWrite);

    // Save flag and increment server revision (simulate server-side versioning).
    databaseLiked = flag;
    revisionCounter++;
    final currentServerRev = revisionCounter;

    print(
        'flag = $flag, serverRev = $currentServerRev, localRev = $localRevision, deviceId = $deviceId');
    if (websocketPushEnabled)
      push(
        isLiked: flag,
        serverRev: currentServerRev,
        localRev: localRevision,
        deviceId: deviceId,
      );

    await _interruptibleDelay(delayAfterWrite);
    isRequestInProgress = false;
    print('flag = $flag, serverRev = $currentServerRev');
    print('Save ended');

    return ServerResponse(
      liked: databaseLiked,
      serverRevision: currentServerRev,
      localRevision: localRevision,
      deviceId: deviceId,
    );
  }

  /// Simulates reloading the current value from the database.
  Future<bool> reload() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return databaseLiked;
  }

  /// Simulates a WebSocket push from the server to the client.
  Future<void> push({
    required bool isLiked,
    required int serverRev,
    required int localRev,
    required int deviceId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
    store.dispatch(PushLikeUpdate(
      liked: isLiked,
      serverRev: serverRev,
      localRev: localRev,
      deviceId: deviceId,
    ));
  }

  /// Simulates an external change to the database (e.g., from another client).
  void simulateExternalChange(bool liked) {
    databaseLiked = liked;
    if (websocketPushEnabled) {
      revisionCounter++;
      push(
        isLiked: databaseLiked,
        serverRev: revisionCounter,
        localRev: Random().nextInt(4294967296),
        deviceId: Random().nextInt(4294967296),
      );
    }
  }

  /// Resets the server to its initial state.
  void reset() {
    databaseLiked = false;
    isRequestInProgress = false;
    requestCount = 0;
    shouldFail = false;
    revisionCounter = 0;
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
