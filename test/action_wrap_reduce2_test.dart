import 'dart:async' show FutureOr;

import 'package:async_redux/async_redux.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Knowing if wrapReduce is overridden, sync, or async', () async {
    //
    var xN = ActionNullableX();
    var yN = ActionNullableY();
    var x = ActionX();
    var y = ActionY();
    var z = ActionZ();

    print(x.wrapReduce.runtimeType);
    print(xN.wrapReduce.runtimeType);
    print(y.wrapReduce.runtimeType);
    print(yN.wrapReduce.runtimeType);
    print(z.wrapReduce.runtimeType);

    print('\nActionX -> true / false / true');
    print('ifWrapReduceOverridden ${x.ifWrapReduceOverridden()}');
    print('ifWrapReduceSync ${x.ifWrapReduceOverridden_Sync()}');
    print('ifWrapReduceAsync ${x.ifWrapReduceOverridden_Async()}');
    expect(x.ifWrapReduceOverridden(), true);
    expect(x.ifWrapReduceOverridden_Sync(), false);
    expect(x.ifWrapReduceOverridden_Async(), true);

    print('\nActionNullableX -> true / false / true');
    print('ifWrapReduceOverridden ${xN.ifWrapReduceOverridden()}');
    print('ifWrapReduceSync ${xN.ifWrapReduceOverridden_Sync()}');
    print('ifWrapReduceAsync ${xN.ifWrapReduceOverridden_Async()}');
    expect(xN.ifWrapReduceOverridden(), true);
    expect(xN.ifWrapReduceOverridden_Sync(), false);
    expect(xN.ifWrapReduceOverridden_Async(), true);

    print('\nActionY -> true / true / false');
    print('ifWrapReduceOverridden ${y.ifWrapReduceOverridden()}');
    print('ifWrapReduceSync ${y.ifWrapReduceOverridden_Sync()}');
    print('ifWrapReduceAsync ${y.ifWrapReduceOverridden_Async()}');
    expect(y.ifWrapReduceOverridden(), true);
    expect(y.ifWrapReduceOverridden_Sync(), true);
    expect(y.ifWrapReduceOverridden_Async(), false);

    print('\nActionNullableY -> true / true / false');
    print('ifWrapReduceOverridden ${yN.ifWrapReduceOverridden()}');
    print('ifWrapReduceSync ${yN.ifWrapReduceOverridden_Sync()}');
    print('ifWrapReduceAsync ${yN.ifWrapReduceOverridden_Async()}');
    expect(yN.ifWrapReduceOverridden(), true);
    expect(yN.ifWrapReduceOverridden_Sync(), true);
    expect(yN.ifWrapReduceOverridden_Async(), false);

    print('\nActionZ => false false false');
    print('ifWrapReduceOverridden ${z.ifWrapReduceOverridden()}');
    print('ifWrapReduceSync ${z.ifWrapReduceOverridden_Sync()}');
    print('ifWrapReduceAsync ${z.ifWrapReduceOverridden_Async()}');
    expect(z.ifWrapReduceOverridden(), false);
    expect(z.ifWrapReduceOverridden_Sync(), false);
    expect(z.ifWrapReduceOverridden_Async(), false);
  });
}

abstract class BaseAction<St> {
  // static const _wrapReduceFlag = Object();

  FutureOr<St?> reduce();

  FutureOr<St?> wrapReduce(Reducer<St> reduce) {
    return null;
  }

  bool ifWrapReduceOverridden_Sync() => wrapReduce is St? Function(Reducer<St>);

  bool ifWrapReduceOverridden_Async() =>
      wrapReduce is Future<St?> Function(Reducer<St>);

  bool ifWrapReduceOverridden() =>
      ifWrapReduceOverridden_Async() || ifWrapReduceOverridden_Sync();
}

/// SYNC: This action overrides the [wrapReduce] method.
class ActionNullableX extends BaseAction<int> {
  @override
  int? reduce() => 123;

  @override
  Future<int?> wrapReduce(Reducer<int> reduce) async {
    print('overriden');
    return null;
  }
}

/// SYNC: This action overrides the [wrapReduce] method.
class ActionX extends BaseAction<int> {
  @override
  int? reduce() => 123;

  @override
  Future<int> wrapReduce(Reducer<int> reduce) async {
    print('overriden');
    return 0;
  }
}

/// This action does NOT override the [wrapReduce] method.
class ActionNullableY extends BaseAction<int> {
  @override
  int reduce() => 456;

  @override
  int? wrapReduce(Reducer<int> reduce) {
    print('overriden');
    return null;
  }
}

/// This action does NOT override the [wrapReduce] method.
class ActionY extends BaseAction<int> {
  @override
  int reduce() => 456;

  @override
  int wrapReduce(Reducer<int> reduce) {
    print('overriden');
    return 0;
  }
}

/// This action does NOT override the [wrapReduce] method.
class ActionZ extends BaseAction<int> {
  @override
  FutureOr<int?> reduce() => 456;
}
