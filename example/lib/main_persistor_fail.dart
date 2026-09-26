// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux
import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';

/// This example lets you manually test what happens when the [Persistor] fails,
/// both when the app opens (reading the state), and when the state changes (saving it).
///
/// The app state is simply a counter. The persistor saves it to a fake "disk",
/// which lives in memory. The disk survives the app restarts you do with the
/// "Restart app" button, but not a real restart of the app.
///
/// The counter is saved to the disk as `v2:<counter>`, for example `v2:5`.
///
/// ## Failing when the app opens
///
/// Tap "Write old format" or "Write garbage", and then "Restart app":
///
/// - "Write old format" writes `v1:<counter>`, which is the format of an "old version"
///   of the app. When reading it, the persistor deletes it, and calls `addError` with a
///   `UserException`. A dialog should open when the app restarts.
///
/// - "Write garbage" writes something that can't be read at all. The persistor deletes it,
///   and calls `addError` with a `FormatException`. This is NOT a `UserException`, but the
///   `GlobalErrorObserver` converts it into one. A dialog should open when the app restarts.
///
/// ## Failing when the state changes
///
/// Choose what happens when saving, and then tap the "+" button to change the state:
///
/// - "Saves OK": The new counter is saved to the disk, and no dialog opens.
///
/// - "Throws UserException": `persistDifference` throws a `UserException`.
///   A dialog should open.
///
/// - "Throws StateError": `persistDifference` throws a `StateError`, which is NOT a
///   `UserException`, but the `GlobalErrorObserver` converts it into one.
///   A dialog should open.
///
/// - "Throws TimeoutException": `persistDifference` throws a `TimeoutException`, and the
///   persistor's `wrapError` converts it into a `UserException`. A dialog should open.
///
/// - "Throws ArgumentError": `persistDifference` throws an `ArgumentError`, which is NOT
///   converted. No dialog opens. Instead, the error is thrown as an unhandled async error,
///   which you can see in the console.
///
/// When saving fails, the counter on the disk does not change. When saving works again,
/// the next save will persist the newest counter.
///
/// If you write bad data to the disk, choose a failing behavior, and restart the app,
/// the bad data is deleted, and then the initial state can't be saved. Two dialogs
/// should open when the app restarts: One for the bad data, and one for the failed save.
///
/// Note: All errors are also printed to the console by the `GlobalErrorObserver`.
///
void main() => runApp(MyApp());

/// The fake "disk", which lives in memory.
final disk = ValueNotifier<String?>(null);

/// What happens when saving the state.
enum SaveBehavior {
  savesOk('Saves OK'),
  throwsUserException('Throws UserException'),
  throwsStateError('Throws StateError'),
  throwsTimeoutException('Throws TimeoutException'),
  throwsArgumentError('Throws ArgumentError');

  final String label;

  const SaveBehavior(this.label);
}

final saveBehavior = ValueNotifier<SaveBehavior>(SaveBehavior.savesOk);

/// Simulates the app starting: Reads the state from the disk with the persistor,
/// and then creates the store.
Future<Store<int>> startApp() async {
  var persistor = MemoryPersistor();

  int? initialState = await persistor.readState();

  if (initialState == null) {
    initialState = 0;
    await persistor.saveInitialState(initialState);
  }

  return Store<int>(
    initialState: initialState,
    persistor: persistor,
    globalErrorObserver: (store) => AppErrorObserver(),
  );
}

/// Saves the counter to the fake [disk], as `v2:<counter>`.
class MemoryPersistor extends Persistor<int> {
  //
  static const _delay = Duration(milliseconds: 300);

  @override
  Future<int?> readState() async {
    await Future.delayed(_delay);

    var data = disk.value;
    print('Persistor: Reading "$data".');

    // Nothing saved yet.
    if (data == null) return null;

    // The current format.
    if (data.startsWith('v2:')) {
      var counter = int.tryParse(data.substring(3));
      if (counter != null) return counter;
    }

    // The format of an old version of the app.
    // We know what it is, so we tell the user with a UserException.
    if (data.startsWith('v1:')) {
      await deleteState();
      addError(const UserException(
        'Your saved counter was in an old format, '
        'so it was reset to zero.',
      ));
      return null;
    }

    // Something we can't read at all.
    // This is not a UserException, but the GlobalErrorObserver will convert it into one.
    await deleteState();
    addError(FormatException('Cannot read the saved data', data));
    return null;
  }

  @override
  Future<void> deleteState() async {
    print('Persistor: Deleting the state.');
    disk.value = null;
  }

