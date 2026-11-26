import 'package:async_redux/async_redux.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final asyncAction in [false, true]) {
    for (final failure in _Failure.values) {
      test('after runs once when $failure throws, async=$asyncAction', () async {
        final original = StateError('reducer');
        final secondary = StateError('error handling');
        final events = <String>[];
        final action = asyncAction
            ? _AsyncFailure(original, secondary, failure, events)
            : _SyncFailure(original, secondary, failure, events);
        final store = Store<int>(
          initialState: 0,
          actionObservers: [_Observer(events)],
          globalErrorObserver: failure == _Failure.globalFactory
              ? (_) => throw secondary
              : null,
        );
        addTearDown(store.teardown);

        Object? thrown;
        try {
          await store.dispatch(action);
        } catch (error) {
          thrown = error;
        }

        expect(thrown, same(secondary));
        expect(events, ['start', 'reduce', 'wrap', 'after', 'end']);
        expect(action.status.originalError, same(original));
        expect(
          action.status.wrappedError,
          failure == _Failure.globalFactory ? isNull : same(action.wrappedError),
        );
        expect(action.status.hasFinishedMethodBefore, isTrue);
        expect(action.status.hasFinishedMethodReduce, isFalse);
        expect(action.status.hasFinishedMethodAfter, isTrue);
        expect(action.status.isCompletedFailed, isTrue);
        expect(store.state, 0);
        expect(store.errors, isEmpty);
        expect(store.actionsInProgress(), isEmpty);
        // Only dialog metadata fails after the failure has been recorded.
        expect(store.isFailed(action.runtimeType), failure == _Failure.dialogMetadata);
      });
    }
  }
}

enum _Failure { globalFactory, statusKey, dialogMetadata }

abstract class _FailingAction extends ReduxAction<int> {
  _FailingAction(this.original, this.secondary, this.failure, this.events) {
    wrappedError = failure == _Failure.dialogMetadata
        ? _MalformedDialog(secondary)
        : original;
  }

  final Object original;
  final Object secondary;
  final _Failure failure;
  final List<String> events;
  late final Object wrappedError;

  @override
  Object? get statusKey {
    if (failure == _Failure.statusKey && status.originalError != null) throw secondary;
    return null;
  }

  @override
  Object wrapError(Object error, StackTrace stackTrace) {
    events.add('wrap');
    return wrappedError;
  }

  @override
  void after() {
    events.add('after');
    expect(status.hasFinishedMethodAfter, isFalse);
    expect(store.actionsInProgress(), contains(this));
    expect(store.errors, isEmpty);
  }
}

class _SyncFailure extends _FailingAction {
  _SyncFailure(super.original, super.secondary, super.failure, super.events);

  @override
  int? reduce() {
    events.add('reduce');
    throw original;
  }
}

class _AsyncFailure extends _FailingAction {
  _AsyncFailure(super.original, super.secondary, super.failure, super.events);

  @override
  Future<int?> reduce() async {
    await microtask;
    events.add('reduce');
    throw original;
  }
}

// Deliberately fail while inspecting dialog metadata, after after() has run.
// ignore: missing_override_of_must_be_overridden
class _MalformedDialog extends UserException {
  _MalformedDialog(this.secondary) : super('malformed dialog');

  final Object secondary;

  @override
  bool get ifOpenDialog => throw secondary;
}

class _Observer extends ActionObserver<int> {
  _Observer(this.events);

  final List<String> events;

  @override
  void observe(ReduxAction<int> action, int dispatchCount, {required bool ini}) {
    events.add(ini ? 'start' : 'end');
  }
}
