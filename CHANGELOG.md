Please visit the <a href="https://github.com/marcglasberg/redux_app_example">Redux App Example</a>
repository in GitHub for a full-fledged example with a complete app showcasing the fundamentals and
best practices described in the AsyncRedux Readme.

# [19.0.0-dev.7] - 2022/02/21

* Breaking change: The `Action.wrapError(error, stackTrace)` method now also gets the stacktrace
  instead of just the error. If your code breaks, just add the extra parameter, like so:
  `Object wrapError(error) => ...` turns into `Object wrapError(error, _) => ...`

<br>

* Breaking change: When a `Persistor` is provided to the Store, it now considers the
  `initialState` is already persisted. Before this change, it considered nothing was
  persisted. Note: Before you create the store, you are allowed to call the `Persistor` methods
  directly: `Persistor.saveInitialState()`, `readState()` and `deleteState()`.
  However, after you create the store, please don't call those methods yourself anymore.
  If you do it, AsyncRedux cannot keep track of which state was persisted. After store creation,
  if necessary, you should use the corresponding methods `Store.saveInitialStateInPersistence()`,
  `Store.readStateFromPersistence()` and `Store.deleteStateFromPersistence()`. These methods let
  AsyncRedux keep track of the persisted state, so that it's able to call
  `Persistor.persistDifference()` with the appropriate parameters.

<br>

* Method `Store.getLastPersistedStateFromPersistor()` returns the state that was last persisted
  to the local persistence. It's unlikely you will use this method yourself.

<br>

* Breaking change: The factory declaration used to have two type parameters, but now it has three:
  `class Factory extends VmFactory<AppState, MyConnector, MyViewModel>`
  With that change, you can now reference the view-model inside the Factory methods, by using
  the `vm` getter. Example:
    ```
    ViewModel fromStore() =>
      ViewModel(
        value: _calculateValue(),
        onTap: _onTap);
    }  
    
    void _onTap() => dispatch(SaveValueAction(vm.value)); // Use the value from the vm.
    ```

  Note 1: You can only use the `vm` getter after the `fromStore()` method is called, which means
  you cannot reference the `vm` inside of the `fromStore()` method itself. If you do that,
  you'll get a `StoreException`. You also cannot use the `vm` getter if the view-model is null.

  Note 2: To reduce boilerplate, and not having to pass the `AppState` type parameter whenever you
  create a Factory, I recommend you define a base Factory, like so:
    ```
    abstract class BaseFactory<T extends Widget?, Model extends Vm> extends VmFactory<AppState, T, Model> {
        BaseFactory([T? connector]) : super(connector);
    }
    ```

* Added class LocalJsonPersist to help persist the state as pure Json.

# [18.0.2] - 2022/12/11

* Fixed small bug when persistor is paused before being used once.

# [18.0.0] - 2022/10/23

* Version bump of dependencies.

# [17.0.1] - 2022/10/09

* Fixed issue with the StoreConnector.shouldUpdateModel method when the widget updates.

# [17.0.0] - 2022/09/15

* The `StateObserver.observe()` method signature changed to include an `error` parameter:
  ```
  void observe(
     ReduxAction<St> action,
     St stateIni,
     St stateEnd,
     Object? error,
     int dispatchCount,
     );
  ```

  The state-observers are now also called when the action reducer complete with a error.
  In this case, the `error` object will not be null. This makes it easier to use state-observers
  for metrics. Please, see the documentation for the recommended clean-code way to do this.

# [16.1.0] - 2022/09/13

* Added another cache function, for 2 states and 3 parameters: `cache2states_3params`.

# [16.0.0] - 2022/05/15

