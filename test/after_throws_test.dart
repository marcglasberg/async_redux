import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:flutter_test/flutter_test.dart';

// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

late List<String> info;

/// IMPORTANT:
/// These tests may print errors to the console. This is normal.
///
void main() {
  test('If the after method throws, the error will be thrown asynchronously.', () async {
    //
    dynamic error;
    dynamic asyncError;
    late Store<String> store;

    await runZonedGuarded(() async {
      info = [];
      store = Store<String>(initialState: "");

      try {
        store.dispatch(ActionA());
      } catch (_error) {
        error = _error;
      }
      await Future.delayed(const Duration(seconds: 1));
    }, (_asyncError, s) {
      asyncError = _asyncError;
    });

    expect(store.state, "A");

    expect(info, [
      'A.before state=""',
      'A.reduce state=""',
      'A.after state="A"',
    ]);

    expect(error, isNull);

    expect(
        asyncError,
        "Method 'ActionA.after()' has thrown an error:\n"
        " 'some-error'.:\n"
        "  some-error");
  });
}

class ActionA extends ReduxAction<String> {
  @override
  void before() {
    info.add('A.before state="$state"');
  }

  @override
  String reduce() {
    info.add('A.reduce state="$state"');
    return state + 'A';
  }

  @override
  void after() {
    info.add('A.after state="$state"');
    throw "some-error";
  }
}
