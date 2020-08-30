## [4.0.0-Dev] - 2020/08/23

* Deprecated: 

`StoreConnector`'s `model` parameter is now deprecated. It expects a `BaseModel`
object, which is also deprecated. AsyncRedux run the `BaseModel.fromStore()` 
method to obtain yet another object of type `BaseModel`, which is the view-model 
used by the connector.

While the `model` parameter is easy to use, it is also easy to use it wrong.

Instead, you should now use the `StoreConnector`'s `vm` parameter to pass an 
object of type `VmFactory`. AsyncRedux will run the `VmFactory.fromStore()` 
method to obtain an object of type `Vm`, which is now the view-model used by 
the connector. Note: `Vm` is immutable, and all its fields must be final.

AsyncRedux will inject the `state` and the `dispatch`/`dispatchFuture` methods
into `VmFactory`, so that you easily can create any fields and methods you
need to help you build the view-model.

This is a complete example:

```dart
class MyHomePageConnector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
	return StoreConnector<AppState, ViewModel>(
	  vm: Factory(this),
	  builder: (BuildContext context, ViewModel vm) => MyHomePage(
		counter: vm.counter,
		onIncrement: vm.onIncrement,
	  ));
  }}

class Factory extends VmFactory<AppState, MyHomePageConnector> {
  Factory(widget) : super(widget);
  @override
  ViewModel fromStore() => ViewModel(
      counter: state.counter,
      onIncrement: () => dispatch(IncrementAndGetDescriptionAction()),
      );
}

class ViewModel extends Vm {  
  final int counter;
  final String description;
  ViewModel({
       @required this.counter,
       @required this.onIncrement,
  }) : super(equals: [counter]);
}
```

Please note, `StoreConnector`'s `converter` parameter still works and will NOT be deprecated.

* View-model equality:

Just as before, if you provide the `Vm.equals` field in the constructor, it will
automatically create equals/hashcode for you, so that the connector can know
when the view-model changed, and rebuild. However, you can now provide your
own comparison method, if you want. To that end, your state classes must 
implement the `VmEquals` interface. As a default, objects of type `VmEquals`
are compared by identity, while all other object types are, as usual, compared 
by equality. You may then override the `VmEquals.vmEquals()` method to provide 
your custom comparisons.                  

* Breaking Change:

The abstract `ReduxAction.reduce()` method signature has a return type of `FutureOr<AppState>`,
but your concrete reducers must return one or the other: `AppState` or `Future<AppState>`.
  
That's necessary because AsyncRedux knows if a reducer is sync or async not by checking the returned type,
but by checking your `reducer()` method signature. 
If it is `FutureOr<AppState>`, AsyncRedux can't know if it's sync or async, 
and will throw a StoreException:

```
Reducer should return `St` or `Future<St>`. Do not return `FutureOr<St>`.
```
 
* Breaking Change:
 
While the `reduce()` method of a *sync* reducer continues to run synchronously with the dispatch, 
the `reduce()` method of an *async* reducer will now not be called immediately, 
but will be scheduled in a later task.

Previously to version 4.0.0 the async reducer would have at least started synchronously with the dispatch
(and would run synchronously until the first `await`).

Previously, you would also have to make sure to never return a completed future
for an async reducer, but this is no longer necessary in version 4.0.0.     


## [3.0.5] - 2020/08/18

* Action.after() will now throw the error asynchronously (instead of swallowing it).


## [3.0.4] - 2020/08/13

* Fix: withoutHardCause was removing the code field.


## [3.0.3] - 2020/08/11

* cache3.
* LocalPersist is exported separately.


## [3.0.0] - 2020/07/27

* Works for Web.


## [2.13.1] - 2020/07/17

* WrapError may now convert to any error type.
* UserException hardCause() and withoutHardCause() methods.


## [2.13.0] - 2020/07/16

* typedef Reducer.
* ReduxAction.wrapReduce().


## [2.12.3] - 2020/07/08

* Docs improvement.


