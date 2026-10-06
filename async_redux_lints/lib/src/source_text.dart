import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/dart/ast/ast.dart';

/// Returns false if the source of [unit] doesn't contain the identifier [name], or
/// true if it may. For example, `Store` is not found in `StoreProvider`.
///
/// Searching the text is much faster than visiting the whole unit, so rules that only
/// report code that uses a name, like `UserExceptionDialog`, use this to skip the files
/// that don't.
bool mayContainName(RuleContext context, CompilationUnit unit, String name) {
  var current = context.currentUnit;
  if (current == null || current.unit != unit) return true;
  return containsName(current.content, name);
}

/// Returns true if [text] contains the ASCII identifier [name], not as part of a longer
/// word.
bool containsName(String text, String name) =>
    (_searches[name] ??= _NameSearch(name)).isIn(text);

/// Returns the offsets, in increasing order, where [text] contains the ASCII identifier
/// [name], not as part of a longer word.
List<int> nameOffsets(String text, String name) =>
    (_searches[name] ??= _NameSearch(name)).offsetsIn(text);

final _searches = <String, _NameSearch>{};

/// Finds an ASCII name in a text, as a whole word, with the Boyer-Moore-Horspool
/// algorithm, which skips ahead several characters at a time. In the Dart VM, this is
/// several times faster than `RegExp.hasMatch`, and than `String.contains`, which
/// doesn't skip.
class _NameSearch {
  final String name;

  /// For each ASCII code unit, how far the search can move when it's the last code
  /// unit of the part of the text being compared with [name].
  final List<int> _skip;

  _NameSearch(this.name) : _skip = List.filled(128, name.length) {
    for (var i = 0; i < name.length - 1; i++) {
      _skip[name.codeUnitAt(i)] = name.length - 1 - i;
    }
  }

  /// Returns true if [text] contains [name], not as part of a longer word.
  bool isIn(String text) => _indexIn(text, 0) != -1;

  /// Returns the offsets where [text] contains [name], not as part of a longer word.
  List<int> offsetsIn(String text) => [
    for (
      var start = _indexIn(text, 0);
      start != -1;
      start = _indexIn(text, start + name.length)
    )
      start,
  ];

  /// Returns the offset of the first [name] in [text], not as part of a longer word,
  /// that starts at [from] or later. Returns -1 if there is none.
  int _indexIn(String text, int from) {
    var length = name.length;
    var lastOfName = name.codeUnitAt(length - 1);
    // The index of the last code unit of the part of the text being compared.
    var end = from + length - 1;
    while (end < text.length) {
      var codeUnit = text.codeUnitAt(end);
      if (codeUnit == lastOfName && _isAt(text, end - length + 1)) {
        return end - length + 1;
      }
      // A code unit that isn't ASCII isn't in the name, so the search skips past it.
      end += (codeUnit < 128) ? _skip[codeUnit] : length;
    }
    return -1;
  }

  /// Returns true if [name] is in [text] at [start], with no word characters around
  /// it. The last code unit was already compared.
  bool _isAt(String text, int start) {
    for (var i = 0; i < name.length - 1; i++) {
      if (text.codeUnitAt(start + i) != name.codeUnitAt(i)) return false;
    }
    var after = start + name.length;
    return (start == 0 || !_isWordCharacter(text.codeUnitAt(start - 1))) &&
        (after == text.length || !_isWordCharacter(text.codeUnitAt(after)));
  }

  /// Returns true for letters, digits and `_`. These are the word characters of a
  /// `\b` in a `RegExp`.
  static bool _isWordCharacter(int codeUnit) =>
      (codeUnit >= 0x61 && codeUnit <= 0x7A) ||
      (codeUnit >= 0x41 && codeUnit <= 0x5A) ||
      (codeUnit >= 0x30 && codeUnit <= 0x39) ||
      codeUnit == 0x5F;
}
