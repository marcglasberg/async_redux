import 'package:async_redux/async_redux.dart';
import 'package:flutter_test/flutter_test.dart';

// These active regressions assert the documented maximum queue capacity.
// _addError currently trims before insertion using > instead of >=, so the
// effective capacity exceeds the configured maximum by one. Keep the expected
// contract here rather than blessing that off-by-one behavior.
void main() {
  for (final configuredMaximum in <int?>[null, 2, 0]) {
    final maximum = configuredMaximum ?? 10;
    test('error queue honors maximum $maximum (configured=$configuredMaximum)', () async {
      final store = Store<int>(initialState: 0, maxErrorsQueued: configuredMaximum);
      addTearDown(store.teardown);
      final errors = List.generate(maximum + 3, (i) => UserException('error $i'));
      for (final error in errors) {
        store.dispatchSync(_Fail(error));
      }
      expect(store.errors, errors.skip(errors.length - maximum).toList());
      expect(store.internalHasErrors, maximum > 0);
    });
  }
}

class _Fail extends ReduxAction<int> {
  _Fail(this.error);
  final UserException error;

  @override
  int? reduce() => throw error;
}
