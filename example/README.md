# Examples

1. <a href="https://github.com/marcglasberg/async_redux/blob/master/example/main.dart">main</a>

    This example shows a counter and a button.
    When the button is tapped, the counter will increment synchronously.
    
    In this simple example, the app state is simply a number (the counter),
    and thus the store is defined as `Store<int>`. The initial state is `0`.    

2. <a href="https://github.com/marcglasberg/async_redux/blob/master/example/main_increment_async.dart">main_increment_async</a>
   
   This example shows a counter, a text description, and a button.
   When the button is tapped, the counter will increment synchronously,
   while an async process downloads some text description that relates
   to the counter number.  

3. <a href="https://github.com/marcglasberg/async_redux/blob/master/example/main_before_and_after.dart">main_before_and_after</a>
   
    This example shows a counter, a text description, and a button.
    When the button is tapped, the counter will increment synchronously,
    while an async process downloads some text description that relates
    to the counter number.
   
    While the async process is running, a redish modal barrier will prevent
    the user from tapping the button. The model barrier is removed even if
    the async process ends with an error, which can be simulated by turning
    off the internet connection (putting the phone in airplane mode).

5. <a href="https://github.com/marcglasberg/async_redux/blob/master/example/main_before_and_after_STATE_test.dart">main_before_and_after_STATE_test</a>

   This example displays the testing capabilities of AsyncRedux: 
   How to test the store, actions, sync and async reducers, 
   by using the StoreTester. **Important:** To run the tests, put this file in a test directory.
 
4. <a href="https://github.com/marcglasberg/async_redux/blob/master/example/main_show_error_dialog.dart">main_show_error_dialog</a>
    
    This example lets you enter a name and click save.
    If the name has less than 4 chars, an error dialog will be shown.    

6. <a href="https://github.com/marcglasberg/async_redux/blob/master/example/main_event_redux.dart">main_event_redux</a>

   This example shows a text-field, and two buttons.
   When the first button is tapped, an async process downloads some text from the internet
   and puts it in the text-field.
   When the second button is tapped, the text-field is cleared.
   
   This is meant to demonstrate the use of *events* to change a controller state.
    
   It also demonstrates the use of an abstract class to override the action's `before()` and `after()` methods.
    
   
    
    
