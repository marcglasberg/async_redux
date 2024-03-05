// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// Based upon packages redux by Brian Egan, and flutter_redux by Brian Egan and John Ryan.
// Uses code from package equatable by Felix Angelov.
// For more info, see: https://pub.dartlang.org/packages/async_redux

library async_redux_view_model;

import 'package:async_redux/async_redux.dart';
import 'package:flutter/material.dart';

part 'equality.dart';

/// Each state passed in the [Vm.equals] parameter in the in view-model will be
/// compared by equality (==), unless it is of type [VmEquals], when it will be
/// compared by the [VmEquals.vmEquals] method, which by default is a comparison
/// by identity (but can be overridden).
abstract class VmEquals<T> {
  bool vmEquals(T other) => identical(this, other);
}

/// [Vm] is a base class for your view-models.
///
/// A view-model is a helper object to a [StoreConnector] widget. It holds the
/// part of the Store state the corresponding dumb-widget needs, and may also
/// convert this state part into a more convenient format for the dumb-widget
/// to work with.
///
/// Each time the state changes, all [StoreConnector]s in the widget tree will
/// create a view-model, and compare it with the view-model they created with
/// the previous state. Only if the view-model changed, the [StoreConnector]
/// will rebuild. For this to work, you must implement equals/hashcode for the
/// view-model class. Otherwise, the [StoreConnector] will think the view-model
/// changed everytime, and thus will rebuild everytime. This wouldn't create any
/// visible problems to your app, but would be inefficient and maybe slow.
///
/// Using the [Vm] class you can implement equals/hashcode without having to
/// override these methods. Instead, simply list all fields (which are not
/// immutable, like functions) to the [equals] parameter in the constructor.
/// For example:
///
/// ```
/// ViewModel({this.counter, this.onIncrement}) : super(equals: [counter]);
/// ```
///
/// Each listed state will be compared by equality (==), unless it is of type
/// [VmEquals], when it will be compared by the [VmEquals.vmEquals] method,
/// which by default is a comparison by identity (but can be overridden).
///
@immutable
abstract class Vm {
  /// The List of properties which will be used to determine whether two BaseModels are equal.
  final List<Object?> equals;

  /// The constructor takes an optional List of fields which will be used
  /// to determine whether two [Vm] are equal.
  Vm({this.equals = const []}) : assert(_onlyContainFieldsOfAllowedTypes(equals));

  /// Fields should not contain functions.
  static bool _onlyContainFieldsOfAllowedTypes(List equals) {
    equals.forEach((Object? field) {
      if (field is Function)
        throw StoreException("ViewModel equals "
            "can't contain field of type Function: ${field.runtimeType}.");
    });

    return true;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Vm &&
            runtimeType == other.runtimeType &&
            _listEquals(
              equals,
              other.equals,
            );
  }

  bool _listEquals<T>(List<T>? list1, List<T>? list2) {
    if (list1 == null) return list2 == null;
    if (list2 == null || list1.length != list2.length) return false;
    if (identical(list1, list2)) return true;
    for (int index = 0; index < list1.length; index++) {
      var item1 = list1[index];
      var item2 = list2[index];

      if ((item1 is VmEquals<T>) &&
          (item2 is VmEquals<T>) //
          &&
          !item1.vmEquals(item2)) return false;

      if (item1 != item2) return false;
    }
    return true;
  }

  @override
  int get hashCode => runtimeType.hashCode ^ _propsHashCode;

  int get _propsHashCode {
    int hashCode = 0;
    equals.forEach((Object? prop) => hashCode = hashCode ^ prop.hashCode);
    return hashCode;
  }

  @override
  String toString() => '$runtimeType{${equals.join(', ')}}';
}

/// Factory that creates a view-model of type [Vm], for the [StoreConnector]:
///
/// ```
/// return StoreConnector<AppState, _ViewModel>(
///      vm: _Factory(),
///      builder: ...
/// ```
///
/// You must override the [fromStore] method:
///
/// ```
/// class _Factory extends VmFactory {
///    _ViewModel fromStore() => _ViewModel(
///        counter: state,
///        onIncrement: () => dispatch(IncrementAction(amount: 1)));
/// }
/// ```
///
/// If necessary, you can pass the [StoreConnector] widget to the factory:
///
/// ```
/// return StoreConnector<AppState, _ViewModel>(
///      vm: _Factory(this),
///      builder: ...
///
/// ...
/// class _Factory extends VmFactory<AppState, MyHomePageConnector> {
///    _Factory(connector) : super(connector);
///    _ViewModel fromStore() => _ViewModel(
///        counter: state,
///        onIncrement: () => dispatch(IncrementAction(amount: widget.amount)));
/// }
/// ```
///
abstract class VmFactory<St, T extends Widget?, Model extends Vm> {
  /// You need to pass the connector widget only if the view-model needs any info from it.
  VmFactory([this._connector]);

