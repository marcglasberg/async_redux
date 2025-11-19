# Examples

1. <a href="https://github.com/marcglasberg/async_redux/blob/master/example/lib/main.dart">main</a>

    This example shows a counter and a button.
    When the button is tapped, the counter will increment synchronously.
    
    In this simple example, the app state is simply a number (the counter),
    and thus the store is defined as `Store<int>`. The initial state is `0`.    

2. <a href="https://github.com/marcglasberg/async_redux/blob/master/example/lib/main_increment_async.dart">main_increment_async</a>
   
   This example shows a counter, a text description, and a button.
   When the button is tapped, the counter will increment synchronously,
   while an async process downloads some text description that relates
   to the counter number.  

3. <a href="https://github.com/marcglasberg/async_redux/blob/master/example/lib/main_before_and_after.dart">main_before_and_after</a>
   
    This example shows a counter, a text description, and a button.
    When the button is tapped, the counter will increment synchronously,
    while an async process downloads some text description that relates
    to the counter number.
   
    While the async process is running, a redish modal barrier will prevent
    the user from tapping the button. The model barrier is removed even if
    the async process ends with an error, which can be simulated by turning
    off the internet connection (putting the phone in airplane mode).

4. <a href="https://github.com/marcglasberg/async_redux/blob/master/example/lib/main_static_view_model.dart">main_static_view_model</a>

    This example shows how to use the same `ViewModel` architecture of flutter_redux.
    This is specially useful if you are migrating from flutter_redux.  
    Here, you use the `StoreConnector`'s `converter` parameter, instead of the `vm` parameter.
    And `ViewModel` doesn't extend `Vm`, but has a static factory:
    `converter: (store) => ViewModel.fromStore(store)`.    

5. <a href="https://github.com/marcglasberg/async_redux/blob/master/example/test/main_before_and_after_STATE_test.dart">main_before_and_after_STATE_test</a>

   This example displays the testing capabilities of AsyncRedux: 
   How to test the store, actions, sync and async reducers, 
   by using the StoreTester. **Important:** To run the tests, put this file in a test directory.
 
6. <a href="https://github.com/marcglasberg/async_redux/blob/master/example/lib/main_show_error_dialog.dart">main_show_error_dialog</a>
    
    This example lets you enter a name and click save.
    If the name has less than 4 chars, an error dialog will be shown.    

7. <a href="https://github.com/marcglasberg/async_redux/blob/master/example/lib/main_navigate.dart">main_navigate</a>

    This example shows a route in the screen, all red. 
    When you tap the screen it will push a new route, all blue.
    When you tap the screen again it will pop the blue route.

8. <a href="https://github.com/marcglasberg/async_redux/blob/master/example/lib/main_event.dart">main_event_redux</a>

   This example shows a text-field, and two buttons.
   When the first button is tapped, an async process downloads some text from the internet
   and puts it in the text-field.
   When the second button is tapped, the text-field is cleared.
   
   This is meant to demonstrate the use of *events* to change a controller state.
    
   It also demonstrates the use of an abstract class to override the action's `before()` and `after()` methods.
    
9. <a href="https://github.com/marcglasberg/async_redux/blob/master/example/lib/main_infinite_scroll.dart">main_infinite_scroll.dart</a>

   This example demonstrates how to get a `Future` that completes when an action is done.
   It shows a list of number descriptions. 
   If you pull to refresh the page (scroll above the top of the page) 
   a `RefreshIndicator` will appear until the list is updated with different data.
   
10. <a href="https://github.com/marcglasberg/async_redux/blob/master/example/lib/main_wait_action_simple.dart">main_wait_action_simple</a>

   This example is the same as the one in `main_before_and_after.dart`.
   However, instead of declaring a `MyWaitAction`, it uses the build-in `WaitAction`.         
   
11. <a href="https://github.com/marcglasberg/async_redux/blob/master/example/lib/main_wait_action_advanced_1.dart">main_wait_action_advanced_1</a>

   This example demonstrates how to use `WaitAction` in advanced ways.   
   10 buttons are shown. When a button is clicked it will be replaced by a downloaded text description. 
   Each button shows a progress indicator while its description is downloading. 
   The screen title shows the text "Downloading..." if any of the buttons is currently downloading.   
   
12. <a href="https://github.com/marcglasberg/async_redux/blob/master/example/lib/main_wait_action_advanced_2.dart">main_wait_action_advanced_2</a>

   This example is the same as the one in `main_wait_action_advanced_1.dart`.
   However, instead of only using flags in the `WaitAction`, it uses both flags and references.
