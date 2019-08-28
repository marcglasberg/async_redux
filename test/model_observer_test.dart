import 'dart:async';

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  //
  //////////////////////////////////////////////////////////////////////////////////////////////////
  testWidgets(
    //
    "ModelObserver.",
    //
    (WidgetTester tester) async {
      //
      Store<_StateTest> store = Store<_StateTest>(
        initialState: _StateTest("A", 1),
        modelObserver: _MyModelObserver(),
      );

      StoreProvider<_StateTest> provider = StoreProvider<_StateTest>(
        store: store,
        child: const _DumbWidgetConnectorTest(),
      );

      await tester.pumpWidget(_TestApp(provider));

      // A ➜ B
      expect(store.state.text, "A");
      store.dispatch(_MyAction("B", 1));
      expect(store.state.text, "B");

      await tester.pump();

      expect(_MyModelObserver.previous.text, "A");
      expect(_MyModelObserver.current.text, "B");

      // ---

      // B ➜ B
      expect(store.state.text, "B");
      store.dispatch(_MyAction("B", 2));
      expect(store.state.text, "B");

      await tester.pump();

      expect(_MyModelObserver.previous.text, "B");
      expect(_MyModelObserver.current.text, "B");

      // ---

      // B ➜ C
      expect(store.state.text, "B");
      store.dispatch(_MyAction("C", 1));
      expect(store.state.text, "C");

      await tester.pump();

      expect(_MyModelObserver.previous.text, "B");
      expect(_MyModelObserver.current.text, "C");

      // ---

      // C ➜ A
      expect(store.state.text, "C");
      store.dispatch(_MyAction("D", 1));
      expect(store.state.text, "D");

      await tester.pump();

      expect(_MyModelObserver.previous.text, "C");
      expect(_MyModelObserver.current.text, "D");
    },
  );
}

////////////////////////////////////////////////////////////////////////////////////////////////////

class _MyModelObserver<T> extends DefaultModelObserver<BaseModel> {
  static _MyViewModel previous;
  static _MyViewModel current;

  @override
  void observe({
    BaseModel modelPrevious,
    BaseModel modelCurrent,
    bool isDistinct,
    StoreConnector storeConnector,
    int reduceCount,
  }) {
    previous = modelPrevious;
    current = modelCurrent;

    super.observe(
      modelPrevious: modelPrevious,
      modelCurrent: modelCurrent,
      isDistinct: isDistinct,
      storeConnector: storeConnector,
      reduceCount: reduceCount,
    );
  }
}

////////////////////////////////////////////////////////////////////////////////////////////////////

class _TestApp extends StatelessWidget {
  final StoreProvider<_StateTest> provider;

  _TestApp(this.provider);

  @override
  Widget build(BuildContext context) => provider;
}

////////////////////////////////////////////////////////////////////////////////////////////////////

@immutable
class _StateTest {
  final String text;
  final int number;

  _StateTest(this.text, this.number);
}

////////////////////////////////////////////////////////////////////////////////////////////////////

class _DumbWidgetConnectorTest extends StatelessWidget {
  const _DumbWidgetConnectorTest();

  @override
  Widget build(BuildContext context) => StoreConnector<_StateTest, _MyViewModel>(
        debug: this,
        model: _MyViewModel(),
        builder: (context, vm) => Container(),
      );
}

class _MyViewModel extends BaseModel<_StateTest> {
  _MyViewModel();

  String text;

  _MyViewModel.build(this.text) : super(equals: [text]);

  @override
  _MyViewModel fromStore() => _MyViewModel.build(state.text);
}

////////////////////////////////////////////////////////////////////////////////////////////////////

class _MyAction extends ReduxAction<_StateTest> {
  String text;
  int number;

  _MyAction(this.text, this.number);

  @override
  FutureOr<_StateTest> reduce() => _StateTest(text, number);
}

////////////////////////////////////////////////////////////////////////////////////////////////////
