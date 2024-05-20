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
        final store = Store<int>(initialState: 0);

        await tester.pumpWidget(StoreProvider<int>(
          store: store,
          child: _TestWidget(),
        ));

        expect(find.text("0"), findsOneWidget);

        store.dispatch(UpdateStateAction(1));
        await tester.pumpAndSettle();
        expect(find.text("0"), findsOneWidget);

        store.dispatch(UpdateStateAction(2));
        await tester.pumpAndSettle();
        expect(find.text("2"), findsOneWidget);
      },
    );

    testWidgets(
      "shouldUpdateModel.vm with external rebuild",
      (tester) async {
        final store = Store<int>(initialState: 0);

        await tester.pumpWidget(StoreProvider<int>(
          store: store,
          child: _TestWidget(),
        ));

        expect(find.text("0"), findsOneWidget);

        store.dispatch(UpdateStateAction(1));
        await tester.pump();
        await tester.pump();
        expect(find.text("0"), findsOneWidget);

        tester.firstState<_TestWidgetState>(find.byType(_TestWidget)).forceRebuild();
        await tester.pump();
        await tester.pump();
        expect(find.text("0"), findsOneWidget);
      },
    );

    testWidgets(
      "When the observed state changes, the widget rebuilds",
      (tester) async {
        final store = Store<AppState>(
          initialState: AppState(
            text: 'x',
            boolean: false,
          ),
        );

        await tester.pumpWidget(StoreProvider<AppState>(
          store: store,
          child: _AnotherConnector(),
        ));

        // Initially, that's what we have.
        expect(find.text("text: x / boolean: false"), findsOneWidget);

        store.dispatch(UpdateStateAction(
          AppState(text: 'y', boolean: false),
        ));

        await tester.pump();
        await tester.pump();
        expect(find.text("text: y / boolean: false"), findsOneWidget);

        store.dispatch(UpdateStateAction(
          AppState(text: 'y', boolean: true),
        ));

        await tester.pump();
        await tester.pump();
        expect(find.text("text: y / boolean: true"), findsOneWidget);
      },
    );

    testWidgets(
      "When 'isWaiting' changes, the widget rebuilds (notify true)",
      (tester) async {
        final store = Store<int>(initialState: 1);

        await tester.pumpWidget(StoreProvider<int>(
          store: store,
          child: _IsWaitingConnector(),
        ));

        // 1) Initially, we're NOT waiting.
        expect(find.text("isWaiting: false"), findsOneWidget);

        // 2) When we dispatch an ASYNC action, we ARE waiting.
        store.dispatch(_AsyncChangeStateAction(), notify: true);
        await tester.pump();
        expect(find.text("isWaiting: true"), findsOneWidget);

        // 3) After 99 milliseconds we are STILL waiting, because the action takes 100ms to finish.
        await tester.pump(const Duration(milliseconds: 99));
        print('store.state.text = ${'isWaiting: ${store.isWaiting(_AsyncChangeStateAction)}'}');
        expect(find.text("isWaiting: true"), findsOneWidget);

        // 4) After 1 more millisecond we are FINISHED WAITING, as the action finished.
        await tester.pump(const Duration(milliseconds: 1));
        print('store.state.text = ${'isWaiting: ${store.isWaiting(_AsyncChangeStateAction)}'}');
        expect(find.text("isWaiting: false"), findsOneWidget);
      },
    );

    testWidgets(
      "When 'isWaiting' changes, the widget rebuilds (notify false)",
      (tester) async {
        final store = Store<int>(initialState: 1);

        await tester.pumpWidget(StoreProvider<int>(
          store: store,
          child: _IsWaitingConnector(),
        ));

        // 1) Initially, we're NOT waiting.
        expect(find.text("isWaiting: false"), findsOneWidget);

        // 2) When we dispatch an ASYNC action, we ARE waiting.
        store.dispatch(_AsyncChangeStateAction(), notify: false);
        await tester.pump();
        expect(find.text("isWaiting: true"), findsOneWidget);

        // 3) After 99 milliseconds we are STILL waiting, because the action takes 100ms to finish.
        await tester.pump(const Duration(milliseconds: 99));
        print('store.state.text = ${'isWaiting: ${store.isWaiting(_AsyncChangeStateAction)}'}');
        expect(find.text("isWaiting: true"), findsOneWidget);

        // 4) After 1 more millisecond we are FINISHED WAITING, as the action finished.
        await tester.pump(const Duration(milliseconds: 1));
        print('store.state.text = ${'isWaiting: ${store.isWaiting(_AsyncChangeStateAction)}'}');
        expect(find.text("isWaiting: false"), findsOneWidget);
      },
    );

    testWidgets(
      "When 'isWaiting' changes, the widget rebuilds. "
      "The action fails with a dialog",
      (tester) async {
        final store = Store<int>(initialState: 1);

        await tester.pumpWidget(StoreProvider<int>(
          store: store,
          child: _IsWaitingConnector(),
        ));

        // 1) Initially, we're NOT waiting.
        expect(find.text("isWaiting: false"), findsOneWidget);

        // 2) When we dispatch an ASYNC action, we ARE waiting.
        store.dispatch(_AsyncChangeStateAction(failWithDialog: true));
        await tester.pump();
        expect(find.text("isWaiting: true"), findsOneWidget);

        // 3) After 99 milliseconds we are STILL waiting, because the action takes 100ms to finish.
        await tester.pump(const Duration(milliseconds: 99));
        print('store.state.text = ${'isWaiting: ${store.isWaiting(_AsyncChangeStateAction)}'}');
        expect(find.text("isWaiting: true"), findsOneWidget);

        // 4) After 1 more millisecond we are FINISHED WAITING, as the action finished.
        await tester.pump(const Duration(milliseconds: 1));
        print('store.state.text = ${'isWaiting: ${store.isWaiting(_AsyncChangeStateAction)}'}');
        expect(find.text("isWaiting: false"), findsOneWidget);
      },
    );

    testWidgets(
      "When 'isWaiting' changes, the widget rebuilds. "
      "The action fails with no dialog",
      (tester) async {
        final store = Store<int>(initialState: 1);

        await tester.pumpWidget(StoreProvider<int>(
          store: store,
          child: _IsWaitingConnector(),
        ));

        // 1) Initially, we're NOT waiting.
        expect(find.text("isWaiting: false"), findsOneWidget);

        // 2) When we dispatch an ASYNC action, we ARE waiting.
        store.dispatch(_AsyncChangeStateAction(failNoDialog: true));
        await tester.pump();
        expect(find.text("isWaiting: true"), findsOneWidget);

        // 3) After 99 milliseconds we are STILL waiting, because the action takes 100ms to finish.
        await tester.pump(const Duration(milliseconds: 99));
        print('store.state.text = ${'isWaiting: ${store.isWaiting(_AsyncChangeStateAction)}'}');
        expect(find.text("isWaiting: true"), findsOneWidget);

        // 4) After 1 more millisecond we are FINISHED WAITING, as the action finished.
        await tester.pump(const Duration(milliseconds: 1));
        print('store.state.text = ${'isWaiting: ${store.isWaiting(_AsyncChangeStateAction)}'}');
        expect(find.text("isWaiting: false"), findsOneWidget);
      },
    );
  });
}

