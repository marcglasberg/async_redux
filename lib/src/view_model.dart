library async_redux_view_model;

import 'package:async_redux/async_redux.dart';
import 'package:meta/meta.dart';

part 'equality.dart';

// Developed by Marcelo Glasberg (Aug 2019).
// Based upon packages redux by Brian Egan, and flutter_redux by Brian Egan and John Ryan.
// Uses code from package equatable by Felix Angelov.
// For more info, see: https://pub.dartlang.org/packages/async_redux

// /////////////////////////////////////////////////////////////////////////////

/// Each state passed in the [Vm.equals] parameter in the in view-model will be
/// compared by equality (==), unless it is of type [VmEquals], when it will be
/// compared by the [VmEquals.vmEquals] method, which by default is a comparison
/// by identity (but can be overridden).
abstract class VmEquals<T> {
  bool vmEquals(T other) => identical(this, other);
}

// /////////////////////////////////////////////////////////////////////////////

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

// /////////////////////////////////////////////////////////////////////////////

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
///    _Factory(widget) : super(widget);
///    _ViewModel fromStore() => _ViewModel(
///        counter: state,
///        onIncrement: () => dispatch(IncrementAction(amount: widget.amount)));
/// }
/// ```
///
abstract class VmFactory<St, T> {
  /// A reference to the connector widget that will instantiate the view-model.
  final T? widget;

  late final Store<St> _store;
  late final St _state;

  /// You need to pass the connector widget only if the view-model needs any info from it.
  VmFactory([this.widget]);

  Vm? fromStore();

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

  /// Dispatch an action, possibly changing the store state.
  Dispatch<St> get dispatch => _store.dispatch;

  /// Dispatch an action, possibly changing the store state.
  DispatchAsync<St> get dispatchAsync => _store.dispatchAsync;

  UserException? getAndRemoveFirstError() => _store.getAndRemoveFirstError();
}

/// For internal use only. Please don't use this.
void internalsVmFactoryInject<St>(VmFactory vmFactory, St state, Store store) {
  vmFactory._setStore(state, store);
}

// /////////////////////////////////////////////////////////////////////////////

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

// /////////////////////////////////////////////////////////////////////////////
