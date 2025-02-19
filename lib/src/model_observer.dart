// Developed by Marcelo Glasberg (2019) https://glasberg.dev and https://github.com/marcglasberg
// Based upon packages redux by Brian Egan, and flutter_redux by Brian Egan and John Ryan.
// Uses code from package equatable by Felix Angelov.
// For more info: https://asyncredux.com AND https://pub.dev/packages/async_redux

import 'package:async_redux/async_redux.dart';

/// The [ModelObserver] is rarely used. It's goal is to observe and troubleshoot the model changes
/// causing rebuilds. While you may subclass it to implement its [observe] method, usually you can
/// just use the provided [DefaultModelObserver] to print the StoreConnector's ViewModel to the
/// console.
///
abstract class ModelObserver<Model> {
  //
  /// The [ModelObserver] can be used to observe and troubleshoot the model changes.
  ///
  /// The [storeConnector] works by rebuilding the widget when the model changes.
  /// It needs to compare the [modelPrevious] with the [modelCurrent] to decide if the widget should
  /// rebuild:
  ///
  /// - [isDistinct] is `true` means the widget rebuilt because the model changed.
  /// - [isDistinct] is `false` means the widget didn't rebuilt because the model hasn't changed.
  /// - [isDistinct] is `null` means the widget rebuilds everytime (because of
  ///                the `StoreConnector.distinct` parameter), and the model is not relevant.
  void observe({
    required Model? modelPrevious,
    required Model? modelCurrent,
    bool? isDistinct,
    StoreConnectorInterface? storeConnector,
    int? reduceCount,
    int? dispatchCount,
  });
}

/// The [DefaultModelObserver] prints the StoreConnector's ViewModel to the console.
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
