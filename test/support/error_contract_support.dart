import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:fake_async/fake_async.dart';

// Dart permits throwing any non-null Object, not only Exception and Error.
enum ErrorKind {
  exception,
  error,
  assertion,
  user,
  noDialog,
  abort,
  text,
  integer,
  boolean,
  object,
  list,
  map,
  record,
  function,
  future,
}

Object errorValue(ErrorKind kind, String label) => switch (kind) {
  ErrorKind.exception => FormatException(label),
  ErrorKind.error => StateError(label),
  ErrorKind.assertion => AssertionError(label),
  ErrorKind.user => UserException(label),
  ErrorKind.noDialog => UserException(label).noDialog,
  ErrorKind.abort => AbortDispatchException(),
  ErrorKind.text => label,
  ErrorKind.integer => 42,
  ErrorKind.boolean => false,
  ErrorKind.object => Object(),
  ErrorKind.list => <Object>[label],
  ErrorKind.map => <String, Object>{'error': label},
  ErrorKind.record => (label, 42),
  ErrorKind.function => () => label,
  ErrorKind.future => Future<Object>.value(UserException(label)),
};

enum ErrorConversion { keep, swallow, exception, error, user, noDialog, abort }

class ErrorRule {
  ErrorRule(this.conversion, this.throwsResult, String label)
    : replacement = switch (conversion) {
        ErrorConversion.keep || ErrorConversion.swallow => null,
        ErrorConversion.exception => FormatException(label),
        ErrorConversion.error => StateError(label),
        ErrorConversion.user => UserException(label),
        ErrorConversion.noDialog => UserException(label).noDialog,
        ErrorConversion.abort => AbortDispatchException(),
      };

  final ErrorConversion conversion;
  final bool throwsResult;
  final Object? replacement;

  Object? expected(Object input) =>
      conversion == ErrorConversion.keep ? input : replacement;

  Object? apply(Object input) {
    final result = expected(input);
    if (throwsResult) throw result!;
    return result;
  }
}

Iterable<(ErrorConversion, bool)> get errorRules sync* {
  for (final conversion in ErrorConversion.values) {
    yield (conversion, false);
    if (conversion != ErrorConversion.swallow) yield (conversion, true);
  }
}

bool isActionErrorRethrown(Object? error) =>
    error != null && error is! UserException && error is! AbortDispatchException;

bool isRecordedFailure(Object? error) =>
    error != null && error is! AbortDispatchException;

bool opensDialog(Object? error) => error is UserException && error.ifOpenDialog;

abstract class ErrorProbeAction extends ReduxAction<int> {
  final events = <String>[];
  void Function()? onAbort;
  void Function()? onBefore;
  int? Function()? onReduce;
  void Function()? onAfter;
  Object? Function(Object, StackTrace)? onWrapError;
  final localInputs = <(Object, StackTrace)>[];
  final afterStatuses = <ActionStatus>[];
  final afterStates = <int>[];
  final afterQueueLengths = <int>[];
  Object? key;

  @override
  Object? get statusKey => key;

  @override
  bool abortDispatch() {
    events.add('abort');
    onAbort?.call();
    return false;
  }

  @override
  void before() {
    events.add('before');
    onBefore?.call();
  }

  int? runReducer() {
    events.add('reduce');
    return onReduce == null ? state + 1 : onReduce!();
  }

  @override
  void after() {
    events.add('after');
    afterStatuses.add(status);
    afterStates.add(state);
    afterQueueLengths.add(store.errors.length);
    onAfter?.call();
  }

  @override
  Object? wrapError(Object error, StackTrace stackTrace) {
    events.add('local');
    localInputs.add((error, stackTrace));
    return onWrapError == null ? error : onWrapError!(error, stackTrace);
  }
}

class SyncErrorProbe extends ErrorProbeAction {
  @override
  int? reduce() => runReducer();
}

class AsyncErrorProbe extends ErrorProbeAction {
  @override
  Future<int?> reduce() async {
    await microtask;
    return runReducer();
  }
}

mixin AsyncProbeBefore on ErrorProbeAction {
  @override
  Future<void> before() async {
    await microtask;
    super.before();
  }
}

class AsyncBeforeSyncErrorProbe = SyncErrorProbe with AsyncProbeBefore;
class AsyncBeforeAsyncErrorProbe = AsyncErrorProbe with AsyncProbeBefore;

ErrorProbeAction errorProbe(bool asyncBefore, bool asyncReduce) => asyncReduce
    ? (asyncBefore ? AsyncBeforeAsyncErrorProbe() : AsyncErrorProbe())
    : (asyncBefore ? AsyncBeforeSyncErrorProbe() : SyncErrorProbe());

class ObservedError {
  ObservedError(this.error, this.original, this.stack, this.action, this.store);

  final Object error;
  final Object original;
  final StackTrace stack;
  final ReduxAction<int>? action;
  final Store<int> store;
}

class ProbeGlobalObserver extends GlobalErrorObserver<int> {
  ProbeGlobalObserver(this.seen, this.transform);

  final List<ObservedError> seen;
  final Object? Function(Object) transform;

  @override
  Object? observe() {
    seen.add(ObservedError(error, originalError, stackTrace, action, store));
    return transform(error);
  }
}

class DispatchResult {
  ActionStatus? status;
  Object? error;
  StackTrace? stack;
  bool returnedFuture = false;
  bool threwSynchronously = false;
}

DispatchResult dispatchCapturing(
  Store<int> store,
  ReduxAction<int> action,
  FakeAsync async, {
  bool notify = true,
}) {
  final result = DispatchResult();
  try {
    final status = store.dispatch(action, notify: notify);
    if (status is Future<ActionStatus>) {
      result.returnedFuture = true;
      status.then<void>(
        (value) {
          result.status = value;
        },
        onError: (Object error, StackTrace stack) {
          result.error = error;
          result.stack = stack;
        },
      );
    } else {
      result.status = status;
    }
  } catch (error, stack) {
    result.threwSynchronously = true;
    result.error = error;
    result.stack = stack;
  }
  async.flushMicrotasks();
  return result;
}
