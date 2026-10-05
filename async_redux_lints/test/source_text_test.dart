import 'package:async_redux_lints/src/source_text.dart';
import 'package:test/test.dart';

void main() {
  group('containsName', () {
    test('finds the name as a whole word', () {
      expect(containsName('Store', 'Store'), isTrue);
      expect(containsName('var store = Store<AppState>();', 'Store'), isTrue);
      expect(containsName('ar.Store(initialState: s)', 'Store'), isTrue);
      expect(containsName('(Store)', 'Store'), isTrue);
      expect(containsName('a\nStore\nb', 'Store'), isTrue);
    });

    test("doesn't find the name inside a longer word", () {
      expect(containsName('StoreProvider', 'Store'), isFalse);
      expect(containsName('AppStore', 'Store'), isFalse);
      expect(containsName('_Store', 'Store'), isFalse);
      expect(containsName('Store_', 'Store'), isFalse);
      expect(containsName('Store2', 'Store'), isFalse);
      expect(containsName('store', 'Store'), isFalse);
    });

    test('keeps searching after a match inside a longer word', () {
      expect(containsName('AppStore Store', 'Store'), isTrue);
      expect(containsName('StoreProvider Store', 'Store'), isTrue);
      expect(containsName('StorStore Store', 'Store'), isTrue);
      expect(containsName('SStore', 'Store'), isFalse);
    });

    test('works with short texts and names', () {
      expect(containsName('', 'Store'), isFalse);
      expect(containsName('Stor', 'Store'), isFalse);
      expect(containsName('a b', 'b'), isTrue);
      expect(containsName('ab', 'b'), isFalse);
    });

    test('skips code units that are not ASCII', () {
      expect(containsName('// é ✓ 😀\nStore', 'Store'), isTrue);
      expect(containsName('é😀Store😀é', 'Store'), isTrue);
      expect(containsName('😀😀😀😀😀😀', 'Store'), isFalse);
    });

    test('names with repeated letters', () {
      expect(containsName('x.setNavigatorKey(key);', 'setNavigatorKey'), isTrue);
      expect(containsName('Vm.createFrom(store, f)', 'createFrom'), isTrue);
      expect(containsName('createFromJson', 'createFrom'), isFalse);
      expect(
        containsName('UserExceptionDialogs UserExceptionDialog(', 'UserExceptionDialog'),
        isTrue,
      );
    });
  });
}
