import 'package:async_redux/async_redux.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final phase in ['start', 'state', 'end']) {
    test('dispatch survives failure while reporting the $phase observer', () async {
      final malformed = _MalformedDialogError();
      final reports = <GlobalErrorSource>[];
      final events = <String>[];
      final store = Store<int>(
        initialState: 0,
        actionObservers: [
          _ActionObserver((ini) {
            events.add(ini ? 'start' : 'end');
            if ((ini && phase == 'start') || (!ini && phase == 'end')) {
              throw StateError('observer');
            }
          }),
          _ActionObserver((ini) => events.add(ini ? 'next:start' : 'next:end')),
        ],
        stateObservers: [
          _StateObserver(() {
            events.add('state');
            if (phase == 'state') throw StateError('observer');
          }),
          _StateObserver(() => events.add('next:state')),
        ],
        globalErrorObserver: (_) => _ErrorObserver(reports, malformed),
      );
      addTearDown(store.teardown);

      for (var index = 1; index <= 2; index++) {
        final action = _Increment();
        final status = store.dispatchSync(action);
        expect(status.isCompletedOk, isTrue);
        expect(status.originalError, isNull);
        expect(status.wrappedError, isNull);
        expect(action.finished, isTrue);
        expect(store.state, index);
        expect(store.dispatchCount, index);
        expect(store.reduceCount, index);
        expect(store.errors, isEmpty);
        expect(store.isFailed(_Increment), isFalse);
        expect(store.actionsInProgress(), isEmpty);
      }

      // Reporting the malformed dialog throws, but never recursively invokes the
      // global observer. Its guard must also reset for the next dispatch.
      expect(malformed.reads, 2);
      expect(
        reports,
        List.filled(
          2,
          phase == 'state'
              ? GlobalErrorSource.stateObserver
              : GlobalErrorSource.actionObserver,
        ),
      );
      expect(events, [
        for (var index = 0; index < 2; index++) ...[
          'start',
          'next:start',
          'state',
          'next:state',
          'end',
          'next:end',
        ],
      ]);
    });
  }
}

// This test double corrupts dialog metadata; no exception-copying API is used.
// ignore: missing_override_of_must_be_overridden
class _MalformedDialogError extends UserException {
  _MalformedDialogError() : super('malformed diagnostic');
  int reads = 0;

  @override
  bool get ifOpenDialog {
    reads++;
    throw StateError('dialog metadata unavailable');
  }
}

class _ErrorObserver extends GlobalErrorObserver<int> {
  _ErrorObserver(this.reports, this.replacement);
  final List<GlobalErrorSource> reports;
  final UserException replacement;

  @override
  Object observe() {
    reports.add(errorSource);
    return replacement;
  }
}

class _ActionObserver extends ActionObserver<int> {
  _ActionObserver(this.callback);
  final void Function(bool) callback;

  @override
  void observe(ReduxAction<int> action, int dispatchCount, {required bool ini}) =>
      callback(ini);
}

class _StateObserver extends StateObserver<int> {
  _StateObserver(this.callback);
  final void Function() callback;

  @override
  void observe(
    ReduxAction<int> action,
    int prevState,
    int newState,
    Object? error,
    int dispatchCount,
  ) => callback();
}

class _Increment extends ReduxAction<int> {
  bool finished = false;

  @override
  int reduce() => state + 1;

  @override
  void after() => finished = true;
}