* Breaking change: Async `reduce()` methods (those that return Futures) are now called
  synchronously (in the same microtask of their dispatch), just like a regular async function is.
  In other words, now dispatching a sync action works just the same as calling a sync function,
  and dispatching an async action works just the same as calling an async function.

  ```
  // Example: The below code will print: "BEFORE a1 f1 AFTER a2 f2"  
  
  print('BEFORE');
  dispatch(MyAsyncAction());
  asyncFunction();
  print('AFTER');     
          
  class MyAsyncAction extends ReduxAction<AppState> {
     Future<AppState?> reduce() async {
        print('a1');
        await microtask;
        print('a2');
        return state;
        }  
  }
  
  Future<void> asyncFunction() async {
     print('f1');
     await Future.microtask((){});
     print('f2');     
     } 

  ```  

  Before version `16.0.0`, the `reduce()` method was called in a later microtask. Please note, the
  async `reduce()` methods continue to return and apply the state in a later microtask (this did
  not change).

  The above breaking change is unlikely to affect you in any way, but if you want the old behavior,
  just add `await microtask;` to the first line of your `reduce()` method.

<br>

* Breaking change: When your reducer is async (i.e., returns `Future<AppState>`) you must make sure
  you **do not return a completed future**, meaning all execution paths of the reducer must pass
  through at least one `await` keyword. In other words, don't return a Future if you don't need it.
  If your reducer has no `await`s, you must return `AppState?` instead of `Future<AppState?>`, or
  add `await microtask;` to the start of your reducer, or return `null`. For example:

  ```dart 
  // These are right:
  AppState? reduce() { return state; }
  AppState? reduce() { someFunc(); return state; }
  Future<AppState?> reduce() async { await someFuture(); return state; }
  Future<AppState?> reduce() async { await microtask; return state; }
  Future<AppState?> reduce() async { if (state.someBool) return await calculation(); return null; }
  
  // But these are wrong:
  Future<AppState?> reduce() async { return state; }
  Future<AppState?> reduce() async { someFunc(); return state; }
  Future<AppState?> reduce() async { if (state.someBool) return await calculation(); return state; }
  ```

  If you don't follow this rule, AsyncRedux may seem to work ok, but will eventually misbehave.

  It's generally easy to make sure you are not returning a completed future.
  In the rare case your reducer function is very complex, and you are unsure that all code paths
  pass through an `await`, just add `assertUncompletedFuture();` at the very END of your `reduce`
  method, right before the `return`. If you do that, an error will be shown in the console if
  the `reduce` method ever returns a completed future.

  If you're an advanced user interested in the details, check the
  <a href="https://github.com/marcglasberg/async_redux/blob/master/test/sync_async_test.dart">
  sync/async tests</a>.

<br>

* When the `Event` class was created, Flutter did not have another class with that name.
  Now there is. For this reason, a typedef now allows you to use `Evt` instead.
  If you need, you can hide one of them, by importing AsyncRedux like this:

  ```dart
  import 'package:async_redux/async_redux.dart' hide Event;
  ```
  or

  ```dart
  import 'package:async_redux/async_redux.dart' hide Evt;  
  ```

# [15.0.0] - 2022/05/12

* Flutter 3.0 support.

# [14.1.4] - 2022/05/10

* `NavigateAction.popUntilRouteName()` can print the routes (for debugging).

# [14.1.2] - 2022/04/21

* Better stacktrace for wrapped errors in actions.

# [14.1.1] - 2022/04/21

