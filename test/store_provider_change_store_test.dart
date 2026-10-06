import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'When the StoreProvider gets a new store, '
      'the widgets rebuild when the state of the new store changes', (tester) async {
    var storeA = Store<int>(initialState: 1);
    var storeB = Store<int>(initialState: 10);

    Widget app(Store<int> store) => StoreProvider<int>(
          store: store,
          child: MaterialApp(
            home: Builder(
              // ignore: async_redux_lints/avoid_context_state
              builder: (context) => Text('${context.getState<int>()}'),
            ),
          ),
        );

    await tester.pumpWidget(app(storeA));
    expect(find.text('1'), findsOneWidget);

    await tester.pumpWidget(app(storeB));
    expect(find.text('10'), findsOneWidget);

    storeB.dispatch(_Increment());
    await tester.pump();
    await tester.pump();
    expect(find.text('11'), findsOneWidget);

    // The old store no longer rebuilds the widgets.
    storeA.dispatch(_Increment());
    await tester.pump();
    await tester.pump();
    expect(find.text('11'), findsOneWidget);
  });
}

class _Increment extends ReduxAction<int> {
  @override
  int reduce() => state + 1;
}
