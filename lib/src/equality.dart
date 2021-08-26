part of async_redux_view_model;

// /////////////////////////////////////////////////////////////////////////////

// Developed by Google.
// For some reason pub.dev complains if we add the collection package.
// I got tired of this, and copied ListEquality here.

class _ListEquality<E> implements _Equality<List<E>> {
  static const int _HASH_MASK = 0x7fffffff;

  final _Equality<E> _elementEquality;

  const _ListEquality(
      [_Equality<E> elementEquality = const _DefaultEquality<Never>()])
      : _elementEquality = elementEquality;

  @override
  bool equals(List<E>? list1, List<E>? list2) {
    if (identical(list1, list2)) return true;
    if (list1 == null || list2 == null) return false;
    var length = list1.length;
    if (length != list2.length) return false;
    for (var i = 0; i < length; i++) {
      if (!_elementEquality.equals(list1[i], list2[i])) return false;
    }
    return true;
  }

  @override
  int hash(List<E>? list) {
    if (list == null) return null.hashCode;
    var hash = 0;
    for (var i = 0; i < list.length; i++) {
      var c = _elementEquality.hash(list[i]);
      hash = (hash + c) & _HASH_MASK;
      hash = (hash + (hash << 10)) & _HASH_MASK;
      hash ^= (hash >> 6);
    }
    hash = (hash + (hash << 3)) & _HASH_MASK;
    hash ^= (hash >> 11);
    hash = (hash + (hash << 15)) & _HASH_MASK;
    return hash;
  }

  @override
  bool isValidKey(Object o) => o is List<E>;
}

// /////////////////////////////////////////////////////////////////////////////

class _DefaultEquality<E> implements _Equality<E> {
  const _DefaultEquality();

  @override
  bool equals(Object? e1, Object? e2) => e1 == e2;

  @override
  int hash(Object? e) => e.hashCode;

  @override
  bool isValidKey(Object o) => true;
}

// /////////////////////////////////////////////////////////////////////////////

abstract class _Equality<E> {
  const factory _Equality() = _DefaultEquality<E>;

  bool equals(E e1, E e2);

  int hash(E e);

  bool isValidKey(Object o);
}

// /////////////////////////////////////////////////////////////////////////////