class _TestWidget extends StatefulWidget {
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

////////////////////////////////////////////////////////////////////////////////////////////////////

class _AnotherWidget extends StatelessWidget {
  final String text;
  final bool boolean;

  const _AnotherWidget({
    required this.text,
    required this.boolean,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Text('text: $text / boolean: $boolean'),
    );
  }
}

class _AnotherConnector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, AnotherViewModel>(
      vm: () => AnotherFactory(this),
      builder: (context, vm) {
        return _AnotherWidget(
          text: vm.text,
          boolean: vm.boolean,
        );
      },
    );
  }
}

class AnotherFactory extends VmFactory<AppState, _AnotherConnector, AnotherViewModel> {
  AnotherFactory(connector) : super(connector);

  @override
  AnotherViewModel fromStore() {
    return AnotherViewModel(
      text: state.text,
      boolean: state.boolean,
    );
  }
}

class AnotherViewModel extends Vm {
  final String text;
  final bool boolean;

  AnotherViewModel({
    required this.text,
    required this.boolean,
  }) : super(equals: [text, boolean]);
}

class AppState {
  final String text;
  final bool boolean;

  AppState({
    required this.text,
    required this.boolean,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppState &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          boolean == other.boolean;

  @override
  int get hashCode => text.hashCode ^ boolean.hashCode;

  @override
  String toString() {
    return 'AppState{text: $text, boolean: $boolean}';
  }
}

////////////////////////////////////////////////////////////////////////////////////////////////////

class _IsWaitingWidget extends StatelessWidget {
  final bool isWaiting;

  const _IsWaitingWidget({required this.isWaiting});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: Text('isWaiting: $isWaiting'));
  }
}

class _IsWaitingConnector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StoreConnector<int, IsWaitingViewModel>(
      vm: () => IsWaitingFactory(this),
      builder: (context, vm) {
        return _IsWaitingWidget(isWaiting: vm.isWaiting);
      },
    );
  }
}

class IsWaitingFactory extends VmFactory<int, _IsWaitingConnector, IsWaitingViewModel> {
  IsWaitingFactory(connector) : super(connector);

  @override
  IsWaitingViewModel fromStore() {
    return IsWaitingViewModel(
      isWaiting: isWaiting(_AsyncChangeStateAction),
    );
  }
}

class IsWaitingViewModel extends Vm {
  final bool isWaiting;

  IsWaitingViewModel({
    required this.isWaiting,
  }) : super(equals: [isWaiting]);
}

class _AsyncChangeStateAction extends ReduxAction<int> {
  //
  final bool failWithDialog;
  final bool failNoDialog;

  _AsyncChangeStateAction({
    this.failWithDialog = false,
    this.failNoDialog = false,
  });

  @override
  Future<int?> reduce() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (failWithDialog) throw const UserException('Fail');
    if (failNoDialog) throw const UserException('Fail').noDialog;
    return null;
  }
}
