import 'package:async_redux/async_redux.dart';
import "package:test/test.dart";

class AppState {
  String text;

  AppState(this.text);
}

class MyAction extends ReduxAction<AppState> {
  int value;

  MyAction(this.value);

  @override
  AppState reduce() => AppState(state.text + value.toString());
}

class MyAction1 extends MyAction {
  MyAction1() : super(1);
}

class MyAction2 extends MyAction {
  MyAction2() : super(2);
}

class MyAction3 extends MyAction {
  MyAction3() : super(3);
}

class MyAction4 extends MyAction {
  MyAction4() : super(4);
}

class MyAction5 extends MyAction {
  MyAction5() : super(5);
}

class MyMockAction extends MockAction<AppState> {
  @override
  AppState reduce() => AppState(state.text + '[' + (action as MyAction).value.toString() + ']');
}

void main() {
  StoreTester<AppState> createMockStoreTester() {
    var store = MockStore<AppState>(initialState: AppState("0"));
    return StoreTester.from(store);
  }

  ///////////////////////////////////////////////////////////////////////////////

  test('Store: mock a single sync action.', () async {
    var store = MockStore<AppState>(initialState: AppState("0"));
    expect(store.state.text, "0");
    store.dispatch(MyAction1());
    expect(store.state.text, "01");

    // With mock:
    store = MockStore<AppState>(initialState: AppState("0"));
    expect(store.state.text, "0");
    store.addMock(
      MyAction1,
      (ReduxAction<AppState> action, AppState state) => AppState(state.text + 'A'),
    );
    store.dispatch(MyAction1());
    expect(store.state.text, "0A");
  });

  ///////////////////////////////////////////////////////////////////////////////

  test('StoreTester: mock a single sync action.', () async {
    // Without mock:
    var storeTester = createMockStoreTester();
    expect(storeTester.state.text, "0");
    storeTester.dispatch(MyAction1());
    expect(storeTester.state.text, "01");

    // With mock:
    storeTester = createMockStoreTester();
    expect(storeTester.state.text, "0");
    storeTester.addMock(
        MyAction1, (ReduxAction<AppState> action, AppState state) => AppState(state.text + 'A'));
    storeTester.dispatch(MyAction1());
    expect(storeTester.state.text, "0A");
  });

  ///////////////////////////////////////////////////////////////////////////////

  test('Store: mock sync actions in different ways.', () async {
    // Without mock:
    var store = MockStore<AppState>(initialState: AppState("0"));
    expect(store.state.text, "0");
    store.dispatch(MyAction1());
    store.dispatch(MyAction2());
    store.dispatch(MyAction3());
    store.dispatch(MyAction4());
    store.dispatch(MyAction5());
    expect(store.state.text, "012345");

    // With mock:
    store = MockStore<AppState>(initialState: AppState("0"));
    expect(store.state.text, "0");
    store.addMocks({
      /// 1) `null` to disable dispatching the action of a certain type.
      MyAction1: null,

      /// 2) A `MockAction<St>` instance to dispatch that action instead,
      /// and provide the original action as a getter to the mocked action.
      MyAction2: MyMockAction(),

      /// 3) A `ReduxAction<St>` instance to dispatch that mocked action instead.
      MyAction3: MyAction(7),

      /// 4) `ReduxAction<St> Function(ReduxAction<St>)` to create a mock
      /// from the original action,
      MyAction4: (ReduxAction<AppState> action) => MyAction((action as MyAction).value + 4),

      /// 5) `St Function(ReduxAction<St>, St)` to modify the state directly.
      MyAction5: (ReduxAction<AppState> action, AppState state) =>
          AppState(state.text + '|' + (action as MyAction).value.toString()),
    });
    store.dispatch(MyAction1());
    store.dispatch(MyAction2());
    store.dispatch(MyAction3());
    store.dispatch(MyAction4());
    store.dispatch(MyAction5());
    expect(store.state.text, "0[2]78|5");
  });

  ///////////////////////////////////////////////////////////////////////////////

  test("Mock can't be of invalid type.", () async {
    var store = MockStore<AppState>(initialState: AppState("0"));
    expect(store.state.text, "0");
    store.addMocks({MyAction1: 123});

    Object error;
    try {
      store.dispatch(MyAction1());
    } catch (_error) {
      error = _error;
    }

    expect(error, const TypeMatcher<StoreException>());
    expect(
        error.toString(),
        "Action of type `MyAction1` can't be mocked by a mock of type `int`.\n"
        "Valid mock types are:\n"
        "`null`\n"
        "`MockAction<St>`\n"
        "`ReduxAction<St>`\n"
        "`ReduxAction<St> Function(ReduxAction<St>)`\n"
        "`St Function(ReduxAction<St>, St)`\n");
  });

  ///////////////////////////////////////////////////////////////////////////////
}