* The store persistor can now be paused and resumed, with methods `store.pausePersistor()`,
  `store.persistAndPausePersistor()` and `store.resumePersistor()`. This may be used together with
  the app lifecycle, to prevent a persistence process to start when the app is being shut down. For
  example:

  ```     
  child: StoreProvider<AppState>(
  store: store,
    child: AppLifecycleManager( // Add this widget here to capture lifecycle events.
      child: MaterialApp( 
  ...     
  
  class AppLifecycleManager extends StatefulWidget {
    final Widget child;
    const AppLifecycleManager({Key? key, required this.child}) : super(key: key);  
    _AppLifecycleManagerState createState() => _AppLifecycleManagerState();
  }
  
  class _AppLifecycleManagerState extends State<AppLifecycleManager> with WidgetsBindingObserver {
  
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }
  
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    store.dispatch(ProcessLifecycleChange_Action(lifecycle));
  }
  
  Widget build(BuildContext context) => widget.child;
  }

  class ProcessLifecycleChangeAction extends ReduxAction<AppState> {
     final AppLifecycleState lifecycle;
     ProcessLifecycleChangeAction(this.lifecycle);

     @override
     Future<AppState?> reduce() async {
       if (lifecycle == AppLifecycleState.resumed || lifecycle == AppLifecycleState.inactive) {
         store.resumePersistor();  
       } else if (lifecycle == AppLifecycleState.paused || lifecycle == AppLifecycleState.detached) {
         store.persistAndPausePersistor();
       } else
         throw AssertionError(lifecycle);

       return null;
     }
   }
  ```  

* When logging out of the app, you can call `store.deletePersistedState()` to ask the persistor to
  delete the state from disk.

* Breaking change: This is a very minor change, unlikely to affect you. The signature for
  the `Action.wrapError` method has changed from `Object? wrapError(error)`
  to `Object? wrapError(Object error)`. If you get an error when you upgrade, you can fix it by
  changing the method that broke into `Object? wrapError(dynamic error)`.

* Breaking change: Context is now nullable for these StoreConnector methods:
  ```
  void onInitialBuildCallback(BuildContext? context, Store<St> store, Model viewModel);
  void onDidChangeCallback(BuildContext? context, Store<St> store, Model viewModel);
  void onWillChangeCallback(BuildContext? context, Store<St> store, Model previousVm, Model newVm);
  ```   

# [13.3.1] - 2021/12/23

* Version bump of dependencies.

# [13.2.2] - 2021/12/23

* Version bump of dependencies.

# [13.2.1] - 2021/12/16

* Fixed `MockStore.dispatchAsync()` and `MockStore.dispatchSync()` methods.

# [13.2.0] - 2021/11/26

* `delay` parameter for `WaitAction.add()` and `WaitAction.remove()` methods.

# [13.1.0] - 2021/11/02

* Added missing `dispatchSync` and `dispatchAsync` to `StoreTester`.

# [13.0.6] - 2021/09/10

* Added missing `dispatchSync` to `VmFactory`.

# [13.0.5] - 2021/09/29

* Sometimes, the store state is such that it's not possible to create a view-model. In those cases,
  the `fromStore()` method in the `Factory` can now return a `null` view-model. In that case,
  the `builder()` method in the `StoreConnector` can detect that the view-model is `null`, and then
  return some widget that does not depend on the view-model. For example:

  ```
  return StoreConnector<AppState, ViewModel?>(
    vm: () => Factory(this),
    builder: (BuildContext context, ViewModel? vm) {
      return (vm == null)
        ? Text("The user is not logged in")
        : MyHomePage(user: vm.user)
  
  ...              
         
  class Factory extends VmFactory<AppState, MyHomePageConnector, ViewModel> {   
  ViewModel? fromStore() {
    return (store.state.user == null)
        ? null
        : ViewModel(user: store.state.user)
  
  ...
  
  class ViewModel extends Vm {
    final User user;  
    ViewModel({required this.user}) : super(equals: [user]);
  ```

# [13.0.4] - 2021/09/20

* `dispatch` can be used to dispatch both sync and async actions. It returns a `FutureOr`. You can
  await the result or not, as desired.

* `dispatchAsync` can also be used to dispatch both sync and async actions. But it always returns a
  `Future` (not a `FutureOr`). Use this only when you explicitly need a `Future`, for example, when
  working with the `RefreshIndicator` widget.

* `dispatchSync` allows you to dispatch SYNC actions only. In that case, `dispatchSync(action)` is
  exactly the same as `dispatch(action)`. However, if your action is ASYNC, `dispatchSync` will
  throw an error. Use this only when you need to make sure an action is sync (meaning it impacts the
  store state immediately when it returns). This is not very common. Important: An action is sync if
  and only if both its `before` and `reduce` methods are sync. If any or both these methods return a
  Future, then the action is async and will throw an error when used with `dispatchSync`.

