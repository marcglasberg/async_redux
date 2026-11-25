import 'package:async_redux/async_redux.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final sync in [false, true]) {
    testWidgets('Given an idle dialog, when errors arrive together (syncStream: $sync), '
        'then all are shown once in order after a frame', (tester) async {
      final store = Store<int>(initialState: 0, syncStream: sync);
      addTearDown(store.shutdown);
      final shown = <String?>[];
      final phases = <SchedulerPhase>[];
      await tester.pumpWidget(
        _app(store, (context, error, local) {
          shown.add(error.message);
          phases.add(SchedulerBinding.instance.schedulerPhase);
          expect(local, isTrue);
        }),
      );
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.runAsync(() async {
        for (final message in ['one', 'two', 'three']) {
          await store.dispatchAndWait(_Fail(message), notify: false);
        }
      });
      expect(store.state, 0);
      expect(shown, isEmpty);
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpAndSettle();

      expect(shown, ['one', 'two', 'three']);
      expect(phases, everyElement(SchedulerPhase.postFrameCallbacks));
      expect(store.errors, isEmpty);
      await tester.pump();
      expect(shown, hasLength(3));
    });
  }

  testWidgets('Given pending errors, when unmounted before the frame, '
      'then errors stay queued and are displayed on remount', (tester) async {
    final store = Store<int>(initialState: 0);
    addTearDown(store.shutdown);
    final shown = <String?>[];
    void show(BuildContext context, UserException error, bool local) =>
        shown.add(error.message);
    await tester.pumpWidget(_app(store, show));
    await tester.runAsync(() => store.dispatchAndWait(_Fail('pending')));

    await tester.pumpWidget(const SizedBox());
    expect(shown, isEmpty);
    expect(store.errors.map((error) => error.message), ['pending']);
    expect(tester.takeException(), isNull);

    await tester.runAsync(() => store.dispatchAndWait(_Fail('after dispose')));
    await tester.pump();
    expect(shown, isEmpty);
    await tester.pumpWidget(_app(store, show));
    await tester.pumpAndSettle();
    expect(shown, ['pending', 'after dispose']);
    expect(store.errors, isEmpty);
  });

  testWidgets('Given a pending callback, when the provider replaces its store, '
      'then only the new store is consumed and observed', (tester) async {
    final oldStore = Store<int>(initialState: 0);
    final newStore = Store<int>(initialState: 0);
    addTearDown(oldStore.shutdown);
    addTearDown(newStore.shutdown);
    final shown = <String?>[];
    // Keep the child identical so only the inherited dependency triggers the switch.
    final child = MaterialApp(
      home: UserExceptionDialog<int>(
        onShowUserExceptionDialog: (context, error, local) => shown.add(error.message),
        child: const SizedBox(),
      ),
    );
    await tester.pumpWidget(StoreProvider<int>(store: oldStore, child: child));
    await tester.runAsync(() async {
      await oldStore.dispatchAndWait(_Fail('old pending'));
      await newStore.dispatchAndWait(_Fail('new pending'));
    });
    await tester.pumpWidget(StoreProvider<int>(store: newStore, child: child));
    await tester.pumpAndSettle();
    expect(shown, ['new pending']);
    expect(oldStore.errors.map((error) => error.message), ['old pending']);

    await tester.runAsync(() async {
      await oldStore.dispatchAndWait(_Fail('old later'));
      await newStore.dispatchAndWait(_Fail('new later'));
    });
    await tester.pumpAndSettle();
    expect(shown, ['new pending', 'new later']);
    expect(oldStore.errors, hasLength(2));
    expect(newStore.errors, isEmpty);
  });

  testWidgets(
    'Given independent stores, when both fail, then each dialog receives its own errors',
    (tester) async {
      final first = Store<int>(initialState: 0);
      final second = Store<int>(initialState: 0);
      addTearDown(first.shutdown);
      addTearDown(second.shutdown);
      final firstShown = <String?>[];
      final secondShown = <String?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              StoreProvider<int>(
                store: first,
                child: UserExceptionDialog<int>(
                  onShowUserExceptionDialog: (context, error, local) =>
                      firstShown.add(error.message),
                  child: const SizedBox(),
                ),
              ),
              StoreProvider<int>(
                store: second,
                child: UserExceptionDialog<int>(
                  onShowUserExceptionDialog: (context, error, local) =>
                      secondShown.add(error.message),
                  child: const SizedBox(),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.runAsync(() async {
        await first.dispatchAndWait(_Fail('first'));
        await second.dispatchAndWait(_Fail('second'));
        await first.dispatchAndWait(_Fail('first again'));
      });
      await tester.pumpAndSettle();
      expect(firstShown, ['first', 'first again']);
      expect(secondShown, ['second']);
    },
  );

  testWidgets('Given no dialog errors, when state changes or a noDialog action fails, '
      'then the child is not rebuilt and no dialog is shown', (tester) async {
    final store = Store<int>(initialState: 0);
    addTearDown(store.shutdown);
    var builds = 0;
    final shown = <String?>[];
    await tester.pumpWidget(
      _app(
        store,
        (context, error, local) => shown.add(error.message),
        child: Builder(
          builder: (context) {
            builds++;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final initialBuilds = builds;
    await tester.runAsync(() async {
      await store.dispatchAndWait(_Increment());
      await store.dispatchAndWait(_Fail('silent', noDialog: true));
    });
    await tester.pump();
    expect(store.state, 1);
    expect(builds, initialBuilds);
    expect(shown, isEmpty);
    expect(store.errors, isEmpty);
  });

  testWidgets('Given an updated widget, when a pending error is displayed, '
      'then the latest callback and context option are used', (tester) async {
    final store = Store<int>(initialState: 0);
    addTearDown(store.shutdown);
    final shown = <String>[];
    await tester.pumpWidget(_app(store, (context, error, local) => shown.add('old')));
    await tester.runAsync(() => store.dispatchAndWait(_Fail('pending')));
    await tester.pumpWidget(
      _app(
        store,
        (context, error, local) => shown.add('${error.message}:$local'),
        useLocalContext: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(shown, ['pending:false']);
  });
}

Widget _app(
  Store<int> store,
  ShowUserExceptionDialog show, {
  Widget child = const SizedBox(),
  bool useLocalContext = true,
}) => StoreProvider<int>(
  store: store,
  child: MaterialApp(
    home: UserExceptionDialog<int>(
      onShowUserExceptionDialog: show,
      useLocalContext: useLocalContext,
      child: child,
    ),
  ),
);

class _Fail extends ReduxAction<int> {
  final String message;
  final bool noDialog;

  _Fail(this.message, {this.noDialog = false});

  @override
  int reduce() => throw UserException(message, ifOpenDialog: !noDialog);
}

class _Increment extends ReduxAction<int> {
  @override
  int reduce() => state + 1;
}
