<img src="https://asyncredux.com/img/platipus_FlutterReact.jpg">

[![Pub Version](https://img.shields.io/pub/v/async_redux?style=flat-square&logo=dart)](https://pub.dev/packages/async_redux)
[![pub package](https://img.shields.io/badge/Awesome-Flutter-blue.svg?longCache=true&style=flat-square)](https://github.com/Solido/awesome-flutter)
[![GitHub stars](https://img.shields.io/github/stars/marcglasberg/async_redux?style=social)](https://github.com/marcglasberg/async_redux)
![Code Climate issues](https://img.shields.io/github/issues/marcglasberg/async_redux?style=flat-square)
![GitHub closed issues](https://img.shields.io/github/issues-closed/marcglasberg/async_redux?style=flat-square)
![GitHub contributors](https://img.shields.io/github/contributors/marcglasberg/async_redux?style=flat-square)
![GitHub repo size](https://img.shields.io/github/repo-size/marcglasberg/async_redux?style=flat-square)
![GitHub forks](https://img.shields.io/github/forks/marcglasberg/async_redux?style=flat-square)
![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)
[![Developed by Marcelo Glasberg](https://img.shields.io/badge/Developed%20by%20Marcelo%20Glasberg-blue.svg)](https://glasberg.dev/)
[![Glasberg.dev on pub.dev](https://img.shields.io/pub/publisher/async_redux.svg)](https://pub.dev/publishers/glasberg.dev/packages)
[![Platforms](https://badgen.net/pub/flutter-platform/async_redux)](https://pub.dev/packages/async_redux)

#### Contributors

<a href="https://github.com/marcglasberg/async_redux/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=marcglasberg/async_redux&columns=9"/>
</a>

#### Sponsor

[![](./example/SponsoredByMyTextAi.png)](https://mytext.ai)

# Async Redux | *state management*

* Simple to learn and easy to use
* Powerful enough to handle complex applications with millions of users
* Testable

This means you'll be able to create apps much faster,
and other people on your team will easily understand and modify your code.

## What is it?

An optimized reimagined version of Redux.
A mature solution, battle-tested in hundreds of real-world applications.
Written from the ground up, created
by [Marcelo Glasberg](https://github.com/marcglasberg)
(see [all my packages](https://pub.dev/publishers/glasberg.dev/packages)).

> There is also
> a [version for React](https://www.npmjs.com/package/async-redux-react)

> Optionally use it with [Provider](https://pub.dev/packages/provider_for_redux)
> or [Flutter Hooks](https://pub.dev/packages/flutter_hooks_async_redux)

# Documentation

The complete docs are published at **https://asyncredux.com**

Below is a quick overview.

***

# Store, state, actions and reducers

The store holds all the application **state**. A few examples:

```dart
// Here, the state is a number
var store = Store<int>(initialState: 1);
```

```dart
// Here, the state is an object
class AppState {
  final String name;
  final int age;
  State(this.name, this.age);
}

var store = Store<AppState>(initialState: AppState('Mary', 25));
```

&nbsp;

To use the store, add it in a `StoreProvider` at the top of your widget tree.

```dart
Widget build(context) {
  return StoreProvider<int>(
    store: store,
    child: MaterialApp( ... ), 
    );                      
}
```

&nbsp;

# Widgets use the state

```dart
class MyWidget extends StatelessWidget {

  Widget build(context) {
    return Text('${context.state.name} has ${context.state.age} years old');
  }
}
```

&nbsp;

# Actions and reducers

An **action** is a class that contain its own **reducer**.

```dart
class Increment extends Action {

  // The reducer has access to the current state
  int reduce() => state + 1; // It returns a new state
}
```

&nbsp;

# Dispatch an action

The store state is **immutable**.

The only way to change the store **state** is by dispatching an **action**.
The action reducer returns a new state, that replaces the old one.

```dart
// Dispatch an action
store.dispatch(Increment());

// Dispatch multiple actions
store.dispatchAll([Increment(), LoadText()]);

// Dispatch an action and wait for it to finish
await store.dispatchAndWait(Increment());

// Dispatch multiple actions and wait for them to finish
await store.dispatchAndWaitAll([Increment(), LoadText()]);
```

&nbsp;

# Widgets can dispatch actions

The context extensions to dispatch actions are `dispatch` , `dispatchAll` etc.

```dart
class MyWidget extends StatelessWidget {
 
  Widget build(context) { 
    return ElevatedButton(
      onPressed: () => context.dispatch(Increment());
    }     
}
```

&nbsp;

# Actions can do asynchronous work

They download information from the internet, or do any other async work.

```dart
var store = Store<String>(initialState: '');
```

```dart
class LoadText extends Action {

  // This reducer returns a Future  
  Future<String> reduce() async {
  
    // Download something from the internet
    var response = await http.get('https://dummyjson.com/todos/1');
    
    // Change the state with the downloaded information
    return response.body;      
  }
}
```

&nbsp;

> If you want to understand the above code in terms of traditional Redux
> patterns,
> all code until the last `await` in the `reduce` method is the equivalent of a
> middleware,
> and all code after that is the equivalent of a traditional reducer.
> It's still Redux, just written in a way that is easy and boilerplate-free.
> No need for Thunks or Sagas.

&nbsp;

# Actions can throw errors

If something bad happens, you can simply **throw an error**. In this case, the
state will
not
change. Errors are caught globally and can be handled in a central place, later.

In special, if you throw a `UserException`, which is a type provided by Async
Redux,
a dialog (or other UI) will open automatically, showing the error message to the
user.

```dart
class LoadText extends Action {
    
  Future<String> reduce() async {  
    var response = await http.get('https://dummyjson.com/todos/1');

    if (response.statusCode == 200) return response.body;
    else throw UserException('Failed to load');         
  }
}
```

&nbsp;

To show a spinner while an asynchronous action is running, use
`isWaiting(action)`.

To show an error message inside the widget, use `isFailed(action)`.

```dart
class MyWidget extends StatelessWidget {

  Widget build(context) {
    
    if (context.isWaiting(LoadText)) return CircularProgressIndicator();
    if (context.isFailed(LoadText)) return Text('Loading failed...');
    return Text(context.state);
  }
}
```

&nbsp;

# Actions can dispatch other actions

You can use `dispatchAndWait` to dispatch an action and wait for it to finish.

```dart
class LoadTextAndIncrement extends Action {

  Future<AppState> reduce() async {    
    
    // Dispatch and wait for the action to finish
    await dispatchAndWait(LoadText());
    
    // Only then, increment the state
    return state.copy(count: state.count + 1);
  }
}
```

&nbsp;

You can also dispatch actions in **parallel** and wait for them to finish:

```dart
class BuyAndSell extends Action {

  Future<AppState> reduce() async {
  
    // Dispatch and wait for both actions to finish
    await dispatchAndWaitAll([
      BuyAction('IBM'), 
      SellAction('TSLA')
    ]);
    
    return state.copy(message: 'New cash balance is ${state.cash}');
  }
}
```

&nbsp;

You can also use `waitCondition` to wait until the `state` changes in a certain
way:

```dart
class SellStockForPrice extends Action {
  final String stock;
  final double limitPrice;
  SellStockForPrice(this.stock, this.limitPrice);

  Future<AppState?> reduce() async {  
  
    // Wait until the stock price is higher than the limit price
    await waitCondition(
      (state) => state.stocks[stock].price >= limitPrice
    );
      
    // Only then, post the sell order to the backend
    var amount = await postSellOrder(stock);    
    
    return state.copy(
      stocks: state.stocks.setAmount(stock, amount),
    ); 
}
```

&nbsp;

# Add features to your actions

You can add **mixins** to your actions, to accomplish common tasks.

## Check for Internet connectivity

`CheckInternet` ensures actions only run with internet,
otherwise an **error dialog** prompts users to check their connection:

```dart
class LoadText extends Action with CheckInternet {
      
   Future<String> reduce() async {
      var response = await http.get('https://dummyjson.com/todos/1');
      ...      
   }
}   
```

&nbsp;

`NoDialog` can be added to `CheckInternet` so that no dialog is opened.
Instead, you can display some information in your widgets:

```dart
class LoadText extends Action with CheckInternet, NoDialog { 
  ... 
  }

class MyWidget extends StatelessWidget {
  Widget build(context) {     
     if (context.isFailed(LoadText)) Text('No Internet connection');
  }
}   
```

&nbsp;

`AbortWhenNoInternet` aborts the action silently (without showing any dialogs)
if there is no internet connection.

&nbsp;

## NonReentrant

To prevent an action from being dispatched while it's already running,
add the `NonReentrant` mixin to your action class.

```dart
class LoadText extends Action with NonReentrant {
   ...
   }
```

&nbsp;

## Retry

Add the `Retry` mixin to retry the action a few times with exponential backoff, 
if it fails. Add `UnlimitedRetries` to retry indefinitely:

```dart
class LoadText extends Action with Retry, UnlimitedRetries {
   ...
   }
```

&nbsp;

## UnlimitedRetryCheckInternet

Add `UnlimitedRetryCheckInternet` to check if there is internet when you run
some action that needs it. If there is no internet, the action will abort
silently and then retried unlimited times, until there is internet. It will also
retry if there is internet but the action failed.

```dart
class LoadText extends Action with UnlimitedRetryCheckInternet {
   ...
   }
```

&nbsp;

## Throttle

The `Throttle` mixin prevents a dispatched action from running too often.
If the action loads information, the information is considered _fresh_.
Only after the throttle period ends is the information considered _stale_,
allowing the action to run again to reload the information.

```dart
class LoadPrices extends Action with Throttle {  
  
  final int throttle = 5000; // Milliseconds

  Future<AppState> reduce() async {      
    var result = await loadJson('https://example.com/prices');              
    return state.copy(prices: result);
  }
}
```

&nbsp;

## Debounce

To limit how often an action occurs in response to rapid inputs, you can add 
the `Debounce` mixin to your action class. For example, when a user types in 
a search bar, debouncing ensures that not every keystroke triggers a server 
request. Instead, it waits until the user pauses typing before acting.

```dart
class SearchText extends Action with Debounce {
  final String searchTerm;
  SearchText(this.searchTerm);
  
  final int debounce = 300; // Milliseconds

  Future<AppState> reduce() async {
      
    var response = await http.get(
      Uri.parse('https://example.com/?q=' + encoded(searchTerm))
    );
        
    return state.copy(searchResult: response.body);
  }
}
```

&nbsp;

## OptimisticUpdate (soon)

To provide instant feedback on actions that save information to the server, this
feature
immediately
applies state changes as if they were already successful, before confirming with
the
server.
If the server update fails, the change is rolled back and, optionally, a
notification can
inform
the user of the issue.

```dart
class SaveName extends Action with OptimisticUpdate { 
   
  async reduce() { ... } 
}
```

&nbsp;

# Events

Flutter widgets like `TextField` and `ListView` hold their own internal state.
You can use `Events` to interact with them.

```dart
// Action that changes the text of a TextField
class ChangeText extends Action {
  final String newText;
  ChangeText(this.newText);    
 
  AppState reduce() => state.copy(changeText: Event(newText));
  }
}

// Action that scrolls a ListView to the top
class ScrollToTop extends Action {
  AppState reduce() => state.copy(scroll: Event(0));
  }
}
```

&nbsp;

# Persist the state

You can add a `persistor` to save the state to the local device disk.

```dart
var store = Store<AppState>(
  persistor: MyPersistor(),  
);  
```

&nbsp;

# Testing your app is easy

Just dispatch actions and wait for them to finish.
Then, verify the new state or check if some error was thrown.

```dart
class AppState {  
  List<String> items;    
  int selectedItem;
}

test('Selecting an item', () async {   

    var store = Store<AppState>(
      initialState: AppState(        
        items: ['A', 'B', 'C']
        selectedItem: -1, // No item selected
      ));
    
    // Should select item 2                
    await store.dispatchAndWait(SelectItem(2));    
    expect(store.state.selectedItem, 'B');
    
    // Fail to select item 42
    var status = await store.dispatchAndWait(SelectItem(42));    
    expect(status.originalError, isA<>(UserException));
});
```

&nbsp;

# Advanced setup

If you are the Team Lead, you set up the app's infrastructure in a central
place,
and allow your developers to concentrate solely on the business logic.

You can add a `stateObserver` to collect app metrics, an `errorObserver` to log
errors,
an `actionObserver` to print information to the console during development,
and a `globalWrapError` to catch all errors.

```dart
var store = Store<String>(    
  stateObserver: [MyStateObserver()],
  errorObserver: [MyErrorObserver()],
  actionObservers: [MyActionObserver()],
  globalWrapError: MyGlobalWrapError(),
```

&nbsp;

For example, the following `globalWrapError` handles `PlatformException` errors
thrown
by Firebase. It converts them into `UserException` errors, which are built-in
types that
automatically show a message to the user in an error dialog:

```dart
Object? wrap(error, stackTrace, action) =>
  (error is PlatformException)
    ? UserException('Error connecting to Firebase')
    : error;
}  
```

&nbsp;

# Advanced action configuration

The Team Lead may create a base action class that all actions will extend, and
add some
common
functionality to it. For example, getter shortcuts to important parts of the
state,
and selectors to help find information.

```dart
class AppState {  
  List<Item> items;    
  int selectedItem;
}

class Action extends ReduxAction<AppState> {

  // Getter shortcuts   
  List<Item> get items => state.items;
  Item get selectedItem => state.selectedItem;
  
  // Selectors 
  Item? findById(int id) => items.firstWhereOrNull((item) => item.id == id);
  Item? searchByText(String text) => items.firstWhereOrNull((item) => item.text.contains(text));
  int get selectedIndex => items.indexOf(selectedItem);     
}
```

&nbsp;

Now, all actions can use them to access the state in their reducers:

```dart
class SelectItem extends Action {
  final int id;
  SelectItem(this.id);
    
  AppState reduce() {
    Item? item = findById(id);
    if (item == null) throw UserException('Item not found');
    return state.copy(selected: item);
  }    
}
```         

***

To learn more, the complete Async Redux documentation is published
at https://asyncredux.com

***

## By Marcelo Glasberg

<a href="https://glasberg.dev">_glasberg.dev_</a>
<br>
<a href="https://github.com/marcglasberg">_github.com/marcglasberg_</a>
<br>
<a href="https://www.linkedin.com/in/marcglasberg/">
_linkedin.com/in/marcglasberg/_</a>
<br>
<a href="https://twitter.com/glasbergmarcelo">_twitter.com/glasbergmarcelo_</a>
<br>
<a href="https://stackoverflow.com/users/3411681/marcg">
_stackoverflow.com/users/3411681/marcg_</a>
<br>
<a href="https://medium.com/@marcglasberg">_medium.com/@marcglasberg_</a>
<br>

*I wrote Google's official Flutter documentation on layout rules*:

* <a href="https://flutter.dev/docs/development/ui/layout/constraints">
  Understanding
  constraints</a>

*The Flutter packages I've authored:*

* <a href="https://pub.dev/packages/async_redux">async_redux</a>
* <a href="https://pub.dev/packages/provider_for_redux">provider_for_redux</a>
* <a href="https://pub.dev/packages/i18n_extension">i18n_extension</a>
* <a href="https://pub.dev/packages/align_positioned">align_positioned</a>
* <a href="https://pub.dev/packages/network_to_file_image">
  network_to_file_image</a>
* <a href="https://pub.dev/packages/image_pixels">image_pixels</a>
* <a href="https://pub.dev/packages/matrix4_transform">matrix4_transform</a>
* <a href="https://pub.dev/packages/back_button_interceptor">
  back_button_interceptor</a>
* <a href="https://pub.dev/packages/indexed_list_view">indexed_list_view</a>
* <a href="https://pub.dev/packages/animated_size_and_fade">
  animated_size_and_fade</a>
* <a href="https://pub.dev/packages/assorted_layout_widgets">
  assorted_layout_widgets</a>
* <a href="https://pub.dev/packages/weak_map">weak_map</a>
* <a href="https://pub.dev/packages/themed">themed</a>
* <a href="https://pub.dev/packages/bdd_framework">bdd_framework</a>
* <a href="https://pub.dev/packages/tiktoken_tokenizer_gpt4o_o1">
  tiktoken_tokenizer_gpt4o_o1</a>

*My Medium Articles:*

* <a href="https://medium.com/flutter-community/https-medium-com-marcglasberg-async-redux-33ac5e27d5f6">
  Async Redux: Flutter’s non-boilerplate version of Redux</a> 
  (versions: <a href="https://medium.com/flutterando/async-redux-pt-brasil-e783ceb13c43">
  Português</a>)
* <a href="https://medium.com/flutter-community/i18n-extension-flutter-b966f4c65df9">
  i18n_extension</a> 
  (versions: <a href="https://medium.com/flutterando/qual-a-forma-f%C3%A1cil-de-traduzir-seu-app-flutter-para-outros-idiomas-ab5178cf0336">
  Português</a>)
* <a href="https://medium.com/flutter-community/flutter-the-advanced-layout-rule-even-beginners-must-know-edc9516d1a2">
  Flutter: The Advanced Layout Rule Even Beginners Must Know</a> 
  (versions: <a href="https://habr.com/ru/post/500210/">русский</a>)
* <a href="https://medium.com/flutter-community/the-new-way-to-create-themes-in-your-flutter-app-7fdfc4f3df5f">
  The New Way to create Themes in your Flutter App</a> 