* `StoreTester.getConnectorTester` helps test `StoreConnector`s methods, such as `onInit`,
  `onDispose` and `onWillChange`. For example, suppose you have a `StoreConnector` which
  dispatches `SomeAction` on its `onInit`. You could test it like this:

  ``` 
  class MyConnector extends StatelessWidget { 
     Widget build(BuildContext context) => StoreConnector<AppState, Vm>(
        vm: () => _Factory(), 
        onInit: _onInit, 
        builder: (context, vm) { ... } 
     } 
  
  void _onInit(Store<AppState> store) => store.dispatch(SomeAction()); 
  } 
  
  var storeTester = StoreTester(...); 
  var connectorTester = storeTester.getConnectorTester(MyConnector()); 
  connectorTester.runOnInit(); 
  var info = await tester.waitUntil(SomeAction);  
  ```
  For more information, see section **Testing the StoreConnector** in the readme file.

* Fix: `UserExceptionDialog` now shows all `UserException`s. It was discarding some of them under
  some circumstances, in a regression created in version 4.0.4.

* In the `Store` constructor you can now set `maxErrorsQueued` to control the maximum number of
  errors the `UserExceptionDialog` error-queue can hold. Default is `10`.

* `ConsoleActionObserver` is now provided to print action details to the console.

* `WaitAction.toString()` now returns a better description.

# [12.0.4] - 2021/08/19

* `NavigateAction.toString()` now returns a better description, like `Action NavigateAction.pop()`.

* Fixed `NavigateAction.popUntilRouteName` and `NavigateAction.pushNamedAndRemoveAll` to return the
  correct `.type`.

* Added section `Dependency Injection` in README.md.

# [12.0.3] - 2021/08/11

* Improved error messages when the reducer returns an invalid type.

* New `StoreTester` methods: `waitUntilAll()` and `waitUntilAllGetLast()`.

* Passing an environment to the store, to help with dependency injection: `Store(environment: ...)`

# [12.0.0] - 2021/06/29

* Breaking change: Improved state typing for some `Store` parameters. You will now have to use
  `Persistor<AppState>` instead of `Persistor`, and `WrapError<AppState>` instead of `WrapError`
  etc.

* Global `Store(wrapReduce: ...)`. You may now globally wrap the reducer to allow for some pre or
  post-processing. Note: if the action also have a wrapReduce method, this global wrapper will be
  called AFTER (it will wrap the action's wrapper which wraps the action's reducer).

* Downgraded dev_dependencies `test: ^1.16.0`

# [11.0.1] - 2021/06/22

* You can now provide callbacks `onOk` and `onCancel` to an `UserException`. This allows you to
  dispatch actions when the user dismisses the error dialog. When using the
  default `UserExceptionDialog`: (i) if only `onOk` is provided, it will be called when the dialog
  is dismissed, no matter how. (ii) If both `onOk` and `onCancel` are provided, then `onOk` will be
  called only when the OK button is pressed, while `onCancel` will be called when the dialog is
  dismissed by any other means.

# [11.0.0] - 2021/06/02

* Breaking change: The `dispatchFuture` function is not necessary anymore. Just rename it
  to `dispatch`, since now the `dispatch` function always returns a future, and you can await it or
  not, as desired.

* Breaking change: `ReduxAction.hasFinished()` has been deprecated. It should be renamed
  to `isFinished`.

* The `dispatch` function now returns an `ActionStatus`. Usually you will discard this info, but you
  may use it to know if the action completed with no errors. For example, suppose a `SaveAction`
  looks like this:

  ```                                      
  class SaveAction extends ReduxAction<AppState> {      
    Future<AppState> reduce() async {
	  bool isSaved = await saveMyInfo(); 
      if (!isSaved) throw UserException("Save failed.");	 
	  ...
    }
  }
  ```

  Then, when you save some info, you want to leave the current screen if and only if the save
  process succeeded:

  ```
  var status = await dispatch(SaveAction(info));
  if (status.isFinished) dispatch(NavigateAction.pop()); // Or: Navigator.pop(context) 
  ```              

