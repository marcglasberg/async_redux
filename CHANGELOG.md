_Please visit
an <a href="https://github.com/marcglasberg/SameAppDifferentTech/blob/main/MobileAppFlutterRedux/README.md">
Async Redux App Example Repository</a> in GitHub for a full-fledged example with a complete app
showcasing the fundamentals and best practices described in the AsyncRedux README.md file._

# 22.4.8

* For those who use `flutter_hooks`, you can now use the
  new https://pub.dev/packages/flutter_hooks_async_redux package
  to add Redux to flutter_hooks.

# 22.3.0

* In the `reduce` method of your actions you can now access the _initial state_ of the action, by
  using the `initialState` getter. In other words, you have access to a copy of the state as it was
  when the action was first dispatched. This is useful when you need to calculate some value
  asynchronously, and then you only want to apply the result to the state if that value hasn't
  changed in the meantime. For example:

  ```dart
  class MyAction extends ReduxAction<AppState> {
    Future<AppState> reduce() async {
      var newValue = await someAsyncStuff();
      if (state.value == initialState.value) return state.copyWith(value: newValue);
      else return null;
    }
  }
  ```   

# 22.1.0

* You can now use `var isWaiting = context.isWaiting(MyAction)` to check if an async action of
  the given type is currently being processed. You can then use this boolean to show a loading
  spinner in your widget.
  Note: Inside your `VmFactory` you can also use `isWaiting: isWaiting(MyAction)`. See
  the <a href="https://github.com/marcglasberg/async_redux/blob/master/example/lib/main_show_spinner.dart">
  Show Spinner Example</a>.


* You can now use `var isFailed = context.isFailed(MyAction)` to check if an action of the given
  type has thrown an `UserException`. You can then use this boolean to show an error message.
  You can also get the exception with `var exception = context.exceptionFor(MyAction)` to use its
  error message, and clear the exception with `context.clearExceptionFor(MyAction)`.
  Note: Inside your `VmFactory` you can also use `isFailed: isFailed(MyAction)` etc. See
  the <a href="https://github.com/marcglasberg/async_redux/blob/master/example/lib/main_show_error_dialog.dart">
  Show Error Dialog Example</a>.


* You can add **mixins** to your actions, to accomplish common tasks:

    - `CheckInternet` ensures actions only run with internet, otherwise an error dialog
      prompts users to check their connection:

      ```dart
      class LoadText extends ReduxAction<AppState> with CheckInternet {
          
      Future<String> reduce() async {
          var response = await http.get('http://numbersapi.com/42');
          ...      
      }}
      ```

    - `NoDialog` can be added to `CheckInternet` so that no dialog is opened.
      Instead, you can display some information in your widgets:

      ```dart
      class LoadText extends Action with CheckInternet, NoDialog { ... }
      
      if (context.isFailed(LoadText)) Text('No Internet connection');
      ```

    - `AbortWhenNoInternet` aborts the action silently (without showing any dialogs)
      if there is no internet connection.

    - `NonReentrant` prevents reentrant actions, so that when you dispatch an action
      that's already running it gets aborted (no errors are shown).

    - `Retry` retries the action a few times with exponential backoff, if it fails.
      Add `UnlimitedRetries` to retry the action indefinitely:

      ```dart
      class LoadText extends ReduxAction<AppState> with Retry, UnlimitedRetries, NonReentrant { 
      ```

  Other mixins will be provided in the future, for Throttling, Debouncing and Caching.

