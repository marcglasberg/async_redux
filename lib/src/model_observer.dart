// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// Based upon packages redux by Brian Egan, and flutter_redux by Brian Egan and John Ryan.
// Uses code from package equatable by Felix Angelov.
// For more info, see: https://pub.dartlang.org/packages/async_redux

import 'package:async_redux/async_redux.dart';

/// This will be given all errors, including those of type UserException.
/// Return true to throw the error. False to swallow it.
/// Note:
/// * When isDistinct==true, it means the widget rebuilt because the model changed.
/// * When isDistinct==false, it means the widget didn't rebuilt because the model hasn't changed.
/// * When isDistinct==null, it means the widget rebuilds everytime, and the model is not relevant.
abstract class ModelObserver<Model> {
  void observe({
    required Model? modelPrevious,
    required Model? modelCurrent,
    bool? isDistinct,
    StoreConnectorInterface? storeConnector,
    int? reduceCount,
    int? dispatchCount,
  });
}

/// This model observer prints the StoreConnector's ViewModel to the console.
///
/// Passe it to the store like this:
///
/// `var store = Store(modelObserver:DefaultModelObserver());`
///
/// If you need to print the type of the `StoreConnector` to the console,
/// make sure to pass `debug:this` as a `StoreConnector` constructor parameter.
/// Then, optionally, you can also specify a list of `StoreConnector`s to be
/// observed:
///
/// `DefaultModelObserver([MyStoreConnector, SomeOtherStoreConnector]);`
///
/// You can also override your `ViewModels.toString()` to print out
/// any extra info you need.
///
class DefaultModelObserver<Model> implements ModelObserver<Model> {
  Model? _previous;
  Model? _current;

  Model? get previous => _previous;

  Model? get current => _current;

  final List<Type> _storeConnectorTypes;

  DefaultModelObserver([this._storeConnectorTypes = const <Type>[]]);

  @override
  void observe({
    required Model? modelPrevious,
    required Model? modelCurrent,
    bool? isDistinct,
    StoreConnectorInterface? storeConnector,
    int? reduceCount,
    int? dispatchCount,
  }) {
    _previous = modelPrevious;
    _current = modelCurrent;

    var shouldObserve = _storeConnectorTypes.isEmpty ||
        _storeConnectorTypes.contains(storeConnector!.debug?.runtimeType);

    if (shouldObserve)
      print("Model D:$dispatchCount R:$reduceCount = "
          "Rebuild:${isDistinct == null || isDistinct}, "
          "${storeConnector!.debug == null ? "" : //
              "Connector:${storeConnector.debug.runtimeType}"}, "
          "Model:$modelCurrent.");
  }
}
