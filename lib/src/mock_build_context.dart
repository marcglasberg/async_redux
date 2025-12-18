// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// Based upon packages redux by Brian Egan, and flutter_redux by Brian Egan and John Ryan.
// Uses code from package equatable by Felix Angelov.
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

import 'package:async_redux/async_redux.dart';
import 'package:flutter/foundation.dart' show DiagnosticsTreeStyle;
import 'package:flutter/material.dart';

/// A mock BuildContext that holds a Store reference, for testing purposes.
///
/// This allows you to test smart widgets created with context extensions.
/// For example, suppose this is your smart widget:
///
/// ```dart
/// class MyConnector extends StoreConnector<AppState, MyModel> {
///   Widget build(BuildContext context) {
///     return MyWidget(name: context.state.name);
///   }
/// }
/// ```
///
/// This is how you can test it with:
///
/// ```dart
/// // First, create a Store with the desired initial state.
/// var store = Store(initialState: AppState(name: 'Mark');
///
/// // Then, create a mock BuildContext with that store.
/// var context = MockBuildContext(store);
///
/// // Instantiate your StoreConnector or StoreProvider and build the widget.
/// var widget = MyConnector().build(context) as MyWidget;
/// expect(widget.name, 'Mark');
/// ```
///
class MockBuildContext extends BuildContext {
  final Store store;

  MockBuildContext(this.store) {
    // Create the static store backdoor.
    StoreProvider(store: store, child: const SizedBox());
  }

  @override
  Widget get widget => const Placeholder();

  @override
  bool get debugDoingBuild => true;

  @override
  InheritedWidget dependOnInheritedElement(InheritedElement ancestor,
      {Object? aspect}) {
    throw UnimplementedError('Not implemented in MockBuildContext.');
  }

  @override
  T? dependOnInheritedWidgetOfExactType<T extends InheritedWidget>(
      {Object? aspect}) {
    throw UnimplementedError('Not implemented in MockBuildContext.');
  }

  @override
  DiagnosticsNode describeElement(String name,
      {DiagnosticsTreeStyle style = DiagnosticsTreeStyle.errorProperty}) {
    return DiagnosticsNode.message('Not implemented in MockBuildContext.');
  }

  @override
  List<DiagnosticsNode> describeMissingAncestor(
      {required Type expectedAncestorType}) {
    return [DiagnosticsNode.message('Not implemented in MockBuildContext.')];
  }

  @override
  DiagnosticsNode describeOwnershipChain(String name) {
    return DiagnosticsNode.message('Not implemented in MockBuildContext.');
  }

  @override
  DiagnosticsNode describeWidget(String name,
      {DiagnosticsTreeStyle style = DiagnosticsTreeStyle.errorProperty}) {
    return DiagnosticsNode.message('Not implemented in MockBuildContext.');
  }

  @override
  void dispatchNotification(Notification notification) {
    // Do nothing.
  }

  @override
  T? findAncestorRenderObjectOfType<T extends RenderObject>() {
    throw UnimplementedError('Not implemented in MockBuildContext.');
  }

  @override
  T? findAncestorStateOfType<T extends State<StatefulWidget>>() {
    throw UnimplementedError('Not implemented in MockBuildContext.');
  }

  @override
  T? findAncestorWidgetOfExactType<T extends Widget>() {
    throw UnimplementedError('Not implemented in MockBuildContext.');
  }

  @override
  RenderObject? findRenderObject() {
    throw UnimplementedError('Not implemented in MockBuildContext.');
  }

  @override
  T? findRootAncestorStateOfType<T extends State<StatefulWidget>>() {
    throw UnimplementedError('Not implemented in MockBuildContext.');
  }

  @override
  InheritedElement?
      getElementForInheritedWidgetOfExactType<T extends InheritedWidget>() {
    throw UnimplementedError('Not implemented in MockBuildContext.');
  }

  @override
  T? getInheritedWidgetOfExactType<T extends InheritedWidget>() {
    throw UnimplementedError('Not implemented in MockBuildContext.');
  }

  @override
  bool get mounted => true;

  @override
  BuildOwner? get owner => null;

  @override
  Size? get size =>
      throw UnimplementedError('Not implemented in MockBuildContext.');

  @override
  void visitAncestorElements(ConditionalElementVisitor visitor) {
    // Do nothing.
  }

  @override
  void visitChildElements(ElementVisitor visitor) {
    // Do nothing.
  }
}