  Model? fromStore();

  /// To test the view-model generated by a Factory, first create a store-tester.
  /// Then call the [fromStoreTester] method, passing the store-tester. You will get
  /// the view-model, which you can use to:
  /// * Inspect the view-model properties directly, or
  /// * Call any of the view-model callbacks. If the callbacks dispatch actions,
  /// you can wait for them using the store-tester.
  ///
  /// Example:
  /// ```
  /// var storeTester = StoreTester(initialState: User("Mary"));
  /// var vm = MyFactory().fromStoreTester(storeTester);
  /// expect(vm.user.name, "Mary");
  ///
  /// vm.onChangeNameTo("Bill"); // Dispatches SetNameAction("Bill").
  /// var info = await storeTester.wait(SetNameAction);
  /// expect(info.state.name, "Bill");
  /// ```
  /// Note: This method must be called in a recently created factory, as this
  /// method may be called only once per factory instance.
  ///
  @visibleForTesting
  Model? fromStoreTester(StoreTester<St> storeTester) {
    internalsVmFactoryInject(this, storeTester.state, storeTester.store);
    return internalsVmFactoryFromStore(this) as Model;
  }

  final T? _connector;

  /// The connector widget that will instantiate the view-model.
  @Deprecated("Use `connector` instead")
  T? get widget => _connector;

  /// The connector widget that will instantiate the view-model.
  T get connector {
    if (_connector == null)
      throw StoreException(
          "To use the `connector` field you must pass it to the factory constructor:"
          "\n\n"
          "return StoreConnector<AppState, _Vm>(\n"
          "   vm: () => Factory(this),\n"
          "   ..."
          "\n\n"
          "class Factory extends VmFactory<_Vm, MyConnector> {\n"
          "   Factory(Widget widget) : super(widget);");
    else
      return _connector;
  }

  late final Store<St> _store;
  late final St _state;

  /// Once the Vm is created, we save it so that it can be used by factory methods.
  Model? _vm;
  bool _vmCreated = false;

  /// Once the view-model is created, and as long as it's not null, you can reference
  /// it by using the [vm] getter. This is meant to be used inside of Factory methods.
  ///
  /// Example:
  ///
  /// ```
  /// ViewModel fromStore() =>
  ///   ViewModel(
  ///     value: _calculateValue(),
  ///     onTap: _onTap);
  ///   }
  ///
  /// // Here we use the value, without having to recalculate it.
  /// void _onTap() => dispatch(SaveValueAction(vm.value));
  /// ```
  ///
  Model get vm {
    if (!_vmCreated)
      throw StoreException("You can't reference the view-model "
          "before it's created and returned by the fromStore method.");

    if (_vm == null)
      throw StoreException("You can't reference the view-model, "
          "because it's null.");

    return _vm!;
  }

  bool get ifVmIsNull {
    if (!_vmCreated)
      throw StoreException("You can't reference the view-model "
          "before it's created and returned by the fromStore method.");

    return (_vm == null);
  }

  void _setStore(St state, Store store) {
    _store = store as Store<St>;
    _state = state;
  }

  /// The state the store was holding when the factory and the view-model were created.
  /// This state is final inside of the factory.
  St get state => _state;

  Object? get env => _store.env;

  /// The current (most recent) store state.
  /// This will return the current state the store holds at the time the method is called.
  St currentState() => _store.state;

  /// Dispatches the action, applying its reducer, and possibly changing the store state.
  /// The action may be sync or async.
  ///
  /// ```dart
  /// dispatch(new MyAction());
  /// ```
  ///
  /// Method [dispatch] is of type [Dispatch].
  ///
  /// See also:
  /// - [dispatchSync] which dispatches sync actions, and throws if the action is async.
  /// - [dispatchAndWait] which dispatches both sync and async actions, and returns a Future.
  Dispatch<St> get dispatch => _store.dispatch;

