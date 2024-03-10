import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  //
  testWidgets(
    //
    "ModelObserver.",
    //
    (WidgetTester tester) async {
      //
      var modelObserver = DefaultModelObserver<String>();

      Store<_StateTest> store = Store<_StateTest>(
        initialState: _StateTest("A", 1),
        modelObserver: modelObserver,
      );

      StoreProvider<_StateTest> provider = StoreProvider<_StateTest>(
        store: store,
        child: const _MyWidgetConnector(),
      );

      await tester.pumpWidget(_TestApp(provider));

      // A ➜ B
      expect(store.state.text, "A");
      store.dispatch(_MyAction("B", 1));
      expect(store.state.text, "B");

      await tester.pump();

      expect(modelObserver.previous, "A");
      expect(modelObserver.current, "B");

      // ---

      // B ➜ B
      expect(store.state.text, "B");
      store.dispatch(_MyAction("B", 2));
      expect(store.state.text, "B");

      await tester.pump();

      expect(modelObserver.previous, "B");
      expect(modelObserver.current, "B");

      // ---

      // B ➜ C
      expect(store.state.text, "B");
      store.dispatch(_MyAction("C", 1));
      expect(store.state.text, "C");

      await tester.pump();

      expect(modelObserver.previous, "B");
      expect(modelObserver.current, "C");

      // ---

      // C ➜ A
      expect(store.state.text, "C");
      store.dispatch(_MyAction("D", 1));
      expect(store.state.text, "D");

      await tester.pump();

      expect(modelObserver.previous, "C");
      expect(modelObserver.current, "D");
    },
  );
}

class _TestApp extends StatelessWidget {
  final StoreProvider<_StateTest> provider;

  _TestApp(this.provider);

  @override
  Widget build(BuildContext context) => provider;
}

@immutable
class _StateTest {
  final String text;
  final int number;

  _StateTest(this.text, this.number);
}

class _MyWidgetConnector extends StatelessWidget {
  const _MyWidgetConnector();

  @override
  Widget build(BuildContext context) => StoreConnector<_StateTest, String>(
        debug: this,
        converter: (Store<_StateTest> store) => store.state.text,
        builder: (BuildContext context, String model) => Container(),
      );
}

class _MyAction extends ReduxAction<_StateTest> {
  String text;
  int number;

  _MyAction(this.text, this.number);

  @override
  _StateTest reduce() => _StateTest(text, number);
}
