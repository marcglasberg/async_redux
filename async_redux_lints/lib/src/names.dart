// Helpers for the names of classes, fields and files. They check the code units
// directly, which is many times faster than a `RegExp`.

const _underscore = 0x5F;

/// Returns the number of underscores at the start of [name], like 1 for `_counter`.
int leadingUnderscores(String name) {
  var count = 0;
  while (count < name.length && name.codeUnitAt(count) == _underscore) {
    count++;
  }
  return count;
}

/// Returns [name] without the underscores at its start, like `counter` for `_counter`.
String withoutLeadingUnderscores(String name) {
  var count = leadingUnderscores(name);
  return (count == 0) ? name : name.substring(count);
}

/// Returns [name] without the underscores at its end, like `LoadUser` for
/// `LoadUser__`.
String withoutTrailingUnderscores(String name) {
  var end = name.length;
  while (end > 0 && name.codeUnitAt(end - 1) == _underscore) {
    end--;
  }
  return (end == name.length) ? name : name.substring(0, end);
}

/// Returns true if [codeUnit] is an ASCII uppercase letter.
bool isUppercase(int codeUnit) => codeUnit >= 0x41 && codeUnit <= 0x5A;

/// Returns true if [codeUnit] is an ASCII lowercase letter.
bool isLowercase(int codeUnit) => codeUnit >= 0x61 && codeUnit <= 0x7A;

/// Returns true if [codeUnit] is an ASCII digit.
bool isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;
