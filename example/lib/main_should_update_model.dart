// import 'package:async_redux/async_redux.dart';
// import 'package:flutter/material.dart';
//
// // Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// // For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux
//
// late Store<int> store;
//
// /// This example shows how to prevent rebuilding from invalid states,
// /// using the `when` parameter of context.select.
// ///
// /// When the button is tapped, the counter will increment 5 times,
// /// synchronously. So, the sequence would be 0, 5, 10, 15, 20, 25 etc.
// ///
// /// However, we consider odd numbers invalid (the `when` parameter
// /// returns `false` for odd numbers).
// ///
// /// Therefore, it will display 0, 4, 10, 14, 20, 24 etc.
// ///
// void main() {
//   store = Store<int>(initialState: 0);
//   runApp(MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) => StoreProvider<int>(
//       store: store,
//       child: MaterialApp(
//         home: MyHomePageConnector(),
//       ));
// }
//
// /// This action increments the counter by [amount]].
// class IncrementAction extends ReduxAction<int> {
//   final int amount;
//
//   IncrementAction({required this.amount});
//
//   @override
//   int reduce() => state + amount;
// }
//
// class MyHomePageConnector extends StatelessWidget {
//   MyHomePageConnector({Key? key}) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     // Use context.select with the `when` parameter.
//     final counter = context.select(
//       (state) => state,
//       when: (state) => state % 2 == 0, // Only rebuild when the counter is even.
//     );
//
//     return MyHomePage(
//       counter: counter,
//       onIncrement: () {
//         // Increment 5 times
//         context.dispatch(IncrementAction(amount: 1));
//         context.dispatch(IncrementAction(amount: 1));
//         context.dispatch(IncrementAction(amount: 1));
//         context.dispatch(IncrementAction(amount: 1));
//         context.dispatch(IncrementAction(amount: 1));
//       },
//     );
//   }
// }
//
// class MyHomePage extends StatelessWidget {
//   final int counter;
//   final VoidCallback onIncrement;
//
//   MyHomePage({
//     Key? key,
//     required this.counter,
//     required this.onIncrement,
//   }) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Increment Example')),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const Padding(
//               padding: const EdgeInsets.all(20.0),
//               child: Text(
//                   'Each time you push the button it increments 5 times.\n\n'
//                   'But only even values are valid to appear in the UI.\n\n'
//                   'This demonstrates the use of the `when` parameter in context.select.'),
//             ),
//             Text('$counter', style: const TextStyle(fontSize: 30))
//           ],
//         ),
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: onIncrement,
//         child: const Icon(Icons.add),
//       ),
//     );
//   }
// }
//
// extension BuildContextExtension on BuildContext {
//   int get state => getState<int>();
//
//   int read() => getRead<int>();
//
//   R select<R>(
//     R Function(int state) selector, {
//     bool Function(int state)? when,
//   }) =>
//       getSelect<int, R>(selector);
// }