# [10.0.1] - 2021/05/15

* Breaking change: The new `UserExceptionDialog.useLocalContext` parameter now allows
  the `UserExceptionDialog` to be put in the `builder` parameter of the `MaterialApp` widget. Even
  if you use this dialog, it is unlikely this will be a breaking change for you. But if it is, and
  your error dialog now has problems, simply make `useLocalContext: true` to return to the old
  behavior.

* Breaking change: `StoreConnector` parameters `onInitialBuild`, `onDidChange`
  and `onWillChange` now also get the context and the store. For example, where you previously
  had `onInitialBuild(vm) {...}` now you have `onInitialBuild(context, store, vm) {...}`.

# [9.0.9] - 2021/05/10

* LocalPersist `saveJson()` and `loadJson()` methods.

# [9.0.8] - 2021/04/26

* FIC and weak-map version bump.

# [9.0.7] - 2021/04/16

* NNBD improvements.
* FIC version bump.

# [9.0.1] - 2021/03/22

* Downgrade to file: ^6.0.0 to improve compatibility.

# [9.0.0] - 2021/03/03

* Nullsafe.

# [8.0.0] - 2021/02/21

* Uses nullsafe dependencies (it's not yet itself nullsafe).

* Breaking change: Cache functions (for memoization) have been renamed and extended.

# [7.0.2] - 2021/02/12

* LocalPersist: Better handling of mock file-systems.

# [7.0.1] - 2020/12/30

* Breaking change:

  Now the `vm` parameter in the `StoreConnector` is a function that creates a `VmFactory` (instead
  of being a `VmFactory` object itself).

  So, to upgrade, you just need to provide this:

  ```
  vm: () => MyFactory(this),
  ```

  Instead of this:

  ```                
  // Deprecated.
  vm: MyFactory(this), 
  ```

  Now the `StoreConnector` will create a `VmFactory` every time it needs a view-model. The Factory
  will have access to:

    1) `state` getter: The state the store was holding when the factory and the view-model were
       created. This state is final inside the factory.

    2) `currentState()` method: The current (most recent) store state. This will return the current
       state the store holds at the time the method is called.

* New store parameter `immutableCollectionEquality` lets you override the equality used for
  immutable collections from the <a href="https://pub.dev/packages/fast_immutable_collections">
  fast_immutable_collections</a> package.

# [6.0.3] - 2020/12/03

* StoreTester.dispatchState().

# [6.0.2] - 2020/11/16

* VmFactory.getAndRemoveFirstError().

# [6.0.1] - 2020/10/30

* `NavigateAction` now closely follows the `Navigator` api:  `push()`,
  `pop()`, `popAndPushNamed()`, `pushNamed()`, `pushReplacement()`, `pushAndRemoveUntil()`,
  `replace()`, `replaceRouteBelow()`, `pushReplacementNamed()`, `pushNamedAndRemoveUntil()`,
  `pushNamedAndRemoveAll()`, `popUntil()`, `removeRoute()`, `removeRouteBelow()`,
  `popUntilRouteName()` and `popUntilRoute()`.

# [5.0.0] - 2020/10/19

* Breaking change: OnWillChangeCallback now provides previousVm.

# [4.0.4] - 2020/10/19

* Better performance: Less unnecessary view-model calculations.
* StoreConnector.shouldUpdateModel fix.

# [4.0.1] - 2020/10/02

## Flutter 1.22 compatibility

Bumping _file: ^6.0.0-nullsafety.2_

<br>

## Breaking Change

The abstract `ReduxAction.reduce()` method signature has a return type of `FutureOr<AppState>`, but
your concrete reducers must return one or the other: `AppState` or `Future<AppState>`.