  @override
  Future<void> persistDifference({
    required int? lastPersistedState,
    required int newState,
  }) async {
    await Future.delayed(_delay);

    print('Persistor: Saving $newState (last persisted: $lastPersistedState). '
        'Behavior: ${saveBehavior.value.label}.');

    switch (saveBehavior.value) {
      case SaveBehavior.savesOk:
        disk.value = 'v2:$newState';
      case SaveBehavior.throwsUserException:
        throw UserException('Could not save the counter ($newState).');
      case SaveBehavior.throwsStateError:
        throw StateError('The disk is full');
      case SaveBehavior.throwsTimeoutException:
        throw TimeoutException('The disk is too slow');
      case SaveBehavior.throwsArgumentError:
        throw ArgumentError('This one is not converted');
    }
  }

  /// The initial state is saved before the store exists, so if saving fails,
  /// we use [addError] to tell the user when the store is created.
  @override
  Future<void> saveInitialState(int state) async {
    try {
      await persistDifference(lastPersistedState: null, newState: state);
    } catch (error, stackTrace) {
      Object? wrappedError = wrapError(error, stackTrace);
      if (wrappedError != null) addError(wrappedError, stackTrace);
    }
  }

  /// Converts timeouts into errors the user can understand.
  @override
  Object? wrapError(Object error, StackTrace stackTrace) {
    if (error is TimeoutException)
      return const UserException('Saving took too long, so the counter was not saved.')
          .addCause(error);
    else
      return error;
  }

  /// No throttle, so that the state is saved as soon as it changes.
  @override
  Duration? get throttle => null;
}

/// Prints all errors to the console. Converts some persistence errors into
/// [UserException]s, so that they are shown to the user.
class AppErrorObserver extends GlobalErrorObserver<int> {
  @override
  Object? observe() {
    var source = (action == null) ? 'the Persistor' : action.runtimeType.toString();
    print('GlobalErrorObserver: Error from $source: $error');

    // Errors from the persistor have a null action.
    if (action == null && (error is StateError || error is FormatException))
      return const UserException('There was a problem with your saved data.').addCause(error);

    return error;
  }
}

class IncrementAction extends ReduxAction<int> {
  @override
  int reduce() => state + 1;
}

/// Restarts the app when the "Restart app" button is tapped, by reading the state
/// from the disk again and creating a new store. The whole widget tree is recreated,
/// including the [UserExceptionDialog].
class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Future<Store<int>> _store;

  @override
  void initState() {
    super.initState();
    _store = startApp();
  }

  void _restart() {
    print('\n---------- Restarting the app ----------');
    setState(() {
      _store = startApp();
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Store<int>>(
        future: _store,
        builder: (context, snapshot) {
          var store = snapshot.data;

          if (snapshot.connectionState != ConnectionState.done || store == null)
            return const MaterialApp(
              home: Scaffold(body: Center(child: CircularProgressIndicator())),
            );

          return StoreProvider<int>(
            key: ObjectKey(store),
            store: store,
            child: MaterialApp(
              home: UserExceptionDialog<int>(
                child: MyHomePage(restart: _restart),
              ),
            ),
          );
        },
      );
}

class MyHomePage extends StatelessWidget {
  final VoidCallback restart;

  MyHomePage({Key? key, required this.restart}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final counter = context.state;

    return Scaffold(
      appBar: AppBar(title: const Text('Persistor Failures')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(child: Text('$counter', style: const TextStyle(fontSize: 48))),
          const SizedBox(height: 8),
          Center(
            child: ValueListenableBuilder<String?>(
              valueListenable: disk,
              builder: (context, value, _) => Text(
                'On disk: ${value ?? '(nothing)'}',
                style: const TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ),
          ),
          const Divider(height: 32),
          //
          const Text('When the state changes', style: TextStyle(fontSize: 20)),
          const Text('Choose what happens when saving, then tap "+".'),
          ValueListenableBuilder<SaveBehavior>(
            valueListenable: saveBehavior,
            builder: (context, value, _) => RadioGroup<SaveBehavior>(
              groupValue: value,
              onChanged: (behavior) => saveBehavior.value = behavior!,
              child: Column(
                children: [
                  for (var behavior in SaveBehavior.values)
                    RadioListTile<SaveBehavior>(
                      title: Text(behavior.label),
                      value: behavior,
                      dense: true,
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 32),
          //
          const Text('When the app opens', style: TextStyle(fontSize: 20)),
          const Text('Write bad data to the disk, then restart the app.'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => disk.value = 'v1:$counter',
                child: const Text('Write old format'),
              ),
              OutlinedButton(
                onPressed: () => disk.value = '%&*garbage*&%',
                child: const Text('Write garbage'),
              ),
              ElevatedButton(
                onPressed: restart,
                child: const Text('Restart app'),
              ),
            ],
          ),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.dispatch(IncrementAction()),
        child: const Icon(Icons.add),
      ),
    );
  }
}

extension BuildContextExtension on BuildContext {
  int get state => getState<int>();
}