* Some features of the `async_redux` package are now available in a standalone Dart-only core
  package: https://pub.dev/packages/async_redux_core. You may use that core package when you
  are developing a Dart server (backend) with [Celest](https://celest.dev/), or when developing your
  own Dart-only package that does not depend on Flutter. Note: For the moment, the core
  package simply contains the `UserException`, and nothing more. If you now
  import `async_redux_core` in your Celest server code and throw an `UserException` there, the
  exception message will automatically be shown in a dialog to the user in your client app (if you
  use the `UserExceptionDialog` feature).

  > **For Flutter applications nothing changes.**
  > You don't need to import the core package directly.
  > You should continue to use this async_redux package, which already exports
  > the code that's now in the core package.


* You can now access the store inside of widgets, and have your widgets rebuild when the state
  changes, by using `context.state` and `context.dispatch` etc. This is only useful when you want to
  access the store state, and dispatch actions directly inside your widgets, instead of using
  the `StoreConnector` (dumb widget / smart widget pattern). For example:

  ```dart
  // Read state (will rebuild when the state changes) 
  var myInfo = context.state.myInfo;
  
  // Dispatch action
  context.dispatch(MyAction());
  
  // Use isWaiting to show a spinner
  if (context.isWaiting(MyAction)) return CircularProgressIndicator();
  
  // Use isFailed to show an error message
  if (context.isFailed(MyAction)) return Text('Loading failed');
                                                                   
  // Use exceptionFor to get the error message from the exception
  if (context.isFailed(MyAction)) return Text(context.exceptionFor(MyAction).message);
  
  // Use clearExceptionFor to clear the error
  context.clearExceptionFor(MyAction);
  ```      

  However, to use `context.state` like shown above you must define this extension method in your own
  code (supposing your state class is called `AppState`):

  ```dart  
  extension BuildContextExtension on BuildContext {
     AppState get state => getState<AppState>();       
  }
  ```     

  See
  the: <a href="https://github.com/marcglasberg/async_redux/blob/master/example/lib/main_conector_vs_provider.dart.dart">
  Connector vs Provider Example</a>.


* You can now get and set properties in the `Store` using the `prop` and `setProp` methods.
  These methods are available in `Store`, in `ReduxAction`, and in `VmFactory`.
  They can be used to save global values, but scoped to the store.
  For example, you could save timers, streams or futures used by actions:

  ```dart  
  setProp("timer", Timer(Duration(seconds: 1), () => print("tick")));
  var timer = prop<Timer>("timer");
  timer.cancel();
  ```   

  You can later use `store.disposeProps` to stop, close or ignore, all stream related objects,
  timers and futures, saved as props in the store. It will also remove them from there.

# 22.0.0

* BREAKING CHANGE: `StoreConnector.model` was removed, after being deprecated for a long
  time. Please, use the `vm` parameter instead. See classes `VmFactory` and `Vm`.

* BREAKING CHANGE: `ReduxAction.reduceWithState()` was removed, after being deprecated for a long
  time.

* BREAKING CHANGE: `StoreProvider.of` was removed. See `context.state` and `context.dispatch` etc,
  in version 22.1.0 above.

* BREAKING CHANGE: The `UserException` class was modified so that it was possible to move it to the
  `async_redux_core`. If your use of `UserException` was limited to specifying the error message,
  then you don't need to change anything: `throw UserException('Error message')` will continue to
  work as before. However, for other more advanced features you will have to read
  the `UserException` documentation and adapt. In the new public API of `UserException` you can now
  specify a `message`, `reason`, `code`, `errorText` and `ifOpenDialog` in the constructor, and
  then you can use methods `addCallbacks`, `addCause`, `addProps`, `withErrorText` and `noDialog`
  to add more information:

  ```dart
  throw UserException('Invalid number', reason: 'Must be less than 42')
     .addCallbacks(onOk: () => print('OK'), onCancel: () => print('CANCEL'))
     .addCause(FormatException('Invalid input'))
     .addProps({'number': 42}))                                                  
     .withErrorText('Type a smaller number')
     .noDialog;
  ```                  

  Note the `code` parameter can only be a number now. If you were using a different type,
  for example enums, you can now include it in the props, like
  so: `throw UserException('').addProps({'code': myError.invalidInput}).` or you can even create
  an extension method which allows you to
  write `throw UserException('').withCode(myError.invalidInput).`
  However, please read the new `UserException` documentation to learn about the recommended way to
  use `code` to define the text of the error messages, and even easily translate them to the user
  language by using the [i18n_extension](https://pub.dev/packages/i18n_extension) translations
  package.

* To test the view-model generated by a `VmFactory`, you can now use the static
  method `Vm.createFrom(store, factory)`. The method will return the view-model, which you can use
  to inspect the view-model properties directly, or call any of the view-model callbacks. Example:

  ```dart
  var store = Store(initialState: User("Mary"));
  var vm = Vm.createFrom(store, MyFactory());
  
  // Checking a view-model property.    
  expect(vm.user.name, "Mary");
  
  // Calling a view-model callback and waiting for the action to finish.  
  vm.onChangeNameTo("Bill"); // Dispatches SetNameAction("Bill").
  await store.waitActionType(SetNameAction);
  expect(store.state.name, "Bill");    
  
  // Calling a view-model callback and waiting for the state to change.
  vm.onChangeNameTo("Bill"); // Dispatches SetNameAction("Bill").
  await store.waitCondition((state) => state.name == "Bill");
  expect(store.state.name, "Bill");
  ```

* DEPRECATION WARNING: While the `StoreTester` is a powerful tool with advanced features that are
  beneficial for the most complex testing scenarios, for **almost all tests** it's now recommended
  to use the `Store` directly. This approach involves waiting for an action to complete its dispatch
  process or for the store state to meet a certain condition. After this, you can verify the current
  state or action using the new
  methods `store.dispatchAndWait`, `store.waitCondition`, `store.waitActionCondition`,
  `store.waitAllActions`, `store.waitActionType`, `store.waitAllActionTypes`,
  and `store.waitAnyActionTypeFinishes`. For example:

  ```dart
  // Wait for some action to dispatch and check the state. 
  await store.dispatchAndWait(MyAction());
  expect(store.state.name, 'John')
  
  // Wait for some action to dispatch, and check for errors in the action status.
  var status = await dispatchAndWait(MyAction());
  expect(status.originalError, isA<UserException>());
  
  // Dispatches two actions in SERIES (one after the other).
  await dispatchAndWait(SomeAsyncAction());
  await dispatchAndWait(AnotherAsyncAction());
  
  // Dispatches two actions in PARALLEL and wait for their TYPES.
  expect(store.state.portfolio, ['TSLA']);
  dispatch(BuyAction('IBM'));
  dispatch(SellAction('TSLA'));
  await store.waitAllActionTypes([BuyAction, SellAction]);
  expect(store.state.portfolio, ['IBM']);
  
  // Dispatches two actions in PARALLEL and wait for them.
  let action1 = BuyAction('IBM');
  let action2 = BuyAction('TSLA');
  dispatch(action1);
  dispatch(action2);
  await store.waitAllActions([action1, action2]);
  expect(store.state.portfolio.containsAll('IBM', 'TSLA'), isFalse);
  
  // Wait until no actions are in progress.
  dispatch(BuyStock('IBM'));
  dispatch(BuyStock('TSLA'));  
  await waitAllActions([]);                 
  expect(state.stocks, ['IBM', 'TSLA']);
  
  // Wait for some action of a given type.
  dispatch(ChangeNameAction());
  var action = store.waitActionType(ChangeNameAction);
  expect(action, isA<ChangeNameAction>());
  expect(action.status.isCompleteOk, isTrue);
  expect(store.state.name, 'Bill');
  
  // Wait until any action of the given types finishes dispatching.
  dispatch(BuyOrSellAction());   
  var action = store.waitAnyActionTypeFinishes([BuyAction, SellAction]);  
  expect(store.state.portfolio.contains('IBM'), isTrue);
  
  // Wait for some state condition.
  expect(store.state.name, 'John')               
  dispatch(ChangeNameAction("Bill"));
  var action = await store.waitCondition((state) => state.name == "Bill");
  expect(action, isA<ChangeNameAction>());
  expect(store.state.name, 'Bill');  
  ```                          

  Note the `StoreTester` will NOT be removed, now or in the future. It's just not the recommended
  way to test the store anymore.

# 21.7.1

* DEPRECATION WARNING:
    - Replace `action.isFinished` with `action.status.isCompletedOk`
    - Replace `action.status.isBeforeDone` with `action.status.hasFinishedMethodBefore`
    - Replace `action.status.isReduceDone` with `action.status.hasFinishedMethodReduce`
    - Replace `action.status.isAfterDone` with `action.status.hasFinishedMethodAfter`
    - Replace `action.status.isFinished` with `action.status.isCompletedOk`


* The `action.status` now has a few more values:
    - `isCompleted` if the action has completed executing, either with or without errors.
    - `isCompletedOk` if the action has completed with no errors.
    - `isCompletedFailed` if the action has completed with errors.
    - `originalError` Holds the error thrown by the action's before/reduce methods, if any.
    - `wrappedError` Holds the error thrown by the action, after it was processed by the
      action's `wrapError` and the `globalWrapError`.

# 21.6.0

* DEPRECATION WARNING: The `wrapError` parameter of the `Store` constructor is now deprecated in
  favor of the `globalWrapError` parameter. The reason for this deprecation is that the
  new `GlobalWrapError` works in the same way as the action's `ReduxAction.wrapError`,
  while `WrapError` does not. The difference is that when `WrapError` returns `null`, the original
  error is not modified, while with `GlobalWrapError` returning `null` will instead disable the
  error. In other words, where your old `WrapError` returned `null`, your new `GlobalWrapError`
  should return the original `error`:

  ```
  // WrapError (deprecated):
  Object? wrap(error, stackTrace, action) {
     if (error is MyException) return null; // Keep the error unaltered.
     else return processError(error);
  }
  
  // GlobalWrapError:
  Object? wrap( error, stackTrace, action) {
     if (error is MyException) return error; // Keep the error unaltered.
     else return processError(error);
  }
  ```
  Also note, `GlobalWrapError` is more powerful because it can disable the error,
  whereas `WrapError` cannot.

* Throwing an error in the action's `wrapError` or in the `GlobalWrapError` was disallowed
  (you needed to make sure it never happened). Now, it's allowed. If instead of RETURNING an error
  you THROW an error inside these wrappers, AsyncRedux will catch it and use it instead the original
  error. In other words, returning an error or throwing an error from inside the wrappers now has
  the same effect. However, it is still recommended to return the error rather than throwing it.

# 21.5.0

* DEPRECATION WARNING: Method `dispatchAsync` was renamed to `dispatchAndWait`. The old name is
  still available, but deprecated and will be removed. The new name is more descriptive of what the
  method does, and the fact that `dispatchAndWait` can be used to dispatch both sync and async
  actions. The only difference between `dispatchAndWait` and `dispatch` is that `dispatchAndWait`
  returns a `Future` which can be awaited to know when the action is finished.

# 21.1.1

* `await StoreTester.dispatchAndWait(action)` dispatches an action, and then waits until it
  finishes. This is the same as
  doing: `storeTester.dispatch(action); await storeTester.wait(action);`.

# 21.0.2

* Flutter 3.16.0 compatible.

# 20.0.2

* Fixed `WrapReduce` (which may be used to wrap the reducer to allow for some pre- or
  post-processing) to avoid async reducers to be called twice.

# 20.0.0

* Flutter 3.10.0 and Dart 3.0.0

# 19.0.2

* Docs improvement.

# 19.0.1

* Flutter 3.7.5, Dart 2.19.2, fast_immutable_collections: 9.0.0.

* BREAKING CHANGE: The `Action.wrapError(error, stackTrace)` method now also gets the stacktrace
  instead of just the error. If your code breaks, just add the extra parameter, like so:
  `Object wrapError(error) => ...` turns into `Object wrapError(error, _) => ...`

<br>

* BREAKING CHANGE: When a `Persistor` is provided to the Store, it now considers the
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

* BREAKING CHANGE: The factory declaration used to have two type parameters, but now it has three:
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

# 18.0.2

* Fixed small bug when persistor is paused before being used once.

# 18.0.0

* Version bump of dependencies.

# 17.0.1

* Fixed issue with the StoreConnector.shouldUpdateModel method when the widget updates.

# 17.0.0

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

# 16.1.0

* Added another cache function, for 2 states and 3 parameters: `cache2states_3params`.

# 16.0.0

* BREAKING CHANGE: Async `reduce()` methods (those that return Futures) are now called
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

* BREAKING CHANGE: When your reducer is async (i.e., returns `Future<AppState>`) you must make sure
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

# 15.0.0

* Flutter 3.0 support.

# 14.1.4

* `NavigateAction.popUntilRouteName()` can print the routes (for debugging).

# 14.1.2

* Better stacktrace for wrapped errors in actions.

# 14.1.1

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

* BREAKING CHANGE: This is a very minor change, unlikely to affect you. The signature for
  the `Action.wrapError` method has changed from `Object? wrapError(error)`
  to `Object? wrapError(Object error)`. If you get an error when you upgrade, you can fix it by
  changing the method that broke into `Object? wrapError(dynamic error)`.

* BREAKING CHANGE: Context is now nullable for these StoreConnector methods:
  ```
  void onInitialBuildCallback(BuildContext? context, Store<St> store, Model viewModel);
  void onDidChangeCallback(BuildContext? context, Store<St> store, Model viewModel);
  void onWillChangeCallback(BuildContext? context, Store<St> store, Model previousVm, Model newVm);
  ```   

# 13.3.1

* Version bump of dependencies.

# 13.2.2

* Version bump of dependencies.

# 13.2.1

* Fixed `MockStore.dispatchAsync()` and `MockStore.dispatchSync()` methods.
  Note: `dispatchAsync` was later renamed to `dispatchAndWait`.

# 13.2.0

* `delay` parameter for `WaitAction.add()` and `WaitAction.remove()` methods.

# 13.1.0

* Added missing `dispatchSync` and `dispatchAsync` to `StoreTester`.
  Note: `dispatchAsync` was later renamed to `dispatchAndWait`.

# 13.0.6

* Added missing `dispatchSync` to `VmFactory`.

# 13.0.5

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

# 13.0.4

* `dispatch` can be used to dispatch both sync and async actions. It returns a `FutureOr`. You can
  await the result or not, as desired.

* `dispatchAsync` can also be used to dispatch both sync and async actions. But it always returns a
  `Future` (not a `FutureOr`). Use this only when you explicitly need a `Future`, for example, when
  working with the `RefreshIndicator` widget. Note: `dispatchAsync` was later renamed
  to `dispatchAndWait`.

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
  For more information, see section **Testing the StoreConnector** in the README.md file.

* Fix: `UserExceptionDialog` now shows all `UserException`s. It was discarding some of them under
  some circumstances, in a regression created in version 4.0.4.

* In the `Store` constructor you can now set `maxErrorsQueued` to control the maximum number of
  errors the `UserExceptionDialog` error-queue can hold. Default is `10`.

* `ConsoleActionObserver` is now provided to print action details to the console.

* `WaitAction.toString()` now returns a better description.

# 12.0.4

* `NavigateAction.toString()` now returns a better description, like `Action NavigateAction.pop()`.

* Fixed `NavigateAction.popUntilRouteName` and `NavigateAction.pushNamedAndRemoveAll` to return the
  correct `.type`.

* Added section `Dependency Injection` in README.md.

# 12.0.3

* Improved error messages when the reducer returns an invalid type.

* New `StoreTester` methods: `waitUntilAll()` and `waitUntilAllGetLast()`.

* Passing an environment to the store, to help with dependency injection: `Store(environment: ...)`

# 12.0.0

* BREAKING CHANGE: Improved state typing for some `Store` parameters. You will now have to use
  `Persistor<AppState>` instead of `Persistor`, and `WrapError<AppState>` instead of `WrapError`
  etc.

* Global `Store(wrapReduce: ...)`. You may now globally wrap the reducer to allow for some pre or
  post-processing. Note: if the action also have a wrapReduce method, this global wrapper will be
  called AFTER (it will wrap the action's wrapper which wraps the action's reducer).

* Downgraded dev_dependencies `test: ^1.16.0`

# 11.0.1

* You can now provide callbacks `onOk` and `onCancel` to an `UserException`. This allows you to
  dispatch actions when the user dismisses the error dialog. When using the
  default `UserExceptionDialog`: (i) if only `onOk` is provided, it will be called when the dialog
  is dismissed, no matter how. (ii) If both `onOk` and `onCancel` are provided, then `onOk` will be
  called only when the OK button is pressed, while `onCancel` will be called when the dialog is
  dismissed by any other means.

# 11.0.0

* BREAKING CHANGE: The `dispatchFuture` function is not necessary anymore. Just rename it
  to `dispatch`, since now the `dispatch` function always returns a future, and you can await it or
  not, as desired.

* BREAKING CHANGE: `ReduxAction.hasFinished()` has been deprecated. It should be renamed
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

# 10.0.1

* BREAKING CHANGE: The new `UserExceptionDialog.useLocalContext` parameter now allows
  the `UserExceptionDialog` to be put in the `builder` parameter of the `MaterialApp` widget. Even
  if you use this dialog, it is unlikely this will be a breaking change for you. But if it is, and
  your error dialog now has problems, simply make `useLocalContext: true` to return to the old
  behavior.

* BREAKING CHANGE: `StoreConnector` parameters `onInitialBuild`, `onDidChange`
  and `onWillChange` now also get the context and the store. For example, where you previously
  had `onInitialBuild(vm) {...}` now you have `onInitialBuild(context, store, vm) {...}`.

# 9.0.9

* LocalPersist `saveJson()` and `loadJson()` methods.

# 9.0.8

* FIC and weak-map version bump.

# 9.0.7

* NNBD improvements.
* FIC version bump.

# 9.0.1

* Downgrade to file: ^6.0.0 to improve compatibility.

# 9.0.0

* Nullsafe.

# 8.0.0

* Uses nullsafe dependencies (it's not yet itself nullsafe).

* BREAKING CHANGE: Cache functions (for memoization) have been renamed and extended.

# 7.0.2

* LocalPersist: Better handling of mock file-systems.

# 7.0.1

* BREAKING CHANGE:

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

# 6.0.3

* StoreTester.dispatchState().

# 6.0.2

* VmFactory.getAndRemoveFirstError().

# 6.0.1

* `NavigateAction` now closely follows the `Navigator` api:  `push()`,
  `pop()`, `popAndPushNamed()`, `pushNamed()`, `pushReplacement()`, `pushAndRemoveUntil()`,
  `replace()`, `replaceRouteBelow()`, `pushReplacementNamed()`, `pushNamedAndRemoveUntil()`,
  `pushNamedAndRemoveAll()`, `popUntil()`, `removeRoute()`, `removeRouteBelow()`,
  `popUntilRouteName()` and `popUntilRoute()`.

# 1.0.0

* Initial commit: 2019/Aug05