That's necessary because AsyncRedux knows if a reducer is sync or async not by checking the returned
type, but by checking your `reducer()` method signature. If it is `FutureOr<AppState>`, AsyncRedux
can't know if it's sync or async, and will throw a `StoreException`:

```
Reducer should return `St?` or `Future<St?>`. Do not return `FutureOr<St?>`.
```

<br>

## Breaking Change

Previously to version 4.0.0, your *async* reducers would have to make sure never to return completed
futures. This is no longer necessary in version 4.0.0.

Now, while *sync* reducers continue to run synchronously with the dispatch, the *async* reducers
will not be called immediately, but will be scheduled in a later task.

Why is this a breaking change? Previously to version 4.0.0, the async reducers would have at least
started synchronously with the dispatch, and would run synchronously until the first `await`. You
probably shouldn't be counting on the executing order of the beginning of async reducers anyway, so
your code is unlikely to break after upgrading to version 4.0.0. But, please run your tests in this
new version and open an issue if it has created any problems for you that you think would make it
difficult to migrate.

<br>

## Deprecated

`StoreConnector`'s `model` parameter is now deprecated. It expects a `BaseModel`
object, which is also deprecated. AsyncRedux run the `BaseModel.fromStore()`
method to obtain yet another object of type `BaseModel`, which is the view-model used by the
connector.

While the `model` parameter is easy to use, it is also easy to use it wrong.

Instead, you should now use the `StoreConnector`'s `vm` parameter to pass an object of
type `VmFactory`. AsyncRedux will run the `VmFactory.fromStore()`
method to obtain an object of type `Vm`, which is now the view-model used by the connector.
Note: `Vm` is immutable, and all its fields must be final.

AsyncRedux will inject the `state` and the `dispatch`/`dispatchFuture` methods into `VmFactory`, so
that you easily can create any fields and methods you need to help you build the view-model.

This is a complete example:

```dart
class MyHomePageConnector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, ViewModel>(
        vm: () => Factory(this),
        builder: (BuildContext context, ViewModel vm) =>
            MyHomePage(
              counter: vm.counter,
              onIncrement: vm.onIncrement,
            ));
  }
}

class Factory extends VmFactory<AppState, MyHomePageConnector, ViewModel> {
  Factory(connector) : super(connector);

  @override
  ViewModel fromStore() =>
      ViewModel(
        counter: state.counter,
        onIncrement: () => dispatch(IncrementAndGetDescriptionAction()),
      );
}

class ViewModel extends Vm {
  final int counter;
  final String description;

  ViewModel({
    required this.counter,
    required this.onIncrement,
  }) : super(equals: [counter]);
}
```

Please note, `StoreConnector`'s `converter` parameter still works and will NOT be deprecated.

<br>

## View-model equality

Just as before, if you provide the `Vm.equals` field in the constructor, it will automatically
create equals/hashcode for you, so that the connector can know when the view-model changed, and
rebuild. However, you can now provide your own comparison method, if you want. To that end, your
state classes must implement the `VmEquals` interface. As a default, objects of type `VmEquals`
are compared by identity, while all other object types are, as usual, compared by equality. You may
then override the `VmEquals.vmEquals()` method to provide your custom comparisons.

<br>
<br>
<br>

# [3.0.5] - 2020/08/18

* Action.after() will now throw the error asynchronously (instead of swallowing it).

# [3.0.4] - 2020/08/13

* Fix: withoutHardCause was removing the code field.

# [3.0.3] - 2020/08/11

* cache3.
* LocalPersist is exported separately.

# [3.0.0] - 2020/07/27

* Works for Web.

# [2.13.1] - 2020/07/17

* WrapError may now convert to any error type.
* UserException hardCause() and withoutHardCause() methods.

# [2.13.0] - 2020/07/16

* typedef Reducer.
* ReduxAction.wrapReduce().

# [2.12.3] - 2020/07/08

* Docs improvement.

