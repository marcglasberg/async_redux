import 'package:async_redux/async_redux.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backdoorStaticGlobal', () async {
    Store<String> store = Store<String>(initialState: "abc");
    StoreProvider(store: store, child: Container());

    expect(StoreProvider.backdoorStaticGlobal(), store);
    expect(StoreProvider.backdoorStaticGlobal<dynamic>(), store);
    expect(StoreProvider.backdoorStaticGlobal<String>(), store);

    expect(() => StoreProvider.backdoorStaticGlobal<int>(), throwsA(isA<StoreException>()));

    var backdoorStore = StoreProvider.backdoorStaticGlobal();
    expect(backdoorStore, store);

    var backdoorState = StoreProvider.backdoorStaticGlobal().state;
    expect(backdoorState, "abc");
  });
}
