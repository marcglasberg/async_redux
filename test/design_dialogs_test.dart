import 'package:async_redux/async_redux.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _FailAction extends ReduxAction<int> {
  @override
  int reduce() => throw const UserException('Upgrade failure');
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('default error dialog uses standalone design types on $platform', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final store = Store<int>(initialState: 0);
      store.dispatchSync(_FailAction());
      await tester.pumpWidget(
        StoreProvider<int>(
          store: store,
          child: MaterialApp(
            home: UserExceptionDialog<int>(
              useLocalContext: true,
              child: const SizedBox(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Upgrade failure'), findsOneWidget);
      expect(
        find.byType(platform == TargetPlatform.iOS ? CupertinoAlertDialog : AlertDialog),
        findsOneWidget,
      );
      expect(store.errors, isEmpty);
      await tester.pumpWidget(const SizedBox());
      store.shutdown();
    });
  }
}