## [2.12.2] - 2020/06/30

* Global WrapError now gets error, stackTrace, and action (none of them optional).
* MockStore (still experimental, in `mock_store.dart`), lets you mock or disable actions/reducers during tests. 
  (See section `Mocking actions and reducers` in README.md).
* ReduxAction.status and ReduxAction.hasFinished. (Search for "Action status" in README.md).
* ReduxAction.reduceWithState deprecated (will be removed).


## [2.11.1] - 2020/06/12

* Added cache/reselector functions with 1 or 2 states and zero parameters: `cache1` and `cache2`.
* Breaking change: Other cache/reselector functions are now named `cache1_1`, `cache1_2`, `cache2_1`, and `cache2_2`.
* Breaking change: Dispatch/DispatchFuture with `notify: false` will change the state but not rebuild widgets. 


## [2.10.0] - 2020/06/01

* BaseModel now doesn't give direct access to the store, and doesn't read the 
  state from the store anymore. The state is now copied and kept constant in 
  the view-model, as it should.  


## [2.9.0] - 2020/05/25

* Stacktrace in WrapError.
* EventMultiple (Event.map).


## [2.8.11] - 2020/05/19

* <a href="https://pub.dev/packages/async_redux#reselectors">Reselectors</a>.


## [2.8.7] - 2020/05/15

* Store.stateTimestamp now records the timestamp when the current state in the store was created.


## [2.8.6] - 2020/05/13

* Fixed corner case for StoreTester.waitAll.


## [2.8.5] - 2020/05/12

* Small fixes: better generics; Better waitCondition stream close.


## [2.8.4] - 2020/05/08

* Fix LocalPersist imports.
* Fix abortDispatch not getting the state.


## [2.8.1] - 2020/05/01

* A filesystem may be injected into LocalPersist (usually to be used with MemoryFileSystem).
* Fix: LocalPersist.subDirs.


## [2.8.0] - 2020/04/30

* Store.waitCondition() returns a future which will complete when the state meets a given condition.
   
* Breaking change: StoreTester.waitCondition() now accepts a parameter called testImmediately.
When testImmediately is true (now the default), it will test the condition immediately when 
the method is called. If the condition is true, the method will return immediately,
without waiting for any actions to be dispatched. 
When testImmediately is false (the old behavior), it will only test the condition once an 
action is dispatched.


## [2.7.3] - 2020/04/30

* Fix: When dbName is a String, LocalPersist doesn't break it in the dot anymore.
* LocalPersist subDirs.


## [2.7.2] - 2020/04/24

* WaitAction now has dynamic generic type in TestInfo.type (compatible with the StoreTester).


## [2.7.1] - 2020/04/15

* WaitAction is now compatible with BuiltValue and Freezed packages.


## [2.7.0] - 2020/04/14

* WaitAction (Search for "Progress indicators" in README.md).
* Example: main_wait_action_simple.dart
* Example: main_wait_action_advanced_1.dart
* Example: main_wait_action_advanced_2.dart


## [2.6.0] - 2020/04/01

* The default timeout for the StoreTester wait functions can now be globally changed.
* The default debug information printed to the console can now be changed or turned off globally.


## [2.5.8] - 2020/03/17

* NavigateAction.push(Route).


## [2.5.7] - 2020/03/09

* Action.abortDispatch.


## [2.5.6] - 2020/03/05

* Fixed orElse in TestInfo operator [].


## [2.5.5] - 2020/02/18

* StoreTester.lastInfo (Search for "lastInfo" in README.md).
* PersistorPrinterDecorator: saveInitialState linked to the correct method.
* Fix failing tests by ensuring initialization.


## [2.5.4] - 2020/02/18

* Docs improvement.


## [2.5.3] - 2020/01/29

* Removes the generic type from PersistAction in tests.


## [2.5.2] - 2020/01/28

* Errors queue is cloned in TestInfo.


## [2.5.1] - 2020/01/26

* NavigateAction.pushNamedAndRemoveUntil.


