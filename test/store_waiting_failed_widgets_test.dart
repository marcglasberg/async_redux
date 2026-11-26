import 'package:async_redux/async_redux.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/waiting_failed_support.dart';

void main() {
  testWidgets('keyed status and clearing rebuild widgets with unchanged state', (
    tester,
  ) async {
    final store = Store<int>(initialState: 0);
    await tester.pumpWidget(
      MaterialApp(
        home: StoreProvider<int>(
          store: store,
          child: const Scaffold(body: Column(children: [_Row('a'), _Row('b')])),
        ),
      ),
    );
    expect(find.text('a:false:false:-'), findsOneWidget);
    expect(find.text('b:false:false:-'), findsOneWidget);

    final a = TrackingAction<int>(key: 'a', error: const UserException('A').noDialog);
    final b = TrackingAction<int>(key: 'b', error: const UserException('B').noDialog);
    final doneA = store.dispatchAndWait(a, notify: false);
    final doneB = store.dispatchAndWait(b, notify: false);
    await _pump(tester);
    expect(find.text('a:true:false:-'), findsOneWidget);
    expect(find.text('b:true:false:-'), findsOneWidget);
    a.release();
    await doneA;
    await _pump(tester);
    expect(find.text('a:false:true:A'), findsOneWidget);
    expect(find.text('b:true:false:-'), findsOneWidget);
    b.release();
    await doneB;
    await _pump(tester);
    expect(find.text('a:false:true:A'), findsOneWidget);
    expect(find.text('b:false:true:B'), findsOneWidget);

    await tester.tap(find.byKey(const Key('clear-a')));
    await _pump(tester);
    expect(find.text('a:false:false:-'), findsOneWidget);
    expect(find.text('b:false:true:B'), findsOneWidget);

    // A new dispatch clears the previous failure immediately. A second action
    // with the same key must keep the spinner alive when the first finishes.
    final retry = TrackingAction<int>(key: 'b');
    final overlapping = TrackingAction<int>(key: 'b');
    final retryDone = store.dispatchAndWait(retry, notify: false);
    final overlappingDone = store.dispatchAndWait(overlapping, notify: false);
    expect(store.exceptionFor(TrackingAction<int>, statusKey: 'b'), isNull);
    await _pump(tester);
    expect(find.text('b:true:false:-'), findsOneWidget);
    retry.release();
    await retryDone;
    await _pump(tester);
    expect(find.text('b:true:false:-'), findsOneWidget);
    overlapping.release();
    await overlappingDone;
    await _pump(tester);
    expect(find.text('b:false:false:-'), findsOneWidget);

    final againA = TrackingAction<int>(
      key: 'a',
      error: const UserException('A2').noDialog,
    );
    final againB = TrackingAction<int>(
      key: 'b',
      error: const UserException('B2').noDialog,
    );
    final againADone = store.dispatchAndWait(againA, notify: false);
    final againBDone = store.dispatchAndWait(againB, notify: false);
    againA.release();
    againB.release();
    await againADone;
    await againBDone;
    await _pump(tester);
    expect(find.text('a:false:true:A2'), findsOneWidget);
    expect(find.text('b:false:true:B2'), findsOneWidget);
    store.clearAllExceptions();
    await _pump(tester);
    expect(find.text('a:false:false:-'), findsOneWidget);
    expect(find.text('b:false:false:-'), findsOneWidget);
    expect(store.state, 0);
    expect(store.errors, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await store.teardown();
  });
}

Future<void> _pump(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

class _Row extends StatelessWidget {
  const _Row(this.id);
  final String id;

  @override
  Widget build(BuildContext context) {
    final waiting = context.isWaiting(TrackingAction<int>, statusKey: id);
    final failed = context.isFailed(TrackingAction<int>, statusKey: id);
    final error = context.exceptionFor(TrackingAction<int>, statusKey: id);
    return Row(
      children: [
        Text('$id:$waiting:$failed:${error?.message ?? '-'}'),
        TextButton(
          key: Key('clear-$id'),
          onPressed: () => context.clearExceptionFor(TrackingAction<int>, statusKey: id),
          child: const Text('clear'),
        ),
      ],
    );
  }
}