# [2.12.2] - 2020/06/30

* Global WrapError now gets error, stackTrace, and action (none of them optional).
* MockStore (still experimental, in `mock_store.dart`), lets you mock or disable actions/reducers
  during tests.
  (See section `Mocking actions and reducers` in README.md).
* ReduxAction.status and ReduxAction.isFinished. (Search for "Action status" in README.md).
* ReduxAction.reduceWithState deprecated (will be removed).

# [2.11.1] - 2020/06/12

* Added cache/reselector functions with 1 or 2 states and zero parameters: `cache1` and `cache2`.
* Breaking change: Other cache/reselector functions are now named `cache1_1`, `cache1_2`, `cache2_1`
  , and `cache2_2`.
* Breaking change: Dispatch/DispatchFuture with `notify: false` will change the state but not
  rebuild widgets.

# [2.10.0] - 2020/06/01

* BaseModel now doesn't give direct access to the store, and doesn't read the state from the store
  anymore. The state is now copied and kept constant in the view-model, as it should.

# [2.9.0] - 2020/05/25

* Stacktrace in WrapError.
* EventMultiple (Event.map).

# [2.8.11] - 2020/05/19

* <a href="https://pub.dev/packages/async_redux#reselectors">Reselectors</a>.

# [2.8.7] - 2020/05/15

* Store.stateTimestamp now records the timestamp when the current state in the store was created.

# [2.8.6] - 2020/05/13

* Fixed corner case for StoreTester.waitAll.

# [2.8.5] - 2020/05/12

* Small fixes: better generics; Better waitCondition stream close.

# [2.8.4] - 2020/05/08

* Fix LocalPersist imports.
* Fix abortDispatch not getting the state.

# [2.8.1] - 2020/05/01

* A filesystem may be injected into LocalPersist (usually to be used with MemoryFileSystem).
* Fix: LocalPersist.subDirs.

# [2.8.0] - 2020/04/30

* Store.waitCondition() returns a future which will complete when the state meets a given condition.

* Breaking change: StoreTester.waitCondition() now accepts a parameter called testImmediately. When
  testImmediately is true (now the default), it will test the condition immediately when the method
  is called. If the condition is true, the method will return immediately, without waiting for any
  actions to be dispatched. When testImmediately is false (the old behavior), it will only test the
  condition once an action is dispatched.

# [2.7.3] - 2020/04/30

* Fix: When dbName is a String, LocalPersist doesn't break it in the dot anymore.
* LocalPersist subDirs.

# [2.7.2] - 2020/04/24

* WaitAction now has dynamic generic type in TestInfo.type (compatible with the StoreTester).

# [2.7.1] - 2020/04/15

* WaitAction is now compatible with BuiltValue and Freezed packages.

# [2.7.0] - 2020/04/14

* WaitAction (Search for "Progress indicators" in README.md).
* Example: main_wait_action_simple.dart
* Example: main_wait_action_advanced_1.dart
* Example: main_wait_action_advanced_2.dart

# [2.6.0] - 2020/04/01

* The default timeout for the StoreTester wait functions can now be globally changed.
* The default debug information printed to the console can now be changed or turned off globally.

# [2.5.8] - 2020/03/17

* NavigateAction.push(Route).

# [2.5.7] - 2020/03/09

* Action.abortDispatch.

# [2.5.6] - 2020/03/05

* Fixed orElse in TestInfo operator [].

# [2.5.5] - 2020/02/18

* StoreTester.lastInfo (Search for "lastInfo" in README.md).
* PersistorPrinterDecorator: saveInitialState linked to the correct method.
* Fix failing tests by ensuring initialization.

# [2.5.4] - 2020/02/18

* Docs improvement.

# [2.5.3] - 2020/01/29

* Removes the generic type from PersistAction in tests.

# [2.5.2] - 2020/01/28

* Errors queue is cloned in TestInfo.

# [2.5.1] - 2020/01/26

* NavigateAction.pushNamedAndRemoveUntil.

