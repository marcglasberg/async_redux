import "package:async_redux/async_redux.dart";
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  //
  testWidgets('The UserExceptionDialog shows errors queued before it was mounted.',
      (tester) async {
    var store = Store<int>(initialState: 0);
    await store.dispatchAndWait(FailAction('Error before mount'));
    expect(store.errors.length, 1);

    var shown = <String?>[];
    await tester.pumpWidget(buildApp(store, shown));
    await tester.pump();

    expect(shown, ['Error before mount']);
    expect(store.errors, isEmpty);
  });

  testWidgets('The UserExceptionDialog shows all errors queued before it was mounted.',
      (tester) async {
    var store = Store<int>(initialState: 0);
    await store.dispatchAndWait(FailAction('Error 1'));
    await store.dispatchAndWait(FailAction('Error 2'));
    await store.dispatchAndWait(FailAction('Error 3'));
    expect(store.errors.length, 3);

    var shown = <String?>[];
    await tester.pumpWidget(buildApp(store, shown));
    await tester.pump();

    expect(shown, ['Error 1', 'Error 2', 'Error 3']);
    expect(store.errors, isEmpty);
  });

  testWidgets('The UserExceptionDialog shows errors queued after it was mounted.',
      (tester) async {
    var store = Store<int>(initialState: 0);

    var shown = <String?>[];
    await tester.pumpWidget(buildApp(store, shown));
    await tester.pump();
    expect(shown, isEmpty);

    await tester.runAsync(() => store.dispatchAndWait(FailAction('Error after mount')));
    await tester.pump();
    await tester.pump();

    expect(shown, ['Error after mount']);
  });
}

Widget buildApp(Store<int> store, List<String?> shown) => StoreProvider<int>(
      store: store,
      child: MaterialApp(
        home: UserExceptionDialog<int>(
          useLocalContext: true,
          onShowUserExceptionDialog: (context, exception, useLocalContext) =>
              shown.add(exception.message),
          child: const SizedBox(),
        ),
      ),
    );

class FailAction extends ReduxAction<int> {
  final String msg;

  FailAction(this.msg);

  @override
  int reduce() => throw UserException(msg);
}