## [2.5.0] - 2020/01/20

* Breaking change: The StoreConnector's shouldUpdateModel parameter now functions properly. 
If you are using this, make sure you return true to apply changes (the default when the parameter is not defined), 
and false to ignore model changes.


## [2.4.4] - 2019/01/13

* StoreTester dispatchFuture.


## [2.4.3] - 2019/01/11

* Small UserExceptionDialog web fix.


## [2.4.2] - 2019/12/18

* TestInfo.type now returns generic NavigateAction and UserExceptionAction, to play well with the StoreTester.


## [2.4.1] - 2019/12/10

* Breaking change: Global WrapError, if defined, now receives all errors, including UserExceptions.


## [2.3.3] - 2019/12/07

* iOS specific dialog for UserExceptions.


## [2.3.2] - 2019/11/28

* Docs improvement.


## [2.3.0] - 2019/11/19

* Global ignore in the StoreTester constructor.
* Better treatment of wrap-errors that throw.
* Breaking change: LocalPersist (instead of Saver/Loader).


## [2.2.0] - 2019/11/15

* Breaking change: PersistObserver became Persistor (and other renames).
* PersistorPrinterDecorator. PersistorDummy.


## [2.1.9] - 2019/11/12

* Saver/Loader.


## [2.1.4] - 2019/11/10

* PersistObserver.


## [2.1.3] - 2019/10/30

* Removed deprecated ignoreChange. Use shouldUpdateModel instead.
 
 
## [2.1.0] - 2019/10/27

* Better translations support for UserException. 
* Global WrapError in the store. 


## [2.0.6] - 2019/10/07

* Added sync_async_test.dart
* Doc warning about async reducer returning completed future (missing await). 


## [2.0.5] - 2019/10/05

* Better typing of StoreProvider.dispatch and StoreProvider.dispatchFuture.


## [2.0.4] - 2019/10/01

* StoreTester.waitUntilError and waitUntilErrorGetLast.


## [2.0.3] - 2019/09/21

* NavigateAction tests.
* Navigation arguments.


## [2.0.2] - 2019/09/21

* UserExceptionAction.


## [2.0.1] - 2019/09/19

* Fix: UserException.dialogContent accepts String as cause.


## [2.0.0] - 2019/09/17

* Breaking change: ErrorObserver API.
* StoreTester parameter: shouldThrowUserExceptions (see <a href="https://github.com/marcglasberg/async_redux/issues/20">issue</a>).


## [1.4.3] - 2019/09/15

* Alternative: Use AsyncRedux with Provider (package provider_for_redux).


## [1.4.1] - 2019/09/06

* Flutter Awesome badge, and Pub badge.


## [1.4.0] - 2019/09/02

* Fix: dispatchFuture getter in ReduxAction.


## [1.3.9] - 2019/08/31

* NavigateAction.navigatorKey getter.


## [1.3.8] - 2019/08/30

* Alternatives to the Connector (StoreProvider static methods).
* Waiting until an Action is finished (dispatchFuture).


## [1.3.7] - 2019/08/28

* ModelObserver and DefaultModelObserver.


## [1.3.5] - 2019/08/27

* README improvement.


## [1.3.3] - 2019/08/26

* StoreConnector's converter and model parameters.


## [1.2.3] - 2019/08/23

* StoreTester timeout message.


## [1.2.0] - 2019/08/22

* Doc improvement. StoreTester improvements.


## [1.1.3] - 2019/08/21

* StoreTester: waitCondition and waitConditionGetLast.


## [1.1.2] - 2019/08/13

* README improvement.


## [1.1.1] - 2019/08/10

* Ignore actions in the StoreTester.


## [1.1.0] - 2019/08/07

* Correct stacktrace for unwrapped action errors.


## [1.0.9] - 2019/08/07

* Error message improvement.


## [1.0.4] - 2019/08/05

* Store tester.


## [1.0.0] - 2019/08/05

* Initial commit.
