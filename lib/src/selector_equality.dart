import 'package:collection/collection.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

import 'store.dart' show CompareBy;

/// Collection comparison for selectors that preserves FIC item semantics.
///
/// DeepCollectionEquality delegates nested comparisons and hashing back to this
/// instance in deep mode. FIC item comparison is delegated without recursion.
class SelectorEquality extends DeepCollectionEquality {
  const SelectorEquality(this.collectionEquality);

  final CompareBy collectionEquality;

  @override
  bool equals(Object? e1, Object? e2) {
    if (collectionEquality == CompareBy.byEquals) return e1 == e2;

    if (e1 is ImmutableCollection || e2 is ImmutableCollection) {
      if (e1 is! ImmutableCollection || e2 is! ImmutableCollection) return false;

      return switch (collectionEquality) {
        CompareBy.byEquals => e1 == e2,
        CompareBy.byDeepEquals => areImmutableCollectionsWithEqualItems(e1, e2),
        CompareBy.byIdentity => identical(e1, e2) || areSameImmutableCollection(e1, e2),
      };
    }

    if (collectionEquality == CompareBy.byIdentity) {
      if (e1 is Iterable || e2 is Iterable || e1 is Map || e2 is Map) {
        return identical(e1, e2);
      }
      return e1 == e2;
    }

    return super.equals(e1, e2);
  }

  @override
  int hash(Object? o) {
    if (collectionEquality == CompareBy.byEquals) return o.hashCode;

    if (o is ImmutableCollection) {
      // FIC's hashCode matches its own ==, but may disagree with an overridden
      // policy. A shared hash keeps set elements and map keys comparable even
      // across different FIC configurations. Collisions are resolved by equals.
      return 0;
    }

    if (collectionEquality == CompareBy.byIdentity) {
      return o is Iterable || o is Map ? identityHashCode(o) : o.hashCode;
    }

    return super.hash(o);
  }
}
