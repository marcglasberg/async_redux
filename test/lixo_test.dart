import 'package:async_redux/async_redux.dart';

@stateClass
class AppState {
  final int counter;
  final bool waiting, loading;

  AppState({
    required this.counter,
    required this.waiting,
    required this.loading,
  });

  AppState copy({int? counter, bool? waiting, bool? loading}) => AppState(
        waiting: waiting ?? this.waiting,
        loading: loading ?? this.loading,
        counter: counter ?? this.counter,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppState &&
          runtimeType == other.runtimeType &&
          waiting == other.waiting &&
          loading == other.loading &&
          counter == other.counter;

  @override
  int get hashCode => Object.hash(counter, loading, waiting);

// static AppState initialState() => AppState(
//   counter: 1,
//   waiting: false,
//   clearTextEvt: Event.spent(),
//   changeTextEvt: Event<String>.spent(),
// );
//
// @override
// bool operator ==(Object other) =>
//     identical(this, other) ||
//         other is AppState &&
//             runtimeType == other.runtimeType &&
//             counter == other.counter &&
//             waiting == other.waiting;
//
// @override
// int get hashCode => counter.hashCode ^ waiting.hashCode;
}
