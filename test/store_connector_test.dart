import "package:async_redux/async_redux.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group(StoreConnector, () {
    // TODO shouldUpdateModel does not currently work with converter
    testWidgets(
      "shouldUpdateModel.converter",
      (tester) async {
        final storeTester = StoreTester<int>(initialState: 0);

        await tester.pumpWidget(StoreProvider<int>(
          store: storeTester.store,
          child: MaterialApp(
            home: StoreConnector<int, int>(
              converter: (store) => store.state,
              shouldUpdateModel: (state) => state % 2 == 0,
              builder: (context, value) {
                return Text(value.toString());
              },
            ),
          ),
        ));

        expect(find.text("0"), findsOneWidget);

        await storeTester.dispatchState(1);
        await tester.pumpAndSettle();
        expect(find.text("0"), findsOneWidget);

        await storeTester.dispatchState(2);
        await tester.pumpAndSettle();
        expect(find.text("2"), findsOneWidget);
      },
      skip: true,
    );

    testWidgets(
      "shouldUpdateModel.vm",
      (tester) async {
        final storeTester = StoreTester<int>(initialState: 0);

        await tester.pumpWidget(StoreProvider<int>(
          store: storeTester.store,
          child: _TestWidget(),
        ));

        expect(find.text("0"), findsOneWidget);

        await storeTester.dispatchState(1);
        await tester.pumpAndSettle();
        expect(find.text("0"), findsOneWidget);

        await storeTester.dispatchState(2);
        await tester.pumpAndSettle();
        expect(find.text("2"), findsOneWidget);
      },
    );

    testWidgets(
      "shouldUpdateModel.vm with external rebuild",
      (tester) async {
        final storeTester = StoreTester<int>(initialState: 0);

        await tester.pumpWidget(StoreProvider<int>(
          store: storeTester.store,
          child: _TestWidget(),
        ));

        expect(find.text("0"), findsOneWidget);

        storeTester.dispatchState(1);
        await tester.pump();
        await tester.pump();
        expect(find.text("0"), findsOneWidget);

        tester.firstState<_TestWidgetState>(find.byType(_TestWidget)).forceRebuild();
        await tester.pump();
        await tester.pump();
        expect(find.text("0"), findsOneWidget);
      },
    );
  });
}

class _TestWidget extends StatefulWidget {
  _TestWidget({
    Key? key,
  }) : super(key: key);

  @override
  State<_TestWidget> createState() => _TestWidgetState();
}

class _TestWidgetState extends State<_TestWidget> {
  void forceRebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: _TestContent(key: const ValueKey("tester")),
    );
  }
}

class _TestContent extends StatelessWidget {
  _TestContent({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StoreConnector<int, ViewModel>(
      vm: () => Factory(this),
      shouldUpdateModel: (state) => state % 2 == 0,
      builder: (context, vm) {
        return Text(vm.counter.toString());
      },
    );
  }
}

class Factory extends VmFactory<int, _TestContent, ViewModel> {
  Factory(connector) : super(connector);

  @override
  ViewModel fromStore() {
    return ViewModel(
      counter: state,
    );
  }
}

class ViewModel extends Vm {
  final int counter;

  ViewModel({
    required this.counter,
  }) : super(equals: [counter]);
}
