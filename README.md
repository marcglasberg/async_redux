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

#### Created by

**[Marcelo Glasberg](https://glasberg.dev)** | [LinkedIn](https://linkedin.com/in/marcglasberg/) | [GitHub](https://github.com/marcglasberg/)

#### Contributors

<a href="https://github.com/marcglasberg/async_redux/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=marcglasberg/async_redux&columns=9"/>
</a>

#### Sponsor

[![](./example/SponsoredByMyTextAi.png)](https://mytext.ai)

# AsyncRedux | *state management*

* Simple to learn, easy to use
* Handles complex applications with millions of users
* Testable

You'll be able to create apps much faster,
and other people on your team will easily understand and modify your code.

## What is it?

An optimized reimagined version of Redux.
A mature solution, battle-tested in hundreds of real-world applications.
Created by [Marcelo Glasberg](https://github.com/marcglasberg)
(see [all my packages](https://pub.dev/publishers/glasberg.dev/packages)).

> There is also a version for React
> [called Kiss State](https://kissforreact.org/)

> If you use Bloc, check [Bloc Superpowers](https://pub.dev/packages/bloc_superpowers)

> Optionally use AsyncRedux with [Provider](https://pub.dev/packages/provider_for_redux)
> or [Flutter Hooks](https://pub.dev/packages/flutter_hooks_async_redux)

# Documentation

### Complete docs → **https://asyncredux.com**

### Claude Code Skills → *
*[On GitHub](https://github.com/marcglasberg/async_redux/tree/main/.claude/skills)**

&nbsp;

_Below is a quick overview._

***

# Store and state

The **store** holds all the application **state**.

```dart
// The application state
class AppState {
  final String name;
  final int age;
  AppState(this.name, this.age);
}

// Create the store with the initial state
var store = Store<AppState>(
   initialState: AppState('Mary', 25)
);
```

&nbsp;

To use the store, add it in a `StoreProvider` at the top of your widget tree.

```dart
Widget build(context) {
  return StoreProvider<AppState>(
    store: store,
    child: MaterialApp( ... ), 
    );                      
}
```

&nbsp;

# Widgets use the state

Using `context.state`, your widgets rebuild when the state changes.

```dart
class MyWidget extends StatelessWidget {

  Widget build(context)
    => Text('${context.state.name} has ${context.state.age} years old');
}
```

Or use `context.select()` to get only the parts of the state you need.

```dart
Widget build(context) {

  var state = context.select((st) => (
     name: st.user.name, 
     age: st.user.age),
  );
  
  return Text('${state.name} has ${state.age} years old');
}
```

This also works:

```dart
Widget build(context) {
  var name = context.select((st) => st.name);
  var age = context.select((st) => st.age);
  
  return Text('$name has $age years old');
}
```

&nbsp;

# Actions change the state

The application state is **immutable**,
so the only way to change it is by **dispatching** an **action**.

```dart
// Dispatch an action
dispatch(Increment());

// Dispatch multiple actions
dispatchAll([Increment(), LoadText()]);

// Dispatch an action and wait for it to finish
await dispatchAndWait(Increment());

// Dispatch multiple actions and wait for them to finish
await dispatchAndWaitAll([Increment(), LoadText()]);
```

&nbsp;

An **action** is a class with a name that describes what it does, like
`Increment`, `LoadText`, or `BuyStock`.

It must include a method called `reduce`. This "reducer" has access to the
current state, and must return a new one to replace it.

```dart
class Increment extends Action {

  // The reducer has access to the current state
  AppState reduce() 
    => AppState(state.name, state.age + 1); // Returns new state
}
```

&nbsp;

# Widgets can dispatch actions

In your widgets, use `context.dispatch` to dispatch actions.

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

Actions may download information from the internet, or do any other async work.

```dart
class LoadText extends Action {

  // This reducer returns a Future
  Future<AppState> reduce() async {

    // Download something from the internet
    var response = await http.get('https://dummyjson.com/todos/1');
    var newName = state.response.body;

    // Change the state with the downloaded information
    return AppState(newName, state.age);
  }
}
```

&nbsp;

# Actions can throw errors

If something bad happens, you can simply **throw an error**. In this case, the
state will not change. Errors are caught globally and can be handled in a
central place, later.

In special, if you throw a `UserException`, which is a type provided by Async
Redux, a dialog (or other UI) will open automatically, showing the error message
to the user.

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
      (st) => st.stocks[stock].price >= limitPrice
    );
      
    // Only then, post the sell order to the backend
    var amount = await postSellOrder(stock);    
    
    return state.copy(
      stocks: state.stocks.setAmount(stock, amount),
    ); 
}
```

&nbsp;

# Add mixins to your actions

You can use **mixins** to accomplish common tasks.

## Check for Internet connectivity

Mixin `CheckInternet` ensures actions only run with internet,
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

Mixin `NoDialog` can be added to `CheckInternet` so that no dialog is opened.
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

Mixin `AbortWhenNoInternet` aborts the action silently (without showing any
dialogs) if there is no internet connection.

&nbsp;

## NonReentrant

Mixin `NonReentrant` prevents an action from being dispatched while it's
already running.

```dart
class LoadText extends Action with NonReentrant {
   ...
}
```

&nbsp;

## Retry

Mixin `Retry` retries the action a few times with exponential backoff,
if it fails. Add `UnlimitedRetries` to retry indefinitely:

```dart
class LoadText extends Action with Retry, UnlimitedRetries {
   ...
}
```

&nbsp;

## UnlimitedRetryCheckInternet

Mixin `UnlimitedRetryCheckInternet` checks if there is internet when you run
some action that needs it. If there is no internet, the action will abort
silently and then retried unlimited times, until there is internet. It will also
retry if there is internet but the action failed.

```dart
class LoadText extends Action with UnlimitedRetryCheckInternet {
   ...
}
```

&nbsp;

## Fresh

Mixin `Fresh` prevents a dispatched action from reloading the same information
while it is still up to date. The first dispatch always runs and loads the data.
While the data is _fresh_, later dispatches do nothing. When the fresh period
ends, the data becomes _stale_ and the action may run again.

```dart
class LoadPrices extends Action with Fresh {  
  
  final int freshFor = 5000; // Milliseconds

  Future<AppState> reduce() async {      
    var result = await loadJson('https://example.com/prices');              
    return state.copy(prices: result);
  }
}
```

&nbsp;

## Throttle

Mixin Throttle limits how often an action can run, acting as a simple rate
limit. The first dispatch runs right away.
Any later dispatches during the throttle period are ignored.
Once the period ends, the next dispatch is allowed to run again.

```dart
class RefreshFeed extends Action with Throttle {
  final int throttle = 3000; // Milliseconds

  Future<AppState> reduce() async {
    final items = await loadJson('https://example.com/feed');
    return state.copy(feedItems: items);
  }
}
```

&nbsp;

## Debounce

Mixin `Debounce` limits how often an action occurs in response to rapid inputs.
For example, when a user types in a search bar, debouncing ensures that not
every keystroke triggers a server request. Instead, it waits until the user
pauses typing before acting.

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

## OptimisticCommand

Mixin `OptimisticCommand` helps you provide instant feedback on **blocking**
actions that save information to the server. You immediately apply state changes
as if they were already successful. The UI prevents the user from making other
changes until the server confirms the update. If the update fails, the change
is rolled back.

```dart
class SaveTodo extends Action with OptimisticCommand {
  final Todo todo;
  SaveTodo(this.todo); 
   
  async reduce() { ... } 
}
```

&nbsp;

## OptimisticSync

Mixin `OptimisticSync` helps you provide instant feedback on **non-blocking**
actions that save information to the server. The UI does **not** prevent the
user from making other changes. Changes are applied locally right away,
while the mixin synchronizes those changes with the server in the background.

```dart
class SaveLike extends Action with OptimisticSync {
  final bool isLiked;
  SaveLike(this.isLiked); 
  
  async reduce() { ... } 
}
```

&nbsp;

## OptimisticSyncWithPush

Mixin `OptimisticSyncWithPush` is similar to `OptimisticSync`, but it also
assumes that the app listens to the server, for example via WebSockets.
It supports server versioning and multiple clients updating the same data
concurrently.

```dart
class SaveLike extends Action with OptimisticSyncWithPush {
  final bool isLiked;
  SaveLike(this.isLiked); 
  
  async reduce() { ... } 
}
```

&nbsp;

# Events

You can use `Evt()` to create events that perform one-time operations,
to work with widgets like **TextField** or **ListView** that manage their
own internal state.

```dart
// Action that changes the text of a TextField
class ChangeText extends Action {
  final String newText;
  ChangeText(this.newText);    
  AppState reduce() => state.copy(changeText: Evt(newText));
  }
}

// Action that scrolls a ListView to the top
class ScrollToTop extends Action {
  AppState reduce() => state.copy(scroll: Evt(0));
  }
}
```

Then, consume the events in your widgets:

```dart
Widget build(context) {

  var clearText = context.event((st) => st.clearTextEvt);
  if (clearText) controller.clear();

  var newText = context.event((st) => st.changeTextEvt);
  if (newText != null) controller.text = newText;
  
  return ...
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
place, and allow your developers to concentrate solely on the business logic.

You can add a `stateObserver` to collect app metrics, an `errorObserver` to log
errors, an `actionObserver` to print information to the console during
development, and a `globalWrapError` to catch all errors.

```dart
var store = Store<String>(    
  stateObserver: [MyStateObserver()],
  errorObserver: [MyErrorObserver()],
  actionObservers: [MyActionObserver()],
  globalWrapError: MyGlobalWrapError(),
```

&nbsp;

For example, the following `globalWrapError` handles `PlatformException` errors
thrown by Firebase. It converts them into `UserException` errors, which are
built-in types that automatically show a message to the user in an error dialog:

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
add some common functionality to it. For example, getter shortcuts to important
parts of the state, and selectors to help find information.

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

&nbsp;

# Claude Code Skills

This package includes **Skills** that help you use `async_redux` with
Claude Code and other AI agents.

To use it, you have to copy the skills
from [this repository](https://github.com/marcglasberg/async_redux/tree/master/.claude/skills)
to your project.
[Learn more](https://asyncredux.com/flutter/claude-code-skills).

---

### Complete docs → **https://asyncredux.com**

***

## Created by Marcelo Glasberg

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

*Flutter packages I've authored:*

* <a href="https://pub.dev/packages/bloc_superpowers">bloc_superpowers</a>
* <a href="https://pub.dev/packages/i18n_extension">i18n_extension</a>
* <a href="https://pub.dev/packages/async_redux">async_redux</a>
* <a href="https://pub.dev/packages/provider_for_redux">provider_for_redux</a>
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

*The JavaScript/TypeScript packages I've authored:*

* [Kiss State, for React](https://kissforreact.org/) (similar to AsyncRedux,
  but for React)
* [Easy BDD Tool, for Jest](https://www.npmjs.com/package/easy-bdd-tool-jest)

*My Medium Articles:*

* <a href="https://medium.com/flutter-community/https-medium-com-marcglasberg-async-redux-33ac5e27d5f6">
  AsyncRedux: Flutter’s non-boilerplate version of Redux</a> 
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
