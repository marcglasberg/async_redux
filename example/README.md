# Examples

1. [main](lib/main.dart)

    This example shows a counter and a button.
    When the button is tapped, the counter will increment synchronously.
    
    In this simple example, the app state is simply a number (the counter),
    and thus the store is defined as `Store<int>`. The initial state is `0`.    

2. [main_increment_async](lib/main_increment_async.dart)
   
   This example shows a counter, a text description, and a button.
   When the button is tapped, the counter will increment synchronously,
   while an async process downloads some text description that relates
   to the counter number.  

3. [main_before_and_after](lib/main_before_and_after.dart)
   
    This example shows a counter, a text description, and a button.
    When the button is tapped, the counter will increment synchronously,
    while an async process downloads some text description that relates
    to the counter number.
   
    While the async process is running, a redish modal barrier will prevent
    the user from tapping the button. The model barrier is removed even if
    the async process ends with an error, which can be simulated by turning
    off the internet connection (putting the phone in airplane mode).

4. [main_before_and_after_STATE_test](test/main_before_and_after_STATE_test.dart)

   This example displays the testing capabilities of AsyncRedux: 
   How to test the store, actions, sync and async reducers, 
   by using the Store directly. **Important:** To run the tests, put this file in a test directory.
 
5. [main_show_error_dialog](lib/main_show_error_dialog.dart)
    
    This example lets you enter a name and click save.
    If the name has less than 4 chars, an error dialog will be shown.    

6. [main_navigate](lib/main_navigate.dart)

    This example shows a route in the screen, all red. 
    When you tap the screen it will push a new route, all blue.
    When you tap the screen again it will pop the blue route.

7. [main_event](lib/main_event.dart)

   This example shows a text-field, and two buttons.
   When the first button is tapped, an async process downloads some text from the internet
   and puts it in the text-field.
   When the second button is tapped, the text-field is cleared.
   
   This is meant to demonstrate the use of *events* to change a controller state.
    
   It also demonstrates the use of an abstract class to override the action's `before()` and `after()` methods.
    
8. [main_infinite_scroll.dart](lib/main_infinite_scroll.dart)

   This example demonstrates how to get a `Future` that completes when an action is done.
   It shows a list of number descriptions. 
   If you pull to refresh the page (scroll above the top of the page) 
   a `RefreshIndicator` will appear until the list is updated with different data.
   
9. [main_wait_action_simple](lib/main_wait_action_simple.dart)

   This example is the same as the one in `main_before_and_after.dart`.
   It uses `context.isWaiting()` to display progress while the action is running.
   
10. [main_wait_action_advanced_1](lib/main_wait_action_advanced_1.dart)

   This example uses `statusKey` to track each download independently.
   10 buttons are shown. When a button is clicked it will be replaced by a downloaded text description. 
   Each button shows a progress indicator while its description is downloading. 
   The screen title shows the text "Downloading..." if any of the buttons is currently downloading.   
   
11. [main_wait_action_advanced_2](lib/main_wait_action_advanced_2.dart)

   This example is the same as the one in `main_wait_action_advanced_1.dart`.
   It uses composite `statusKey` values to track each field of each row separately.
