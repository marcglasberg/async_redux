// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

import 'package:flutter/material.dart' hide Action;

import '../async_redux.dart';

/// Helps testing the `StoreConnector`s methods, such as `onInit`,
/// `onDispose` and `onWillChange`.
///
/// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux
///
/// Example: Suppose you have a `StoreConnector` which dispatches `SomeAction`
/// on its `onInit`. How could you test that?
///
/// ```
/// class MyConnector extends StatelessWidget {
///   Widget build(BuildContext context) => StoreConnector<AppState, Vm>(
///         vm: () => _Factory(),
///         onInit: _onInit,
///         builder: (context, vm) { ... }
///   }
///
///   void _onInit(Store<AppState> store) => store.dispatch(SomeAction());
/// }
///
/// var storeTester = StoreTester(...);
/// ConnectorTester(tester, MyConnector()).runOnInit();
/// var info = await tester.waitUntil(SomeAction);
/// ```
///
class ConnectorTester<St, Model> {
  final Store<St> store;
  final StatelessWidget widgetConnector;

  StoreConnector<St, Model>? _storeConnector;

  StoreConnector<St, Model> get storeConnector => _storeConnector ??=
      // ignore: invalid_use_of_protected_member
      widgetConnector.build(StatelessElement(widgetConnector))
          as StoreConnector<St, Model>;

  ConnectorTester(this.store, this.widgetConnector);

  void runOnInit() {
    final OnInitCallback<St>? onInit = storeConnector.onInit;
    if (onInit != null) onInit(store);
  }

  void runOnDispose() {
    final OnDisposeCallback<St>? onDispose = storeConnector.onDispose;
    if (onDispose != null) onDispose(store);
  }

  void runOnWillChange(
    Model previousVm,
    Model newVm,
  ) {
    final OnWillChangeCallback<St, Model>? onWillChange =
        storeConnector.onWillChange;
    if (onWillChange != null)
      onWillChange(StatelessElement(widgetConnector), store, previousVm, newVm);
  }
}
