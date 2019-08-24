# async_redux

**AsyncRedux** is a special version of Redux which:

1. Is easy to learn
2. Is easy to use
3. Is easy to test
4. Has no boilerplate

The below documentation is very detailed. 
For an overview, go to the <a href="https://medium.com/@marcglasberg/https-medium-com-marcglasberg-async-redux-33ac5e27d5f6?sk=87aefd759273920d444185aa9d447ba0">Medium story</a>.

# Table of Contents

   * [What is Redux?](#what-is-redux)
   * [Why use this Redux version over others?](#why-use-this-redux-version-over-others)
   * [Store and State](#store-and-state)
   * [Actions](#actions)
      * [Sync Reducer](#sync-reducer)
      * [Async Reducer](#async-reducer)
      * [Changing state is optional](#changing-state-is-optional)
      * [Before and After the Reducer](#before-and-after-the-reducer)
   * [Connector](#connector)
   * [Processing errors thrown by Actions](#processing-errors-thrown-by-actions)
      * [Giving better error messages](#giving-better-error-messages)
      * [User exceptions](#user-exceptions)
   * [Testing](#testing)
      * [Test files](#test-files)
   * [Route Navigation](#route-navigation)
   * [Events](#events)
      * [Can I put mutable events into the store state?](#can-i-put-mutable-events-into-the-store-state)
      * [When should I use events?](#when-should-i-use-events)
      * [Advanced event features](#advanced-event-features)
   * [State Declaration](#state-declaration)
      * [Selectors](#selectors)
   * [Action Subclassing](#action-subclassing)
      * [Abstract Before and After](#abstract-before-and-after)
   * [IDE Navigation](#ide-navigation)
   * [Logging and Persistence](#logging-and-persistence)
   * [How to interact with the database](#how-to-interact-with-the-database)
   * [How to deal with Streams](#how-to-deal-with-streams)
      * [So, how do you use streams?](#so-how-do-you-use-streams)
      * [And where the stream subscriptions themselves are stored?](#and-where-the-stream-subscriptions-themselves-are-stored)
      * [How do streams pass their information to the store and ultimately to the widgets?](#how-do-streams-pass-their-information-to-the-store-and-ultimately-to-the-widgets)
      * [To sum up:](#to-sum-up)
   * [Recommended Directory Structure](#recommended-directory-structure)

## What is Redux?

A single **store** holds all the **state**, which is immutable.
When you need to modify some state you **dispatch** an **action**. 
Then a **reducer** creates a new copy of the state, with the desired changes. 
Your widgets are **connected** to the store (through **store-connectors** and **view-models**), 
so they know that the state changed, and rebuild as needed.

## Why use this Redux version over others?

Plain vanilla Redux is too low-level, which makes it very flexible 
but results in a lot of boilerplate, and a steep learning curve.

Combining reducers is a manual task, and you have to list them one by one. 
If you forget to list some reducer, you will not know it until your tests point out 
that some state is not changing as you expected.    

Reducers can't be async, so you need to create middleware, which is also difficult to setup and use. 
You have to list them one by one, 
and if you forget one of them you will also not know it until your tests point it out.
The `redux_thunk` package can help with that, but adds some more complexity.

It's difficult to know which actions fire which reducers, and hard to navigate the code in the IDE. 
In IntelliJ you may press CTRL+B to navigate between a method use and its declaration. 
However, this is of no use if actions and reducers are independent classes. 
You have to search for action "usages", which is not so convenient since it also list dispatches. 


It's also difficult to list all actions and reducers, and you may end up implementing some reducer just to 
realize it already exists with another name.

Testing reducers is simple, since they are pure functions, but integration tests are difficult. 
In the real world you need to test complex middleware that fires other middleware and many reducers, 
with intermediate state changes that you want to test for. 
Especially if you are doing BDD or Acceptance Tests you may need to wait for some middleware to finish, 
and then dispatch some other actions, and test for intermediate states.

Another problem is that vanilla Redux assumes it holds all of the application state, 
and this is not practical in a real Flutter app. 
If you add a simple `TextField` with a `TextEditingController`, or a `ListView` with a `ScrollController`, 
then you have state outside of the Redux store. 
Suppose your middleware is downloading some information, 
and it wishes to scroll a `ListView` as soon as the info arrives. 
This would be simple if the list scroll position is saved in the Redux store. 
However, this state must be in the `ScrollController`, not the store.       
 
**AsyncRedux solves all of these problems and more:**
 
* It's much easier to learn and use than regular Redux.
* It comes with its own testing tools that make even complex tests easy to setup and run.
* You can navigate between action dispatches and their corresponding reducers with a single IDE command or click.
* You can also use your IDE to list all actions/reducers. 
* You don't need to add or list reducers and middleware anywhere.
* In fact, reducers can be async, so you don't need middleware.
* There is no need for generated code (as some Redux versions do).
* It has the concept of "events", to deal with Flutter state controllers.
* It helps you show errors thrown by reducers to the user.
* It's easy to add both logging and store persistence.

## Store and State

Declare your store and state, like this:

    var state = AppState.initialState();
    
    var store = Store<AppState>(
      initialState: state,      
    );

## Actions

If you want to change the store state you must "dispatch" some action. 
In AsyncRedux all actions extend `ReduxAction`.

The reducer of an action is simply a method of the action itself, called `reduce()`. 
All actions must override this method.

The reducer has direct access to:
 - The store state (which is a getter of the `Action` class).
 - The action state itself (the class fields, passed to the action when it was instantiated and dispatched).
 - The `dispatch` method, so that other actions may be dispatched from the reducer. 
 
### Sync Reducer

If you want to do some synchronous work, simply declare the reducer to return `AppState`, 
then change the state and return it. 

For example, let's start with a simple action to increment a counter by some value:

    class IncrementAction extends ReduxAction<AppState> {
      
      final int amount;
    
      IncrementAction({this.amount}) : assert(amount != null);
    
      @override
      AppState reduce() {
        return state.copy(counter: state.counter + amount));
      }
    }

This action is dispatched like this:

    store.dispatch(IncrementAction(amount: 3));
    
Note the reducer above has direct access to both the counter state (`state.counter`) 
and to the action state (the field `amount`).

We will show you later how to easily test sync reducers, using the **StoreTester**.

Try running the: <a href="https://github.com/marcglasberg/async_redux/blob/master/example/main.dart">Increment Example</a>.

### Async Reducer
 
If you want to do some asynchronous work, simply declare the reducer to return `Future<AppState>` 
then change the state and return it. There is no need of any "middleware", like for other Redux versions.

Note: In IntelliJ, to convert the reducer from sync to async, press `Alt+ENTER` and select `Convert to async function body`. 

As an example, suppose you want to increment a counter by a value you get from the database. 
The database access is async, so you must use an async reducer:

    class QueryAndIncrementAction extends ReduxAction<AppState> {                    
    
      @override
      Future<AppState> reduce() async {
        int value = await getAmount();
        return state.copy(counter: state.counter + value));
      }
    }

This action is dispatched like this:

    store.dispatch(QueryAndIncrementAction());
    
We will show you later how to easily test async reducers, using the **StoreTester**.    

Try running the: <a href="https://github.com/marcglasberg/async_redux/blob/master/example/main_increment_async.dart">Increment Async Example</a>.

### Changing state is optional

For both sync and async reducers, returning a new state is optional. 
If you don't plan on changing the state, simply return `null`. This is the same as returning the state unchanged.

Why is this useful?  Because some actions may simply start other async processes, or dispatch other actions.
  
For example, suppose you want to have two separate actions, one for querying some value from the database, 
and another action to change the state:

    class QueryAction extends ReduxAction<AppState> {                    
    
      @override
      Future<AppState> reduce() async {
        int value = await getAmount();
        dispatch(IncrementAction(amount: value));
        return null;
      }
    }

    class IncrementAction extends ReduxAction<AppState> {
      
      final int amount;
    
      IncrementAction({this.amount}) : assert(amount != null);
    
      @override
      AppState reduce() {
        return state.copy(counter: state.counter + amount));
      }
    }

Note the `reduce()` methods have direct access to `state` and `dispatch`. 
There is no need to write `store.state` and `store.dispatch` (although you can, if you want). 

### Before and After the Reducer 

Sometimes, while an async reducer is running, you want to prevent the user from touching the screen.
Also, sometimes you want to check preconditions like the presence of an internet connection,
and don't run the reducer if those preconditions are not met.

To help you with these use cases, you may override methods `ReduxAction.before()` 
and `ReduxAction.after()`, which run respectively before and after the reducer. 

The `before()` method runs before the reducer. 
If you want it to run synchronously, it should return `void`:

    void before() { ... }
    
To run it asynchronously, return `Future<void>`:

    Future<void> before() async { ... }

If it throws an error, then `reduce()` will NOT run. 
This means you can use it to check any preconditions
and throw an error if you want to prevent the reducer from running. For example:

    Future<void> before() async => await checkInternetConnection();

This method is also capable of dispatching actions, so it can be used to turn on a modal barrier:    
      
    void before() => dispatch(WaitAction(true));
    
Note: If this method runs asynchronously, then `reduce()` will also be async,
since it must wait for this one to finish.

The `after()` method runs after `reduce()`, even if an error was thrown by `before()` or `reduce()` 
(akin to a "finally" block). If the `after()` method itself throws an error, 
then this error will be "swallowed" and ignored. Avoid `after()` methods which can throw errors.

This method can also dispatch actions, so it can be used to turn off some modal barrier
when the reducer ends, even if there was some error in the process:

    void after() => dispatch(WaitAction(false));

Complete example:

    // This action increments a counter by 1, and then gets some description text.
    class IncrementAndGetDescriptionAction extends ReduxAction<AppState> {
      
      @override
      Future<AppState> reduce() async {      
        dispatch(IncrementAction());
        String description = await read("http://numbersapi.com/${state.counter}");    
        return state.copy(description: description);
      }    
      
      void before() => dispatch(WaitAction(true));    
      
      void after() => dispatch(WaitAction(false));
    }

Try running the: <a href="https://github.com/marcglasberg/async_redux/blob/master/example/main_before_and_after.dart">Before and After Example</a>.

## Connector

As usual, in Redux you generally have two widgets, one called the "dumb-widget", which knows nothing
about Redux and the store, and another one to "wire" the store with that dumb-widget.
Vanilla Redux calls these wiring widgets "containers", but we consider this bad since Flutter's most common widget is already called a `Container`.
So we call them "connectors", and they do their magic by using a `StoreConnector` 
and a `ViewModel`. 

For example:

    class MyHomePageConnector extends StatelessWidget {          
      @override
      Widget build(BuildContext context) {
        return StoreConnector<AppState, ViewModel>(
          model: ViewModel(),
          builder: (BuildContext context, ViewModel vm) => MyHomePage(
            counter: vm.counter,
            description: vm.description,
            onIncrement: vm.onIncrement,
          ));
      }
    }
    
    // Helper class to the connector widget. Holds the part of the State the widget needs,
    // and may perform conversions to the type of data the widget can conveniently work with.
    class ViewModel extends BaseModel<AppState> {
      ViewModel();
    
      int counter;
      String description;
      VoidCallback onIncrement;
    
      ViewModel.build({
        @required this.counter,
        @required this.description,
        @required this.onIncrement,
      }) : super(equals: [counter, description]);
    
      @override
      ViewModel fromStore() => ViewModel.build(
            counter: state.counter,
            description: state.description,
            onIncrement: () => dispatch(IncrementAndGetDescriptionAction()),
          );
    }

The `StoreConnector` has a `distinct` parameter. 
As a performance optimization, `distinct:true` allows the widget to be rebuilt only when the 
ViewModel changes. If this is not done, then the widget will be rebuilt every time any state 
in the store is changed.

This `distinct` parameter is `true` by default, but this can be changed when creating the store,
by passing it `defaultDistinct:false`.  

If `distinct` is `true`, you must implement equals and hashcode for the `ViewModel`,
otherwise there is no way to know if the ViewModel changed.

This can be done in three ways:

* By typing `ALT`+`INSERT` in IntelliJ IDEA and choosing `==() and hashcode`.
You can't forget to update this whenever new parameters are added to the model.

* You can use the <a href="https://pub.dev/packages/built_value">built_value</a> package 
to ensure they are kept correct, without you having to update them manually.

* Just add all the fields you want to the `equals` parameter to the `ViewModel`'s `build` constructor.
This will allow the ViewModel to automatically create its own equals and hashcode implicitly. 
For example:

      ViewModel.build({
          @required this.field1,
          @required this.field2,          
      }) : super(equals: [field1, field2]);
    
## Processing errors thrown by Actions

AsyncRedux has special provisions for dealing with errors, including observing errors, showing errors to users, 
and wrapping errors into more meaningful descriptions.
 
Let's see an example. 
Suppose a logout action that checks if there is an internet connection, and then deletes the database and
sets the store to its initial state:

    class LogoutAction extends ReduxAction<AppState> {      
      @override
      Future<AppState> reduce() async {      
        await checkInternetConnection();    
        await deleteDatabase();               
        dispatch(NavigateToLoginScreenAction();
        return AppState.initialState();
      }
    }

In the above code, the `checkInternetConnection()` function checks if there is an 
<a href="https://pub.dev/packages/connectivity">internet connection</a>,
and if there isn't it throws an error:

    Future<void> checkInternetConnection() async {
        if (await Connectivity().checkConnectivity() == ConnectivityResult.none)                  
            throw NoInternetConnectionException();
    }

All errors thrown by action reducers are sent to the **ErrorObserver**, which you may define during store creation.
For example:    
    
    var store = Store<AppState>(
      initialState: AppState.initialState(),   
      errorObserver: errorObserver,   
    );
    
    bool errorObserver(Object error, ReduxAction action, Store store, Object state, int dispatchCount) {
      print("Error thrown during $action: $error);      
      return true;
    }

If your error observer returns `true`, the error will be rethrown after the `errorObserver` finishes. 
If it returns `false`, the error is considered dealt with, and will be "swallowed" (not rethrown).
 
### Giving better error messages 

If your reducer throws some error you probably want to collect as much information as possible. 
In the above code, if `checkInternetConnection()` throws an error, you want to know that you have a connection
problem, but you also want to know this happened during the logout action. 
In fact, you want all errors thrown by this action to reflect that. 

The solution is implementing the optional `wrapError(error)` method:    

    class LogoutAction extends ReduxAction<AppState> {
      
      @override
      Future<AppState> reduce() async { ... }
    
      @override
      Object wrapError(error) 
          => LogoutError("Logout failed.", cause: error);
    }
    
Note the `LogoutError` above gets the original error as cause, so no information is lost.
In other words, the `wrapError(error)` method acts as the "catch" statement of the action.     
 
### User exceptions

To show error messages to the user, make your actions throw an `UserException`, 
and then wrap your home-page with `UserExceptionDialog`, below `StoreProvider` and `MaterialApp`:

    class MyApp extends StatelessWidget {
      @override
      Widget build(BuildContext context) 
          => StoreProvider<AppState>(
              store: store,
              child: MaterialApp(
                home: UserExceptionDialog<AppState>(
                  child: MyHomePage(),
                )));
    }
 
Try running the: <a href="https://github.com/marcglasberg/async_redux/blob/master/example/main_show_error_dialog.dart">Show Error Dialog Example</a>. 
 
**In more detail:**
 
Sometimes, actions fail because the user provided invalid information. 
These failings don't represent errors in the code, so you usually don't want to log them as errors.
What you want, instead, is just warn the user by opening a dialog with some corrective information.
For example, suppose you want to save the user's name, and you only accept names with at least 4 characters:
 
    class SaveUserAction extends ReduxAction<AppState> {
       final String name;       
       SaveUserAction(this.name);
             
       @override
       Future<AppState> reduce() async {      
         if (name.length < 4) dispatch(ShowDialogAction("Name must have at least 4 letters."));    
         else await saveUser(name);         
         return null;   
       }
     }

Clearly, there is no need to log as an error the user's attempt to save a 3-char name.
The above code dispatches a `ShowDialogAction`, which you would have to wire into a Flutter error dialog somehow. 

However, there's an easier approach. Just throw AsyncRedux's built-in `UserException`: 

    class SaveUserAction extends ReduxAction<AppState> {
       final String name;
       SaveUserAction(this.name);
             
       @override
       Future<AppState> reduce() async {      
         if (name.length < 4) throw UserException("Name must have at least 4 letters.");    
         await saveName(name);
         return null;            
       }
     }

The special `UserException` error class represents "user errors" which are meant as warnings to the user, 
and not as code errors to be logged. 
By default (if you don't define your own `errorObserver`) only errors which are not `UserException` are thrown. 
And if you do define an `errorObserver`, you'd probably want to replicate this behavior.  

In any case, `UserException`s are put into a special error queue, 
from where they may be shown to the user, one by one.
You may use `UserException` as is, or subclass it, returning title and message for the alert dialog shown to the user.

As explained in the beginning of this section, 
if you use the build-in error handling you must wrap your home-page with `UserExceptionDialog`.
There, you may pass the `onShowUserExceptionDialog` parameter to change the default dialog, show a toast, or some other suitable widget:                   

      UserExceptionDialog<AppState>(
          child: MyHomePage(),
          onShowUserExceptionDialog: 
              (BuildContext context, UserException userException) => showDialog(...),
          );
 
## Testing
 
It's often said that vanilla Redux **reducers** are easy to test because they're pure functions.
While this is true, real-world applications are composed not only of sync reducers, 
but also of middleware async code, which is not easy to test at all.  
 
AsyncRedux provides the `StoreTester` class that makes it easy to test both sync and async reducers.

Start by creating the store-tester from a store:    
    
    var store = Store<AppState>(initialState: AppState.initialState());
    var storeTester = StoreTester.from(store);

Or else, creating it directly from `AppState`:       
    
    var storeTester = StoreTester<AppState>(initialState: AppState.initialState());
    
Then, dispatch some action, wait for it to finish, and check the resulting state:    

    storeTester.dispatch(SaveNameAction("Mark"));
    TestInfo<AppState> info = await storeTester.wait(SaveNameAction);
    expect(info.state.name, "Mark");
                
The variable `info` above will contain information about after the action reducer finishes executing,
**no matter if the reducer is sync or async**. 

The `TestInfo` instance contains the following:

* `state`: The store state.   
* `action`: The dispatched Action that resulted in that state.
* `ini`: A boolean which indicates true if this info represents the "initial" state right before the action is 
         dispatched, or false it represents the "end" state right after the action finishes executing.
* `dispatchCount`: The number of dispatched actions so far.             
* `reduceCount`: The number of reduced states so far.
* `errors`: The `UserException`s the store was holding when the information was gathered.
 
While the above example demonstrates the testing of a simple action, 
real-world apps have actions that dispatch other actions. 
You may use different `StoreTester` methods to check if the expected actions are dispatched, 
and test their intermediary states.  
 
Let's see all the available methods of the `StoreTester`:

1. `Future<TestInfo> wait(Type actionType)` 

    Expects **one action** of the given type to be dispatched, and waits until it finishes. 
    Returns the info after the action finishes.
    Will fail with an exception if an unexpected action is seen.                   

2. `Future<TestInfo> waitUntil(Type actionType)`

    Runs until an action of the given type is dispatched, and then waits until it finishes.
    Returns the info after the action finishes.
    **Ignores other** actions types.               

3. `Future<TestInfo> waitUntilAction(ReduxAction action)`

    Runs until the exact given action is dispatched, and then waits until it finishes.
    Returns the info after the action finishes. **Ignores other** actions.
  
4. `Future<TestInfo> waitAllGetLast(List<Type> actionTypes, {List<Type> ignore})`

    Runs until **all** given actions types are dispatched, **in order**.
    Waits until all of them are finished.
    Returns the info after all actions finish.
    Will fail with an exception if an unexpected action is seen, 
    or if any of the expected actions are dispatched in the wrong order.
    To ignore some actions, pass them to the `ignore` list.

5. `Future<TestInfo> waitAllUnorderedGetLast(List<Type> actionTypes, {List<Type> ignore})`

    Runs until **all** given actions types are dispatched, in **any order**.
    Waits until all of them are finished.
    Returns the info after all actions finish.
    Will fail with an exception if an unexpected action is seen.
    To ignore some actions, pass them to the `ignore` list.
    
6. `Future<TestInfoList> waitAll(List<Type> actionTypes, {List<Type> ignore})`        

    The same as `waitAllGetLast`, but instead of returning just the last info, 
    it returns a list with the end info for each action.    
    To ignore some actions, pass them to the `ignore` list.

7. `Future<TestInfoList> waitAllUnordered(List<Type> actionTypes, {List<Type> ignore})`

    The same as `waitAllUnorderedGetLast`, but instead of returning just the last info, 
    it returns a list with the end info for each action.
    To ignore some actions, pass them to the `ignore` list.        
  
8. `Future<TestInfoList<St>> waitCondition(StateCondition<St> condition, {bool ignoreIni = true})`

    Runs until the predicate function `condition` returns true.
    This function will receive each testInfo, from where it can access the state, action, errors etc.
    Only END states will be received, unless you pass `ignoreIni` as false.
    Returns a list with all info until the condition is met.
    
9. `Future<TestInfo<St>> waitConditionGetLast(StateCondition<St> condition, {bool ignoreIni = true})`

    Runs until the predicate function `condition` returns true.
    This function will receive each testInfo, from where it can access the state, action, errors etc.
    Only END states will be received, unless you pass `ignoreIni` as false.
    Returns the info after the condition is met.
    
Some of the methods above return a list of type `TestInfoList`, which contains the step 
by step information of all the actions. You can then query for the actions you want to inspect.
For example, suppose an action named `IncrementAndGetDescriptionAction` calls another 3 actions. 
You can assert that all actions are called in order, 
and then get the state after each one of them have finished, all at once:  

    var storeTester = StoreTester<AppState>(initialState: AppState.initialState());
    expect(storeTester.state.counter, 0);
    expect(storeTester.state.description, isEmpty);

    storeTester.dispatch(IncrementAndGetDescriptionAction());

    TestInfoList<AppState> infos = await storeTester.waitAll([
      IncrementAndGetDescriptionAction,
      WaitAction,
      IncrementAction,
      WaitAction,
    ]);

    // Modal barrier is turned on (first time WaitAction is dispatched).
    expect(infos.get(WaitAction, 1).state.waiting, true);

    // While the counter was incremented the barrier was on.        
    expect(infos[IncrementAction].waiting, true);

    // Then the modal barrier is dismissed (second time WaitAction is dispatched).
    expect(infos.get(WaitAction, 2).state.waiting, false);

    // In the end, counter is incremented, description is created, and barrier is dismissed.
    var info = infos[IncrementAndGetDescriptionAction];
    expect(info.state.waiting, false);
    expect(info.state.description, isNotEmpty);
    expect(info.state.counter, 1);
          
Try running the: <a href="https://github.com/marcglasberg/async_redux/blob/master/example/main_before_and_after_STATE_test.dart">Testing with the Store Listener</a>.      

### Test files

If you want your tests to be comprehensive 
you should probably have 3 different types of test for each widget:

1. **State Tests** — Test the state of the app, including actions/reducers. 
This type of tests make use of the `StoreTester` described above. 

2. **Connector Tests** — Test the connection between the store and the "dumb-widget". 
In other words it tests the "connector-widget" and the "view-model".

3. **Presentation Tests** — Test the UI. In other words it tests the "dumb-widget",
making sure that the widget displays correctly depending on the parameters you use in its constructor.
You pass in the data the widget requires in each test for rendering, 
and then writes assertions against the rendered output. 
Think of these tests as "pure function tests" of our UI.
It also tests that the callbacks are called when necessary.

For example, suppose you have the counter app shown <a href="https://github.com/marcglasberg/async_redux/blob/master/example/main_increment_async.dart">here</a>.
Then:

* The **state test** could create a store with count `0` and description empty, 
and then dispatch `IncrementAction` and expect the count to become `1`.
Then it could test dispatching `IncrementAndGetDescriptionAction` alters the count to `2`
and the description to some non-empty string. 

* The **connector test** would create a store and a page with the `MyHomePageConnector` widget.
It would then access the `MyHomePage` and make sure it gets the expected info from the store, 
and also that the expected `IncrementAndGetDescriptionAction` is dispatched when the "+" button is tapped. 

* The **presentation test** would create the `MyHomePage` widget, 
pass `counter:0` and `description:"abc"` parameters in its constructor, 
and make sure they appear in the screen as expected. 
It would also test that the callback is called when the "+" button is tapped.

Since each widget will have a bunch of related files, you should have some consistent naming convention.
For example, if some dumb-widget is called `MyWidget`, its file could be `my_widget.dart`. 
Then the corresponding connector-widget could be `MyWidgetConnector` in `my_widget_CONNECTOR.dart`.
The three corresponding test files could be named `my_widget_STATE_test.dart`,
`my_widget_CONNECTOR_test.dart` and `my_widget_PRESENTATION_test.dart`.
If you don't like this convention use your own, but just choose one early and stick to it.   

## Route Navigation

AsyncRedux comes with a `NavigateAction` which you can dispatch to navigate your Flutter app.
For this to work, during app initialization you must create a navigator key and then inject it into the action:

    final navigatorKey = GlobalKey<NavigatorState>();
        
    void main() async {            
      NavigateAction.setNavigatorKey(navigatorKey);
      ...
    } 
    
You must also use this same navigator key in your `MaterialApp`: 

    return StoreProvider<AppState>(
      store: store,
      child: MaterialApp(
          ...
          navigatorKey: navigatorKey,          
          initialRoute: '/',          
          onGenerateRoute: ...
          ),
    );
    
Then, use the action as needed:

    dispatch(NavigateAction.pop());     
    dispatch(NavigateAction.pushNamed("myRoute"));     
    dispatch(NavigateAction.pushReplacementNamed("myRoute"));     
    dispatch(NavigateAction.pushNamedAndRemoveAll("myRoute"));     
    dispatch(NavigateAction.popUntil("myRoute"));     

Note: Don't ever save the current route in the store. This will create all sorts of problems. 
If you need to know the route you're in, or even the complete route stack,
you may use these static methods provided by `NavigateAction`:    

    String routeName = NavigateAction.getCurrentNavigatorRouteName(context);
    List<Route> routeStack = NavigateAction.getCurrentNavigatorRouteStack(context);
    
Try running the: <a href="https://github.com/marcglasberg/async_redux/blob/master/example/main_navigate.dart">Navigate Example</a>.        

## Events

In a real Flutter app it's not practical to assume that a Redux store can hold all of the application state.
Widgets like `TextField` and `ListView` make use of controllers, which hold state, 
and the store must be able to work alongside these. For example, in response to the dispatching of some action 
you may want to clear the text-field, or you may want to scroll the list-view to the top. 
Even when no controllers are involved, you may want to execute some one-off processes,
like opening a dialog or closing the keyboard, and it's not obvious how to do that in vanilla Redux. 

AsyncRedux solves these problems by introducing the concept of "events".
The naming convention is that Events are named with the `Evt` suffix.

Boolean events can be created like this:

    var clearTextEvt = Event();
    
But you can have events with payloads of any other data type. For example:

    var changeTextEvt = Event<String>("Hello");   
    var myEvt = Event<int>(42);
 
Events may be put into the store state in their "spent" state, by calling its `spent()` constructor.
For example, while creating the store initial-state:

    static AppState initialState() {    
      return AppState(        
        clearTextEvt: Event.spent(),
        changeTextEvt: Event<String>.spent(),
    }

And then events may be passed down by the `StoreConnector` to some `StatefulWidget`, 
just like any other state: 

    class MyConnector extends StatelessWidget {          
      @override
      Widget build(BuildContext context) {
        return StoreConnector<AppState, ViewModel>(
          model: ViewModel(),
          builder: (BuildContext context, ViewModel vm) => MyWidget(
            initialText: vm.initialText,
            clearTextEvt: vm.clearTextEvt, 
            changeTextEvt: vm.changeTextEvt, 
            onClear: vm.onClear,
          ));
      }
    }
    
    class ViewModel extends BaseModel<AppState> {
      ViewModel();
    
      String initialText;
      Event clearTextEvt;      
      Event<String> changeTextEvt;      
    
      ViewModel.build({
        @required this.initialText,
        @required this.clearTextEvt,
        @required this.changeTextEvt,
      }) : super(equals: [initialText, clearTextEvt, changeTextEvt]);
    
      @override
      ViewModel fromStore() => ViewModel.build(
            initialText: state.initialText,
            clearTextEvt: state.clearTextEvt,
            changeTextEvt: state.changeTextEvt,
            onClear: () => dispatch(ClearTextAction()),                                   
          );
    }

    class ClearTextAction extends ReduxAction<AppState> {          
      @override
      AppState reduce() => state.copy(changeTextEvt: Event());      
    }

    class ChangeTextAction extends ReduxAction<AppState> {
      String newText;
      ChangeTextAction(this.newText);
                      
      @override
      AppState reduce() => state.copy(changeTextEvt: Event<String>(newText));      
    }

This is how it differs: The dumb-widget will "consume" the event in its `didUpdateWidget`
method, and do something with the event payload:

    @override
    void didUpdateWidget(MyWidget oldWidget) {
      super.didUpdateWidget(oldWidget);
      consumeEvents();
    }
    
    void consumeEvents() {      
      if (widget.clearTextEvt.consume()) { // Do something }
      
      var payload = widget.changeTextEvt.consume();           
      if (payload != null) { // Do something }          
    }

The `evt.consume()` will return the payload once, and then that event is considered "spent". 

In more detail, if the event **has no value and no generic type**, then it's a boolean event. 
This means `evt.consume()` returns **true** once, 
and then **false** for subsequent calls. 
However, if the event **has value or some generic type**, then `Event.consume()` returns the **value** once,
and then **null** for subsequent calls.

So, for example, if you use a `controller` to hold the text in a `TextField`:

    void consumeEvents() {
          
        if (widget.clearTextEvt.consume())
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) controller.clear();
          });    
        
        String newText = widget.changeTextEvt.consume();   
        if (newText != null)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) controller.value = controller.value.copyWith(text: newText);
          });  
      }

      
Try running the: <a href="https://github.com/marcglasberg/async_redux/blob/master/example/main_event_redux.dart">Event Example</a>.

### Can I put mutable events into the store state?

Events are mutable, and store state is supposed to be immutable.
Won't this create problems? No! Don't worry, events are used in a contained way, 
and were crafted to play well with the Redux infrastructure.
In special, their `equals()` and `hashcode()` methods make sure no unnecessary widget rebuilds 
happen when they are used as prescribed.   
 
You can think of events as piggybacking in the Redux infrastructure, 
and not belonging to the store state. 
You should just remember **not to persist them** when you persist the store state.

### When should I use events?  
 
The short answer is that you'll know it when you see it. When you want to do something and it's not obvious 
how to do it by changing regular store state, it's probably easy to solve it if you try using events instead.

However, we can also give these guidelines:

1. You may use regular store state to pass constructor parameters to both stateless and stateful widgets.
2. You may use events to change the internal state of stateful widgets, after they are built.
3. You may use events to make one-off changes in controllers.
4. You may use events to make one-off changes in other implicit state like the open state of dialogs or the keyboard.

### Advanced event features

There are some advanced event features you probably won't need, but you should know they exist:

1. Methods `isSpent`, `isNotSpent` and `state`

    Methods `isSpent` and `isNotSpent` tell you if an event is spent or not, without consuming the event.
    Method `state` returns the event payload, without consuming the event.

2. Method `Event.from(Event<T> evt1, Event<T> evt2)` 

    This is a convenience factory method to create `EventMultiple`, 
    a special type of event which consumes from more than one event.
    If the first event is not spent, it will be consumed, and the second will not.
    If the first event is spent, the second one will be consumed.
    So, if both events are NOT spent, the method will have to be called twice to consume both.
    If both are spent, returns null.
    
3. Method `static T consumeFrom<T>(Event<T> evt1, Event<T> evt2)`    

    This is a convenience static method to consume from more than one event.
    If the first event is not spent, it will be consumed, and the second will not.
    If the first event is spent, the second one will be consumed.
    So, if both events are NOT spent, the method will have to be called twice to consume both.
    If both are spent, returns null. For example:
    ```
    String getMessageEvt() {
       return Event.consumeFrom(firstMsgEvt, secondMsgEvt);
     }
    ```
  
  
## State Declaration

While your main state class, usually called `AppState`, may be simple and contain all of the state directly, in a real world application 
you will probably want to create many state classes and add them to the main state class. For example, if you have
some state for the login, some user related state, and some *todos* in a To-Do app, you can organize it like this:

    class AppState {    
      
      final LoginState loginState;
      final UserState userState;
      final TodoState todoState;      
    
      AppState({
        this.loginState,
        this.userState,
        this.todoState,
      });
    
      AppState copy({
        LoginState loginState,
        UserState userState,
        TodoState todoState,
      }) {
        return AppState(          
          login: loginState ?? this.loginState,
          user: userState ?? this.userState,
          todo: todoState ?? this.todoState,          
        );
      }             
      
      static AppState initialState() =>
        AppState(
          loginState: LoginState.initialState(),
          userState: UserState.initialState(),
          todoState: TodoState.initialState());               
      
      @override
      bool operator ==(Object other) =>          
        identical(this, other) || other is AppState && runtimeType == other.runtimeType && 
          loginState == other.loginState && userState == other.userState && todoState == other.todoState;          
      
      @override
      int get hashCode => loginState.hashCode ^ userState.hashCode ^ todoState.hashCode;
    }

All of your state classes may follow this pattern. For example, the `TodoState` could be like this:

    class TodoState {    
      
      final List<Todo> todos;            
    
      TodoState({this.todos});
    
      TodoState copy({List<Todo> todos}) {
        return TodoState(          
          todos: todos ?? this.todos);
      }             
      
      static TodoState initialState() => TodoState(todos: const []);               
      
      @override
      bool operator ==(Object other) {          
        return identical(this, other) || other is TodoState && runtimeType == other.runtimeType && 
          ListEquality.equals(todos, other.todos);
      }    
      
      @override
      int get hashCode => ListEquality.hash(todos);
    }
    
### Selectors

Your connector-widgets usually have a view-model that goes into the store and selects the part of the store
the widget needs. If you have some "selecting logic" that you use in different places, you may create
a "selector". Selectors may be put in separate files, or they may be put into state classes, as static methods.
For example, the `TodoState` class above could contain a selector to filter out some todos:

    static List<Todo> selectTodosForUser(AppState state, User user) 
       => state.todoState.todos.where((todo) => (todo.user == user)).toList();       
    
## Action Subclassing
    
Suppose you have the following `AddTodoAction` for the To-Do app:
    
    class AddTodoAction extends ReduxAction<AppState> {      
      final Todo todo;         
      AddTodoAction(this.todo);
          
      @override
      AppState reduce() {
        if (todo == null) return null;
        else return state.copy(todoState: List.of(state.todoState.todos)..add(todo)));
      }
    }
    
    // You would use it like this:      
    store.dispatch(AddTodoAction(Todo("Buy some beer.")));
   
Since all actions extend `ReduxAction`, you may further use object oriented principles to reduce boilerplate.
Start by creating an **abstract** action base class to allow easier access to the sub-states of your store. 
For example:
    
    abstract class BaseAction extends ReduxAction<AppState> {
      LoginState get loginState => state.loginState;
      UserState get userState => state.userState;
      TodoState get todoState => state.todoState;      
      List<Todo> get todos => todoState.todos; 
    }    
    
And then your actions have an easier time accessing the store state:
    
    class AddTodoAction extends BaseAction {      
      final Todo todo;         
      AddTodoAction(this.todo);
    
      @override
      AppState reduce() {
        if (todo == null) return null;
        else return state.copy(todoState: List.of(todos)..add(todo)));
      }
    }
    
As you can see above, instead of writing `List.of(state.todoState.todos)` you can simply write `List.of(todos)`.
It may seem a small reduction of boilerplate, but it adds up.

Another thing you may do is creating more specialized **abstract** actions, that modify only some part of the state. 
For example:
    
    abstract class TodoAction extends ReduxAction<AppState> {      
      
      TodoState reduceTodoState();
          
      @override
      AppState reduce() {
        TodoState todoState = reduceTodoState();  
        return (todoState == null) ? null : state.copy(todoState: todoState);
      }            
    }    
    
If you declare those specialized abstract actions, you can have specialized reducers that only need to return 
that part of the state that changed:    
    
    class AddTodoAction extends TodoAction {      
      final Todo todo;         
      AddTodoAction(this.todo);
    
      @override
      TodoState reduceTodoState() {
        if (todo == null) return null;
        else return List.of(todos)..add(todo);
      }
    }
    
### Abstract Before and After

Other useful abstract classes you may create provide already overridden `before()` and `after()` methods.
For example, this abstract class turns on a modal barrier when the action starts, 
and removes it when the action finishes:

    abstract class BarrierAction extends ReduxAction<AppState> {            
      void before() => dispatch(WaitAction(true));         
      void after() => dispatch(WaitAction(false));
    }
    
Then you could use it like this:     

    class ChangeTextAction extends BarrierAction {
    
      @override
      Future<AppState> reduce() async {
        String newText = await read("http://numbersapi.com/${state.counter}");    
        return state.copy(
          counter: state.counter + 1,
          changeTextEvt: Event<String>(newText));
      }
    }

The above `BarrierAction` is demonstrated in <a href="https://github.com/marcglasberg/async_redux/blob/master/example/main_event_redux.dart">this example</a>.

## IDE Navigation 

How does AsyncRedux solve the IDE navigation problem?

During development, if you need to see what some action does, you just tell your IDE to navigate to the action itself 
(`CTRL+B` in IntelliJ/Windows, for example) and you have the reducer right there. 

If you need to list all of your actions,
you just go to the `ReduxAction` class declaration and ask the IDE to list all of its subclasses.

## Logging and Persistence

Your store optionally accepts lists of `actionObservers` and `stateObservers`. 
The first one may be used for logging, and the second for persistence:

    var store = Store<AppState>(
      initialState: state,
      actionObservers: [Log.printer(formatter: Log.verySimpleFormatter)],
      stateObservers: persistor.createStateObservers(),
    );

## How to interact with the database

The following advice works for any Redux version, including AsyncRedux.

Pretend the user presses a button in the dumb-widget, 
running a callback which was passed in its constructor. 
This callback, which was created by the Connector widget, will dispatch an action. 

This action's async reducer will connect to the database and get the desired information. 
You can **directly** connect to the database from the async reducer, 
or have a **DAO** to abstract the database implementation details.
 
This would be your reducer: 

    @override
    Future<AppState> reduce() async {
        var something = await myDao.loadSomething(); 
        return state.copy(something: something);
    }

This rebuilds your widgets that depend on `something`, with its new value. 
The state now holds the new `something`, 
and the local store persistor may persist this value to the local file system, if that's what you want.

## How to deal with Streams

The following advice works for any Redux version, including AsyncRedux.

AsyncRedux plays well with Streams, as long as you know how to use them:

- Don't send the streams down to the dumb-widget, and not even to the Connector. 
  If you are declaring, subscribing to, or unsubscribing from streams inside of widgets,
  it means you are mixing Redux with some other architecture. 
  You _can_ do that, but it's not recommended and not necessary.
  
- Don't put streams into the store state. 
  They are not app state, and they should not be persisted to the local filesystem. 
  Instead, they are something that "generates state". 
  
### So, how do you use streams? 

Let's pretend you want to listen to changes to the user name, in a Firestore database.
First, create an action to start listening, and another action to cancel. We could name them `StartListenUserNameAction`
and `CancelListenUserNameAction`. 

- If the stream should run all the time, you may dispatch the start action as soon as the app starts, 
right after you create the store, possibly in `main`. And cancel it when the app finishes.

- If the stream should run only when the user is viewing some screen, you may dispatch the action from 
the `initState` method of the screen widget, and cancel it from the `dispose` method.
Note: More precisely, these things are done by the callbacks that the Connectors create 
and send down to the stateful dumb-widgets.

- If the stream should run only when some actions demand it, 
their reducers may dispatch the actions to start and cancel as needed.        

### And where the stream subscriptions themselves are stored? 

As discussed above, you should NOT put them 
in the store state. Instead save them in some convenient place elsewhere, where your reducers may access them.
Remember you **only** need to access them from the reducers. If you have separate business and client layers,
put them into the business layer.

Some ideas:

- Put them as static variables of the specific **actions** that start them. 
For example, `userNameStream` could be a static field of the `StartListenUserNameAction` class.

- Put them in the **state classes** that most relate to them, but as **static** variables, 
  not instance variables (which would be store state).
  For example, if your `AppState` contains some `UserState`, then `userNameStream` 
  could be a static field of the `UserState` class. 

- Save them in global static variables. 

- Use a service locator, like <a href="https://pub.dev/packages/get_it">get_it</a>.

Or put them wherever you think makes sense.
In all cases above, you can still inject them with mocks, for tests.
    
### How do streams pass their information to the store and ultimately to the widgets?
  
When you create the stream, define its callback so that it dispatches an appropriate action. 
Each time the stream gets some data it will pass it to this action's constructor.
The action's reducer will put the data into the store state, from where it will be 
automatically sent down to the widgets that observe them (through their Connector/ViewModel).

For example:

    Stream<QuerySnapshot> stream = query.snapshots();
    
    streamSub = stream.listen((QuerySnapshot querySnapshot) {
      dispatch(DoSomethingAction(querySnapshot.documentChanges));
      }, onError: ...);    

### To sum up:

1. Put your stream subscriptions where they can be accessed by the reducers, 
but NOT inside of the store state.

2. Don't use streams directly in widgets (not in the Connector widget, and not in the dumb-widget).

3. Create actions to start and cancel streams, and call them when necessary.

4. The stream callback should dispatch actions to put the snapshot data into the store state. 

## Recommended Directory Structure

You probably have your own way of organizing your directory structure, but if you want some recommendation,
here it goes.

First, separate your directory structure by **client** and **business**.
The **client** directory holds Flutter stuff like widgets, including your connector and dumb widgets. 
The **business** directory holds the business layer stuff, including the store, state, and code to 
access the database and to persist the state to disk.

```
├── business
│   ├── lib
│   ├── test
│   └── pubspec.yaml
└── client
    ├── lib
    ├── test
    └── pubspec.yaml
```

Edit the `client/pubspec.yaml` file to contain this:

```dart
dependencies:
  business:
    path: ../business/
```

However, `business/pubspec.yaml` should contain no references to the **client**.  
This guarantees the **client** code can use the **business** code, 
but the **business** code can't access the **client** code. 

In `business/lib` create separate directories for your main features, 
and only then create directories like `actions`, `models`, `dao` or other.

Note that AsyncRedux has no separate reducers nor middleware, so this simplifies the directory structure
in relation to vanilla Redux. 

Your final directory structure would then look something like this:   

```
├── business
│   ├── lib
│   │   ├── login
│   │   │   ├── actions
│   │   │   │   ├── login_action.dart
│   │   │   │   ├── logout_action.dart
│   │   │   │   └── ...
│   │   │   └── models
│   │   │       └── login_state.dart
│   │   ├── todos
│   │   │   ├── actions
│   │   │   │   └── ...
│   │   │   └── models
│   │   │       ├── todos_state.dart
│   │   │       └── todo.dart
│   │   └── users
│   │       ├── actions
│   │       │   ├── create_user_action.dart
│   │       │   ├── change_user_action.dart
│   │       │   ├── delete_user_action.dart
│   │       │   └── ...
│   │       └── models
│   │           └── user.dart
│   ├── test
│   │   ├── login
│   │   │   ├── login_STATE_test.dart
│   │   │   ├── login_action_test.dart
│   │   │   ├── logout_action_test.dart
│   │   │   └── ...
│   │   ├── todos
│   │   │   ├── todos_STATE_test.dart
│   │   │   └── todo_test.dart
│   │   └── users
│   │       └── user_test.dart
│   ├── pubspec.yaml
│   └── ...
└── client
    ├── lib
    │   ├── login
    │   │   ├── login_connector_widget.dart
    │   │   └── login_widget.dart
    │   └── todos
    │       ├── todos_connector_widget.dart
    │       └── todos_widget.dart
    ├── test
    │   ├── login
    │   │   ├── login_CONNECTOR_test.dart
    │   │   └── login_PRESENTATION.dart
    │   └── todos
    │       ├── todos_CONNECTOR_test.dart
    │       └── todos_PRESENTATION.dart
    └── pubspec.yaml
```

***

*The AsyncRedux code is based upon packages <a href="https://pub.dev/packages/redux">redux</a> by Brian Egan,
and <a href="https://pub.dev/packages/flutter_redux">flutter_redux</a> by Brian Egan and John Ryan.
Also uses code from package <a href="https://pub.dev/packages/equatable">equatable</a> by Felix Angelov.
Special thanks: Eduardo Yamauchi and Hugo Passos helped me with the async code, 
checking the documentation, testing everything and making suggestions.
This work started after Thomas Burkhart explained to me why he didn't like Redux.
Reducers as methods of action classes were shown to me by Scott Stoll and Simon Lightfoot.*

*The Flutter packages I've authored:* 
* <a href="https://pub.dev/packages/async_redux">async_redux</a>
* <a href="https://pub.dev/packages/align_positioned">align_positioned</a>
* <a href="https://pub.dev/packages/network_to_file_image">network_to_file_image</a>
* <a href="https://pub.dev/packages/align_positioned">align_positioned</a> 
* <a href="https://pub.dev/packages/back_button_interceptor">back_button_interceptor</a>
* <a href="https://pub.dev/packages/indexed_list_view">indexed_list_view</a> 
* <a href="https://pub.dev/packages/animated_size_and_fade">animated_size_and_fade</a>

---<br>_https://github.com/marcglasberg_<br>
_https://twitter.com/glasbergmarcelo_<br>
_https://stackoverflow.com/users/3411681/marcg_<br>
_https://medium.com/@marcglasberg_<br>