  @Deprecated("Use `dispatchAndWait` instead. This method will be removed.")
  DispatchAsync<St> get dispatchAsync => _store.dispatchAndWait;

  /// Dispatches the action, applying its reducer, and possibly changing the store state.
  /// The action may be sync or async. In both cases, it returns a [Future] that resolves when
  /// the action finishes.
  ///
  /// ```dart
  /// await dispatchAndWait(new DoThisFirstAction());
  /// dispatch(new DoThisSecondAction());
  /// ```
  ///
  /// Note: While the state change from the action's reducer will have been applied when the
  /// Future resolves, other independent processes that the action may have started may still
  /// be in progress.
  ///
  /// Method [dispatchAndWait] is of type [DispatchAndWait]. It returns `Future<ActionStatus>`,
  /// which means you can also get the final status of the action after you `await` it:
  ///
  /// ```dart
  /// var status = await dispatchAndWait(new MyAction());
  /// ```
  ///
  /// See also:
  /// - [dispatch] which dispatches both sync and async actions.
  /// - [dispatchSync] which dispatches sync actions, and throws if the action is async.
  DispatchAndWait<St> get dispatchAndWait => _store.dispatchAndWait;

  /// Dispatches the action, applying its reducer, and possibly changing the store state.
  /// However, if the action is ASYNC, it will throw a [StoreException].
  ///
  /// Method [dispatchSync] is of type [DispatchSync].
  ///
  /// See also:
  /// - [dispatch] which dispatches both sync and async actions.
  /// - [dispatchAndWait] which dispatches both sync and async actions, and returns a Future.
  DispatchSync<St> get dispatchSync => _store.dispatchSync;

  /// Gets the first error from the error queue, and removes it from the queue.
  UserException? getAndRemoveFirstError() => _store.getAndRemoveFirstError();
}

/// For internal use only. Please don't use this.
Vm? internalsVmFactoryFromStore(VmFactory<dynamic, dynamic, dynamic> vmFactory) {
  vmFactory._vm = vmFactory.fromStore();
  vmFactory._vmCreated = true;
  return vmFactory._vm;
}

/// For internal use only. Please don't use this.
void internalsVmFactoryInject<St>(
    VmFactory<St, dynamic, dynamic> vmFactory, St state, Store store) {
  vmFactory._setStore(state, store);
}

/// Don't use, this is deprecated. Please, use the recommended [Vm] class.
/// This should only be used for IMMUTABLE classes.
/// Lets you implement equals/hashcode without having to override these methods.
abstract class BaseModel<St> {
  /// The List of properties which will be used to determine whether two BaseModels are equal.
  final List<Object?> equals;

  /// You can pass the connector widget, in case the view-model needs any info from it.
  final Object? widget;

  /// The constructor takes an optional List of fields which will be used
  /// to determine whether two [BaseModel] are equal.
  BaseModel({this.equals = const [], this.widget})
      : assert(_onlyContainFieldsOfAllowedTypes(equals));

  /// Fields should not contain functions.
  static bool _onlyContainFieldsOfAllowedTypes(List equals) {
    equals.forEach((Object? field) {
      if (field is Function)
        throw StoreException("ViewModel equals "
            "has an invalid field of type ${field.runtimeType}.");
    });

    return true;
  }

  void _setStore(St state, Store store) {
    _state = state;
    _dispatch = store.dispatch;
    _getAndRemoveFirstError = store.getAndRemoveFirstError;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BaseModel &&
          runtimeType == other.runtimeType &&
          const _ListEquality<Object?>().equals(
            equals,
            other.equals,
          );

  @override
  int get hashCode => runtimeType.hashCode ^ _propsHashCode;

  int get _propsHashCode {
    int hashCode = 0;
    equals.forEach((Object? prop) => hashCode = hashCode ^ prop.hashCode);
    return hashCode;
  }

  late St _state;
  Dispatch<St>? _dispatch;
  late UserException? Function() _getAndRemoveFirstError;

  BaseModel fromStore();

  St get state => _state;

  Dispatch<St>? get dispatch => _dispatch;

  UserException? Function() get getAndRemoveFirstError => //
      _getAndRemoveFirstError;

  @override
  String toString() => '$runtimeType{${equals.join(', ')}}';
}

/// For internal use only. Please don't use this.
void internalsBaseModelInject<St>(BaseModel baseModel, St state, Store store) {
  baseModel._setStore(state, store);
}
