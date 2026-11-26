import 'package:async_redux/async_redux.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fresh status and fresh actions have no lifecycle progress or context', () {
    final status = ActionStatus(context: null);
    final first = UpdateStateAction<int>(1);
    final second = UpdateStateAction<int>(2);
    for (final value in [status, first.status, second.status]) {
      expect(value.isDispatched, isFalse);
      expect(value.hasFinishedMethodBefore, isFalse);
      expect(value.hasFinishedMethodReduce, isFalse);
      expect(value.hasFinishedMethodAfter, isFalse);
      expect(value.isDispatchAborted, isFalse);
      expect(value.originalError, isNull);
      expect(value.wrappedError, isNull);
      expect(value.context, isNull);
      expect(value.isCompleted, isFalse);
      expect(value.isCompletedOk, isFalse);
      expect(value.isCompletedFailed, isFalse);
    }
    expect(first.status, same(first.status));
    expect(first.status, isNot(same(second.status)));
    expect(first.status, second.status);
  });

  // Every combination matters here: completion depends on after and the ORIGINAL
  // error, including swallowed errors and an abort after dispatch has started.
  for (var flags = 0; flags < 32; flags++) {
    for (final original in <Object?>[null, false, 'original']) {
      for (final wrapped in <Object?>[null, false, 'wrapped']) {
        test(
          'completion truth table flags=$flags original=$original wrapped=$wrapped',
          () {
            final after = flags & 8 != 0;
            final status = ActionStatus(
              isDispatched: flags & 1 != 0,
              hasFinishedMethodBefore: flags & 2 != 0,
              hasFinishedMethodReduce: flags & 4 != 0,
              hasFinishedMethodAfter: after,
              isDispatchAborted: flags & 16 != 0,
              originalError: original,
              wrappedError: wrapped,
              context: null,
            );
            expect(status.isCompleted, after);
            expect(status.isCompletedOk, after && original == null);
            expect(status.isCompletedFailed, after && original != null);
            expect(status.isCompletedOk && status.isCompletedFailed, isFalse);
            expect(status.isCompletedOk || status.isCompletedFailed, after);
          },
        );
      }
    }
  }

  test('copy preserves every value and null arguments mean no replacement', () async {
    final store = Store<int>(initialState: 0);
    addTearDown(store.teardown);
    final action = UpdateStateAction<int>(1);
    final original = Object();
    final wrapped = Object();
    final status = ActionStatus(
      isDispatched: true,
      hasFinishedMethodBefore: true,
      hasFinishedMethodReduce: true,
      hasFinishedMethodAfter: true,
      isDispatchAborted: true,
      originalError: original,
      wrappedError: wrapped,
      context: (action, store),
    );
    final copy = status.copy(
      isDispatched: null,
      hasFinishedMethodBefore: null,
      hasFinishedMethodReduce: null,
      hasFinishedMethodAfter: null,
      isDispatchAborted: null,
      originalError: null,
      wrappedError: null,
      context: null,
    );
    expect(copy, status);
    expect(copy, isNot(same(status)));
    expect(copy.originalError, same(original));
    expect(copy.wrappedError, same(wrapped));
    expect(copy.context!.$1, same(action));
    expect(copy.context!.$2, same(store));
    expect(copy.hashCode, status.hashCode);

    final replacements = <ActionStatus>[
      status.copy(isDispatched: false),
      status.copy(hasFinishedMethodBefore: false),
      status.copy(hasFinishedMethodReduce: false),
      status.copy(hasFinishedMethodAfter: false),
      status.copy(isDispatchAborted: false),
      status.copy(originalError: false),
      status.copy(wrappedError: false),
      status.copy(context: (UpdateStateAction<int>(2), store)),
    ];
    final originalFields = <Object?>[
      true,
      true,
      true,
      true,
      true,
      original,
      wrapped,
      (action, store),
    ];
    for (var index = 0; index < replacements.length; index++) {
      final replacement = replacements[index];
      expect(replacement, isNot(status));
      expect(replacement.copy(), replacement);
      expect(replacement.copy().hashCode, replacement.hashCode);
      final expectedFields = List<Object?>.of(originalFields);
      expectedFields[index] = index == 7 ? replacement.context : false;
      expect([
        replacement.isDispatched,
        replacement.hasFinishedMethodBefore,
        replacement.hasFinishedMethodReduce,
        replacement.hasFinishedMethodAfter,
        replacement.isDispatchAborted,
        replacement.originalError,
        replacement.wrappedError,
        replacement.context,
      ], expectedFields);
    }
    expect(replacements[0].copy(isDispatched: true), status);
    expect(replacements[1].copy(hasFinishedMethodBefore: true), status);
    expect(replacements[2].copy(hasFinishedMethodReduce: true), status);
    expect(replacements[3].copy(hasFinishedMethodAfter: true), status);
    expect(replacements[4].copy(isDispatchAborted: true), status);
    expect(replacements[5].originalError, false);
    expect(replacements[5].wrappedError, same(wrapped));
    expect(replacements[6].wrappedError, false);
    expect(replacements[6].originalError, same(original));
    expect(status.isDispatched, isTrue);
    expect(status.originalError, same(original));
    expect(status.wrappedError, same(wrapped));
  });

  test(
    'equality uses error value equality, both context members and runtime type',
    () async {
      final firstStore = Store<int>(initialState: 0);
      final secondStore = Store<int>(initialState: 0);
      addTearDown(firstStore.teardown);
      addTearDown(secondStore.teardown);
      final action = UpdateStateAction<int>(1);
      ActionStatus make() => ActionStatus(
        originalError: _ValueError(1),
        wrappedError: _ValueError(2),
        context: (action, firstStore),
      );
      final first = make();
      final second = make();
      final third = make();
      expect(first == first, isTrue);
      expect(first == second && second == first, isTrue);
      expect(first == second && second == third && first == third, isTrue);
      expect(first.hashCode, second.hashCode);
      expect(<ActionStatus>{first, second, third}, hasLength(1));
      expect({first: 'found'}[second], 'found');
      expect(first.copy(context: (action, secondStore)), isNot(first));
      expect(first.copy(context: (UpdateStateAction<int>(1), firstStore)), isNot(first));
      expect(first.copy(originalError: _ValueError(3)), isNot(first));
      expect(first.copy(wrappedError: _ValueError(3)), isNot(first));
      expect(first, isNot(Object()));
      expect(ActionStatus(context: null), isNot(_DerivedStatus()));
      expect(_DerivedStatus(), isNot(ActionStatus(context: null)));
    },
  );

  test('toString exposes all lifecycle and error fields without serializing context', () {
    final status = ActionStatus(
      isDispatched: true,
      hasFinishedMethodBefore: true,
      hasFinishedMethodReduce: false,
      hasFinishedMethodAfter: true,
      isDispatchAborted: true,
      originalError: 'original',
      wrappedError: 'wrapped',
      context: null,
    );
    expect(
      status.toString(),
      'ActionStatus{isDispatched: true, hasFinishedMethodBefore: true, '
      'hasFinishedMethodReduce: false, hasFinishedMethodAfter: true, '
      'isDispatchAborted: true, originalError: original, wrappedError: wrapped}',
    );
  });
}

class _ValueError {
  _ValueError(this.value);
  final int value;

  @override
  bool operator ==(Object other) => other is _ValueError && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class _DerivedStatus extends ActionStatus {
  _DerivedStatus() : super(context: null);
}
