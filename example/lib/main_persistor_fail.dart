// ignore_for_file: async_redux_lints/extend_base_action

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
  savesOk(
    'Saves OK',
    'Tap "+": The counter goes up, and "On disk" changes to the new value. '
        'No dialog opens.\n\n'
        'Why: The persistor\'s persistDifference() writes the new counter to the disk, '
        'and nothing fails.',
  ),
  throwsUserException(
    'Throws UserException',
    'Tap "+": The counter goes up, but "On disk" does NOT change. '
        'A dialog opens saying "Could not save the counter".\n\n'
        'Why: persistDifference() throws a UserException. The persistor\'s wrapError() '
        'keeps it as is, and the GlobalErrorObserver also keeps it as is. '
        'Since it\'s a UserException, the dialog shows it.',
  ),
  throwsStateError(
    'Throws StateError',
    'Tap "+": The counter goes up, but "On disk" does NOT change. '
        'A dialog opens saying "There was a problem with your saved data".\n\n'
        'Why: persistDifference() throws a StateError. The persistor\'s wrapError() '
        'keeps it as is. Then the GlobalErrorObserver sees an error from the persistor '
        '(the action is null), and converts the StateError into a UserException, '
        'which the dialog shows.',
  ),
  throwsTimeoutException(
    'Throws TimeoutException',
    'Tap "+": The counter goes up, but "On disk" does NOT change. '
        'A dialog opens saying "Saving took too long".\n\n'
        'Why: persistDifference() throws a TimeoutException. This time it\'s the '
        'persistor\'s wrapError() that converts it into a UserException. '
        'The GlobalErrorObserver keeps it as is, and the dialog shows it.',
  ),
  throwsArgumentError(
    'Throws ArgumentError',
    'Tap "+": The counter goes up, but "On disk" does NOT change. '
        'NO dialog opens. Look at the console instead.\n\n'
        'Why: persistDifference() throws an ArgumentError. Neither the persistor\'s '
        'wrapError() nor the GlobalErrorObserver convert it into a UserException, '
        'so it can\'t be shown in the dialog. It\'s thrown as an unhandled async error.',
  );

  final String label;
  final String explanation;

  const SaveBehavior(this.label, this.explanation);
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
      return const UserException('There was a problem with your saved data.')
          .addCause(error);

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
              debugShowCheckedModeBanner: false,
              home: Scaffold(body: Center(child: CircularProgressIndicator())),
            );

          return StoreProvider<int>(
            key: ObjectKey(store),
            store: store,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
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
    // ignore: async_redux_lints/avoid_context_state
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
                      title: Text(
                        behavior.label,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        child: Text(behavior.explanation),
                      ),
                      value: behavior,
                      isThreeLine: true,
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
          const SizedBox(height: 16),
          _ButtonWithExplanation(
            button: OutlinedButton(
              onPressed: () => disk.value = 'v1:$counter',
              child: const Text('Write old format'),
            ),
            explanation: 'Tap it: "On disk" changes to "v1:$counter". '
                'Then tap "Restart app": The counter is reset to 0, and a dialog opens '
                'saying "Your saved counter was in an old format".\n\n'
                'Why: The persistor\'s readState() recognizes "v1:" as the format of an '
                'old version of the app. It deletes it from the disk, and calls addError() '
                'with a UserException. Errors added with addError() skip the persistor\'s '
                'wrapError(). The GlobalErrorObserver keeps it as is, and since it\'s a '
                'UserException, the dialog shows it.',
          ),
          _ButtonWithExplanation(
            button: OutlinedButton(
              onPressed: () => disk.value = '%&*garbage*&%',
              child: const Text('Write garbage'),
            ),
            explanation: 'Tap it: "On disk" changes to "%&*garbage*&%". '
                'Then tap "Restart app": The counter is reset to 0, and a dialog opens '
                'saying "There was a problem with your saved data".\n\n'
                'Why: The persistor\'s readState() can\'t read it at all. It deletes it '
                'from the disk, and calls addError() with a FormatException. This is NOT a '
                'UserException, but the GlobalErrorObserver sees an error from the persistor '
                '(the action is null), and converts it into a UserException, '
                'which the dialog shows.',
          ),
          _ButtonWithExplanation(
            button: ElevatedButton(
              onPressed: restart,
              child: const Text('Restart app'),
            ),
            explanation: 'Tap it: The app reads the state from the disk again, and creates '
                'a new store.\n\n'
                'If the disk has a valid "v2:" value, the counter is restored and no dialog '
                'opens. If the disk is empty (or the bad data was just deleted), the counter '
                'starts at 0, and saveInitialState() tries to save it, using the save option '
                'selected above. If that option fails, you get one more dialog '
                '(or a console error, for ArgumentError). So, bad data plus a failing option '
                'means two dialogs: One for the bad data, and one for the failed save.',
          ),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => dispatch(IncrementAction()),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// A button, with an explanation of what happens when you tap it.
class _ButtonWithExplanation extends StatelessWidget {
  final Widget button;
  final String explanation;

  const _ButtonWithExplanation({required this.button, required this.explanation});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            button,
            const SizedBox(height: 6),
            Text(
              explanation,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
}

extension BuildContextExtension on BuildContext {
  int get state => getState<int>();
}
