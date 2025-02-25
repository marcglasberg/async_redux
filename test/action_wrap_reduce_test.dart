import 'package:async_redux/async_redux.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('action.isSync', () async {
    expect(IncrementReduceSyncNoBeforeNoWrap().isSync(), isTrue);
    expect(IncrementReduceAsyncNoBeforeNoWrap().isSync(), isFalse);

    expect(IncrementReduceSyncBeforeSyncNoWrap().isSync(), isTrue);
    expect(IncrementReduceSyncBeforeAsyncNoWrap().isSync(), isFalse);

    expect(IncrementReduceSyncNoBeforeWrapSync().isSync(), isTrue);
    expect(IncrementReduceSyncNoBeforeWrapSync2().isSync(), isTrue);
    expect(IncrementReduceSyncNoBeforeWrapSync3().isSync(), isTrue);

    expect(IncrementReduceSyncNoBeforeWrapAsync().isSync(), isFalse);
    expect(IncrementReduceSyncNoBeforeWrapAsync2().isSync(), isFalse);
    expect(IncrementReduceSyncNoBeforeWrapAsync3().isSync(), isFalse);
  });
}

class State {
  final int count;

  State(this.count);
}

class IncrementReduceSyncNoBeforeNoWrap extends ReduxAction<State> {
  @override
  State reduce() => State(state.count + 1);
}

class IncrementReduceAsyncNoBeforeNoWrap extends ReduxAction<State> {
  @override
  Future<State> reduce() async {
    return State(state.count + 1);
  }
}

class IncrementReduceSyncBeforeSyncNoWrap extends ReduxAction<State> {
  @override
  void before() {}

  @override
  State reduce() => State(state.count + 1);
}

class IncrementReduceSyncBeforeAsyncNoWrap extends ReduxAction<State> {
  @override
  Future<void> before() async {
    await Future.delayed(const Duration(milliseconds: 1));
  }

  @override
  State reduce() => State(state.count + 1);
}

class IncrementReduceSyncNoBeforeWrapSync extends ReduxAction<State> {
  @override
  State reduce() => State(state.count + 1);

  @override
  State? wrapReduce(Reducer<State> reduce) {
    return reduce() as State?;
  }
}

class IncrementReduceSyncNoBeforeWrapSync2 extends ReduxAction<State> {
  @override
  State reduce() => State(state.count + 1);

  @override
  State wrapReduce(Reducer<State> reduce) {
    return reduce() as State;
  }
}

class IncrementReduceSyncNoBeforeWrapSync3 extends ReduxAction<State> {
  @override
  State reduce() => State(state.count + 1);

  @override
  State wrapReduce(Reducer<State> reduce) {
    return reduce() as State;
  }
}

class IncrementReduceSyncNoBeforeWrapAsync extends ReduxAction<State> {
  @override
  State reduce() => State(state.count + 1);

  @override
  Future<State?> wrapReduce(Reducer<State> reduce) async {
    await microtask;
    return reduce();
  }
}

class IncrementReduceSyncNoBeforeWrapAsync2 extends ReduxAction<State> {
  @override
  State reduce() => State(state.count + 1);

  @override
  Future<State> wrapReduce(Reducer<State> reduce) async {
    return reduce() as Future<State>;
  }
}

class IncrementReduceSyncNoBeforeWrapAsync3 extends ReduxAction<State> {
  @override
  State reduce() => State(state.count + 1);

  @override
  Future<State> wrapReduce(Reducer<State> reduce) async {
    return reduce() as Future<State>;
  }
}