# [2.5.0] - 2020/01/20

* Breaking change: The StoreConnector's shouldUpdateModel parameter now functions properly. If you
  are using this, make sure you return true to apply changes (the default when the parameter is not
  defined), and false to ignore model changes.

# [2.4.4] - 2019/01/13

* StoreTester dispatchFuture.

# [2.4.3] - 2019/01/11

* Small UserExceptionDialog web fix.

# [2.4.2] - 2019/12/18

* TestInfo.type now returns generic NavigateAction and UserExceptionAction, to play well with the
  StoreTester.

# [2.4.1] - 2019/12/10

* Breaking change: Global WrapError, if defined, now receives all errors, including UserExceptions.

# [2.3.3] - 2019/12/07

* iOS specific dialog for UserExceptions.

# [2.3.2] - 2019/11/28

* Docs improvement.

# [2.3.0] - 2019/11/19

* Global ignore in the StoreTester constructor.
* Better treatment of wrap-errors that throw.
* Breaking change: LocalPersist (instead of Saver/Loader).

# [2.2.0] - 2019/11/15

* Breaking change: PersistObserver became Persistor (and other renames).
* PersistorPrinterDecorator. PersistorDummy.

# [2.1.9] - 2019/11/12

* Saver/Loader.

# [2.1.4] - 2019/11/10

* PersistObserver.

# [2.1.3] - 2019/10/30

* Removed deprecated ignoreChange. Use shouldUpdateModel instead.

# [2.1.0] - 2019/10/27

* Better translations support for UserException.
* Global WrapError in the store.

# [2.0.6] - 2019/10/07

* Added sync_async_test.dart
* Doc warning about async reducer returning completed future (missing await).

# [2.0.5] - 2019/10/05

* Better typing of StoreProvider.dispatch and StoreProvider.dispatchFuture.

# [2.0.4] - 2019/10/01

* StoreTester.waitUntilError and waitUntilErrorGetLast.

# [2.0.3] - 2019/09/21

* NavigateAction tests.
* Navigation arguments.

# [2.0.2] - 2019/09/21

* UserExceptionAction.

# [2.0.1] - 2019/09/19

* Fix: UserException.dialogContent accepts String as cause.

# [2.0.0] - 2019/09/17

* Breaking change: ErrorObserver API.
* StoreTester parameter: shouldThrowUserExceptions (
  see <a href="https://github.com/marcglasberg/async_redux/issues/20">issue</a>).

# [1.4.3] - 2019/09/15

* Alternative: Use AsyncRedux with Provider (package provider_for_redux).

# [1.4.1] - 2019/09/06

* Flutter Awesome badge, and Pub badge.

# [1.4.0] - 2019/09/02

* Fix: dispatchFuture getter in ReduxAction.

# [1.3.9] - 2019/08/31

* NavigateAction.navigatorKey getter.

# [1.3.8] - 2019/08/30

* Alternatives to the Connector (StoreProvider static methods).
* Waiting until an Action is finished (dispatchFuture).

# [1.3.7] - 2019/08/28

* ModelObserver and DefaultModelObserver.

# [1.3.5] - 2019/08/27

* README improvement.

# [1.3.3] - 2019/08/26

* StoreConnector's converter and model parameters.

# [1.2.3] - 2019/08/23

* StoreTester timeout message.

# [1.2.0] - 2019/08/22

* Doc improvement. StoreTester improvements.

# [1.1.3] - 2019/08/21

* StoreTester: waitCondition and waitConditionGetLast.

# [1.1.2] - 2019/08/13

* README improvement.

# [1.1.1] - 2019/08/10

* Ignore actions in the StoreTester.

# [1.1.0] - 2019/08/07

* Correct stacktrace for unwrapped action errors.

# [1.0.9] - 2019/08/07

* Error message improvement.

# [1.0.4] - 2019/08/05

* Store tester.

# [1.0.0] - 2019/08/05

* Initial commit.
