import 'dart:async';

import 'package:async_redux/async_redux.dart';

// Equal keys deliberately collide in hashCode; action identity is a separate
// contract and must never be replaced with value equality.
class TrackingKey {
  const TrackingKey(this.value);
  final String value;
  @override
  bool operator ==(Object other) => other is TrackingKey && other.value == value;
  @override
  int get hashCode => 1;
  @override
  String toString() => 'key:$value';
}

class TrackingAction<T> extends ReduxAction<int> {
  TrackingAction({
    this.key,
    this.error,
    this.failInBefore = false,
    this.abort = false,
    bool holdBefore = false,
  }) {
    if (!holdBefore) beforeGate.complete();
  }

  final Object? key;
  final Object? error;
  final bool failInBefore;
  final bool abort;
  final beforeGate = Completer<void>();
  final reduceGate = Completer<void>();
  final stages = <String>[];
  void Function(String, TrackingAction<T>)? onStage;
  Object? Function(Object)? transformError;
  bool changeState = false;

  @override
  Object? get statusKey => key;

  void stage(String name) {
    stages.add(name);
    onStage?.call(name, this);
  }

  @override
  bool abortDispatch() {
    stage('abort');
    return abort;
  }

  @override
  Future<void> before() async {
    stage('before:start');
    await beforeGate.future;
    if (failInBefore && error != null) throw error!;
    stage('before:end');
  }

  @override
  Future<int?> reduce() async {
    stage('reduce:start');
    await reduceGate.future;
    if (error != null) throw error!;
    stage('reduce:end');
    return changeState ? state + 1 : null;
  }

  @override
  void after() => stage('after');

  @override
  Object? wrapError(Object error, StackTrace stackTrace) {
    stage('wrapError');
    return transformError == null ? error : transformError!(error);
  }

  void releaseBefore() {
    if (!beforeGate.isCompleted) beforeGate.complete();
  }

  void release() {
    releaseBefore();
    if (!reduceGate.isCompleted) reduceGate.complete();
  }
}

class DerivedTrackingAction extends TrackingAction<int> {
  DerivedTrackingAction({super.key, super.error, super.holdBefore});
}

class EqualTrackingAction extends TrackingAction<int> {
  EqualTrackingAction({super.key, super.error, super.holdBefore});
  int mutableHash = 1;
  @override
  bool operator ==(Object other) => other is EqualTrackingAction;
  @override
  int get hashCode => mutableHash;
}

class SyncTrackingAction<T> extends ReduxAction<int> {
  SyncTrackingAction({this.key, this.error, this.abort = false});
  final Object? key;
  final Object? error;
  final bool abort;
  void Function(String, SyncTrackingAction<T>)? onStage;
  @override
  Object? get statusKey => key;
  @override
  bool abortDispatch() {
    onStage?.call('abort', this);
    return abort;
  }

  @override
  void before() => onStage?.call('before', this);
  @override
  int? reduce() {
    onStage?.call('reduce', this);
    if (error != null) throw error!;
    return null;
  }

  @override
  void after() => onStage?.call('after', this);
}

class TrackingDispatch {
  ActionStatus? status;
  Object? error;
}

TrackingDispatch trackDispatch(
  Store<int> store,
  ReduxAction<int> action, {
  bool notify = true,
}) {
  final result = TrackingDispatch();
  try {
    final dispatched = store.dispatch(action, notify: notify);
    if (dispatched is Future<ActionStatus>) {
      dispatched.then<void>(
        (status) => result.status = status,
        onError: (Object error, StackTrace stack) {
          result.error = error;
        },
      );
    } else {
      result.status = dispatched;
    }
  } catch (error) {
    result.error = error;
  }
  return result;
}
